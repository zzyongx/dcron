/* vim:expandtab:shiftwidth=4:tabstop=4:smarttab:
 */

#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <cstdarg>
#include <errno.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <openssl/md5.h>

#include <configopt.h>

#define SHELL    "/bin/sh"
#define CONFFILE "/etc/cronshell.conf"

static void log(int eno, const char *fmt, ... );
static void childexec(int fds[], int cmdstart, char *argv[]);
static void parentexec(int fds[], int cmdstart, char *argv[]);

int main(int argc, char *argv[])
{
    int cmdstart;
    const char *error;

    error = ConfigOpt::apply(CONFFILE);
    if (error) {
        ConfigOpt::help(error);
        exit(EXIT_FAILURE);
    }

    error = ConfigOpt::apply(argc, argv, &cmdstart);
    if (error) {
        ConfigOpt::help(error);
        exit(EXIT_FAILURE);
    }

    if (ConfigOpt::showhelp) {
        ConfigOpt::help();
        exit(EXIT_SUCCESS);
    }

    int fds[2];
    if (pipe(fds) != 0) {
        log(errno, "pipe() error");
        exit(EXIT_FAILURE);
    }

    pid_t pid = fork();
    if (pid < 0) {
        log(errno, "fork() error");
        exit(EXIT_FAILURE);
    }

    if (pid == 0) {
        childexec(fds, cmdstart, argv);
        exit(EXIT_FAILURE);  // should never exec here
    }

    parentexec(fds, cmdstart, argv);
    return EXIT_SUCCESS;
}

#define LOG_STR_N 2048

static void log(int eno, const char *fmt, ... )
{
    char errstr[LOG_STR_N];
    size_t n = 0;

    struct tm ltm;
    time_t now = time(0);
    n = strftime(errstr, LOG_STR_N, "%Y-%m-%d %H:%M:%S ", localtime_r(&now, &ltm));
    if (eno != 0) {
        n += snprintf(errstr + n, LOG_STR_N - n, "%d:%s ", eno, strerror(eno));
    }

    va_list ap;

    va_start(ap, fmt);
    n += vsnprintf(errstr + n, LOG_STR_N - n - 1, fmt, ap);
    va_end(ap);

    errstr[n++] = '\n';

    int fd = STDOUT_FILENO;
    if (ConfigOpt::logf) {
        fd = open(ConfigOpt::logf, O_WRONLY | O_APPEND | O_CREAT,
                S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        if (fd == -1) fd = STDOUT_FILENO;
    }

    write(fd, errstr, n);

    if (ConfigOpt::logf && fd != STDOUT_FILENO) close(fd);
}

static const char *cmdstr(int start, char *argv[])
{
    static char *str = 0;
    if (str) return str;

    size_t n = 0;
    for (int i = start; argv[i]; ++i) {
        n += strlen(argv[i]) + 1;
    }

    str = (char *) malloc(n);
    n = 0;
    for (int i = start; argv[i]; ++i) {
        strcpy(str + n, argv[i]);
        n += strlen(argv[i]);
        str[n++] = argv[i+1] ? ' ' : '\0';
    }

    return str;
}

static char *md5sum(const char *c, char *dst)
{
    unsigned char md5raw[MD5_DIGEST_LENGTH];
    MD5((unsigned char *) c, strlen(c), md5raw);

    int n = 0;
    char tbl[] = "0123456789abcdef";
    for (int i = 0; i < MD5_DIGEST_LENGTH; ++i) {
        dst[n++] = tbl[md5raw[i] / 16];
        dst[n++] = tbl[md5raw[i] % 16];
    }
    dst[n] = '\0';
    return dst;
}

typedef int (*coordinator_pt)(const char *);

#define COOALLOW 0
#define COODENY  1
#define COOERROR 2

#ifdef COO_MEMCACHED
#include <libmemcached/memcached.h>
static int coomemcached(const char *key)
{
    char *pos;
    char  host[64];
    int   port;

    pos = strchr(ConfigOpt::memcached, ':');
    if (pos) {
        if (pos - ConfigOpt::memcached >= 64 || !*(pos + 1)) return COOERROR;
        strncpy(host, ConfigOpt::memcached, pos - ConfigOpt::memcached);
        host[pos - ConfigOpt::memcached] = '\0';
        port = atoi(pos + 1);
    } else {
        strcpy(host, ConfigOpt::memcached);
        port = 11211;
    }

    memcached_st *handle = memcached_create(0);
    if (!handle) return COOERROR;

    memcached_server_add(handle, host, port);
    memcached_behavior_set(handle, MEMCACHED_BEHAVIOR_RCV_TIMEOUT,
            ConfigOpt::xwindow * 1000 * 1000);
    memcached_behavior_set(handle, MEMCACHED_BEHAVIOR_SND_TIMEOUT,
            ConfigOpt::xwindow * 1000 * 1000);

    // use memcached_return_t in new version of libmemcached
    memcached_return rc;
    for (int i = 0; i < 3; ++i) {
        rc = memcached_add(handle, key, strlen(key), "1", 1, ConfigOpt::xwindow, 0);
        if (rc == MEMCACHED_NOTSTORED) {
            memcached_free(handle);
            return COODENY;
        }
        if (rc == MEMCACHED_SUCCESS) {
            memcached_free(handle);
            return COOALLOW;
        }
    }

    log(0, "memcached_add(%s) error %s", key, memcached_strerror(handle, rc));
    memcached_free(handle);
    return COOERROR;
}
#else
static int coomemcached(const char *) { return COOALLOW; }
#endif

#ifdef COO_ZOOKEEPER
#include <zookeeper/zookeeper.h>
static int coozookeeper(const char *key)
{
    zoo_set_debug_level(ZOO_LOG_LEVEL_ERROR);
    const char *zfile = ConfigOpt::logf ? ConfigOpt::logf : "/dev/null"; 
    FILE *zstream = fopen(zfile, "a");
    if (zstream) zoo_set_log_stream(zstream);

    /* must not call zookeeper_close, let session expire */
    zhandle_t *zh;
    zh = zookeeper_init(ConfigOpt::zookeeper, 0, ConfigOpt::xwindow * 1000, 0, 0, 0);
    if (!zh) {
        log(0, "zookeeper_init failed");
        return COOERROR;
    }

    char *path = (char *) malloc(strlen(key) + 2);
    path[0] = '/';
    strcpy(path + 1, key);

    int rc = ZCONNECTIONLOSS;
    for (int i = 0; i < 4 && rc == ZCONNECTIONLOSS; ++i) {
        rc = zoo_create(zh, path, NULL, -1, &ZOO_OPEN_ACL_UNSAFE, ZOO_EPHEMERAL, NULL, 0);
        if (rc == ZNODEEXISTS) {
            free(path);
            return COODENY;
        } else if (rc == ZOK) {
            free(path);
            return COOALLOW;
        }
    }

    log(0, "zoo_create(%s) error %s", key, zerror(rc));
    free(path);
    return COOERROR;
}
#else
static int coozookeeper(const char *) { return COOALLOW; }
#endif

static void childexec(int fds[2], int cmdstart, char *argv[])
{
    coordinator_pt coordinator = 0;
    if (ConfigOpt::zookeeper) {
        coordinator = coozookeeper;
    } else if (ConfigOpt::memcached) {
        coordinator = coomemcached;
    }

    if (coordinator) {
        char key[MD5_DIGEST_LENGTH * 2 + 1];
        md5sum(cmdstr(cmdstart, argv), key);
        int status = coordinator(key);
        if (status == COODENY) {
            log(0, "COODENY %s(%s)", cmdstr(cmdstart, argv), key);
            return;
        }
        if (status == COOERROR) {
            if (ConfigOpt::xpriority) {
                log(0, "COOERROR xprioriy %s(%s)", cmdstr(cmdstart, argv), key);
                return;
            }
        }
        log(0, "EXEC %s(%s)", cmdstr(cmdstart, argv), key);
    } else {
        log(0, "EXEC %s", cmdstr(cmdstart, argv));
    }

    close(fds[0]);
    if (dup2(fds[1], STDOUT_FILENO) == -1) {
        log(errno, "dup2 error");
        return;
    }
    if (ConfigOpt::logmore) {
        if (dup2(fds[1], STDERR_FILENO) == -1) {
            log(errno, "dup2 error");
            return;
        }
    }

    char *cargv[] = { SHELL, "-c", (char *) cmdstr(cmdstart, argv), 0 };
    execvp(SHELL, cargv);
}

#define BUFFER_N (4 * 1024 * 1024) 

static void parentexec(int fds[2], int cmdstart, char *argv[])
{
    close(fds[1]);

    size_t n = 0;
    char *buffer = (char *) malloc(BUFFER_N);

    ssize_t nn;
    char readbuf[PIPE_BUF];
    while ((nn = read(fds[0], readbuf, PIPE_BUF)) > 0) {
        if (n + nn > BUFFER_N) break;
        memcpy(buffer + n, readbuf, nn);
        n += nn;
    }

    int status;
    wait(&status);

    FILE *ofile = fopen(ConfigOpt::outputf, "a");
    if (!ofile) {
        log(errno, "fopen(%s) error", ConfigOpt::outputf);
        return;
    }

    char timebuf[32];
    struct tm ltm;
    time_t now = time(0);
    strftime(timebuf, 32, "%Y-%m-%d %H:%M:%S", localtime_r(&now, &ltm));

    if (WIFEXITED(status)) {
        fprintf(ofile, "\n%s %s exit with code %d\n", timebuf,
                cmdstr(cmdstart, argv), WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
        fprintf(ofile, "\n%s %s terminate by signal %d\n", timebuf,
                cmdstr(cmdstart, argv), WEXITSTATUS(status));
    } else {
        fprintf(ofile, "\n%s %s terminate abnorml\n", timebuf, cmdstr(cmdstart, argv));
    }

    fprintf(ofile, "%.*s", (int) n, buffer);
    fclose(ofile);

    free(buffer);
}

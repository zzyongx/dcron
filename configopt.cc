/* vim:expandtab:shiftwidth=4:tabstop=4:smarttab:
 */

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <configopt.h>

enum OptType { BOOLEAN, INTEGER, STRING, NIL };
struct Opt {
    const char *name;
    const char *lname;
    const char *desc;
    void *value;
    OptType type;
};

int   ConfigOpt::xwindow   = 30;
char *ConfigOpt::zookeeper = 0;
char *ConfigOpt::memcached = 0;
bool  ConfigOpt::xpriority = false;
char *ConfigOpt::outputf   = "/var/log/cronshell";
bool  ConfigOpt::logmore   = false;
char *ConfigOpt::logf      = 0;
bool  ConfigOpt::showhelp  = false;

struct Opt opts[] = {
    { "-h", "--help", "print this screen and exit",
        &ConfigOpt::showhelp,  BOOLEAN },

    { "-w", "--xwindow", "exclusive window, default 30s", 
        &ConfigOpt::xwindow,   INTEGER },

    { "-z", "--zookeeper", "use zookeeper as lock coordinator",
        &ConfigOpt::zookeeper, STRING },

    { "-m", "--memcached", "use memcached as lock coordinator",
        &ConfigOpt::memcached, STRING },

    { "-x", "--exclusive", "exclusive priority, if lock failed, give up",
        &ConfigOpt::xpriority, BOOLEAN },

    { "-2", "--logmore", "capture stderr to outputf",
        &ConfigOpt::logmore,   BOOLEAN },

    { "-o", "--outputf", "output file, default /var/log/cronshell",
        &ConfigOpt::outputf,   STRING },

    { "-l", "--logf", "log file, default stdout",
        &ConfigOpt::logf,      STRING },

    { "-c", "--command", "useless, crond will call SHELL -c", 0, NIL },
    { 0, 0, 0, 0, NIL },
};

const char *ConfigOpt::apply(const char *file)
{
    FILE *fp = fopen(file, "r");
    if (!fp) return "can't open conffile";

    char linebuf[256];
    while (fgets(linebuf, 256, fp)) {
        size_t n = strlen(linebuf);
        if (linebuf[n-1] == '\n') linebuf[n-1] = '\0';

        if (linebuf[0] == '\0' || linebuf[0] == ' '  ||
            linebuf[0] == '#'  || linebuf[0] == '\t') {
            continue;
        }

        char *key = linebuf;
        char *value = 0;

        char *sep = strchr(linebuf, '=');
        if (sep) {
            *sep = '\0';
            /* never free but who care */
            value = (char *) malloc(strlen(sep + 1));
            strcpy(value, sep + 1);
        }

        for (int i = 0; opts[i].name; ++i) {
            if (strcmp(opts[i].lname + 2, key) != 0) continue;
            switch (opts[i].type) {
            case NIL: break;
            case BOOLEAN:
                *((bool *) opts[i].value) = true;
                break;
            case INTEGER:
                if (!value) {
                    fclose(fp);
                    return "check option";
                }
                *((int *) opts[i].value) = atoi(value);
                break;
             case STRING:
                if (!value) {
                    fclose(fp);
                    return "check option";
                }
                *((char **) opts[i].value) = value;
                break;
            }
            break;
        }
    }

    fclose(fp);
    return 0;
}

const char *ConfigOpt::apply(int argc, char *argv[], int *cmdstart)
{
    int i, j;
    for (i = 1; i < argc; ++i) {
        for (j = 0; opts[j].name; ++j) {
            if (strcmp(opts[j].name, argv[i]) != 0) continue;
            switch (opts[j].type) {
            case NIL: break;
            case BOOLEAN:
                *((bool *) opts[j].value) = true;
                break;
            case INTEGER:
                if (i + 1 == argc) return "check option";
                *((int *) opts[j].value) = atoi(argv[++i]);
                break;
            case STRING:
                if (i + 1 == argc) return "check option";
                *((char **) opts[j].value) = argv[++i];
                break;
            }
            break;
        }

        if (!opts[j].name) { // if not found
            if (argv[i][0] == '-') return "unknow option";
            break;
        }
    }

    if (showhelp) return 0;
    if (i == argc) return "command not found";

#ifndef COO_MEMCACHED 
    if (memcached != 0) return "-m not support, compile with COOMEMCACHED support";
#endif

#ifndef COO_ZOOKEEPER
    if (zookeeper != 0) return "-z not support, compile with COOZOOKEEPER support";
#endif

    *cmdstart = i;
    return 0;
}

void ConfigOpt::help(const char *error)
{
    if (error) printf("ERROR %s\n", error);

    printf("cronshell option command\n");
    printf(" if you can not use option in command,\n");
    printf(" put them in /etc/cronshell.conf\n");

    for (int i = 0; opts[i].name; ++i) {
        printf("  %s %s\n", opts[i].name, opts[i].desc);
    }
}

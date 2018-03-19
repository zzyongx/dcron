#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <errno.h>
#include <sys/resource.h>

#include "logger.h"
#include "configopt.h"
#include "zkmgr.h"

LOGGER_INIT();

inline bool dump(const char *file, const std::string &content)
{
  FILE *fp = fopen(file, "w");
  if (!fp) return false;

  fwrite(content.c_str(), content.size(), 1, fp);
  fclose(fp);
  return true;
}

static bool which(const char *file, std::string *fullPath)
{
  fullPath->assign(file);
  if (access(fullPath->c_str(), X_OK) == 0) return true;

  const char *pathEnv = getenv("PATH");
  if (!pathEnv) return false;

  const char *colon = strchr(pathEnv, ':');
  while (colon) {
    fullPath->assign(pathEnv, colon - pathEnv).append(1, '/').append(file);
    if (access(fullPath->c_str(), X_OK) == 0) return true;
    pathEnv = colon + 1;
    colon = strchr(pathEnv, ':');
  }

  fullPath->assign(pathEnv).append(1, '/').append(file);
  if (access(fullPath->c_str(), X_OK) == 0) return true;
  return false;
}

inline bool setRlimitAs(int limit)
{
  if (limit < 500) limit = 500;

  struct rlimit rlmt;
  rlmt.rlim_cur = limit * 1024 * 1024;
  rlmt.rlim_max = limit * 1024 * 1024;

  return setrlimit(RLIMIT_AS, &rlmt) != -1;
}

int main(int argc, char *argv[])
{
  if (argc == 1) {
    fprintf(stderr, "usage: %s <command>\n", argv[0]);
    return EXIT_FAILURE;
  }

  std::string command;
  if (!which(argv[1], &command)) {
    fprintf(stderr, "command %s notfound", argv[1]);
    return EXIT_FAILURE;
  }
  argv[1] = (char *) command.c_str();

  char errbuf[1024];
  ConfigOpt *cnf = ConfigOpt::create(errbuf);
  if (!cnf) {
    fprintf(stderr, "config error %s\n", errbuf);
    return EXIT_FAILURE;
  }

  if (cnf->llap()) daemon(1, 1);

  if (cnf->rlimitAs() && !setRlimitAs(cnf->rlimitAs())) {
    fprintf(stderr, "%d:%s setrlimit(RLIMIT_AS) error", errno, strerror(errno));
    return EXIT_FAILURE;
  }

  if (!Logger::create(cnf->logdir() + "/dcron.log", Logger::DAY, true)) {
    fprintf(stderr, "%d:%s init logger error\n", errno, strerror(errno));
    return EXIT_FAILURE;
  }

  // redirect stderr to logger
  Logger::defLogger->bindStderr();

  ZkMgr *zkMgr = ZkMgr::create(cnf, errbuf);
  if (!zkMgr) {
    log_fatal(0, "%s create ZkMgr error, %s", cnf->name(), errbuf);
    return EXIT_FAILURE;
  }

  int status;
  do {
    log_info(0, "%s %s status %s", cnf->id(), cnf->name(), ZkMgr::statusToString(zkMgr->status()));

    if (zkMgr->status() == ZkMgr::MASTER) {
      status = zkMgr->exec(argc-1, argv+1);
      break;
    } else if (zkMgr->status() == ZkMgr::SLAVE) {
      zkMgr->suspend();
    } else if (zkMgr->status() == ZkMgr::OUT) {
      return EXIT_SUCCESS;
    } else {
      return EXIT_FAILURE;
    }
  } while (true);

  if (cnf->zkdump()) {
    sleep(1);   // wait negotiate timeout
    std::string json;
    if (zkMgr->dump(&json)) dump(cnf->zkdump(), json);
  }

  return status;
}

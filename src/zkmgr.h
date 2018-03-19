#ifndef _ZKMGR_H_
#define _ZKMGR_H_

#include <string>
#include <map>
#include <pthread.h>
#include <zookeeper/zookeeper.h>
#include "configopt.h"

class ZkMgr {
public:
  enum NodeStatus {MASTER, SLAVE, OUT, ZKOK, ZKAGAIN, ZKFATAL};
  enum ZkStatus { MASTER_GONE, SESSION_GONE, MASTER_WAIT, WORKER_SUSPEND };

  static ZkMgr *create(ConfigOpt *cnf, char *errbuf);
  static const char *statusToString(NodeStatus status);

  NodeStatus status() const { return status_; }
  int exec(int argc, char *argv[]);
  void suspend();
  bool dump(std::string *json) const;

private:
  bool createWorkDir(char *errbuf);
  NodeStatus competeMaster(bool first, char *errbuf);
  NodeStatus joinWorkers(bool master, char *errbuf);
  NodeStatus setWatch(char *errbuf);
  pid_t exec(int argc, char *argv[], const std::map<std::string, std::string> &env, int cnt);
  bool wait(pid_t pid, size_t cnt, bool *retry, int *exitStatus);
  void setStatus(int status);
  void setResult(int retry, int status, const char *error = 0);
  void rsyncFifoData();

  static void watchMasterNode(zhandle_t *, int type, int state, const char *path, void *watcherCtx);
  static void globalWatcher(zhandle_t *, int type, int state, const char *path, void *watcherCtx);

private:
  std::string taskPath_;
  std::string masterNode_;
  std::string workersNode_;
  std::string statusNode_;
  std::string resultNode_;
  std::string llapNode_;

  int fifoFd_;

  zhandle_t  *zh_;
  NodeStatus  status_;
  ConfigOpt  *cnf_;

  ZkStatus zkStatus_;
  pthread_mutex_t *mutex_;
  pthread_cond_t  *cond_;
};

#endif

#ifndef _CONFIGOPT_H_
#define _CONFIGOPT_H_

#include <string>

class ConfigOpt {
public:
  enum RetryStrategy { RETRY_ON_CRASH, RETRY_ON_ABEXIT, RETRY_NOTHING };
  static ConfigOpt *create(char *errbuf);

  const char *id() const { return id_.c_str(); }
  const char *name() const { return name_.c_str(); }
  const char *zkhost() const { return zkhost_.c_str(); }
  const char *fifo() const { return fifo_.c_str(); }

  const char *zkdump() const { return zkdump_.empty() ? 0 : zkdump_.c_str(); }
  bool tcrash() const { return tcrash_; }

  std::string logdir() const { return logdir_; }
  std::string libdir() const { return libdir_; }

  size_t maxRetry() const { return maxRetry_; }
  RetryStrategy retryStrategy() const { return retryStrategy_; }

  int stick() const { return stick_ > 0 ? stick_ : 0; }
  bool llap() const { return llap_; }
  bool captureStdio() const { return captureStdio_; }

  const char *user() const { return user_.c_str(); }
  int uid() const { return uid_; }
  int gid() const { return gid_; }

  int rlimitAs() const { return rlimitAs_; }

private:
  ConfigOpt() {}
  bool parseUser(const char *user, char *errbuf);

  std::string id_;
  std::string zkhost_;
  std::string name_;

  int maxRetry_;
  RetryStrategy retryStrategy_;

  bool llap_;
  int  stick_;
  bool captureStdio_;

  std::string user_;
  int uid_;
  int gid_;

  std::string libdir_;
  std::string logdir_;
  std::string fifo_;

  std::string zkdump_;
  bool tcrash_;

  int rlimitAs_;
};

#endif

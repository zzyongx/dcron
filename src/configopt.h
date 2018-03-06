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

  std::string logdir() const { return logdir_; }
  std::string libdir() const { return libdir_; }

  size_t maxRetry() const { return maxRetry_; }
  RetryStrategy retryStrategy() const { return retryStrategy_; }

  bool stick() const { return stick_; }
  bool llap() const { return llap_; }
  bool captureStdio() const { return captureStdio_; }

private:
  ConfigOpt() {}

  std::string id_;
  std::string zkhost_;
  std::string name_;

  int maxRetry_;
  RetryStrategy retryStrategy_;

  bool llap_;
  bool stick_;
  bool captureStdio_;

  int negotiateTimeout_;

  std::string libdir_;
  std::string logdir_;
  std::string fifo_;
  std::string zkdump_;
};

#endif

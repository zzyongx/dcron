/* vim:expandtab:shiftwidth=4:tabstop=4:smarttab:
 */

#ifndef _CONFIGOPT_H_
#define _CONFIGOPT_H_

class ConfigOpt {
public:
    static void help(const char *error = 0);
    static const char *apply(const char *conffile);
    static const char *apply(int argc, char *argv[], int *cmdstart);

    static int   xwindow;
    static char *zookeeper;
    static char *memcached;
    static bool  xpriority;
    static char *outputf;
    static bool  logmore;
    static char *logf;
    static bool  showhelp;

private:
    ~ConfigOpt() {}
};

#endif

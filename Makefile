# Makefile for systems with GNU tools
CC      = gcc
CXX     = g++
INSTALL = install
LDFLAGS = -lpthread
DEPSDIR = ".deps"
ARLIBS  = $(DEPSDIR)/libzookeeper_mt.a $(DEPSDIR)/libjsoncpp.a
WARN    = -Werror -Wall -Wshadow -Wextra -Wno-comment

ifeq ($(DEBUG), 1)
    CFLAGS += -O0 -g
else
    CFLAGS += -O2 -g
endif

ifndef ($(INSTALLDIR))
	INSTALLDIR = /usr/local
endif

VPATH = .:./libs
BUILDDIR = build

OBJS    = $(BUILDDIR)/configopt.o $(BUILDDIR)/zkmgr.o

default: configure dcron jsonpath
	@echo finished

dcron: $(BUILDDIR)/dcron.o $(OBJS)
	$(CXX) $(CFLAGS) -o $(BUILDDIR)/$@ $^ $(ARLIBS) $(LDFLAGS)

jsonpath: $(BUILDDIR)/jsonpath.o
	$(CXX) $(CFLAGS) -o $(BUILDDIR)/$@ $^ $(ARLIBS) $(LDFLAGS)

.PHONY: configure
configure:
	@mkdir -p $(BUILDDIR)
	@ls $(ARLIBS) &>/dev/null || (echo "make get-deps first"; exit 2)

.PHONY: get-deps
get-deps:
	@mkdir -p $(DEPSDIR)

	@echo "compile jsoncpp" && \
	  cd $(DEPSDIR) && \
    (test -f 0.10.4.tar.gz || wget https://github.com/open-source-parsers/jsoncpp/archive/0.10.4.tar.gz) && \
    rm -rf jsoncpp-0.10.4 && tar xzf 0.10.4.tar.gz &&   \
    mkdir -p jsoncpp-0.10.4/build && cd jsoncpp-0.10.4/build && \
    cmake -DCMAKE_BUILD_TYPE=debug -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF \
      -DARCHIVE_INSTALL_DIR=../.. -G "Unix Makefiles" .. && make install

	@echo "compile zookeeper" && \
    cd $(DEPSDIR) && \
    (test -f zookeeper-3.4.10.tar.gz || wget http://ftp.cuhk.edu.hk/pub/packages/apache.org/zookeeper/stable/zookeeper-3.4.10.tar.gz) && \
     rm -rf zookeeper-3.4.10 && tar xvf zookeeper-3.4.10.tar.gz && cd zookeeper-3.4.10/src/c && \
     ./configure && make && make install
	cp /usr/local/lib/libzookeeper_mt.a $(DEPSDIR)

$(BUILDDIR)/%.o: src/%.cc
	$(CXX) -o $@ $(WARN) $(CXXWARN) $(CFLAGS) $(PREDEF) -c $<

.PHONY: install
install:
	$(INSTALL) -D $(BUILDDIR)/dcron $(RPM_BUILD_ROOT)$(INSTALLDIR)/bin
	mkdir -p $(RPM_BUILD_ROOT)/var/lib/dcron
	mkdir -p $(RPM_BUILD_ROOT)/var/log/dcron

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)/*

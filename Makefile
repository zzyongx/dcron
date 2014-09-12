# Makefile for systems with GNU tools
CC      = gcc
CXX     = g++
INSTALL = install

CFLAGS  = -I.
PREDEF  = -D_FILE_OFFSET_BITS=64
CXXWARN = -Wno-invalid-offsetof
WARN    =
PREDEF  = 
LDFLAGS = -lcrypto

ifeq ($(DEBUG), 1)
    CFLAGS += -O0 -g
    WARN   += -Wall -Wextra -Wno-comment -Wformat -Wimplicit \
			  -Wparentheses -Wswitch -Wunused
else
    CFLAGS += -O2 -g
    WARN   += -Wall -Wextra -Wno-comment -Wformat -Wimplicit \
			  -Wparentheses -Wswitch -Wuninitialized -Wunused
endif

ifndef ($(INSTALLDIR))
	INSTALLDIR = /usr/local
endif

ifeq ($(COOMEMCACHED), 1)
    PREDEF  += -DCOO_MEMCACHED
    CFLAGS  += $(COOMEMCACHED_CFLAGS)
    LDFLAGS += $(COOMEMCACHED_LDFLAGS) -lmemcached
endif

ifeq ($(COOZOOKEEPER), 1)
    PREDEF  += -DCOO_ZOOKEEPER
    CFLAGS  += $(COOZOOKEEPER_CFLAGS)
    LDFLAGS += $(COOZOOKEEPER_LDFLAGS) -lzookeeper_mt
endif

VPATH = .:./libs

OBJS    = build/cronshell.o build/configopt.o

cronshell: configure $(OBJS)
	$(CXX) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

.PHONY: configure
configure:
	mkdir -p build

build/%.o:%.cc
	$(CXX) -o $@ $(WARN) $(CXXWARN) $(CFLAGS) $(PREDEF) -c $<

build/%.o:%.c
	$(CC) -o $@ $(WARN) $(CFLAGS) $(PREDEF) -c $<

.PHONY: install
install:
	$(INSTALL) -D cronshell $(DESTDIR)$(INSTALLDIR)/bin/cronshell
	test -f $(DESTDIR)/etc/cronshell.conf || \
		$(INSTALL) -D cronshell.conf $(DESTDIR)/etc/cronshell.conf

.PHONY: help
help:
	@echo "make [COOMEMCACHED=1] [COOZOOKEEPER=1]"
	@echo "default cronshell doesn't support coordinator"
	@echo "make with COOMEMCACHED=1 OR COOZOOKEEPER=1 to appoint use coordinator"
	@echo "COOMEMCACHED_CFLAGS and COOMEMCACHED_LDFLAGS append compile option"
	@echo "so is COOZOOKEEPER_CFLAGS and COOZOOKEEPER_LDFLAGS"

.PHONY: clean
clean:
	rm -rf ./smf_auto_config.h ./build/*

#!/bin/bash

BIN="${BASH_SOURCE[0]}"
BINDIR=$(readlink -e $(dirname $BIN))
DCRON=$BINDIR/../build/dcron
JPATH=$BINDIR/../build/jsonpath

test -f $BINDIR/../ENV.sh && source $BINDIR/../ENV.sh
DCRON_ZK=${DCRON_ZK:-127.0.0.1:2181}
DCRON_ZK=$DCRON_ZK/dcron
LIBDIR=/var/lib/dcron

ZKDUMP=$BINDIR/zkdump
export DCRON_ZKDUMP=$ZKDUMP
export DCRON_ZK=$DCRON_ZK

export DCRON_ID=node-a
export DCRON_NAME=blackbox.%Y%m%d_%H%M%S

echo "TEST DCRON_STICK"
export DCRON_STICK=5
$DCRON $BINDIR/dumb.sh exit0

test -f "$LIBDIR/blackbox.stick" || {
  echo "$LINNO stick file was not found"
  exit 1
}

sleep 2
$DCRON $BINDIR/dumb.sh stick

NODE=$(cat $ZKDUMP | $JPATH 'status.id')
test $NODE = 'node-a' || {
  echo "$LINENO status.id error"
  exit 1
}

STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = 0 || {
  echo "$LINENO status.status error"
  exit 1
}

echo "TEST DCRON_STICK expired"
sleep 6
$DCRON $BINDIR/dumb.sh stick

test $? = 1 || {
  echo "$LINENO exit status error"
  exit 1
}

STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = 1 || {
  echo "$LINENO status.status error"
  exit 1
}

echo "OK"

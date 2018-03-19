#!/bin/bash

BIN="${BASH_SOURCE[0]}"
BINDIR=$(readlink -e $(dirname $BIN))
DCRON=$BINDIR/../build/dcron
JPATH=$BINDIR/../build/jsonpath

test -f $BINDIR/../ENV.sh && source $BINDIR/../ENV.sh
DCRON_ZK=${DCRON_ZK:-127.0.0.1:2181}
DCRON_ZK=$DCRON_ZK/dcron

BLOCK_ZK="iptables -I OUTPUT -p tcp --dport 2181 -j REJECT --reject-with tcp-reset"
UNBLOCK_ZK="iptables -D OUTPUT -p tcp --dport 2181 -j REJECT --reject-with tcp-reset"

ZKDUMP=$BINDIR/zkdump
export DCRON_ZKDUMP=$ZKDUMP
export DCRON_ZK=$DCRON_ZK
export DCRON_RETRYON=ABEXIT
export DCRON_STICK=""

export DCRON_NAME=blackbox.%Y%m%d_%H%M%S
TASKID=$(date +%Y%m%d_%H%M%S)

rm -f $BINDIR/dumb
export DCRON_DUMB_RESULT=$BINDIR/dumb
$DCRON $BINDIR/dumb.sh sleep30 &

sleep 1
$BLOCK_ZK

sleep 20  # wait zk session timeout
$UNBLOCK_ZK

sleep 15 # wait dcron finish
test $(cat $BINDIR/dumb 2>/dev/null) = "ERROR" || {
  echo "$FILENO dumb should not run to completion"
  exit 1
}

#!/bin/bash

BIN="${BASH_SOURCE[0]}"
BINDIR=$(readlink -e $(dirname $BIN))
DCRON=$BINDIR/../build/dcron
JPATH=$BINDIR/../build/jsonpath

test -f $BINDIR/../ENV.sh && source $BINDIR/../ENV.sh
DCRON_ZK=${DCRON_ZK:-127.0.0.1:2181}
DCRON_ZK=$DCRON_ZK/dcron

ZKDUMP=$BINDIR/zkdump
export DCRON_ZKDUMP=$ZKDUMP
export DCRON_ZK=$DCRON_ZK

export DCRON_ID=node-a
export DCRON_NAME=hold.%Y%m%d_%H%M
TASKID=$(date +%Y%m%d_%H%M)

$DCRON touch $BINDIR/hold &

export DCRON_ID=node-b
$DCRON touch $BINDIR/hold

sleep 2 # negotiate timeout

NODE=$(cat $ZKDUMP | $JPATH 'llapNode')
test "$NODE" = "/hold/llap" || {
  echo "llapNode error $NODE"
  exit 1
}

NODE=$(cat $ZKDUMP | $JPATH 'statusNode')
test "$NODE" = "/hold/$TASKID/status" || {
  echo "statusNode error $NODE"
  exit 1
}

NODE=$(cat $ZKDUMP | $JPATH 'workersNode')
test "$NODE" = "/hold/$TASKID/workers" || {
  echo "workersNode error $NODE"
  exit 1
}

WORKERS=$(cat $ZKDUMP | $JPATH 'workers')
((echo $WORKERS | grep -q node-a) && (echo $WORKERS | grep -q node-b)) || {
  echo "workers error $WORKERS"
  exit 1
}

STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = '0' || {
  echo "status error $STATUS"
  exit 1
}
ID=$(cat $ZKDUMP | $JPATH 'status.id')
(test "$ID" = "node-a" || test "$ID" = "node-b") || {
  echo "status.id error $ID"
  exit 1
}

sleep 60   # particle size of cron is minutes
export DCRON_ID=node-a
$DCRON touch $BINDIR/ENOTDIR/hold

STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = 1 || {
  echo "$LINENO status error $status"
  exit 1
}

echo "OK"

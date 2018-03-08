#!/bin/bash

BIN="${BASH_SOURCE[0]}"
BINDIR=$(readlink -e $(dirname $BIN))
DCRON=$BINDIR/../build/dcron
JPATH=$BINDIR/../build/jsonpath
LOGDIR=/var/log/dcron
LIBDIR=/var/log/dcron

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

test ! -f $LOGDIR/$TASKID.stdout || {
  echo "empty stdout file should not exist"
  exit 1
}

test ! -f $LOGDIR/$TASKID.stderr || {
  echo "empty stderr file should not exist"
  exit 1
}

test ! -f $LIBDIR/$TASKID.fifo || {
  echo "fifo file should not exist"
  exit 1
}

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
  echo "$LINENO workers error $WORKERS"
  exit 1
}

STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = '0' || {
  echo "$LINENO status error $STATUS"
  exit 1
}
ID=$(cat $ZKDUMP | $JPATH 'status.id')
(test "$ID" = "node-a" || test "$ID" = "node-b") || {
  echo "$LINENO status.id error $ID"
  exit 1
}

sleep 60   # particle size of cron is minutes
export DCRON_RETRYON=ABEXIT
export DCRON_ID=node-a
$DCRON touch $BINDIR/ENOTDIR/hold

STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = 1 || {
  echo "$LINENO status error $status"
  exit 1
}

R1=$(cat $ZKDUMP | $JPATH 'result[1]')
R2=$(cat $ZKDUMP | $JPATH 'result[2]')
(test "$R1" != "" && test "$R2" == "") || {
  echo "$LINENO result length error"
  exit 1
}

STATUS=$(cat $ZKDUMP | $JPATH 'result[0].status')
test "$STATUS" = 1 || {
  echo "$LINENO result[0].status error"
  exit 1
}

sleep 60
$DCRON $BINDIR/dumb.sh fifo_set

IDX=0
for suffix in $(seq -f "%02g" 6 10); do
  jpath="llap[$IDX].k"
  VAL=$(cat $ZKDUMP | $JPATH "$jpath")
  test "$VAL" = "DUMB_${suffix}" || {
    echo "$LINENO $jpath error"
    exit 1
  }
  IDX=$((IDX+1))
done

sleep 60
$DCRON $BINDIR/dumb.sh fifo_get
STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = 0 || {
  echo "$LINENO status.status error"
  exit 1
}

sleep 60
export DCRON_USER="nobody:nobody"
$DCRON $BINDIR/dumb.sh setuid
STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
test "$STATUS" = 0 || {
  echo "$LINENO status.status error"
  exit 1
}

echo "OK"

#!/bin/bash

BIN="${BASH_SOURCE[0]}"
BINDIR=$(readlink -e $(dirname $BIN))
DCRON=$BINDIR/../build/dcron
JPATH=$BINDIR/../build/jsonpath
LOGDIR=/var/log/dcron
LIBDIR=/var/lib/dcron

test -f $BINDIR/../ENV.sh && source $BINDIR/../ENV.sh
DCRON_ZK=${DCRON_ZK:-127.0.0.1:2181}
DCRON_ZK=$DCRON_ZK/dcron

ZKDUMP=$BINDIR/zkdump
export DCRON_ZKDUMP=$ZKDUMP
export DCRON_ZK=$DCRON_ZK
export DCRON_RETRYON=ABEXIT
export DCRON_STICK=""

export DCRON_NAME=blackbox.%Y%m%d_%H%M%S
TASKID=$(date +%Y%m%d_%H%M%S)

test_exit0()
{
  export DCRON_ID=node-a
  $DCRON $BINDIR/dumb.sh exit0 &

  export DCRON_ID=node-b
  $DCRON $BINDIR/dumb.sh exit0

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
  test "$NODE" = "/blackbox/llap" || {
    echo "llapNode error $NODE"
    exit 1
  }

  NODE=$(cat $ZKDUMP | $JPATH 'statusNode')
  test "$NODE" = "/blackbox/$TASKID/status" || {
    echo "statusNode error $NODE"
    exit 1
  }

  NODE=$(cat $ZKDUMP | $JPATH 'workersNode')
  test "$NODE" = "/blackbox/$TASKID/workers" || {
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
}

test_abexit()
{
  export DCRON_ID=node-a
  $DCRON $BINDIR/dumb.sh abexit

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
}

test_fifo()
{
  export DCRON_ID=node-a
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

  sleep 2
  $DCRON $BINDIR/dumb.sh fifo_get
  STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
  test "$STATUS" = 0 || {
    echo "$LINENO status.status error"
    exit 1
  }
}

test_user()
{
  export DCRON_USER="nobody:nobody"
  export DCRON_ID=node-a
  $DCRON $BINDIR/dumb.sh setuid

  STATUS=$(cat $ZKDUMP | $JPATH 'status.status')
  test "$STATUS" = 0 || {
    echo "$LINENO status.status error"
    exit 1
  }
}

test_crash()
{
  local save_retryon=$DCRON_RETRYON
  rm -f $LIBDIR/blacktest.stick

  export DCRON_RETRYON=CRASH
  export DCRON_TEST_CRASH=1
  export DCRON_ID=node-a
  $DCRON $BINDIR/dumb.sh &

  export DCRON_TEST_CRASH=0
  export DCRON_ID=node-b
  $DCRON $BINDIR/dumb.sh

  local status=$(cat $ZKDUMP | $JPATH 'status.status')
  test "$status" = 0 || {
    echo "$LINENO status.status error"
    exit 1
  }

  local node=$(cat $ZKDUMP | $JPATH 'workers[0]')
  test "$node" = "node-a" || {
    echo "$LINENO workers[0] error"
    exit 1
  }

  node=$(cat $ZKDUMP | $JPATH 'status.id')
  local nodeb=$(cat $ZKDUMP | $JPATH 'workers[1]')
  test "$node" = "$nodeb" || {
    echo "$LINENO status.id error"
    exit 1
  }

  export DCRON_RETRYON=$save_retryon
}

test_rlimit_as()
{
  export DCRON_RLIMIT_AS=600
  export DCRON_MAXRETRY=1

  $DCRON $BINDIR/dumb.sh exit0
  test $? = 0 || {
    echo "$LINENO status error"
    exit 1
  }

  sleep 1
  $DCRON $BINDIR/dumb.sh limitas
  test $? != 0 || {
    echo "$LINENO status error"
    exit 1
  }

  export DCRON_RLIMIT_AS=""
  export DCRON_MAXRETRY=""
}

test_stick()
{
  export DCRON_STICK=5
  export DCRON_ID=node-a
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

  export DCRON_STICK=""
}

echo "TEST DCRON exit0"
test_exit0

echo "TEST DCRON_ABEXIT"
sleep 2
test_abexit

echo "TEST DCRON crash"
sleep 2
test_crash

echo "TEST fifo"
sleep 2
test_fifo

echo "TEST DCRON_USER"
sleep 2
test_user

echo "TEST DCRON_STICK"
sleep 2
test_stick

echo "TEST DCRON_RLIMIT_AS"
sleep 2
test_rlimit_as

echo "OK"

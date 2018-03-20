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
$UNBLOCK_ZK 2>/dev/null

ZKDUMP=$BINDIR/zkdump
export DCRON_ZKDUMP=$ZKDUMP
export DCRON_ZK=$DCRON_ZK
export DCRON_RETRYON=ABEXIT
export DCRON_STICK=""

export DCRON_NAME=blackbox.%Y%m%d_%H%M%S
TASKID=$(date +%Y%m%d_%H%M%S)

test_kill_process_when_session_timeout()
{
  rm -f $BINDIR/dumb
  export DCRON_DUMB_RESULT=$BINDIR/dumb
  $DCRON $BINDIR/dumb.sh sleep30 &

  sleep 1
  $BLOCK_ZK

  sleep 20  # wait zk session timeout
  $UNBLOCK_ZK

  sleep 15 # wait dcron finish
  test $(cat $BINDIR/dumb 2>/dev/null) = "ERROR" || {
    echo "$LINENO dumb should not run to completion"
    exit 1
  }

  unset DCRON_DUMB_RESULT
}

test_start_when_zk_down()
{
  rm -f $ZKDUMP
  $BLOCK_ZK
  $DCRON $BINDIR/dumb.sh exit0 &

  usleep 300000
  $UNBLOCK_ZK
  wait # wait

  STATUS=$(cat $ZKDUMP 2>/dev/null | $JPATH 'status.status')
  test "$STATUS" = 0 || {
    echo "$LINENO status error $STATUS"
    exit 1
  }
}

test_zconnectionloss_when_compete_master_success()
{
  rm -f $ZKDUMP
  DCRON_TEST_CONNECTIONLOSS_WHEN_COMPETE_MASTER_SUCCESS=true $DCRON $BINDIR/dumb.sh exit0

  STATUS=$(cat $ZKDUMP 2>/dev/null | $JPATH 'status.status')
  test "$STATUS" = 0 || {
    echo "$LINENO status error $STATUS"
    exit 1
  }
}

test_zconnectionloss_when_compete_master_failure()
{
  rm -f $ZKDUMP
  DCRON_TEST_CONNECTIONLOSS_WHEN_COMPETE_MASTER_FAILURE=true $DCRON $BINDIR/dumb.sh exit0

  STATUS=$(cat $ZKDUMP 2>/dev/null | $JPATH 'status.status')
  test "$STATUS" = 0 || {
    echo "$LINENO status error $STATUS"
    exit 1
  }
}

test "$TESTCASE" != "" && {
  $TESTCASE
  exit 0
}

echo "TEST SESSION TIMEOUT"
test_kill_process_when_session_timeout
sleep 2

echo "TEST ZCONNECTIONLOSS"
test_start_when_zk_down
sleep 2

echo "TEST ZCONNECTIONLOSS WHEN COMPETE MASTER SUCCESS"
test_zconnectionloss_when_compete_master_success
sleep 2

echo "TEST ZCONNECTIONLOSS WHEN COMPETE MASTER FAILURE"
test_zconnectionloss_when_compete_master_failure

echo "OK"

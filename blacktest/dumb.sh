#!/bin/bash

test_fifo_get_impl()
{
  local name="$1"
  local actval="$2"
  local expval="$3"

  test "$actval" = "$expval" || {
    echo "$name expect $expval, got $actval"
    exit 1
  }
}

test_fifo_get()
{
  test_fifo_get_impl "DCRON_DUMB_03" "$DCRON_DUMB_03" ""

  test_fifo_get_impl "DCRON_DUMB_06" "$DCRON_DUMB_06" "06"
  test_fifo_get_impl "DCRON_DUMB_07" "$DCRON_DUMB_07" "07"
  test_fifo_get_impl "DCRON_DUMB_08" "$DCRON_DUMB_08" "08"
  test_fifo_get_impl "DCRON_DUMB_09" "$DCRON_DUMB_09" "09"
  test_fifo_get_impl "DCRON_DUMB_10" "$DCRON_DUMB_10" "10"
}

test_fifo_set()
{
  for i in $(seq -f "%02g" 1 10); do
    echo "DUMB_${i}=$i" > $DCRON_FIFO
  done
}

test_setuid()
{
  local user=$(id -n -u)
  local group=$(id -n -g)

  (test "$user" = "nobody" && test "$group" = "nobody") || {
    echo "user expects nobody, got $user. group expects nobody, got $group"
    exit 1
  }

  echo "DUMB_01=01" > $DCRON_FIFO
  if [ $? != 0 ]; then
    echo "fifo can not be written after setuid"
    exit 1
  fi
}

test_stick()
{
  test "$DCRON_TEST_STICK" = "node-a" || {
    echo "stick expect node-a, get $DCRON_TEST_STICK"
    exit 1
  }
}

test_abexit()
{
  exit 1
}

test_exit0()
{
  exit 0
}

cmd=${1:null}

case $cmd in
  "fifo_set" ) test_fifo_set ;;
  "fifo_get" ) test_fifo_get ;;
  "setuid" )   test_setuid ;;
  "stick" )    test_stick ;;
  "abexit" )   test_abexit ;;
  "exit0" )    test_exit0 ;;
esac

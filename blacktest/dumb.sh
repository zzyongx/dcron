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
    echo "DUMB_${i}=$i" >> $DCRON_FIFO
  done
}

cmd=${1:null}

case $cmd in
  "fifo_set" ) test_fifo_set ;;
  "fifo_get" ) test_fifo_get ;;
esac

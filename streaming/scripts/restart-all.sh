#!/bin/bash

killall -TERM oggfwd
sleep 1
killall -9 oggfwd
sleep 1

for i in ice_cast_*.sh; do
	./$i > /dev/null 2>&1 &
done

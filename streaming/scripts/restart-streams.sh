#!/bin/bash

./kill-streams.sh
./manage-streams.pl > /dev/null 2>&1 &

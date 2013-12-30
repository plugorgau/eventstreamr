#!/bin/bash

chromium-browser -incognito http://localhost:8000/app/launch.html &
sleep 3
wmctrl -r "AV Status" -b add,above

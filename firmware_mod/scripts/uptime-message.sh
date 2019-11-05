#!/bin/sh

SLEEP_TIME=60

while true; do
  	debug_msg "Sendinding uptime message"
		/system/sdcard/bin/telegram m "$(uptime)"
  sleep ${SLEEP_TIME}
done;
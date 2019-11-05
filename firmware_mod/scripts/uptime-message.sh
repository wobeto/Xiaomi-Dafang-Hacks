#!/bin/sh

. /system/sdcard/config/uptime-message.conf

while true; do
  debug_msg "Sendinding uptime message"
	/system/sdcard/bin/telegram m "$(uptime)"
  sleep ${MESSAGE_INTERVAL}
done;
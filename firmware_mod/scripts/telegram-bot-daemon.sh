#!/bin/sh
. /system/sdcard/scripts/common_functions.sh

CURL="/system/sdcard/bin/curl"
LASTUPDATEFILE="/tmp/last_update_id"
TELEGRAM="/system/sdcard/bin/telegram"
JQ="/system/sdcard/bin/jq"
AUDIOPLAY="/system/sdcard/bin/audioplay"

HELP_STR="######### Bot commands #########\n\
# /mem - show memory information\n\
# /shot - take a shot\n\
# /detectionon - motion detect on\n\
# /detectionoff - motion detect off\n\
# /textalerts - Text alerts on motion detection\n\
# /imagealerts - Image alerts on motion detection\n\
# /videoalerts - Video alerts on motion detection\n\
# /sensitivity # - Set motion detection sensitivity (0-4)\n\
# /status - motion detect status\n\
# /sound - play dog sound\n\
# /motorup\n\
# /motordown\n\
# /motorleft\n\
# /motorright\n\
# /motorcalibrate\n\
# /reboot - reboot"

. /system/sdcard/config/telegram.conf
[ -z $apiToken ] && echo "api token not configured yet" && exit 1
[ -z $userChatId ] && echo "chat id not configured yet" && exit 1

sendShot() {
  /system/sdcard/bin/getimage > "/tmp/telegram_image.jpg" &&\
  $TELEGRAM p "/tmp/telegram_image.jpg"
  rm "/tmp/telegram_image.jpg"
}

motorUp() {
  motor up 100
}

motorDown() {
  motor down 100
}

motorLeft() {
  motor left 100
}

motorRight() {
  motor right 100
}

motorCalibrate() {
  motor reset_pos_count
}

sendStatus() {
  $TELEGRAM m "Motion status = $(motion_detection status)"
}
sendMem() {
  $TELEGRAM m $(free -k | awk '/^Mem/ {print "Mem: used "$3" free "$4} /^Swap/ {print "Swap: used "$3}')
}

detectionOn() {
  motion_detection on && $TELEGRAM m "Motion detection started"
}

detectionOff() {
  motion_detection off && $TELEGRAM m "Motion detection stopped"
}

textAlerts() {
  rewrite_config /system/sdcard/config/telegram.conf telegram_alert_type "text"
  $TELEGRAM m "Text alerts on motion detection"
}

imageAlerts() {
  rewrite_config /system/sdcard/config/telegram.conf telegram_alert_type "image"
  $TELEGRAM m "Image alerts on motion detection"
}

videoAlerts() {
  rewrite_config /system/sdcard/config/telegram.conf telegram_alert_type "video"
  $TELEGRAM m "Video alerts on motion detection"
}

motionSensitivity() {
  $TELEGRAM m "Setting motion sensitivity to: $1"
  rewrite_config /system/sdcard/config/motion.conf motion_sensitivity "$1"
  /system/sdcard/bin/setconf -k m -v $1
}

playSound() {
  $AUDIOPLAY /system/sdcard/media/dog.wav 100 &
}

reboot() {
  $TELEGRAM m "Rebooting in 60 seconds..."
  /sbin/reboot -d 60 &
}

update() {
  $TELEGRAM m "Starting update process. It will take several minutes before it is\
  completed and you won't be notified when it ends. When it ends the camera will reboot."
  /system/sdcard/bin/busybox nohup /system/sdcard/autoupdate.sh -v -f
}

respond() {
#  log "respond"
#  log "respond to: $chatId"
  case $1 in
    /mem) sendMem;;
    /shot) sendShot;;
    /detectionon) detectionOn;;
    /detectionoff) detectionOff;;
    /textalerts) textAlerts;;
    /imagealerts) imageAlerts;;
    /videoalerts) videoAlerts;;
    /sensitivity) motionSensitivity $2;;
    /reboot) reboot;;
    /motorup) motorUp;;
    /motordown) motorDown;;
    /motorleft) motorLeft;;
    /motorright) motorRight;;
    /motorcalibrate) motorCalibrate;;
    /sound) playSound;;
    /status) sendStatus;;
    /update) update;;
    /help) $TELEGRAM m $HELP_STR;;
    *) $TELEGRAM m "I can't respond to '$1' command"
  esac
}

readNext() {
  lastUpdateId=$(cat $LASTUPDATEFILE || echo "0")
  json=$($CURL -s -X GET "https://api.telegram.org/bot$apiToken/getUpdates?offset=$lastUpdateId&limit=1&allowed_updates=message")
  echo $json
}

markAsRead() {
  nextId=$(($1 + 1))
  echo "$nextId" > $LASTUPDATEFILE
}

main() {
  json=$(readNext)

  [ -z "$json" ] && return 0
  if [ "$(echo "$json" | $JQ -r '.ok')" != "true" ]; then
    echo "$(date '+%F %T') Bot error: $json" >> /tmp/telegram.log
    [ "$(echo "$json" | $JQ -r '.error_code')" == "401" ] && return 1
    return 0
  fi;

  chatId=$(echo "$json" | $JQ -r '.result[0].message.chat.id // ""')
  [ -z "$chatId" ] && return 0 # no new messages

  cmd=$(echo "$json" | $JQ -r '.result[0].message.text // ""')
  updateId=$(echo "$json" | $JQ -r '.result[0].update_id // ""')

  if [ "$chatId" != "$userChatId" ]; then
    username=$(echo "$json" | $JQ -r '.result[0].message.from.username // ""')
    firstName=$(echo "$json" | $JQ -r '.result[0].message.from.first_name // ""')
    $TELEGRAM m "Received message from not authrized chat: $chatId\nUser: $username($firstName)\nMessage: $cmd"
  else
    respond $cmd
  fi;

### Replace if above with text below to accept multiple chatids.
### They must be configured in telegram.conf like this (replace values): userChatId=("123456789" "-987654111") 
#  . /wobeto/imports.sh
#  containsElement "$chatId" "${userChatId[@]}"
#  local result=$?
#  log $result
#  if [ $result -ne 1 ]; then
#    username=$(echo "$json" | $JQ -r '.result[0].message.from.username // ""')
#    firstName=$(echo "$json" | $JQ -r '.result[0].message.from.first_name // ""')
#    $TELEGRAM m $chatId "Received message from not authrized chat: $chatId\nUser: $username($firstName)\nMessage: $cmd"
#  else
#    log "Responding $cmd"
#    respond $cmd
#  fi;

  markAsRead $updateId
}

while true; do
  main >/dev/null 2>&1
  [ $? -gt 0 ] && exit 1
  sleep 1
done;

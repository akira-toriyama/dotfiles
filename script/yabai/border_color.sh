#!/usr/bin/env sh

readonly ARRAY=("0xFFFFFF00" "0xFFFF00FF" "0xFF00FFFF" "0x00FFFFFF" "0xF0F0F0FF" "0xF0F0FFF0")

while true
do
  borders active_color=${ARRAY[$(($RANDOM % ${#ARRAY[*]}))]} width=4.0 &
  sleep 0.1
done

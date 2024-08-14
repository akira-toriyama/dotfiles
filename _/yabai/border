#!/usr/bin/env sh

readonly ARRAY=("0xFFFFFF00" "0xFFFF00FF" "0xFF00FFFF" "0x00FFFFFF" "0xF0F0F0FF" "0xF0F0FFF0")

options=(
  ax_focus=on
	width=6
)

while true
do
  borders "${options[@]}" active_color=${ARRAY[$(($RANDOM % ${#ARRAY[*]}))]} 2>/dev/null 1>&2 &
  sleep 0.2
done

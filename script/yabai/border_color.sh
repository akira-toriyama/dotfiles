#!/bin/sh

a=("0xFFFFFF00" "0xFFFF00FF" "0xFF00FFFF" "0x00FFFFFF" "0xF0F0F0FF" "0xF0F0FFF0")

while true
do
  sleep 0.1
  yabai -m config active_window_border_color $(shuf -n1 -e "${a[@]}")
done

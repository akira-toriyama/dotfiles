#!/bin/sh

a=("0xFFFFFF00" "0xFFFF00FF" "0xFF00FFFF" "0x00FFFFFF" "0xF0F0F0FF" "0xF0F0FFF0")

yabai -m config window_border_width 4

while true
do
  yabai -m config active_window_border_color $(shuf -n1 -e "${a[@]}")
  sleep 0.01
done


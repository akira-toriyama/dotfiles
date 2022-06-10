#!/bin/sh

a=("0xFFFFFF00" "0xFFFF00FF" "0xFF00FFFF" "0x00FFFFFF" "0xF0F0F0FF" "0xF0F0FFF0")

sleep 10s
# yabai -m window --move rel:0:0 
# yabai -m window --move rel:5:5
# yabai -m window --move rel:-5:-5
yabai -m config active_window_border_color $(shuf -n1 -e "${a[@]}")
yabai -m config window_border_width 40
yabai -m config window_border_width 2

sleep 10s
# yabai -m window --move rel:0:0 
# yabai -m window --move rel:5:5
# yabai -m window --move rel:-5:-5
yabai -m config active_window_border_color $(shuf -n1 -e "${a[@]}")
yabai -m config window_border_width 40
yabai -m config window_border_width 2

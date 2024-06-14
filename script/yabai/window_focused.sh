#!/usr/bin/env sh

yabai -m window --resize top:0:2
yabai -m window --resize bottom:0:-2
# yabai -m window --resize right:-2:0
# yabai -m window --resize left:2:0

sleep 0.02

yabai -m window --resize top:0:-2
yabai -m window --resize bottom:0:2
# yabai -m window --resize right:2:0
# yabai -m window --resize left:-2:0

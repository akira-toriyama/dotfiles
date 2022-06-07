#!/bin/sh

yabai -m window --move rel:0:0 &
wait
sleep 0s &
wait

yabai -m window --move rel:4:4 &
wait
sleep 300s &
wait

yabai -m window --move rel:-4:-4

#!/bin/sh

sleep 0.03 &
wait $!

yabai -m window --move rel:10:5 &
wait $!
sleep 0.03 &
wait $!

yabai -m window --move rel:-10:-5 &
wait $!
sleep 0.03 &
wait $!


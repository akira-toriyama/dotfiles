#!/bin/sh

yabai -m window --move rel:30:30 &
wait

yabai -m window --move rel:-30:-30 & 
wait

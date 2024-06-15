#!/usr/bin/env sh

borders active_color='gradient(top_left=0xaaffa100,bottom_right=0xaaaa0033)' \
        ax_focus=on \
        width=6 \
        order=above \
        background_color=0x00000000 \
        2>/dev/null 1>&2 &

sleep 0.07
borders active_color='glow(0xffff5100)' 2>/dev/null 1>&2 &
sleep 0.07
borders active_color='glow(0xffff5100)' 2>/dev/null 1>&2 &
sleep 0.07
borders active_color='glow(0xffff0000)' 2>/dev/null 1>&2 &
sleep 0.07
borders active_color='glow(0xffff5100)' 2>/dev/null 1>&2 &
sleep 0.07
borders active_color='gradient(top_left=0xffffa100,bottom_right=0xffaa0033)' 2>/dev/null 1>&2 &

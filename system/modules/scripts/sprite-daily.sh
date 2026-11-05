#!/bin/bash
# The morning run of the Prospector Dongle's sprite swap and, after it, the
# Cyboard Imprint's key LEDs painted in that sprite's colours (canon t-0967)
# and drawing the effect of the day (canon t-2d9r).
# launchd (sprite-sender.nix) runs it as
#   sprite-daily.sh <profile bin> <sender.json>
# where <profile bin> holds the sprite-sender and canon-dongle wrappers of
# home/modules/packages.nix (launchd's PATH lacks the home-manager profile)
# and <sender.json> is the sprite sender's config, in dotfiles-private.
#
# Four stages, each the gate of the next, so that a day whose swap failed
# changes nothing and the keys keep matching the dongle's screen:
#   1 `sprite-sender daily`    swaps the sprite (exit 1: no device in range,
#                              no clone of the collection, a refused GIF; the
#                              day is skipped, no retry)
#   2 `sprite-sender colours`  the five colours the GIF now on the screen
#                              shows most: the heaviest lively one first,
#                              the rest heaviest first
#   3 `canon-dongle palette`   hands them to the Imprint Dongle as slots 0..4;
#                              --wait 600 covers a KVM switch that hides the
#                              dongle for a while (longer: exit 1, the day is
#                              skipped, the keys keep yesterday's colours)
#   4 `canon-dongle effect --daily`  picks the press effect of the day, one
#                              of canon's eight in turn by the date, in the
#                              palette's colours (dongle.py's DAILY_EFFECTS:
#                              a new effect joins the round in canon, nothing
#                              changes here); the same --wait, though the
#                              dongle just answered (exit 1: the keys keep
#                              yesterday's effect with today's colours)
# The exit status is the failed stage's. launchd appends everything to
# ~/Library/Logs/sprite-sender.log (sprite-sender.nix), where the dongle's
# `palette ok` and `effect ok` lines are the day's evidence; the colours stay
# there and in no repository (they name the sprite, canon CLAUDE.md's privacy
# rule).
set -euo pipefail

bin="$1"
config="$2"

"$bin/sprite-sender" daily --config "$config"
line="$("$bin/sprite-sender" colours --config "$config")"
read -ra colours <<<"$line"
"$bin/canon-dongle" palette --wait 600 "${colours[@]}"
exec "$bin/canon-dongle" effect --wait 600 --daily

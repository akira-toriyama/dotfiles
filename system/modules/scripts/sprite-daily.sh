#!/bin/bash
# The morning run of the Prospector Dongle's sprite swap and, after it, the
# Cyboard Imprint's key LEDs painted in that sprite's colours (canon t-0967).
# launchd (sprite-sender.nix) runs it as
#   sprite-daily.sh <profile bin> <sender.json>
# where <profile bin> holds the sprite-sender and canon-dongle wrappers of
# home/modules/packages.nix (launchd's PATH lacks the home-manager profile)
# and <sender.json> is the sprite sender's config, off every repository.
#
# Three stages, each the gate of the next, so that a day whose swap failed
# changes nothing and the keys keep matching the dongle's screen:
#   1 `sprite-sender daily`    swaps the sprite (exit 1: no device in range,
#                              the drive not mounted, a refused GIF; the day
#                              is skipped, no retry)
#   2 `sprite-sender colours`  the five colours the GIF now on the screen
#                              shows most, liveliest first
#   3 `canon-dongle palette`   hands them to the Imprint Dongle as slots 0..4;
#                              --wait 600 covers a KVM switch that hides the
#                              dongle for a while (longer: exit 1, the day is
#                              skipped, the keys keep yesterday's colours)
# The exit status is the failed stage's. launchd appends everything to
# /tmp/sprite-sender.log, where the dongle's `palette ok` line is the day's
# evidence; the colours stay there and in no repository (they name the
# sprite, canon CLAUDE.md's privacy rule).
set -euo pipefail

bin="$1"
config="$2"

"$bin/sprite-sender" daily --config "$config"
line="$("$bin/sprite-sender" colours --config "$config")"
read -ra colours <<<"$line"
exec "$bin/canon-dongle" palette --wait 600 "${colours[@]}"

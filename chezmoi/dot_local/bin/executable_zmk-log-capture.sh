#!/bin/bash
# 24/7 serial capture for the ZMK BLE HID Host dongle (launchd: org.nixos.zmk-log,
# declared in system/modules/zmk-log.nix; retire when the dongle is stable — t-x0ak).
# Resolves the dongle by USB product name "BLE HID Host" via ioreg (follows re-plug),
# timestamps each line with "%F %T", appends to ~/zmk-logs/zmk-YYYY-MM-DD.log
# (daily rotation via the dated filename), prunes logs older than RETAIN_DAYS.
# Spec: projects t-6cdr body.
#
# set -u only, no errexit: grep の不一致や ioreg の一時失敗といった
# 正常系の非 0 で落ちてはいけない（docs/scripts-inventory.md の分類 ①）。
set -u

LOGDIR="$HOME/zmk-logs"
RETAIN_DAYS=120
PRODUCT="BLE HID Host"

mkdir -p "$LOGDIR"

find_dev() {
  # locationID (decimal) of the USB device -> hex prefix -> /dev/cu.usbmodem<prefix>*
  local loc prefix
  loc=$(ioreg -p IOUSB -l -w0 | grep -A20 "\"USB Product Name\" = \"$PRODUCT\"" |
    grep -m1 '"locationID"' | grep -oE '[0-9]+$')
  [ -n "$loc" ] || return 1
  prefix=$(printf '%x' "$loc" | sed 's/0*$//')
  local devs=("/dev/cu.usbmodem${prefix}"*)
  [ -e "${devs[0]}" ] || return 1
  echo "${devs[0]}"
}

prune() {
  find "$LOGDIR" -name 'zmk-*.log' -mtime +"$RETAIN_DAYS" -delete 2>/dev/null
}

echo "$(date '+%F %T') capture: starting (product=\"$PRODUCT\")" >&2

while :; do
  prune
  DEV=$(find_dev)
  if [ -z "$DEV" ]; then
    sleep 5
    continue
  fi
  echo "$(date '+%F %T') capture: attached $DEV" >&2
  # cat ends on USB re-enumeration (I/O error) -> loop re-resolves the device.
  cat "$DEV" 2>/dev/null | while IFS= read -r line; do
    printf '%s %s\n' "$(date '+%F %T')" "$line" >>"$LOGDIR/zmk-$(date +%F).log"
  done
  echo "$(date '+%F %T') capture: detached $DEV" >&2
  sleep 2
done

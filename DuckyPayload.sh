#!/bin/bash

HID_DEV="/dev/hidg0"
HID_HELPER="/usr/local/bin/hid-keypress"
YOUTUBE_URL="https://www.youtube.com/@josiahgold3n?sub_confirmation=1"

log() {
  echo "[duckypayload-win] $1"
}

wait_for_hid_device() {
  log "Waiting for $HID_DEV to appear..."
  for i in {1..20}; do
    if [ -e "$HID_DEV" ]; then
      log "$HID_DEV found."
      return 0
    fi
    sleep 1
  done
  log "HID device not found, exiting."
  return 1
}

send_with_retry() {
  local msg="$1"
  for attempt in {1..5}; do
    log "Sending: '$msg' (attempt $attempt)"
    "$HID_HELPER" "$msg"
    rc=$?
    if [ $rc -eq 0 ]; then
      log "Success."
      return 0
    fi
    log "Failed (rc=$rc), retrying..."
    sleep 1
  done
  log "Failed all attempts for: $msg"
  return 1
}

open_on_windows() {
  # Open Run dialog
  send_with_retry "<GUI+r>"
  sleep 0.6

  # Clear any junk in the Run box
  send_with_retry "<CTRL+a>"
  sleep 0.1
  send_with_retry "<BACKSPACE>"
  sleep 0.1

  # Type your URL
  send_with_retry "$YOUTUBE_URL"
  sleep 0.3

  # Press Enter
  send_with_retry "<ENTER>"
}

wait_for_hid_device || exit 0

log "Sleeping 5s for Windows to enumerate keyboard..."
sleep 5

log "Firing Windows payload..."
open_on_windows

log "Payload complete."
exit 0

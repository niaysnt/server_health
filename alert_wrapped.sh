#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="$HOME/server_health/logs"
ALERT_LOG="LOG_DIR/alerts.log"
SCRIPT="$HOME/server_health/helth_checker.sh"

mkdir -p "$LOG_DIR"

if "$SCRIPT"; then
   exist 0
 else
   TS="$(date +'%F %T')"
   echo "[$TS] ALERT: Threshold exceeded (see latest CSV row)" >> "$ALERT_LOG"
   exit 1
fi

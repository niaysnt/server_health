#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="$HOME/server_health/logs"
ALERT_LOG="$LOG_DIR/alerts.logs"
SCRIPT="$HOME/server_health/health_checker.sh"

mkdir -p "$LOG_DIR"

if "$SCRIPT"; then
  exit 0
else
  TS="$(date +'%F %T')"
  echo "[$TS} ALERT: Threshold exceeded (see latest CSV row)" >> "$ALERT_LOG"
  exit 1
fi

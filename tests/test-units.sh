#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
service="$ROOT_DIR/server-maintenance.service"
timer="$ROOT_DIR/server-maintenance.timer"

grep -Fxq 'ExecStart=/usr/local/sbin/server-maintenance' "$service"
grep -Fxq 'TimeoutStartSec=30min' "$service"
grep -Fxq 'Nice=10' "$service"
grep -Fxq 'IOSchedulingClass=idle' "$service"
grep -Fxq 'OnCalendar=Sun *-*-* 04:00:00' "$timer"
grep -Fxq 'Persistent=true' "$timer"
grep -Fxq 'RandomizedDelaySec=15m' "$timer"
grep -Fxq 'AccuracySec=1m' "$timer"

#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo 'run install.sh as root' >&2
  exit 1
fi

source_dir=$(cd "$(dirname "$0")" && pwd)

install -Dm755 "$source_dir/server-maintenance" /usr/local/sbin/server-maintenance
install -Dm644 "$source_dir/server-maintenance.service" /etc/systemd/system/server-maintenance.service
install -Dm644 "$source_dir/server-maintenance.timer" /etc/systemd/system/server-maintenance.timer
systemctl daemon-reload
systemctl enable --now server-maintenance.timer

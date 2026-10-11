#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT_DIR/server-maintenance"
PASS=0
FAIL=0

report() {
  local name=$1
  shift
  if "$@"; then
    printf 'PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL: %s\n' "$name" >&2
    FAIL=$((FAIL + 1))
  fi
}

test_invalid_argument() (
  source "$SCRIPT"
  main --unknown >/dev/null 2>&1
  [[ $? -eq 2 ]]
)

test_dry_run_is_non_mutating() (
  local work
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  CALL_LOG="$work/calls"
  : >"$CALL_LOG"

  source "$SCRIPT"
  available_bytes() { printf '1000000\n'; }
  acquire_lock() { return 0; }
  paccache() { printf 'paccache %s\n' "$*" >>"$CALL_LOG"; }
  docker() { printf 'docker %s\n' "$*" >>"$CALL_LOG"; }
  journalctl() { printf 'journalctl %s\n' "$*" >>"$CALL_LOG"; }
  numfmt() { printf '%sB\n' "${*: -1}"; }

  main --dry-run >/dev/null 2>&1 || return 1

  grep -q 'paccache -dk2' "$CALL_LOG" &&
    grep -q 'docker system df' "$CALL_LOG" &&
    grep -q 'journalctl --disk-usage' "$CALL_LOG" &&
    ! grep -q 'image prune' "$CALL_LOG" &&
    ! grep -q 'builder prune' "$CALL_LOG" &&
    ! grep -q -- '--vacuum' "$CALL_LOG"
)

test_stage_failure_does_not_abort_later_stages() (
  local work rc
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  CALL_LOG="$work/calls"
  : >"$CALL_LOG"

  source "$SCRIPT"
  effective_uid() { printf '0\n'; }
  available_bytes() { printf '1000000\n'; }
  acquire_lock() { return 0; }
  paccache() { printf 'paccache %s\n' "$*" >>"$CALL_LOG"; return 9; }
  docker() { printf 'docker %s\n' "$*" >>"$CALL_LOG"; }
  journalctl() { printf 'journalctl %s\n' "$*" >>"$CALL_LOG"; }
  numfmt() { printf '%sB\n' "${*: -1}"; }

  main >/dev/null 2>&1
  rc=$?

  [[ $rc -eq 1 ]] &&
    grep -q 'docker image prune' "$CALL_LOG" &&
    grep -q 'docker builder prune' "$CALL_LOG" &&
    grep -q 'journalctl --vacuum-time=30d --vacuum-size=200M' "$CALL_LOG"
)

test_lock_contention_fails_cleanly() (
  source "$SCRIPT"
  available_bytes() { printf '1000000\n'; }
  acquire_lock() { return 1; }
  main --dry-run >/dev/null 2>&1
  [[ $? -eq 1 ]]
)

report invalid_argument test_invalid_argument
report dry_run_is_non_mutating test_dry_run_is_non_mutating
report stage_failure_continues test_stage_failure_does_not_abort_later_stages
report lock_contention test_lock_contention_fails_cleanly
printf 'pass=%d fail=%d\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]

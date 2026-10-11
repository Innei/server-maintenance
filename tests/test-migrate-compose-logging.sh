#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT_DIR/migrate-compose-logging.sh"
PASS=0
FAIL=0

report() {
  local name=$1
  shift
  if "$@"; then
    PASS=$((PASS + 1))
  else
    printf 'FAIL: %s\n' "$name" >&2
    FAIL=$((FAIL + 1))
  fi
}

test_invalid_argument() {
  "$SCRIPT" --unknown >/dev/null 2>&1
  [[ $? -eq 2 ]]
}

test_default_mode_only_validates() {
  local work
  work=$(mktemp -d)
  mkdir -p "$work/project"
  : >"$work/project/compose.yml"
  : >"$work/calls"

  (
    source "$SCRIPT"
    PROJECTS=("test|$work/project|compose.yml")
    docker() {
      printf 'docker %s\n' "$*" >>"$work/calls"
      return 0
    }
    main
  ) >/dev/null

  local rc=0
  grep -q 'docker compose -p test -f compose.yml config -q' "$work/calls" &&
    ! grep -q ' up ' "$work/calls" || rc=1
  rm -rf "$work"
  return "$rc"
}

test_apply_recreates_only_existing_services() {
  local work
  work=$(mktemp -d)
  mkdir -p "$work/project"
  : >"$work/project/compose.yml"
  : >"$work/calls"

  (
    source "$SCRIPT"
    PROJECTS=("test|$work/project|compose.yml")
    docker() {
      printf 'docker %s\n' "$*" >>"$work/calls"
      if [[ $1 == ps ]]; then
        printf 'database\n'
      fi
      return 0
    }
    verify_logging_limits() { return 0; }
    main --apply
  ) >/dev/null

  local rc=0
  grep -q 'docker compose -p test -f compose.yml up -d --force-recreate --no-build --pull never --no-deps database' "$work/calls" || rc=1
  rm -rf "$work"
  return "$rc"
}

report invalid_argument test_invalid_argument
report default_mode_only_validates test_default_mode_only_validates
report apply_recreates_only_existing_services test_apply_recreates_only_existing_services
printf 'pass=%d fail=%d\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]

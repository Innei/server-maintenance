#!/usr/bin/env bash
set -euo pipefail

APPLY=0

if ! declare -p PROJECTS >/dev/null 2>&1; then
  declare -a PROJECTS=(
    'rtmp|/home/innei/docker-compose/rtmp|docker-compose.yml'
    'ddns|/home/innei/docker-compose/ddns|docker-compose.yml'
    'sub-store|/home/innei/docker-compose/sub-store|docker-compose.yml'
    'rustfs|/home/innei/docker-compose/rustfs|docker-compose.yaml'
    'nginx|/home/innei/docker-compose/nginx|docker-compose.yaml'
    'teslamate|/home/innei/docker-compose/teslamate|docker-compose.yml'
    'hass|/home/innei/docker-compose/hass|compose.yml'
    'postgres|/home/innei/docker-compose/postgres|docker-compose.yml'
    'mongo|/home/innei/docker-compose/mongo|docker-compose.yaml'
    'surge-config|/home/innei/docker-compose/surge-config|docker-compose.yml'
    'portainer|/home/innei/docker-compose/portainer|docker-compose.yml'
    'moontv|/home/innei/docker-compose/moontv|docker-compose.yml'
    'autobangumi|/home/innei/docker-compose/autobangumi|docker-compose.yml'
    'thumbor|/home/innei/docker-compose/thumbor|docker-compose.yml'
    'telegram-search|/home/innei/docker-compose/telegram-search|docker-compose.yml'
    'matter-server|/home/innei/docker-compose/matter-server|docker-compose.yaml'
    'gitness|/home/innei/docker-compose/gitness|docker-compose.yml'
    'watchower|/home/innei/docker-compose/watchower|docker-compose.yaml'
    'deepl|/home/innei/docker-compose/deepl|docker-compose.yml'
    'tailscale|/home/innei/docker-compose/tailscale|docker-compose.yml'
  )
fi

usage() {
  printf 'Usage: %s [--apply]\n' "${0##*/}"
}

parse_args() {
  case $# in
    0) APPLY=0 ;;
    1)
      [[ $1 == --apply ]] || { usage >&2; return 2; }
      APPLY=1
      ;;
    *) usage >&2; return 2 ;;
  esac
}

process_project() {
  local entry=$1 project dir file
  local -a services=()
  IFS='|' read -r project dir file <<<"$entry"

  printf 'validating project=%s\n' "$project"
  (cd "$dir" && docker compose -p "$project" -f "$file" config -q)

  if (( APPLY )); then
    mapfile -t services < <(
      docker ps -a \
        --filter "label=com.docker.compose.project=$project" \
        --format '{{.Label "com.docker.compose.service"}}' | sort -u
    )
    if (( ${#services[@]} == 0 )); then
      printf 'no existing services found for project=%s\n' "$project" >&2
      return 1
    fi
    printf 'recreating project=%s services=%s\n' "$project" "${services[*]}"
    (cd "$dir" && docker compose -p "$project" -f "$file" \
      up -d --force-recreate --no-build --pull never --no-deps "${services[@]}")
  else
    printf 'validated project=%s\n' "$project"
  fi
}

verify_logging_limits() {
  local failures=0 id name config

  while read -r id; do
    [[ -n $id ]] || continue
    name=$(docker inspect --format '{{.Name}}' "$id")
    config=$(docker inspect --format '{{json .HostConfig.LogConfig.Config}}' "$id")
    if [[ $config != *'"max-size":"50m"'* || $config != *'"max-file":"3"'* ]]; then
      printf 'logging-limit-failed container=%s config=%s\n' "$name" "$config" >&2
      failures=$((failures + 1))
    else
      printf 'logging-limit-ok container=%s\n' "$name"
    fi
  done < <(docker ps -aq --filter label=com.docker.compose.project)

  printf 'standalone exception: ps5living\n'
  (( failures == 0 ))
}

main() {
  parse_args "$@" || return $?

  local entry
  for entry in "${PROJECTS[@]}"; do
    process_project "$entry"
  done

  if (( APPLY )); then
    verify_logging_limits
  fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi

# Server Maintenance

Conservative, scheduled disk cleanup for an Arch Linux server running Docker.

The maintenance job keeps recent package and Docker data, rotates old system
logs, records every stage in the systemd journal, and continues to the next
stage if one cleanup command fails.

## What it cleans

| Area | Policy |
| --- | --- |
| Pacman cache | Keep the two newest package versions |
| Unused Docker images | Remove images older than 14 days |
| Docker build cache | Remove cache older than 14 days |
| systemd journal | Keep at most 30 days and 200 MB |

The script reports available disk space before and after each run.

> [!IMPORTANT]
> The maintenance job never runs `docker system prune`, `docker volume prune`,
> or `docker container prune`. Application volumes and bind-mounted data are
> outside its cleanup scope.

> [!WARNING]
> An unused image may be removed even when its Compose configuration or data
> volume still exists. Docker may need to pull that image again before the
> application can be restored.

## Requirements

- Arch Linux with systemd
- Bash 5
- Docker Engine and Docker Compose v2
- `pacman-contrib` for `paccache`
- Standard `coreutils` and `util-linux` tools

## Install

```bash
git clone https://github.com/Innei/server-maintenance.git
cd server-maintenance

# Inspect the planned cleanup without changing the system.
./server-maintenance --dry-run

# Install the script and enable its timer.
sudo ./install.sh
```

The timer runs every Sunday at 04:00, with a randomized delay of up to 15
minutes. Persistent scheduling means a missed run starts after the server comes
back online.

Check the schedule:

```bash
systemctl list-timers server-maintenance.timer --no-pager
```

## Run manually

Preview the cleanup:

```bash
/usr/local/sbin/server-maintenance --dry-run
```

Start a live run through systemd:

```bash
sudo systemctl start server-maintenance.service
```

Read the latest result:

```bash
systemctl show server-maintenance.service -p Result -p ExecMainStatus
journalctl -u server-maintenance.service -n 100 --no-pager
```

Each cleanup stage is independent. The final exit status is non-zero if any
stage fails, while later stages still get a chance to run. A non-blocking file
lock prevents overlapping executions.

## Limit Docker container logs

Configure Docker's `json-file` driver before recreating existing containers:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
```

Save this as `/etc/docker/daemon.json`, then restart Docker:

```bash
sudo systemctl restart docker
```

Docker applies daemon logging defaults only to newly created containers.

### Compose migration

`migrate-compose-logging.sh` validates and recreates the Compose services that
were present on the original server. Its project paths are intentionally
explicit.

> [!CAUTION]
> Review and edit the `PROJECTS` array before using this script on another
> server. Applying the migration briefly restarts every listed service.

Validation only—the default and safe mode:

```bash
./migrate-compose-logging.sh
```

Recreate only services that already have containers, without pulling or
building images:

```bash
./migrate-compose-logging.sh --apply
```

The apply mode uses `--no-build`, `--pull never`, and `--no-deps`, then verifies
that every Compose container has `max-size=50m` and `max-file=3`.

## Files

| File | Purpose |
| --- | --- |
| `server-maintenance` | Cleanup program with dry-run and stage isolation |
| `server-maintenance.service` | Hardened one-shot systemd service |
| `server-maintenance.timer` | Persistent weekly schedule |
| `install.sh` | Root installer and timer activation |
| `migrate-compose-logging.sh` | One-time Compose logging migration |
| `tests/` | Command-mocking and unit-file checks |

## Test

```bash
./tests/test-server-maintenance.sh
./tests/test-units.sh
./tests/test-migrate-compose-logging.sh
bash -n server-maintenance install.sh migrate-compose-logging.sh tests/*.sh
```

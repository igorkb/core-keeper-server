# Core Keeper Server Ops

Containerized Core Keeper dedicated server management for this workspace, with helper scripts for start/stop, logs, backup/restore, status reporting, and remote deployment.

## Layout

- `docker-compose.yml` — base container definition, pinned image, healthcheck, log rotation
- `docker-compose.direct-connect.yml` — automatic UDP port publishing override for direct-connect mode
- `.env.example` — documented runtime configuration template
- `.compose.env` — Compose interpolation helper used by the scripts
- `server.sh` — top-level entrypoint for common operations
- `scripts/` — operational subcommands
- `data/server-files/` — installed server files, logs, `GameID.txt`
- `data/world-data/` — persistent save/config data
- `backups/` — backup archives and checksums
- `logs/` — script-generated backup/restore logs

## Basic usage

Run everything from the project root:

- `./server.sh start`
- `./server.sh stop`
- `./server.sh stop --no-backup`
- `./server.sh restart`
- `./server.sh status`
- `./server.sh logs`
- `./server.sh logs -f`
- `./server.sh logs --docker`
- `./server.sh backup`
- `./server.sh restore`

Without arguments, `./server.sh` opens the interactive menu.

## Configuration

1. Copy `.env.example` to `.env` if it does not already exist.
2. Adjust the server name, player cap, world settings, and optional integrations.
3. Keep `.env` local; it is intentionally ignored from source control.

### SDR vs direct-connect

By default, leave `SERVER_PORT` empty to use Steam Datagram Relay (SDR).

To enable direct-connect mode:

1. Set `SERVER_PORT` in `.env`
2. Open/forward the matching UDP port on your host/network
3. Start the server normally with `./server.sh start`

The helper scripts automatically add `docker-compose.direct-connect.yml` when `SERVER_PORT` is set, so UDP publishing happens without editing the base Compose file.

## Backups

`./server.sh backup` creates a compressed backup of `data/world-data/` and writes:

- `backups/core-keeper_backup_<timestamp>.tar.gz`
- `backups/core-keeper_backup_<timestamp>.tar.gz.sha256`

Behavior:

- backup archive is created atomically through a temporary file
- archive readability is verified before it is published
- a SHA-256 checksum is generated
- old backups are pruned by newest-first retention (default keeps the latest 3)

## Restore workflow

`./server.sh restore` validates the archive before replacing live data.

Current restore behavior:

1. verify the archive can be listed and, if present, the checksum matches
2. stop the running server if needed
3. extract into a staging directory
4. verify the extracted layout
5. move current `data/world-data/` to `data/world-data.pre-restore-<timestamp>`
6. move the restored data into place

If restore completes, the rollback copy is preserved for manual cleanup after verification.

## Logs and status

- game logs are read from `data/server-files/logs/`
- Game ID is read from `data/server-files/GameID.txt`
- status output shows:
  - container running/stopped state
  - Game ID (if generated)
  - world-data size
  - latest backup age
  - SDR vs direct-connect summary

## Remote deployment

Use `scripts/deploy-remote.sh` to sync and start the project on a remote machine.

### First-time setup

Create the deployment config template:

- `./scripts/deploy-remote.sh --setup`

This creates `scripts/.deploy.conf`.

### Remote deploy behavior

The deploy script now:

1. validates required options
2. uses safer SSH host-key handling (`accept-new`)
3. checks for Docker/Compose on the remote host
4. syncs the project while excluding runtime state
5. pulls the pinned image on the remote host
6. starts the stack remotely
7. verifies the container is running

Example usage:

- `./scripts/deploy-remote.sh --host example.com --path /opt/core-keeper-server`

## Notes

- The helper scripts use `.compose.env` for Compose interpolation so runtime placeholders in `.env` (such as Discord template variables) are not accidentally interpolated by Compose itself.
- Runtime state directories are ignored from source control on purpose.

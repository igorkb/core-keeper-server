# Core Keeper Server Ops

Containerized Core Keeper dedicated server with helper scripts for start/stop, logs, backup/restore, status reporting, and remote deployment.

This is a hobby project designed to be a practical, self-contained solution for hosting a Core Keeper server with minimal setup and operational overhead.

Although quite capable, this project is meant to be used for personal purposes and should not be considered a production-grade solution. Use at your own risk and remember to keep regular backups of your world data!

## Quick start

Clone the repo, then run:

```sh
./ckserver.sh
```

Select **Start Server** from the menu (or run `./ckserver.sh start` directly). No configuration is required to get going.

> Without a `.env` file the server starts with defaults: a new world is created at slot `0` with a random seed, standard difficulty, and a randomly generated Game ID.

Share that Game ID with your friends so they can join via **Join Game** in Core Keeper.

To customise the server name, player cap, world seed, or other settings, copy `.env.example` to `.env` and edit it before starting. See [Configuration](#configuration) for details.

If you want to load an existing world, copy the relevant files into `data/world-data/` before starting the server for the first time. See [Importing an existing world](#importing-an-existing-world) for instructions.

## Project layout

- `docker-compose.yml` — base container definition, pinned image, healthcheck, log rotation
- `docker-compose.direct-connect.yml` — automatic UDP port publishing override for direct-connect mode
- `.env.example` — documented runtime configuration template
- `.compose.env` — Compose interpolation helper used by the scripts
- `ckserver.sh` — top-level entrypoint for common operations
- `scripts/` — operational subcommands
- `data/server-files/` — installed server files, logs, `GameID.txt`
- `data/world-data/` — persistent save/config data
- `backups/` — backup archives and checksums
- `logs/` — script-generated backup/restore logs

## Prerequisites

- **Docker Engine** v24+ (`docker --version`)
- **Docker Compose v2** plugin — `docker compose` (not the legacy `docker-compose` v1)
- **rsync** and **ssh** — only needed for `scripts/deploy-remote.sh`

## Basic usage

Run everything from the project root:

- `./ckserver.sh start`
- `./ckserver.sh stop`
- `./ckserver.sh stop --no-backup`
- `./ckserver.sh restart`
- `./ckserver.sh status`
- `./ckserver.sh logs`
- `./ckserver.sh logs -f`
- `./ckserver.sh logs --docker`
- `./ckserver.sh backup`
- `./ckserver.sh restore`

Without arguments, `./ckserver.sh` opens the interactive menu.

## Configuration

1. Copy `.env.example` to `.env` if it does not already exist.
2. Adjust the server name, player cap, world settings, and optional integrations.
3. Keep `.env` local; it is intentionally ignored from source control.

### SDR (Steam Datagram Relay) vs direct-connect

By default, leave `SERVER_PORT` empty to use Steam Datagram Relay (SDR).

To enable direct-connect mode:

1. Set `SERVER_PORT` in `.env`
2. Open/forward the matching UDP port on your host/network
3. Start the server normally with `./ckserver.sh start`

The helper scripts automatically add `docker-compose.direct-connect.yml` when `SERVER_PORT` is set, so UDP publishing happens without editing the base Compose file.

## Importing an existing world

If you already have a singleplayer world you want to continue on the dedicated server, copy it before starting the server for the first time.

### Step 1 — Find your local save files

Common locations for Core Keeper save files:

**Windows**

```
%APPDATA%\LocalLow\Pugstorm\Core Keeper\Steam\<SteamID64>\worlds\
```

**macOS**

```
~/Library/Application Support/com.pugstorm.corekeeper/Steam/<SteamID64>/worlds/
```

**Linux (Steam)**

```
~/.config/unity3d/Pugstorm/Core Keeper/Steam/<SteamID64>/worlds/
```

Replace `<SteamID64>` with your numeric Steam ID (visible in your Steam profile URL).

### Step 2 — Copy the world files

Two files are required for each world. Rename them to match the slot number you want to use on the server (slot `0` is the default):

| Source file                 | Destination                                       |
| --------------------------- | ------------------------------------------------- |
| `<WorldName>.world.gzip`    | `data/world-data/worlds/<slot>.world.gzip`        |
| `<WorldName>.mapparts.gzip` | `data/world-data/servermaps/<slot>.mapparts.gzip` |

### Step 3 — Configure and start

Set `WORLD_INDEX` in `.env` to the slot number you used (default is `0`):

```
WORLD_INDEX=0
```

Then start the server normally:

```
./ckserver.sh start
```

> **Note:** Use slots `1`–`9` to host additional worlds without overwriting the one in slot `0`.

## Backups

`./ckserver.sh backup` creates a compressed backup of `data/world-data/` and writes:

- `backups/core-keeper_backup_<timestamp>.tar.gz`
- `backups/core-keeper_backup_<timestamp>.tar.gz.sha256`

Behavior:

- backup archive is created atomically through a temporary file
- archive readability is verified before it is published
- a SHA-256 checksum is generated
- old backups are pruned by newest-first retention (default keeps the latest 3)

## Restore workflow

`./ckserver.sh restore` validates the archive before replacing live data.

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

> ⚠️ **Alert:** Remote deployment is not tested and is considered an experimental feature in its early stages. Only use it if you know what you are doing. Be cautious and always keep backups of your world data before attempting remote sync or deployment.

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

### Security notes

- **Root user default** — `REMOTE_USER` defaults to `root` as a convenience for initial setup. In production, prefer a dedicated non-root user with sudo access limited to Docker.
- **SSH host-key trust** — the script uses `StrictHostKeyChecking=accept-new`, which automatically trusts the remote host on the first connection and rejects unexpected key changes afterwards (TOFU — trust on first use). Verify the host fingerprint manually before deploying to an untrusted machine.

## Notes

- **`.compose.env`** — this file is intentionally committed and intentionally empty. It is passed to `docker compose` as the Compose-level variable substitution source (`--env-file .compose.env`). The actual runtime configuration lives in `.env`, which is passed directly to the container via the `env_file:` directive in `docker-compose.yml` and is **not** processed by Compose interpolation. This separation is important: the Discord message templates in `.env` contain placeholders like `${char_name}` and `${gameid}` that are meant to be expanded by the container's own scripting — if Compose processed them, they would silently become empty strings. Removing `.compose.env` would break Discord notifications.
- Runtime state directories (`data/`, `backups/`, `logs/`) are excluded from source control on purpose — see `.gitignore`.

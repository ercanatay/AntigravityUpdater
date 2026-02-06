# Docker Updater

This directory contains a Docker-focused updater script for Antigravity Manager deployments.
It supports the shared 51-language locale set used across the project.

## Script

- `antigravity-docker-update.sh`

## What It Does

- Detects the latest Antigravity Manager release tag from GitHub
- Pulls the matching Docker image from `lbjlaq/antigravity-manager`
- Optionally recreates an existing container with the new image

## Requirements

- Docker CLI
- `curl`
- `python3`

## Usage

```bash
# Change language
./docker/antigravity-docker-update.sh --lang

# Reset saved language preference
./docker/antigravity-docker-update.sh --reset-lang

# Check only (no pull, no restart)
./docker/antigravity-docker-update.sh --check-only

# Show changelog before pull/restart
./docker/antigravity-docker-update.sh --changelog

# Pull latest image tag based on latest GitHub release
./docker/antigravity-docker-update.sh

# Pull specific tag
./docker/antigravity-docker-update.sh --tag v4.1.7

# Pull and restart existing container
./docker/antigravity-docker-update.sh --restart-container --container-name antigravity-manager
```

## Important Notes

- `--restart-container` works for containers started with `docker run`.
- If the container is managed by Docker Compose, the script stops and shows this command instead:

```bash
docker compose pull && docker compose up -d
```

## Log File

- `$XDG_STATE_HOME/AntigravityUpdater/docker-updater.log`
- Fallback when `XDG_STATE_HOME` is not set: `~/.local/state/AntigravityUpdater/docker-updater.log`

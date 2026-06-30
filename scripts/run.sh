#!/bin/bash
# run.sh — Start an interactive sandbox container session.
#
# Usage:
#   ./run.sh [args...]
#
# Any extra arguments are forwarded to "docker compose run" (e.g. --build).
# The container is removed on exit (--rm) but /persist survives via the
# bind-mount declared in docker-compose.yml.
#
# Automatically selects "docker compose" (v2 plugin) or falls back to the
# legacy "docker-compose" binary.

cd "$(dirname "$0")/.." || exit

# --- Pick a Docker Compose command -------------------------------------------
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
else
  echo "Error: neither 'docker compose' nor 'docker-compose' is installed" >&2
  exit 1
fi

# --service-ports publishes the VNC port (5901) declared in docker-compose.yml
# so you can connect a VNC client while the session is running.
exec $COMPOSE run --rm --service-ports sandbox "$@"


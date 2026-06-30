#!/bin/bash
# run.sh - Start the sandbox container
#
# Usage:
#   ./run.sh


cd "$(dirname "$0")/.."

# Detect compose command
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
else
  echo "Error: neither 'docker compose' nor 'docker-compose' is installed" >&2
  exit 1
fi

exec $COMPOSE run --rm --service-ports sandbox "$@"


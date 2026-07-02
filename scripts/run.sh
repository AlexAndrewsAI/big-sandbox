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

set -euo pipefail
cd "$(dirname "$0")/.." || exit

# --- Parse arguments ---------------------------------------------------------
SETUP_SSH_TUNNEL=true
for arg in "$@"; do
  case $arg in
    --no-ssh-tunnel)
      SETUP_SSH_TUNNEL=false
      ;;
    *)
      ;;
  esac
done

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
if [ "$SETUP_SSH_TUNNEL" = true ]; then
  echo "🔒 Setting up SSH tunnel for secure VNC access..."
  echo "The SSH tunnel will run in the background."
  echo "VNC connections will be encrypted."
  echo "SSH tunnel will forward to localhost:5902"
  echo "(to avoid conflict with Docker's port mapping)"
  echo ""

  # Start SSH tunnel in background with retries
  (
    set +e  # Allow SSH failures for retries
    retries=10
    delay=2
    i=1

    # SSH options for tunnel setup
    SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
    SSH_TUNNEL=(-f -N -L 5902:localhost:5901 -p 2222 sandbox@localhost)

    while [ "$i" -le "$retries" ]; do
      if sshpass -p 'sandbox' ssh "${SSH_OPTS[@]}" \
         "${SSH_TUNNEL[@]}" 2>/dev/null; then
        echo "✅ SSH tunnel established."
        echo "Connect your VNC client to localhost:5902"
        echo "   (Connection is now encrypted via SSH)"
        echo ""
        exit 0
      else
        if [ "$i" -lt "$retries" ]; then
          echo "⏳  Waiting for container to be ready... ($i/$retries)"
          sleep "$delay"
        fi
      fi
      i=$((i+1))
    done

    echo "⚠️  SSH tunnel setup failed."
    echo "The container might not be ready yet."
    echo "You can manually set up the tunnel later with:"
    echo "  sshpass -p 'sandbox' ssh -o StrictHostKeyChecking=no"
    echo "    -o UserKnownHostsFile=/dev/null -L 5902:localhost:5901"
    echo "    -p 2222 sandbox@localhost"
    echo ""
  ) &

  # Function to cleanup SSH tunnel on exit
  cleanup_ssh_tunnel() {
    set +e  # Allow pkill to fail if no process found
    pkill -f "ssh.*-L.*5902.*2222" 2>/dev/null || true
  }

  trap cleanup_ssh_tunnel EXIT
fi

exec $COMPOSE run --rm --service-ports sandbox "$@"


#!/bin/bash
# build.sh — Build the big-sandbox Docker image.
#
# Steps:
#   1. Verify docker-compose.yml exists (points user at the example if not).
#   2. Fetch the upstream .bashrc if we don't already have one.
#   3. Optionally sync a "persist/" directory from another sandbox location
#      (configured via config.yml → location / exclude).
#   4. Run "docker compose build" with plain progress output.
#
# Usage:
#   ./build.sh [--build-arg KEY=VAL]...

set -euo pipefail
cd "$(dirname "$0")/.." || exit

# --- Prerequisite: docker-compose.yml ----------------------------------------
if [ ! -f docker-compose.yml ]; then
  echo "docker-compose.yml not found. Create it from the example:"
  echo ""
  echo "  cp docker-compose.example.yml docker-compose.yml"
  echo ""
  exit 1
fi

# --- Seed .bashrc from upstream ----------------------------------------------
# The upstream simple-agent-sandbox repo ships a sensible default .bashrc.
# We only fetch it once; after that the user can edit persist/.bashrc freely.
mkdir -p persist
if [ ! -f persist/.bashrc ]; then
  echo "persist/.bashrc not found — fetching from simple-agent-sandbox..."
  curl -fsSL https://raw.githubusercontent.com/AlexAndrewsAI/simple-agent-sandbox/refs/heads/main/persist/.bashrc -o persist/.bashrc
fi

# --- Optional persist sync ----------------------------------------------------
# If config.yml declares a "location", rsync that sandbox's persist/ into
# ours so we start with the same dotfiles, tools, and cached data.  The
# optional "exclude" list lets us skip large or irrelevant subtrees.
if [ -f config.yml ] && yq -r '.location' config.yml &>/dev/null; then
  location=$(yq -r '.location' config.yml)

  if [ "$location" != "null" ] && [ -n "$location" ]; then
    echo "Syncing persist from $location..."

    exclude_args=()
    if yq -r '.exclude' config.yml &>/dev/null; then
      while IFS= read -r pattern; do
        if [ "$pattern" != "null" ] && [ -n "$pattern" ]; then
          exclude_args+=(--exclude "$pattern")
        fi
      done < <(yq -r '.exclude[]' config.yml)
    fi

    if [ -d "$location/persist" ]; then
      if command -v rsync &>/dev/null; then
        rsync -av "${exclude_args[@]}" "$location/persist/" persist/
        echo "Sync complete."
      else
        echo "WARNING: rsync not installed — skipping persist sync from $location" >&2
      fi
    else
      echo "WARNING: Source directory $location/persist/ does not exist" >&2
    fi
  fi
fi

# --- Build --------------------------------------------------------------------
docker compose build --progress=plain "$@"

#!/bin/bash
# build.sh - Build the Docker image
set -euo pipefail
cd "$(dirname "$0")/.."
echo "DEBUG: Working directory is $(pwd)"

if [ ! -f docker-compose.yml ]; then
  echo "docker-compose.yml not found. Create it from the example:"
  echo ""
  echo "  cp docker-compose.example.yml docker-compose.yml"
  echo ""
  exit 1
fi

# Fetch .bashrc from upstream if not present
mkdir -p persist
if [ ! -f persist/.bashrc ]; then
  echo "persist/.bashrc not found — fetching from simple-agent-sandbox..."
  curl -fsSL https://raw.githubusercontent.com/AlexAndrewsAI/simple-agent-sandbox/refs/heads/main/persist/.bashrc -o persist/.bashrc
fi

# Sync persist from another sandbox location if configured
echo "DEBUG: Checking for config.yml..."
if [ -f config.yml ]; then
  echo "DEBUG: config.yml found"
  echo "DEBUG: Checking if .location field exists..."
  if yq '.location' config.yml &>/dev/null; then
    location=$(yq '.location' config.yml)
    location="${location#\"}"
    location="${location%\"}"
    location="${location#\'}"
    location="${location%\'}"
    echo "DEBUG: location = '$location'"
    if [ "$location" != "null" ] && [ -n "$location" ]; then
      echo "DEBUG: Syncing persist from $location..."

      exclude_args=()
      if yq '.exclude' config.yml &>/dev/null; then
        echo "DEBUG: Reading exclude patterns..."
        while IFS= read -r pattern; do
          pattern="${pattern#\"}"
          pattern="${pattern%\"}"
          pattern="${pattern#\'}"
          pattern="${pattern%\'}"
          if [ "$pattern" != "null" ] && [ -n "$pattern" ]; then
            echo "DEBUG:   exclude: $pattern"
            exclude_args+=(--exclude "$pattern")
          fi
        done < <(yq '.exclude[]' config.yml)
      else
        echo "DEBUG: No exclude field found"
      fi

      echo "DEBUG: Checking source dir $location/persist/..."
      if [ -d "$location/persist" ]; then
        echo "DEBUG: Source dir exists"
        if command -v rsync &>/dev/null; then
          echo "DEBUG: Running rsync..."
          echo rsync -av "${exclude_args[@]}" "$location/persist/" persist/
          rsync -av "${exclude_args[@]}" "$location/persist/" persist/
          echo "Sync complete."
        else
          echo "WARNING: rsync not installed — skipping persist sync from $location" >&2
        fi
      else
        echo "WARNING: Source directory $location/persist/ does not exist" >&2
      fi
    else
      echo "DEBUG: location is null or empty — skipping sync"
    fi
  else
    echo "DEBUG: .location field not found in config.yml — skipping sync"
  fi
else
  echo "DEBUG: config.yml not found — skipping persist sync"
fi

docker compose build --progress=plain "$@"

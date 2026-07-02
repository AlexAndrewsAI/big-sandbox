#!/bin/bash
# build.sh — Build the big-sandbox Docker image.
#
# Steps:
#   1. Verify config.yml and docker-compose.yml exist
#      (offers to copy from examples if not).
#   2. Fetch the upstream .bashrc if we don't already have one.
#   3. Optionally sync a "persist/" directory from another sandbox location
#      (configured via config.yml → location / exclude).
#   4. Run "docker compose build" with plain progress output.
#   5. Optionally push to Docker Hub.
#
# Usage:
#   ./build.sh [-n|--no-cache] [-p|--push]

set -euo pipefail
cd "$(dirname "$0")/.." || exit

# Parse arguments
no_cache=false
push=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--no-cache)
      no_cache=true
      shift
      ;;
    -p|--push)
      push=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-n|--no-cache] [-p|--push]"
      exit 1
      ;;
  esac
done

# --- Prerequisite: config files ----------------------------------------------
missing_files=()
[ ! -f config.yml ] && missing_files+=("config.yml")
[ ! -f docker-compose.yml ] && missing_files+=("docker-compose.yml")

if [ ${#missing_files[@]} -gt 0 ]; then
  echo "The following config files are missing:"
  for file in "${missing_files[@]}"; do
    echo "  - $file"
  done
  echo ""
  read -p "Copy from example files? [y/N] " -n 1 -r
  echo
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    for file in "${missing_files[@]}"; do
      example="${file%.yml}.example.yml"
      if [ -f "$example" ]; then
        cp "$example" "$file"
        echo "Copied $example to $file"
      else
        echo "ERROR: $example not found" >&2
        exit 1
      fi
    done
  else
    exit 1
  fi
fi

# --- Seed .bashrc from upstream ----------------------------------------------
# The upstream simple-agent-sandbox repo ships a sensible default .bashrc.
# We only fetch it once; after that the user can edit persist/.bashrc freely.
mkdir -p persist
if [ ! -f persist/.bashrc ]; then
  echo "persist/.bashrc not found — fetching from simple-agent-sandbox..."
  BASHRC_URL="https://raw.githubusercontent.com/"
  BASHRC_URL+="AlexAndrewsAI/simple-agent-sandbox/"
  BASHRC_URL+="refs/heads/main/persist/.bashrc"
  curl -fsSL "$BASHRC_URL" -o persist/.bashrc
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
        echo "ERROR: rsync not installed" >&2
        echo "persist sync is configured in config.yml but rsync is not available." >&2
        echo "Install rsync to enable persist sync, or remove the 'location' field from config.yml." >&2
        echo "  Ubuntu/Debian: sudo apt install rsync" >&2
        echo "  macOS: rsync is pre-installed" >&2
        echo "  Fedora/RHEL: sudo dnf install rsync" >&2
        exit 1
      fi
    else
      echo "ERROR: Source directory $location/persist/ does not exist" >&2
      echo "persist sync is configured but the source directory was not found." >&2
      echo "Check the 'location' field in config.yml and ensure the path is correct." >&2
      exit 1
    fi
  fi
fi

# --- Build --------------------------------------------------------------------
build_args=(--progress=plain)
if [ "$no_cache" = true ]; then
  build_args+=(--no-cache)
fi

docker compose build "${build_args[@]}"

# --- Push --------------------------------------------------------------------
if [ "$push" = true ]; then
  echo "Pushing image to Docker Hub..."
  docker compose push

  # Create and push dated tag
  image_name=$(yq -r '.services.sandbox.image' docker-compose.yml)
  if [ "$image_name" != "null" ] && [ -n "$image_name" ]; then
    dated_tag=$(date +%Y-%m-%d)
    dated_image="${image_name%:*}:${dated_tag}"

    echo "Tagging image as $dated_image..."
    docker tag "$image_name" "$dated_image"

    echo "Pushing $dated_image..."
    docker push "$dated_image"
  else
    echo "WARNING: Could not determine image name from docker-compose.yml" >&2
  fi
fi

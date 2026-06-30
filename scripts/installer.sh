#!/bin/bash
# installer.sh — Execute the custom "install" steps from config.yml.
#
# Called during "docker build" as the sandbox user so that downloaded tools
# (AppImages, pip packages, npm globals, etc.) land in /home/sandbox and
# don't require root to write.
#
# Each top-level key under "install:" in config.yml becomes one step.
# The key name is a human-readable label; the value is a shell command that
# is eval'd.  Steps run sequentially and the build fails fast on the first
# error so the user can fix the offending command and rebuild.
#
# Usage:
#   installer.sh [config-path]   # default: /tmp/config.yml

set -euo pipefail

CONFIG="${1:-/tmp/config.yml}"

# --- Config file presence -----------------------------------------------------
if [ ! -f "$CONFIG" ]; then
  echo "installer.sh: config.yml not found at $CONFIG — skipping install section" >&2
  exit 0
fi

# --- Does the install section exist and is it non-empty? ----------------------
if ! YQ_CHECK=$(yq -r '.install' "$CONFIG" 2>/dev/null) || [ "$YQ_CHECK" = "null" ] || [ -z "$YQ_CHECK" ]; then
  echo "installer.sh: no 'install' section found in $CONFIG — nothing to do"
  exit 0
fi

KEYS=$(yq -r '.install | keys[]' "$CONFIG" 2>/dev/null || true)
if [ -z "$KEYS" ]; then
  echo "installer.sh: 'install' section is empty — nothing to do"
  exit 0
fi

# --- Run each install step ----------------------------------------------------
echo "installer.sh: Processing install section from $CONFIG"

while IFS= read -r key; do
  cmd=$(yq -r ".install[\"$key\"]" "$CONFIG" 2>/dev/null || true)

  if [ -z "$cmd" ] || [ "$cmd" = "null" ]; then
    echo "installer.sh:   [SKIP] $key (empty or null command)"
    continue
  fi

  echo "installer.sh:   [RUN]   $key"
  echo "installer.sh:   cmd:    $cmd"
  eval "$cmd" && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "installer.sh:   [FAIL]  $key exited with code $rc" >&2
    echo "installer.sh: Aborting build — fix the error and rebuild." >&2
    exit "$rc"
  fi
  echo "installer.sh:   [OK]    $key installed successfully"
done <<< "$KEYS"

echo "installer.sh: Done processing install section"

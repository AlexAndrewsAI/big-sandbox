#!/bin/bash
# installer.sh - Read config.yml and run each command under the install: section
# Called during Docker build as the sandbox user.
# Exits immediately on first failure (fail-fast) so the user can intervene.
set -euo pipefail

CONFIG="${1:-/tmp/config.yml}"

if [ ! -f "$CONFIG" ]; then
  echo "installer.sh: config.yml not found at $CONFIG — skipping install section" >&2
  exit 0
fi

# Check if the install section exists at all
if ! YQ_CHECK=$(yq -r '.install' "$CONFIG" 2>/dev/null) || [ "$YQ_CHECK" = "null" ] || [ -z "$YQ_CHECK" ]; then
  echo "installer.sh: no 'install' section found in $CONFIG — nothing to do"
  exit 0
fi

KEYS=$(yq -r '.install | keys[]' "$CONFIG" 2>/dev/null || true)
if [ -z "$KEYS" ]; then
  echo "installer.sh: 'install' section is empty — nothing to do"
  exit 0
fi

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

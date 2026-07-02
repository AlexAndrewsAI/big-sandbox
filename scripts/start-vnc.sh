#!/bin/bash
# start-vnc.sh — Launch a full VNC desktop session inside the
# sandbox container.
#
# Cleanup: all backgrounded desktop processes are tracked and killed on EXIT
# so they don't leak if the script exits early or the container stops.
#
# What it does, in order:
#   1. Ensures a VNC password exists (prompts on first run).
#   2. Creates a shared X authority file so both root and sandbox can
#      authenticate against the same display.
#   3. Starts Xvfb (virtual framebuffer) on display :1 as root.
#   4. Launches a D-Bus session + XFCE desktop as the sandbox user.
#   5. Starts x11vnc to expose the desktop on port 5901.
#
# Requirements:
#   - Must be run as the "sandbox" user with NOPASSWD sudo.
#   - Xvfb, x11vnc, xauth, and xfce4 must be installed.
#
# Environment variables set here propagate to the XFCE session and any
# child processes (e.g. terminals, browsers) the agent launches.

set -euo pipefail
PASSWORD_FILE="/persist/.vnc/passwd"

# --- VNC password setup -----------------------------------------------------
# On first run there is no password file, so prompt the user to create one.
# Subsequent runs reuse the stored password silently.
mkdir -p /persist/.vnc

if [ ! -f "$PASSWORD_FILE" ]; then
  echo "No VNC password found. Please set one now:"
  x11vnc -storepasswd "$PASSWORD_FILE"
  echo "Password saved to $PASSWORD_FILE"
fi

# --- Shared X authority ------------------------------------------------------
# Xvfb runs as root and x11vnc runs as sandbox, so they need a shared
# X authority file.  We create one, add a fresh magic cookie, and make
# it world-readable so both users can authenticate.
XAUTHORITY_FILE="/tmp/.Xauthority-shared"

# Remove any stale authority file from a previous container run.
sudo rm -f "$XAUTHORITY_FILE"

export DISPLAY=:1
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export XAUTHORITY="$XAUTHORITY_FILE"

COOKIE=$(mcookie)
sudo xauth -f "$XAUTHORITY_FILE" add :1 MIT-MAGIC-COOKIE-1 "$COOKIE"
sudo chmod 644 "$XAUTHORITY_FILE"

# --- Process cleanup -------------------------------------------------------
# Track every backgrounded process so an EXIT trap can kill them all.
# This prevents orphaned Xvfb/xfce4-session/x11vnc if the script exits
# early (e.g. error signal) or the Docker container stops.
CHILD_PIDS=()

cleanup_processes() {
  set +e
  for pid in "${CHILD_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait
}
trap cleanup_processes EXIT

# --- Virtual framebuffer (Xvfb) ---------------------------------------------
# Needs root to create the /tmp/.X11-unix socket.  Resolution is 1280x720
# at 24-bit colour depth — enough for a usable desktop without wasting RAM.
sudo Xvfb :1 -screen 0 1280x720x24 -auth "$XAUTHORITY_FILE" &
CHILD_PIDS+=($!)
sleep 1

# --- User environment --------------------------------------------------------
# These variables ensure GUI apps write their config/cache/data under
# /persist so they survive container restarts.
LOCAL_PATHS="/home/sandbox/.local/bin:/persist/.local/bin"
LOCAL_PATHS+=":/usr/local/bin:/usr/bin:/bin"
export PATH="$LOCAL_PATHS"
export PATH+=:/home/sandbox/node_modules/cline/bin
export HOME=/persist
export XDG_CONFIG_HOME=/persist/.config
export XDG_DATA_HOME=/persist/.local/share
export XDG_CACHE_HOME=/persist/.cache

# --- D-Bus session bus ------------------------------------------------------
# Required by many XFCE components (volume, power, notifications, etc.).
set +e  # dbus-launch may fail
eval "$(dbus-launch --sh-syntax)"
set -e
if command -v dbus-update-activation-environment &> /dev/null; then
  dbus-update-activation-environment --systemd DISPLAY 2>/dev/null || true
fi
sleep 1

# --- XFCE desktop -----------------------------------------------------------
xfce4-session &
CHILD_PIDS+=($!)
sleep 1

# --- VNC server (x11vnc) ----------------------------------------------------
# - -noshm: disable MIT-SHM shared memory extension (not available in
#   containers, causes "BadAccess" errors if left enabled).
# - -nopw: we use -rfbauth instead; this suppresses the "you have no
#   password" warning.
# - -shared: allow multiple simultaneous VNC clients.
x11vnc -display :1 -auth "$XAUTHORITY_FILE" -rfbauth "$PASSWORD_FILE" \
       -forever -shared -nopw -noshm -rfbport 5901 &
CHILD_PIDS+=($!)

echo "VNC server started on display :1 (port 5901)"

# Block until all backgrounded desktop processes exit, then clean them up.
# The EXIT trap fires on normal exit, SIGTERM, or any child dying.
wait

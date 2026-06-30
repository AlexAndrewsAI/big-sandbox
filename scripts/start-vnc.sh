#!/bin/bash
# start-vnc.sh - Start x11vnc server on display :1
# Designed to run as the sandbox user with NOPASSWD sudo for root operations.
# Prompts for a password if none is set up yet.

PASSWORD_FILE="/persist/.vnc/passwd"

# Ensure .vnc directory exists (owned by sandbox)
mkdir -p /persist/.vnc

if [ ! -f "$PASSWORD_FILE" ]; then
  echo "No VNC password found. Please set one now:"
  x11vnc -storepasswd "$PASSWORD_FILE"
  echo "Password saved to $PASSWORD_FILE"
fi

XAUTHORITY_FILE="/tmp/.Xauthority-shared"

# Clean up stale X authority from a previous run
sudo rm -f "$XAUTHORITY_FILE"

# Set DISPLAY environment variable
export DISPLAY=:1

# Set locale to UTF-8
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Create a shared X authority file as root so Xvfb can use it
# (sandbox can connect to it since we make it world-readable)
export XAUTHORITY="$XAUTHORITY_FILE"
COOKIE=$(mcookie)
sudo xauth -f "$XAUTHORITY_FILE" add :1 MIT-MAGIC-COOKIE-1 "$COOKIE"
sudo chmod 644 "$XAUTHORITY_FILE"

# Start Xvfb on display :1 (needs root to create /tmp/.X11-unix)
sudo Xvfb :1 -screen 0 1280x720x24 -auth "$XAUTHORITY_FILE" &
sleep 1

# Start D-Bus + XFCE session as sandbox (we're already sandbox)
export PATH=/home/sandbox/.local/bin:/persist/.local/bin:/usr/local/bin:/usr/bin:/bin:/home/sandbox/node_modules/cline/bin
export HOME=/persist
export XDG_CONFIG_HOME=/persist/.config
export XDG_DATA_HOME=/persist/.local/share
export XDG_CACHE_HOME=/persist/.cache

eval "$(dbus-launch --sh-syntax)"
if command -v dbus-update-activation-environment &> /dev/null; then
  dbus-update-activation-environment --systemd DISPLAY 2>/dev/null || true
fi
sleep 1
xfce4-session &
sleep 1

# Start x11vnc as sandbox with shared auth
x11vnc -display :1 -auth "$XAUTHORITY_FILE" -rfbauth "$PASSWORD_FILE" -forever -shared -nopw -noshm -rfbport 5901 &

echo "VNC server started on display :1 (port 5901)"

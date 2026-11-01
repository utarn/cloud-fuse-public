#!/usr/bin/env bash
# Install (or remove) a per-user LaunchAgent that mounts the Cloud Fuse SMB
# share at login and re-mounts it within a minute if it goes away.
#
#   ./docker/macos-install-automount.sh            # install + start
#   ./docker/macos-install-automount.sh --uninstall
#
# The agent runs docker/macos-mount.sh, so it inherits that script's defaults
# and environment overrides.  It runs in the user's GUI session, which is what
# mount_smbfs needs; run it while logged in as the user who owns the mount.
set -euo pipefail

LABEL="local.cloud-fuse.mount"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOUNT_SCRIPT="$SCRIPT_DIR/macos-mount.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/cloud-fuse-mount.log"
DOMAIN="gui/$(id -u)"

if [ ! -x "$MOUNT_SCRIPT" ]; then
    echo "install-automount: $MOUNT_SCRIPT is missing or not executable" >&2
    exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "removed $LABEL (the current mount, if any, is left in place)"
    exit 0
fi

mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"

# RunAtLoad mounts at login; StartInterval retries once a minute so the mount
# appears after Docker Desktop finishes starting, and returns after a container
# restart.  macos-mount.sh is idempotent.
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$MOUNT_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
EOF

bootout() { launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true; }
bootout
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "installed $PLIST"
echo "mount: $MOUNT_SCRIPT"
echo "log:   $LOG"

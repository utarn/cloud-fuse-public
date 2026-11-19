#!/usr/bin/env bash
# Mount the Cloud Fuse SMB share on macOS with the userspace SMB client.
#
# Why not Finder's "Connect to Server"?  Finder uses the NetFS/kernel SMB
# client, which cannot mount a share served from the same Mac.  Docker Desktop
# publishes the container's ports on the Mac's own address, so NetFS ends in
# "The server may not exist or it is unavailable at this time"
# (NetAuthSysAgent logs "GetServerInfo failed").  mount_smbfs has no such
# restriction and the same share mounts and reads/writes normally.
#
# Usage:
#   ./docker/macos-mount.sh                 # mount (defaults below)
#   ./docker/macos-mount.sh --unmount       # unmount
#
# Environment overrides:
#   CLOUD_FUSE_SMB_SERVER     127.0.0.1        (or the Mac's LAN IP)
#   CLOUD_FUSE_SMB_SHARE      google-drive
#   CLOUD_FUSE_SMB_USER       cloudfuse
#   CLOUD_FUSE_SMB_PASSWORD   cloudfuse
#   CLOUD_FUSE_SMB_MOUNTPOINT $HOME/GoogleDrive
set -euo pipefail

SERVER="${CLOUD_FUSE_SMB_SERVER:-127.0.0.1}"
SHARE="${CLOUD_FUSE_SMB_SHARE:-google-drive}"
USER="${CLOUD_FUSE_SMB_USER:-cloudfuse}"
PASS="${CLOUD_FUSE_SMB_PASSWORD:-cloudfuse}"
MP="${CLOUD_FUSE_SMB_MOUNTPOINT:-$HOME/GoogleDrive}"

is_mounted() {
    mount | grep -Fq " on $MP (smbfs"
}

if [ "${1:-}" = "--unmount" ]; then
    if is_mounted; then
        diskutil unmount "$MP" >/dev/null 2>&1 || umount "$MP"
        echo "unmounted $MP"
    else
        echo "not mounted at $MP"
    fi
    exit 0
fi

if is_mounted; then
    echo "already mounted at $MP"
    exit 0
fi

mkdir -p "$MP"
# soft: file operations time out instead of hanging Finder if the container
# stops.  noowners/nosuid/nodev match the SMB mount defaults Finder would use.
mount_smbfs -o soft,noowners,nosuid,nodev \
    "//$USER:$PASS@$SERVER/$SHARE" "$MP"
echo "mounted //$SHARE at $MP"

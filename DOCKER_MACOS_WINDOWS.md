# Running Cloud Fuse on macOS & Windows with Docker

Cloud Fuse is a Linux FUSE filesystem. Neither macOS nor Windows provides the
Linux FUSE3 kernel interface, so the published container runs the daemon inside
Docker's Linux VM and re-exports the mount to the host as a normal SMB share.

- **Desktop image:** [`utarn/cloud-fuse:smb`](https://hub.docker.com/r/utarn/cloud-fuse)
  (`linux/amd64`, `linux/arm64`). `utarn/cloud-fuse:latest` is the same daemon
  without the SMB export.
- **No kernel extensions:** no macFUSE, no WinFsp, no SIP or driver-signing changes
- **Tuned Samba:** `vfs_fruit` / `vfs_catia` avoid `._*` AppleDouble files and
  map macOS-legal names
- **Tiered cache:** evicted content is re-fetched on demand; writes return
  immediately and upload in the background

---

## Prerequisites

| | macOS | Windows |
|---|---|---|
| Container runtime | Docker Desktop (VirtioFS) or OrbStack | Docker Desktop with the WSL2 backend |
| OS | Apple Silicon or Intel | Windows 10/11 (WSL2 enabled) |

You also need a **Google OAuth Desktop-app client** (client ID + secret), because
Cloud Fuse talks to Google Drive through your own OAuth project:

1. Open <https://console.cloud.google.com/> and create (or select) a project.
2. **APIs & Services → Library → Google Drive API → Enable**.
3. **APIs & Services → OAuth consent screen**: choose *External*, add the Google
   account you will mount as a **test user**.
4. **APIs & Services → Credentials → Create credentials → OAuth client ID →
   Desktop app**. Copy the client ID and client secret.

---

## 1. Get the files, a license, and configuration

```sh
git clone https://github.com/utarn/cloud-fuse-public.git
cd cloud-fuse-public
cp .env.example .env
mkdir -p data/licenses
```

PowerShell:

```powershell
git clone https://github.com/utarn/cloud-fuse-public.git
cd cloud-fuse-public
Copy-Item .env.example .env
New-Item -ItemType Directory -Force data\licenses
```

Edit `.env` and set `CLOUD_FUSE_ACCOUNT`, `CLOUD_FUSE_CLIENT_ID`,
`CLOUD_FUSE_CLIENT_SECRET`, and (optionally) a different `SMB_PASSWORD`.

> Use the **lower-case form** of the Google email for `CLOUD_FUSE_ACCOUNT`. It is
> used as the Account name and as the license file name.

Purchase a license at <https://cloudfuse.scigrad.com/> and save the JWT as:

```
data/licenses/<your-google-email>.jwt
```

PowerShell:

```powershell
Set-Content -NoNewline -Path "data\licenses\<your-google-email>.jwt" -Value "<jwt>"
```

---

## 2. Authorize the account once

The OAuth flow listens on a fixed loopback port (`8765`) that the compose file
publishes, so the browser on the host can reach it. Docker Desktop's host
networking is not required.

Run the one-shot `auth` profile:

```sh
docker compose --profile auth run --rm --service-ports auth
```

It prints an authorization URL. Open it, sign in to the account from `.env`, and
approve access. When the flow succeeds, credentials are written to
`data/<account>/credentials.json` and the command exits.

> **No Docker Desktop?** Authorize on any Linux machine or inside WSL2 with the
> native package:
> ```sh
> sudo cloud-fuse auth <account>
> ```
> then copy that machine's
> `/var/lib/cloud-fuse/<account>/credentials.json` to
> `data/<account>/credentials.json`.

---

## 3. Start the stack

```sh
docker compose up -d
docker compose logs -f cloud-fuse
```

The log shows the daemon mounting the Drive and
`serve-with-smb: smbd is listening on port 445`.

---

## 4. Mount the share

The share is named **`google-drive`**. The shipped compose publishes SMB on
`127.0.0.1` only.

### macOS — the same Mac running Docker

Finder's *Connect to Server* uses the NetFS/kernel SMB client, which **cannot
mount a share served from the same machine**. Docker Desktop publishes the
container's port on the Mac's own address, so Finder reports *"The server may
not exist or it is unavailable at this time"* (`GetServerInfo failed` in
`NetAuthSysAgent` logs). The userspace `mount_smbfs` client has no such
restriction.

Use the helper, which mounts the share at `~/GoogleDrive`:

```sh
./docker/macos-mount.sh              # mount
open ~/GoogleDrive                   # browse in Finder; drag it to the sidebar
./docker/macos-mount.sh --unmount    # unmount
```

It reads `CLOUD_FUSE_SMB_SERVER`, `CLOUD_FUSE_SMB_SHARE`,
`CLOUD_FUSE_SMB_USER`, `CLOUD_FUSE_SMB_PASSWORD`, and
`CLOUD_FUSE_SMB_MOUNTPOINT` if you changed the defaults. For example:

```sh
CLOUD_FUSE_SMB_PASSWORD='your-password' ./docker/macos-mount.sh
```

To mount at login — and re-mount within a minute if the container restarts —
install the LaunchAgent:

```sh
./docker/macos-install-automount.sh              # install + start now
./docker/macos-install-automount.sh --uninstall  # remove
```

It writes `~/Library/LaunchAgents/local.cloud-fuse.mount.plist` and logs to
`~/Library/Logs/cloud-fuse-mount.log`.

### Windows — the same PC running Docker

Windows' own SMB server (`LanmanServer`) occupies port 445, so Docker cannot
publish the share until it is stopped (elevated PowerShell):

```powershell
Stop-Service -Name LanmanServer
```

Then map the share as the configured SMB user:

```powershell
net use Z: \\127.0.0.1\google-drive /user:cloudfuse *
# or:
#   File Explorer -> This PC -> Map network drive
#   Folder: \\127.0.0.1\google-drive
#   "Connect using different credentials": SMB_USER / SMB_PASSWORD from .env
```

Restore the host's SMB server when you no longer need the share:

```powershell
net use Z: /delete
Start-Service -Name LanmanServer
```

> **Alternative:** WSL2 supports FUSE natively. Installing the native package
> inside WSL2 and opening the mount through `\\wsl$\<distro>\...` avoids the
> port-445 conflict entirely.

### From another machine on the LAN

Change the port mapping in `docker-compose.yml` from `127.0.0.1:445:445` to
`445:445`, restart with `docker compose up -d`, then connect with the Docker
host's LAN address:

- macOS: `smb://<docker-host-lan-ip>/google-drive`
- Windows: `\\<docker-host-lan-ip>\google-drive`
- Log in as **Registered User** with `SMB_USER` / `SMB_PASSWORD`.

Exposing SMB on the LAN also exposes the Drive to anyone who can reach it, so
use a strong password and a firewall rule that restricts the port.

---

## Day-to-day operations

```sh
docker compose pull          # fetch a newer image
docker compose up -d         # recreate with the new image
docker compose logs -f cloud-fuse
docker compose down          # stop; the cache volume is preserved
docker compose down -v       # stop and delete the cache volume
```

The `cloud-fuse-state` volume holds the metadata store and content cache. It is
preserved across `down`, so evicted content is not re-downloaded after a restart
and pending uploads are not lost.

---

## How it works

```
Google Drive  ──HTTPS──▶  cloud-fuse daemon (privileged, /dev/fuse)
                                  │
                                  ▼
                           /mnt/drive (live FUSE mount)
                                  │
                                  ▼
                    Samba in the same container (vfs_fruit / vfs_catia)
                                  │  127.0.0.1:445
                                  ▼
                        macOS (mount_smbfs) / Windows Explorer
```

- The container is `privileged` and receives `/dev/fuse` so it can create the
  FUSE mount inside Docker's Linux VM.
- The daemon and Samba share one container, so Samba exports the *live* mount
  directly. A FUSE submount cannot be reliably propagated to a second container
  through a Docker volume.
- Samba runs `force user = root` because Cloud Fuse reports files as
  `root:root`; `create mask` / `directory mask` keep new files at `644` / `755`.
- `strict sync = no` keeps SMB flushes from blocking on the daemon's
  upload-completing `fsync`.

---

## Troubleshooting

### Finder says the server may not exist (same Mac)

Expected on the machine running Docker Desktop. Use `./docker/macos-mount.sh`
instead of Finder's *Connect to Server*, or connect from a different machine.

### Port 445 is already in use

Only one process may bind 445:

- macOS: turn off *System Settings → General → Sharing → File Sharing*.
- Windows: `Stop-Service -Name LanmanServer` (elevated).

Check the published port with `docker compose port cloud-fuse 445` and
`lsof -nP -iTCP:445 -sTCP:LISTEN` (macOS/Linux).

### Container exits with `license file missing`

The JWT must be at `data/licenses/<lower-case-account>.jwt`.

### Container exits with `credential source is not readable`

Run step 2 first; `data/<account>/credentials.json` must exist.

### The share mounts but every write fails

The daemon may have lost its Google OAuth session (for example after sleep).
Check its state:

```sh
docker compose exec cloud-fuse cloud-fuse \
  --config-dir /config --state-dir /var/lib/cloud-fuse \
  --runtime-dir /run/cloud-fuse status "$CLOUD_FUSE_ACCOUNT"
```

`state: needs-reauth` means the refresh token is no longer usable (Google
expires refresh tokens after 7 days while the OAuth client is still in
"Testing" mode). Re-authorize the running container — the compose file
publishes the fixed callback port 8765:

```sh
docker compose exec cloud-fuse cloud-fuse \
  --config-dir /config --state-dir /var/lib/cloud-fuse \
  --runtime-dir /run/cloud-fuse auth <account> \
  --listen 0.0.0.0:8765 --no-browser
```

Open the printed URL on the host. The browser's callback to
`http://127.0.0.1:8765/` is forwarded into the container, and a successful
authorization reloads the running daemon automatically. Do not pass
`--reload`; it only reloads an existing credential.

Alternatively, re-run the one-shot authorization from step 2 and recreate the
container:

```sh
docker compose --profile auth run --rm --service-ports auth
docker compose up -d --force-recreate
```

### Windows cannot access `\\127.0.0.1\google-drive`

Make sure `LanmanServer` is stopped, the container is running
(`docker compose ps`), and port 445 is published to `127.0.0.1`.

---

## Performance & cache tuning

The container inherits the core optimizations:
- **Fixed-size chunking**: content is streamed in bounded blocks on demand.
- **Read-ahead**: sequential reads prefetch ahead within a fixed byte budget,
  which helps video playback and large copies.
- **Non-blocking writes**: creations and edits return from the local dirty
  buffer; background workers upload asynchronously.
- **Samba `vfs_fruit`**: avoids `.DS_Store` / `._*` AppleDouble sidecars.

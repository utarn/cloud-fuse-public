# Cloud Fuse Packages

Cloud Fuse mounts a Google Drive account as an on-demand, read-write FUSE filesystem on Linux. File and directory changes apply locally immediately and synchronize to Drive in the background.

This repository hosts official GPG-signed RPM and DEB packages and package repositories for Cloud Fuse, plus the Docker Compose setup for macOS and Windows.

## Supported Distributions and Architectures

| Distribution | Version | Codename / Target | Architectures | Package Format |
|---|---|---|---|---|
| Rocky Linux | 9 | `el9` | `x86_64`, `aarch64` | RPM |
| Rocky Linux | 10 | `el10` | `x86_64`, `aarch64` | RPM |
| Fedora | 44 | `fc44` | `x86_64` | RPM |
| Ubuntu | 22.04 LTS | `jammy` | `amd64` (x86_64), `arm64` (aarch64) | DEB |
| Ubuntu | 24.04 LTS | `noble` | `amd64` (x86_64), `arm64` (aarch64) | DEB |
| Ubuntu | 26.04 | `resolute` | `amd64` (x86_64), `arm64` (aarch64) | DEB |
| Debian | 12 | `bookworm` | `amd64` (x86_64), `arm64` (aarch64) | DEB |
| Debian | 13 | `trixie` | `amd64` (x86_64), `arm64` (aarch64) | DEB |

---

## Windows & macOS (Docker)

Cloud Fuse runs in a privileged Linux container and exports the mounted Drive to
**Finder** and **File Explorer** over native SMB. The desktop image is
[`utarn/cloud-fuse:smb`](https://hub.docker.com/r/utarn/cloud-fuse)
(`linux/amd64`, `linux/arm64`); `utarn/cloud-fuse:latest` is the same daemon
without the SMB export. No macFUSE, WinFsp, or kernel extensions are needed.

```sh
git clone https://github.com/utarn/cloud-fuse-public.git
cd cloud-fuse-public
cp .env.example .env      # account + Google OAuth desktop-client credentials
mkdir -p data/licenses    # put <account>.jwt here
docker compose --profile auth run --rm --service-ports auth   # one-time Google authorization
docker compose up -d
```

On macOS, mount the share with `./docker/macos-mount.sh` (Finder cannot mount a
share served from the same Mac through Docker Desktop). On Windows, stop
`LanmanServer` and map `\\127.0.0.1\google-drive`. See
[DOCKER_MACOS_WINDOWS.md](DOCKER_MACOS_WINDOWS.md) for prerequisites, the
Google OAuth and license setup, LAN access, and troubleshooting.

---

## Ubuntu Repository Installation

Install the signing key and add the APT repository:

```sh
sudo apt-get install -y software-properties-common ca-certificates curl gpg
sudo install -d -m 0755 /etc/apt/trusted.gpg.d
curl -fsSL https://utarn.github.io/cloud-fuse-public/cloud-fuse.gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/trusted.gpg.d/cloud-fuse.gpg
sudo add-apt-repository "deb https://utarn.github.io/cloud-fuse-public/apt $(. /etc/os-release && echo $VERSION_CODENAME) main"
sudo apt update && sudo apt install cloud-fuse
```

The key is installed into `/etc/apt/trusted.gpg.d` because Ubuntu 22.04's
`add-apt-repository` cannot parse inline `[signed-by=...]` options. This keeps
the same command working on every supported Ubuntu release.

## Debian Repository Installation

Debian 12's `add-apt-repository` writes an empty sources file when APT uses
deb822 sources, and Debian 13 no longer ships `software-properties-common`.
Install the key and write the sources file directly:

```sh
sudo apt-get install -y ca-certificates curl gpg
sudo install -d -m 0755 /etc/apt/trusted.gpg.d
curl -fsSL https://utarn.github.io/cloud-fuse-public/cloud-fuse.gpg.key | sudo gpg --batch --yes --dearmor -o /etc/apt/trusted.gpg.d/cloud-fuse.gpg
echo "deb https://utarn.github.io/cloud-fuse-public/apt $(. /etc/os-release && echo $VERSION_CODENAME) main" | sudo tee /etc/apt/sources.list.d/cloud-fuse.list
sudo apt update && sudo apt install cloud-fuse
```

For the optional status monitor GUI:

```sh
sudo apt install cloud-fuse-gui
```

---

## Enterprise Linux (Rocky Linux 9 / 10) Repository Installation

Import the signing key and add the DNF repository:

```sh
sudo dnf install -y dnf-plugins-core
sudo rpm --import https://utarn.github.io/cloud-fuse-public/cloud-fuse.gpg.key
sudo dnf config-manager --add-repo https://utarn.github.io/cloud-fuse-public/rpm/cloud-fuse-el9.repo   # or cloud-fuse-el10.repo
sudo dnf install cloud-fuse
```

For the optional status monitor GUI:

```sh
sudo dnf install cloud-fuse-gui
```

---

## Licensing

Cloud Fuse requires an active license tied to the Google Drive account (email address) being mounted.

### 1. Purchase a License
You can purchase a license for your Google account at:
**[https://cloudfuse.scigrad.com/](https://cloudfuse.scigrad.com/)**

Once purchased, you will receive a license key (a signed compact JWT token).

### 2. Enter and Install the License
Install your license key using the `cloud-fuse license add` command (requires root / sudo):

```sh
sudo cloud-fuse license add <your-google-email> --key "<license-token>"
```

Alternatively, you can provide the token from a file or standard input:

```sh
# From a file:
sudo cloud-fuse license add <your-google-email> --file /path/to/license.jwt

# From standard input:
cat license.jwt | sudo cloud-fuse license add <your-google-email> -
```

### 3. Verify Installed Licenses
View installed licenses and verification status:

```sh
# List all installed licenses
sudo cloud-fuse license list

# Show detailed license information for an account
sudo cloud-fuse license show <your-google-email>

# Display the raw JWT token
sudo cloud-fuse license show <your-google-email> --raw
```

---

## Direct Download Installation (Release Assets)

If you prefer to download standalone packages directly from the GitHub Release (`v0.4.4`), you can download any package, its signature, and the public key:

Release page: [https://github.com/utarn/cloud-fuse-public/releases/tag/v0.4.4](https://github.com/utarn/cloud-fuse-public/releases/tag/v0.4.4)

### 1. Download the public signing key

```sh
curl -fsSL -O https://utarn.github.io/cloud-fuse-public/cloud-fuse.gpg.key
```

### 2. Verify the signing key fingerprint

```sh
gpg --show-keys cloud-fuse.gpg.key
```

Verify that the output displays fingerprint `922281C603F829A8D5D65832F23DDDAC7BC2AA3F`.

### 3. RPM Verification and Installation (Rocky Linux / Fedora)

RPM packages have cryptographic signatures embedded in their headers.

```sh
# Import the public signing key into the RPM database
sudo rpm --import cloud-fuse.gpg.key

# Verify package integrity and signature (e.g. el9, el10, or fc44)
rpm --checksig cloud-fuse-0.4.4-1.el9.x86_64.rpm

# Install package
sudo dnf install ./cloud-fuse-0.4.4-1.el9.x86_64.rpm
# Or on Fedora 44:
# sudo dnf install ./cloud-fuse-0.4.4-1.fc44.x86_64.rpm
# Optional GUI package:
# sudo dnf install ./cloud-fuse-gui-0.4.4-1.el9.x86_64.rpm
```

### 4. DEB Verification and Installation (Ubuntu / Debian)

DEB packages are verified using detached `.asc` OpenPGP signatures.

```sh
# Import public key into your GPG keyring
gpg --import cloud-fuse.gpg.key

# Verify package detached signature
gpg --verify cloud-fuse-0.4.4-<suite>-<arch>.deb.asc cloud-fuse-0.4.4-<suite>-<arch>.deb

# Install package (with dependencies)
sudo apt-get update
sudo apt-get install -y ./cloud-fuse-0.4.4-<suite>-<arch>.deb
# Optional GUI package:
# sudo apt-get install -y ./cloud-fuse-gui-0.4.4-<suite>-<arch>.deb
```

Where `<suite>` is one of `jammy`, `noble`, `resolute`, `bookworm`, `trixie`, and `<arch>` is `amd64` or `arm64`.

### Runtime Dependencies

- **`fuse3`**: Cloud Fuse requires `fuse3` (which provides `/dev/fuse` and `fusermount3`). It is declared as a package dependency and installed automatically by `apt` or `dnf`.
- **GUI Package (`cloud-fuse-gui`)**: Requires an active X11 or Wayland session, OpenGL / Mesa driver support, and standard font libraries.

---

## Package Signing Key

All releases and repository metadata are signed with the official project key:

| Attribute | Details |
|---|---|
| User ID | `Utharn Buranasaksee <utharn.b@rmutsb.ac.th>` |
| Key Type | RSA 4096-bit, sign-only (`[SC]`) |
| Fingerprint | `922281C603F829A8D5D65832F23DDDAC7BC2AA3F` |
| Expiration | 2031-10-21 |

To verify the key fingerprint independently:

```sh
gpg --show-keys cloud-fuse.gpg.key
```

The primary key fingerprint must match `922281C603F829A8D5D65832F23DDDAC7BC2AA3F` exactly.

---

## Package Lifecycle: Upgrade, Remove, and Purge

- **Install**: Installs the binary `/usr/bin/cloud-fuse`, systemd template unit `/usr/lib/systemd/system/cloud-fuse@.service` (or `/lib/systemd/system/cloud-fuse@.service`), man pages, and SELinux module (RPM) or AppArmor profile (DEB). Installation does **not** enable or start any Instance.
- **Upgrade**: Replaces binaries and issues a `systemctl try-restart` on active `cloud-fuse@<account>` services. Database migrations run automatically at startup and create a pre-upgrade backup (`metadata.db.pre-<version>`).
- **Remove**: Stops and disables running Instances, removes binaries, units, man pages, and security policies. **Preserves** configuration in `/etc/cloud-fuse/` and cache/state in `/var/lib/cloud-fuse/`.
- **Purge**: Removing the package (including `apt purge`) never deletes Google Drive authentication tokens or cached files. To permanently delete all local account data, configuration, cache, and credentials, run:
  ```sh
  sudo cloud-fuse purge <account-name>
  # or to purge all accounts:
  sudo cloud-fuse purge --all
  ```

---

## Documentation and Usage

For full instructions on configuring Google Cloud OAuth credentials, setting up accounts, mounting, and monitoring Cloud Fuse, see [HOW_TO_USE.md](https://github.com/utarn/linux-online-drive/blob/main/HOW_TO_USE.md).

# Big Sandbox

A Docker-based sandbox environment for running AI agents. Extends [simple-agent-sandbox](https://github.com/AlexAndrewsAI/simple-agent-sandbox) with additional mounts and configuration.

This repository is designed to be used in conjunction with the other repositories at https://github.com/AlexAndrewsAI?tab=repositories.

## Quick Start
1. **Copy Configs:** Copy the example files and edit to taste:
   ```bash
   cp config.example.yml config.yml
   cp docker-compose.example.yml docker-compose.yml
   ```
2. **Edit:** Uncomment/adjust mounts in `docker-compose.yml` and tools in `config.yml`
3. **Build:** `docker compose build`
4. **Run:** `docker compose run --rm sandbox`

## Tech Stack

| Component | Tool |
|-----------|------|
| Container Runtime | Docker & Docker Compose |
| Base Image | alexandrewsai/simple-agent-sandbox:latest |
| Config Format | YAML |
| Shell | Bash |
| Package Manager | npm, curl-based installers |
| VNC Server | x11vnc (with SSH tunneling support) |
| SSH Server | openssh-server (for secure VNC tunneling) |

## Project Structure

```
big-sandbox/
  ├── Dockerfile                    (Container build instructions)
  ├── docker-compose.example.yml    (Template — copy to docker-compose.yml)
  ├── docker-compose.yml            (Real compose file — gitignored)
  ├── config.example.yml            (Template — copy to config.yml)
  ├── config.yml                    (Real config — gitignored)
  ├── scripts/
  │   ├── installer.sh              (Reads config.yml, runs install commands)
  │   ├── run.sh                    (Start interactive sandbox shell)
  │   ├── build.sh                  (Build the Docker image)
  │   └── start-vnc.sh              (Launch VNC/desktop server)
  ├── persist/                      (Mounted volume for persistent state, gitignored)
  └── README.md
```

## Essential Directives

### Configuration Management
- **Real files are gitignored:** Both `config.yml` and `docker-compose.yml` are real config files that live in `.gitignore`. The `*.example.*` files are the tracked templates.
- **Adding/Removing Tools:** Edit `config.yml` — add/comment out entries under `install:`
- **Install Format:** Each key under `install:` maps to a shell command string executed by `scripts/installer.sh`
- **Config-Driven:** All tool installation is driven by `config.yml`; do not hardcode installs in the Dockerfile
- **Mounts in Compose:** Volume mounts are defined in `docker-compose.yml`, not parsed from config.yml by helper scripts

### Docker Workflow
- **Real compose over helpers:** The source of truth for volumes, env, and service config is `docker-compose.yml`. The helper scripts (`run.sh`, `build.sh`) are thin wrappers around `docker compose`.
- **Rebuild After Config Changes:** If `config.yml` changes, rebuild with `docker compose build`
- **Persistent State:** All persistent data lives in `./persist` on the host, mounted at `/persist` in the container
- **No State in Image:** Do not store credentials, keys, or session data in the Docker image layers

### Operational Constraints
- **No Interactive Prompts:** Mock or bypass any interactive commands in install scripts
- **No Git Operations:** Don't stage/commit unless explicitly requested
- **Keep Instructions Current:** Update "Tech Stack," "Project Structure," and "Workflow Commands" if the Dockerfile, config format, or core tooling changes

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [yq](https://github.com/mikefarah/yq) (used by build.sh to read config.yml)
- [rsync](https://rsync.samba.org/) (optional - only needed if using persist sync feature in config.yml)

## Security Considerations

This sandbox environment uses permissive security settings for convenience in development and testing:

- **Passwordless sudo:** The `sandbox` user has `NOPASSWD` sudo access (`sandbox ALL=(ALL) NOPASSWD:ALL`) to enable Xvfb startup and filesystem operations without interactive prompts
- **SSH password authentication:** SSH server is configured with password authentication enabled (default password: `sandbox`)
- **Root SSH login:** `PermitRootLogin yes` is set in SSH config for debugging convenience
- **Default credentials:** Both SSH and VNC use the default password `sandbox` unless changed

These settings are intentional for a local development sandbox but **should not be used in production environments** without modification. For production use:

1. Change default passwords using `passwd` inside the container
2. Disable password authentication and use SSH keys only
3. Remove `PermitRootLogin yes` from SSH config
4. Restrict sudo access to specific commands only
5. Use proper SSH host key verification (remove `-o StrictHostKeyChecking=no`)
6. Run the container in an isolated network environment
7. Consider using Docker secrets or environment variables for sensitive data

## External Dependencies

The Dockerfile depends on external resources that may change or become unavailable:

- **useful-shell-scripts repository:** Cloned from `https://github.com/AlexAndrewsAI/useful-shell-scripts.git` during build
- **AppImage downloads:** Downloads tools from GitHub releases (e.g., Cryptomator)
- **Base image:** Pulls `alexandrewsai/simple-agent-sandbox:latest` from Docker Hub

If these external resources change or become unavailable, builds may fail. Consider:

1. Pinning specific commit hashes for git clones
2. Using specific release versions for AppImage downloads
3. Pinning base image tags instead of `latest`
4. Mirroring critical dependencies internally for production builds

## Workflow Commands

```bash
cp config.example.yml config.yml                # Create real config from template
cp docker-compose.example.yml docker-compose.yml # Create real compose from template
scripts/build.sh                                 # Build (or: docker compose build)
scripts/run.sh                                   # Interactive shell + VNC desktop (ports published)
scripts/run.sh --build                           # Rebuild image, then run
docker compose exec sandbox bash                 # Attach a second shell to a running container
docker compose down                              # Stop the container
```

## Desktop Access (VNC)

The container can run a lightweight desktop environment with **Xvfb** (virtual framebuffer), **XFCE** (desktop environment), and **x11vnc** (VNC server) for displaying browser windows or GUIs from AI agents.

### Prerequisites

Xvfb, x11vnc, chromium, and XFCE install automatically from the `apt:` list in `config.yml` during `docker compose build`.

**On the host**, install a VNC client such as:

- **Linux:** `sudo apt install tigervnc-viewer` (or Remmina, Vinagre)
- **macOS:** [TigerVNC](https://tigervnc.org/) or [RealVNC](https://www.realvnc.com/)
- **Windows:** [TigerVNC](https://tigervnc.org/) or [RealVNC](https://www.realvnc.com/)

### First Run — Set a VNC Password

The first time VNC starts, it will prompt you to set a password:

```bash
scripts/run.sh
# When you see: "No VNC password found. Please set one now:"
# Type your VNC password and confirm.
```

The password is stored in `./persist/.vnc/passwd` and persists across restarts.

### Connect to the Desktop

🔒 **Automatic SSH Tunneling:** The `run.sh` script automatically sets up an encrypted SSH tunnel for secure VNC access. Note that VNC clients may still show security warnings due to the inherent nature of the VNC protocol (it lacks built-in encryption), but your connection is encrypted at the network layer via SSH. You can safely dismiss these warnings when using SSH tunneling.

#### Automated Secure Connection (Recommended)

Simply start the container with the run script:

```bash
scripts/run.sh
```

The script will:
1. Automatically establish an SSH tunnel in the background
2. Wait for the container to be ready (with retries)
3. Display connection status messages
4. Enable encrypted VNC access on `localhost:5902` (port 5902 used to avoid conflict with Docker's port mapping)

**Connect your VNC client to `localhost:5902`** - the connection is encrypted via SSH at the network layer.

#### Manual SSH Tunnel (If Needed)

If the automatic tunnel fails or you prefer manual setup:

```bash
sshpass -p 'sandbox' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -L 5902:localhost:5901 -p 2222 sandbox@localhost
```

Then connect your VNC client to `localhost:5902`.

> **Why port 5902?** The SSH tunnel uses port 5902 locally to avoid conflict with Docker's port mapping (which publishes port 5901). This ensures your VNC traffic goes through the encrypted SSH tunnel rather than directly to the container.

> **Note:** The default password is `sandbox`. You can change it inside the container with `passwd`. For full host key verification (recommended for production), remove the `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null` options.

#### Direct Connection (Unencrypted - Not Recommended)

To disable automatic SSH tunneling and use direct (unencrypted) VNC access:

```bash
scripts/run.sh --no-ssh-tunnel
```

> **⚠️ Direct connections are unencrypted** and will show security warnings in VNC clients like TigerVNC. Even with SSH tunneling, some clients may still show warnings due to the VNC protocol's inherent lack of encryption.

**Benefits of SSH tunneling:**
- ✅ Encrypts all VNC traffic at the transport layer
- ✅ Uses standard SSH authentication
- ✅ Works with any VNC client
- ✅ More secure than direct VNC access
- ✅ Prevents network eavesdropping

> **Important Note about VNC Security Warnings:** The VNC protocol itself is inherently unencrypted, so clients like TigerVNC may still show security warnings even when using SSH tunneling. This is expected behavior - SSH tunneling encrypts the network connection (transport layer), but the VNC protocol doesn't have built-in encryption. Your connection is still more secure than direct VNC access, as the network traffic is encrypted via SSH. You can safely dismiss the warning when using SSH tunneling.

> **Port 5902 vs 5901:** The SSH tunnel forwards to local port 5902 to avoid conflict with Docker's port mapping (which also publishes port 5901). Connecting to localhost:5902 ensures your traffic goes through the encrypted SSH tunnel, while localhost:5901 would be a direct (unencrypted) connection.

**Default credentials:**
- SSH username: `sandbox`
- SSH password: `sandbox` (can be changed inside the container with `passwd`)

### SSH Key Authentication (Optional Enhancement)

For passwordless SSH tunneling, you can set up SSH key authentication:

1. **Generate an SSH key pair** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/sandbox_key
   ```

2. **Copy your public key to the container:**
   ```bash
   sshpass -p 'sandbox' ssh-copy-id -i ~/.ssh/sandbox_key.pub -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 sandbox@localhost
   ```

3. **Update the run.sh script** to use your SSH key by modifying the SSH command to include `-i ~/.ssh/sandbox_key`.

> **Note:** The automated tunnel uses password authentication by default and forwards to local port 5902. For key-based auth, you'll need to modify the script or use manual tunneling.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `Connection refused` on port 5901 | Make sure you used `scripts/run.sh` (which adds `--service-ports`). VNC also needs ~3s to initialize. Check `docker compose logs sandbox`. |
| Prompted for VNC password every time | Run `x11vnc -storepasswd /persist/.vnc/passwd` inside the container to save a persistent password. |
| Blank screen / no desktop | XFCE starts automatically. If the screen is empty, launch an app manually: `DISPLAY=:1 chromium &` from the container shell. |
| SSH connection refused | Ensure port `2222` is exposed in `docker-compose.yml`. Check if SSH is running: `docker compose exec sandbox ps aux | grep sshd`. SSH server is installed in the Dockerfile by default. For manual testing, use: `sshpass -p 'sandbox' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 sandbox@localhost` |
| SSH host key prompt | The automated tunnel uses `-o StrictHostKeyChecking=no` to avoid interactive prompts. If you see host key verification prompts, use the manual SSH command with the same options or add the container's host key to your known_hosts. |
| Automatic SSH tunnel fails | The script retries 10 times with 2-second delays. If it still fails, the container might not be starting properly. Check `docker compose logs sandbox` and ensure SSH server is running inside the container. The script uses `sshpass` with the default password `sandbox` and `-o StrictHostKeyChecking=no` to avoid interactive prompts. |
| VNC security warning persists | This is expected behavior. VNC clients like TigerVNC may show security warnings even with SSH tunneling because the VNC protocol itself is inherently unencrypted. SSH tunneling encrypts the network connection (transport layer), but the VNC protocol lacks built-in encryption. Your connection is still more secure than direct VNC access, and you can safely dismiss the warning when using SSH tunneling. |
| rsyslog imklog warnings | These are expected in containers and can be ignored. The warning "cannot open kernel log (/proc/kmsg)" is normal because containers don't have access to kernel logs. |

## Environment Variables

| Variable | Value                       | Description                                  |
| -------- | --------------------------- | -------------------------------------------- |
| `HOME`   | `/persist`                  | Sets the home directory inside the container |
| `PATH`   | `/home/sandbox/.local/bin:/persist/.local/bin:/usr/local/bin:/usr/bin:/bin:/home/sandbox/node_modules/cline/bin` | Ensures installed binaries are available     |

## Notes

- The `./persist` directory is gitignored and should not be committed.
- The container runs `bash` by default, providing an interactive shell.
- Tool installation is driven by `config.yml`. Each key under `install:` maps directly to its install command string.
- Volume mounts are defined in `docker-compose.yml` — the single source of truth. Helper scripts are thin wrappers and do not duplicate mount logic.

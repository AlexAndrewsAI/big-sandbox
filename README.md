# Big Sandbox

A Docker-based sandbox environment for running AI agents. Extends [simple-agent-sandbox](https://github.com/AlexAndrewsAI/simple-agent-sandbox) with additional mounts and configuration.

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
- [rsync](https://rsync.samba.org/) (used by build.sh to sync persist from another sandbox)
- [yq](https://github.com/mikefarah/yq) (used by build.sh to read config.yml)

## Workflow Commands

```bash
cp config.example.yml config.yml                # Create real config from template
cp docker-compose.example.yml docker-compose.yml # Create real compose from template
scripts/build.sh                                 # Build (or: docker compose build)
scripts/run.sh                                   # Quick interactive shell (no desktop)
scripts/run.sh --desktop                         # Interactive shell + VNC desktop
scripts/run.sh --desktop -d                      # Detached desktop (attach later with 'exec bash')
```

## Desktop Access (VNC)

The container can run a lightweight desktop environment with **Xvfb** (virtual framebuffer), **Fluxbox** (window manager), and **x11vnc** (VNC server) for displaying browser windows or GUIs from AI agents.

### Prerequisites

Xvfb, x11vnc, chromium, and fluxbox install automatically from the `apt:` list in `config.yml` during `docker compose build`.

**On the host**, install a VNC client such as:

- **Linux:** `sudo apt install tigervnc-viewer` (or Remmina, Vinagre)
- **macOS:** [TigerVNC](https://tigervnc.org/) or [RealVNC](https://www.realvnc.com/)
- **Windows:** [TigerVNC](https://tigervnc.org/) or [RealVNC](https://www.realvnc.com/)

### First Run — Set a VNC Password

The first time VNC starts, it will prompt you to set a password:

```bash
scripts/run.sh --desktop
# When you see: "No VNC password found. Please set one now:"
# Type your VNC password and confirm.
```

The password is stored in `./persist/.vnc/passwd` and persists across restarts.

### Connect to the Desktop

Port `5901` is exposed in `docker-compose.yml`. Use the helper script:

**Interactive shell with desktop**

```bash
scripts/run.sh --desktop
# Wait ~3 seconds for VNC to initialize
# Connect to localhost:5901 with your VNC client
```

**Detached (desktop only)**

```bash
scripts/run.sh --desktop -d
# Connect to localhost:5901 with your VNC client
# To attach a shell later:  docker compose exec sandbox bash
# To stop:                  docker compose down
```

> **Why `--service-ports`?** `docker compose run` does not publish ports by default.
> The `--desktop` flag adds `--service-ports` so port 5901 is reachable from your host.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `Connection refused` on port 5901 | Make sure you used `scripts/run.sh --desktop` (adds `--service-ports`). VNC also needs ~3s to initialize. Check `docker compose logs sandbox`. |
| Prompted for VNC password every time | Run `x11vnc -storepasswd /persist/.vnc/passwd` inside the container to save a persistent password. |
| Blank screen / no window manager | Fluxbox starts automatically. If the screen is empty, launch an app manually: `DISPLAY=:1 chromium-browser &` from the container shell. |

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

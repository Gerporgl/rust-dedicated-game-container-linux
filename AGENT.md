# AGENT.md - Rust Dedicated Game Container

## Project Overview

A Docker/podman/LXC container for running a Rust dedicated game server on Ubuntu 24.04 LTS with systemd init, optimized for Proxmox VE and LXC environments.

## System Architecture

```
systemd ─┬─bash ─┬─RustDedicated
         │        └─auto_updater
         ├─nginx ───nginx
         └─systemd-journal
```

### Process Breakdown

| Process | Purpose |
|---------|---------|
| **systemd (init)** | Full init system for proper service management |
| **rust-server.service** | systemd unit that runs the actual Rust game server |
| **nginx** | Serves webrcon static pages on port 8080 |
| **shutdown_app** | Node.js app that sends RCON "quit" command before shutdown |
| **restart_app** | Node.js app that manages server restarts during updates |
| **scheduler_app** | Node.js app that periodically checks for updates every 5 minutes |
| **heartbeat_app** | Node.js app for health monitoring |
| **rcon** | CLI RCON wrapper (linked to rcon_app/app.js) |

## Directory Structure

```
.
├── configs/                    # Configuration files
│   ├── carbon/                # Carbon plugin configs
│   ├── html/                  # Webrcon frontend (index.html, webrcon.tar.xz)
│   ├── nginx_rcon.conf        # Nginx configuration
│   ├── rust-server.service    # systemd service unit
│   ├── rust.default.env       # Default game configuration
│   ├── sshd_config            # SSH daemon configuration
│   └── install.txt            # SteamCMD install script
├── default_rust_data_overrides/ # Default overrides for steamcmd data
├── node_apps/                  # Node.js helper applications
│   ├── heartbeat_app/
│   ├── rcon_app/              # CLI RCON interface
│   ├── restart_app/           # Server restart coordinator
│   ├── scheduler_app/         # Update checker scheduler
│   └── shutdown_app/          # Graceful shutdown handler
├── scripts/                    # Game server scripts
│   ├── rust-game              # Main entrypoint script
│   ├── rust_motd              # Server MOTD display
│   ├── fix_conn.sh            # Webrcon patching
│   ├── update_check.sh        # Steam update checker
│   ├── stop-rust              # Shutdown script
│   ├── cat_authkeys.sh        # SSH key aggregator
│   └── chown_steam.sh         # Ownership fixer
├── run.sh                      # Main container launcher
├── build.sh                     # Docker image builder
└── run_local.sh                # Local run without building
```

## Core Configuration Files

### 1. `configs/rust.default.env`
Main game server configuration (mounted at runtime, regenerated on restart):

| Variable | Default | Description |
|----------|---------|-------------|
| `RUST_SERVER_STARTUP_ARGUMENTS` | See file | Server launch arguments |
| `RUST_RCON_PASSWORD` | "does not matter" | Auto-generated on start |
| `RUST_SERVER_NAME` | "Pure Rust Server" | Server display name |
| `RUST_SERVER_MAXPLAYERS` | 100 | Player limit |
| `RUST_CARBON_ENABLED` | 1 | Carbon plugin framework |
| `RUST_CARBON_BRANCH` | "" | Carbon branch (e.g., linux) |
| `RUST_UPDATE_BRANCH` | public | Steam update branch |
| `RUST_SERVER_WORLDSIZE` | 4000 | Default map size |

### 2. `configs/rust-server.service`
systemd unit configuration:
```ini
[Service]
ExecStart=/app/rust-game
ExecStop=/app/stop-rust
Type=exec
User=steam
Restart=always
RestartSec=1
```

## User Accounts

| User | UID | Purpose |
|------|-----|---------|
| **root** | 0 | System admin, SSH access |
| **steam** | 1000 | Game server process owner |

### Privileged Commands
```bash
# Sudoers configured for steam user:
# - /app/cat_authkeys.sh (read SSH keys)
# - /app/chown_steam.sh (fix file ownership)
```

## Key Scripts

### `/app/rust-game` - Main Entry Point
- Sets up SSH key aggregation (pulls root keys for steam login)
- Copies default overrides to `steamcmd/rust/`
- Generates random RCON password and world seed if not mounted
- Displays current configuration before starting
- Installs steamcmd and Rust game files
- Traps SIGINT/SIGTERM for graceful shutdown

### `/app/install.txt` - SteamCMD Script
```bash
# Installs Rust on first run, updates via steamcmd + app_info_update
+runscript /app/install.txt
```

### `/app/update_check.sh` - Update Checker
- Runs every 5 minutes via scheduler_app
- Compares current build.id with Steam's latest build ID
- If update available: notifies players → kicks all → restarts server
- Lock-based to prevent concurrent updates

## Ports

| Port | Protocol | Purpose | Bind Address |
|------|----------|---------|--------------|
| 2222 | TCP | SSH (remapped from 22) | 127.0.0.1 |
| 28015 | UDP | Game server | All |
| 28016 | UDP | Query server | All |
| 28017 | TCP | Dedicated app | All |
| 28666 | TCP | RCON | 127.0.0.1 |
| 8080 | TCP | Webrcon UI | 127.0.0.1 |

## Node.js Helper Apps

### restart_app/app.js
- Sends in-game notifications (5-min countdown)
- Kicks all players with status message
- Graceful server termination via RCON "quit"
- Force kill after 2 minutes if server unresponsive

### rcon_app/app.js
- CLI interface for RCON commands
- Interactive mode: `rcon -i`
- Chat filtering: `rcon -f chat`
- Live chat view: `rcon -f chat -f generic`
- Timeout option: `-t 1000`

Example commands:
```bash
rcon playerlist           # Player list
rcon -it                  # Interactive mode
rcon -f chat              # Filter for chat messages only
rcon ban 12345             # Ban player
rcon say Hello             # Server announcement
```

## SSH Configuration

**sshd_config**:
- Password authentication: disabled
- Key-based authentication only (configured at container creation)
- PAM: enabled
- No X11 forwarding

**Authorized keys setup** (run once per container):
```bash
# Example: add your public key to run_with_ssh.sh
# Container orchestrators (Proxmox LXC) set this at build time
```

## Logs

### Real-time monitoring
```bash
# View live logs with timestamps
journalctl -u rust-server -f

# Grab all logs
journalctl -u rust-server | cat

# Normal view
journalctl -u rust-server
```

### RCON commands inside container
```bash
rcon players              # Quick player list
rcon -it                  # Full interactive mode
```

## Running the Container

### Quick Start
```bash
./run.sh
# Prompts for root password, creates rust_data/, starts container
```

### Build Image Locally
```bash
./build.sh           # Build only
./build_and_run.sh   # Build and run
```

### Container Environment Variables
```bash
IMAGE_NAME=ghcr.io/gerporgl/rust-server:latest

# Port mappings:
-p 127.0.0.1:2222:22   # SSH
-p 28015:28015/udp     # Game
-p 28016:28016/udp     # Query
-p 28017:28017         # App
-p 127.0.0.1:28666:28666 # RCON
-p 127.0.0.1:8080:8080   # Webrcon
```

## rcon Command Reference

```bash
# Basic usage
rcon <command>

# Interactive session
rcon -it

# Filter output types
rcon -f chat          # Only chat messages
rcon -f generic       # Only generic/announcement messages
rcon -f any           # All message types
rcon -f chat -f generic # Multiple filters

# Options
-t <ms>    Timeout (default: 1000)
-i         Interactive mode
-s         Silent mode (no output on error)
-d         Debug mode

# Examples
rcon kick 12345
rcon ban 67890
rcon setday 100
rcon weather rain
rcon god On
```

## Common Tasks

### View current configuration
```bash
# Inside container, check rust.env
cat /home/steam/steamcmd/rust/rust.env

# See systemd status
systemctl status rust-server
```

### Emergency restart
```bash
# Via systemd (restarts with exponential backoff)
systemctl restart rust-server

# Manual RCON command
rcon quit
```

### Database migrations
```bash
# The server handles migrations automatically on startup
# Logs appear in journalctl
journalctl -u rust-server -f | grep -i migrate
```

## Troubleshooting

### Server won't start
1. Check permissions: `ls -la /home/steam/steamcmd/rust/`
2. Verify RCON password: check rust.env
3. Look at logs: `journalctl -u rust-server --no-pager`

### Webrcon not connecting
1. Run `./fix_conn.sh` inside container to patch connection script
2. Verify port 8080 is accessible
3. Check nginx config: `systemctl status nginx`

### Update loop
1. Check `build.id` matches Steam's current build
2. Verify network connectivity to Steam servers
3. Manually trigger update: edit RUST_UPDATE_BRANCH in rust.env

## Security Notes

- RCON on port 28666 is **not secure** - bind to localhost only
- Webrcon on port 8080 is **not secure** - bind to localhost only
- SSH requires key-based authentication (no passwords)
- Root password is set at container creation (not baked in image)

## Dependencies

| Component | Version | Purpose |
|-----------|---------|---------|
| Ubuntu | 24.04 LTS | Base OS |
| Node.js | 24 | Helper apps |
| nginx | latest | Webrcon web server |
| steamcmd | latest | Game installer/updater |
| systemd | latest | Init system |
| OpenSSL | latest | TLS for RCON/webrcon |

## Environment Variables Reference

### Server Configuration
```
RUST_SERVER_STARTUP_ARGUMENTS
RUST_SERVER_PORT
RUST_SERVER_QUERYPORT
RUST_APP_PORT
RUST_RCON_PORT
RUST_RCON_PASSWORD
RUST_SERVER_NAME
RUST_SERVER_DESCRIPTION
RUST_SERVER_SEED
RUST_SERVER_WORLDSIZE
RUST_SERVER_MAXPLAYERS
RUST_UPDATE_BRANCH
```

### Carbon Plugin
```
RUST_CARBON_ENABLED      # 1 or 0
RUST_CARBON_UPDATE_ON_BOOT  # 1 or 0
RUST_CARBON_BRANCH       # e.g., "linux"
```

### Update Controls
```
RUST_UPDATE_CHECKING      # 1 to enable auto-updates
RUST_HEARTBEAT            # 1 or 0
RUST_SERVER_SAVE_INTERVAL # Seconds between saves (default: 600)
```

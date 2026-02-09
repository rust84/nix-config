# nix-config

[![built with nix](https://img.shields.io/badge/built_with_nix-blue?style=for-the-badge&logo=nixos&logoColor=white)](https://builtwithnix.org)

Fully reproducible, flake-based NixOS configuration managing multiple hosts, user environments, and secrets.

## Repository structure

```
.
├── flake.nix              # Flake definition (inputs, outputs, system configs)
├── flake.lock             # Pinned dependency versions
├── lib/
│   └── mkSystem.nix       # Helper that wires up a NixOS host with home-manager + sops
├── hosts/
│   ├── _modules/          # Shared NixOS modules (services, filesystems, common settings)
│   ├── duriel/            # Production server (ZFS NAS, Samba, NFS, monitoring)
│   ├── playground/        # Lab host (Blocky DNS, 1Password Connect, Podman)
│   └── bootstrap/         # Minimal installer image (disko, SSH-only)
├── homes/
│   ├── _modules/          # Shared home-manager modules (shell, editor, security)
│   └── russell/           # User config, per-host overrides, user secrets
├── overlays/              # Nixpkgs overlays (unstable channel, rust toolchain)
├── pkgs/                  # Custom packages (NixVim build)
└── .taskfiles/            # Task runner definitions (build, deploy, sops)
```

## Flake inputs

All pinned to **nixos-24.05** (June 2024). Do not run `nix flake update` without checking for breaking changes.

| Input | Purpose |
|---|---|
| `nixpkgs` (24.05) | Base package set |
| `nixpkgs-unstable` | Bleeding-edge packages (exposed as `pkgs.unstable`) |
| `home-manager` (24.05) | Declarative user environments |
| `nixvim` (24.05) | Neovim configuration as Nix |
| `sops-nix` | Age-encrypted secrets at build time |
| `rust-overlay` | Rust toolchain overlay |
| `nix-inspect` | Nix store inspection tool |

## Hosts

### duriel (production)

Primary server. Intel CPU, EXT4 root, ZFS pool (`tank`).

**Network:** `10.20.0.227/24`, DHCP, firewall disabled

**Services:**
- **Samba** -- shares `Docs`, `Media`, `Paperless` from `/tank/`, allows `10.20.0.0/24` and `10.20.1.0/24`
- **NFS** -- exports from ZFS pool
- **ZFS** -- monthly auto-scrub, trim enabled
- **smartd + smartctl-exporter** (`:9633`) -- disk health monitoring
- **node-exporter** (`:9100`) -- Prometheus system metrics
- **OpenSSH** -- key-only auth, no root login

### playground (lab)

Experimental/testing host. Intel CPU, EXT4 root.

**Services:**
- **Blocky** (`:53`, API `:4000`) -- DNS proxy with ad-blocking, upstream Cloudflare TLS
- **Chrony** -- NTP sync
- **1Password Connect** (`:8080`/`:8081`) -- runs in Podman
- **Podman** -- Docker-compatible container runtime
- **cfdyndns** -- Cloudflare dynamic DNS updates every 5 min
- **OpenSSH**, **node-exporter**

### bootstrap

Minimal NixOS installer config with disko disk layout (NVMe + LVM + ext4). SSH-only access with root key.

## Module system

### How it works

`lib/mkSystem.nix` composes each host from three layers:

1. **Common modules** (`hosts/_modules/common/`) -- locale (`en_GB.UTF-8`, `Europe/London`), Nix settings (flakes, GC, cachix substituters), fish shell
2. **NixOS modules** (`hosts/_modules/nixos/`) -- users, sops, nix GC schedule, filesystem support, and all service modules
3. **Host-specific config** (`hosts/<hostname>/`) -- hardware, enabled services, host secrets

### Available service modules

Each service lives in `hosts/_modules/nixos/services/<name>/` and is toggled via `config.modules.services.<name>.enable`.

| Module | Port(s) | Notes |
|---|---|---|
| `openssh` | 22 | Hardened (no password, no root) |
| `samba` | 139, 445 | SMB shares with subnet ACL |
| `nfs` | 2049 | TCP only |
| `blocky` | 53, 4000 | DNS proxy + ad-blocking |
| `bind` | 53 | BIND DNS server |
| `dnsdist` | configurable | DNS load balancer |
| `chrony` | 123 | NTP server/client |
| `nginx` | 80, 443 | Reverse proxy with ACME (Cloudflare DNS) |
| `k3s` | 6443 | Lightweight Kubernetes (server mode) |
| `podman` | -- | Container runtime with Docker compat |
| `minio` | configurable | S3-compatible storage with optional nginx frontend |
| `onepassword-connect` | 8080, 8081 | 1Password API/sync in Podman |
| `cfdyndns` | -- | Cloudflare dynamic DNS |
| `node-exporter` | 9100 | Prometheus node metrics |
| `smartd` | -- | Disk health monitoring |
| `smartctl-exporter` | 9633 | S.M.A.R.T. metrics for Prometheus |

## Home Manager

User `russell` is configured via `homes/russell/` with per-host overrides in `homes/russell/hosts/`.

**Enabled modules:**
- **Shell:** fish (with plugins), starship prompt (Catppuccin theme), zoxide, bat, btop, go-task, common CLI utilities
- **Editor:** Neovim via NixVim (custom build exposed as a flake package)
- **Git:** Signing with GPG key `5D560D07A4694C2F`, default branch `main`, gh CLI
- **SSH client:** ControlMaster multiplexing, agent forwarding to `*.internal` hosts
- **GPG:** gpg-agent with platform-appropriate pinentry

## Secrets

Managed with [sops-nix](https://github.com/Mic92/sops-nix) using **age** encryption.

**Keys** (defined in `.sops.yaml`):
- `hosts_andariel` -- host key
- `host_duriel` -- host key
- `user_russell` -- personal key

All `*.sops.yaml` files are encrypted to all three keys.

**Per-host secrets:**
- `duriel`: user password hash
- `playground`: user password hash, 1Password credentials, Cloudflare API token + DDNS records

**Age key location on hosts:** `~/.config/age/keys.txt` (auto-generated from SSH host keys by sops module)

## Deploying

### Prerequisites

`nix` must be available on the machine running the commands (or run directly on the target host). The Taskfile commands use `nixos-rebuild` with `--build-host` and `--target-host` over SSH.

### Build without applying (dry run)

```console
task nix:build-nixos host=duriel
```

Runs `nixos-rebuild build --flake .#duriel` on the remote host. Compiles the config but does **not** activate it.

### Apply

```console
task nix:apply-nixos host=duriel
```

Runs `nixos-rebuild switch --flake .#duriel`. Only changed services restart.

### Manual deployment (no local nix)

If nix isn't installed locally, rsync the repo to the target host and build there:

```console
rsync -avz --exclude='.git' ~/repos/nix-config/ russell@duriel.internal:~/repos/nix-config/
ssh russell@duriel.internal
cd ~/repos/nix-config && git init && git add -A && git commit -m "sync"
sudo nixos-rebuild build --flake .#duriel    # dry run
sudo nixos-rebuild switch --flake .#duriel   # apply
```

### Rollback

```console
ssh russell@duriel.internal 'sudo nixos-rebuild switch --rollback'
```

Or select a previous generation from the bootloader.

## Networking

| Subnet | Purpose |
|---|---|
| `10.20.0.0/24` | Primary network |
| `10.20.1.0/24` | Secondary network |

**Internal domain:** `russhome.xyz` (also `.internal` suffix for SSH)

**DNS resolution:** Blocky on playground forwards to Cloudflare (`1.1.1.1` TLS), with conditional forwarding to `10.20.0.1:53` for `russhome.xyz` and reverse DNS.

**ACME/TLS:** Certificates via Cloudflare DNS-01 challenges, email `postmaster@russhome.xyz`.

## Adding overlays

Add individual nix files to `./overlays/`:

```nix
final: prev: {
    hello = (prev.hello.overrideAttrs (oldAttrs: { doCheck = false; }));
}
```

## SOPS key rotation

Re-encrypt all secrets after adding or removing a key in `.sops.yaml`:

```console
task sops:re-encrypt
```

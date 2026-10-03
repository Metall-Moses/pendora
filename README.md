# Pendora <img src="assets/logo.svg" width="34" height="34" alt="Pendora" style="vertical-align: middle;" />

[![Fedora](https://img.shields.io/badge/Fedora-51A2DA?style=flat-square&logo=fedora&logoColor=white)](https://fedoraproject.org/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Lua](https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://www.lua.org/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![QEMU/KVM](https://img.shields.io/badge/QEMU%2FKVM-FF6600?style=flat-square&logo=qemu&logoColor=white)](https://www.qemu.org/)
[![Kali Tools](https://img.shields.io/badge/Kali%20Tools-557C94?style=flat-square&logo=kalilinux&logoColor=white)](https://www.kali.org/tools/)
[![Sway](https://img.shields.io/badge/Sway-000000?style=flat-square&logo=sway&logoColor=white)](https://swaywm.org/)
[![Status](https://img.shields.io/badge/Status-Beta-orange?style=flat-square)](https://github.com/sec-moose/pendora)
[![Repo Size](https://img.shields.io/github/repo-size/sec-moose/pendora?style=flat-square)](https://github.com/sec-moose/pendora)

> 🚀 **Project Status: Beta Stage**  
> Pendora has officially advanced to **Beta**. Core deployment profiles (Basic GNOME Pentest, Sway Dynamic Desktop, and Full End-to-End Installation) have been verified on Fedora Workstation VMs. Continuous testing is actively underway to further test tools, upstream suites, container interactions, and virtualization environments.

> ⚠️ **Disclaimer & Notice**  
> * **AI-Assisted Development**: Artificial intelligence (AI) has been utilized for parts of this project, including code generation, deployment scripts, configuration templates, and documentation.  
> * **Third-Party & Vendor Scripts**: Certain upstream modules fetch and execute installation scripts directly from official vendor sources (notably SysReptor's installer at [`https://docs.sysreptor.com/install.sh`](https://docs.sysreptor.com/install.sh)). Users are strongly encouraged to inspect and read through all scripts thoroughly before executing them.  
> * **Use Entirely at Your Own Risk**: This project is provided "as is" without warranty of any kind. The creator assumes no responsibility or liability for third-party scripts, remote downloads, system misconfigurations, or data loss resulting from the use of this repository. By using, cloning, or running this project, you explicitly acknowledge and accept this.
**Pendora** is a modular installation framework and configuration template designed to transform a standard **Fedora Linux** installation into a penetration testing and security assessment virtual machine.

It brings the toolset, workflows, and aesthetics of Kali Linux to Fedora's modern ecosystem (Wayland, RPM/DNF, systemd) using a modular, human-editable list structure.

---

## Architecture

Pendora organizes tooling, services, and configuration into four dedicated tiers:

```
┌────────────────────────────────────────────────────────────────────────┐
│                                PENDORA                                 │
├───────────────────┬───────────────────┬────────────────┬───────────────┤
│ 1. Native DNF RPM │ 2. Pipx Isolated  │ 3. Containers  │ 4. Shell &    │
│    (pkg-lists/)   │    (pipx-lists/)  │    & Upstreams │    Look-&-Feel│
│                   │                   │   (upstreams/) │    (zsh/)     │
│ 109 Fedora pkgs   │ 11 Python tools   │ Portainer:7999 │ Zsh setup     │
│ Scanners, debug,  │ netexec, impacket │ SysReptor:8000 │ Completions   │
│ compilers, sniff  │ responder, sqlmap │ BloodHound:8080│ Aliases, hl   │
└───────────────────┴───────────────────┴────────────────┴───────────────┘
```

1. **Native Fedora RPMs (`pkg-lists/`)**: 109 packages verified directly against official Fedora repositories covering base compilers, networking, sniffers, web discovery, reversing, and forensics.
2. **Pipx Isolated Python Tools (`pipx-lists/`)**: Offensive Python utilities requiring isolated environments to prevent library conflicts with system Python (`netexec`, `impacket`, `certipy-ad`, `bloodhound-ce`, `updog`, `sqlmap`, etc.).
3. **Standalone Upstreams & Containers (`upstreams/`)**: Vendor installers, git clones, and Docker containers for enterprise suites (`metasploit`, `burpsuite`, `seclists`, `evil-winrm`, `zap`, `hack-font`, `rustscan`, `naabu`, `portainer`, `sysreptor`, `bloodhound`, `devtunnel`, `responder`).
4. **Interactive Shell Environment (`zsh/`)**: Interactive Zsh configuration with autosuggestions, syntax highlighting, and pentesting aliases.

> 📖 **Tool Quick-Reference Guide**: For common startup commands, usage examples, keybindings, and dashboard URLs for every tool in this repository, see [assets/TOOL_REFERENCE.md](assets/TOOL_REFERENCE.md).
---

## Desktop Choice: Retain GNOME or Deploy Sway
Pendora provides full flexibility over your graphical environment. You can choose whether you want a headless/GNOME-compatible pentest environment or the full dynamic tiling desktop experience:

> 🔄 **Switch Between GNOME & Sway at Login**:  
> Installing Sway does not remove or alter your GNOME desktop. You can seamlessly switch between **GNOME** and **Sway** at any time on the login screen (GDM): click your username, select the gear icon (⚙️) in the bottom-right corner, and select your desired session before entering your password.
> 💡 **Testing Status & Recommendations:**  
> * **Tested & Verified — Full Installation (`./install.sh --all` / `--all --yes`)**: End-to-end single-pass deployment verifying all native security packages (00–70), Pipx tools, Upstream suites, Docker containers, and the Sway tiling desktop environment.
> * **Tested & Verified — Sway Dynamic Desktop (`./install.sh --sway`)**: Deploys the lightweight Sway tiling compositor, Noctalia desktop shell, Hack Nerd Font, focus-based window opacity, crisp 1080p display rendering, automatic GNOME keyboard layout inheritance, and bidirectional SPICE host/guest clipboard sharing. 100% native Fedora RPMs (zero COPR repositories required).
> * **Tested & Verified — Basic Pentest Setup (`./install.sh --basic`)**: Keeps your default Fedora GNOME desktop intact while deploying all pentest CLI tools, Pipx tools, Docker container suites, Zsh, Neovim, and Alacritty.

| Mode | Flag | Validation Status | Included Components |
|---|---|---|---|
| **Full Desktop** | `--all` (`-a`) | **Tested & Verified** | Single-pass combination of everything in Basic **plus** Sway desktop stack (`70-sway.list`, Sway/Noctalia dotfiles, screensharing portal services). |
| **Sway Desktop** | `--sway` (`-W`) | **Tested & Verified** | Installs `70-sway.list`, sets up screensharing user unit, deploys Sway & Noctalia configuration (Pendora theme), focus opacity daemon, GNOME keyboard auto-sync, Zsh, Neovim, Alacritty, and custom wallpapers. |
| **Basic Pentest** | `--basic` (`-b`) | **Tested & Verified** | Retains existing GNOME desktop. Deploys all pentest packages (00–60), Pipx tools, Docker containers, Kali Zsh prompt, Alacritty, Neovim/LazyVim, hostname, and wallpapers. **Zero desktop/window manager changes.** |

<p align="center">
  <b>Sway Dynamic Tiling Desktop Environment (Noctalia Shell + Catppuccin Alacritty + Focus Opacity)</b><br/>
  <img src="assets/Pendora-Sway.png" width="100%" alt="Pendora Sway Dynamic Tiling Penetration Testing Desktop Environment" />
</p>

<p align="center">
  <b>Fedora GNOME Penetration Testing Desktop Environment (Basic Install)</b><br/>
  <img src="assets/Pendora-Gnome.png" width="100%" alt="Pendora GNOME Penetration Testing Desktop Environment" />
</p>
---

## Requirements & Test Environment

The scripts and package templates in this project are designed, tested, and validated against the following target environment:

* **Operating System**: Up-to-date [Fedora Workstation](https://fedoraproject.org/workstation/) (GNOME Desktop)
* **Virtualization**: Virtual Machine deployed in **Virtual Machine Manager (`virt-manager`)** powered by **QEMU + KVM**
* **Minimum Tested Baseline**: **4 Virtual Cores (vCPUs)**, **4 GB RAM**, and **25 GB Virtual Hard Drive (Disk)**
* **Recommended Specs for Active Use**:
  * **Processor**: **8 Virtual Cores (vCPUs)** *(recommended for fast multithreaded scanning and cracking: nmap, masscan, ffuf)*
  * **Memory**: **Minimum 8 GB RAM** *(recommended for running concurrent container stacks: SysReptor, BloodHound, and Portainer alongside Burp Suite and browser)*
  * **Total Disk Space**: **35–50 GB** *(provides comfortable headroom beyond the ~11 GB install footprint for wordlists, database dumps, and captures)*
* **Storage Footprint Details**:
  * **Installation Size**: The full script deploys **~11 GB** of software across native RPMs, Pipx virtualenvs, standalone tools, wordlists (SecLists), and Docker container images. During active installation, peak usage reaches **~18–19 GB** due to temporary package caches and container layer downloads.
  * **Minimum VM Disk**: **25 GB** *(tested working baseline for a clean installation)*.
* **Privileges**: Regular user account with `sudo` permissions (**do NOT run the script as `sudo`**)
* **Connectivity**: Active internet connection to reach Fedora DNF mirrors, GitHub, PyPI, and Docker Hub
### Prerequisites Before Running

1. **Update System First**:
   Always perform a full system update before executing the script:
   ```bash
   sudo dnf upgrade --refresh -y
   ```
   *(Reboot the VM if a new kernel or systemd packages were installed).*

2. **Execution Permissions & Non-Root Execution**:
   > ⚠️ **Important:** **Do NOT run `install.sh` as `sudo`** (i.e. avoid `sudo ./install.sh`).
   > Always run it as your regular user: `./install.sh --all`.
   > The script handles `sudo` internally for tasks requiring root (DNF, hostname, Docker service). Running the entire script under `sudo` will incorrectly install user tools (`pipx`, `.zshrc`) into `/root/` instead of your user environment.

3. **Installation Duration, Prompts & Network Downloads**:
   * **Attendance Required**: The full installation takes significant time to complete (typically 15–30 minutes depending on your hardware and network connection) as it installs 120+ RPMs, builds Python wheels, downloads multi-gigabyte wordlists (SecLists), and pulls Docker container images.
   * **Sudo & Interactive Pauses**: Keep an eye on the terminal. The script periodically requests your `sudo` password for privileged operations and pauses to present generated credential cards (Portainer setup token, SysReptor credentials, BloodHound password) waiting for `[Enter]` to proceed.
   * **OWASP ZAP & Dev Tunnels Downloads**: During the upstream installations, downloading **OWASP ZAP** (Flatpak runtimes: `org.freedesktop.Platform`, GNOME runtime, codecs) and the standalone **Microsoft Dev Tunnels CLI** (`devtunnel`) binary takes time. The terminal may appear frozen or idle for several minutes while downloading these packages. **This is completely normal and has not hung during testing** — do not terminate the process; it will proceed automatically once the downloads finish.
---

## Directory Structure

```text
pendora/
├── install.sh                  # Central orchestrator and deployment script
├── README.md                   # Project documentation
├── pkg-lists/                  # Plain-text native DNF package lists
│   ├── 00-base.list            # System environment, compilers, stow, zsh, tmux, pipx
│   ├── 10-networking.list      # Port scanners, DNS enumeration, sniffers, VPN, routing
│   ├── 20-web.list             # Web security discovery & fuzzers (ffuf, gobuster, etc.)
│   ├── 30-forensics.list       # Reverse engineering, debuggers, static analysis (radare2, gdb)
│   ├── 40-auditing.list        # Password cracking & credential auditing (john, hashcat, hydra)
│   ├── 50-wireless.list        # 802.11 wireless security (aircrack-ng, kismet, reaver)
│   ├── 60-docker.list          # Docker daemon (moby-engine), CLI, and Docker Compose
│   └── 70-sway.list            # Sway tiling compositor, portals, Noctalia shell, dependencies
├── pipx-lists/                 # Isolated Python tool lists
│   └── pipx-tools.list         # netexec (git), impacket, certipy-ad, bloodhound-ce, updog, etc.
├── upstreams/                  # Standalone third-party installers
│   ├── install-upstreams.sh    # Metasploit, Burp, SecLists, Evil-WinRM, ZAP, Font, RustScan, Naabu, Portainer, SysReptor, BloodHound, Dev Tunnels, Responder
│   └── README.md
├── alacritty/                  # Alacritty terminal & Catppuccin Macchiato theme
│   └── .config/alacritty/      # alacritty.toml, catppuccin-macchiato.toml (Stow-compatible)
├── sway/                       # Sway tiling window manager & Noctalia shell
│   └── .config/sway/           # config (Stow-compatible)
│   └── .config/noctalia/       # config.toml, palettes/Pendora.json (Stow-compatible)
├── nvim/                       # Neovim, LazyVim & Catppuccin Macchiato theme
│   └── .config/nvim/           # init.lua, lazy.lua, plugins/colorscheme.lua (Stow-compatible)
└── zsh/                        # Shell styling & dotfiles
    └── .zshrc                  # Kali prompt with Fedora logo and pentesting shortcuts
```

---

## Web Services & Dashboards

| Service | Port / Protocol | Local URL | Status & Description |
|---|---|---|---|
| **Portainer CE** | `7999` (HTTPS) | `https://localhost:7999` | ⚠️ *Work in Progress* — Docker management web dashboard (deployment under investigation) |
| **SysReptor** | `8000` (HTTP) | `http://localhost:8000` | Pentest reporting platform (uses official [SysReptor install script](https://docs.sysreptor.com/install.sh)) |
| **BloodHound CE** | `8080` (HTTP) | `http://localhost:8080` | Active Directory attack path analysis & visualization |

*(For full credentials, startup commands, and terminal workflows across all categories, see the [Tool Reference Guide](assets/TOOL_REFERENCE.md)).*
> ℹ️ **Third-Party Script Notice**: The SysReptor deployment pulls and executes the vendor's official installer from [`https://docs.sysreptor.com/install.sh`](https://docs.sysreptor.com/install.sh). Users should always review third-party scripts before running them.



## How to Customize Package Lists

All files in `pkg-lists/` and `pipx-lists/` are structured for manual editing. The parser in `install.sh` automatically ignores empty lines and strips inline comments (`# ...`).

* **To disable a tool temporarily**: Prepend a `#` to the line:
  ```text
  # masscan                     # Ultra-fast TCP port scanner
  ```
* **To remove a tool permanently**: Delete the line from the file.
* **To add a new package**: Add the package name on a new line (inline comments optional):
  ```text
  cifs-utils                    # SMB/CIFS filesystem mount utilities
  ```

---

## Usage Instructions

Make sure the installer scripts are executable:

```bash
chmod +x install.sh upstreams/install-upstreams.sh
```

*(Run all commands as your regular user, never with `sudo ./install.sh`)*

### 1. Inspect Available Modules & Tool Counts
View a complete summary of all available package categories, Pipx tools, and upstream services:

```bash
./install.sh --list
```

### 2. Dry-Run Simulation (Recommended First Step)
Simulate execution to view every planned command and package without making system changes:

```bash
# Preview full installation across all four tiers
./install.sh --all --dry-run

# Preview only native DNF package installations
./install.sh --dry-run
```

### 3. Modular / Granular Installation
Install only the specific components you need:

```bash
# Install specific DNF categories only
./install.sh -c 10-networking -c 30-forensics

# Install only Docker engine packages
./install.sh -c 60-docker

# Install Docker engine AND deploy all containers (Portainer, SysReptor, BloodHound)
./install.sh --docker
# Install only Pipx-isolated Python security tools
./install.sh --pipx

# Deploy only the Kali/Fedora Zsh configuration
./install.sh --zsh

# Deploy complete Sway desktop stack, Noctalia shell, Zsh, Neovim, Alacritty & wallpapers
./install.sh --sway

# Deploy Alacritty terminal configuration & Catppuccin theme
./install.sh --alacritty

# Deploy Neovim/LazyVim configuration & Catppuccin theme
./install.sh --nvim
# Deploy and apply Pendora custom desktop wallpapers
./install.sh --wallpaper

# Set system hostname to 'pendora'
./install.sh --hostname
# Run specific upstream targets directly
cd upstreams
./install-upstreams.sh portainer sysreptor bloodhound devtunnel responder hack-font
```

### 4. Sway Dynamic Desktop (`--sway` / `-W`) — Tested & Verified
Deploys the complete standalone Sway Wayland tiling compositor, Noctalia shell, dynamic opacity, Hack Nerd Font, and terminal configurations:

```bash
# Interactive run
./install.sh --sway

# Non-interactive automated run
./install.sh --sway --yes
```

### 5. Basic Installation (`--basic` / `-b`) — Tested & Verified
Installs the complete penetration testing environment (all security packages 00-60, Pipx tools, upstreams, Docker containers, Zsh, Alacritty, Neovim, hostname) while keeping your existing GNOME desktop intact:

```bash
# Interactive run
./install.sh --basic

# Non-interactive automated run
./install.sh --basic --yes
```

### 6. Full Installation (`--all` / `-a`) — Tested & Verified
Installs the complete penetration testing toolkit (all native security packages 00–70, Pipx tools, Upstream suites, Docker containers) and configures the standalone Sway dynamic tiling desktop with the Noctalia shell, screensharing portal services, and dotfiles in a single automated pass:

```bash
# Interactive run
./install.sh --all

# Non-interactive automated run
./install.sh --all --yes
```

## Post-Installation

All shell configurations, font definitions, and group memberships are **automated** during execution:

* **Default Login Shell**: Automatically updated to Zsh (`/bin/zsh`) for your user account.
* **Docker Permissions**: Your user is added to the `docker` supplementary group.
* **Terminal Iconography**: Alacritty is pre-configured with `Hack Nerd Font` to render the Fedora prompt logos and glyphs.

To apply new group memberships and graphical session targets, simply reboot the system:

```bash
sudo reboot
```

---

## Known Issues & Work in Progress

* **Portainer Deployment (Under Investigation)**:  
  The automated Portainer CE container deployment is currently not initializing properly during the upstream installation phase.  
  > ℹ️ **Isolated Scope**: This issue is confined strictly to Portainer itself and **does not affect any other container stacks** (such as SysReptor or BloodHound CE), which build, initialize, and operate normally.

* **Sway Virtual Machine Viewer Rescaling (Work in Progress)**:  
  When running the Sway session inside a virtual machine (e.g., `virt-manager` / QEMU with SPICE):
  * **Window Rescaling**: Dynamically dragging or rescaling the virtual machine viewer window does not resize the desktop session in full (session operates at configured 1080p).
  * **Host-to-VM Clipboard Sharing (Resolved & Verified)**: Bidirectional copy-paste between host and guest operates out of the box via the integrated `sway-spice-clipboard-bridge` service and `spice-vdagent -x`.  
  > 💡 **Tip**: If dynamic display auto-rescaling on window drag is required for a specific workflow, you can simply select **GNOME** on the login screen (GDM), where SPICE guest agent display auto-configuration is natively supported.

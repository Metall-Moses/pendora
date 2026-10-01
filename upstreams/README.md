# Standalone Upstream Installers

This directory contains deployment scripts and documentation for security tools, containers, and prerequisites not distributed directly as native Fedora RPMs.

## Tools Covered

| Tool | Source / Method | Port / Access | Description |
|---|---|---|---|
| **Metasploit** | Rapid7 Omnibus Installer | CLI (`msfconsole`) | Industry standard penetration testing framework |
| **Burp Suite** | PortSwigger Linux Installer | GUI (`burpsuite`) | Web application security testing and interception proxy |
| **SecLists** | GitHub Git Clone | `/usr/share/wordlists/seclists` | Security tester's companion wordlists & dictionaries |
| **Evil-WinRM** | RubyGem (`gem install`) | CLI (`evil-winrm`) | Ultimate WinRM shell for Windows penetration testing |
| **OWASP ZAP** | Flathub Flatpak | GUI (`zaproxy`) | Open source web application vulnerability scanner |
| **Hack Nerd Font** | GitHub Release (`ryanoasis/nerd-fonts`) | System Fonts | Monospace font with full icons for terminal & prompt |
| **Portainer CE** | Docker Container | `https://localhost:7999` | Container management web interface |
| **SysReptor** | Docker Compose Installer | `http://localhost:8000` | Pentest reporting and finding documentation platform |
| **BloodHound CE** | Docker Compose (`ghst.ly/getbhce`) | `http://localhost:8080` | Active Directory attack path analysis & visualization (Portainer manageable) |
| **Dev Tunnels** | Microsoft Official (`aka.ms/TunnelsCliDownload`) | CLI (`devtunnel`) | Microsoft Dev Tunnels CLI for secure tunneling and remote port forwarding |
| **Responder** | GitHub Git Clone (`lgandx/Responder`) + Venv | CLI (`responder`) | LLMNR, NBT-NS, and mDNS poisoner and credential harvester |

## Usage

```bash
# Dry run check for all upstreams
./install-upstreams.sh --dry-run all

# Install specific tools
./install-upstreams.sh portainer sysreptor bloodhound devtunnel responder

# Install all upstream tools non-interactively
./install-upstreams.sh --yes all
```

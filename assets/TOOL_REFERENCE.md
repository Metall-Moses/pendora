# Pendora Tool Reference & Quick Start Guide

A quick-reference summary for every tool category, standalone suite, and container stack deployed by **Pendora**, including primary commands, flags, and local dashboard URLs.

---

## 1. Networking & Reconnaissance (`pkg-lists/10-networking.list`)

| Tool | Common Command / Startup | Use Case |
|---|---|---|
| **Nmap** | `nmap -sC -sV -p- -oN scan.txt <target>` | Default scripts, version detection, all ports |
| **Ncat** | `ncat -lvnp 4444` | Open raw TCP listener (modern Netcat) |
| **Masscan** | `sudo masscan -p1-65535 <subnet> --rate=10000` | Ultra-fast mass network port discovery |
| **Tcpdump** | `sudo tcpdump -i eth0 -nn -s0 -w capture.pcap` | Command-line network packet capture |
| **Wireshark / TShark** | `wireshark` *(GUI)* or `tshark -i any` | Interactive protocol inspection & analysis |
| **Socat** | `socat TCP-LISTEN:8080,fork TCP:target:80` | Multi-purpose port forwarding / bidirectional relay |
| **ProxyChains** | `proxychains4 nmap -sT -Pn -p80 <target>` | Tunnel TCP traffic through SOCKS proxies |
| **Arp-scan** | `sudo arp-scan --localnet` | Identify alive hosts on local Ethernet/WiFi |
| **Dnsenum** | `dnsenum --enum target.com` | Comprehensive DNS enumeration & subdomains |
| **Hping3** | `sudo hping3 -S -p 80 -c 5 <target>` | Custom TCP/IP packet assembler and tester |

---

## 2. Web Application Security (`pkg-lists/20-web.list`)

| Tool | Common Command / Startup | Use Case |
|---|---|---|
| **FFUF** | `ffuf -u http://target/FUZZ -w /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt` | Fast web directory & parameter fuzzing |
| **Gobuster** | `gobuster dir -u http://target -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-medium-directories.txt` | URI & directory brute-forcing |
| **WhatWeb** | `whatweb -a 3 http://target` | Web technology, server & CMS fingerprinting |
| **HTTPie** | `http GET http://target/api/v1 Authorization:"Bearer token"` | Clean, colored terminal HTTP client |

---

## 3. Password Cracking & Auditing (`pkg-lists/40-auditing.list`)

| Tool | Common Command / Startup | Use Case |
|---|---|---|
| **Hydra** | `hydra -l admin -P /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt ssh://target` | Online network brute-force (SSH/FTP/HTTP) |
| **Medusa** | `medusa -h target -u admin -P wordlist.txt -M rdp` | Modular, parallel network login cracking |
| **John the Ripper** | `john --wordlist=/usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt hashes.txt` | Offline password & shadow hash cracker |
| **Hashcat** | `hashcat -m 1000 -a 0 ntlm_hashes.txt rockyou.txt` | GPU-accelerated hash cracking (`-m 1000` = NTLM) |

---

## 4. Reverse Engineering & Forensics (`pkg-lists/30-forensics.list`)

| Tool | Common Command / Startup | Use Case |
|---|---|---|
| **Radare2** | `r2 -d ./binary` (then `aaa` -> `pdf @main`) | Command-line reverse engineering & disassembler |
| **GDB** | `gdb -q ./binary` (then `r`, `b *main`) | The GNU dynamic debugger |
| **Binwalk** | `binwalk -e firmware.bin` | Analyze and extract embedded files / firmware |
| **Foremost** | `foremost -i image.dd -o /tmp/recovered/` | File carving based on headers and footers |
| **ExifTool** | `exiftool image.jpg` | Inspect and extract file metadata |
| **TestDisk** | `sudo testdisk` or `sudo photorec` | Partition repair and deleted file recovery |
| **Hexedit** | `hexedit binary_file` | Direct hexadecimal editor |

---

## 5. Wireless Security (`pkg-lists/50-wireless.list`)

| Tool | Common Command / Startup | Use Case |
|---|---|---|
| **Aircrack-ng** | `sudo airmon-ng start wlan0`<br>`sudo airodump-ng wlan0mon`<br>`aircrack-ng -w rockyou.txt capture.cap` | 802.11 monitor mode, capture, and WPA-PSK key cracking |
| **Kismet** | `kismet` (then open `http://localhost:2501`) | Passive wireless device and packet sniffer |
| **Reaver** | `sudo reaver -i wlan0mon -b <BSSID> -vv` | WPS brute-force assessment |

---

## 6. Isolated Python Pentest Tools (`pipx-lists/pipx-tools.list`)

| Tool | Command | Description |
|---|---|---|
| **NetExec (nxc)** | `nxc smb 192.168.1.0/24 -u user -p pass` | Modern Active Directory & network execution tool |
| **Impacket** | `impacket-secretsdump domain/user:pass@target`<br>`impacket-psexec domain/user:pass@target`<br>`impacket-wmiexec domain/user:pass@target` | Full suite of Windows/AD exploitation scripts |
| **Certipy** | `certipy find -vulnerable -u user@domain -p pass` | Active Directory Certificate Services (AD CS) auditing |
| **SQLmap** | `sqlmap -u "http://target/page.php?id=1" --batch --dbs` | Automated SQL injection & database takeover |
| **Mitmproxy** | `mitmproxy` *(interactive TUI on port 8080)* | SSL/TLS intercepting HTTP proxy |
| **Arjun** | `arjun -u http://target/api/endpoint -m GET` | HTTP parameter discovery suite |
| **Dirsearch** | `dirsearch -u http://target -e php,html,js` | Advanced recursive web path brute-forcer |
| **Updog** | `updog -p 9090 -d /path/to/share` | Instant HTTP/S file transfer server with uploads |
| **Sublist3r** | `sublist3r -d domain.com` | OSINT subdomain discovery |

---

## 7. Upstreams & Enterprise Suites (`upstreams/`)

| Tool | Launch Command / Local URL | Description |
|---|---|---|
| **Metasploit** | `msfconsole` | Full Metasploit penetration testing framework |
| **Burp Suite** | `burpsuite` *(GUI)* | Burp Suite Community Edition proxy & scanner |
| **OWASP ZAP** | `zap` *(GUI via Flatpak)* | Zed Attack Proxy web vulnerability suite |
| **Evil-WinRM** | `evil-winrm -i target_ip -u Administrator -p pass` | Windows Remote Management shell |
| **Responder** | `sudo responder -I eth0 -dwv` | LLMNR / NBT-NS / mDNS poisoning & hash capture |
| **SecLists** | `/usr/share/wordlists/seclists/` | Massive collection of wordlists, payloads, usernames |
| **DevTunnel** | `devtunnel host -p 8000` | Secure port forwarding to expose local ports publicly |

---

## 8. Web Dashboards & Container Stacks (`upstreams/` & `60-docker.list`)

| Service | Port / Protocol | Local Dashboard URL | Default Credentials |
|---|---|---|---|
| **Portainer CE** | `7999` (HTTPS) | `https://localhost:7999` | User: `admin`<br>Setup token in `/opt/portainer/admin_setup.txt` |
| **SysReptor** | `8000` (HTTP) | `http://localhost:8000` | User: `reptor`<br>Password in `/opt/sysreptor/admin_credentials.txt` |
| **BloodHound CE** | `8080` (HTTP) | `http://localhost:8080` | User: `admin`<br>Password in `/opt/bloodhound/admin_credentials.txt` |

* **Manage all containers via Docker**:
  ```bash
  docker ps                                     # View running containers
  cd /opt/sysreptor && docker compose logs -f   # SysReptor container logs
  cd /opt/bloodhound && docker compose logs -f  # BloodHound container logs
  ```

---

## 9. Terminal & Shell Shortcuts (`00-base.list` & `zsh/`)

| Shortcut / Alias | Function |
|---|---|
| `myip` | Show active IPv4/IPv6 addresses with colors (`ip -br -c a`) |
| `ports` | Show all listening TCP/UDP ports with PIDs (`ss -tulpn`) |
| `serve-http` | Quick Python HTTP web server on port 8000 |
| `serve-updog` | Updog web server on port 9090 with file upload support |
| `Ctrl + P` | Toggle between 2-line Kali prompt and 1-line prompt |
| `nvim` | Neovim with LazyVim & Catppuccin Macchiato theme |
| `tmux` | Terminal multiplexer (split panes, detach/attach sessions) |

---

## 10. Hyprland Dynamic Desktop (`70-hyprland.list` & `hyprland/`)

| Keybinding | Action |
|---|---|
| `SUPER + T` | Open Alacritty terminal |
| `SUPER + F` | Open Nautilus file manager |
| `SUPER + B` | Open Browser (Firefox) |
| `SUPER + SHIFT + Space` | Open Rofi application runner |
| `SUPER + SHIFT + S` | Hyprshot interactive region screenshot |
| `SUPER + SHIFT + V` | Clipboard history search menu (cliphist + rofi) |
| `SUPER + Q` | Close active window |
| `SUPER + 1` through `9` | Switch between persistent workspaces |

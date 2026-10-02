#!/usr/bin/env bash
#
# pendora - Standalone Upstream Tools Installer
# Installs security tools that require vendor packages, git cloning, or rubygems.
#

set -euo pipefail

DRY_RUN=false
ASSUME_YES=false

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_help() {
    cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") [OPTIONS] [TOOL...]

${BOLD}Options:${NC}
  -h, --help      Show this help message
  -d, --dry-run   Simulate installation commands without executing
  -y, --yes       Assume yes for confirmation prompts

${BOLD}Available Upstream Tools:${NC}
  metasploit      Metasploit Framework (via Rapid7 official omnibus installer)
  burpsuite       Burp Suite Community Edition (via PortSwigger Linux installer)
  seclists        SecLists wordlist collection cloned to /usr/share/wordlists/seclists
  evil-winrm      Evil-WinRM Windows remote management shell (via gem)
  zap             Zed Attack Proxy (via Flathub Flatpak)
  hack-font       Hack Nerd Font (TTF glyphs from official Nerd Fonts release)
  rustscan        RustScan modern 65k-port scanner (via GitHub release -> /usr/local/bin/rustscan)
  naabu           Naabu fast port scanner (via ProjectDiscovery -> /usr/local/bin/naabu)
  portainer       Portainer Community Edition (management UI container on port 7999)
  bloodhound      BloodHound Community Edition (via Docker Compose on port 8080)
  devtunnel       Microsoft Dev Tunnels CLI (secure tunneling to localhost)
  responder       Responder LLMNR/NBT-NS/mDNS poisoner (via lgandx GitHub + venv)
  all             Install all upstream tools

${BOLD}Examples:${NC}
  $(basename "$0") --dry-run metasploit
  $(basename "$0") seclists evil-winrm
  $(basename "$0") all
EOF
}

install_metasploit() {
    log_info "Installing Metasploit Framework via Rapid7 omnibus installer..."
    local cmd="curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o /tmp/msfinstall && chmod 755 /tmp/msfinstall && sudo /tmp/msfinstall"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] $cmd"
    else
        bash -c "$cmd"
        log_success "Metasploit installed successfully."
    fi
}

install_burpsuite() {
    log_info "Downloading Burp Suite Community Edition installer..."
    local installer_url="https://portswigger.net/burp/releases/download?product=community&type=linux"
    local dest="/tmp/burpsuite_community.sh"
    local varfile="/tmp/burp_response.varfile"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] curl -fsSL '$installer_url' -o '$dest' && chmod +x '$dest'"
        echo "  [DRY-RUN] sudo '$dest' -q -dir /opt/BurpSuiteCommunity -overwrite -varfile '$varfile'"
        echo "  [DRY-RUN] sudo ln -sf /opt/BurpSuiteCommunity/BurpSuiteCommunity /usr/local/bin/burpsuite"
    else
        curl -fsSL "$installer_url" -o "$dest"
        if head -n 1 "$dest" | grep -q "^<"; then
            log_error "PortSwigger returned an HTML error page instead of installer script."
            return 1
        fi
        chmod +x "$dest"

        # Pre-seed install4j response varfile for non-interactive automated installation
        cat > "$varfile" <<'EOF'
sys.installationDir=/opt/BurpSuiteCommunity
sys.symlinkDir=/usr/local/bin
EOF

        log_info "Running Burp Suite installer in unattended mode (-q -dir /opt/BurpSuiteCommunity -overwrite)..."
        sudo "$dest" -q -dir /opt/BurpSuiteCommunity -overwrite -varfile "$varfile"

        # Ensure launcher symlinks exist in /usr/local/bin
        if [ -f /opt/BurpSuiteCommunity/BurpSuiteCommunity ]; then
            [ ! -e /usr/local/bin/burpsuite ] && sudo ln -sf /opt/BurpSuiteCommunity/BurpSuiteCommunity /usr/local/bin/burpsuite
            [ ! -e /usr/local/bin/BurpSuiteCommunity ] && sudo ln -sf /opt/BurpSuiteCommunity/BurpSuiteCommunity /usr/local/bin/BurpSuiteCommunity
        fi

        # Clean up temporary installer and varfile
        rm -f "$dest" "$varfile"
        log_success "Burp Suite installed in unattended mode. Symlink ready at /usr/local/bin/burpsuite"
    fi
}

install_seclists() {
    log_info "Installing SecLists to /usr/share/wordlists/seclists..."
    local target_dir="/usr/share/wordlists/seclists"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo mkdir -p /usr/share/wordlists"
        echo "  [DRY-RUN] sudo git clone --depth 1 https://github.com/danielmiessler/SecLists.git $target_dir"
        echo "  [DRY-RUN] sudo gzip -d -k /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz 2>/dev/null || true"
    else
        sudo mkdir -p /usr/share/wordlists
        if [ -d "$target_dir/.git" ]; then
            log_info "SecLists already exists. Pulling latest updates..."
            sudo git -C "$target_dir" pull --ff-only
        else
            sudo git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$target_dir"
        fi
        if [ -f "$target_dir/Passwords/Leaked-Databases/rockyou.txt.tar.gz" ]; then
            log_info "Extracting rockyou.txt..."
            sudo tar -xzf "$target_dir/Passwords/Leaked-Databases/rockyou.txt.tar.gz" -C "$target_dir/Passwords/Leaked-Databases/"
        fi
        log_success "SecLists installed at $target_dir"
    fi
}

install_evil_winrm() {
    log_info "Installing Evil-WinRM via RubyGem..."
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo gem install evil-winrm"
    else
        if ! command -v gem &>/dev/null; then
            log_error "gem command not found. Ensure ruby, rubygems, ruby-devel, and readline-devel are installed."
            return 1
        fi
        # Ensure ruby.h and readline headers are installed for compiling readline-ext native gem
        if ! rpm -q ruby-devel readline-devel &>/dev/null; then
            log_info "Installing missing ruby-devel and readline-devel for native gem compilation..."
            sudo dnf install -y ruby-devel readline-devel
        fi
        sudo gem install evil-winrm
        log_success "Evil-WinRM installed."
    fi
}

install_zap() {
    log_info "Installing OWASP ZAP (Zed Attack Proxy) via Flatpak..."
    local target_user="${SUDO_USER:-${USER:-$(id -un)}}"
    local flatpak_cmd=(flatpak --user)
    if [ -n "${SUDO_USER:-}" ] && [ "$EUID" -eq 0 ]; then
        flatpak_cmd=(sudo -u "$SUDO_USER" flatpak --user)
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] ${flatpak_cmd[*]} remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
        echo "  [DRY-RUN] ${flatpak_cmd[*]} install -y --noninteractive flathub org.zaproxy.ZAP"
        echo "  [DRY-RUN] Create /usr/local/bin/zap launcher wrapper"
    else
        if ! command -v flatpak &>/dev/null; then
            log_info "flatpak not found. Installing flatpak via dnf..."
            sudo dnf install -y flatpak || { log_error "Failed to install flatpak"; return 1; }
        fi
        log_info "Configuring Flathub remote in user scope for ${target_user}..."
        "${flatpak_cmd[@]}" remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        log_info "Installing org.zaproxy.ZAP in user scope..."
        "${flatpak_cmd[@]}" install -y --noninteractive flathub org.zaproxy.ZAP

        # Create launcher wrapper in /usr/local/bin/zap
        local wrapper="/usr/local/bin/zap"
        sudo tee "$wrapper" >/dev/null <<'EOF'
#!/bin/sh
exec flatpak run org.zaproxy.ZAP "$@"
EOF
        sudo chmod +x "$wrapper"
        log_success "ZAP Flatpak installed successfully. Launcher ready at $wrapper"
    fi
}
install_hack_font() {
    log_info "Installing Hack Nerd Font from upstream Nerd Fonts release..."
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.tar.xz"
    local font_dir="/usr/local/share/fonts/HackNerdFont"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo mkdir -p '$font_dir'"
        echo "  [DRY-RUN] curl -fsSL '$font_url' | sudo tar -xJ -C '$font_dir'"
        echo "  [DRY-RUN] sudo fc-cache -f"
    else
        sudo mkdir -p "$font_dir"
        curl -fsSL "$font_url" | sudo tar -xJ -C "$font_dir"
        sudo fc-cache -f
        log_success "Hack Nerd Font installed to $font_dir"
    fi
}
ensure_docker_ready() {
    local target_user="${SUDO_USER:-${USER:-$(id -un)}}"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo systemctl enable --now docker"
        echo "  [DRY-RUN] sudo usermod -aG docker $target_user"
        return 0
    fi

    if ! command -v docker &>/dev/null; then
        log_error "docker command not found. Please install the Docker package list (pkg-lists/60-docker.list) first."
        return 1
    fi

    log_info "Ensuring Docker service is active and user '$target_user' is in docker group..."
    sudo systemctl enable --now docker 2>/dev/null || true
    sudo usermod -aG docker "$target_user" 2>/dev/null || true
}

install_portainer() {
    log_info "Configuring Docker service and deploying Portainer CE..."
    local creds_file="/opt/portainer/admin_setup.txt"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo mkdir -p /opt/portainer"
        echo "  [DRY-RUN] sudo docker volume create portainer_data"
        echo "  [DRY-RUN] sudo docker run -d -p 7999:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest"
        echo "  [DRY-RUN] Extract setup_token from container logs"
        echo "  [DRY-RUN] Display setup token banner and prompt user to copy before continuing"
        echo "  [DRY-RUN] Web interface: https://localhost:7999"
    else
        ensure_docker_ready || return 1

        # If Portainer container is already running, show setup banner and skip re-deployment
        if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^portainer"; then
            log_success "Portainer CE container is already running! Web interface: https://localhost:7999"
            local existing_token=""
            if [ -f "$creds_file" ]; then
                existing_token=$(grep -E "^Setup Token:" "$creds_file" 2>/dev/null | cut -d: -f2- | tr -d ' \r\n' || true)
            fi
            if [ -z "$existing_token" ]; then
                existing_token=$(sudo docker logs portainer 2>&1 | grep -oE "setup_token=[a-zA-Z0-9._-]+" | cut -d= -f2 | head -n 1 | tr -d '\r\n' || true)
            fi
            [ -z "$existing_token" ] && existing_token="Already initialized or check 'sudo docker logs portainer'"

            echo
            echo -e "${GREEN}${BOLD}====================================================${NC}"
            echo -e "${GREEN}${BOLD}Portainer CE Web Dashboard${NC}"
            echo -e "${GREEN}${BOLD}====================================================${NC}"
            echo -e "  Web URL:      ${BOLD}https://localhost:7999${NC}"
            echo -e "  Username:     ${BOLD}admin${NC}"
            echo -e "  Setup Token:  ${BOLD}${existing_token}${NC}"
            echo -e "${YELLOW}  ⚠️  REMINDER: Access https://localhost:7999 to complete admin setup!${NC}"
            echo -e "${GREEN}${BOLD}====================================================${NC}"
            echo
            read -rp "Please copy the Setup Token and URL above. Press [Enter] to continue: " _
            return 0
        fi

        sudo mkdir -p /opt/portainer
        log_info "Creating portainer_data volume..."
        sudo docker volume create portainer_data 2>/dev/null || true
        log_info "Deploying Portainer CE container..."
        sudo docker run -d \
            -p 7999:9443 \
            --name portainer \
            --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            portainer/portainer-ce:latest

        log_info "Waiting for Portainer CE container to initialize and generate setup token..."
        local setup_token=""
        for _ in {1..15}; do
            setup_token=$(sudo docker logs portainer 2>&1 | grep -oE "setup_token=[a-zA-Z0-9._-]+" | cut -d= -f2 | head -n 1 | tr -d '\r\n' || true)
            [ -n "$setup_token" ] && break
            sleep 1
        done
        [ -z "$setup_token" ] && setup_token="Check 'sudo docker logs portainer' for setup_token"

        sudo tee "$creds_file" >/dev/null <<EOF
Web URL:      https://localhost:7999
Username:     admin
Setup Token:  ${setup_token}
Note:         Initial setup must be completed within 5 minutes of first launch.
EOF

        echo
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo -e "${GREEN}${BOLD}Portainer CE Initial Setup${NC}"
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo -e "  Web URL:      ${BOLD}https://localhost:7999${NC}"
        echo -e "  Username:     ${BOLD}admin${NC}"
        echo -e "  Setup Token:  ${BOLD}${setup_token}${NC}"
        echo -e "  Saved to:     ${creds_file}"
        echo -e "${YELLOW}  ⚠️  REMINDER: Copy the Setup Token above to unlock initial admin setup at https://localhost:7999!${NC}"
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo
        read -rp "Please copy the Setup Token and URL above. Press [Enter] to continue: " _
        log_success "Portainer CE deployed successfully! Web interface: https://localhost:7999"
    fi
}
install_sysreptor() {
    log_info "Configuring Docker and deploying SysReptor pentest reporting platform..."
    local install_dir="/opt/sysreptor"
    local installer_script="/tmp/sysreptor_install.sh"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo mkdir -p '$install_dir'"
        echo "  [DRY-RUN] sed -i 's/read -p \"Copy your password.*/CONFIRM=\"y\"/g' '$installer_script'"
        echo "  [DRY-RUN] sed -i 's/read -p .*/true/g' '$installer_script'"
        echo "  [DRY-RUN] cd '$install_dir' && sudo env SYSREPTOR_ENCRYPT='n' CONFIRM='y' CONFIRM_AUTOUPDATE='n' bash '$installer_script'"
        echo "  [DRY-RUN] Display credentials banner and prompt user to copy before continuing"
        echo "  [DRY-RUN] SysReptor interface will be accessible at: http://localhost:8000"
    else
        ensure_docker_ready || return 1
        local creds_file="${install_dir}/admin_credentials.txt"

        # If SysReptor container stack is already running, show credentials if available and skip re-installation
        if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^sysreptor-app"; then
            log_success "SysReptor container stack is already running! Web interface: http://localhost:8000"
            if [ -f "$creds_file" ]; then
                local existing_pw
                existing_pw=$(grep -E "^Password:" "$creds_file" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '\r\n')
                if [ -n "$existing_pw" ]; then
                    echo
                    echo -e "${GREEN}${BOLD}====================================================${NC}"
                    echo -e "${GREEN}${BOLD}SysReptor Credentials${NC}"
                    echo -e "${GREEN}${BOLD}====================================================${NC}"
                    echo -e "  Web URL:   ${BOLD}http://localhost:8000${NC}"
                    echo -e "  Username:  ${BOLD}reptor${NC}"
                    echo -e "  Password:  ${BOLD}${existing_pw}${NC}"
                    echo -e "  Saved to:  ${creds_file}"
                    echo -e "${YELLOW}  ⚠️  REMINDER: Please change this password on first login!${NC}"
                    echo -e "${GREEN}${BOLD}====================================================${NC}"
                    echo
                    read -rp "Please copy your username and password above. Press [Enter] to continue: " _
                fi
            fi
            return 0
        fi

        sudo mkdir -p "$install_dir"
        log_info "Downloading official SysReptor installer..."
        curl -fsSL https://docs.sysreptor.com/install.sh -o "$installer_script"
        chmod +x "$installer_script"

        # Neutralize all interactive read prompts with automated responses to avoid infinite while-loops
        sed -i 's/read -p "Copy your password.*/CONFIRM="y"/g' "$installer_script"
        sed -i 's/read -p "Backup your encryption.*/CONFIRM="y"/g' "$installer_script"
        sed -i 's/read -p "Enable automatic updates.*/CONFIRM_AUTOUPDATE="n"/g' "$installer_script"
        sed -i 's/read -p "Encrypt files and database.*/SYSREPTOR_ENCRYPT="n"/g' "$installer_script"
        sed -i 's/read -p .*/true/g' "$installer_script"

        log_info "Running SysReptor installer in unattended mode (Community Edition)..."

        (
            cd "$install_dir"
            sudo env \
                SYSREPTOR_LICENSE="" \
                SYSREPTOR_ENCRYPT="n" \
                CONFIRM="y" \
                CONFIRM_AUTOUPDATE="n" \
                bash "$installer_script"
        ) 2>&1 | sudo tee "$creds_file"

        # Cleanup temporary installer script
        rm -f "$installer_script"

        # Extract generated superuser credentials
        local generated_pw
        generated_pw=$(grep -E "^Password:" "$creds_file" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '\r\n')
        [ -z "$generated_pw" ] && generated_pw="Check $creds_file"

        echo
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo -e "${GREEN}${BOLD}SysReptor Credentials${NC}"
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo -e "  Web URL:   ${BOLD}http://localhost:8000${NC}"
        echo -e "  Username:  ${BOLD}reptor${NC}"
        echo -e "  Password:  ${BOLD}${generated_pw}${NC}"
        echo -e "  Saved to:  ${creds_file}"
        echo -e "${YELLOW}  ⚠️  REMINDER: Please change this password on first login!${NC}"
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo
        read -rp "Please copy your username and password above. Press [Enter] to continue: " _
        log_success "SysReptor deployment completed! Web interface: http://localhost:8000"
    fi
}
install_bloodhound() {
    log_info "Configuring Docker and deploying BloodHound Community Edition (CE)..."
    local install_dir="/opt/bloodhound"
    local creds_file="${install_dir}/admin_credentials.txt"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo mkdir -p '$install_dir'"
        echo "  [DRY-RUN] sudo curl -sSL https://ghst.ly/getbhce -o '$install_dir/docker-compose.yml'"
        echo "  [DRY-RUN] sudo sed -i '/image:/a \\    restart: always' '$install_dir/docker-compose.yml'"
        echo "  [DRY-RUN] cd '$install_dir' && sudo docker compose up -d"
        echo "  [DRY-RUN] Display credentials banner and prompt user to copy before continuing"
        echo "  [DRY-RUN] BloodHound CE interface will be accessible at: http://localhost:8080"
        echo "  [DRY-RUN] Stack and volumes fully manageable in Portainer at: https://localhost:7999"
    else
        ensure_docker_ready || return 1

        # If BloodHound container stack is already running, show credentials if available and skip re-installation
        if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^bloodhound"; then
            log_success "BloodHound CE container stack is already running! Web interface: http://localhost:8080"
            # Ensure running containers have restart: always enabled for boot persistence
            sudo docker update --restart=always $(sudo docker ps -q --filter "name=bloodhound") 2>/dev/null || true
            sudo docker update --restart=always $(sudo docker ps -q --filter "name=app-db") 2>/dev/null || true
            sudo docker update --restart=always $(sudo docker ps -q --filter "name=graph-db") 2>/dev/null || true
            if [ -f "$creds_file" ]; then
                local existing_pw
                existing_pw=$(grep -E "^Password:" "$creds_file" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '\r\n')
                if [ -n "$existing_pw" ]; then
                    echo
                    echo -e "${GREEN}${BOLD}====================================================${NC}"
                    echo -e "${GREEN}${BOLD}BloodHound CE Credentials${NC}"
                    echo -e "${GREEN}${BOLD}====================================================${NC}"
                    echo -e "  Web URL:   ${BOLD}http://localhost:8080${NC}"
                    echo -e "  Username:  ${BOLD}admin${NC}"
                    echo -e "  Password:  ${BOLD}${existing_pw}${NC}"
                    echo -e "  Saved to:  ${creds_file}"
                    echo -e "${YELLOW}  ⚠️  REMINDER: You must change this password on first login!${NC}"
                    echo -e "${GREEN}${BOLD}====================================================${NC}"
                    echo
                    read -rp "Please copy your username and password above. Press [Enter] to continue: " _
                fi
            fi
            return 0
        fi

        sudo mkdir -p "$install_dir"
        log_info "Downloading official BloodHound CE docker-compose.yml to $install_dir..."
        sudo curl -sSL https://ghst.ly/getbhce -o "$install_dir/docker-compose.yml"
        # Ensure all BloodHound CE services auto-start on system boot
        sudo sed -i '/image:/a \    restart: always' "$install_dir/docker-compose.yml"
        log_info "Starting BloodHound CE stack via docker compose..."
        (cd "$install_dir" && sudo docker compose up -d)
        log_info "Waiting for BloodHound CE container to initialize..."
        local raw_pw_line=""
        local parsed_pw=""
        for _ in {1..15}; do
            raw_pw_line=$(cd "$install_dir" && sudo docker compose logs bloodhound 2>/dev/null | grep -i "initial password" | tail -n 1 || true)
            if [ -n "$raw_pw_line" ]; then
                parsed_pw=$(echo "$raw_pw_line" | sed -E 's/.*(Initial Password Set To:|initial password is:?)[[:space:]]*//I' | tr -d '\r\n')
                [ -n "$parsed_pw" ] && break
            fi
            sleep 2
        done
        [ -z "$parsed_pw" ] && parsed_pw="Run 'cd $install_dir && sudo docker compose logs bloodhound' to view"

        # Save credentials to /opt/bloodhound/admin_credentials.txt
        sudo tee "$creds_file" >/dev/null <<EOF
Web URL:   http://localhost:8080
Username:  admin
Password:  ${parsed_pw}
EOF

        echo
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo -e "${GREEN}${BOLD}BloodHound CE Credentials${NC}"
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo -e "  Web URL:   ${BOLD}http://localhost:8080${NC}"
        echo -e "  Username:  ${BOLD}admin${NC}"
        echo -e "  Password:  ${BOLD}${parsed_pw}${NC}"
        echo -e "  Saved to:  ${creds_file}"
        echo -e "${YELLOW}  ⚠️  REMINDER: You must change this password on first login!${NC}"
        echo -e "${GREEN}${BOLD}====================================================${NC}"
        echo
        read -rp "Please copy your username and password above. Press [Enter] to continue: " _

        log_success "BloodHound CE deployed successfully! Web interface: http://localhost:8080"
        log_info "BloodHound stack and volumes are fully manageable in Portainer (https://localhost:7999)."
    fi
}
install_devtunnel() {
    log_info "Installing Microsoft Dev Tunnels CLI (devtunnel)..."
    local dest="/usr/local/bin/devtunnel"
    local download_url="https://aka.ms/TunnelsCliDownload/linux-x64"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo curl -fL --progress-bar '$download_url' -o '$dest' && sudo chmod +x '$dest'"
    else
        log_info "Downloading devtunnel binary (~60 MB)..."
        sudo curl -fL --progress-bar "$download_url" -o "$dest"
        sudo chmod +x "$dest"
        log_success "Microsoft Dev Tunnels installed to $dest"
    fi
}
install_responder() {
    log_info "Installing Responder (LLMNR, NBT-NS, and mDNS poisoner)..."
    local install_dir="/opt/responder"
    local wrapper="/usr/local/bin/responder"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo git clone https://github.com/lgandx/Responder.git $install_dir"
        echo "  [DRY-RUN] sudo python3 -m venv $install_dir/venv"
        echo "  [DRY-RUN] sudo $install_dir/venv/bin/pip install -r $install_dir/requirements.txt"
        echo "  [DRY-RUN] Create launcher wrapper at $wrapper"
    else
        if ! command -v python3 &>/dev/null || ! rpm -q python3-devel gcc &>/dev/null; then
            log_info "Ensuring python3, python3-devel, and gcc are installed for Responder dependencies..."
            sudo dnf install -y python3 python3-devel gcc || true
        fi
        sudo mkdir -p /opt
        if [ -d "$install_dir/.git" ]; then
            log_info "Responder already exists. Pulling latest updates..."
            sudo git -C "$install_dir" pull --ff-only || true
        else
            sudo git clone https://github.com/lgandx/Responder.git "$install_dir"
        fi
        log_info "Setting up Python virtual environment for Responder..."
        sudo python3 -m venv "$install_dir/venv"
        sudo "$install_dir/venv/bin/pip" install --upgrade pip
        sudo "$install_dir/venv/bin/pip" install -r "$install_dir/requirements.txt"

        # Create launcher wrapper in /usr/local/bin/responder
        sudo tee "$wrapper" >/dev/null <<'EOF'
#!/bin/sh
exec sudo /opt/responder/venv/bin/python /opt/responder/Responder.py "$@"
EOF
        sudo chmod +x "$wrapper"
        log_success "Responder installed successfully! Launcher ready at $wrapper"
    fi
}
install_rustscan() {
    log_info "Installing RustScan modern fast port scanner..."
    local dest="/usr/local/bin/rustscan"
    local download_url="https://github.com/bee-san/RustScan/releases/download/2.4.1/x86_64-linux-rustscan.tar.gz.zip"
    local temp_dir="/tmp/rustscan_install_$$"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] curl -fsSL '$download_url' -o /tmp/rustscan.zip"
        echo "  [DRY-RUN] unzip /tmp/rustscan.zip && tar -xzf x86_64-linux-rustscan.tar.gz"
        echo "  [DRY-RUN] sudo install -m 755 rustscan '$dest'"
    else
        mkdir -p "$temp_dir"
        log_info "Downloading RustScan release archive..."
        curl -fsSL "$download_url" -o "$temp_dir/rustscan.zip"
        unzip -q -o "$temp_dir/rustscan.zip" -d "$temp_dir"
        tar -xzf "$temp_dir/x86_64-linux-rustscan.tar.gz" -C "$temp_dir"
        sudo install -m 755 "$temp_dir/rustscan" "$dest"
        rm -rf "$temp_dir"
        log_success "RustScan installed successfully to $dest"
    fi
}

install_naabu() {
    log_info "Installing Naabu fast port scanner (ProjectDiscovery)..."
    local dest="/usr/local/bin/naabu"
    local download_url="https://github.com/projectdiscovery/naabu/releases/download/v2.6.1/naabu_2.6.1_linux_amd64.zip"
    local temp_dir="/tmp/naabu_install_$$"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] curl -fsSL '$download_url' -o /tmp/naabu.zip"
        echo "  [DRY-RUN] unzip /tmp/naabu.zip naabu"
        echo "  [DRY-RUN] sudo install -m 755 naabu '$dest'"
    else
        mkdir -p "$temp_dir"
        log_info "Downloading Naabu release archive..."
        curl -fsSL "$download_url" -o "$temp_dir/naabu.zip"
        unzip -q -o "$temp_dir/naabu.zip" naabu -d "$temp_dir"
        sudo install -m 755 "$temp_dir/naabu" "$dest"
        rm -rf "$temp_dir"
        log_success "Naabu installed successfully to $dest"
    fi
}








# Parse options
TOOLS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        *)
            TOOLS+=("$1")
            shift
            ;;
    esac
done

if [ ${#TOOLS[@]} -eq 0 ]; then
    show_help
    exit 0
fi

if [[ " ${TOOLS[*]} " =~ " all " ]]; then
    TOOLS=("metasploit" "burpsuite" "seclists" "evil-winrm" "zap" "hack-font" "rustscan" "naabu" "portainer" "sysreptor" "bloodhound" "devtunnel" "responder")
elif [[ " ${TOOLS[*]} " =~ " containers " ]] || [[ " ${TOOLS[*]} " =~ " docker " ]]; then
    TOOLS=("portainer" "sysreptor" "bloodhound")
fi
echo -e "${BOLD}Pendora - Standalone Upstream Tool Installation${NC}"
echo "========================================================"
log_info "Selected tools: ${TOOLS[*]}"

if [ "$ASSUME_YES" = false ] && [ "$DRY_RUN" = false ]; then
    read -rp "Proceed with installation? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { log_warn "Aborted by user."; exit 0; }
fi

for tool in "${TOOLS[@]}"; do
    case "$tool" in
        metasploit)
            install_metasploit
            ;;
        burpsuite)
            install_burpsuite
            ;;
        seclists)
            install_seclists
            ;;
        evil-winrm)
            install_evil_winrm
            ;;
        zap)
            install_zap
            ;;
        hack-font|font)
            install_hack_font
            ;;
        rustscan)
            install_rustscan
            ;;
        naabu)
            install_naabu
            ;;
        portainer)
            install_portainer
            ;;
        sysreptor)
            install_sysreptor
            ;;
        bloodhound)
            install_bloodhound
            ;;
        devtunnel|devtunnels)
            install_devtunnel
            ;;
        responder)
            install_responder
            ;;
        *)
            log_error "Unknown tool: $tool"
            exit 1
            ;;
    esac
done

log_success "All requested upstream tools processed."

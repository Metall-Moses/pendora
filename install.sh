#!/usr/bin/env bash
#
# pendora - Fedora Penetration Testing VM Setup Script
# Reads modular package lists from pkg-lists/, pipx-lists/, and upstreams/.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISTS_DIR="${SCRIPT_DIR}/pkg-lists"
PIPX_DIR="${SCRIPT_DIR}/pipx-lists"
UPSTREAMS_SCRIPT="${SCRIPT_DIR}/upstreams/install-upstreams.sh"

DRY_RUN=false
ASSUME_YES=""
INSTALL_PIPX=false
INSTALL_UPSTREAMS=false
INSTALL_ZSH=false
INSTALL_HYPRLAND=false
INSTALL_ALACRITTY=false
INSTALL_NVIM=false
INSTALL_WALLPAPER=false
INSTALL_DOCKER_CONTAINERS=false
SET_HOSTNAME=false
RUN_ALL=false
RUN_BASIC=false
REBOOT=true
SELECTED_CATEGORIES=()
CUSTOM_FILES=()

# Colors for terminal output
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
${BOLD}Usage:${NC} $(basename "$0") [OPTIONS]

${BOLD}Options:${NC}
  -h, --help               Show this help message and exit
  -l, --list               Display available categories and package counts
  -d, --dry-run            Simulate execution; print commands without installing
  -y, --yes                Pass -y to dnf / assume yes for prompts
  -c, --category <name>    Install specific category (e.g. -c 10-networking -c 30-forensics)
  -f, --file <file>        Install packages from a specific file
  -p, --pipx               Install Python security tools via pipx
  -u, --upstreams          Run standalone upstream installers (Metasploit, Burp, SecLists, etc.)
  -D, --docker, --containers Install Docker engine and deploy container stacks (Portainer, SysReptor, BloodHound)
  -z, --zsh                Deploy Kali-styled .zshrc configuration
  -W, --hyprland           Install Hyprland desktop stack, Noctalia shell, Zsh, Neovim, Alacritty & wallpapers
  -T, --alacritty          Deploy Alacritty terminal configuration & Catppuccin Macchiato theme
  -N, --nvim               Deploy Neovim/LazyVim configuration & Catppuccin Macchiato theme
  -H, --hostname           Set system hostname to 'pendora'
  -B, --wallpaper          Deploy and apply Pendora custom wallpaper
  -b, --basic              Basic pentest setup without Hyprland (00-60 DNF + pipx + upstreams + zsh + alacritty + nvim + wallpaper)
  -a, --all                Full setup including Hyprland desktop stack & wallpaper
  --no-reboot              Do not reboot system after installation
${BOLD}Examples:${NC}
  $(basename "$0") --list
  $(basename "$0") --dry-run
  $(basename "$0") -c 10-networking -c 20-web
  $(basename "$0") --pipx
  $(basename "$0") --all --dry-run
EOF
}

check_distro() {
    if [ ! -f /etc/fedora-release ]; then
        log_warn "This script is tailored for Fedora Linux. /etc/fedora-release not detected."
        if [ "$DRY_RUN" = false ]; then
            read -rp "Continue anyway? [y/N]: " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
        fi
    fi
}
check_non_root() {
    if [ "$EUID" -eq 0 ] && [ -z "${ALLOW_ROOT:-}" ]; then
        log_warn "You are running this script directly as root or via sudo."
        log_warn "It is recommended to run as your regular user: ./install.sh"
        log_warn "The script internally requests sudo for commands requiring root."
        if [ "$DRY_RUN" = false ]; then
            read -rp "Continue as root anyway? [y/N]: " confirm_root
            [[ "$confirm_root" =~ ^[Yy]$ ]] || exit 1
        fi
    fi
}


# Parse a package list file, filtering out blank lines and comments
parse_package_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_error "List file not found: $file"
        return 1
    fi
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" | grep -vE '^[[:space:]]*$' || true
}

list_categories() {
    echo -e "${BOLD}1. Native DNF Package Categories (pkg-lists/):${NC}"
    echo "----------------------------------------------------"
    printf "%-30s %s\n" "Category / File" "Package Count"
    echo "----------------------------------------------------"

    local total=0
    for list_file in "${LISTS_DIR}"/*.list; do
        [ -f "$list_file" ] || continue
        local name
        name="$(basename "$list_file" .list)"
        local count
        count="$(parse_package_file "$list_file" | wc -l)"
        total=$((total + count))
        printf "%-30s %d packages\n" "$name" "$count"
    done
    echo "----------------------------------------------------"
    printf "%-30s %d packages\n" "TOTAL NATIVE DNF" "$total"
    echo

    echo -e "${BOLD}2. Pipx Python Tool Lists (pipx-lists/):${NC}"
    echo "----------------------------------------------------"
    for pfile in "${PIPX_DIR}"/*.list; do
        [ -f "$pfile" ] || continue
        local pname
        pname="$(basename "$pfile")"
        local pcount
        pcount="$(parse_package_file "$pfile" | wc -l)"
        printf "%-30s %d tools\n" "$pname" "$pcount"
    done
    echo

    echo -e "${BOLD}3. Standalone Upstream Installers (upstreams/):${NC}"
    echo "----------------------------------------------------"
    echo "  - metasploit   (Rapid7 Omnibus Installer)"
    echo "  - burpsuite    (PortSwigger Linux Installer)"
    echo "  - seclists     (GitHub git clone -> /usr/share/wordlists/seclists)"
    echo "  - evil-winrm   (RubyGem)"
    echo "  - zap          (OWASP ZAP via Flatpak)"
    echo "  - hack-font    (Hack Nerd Font for terminal and prompt iconography)"
    echo "  - rustscan     (RustScan ultra-fast 65k-port scanner binary in /usr/local/bin)"
    echo "  - naabu        (Naabu fast port scanner by ProjectDiscovery in /usr/local/bin)"
    echo "  - portainer    (Portainer Community Edition UI on port 7999)"
    echo "  - bloodhound   (BloodHound Community Edition on port 8080 - Portainer manageable)"
    echo "  - devtunnel    (Microsoft Dev Tunnels CLI for secure port forwarding)"
    echo "  - responder    (Responder LLMNR/NBT-NS/mDNS poisoner in /opt/responder)"
    echo "----------------------------------------------------"
}

run_pipx_install() {
    echo
    echo -e "${BOLD}Installing Pipx Security Tools${NC}"
    echo "===================================================="

    local pipx_pkgs=()
    for pfile in "${PIPX_DIR}"/*.list; do
        [ -f "$pfile" ] || continue
        mapfile -t lines < <(parse_package_file "$pfile")
        for line in "${lines[@]}"; do
            pipx_pkgs+=("$line")
        done
    done

    if [ ${#pipx_pkgs[@]} -eq 0 ]; then
        log_warn "No pipx tools listed in ${PIPX_DIR}."
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] pipx ensurepath"
    else
        if ! command -v pipx &>/dev/null; then
            log_info "pipx command not found. Installing pipx via dnf..."
            sudo dnf install -y pipx
        fi
        pipx ensurepath 2>/dev/null || true
    fi

    log_info "Total pipx tools to install: ${#pipx_pkgs[@]}"
    for tool in "${pipx_pkgs[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY-RUN] pipx install $tool"
        else
            log_info "Running: pipx install $tool"
            pipx install "$tool" || pipx upgrade "$tool" || log_warn "pipx install failed for: $tool"
        fi
    done
    log_success "Pipx processing complete."

    # Post-process Impacket: create convenience aliases and central /usr/local/bin/impacket launcher
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local pipx_bin_dir="${target_home}/.local/bin"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] Create Impacket convenience symlinks (impacket-* and non-.py aliases in ~/.local/bin)"
        echo "  [DRY-RUN] Deploy central /usr/local/bin/impacket CLI launcher"
    else
        if [ -d "$pipx_bin_dir" ]; then
            log_info "Configuring Impacket convenience symlinks (impacket-* and non-.py) in $pipx_bin_dir..."
            for script in "$pipx_bin_dir"/*.py; do
                [ -f "$script" ] || continue
                local base_name
                base_name="$(basename "$script" .py)"
                # e.g. secretsdump -> secretsdump.py
                [ ! -e "${pipx_bin_dir}/${base_name}" ] && ln -sf "$script" "${pipx_bin_dir}/${base_name}"
                # e.g. impacket-secretsdump -> secretsdump.py
                [ ! -e "${pipx_bin_dir}/impacket-${base_name}" ] && ln -sf "$script" "${pipx_bin_dir}/impacket-${base_name}"
            done
            if [ -n "${SUDO_USER:-}" ]; then
                chown -h "${target_user}:${target_user}" "${pipx_bin_dir}"/* 2>/dev/null || true
            fi
        fi

        # Deploy central 'impacket' CLI runner
        sudo tee /usr/local/bin/impacket >/dev/null <<'EOF'
#!/usr/bin/env bash
#
# impacket - Central command runner and helper for Impacket tools suite
#

show_impacket_help() {
    echo -e "\033[1mImpacket Security Suite\033[0m - Network Protocol Testing Framework"
    echo "Usage: impacket <tool> [args...]"
    echo "       impacket-<tool> [args...]"
    echo "       <tool>.py [args...]"
    echo
    echo -e "\033[1mCommon Tools:\033[0m"
    printf "  %-22s %s\n" "secretsdump" "Dump SAM hashes, LSA secrets, and NTDS.dit"
    printf "  %-22s %s\n" "psexec" "PSEXEC-like process execution on remote Windows host"
    printf "  %-22s %s\n" "wmiexec" "Execute non-interactive commands via WMI"
    printf "  %-22s %s\n" "smbclient" "Interactive SMB client (upload/download/explore)"
    printf "  %-22s %s\n" "smbexec" "Interactive SMB execution via service"
    printf "  %-22s %s\n" "ntlmrelayx" "NTLM relay attack suite (HTTP/SMB/LDAP/MSSQL)"
    printf "  %-22s %s\n" "GetNPUsers" "Query AS-REP roasting (accounts with DONT_REQ_PREAUTH)"
    printf "  %-22s %s\n" "GetUserSPNs" "Kerberoast SPN discovery and ticket requester"
    printf "  %-22s %s\n" "ticketConverter" "Convert between ccache and kirbi Kerberos tickets"
    printf "  %-22s %s\n" "goldenPac" "MS14-068 exploit and Kerberos ticket generator"
    printf "  %-22s %s\n" "addcomputer" "Add a new computer account to Active Directory domain"
    printf "  %-22s %s\n" "mimikatz" "Execute Mimikatz via RPC"
    echo
    echo "Run 'impacket <tool> -h' for tool-specific help (e.g. impacket secretsdump -h)"
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_impacket_help
    exit 0
fi

TOOL="$1"
shift

# Check candidate paths
for CANDIDATE in "$HOME/.local/bin/${TOOL}.py" "$HOME/.local/bin/${TOOL}" "/usr/local/bin/${TOOL}.py" "${TOOL}.py" "${TOOL}"; do
    if command -v "$CANDIDATE" &>/dev/null; then
        exec "$CANDIDATE" "$@"
    fi
done

echo "Error: Impacket tool '${TOOL}' not found." >&2
echo "Run 'impacket --help' to view available tools." >&2
exit 1
EOF
        sudo chmod +x /usr/local/bin/impacket
        log_success "Impacket launcher and symlinks configured."
    fi
}

run_upstreams_install() {
    echo
    echo -e "${BOLD}Running Standalone Upstream Installers${NC}"
    echo "===================================================="

    if [ ! -x "$UPSTREAMS_SCRIPT" ]; then
        log_error "Upstream installer script not found or not executable: $UPSTREAMS_SCRIPT"
        return 1
    fi

    local upstream_args=()
    [ "$DRY_RUN" = true ] && upstream_args+=("--dry-run")
    [ -n "$ASSUME_YES" ] && upstream_args+=("--yes")
    upstream_args+=("all")

    "$UPSTREAMS_SCRIPT" "${upstream_args[@]}"
}
run_containers_install() {
    echo
    echo -e "${BOLD}Deploying Docker Containers (Portainer, SysReptor, BloodHound)${NC}"
    echo "===================================================="

    if [ ! -x "$UPSTREAMS_SCRIPT" ]; then
        log_error "Upstream installer script not found or not executable: $UPSTREAMS_SCRIPT"
        return 1
    fi

    local upstream_args=()
    [ "$DRY_RUN" = true ] && upstream_args+=("--dry-run")
    [ -n "$ASSUME_YES" ] && upstream_args+=("--yes")
    upstream_args+=("containers")

    "$UPSTREAMS_SCRIPT" "${upstream_args[@]}"
}

deploy_zsh_config() {
    echo
    echo -e "${BOLD}Deploying Kali-styled Zsh Configuration${NC}"
    echo "===================================================="
    local src_zsh="${SCRIPT_DIR}/zsh/.zshrc"
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local dest_zsh="${target_home}/.zshrc"

    if [ ! -f "$src_zsh" ]; then
        log_error "Source zsh config not found: $src_zsh"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] cp \${SCRIPT_DIR}/zsh/.zshrc to /home/\$USER/.zshrc (with backup if existing)"
        echo "  [DRY-RUN] sudo usermod -s \$(which zsh) \$USER"
    else
        if ! command -v zsh &>/dev/null; then
            log_info "zsh not found. Installing zsh packages via dnf..."
            sudo dnf install -y zsh zsh-autosuggestions zsh-syntax-highlighting || true
        fi
        if [ -f "$dest_zsh" ]; then
            local backup="${dest_zsh}.bak.$(date +%Y%m%d_%H%M%S)"
            log_info "Existing .zshrc found. Backing up to: $backup"
            cp "$dest_zsh" "$backup"
        fi
        cp "$src_zsh" "$dest_zsh"
        if [ -n "${SUDO_USER:-}" ]; then
            chown "${target_user}:${target_user}" "$dest_zsh"
        fi
        log_success "Deployed Kali .zshrc to $dest_zsh"

        if command -v zsh &>/dev/null; then
            local zsh_bin
            zsh_bin="$(which zsh)"
            local current_login_shell
            current_login_shell="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f7)"
            if [ "$current_login_shell" != "$zsh_bin" ]; then
                log_info "Setting default login shell to $zsh_bin for $target_user..."
                sudo usermod -s "$zsh_bin" "$target_user" || true
                log_success "Default login shell updated to $zsh_bin"
            fi
        fi
    fi
}

enable_hyprland_copr() {
    log_info "Enabling Hyprland COPR repository (lionheartp/Hyprland)..."
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo dnf install -y dnf-plugins-core"
        echo "  [DRY-RUN] sudo dnf copr enable -y lionheartp/Hyprland"
    else
        if ! rpm -q dnf-plugins-core &>/dev/null; then
            log_info "Ensuring dnf-plugins-core is installed..."
            sudo dnf install -y dnf-plugins-core || true
        fi
        sudo dnf copr enable -y lionheartp/Hyprland
        log_success "Hyprland COPR repository enabled."
    fi
}
configure_screensharing_systemd() {
    echo
    echo -e "${BOLD}Configuring Hyprland Screensharing (Systemd User Target)${NC}"
    echo "===================================================="
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local target_dir="${target_home}/.config/systemd/user"
    local target_file="${target_dir}/hyprland-session.target"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] mkdir -p /home/\$USER/.config/systemd/user"
        echo "  [DRY-RUN] Write /home/\$USER/.config/systemd/user/hyprland-session.target"
        echo "  [DRY-RUN] systemctl --user daemon-reload"
        echo "  [DRY-RUN] systemctl --user start hyprland-session.target xdg-desktop-portal"
    else
        mkdir -p "$target_dir"
        cat > "$target_file" <<'EOF'
[Unit]
Description=Hyprland session
BindsTo=graphical-session.target
Wants=graphical-session-pre.target
After=graphical-session-pre.target
PropagatesStopTo=graphical-session.target
EOF
        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "${target_user}:${target_user}" "$target_dir"
        fi
        log_success "Created $target_file"

        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user start hyprland-session.target 2>/dev/null || true
        systemctl --user start xdg-desktop-portal 2>/dev/null || true
        log_success "Hyprland screensharing user target configured."
    fi
}

deploy_hyprland_config() {
    echo
    echo -e "${BOLD}Deploying Hyprland Desktop & Noctalia Shell Configuration${NC}"
    echo "===================================================="
    local src_hypr="${SCRIPT_DIR}/hyprland/.config/hypr"
    local src_noctalia="${SCRIPT_DIR}/hyprland/.config/noctalia"
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local dest_hypr="${target_home}/.config/hypr"
    local dest_noctalia="${target_home}/.config/noctalia"

    if [ ! -d "$src_hypr" ]; then
        log_warn "Hyprland source directory not found: $src_hypr"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] mkdir -p /home/\$USER/.config/hypr /home/\$USER/.config/noctalia"
        echo "  [DRY-RUN] cp -r \${SCRIPT_DIR}/hyprland/.config/hypr/* to /home/\$USER/.config/hypr/"
        echo "  [DRY-RUN] cp -r \${SCRIPT_DIR}/hyprland/.config/noctalia/* to /home/\$USER/.config/noctalia/"
        echo "  [DRY-RUN] (or deploy via 'stow -d \${SCRIPT_DIR} -t /home/\$USER hyprland')"
    else
        mkdir -p "$dest_hypr"
        cp -r "$src_hypr"/* "$dest_hypr"/
        if [ -f "$src_hypr/.luarc.json" ]; then
            cp "$src_hypr/.luarc.json" "$dest_hypr"/
        fi

        # Deploy Noctalia shell configuration & Pendora palette
        if [ -d "$src_noctalia" ]; then
            mkdir -p "$dest_noctalia"
            cp -r "$src_noctalia"/* "$dest_noctalia"/
        fi

        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "${target_user}:${target_user}" "$dest_hypr" "$dest_noctalia" 2>/dev/null || true
        fi
        log_success "Deployed Hyprland and Noctalia configuration to $target_home/.config/"
    fi
}
deploy_alacritty_config() {
    echo
    echo -e "${BOLD}Deploying Alacritty & Catppuccin Macchiato Theme${NC}"
    echo "===================================================="
    local src_alacritty="${SCRIPT_DIR}/alacritty/.config/alacritty"
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local dest_alacritty="${target_home}/.config/alacritty"

    if [ ! -d "$src_alacritty" ]; then
        log_warn "Alacritty source directory not found: $src_alacritty"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] mkdir -p /home/\$USER/.config/alacritty"
        echo "  [DRY-RUN] cp -r \${SCRIPT_DIR}/alacritty/.config/alacritty/* to /home/\$USER/.config/alacritty/"
        echo "  [DRY-RUN] (or deploy via 'stow -d \${SCRIPT_DIR} -t /home/\$USER alacritty')"
    else
        if ! command -v alacritty &>/dev/null; then
            log_info "alacritty not found. Installing alacritty via dnf..."
            sudo dnf install -y alacritty || true
        fi
        mkdir -p "$dest_alacritty"
        cp -r "$src_alacritty"/* "$dest_alacritty"/
        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "${target_user}:${target_user}" "$dest_alacritty"
        fi
        log_success "Deployed Alacritty configuration & Catppuccin Macchiato theme to $dest_alacritty"
    fi
}
deploy_nvim_config() {
    echo
    echo -e "${BOLD}Deploying Neovim, LazyVim & Catppuccin Macchiato Theme${NC}"
    echo "===================================================="
    local src_nvim="${SCRIPT_DIR}/nvim/.config/nvim"
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local dest_nvim="${target_home}/.config/nvim"

    if [ ! -d "$src_nvim" ]; then
        log_warn "Neovim source directory not found: $src_nvim"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] mkdir -p /home/\$USER/.config/nvim"
        echo "  [DRY-RUN] cp -r \${SCRIPT_DIR}/nvim/.config/nvim/* to /home/\$USER/.config/nvim/"
        echo "  [DRY-RUN] (or deploy via 'stow -d \${SCRIPT_DIR} -t /home/\$USER nvim')"
    else
        if ! command -v nvim &>/dev/null; then
            log_info "neovim not found. Installing neovim via dnf..."
            sudo dnf install -y neovim || true
        fi
        mkdir -p "$dest_nvim"
        cp -r "$src_nvim"/* "$dest_nvim"/
        # Copy hidden files (.neoconf.json, stylua.toml, etc.)
        for dotf in "$src_nvim"/.*; do
            [ -f "$dotf" ] && cp "$dotf" "$dest_nvim"/
        done
        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "${target_user}:${target_user}" "$dest_nvim"
        fi
        log_success "Deployed Neovim & LazyVim Catppuccin configuration to $dest_nvim"
    fi
}
deploy_wallpaper() {
    echo
    echo -e "${BOLD}Deploying Pendora Desktop Wallpaper & User Profile Logo${NC}"
    echo "===================================================="
    local sys_wp_dir="/usr/share/backgrounds/pendora"
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local user_wp_dir="${target_home}/Pictures/wallpapers"
    local default_wp="${sys_wp_dir}/wallpaper.svg"

    if [ ! -d "${SCRIPT_DIR}/assets" ]; then
        log_warn "Assets directory not found: ${SCRIPT_DIR}/assets"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo mkdir -p $sys_wp_dir"
        echo "  [DRY-RUN] sudo cp \${SCRIPT_DIR}/assets/wallpaper*.svg $sys_wp_dir/"
        echo "  [DRY-RUN] mkdir -p $user_wp_dir"
        echo "  [DRY-RUN] cp \${SCRIPT_DIR}/assets/wallpaper*.svg $user_wp_dir/"
        echo "  [DRY-RUN] Set GNOME system-wide dconf default background to $default_wp"
        echo "  [DRY-RUN] gsettings set org.gnome.desktop.background picture-uri 'file://$default_wp'"
        echo "  [DRY-RUN] Copy assets/logo.png to /var/lib/AccountsService/icons/\$USER"
        echo "  [DRY-RUN] Update /var/lib/AccountsService/users/\$USER (Icon path)"
        echo "  [DRY-RUN] Copy assets/logo.png to /home/\$USER/.face and .face.icon"
        echo "  [DRY-RUN] Deploy assets/pendora_darkbackground.svg to $sys_wp_dir/"
        echo "  [DRY-RUN] Configure GNOME background-logo-extension to display Pendora watermark"
        echo "  [DRY-RUN] Update /usr/share/fedora-logos/ with Pendora watermark"
    else
        log_info "Installing wallpapers to system library ($sys_wp_dir)..."
        sudo mkdir -p "$sys_wp_dir"
        sudo cp "${SCRIPT_DIR}/assets"/wallpaper*.svg "$sys_wp_dir"/
        sudo chmod -R 644 "$sys_wp_dir"/*.svg 2>/dev/null || true
        sudo chmod 755 "$sys_wp_dir"

        log_info "Copying wallpapers to user library ($user_wp_dir)..."
        mkdir -p "$user_wp_dir"
        cp "${SCRIPT_DIR}/assets"/wallpaper*.svg "$user_wp_dir"/
        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "${target_user}:${target_user}" "$user_wp_dir"
        fi

        # 1. Apply system-wide default for GNOME via dconf
        local dconf_dir="/etc/dconf/db/local.d"
        sudo mkdir -p "$dconf_dir"
        sudo tee "${dconf_dir}/00-pendora-wallpaper" >/dev/null <<EOF
[org/gnome/desktop/background]
picture-uri='file://${default_wp}'
picture-uri-dark='file://${default_wp}'
picture-options='zoom'
EOF
        sudo dconf update 2>/dev/null || true

        # 2. Apply to current user session via gsettings if desktop session is active
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.background picture-uri "file://${default_wp}" 2>/dev/null || true
            gsettings set org.gnome.desktop.background picture-uri-dark "file://${default_wp}" 2>/dev/null || true
            gsettings set org.gnome.desktop.background picture-options 'zoom' 2>/dev/null || true
        fi

        # 3. Deploy User Profile Picture / Avatar (AccountsService and ~/.face)
        local logo_png="${SCRIPT_DIR}/assets/logo.png"
        if [ -f "$logo_png" ]; then
            log_info "Setting user profile picture to Pendora logo..."
            # AccountsService system icon
            sudo mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users
            sudo cp "$logo_png" "/var/lib/AccountsService/icons/${target_user}"
            sudo chmod 644 "/var/lib/AccountsService/icons/${target_user}"

            # AccountsService user configuration file
            local user_account_file="/var/lib/AccountsService/users/${target_user}"
            if [ -f "$user_account_file" ]; then
                if grep -q "^Icon=" "$user_account_file"; then
                    sudo sed -i "s|^Icon=.*|Icon=/var/lib/AccountsService/icons/${target_user}|" "$user_account_file"
                else
                    echo "Icon=/var/lib/AccountsService/icons/${target_user}" | sudo tee -a "$user_account_file" >/dev/null
                fi
            else
                sudo tee "$user_account_file" >/dev/null <<EOF
[User]
Icon=/var/lib/AccountsService/icons/${target_user}
EOF
            fi
            sudo chmod 600 "$user_account_file" 2>/dev/null || true

            # Display manager & desktop shell fallback (~/.face and ~/.face.icon)
            cp "$logo_png" "${target_home}/.face" 2>/dev/null || true
            cp "$logo_png" "${target_home}/.face.icon" 2>/dev/null || true
            if [ -n "${SUDO_USER:-}" ]; then
                chown "${target_user}:${target_user}" "${target_home}/.face" "${target_home}/.face.icon" 2>/dev/null || true
            fi
            log_success "User profile picture updated for '$target_user'."
        fi

        # 4. Deploy Desktop Corner Watermark (GNOME background-logo-extension)
        local watermark_svg="${SCRIPT_DIR}/assets/pendora_darkbackground.svg"
        if [ -f "$watermark_svg" ]; then
            log_info "Replacing desktop corner watermark with Pendora branding..."
            local dest_watermark="${sys_wp_dir}/pendora_darkbackground.svg"
            sudo cp "$watermark_svg" "$dest_watermark"
            sudo chmod 644 "$dest_watermark"

            # GNOME dconf override for background-logo-extension
            sudo tee "${dconf_dir}/01-pendora-background-logo" >/dev/null <<EOF
[org/fedorahosted/background-logo-extension]
logo-file='${dest_watermark}'
logo-file-dark='${dest_watermark}'
logo-always-visible=true
EOF
            sudo dconf update 2>/dev/null || true

            # Dynamic gsettings update if desktop session is active
            if command -v gsettings &>/dev/null; then
                gsettings set org.fedorahosted.background-logo-extension logo-file-dark "$dest_watermark" 2>/dev/null || true
                gsettings set org.fedorahosted.background-logo-extension logo-file "$dest_watermark" 2>/dev/null || true
                gsettings set org.fedorahosted.background-logo-extension logo-always-visible true 2>/dev/null || true
            fi

            # Direct fallback replacement in /usr/share/fedora-logos if directory exists
            if [ -d /usr/share/fedora-logos ]; then
                [ ! -f /usr/share/fedora-logos/fedora_darkbackground.svg.bak ] && sudo cp /usr/share/fedora-logos/fedora_darkbackground.svg /usr/share/fedora-logos/fedora_darkbackground.svg.bak 2>/dev/null || true
                sudo cp "$watermark_svg" /usr/share/fedora-logos/fedora_darkbackground.svg 2>/dev/null || true
                sudo cp "$watermark_svg" /usr/share/fedora-logos/fedora_lightbackground.svg 2>/dev/null || true
            fi
            log_success "Desktop corner watermark updated to Pendora branding."
        fi

        log_success "Pendora desktop branding deployed successfully."
    fi
}




set_system_hostname() {
    echo
    echo -e "${BOLD}Configuring System Hostname${NC}"
    echo "===================================================="
    local new_host="pendora"
    log_info "Setting system hostname to: ${BOLD}${new_host}${NC}..."
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo hostnamectl set-hostname $new_host"
    else
        sudo hostnamectl set-hostname "$new_host"
        log_success "System hostname updated to: $new_host"
    fi
}



# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            list_categories
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES="-y"
            shift
            ;;
        --no-reboot)
            REBOOT=false
            shift
            ;;
        -c|--category)
            if [ -z "${2:-}" ]; then
                log_error "Option $1 requires an argument."
                exit 1
            fi
            SELECTED_CATEGORIES+=("$2")
            shift 2
            ;;
        -p|--pipx)
            INSTALL_PIPX=true
            shift
            ;;
        -u|--upstreams)
            INSTALL_UPSTREAMS=true
            shift
            ;;
        -z|--zsh)
            INSTALL_ZSH=true
            shift
            ;;
        -b|--basic)
            RUN_BASIC=true
            INSTALL_PIPX=true
            INSTALL_UPSTREAMS=true
            INSTALL_ZSH=true
            INSTALL_ALACRITTY=true
            INSTALL_NVIM=true
            INSTALL_WALLPAPER=true
            SET_HOSTNAME=true
            INSTALL_HYPRLAND=false
            shift
            ;;
        -W|--hyprland)
            INSTALL_HYPRLAND=true
            INSTALL_WALLPAPER=true
            INSTALL_ZSH=true
            INSTALL_NVIM=true
            INSTALL_ALACRITTY=true
            shift
            ;;
        -T|--alacritty)
            INSTALL_ALACRITTY=true
            shift
            ;;
        -N|--nvim|--neovim)
            INSTALL_NVIM=true
            shift
            ;;
        -B|--wallpaper)
            INSTALL_WALLPAPER=true
            shift
            ;;
        -D|--docker|--containers)
            INSTALL_DOCKER_CONTAINERS=true
            shift
            ;;
        -H|--hostname)
            SET_HOSTNAME=true
            shift
            ;;
        -a|--all)
            RUN_ALL=true
            INSTALL_PIPX=true
            INSTALL_UPSTREAMS=true
            INSTALL_ZSH=true
            INSTALL_HYPRLAND=true
            INSTALL_ALACRITTY=true
            INSTALL_NVIM=true
            INSTALL_WALLPAPER=true
            SET_HOSTNAME=true
            shift
            ;;
        -f|--file)
            if [ -z "${2:-}" ]; then
                log_error "Option $1 requires an argument."
                exit 1
            fi
            CUSTOM_FILES+=("$2")
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

check_distro
check_non_root

# Resolve files to process
# Determine whether DNF packages should be installed
RUN_PACKAGES=false

if [ "$RUN_ALL" = true ] || [ "$RUN_BASIC" = true ] || [ ${#SELECTED_CATEGORIES[@]} -gt 0 ] || [ ${#CUSTOM_FILES[@]} -gt 0 ] || [ "$INSTALL_HYPRLAND" = true ] || [ "$INSTALL_DOCKER_CONTAINERS" = true ]; then
    RUN_PACKAGES=true
elif [ "$INSTALL_PIPX" = false ] && [ "$INSTALL_UPSTREAMS" = false ] && [ "$INSTALL_ZSH" = false ] && [ "$INSTALL_ALACRITTY" = false ] && [ "$INSTALL_NVIM" = false ] && [ "$INSTALL_WALLPAPER" = false ] && [ "$INSTALL_DOCKER_CONTAINERS" = false ] && [ "$SET_HOSTNAME" = false ]; then
    # Default invocation with no flags: install native packages (00-60)
    RUN_PACKAGES=true
fi

TARGET_FILES=()

if [ "$RUN_PACKAGES" = true ]; then
    if [ ${#CUSTOM_FILES[@]} -gt 0 ]; then
        for f in "${CUSTOM_FILES[@]}"; do
            if [ -f "$f" ]; then
                TARGET_FILES+=("$f")
            elif [ -f "${LISTS_DIR}/${f}" ]; then
                TARGET_FILES+=("${LISTS_DIR}/${f}")
            elif [ -f "${LISTS_DIR}/${f}.list" ]; then
                TARGET_FILES+=("${LISTS_DIR}/${f}.list")
            else
                log_error "Could not resolve file: $f"
                exit 1
            fi
        done
    elif [ ${#SELECTED_CATEGORIES[@]} -gt 0 ]; then
        for cat in "${SELECTED_CATEGORIES[@]}"; do
            matched=false
            for list_file in "${LISTS_DIR}"/*"${cat}"*.list; do
                if [ -f "$list_file" ]; then
                    TARGET_FILES+=("$list_file")
                    matched=true
                fi
            done
            if [ "$matched" = false ]; then
                log_error "No category list matching '$cat' found in ${LISTS_DIR}"
                exit 1
            fi
        done
    elif [ "$RUN_ALL" = true ]; then
        for list_file in "${LISTS_DIR}"/*.list; do
            [ -f "$list_file" ] && TARGET_FILES+=("$list_file")
        done
    elif [ "$INSTALL_HYPRLAND" = true ] && [ "$RUN_BASIC" = false ]; then
        TARGET_FILES+=("${LISTS_DIR}/70-hyprland.list")
    elif [ "$INSTALL_DOCKER_CONTAINERS" = true ] && [ "$RUN_BASIC" = false ]; then
        TARGET_FILES+=("${LISTS_DIR}/60-docker.list")
    else
        # Default or --basic: process 00-60 (skip 70-hyprland)
        for list_file in "${LISTS_DIR}"/*.list; do
            [[ "$list_file" =~ "70-hyprland" ]] && continue
            [ -f "$list_file" ] && TARGET_FILES+=("$list_file")
        done
    fi

    ALL_PACKAGES=()

    echo -e "${BOLD}Pendora - Native DNF Package Plan${NC}"
    echo "===================================================="

    for file in "${TARGET_FILES[@]}"; do
        filename="$(basename "$file")"
        log_info "Reading: ${BOLD}${filename}${NC}"
        mapfile -t pkgs < <(parse_package_file "$file")
        if [ ${#pkgs[@]} -gt 0 ]; then
            for p in "${pkgs[@]}"; do
                ALL_PACKAGES+=("$p")
            done
            echo "  -> Found ${#pkgs[@]} packages in ${filename}"
        else
            echo "  -> 0 packages in ${filename}"
        fi
    done

    echo "===================================================="
    log_info "Total native DNF packages to process: ${BOLD}${#ALL_PACKAGES[@]}${NC}"

    # Enable COPR if Hyprland packages are included
    for f in "${TARGET_FILES[@]}"; do
        if [[ "$f" =~ "70-hyprland" ]]; then
            enable_hyprland_copr
            break
        fi
    done

    if [ "$DRY_RUN" = true ]; then
        log_info "Dry run requested. Planned DNF command:"
        echo
        echo "sudo dnf install ${ASSUME_YES} ${ALL_PACKAGES[*]}"
        echo
    else
        if [ -z "$ASSUME_YES" ]; then
            echo
            read -rp "Proceed with DNF installation? [y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                log_warn "DNF installation aborted by user."
            else
                log_info "Executing: sudo dnf install ${ASSUME_YES} ..."
                sudo dnf install $ASSUME_YES "${ALL_PACKAGES[@]}"
                log_success "DNF packages installed successfully."
            fi
        else
            log_info "Executing: sudo dnf install ${ASSUME_YES} ..."
            sudo dnf install $ASSUME_YES "${ALL_PACKAGES[@]}"
            log_success "DNF packages installed successfully."
        fi
    fi

    # If Docker packages were installed, immediately enable service and add user to docker group
    for f in "${TARGET_FILES[@]}"; do
        if [[ "$f" =~ "60-docker" ]]; then
            target_user="${SUDO_USER:-$USER}"
            log_info "Enabling Docker service and adding '$target_user' to docker group..."
            if [ "$DRY_RUN" = true ]; then
                echo "  [DRY-RUN] sudo systemctl enable --now docker"
                echo "  [DRY-RUN] sudo usermod -aG docker $target_user"
            else
                sudo systemctl enable --now docker 2>/dev/null || true
                sudo usermod -aG docker "$target_user" 2>/dev/null || true
                log_success "Docker service enabled and user '$target_user' added to docker group."
            fi
            break
        fi
    done
fi

# Configure screensharing systemd target if Hyprland is requested
if [ "$INSTALL_HYPRLAND" = true ]; then
    configure_screensharing_systemd
fi

# Run Pipx section if requested
if [ "$INSTALL_PIPX" = true ]; then
    run_pipx_install
fi

# Run Upstreams section if requested
if [ "$INSTALL_UPSTREAMS" = true ]; then
    run_upstreams_install
fi

# Deploy Zsh configuration if requested
if [ "$INSTALL_ZSH" = true ]; then
    deploy_zsh_config
fi

# Deploy Hyprland configuration if requested
if [ "$INSTALL_HYPRLAND" = true ]; then
    deploy_hyprland_config
fi

# Deploy Alacritty configuration if requested
if [ "$INSTALL_ALACRITTY" = true ]; then
    deploy_alacritty_config
fi

# Run Docker containers section if requested
if [ "$INSTALL_DOCKER_CONTAINERS" = true ]; then
    run_containers_install
fi

# Deploy Neovim configuration if requested
if [ "$INSTALL_NVIM" = true ]; then
    deploy_nvim_config
fi

# Deploy wallpaper if requested
if [ "$INSTALL_WALLPAPER" = true ]; then
    deploy_wallpaper
fi

# Set system hostname if requested
if [ "$SET_HOSTNAME" = true ]; then
    set_system_hostname
fi

log_success "Pendora execution completed!"

# Do not prompt for reboot if only wallpaper & profile logo was deployed
if [ "$INSTALL_WALLPAPER" = true ] && [ "$RUN_ALL" = false ] && [ "$RUN_BASIC" = false ] && [ "$RUN_PACKAGES" = false ] && [ "$INSTALL_PIPX" = false ] && [ "$INSTALL_UPSTREAMS" = false ] && [ "$INSTALL_ZSH" = false ] && [ "$INSTALL_HYPRLAND" = false ] && [ "$INSTALL_ALACRITTY" = false ] && [ "$INSTALL_NVIM" = false ] && [ "$INSTALL_DOCKER_CONTAINERS" = false ] && [ "$SET_HOSTNAME" = false ]; then
    REBOOT=false
fi

if [ "$REBOOT" = true ]; then
    echo
    echo -e "${BOLD}System Reboot${NC}"
    echo "===================================================="
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] sudo reboot"
    else
        log_info "A system reboot is required to apply shell changes, group permissions, and session targets."
        if [ -n "$ASSUME_YES" ]; then
            log_info "Rebooting system in 5 seconds (Press Ctrl+C to cancel)..."
            sleep 5
            sudo reboot
        else
            read -rp "Reboot system now? [Y/n]: " do_reboot
            if [[ ! "$do_reboot" =~ ^[Nn]$ ]]; then
                log_info "Rebooting system now..."
                sudo reboot
            else
                log_warn "Reboot deferred. Remember to reboot manually: sudo reboot"
            fi
        fi
    fi
fi

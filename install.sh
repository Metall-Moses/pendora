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
SET_HOSTNAME=false
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
  -z, --zsh                Deploy Kali-styled .zshrc configuration
  -W, --hyprland           Install Hyprland desktop stack, COPR, screensharing, and dotfiles
  -T, --alacritty          Deploy Alacritty terminal configuration & Catppuccin Macchiato theme
  -N, --nvim               Deploy Neovim/LazyVim configuration & Catppuccin Macchiato theme
  -H, --hostname           Set system hostname to 'pendora'
  -b, --basic              Basic pentest setup without Hyprland (00-60 DNF + pipx + upstreams + zsh + alacritty + nvim)
  -a, --all                Full setup including Hyprland desktop stack

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
    echo "  - portainer    (Portainer Community Edition UI on port 7999)"
    echo "  - sysreptor    (SysReptor pentest reporting platform on port 8000)"
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
        pipx ensurepath 2>/dev/null || true
    fi

    log_info "Total pipx tools to install: ${#pipx_pkgs[@]}"
    for tool in "${pipx_pkgs[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY-RUN] pipx install $tool"
        else
            log_info "Running: pipx install $tool"
            pipx install "$tool" || log_warn "pipx install failed for: $tool"
        fi
    done
    log_success "Pipx processing complete."
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
        echo "  [DRY-RUN] chsh -s \$(which zsh)"
    else
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

        if command -v zsh &>/dev/null && [ "${SHELL:-}" != "$(which zsh)" ]; then
            log_info "Zsh is installed. You can set it as default shell with: chsh -s \$(which zsh)"
        fi
    fi
}
enable_hyprland_copr() {
    log_info "Enabling Hyprland COPR repository (lionheartp/Hyprland)..."
    local cmd="sudo dnf copr enable -y lionheartp/Hyprland"
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] $cmd"
    else
        $cmd
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
    echo -e "${BOLD}Deploying Hyprland Desktop Configuration${NC}"
    echo "===================================================="
    local src_hypr="${SCRIPT_DIR}/hyprland/.config/hypr"
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)"
    [ -z "$target_home" ] && target_home="$HOME"
    local dest_hypr="${target_home}/.config/hypr"

    if [ ! -d "$src_hypr" ]; then
        log_warn "Hyprland source directory not found: $src_hypr"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] mkdir -p /home/\$USER/.config/hypr"
        echo "  [DRY-RUN] cp -r \${SCRIPT_DIR}/hyprland/.config/hypr/* to /home/\$USER/.config/hypr/"
        echo "  [DRY-RUN] (or deploy via 'stow -d \${SCRIPT_DIR} -t /home/\$USER hyprland')"
    else
        mkdir -p "$dest_hypr"
        cp -r "$src_hypr"/* "$dest_hypr"/
        if [ -f "$src_hypr/.luarc.json" ]; then
            cp "$src_hypr/.luarc.json" "$dest_hypr"/
        fi
        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "${target_user}:${target_user}" "$dest_hypr"
        fi
        log_success "Deployed Hyprland configuration to $dest_hypr"
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
            INSTALL_PIPX=true
            INSTALL_UPSTREAMS=true
            INSTALL_ZSH=true
            INSTALL_ALACRITTY=true
            INSTALL_NVIM=true
            SET_HOSTNAME=true
            INSTALL_HYPRLAND=false
            shift
            ;;
        -W|--hyprland)
            INSTALL_HYPRLAND=true
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
        -H|--hostname)
            SET_HOSTNAME=true
            shift
            ;;
        -a|--all)
            INSTALL_PIPX=true
            INSTALL_UPSTREAMS=true
            INSTALL_ZSH=true
            INSTALL_HYPRLAND=true
            INSTALL_ALACRITTY=true
            INSTALL_NVIM=true
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
TARGET_FILES=()

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
else
    # Default: process all files in order (skip 70-hyprland unless Hyprland requested)
    for list_file in "${LISTS_DIR}"/*.list; do
        if [ "$INSTALL_HYPRLAND" = false ] && [[ "$list_file" =~ "70-hyprland" ]]; then
            continue
        fi
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

if [ "$INSTALL_HYPRLAND" = true ]; then
    enable_hyprland_copr
fi

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

# Deploy Neovim configuration if requested
if [ "$INSTALL_NVIM" = true ]; then
    deploy_nvim_config
fi

# Set system hostname if requested
if [ "$SET_HOSTNAME" = true ]; then
    set_system_hostname
fi

log_success "Pendora execution completed!"

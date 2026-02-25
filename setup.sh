#!/bin/bash
# Professional Ubuntu Development Environment Setup
# High-signal, idempotent, and Docker-aware automation.

set -e
set -o pipefail

# --- Globals ---
LOG_FILE="/tmp/ubuntu_setup_$(date +%Y%m%d_%H%M%S).log"
VERBOSE=false
INSTALLED=(); SKIPPED=(); FAILED=(); INCOMPATIBLE=()
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; NC='\033[0m'

# --- Helpers ---
log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_skip()    { echo -e "${YELLOW}[SKIP]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_incompat(){ echo -e "${MAGENTA}[N/A]${NC}   $1 (Incompatible environment)"; }

print_summary() {
    local title="$1"; local color="$2"; shift 2; local items=("$@")
    if [ ${#items[@]} -gt 0 ]; then
        echo -e "\n${color}${title}:${NC}"
        printf "  - %s\n" "${items[@]}"
    fi
}

on_failure() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        echo -e "\n${RED}!!! Installation Failed (Exit Code: $exit_code) !!!${NC}"
        if [ -f "$LOG_FILE" ]; then
            echo -e "${YELLOW}--- Verbose Log Output (from $LOG_FILE) ---${NC}"
            cat "$LOG_FILE"
        fi
    fi
}

cleanup() {
    if [ -n "$SUDO_ALIVE_PID" ]; then
        kill "$SUDO_ALIVE_PID" 2>/dev/null || true
    fi
}
trap "on_failure; cleanup" EXIT

keep_sudo_alive() {
    while true; do sudo -n -v 2>/dev/null || true; sleep 60; done
}

is_container() {
    if [ -n "$container" ] || [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
        return 0
    fi
    if grep -qE "docker|podman|containerd" /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    return 1
}

is_bare_metal() {
    if is_container; then return 1; fi
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        ! systemd-detect-virt --quiet
        return $?
    fi
    return 0
}

prime_sudo() {
    if ! is_container && [ -t 1 ] && [ -c /dev/tty ]; then
        if ! sudo -n true 2>/dev/null; then
            log_warn "Sudo privileges required. Please enter your password:"
            sudo -v < /dev/tty || return 1
        fi
    fi
    return 0
}

run_quiet() {
    if [ "$VERBOSE" = true ]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
    else
        "$@" >> "$LOG_FILE" 2>&1
    fi
}

show_spinner() {
    local pid=$1; local spinstr='|/-\'
    if [ -t 1 ] && [ "$VERBOSE" = false ]; then
        while kill -0 "$pid" 2>/dev/null; do
            local temp=${spinstr#?}; printf " [%c]  " "$spinstr"; spinstr=$temp${spinstr%"$temp"}
            sleep 0.1; printf "\b\b\b\b\b\b"
        done; printf "    \b\b\b\b"
    fi
}

run_logged() {
    local msg="$1"; shift
    if [[ "$*" == *"sudo"* ]]; then
        prime_sudo
    fi
    
    local status=0
    if [ "$VERBOSE" = true ]; then
        log_info "$msg..."
        "$@" 2>&1 | tee -a "$LOG_FILE" || status=$?
    else
        printf "${BLUE}[INFO]${NC}  $msg... "
        # Run in a subshell to ensure redirections and backgrounding are clean
        ( "$@" ) >> "$LOG_FILE" 2>&1 &
        local pid=$!
        show_spinner "$pid"
        wait "$pid" || status=$?
    fi

    if [ $status -eq 0 ]; then
        if [ "$VERBOSE" = true ]; then
            log_success "$msg."
        else
            printf "\r${GREEN}[OK]${NC}    $msg.   \n"
        fi
        return 0
    else
        if [ "$VERBOSE" = false ]; then printf "\r"; fi
        log_error "$msg. Check $LOG_FILE"
        return 1
    fi
}

source_nvm() {
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    fi
}

execute_tool() {
    local bin="$1" name="$2" func="$3"; shift 3
    if [[ "$bin" =~ ^(nvm|npm|node|gemini|tldr)$ ]]; then
        source_nvm
    fi
    
    if command -v "$bin" >/dev/null 2>&1; then
        log_skip "$name is already installed."
        SKIPPED+=("$name")
    else
        if run_logged "Installing $name" "$func" "$@"; then
            INSTALLED+=("$name")
        else
            FAILED+=("$name")
        fi
    fi
}

# --- Generic Helpers ---
apt_install() {
    run_quiet sudo apt-get install -y "$@"
}

add_apt_repo() {
    local key_url="$1" name="$2" repo_line="$3"
    local keyring_dir="/etc/apt/keyrings"
    local keyring_path="${keyring_dir}/${name}.gpg"
    local list_path="/etc/apt/sources.list.d/${name}.list"
    
    sudo mkdir -p -m 755 "$keyring_dir"
    
    local tmp_key; tmp_key=$(mktemp)
    if ! curl -fsSL "$key_url" -o "$tmp_key"; then
        rm -f "$tmp_key"
        return 1
    fi
    
    if grep -q "BEGIN PGP" "$tmp_key"; then
        cat "$tmp_key" | gpg --dearmor | sudo tee "$keyring_path" > /dev/null
    else
        sudo cp "$tmp_key" "$keyring_path"
    fi
    rm -f "$tmp_key"
    sudo chmod 644 "$keyring_path"
    
    echo "$repo_line" | sudo tee "$list_path" > /dev/null
    
    # Validate the repo with a targeted update
    if ! run_quiet sudo apt-get update -o Dir::Etc::sourcelist="$list_path" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"; then
        sudo rm -f "$list_path" "$keyring_path"
        return 1
    fi
    return 0
}

github_bin_install() {
    local repo="$1" bin_name="$2" asset_pattern="$3"
    local v; v=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name)
    local url; url="https://github.com/${repo}/releases/download/${v}/${asset_pattern//\{v\}/$v}"
    mkdir -p "$HOME/.local/bin"
    wget -qO "/tmp/${bin_name}.tar.gz" "$url"
    tar -xzf "/tmp/${bin_name}.tar.gz" -C "$HOME/.local/bin" "$bin_name"
    rm "/tmp/${bin_name}.tar.gz"
}

safe_gsettings_set() {
    local schema="$1" key="$2" value="$3"
    if ! command -v gsettings >/dev/null 2>&1; then
        return 0
    fi
    
    # Verify schema and key exist before proceeding
    if ! gsettings range "$schema" "$key" >/dev/null 2>&1; then
        log_warn "GSettings schema/key not found: $schema $key"
        return 0
    fi

    # Normalize values for comparison (remove types like 'uint32', '@as', and quotes)
    local clean_value; clean_value=$(echo "$value" | sed -E "s/^([a-z0-9]+|@[a-z0-9]+) //; s/^'//; s/'$//")
    local current_raw; 
    
    if current_raw=$(gsettings get "$schema" "$key" 2>/dev/null); then
        local clean_current; clean_current=$(echo "$current_raw" | sed -E "s/^([a-z0-9]+|@[a-z0-9]+) //; s/^'//; s/'$//")
        
        if [ "$clean_current" != "$clean_value" ]; then
            if run_logged "Configuring $key" gsettings set "$schema" "$key" "$value"; then
                INSTALLED+=("$key")
            else
                FAILED+=("$key")
            fi
        else
            log_skip "$key is already configured."
            SKIPPED+=("$key")
        fi
    else
        log_error "Failed to read GSetting $key from $schema. Is D-Bus running?"
        FAILED+=("$key")
    fi
}

# --- Specialized Installers ---
install_bat() {
    apt_install bat
    mkdir -p "$HOME/.local/bin"
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
}

install_uv() {
    curl -LsSf https://astral.sh/uv/install.sh | run_quiet sh
}

install_nvm() {
    local v; v=$(basename "$(curl -Ls -o /dev/null -w "%{url_effective}" https://github.com/nvm-sh/nvm/releases/latest)")
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${v:-v0.39.7}/install.sh" | run_quiet bash
    source_nvm
    if ! command -v node >/dev/null 2>&1; then
        run_quiet nvm install --lts
    fi
}

install_gh() {
    add_apt_repo "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "github-cli" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/github-cli.gpg] https://cli.github.com/packages stable main" && \
    apt_install gh
}

install_vscode() {
    add_apt_repo "https://packages.microsoft.com/keys/microsoft.asc" "vscode" \
        "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/vscode.gpg] https://packages.microsoft.com/repos/code stable main" && \
    apt_install code
}

install_chrome() {
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then
        return 1
    fi
    wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt_install /tmp/chrome.deb
    rm /tmp/chrome.deb
}

install_opentofu() {
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/tofu.sh
    chmod +x /tmp/tofu.sh
    run_quiet /tmp/tofu.sh --install-method deb
    rm /tmp/tofu.sh
}

install_gcloud() {
    add_apt_repo "https://packages.cloud.google.com/apt/doc/apt-key.gpg" "google-cloud" \
        "deb [signed-by=/etc/apt/keyrings/google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main" && \
    apt_install google-cloud-cli
}

install_kubectl() {
    add_apt_repo "https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key" "kubernetes" \
        "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" && \
    apt_install kubectl
}

install_kubectx() {
    local v; v=$(curl -s https://api.github.com/repos/ahmetb/kubectx/releases/latest | jq -r .tag_name)
    mkdir -p "$HOME/.local/bin"
    for tool in kubectx kubens; do
        wget -qO "/tmp/${tool}.tar.gz" "https://github.com/ahmetb/kubectx/releases/download/${v}/${tool}_${v}_linux_x86_64.tar.gz"
        tar -xzf "/tmp/${tool}.tar.gz" -C "$HOME/.local/bin" "$tool"
        rm "/tmp/${tool}.tar.gz"
    done
}

install_aws() {
    wget -qO /tmp/aws.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
    unzip -q /tmp/aws.zip -d /tmp
    run_quiet sudo /tmp/aws/install --update
    rm -rf /tmp/aws /tmp/aws.zip
}

install_az()      { curl -sL https://aka.ms/InstallAzureCLIDeb | run_quiet sudo bash; }
install_k9s()     { github_bin_install "derailed/k9s" "k9s" "k9s_Linux_amd64.tar.gz"; }
install_yq()      { sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq; }
install_gemini()  { run_quiet npm install -g @google/gemini-cli; }
install_tldr()    { run_quiet npm install -g tldr; }

install_nvidia() {
    apt_install ubuntu-drivers-common
    run_quiet sudo ubuntu-drivers install
    add_apt_repo "https://nvidia.github.io/libnvidia-container/gpgkey" "nvidia" \
        "deb [signed-by=/etc/apt/keyrings/nvidia.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list /" && \
    apt_install nvidia-container-toolkit
}

# --- Configuration ---
configure_system() {
    if run_logged "Updating system and maintenance" bash -c "sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean"; then
        INSTALLED+=("System Updates")
    else
        FAILED+=("System Updates")
    fi

    local needs_disable=false
    for svc in apport whoopsie; do
        if systemctl is-enabled "$svc" 2>/dev/null | grep -qE "^enabled" || systemctl is-active "$svc" 2>/dev/null | grep -qE "^active"; then
            needs_disable=true; break
        fi
    done

    if [ "$needs_disable" = true ]; then
        if run_logged "Disabling error reporting" bash -c "sudo systemctl disable --now apport whoopsie 2>/dev/null || true"; then
            INSTALLED+=("Error Reporting Disabled")
        else
            FAILED+=("Error Reporting Disabled")
        fi
    else
        log_skip "Error reporting services are already disabled or inactive."
        SKIPPED+=("Error Reporting Disabled")
    fi

    if [ -n "$DISPLAY" ] && command -v gsettings >/dev/null 2>&1; then
        log_info "Environment check: DISPLAY='$DISPLAY', gsettings found."
        if ! gsettings list-schemas >/dev/null 2>&1; then
            log_warn "gsettings is available but cannot communicate with D-Bus. Skipping GNOME customizations."
        else
            log_info "Applying GNOME Desktop customizations..."
            if command -v powerprofilesctl >/dev/null 2>&1; then
                if [ "$(powerprofilesctl get)" != "performance" ]; then
                    if run_logged "Setting power profile to performance" sudo powerprofilesctl set performance; then
                        INSTALLED+=("Power Profile")
                    else
                        FAILED+=("Power Profile")
                    fi
                else
                    log_skip "Power profile is already set to performance."
                    SKIPPED+=("Power Profile")
                fi
            fi
            
            safe_gsettings_set "org.gnome.shell.extensions.dash-to-dock" "dock-position" "BOTTOM"
            safe_gsettings_set "org.gnome.shell.extensions.dash-to-dock" "intellihide" "true"
            safe_gsettings_set "org.gnome.shell.extensions.dash-to-dock" "dock-fixed" "false"
            safe_gsettings_set "org.gnome.shell.extensions.dash-to-dock" "extend-height" "false"
            safe_gsettings_set "org.gnome.shell.extensions.dash-to-dock" "dash-max-icon-size" "32"
            safe_gsettings_set "org.gnome.shell.extensions.ding" "icon-size" "'small'"
            safe_gsettings_set "org.gnome.shell.extensions.ding" "new-icons-location" "'top-left'"
            safe_gsettings_set "org.gnome.shell.extensions.ding" "show-home" "false"
            safe_gsettings_set "org.gnome.mutter" "experimental-features" "[]"
            safe_gsettings_set "org.gnome.mutter" "workspaces-only-on-primary" "false"
            safe_gsettings_set "org.gnome.desktop.session" "idle-delay" "900"
            safe_gsettings_set "org.gnome.desktop.privacy" "report-technical-problems" "false"
            safe_gsettings_set "org.gnome.desktop.interface" "color-scheme" "'prefer-dark'"
            safe_gsettings_set "org.gnome.desktop.background" "picture-uri-dark" "'file:///usr/share/backgrounds/Quokka_Everywhere_by_Dilip.png'"
        fi
    else
        log_incompat "GNOME Desktop settings (DISPLAY not set or gsettings missing)"
        INCOMPATIBLE+=("GNOME Desktop settings")
    fi

    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "GIT_PS1_SHOWDIRTYSTATE" "$HOME/.bashrc"; then
            if run_logged "Configuring bash prompt" bash -c "cat << 'EOF' >> \"$HOME/.bashrc\"
if [ -f /usr/lib/git-core/git-sh-prompt ]; then
    . /usr/lib/git-core/git-sh-prompt
    export GIT_PS1_SHOWDIRTYSTATE=1
    export PS1='\${debian_chroot:+(\$debian_chroot)}\\[\\033[01;32m\\]\\u@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[01;33m\\]\$(__git_ps1 \" (%s)\")\\[\\033[00m\]\\$ '
fi
export PATH=\"\$HOME/.local/bin:\$PATH\"
EOF"; then
                INSTALLED+=("Bash Prompt")
            else
                FAILED+=("Bash Prompt")
            fi
        else
            log_skip "Bash prompt is already configured."
            SKIPPED+=("Bash Prompt")
        fi
    fi
}

# --- Main ---
main() {
    # Argument parsing
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose) VERBOSE=true; shift ;;
            *) shift ;;
        esac
    done

    touch "$LOG_FILE"; echo -e "${BLUE}=== Ubuntu Setup ===${NC}\nLogs: $LOG_FILE"
    if [ "$VERBOSE" = true ]; then log_info "Verbose mode enabled."; fi

    prime_sudo
    keep_sudo_alive & SUDO_ALIVE_PID=$!
    configure_system

    source_nvm
    export PATH="$HOME/.local/bin:$PATH"

    run_logged "Ensuring base requirements" apt_install curl wget gpg gnupg pciutils build-essential unzip

    # CLI Toolchain
    execute_tool "git"      "Git"            apt_install git
    execute_tool "gh"       "GitHub CLI"     install_gh
    execute_tool "uv"       "uv"             install_uv
    execute_tool "podman"   "Podman"         apt_install podman
    execute_tool "nvm"      "nvm/Node"       install_nvm
    execute_tool "htop"     "htop"           apt_install htop
    execute_tool "nano"     "nano"           apt_install nano
    execute_tool "jq"       "jq"             apt_install jq
    execute_tool "yq"       "yq"             install_yq
    execute_tool "tree"     "tree"           apt_install tree
    execute_tool "bat"      "bat"            install_bat
    execute_tool "podman-compose" "Compose"  apt_install podman-compose
    
    # DevOps & IaC
    execute_tool "tofu"     "OpenTofu"       install_opentofu
    execute_tool "ansible"  "Ansible"        apt_install ansible

    # Cloud & Kubernetes
    execute_tool "gcloud"   "Google Cloud"   install_gcloud
    execute_tool "kubectl"  "kubectl"        install_kubectl
    execute_tool "kubectx"  "kubectx/kubens" install_kubectx
    execute_tool "aws"      "AWS CLI"        install_aws
    execute_tool "az"       "Azure CLI"      "install_az"
    execute_tool "k9s"      "k9s"            install_k9s

    # Node tools
    execute_tool "gemini"   "Gemini CLI"     install_gemini
    execute_tool "tldr"     "tldr"           install_tldr

    # Hardware Specific
    if ! is_container; then
        if command -v lspci >/dev/null 2>&1 && lspci | grep -iq "nvidia"; then
            execute_tool "nvidia-smi" "NVIDIA Driver" install_nvidia
        fi
    else
        log_incompat "NVIDIA Drivers"
        INCOMPATIBLE+=("NVIDIA Drivers")
    fi

    # GUI Applications
    if [ -n "$DISPLAY" ] || [ -n "$XDG_CURRENT_DESKTOP" ]; then
        execute_tool "code"   "VS Code" install_vscode
        execute_tool "google-chrome-stable" "Chrome" install_chrome
    else
        log_incompat "GUI Applications (VS Code, Chrome)"
        INCOMPATIBLE+=("VS Code")
        INCOMPATIBLE+=("Chrome")
    fi

    echo -e "\n${GREEN}==========================================${NC}"
    log_success "Setup Complete!"
    print_summary "Installed/Configured" "$BLUE" "${INSTALLED[@]}"
    print_summary "Skipped (Installed)" "$YELLOW" "${SKIPPED[@]}"
    print_summary "Skipped (Incompatible)" "$MAGENTA" "${INCOMPATIBLE[@]}"
    print_summary "Failed" "$RED" "${FAILED[@]}"
    echo -e "\n${GREEN}==========================================${NC}"
    echo -e "Run 'source ~/.bashrc' to apply changes."
}

main "$@"

#!/bin/bash
# Professional Ubuntu Development Environment Setup
# High-signal, idempotent, and Docker-aware automation.

set -e

# --- Globals ---
LOG_FILE="/tmp/ubuntu_setup_$(date +%Y%m%d_%H%M%S).log"
INSTALLED=(); SKIPPED=(); FAILED=()
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# --- Helpers ---
log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

on_failure() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then
        echo -e "\n${RED}!!! Installation Failed (Exit Code: $exit_code) !!!${NC}"
        if [ -f "$LOG_FILE" ]; then
            echo -e "${YELLOW}--- Verbose Log Output (from $LOG_FILE) ---${NC}"
            cat "$LOG_FILE"
            echo -e "${YELLOW}--- End of Log ---${NC}"
        fi
    fi
}

cleanup() {
    [ -n "$SUDO_ALIVE_PID" ] && kill "$SUDO_ALIVE_PID" 2>/dev/null || true
}
trap "on_failure; cleanup" EXIT

keep_sudo_alive() {
    while true; do sudo -n -v 2>/dev/null || true; sleep 60; done
}

# Detect if running in a non-interactive environment or container
is_container() {
    [ -f /.dockerenv ] || grep -qE "docker|podman|containerd" /proc/1/cgroup 2>/dev/null
}

prime_sudo() {
    if ! is_container && [ -t 1 ]; then
        if ! sudo -n true 2>/dev/null; then
            log_warn "Sudo privileges required. Please enter your password:"
            # Redirect from /dev/tty ensures this works even when script is piped (curl | bash)
            sudo -v < /dev/tty || return 1
        fi
    fi
    return 0
}

run_quiet() { "$@" >> "$LOG_FILE" 2>&1; }

show_spinner() {
    local pid=$1; local spinstr='|/-\'
    if [ -t 1 ]; then
        while kill -0 "$pid" 2>/dev/null; do
            local temp=${spinstr#?}; printf " [%c]  " "$spinstr"; spinstr=$temp${spinstr%"$temp"}
            sleep 0.1; printf "\b\b\b\b\b\b"
        done; printf "    \b\b\b\b"
    else wait "$pid"; fi
}

run_logged() {
    local msg="$1"; shift; [[ "$*" == *"sudo"* ]] && prime_sudo
    printf "${BLUE}[INFO]${NC}  $msg... "
    "$@" >> "$LOG_FILE" 2>&1 &
    show_spinner $!; wait $! && (printf "\r${GREEN}[OK]${NC}    $msg.   \n"; return 0) || (printf "\r${RED}[ERROR]${NC} $msg. Check $LOG_FILE\n"; return 1)
}

source_nvm() {
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    fi
    return 0
}

execute_tool() {
    local bin="$1" name="$2" func="$3"
    [[ "$bin" =~ ^(nvm|npm|node|gemini|tldr)$ ]] && source_nvm
    if command -v "$bin" >/dev/null 2>&1; then
        log_info "$name is already installed."; SKIPPED+=("$name")
    else
        if run_logged "Installing $name" $func; then
            INSTALLED+=("$name")
        else
            FAILED+=("$name")
        fi
    fi
}

safe_gsettings_set() {
    local schema="$1" key="$2" value="$3"
    if gsettings list-schemas | grep -q "^$schema$" && gsettings list-keys "$schema" | grep -q "^$key$"; then
        log_info "Configuring $key..."; run_quiet gsettings set "$schema" "$key" "$value"
    fi
}

# --- Installers ---
install_git()    { run_quiet sudo apt-get install -y git; }
install_htop()   { run_quiet sudo apt-get install -y htop; }
install_nano()   { run_quiet sudo apt-get install -y nano; }
install_podman() { run_quiet sudo apt-get install -y podman; }
install_jq()     { run_quiet sudo apt-get install -y jq; }
install_tree()   { run_quiet sudo apt-get install -y tree; }
install_compose() { run_quiet sudo apt-get install -y podman-compose; }
install_ansible() { run_quiet sudo apt-get install -y ansible; }

install_uv() {
    curl -LsSf https://astral.sh/uv/install.sh | run_quiet sh
}

install_bat() {
    run_quiet sudo apt-get install -y bat
    mkdir -p "$HOME/.local/bin"
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
}

install_nvm() {
    local v; v=$(basename "$(curl -Ls -o /dev/null -w "%{url_effective}" https://github.com/nvm-sh/nvm/releases/latest)")
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${v:-v0.39.7}/install.sh" | run_quiet bash
    source_nvm; ! command -v node >/dev/null 2>&1 && run_quiet nvm install --lts
}

install_gh() {
    sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    run_quiet sudo apt-get update && run_quiet sudo apt-get install -y gh
}

install_vscode() {
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null
    echo "Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/vscode.sources > /dev/null
    run_quiet sudo apt-get update && run_quiet sudo apt-get install -y code
}

install_chrome() {
    if [ "$(dpkg --print-architecture)" == "amd64" ]; then
        wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        run_quiet sudo apt-get install -y /tmp/chrome.deb && rm /tmp/chrome.deb
    else return 1; fi
}

install_nvidia_drivers() {
    run_quiet sudo apt-get install -y ubuntu-drivers-common && run_quiet sudo ubuntu-drivers install
}

install_nvidia_toolkit() {
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    run_quiet sudo apt-get update && run_quiet sudo apt-get install -y nvidia-container-toolkit
}

install_gcloud() {
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    run_quiet sudo apt-get update && run_quiet sudo apt-get install -y google-cloud-cli
}

install_kubectl() {
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
    run_quiet sudo apt-get update && run_quiet sudo apt-get install -y kubectl
}

install_kubectx() {
    local v; v=$(curl -s https://api.github.com/repos/ahmetb/kubectx/releases/latest | jq -r .tag_name)
    mkdir -p "$HOME/.local/bin"
    wget -qO /tmp/kubectx.tar.gz "https://github.com/ahmetb/kubectx/releases/download/${v}/kubectx_${v}_linux_x86_64.tar.gz"
    wget -qO /tmp/kubens.tar.gz "https://github.com/ahmetb/kubectx/releases/download/${v}/kubens_${v}_linux_x86_64.tar.gz"
    tar -xzf /tmp/kubectx.tar.gz -C "$HOME/.local/bin" kubectx
    tar -xzf /tmp/kubens.tar.gz -C "$HOME/.local/bin" kubens
    rm /tmp/kubectx.tar.gz /tmp/kubens.tar.gz
}

install_aws() {
    wget -qO /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install --update >> "$LOG_FILE" 2>&1
    rm -rf /tmp/aws /tmp/awscliv2.zip
}

install_az() {
    curl -sL https://aka.ms/InstallAzureCLIDeb | run_quiet sudo bash
}

install_k9s() {
    local v; v=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
    mkdir -p "$HOME/.local/bin"
    wget -qO /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${v}/k9s_Linux_amd64.tar.gz"
    tar -xzf /tmp/k9s.tar.gz -C "$HOME/.local/bin" k9s
    rm /tmp/k9s.tar.gz
}

install_opentofu() {
    # Download the installer script:
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
    # Give it execution permissions:
    chmod +x install-opentofu.sh
    # Run the installer:
    ./install-opentofu.sh --install-method deb
    # Remove the installer:
    rm -f install-opentofu.sh
}

install_yq() {
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
}

# --- Configuration ---
configure_system() {
    run_logged "Updating system and maintenance" bash -c "sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean"
    
    if command -v fwupdmgr >/dev/null 2>&1; then
        run_quiet sudo fwupdmgr refresh --force || true
        if sudo fwupdmgr get-updates >> "$LOG_FILE" 2>&1; then
            run_logged "Applying firmware updates" sudo fwupdmgr update -y
        fi
    fi

    if [ -n "$DISPLAY" ]; then
        command -v powerprofilesctl >/dev/null 2>&1 && run_quiet sudo powerprofilesctl set performance
        local s; gsettings list-schemas | grep -q "dash-to-dock" && s="org.gnome.shell.extensions.dash-to-dock"
        [ -z "$s" ] && gsettings list-schemas | grep -q "ubuntu-dock" && s="org.gnome.shell.extensions.ubuntu-dock"
        if [ -n "$s" ]; then 
            safe_gsettings_set "$s" "dock-position" "'BOTTOM'"
            safe_gsettings_set "$s" "intellihide" "true"
            safe_gsettings_set "$s" "dock-fixed" "false"
            safe_gsettings_set "$s" "extend-height" "false"
        fi
        safe_gsettings_set "org.gnome.desktop.interface" "scaling-factor" "1"
        safe_gsettings_set "org.gnome.desktop.interface" "text-scaling-factor" "1.0"
        safe_gsettings_set "org.gnome.desktop.interface" "color-scheme" "'prefer-dark'"
        safe_gsettings_set "org.gnome.desktop.background" "picture-uri-dark" "file:///usr/share/backgrounds/Quokka_Everywhere_by_Dilip.png"
    fi

    if [ -f "$HOME/.bashrc" ] && ! grep -q "GIT_PS1_SHOWDIRTYSTATE" "$HOME/.bashrc"; then
        cat << 'EOF' >> "$HOME/.bashrc"
if [ -f /usr/lib/git-core/git-sh-prompt ]; then
    . /usr/lib/git-core/git-sh-prompt
    export GIT_PS1_SHOWDIRTYSTATE=1
    export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;33m\]$(__git_ps1 " (%s)")\[\033[00m\]\$ '
fi
export PATH="$HOME/.local/bin:$PATH"
EOF
    fi
}

# --- Main ---
main() {
    touch "$LOG_FILE"; echo -e "${BLUE}=== Ubuntu Setup ===${NC}\nLogs: $LOG_FILE"
    
    if ! is_container; then
        prime_sudo; keep_sudo_alive & SUDO_ALIVE_PID=$!
    fi

    source_nvm
    export PATH="$HOME/.local/bin:$PATH"

    run_logged "Ensuring base requirements" bash -c "sudo apt-get update && sudo apt-get install -y curl wget gpg pciutils build-essential unzip"

    # CLI Toolchain
    execute_tool "git"      "Git"            "install_git"
    execute_tool "gh"       "GitHub CLI"     "install_gh"
    execute_tool "uv"       "uv"             "install_uv"
    execute_tool "podman"   "Podman"         "install_podman"
    execute_tool "nvm"      "nvm/Node"       "install_nvm"
    execute_tool "htop"     "htop"           "install_htop"
    execute_tool "nano"     "nano"           "install_nano"
    execute_tool "jq"       "jq"             "install_jq"
    execute_tool "yq"       "yq"             "install_yq"
    execute_tool "tree"     "tree"           "install_tree"
    execute_tool "bat"      "bat"            "install_bat"
    execute_tool "podman-compose" "Compose"  "install_compose"
    
    # DevOps & IaC
    execute_tool "tofu"     "OpenTofu"       "install_opentofu"
    execute_tool "ansible"  "Ansible"        "install_ansible"

    # Cloud & Kubernetes
    execute_tool "gcloud"   "Google Cloud"   "install_gcloud"
    execute_tool "kubectl"  "kubectl"        "install_kubectl"
    execute_tool "kubectx"  "kubectx/kubens" "install_kubectx"
    execute_tool "aws"      "AWS CLI"        "install_aws"
    execute_tool "az"       "Azure CLI"      "install_az"
    execute_tool "k9s"      "k9s"            "install_k9s"

    # Node tools
    source_nvm
    execute_tool "gemini"   "Gemini CLI"     "run_quiet npm install -g @google/gemini-cli"
    execute_tool "tldr"     "tldr"           "run_quiet npm install -g tldr"

    # Hardware Specific
    if ! is_container && command -v lspci >/dev/null 2>&1 && lspci | grep -iq "nvidia"; then
        execute_tool "nvidia-smi" "NVIDIA Driver"  "install_nvidia_drivers"
        execute_tool "nvidia-container-cli" "NVIDIA Toolkit" "install_nvidia_toolkit"
    fi

    # GUI Applications
    if [ -n "$DISPLAY" ] || [ -n "$XDG_CURRENT_DESKTOP" ]; then
        execute_tool "code"   "VS Code" "install_vscode"
        execute_tool "google-chrome-stable" "Chrome" "install_chrome"
    fi
    
    configure_system

    echo -e "\n${GREEN}==========================================${NC}"
    log_success "Setup Complete!"
    [ ${#INSTALLED[@]} -gt 0 ] && echo -e "${BLUE}Installed:${NC} ${INSTALLED[*]}"
    [ ${#SKIPPED[@]} -gt 0 ]   && echo -e "${YELLOW}Skipped:${NC}   ${SKIPPED[*]}"
    [ ${#FAILED[@]} -gt 0 ]    && echo -e "${RED}Failed:${NC}    ${FAILED[*]}"
    echo -e "${GREEN}==========================================${NC}"
    echo -e "Run 'source ~/.bashrc' to apply changes."
}

main "$@"

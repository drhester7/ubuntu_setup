#!/bin/bash
#
# This script configures a development environment on Ubuntu.

set -e

TEMP_FILES=()
cleanup() {
    log "Cleaning up temporary files..."
    if [ ${#TEMP_FILES[@]} -gt 0 ]; then
        rm -f "${TEMP_FILES[@]}"
    fi
}
trap cleanup EXIT

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# patch

patch() {
    log "patching host..."
    sudo apt update && sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean
}

# Function to detect if running in a GUI environment
is_gui_environment() {
    if systemctl get-default | grep -q "graphical.target"; then
        return 0 # True, it's a GUI environment
    else
        return 1 # False, it's a headless environment
    fi
}


# Helper function for installing APT packages
install_apt_pkg() {
    local cmd="$1"
    local pkg="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        log "$pkg is already installed."
    else
        log "Installing $pkg..."
        sudo apt-get install -y "$pkg"
    fi
}

# Function to install curl
install_curl() {
    install_apt_pkg "curl" "curl"
}

# Function to install wget
install_wget() {
    install_apt_pkg "wget" "wget"
}

# Function to install git
install_git() {
    install_apt_pkg "git" "git"
}

install_uv() {
    if command -v uv >/dev/null 2>&1; then
        log "uv is already installed"
    else
        log "Installing uv..."
        install_curl
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
}

# Function to install podman
install_podman() {
    install_apt_pkg "podman" "podman"
}

# Function to install nvm
install_nvm() {
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        log "nvm is already installed."
    else
        log "Installing nvm..."
        install_curl
        # Dynamically get the latest version
        local LATEST_NVM_VERSION
        LATEST_NVM_VERSION=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -z "$LATEST_NVM_VERSION" ]; then
            log "Could not fetch latest nvm version, using a fallback."
            LATEST_NVM_VERSION="v0.39.7" # A recent, known-good version
        fi
        log "Latest nvm version is $LATEST_NVM_VERSION"
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$LATEST_NVM_VERSION/install.sh" | bash

        # Sourcing for the script
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

        # install node lts
        log "Installing latest Node.js via nvm..."
        nvm install --lts
        nvm use node # Explicitly use the installed node version
    fi
}

# Function to install gh
install_gh() {
    if command -v gh >/dev/null 2>&1; then
        log "gh is already installed."
    else
        log "Installing gh..."

        install_wget
	    sudo mkdir -p -m 755 /etc/apt/keyrings
        wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
	    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	    sudo mkdir -p -m 755 /etc/apt/sources.list.d
	    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
	    sudo apt update
	    sudo apt install gh -y
    fi
    log "To authenticate run 'gh auth login'"
}

# Function to install vscode
install_vscode() {
    if command -v code >/dev/null 2>&1; then
        log "vscode is already installed."
    else
        log "Installing vscode..."

        install_wget
        sudo apt-get install gpg -y
        local gpg_file
        gpg_file=$(mktemp)
        TEMP_FILES+=("$gpg_file")
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$gpg_file"
        sudo install -D -o root -g root -m 644 "$gpg_file" /usr/share/keyrings/microsoft.gpg

        echo "Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/vscode.sources > /dev/null


        sudo apt install apt-transport-https -y
        sudo apt update
        sudo apt install code -y
    fi
}

# Function to install gemini-cli
install_gemini_cli() {
    if command -v gemini >/dev/null 2>&1; then
        log "gemini-cli is already installed."
    else
        log "Installing gemini-cli..."
        install_nvm
        # We expect nvm to be sourced in the main function's scope by now
        npm install -g @google/gemini-cli
    fi
}

# Function to install google chrome
install_chrome() {
    if command -v google-chrome-stable >/dev/null 2>&1; then
        log "Google Chrome is already installed."
    else
        log "Installing google chrome..."
        local CHROME_DEB
        CHROME_DEB=$(mktemp --suffix=.deb)
        TEMP_FILES+=("$CHROME_DEB") # Register for cleanup

        wget -O "$CHROME_DEB" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install "$CHROME_DEB"
    fi        
}

# Function to install nano
install_nano() {
    install_apt_pkg "nano" "nano"
}

# Function to install kerberos
install_kerberos() {
    if command -v krb5-config >/dev/null 2>&1; then
        log "kerberos is already installed."
    else
        log "Installing kerberos..."
        sudo apt install libkrb5-dev krb5-user gcc -y
    fi
}

# Function to install htop
install_htop() {
    install_apt_pkg "htop" "htop"
}

# Function to install nvidia server driver
install_nvidia_server_driver() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        log "NVIDIA driver is already installed."
    else
        log "Installing latest NVIDIA server driver..."
        sudo apt-get install ubuntu-drivers-common -y
        sudo ubuntu-drivers install
    fi
}

# Function to install nvidia-container-toolkit
install_nvidia_container_toolkit() {
    if command -v nvidia-container-cli >/dev/null 2>&1; then
        log "nvidia-container-toolkit is already installed."
    else
        log "Installing nvidia-container-toolkit..."
        install_curl
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit
    fi
}


# Function to set Dash to Dock, power, and display settings
configure_desktop_environment() {
    log "Applying Dash to Dock, power, and display settings..."

    # Dash to Dock settings
    if gsettings list-schemas | grep -q "org.gnome.shell.extensions.ubuntu-dock"; then
        SCHEMA="org.gnome.shell.extensions.ubuntu-dock"
        log "Using schema: $SCHEMA"
        gsettings set "$SCHEMA" dock-position 'BOTTOM'
        gsettings set "$SCHEMA" intellihide true
        gsettings set "$SCHEMA" dock-fixed false
        log "Dash to Dock settings applied."
    else
        log "Dash to Dock (Ubuntu Dock) schema not found. Skipping dock settings."
        log "Please ensure 'org.gnome.shell.extensions.ubuntu-dock' is installed."
    fi

    # Set power profile to performance
    if gsettings list-schemas | grep -q "org.gnome.settings-daemon.plugins.power"; then
        log "Setting power profile to performance..."
        gsettings set org.gnome.settings-daemon.plugins.power power-profile 'performance'
        log "Power profile set to performance."
    else
        log "GNOME power settings schema not found. Skipping power profile setting."
    fi

    # Set display scaling to 100% and dark mode
    if gsettings list-schemas | grep -q "org.gnome.desktop.interface"; then
        log "Setting display scaling to 100%..."
        gsettings set org.gnome.desktop.interface scaling-factor 1
        log "Display scaling set to 100%."

        log "Setting dark mode..."
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        log "Dark mode set."
    else
        log "GNOME desktop interface schema not found. Skipping display scaling and dark mode settings."
    fi
}



# Main function
main() {
    # Refresh sudo timestamp at the start
    log "Requesting administrator privileges..."
    sudo -v

    local cli_tools=(
        "git"
        "gh"
        "uv"
        "podman"
        "gemini_cli"
        "htop"
        "nvidia_server_driver"
        "nvidia_container_toolkit"
        "nano"
        #"kerberos"
    )

    local gui_tools=(
        "vscode"
        "chrome"
    )

    local gui_config=(
        "desktop_environment"
    )

    patch

    log "Installing CLI tools..."
    for tool in "${cli_tools[@]}"; do
        "install_${tool}"
    done

    if is_gui_environment; then
        log "Installing GUI applications..."
        for tool in "${gui_tools[@]}"; do
            "install_${tool}"
        done
        
        log "Configuring desktop..."
        for setting in "${gui_config[@]}"; do
            "configure_${setting}"
        done
    fi
    

    log "For good measure, you'll probably need to restart your shell or source ~/.bashrc"
}

main "$@"

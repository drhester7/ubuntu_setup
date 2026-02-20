#!/bin/bash
#
# This script configures a development environment on Ubuntu.

set -e

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

# Function to install curl
install_curl() {
    if command -v curl >/dev/null 2>&1; then
        log "curl is already installed."
    else
        log "Installing curl..."
        sudo apt-get install curl -y
    fi
}

# Function to install wget
install_wget() {
    if command -v wget >/dev/null 2>&1; then
        log "wget is already installed."
    else
        log "Installing wget..."
        sudo apt-get install wget -y
    fi
}

# Function to install git
install_git() {
    if command -v git >/dev/null 2>&1; then
        log "git is already installed."
    else
        log "Installing git..."
        sudo apt-get install git -y
    fi
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
    if command -v podman >/dev/null 2>&1; then
        log "podman is already installed."
    else
        log "Installing podman..."
        sudo apt-get install podman -y
    fi
}

# Function to install nvm
install_nvm() {
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        log "nvm is already installed."
    else
        log "Installing nvm..."
        install_curl
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

        # Sourcing for the script
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
        [ -s " $NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

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
	    out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg
	    cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
	    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	    sudo mkdir -p -m 755 /etc/apt/sources.list.d
	    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
	    sudo apt update
	    sudo apt install gh -y
    fi
    log "To authenticate run 'gh auth login'"
}

# Function to install speedtest
install_speedtest() {
    if command -v speedtest >/dev/null 2>&1; then
        log "speedtest is already installed."
    else
        install_curl
        log "Installing speedtest..."
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
        sudo apt-get install speedtest -y
    fi
}

# Function to install vscode
install_vscode() {
    if command -v code >/dev/null 2>&1; then
        log "vscode is already installed."
    else
        log "Installing vscode..."

        install_wget
        sudo apt-get install gpg -y &&
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg &&
        sudo install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg &&
        rm -f microsoft.gpg

        echo "Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg" > /etc/apt/sources.list.d/vscode.sources


        sudo apt install apt-transport-https -y &&
        sudo apt update &&
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
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install ./google-chrome-stable_current_amd64.deb
        rm ./google-chrome-stable_current_amd64.deb
    fi        
}

# Main function
main() {
    INSTALL_GUI="true"
    if [[ "$1" == "--no-gui" ]]; then
        INSTALL_GUI="false"
        log "Skipping GUI packages installation."
    fi

    patch
    install_git # working
    install_gh # working
    install_uv # working
    install_podman # working
    if [ "$INSTALL_GUI" = "true" ]; then
        install_vscode # working
        install_chrome # working
        #set_dash_to_dock_settings # function needed
    fi
    install_gemini_cli # working
    #install_speedtest # apt not officially supported for noble
    #install_htop # function needed
    #install_nvidia_cuda # function needed
    #install_nvidia_container_toolkit # function needed
    

    log "For good measure, you'll probably need to restart your shell or source ~/.bashrc"
}

main "$@"

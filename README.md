# Ubuntu Development Environment Setup

This script automates the setup of a development environment on a fresh Ubuntu installation. It's designed to be idempotent and hardware-aware.

## Features

- **Hardware-Aware NVIDIA Installation:** Only installs NVIDIA drivers and container toolkit if an NVIDIA GPU is detected via `lspci`.
- **Robust GUI Detection:** Automatically detects if a graphical session is active (via `$DISPLAY` or system targets) before attempting to install GUI applications and configuring desktop settings.
- **Sudo Keep-Alive:** Runs a background process to maintain administrative privileges during long-running installation steps, preventing manual password re-entry.
- **Improved Shell Sourcing:** Automatically sources NVM and Node.js for the current session and provides clear instructions for refreshing your shell (Bash or Zsh) after completion.

## Usage

1.  Clone this repository:
    ```bash
    git clone https://github.com/your-username/ubuntu_setup.git
    cd ubuntu_setup
    ```
2.  Run the setup script:
    ```bash
    ./setup.sh
    ```
3.  Refresh your shell environment (as instructed by the script's final message):
    ```bash
    source ~/.bashrc  # Or source ~/.zshrc for Zsh
    ```

## Installed Tools

### CLI Tools
*   `git`: Version control system.
*   `gh`: GitHub CLI.
*   `uv`: Python package installer.
*   `podman`: Container engine.
*   `nvm`: Node Version Manager (installs the latest LTS version of Node.js).
*   `@google/gemini-cli`: The Gemini CLI.
*   `htop`: Interactive process viewer.
*   `nano`: Text editor.
*   `NVIDIA Server Driver & Container Toolkit`: (Installed only on NVIDIA hardware).

### GUI Applications (Installed only in GUI environments)
*   Visual Studio Code: Code editor.
*   Google Chrome: Web browser.

### Desktop Configuration (Applied only in GNOME environments)
*   Configures Ubuntu Dock (Dash to Dock) to the bottom with intellihide.
*   Sets Power Profile to 'Performance'.
*   Sets Dark Mode and 100% display scaling.

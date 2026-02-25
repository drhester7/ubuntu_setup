# Project Overview

This project provides a robust automation script (`setup.sh`) to transform a fresh Ubuntu installation into a professional development environment. It is designed to be idempotent, hardware-aware, and highly descriptive.

## Key Goals
- **Automation:** Minimize manual configuration steps.
- **Idempotency:** Ensure the script can be run multiple times without causing side effects or redundant operations.
- **Portability:** Support both physical hardware (with GPU detection) and containerized testing environments.

## Installed Toolchain

### Development Runtimes & CLI
- **Python:** `uv` (Fast package manager)
- **Node.js:** `nvm` with LTS version
- **Containers:** `podman`, `podman-compose`, `podman-docker` (Docker CLI alias)
- **Cloud:** `gcloud`, `kubectl`, `aws`, `az`
- **DevOps:** `tofu`, `ansible`, `sops`, `terraform-docs`
- **Kubernetes Utilities:** `k9s`, `kubectx`, `kubens`
- **Modern Utilities:** `jq`, `yq`, `bat`, `gh`, `htop`, `tldr`, `tree`, `nano`, `watch`, `iftop`, `nmap`
- **Security:** `gitleaks`
- **AI Tools:** `@google/gemini-cli`

### GUI Applications
- **Editor:** Visual Studio Code
- **Browser:** Google Chrome (amd64)

### System Configuration
- **GNOME Polish:** Optimized dock position (bottom, intellihide), dark mode, desktop icon configuration (small, top-left, hide home folder), and performance power profile.
- **Aesthetics:** Sets "Quokka Everywhere" as the default dark mode background.
- **Display:** Disabled fractional scaling experimental features and sets 15-minute screen blank timeout.
- **Shell:** Customized Bash prompt with Git branch state tracking and `$HOME/.local/bin` in PATH.
- **Privacy & Maintenance:** Disables error reporting to Canonical (`apport`, `whoopsie`) and automates system package maintenance (`apt upgrade`, `autoremove`).

# Hardware Awareness
The script includes specialized logic to detect NVIDIA hardware using `lspci` and `nvidia-smi`. If found, it automatically installs the appropriate NVIDIA drivers and the NVIDIA Container Toolkit to enable GPU acceleration in Podman/Docker.

# Technical Architecture

## Modular Helpers
- **`add_apt_repo`**: Handles modern GPG keyring management in `/etc/apt/keyrings`, ensuring secure and clean repository additions, followed by a global cache refresh to ensure dependency resolution.
- **`execute_tool`**: A high-level wrapper that checks for binary existence before attempting installation, ensuring idempotency.
- **`safe_gsettings_set`**: Safely modifies GNOME settings only if the schema and key exist, avoiding errors in headless or non-GNOME environments. Normalizes GSettings type prefixes (like `uint32`) for true idempotency.
- **`run_logged`**: Manages background execution with a spinner UI and detailed logging to `/tmp/ubuntu_setup_*.log`.

## Environment Detection
- **`is_container`**: Detects if the script is running inside a Docker/Podman container or a CI environment to skip hardware-specific or GUI configurations.

# Building and Testing

## Local Execution
To set up your local environment:
```bash
chmod +x setup.sh
./setup.sh
```

## Containerized Testing
A `Dockerfile` is provided specifically for verifying the `setup.sh` script in a headless environment. It uses a `developer` user with passwordless sudo to simulate a real-world developer machine.

To build the test environment:
```bash
podman build -t ubuntu-dev-env .
```

# Development Conventions
- **Modular Design:** Each tool installation or configuration step is encapsulated in a dedicated function (e.g., `install_vscode`, `configure_system`).
- **High-Signal Output:** Major steps are logged with timestamps, and identical configurations are skipped with a yellow `[SKIP]` tag.
- **Result Dashboard:** A clean, bulleted summary is displayed upon completion, categorized by success, skip, or environmental incompatibility.

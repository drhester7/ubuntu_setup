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
- **Containers:** `podman`, `podman-compose`
- **Cloud:** `gcloud`, `kubectl`, `aws`, `az`
- **DevOps:** `tofu`, `ansible`
- **Modern Utilities:** `jq`, `yq`, `bat`, `gh`, `htop`, `tldr`, `tree`

### GUI Applications
- **Editor:** Visual Studio Code
- **Browser:** Google Chrome (amd64)

### System Configuration
- **GNOME Polish:** Optimized dock position, dark mode, and performance power profile.
- **Display:** Disabled fractional scaling experimental features for maximum stability.
- **Shell:** Customized Bash prompt with Git branch state tracking.
- **Maintenance:** Automated firmware updates and system package maintenance.

# Hardware Awareness
The script includes specialized logic to detect NVIDIA hardware. If found, it automatically installs the appropriate NVIDIA drivers and the NVIDIA Container Toolkit to enable GPU acceleration in Podman/Docker.

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
- **Modular Design:** Each tool installation or configuration step is encapsulated in a dedicated function.
- **High-Signal Output:** Major steps are logged with timestamps, and identical configurations are skipped with a yellow `[SKIP]` tag.
- **Result Dashboard:** A clean, bulleted summary is displayed upon completion, categorized by success, skip, or environmental incompatibility.

# Professional Ubuntu Development Setup

A robust, idempotent shell script to automate the configuration of a professional development environment on Ubuntu. Designed for high-signal output, hardware awareness, and seamless maintenance.

## Key Features

- **🚀 Modern Toolchain:** Installs a curated set of high-performance CLI tools (`uv`, `podman`, `gh`, `jq`, `bat`, etc.).
- **🔧 Hardware-Aware:** Dynamically detects NVIDIA GPUs to install appropriate drivers and container toolkits.
- **🖥️ Desktop Polish:** Configures GNOME for peak productivity (Dock, Dark Mode, Performance profiles, and Scaling).
- **🛡️ System Maintenance:** Automates system patching, firmware updates (`fwupdmgr`), and deep cleanup (`autoremove`/`autoclean`).
- **🐚 Shell Customization:** Enhances the Bash prompt with real-time Git branch integration.
- **📊 Professional UX:** Provides a clean terminal experience with color-coded logging and a final status dashboard.

## Quick Start

The fastest way to get started is to execute the script directly:

```bash
# Using curl
curl -sSL https://donaldhester.com/ubuntu/setup.sh | bash

# Or using wget
wget -qO- https://donaldhester.com/ubuntu/setup.sh | bash
```

Alternatively, you can clone the repository and run it locally:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/donaldhester/ubuntu_setup.git
   cd ubuntu_setup
   ```

2. **Execute the setup:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Finalize changes:**
   ```bash
   source ~/.bashrc
   ```

## Included Tools

### Core CLI Toolchain
*   **Version Control:** `git`, GitHub CLI (`gh`)
*   **Python:** `uv` (Extremely fast installer/manager)
*   **Containers:** `podman`, `podman-compose`
*   **Runtime:** `nvm` (Node Version Manager) with latest LTS Node.js
*   **AI:** `@google/gemini-cli`
*   **Modern Utilities:** `jq`, `bat`, `tldr`, `tree`, `htop`, `nano`

### GUI Applications (Auto-detected)
*   **Visual Studio Code:** Professional code editor.
*   **Google Chrome:** Web browser (amd64 only).

### Hardware Support
*   **NVIDIA:** Automatic installation of Server Drivers and Container Toolkit if hardware is detected.

## System Configuration

### Desktop Preferences (GNOME)
*   **Dock:** Positioned at the bottom, panel mode disabled, intellihide enabled.
*   **Display:** Forced 100% integer scaling and Preferred Dark Mode.
*   **Power:** Automatically switched to the 'Performance' profile.

### Maintenance
*   **Firmware:** Automated hardware metadata refresh and update via `fwupdmgr`.
*   **Cleanup:** Performs `apt autoremove` and `autoclean` to maintain a lean system.

## Testing with Docker

A `Dockerfile` is provided to test the setup in a clean Ubuntu 24.04 environment:

```bash
docker build -t ubuntu-dev-env .
docker run -it ubuntu-dev-env
```

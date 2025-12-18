# Project Overview

This project automates the setup of a development environment on a fresh Ubuntu installation. It uses a shell script (`setup.sh`) to install a collection of common development tools. A `Dockerfile` is also included to create a containerized version of the environment.

The script installs the following tools:
*   `git`: Version control system.
*   `gh`: GitHub CLI.
*   `uv`: Python package installer.
*   `podman`: Container engine.
*   `nvm`: Node Version Manager, used to install Node.js and npm.
*   `@google/gemini-cli`: The Gemini CLI.
*   Visual Studio Code: Code editor.
*   `curl` and `wget`: Command-line tools for transferring data.
*   `speedtest-cli`: Command-line interface for testing internet bandwidth.

# Building and Running

## Running the Setup Script

To set up your local environment, execute the `setup.sh` script:

```bash
./setup.sh
```

The script will update the system's package lists, upgrade existing packages, and then install the tools listed above. It's recommended to restart your shell session or source your `~/.bashrc` file after the script finishes to ensure all environment changes take effect.

## Building the Docker Image

A `Dockerfile` is provided to build a container image with the specified development environment.

To build the image, run:

```bash
docker build -t ubuntu-dev-env .
```
This `Dockerfile` is specifically designed to create an environment for testing the `setup.sh` script. The `RUN ./setup.sh` command is now active and will execute the setup script during the image build process.

# Development Conventions

The `setup.sh` script follows a modular structure, with separate functions for installing each tool. This makes it easy to add, remove, or modify the installation process for individual components. Each major step is logged to the console with a timestamp.

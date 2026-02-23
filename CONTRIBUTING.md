# Developer Guide: Extending the Setup Script

This document explains the architecture of `setup.sh` and provides instructions on how to add new tools or configurations.

## Architecture Overview

The script is designed to be **idempotent**, **high-signal**, and **Docker-aware**. It follows a strict modular structure:

1.  **Helpers:** Utility functions for logging, spinner animation, and sudo management.
2.  **Installers:** Atomic functions (prefixed with `install_`) dedicated to a single tool.
3.  **Configuration:** Logic for system-wide settings (GNOME, shell prompts, maintenance).
4.  **Main:** The execution loop that orchestrates the entire process.

---

## How to Add a New CLI Tool

### 1. Create an Installation Function
Add a new function in the **Installers** section. Use `run_quiet` to redirect verbose output to the log file.

```bash
install_mytool() {
    # Example for an APT package
    run_quiet sudo apt-get install -y mytool
    
    # Example for a binary download
    # wget -qO- https://example.com/install.sh | run_quiet bash
}
```

### 2. Register the Tool in `main()`
Add a single line to the `main()` function using the `execute_tool` wrapper.

```bash
# Usage: execute_tool "binary_name" "Display Name" "function_name"
execute_tool "mytool" "My Tool" "install_mytool"
```

The `execute_tool` wrapper will:
- Check if `mytool` is already in the `$PATH`.
- If missing, run your installation function with a spinning wheel.
- Record the result for the final summary dashboard.

---

## How to Add a New GUI Tool

GUI tools should only be installed if a display is present. Place these within the `if [ -n "$DISPLAY" ]` block in `main()`.

```bash
if [ -n "$DISPLAY" ]; then
    execute_tool "code" "VS Code" "install_vscode"
    execute_tool "my-gui-app" "My GUI App" "install_my_gui_app"
fi
```

---

## Important Helpers

### `run_quiet`
Use this for standard commands where you want to hide the "wall of text" but keep it available in the log file for debugging.
```bash
run_quiet sudo apt-get update
```

### `run_logged`
Use this for long-running tasks that aren't managed by `execute_tool`. It provides a message and a spinning wheel.
```bash
run_logged "Optimizing System" my_heavy_function
```

### `safe_gsettings_set`
Always use this for GNOME configurations to prevent the script from crashing if a schema or key is missing.
```bash
safe_gsettings_set "org.gnome.desktop.interface" "cursor-size" "24"
```

---

## Testing Your Changes

Before committing, always verify your changes using the provided `Dockerfile`. This ensures your installation logic works on a fresh Ubuntu system and doesn't rely on existing local state.

```bash
docker build -t ubuntu-dev-test .
```

If the build fails, the script will automatically output the verbose log to your terminal for debugging.

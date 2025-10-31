#!/bin/bash

# Detect OS (basic check for cross-platform awareness)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "This is a bash script for Linux/macOS. Use the PowerShell version for Windows."
    exit 1
fi

# Check prerequisites
if ! command -v git &> /dev/null; then
    echo "Git not installed. Install from https://git-scm.com/."
    exit 1
fi
if ! command -v code &> /dev/null; then
    echo "VS Code not installed. Install from https://code.visualstudio.com/."
    exit 1
fi
if ! command -v docker &> /dev/null; then
    echo "Docker not installed. Install from https://docker.com/."
    exit 1
fi

# Check and install Dev Containers extension
EXTENSION_ID="ms-vscode-remote.remote-containers"
if ! code --list-extensions | grep -q "$EXTENSION_ID"; then
    echo "Installing Dev Containers extension..."
    code --install-extension "$EXTENSION_ID" || { echo "Extension installation failed."; exit 1; }
fi

# Securely prompt for Tailscale key (no echo)
read -s -p "Enter your Tailscale auth key (input hidden): " TS_AUTHKEY
echo ""
export TS_AUTHKEY="$TS_AUTHKEY"

# Clone or update repo
REPO_URL="https://github.com/hratsch/d3s.git"
REPO_DIR="$HOME/k3s-dev-env"
if [ -d "$REPO_DIR/.git" ]; then
    echo "Repo exists. Pulling latest changes..."
    cd "$REPO_DIR"
    git pull origin main || { echo "Git pull failed."; exit 1; }
else
    echo "Cloning repo..."
    git clone "$REPO_URL" "$REPO_DIR" || { echo "Clone failed."; exit 1; }
    cd "$REPO_DIR"
fi

# Open in VS Code
code .

# Instruct on next steps (no auto-reopen via CLI, but devcontainer CLI alternative)
echo "In VS Code, press Ctrl+Shift+P and select 'Dev Containers: Reopen in Container' to start."
echo "Alternative (headless, no VS Code): Install devcontainer CLI via 'npm install -g @devcontainers/cli', then run 'devcontainer up --workspace-folder .'"
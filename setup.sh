#!/bin/bash

# Exit on error
set -e

# Start logging - delete this section after script is solid
exec > >(tee setup.log) 2>&1
# End logging

# Print commands for debugging
set -x

# Cache sudo credentials early
sudo -v

# Function to install packages
install_packages() {
    echo "Installing packages: $@"
    sudo apt update
    sudo apt install -y "$@"
}

# OS check with confirmation
if ! grep -q "Ubuntu 24.04" /etc/os-release; then
    echo "Optimized for Ubuntu 24.04. Proceed? (y/n)"
    read -r confirm
    [ "$confirm" != "y" ] && exit 1
fi

# Git
command -v git &> /dev/null || install_packages git

# Docker with validation
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    install_packages ca-certificates curl gnupg
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
fi
# Test Docker access
if ! docker version &> /dev/null; then
    echo "Docker access failed. Relogin for group changes. Exiting."
    exit 1
fi

# Node.js/npm via NodeSource
command -v node &> /dev/null && command -v npm &> /dev/null || {
    echo "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    install_packages nodejs
}

# devcontainer CLI
command -v devcontainer &> /dev/null || {
    echo "Installing devcontainer CLI..."
    sudo npm install -g @devcontainers/cli
}

# Neovim via PPA
if ! command -v nvim &> /dev/null || [ "$(nvim --version | head -n1 | cut -d ' ' -f2 | cut -d '.' -f1-2)" != "0.10" ]; then
    echo "Installing latest Neovim..."
    sudo add-apt-repository ppa:neovim-ppa/unstable -y
    sudo apt update
    install_packages neovim
fi

# OpenLens with arch detection
command -v open-lens &> /dev/null || {
    echo "Installing OpenLens..."
    install_packages desktop-file-utils
    ARCH=$(dpkg --print-architecture)
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/MuhammedKalkan/OpenLens/releases/latest | grep "browser_download_url.*${ARCH}\.deb\"" | grep -v "sha256" | cut -d '"' -f 4 | head -n1)
    [ -z "$LATEST_RELEASE" ] && { echo "Failed to fetch OpenLens URL."; exit 1; }
    curl -L "$LATEST_RELEASE" -o openlens.deb
    sudo dpkg -i openlens.deb || true
    sudo apt --fix-broken install -y
    rm openlens.deb
}

# LazyVim with k8s plugin
[ -d "$HOME/.config/nvim" ] || {
    echo "Setting up LazyVim..."
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
    mkdir -p "$HOME/.config/nvim/lua/plugins"
    cat << EOF > "$HOME/.config/nvim/lua/plugins/kubernetes.lua"
return {
  { "Ramilito/kubectl.nvim" },
}
EOF
    nvim --headless "+Lazy! sync" +qa || echo "Run nvim and :Lazy sync manually."
}

# Tailscale key
read -s -p "Enter Tailscale auth key: " TS_AUTHKEY
echo ""
export TS_AUTHKEY="$TS_AUTHKEY"

# Repo
REPO_URL="https://github.com/hratsch/d3s.git"
REPO_DIR="$HOME/k3s-dev-env"
[ -d "$REPO_DIR/.git" ] && { echo "Updating repo..."; cd "$REPO_DIR"; git pull origin main; } || { echo "Cloning repo..."; git clone "$REPO_URL" "$REPO_DIR"; cd "$REPO_DIR"; }

# Dev container with diagnostics
echo "Starting dev container..."
[ -f ".devcontainer/Dockerfile" ] && [ -f ".devcontainer/devcontainer.json" ] || { echo "Missing .devcontainer files."; exit 1; }
devcontainer up --workspace-folder . || { echo "Failed. Check docker logs or files."; exit 1; }

# Container ID and instructions
CONTAINER_ID=$(docker ps -q --filter label=devcontainer.local_folder="$PWD" --latest)
[ -n "$CONTAINER_ID" ] && {
    echo "Container ID: $CONTAINER_ID"
    echo "Enter: docker exec -it $CONTAINER_ID bash"
    echo "Edit: nvim <file> (LazyVim + k8s)"
    echo "GUI: open-lens & (~/.kube/config)"
    echo "Test: tailscale status; kubectl get nodes"
} || echo "No container. Run devcontainer up manually."

echo "Done! See setup.log for details."
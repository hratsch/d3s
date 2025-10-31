#!/bin/bash

# Exit on error and print commands for debugging
set -e
set -x

# Function to install packages with confirmation
install_packages() {
    echo "Installing packages: $@"
    sudo apt update
    sudo apt install -y "$@"
}

# Check if Ubuntu
if ! grep -q "Ubuntu 24.04" /etc/os-release; then
    echo "This script is optimized for Ubuntu 24.04. Proceed at your own risk? (y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then exit 1; fi
fi

# Install Git if missing
if ! command -v git &> /dev/null; then
    install_packages git
fi

# Install Docker if missing (official method)
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    install_packages ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    echo "Docker installed. You must log out and back in for non-sudo access. Continue anyway? (y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then exit 1; fi
fi

# Install latest Node.js (includes npm) via NodeSource (minimal deps)
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Installing Node.js 20 LTS with npm..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    install_packages nodejs
fi

# Install devcontainer CLI if missing
if ! command -v devcontainer &> /dev/null; then
    echo "Installing devcontainer CLI..."
    sudo npm install -g @devcontainers/cli
fi

# Install latest Neovim via PPA
if ! command -v nvim &> /dev/null || [ "$(nvim --version | head -n1 | cut -d ' ' -f2 | cut -d '.' -f1-2)" != "0.10" ]; then
    echo "Installing latest Neovim..."
    sudo add-apt-repository ppa:neovim-ppa/unstable -y
    sudo apt update
    install_packages neovim
fi

# Install OpenLens (with dependency fix)
if ! command -v open-lens &> /dev/null; then
    echo "Installing OpenLens..."
    install_packages desktop-file-utils  # Fixes update-desktop-database
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/MuhammedKalkan/OpenLens/releases/latest | grep "browser_download_url.*deb" | cut -d '"' -f 4)
    curl -L "$LATEST_RELEASE" -o openlens.deb
    sudo dpkg -i openlens.deb || true  # Ignore initial errors
    sudo apt --fix-broken install -y   # Resolve any broken deps
    rm openlens.deb
fi

# Set up LazyVim with valid Kubernetes plugin
if [ ! -d "$HOME/.config/nvim" ]; then
    echo "Setting up LazyVim..."
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
    mkdir -p "$HOME/.config/nvim/lua/plugins"
    cat << EOF > "$HOME/.config/nvim/lua/plugins/kubernetes.lua"
return {
  { "Ramilito/kubectl.nvim" },  -- Valid plugin for k8s navigation
}
EOF
    # Sync plugins headlessly
    nvim --headless "+Lazy! sync" +qa || echo "Plugin sync had issues; run nvim and :Lazy sync manually."
fi

# Secure Tailscale key prompt
read -s -p "Enter your Tailscale auth key: " TS_AUTHKEY
echo ""
export TS_AUTHKEY="$TS_AUTHKEY"

# Clone/update repo
REPO_URL="https://github.com/hratsch/d3s.git"
REPO_DIR="$HOME/k3s-dev-env"
if [ -d "$REPO_DIR/.git" ]; then
    echo "Updating repo..."
    cd "$REPO_DIR"
    git pull origin main
else
    echo "Cloning repo..."
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

# Build and run dev container
echo "Starting dev container..."
devcontainer up --workspace-folder . || echo "Build failed; check Dockerfile or dependencies."

# Get container ID and instructions
CONTAINER_ID=$(docker ps -q --filter label=devcontainer.local_folder="$PWD" --latest)
if [ -n "$CONTAINER_ID" ]; then
    echo "Container running (ID: $CONTAINER_ID)."
    echo "Enter shell: docker exec -it $CONTAINER_ID bash"
    echo "Edit files: nvim <file> (inside container; LazyVim with k8s support)"
    echo "GUI: open-lens & (import ~/.kube/config if needed)"
    echo "Test: tailscale status; kubectl get nodes"
else
    echo "No container found. Run 'devcontainer up --workspace-folder $REPO_DIR' manually after logout/login."
fi

echo "Setup complete! Log out/in for full Docker access if prompted earlier."
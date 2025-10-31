#!/bin/bash

# Exit on error
set -e

# Function to check and install packages
install_if_missing() {
    PACKAGE=$1
    if ! command -v $PACKAGE &> /dev/null; then
        echo "$PACKAGE not found. Installing..."
        sudo apt-get update && sudo apt-get install -y $PACKAGE
    else
        echo "$PACKAGE is already installed."
    fi
}

# Install prerequisites: Git, Docker, Node.js (for npm/devcontainer CLI), Neovim
install_if_missing git
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "Docker installed. Log out and back in for group changes to take effect."
fi
install_if_missing nodejs  # For npm; assumes apt has Node 18+ for 2025 Ubuntu
install_if_missing npm
install_if_missing neovim

# Install devcontainer CLI if missing
if ! command -v devcontainer &> /dev/null; then
    echo "Installing devcontainer CLI..."
    sudo npm install -g @devcontainers/cli
fi

# Install OpenLens (download latest deb from GitHub)
if ! command -v open-lens &> /dev/null; then
    echo "Installing OpenLens..."
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/MuhammedKalkan/OpenLens/releases/latest | grep "browser_download_url.*deb" | cut -d '"' -f 4)
    curl -L $LATEST_RELEASE -o openlens.deb
    sudo dpkg -i openlens.deb || sudo apt-get install -f -y  # Fix dependencies if needed
    rm openlens.deb
fi

# Set up LazyVim with Kubernetes plugins
if [ ! -d "$HOME/.config/nvim" ]; then
    echo "Setting up LazyVim..."
    git clone https://github.com/LazyVim/starter $HOME/.config/nvim
    rm -rf $HOME/.config/nvim/.git  # Remove git to avoid unintended updates
    # Add basic Kubernetes plugin (e.g., for YAML/Helm support)
    mkdir -p $HOME/.config/nvim/lua/plugins
    cat << EOF > $HOME/.config/nvim/lua/plugins/kubernetes.lua
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections.lualine_x = { "encoding", "fileformat", "filetype" }
    end,
  },
  { "kubernetes.nvim" },  -- Basic k8s plugin; install via lazy
}
EOF
    # Run nvim headlessly to install plugins
    nvim --headless "+Lazy! sync" +qa
fi

# Securely prompt for Tailscale key
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

# Build and run dev container
echo "Building and running dev container..."
devcontainer up --workspace-folder .

# Get container ID for instructions
CONTAINER_ID=$(docker ps -q --filter label=devcontainer.local_folder=$PWD)

# Final instructions
echo "Dev container is running. To enter: docker exec -it $CONTAINER_ID bash"
echo "Inside, use 'nvim' for editing (LazyVim preconfigured with k8s basics)."
echo "Launch OpenLens GUI: open-lens & (or from menu) and import ~/.kube/config if needed."
echo "Verify Tailscale: tailscale status; k3s access: kubectl get nodes."
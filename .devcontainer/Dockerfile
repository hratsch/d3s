# Base image: Ubuntu 22.04 for familiarity and stability
FROM ubuntu:22.04

# Update packages and install basic tools: curl for downloads, git for version control, vim for editing, bash-completion for better CLI experience, ca-certificates and gnupg for secure connections
RUN apt-get update && apt-get install -y \
    curl git vim bash-completion ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*  # Clean up to reduce image size

# Install Tailscale: Adds the repository keyring and list, then installs the package
RUN mkdir -p --mode=0755 /usr/share/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null \
    && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list \
    && apt-get update && apt-get install -y tailscale \
    && rm -rf /var/lib/apt/lists/*  # Clean up

# Install kubectl: Downloads the latest stable version, makes it executable, and moves to bin
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Helm: Uses the official script to install the latest version
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install k9s: Downloads the latest release tarball, extracts, and moves the binary to bin (terminal UI for cluster management)
RUN curl -sL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar xz \
    && mv k9s /usr/local/bin/

# Install k3s binary: Downloads and installs without starting the server (for CLI use, like k3s kubectl or local testing)
RUN curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

# Set up bash enhancements: Adds completion for kubectl, alias 'k' for kubectl, and completion for the alias
RUN echo "source <(kubectl completion bash)" >> /root/.bashrc \
    && echo "alias k=kubectl" >> /root/.bashrc \
    && echo "complete -o default -F __start_kubectl k" >> /root/.bashrc

# Set working directory to /workspace (mounts your repo here)
WORKDIR /workspace

# Keep the container running indefinitely (allows attaching via VS Code)
CMD ["sleep", "infinity"]
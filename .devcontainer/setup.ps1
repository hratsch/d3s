# Detect OS
if (-not $IsWindows) {
    Write-Host "This is a PowerShell script for Windows. Use the bash version for Linux/macOS."
    exit 1
}

# Check prerequisites
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not installed. Install from https://git-scm.com/."
    exit 1
}
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "VS Code not installed. Install from https://code.visualstudio.com/."
    exit 1
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker not installed. Install from https://docker.com/."
    exit 1
}

# Check and install Dev Containers extension
$EXTENSION_ID = "ms-vscode-remote.remote-containers"
$installedExtensions = code --list-extensions
if (-not ($installedExtensions -contains $EXTENSION_ID)) {
    Write-Host "Installing Dev Containers extension..."
    code --install-extension $EXTENSION_ID
    if ($LASTEXITCODE -ne 0) { Write-Host "Extension installation failed."; exit 1 }
}

# Securely prompt for Tailscale key
$TS_AUTHKEY = Read-Host -Prompt "Enter your Tailscale auth key (input hidden)" -AsSecureString
$TS_AUTHKEY_PLAIN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TS_AUTHKEY))
$env:TS_AUTHKEY = $TS_AUTHKEY_PLAIN

# Clone or update repo
$REPO_URL = "https://github.com/hratsch/d3s.git"
$REPO_DIR = "$HOME\k3s-dev-env"
if (Test-Path "$REPO_DIR\.git") {
    Write-Host "Repo exists. Pulling latest changes..."
    Set-Location $REPO_DIR
    git pull origin main
    if ($LASTEXITCODE -ne 0) { Write-Host "Git pull failed."; exit 1 }
} else {
    Write-Host "Cloning repo..."
    git clone $REPO_URL $REPO_DIR
    if ($LASTEXITCODE -ne 0) { Write-Host "Clone failed."; exit 1 }
    Set-Location $REPO_DIR
}

# Open in VS Code
code .

# Instruct on next steps
Write-Host "In VS Code, press Ctrl+Shift+P and select 'Dev Containers: Reopen in Container' to start."
Write-Host "Alternative (headless, no VS Code): Install devcontainer CLI via 'npm install -g @devcontainers/cli', then run 'devcontainer up --workspace-folder .'"
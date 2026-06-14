#!/bin/bash
set -euo pipefail

echo "==> updating package lists"
sudo apt update

echo "==> installing packages"
sudo apt install -y \
  zsh neovim git btop gh jq bat ripgrep fd-find fzf lazygit \
  eza wget zoxide nodejs npm openssh-server \
  zsh-autosuggestions zsh-syntax-highlighting \
  unzip mandoc curl \
  libegl1-mesa-dev libgles2-mesa-dev mesa-va-drivers mesa-vulkan-drivers

if ! command -v fd >/dev/null; then
  sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

echo "==> installing yazi"
if ! command -v yazi >/dev/null; then
  curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
  echo "deb https://debian.griffo.io/apt $(lsb_release -sc 2>/dev/null || echo bookworm) main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list
  sudo apt update
  sudo apt install -y yazi || {
    echo "==> yazi not available via apt (arm64) — installing from GitHub"
    YAZI_VER=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | jq -r .tag_name)
    curl -fsSL "https://github.com/sxyazi/yazi/releases/download/${YAZI_VER}/yazi-aarch64-unknown-linux-gnu.zip" -o /tmp/yazi.zip
    sudo unzip -o /tmp/yazi.zip -d /usr/local/bin/
    rm -f /tmp/yazi.zip
  }
fi

echo "==> installing starship"
if ! command -v starship >/dev/null; then
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

echo "==> installing foot (terminal)"
if ! command -v foot >/dev/null; then
  sudo apt install -y foot
fi

echo "==> installing opencode"
if ! command -v opencode >/dev/null; then
  sudo npm i -g opencode-ai@latest
fi

echo "==> installing JetBrains Mono Nerd Font"
if [ ! -f /usr/local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf ]; then
  sudo mkdir -p /usr/local/share/fonts
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip -o /tmp/JetBrainsMono.zip
  unzip -o /tmp/JetBrainsMono.zip -d /usr/local/share/fonts/ 2>/dev/null || true
  fc-cache -fv >/dev/null 2>&1 || true
  rm -f /tmp/JetBrainsMono.zip
fi

echo "==> installing uv"
if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

echo "==> creating user fomar"
if ! id fomar >/dev/null 2>&1; then
  sudo useradd -m -G sudo,adm,audio,video,netdev,input,render fomar
  echo "fomar:fomar" | sudo chpasswd
fi

echo "==> setting hostname"
sudo hostnamectl set-hostname dgtablet

echo "==> enabling sshd"
sudo systemctl enable --now ssh

echo "==> setting zsh as default shell for chaos and fomar"
sudo chsh -s /usr/bin/zsh chaos
sudo chsh -s /usr/bin/zsh fomar

echo "==> cloning notes repo"
if [ ! -d /home/fomar/notes/.git ]; then
  sudo -u fomar mkdir -p /home/fomar/notes
  sudo -u fomar git clone https://github.com/jitumaatgit/notes /home/fomar/notes 2>/dev/null || echo "notes repo clone failed (ok if not accessible yet)"
fi

echo "==> configuring LightDM autologin for fomar"
sudo sed -i 's/^autologin-user=.*/autologin-user=fomar/' /etc/lightdm/lightdm.conf
grep -q 'autologin-user=fomar' /etc/lightdm/lightdm.conf || echo "autologin-user=fomar" | sudo tee -a /etc/lightdm/lightdm.conf

echo "==> running deploy.sh as fomar"
curl -fsSL https://raw.githubusercontent.com/jitumaatgit/tablet-dotfiles/main/deploy.sh | sudo -u fomar bash

echo "==> setup complete. reboot to finish."

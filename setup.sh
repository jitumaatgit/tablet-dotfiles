#!/bin/bash
set -euo pipefail

echo "==> updating package lists"
sudo apt update

echo "==> installing packages"
sudo apt install -y \
  zsh git btop gh jq bat ripgrep fd-find fzf lazygit \
  eza wget zoxide nodejs npm openssh-server \
  zsh-autosuggestions zsh-syntax-highlighting \
  unzip mandoc curl

if ! command -v fd >/dev/null; then
  sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

echo "==> installing neovim (from GitHub, apt version too old)"
if [ ! -x /usr/local/bin/nvim ] || nvim --version 2>/dev/null | head -1 | grep -qF '0.10'; then
  NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz"
  curl -fsSL "$NVIM_URL" -o /tmp/nvim.tar.gz
  sudo rm -rf /usr/local/nvim
  sudo tar -C /usr/local -xzf /tmp/nvim.tar.gz
  sudo ln -sf /usr/local/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim
  rm -f /tmp/nvim.tar.gz
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

if ! command -v starship >/dev/null; then
  echo "==> installing starship"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

if ! command -v foot >/dev/null; then
  echo "==> installing foot (terminal)"
  sudo apt install -y foot
fi

if ! command -v opencode >/dev/null; then
  echo "==> installing opencode"
  sudo npm i -g opencode-ai@latest
fi

if [ ! -f /usr/local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf ]; then
  echo "==> installing JetBrains Mono Nerd Font"
  sudo mkdir -p /usr/local/share/fonts
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip -o /tmp/JetBrainsMono.zip
  unzip -o /tmp/JetBrainsMono.zip -d /usr/local/share/fonts/ 2>/dev/null || true
  fc-cache -fv >/dev/null 2>&1 || true
  rm -f /tmp/JetBrainsMono.zip
fi

if ! command -v uv >/dev/null; then
  echo "==> installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

if ! id fomar >/dev/null 2>&1; then
  echo "==> creating user fomar"
  sudo useradd -m -G sudo,adm,audio,video,netdev,input,render fomar
  echo "fomar:fomar" | sudo chpasswd
fi
sudo mkdir -p /home/fomar/.ssh
sudo chmod 700 /home/fomar/.ssh
sudo cp ~/.ssh/authorized_keys /home/fomar/.ssh/ 2>/dev/null || true
sudo chown -R fomar:fomar /home/fomar/.ssh

echo "==> setting hostname"
sudo hostnamectl set-hostname dgtablet

echo "==> enabling sshd"
sudo systemctl enable --now ssh

echo "==> setting zsh as default shell for chaos and fomar"
sudo chsh -s /usr/bin/zsh chaos
sudo chsh -s /usr/bin/zsh fomar

echo "==> authenticating github CLI for fomar"
if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
  sudo -u fomar mkdir -p /home/fomar/.config/gh
  echo "${GH_TOKEN:-$GITHUB_TOKEN}" | sudo -u fomar gh auth login --with-token
  sudo -u fomar gh auth setup-git
  echo "==> cloning notes repo"
  sudo -u fomar mkdir -p /home/fomar/notes
  if [ ! -d /home/fomar/notes/.git ]; then
    sudo -u fomar git clone https://github.com/jitumaatgit/notes /home/fomar/notes
  fi
else
  echo "==> no GH_TOKEN set — skipping notes clone, run 'gh auth login' as fomar manually"
fi

echo "==> configuring LightDM autologin for fomar"
sudo sed -i 's/^autologin-user=.*/autologin-user=fomar/' /etc/lightdm/lightdm.conf
grep -q 'autologin-user=fomar' /etc/lightdm/lightdm.conf || echo "autologin-user=fomar" | sudo tee -a /etc/lightdm/lightdm.conf

echo "==> running deploy.sh as fomar"
curl -fsSL https://raw.githubusercontent.com/jitumaatgit/tablet-dotfiles/main/deploy.sh | sudo -u fomar bash

echo "==> setup complete. reboot to finish."

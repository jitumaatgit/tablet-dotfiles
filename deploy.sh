#!/bin/bash
set -euo pipefail

DOTFILES_REPO="https://github.com/jitumaatgit/tablet-dotfiles"

if [ -d "$HOME/.dotfiles" ]; then
  echo "==> updating dotfiles"
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" fetch origin
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" reset --hard origin/main
else
  echo "==> cloning dotfiles bare repo"
  git clone --bare "$DOTFILES_REPO" "$HOME/.dotfiles"
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -f main
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no
fi

echo "==> configuring foot autostart"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/foot.desktop" << 'FT'
[Desktop Entry]
Type=Application
Name=Foot
Exec=foot --server
Icon=foot
Categories=System;TerminalEmulator;
X-GNOME-Autostart-enabled=true
FT

echo "==> dotfiles deployed. reboot to finish."

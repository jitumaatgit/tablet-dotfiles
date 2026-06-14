#!/bin/bash
set -euo pipefail

DOTFILES_REPO="https://github.com/jitumaatgit/tablet-dotfiles"

if [ -d "$HOME/.dotfiles" ]; then
  echo "==> updating dotfiles"
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" pull origin main
else
  echo "==> cloning dotfiles bare repo"
  git clone --bare "$DOTFILES_REPO" "$HOME/.dotfiles"
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout -f main
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no
fi

echo "==> configuring WezTerm autostart"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/wezterm.desktop" << 'WZ'
[Desktop Entry]
Type=Application
Name=WezTerm
Exec=wezterm start --always-new-process
Icon=org.wezfurlong.wezterm
Categories=System;TerminalEmulator;
X-GNOME-Autostart-enabled=true
WZ

echo "==> installing nvim plugins"
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "==> installing treesitter parsers"
nvim --headless "+TSInstallSync markdown markdown_inline lua bash rust python" +qa 2>/dev/null || true

echo "==> dotfiles deployed. reboot to finish."

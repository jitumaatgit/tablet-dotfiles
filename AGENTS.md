# AGENTS.md — Doogee U10 Debian tablet (home-wide)

Machine-wide setup notes. See `/tmp/opencode/handoff-doogee-u10-debian.md` for hardware specs, eMMC migration history, and boot chain. See `notes/AGENTS.md` for the Obsidian vault only.

## Debian package quirks (trixie)

- Helix editor is packaged as `hx`, not `helix`. Binary: `hx`. Confirmed in trixie apt.
- Anki is NOT in Debian apt repos (dropped). Install via flatpak: `flatpak install -y flathub net.ankiweb.Anki` (flathub remote already configured).
- `rustup` apt package conflicts with and supersedes Debian's `rustc`, `cargo`, `rust-analyzer`. Use `rustup` to manage the Rust toolchain (`rustup default stable`, `rustup component add rust-analyzer`); do NOT `apt install rustc`.
- `tshark`/`wireshark-common` postinst blocks `apt install` with an interactive debconf prompt about non-root capture (wireshark group). If apt times out, finish with `sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a`.
- Non-interactive tshark config sets `wireshark-common/install-setuid: false` and does NOT create the `wireshark` group. For non-root capture, set it up manually: `sudo groupadd -r wireshark; sudo usermod -aG wireshark fomar; sudo chgrp wireshark /usr/bin/dumpcap; sudo chmod 750 /usr/bin/dumpcap; sudo setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap`. User must re-login (or `sg wireshark -c '...'`) for the group to apply.
- `getcap` is NOT installed by default; only `setcap` (from `libcap2-bin` is missing — install if you need to verify capabilities).

## CPU governor / power (RK3562)

- `rk-power-profile-sync.service` maps Phosh power modes → governors via `/etc/default/rk-power-profile-map`. It overrides manual `scaling_governor` writes whenever the Phosh power mode changes. Edit that file to make a governor choice persistent across mode switches (backup before editing; backup saved at `/etc/default/rk-power-profile-map.bak.*`).
- On this all-A53 SoC, `schedutil` gives ~99.9% of `performance` governor throughput under load (measured: SHA256 786.6k vs 787.6k KB/s) but idles to 408 MHz. `performance` governor pins 2.016 GHz with no measurable benefit for typical work — use `schedutil` as the daily driver.
- `powersave` governor pins 408 MHz = ~20% of performance throughput (5x slower). Reserve for emergency battery stretching only. The `RK_POWER_SAVER_MAX_PCT=65` freq cap is moot — `powersave` parks at min freq regardless.
- Available governors: `interactive conservative ondemand userspace powersave performance schedutil`. Freq steps (kHz): 408000 → 2016000. Driver: `cpufreq-dt`.
- `openssl speed -seconds N -bytes B sha256` is a portable SoC governor benchmark that exercises the ARM crypto extensions (AES/SHA1/SHA2/CRC32 present on this SoC).

## Battery / power measurement

- `/sys/class/power_supply/battery/current_now` + `voltage_now` give instantaneous power draw, BUT `current_now` reflects charge current when the tablet is charging — only meaningful when discharging (unplugged). To measure real system draw: unplug, then sample.
- `current_now` is in microamps, `voltage_now` in microvolts. Power (W) = current_now * voltage_now / 1e12.
- Battery capacity: ~4510 mAh (`charge_full_design`). zram swap: 1.9 GB.

## Installed toolchain (verified working)

- `hx` (Helix 25.01.1), `nmap` 7.95, `tcpdump` 4.99.5, `tshark` 4.4.15, `traceroute` 2.1.6, `mtr` 0.95, `rustc`/`cargo`/`rust-analyzer` 1.96.0 stable, `openssl` 3.5.6, Anki 25.09.05 (flatpak).
- `gcc git curl dig` were pre-existing. `clang`, `wireshark` GUI, `gdb` not installed.
- Rust builds on 4x A53 are slow — offload heavy `cargo build` to a desktop/VPS via SSH/mosh; use the tablet as a thin client with `hx` + `rust-analyzer` for editing.

## Dotfiles (bare repo)

- Dotfiles live in a **bare git repo** at `~/.dotfiles` with work-tree = `$HOME`. Files like `.zshrc` live directly in `~` — no symlinks. Remote: https://github.com/jitumaatgit/tablet-dotfiles (branch `main`).
- The `dotfiles` alias (`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`) only exists in interactive zsh. From a script/non-interactive shell, use the full form:
  ```
  git --git-dir=$HOME/.dotfiles --work-tree=$HOME <command>
  ```
- `.gitignore` is **deny-by-default**: starts with `/*` then `!/path` opt-ins. New root-level files/dirs must be explicitly added to `.gitignore` before they can be tracked.
- Push workflow:
  ```
  dotfiles add -A
  dotfiles commit -m "..."
  dotfiles push
  ```
- Credential helper is set up by `gh auth setup-git` (HTTPS, run in setup.sh). `.gitconfig` holds `user.name`/`user.email`.
- Lazygit does NOT work with bare repos — UI floods with untracked files. Use CLI (`dotfiles status`, `dotfiles diff`, `dotfiles add -p`).
- Deploy elsewhere uses `fetch + reset --hard origin/main`, NOT `pull` (pull fails on bare repos with unstaged changes). The tablet is a consumer, not the source of truth.

## Neovim

- Wayland clipboard: `xclip` alone produces `target STRING not available` errors. Install `wl-clipboard` (`apt install wl-clipboard`) — Neovim auto-detects `wl-copy`/`wl-paste` and prefers them over xclip on Wayland.
- marksman (Markdown LSP) is installed via Mason as `marksman-linux-arm64` at `~/.local/share/nvim/mason/bin/marksman`. On this slow ARM64 SoC with a large vault (~756 .md files), marksman crashes with `MailboxProcessor.PostAndAsyncReply timed out` unless `incremental_references = true` is set in `~/notes/.marksman.toml`.

## Wi-Fi constraint (unchanged, see handoff)

- Seekwave EA6621Q via `skw_sdio`, no monitor mode / no injection. 802.11 attacks need a compatible USB Wi-Fi dongle (Alfa) + USB-C hub. `iw list` returns empty.

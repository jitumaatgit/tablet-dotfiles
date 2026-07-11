# AGENTS.md — Doogee U10 Debian tablet (home-wide)

Machine-wide setup notes. See `notes/AGENTS.md` for the Obsidian vault only. (Note: `/tmp/opencode/handoff-doogee-u10-debian.md` was previously referenced here for hardware/eMMC/boot-chain detail but does NOT exist on disk — boot-chain basics are inlined in the "Kernel, boot chain & eMMC layout" section below; re-create that handoff doc if you do a full write-up.)

## Debian package quirks (trixie)

- Helix editor is packaged as `hx`, not `helix`. Binary: `hx`. Confirmed in trixie apt.
- Anki is NOT in Debian apt repos (dropped). Install via flatpak: `flatpak install -y flathub net.ankiweb.Anki` (flathub remote already configured).
- `rustup` apt package conflicts with and supersedes Debian's `rustc`, `cargo`, `rust-analyzer`. Use `rustup` to manage the Rust toolchain (`rustup default stable`, `rustup component add rust-analyzer`); do NOT `apt install rustc`.
- `tshark`/`wireshark-common` postinst blocks `apt install` with an interactive debconf prompt about non-root capture (wireshark group). If apt times out, finish with `sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a`.
- Non-interactive tshark config sets `wireshark-common/install-setuid: false` and does NOT create the `wireshark` group. For non-root capture, set it up manually: `sudo groupadd -r wireshark; sudo usermod -aG wireshark fomar; sudo chgrp wireshark /usr/bin/dumpcap; sudo chmod 750 /usr/bin/dumpcap; sudo setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap`. User must re-login (or `sg wireshark -c '...'`) for the group to apply.
- `getcap` is NOT installed by default; only `setcap` (from `libcap2-bin` is missing — install if you need to verify capabilities).
- Third-party apt repo `/etc/apt/sources.list.d/debian.griffo.io.list` serves ONLY dev tools (deno, zig, forgejo, lazygit, yazi, zed, uv, fzf, termusic, tigerbeetle, uncloud) — no system/kernel/Android/container packages. Don't look here for waydroid, gbinder, etc.
- `bat` is packaged as `batcat`, not `bat`. Binary: `batcat`. `.zshrc` aliases `bat=batcat` but aliases don't expand in `sh -c` strings or env vars — always use `batcat` directly in `MANPAGER`, scripts, etc.
- `batcat` 0.25.0 does NOT bundle Catppuccin themes. Install manually: download `.tmTheme` from `catppuccin/bat` GitHub into `~/.config/bat/themes/`, then run `batcat cache --build` to register them.

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
- Build-offload constraint: the user's main laptop is Windows with WSL2/Docker blocked by corp policy — those are NOT options. For heavy builds, the only offload is a temporary ARM64 cloud VPS (Hetzner CAX11 / AWS Graviton, rent for ~1h), or native overnight build on the tablet (kernel build ~3-4h at `make -j2`; `-j4` OOM-risks on 3.8 GB RAM).

## Dotfiles (bare repo)

- Dotfiles live in a **bare git repo** at `~/.dotfiles` with work-tree = `$HOME`. Files like `.zshrc` live directly in `~` — no symlinks. Remote: https://github.com/jitumaatgit/tablet-dotfiles (branch `main`).
- The `dotfiles` alias (`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`) only exists in interactive zsh. From a script/non-interactive shell, use the full form:
  ```
  git --git-dir=$HOME/.dotfiles --work-tree=$HOME <command>
  ```
- CLI flags (`--git-dir`/`--work-tree`) only apply to that one git invocation. For **subprocesses that spawn git** (e.g. opencode's agent), use env vars instead — they propagate to children: `GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME <command>`. The `occ()` function in `~/.zshrc` uses this pattern with `git rev-parse --git-dir` to auto-detect local repos vs. bare-repo-only dirs.
- `.gitignore` is **deny-by-default**: starts with `/*` then `!/path` opt-ins. New root-level files/dirs must be explicitly added to `.gitignore` before they can be tracked.
- Push workflow:
  ```
  dotfiles add -A
  dotfiles commit -m "..."
  dotfiles push
  ```
- Credential helper is set up by `gh auth setup-git` (HTTPS, run in setup.sh). `.gitconfig` holds `user.name`/`user.email`.
- **`remote.origin.fetch` refspec was initially missing** — `git fetch` wrote to `FETCH_HEAD` only, never created `origin/main`. Without `origin/main`, `--force-with-lease` rejects pushes (`stale info`) because it has no tracking ref to compare against. Fixed by setting `remote.origin.fetch` to `+refs/heads/*:refs/remotes/origin/*` (2026-07-11). If a fresh clone or rebuild re-introduces this, the same fix applies.
- After amending a pushed commit, force-push with `GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME git push --force-with-lease origin main`.
- Lazygit does NOT work with bare repos — UI floods with untracked files. Use CLI (`dotfiles status`, `dotfiles diff`, `dotfiles add -p`).
- Deploy elsewhere uses `fetch + reset --hard origin/main`, NOT `pull` (pull fails on bare repos with unstaged changes). The tablet is a consumer, not the source of truth.
- `~/.agents/` is tracked (opt-in `!/.agents/**` in `.gitignore`) for cross-port parity with the windows repo (`jitumaatgit/dotfiles` also tracks it). Tree is text-only — no secrets/caches. `.agents/.skill-lock.json` (skill-registry manifest) drifts across systems as skills update independently — like scoop's `config.json` on Windows. If it starts causing worktree churn, `git update-index --skip-worktree .agents/.skill-lock.json` keeps it tracked but invisible to `status`/`pull` (undo with `--no-skip-worktree`).

## Neovim

- Config: LazyVim at `~/.config/nvim/` (`init.lua` → `lua/config/` for options/keymaps, `lua/plugins/` for plugin specs, `lua/custom/` for custom modules). Config files also at `~/.local/share/nvim/`.
- **`glob`/`grep` tools do NOT expand `~`** — always use `/home/fomar/.config/nvim/` (full path) when searching for Neovim config files with these tools. `bash` does expand `~`, so `ls ~/.config/nvim/` works.
- Wayland clipboard: `xclip` alone produces `target STRING not available` errors. Install `wl-clipboard` (`apt install wl-clipboard`) — Neovim auto-detects `wl-copy`/`wl-paste` and prefers them over xclip on Wayland.
- marksman (Markdown LSP) is installed via Mason as `marksman-linux-arm64` at `~/.local/share/nvim/mason/bin/marksman`. On this slow ARM64 SoC with a large vault (~756 .md files), marksman crashes with `MailboxProcessor.PostAndAsyncReply timed out` unless `incremental_references = true` is set in `~/notes/.marksman.toml`.

## Kernel, boot chain & eMMC layout

- Running kernel is rockchip BSP `6.1.118` (NOT Debian stock). `/proc/config.gz` is available (IKCONFIG_PROC enabled) — `zcat /proc/config.gz` gives the running config, use as base for rebuilds.
- `/lib/modules/6.1.118/build` and `.../source` symlinks are DANGLING (point to `/home/cosmo/antigravity/rkdebian/src/kernel` — that user/dir is gone). No kernel headers on disk; DKMS and out-of-tree modules are impossible without re-fetching rockchip BSP source.
- `/boot` on rootfs is EMPTY — kernel does NOT load from rootfs `/boot`. It lives in a dedicated Android-style boot partition on eMMC. `/proc/cmdline` contains `androidboot.fwver=ddr-v1.06-...,spl-v1.06,bl31-v1.22,bl32-v1.08,uboot--boot` confirming the Android boot chain (DDR init → SPL → TF-A bl31 → bl32 → u-boot) baked into firmware.
- `fw_printenv` is NOT installed; u-boot env not readable. Whether this u-boot honors an extlinux/syslinux fallback on rootfs (which would make kernel replacement trivial) is untested — test before assuming.
- Stock Debian 6.12 kernel (`linux-image-6.12.86+deb13-arm64`) ships 48 rockchip DTBs but ZERO for rk3562 (only rk3566/rk3568). Booting it = no display/Wi-Fi(`skw_sdio`)/touch, likely unbootable. Do NOT `apt install` a stock Debian kernel expecting it to work on this tablet.
- eMMC = `mmcblk2`, ~25 Android-style GPT partitions. Debian root = `mmcblk2p25` (110.4G ext4, label `rootfs-emmc`, mounted at `/`). `mmcblk2p1`–`p18` are firmware/boot (DDR/SPL/bl31/bl32/u-boot/boot_a/boot_b/vendor_boot) — DO NOT `dd`/reformat without a backup. Partition names aren't in `lsblk` output; dump with `sudo sgdisk -p /dev/mmcblk2` (needs `gdap`/`gdisk`).

## Wi-Fi constraint (unchanged, see handoff)

- Seekwave EA6621Q via `skw_sdio`, no monitor mode / no injection. 802.11 attacks need a compatible USB Wi-Fi dongle (Alfa) + USB-C hub. `iw list` returns empty.

## Waydroid / Android containers

- Waydroid needs binderfs; running kernel has `CONFIG_ANDROID_BINDER_IPC is not set` — `waydroid_container.service` will fail with "binder node not found" until the kernel is rebuilt with `CONFIG_ANDROID_BINDER_IPC=y` + `CONFIG_ANDROID_BINDERFS=y`. No DKMS shortcut (no headers, see above).
- Waydroid is NOT in trixie apt main, sid, or the griffo repo. Install from upstream: `curl -s https://repo.waydro.id | sudo bash -s -- -s trixie` then `apt install waydroid` (`-s trixie` is an explicitly supported value).
- Stock Debian 6.12 kernel's `binder_linux.ko` has `CONFIG_ANDROID_BINDERFS is not set` (legacy `/dev/binder` only, not binderfs) AND won't load on 6.1.118 (vermagic mismatch) — irrelevant for this tablet, don't waste time on it.

## Shell & environment

- `.zshrc` line 73: `for f in ~/notes/*.env; do . "$f"; done` — dropping any `.env` file in `~/notes/` auto-exports its contents on interactive zsh startup. Preferred way to add new API env vars without editing `.zshrc` directly (e.g. `~/notes/exa.env` for `EXA_API_KEY`).
- `MANPAGER` with `batcat` needs `MANROFFOPT="-c"` — without it, raw ANSI escape fragments (`4m`, `24m`, etc.) leak through because `col -bx` only strips backspace overstrikes, not SGR codes. `MANROFFOPT="-c"` tells groff not to emit them at all.

## Conventions

- All directories and files must be lowercase-kebab-case unless explicitly told otherwise.

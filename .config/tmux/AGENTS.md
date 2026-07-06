## Non-obvious Learnings

### tmux-resurrect: `ps` save-command-strategy fails to resolve nvim command

`save_command_strategies/ps.sh` returns empty output for nvim panes on this system — `ps -ao "ppid,args" | grep "^${pane_pid}"` finds no child (PPID lookup broken, likely busybox/Debian `ps` column layout or reparenting of `nvim --embed`). `linux_procfs` resolves to `nvim --embed` (wrong — headless embed, not usable for restore). The empty resolution causes restore to skip the pane entirely via awk filter `$11 !~ "^:$"`.

### Fix: `@resurrect-processes` inline strategy bypasses broken resolution

`set -g @resurrect-processes '~nvim -> nvim'` matches panes whose resolved command starts with `nvim` and overrides the restore to plain `nvim`. This sidesteps the broken `ps` resolution and the `$11` awk filter — direct path.

### `@resurrect-capture-pane-contents 'off'` avoids ghost frames

When capture-pane-contents is on and a pane is skipped during restore, `restore.sh` falls back to `cat`-ing the captured frame text + `exec shell`, which prints nvim's last frame as static text then drops to prompt — looks like nvim is up but isn't.

### auto-session + resurrect: Session.vim is the missing link

`@resurrect-strategy-nvim 'session'` runs `nvim -S Session.vim` but needs a Session.vim file in the pane cwd. `rmagatti/auto-session` writes it on exit/switch. Without auto-session, nvim relaunches empty even if the pane is correctly restored.

### Two tmux plugin installs, one active

Active: `~/.config/tmux/plugins/tmux-resurrect/` (per `tmux show-options -g | grep script-path`). Stale: `~/.tmux/plugins/tmux-resurrect/`. tpm itself runs from `~/.tmux/plugins/tpm/tpm` (configured in `run` directive).

### `display-popup -e` silently eats the next arg — no error, popup just dies

`-e` expects `VARIABLE=value` form. A bare `-e` (intended as "export env") consumes the next flag (`-w 80%`) as its value, leaving `-h` malformed. Symptom: popup flashes and vanishes, no message. Debug by running the inner command directly outside tmux — `inappropriate ioctl for device` reveals the real culprit.

### `run-shell` has no PTY — interactive TUIs (fzf) exit silently

`bind C-r run-shell '... | fzf'` runs fzf with no controlling terminal. fzf detects the missing PTY and exits 0 immediately — no error, no picker. Use `display-popup -E` (tmux 3.2+) instead, which spawns a real terminal pane. Verified on tmux 3.5a / Debian trixie aarch64.

### tmux-resurrect restore API: symlink target to `last`, then run restore.sh

Custom restore must `ln -sf chosen.txt last` in `~/.local/share/tmux/resurrect/` before invoking `scripts/restore.sh`. The script hardcodes `last` as its input — there's no `-f file` flag. Sorted `ls -1 *.txt | sort -r` gives newest-first; Enter on top entry == restore latest (degrades to default behavior).

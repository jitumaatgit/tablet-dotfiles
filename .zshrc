# --- zsh config for dgtablet ---

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt extended_history hist_ignore_dups hist_ignore_space hist_reduce_blanks share_history auto_cd correct

autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source <(fzf --zsh)
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --strip-cwd-prefix"

_lazy_init() {
  eval "$(zoxide init zsh --cmd cd)"
  eval "$(starship init zsh)"
  add-zsh-hook -d precmd _lazy_init
}

function set_win_title() { echo -ne "\033]0; $(basename "$PWD") \007" }
starship_precmd_user_func="set_win_title"
add-zsh-hook precmd _lazy_init

alias ls='eza --icons --group-directories-first -a'
alias bat=batcat
alias cat='bat --paging=never'
alias grep='rg --color=auto'
alias lg='lazygit'
alias find='fd'
alias i='z -i'
alias zi='z -i'
alias vim='nvim'
alias oc='opencode'
occ() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if [ $# -gt 0 ]; then
      opencode run "$@"
      return
    fi
    opencode run --command commit
  else
    if [ $# -gt 0 ]; then
      GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME opencode run "$@"
      return
    fi
    GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME opencode run --command commit
  fi
}
function ocp {
  if [ $# -gt 0 ]; then
    opencode --prompt "$*"
    return
  fi
  mkdir -p ~/notes/90-archive/prompts
  local f="$HOME/notes/90-archive/prompts/$(date +%Y%m%d-%H%M%S).md"
  ${EDITOR:-nvim} "$f"
  [ -s "$f" ] || return
  local p="$(command awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{f=0; next} !f' "$f")"
  [ -n "$p" ] || return
  opencode --prompt "$p"
}
alias preview='bat --style=plain --paging=always'
alias dotfiles='git --git-dir="$HOME/.dotfiles" --work-tree="$HOME"'

export EDITOR="nvim"
export VISUAL="foot nvim"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd --version-file-strategy=recursive)"
export OPENCODE_DISABLE_AUTOUPDATE=true
export PLANNOTATOR_DATA_DIR="$HOME/notes/docs/plannotator"
export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
export MANROFFOPT="-c"
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

[ -f ~/notes/opencode-server.env ] && . ~/notes/opencode-server.env
[ -f ~/notes/deepseek.env ] && . ~/notes/deepseek.env
for f in ~/notes/*.env; do [ -f "$f" ] && . "$f"; done

[ -f ~/.free-coding-models.env ] && . ~/.free-coding-models.env  # free-coding-models-env

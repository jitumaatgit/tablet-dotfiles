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

source /usr/share/doc/fzf/examples/key-bindings.zsh
source /usr/share/doc/fzf/examples/completion.zsh
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --strip-cwd-prefix"

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

function set_win_title() { echo -ne "\033]0; $(basename "$PWD") \007" }
starship_precmd_user_func="set_win_title"

alias ls='eza --icons --group-directories-first -a'
alias cat='bat --paging=never'
alias grep='rg --color=auto'
alias lg='lazygit'
alias find='fd'
alias vim='nvim'
alias oc='opencode'
alias preview='bat --style=plain --paging=always'

export EDITOR="nvim"
export VISUAL="wezterm start -- nvim"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export OPENCODE_DISABLE_AUTOUPDATE=true

[ -f ~/notes/opencode-server.env ] && . ~/notes/opencode-server.env
[ -f ~/notes/deepseek.env ] && . ~/notes/deepseek.env
for f in ~/notes/*.env; do [ -f "$f" ] && . "$f"; done

# ~/.zshrc - Kali-styled interactive Zsh configuration for Pendora (Fedora)
# Replicates authentic Kali Linux prompt, syntax highlighting, completions and keybindings.

# Ensure local user binaries (pipx, local scripts) are in PATH
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Zsh Options
setopt autocd              # Change directory just by typing its name
setopt interactivecomments # Allow comments in interactive shell (#)
setopt magicequalsubst     # Enable filename expansion for arguments like 'prefix=path'
setopt nonomatch           # Don't error out immediately if globbing has no match
setopt notify              # Report background job status immediately
setopt numericglobsort     # Sort filenames numerically when appropriate
setopt promptsubst         # Enable variable & command substitution in prompt

WORDCHARS='_-' # Don't consider certain characters part of word navigation

# Hide EOL sign ('%')
PROMPT_EOL_MARK=""

# Keybindings (Standard Emacs / Modern Terminal)
bindkey -e
bindkey ' ' magic-space
bindkey '^U' backward-kill-line
bindkey '^[[3;5~' kill-word
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[5~' beginning-of-buffer-or-history
bindkey '^[[6~' end-of-buffer-or-history
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[Z' undo

# Advanced Completion Engine
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# History Configurations
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify

alias history="history 0"

# Time output format
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

# Color support detection
force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

# Authentic Kali Prompt Definition
configure_prompt() {
    prompt_symbol=" %F{cyan}󰞀%F{%(#.red.blue)} "
    # Skull symbol for root prompt
    [ "$EUID" -eq 0 ] && prompt_symbol=" %F{yellow}💀%F{red} "

    # Hostname: Default to 'pendora' if running under generic default hostnames (fedora, localhost)
    local prompt_host="${PROMPT_HOST:-}"
    if [ -z "$prompt_host" ]; then
        if [[ "${HOST:-}" =~ ^(fedora|localhost)(\..*)?$ ]] || [ -z "${HOST:-}" ]; then
            prompt_host="pendora"
        else
            prompt_host="%m"
        fi
    fi

    case "$PROMPT_ALTERNATIVE" in
        twoline)
            # Two-line Kali prompt:
            # ┌──(user㉿host)-[~/path]
            # └─$
            PROMPT=$'%F{%(#.blue.green)}┌──${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'$prompt_symbol$prompt_host$'%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]\n└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
            ;;
        oneline)
            PROMPT=$'${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{%(#.red.blue)}%n@'$prompt_host$'%b%F{reset}:%B%F{%(#.blue.green)}%~%b%F{reset}%(#.#.$) '
            ;;
        backtrack)
            PROMPT=$'${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{red}%n@'$prompt_host$'%b%F{reset}:%B%F{blue}%~%b%F{reset}%(#.#.$) '
            ;;
    esac
}

# Prompt Settings
PROMPT_ALTERNATIVE=twoline
NEWLINE_BEFORE_PROMPT=yes

if [ "$color_prompt" = yes ]; then
    VIRTUAL_ENV_DISABLE_PROMPT=1
    configure_prompt

    # Syntax Highlighting with Kali Palette (Fedora native path: /usr/share/zsh-syntax-highlighting/)
    for hl_path in /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
                   /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
        if [ -f "$hl_path" ]; then
            source "$hl_path"
            ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
            ZSH_HIGHLIGHT_STYLES[default]=none
            ZSH_HIGHLIGHT_STYLES[unknown-token]=underline
            ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
            ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
            ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green,bold
            ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
            ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
            ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
            ZSH_HIGHLIGHT_STYLES[path]=bold
            ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
            ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
            ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta,bold
            ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta,bold
            ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
            ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
            ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
            ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
            ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
            ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta,bold
            ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
            ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
            ZSH_HIGHLIGHT_STYLES[arg0]=fg=cyan
            ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red,bold
            ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue,bold
            ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green,bold
            ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta,bold
            ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow,bold
            ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan,bold
            break
        fi
    done
else
    PROMPT='%n@%m:%~%(#.#.$) '
fi
unset color_prompt force_color_prompt

# Toggle between two-line and one-line prompt with Ctrl + P
toggle_oneline_prompt(){
    if [ "$PROMPT_ALTERNATIVE" = oneline ]; then
        PROMPT_ALTERNATIVE=twoline
    else
        PROMPT_ALTERNATIVE=oneline
    fi
    configure_prompt
    zle reset-prompt
}
zle -N toggle_oneline_prompt
bindkey '^P' toggle_oneline_prompt

# Terminal title support
case "$TERM" in
xterm*|rxvt*|Eterm|aterm|kterm|gnome*|alacritty)
    TERM_TITLE=$'\e]0;${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%n@%m: %~\a'
    ;;
*)
    ;;
esac

precmd() {
    print -Pnr -- "$TERM_TITLE"
    if [ "$NEWLINE_BEFORE_PROMPT" = yes ]; then
        if [ -z "$_NEW_LINE_BEFORE_PROMPT" ]; then
            _NEW_LINE_BEFORE_PROMPT=1
        else
            print ""
        fi
    fi
}

# Colorized Directory Listings & Utilities
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:"

    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip --color=auto'

    export LESS_TERMCAP_mb=$'\E[1;31m'
    export LESS_TERMCAP_md=$'\E[1;36m'
    export LESS_TERMCAP_me=$'\E[0m'
    export LESS_TERMCAP_so=$'\E[01;33m'
    export LESS_TERMCAP_se=$'\E[0m'
    export LESS_TERMCAP_us=$'\E[1;32m'
    export LESS_TERMCAP_ue=$'\E[0m'
    export MANROFFOPT="-c"

    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
fi

alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'

# Autosuggestions (Fedora native path: /usr/share/zsh-autosuggestions/)
for as_path in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
               /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    if [ -f "$as_path" ]; then
        source "$as_path"
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
        break
    fi
done

# Pentesting Quick Aliases
alias myip="ip -br -c a"
alias ports="ss -tulpn"
alias serve-http="python3 -m http.server 8000"
alias serve-updog="updog -p 9090"
alias seclists="ls -la /usr/share/wordlists/seclists 2>/dev/null || echo 'SecLists not installed at /usr/share/wordlists/seclists'"

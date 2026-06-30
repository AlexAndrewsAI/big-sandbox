# ~/.bashrc

# Enable color support for ls and grep
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi



alias histfind="history | grep --color=always --ignore-case"
alias t="tail -f"
alias l="less"
alias topu="top -u $USER"
alias ll="ls -lha"
alias la="ls -a"
alias ld="ls -d"
alias lt="ls -lhatr"
devnullredirect () {
    echo "$@ 2>/dev/null"
    "$@" 2>/dev/null
}
function f {
    devnullredirect find . -iname $@
}

alias uv-tests="source .venv/bin/activate; uv sync --dev; ruff format; ruff check --fix; pytest --cov=myproj --cov-report term-missing; mypy ."
alias venv-here="[ ! -d .venv ] && uv venv; source .venv/bin/activate"



# Source personal customizations if present (not committed to git)
if [ -f /persist/bashrc-extra ]; then
    . /persist/bashrc-extra
fi

echo "Welcome to the Simple Agent Sandbox!"
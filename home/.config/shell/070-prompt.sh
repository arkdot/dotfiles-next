# Initializes starship prompt.
if has_command "starship"; then
    export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
    if shell_is_zsh; then
        eval "$(starship init zsh)"
    else
        eval "$(starship init bash)"
    fi
elif shell_is_zsh; then
    autoload -U colors && colors
    PS1="%F{blue}%n%f%F{cyan}@%f%F{magenta}%m%f %F{green}%~%f
%F{green}>%f "
else
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\$ '
fi

# Add color to terminal
export CLICOLOR=1

# Initializes starship prompt.
if has_command "starship"; then
    export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
    eval "$(starship init zsh)"
elif shell_is_zsh; then
    autoload -U colors && colors
    PS1="%F{blue}%n%f%F{cyan}@%f%F{magenta}%m%f %F{green}%~%f
%F{green}>%f "
else
fi

# Add color to terminal
export CLICOLOR=1

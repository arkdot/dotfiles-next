if has_command "zoxide"; then
    if shell_is_zsh; then
        eval "$(zoxide init zsh)"
    elif shell_is_bash; then
        eval "$(zoxide init bash)"
    fi
fi

if has_command "eza"; then
    alias ls="eza --color=auto --group-directories-first"
    alias ll="ls --long -g --icons=always"
    alias tree="ll --tree"
fi

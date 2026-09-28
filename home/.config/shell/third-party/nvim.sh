
if has_command "bob"; then
    prepend_path "${XDG_DATA_HOME}/bob/nvim-bin"
    alias vi="nvim"
    alias vim="nvim"
fi

if has_command "nvim"; then
    alias vi="nvim"
    alias vim="nvim"
fi

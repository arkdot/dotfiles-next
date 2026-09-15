if has_command "tmux"; then
    alias t="tmux"
    alias ts="tmux-sessionizer"
    alias tls="tmux list-sessions"
    alias tns="tmux new-session -t"
    alias tks="tmux kill-session -t"
    alias ta="tmux attach-session -t"
fi

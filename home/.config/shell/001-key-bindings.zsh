# Key bindings in emacs mode.
# Restores Ctrl/A and Ctrl/E to move to the beginning and end of the line.
bindkey -e

# Start typing + [Up-Arrow] - fuzzy find history forward
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# [Ctrl-RightArrow] - move forward one word
bindkey -M emacs '^[[1;5C' forward-word
bindkey -M viins '^[[1;5C' forward-word
bindkey -M vicmd '^[[1;5C' forward-word

# [Ctrl-LeftArrow] - move backward one word
bindkey -M emacs '^[[1;5D' backward-word
bindkey -M viins '^[[1;5D' backward-word
bindkey -M vicmd '^[[1;5D' backward-word


# Edit the current command line in $EDITOR
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

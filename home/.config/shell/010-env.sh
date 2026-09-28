# Prefer US English and use UTF-8
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"

export TERM="xterm-256color"

# Additional directories to look for programs
prepend_path() { [[ -d "$1" ]] && case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }

prepend_path $HOME/.cargo/bin
prepend_path $HOME/.local/bin

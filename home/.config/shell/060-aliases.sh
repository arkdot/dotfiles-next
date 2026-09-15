# cd aliases.
alias dl="cd ~/Downloads"
alias dt="cd ~/Desktop"
alias doc="cd ~/Documents"

# Change owner.
alias my="sudo chown `id -u`:`id -g`"

# == ls aliases ======================================================================
alias ls="ls --color=auto --group-directories-first"
alias ll="ls -lh"
alias l="ll"
alias l1="ls -1"
alias la="ll -a"
alias lla="ll -a"

# == du aliases ======================================================================
if has_command "ncdu"; then
    alias du="ncdu -x -r --exclude .git"
else
    alias du="du -h"
fi
alias du1="\du -h --max-depth=1"


alias grep="grep --color"
alias egrep="egrep --color"

# Other aliases
alias rle="readlink -e"

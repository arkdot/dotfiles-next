# == cd ========================================================================
shopt -s autocd               # prepend cd to directory names automatically
shopt -s dirspell             # correct spelling errors during tab-completion
shopt -s cdspell              # correct spelling errors in arguments supplied to cd
shopt -s nocaseglob           # case-insensitive globbing (used in pathname expansion)
shopt -s globstar 2>/dev/null # recursive globbing (enables ** to recurse all directories)
CDPATH=".:~"                  # this defines where cd looks for targets

# == Completion ================================================================
bind "set completion-ignore-case on"     # perform file completion in a case insensitive fashion
bind "set completion-map-case on"        # treat hyphens and underscores as the same
bind "set show-all-if-ambiguous on"      # display matches for ambiguous patterns at first tab press
bind "set mark-symlinked-directories on" # add trailing slash when autocompleting symlinks to directories
bind Space:magic-space                   # typing !!<space> will replace the !! with your last command

# == History ===================================================================
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND ;} history -a"

shopt -s histreedit  # wllow use to re-edit a failed history substitution.
shopt -s cmdhist     # save multi-line commands as one command
shopt -s histverify  # history expansions will be verified before execution.
shopt -s histappend  # append to the history file, don't overwrite it

export HISTTIMEFORMAT="[%F %T] "
export HISTSIZE=10000
export HISTFILESIZE=10000

mkdir -p "${XDG_STATE_HOME}/bash"
export HISTFILE=${XDG_STATE_HOME}/bash/history

# Avoid duplicate entries and skip commands with a leading space
# (ignoreboth = ignorespace + ignoredups; erasedups also purges prior dupes)
HISTCONTROL="erasedups:ignoreboth"

# Don't record these commands
export HISTIGNORE="&:[ ]*:exit:ls:bg:fg:history:clear"

# Enable incremental history search with up/down arrows (also Readline goodness)
# Learn more about this here: http://codeinthehole.com/writing/the-most-important-command-line-tip-incremental-history-searching-with-inputrc/
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e[C": forward-char'
bind '"\e[D": backward-char'

setopt always_to_end      # When completing a word, move the cursor to the end of the word
setopt complete_in_word   # if unset, the cursor is set to the end of the word if completion is started.
                          # Otherwise it stays there and completion is done from both ends.
setopt auto_list          # list available completion when pressing Tab
setopt auto_menu          # cycle through possible completions when pressing Tab repeatedly
setopt auto_pushd         # make cd push each old directory onto the stack
setopt pushd_ignore_dups  # don't push duplicates onto the stack
setopt no_beep            # silence all bells and beeps

# == History ===================================================================
setopt hist_expire_dups_first  # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_find_no_dups       # when searching history don't show results already cycled through twice
setopt hist_ignore_dups        # do not write events to history that are duplicates of previous events
setopt hist_ignore_all_dups    # delete old recorded event if new event is a duplicate
setopt hist_save_no_dups       # if a new command is a duplicate of the previous command, don't save it
setopt hist_ignore_space       # remove command line from history list when first character is a space
setopt hist_reduce_blanks      # remove superfluous blanks from history items
setopt hist_verify             # show command with history expansion to user before running it
setopt histignorespace         # remove commands from the history when the first character is a space
setopt inc_append_history      # save history entries as soon as they are entered
setopt share_history           # share history between different instances of the shell

mkdir -p "${XDG_STATE_HOME}/zsh"
HISTFILE="${XDG_STATE_HOME}/zsh/history"
HISTSIZE=100000
SAVEHIST=${HISTSIZE}


# == Completions ===============================================================
# Force rehash when command not found
_force_rehash() {
    ((CURRENT == 1)) && rehash
    return 1
}
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_DIR}/zsh/cache"

zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*' completer _oldlist _expand _force_rehash _complete _match # forces zsh to realize new commands
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'                           # matches case insensitive for lowercase
zstyle ':completion:*' insert-tab pending                                        # pasting with tabs doesn't perform completion
zstyle ':completion:*' menu select=2                                             # menu if nb items > 2
zstyle ':completion:*' special-dirs true                                         # Show dotfiles in completions

zstyle ':completion:*:functions' ignored-patterns '_*' #Ignore completion functions for commands you don't have
zstyle ':completion:*' squeeze-slashes true            #f you end up using a directory as argument, this will remove the trailing slash (useful in ln)

# Tweak the UX of the autocompletion menu to match even if we made a typo and enable navigation using the arrow keys
# zstyle ':completion:*' menu select   # select completions with arrow keys
zstyle ':completion:*' group-name '' # group results by category

zstyle ':completion:::::' completer _expand _complete _ignored _approximate # enable approximate matches for completion

# Make zsh know about hosts already accessed by SSH
zstyle -e ':completion:*:(ssh|scp|sftp|rsh|rsync):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false

# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no

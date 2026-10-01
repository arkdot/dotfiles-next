# Managed by dotfiles repo.
# Source shell fragments in deterministic order by filename prefix and path.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

shell_files=$(find "$HOME/.config/shell" -type l \( -name '*.sh' -o -name '*.bash' \) | sort)

for shell_file in ${shell_files}; do
  [[ -f "$shell_file" ]] && source "$shell_file"
done

alias s='source "$HOME/.bashrc"'

# Source $HOME/.extra if exists
[[ -f $HOME/.extra ]] && source ~/.extra

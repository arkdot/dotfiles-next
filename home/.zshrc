# Managed by dotfiles repo.
# Source shell fragments in deterministic order by filename prefix and path.

shell_files=$(find "$HOME/.config/shell" -type l \( -name '*.sh' -o -name '*.zsh' \) | sort)

for shell_file in ${(f)shell_files}; do
  [[ -f "$shell_file" ]] && source "$shell_file"
done

alias s='source "$HOME/.zshrc"'

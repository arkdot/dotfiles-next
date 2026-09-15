# Managed by dotfiles repo.
# Source shell fragments in deterministic order by filename prefix and path.

shell_files=( ${(f)"$(find "$HOME/.config/shell" -type f \( -name '*.sh' -o -name '*.zsh' \) -print | sort)"} )

for shell_file in "${shell_files[@]}"; do
  [[ -f "$shell_file" ]] && source "$shell_file"
done

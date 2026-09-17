#!/usr/bin/env bash
set -euo pipefail

# --- Color Codes ---
readonly reset="\033[0m"
readonly green="\033[32m"
readonly yellow="\033[33m"
readonly red="\033[31m"

# --- Configuration ---
readonly repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly dotfiles_source_dir="${repo_root}/home"

# --- Global Flags ---
dry_run=false
remove=false
force=false

# --- Logging Functions ---
log_added() {
  local file="$1"
  printf '%b[+]%b %s\n' "$green" "$reset" "$file"
}

log_modified() {
  local file="$1"
  printf '%b[~]%b %s\n' "$yellow" "$reset" "$file"
}

log_deleted() {
  local file="$1"
  printf '%b[-]%b %s\n' "$red" "$reset" "$file"
}

log_skipped() {
  local file="$1"
  printf '%b[!]%b Skipped: %s\n' "$yellow" "$reset" "$file"
}

log_error() {
  local message="$1"
  printf '%b[!]%b %s\n' "$red" "$reset" "$message" >&2
}

# --- User Prompts ---
confirm_action() {
  local prompt="$1"
  local default="${2:-n}"
  local answer

  printf '%b[?]%b %s [y/N] ' "$yellow" "$reset" "$prompt"
  read -r answer

  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Core Functions ---
link_dotfiles() {
  local file rel_path destination

  while IFS= read -r -d '' file; do
    rel_path="${file#${dotfiles_source_dir}/}"
    destination="${HOME}/${rel_path}"

    # Create parent directory if it doesn't exist
    mkdir -p -- "$(dirname -- "${destination}")"

    # Skip if already correctly symlinked
    if [[ -L "${destination}" && "$(readlink -- "${destination}")" == "${file}" ]]; then
      continue
    fi

    # Handle existing file/link
    if [[ -e "${destination}" || -L "${destination}" ]]; then
      log_modified "$rel_path"
      if [[ "$force" == false ]]; then
        if ! confirm_action "Overwrite ${destination}"; then
          log_skipped "$rel_path"
          continue
        fi
      fi
      [[ "$dry_run" == true ]] || rm -rf -- "${destination}"
    else
      log_added "$rel_path"
    fi

    [[ "$dry_run" == true ]] || ln -s -- "${file}" "${destination}"
  done < <(find "$dotfiles_source_dir" -type f -print0)
}

remove_dotfiles() {
  if [[ "$force" == false ]]; then
    if ! confirm_action "Remove ALL symlinked dotfiles from ${HOME}?"; then
      log_skipped "Removal cancelled by user."
      return
    fi
  fi

  local repo_file rel_path link target_dir

  # Remove symlinked files
  while IFS= read -r -d '' repo_file; do
    rel_path="${repo_file#${dotfiles_source_dir}/}"
    link="${HOME}/${rel_path}"

    if [[ -L "$link" && "$(readlink -- "$link")" == "$repo_file" ]]; then
      log_deleted "$rel_path"
      [[ "$dry_run" == true ]] || rm -f -- "$link"
    fi
  done < <(find "$dotfiles_source_dir" -type f -print0)

  # Remove empty directories
  while IFS= read -r -d '' repo_dir; do
    [[ "$repo_dir" == "$dotfiles_source_dir" ]] && continue

    rel_path="${repo_dir#${dotfiles_source_dir}/}"
    target_dir="${HOME}/${rel_path}"

    if [[ -d "$target_dir" ]] && [[ -z "$(find "$target_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
      log_deleted "$rel_path/"
      if [[ "$dry_run" == true ]]; then
        echo "  (Would remove empty directory)"
      else
        if ! rmdir -- "$target_dir" 2>/dev/null; then
          log_error "Failed to remove directory: $target_dir"
        fi
      fi
    fi
  done < <(find "$dotfiles_source_dir" -depth -type d -print0)
}

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename -- "$0") [OPTIONS]

Manage dotfiles via symlinks.

Options:
  -n, --dry-run     Show what would happen without making changes.
  -x, --remove      Remove symlinked dotfiles from \$HOME.
  -f, --force       Skip confirmation prompts (use with caution).
  -h, --help        Show this help message.
EOF
}

# --- Main ---
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run) dry_run=true ;;
      -x|--remove)  remove=true ;;
      -f|--force)   force=true ;;
      -h|--help)    usage; exit 0 ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done

  # Validate source directory
  if [[ ! -d "$dotfiles_source_dir" ]]; then
    log_error "Dotfiles source directory not found: ${dotfiles_source_dir}"
    exit 1
  fi

  # Execute based on mode
  if [[ "$remove" == true ]]; then
    remove_dotfiles
  else
    link_dotfiles
  fi

  # Dry-run notice
  if [[ "$dry_run" == true ]]; then
    echo "--- Dry run complete. No changes were made. ---"
  fi
}

main "$@"
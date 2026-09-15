#!/usr/bin/env bash
set -euo pipefail

reset="\033[0m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="${repo_root}/home"
dry_run=false
remove=false

log_added() {
  printf '%b[+]%b %s\n' "$green" "$reset" "$1"
}

log_modified() {
  printf '%b[~]%b %s\n' "$yellow" "$reset" "$1"
}

log_deleted() {
  printf '%b[-]%b %s\n' "$red" "$reset" "$1"
}

confirm_overwrite() {
  local target="$1"

  printf '%b[?]%b Overwrite %s? [y/N] ' "$yellow" "$reset" "$target"
  read -r answer

  case "$answer" in
    [Yy]|[Yy][Ee][Ss])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_files() {
  for file in $(find "$source_dir" -type f -print); do
    rel_path="${file#"${source_dir}"/}"
    destination="${HOME}/${rel_path}"

    mkdir -p "$(dirname -- "${destination}")"

    if [[ -L "${destination}" ]]; then
      if [[ "$(readlink -- "${destination}")" == "${file}" ]]; then
        continue
      fi

      log_modified "${rel_path}"
      if ! confirm_overwrite "${destination}"; then
        echo "Skipped: ${destination}"
        continue
      fi
      if [[ "$dry_run" == false ]]; then
        rm -f "${destination}"
        ln -s "${file}" "${destination}"
      fi
      continue
    fi

    if [[ -e "${destination}" ]]; then
      log_modified "${rel_path}"
      if ! confirm_overwrite "${destination}"; then
        echo "Skipped: ${destination}"
        continue
      fi
      if [[ "$dry_run" == false ]]; then
        rm -rf "${destination}"
      fi
    else
      log_added "${rel_path}"
    fi

    if [[ "$dry_run" == false ]]; then
      ln -s "${file}" "${destination}"
    fi
  done
}

remove_files() {
  for repo_file in $(find "$source_dir" -type f | sort); do
    rel_path="${repo_file#"${source_dir}"/}"
    link="${HOME}/${rel_path}"

    if [[ -L "$link" ]] && [[ "$(readlink -- "$link")" == "$repo_file" ]]; then
      log_deleted "$rel_path"
      if [[ "$dry_run" == false ]]; then
        rm -f "$link"
      fi
    fi
  done

  for repo_dir in $(find "$source_dir" -depth -type d | sort -r); do
    rel_path="${repo_dir#"${source_dir}"/}"

    if [[ "$rel_path" == "$source_dir" ]]; then
      continue
    fi

    target_dir="${HOME}/${rel_path}"

    if [[ -d "$target_dir" ]] && [[ -z "$(find "$target_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
      if [[ "$dry_run" == false ]]; then
        rmdir "$target_dir" 2>/dev/null || true
      else
        echo "Would remove empty directory: $target_dir"
      fi
    fi
  done
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        dry_run=true
        ;;
      -x|--remove)
        remove=true
        ;;
      -h|--help)
        echo "Usage: $0 [-n|--dry-run] [-x|--remove]"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: $0 [-n|--dry-run] [-x|--remove]" >&2
        exit 1
        ;;
    esac
    shift
done

  if [[ ! -d "${source_dir}" ]]; then
    echo "Missing dotfiles source directory: ${source_dir}" >&2
    exit 1
  fi


  if [[ "$remove" == true ]]; then
    remove_files
    if [[ "$dry_run" == true ]]; then
      echo "This was a dry-run, nothing actually happened"
    fi
    return 0
  fi

  install_files

  if [[ "$dry_run" == true ]]; then
    echo "This was a dry-run, nothing actually happened"
  fi
}

main "$@"

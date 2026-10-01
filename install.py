#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["rich"]
# ///

"""Boostraps dotfiles.

Directories will be created, and files will be symlinked.
"""

import argparse
import subprocess
import sys
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from tempfile import NamedTemporaryFile

from rich.console import Console
from rich.prompt import Confirm
from rich.progress import Progress

# Tools to be installed using cargo
CARGO_TOOL_LIST = ["bat", "eza", "fd-find", "ripgrep", "starship", "zoxide"]


# Rich console for logging & prompting
console = Console(stderr=True, highlight=False)


@dataclass(frozen=True)
class Config:
    dry_run: bool = False
    remove: bool = False
    force: bool = False  # do not ask for confirmation


def fatal_error(msg: str):
    console.print(f"[bold red]!! FATAL ERROR: {msg}")


def error(msg: str):
    console.print(f"[bold red]!! ERROR: {msg}")


def header(msg):
    console.print(f"\n[green]{msg}[/green]")


def parse_command_line() -> Config:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="show what would happen without making changes",
    )
    parser.add_argument(
        "-x",
        "--clean",
        action="store_true",
        help="remove symlinked files and empty directories",
    )
    args = parser.parse_args()
    return Config(dry_run=args.dry_run, remove=args.clean)


def ensure_directory(path: Path):
    """If `path` is not a directory, prints a fatal error and exists."""
    if not path.exists():
        fatal_error(f"{path!s}: not a valid path")
        sys.exit(1)
    if not path.is_dir():
        fatal_error(f"{path!s}: not a valid directory")
        sys.exit(1)


def log_added(path: Path):
    console.print(f"[bold green][+][/bold green] {path}")


def log_deleted(path: Path):
    console.print(f"[bold red][-][/bold red] {path}")


def log_modified(path: Path):
    console.print(f"[bold yellow][~][/bold yellow] {path}")


def iter_dotfiles(root: Path, dest_dir: Path) -> Iterator[Path, Path]:
    """Iterates over files and directories in the root directory.

    Creates the destination path on the fly.
    """
    return (
        (source, dest_dir / source.relative_to(source.parts[0]))
        for source in root.glob("**/*")
    )


def remove_dotfiles(root: Path, destination: Path, config: Config):
    """Removes links and empty directories created by `symlink_dotfiles`."""
    dry_run = config.dry_run

    # Get deepest path first to be able to remove empty directories
    by_depth = sorted(
        iter_dotfiles(root, destination),
        key=lambda item: len(item[0].parts),
        reverse=True,
    )

    for source_path, dest_path in by_depth:
        if dest_path.is_symlink():
            if dest_path.resolve() == source_path.resolve():
                log_deleted(dest_path)
                if not dry_run:
                    dest_path.unlink()

        # Removes empty directories
        elif dest_path.is_dir() and not list(dest_path.glob("**/*")):
            log_deleted(dest_path)
            if not dry_run:
                dest_path.rmdir()


def confirm_update(source: Path, target: Path, force: bool, dry_run: bool) -> bool:
    """Asks for confirmation before removing and replacing a file or symlink.

    If `force` is `False`, asks for user confirmation.
    If `dry_run` is `True`, still prints log messages but actually does nothing.

    Returns:
        bool: `True` if the file was confirmed to be destroyed by the user, `False` otherwise
    """
    destroy = True
    if not dry_run and not force:
        destroy = Confirm.ask(f"{target!s}: already exists. Destroy it?")

    if destroy:
        log_modified(target)
        if not dry_run:
            target.unlink()
            target.symlink_to(source.resolve())

    return destroy


def symlink_dotfiles(root: Path, destination: Path, config: Config):
    """Recursively creates directory and links to files from `root` to `destination`."""
    dry_run = config.dry_run
    force = config.force

    for source_path, dest_path in iter_dotfiles(root, destination):
        # source_path is a directory: creates destination directory if does not exist
        if source_path.is_dir():
            if dest_path.exists():
                if not dest_path.is_dir():
                    fatal_error(f"{dest_path!s}: expected to be a directory but is not")
            else:
                # log_added(dest_path)
                if not dry_run:
                    dest_path.mkdir()

        # source_path is a file
        else:
            # Remove existing file / updates symbolic link
            if dest_path.exists():
                if dest_path.is_symlink():
                    if dest_path.resolve() != source_path.resolve():
                        confirm_update(
                            source_path, dest_path, force=force, dry_run=dry_run
                        )
                else:
                    confirm_update(source_path, dest_path, force=force, dry_run=dry_run)

            else:
                # dest_path does not exist: creates a new symlink
                log_added(dest_path)
                if not dry_run:
                    dest_path.symlink_to(source_path.resolve())


def has_command(command: str) -> bool:
    """Invokes the commands and returns true if commands exists."""
    try:
        subprocess.run([command], check=False, capture_output=True)
    except FileNotFoundError:
        return False
    return True


def install_cargo():
    """Installs cargo."""

    with NamedTemporaryFile(delete_on_close=False) as fp:
        result = subprocess.run(
            ["curl", "-s", "-S", "-f", "https://sh.rustup.rs"],
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            fatal_error(f"failed to download cargo install script:\n{result.stderr}\n")
            fatal_error("failed to download cargo install script")
            sys.exit(1)
        else:
            fp.write(result.stdout)
            fp.close()


        with Progress(console=console) as progress:
            task = progress.add_task("[cyan]Installing cargo...", total=None)

            result = subprocess.run(
                ["sh", fp.name, "-q", "-y", "--no-modify-path"],
                capture_output=True,
                check=False,
            )
            if result.returncode != 0:
                progress.update(task, description="[bold red]Failed")
                fatal_error(f"failed to install cargo:\n{result.stderr}\n")
                fatal_error("failed to install cargo")
                sys.exit(1)
            else:
                progress.update(task, description="[green]cargo installation: Done!")


def _cargo_install(package: str, cargo_executable: Path) -> bool:
    """Run `cargo install --locked <package>`."""
    result = subprocess.run([cargo_executable, "install", "--locked", package], capture_output=True, check=False)
    if result.returncode != 0:
        error(f"{package}: installation failed")
        return False
    return True


def install_tools(dry_run: bool):
    """Install tools using install scripts located in `root`.

    Scripts are expected to be named as using this format: <number>_install-<tool_name>.sh.
    """

    if not has_command("cargo"):
        install_cargo()

    # Create full path to cargo executable and check it is actually here
    cargo_executable = Path.home() / ".cargo" / "bin" / "cargo"
    if not cargo_executable.is_file():
        fatal_error(f"cargo executable not found at {cargo_executable!s}")

    for tool in CARGO_TOOL_LIST:
        if dry_run:
            console.print("skipping...")
        else:
            with Progress(console=console) as progress:
                task = progress.add_task(f"[cyan]Installing {tool}...", total=None)
                success = _cargo_install(tool, cargo_executable)
                if success:
                    progress.update(task, description="[green]{tool}: Done!")
                else:
                    progress.update(task, description="[bold red]{tool}: Failed")


def main():
    config=parse_command_line()

    source_root=Path("home")
    dest_root=Path.home()

    if not dest_root.is_dir():
        fatal_error(f"{dest_root!s} is not a valid directory. Cannot setup dotfiles")
        sys.exit(1)

    if config.remove:
        header("== Removing symlinks =================================")
        remove_dotfiles(source_root, dest_root, config)
    else:
        header("== Symlink dotfiles ==================================")
        symlink_dotfiles(source_root, dest_root, config)

        header("== Installing tools ==================================")
        install_tools(config.dry_run)

    if config.dry_run:
        console.print()
        console.print("This was a dry run: nothing actually happened")


if __name__ == "__main__":
    main()

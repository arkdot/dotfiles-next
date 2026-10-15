#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["rich", "requests", "pydantic"]
# ///

"""Boostraps dotfiles.

Directories will be created, and files will be symlinked.
"""

from __future__ import annotations

import argparse
import json
import platform
import re
import subprocess
import sys
import tarfile
import tempfile
from collections.abc import Iterator, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from platform import uname_result
from typing import Annotated, Literal
from urllib.parse import urlparse

import requests
from pydantic import BaseModel, ConfigDict, Field, model_validator
from rich.console import Console
from rich.progress import Progress
from rich.prompt import Confirm

# Rich console for logging & prompting
console = Console(stderr=True, highlight=False)


@dataclass(frozen=True)
class SystemInfo:
    """Stores system informations (os, architecture...)."""

    _uname: uname_result = field(init=False, default_factory=platform.uname)

    @property
    def arch(self) -> str:
        return self._uname.machine

    @property
    def os(self) -> str:
        return self._uname.system.lower()

    @property
    def os_alias(self) -> str:
        if self.os == "darwin":
            return "macos"
        return self.os

    @property
    def vendor(self) -> str:
        if self.os == "darwin":
            return "apple"
        return "unknown"

    def asdict(self):
        return {key: getattr(self, key) for key in ("arch", "os", "os_alias", "vendor")}


SYSTEM = SystemInfo()

# == GitHub interactions ================================================================================


@dataclass
class GitHubRepo:
    GITHUB_API = "https://api.github.com"

    owner: str
    repo: str

    def __init__(self, homepage: str):
        """Initializes a GitHubRepo the repo home page.

        Args:
            homepage: github.com project url (https://github.com/<owner>/<repo>)

        Raises:
            ValueError: if url does not repect expected format
        """
        parsed = urlparse(homepage)

        if parsed.netloc != "github.com":
            raise ValueError("GitHubRepo home page url must start with github.com")

        tokens = parsed.path.split("/")[1:]
        if len(tokens) != 2:
            raise ValueError(f"Misformatted GitHub repository url: {homepage!s}")

        self.owner = tokens[0]
        self.repo = tokens[1]

    @property
    def release_url(self) -> str:
        return f"{self.GITHUB_API}/repos/{self.owner}/{self.repo}/releases"

    def get_release_list(self) -> list[GitHubRelease]:
        response = requests.get(self.release_url)
        response.raise_for_status()
        return [GitHubRelease.model_validate(item) for item in response.json()]

    def get_release(self, version: str) -> GitHubRelease:
        releases = self.get_release_list()
        if releases and version == "latest":
            return releases[0]
        by_version = {r.version: r for r in releases}
        if version not in by_version:
            raise ValueError(f"cannot find version {version!r} in release list")
        return by_version[version]


class GitHubAsset(BaseModel):
    browser_download_url: str
    name: str


class GitHubRelease(BaseModel):
    html_url: str
    tag_name: str
    assets: list[GitHubAsset]

    @property
    def version(self) -> str:
        match = re.match("v?(.*)", self.tag_name)
        if not match:
            raise ValueError(f"Cannot parse tag {self.tag_name!s}")
        return match.group(1)

    def get_asset(self, name: str) -> GitHubAsset:
        """Returns the asset with given name.

        Raises:
            ValueError: if the requested asset does not exist in the release.
        """
        assets = {asset.name: asset for asset in self.assets}
        if name not in assets:
            raise ValueError(
                f"Cannot find asset {name!r} in last release assets (see {self.html_url})"
            )
        return assets[name]


# == Tarball extraction =================================================================================
class FilterBase:
    """Filter base class for tar that can be chained.

    Stores members in `seen` the same member is not seen multiple time, which
    for some reason is the case if not taken care of.
    """

    def __init__(self):
        self._next: FilterBase | None = None

    def __call__(
        self, member: tarfile.TarInfo | None, path: Path
    ) -> tarfile.TarInfo | None:
        if self._next:
            member = self._next.__call__(member, path)
        return member

    def add(self, other: FilterBase) -> FilterBase:
        self._next = other
        return self

    def __exit__(self, *exc_info):
        pass


class StripComponentsFilter(FilterBase):
    def __init__(self, n: int = 1):
        super().__init__()
        self.n = n

    def __call__(
        self, member: tarfile.TarInfo | None, path: Path
    ) -> tarfile.TarInfo | None:
        if member and member.name != ".":
            parts = Path(member.name).parts
            assert len(parts) >= self.n
            member.name = str(Path(*parts[self.n :]))
            return super().__call__(member, path)
        return None


class CustomTargetsFilter(FilterBase):
    def __init__(self, targets: dict[str, str]):
        super().__init__()
        self.targets = {Path(source): Path(dest) for source, dest in targets.items()}

    def __call__(
        self, member: tarfile.TarInfo | None, path: Path
    ) -> tarfile.TarInfo | None:
        if member:
            path = Path(member.name)
            for target, dest_dir in self.targets.items():
                if path.is_relative_to(target):
                    member.name = str(dest_dir / path)
                    return super().__call__(member, path)
        return None


def download_tarball(
    url: str,
    target_dir: Path = Path(),
    strip_components: int = 0,
    targets: dict[str, str] | None = None,
):
    """Downloads and extracts a tarball to `target_dir`."""

    filter_func = StripComponentsFilter(strip_components)
    if targets:
        filter_func.add(CustomTargetsFilter(targets))

    # Not pretty.
    # Reasons are:
    #   1) using `extract_all(filter_func=...)` does crashes for some dubious reason.
    #   2) we have to get the list of all members and pass it to `extractall`
    #   3) we cannot do that by streaming the request into `tarfile.open`
    with tempfile.TemporaryFile() as fp:
        response = requests.get(url)
        response.raise_for_status()
        fp.write(response.content)
        fp.seek(0)

        with tarfile.open(fileobj=fp, mode="r:gz") as tarobj:
            members = [filter_func(m, Path()) for m in tarobj.getmembers()]
            members = [m for m in members if m is not None]
            tarobj.extractall(path=target_dir, members=members)


# =======================================================================================================


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


OSType = Literal["darwin", "linux", "*"]


class TarStrategy(StrictModel):
    """Install packages by downloading and uncompressing tarballs."""

    strategy: Literal["tar"]
    version: str
    url: str
    asset_name_format: dict[OSType, str]
    targets: dict[str, str] = Field(default_factory=dict)
    strip_components: int = 1

    @property
    def asset_name(self) -> str:
        d = SYSTEM.asdict()
        d["version"] = self.version
        key = "*" if "*" in self.asset_name_format else SYSTEM.os
        return self.asset_name_format[key].format(**d)

    @property
    def asset_url(self) -> str:
        return (
            GitHubRepo(self.url)
            .get_release(self.version)
            .get_asset(self.asset_name)
            .browser_download_url
        )

    def install(self, target_dir: Path):
        download_tarball(
            self.asset_url,
            target_dir,
            strip_components=self.strip_components,
            targets=self.targets,
        )


class CargoStrategy(StrictModel):
    """Install packages using `cargo install`."""

    strategy: Literal["cargo"]
    package: str

    def install(self, target_dir: Path):
        cargo_install(
            self.package, cargo_executable=Path.home() / ".cargo" / "bin" / "cargo"
        )


class ScriptStrategy(StrictModel):
    strategy: Literal["script"]
    script: Sequence[str]
    interpreter: str = "bash"

    def install(self, target_dir: Path):
        with tempfile.NamedTemporaryFile(mode="wt") as fp:
            fp.write("\n".join(self.script))
            fp.seek(0)

            subprocess.run(
                [self.interpreter, fp.name], check=True, capture_output=True, text=True
            )


InstallStrategy = Annotated[
    TarStrategy | CargoStrategy | ScriptStrategy, Field(discriminator="strategy")
]


class Package(BaseModel):
    """A program to install."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    name: str
    install: dict[OSType, InstallStrategy]
    executable: str = Field(default="")

    @model_validator(mode="before")
    @classmethod
    def set_default_executable(cls, data):
        if isinstance(data, dict) and "executable" not in data:
            data["executable"] = data["name"]
        return data

    def do_install(self, target_dir: Path):
        try:
            if "*" in self.install:
                self.install["*"].install(target_dir)
            else:
                self.install[SYSTEM.os].install(target_dir)
        except Exception as exc:
            error(f"Install failed: {exc!s}")
            return False
        return True


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


def log_added(path: Path):
    console.print(f"[bold green][+][/bold green] {path}")


def log_deleted(path: Path):
    console.print(f"[bold red][-][/bold red] {path}")


def log_modified(path: Path):
    console.print(f"[bold yellow][~][/bold yellow] {path}")


def iter_dotfiles(root: Path, dest_dir: Path) -> Iterator[tuple[Path, Path]]:
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
    result = subprocess.run(["which", command], check=False, capture_output=True)
    return result.returncode == 0


def cargo_install(package: str, cargo_executable: Path) -> bool:
    """Run `cargo install --locked <package>`."""
    result = subprocess.run(
        [cargo_executable, "install", "--locked", package],
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def install_tools(dry_run: bool, target_dir: Path):
    """Install tools listed in `packages.json`."""

    packages_list_path = Path("packages.json")
    if packages_list_path.exists():
        tools = [
            Package.model_validate(p)
            for p in json.loads(packages_list_path.read_text())
        ]

        for tool in tools:
            if dry_run or has_command(tool.executable):
                console.print(f"[cyan]==> {tool.name}: skipping")

            else:
                with Progress(console=console) as progress:
                    prefix = f"==> {tool.name}"
                    task = progress.add_task(
                        f"[cyan]{prefix}...", total=None
                    )
                    success = tool.do_install(target_dir)
                    if success:
                        progress.update(task, description=f"[green]{prefix}: Done!")
                    else:
                        progress.update(
                            task, description=f"[bold red]{prefix}: Failed"
                        )


def main():
    config = parse_command_line()

    source_root = Path("home")
    dest_root = Path.home()

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
        install_tools(config.dry_run, dest_root / ".local")

    if config.dry_run:
        console.print()
        console.print("This was a dry run: nothing actually happened")


if __name__ == "__main__":
    main()

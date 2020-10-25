from functools import partial
import os
from pathlib import Path
from typing import Generator, Iterable, Set, List

from ranger.api.commands import Command


class z(Command):
    """
    :z <patterns>

    Jump to a directory using fasd. Supports tab completion.
    """
    def execute(self) -> None:
        args = self.rest(1).split()
        if args:
            directories = self._get_directories(*args)
            if directories:
                self.fm.cd(directories[0])
            else:
                self.fm.notify("No results from fasd", bad=True)

    def tab(self, tabnum: int) -> Generator[str, None, None]:
        start, current = self.start(1), self.rest(1)
        for path in self._get_directories(*current.split()):
            yield start + path

    @staticmethod
    def _get_directories(*args) -> List[str]:
        import subprocess
        output = subprocess.check_output(["fasd", "-dl", *args], universal_newlines=True)
        dirs = output.strip().split("\n")
        dirs.sort(reverse=True)  # Listed in ascending frecency
        return dirs


# TODO make standalone script
class dot(Command):
    """
    :dot <pkg_name>

    Move files to the dotfiles package <pkg_name>.
    Files are either those tagged with `.` (entire tree),
    marked or currently selected.
    """
    BASE_DIR = Path("~").expanduser()
    DOTFILES_DIR = Path("~/dotfiles").expanduser()
    TAG = '.'

    def execute(self) -> None:
        pkg_name = self.arg(1)
        if not pkg_name:
            self.fm.notify("Missing package name", bad=True)
            return
        elif self.rest(2):
            self.fm.notify("Too many arguments", bad=True)
            return

        paths = self._collect_paths()
        try:
            rel_paths = tuple(sorted(p.relative_to(self.BASE_DIR) for p in paths))
        except ValueError as e:
            self.fm.notify(str(e), bad=True)
            return

        self._check_confirm_paths(pkg_name, rel_paths)

    def _check_confirm_paths(self, pkg_name: str, rel_paths: Iterable[Path]) -> None:
        self.fm.ui.console.ask(
            f"Add files to pkg {pkg_name!r}? [y/n] | {', '.join(map(str, rel_paths))}",
            partial(self._on_confirm_paths, pkg_name, rel_paths),
            ('y', 'n')
        )

    def _on_confirm_paths(self, pkg_name: str, rel_paths: Iterable[Path], answer: str) -> None:
        if answer.lower() == 'n':
            return

        if pkg_name not in self._pkg_names():
            self.fm.ui.console.ask(
                f"dotfile package {pkg_name!r} does not exist. Create? [y/n]",
                partial(self._on_confirm_pkg_name, pkg_name, rel_paths),
                ('y', 'n')
            )
        else:
            self._import_dotfiles(pkg_name, rel_paths)

    def _on_confirm_pkg_name(self, pkg_name: str, rel_paths: Iterable[Path], answer: str) -> None:
        if answer.lower() == 'y':
            self._import_dotfiles(pkg_name, rel_paths)

    def _import_dotfiles(self, pkg_name: str, rel_paths: Iterable[Path]) -> None:
        import os
        import shutil

        pkg_dir = self.DOTFILES_DIR / pkg_name

        src_paths = [self.BASE_DIR / p for p in rel_paths]
        dst_paths = [pkg_dir / p for p in rel_paths]
        existing_paths = [p for p in dst_paths if p.exists()]
        if existing_paths:
            self.fm.notify(f"Files already exist: {', '.join(map(str, existing_paths))}", bad=True)
            # TODO could ask to overwrite
            return

        for src, dst in zip(src_paths, dst_paths):
            rel_dst = os.path.relpath(dst, start=src.parent)
            try:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(src, dst)
            except Exception as e:
                self.fm.notify(f"Couldn't move {src!s} to {dst!s}", bad=True, exception=e)
                continue
            else:
                try:
                    src.symlink_to(rel_dst)
                except ValueError as e:
                    self.fm.notify(f"Couldn't symlink {src!s} to {dst!s}", bad=True, exception=e)

        # Cannot use tags.remove(*src_path)
        # because they could have been expanded earlier.
        # Instead, we erase all '.' tags.
        for path, tag in self.fm.tags.tags.items():
            if tag == self.TAG:
                self.fm.tags.remove(path)

        self.fm.ui.status.need_redraw = True
        self.fm.ui.need_redraw = True

    def _collect_paths(self) -> Set[Path]:
        files: Set[str] = set()
        if self.fm.tags:
            files = {p for p, tag in self.fm.tags.tags.items() if tag == self.TAG}

        if not files:
            files = {obj.path for obj in self.fm.thistab.get_selection()}

        # expand directories
        expanded_paths: Set[Path] = set()
        for fpath in files:
            path = Path(fpath)
            if path.is_dir():
                expanded_paths |= {p for p in path.rglob("*") if p.is_file()}
            else:
                expanded_paths.add(path)

        # filter symlinks
        filtered_paths = {p for p in expanded_paths if not p.is_symlink()}

        return filtered_paths

    def tab(self, tabnum: int) -> Generator[str, None, None]:
        start, current = self.start(1), self.rest(1)
        for name in sorted(self._pkg_names()):
            if name.startswith(current):
                yield start + name

    @classmethod
    def _pkg_names(cls) -> Generator[str, None, None]:
        yield from (p.name for p in cls.DOTFILES_DIR.iterdir() if p.is_dir())


class unlink(Command):
    """
    :unlink [<remove>]

    Replace a symlink with the thing it links to and optionally remove the original.
    """

    def execute(self):
        import shutil
        remove = bool(self.arg(1))

        fileobjs = self.fm.thistab.get_selection()
        paths = {Path(obj.path) for obj in fileobjs}
        for src in paths:
            if not src.is_symlink():
                continue
            try:
                dst = src.resolve(strict=True)
            except FileNotFoundError:
                self.fm.notify(f"Target of {src!s} does not exist", bad=True)
                continue
            src.unlink()
            if remove:
                shutil.move(dst, src)
            else:
                shutil.copy2(dst, src)


class aur_mark_new(Command):
    """
    :aur_mark_new

    Scan directory of seen aurutils repos and tag new packages.
    """
    def execute(self):
        seen_dir = (os.environ.get('XDG_DATA_HOME', os.path.expanduser("~/.local/share"))
                    + "/aurutils/view")
        dir_ = self.fm.thisdir
        dir_.load_content(schedule=False)  # force load content, so we can use .files
        dir_.mark_all(False)
        for f in dir_.files:
            if not os.path.exists(os.path.join(seen_dir, f.basename)):
                dir_.mark_item(f, True)  # f.mark()
            # dir_.mark_item(f, not os.path.exists(os.path.join(seen_dir, f.basename)))

        dir_.load_content()

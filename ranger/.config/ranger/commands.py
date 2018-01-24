from ranger.api.commands import Command


class z(Command):
    """
    :z <patterns>

    Jump to a directory using fasd.
    """
    def execute(self) -> None:
        args = self.rest(1).split()
        if args:
            import subprocess
            directory = subprocess.check_output(["fasd", "-dl", *args], universal_newlines=True).strip()
            if directory:
                self.fm.cd(directory)
            else:
                self.fm.notify("No results from fasd", bad=True)

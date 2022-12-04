import shlex
import subprocess
from pathlib import Path

import sublime
import sublime_plugin

from resumeback import send_self
import sublime_lib


class SearchTermsInputHandler(sublime_plugin.TextInputHandler):
    def placeholder(self):
        return "Search terms (-A)"


class OpenLocateCommand(sublime_plugin.WindowCommand):
    @send_self
    def run(self, this, *, search_terms="", terms=()):
        if not terms and search_terms:
            terms = shlex.split(search_terms)

        window = self.window
        yield sublime.set_timeout_async(this.send_wait, 0)  # Switch to async thread
        output = subprocess.check_output(["locate", "-A", *terms], text=True).strip()
        
        if len(options := output.splitlines()) == 1:
            path = options[0]
        else:
            path = yield sublime_lib.show_selection_panel(window, options, on_select=this.send)
        window.open_file(path)

    def input(self, search_terms=None, terms=()):
        if not terms and not search_terms:
            return SearchTermsInputHandler()

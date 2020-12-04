import sublime
import sublime_plugin

quotes = ['"', "'", '"""', "'''"]


class PythonPrintCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        sel = self.view.sel()
        regions = [reg if not reg.empty() else self.view.word(reg) for reg in sel]
        self.view.add_regions("old_sel", regions)

        # Apply in reverse to not mess up our previously saved regions
        # This is also necessary because we need to change the selection
        for reg in reversed(regions):
            selected_text = self.view.substr(reg)
            if not selected_text:
                continue
            for quote in quotes:
                if quote not in selected_text:
                    break
            text = f"\nprint(f{quote}{{{selected_text}=}}{quote})"
            # view.insert does not auto-indent, so we run the insert command
            # self.view.insert(edit, line.end(), text)
            sel.clear()
            line = self.view.line(reg)
            sel.add(sublime.Region(line.end(), line.end()))
            self.view.run_command('insert', {'characters': text})

        # Restore old selection (additionally, the expanded selection
        # if a selection was empty before)
        sel.clear()
        sel.add_all(self.view.get_regions("old_sel"))
        self.view.erase_regions("old_sel")

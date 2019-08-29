import sublime_plugin


class CycleGroupsCommand(sublime_plugin.WindowCommand):
    def run(self):
        w = self.window
        w.focus_group((w.active_group() + 1) % w.num_groups())

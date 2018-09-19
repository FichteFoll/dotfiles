import os

import sublime
import sublime_plugin


class RelinkResourceFileListener(sublime_plugin.EventListener):

    def on_post_save_async(self, view):
        path = view.file_name()
        if not path:
            return
        packages_path = sublime.packages_path()

        is_resource_file = path.startswith(packages_path)
        if is_resource_file and os.path.islink(path):
            self._relink(path)

    def _relink(self, path):
        link_path = os.readlink(path)
        print("relinking", path, link_path)
        os.remove(path)
        os.symlink(link_path, path)

import re
import os

import sublime
import sublime_plugin


class RelinkResourceFileListener(sublime_plugin.EventListener):

    def on_post_save_async(self, view):
        path = view.file_name()
        if not path:
            return
        packages_path = sublime.packages_path()
        merge_packages_path = re.sub(r"sublime-text(-3)?", "sublime-merge", packages_path)
        # TODO Windows/macOS

        is_resource_file = path.startswith(packages_path) or path.startswith(merge_packages_path)
        if is_resource_file and os.path.islink(path):
            self._relink(path)

    def _relink(self, path):
        link_path = os.readlink(path)
        print("relinking", path, link_path)
        os.remove(path)
        os.symlink(link_path, path)

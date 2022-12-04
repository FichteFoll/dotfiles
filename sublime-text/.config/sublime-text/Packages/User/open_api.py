# https://gist.github.com/OdatNurd/d74821a67ba6627d3f617cd4265bfb5d
import sublime
import sublime_plugin

import glob
import os


def get_plugin_files():
    """
    Return a list of all of the files that are used to provide the Sublime API;
    this covers files from all available plugin hosts, including those that
    may not have existed at the point where this plugin was created.
    """
    if hasattr(get_plugin_files, "files"):
        return get_plugin_files.files

    root = os.path.dirname(sublime.executable_path())

    if int(sublime.version()) >= 4000:
        lib_path = os.path.join(root, "Lib")

        host_dirs = [p for p in os.listdir(lib_path)
                     if os.path.isdir(os.path.join(lib_path, p))]

    else:
        lib_path = root
        host_dirs = [root]

    files = []
    for path in host_dirs:
        files.extend(glob.glob(os.path.join(lib_path, path, "*.py")))

    get_plugin_files.files = sorted(files)
    return get_plugin_files.files


class FileInputHandler(sublime_plugin.ListInputHandler):
    def placeholder(self):
        return "Select API file to open"

    def list_items(self):
        files = get_plugin_files()

        items = []
        for file in files:
            path, plugin = os.path.split(file)
            _, host = os.path.split(path)
            items.append(("%s - %s" % (host, plugin), file))

        return items


class OpenApiFilesCommand(sublime_plugin.WindowCommand):
    def run(self, file):
        view = self.window.open_file(file)
        view.settings().set("_make_read_only", True)

    def input(self, args):
        if "file" not in args:
            return FileInputHandler()


class ApiFileListener(sublime_plugin.ViewEventListener):
    @classmethod
    def is_applicable(cls, settings):
        return settings.get("_make_read_only", False)

    def on_load(self):
        self.view.set_read_only(True)
        self.view.settings().erase("_make_read_only")

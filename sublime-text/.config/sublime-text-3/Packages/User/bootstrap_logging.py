from functools import partial
from collections import defaultdict

import sublime

function_names = {
    'log_build_systems',
    'log_commands',
    'log_control_tree',
    'log_fps',
    'log_indexing',
    'log_input',
    'log_result_regex',
}

# Ensure this exists
if not hasattr(sublime, 'logging_cache'):
    setattr(sublime, 'logging_cache', defaultdict(bool))

# Collect original functions
original_functions = {name: getattr(sublime, name)
                      for name in function_names}


# Override functions with our new function
def toogle_logging(name, value=None):
    if value is None:
        value = not sublime.logging_cache[name]
    sublime.logging_cache[name] = value
    original_functions[name](value)


for name in function_names:
    setattr(sublime, name, partial(toogle_logging, name))

print("Note: sublime.log_* methods have been overridden and now toggle when "
      "called without a parameter")


def plugin_unloaded():
    for name, func in original_functions.items():
        setattr(sublime, "log_" + name, func)
    print("Note: Original functionality for sublime.log_* methods has been "
          "restored")

/*
 * vimfx configuration file
 *
 * Inspiration:
 *   https://github.com/akhodakivskiy/VimFx/wiki/Share-your-config-file
 *   https://github.com/azuwis/.vimfx/blob/master/config.js
 */

/* jshint esversion: 6 */

// imports
const {classes: Cc, interfaces: Ci, utils: Cu} = Components;
const nsIFile = () => Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
const nsIProcess = () => Cc["@mozilla.org/process/util;1"].createInstance(Ci.nsIProcess);
const {commands} = vimfx.modes.normal;

// constants
const MPV_PATH = "/usr/bin/env";
const MPV_OPTIONS = "mpv"; // space-separated

// setting overrides
vimfx.set('prevent_autofocus', true);

// helpers
function bind (shortcuts, command, custom=false) {
  vimfx.set(`${custom ? 'custom.' : ''}mode.normal.${command}`, shortcuts);
}

function addCommand (shortcuts, options, fn) {
  vimfx.addCommand(options, fn);
  bind(shortcuts, options.name, true);
}

// command rebinds
bind('M', 'mark_scroll_position');
bind('J', 'tab_select_next');
bind('K', 'tab_select_previous');

// custom commands
addCommand('m', {
  name: "open_mpv",
  description: "Open current page in mpv"
}, ({vim}) => {
  // const location = new vim.window.URL(vim.browser.currentURI.spec);
  // mpv(location.href);
  const url = vim.browser.currentURI.spec;
  mpv(url);
});

addCommand('em', {
  name: "follow_in_mpv",
  description: 'Open link in mpv',
}, (args) => {
  const {vim} = args;

  commands.follow_in_tab.run(
    Object.assign({}, args, {
      callbackOverride({type, href, timesLeft}) {
        if (type === 'link') {
          vim.notify(`mpv: ${href}`);
          mpv(href);
        }
        else { // shouldn't happen with `commands.follow_in_tab`
          vim.notify("mpv: can only operate on links!");
        }
        return (timesLeft > 1);
      },
    })
  );
});

addCommand('gs', {
    name: 'toggle_https',
    description: 'Toggle HTTPS',
    category: 'location',
}, ({vim}) => {
    const {gBrowser} = vim.window;
    const location = new vim.window.URL(gBrowser.currentURI.spec);
    if (location.protocol === "http:")
      location.protocol = "https:";
    else if (location.protocol === "https:")
      location.protocol = "http:";
    gBrowser.loadURI(location.href);
});

addCommand(',a', {
  name: 'goto_addons',
  description: 'Addons',
}, ({vim}) => {
  vim.window.BrowserOpenAddonsMgr();
});

addCommand(',c', {
  name: 'goto_config',
  description: 'Config',
}, ({vim}) => {
  vim.window.switchToTabHavingURI('about:config', true);
});

addCommand(',d', {
  name: 'goto_downloads',
  description: 'Downloads',
}, ({vim}) => {
  // vim.window.switchToTabHavingURI('about:downloads', true)
  vim.window.DownloadsPanel.showDownloadsHistory();
});

addCommand(',s', {
  name: 'goto_preferences',
  description: 'Preferences',
}, ({vim}) => {
  vim.window.openPreferences();
});

addCommand(',R', {
  name: 'restart',
  description: 'Restart',
}, ({vim}) => {
  Services.startup.quit(Services.startup.eRestart | Services.startup.eAttemptQuit);
});

addCommand('O', {
  name: 'focus_location_bar_unhighlighted',
  description: 'Focus the location bar with the URL unhighlighted',
  category: 'location',
  order: commands.focus_location_bar.order + 10,
}, (args) => {
  commands.focus_location_bar.run(args);
  let active = args.vim.window.document.activeElement;
  active.selectionStart = active.selectionEnd;
});

addCommand('gt', {
  name: 'search_tabs',
  description: 'Search tabs',
  category: 'tabs',
  order: commands.focus_location_bar.order + 20,
}, (args) => {
  let {vim} = args;
  let {gURLBar} = vim.window;
  gURLBar.value = '';
  commands.focus_location_bar.run(args);
  // `*` searches bookmarks,
  // `%` searches tabs
  gURLBar.value = '% ';
  gURLBar.onInput(new vim.window.KeyboardEvent('input'));
});

addCommand(',n', {
  name: 'noscript_click_toolbar_button',
  description: 'NoScript button',
}, ({vim}) => {
  vim.window.document.getElementById('noscript-tbb').click();
});

addCommand(',k', {
  name: 'keefox_click_toolbar_button',
  description: 'KeeFox button',
}, ({vim}) => {
  vim.window.document.getElementById('keefox-button').click();
});


const gClipboardHelper = Cc["@mozilla.org/widget/clipboardhelper;1"].getService(Ci.nsIClipboardHelper);

addCommand(',T', {
  name: 'touhou_titles',
  description: 'Fetch Touhou music titles',
}, ({vim}) => {
  vimfx.send(vim, "touhou_titles", null, (data) => {gClipboardHelper.copyString(data); console.log("copied");});
});

vimfx.addCommand({
  name: 'find_something_in_document',
  description: 'Test',
}, ({vim}) => {
  vimfx.send(vim, "query_selector_test");
});
vimfx.set("custom.mode.normal.find_something_in_document", ",t");


// more helpers
function mpv(url) {
  let args = MPV_OPTIONS.split(' ');

  // Parse YouTube playlist options
  if (url.includes('youtube.com/')) {
    // Parse url params to an object like:
    // {"v":"g04s2u30NfQ","index":"3","list":"PL58H4uS5fMRzmMC_SfMelnCoHgB8COa5r"}
    let qs = parse_query(url);
    console.log("qs:", qs);
    if (qs.list && qs.index) {
      // Append options if ytdl-raw-options already in `args`
      let ytdlRawOptionsIndex = -1;
      for (let i = 0; i < args.length; i++) {
        if (args[i].startsWith('--ytdl-raw-options=')) {
          ytdlRawOptionsIndex = i;
          args[ytdlRawOptionsIndex] += `,yes-playlist=`;
          break;
        }
      }
      if (ytdlRawOptionsIndex == -1) {
        args.push(`--ytdl-raw-options=yes-playlist=`);
      }
      args.push(`--playlist-pos=${qs.index - 1}`);
    }
  }

  args.push(url);
  exec(MPV_PATH, args);
}

function parse_query(url) {
  const j = url.indexOf('?');
  if (j == -1)
    return {};
  const a = url.substr(j + 1).split('&');
  if (a === '')
    return {};
  let b = {};
  for (let i = 0; i < a.length; ++i) {
    let p = a[i].split('=', 2);
    if (p.length == 1) {
      b[p[0]] = '';
    } else {
      b[p[0]] = decodeURIComponent(p[1].replace(/\+/g, ' '));
    }
  }
  return b;
}

function exec(cmd, args, observer) {
  console.log(`executing: '${cmd}' with arguments`, args);
  // https://developer.mozilla.org/en-US/docs/XPCOM_Interface_Reference/nsIProcess
  const file = nsIFile();
  file.initWithPath(cmd);
  const process = nsIProcess();
  process.init(file);
  process.runAsync(args, args.length, observer);
}

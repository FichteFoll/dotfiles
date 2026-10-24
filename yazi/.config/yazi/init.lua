require("zoxide"):setup {
  update_db = true,
}

require("full-border"):setup()

require("git"):setup {
  -- Order of status signs showing in the linemode
  order = 1500,
}

-- Define a partial class derived from YatlineConfig.
-- https://github.com/LuaLS/lua-language-server/pull/3024
--
---@class (partial) YatlineConfig.P: YatlineConfig
---@type YatlineConfig.P
local yatline_config = {
  style_a = {
    bg = "blue",
    fg = "black",
    bg_mode = {
      normal = "blue",
      select = "brightyellow",
      un_set = "brightred",
    },
  },
  style_c = { bg = "reset", fg = "brightwhite" },

  header_line = {
    left = {
      section_a = {
        { type = "line", name = "tabs" },
      },
      section_b = {},
      section_c = {
        { type = "coloreds", name = "count", params = { false, true } },
        -- add spacing for starship header
        { type = "string",   custom = true,  name = " " },
      },
    },
    right = {
      section_a = {
        { type = "string", custom = true, name = string.format("%s@%s", ya.user_name() or "", ya.host_name() or "") },
        -- { type = "string", custom = true, name = "yazi" },
      },
      section_b = {
      },
      section_c = {
        { type = "coloreds", custom = false,      name = "githead" },
        { type = "string",   name = "task_states" },
      },
    },
  },

  status_line = {
    left = {
      section_a = {
        { type = "string", name = "tab_mode" },
      },
      section_b = {
        { type = "coloreds", name = "permissions" },
        { type = "string",   name = "hovered_ownership" },
        { type = "string",   name = "modified_time" },
      },
      section_c = {
        { type = "string", name = "hovered_name" },
      },
    },
    right = {
      section_a = {
        { type = "string", name = "cursor_position" },
        { type = "string", name = "cursor_percentage" },
      },
      section_b = {
        { type = "coloreds", name = "count", params = { false, true } },
      },
      section_c = {
        { type = "string", name = "hovered_size" },
        -- { type = "coloreds", name = "count", params = { false, true } },
      },
    },
  },
}

require("yatline"):setup(yatline_config)

-- https://github.com/imsi32/yatline-githead.yazi
-- require("yatline-githead"):setup({
--     behind_remote_symbol = "↑",
--     ahead_remote_symbol = "↓",
-- })

function Yatline.string.get:modified_time()
  local h = cx.active.current.hovered
  if h and h.cha.mtime then
    return "M: " .. os.date("%Y-%m-%d %H:%M", h.cha.mtime // 1)
  end
  return ""
end

require("starship"):setup({
  config_file = "~/.config/yazi/starship.toml",
})

-- https://github.com/boydaihungst/pref-by-location.yazi
local pref_by_location = require("pref-by-location")
pref_by_location:setup({
  -- Hide "enable" and "disable" notifications.
  -- no_notify = false -- true|false (Optional)

  prefs = {
    -- location: String | Lua pattern (Required)
    --   - https://www.lua.org/manual/5.4/manual.html#6.4.1
    --   - To escape special characters in a string: `pref_by_location.is_literal_string`

    -- sort: {} (Optional) https://yazi-rs.github.io/docs/configuration/yazi#mgr.sort_by
    --   - extension: "none"|"mtime"|"btime"|"extension"|"alphabetical"|"natural"|"size"|"random", (Optional)
    --   - reverse: true|false (Optional)
    --   - dir_first: true|false (Optional)
    --   - translit: true|false (Optional)
    --   - sensitive: true|false (Optional)

    -- linemode: "none" |"size" |"btime" |"mtime" | "permissions" |"owner" (Optional)
    --   - https://yazi-rs.github.io/docs/configuration/yazi#mgr.linemode
    --   - Custom linemode also works.

    -- show_hidden: true|false (Optional) https://yazi-rs.github.io/docs/configuration/yazi#mgr.show_hidden

    -- Sort by birth time.
    { location = ".*/Downloads?",
      sort = { "btime", reverse = true, dir_first = true },
    },
    { location = ".*/Downloads/Telegram Desktop",
      sort = { "btime", reverse = true, dir_first = true },
    },
    { location = ".*/tmp",
      sort = { "btime", reverse = true, dir_first = true },
    },
    { location = ".*/[Ss]creenshots/mpv",
      sort = { "btime", reverse = true, dir_first = true },
    },
  },
})

require("relative-motions"):setup({
  show_numbers = "relative",
  show_motion = true,
})

require("close-and-restore-tab"):setup()

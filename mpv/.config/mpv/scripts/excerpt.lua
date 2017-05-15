-- excerpt.lua - Create excerpts of videos in mpv.
--
-- Version: 0.1.2
-- URL: https://github.com/FichteFoll/mpv-scripts
-- License: GPLv2
--
-- This script allows to create excerpts of a video that is played,
-- which will be done using mpv itself.
--
-- * press "Alt+i" to mark the begin of the range to excerpt
-- * press "Alt+o" to mark the end   of the range to excerpt
-- * press "Alt+x" to start the creation of the excerpt
--
-- Based on: https://github.com/lvml/mpv-plugin-excerpt/blob/master/excerpt.lua


-- Copyright (C) 2016 Lutz Vieweg <lvml@5t9.de>
-- Copyright (C) 2016 RiCON
-- Copyright (C) 2017 FichteFoll <fichtefoll2@googlemail.com>
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


utils = require 'mp.utils'
options = require 'mp.options'
msg = require 'mp.msg'

excerpt_begin = 0.0
excerpt_end   = mp.get_property_native("duration")
if excerpt_end == nil then
    excerpt_end = 0.0
end

-- set options by using --script-opts=excerpt-<option>=<value>
-- or creating lua-settings/excerpt.conf inside mpv config dir
-- by default, basedir is pwd if empty.
local o = {
    basedir = "",
    random_name = false,
    char_size = 4,  -- number of random characters
    container = "webm",
    profile = "", -- "auto" expands to "conv-to-<container>"
    -- milliseconds = true
}
options.read_options(o)


function makeString(l, seed)
    l = math.max(1, l)
    math.randomseed(seed)
    local all = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local s = {}
    for i = 1, l do
        r = math.random(#all)
        s[i] = string.sub(all, r, r)
    end
    return table.concat(s)
end

function secondsToTime(s, ms)
    local ms = (ms ~= nil and ms) or false
    local h = math.floor(s / (60 * 60))
    local m = math.floor((s / 60) % 60)
    local s = (ms == true and s % 60 or math.floor(s % 60))
    local format = "%02d:%02d:" .. (ms == true and "%06.3f" or "%02d")
    return string.format(format, h, m, s)
end

function secondsToFilenameTime(s, sep)
    local sep = sep or ":"
    local dur = mp.get_property('duration')
    -- local show_hours = (dur / (60 * 60)) >= 1
    local show_hours = true
    local h = math.floor(s / (60 * 60))
    local m = math.floor((s / 60) % 60)
    s = s%60
    if show_hours then
        return string.format("%02d%s%02d%s%02d", h, sep, m, sep, s)
    else
        return string.format("%02d%s%02d", m, sep, s)
    end
end

function excerpt_rangemessage()
    local duration = excerpt_end - excerpt_begin
    local message = ""
    message = message .. "begin=" .. secondsToTime(excerpt_begin) .. " "
    message = message .. "end=" .. secondsToTime(excerpt_end) .. " "
    message = message .. "duration=" .. string.format("%.3f", duration) .. "s"
    return message
end

function excerpt_rangeinfo()
    local message = excerpt_rangemessage()
    mp.msg.log("info", message)
    mp.osd_message(message, 5)
end

function excerpt_mark_begin_handler()
    pt = mp.get_property_native("playback-time")

    excerpt_begin = pt
    if excerpt_begin > excerpt_end then
        excerpt_end = excerpt_begin
    end

    excerpt_rangeinfo()
end

function excerpt_mark_end_handler()
    pt = mp.get_property_native("playback-time")

    excerpt_end = pt
    if excerpt_end < excerpt_begin then
        excerpt_begin = excerpt_end
    end

    excerpt_rangeinfo()
end

function excerpt_write_handler()
    if excerpt_begin == excerpt_end then
        message = "excerpt_write: not writing because begin == end == " .. excerpt_begin
        mp.osd_message(message, 3)
        return
    end

    -- determine file name
    local cwd, _ = utils.split_path(mp.get_property("path", '.'))
    if (cwd:find("://") ~= nil) then
        cwd = os.getenv('HOME')
    end
    local path = ""
    local screenshot_dir = mp.get_property('screenshot-directory', '')
    if (o.basedir == "") and (screenshot_dir ~= "") then
        path = screenshot_dir
    elseif (o.basedir == "") then
        path = cwd
    else
        path = o.basedir
    end
    path = string.gsub(path, '^(~)', os.getenv('HOME') or os.getenv("USERPROFILE") or "")
    mp.msg.debug('cwd: '..cwd..' path: '..path)
    local direntries = utils.readdir(path, "files")
    -- mp.msg.debug(direntries)
    local ftable = {}
    for i = 1, #direntries do
        -- mp.msg.log("info", "direntries[" .. i .. "] = " .. direntries[i])
        ftable[direntries[i]] = 1
    end

    local title = mp.get_property("media-title")
    title = title:gsub("%.%w%w%w?%w?$", "") -- remove extension (if it exists)
    local fname = ("%s [%s_%s]"):format(title,
                                        secondsToFilenameTime(excerpt_begin, "-"),
                                        secondsToFilenameTime(excerpt_end, "-"))
    fname = string.gsub(fname, "[:\\;*?/\"]", "_")

    -- assure we find a file that doesn't exist
    local f_suffix = ""
    for i=0, 999 do
        local f = ("%s%s.%s"):format(fname, f_suffix, o.container)
        if ftable[f] == nil then
            fname = f
            break
        end
        if random_name then
            f_suffix = makeString(o.char_size, excerpt_begin + excerpt_end + i)
        else
            f_suffix = ("%03d"):format(i)
        end
    end

    local srcname = mp.get_property_native("path")

    local rangemessage = excerpt_rangemessage()
    local log_message = rangemessage .. "\nwriting excerpt of source file '" .. srcname .. "'"
    log_message = log_message .. "\nto destination file '" .. utils.join_path(path, fname) .. "'"
    msg.info(log_message)
    mp.osd_message(rangemessage .. "\n\nstarting encode...", 10)

    local profile = nil
    if o.profile == "auto" then
        profile = "conv-to-"..o.container
    elseif o.profile ~= "" then
        profile = o.profile
    end

    t = {cancellable = false}
    t.args = {'mpv', srcname, '--quiet'}
    table.insert(t.args, '--start=+' .. excerpt_begin)
    table.insert(t.args, '--end=+' .. excerpt_end)
    if profile then
        table.insert(t.args, '--profile=' .. profile)
    end
    table.insert(t.args, '--o=' .. utils.join_path(cwd, fname))
    if (mp.get_property('edition') ~= nil) then
        table.insert(t.args, '--edition=' .. mp.get_property('edition'))
    end
    props = {'vid', 'aid', 'sid', 'mute', 'sub-visibility', 'ass-style-override', 'audio-delay', 'sub-delay'}
    for _, prop in pairs(props) do
        table.insert(t.args, '--'..prop..'='..mp.get_property(prop))
    end

    msg.info("Running: " .. utils.to_string(t.args))
    local res = utils.subprocess(t)
    if (res.status < 0) then
        mp.osd_message("encode failed")
        msg.warn("encode failed; captured stdout follows")
        msg.warn(res.stdout)
        return
    end

    mp.osd_message("encode complete")
    -- unfortunately mpv doesn't always exit with an error code despite errors
    -- and checking whether a file exists in lua is bothersome
    msg.info("encode complete; captured stdout follows")
    msg.info(res.stdout)


    -- set media title
    msg.debug("setting title property")
    local title = mp.get_property("media-title")
    title = ("%s [%s-%s]"):format(title,
                                  secondsToFilenameTime(excerpt_begin),
                                  secondsToFilenameTime(excerpt_end))

    cmd = {cancellable = false,
           args = {"mkvpropedit",
                   utils.join_path(cwd, fname),
                   "-s",
                   'title=' .. title}}
    local res = utils.subprocess(cmd)
    if (res.status < 0) then
        msg.warn("setting title property failed")
    end

    -- move to target dir
    msg.info(("moving: %s to %s"):format(utils.join_path(cwd, fname), utils.join_path(path, fname)))
    os.rename(utils.join_path(cwd, fname), utils.join_path(path, fname))

    mp.osd_message("Saved to " .. utils.join_path(path, fname), 5)
end

mp.add_key_binding("Alt+i", "excerpt_mark_begin", excerpt_mark_begin_handler)
mp.add_key_binding("Alt+o", "excerpt_mark_end", excerpt_mark_end_handler)
mp.add_key_binding("Alt+x", "excerpt_write", excerpt_write_handler)

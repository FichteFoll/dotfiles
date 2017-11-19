--[[
    A template script used for Automation 4 karaoke FXes with Aegisub
    You will want to call `register()` at the end of your script or whenever at least `script_name` is defined.

    Functions to be defined:

    *   init(subs, meta, styles) [optional]

        Called after all possibly existing previous fx lines have been deleted and the karaoke lines restored.
        Do whatever you like in here. Won't be called if `init` is nil.

        @subs
            The subs table passed by aegisub.

        @meta, @styles
            Results of karaskel.collect_head(subs, false).

    *   do_fx(subs, meta, styles, line, baseline)

        Called when is_parseble(line) returns `true`, i.e. when you should parse that line.
        The parsed line will be commented and its effect set to "karaoke" iff this function returns a value evaluating
        to `true`.

        @subs
            Same as for init().

        @meta, @styles
            Same as for init().

        @line
            This is the line source you will be using. You can do anything with it, it's in fact a table.copy of
            @baseline with its effect set to "fx" and layer to 2.

            Has a field named "_i" which defines the line's index in `subs` and a field named "_li" which counts up
            every time do_fx is called.

        @baseline
            The table representing the line.
            This is a REFERENCE, you need to table.copy() this before if you want to insert a new copy.
            The line itself should not be modified at all, e.g. when you plan to run this macro a few times.

            Also defines "_i" and "_li" (see @line).

    Variables to be defined (before calling `register()`):

    *   script_name


    Includes a variety of utility functions.

    By FichteFoll, last modified: 2015-12-23
]]

require("karaskel")
-- require("op_overloads")

-- ############################# handler funcs #################################

function macro_script_handler(subs)
    aegisub.progress.title("Apply "..script_name)

    script_handler(subs)

    aegisub.set_undo_point('"Apply '..script_name..'"')
end

function script_handler(subs)
    aegisub.progress.task("Getting header data...")
    local meta, styles = karaskel.collect_head(subs, false)

    -- undo the fx before parsing the karaoke data
    aegisub.progress.task("Removing old karaoke lines...")
    undo_fx(subs)

    aegisub.progress.task("Applying effect...")
    local i,  maxi = 1, #subs
    local li = 0

    if init then
        init(subs, meta, styles)
    end

    while i <= maxi do
        local l = subs[i]
        if aegisub.progress.is_cancelled() then
            if aegisub.cancel then aegisub.cancel() end
            return
        end

        aegisub.progress.task(("Applying effect (%d/%d)..."):format(i, maxi))
        aegisub.progress.set((i-1) / maxi * 100)

        if line_is_parseable(l) then
            -- karaskel.preproc_line(subs, meta, styles, l)

            li = li + 1
            l._li = li
            l._i = i

            -- prepare the to-be-copyied line
            local line = table.copy(l)
            line.effect = "fx"
            line.layer = 2

            if do_fx(subs, meta, styles, line, l) then
                l.comment = true
                l.effect = "karaoke"
            end
            subs[i] = l
        end

        i = i + 1
    end

    aegisub.progress.task("Finished!")
    aegisub.progress.set(100)
end


function undo_macro_script_handler(subs, ...)
    aegisub.progress.title("Undoing "..script_name)

    undo_fx(subs)

    aegisub.set_undo_point("\"Undo "..script_name.."\"")
end


function undo_fx(subs)
    aegisub.progress.task("Unapplying effect...")

    local  i,  maxi = 1, #subs
    local ai, maxai = i,  maxi
    while i <= maxi do
        if aegisub.progress.is_cancelled() then
            if aegisub.cancel then aegisub.cancel() end
            return
        end

        aegisub.progress.task(("Unapplying effect (%d/%d)..."):format(ai, maxai))
        aegisub.progress.set((ai-1) / maxai * 100)

        local l = subs[i]
        if (l.class == "dialogue" and not l.comment and l.effect == "fx") then
            subs.delete(i)
            maxi = maxi - 1
        else
            if (l.class == "dialogue" and l.comment and l.effect == "karaoke") then
                l.comment = false
                l.effect = ''
                subs[i] = l
            end

            i = i + 1
        end
    end
end


-- ############################### parsing funcs ###############################

function parse_syls(line)
    -- parse the line's syllables and add them to the `line._noblank` table
    -- requires you to call karaskel.preproc_line first
    line._noblank = {n = 0}
    for i = 1, line.kara.n do
        local syl = line.kara[i]
        if (syl.duration > 0 and syl.text_stripped ~= ''
                and syl.text_stripped ~= ' ' and syl.text_stripped ~= '　') then
            line._noblank.n = line._noblank.n + 1
            line._noblank[line._noblank.n] = syl
            syl.i = line._noblank.n
            syl._blank = false
        else
            syl._blank = true
        end
    end
end

function parse_style_colors(line, style)
    style = style or line.styleref
    line._c = {}
    line._a = {}
    for i, c, a in colors_from_style(style) do
        line._c[i] = c
        line._a[i] = a
    end
end

--[[Parse the color overrides on the line
    (assuming they are the only blocks before the {\k}-block)
    and add them to line._colors
    Lines should look like this:
    {\c&H8D566C&\2c&HC982AE&\3c&H1A0110&}{\t(720,720,\c&HFFFFFF&\2c&HA99E4F&\3c&H161501&)}
      {\t(1900,2900,\2c&HBCA2C6&\c&H605064&\3c&H0B0006&)}{\k24}sho{\k24}se{\k16}n ...
]]
function parse_line_colors(line)
    line._colors = {_all = ""}

    local colors_str, text = line.text:match("^(.-)({\\k.+)$")
    if not colors_str then
        -- we are probably in a "sub" block, just consume all the override blocks
        -- wat?
        colors_str = ""
        text = line.text:gsub("({.-})", function (override)
            colors_str = colors_str .. override
            return ""
        end)
    end
    if not colors_str then
        log("No match on line: %s\n", line.text)
    end

    if colors_str and #colors_str > 0 then
        -- collect color blocks
        for str in colors_str:gmatch("{(.-)}") do
            -- always assuming there is only one \t override tag each
            local start, stop, colors = str:match("\\t%((%d+),(%d+),(%S-)%)")
            if not colors then
                colors = str:match("\\t%((%S-)%)")
            end

            local block = {
                text   = str,
                start  = tonumber(start) or 0,
                stop   = tonumber(stop)  or (colors and line.duration or 0),
                colors = colors or str
            }

            if not colors then -- supposed to happen only once
                line._colors._base = block
            else
                table.insert(line._colors, block)
            end
            line._colors._all = line._colors._all .. str
        end

        -- log(repr(line._colors) .. "\n")
    end
end

-- ############################### helping funcs ###############################

-- Returns the selected color `i` (or the first one) at `timestamp` given a few override codes.
-- Does not check for validity anywhere
-- do not abuse. Returns nil if color `i` was not found.
function color_at(col, timestamp, i)
    i = i or "[1-4]"  -- match any color number in the pattern
    if i == 1 then
        i = "1?"  -- 1 can be omitted
    end

    function _ret(col)
        -- used to select the specified color "i"; nil if not found
        return col.colors:match("\\"..i.."c(&H%w+&)") or nil
    end

    local active, last
    -- iterate over override blocks for the currently active transition, consider only the last
    local start, stop
    for _, block in ipairs(col) do
        if (timestamp > block.start and timestamp < block.stop and _ret(block)) then
            active = block
        end
    end

    -- ... for the lastly active transition
    for _, block in ipairs(col) do
        if (timestamp > block.stop and _ret(block)) then
            last = block
        end
    end
    if not last then last = col._base; end

    if not active then
        return _ret(last) -- just return the last color
    end

    -- select the specified color
    local start, stop = _ret(last), _ret(active)

    -- either no color or no "new" color found
    if not stop then
        -- log("stcol: %s\n", last.colors)
        -- log("start: %s\n", start)
        return start or nil
    end

    -- interpolate the color
    local pct = (timestamp - active.start) * 1.0 / (active.stop - active.start)
    return interpolate_color(pct, start, stop)
end

-- Searches for \t-tag times and shifts them by `by`
function shift_ttags(str, by)
    return str:gsub("\\t%((%d+),(%d+)", function (start, stop)
        return ("\\t(%d,%d"):format(tostring(tonumber(start) - by),
                                    tostring(tonumber(stop)  - by))
    end)
end

-- Create a list of charsyls used in char templates
function get_charsyls(syl)
    local charsyls = {}
    local charsyl = table.copy(syl)

    local left = syl.left
    for c in unicode.chars(syl.text_stripped) do
        charsyl.text = c
        charsyl.text_stripped = c
        charsyl.text_spacestripped = c
        charsyl.prespace, charsyl.postspace = "", "" -- for whatever anyone might use these for
        charsyl.width = aegisub.text_extents(syl.style, c)
        charsyl.left = left
        charsyl.center = left + charsyl.width/2
        charsyl.right = left + charsyl.width
        charsyl.prespacewidth, charsyl.postspacewidth = 0, 0 -- whatever...
        left = left + charsyl.width

        table.insert(charsyls, table.copy(charsyl))
    end

    return charsyls
end

function repr(val, indent, visited, indent_level)
    indent_level = indent_level or 0
    indent = indent or ""
    visited = visited or {}

    local function apply_indent(str)
        if indent ~= "" then
            return str .. "\n" .. indent * indent_level
        end
        return str
    end

    if type(val) == "table" then
        if visited[val] then
            return "<recursive lookup>"
        end
        visited[val] = true

        local str = "{"
        indent_level = indent_level + 1
        for k, v in pairs(val) do
            str = apply_indent(str)
            str = str .. ("%s = %s, "):format(
                k,
                repr(v, indent, visited, indent_level)
            )
        end
        if #val > 0 then
            str = str:sub(1, -3) -- trim last ", "
        end
        indent_level = indent_level - 1
        str = apply_indent(str)
        return str .. "}"
    elseif type(val) == "string" then
        return ("%q"):format(val)
    else
        return tostring(val)
    end
end

function colors_from_style(style)
    local i = 0

    function enum_colors()
        i = i + 1
        if (i > 4) then
            return nil
        end

        -- i, color, alpha
        return i, color_from_style(style["color"..tostring(i)]), alpha_from_style(style["color"..tostring(i)])
    end

    return enum_colors, nil, nil
end

function strip_comments(str)
    return str:gsub("{.-}", "")
end

function xor(...)
    -- return the first parameter which evaluates to `true`
    args = {...}
    for v in args do
        if v then
            return v
        end
    end
    return args[#args] -- return the last element if none is true
end

function _if(test, a, b)
    return test and a or b
end

function line_is_parseable(l)
    return (l.class == "dialogue" and not l.comment)
        or (l.class == "dialogue" and     l.comment and l.effect == "karaoke")
end

function round(num, idp)
    local mult = 10^(idp or 0)
    if num >= 0 then
        return math.floor(num * mult + 0.5) / mult
    else
        return math.ceil(num * mult - 0.5) / mult
    end
end

function randomfloat(min, max)
    return math.random() * (max - min) + min
end

function randomprefix()
    return math.random(0,1) * 2 - 1
end

function randomrange(base, prefix)
    local factor = 1
    if prefix then
        factor = randomprefix()
    end
    local min, max = 0, 0
    if type(base) == 'table' then
        min = base.min
        max = base.max
    else
        max = base
    end
    return factor * math.random(min, max)
end

function string.concat(...)
    str = ""
    for _, elem in pairs{...} do
        -- there shouldn't be any nils here
        str = str .. tostring(elem)
    end
    return str
end

function string.startswith(self, piece)
    return string.sub(self, 1, string.len(piece)) == piece
end

function string.endswith(self, piece)
    return string.sub(self, -string.len(piece)) == piece
end


-- ############################### templater help funcs ############################

function ci_inc()
    if (lastsyl ~= basesyl) then
        sci = 0
        scin = _G.unicode.len(basesyl.text_stripped:gsub("%s",""))
        lastsyl = basesyl
    end
    if (sci == scin) then
        sci = 0
        ci = ci - scin
    end
    local clen = _G.unicode.len(syl.text_stripped:gsub("%s",""))
    sci = sci + clen
    ci = ci + clen
    return ""
end


-- ############################### validation funcs ############################

function macro_validation(subs)
    for i = 1, #subs do
        local l = subs[i]
        if line_is_parseable(l) then
            return true
        end
    end

    return false, "No parseable line found"
end

function undo_macro_validation(subs)
    for i = 1, #subs do
        local l = subs[i]
        if (l.class == "dialogue" and (
                (not l.comment and l.effect == "fx") or
                (    l.comment and l.effect == "karaoke") )) then
            return true
        end
    end

    return false, "No karaoke line found"
end

-- ############################## registering ##################################

function register()
    aegisub.register_macro("Apply "..script_name,
                           "Processing script as templater",
                           macro_script_handler,
                           macro_validation)
    -- should not be needed (for my setup at least, I have a separate macro which does this)
    -- aegisub.register_macro("Undo "..script_name, "Removing templated lines", undo_macro_script_handler, undo_macro_validation)
end

return {
    macro_script_handler = macro_script_handler,
    script_handler = script_handler,
    undo_macro_script_handler = undo_macro_script_handler,
    undo_fx = undo_fx,
    parse_syls = parse_syls,
    parse_style_colors = parse_style_colors,
    parse_line_colors = parse_line_colors,
    color_at = color_at,
    shift_ttags = shift_ttags,
    get_charsyls = get_charsyls,
    repr = repr,
    colors_from_style = colors_from_style,
    strip_comments = strip_comments,
    xor = xor,
    _if = _if,
    line_is_parseable = line_is_parseable,
    round = round,
    randomfloat = randomfloat,
    randomprefix = randomprefix,
    randomrange = randomrange,
    -- string.concat = string.concat,
    -- string.startswith = string.startswith,
    -- string.endswith = string.endswith,
    register = register
}

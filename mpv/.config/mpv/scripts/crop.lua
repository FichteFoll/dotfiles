local assdraw = require 'mp.assdraw'
local needs_drawing = false
local dimensions_changed = false
local crop_first_corner = nil -- in video space

function get_video_dimensions()
    if not dimensions_changed then
        return _video_dimensions
    end
    -- this function is very much ripped from video/out/aspect.c in mpv's source
    local video_params = mp.get_property_native("video-out-params")
    if not video_params then
        return nil
    end
    dimensions_changed = false
    local keep_aspect = mp.get_property_bool("keepaspect")
    local w = video_params["w"]
    local h = video_params["h"]
    local dw = video_params["dw"]
    local dh = video_params["dh"]
    if mp.get_property_number("video-rotate") % 180 == 90 then
        w, h = h,w
        dw, dh = dh, dw
    end
    _video_dimensions = {}
    if keep_aspect then
        local unscaled = mp.get_property_native("video-unscaled")
        local panscan = mp.get_property_number("panscan")
        local window_w, window_h = mp.get_osd_size()

        local fwidth = window_w
        local fheight = math.floor(window_w / dw * dh)
        if fheight > window_h or fheight < h then
            local tmpw = math.floor(window_h / dh * dw)
            if tmpw <= window_w then
                fheight = window_h
                fwidth = tmpw
            end
        end
        local vo_panscan_area = window_h - fheight
        local f_w = fwidth / fheight
        local f_h = 1
        if vo_panscan_area == 0 then
            vo_panscan_area = window_h - fwidth
            f_w = 1
            f_h = fheight / fwidth
        end
        if unscaled or unscaled == "downscale-big" then
            vo_panscan_area = 0
            if unscaled or (dw <= window_w and dh <= window_h) then
                fwidth = dw
                fheight = dh
            end
        end

        local scaled_width = fwidth + math.floor(vo_panscan_area * panscan * f_w)
        local scaled_height = fheight + math.floor(vo_panscan_area * panscan * f_h)

        local split_scaling = function (dst_size, scaled_src_size, zoom, align, pan)
            scaled_src_size = math.floor(scaled_src_size * 2 ^ zoom)
            align = (align + 1) / 2
            local dst_start = math.floor((dst_size - scaled_src_size) * align + pan * scaled_src_size)
            if dst_start < 0 then
                --account for C int cast truncating as opposed to flooring
                dst_start = dst_start + 1
            end
            local dst_end = dst_start + scaled_src_size;
            if dst_start >= dst_end then
                dst_start = 0
                dst_end = 1
            end
            return dst_start, dst_end
        end
        local zoom = mp.get_property_number("video-zoom")

        local align_x = mp.get_property_number("video-align-x")
        local pan_x = mp.get_property_number("video-pan-x")
        _video_dimensions.x1, _video_dimensions.x2 = split_scaling(window_w, scaled_width, zoom, align_x, pan_x)

        local align_y = mp.get_property_number("video-align-y")
        local pan_y = mp.get_property_number("video-pan-y")
        _video_dimensions.y1, _video_dimensions.y2 = split_scaling(window_h,  scaled_height, zoom, align_y, pan_y)
    else
        _video_dimensions.x1 = 0
        _video_dimensions.x2 = window_w
        _video_dimensions.y1 = 0
        _video_dimensions.y2 = window_h
    end
    _video_dimensions.rw = w / (_video_dimensions.x2 - _video_dimensions.x1)
    _video_dimensions.rh = h / (_video_dimensions.y2 - _video_dimensions.y1)
    return _video_dimensions
end

function sort_corners(c1, c2)
    local r1, r2 = {}, {}
    if c1.x < c2.x then r1.x, r2.x = c1.x, c2.x else r1.x, r2.x = c2.x, c1.x end
    if c1.y < c2.y then r1.y, r2.y = c1.y, c2.y else r1.y, r2.y = c2.y, c1.y end
    return r1, r2
end

function clamp(low, value, high)
    if value <= low then
        return low
    elseif value >= high then
        return high
    else
        return value
    end
end

function clamp_to_screen(point, video_dim)
    return {
        x = clamp(video_dim.x1, point.x, video_dim.x2),
        y = clamp(video_dim.y1, point.y, video_dim.y2)
    }
end

function screen_to_video(point, video_dim)
    return {
        x = math.floor(video_dim.rw * (point.x - video_dim.x1) + 0.5),
        y = math.floor(video_dim.rh * (point.y - video_dim.y1) + 0.5)
    }
end

function video_to_screen(point, video_dim)
    return {
        x = math.floor(point.x / video_dim.rw + video_dim.x1 + 0.5),
        y = math.floor(point.y / video_dim.rh + video_dim.y1 + 0.5)
    }
end

function draw_shade(ass, top_left_corner, bottom_right_corner, video_dim)
    ass:new_event()
    ass:pos(0, 0)
    ass:append('{\\bord0}')
    ass:append('{\\shad0}')
    ass:append('{\\c&H000000&}')
    ass:append('{\\alpha&H77}')
    local c1, c2 = top_left_corner, bottom_right_corner
    local v = video_dim
    --   v.x1   c1.x   c2.x  v.x2
    -- v.y1+-----+------------+
    --     |     |     ur     |
    -- c1.y| ul  +-------+----+
    --     |     |       |    |
    -- c2.y+-----+-------+ lr |
    --     |     ll      |    |
    -- v.y2+-------------+----+
    ass:draw_start()
    ass:rect_cw(v.x1, v.y1, c1.x, c2.y) -- ul
    ass:rect_cw(c1.x, v.y1, v.x2, c1.y) -- ur
    ass:rect_cw(v.x1, c2.y, c2.x, v.y2) -- ll
    ass:rect_cw(c2.x, c1.y, v.x2, v.y2) -- lr
    ass:draw_stop()
    -- also possible to draw a rect over the whole video
    -- and \iclip it in the middle, but seemingy slower
end

function draw_crosshair(ass, center, window_size)
    ass:new_event()
    ass:append('{\\bord0}')
    ass:append('{\\shad0}')
    ass:append('{\\c&HBBBBBB&}')
    ass:append('{\\alpha&H00&}')
    ass:pos(0, 0)
    ass:draw_start()
    ass:rect_cw(center.x - 0.5, 0, center.x + 0.5, window_size.h)
    ass:rect_cw(0, center.y - 0.5, window_size.w, center.y + 0.5)
    ass:draw_stop()
end

function draw_position_text(ass, text, position, window_size, offset)
    ass:new_event()
    local align = 1
    local ofx = 1
    local ofy = -1
    if position.x > window_size.w / 2 then
        align = align + 2
        ofx = -1
    end
    if position.y < window_size.h / 2 then
        align = align + 6
        ofy = 1
    end
    ass:append('{\\an'..align..'}')
    ass:append('{\\fs26}')
    ass:append('{\\bord1.5}')
    ass:pos(ofx*offset + position.x, ofy*offset + position.y)
    ass:append(text)
end

function draw_crop_zone()
    if needs_drawing then
        local cursor_pos = {}
        local video_dim = get_video_dimensions()
        if not video_dim then
            cancel_crop()
            return
        end
        cursor_pos.x, cursor_pos.y = mp.get_mouse_pos()
        cursor_pos = clamp_to_screen(cursor_pos, video_dim)
        local ass = assdraw.ass_new()

        if crop_first_corner then
            local first_corner = video_to_screen(crop_first_corner, video_dim)
            local c1, c2 = sort_corners(first_corner, cursor_pos)
            draw_shade(ass, c1, c2, video_dim)
        end

        local window_size = {}
        window_size.w, window_size.h = mp.get_osd_size()
        draw_crosshair(ass, cursor_pos, window_size)

        cursor_video = screen_to_video(cursor_pos, video_dim)
        local text = string.format("%d, %d", cursor_video.x, cursor_video.y)
        if crop_first_corner then
            text = string.format("%s (%dx%d)", text,
                math.abs(cursor_video.x - crop_first_corner.x),
                math.abs(cursor_video.y - crop_first_corner.y)
            )
        end
        draw_position_text(ass, text, cursor_pos, window_size, 6)

        mp.set_osd_ass(window_size.w, window_size.h, ass.text)
        needs_drawing = false
    end
end

function crop_video(x, y, w, h)
    local vf_table = mp.get_property_native("vf")
    vf_table[#vf_table + 1] = {
        name="crop",
        params= {
            x = tostring(x),
            y = tostring(y),
            w = tostring(w),
            h = tostring(h)
        }
    }
    mp.set_property_native("vf", vf_table)
end

function update_crop_zone_state()
    local dim = get_video_dimensions()
    if not dim then
        cancel_crop()
        return
    end
    local second_corner = {}
    second_corner.x, second_corner.y = mp.get_mouse_pos()
    second_corner = clamp_to_screen(second_corner, dim)
    second_corner = screen_to_video(second_corner, dim)
    if crop_first_corner == nil then
        crop_first_corner = second_corner
    else
        local c1, c2 = sort_corners(crop_first_corner, second_corner)
        crop_video(c1.x, c1.y, c2.x - c1.x, c2.y - c1.y)
        cancel_crop()
    end
end

function reset_crop()
    dimensions_changed = true
    needs_drawing = true
end

function start_crop()
    if not mp.get_property("path") or mp.get_property("video") == "no" then return end
    needs_drawing = true
    dimensions_changed = true
    mp.add_forced_key_binding("mouse_move", "crop-mouse-moved", function() needs_drawing = true end)
    mp.add_forced_key_binding("MOUSE_BTN0", "crop-mouse-click", update_crop_zone_state)
    mp.add_forced_key_binding("ESC", "crop-esc", cancel_crop)
    local properties = {
        "keepaspect",
        "video-out-params",
        "video-unscaled",
        "panscan",
        "video-zoom",
        "video-align-x",
        "video-pan-x",
        "video-align-y",
        "video-pan-y",
        "osd-width",
        "osd-height",
    }
    for _, p in ipairs(properties) do
        mp.observe_property(p, "native", reset_crop)
    end
end

function cancel_crop()
    needs_drawing = false
    crop_first_corner = nil
    mp.remove_key_binding("crop-mouse-moved")
    mp.remove_key_binding("crop-mouse-click")
    mp.remove_key_binding("crop-esc")
    mp.unobserve_property(reset_crop)
    mp.set_osd_ass(1280, 720, '')
end

mp.register_idle(draw_crop_zone)
mp.add_key_binding(nil, "start-crop", start_crop)

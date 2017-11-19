-- made by FichteFoll


script_name = "Unapply karaoke template"
script_description = "Reverse standard karaoke templater"
script_author = "FichteFoll"
script_version = 1.0

-- loaded, fx_utils = xpcall(require, debug.traceback, "FX_utils")

-- ############################# funcs ##############################


function unapply_template_macro(subs)
	aegisub.progress.title(script_name);
	unapply_template(subs)
	aegisub.set_undo_point(script_name)
end

function unapply_template(subs)
	aegisub.progress.task("Unapplying effect...")

	local  i,  maxi = 1, #subs
	local ai, maxai = i,  maxi
	while i <= maxi do
		if aegisub.progress.is_cancelled() then
			if aegisub.cancel then aegisub.cancel() end
			return
		end

		aegisub.progress.task(string.format("Unapplying effect (%d/%d)...", ai, maxai))
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

function unapply_template_validation(subs)
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

aegisub.register_macro(script_name, "Unapplies standard karaoke templater", unapply_template_macro, unapply_template_validation)

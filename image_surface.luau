--!strict
-- Transparent image viewport. Keep the last loaded image during a CDN wait.
return function(zeron: any, model: any)
	return ui.component(function(): Node
		local function fit(): string return if zeron.setting("aspect"):get() ~= false then "contain" else "cover" end
		return ui.div {
			id = "nekos-image-surface", w_full = true, h_full = true, min_h = 0, overflow = "hidden",
			ui.presence(function()
				local image = model.current()
				if not image or not model.allowed() then return "" end
				local protected = model.concealed()
				if protected and zeron.setting("hide_nsfw"):get() ~= false then return "" end
				return image.url .. (if protected then ":blur" else ":plain")
			end, function(key: string): Node
				local image = model.current()
				if key == "" or not image then return ui.div {} end
				return ui.image {
					id = "nekos-current-image",
					src = image.url, w_full = true, h_full = true, label = "Anime image",
					blur = if model.concealed() then 28 else 0, fit = fit,
					on_load = function() model.loaded(image.url) end,
					on_error = function() model.failed(image.url) end,
					fallback = ui.presence(function()
						local previous = model.previous()
						return if previous then previous.url else ""
					end, function(url: string): Node
						return if url == "" then ui.div {} else ui.image { src = url, label = "Previous loaded image", w_full = true, h_full = true, fit = fit }
					end, {w_full=true,h_full=true}),
				}
			end, { w_full = true, h_full = true }),
		}
	end)
end

--!strict
-- Zeron owns the panel tabs and divider. This content is only the image.
return function(zeron: any, model: any)
	return ui.component(function(): Node
		local visibility = model.attach()
		return ui.div {
			id = "nekos-native-image", w_full = true, h_full = true, min_h = 0,
			bg = "$surface.sunken", overflow = "hidden", on_visible = visibility,
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
					src = image.url, w_full = true, h_full = true,
					label = "Anime image", blur = if model.concealed() then 28 else 0,
					fit = function() return if zeron.setting("aspect"):get() ~= false then "contain" else "cover" end,
					on_load = function() model.loaded(image.url) end,
					on_error = function() model.failed(image.url) end,
				}
			end, { w_full = true, h_full = true }),
		}
	end)
end

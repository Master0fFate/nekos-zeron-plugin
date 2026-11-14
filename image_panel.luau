--!strict
local Button = require("@ds/button")
local Text = require("@ds/text")
local Icon = require("@ds/icon")

return function(zeron: any, model: any, Gallery: any?, open_settings: (() -> ())?)
	local Surface = require("./image_surface")(zeron, model)
	local settings = open_settings or function() end
	return ui.component(function(): Node
		local visibility = model.attach()
		local function action(label: string, icon: string?, run: () -> (), disabled: (() -> boolean)?): Node
			local compact = icon ~= nil and label ~= "Refresh"
			return Button {label=label,tooltip=label,size="xs",tone="ghost",icon=compact,on_click=run,disabled=disabled,
				if icon then Icon {name=icon,size=14} else nil,if compact then nil else label}
		end
		return ui.column {
			id = "nekos-native-image", w_full = true, h_full = true, min_h = 0, overflow = "hidden", on_visible = visibility,
			-- No background fill: letterboxing uses the host panel's own surface.
			ui.column {w_full=true,shrink=0,px="$space.2",py="$space.2",gap="$space.1",
				ui.row {w_full=true,items="center",gap="$space.1",flex_wrap=true,
					action("Refresh", "refresh", function() model.command("refresh") end, function() return model.state.loading:get() or model.state.cooling:get() end),
					action("Previous", "alt-arrow-left", function() model.command("previous") end, function() return model.current()==nil end),
					action("Next", "alt-arrow-right", function() model.command("next") end, function() return model.current()==nil end),
					Button {function() return if model.autoplay:get() then "Pause" else "Play" end,label="Play or pause slideshow",size="xs",tone="ghost",on_click=function() model.command("play") end},
					action("Settings", "settings", settings),
				},
				ui.row {w_full=true,items="center",gap="$space.2",
					Text {function() return model.message:get() end,id="nekos-panel-status",style="caption",tone="secondary",wrap=true,grow=1,min_w=0},
					ui.show(function() return model.concealed() end,action("Reveal",nil,function() model.command("reveal") end)),
				},
			},
			ui.div {w_full=true,h=1,shrink=0,bg="$border.subtle"},
			ui.div {w_full=true,grow=1,min_h=0,
				ui.presence(function() return if Gallery and zeron.setting("mode"):get() == "gallery" then "gallery" else "single" end,
				function(mode): Node return if mode == "gallery" then Gallery {embedded=true} else Surface {} end,
				{w_full=true,h_full=true}),
			},
			ui.show(function() return zeron.setting("mode"):get() ~= "gallery" and zeron.setting("metadata"):get() ~= false and model.current() ~= nil and not model.concealed() end,
				ui.column {w_full=true,shrink=0,p="$space.2",gap="$space.1",
					Text {function()
						local image=model.current(); if not image then return "" end
						return image.rating .. (if image.artist then " · " .. image.artist else "")
					end,id="nekos-panel-metadata",style="caption",tone="secondary",literal=true,wrap=true},
					Text {function() local image=model.current(); return if image then table.concat(image.tags,", ") else "" end,style="caption",tone="secondary",literal=true,truncate=true},
					ui.show(function() local image=model.current(); return image~=nil and image.source~=nil end,
						action("Source",nil,function() local image=model.current(); if image and image.source and model.allowed() and not model.concealed() then zeron.open_url(image.source) end end)),
				}),
		}
	end)
end

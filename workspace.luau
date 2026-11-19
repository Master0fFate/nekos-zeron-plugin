--!strict
local Tabs = require("@ds/tabs")
local Button = require("@ds/button")

return function(Gallery: any, Panel: any, tab: any)
	return function(props: { close: (() -> ())? }): Node
		return ui.column {
			w_full = true, h_full = true, min_h = 0,
			ui.row {
				w_full = true, px = "$space.5", pt = "$space.2", shrink = 0,
				Tabs {
					value = tab, label = "Nekos views", rule = true,
					options = { { value = "panel", label = "Image controls" }, { value = "gallery", label = "Gallery" } },
					trail = if props.close then Button { "Close", label = "Close panel", size = "sm", tone = "ghost", on_click = props.close } else nil,
				},
			},
			ui.div {
				w_full = true, grow = 1, min_h = 0,
				ui.presence(function() return tab:get() end, function(view)
					return if view == "gallery" then Gallery { close = props.close } else Panel()
				end, { w_full = true, h_full = true }),
			},
		}
	end
end

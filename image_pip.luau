--!strict
local Button = require("@ds/button")
local Text = require("@ds/text")
local Icon = require("@ds/icon")
local geometry = require("./pip_geometry")

type Point = geometry.Point
type Frame = geometry.Frame

return function(zeron: any, model: any, open_settings: () -> ())
	local Surface = require("./image_surface")(zeron, model)
	local frame = ui.state("nekos_pip_frame", nil :: Frame?)
	local bounds = ui.computed(function(): Frame
		return geometry.fit(ui.window.size:get(), frame:get())
	end)

	local Player = ui.component(function(): Node
		local visible = model.attach()
		local start: { pointer: Point, frame: Frame }? = nil
		local function begin(e: Point)
			start = { pointer = { x = e.x, y = e.y }, frame = bounds:peek() }
		end
		local function finish() start = nil end
		local function move(e: Point)
			if not start then return end
			local origin = start.frame
			frame:set({ x = origin.x + e.x - start.pointer.x, y = origin.y + e.y - start.pointer.y, w = origin.w, h = origin.h })
		end
		local function resize(e: Point)
			if not start then return end
			frame:set(geometry.resize(ui.window.size:peek(), start.frame, e.x - start.pointer.x, e.y - start.pointer.y))
		end
		local function action(label: string, icon: string, run: () -> (), disabled: (() -> boolean)?): Node
			return Button { label = label, tooltip = label, size = "xs", tone = "ghost", icon = true,
				on_click = run, disabled = disabled, Icon { name = icon, size = 14 } }
		end
		local function no_image(): boolean return model.current() == nil end
		local function busy(): boolean return model.state.loading:get() or model.state.cooling:get() end
		return ui.column {
			id = "nekos-image-pip", label = "Nekos Picture-in-Picture",
			x = function() return bounds:get().x end, y = function() return bounds:get().y end,
			w = function() return bounds:get().w end, h = function() return bounds:get().h end,
			bg = "$background", rounded = "$radius.lg", border = 1, border_color = "$border.subtle",
			shadow = { y = 4, blur = 16, color = "#00000055" },
			overflow = "hidden", on_visible = visible,
			ui.row { h = 32, shrink = 0, px = 4, items = "center",
				ui.row { id = "nekos-pip-drag", h_full = true, grow = 1, min_w = 0, items = "center", px = 4,
					cursor = "grab", on_press = begin, on_pointer_move = move, on_release = finish,
					Text { "Nekos", style = "caption", truncate = true },
				},
				action("Close PiP", "close", model.close),
			},
			ui.div { w_full = true, grow = 1, min_h = 0, Surface {} },
			ui.row { w_full = true, h = 30, shrink = 0, items = "center", px = 4,
				action("Refresh", "refresh", function() model.command("refresh") end, busy),
				action("Previous", "alt-arrow-left", function() model.command("previous") end, no_image),
				Button { function() return if model.autoplay:get() then "Pause" else "Play" end,
					label = "Play or pause slideshow", size = "xs", tone = "ghost", on_click = function() model.command("play") end },
				action("Next", "alt-arrow-right", function() model.command("next") end, no_image),
				action("Settings", "settings", open_settings),
				ui.div { grow = 1, min_w = 0 },
				ui.row { id = "nekos-pip-resize", w = 20, h_full = true, items = "center", justify = "center",
					label = "Resize PiP", cursor = "nwse-resize", on_press = begin, on_pointer_move = resize, on_release = finish,
					Icon { name = "expand-arrows", size = 12 },
				},
			},
			ui.row { shrink = 0, w_full = true, items = "center", px = 8, pb = 4, gap = 4,
				Text { function() return model.message:get() end, id = "nekos-pip-status", style = "caption", tone = "secondary", truncate = true, grow = 1, min_w = 0 },
				ui.show(model.concealed, Button { "Reveal", size = "xs", tone = "secondary", on_click = function() model.command("reveal") end }),
			},
			ui.show(function()
				return bounds:get().h >= 240 and zeron.setting("metadata"):get() ~= false and model.current() ~= nil and not model.concealed()
			end, Text { function()
				local image = model.current()
				return if image then image.rating .. (if image.artist then " · " .. image.artist else "") else ""
			end, id = "nekos-pip-metadata", style = "caption", tone = "secondary", literal = true, truncate = true, px = 8, pb = 4 }),
		}
	end)

	return function(): Node
		return ui.presence(function() return if model.pip_open:get() then "open" else "closed" end, function(mode: string): Node
			if mode == "closed" then return ui.div { w = 0, h = 0 } end
			return ui.layer { placement = { x = "start", y = "start", inset = 0 }, Player {} }
		end)
	end
end

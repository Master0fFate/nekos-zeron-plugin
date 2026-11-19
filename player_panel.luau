--!strict
local Settings = require("@ds/settings")
local Button = require("@ds/button")
local Switch = require("@ds/switch")
local Stepper = require("@ds/stepper")
local Text = require("@ds/text")

return function(zeron: any, player: any, exporter: any, open_settings: () -> ())
	return function(): Node
		local function command(label: string, action: string): Node
			return Button {
				label, label = label, size = "sm", tone = "ghost",
				disabled = function()
					return if action == "refresh" then player.state.loading:get() or player.state.cooling:get() else player.current() == nil
				end,
				on_click = function() player.command(action) end,
			}
		end
		local function current()
			return if player.allowed() and not player.concealed() then player.current() else nil
		end
		local function action(label: string, callback: () -> ()): Node
			return Button { label, label = label, size = "sm", tone = "ghost", disabled = function() return current() == nil or exporter.busy:get() end, on_click = callback }
		end
		return ui.scroll {
			id = "nekos-panel-controls", w_full = true, h_full = true,
			ui.column {
				w_full = true, items = "center", p = "$space.6",
				Settings.Page {
					title = "Image controls",
					description = "Playback, filters, and image actions.",
					trail_top = true,
					trail = Button { "Open PiP", label = "Open image PiP", size = "sm", tone = "primary", on_click = player.open },
					Settings.Section {
						title = "Playback",
						Settings.Group {
							Settings.Row { label = "Slideshow", description = "Off keeps the current image on screen.", control = Switch { value = player.autoplay, label = "Slideshow", on_change = player.changed } },
							Settings.Row { label = "Change image every", description = "Images play in order, then repeat.", control = Stepper { value = player.interval, min = 1, max = 3600, unit = "s", name = "Slideshow interval", size = "sm", on_change = player.changed } },
							Settings.Row { label = "Current image", description = function() return player.message:get() end, control = ui.row { gap = "$space.1", command("Previous", "previous"), command("Next", "next"), command("Refresh", "refresh") } },
						},
						ui.show(function() return player.concealed() end, ui.row { px = Settings.inset(), command("Reveal image", "reveal") }),
					},
					Settings.Section {
						title = "Image",
						Settings.Group {
							Settings.Row { label = "Save or open", description = "Keep the original, or convert in Download format settings.",
								control = ui.row { gap = "$space.1",
									action("Download", function()
										local image = current()
										if image then exporter.save(image, zeron.setting("download_format"):peek() or "original", function() local now = current(); return now ~= nil and now.url == image.url end) end
									end),
									action("Copy URL", function() local image = current(); if image then ui.clipboard.write(image.url); zeron.toast("Image URL copied") end end),
									action("Open Original", function() local image = current(); if image then zeron.open_url(image.url) end end),
								},
							},
						},
						ui.show(function() return zeron.setting("metadata"):get() ~= false and current() ~= nil end,
							Text { function()
								local image = current()
								if not image then return "" end
								return (if image.artist then "Artist · " .. image.artist .. "\n" else "") .. "Tags · " .. table.concat(image.tags, ", ")
							end, style = "caption", tone = "secondary", wrap = true, literal = true, px = Settings.inset() }),
					},
					Settings.Section {
						Settings.Group { Settings.Row { label = "Filters & settings", description = "Ratings, tags, image fit, and download format.", on_click = open_settings } },
						Text { "Drag the PiP title to move it. Drag the resize handle to change its size. Playback pauses when all image views are hidden.", style = "caption", tone = "secondary", wrap = true, px = Settings.inset() },
						Text { "Changes are saved automatically. Nekos API ratings may be inaccurate.", style = "caption", tone = "secondary", wrap = true, px = Settings.inset() },
					},
				},
			},
		}
	end
end

--!strict
local ID = "nekos-api-anime-images"
local zeron = require("./zeron")(ID)
local Button = require("@ds/button")
local PanelHome = require("@ds/panel_home")
local model = require("./slideshow")(zeron)
local exporter = require("./download")(zeron)
local settings = function() zeron.open({ settings = "plugin-" .. ID }) end
local Gallery = require("./gallery")(zeron, settings, model, exporter)
local Controls = require("./player_panel")(zeron, model, exporter, settings)
local Image = require("./image_panel")(zeron, model)
local Workspace = require("./workspace")(Gallery, Controls, ui.state("nekos_view", "panel"))

zeron.page {
	id = "gallery", title = "Nekos Anime Images", icon = "gallery",
	build = function(): Node return Workspace { panel = zeron.context("panel") } end,
}
zeron.tab("nekos-image", function(): Node return Image {} end)
zeron.tab("nekos-controls", function(): Node return Controls(zeron.context("panel")) end)
zeron.tab("nekos-gallery", function(): Node return Gallery { panel = zeron.context("panel") } end)

local function open(kind: string, title: string)
	local panel = zeron.context("panel")
	if panel then
		panel.open_tab { kind = kind, title = title, icon = "gallery", data = { key = kind } }
	else
		zeron.toast("Select Nekos Anime Images in the sidebar to open its page and panel.")
	end
end
ui.command { id = "open_panel", title = "Open Nekos Image Panel", menu = "View", run = function() open("nekos-image", "Nekos image") end }
ui.command { id = "open_gallery", title = "Open Nekos Anime Images", menu = "View", key = "cmd+shift+g", run = function() open("nekos-gallery", "Nekos gallery") end }
ui.command { id = "panel_controls", title = "Nekos Image Panel Controls", menu = "View", run = function() open("nekos-controls", "Nekos controls") end }

zeron.place {
	at = "#sidebar-actions",
	after = function(): Node
		local panel = zeron.context("panel")
		return Button { "Nekos image panel", label = "Open Nekos Image Panel", tone = "ghost", size = "sm", on_click = function() model.open(panel) end }
	end,
}
zeron.place {
	at = "hook:panel.empty",
	after = function(): Node
		local panel = zeron.context("panel")
		if not panel then return ui.div {} end
		return PanelHome.Row { id = "nekos-open-panel", icon = "gallery", label = "Nekos image", on_click = function() model.open(panel) end }
	end,
}
-- The exporter exists only for a user-requested save and uses Zeron's own web view.
zeron.place { at = "#shell-chats", after = exporter.node }

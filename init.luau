--!strict
local ID = "nekos-api-anime-images"
local zeron = require("./zeron")(ID)
local PanelHome = require("@ds/panel_home")
local model = require("./slideshow")(zeron)
local exporter = require("./download")(zeron)
local settings = function() zeron.open({ settings = "plugin-" .. ID }) end
local Gallery = require("./gallery")(zeron, settings, model, exporter)
local Controls = require("./player_panel")(zeron, model, exporter, settings)
local PictureInPicture = require("./image_pip")(zeron, model, settings)
local Workspace = require("./workspace")(Gallery, Controls, ui.state("nekos_view", "panel"))

zeron.page {
	id = "gallery", title = "Nekos Anime Images", icon = "gallery",
	build = function(): Node return Workspace {} end,
}
zeron.tab("nekos-controls", function(): Node return Controls() end)
zeron.tab("nekos-gallery", function(): Node return Gallery {} end)

local function open(kind: string, title: string)
	local panel = zeron.context("panel")
	if panel then
		panel.open_tab { kind = kind, title = title, icon = "gallery", data = { key = kind } }
	else
		zeron.toast("Select Nekos Anime Images in the sidebar to open its page.")
	end
end
ui.command { id = "open_panel", title = "Open Nekos Picture-in-Picture", menu = "View", run = model.open }
ui.command { id = "open_gallery", title = "Open Nekos Anime Images", menu = "View", key = "cmd+shift+g", run = function() open("nekos-gallery", "Nekos gallery") end }
ui.command { id = "panel_controls", title = "Nekos Image Controls", menu = "View", run = function() open("nekos-controls", "Nekos controls") end }

zeron.place {
	at = "hook:panel.empty",
	after = function(): Node
		return PanelHome.Row { id = "nekos-open-panel", icon = "gallery", label = "Nekos Picture-in-Picture", on_click = model.open }
	end,
}
-- The exporter exists only for a user-requested save and uses Zeron's own web view.
zeron.place { at = "#shell-chats", after = exporter.node }
zeron.place { at = "#shell-chats", after = PictureInPicture }

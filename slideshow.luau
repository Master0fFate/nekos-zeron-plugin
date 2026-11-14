--!strict
local api = require("./api")
local build_state = require("./gallery_state")

return function(zeron: any, request: ((string) -> any)?)
	local viewers = ui.state("panel_viewers", 0)
	local visible = ui.computed(function() return viewers:get() > 0 end)
	local state = build_state(zeron, { shared = true, enabled = visible, request = request })
	local store = zeron.store("native_slideshow", {})
	local saved = store:peek()
	if type(saved) ~= "table" then saved = {} end
	local defaults = zeron.settings()
	local playing = ui.state("slideshow_playing", if saved.autoplay ~= nil and saved.default_autoplay == defaults.floating_autoplay then saved.autoplay == true else defaults.floating_autoplay == true)
	local interval = ui.state("slideshow_interval", api.number(if saved.default_interval == defaults.floating_interval then saved.interval else defaults.floating_interval, 10, 1, 3600))
	local ready = ui.state("slideshow_ready", "")

	local function current(): api.Image?
		return state.images:get()[state.index:get()]
	end
	local function allowed(): boolean
		local image = current()
		if not image then return false end
		return api.filters(zeron.settings()).allowed[image.rating] == true
	end
	local function concealed(): boolean
		local image = current()
		return image ~= nil and image.rating ~= "safe" and state.revealed:get()[image.id] ~= true
			and (zeron.setting("hide_nsfw"):get() ~= false or zeron.setting("blur_nsfw"):get() ~= false)
	end
	local function changed()
		store:set({ autoplay = playing:peek(), interval = interval:peek(), default_autoplay = zeron.setting("floating_autoplay"):peek(), default_interval = zeron.setting("floating_interval"):peek() })
	end
	zeron.on_setting(function(id, value)
		if id == "floating_autoplay" then playing:set(value == true); changed() end
		if id == "floating_interval" then interval:set(api.number(value, 10, 1, 3600)); changed() end
	end)

	local function step(delta: number)
		local count = state.images:len()
		if count > 0 then state.index:set((state.index:peek() - 1 + delta) % count + 1) end
	end
	ui.effect(function()
		local image = current()
		local active = visible:get() and zeron.window().shown
		local autoplay = playing:get()
		local seconds = interval:get()
		local loaded = ready:get()
		local hidden = concealed()
		local loading = state.loading:get()
		if active and autoplay and not loading and image and state.images:len() > 1 and (hidden or loaded == image.url) then
			local stop = ui.after(seconds * 1000, function() step(1) end)
			ui.on_cleanup(stop)
		end
	end)

	return {
		state = state, autoplay = playing, interval = interval, changed = changed,
		current = current, allowed = allowed, concealed = concealed,
		active = visible,
		message = ui.computed(function()
			if state.loading:get() then return "Loading images…" end
			if state.message:get() ~= "" then return state.message:get() end
			local image = current()
			if not image then return "Open the image panel to start." end
			if concealed() then return "NSFW preview protected. Reveal it here." end
			return `Image {state.index:get()} of {state.images:len()} · {image.rating}`
		end),
		attach = function()
			local attached = false
			local function show(on: boolean)
				if on == attached then return end
				attached = on
				viewers:set(math.max(0, viewers:peek() + (if on then 1 else -1)))
			end
			ui.on_cleanup(function() show(false) end)
			return show
		end,
		loaded = function(url: string)
			local image = current()
			if image and image.url == url then ready:set(url) end
		end,
		failed = function(url: string)
			local image = current()
			if image and image.url == url then
				state.message:set("Image could not load. Select Next or Refresh.")
				ready:set(url)
			end
		end,
		command = function(action: string)
			if action == "next" then step(1)
			elseif action == "previous" then step(-1)
			elseif action == "refresh" then state.load(false)
			elseif action == "reveal" then
				local image = current()
				if image and allowed() then state.revealed:set_key(image.id, true) end
			end
		end,
		present = function(images: { api.Image }, index: number)
			state.images:set(table.clone(images))
			state.index:set(math.clamp(index, 1, math.max(1, #images)))
			state.revealed:set({})
		end,
		open = function(panel: any)
			if not panel then
				zeron.toast("Open Nekos Anime Images from the sidebar, then select Open panel.")
				return
			end
			panel.open_tab { kind = "nekos-image", title = "Nekos image", icon = "gallery", data = { key = "nekos-image" } }
		end,
	}
end

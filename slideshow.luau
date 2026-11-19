--!strict
local api = require("./api")
local build_state = require("./gallery_state")

return function(zeron: any, request: ((string) -> any)?)
	local viewers = ui.state("panel_viewers", 0)
	local pip_open = ui.state("nekos_pip_open", false)
	local visible = ui.computed(function() return viewers:get() > 0 end)
	local state = build_state(zeron, { shared = true, enabled = visible, request = request })
	local store = zeron.store("native_slideshow", {})
	local saved = store:peek()
	if type(saved) ~= "table" then saved = {} end
	local defaults = zeron.settings()
	local playing = ui.state("slideshow_playing", if saved.autoplay ~= nil and saved.default_autoplay == defaults.floating_autoplay then saved.autoplay == true else defaults.floating_autoplay == true)
	local interval = ui.state("slideshow_interval", api.number(if saved.default_interval == defaults.floating_interval then saved.interval else defaults.floating_interval, 10, 1, 3600))
	-- Track every image in the current batch: cached images may not emit a
	-- second on_load event when revisited. A missing event must not stop playback.
	local results = ui.state("image_results", {} :: { [string]: string })
	local retained = ui.state("last_loaded_image", nil :: api.Image?)
	local retained_revision = ui.state("last_loaded_revision", -1)
	local retained_privacy = ui.state("last_loaded_privacy", "")
	local function current(): api.Image? return state.images:get()[state.index:get()] end
	local function allowed(image: api.Image?): boolean
		image = image or current()
		return image ~= nil and api.filters(zeron.settings()).allowed[image.rating] == true
	end
	local function concealed(image: api.Image?): boolean
		image = image or current()
		return image ~= nil and image.rating ~= "safe" and state.revealed:get()[image.id] ~= true
			and (zeron.setting("hide_nsfw"):get() ~= false or zeron.setting("blur_nsfw"):get() ~= false)
	end
	local function privacy(): string
		return tostring(zeron.setting("hide_nsfw"):get()) .. ":" .. tostring(zeron.setting("blur_nsfw"):get())
	end
	local function changed()
		store:set({ autoplay = playing:peek(), interval = interval:peek(), default_autoplay = zeron.setting("floating_autoplay"):peek(), default_interval = zeron.setting("floating_interval"):peek() })
	end
	zeron.on_setting(function(id, value)
		if id == "floating_autoplay" then playing:set(value == true); changed() end
		if id == "floating_interval" then interval:set(api.number(value, 10, 1, 3600)); changed() end
	end)
	ui.effect(function()
		state.revision:get()
		results:set({})
		retained:set(nil)
	end)
	ui.effect(function()
		local kept = {}
		local known = results:peek()
		for _, image in state.images:get() do kept[image.url] = known[image.url] end
		results:set(kept)
	end)
	local function step(delta: number)
		local count = state.images:len()
		if count > 0 then state.index:set((state.index:peek() - 1 + delta) % count + 1) end
	end
	local function failed(url: string)
		results:set_key(url, "failed")
	end
	-- API timeouts do not cover image CDN requests. Bound that wait separately.
	ui.effect(function()
		local image = current()
		local active = visible:get() and zeron.window().shown
		if active and image and allowed(image) and not concealed(image) and results:get()[image.url] == nil then
			local url = image.url
			local stop = ui.after(15000, function() failed(url) end)
			ui.on_cleanup(stop)
		end
	end)
	ui.effect(function()
		local image = current()
		local active = visible:get() and zeron.window().shown
		local autoplay, seconds = playing:get(), interval:get()
		local outcome = if image then results:get()[image.url] else nil
		local hidden, loading = concealed(), state.loading:get()
		if active and autoplay and not loading and image and (hidden or outcome ~= nil) then
			local all_failed = outcome == "failed"
			for _, candidate in state.images:get() do
				if results:get()[candidate.url] ~= "failed" then all_failed = false; break end
			end
			if all_failed then
				playing:set(false); changed()
				return
			end
			local stop = ui.after((if outcome == "failed" then 1 else seconds) * 1000, function()
				if state.images:len() == 1 then state.load(false) else step(1) end
			end)
			ui.on_cleanup(stop)
		end
	end)
	return {
		state = state, autoplay = playing, interval = interval, changed = changed,
		current = current, allowed = allowed, concealed = concealed, active = visible,
		outcome = function() local image = current(); return if image then results:get()[image.url] else nil end,
		previous = function(): api.Image?
			local image = retained:get()
			return if image and current() and retained_revision:get() == state.revision:get()
				and retained_privacy:get() == privacy() and allowed(image) and not concealed(image) and not concealed()
				then image else nil
		end,
		message = ui.computed(function()
			if state.loading:get() then return "Fetching images…" end
			if state.message:get() ~= "" then return state.message:get() end
			local image = current()
			if not image then return "No images. Select Refresh or change the filters." end
			if concealed() then return "NSFW preview protected. Select Reveal." end
			local outcome = results:get()[image.url]
			if outcome == "failed" then return "Image unavailable or timed out. Select Next or Refresh." end
			if outcome == nil then return `Loading image {state.index:get()} of {state.images:len()}…` end
			return `Image {state.index:get()} of {state.images:len()}`
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
			results:set_key(url, "ready")
			local image = current()
			if image and image.url == url and allowed(image) and not concealed(image) then
				retained:set(image); retained_revision:set(state.revision:peek()); retained_privacy:set(privacy())
			end
		end,
		failed = failed,
		command = function(action: string)
			if action == "next" then step(1)
			elseif action == "previous" then step(-1)
			elseif action == "refresh" then state.load(false)
			elseif action == "play" then playing:set(not playing:peek()); changed()
			elseif action == "reveal" then local image = current(); if image and allowed(image) then state.revealed:set_key(image.id, true) end
			end
		end,
		pip_open = pip_open,
		open = function() pip_open:set(true) end,
		close = function() pip_open:set(false) end,
	}
end

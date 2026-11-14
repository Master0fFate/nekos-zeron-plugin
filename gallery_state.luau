--!strict
local api = require("./api")

local MAX_IMAGES = 300
local MAX_HISTORY = 1000
local TIMEOUT_MS = 15000

local function same_filters(a: api.Filters?, b: api.Filters): boolean
	if not a or api.url(a) ~= api.url(b) or a.deduplicate ~= b.deduplicate then
		return false
	end
	for tag in a.excluded do
		if not b.excluded[tag] then
			return false
		end
	end
	for tag in b.excluded do
		if not a.excluded[tag] then
			return false
		end
	end
	return true
end

-- A limit applies even if the gallery is closed and reopened.
local retry_at = 0

return function(zeron: any, options: any?)
	local serial = 0
	local function state(value: any): any
		if options and options.shared then
			serial += 1
			return ui.state(`nekos-panel-{serial}`, value)
		end
		return ui.use_state(value)
	end
	local images = state({} :: { api.Image })
	local index = state(1)
	local message = state("")
	local loading = state(false)
	local cooling = state(false)
	local revealed = state({} :: { [string]: boolean })
	local offset = state(0)
	local filters: api.Filters? = nil
	local was_enabled = false
	local task: any = nil
	local stop_timeout: (() -> ())? = nil
	local stop_cooldown: (() -> ())? = nil
	local generation = 0
	local append_stalled = false
	local history: { [string]: boolean } = {}
	local order: { string } = {}
	local first = 1

	local function stop_request()
		generation += 1
		if stop_timeout then
			stop_timeout()
			stop_timeout = nil
		end
		if task then
			task:cancel()
			task = nil
		end
		loading:set(false)
	end

	local function update_cooldown()
		local left = retry_at - ui.now()
		cooling:set(left > 0)
		if stop_cooldown then
			stop_cooldown()
			stop_cooldown = nil
		end
		if left > 0 then
			stop_cooldown = ui.after(math.min(left, 60000), update_cooldown)
		end
	end

	local function is_seen(image: api.Image): boolean
		return history["id:" .. image.id] or history["url:" .. image.url] or false
	end

	local function remember(image: api.Image)
		for _, key in { "id:" .. image.id, "url:" .. image.url } do
			if not history[key] then
				history[key] = true
				table.insert(order, key)
			end
		end
		while #order - first + 1 > MAX_HISTORY * 2 do
			history[order[first]] = nil
			first += 1
		end
		if first > MAX_HISTORY then
			order = table.move(order, first, #order, 1, {})
			first = 1
		end
	end

	local function load(append: boolean, automatic: boolean?, after_load: ((number) -> ())?)
		local current = filters
		if not current or loading:peek() then
			return
		end
		local url = api.url(current)
		if not url then
			message:set("Enable at least one image rating in Settings.")
			return
		end
		if retry_at > ui.now() then
			update_cooldown()
			message:set(`Nekos API rate limit. Try again in {math.ceil((retry_at - ui.now()) / 1000)} seconds.`)
			return
		end
		local existing = images:peek()
		local previous_count = if append then #existing else 0
		if previous_count >= MAX_IMAGES or (automatic and append and append_stalled) then
			return
		end

		generation += 1
		local request = generation
		loading:set(true)
		message:set("")
		stop_timeout = ui.after(TIMEOUT_MS, function()
			stop_timeout = nil
			if generation == request then
				stop_request()
				append_stalled = true
				message:set("The request timed out. Select Refresh to try again.")
			end
		end)

		task = ui.task(function()
			local ok, response = pcall(function()
				return if options and options.request then options.request(url) else ui.fetch(url, { headers = { Accept = "application/json" } }):await()
			end)
			if request ~= generation then
				return
			end
			if stop_timeout then
				stop_timeout()
				stop_timeout = nil
			end
			task = nil

			local result: { api.Image }? = nil
			local failure: string? = nil
			if not ok then
				failure = "Could not reach Nekos API. Select Refresh to try again."
			elseif response.status == 429 then
				local delay = api.retry_seconds(response.headers["retry-after"], os.time())
				retry_at = ui.now() + delay * 1000
				update_cooldown()
				failure = `Nekos API rate limit. Try again in {delay} seconds.`
			elseif not response.ok then
				failure = `Nekos API returned HTTP {response.status}. Select Refresh to try again.`
			else
				result = api.images(response.json, current)
				if result == nil then
					failure = "Nekos API returned an invalid response."
				end
			end
			if result == nil then
				append_stalled = true
				message:set(failure or "Could not load images.")
				loading:set(false)
				return
			end

			local next_images = if append then table.clone(existing) else {}
			for _, image in result do
				if #next_images >= math.min(MAX_IMAGES, previous_count + current.limit) then
					break
				end
				if not current.deduplicate or not is_seen(image) then
					table.insert(next_images, image)
					remember(image)
				end
			end

			append_stalled = #next_images == previous_count
			if append_stalled then
				message:set(if #existing > 0 then "No new images matched. Try again or change the filters." else "No images matched these filters.")
			else
				if not append then
					index:set(1)
					revealed:set({})
					offset:set(0)
				end
				images:set(next_images)
				if after_load then
					after_load(previous_count + 1)
				end
			end
			loading:set(false)
		end)
	end

	ui.effect(function()
		local current = api.filters(zeron.settings())
		local enabled = not options or not options.enabled or options.enabled:get()
		local resumed = enabled and not was_enabled
		was_enabled = enabled
		if not enabled then stop_request() end
		if same_filters(filters, current) then
			if resumed and #images:peek() == 0 then ui.after(0, function() load(false) end) end
			return
		end
		stop_request()
		filters = current
		table.clear(history)
		table.clear(order)
		first = 1
		append_stalled = false
		revealed:set({})
		images:set({})
		index:set(1)
		offset:set(0)
		if enabled then ui.after(0, function() load(false) end) end
	end)

	local refresh = zeron.setting("auto_refresh")
	local interval = zeron.setting("refresh_interval")
	ui.effect(function()
		local enabled = refresh:get() == true and (not options or not options.enabled or options.enabled:get())
		local visible = zeron.window().shown
		local seconds = api.number(interval:get(), 60, 5, 3600)
		if enabled and visible then
			local stop = ui.every(seconds * 1000, function()
				if retry_at <= ui.now() then
					load(false)
				end
			end)
			ui.on_cleanup(stop)
		end
	end)
	ui.on_cleanup(function()
		stop_request()
		if stop_cooldown then
			stop_cooldown()
		end
	end)
	update_cooldown()

	return {
		images = images,
		index = index,
		message = message,
		loading = loading,
		cooling = cooling,
		revealed = revealed,
		offset = offset,
		load = load,
		max_images = MAX_IMAGES,
	}
end

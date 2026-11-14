--!strict
local api = require("./api")
local page = require("./export_page")

return function(zeron: any)
	local busy = ui.state("nekos_export_busy", false)
	local web: any = nil
	local request: any = nil
	local token = 0
	local expected: string? = nil
	local timeout: (() -> ())? = nil
	local saving = false

	local function finish(problem: string?)
		if timeout then timeout(); timeout = nil end
		request = nil
		expected = nil
		saving = false
		busy:set(false)
		if web then web:close(); web = nil end
		if problem then zeron.toast(problem .. " You can also use Open Original.") end
	end
	local function permitted(): boolean
		return request ~= nil and request.allowed()
	end
	return {
		busy = busy,
		save = function(image: api.Image, format: string, allowed: () -> boolean)
			if busy:peek() or not allowed() or not api.image_url(image.url) then return end
			token += 1
			request = { data = { url = image.url, id = image.id, format = format, token = token }, allowed = allowed }
			busy:set(true)
			timeout = ui.after(30000, function() timeout = nil; if not saving then finish("The built-in image exporter did not respond.") end end)
		end,
		node = function(): Node
			return ui.presence(function() return busy:get() end, function(on: boolean): Node
				if not on then return ui.div {} end
				local this_token = token
				local started = false
				local ok, controller = pcall(function() return ui.web { profile = "ephemeral", messages = true } end)
				if not ok then
					ui.after(0, function() finish("The built-in web view is unavailable.") end)
					return ui.div {}
				end
				web = controller
				return ui.webview {
					id = "nekos-exporter", web = web, html = page, w = 1, h = 1, transparent = true, messages = true,
					on_load = function()
						if started or token ~= this_token or not web then return end
						started = true
						if not permitted() then finish(nil); return end
						web:run("window.nekosExport(" .. ui.json.encode(request.data) .. ")")
					end,
					on_error = function(_, problem: string) if token == this_token then finish(problem) end end,
					on_message = function(value: any, origin: string, main: boolean)
						if not main or (origin ~= "" and origin ~= "null" and origin ~= "about:blank" and origin ~= "about" and origin ~= "about://" and origin ~= "://") then return end
						if not request or type(value) ~= "table" or value.token ~= request.data.token then return end
						if not permitted() then finish(nil); return end
						if value.kind == "error" then
							finish(if type(value.error) == "string" then value.error else "Image export failed.")
						elseif expected == nil and value.kind == "prepared" and type(value.url) == "string" and string.sub(value.url, 1, 5) == "blob:" then
							expected = value.url
							web:run("window.nekosCommit(" .. tostring(value.token) .. ")")
						end
					end,
					on_download = function(d: any)
						if saving or token ~= this_token or not permitted() or expected == nil or d.url ~= expected then d:cancel(); return end
						saving = true
						if timeout then timeout(); timeout = nil end
						ui.task(function()
							local ok, file = pcall(function() return ui.save_file { name = d.name, title = "Save image" }:await() end)
							if not ok or not file or not permitted() then d:cancel(); finish(if not ok then "Could not open Save dialog." else nil); return end
							local saved, problem = pcall(function()
								d:save_to(file, { on_finish = function(success: boolean, err: string?)
									finish(if success then nil else err or "Image download failed.")
									if success then zeron.toast("Image saved") end
								end })
							end)
							if not saved then finish(tostring(problem)) end
						end)
					end,
				}
			end, { absolute = true, w = 1, h = 1, aria_hidden = true })
		end,
	}
end

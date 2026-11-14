--!strict
local Text = require("@ds/text")
local Button = require("@ds/button")
local Icon = require("@ds/icon")
local Badge = require("@ds/badge").Badge
local Empty = require("@ds/empty_state")
local api = require("./api")
local gallery_state = require("./gallery_state")

local LABEL = { safe = "Safe", suggestive = "Suggestive", borderline = "Borderline", explicit = "Explicit" }
local CARD_HEIGHT = 246

local function action(label: string, icon: any, tone: any, on_click: () -> (), disabled: (() -> boolean)?): Node
	return Button {
		label = label,
		tone = tone,
		size = "sm",
		disabled = disabled,
		on_click = on_click,
		Icon { name = icon, size = 14, aria_hidden = true },
		label,
	}
end

return function(zeron: any, open_settings: () -> (), player: any?, exporter: any?)
	local downloads = exporter or require("./download")(zeron)
	local Gallery = ui.component(function(props: { close: (() -> ())?, panel: any?, embedded: boolean? }): Node
		local state = if player then player.state else gallery_state(zeron)
		local visibility = if player then player.attach() else nil
		local Surface = if player then require("./image_surface")(zeron, player) else nil
		local width = ui.use_state(0)
		local busy_save = downloads.busy
		local panel = props.panel
		local list_ref = ui.ref()
		local mode = zeron.setting("mode")
		local metadata = zeron.setting("metadata")
		local aspect = zeron.setting("aspect")
		local hide = zeron.setting("hide_nsfw")
		local blur = zeron.setting("blur_nsfw")
		local format = zeron.setting("download_format")
		local auto_more = zeron.setting("auto_more")
		local nsfw = zeron.setting("enable_nsfw")
		local at_end = ui.use_state(false)
		ui.effect(function()
			if auto_more:get() == true and mode:get() == "gallery" and at_end:get() then
				local cancel = ui.after(0, function() state.load(true, true) end)
				ui.on_cleanup(cancel)
			end
		end)

		local function columns(w: number): number
			return if w >= 990 then 4 elseif w >= 720 then 3 elseif w >= 470 then 2 else 1
		end

		local function selected(): api.Image?
			local index = state.index:get()
			return state.images:get()[index]
		end

		local function choose(index: number, scroll: boolean?)
			state.index:set(index)
			if scroll then
				local list = list_ref:peek()
				if list then
					list:scroll_to_row(math.ceil(index / columns(width:peek())), { align = "nearest" })
				end
			end
		end

		local function next_image()
			if player then player.command("next"); return end
			local count = state.images:len()
			local index = state.index:peek()
			if index < count then
				choose(index + 1, true)
			else
				state.load(true, false, function(next_index)
					ui.after(0, function()
						choose(next_index, true)
					end)
				end)
			end
		end

		local function unlocked(image: api.Image, index: number): boolean
			if image.rating == "safe" then
				return true
			end
			return nsfw:get() == true and zeron.setting(image.rating):get() == true
				and (hide:get() == false or state.revealed:get()[image.id] == true)
		end

		local function current_image(): api.Image?
			local image = selected()
			return if image and unlocked(image, state.index:get()) then image else nil
		end

		local function preview(image: api.Image, index: number, single: boolean): Node
			local failed = ui.use_state(false)
			local function placeholder(text: string, icon: any): Node
				return ui.column {
					w_full = true,
					h_full = true,
					items = "center",
					justify = "center",
					gap = "$space.2",
					color = "$text.tertiary",
					Icon { name = icon, size = 22, aria_hidden = true },
					Text { text, style = "caption", tone = "secondary" },
				}
			end

			return ui.overlay {
				w_full = true,
				h_full = true,
				ui.presence(function()
					return if not unlocked(image, index) then "hidden"
						elseif image.rating ~= "safe" and blur:get() ~= false and not state.revealed:get()[image.id] then "blur"
						else "plain"
				end, function(kind: string)
					local reveal = function()
						choose(index)
						state.revealed:set_key(image.id, true)
					end
					if kind == "hidden" then
						return ui.column {
							w_full = true, h_full = true, items = "center", justify = "center", gap = "$space.3",
							Text { "NSFW preview hidden", tone = "secondary", style = "caption" },
							Button { "Reveal image", tone = "secondary", size = "sm", on_click = reveal },
						}
					end
					return ui.overlay {
						w_full = true,
						h_full = true,
						overflow = "hidden",
						ui.image {
							id = `nekos-preview-{kind}`,
							src = image.url,
							w_full = true,
							h_full = true,
							label = if kind == "blur" then "Blurred anime image" else "Anime image",
							fit = function()
								return if aspect:get() ~= false then "contain" else "cover"
							end,
							blur = if kind == "blur" then 28 else 0,
							on_error = function() failed:set(true); if player then player.failed(image.url) end end,
							on_load = function() failed:set(false); if player then player.loaded(image.url) end end,
							fallback = ui.presence(function() return failed:get() end, function(broken)
								return placeholder(if broken then "Preview unavailable" else "Loading preview…", "gallery")
							end, { w_full = true, h_full = true }),
						},
						if kind == "blur" then ui.column {
							w_full = true, h_full = true, items = "center", justify = "center",
							Button { "Reveal image", tone = "secondary", size = "sm", on_click = reveal },
						} else nil,
					}
				end, { w_full = true, h_full = true }),
			}
		end

		local Card = ui.component(function(p: { image: api.Image, index: number, single: boolean? }): Node
			local image = p.image
			local number = p.index
			return ui.column {
				id = `nekos-image-{number}`,
				grow = if p.single then 0 else 1,
				basis = if p.single then nil else 0,
				w_full = p.single == true,
				h_full = p.single == true,
				h = if p.single then nil else CARD_HEIGHT,
				min_w = 0,
				rounded = "$radius.xl",
				border = 1,
				border_color = function()
					return if state.index:get() == number then "$accent" else "$border.subtle"
				end,
				overflow = "hidden",
				ui.div {
					w_full = true,
					grow = 1,
					min_h = 0,
					preview(image, number, p.single == true),
				},
				if not p.single then ui.row {
					w_full = true,
					shrink = 0,
					p = "$space.2",
					gap = "$space.2",
					items = "center",
					Button {
						function() return if state.index:get() == number then "Selected" else "Select" end,
						label = `Select image {number}`,
						tone = "ghost",
						size = "xs",
						on_click = function() choose(number) end,
					},
					ui.div { grow = 1 },
					ui.show(function() return metadata:get() ~= false end, Badge {
						LABEL[image.rating], tone = if image.rating == "safe" then "success" else "warning",
					}),
				} else nil,
			}
		end)

		local function gallery_list(): Node
			return ui.presence(function() return columns(width:get()) end, function(per_row: number): Node
				local rows = ui.computed(function()
					local images = state.images:get()
					local result = {}
					for first = 1, #images, per_row do
						local row = {}
						for i = first, math.min(first + per_row - 1, #images) do
							table.insert(row, images[i])
						end
						table.insert(result, row)
					end
					return result
				end)
				return ui.list {
					id = "nekos-image-list",
					ref = list_ref,
					w_full = true,
					h_full = true,
					height = CARD_HEIGHT + 12,
					data = rows,
					row = function(images: { api.Image }, row: State<number>)
						local first = (row:peek() - 1) * per_row + 1
						local cards: { Node } = {}
						for column = 1, per_row do
							if images[column] then
								table.insert(cards, Card { image = images[column], index = first + column - 1 })
							else
								table.insert(cards, ui.div { grow = 1, basis = 0, min_w = 0 })
							end
						end
						return ui.row { w_full = true, h = CARD_HEIGHT + 12, gap = "$space.3", pb = "$space.3", cards }
					end,
					scrollbar = true,
					offset = state.offset,
					at_end = at_end,
					overscan = 1,
					ahead = 0,
					on_end = function()
						if auto_more:peek() == true and state.images:len() > 0 and not state.cooling:peek() and zeron.window(true).shown then
							state.load(true, true)
						end
					end,
				}
			end, { w_full = true, h_full = true })
		end

		local function single_image(): Node
			if Surface then return Surface {} end
			return ui.presence(function()
				local i = state.index:get()
				local image = state.images:get()[i]
				return if image then `{i}:{image.id}:{image.url}` else ""
			end, function(): Node
				local index = state.index:peek()
				local image = state.images:peek()[index]
				return if image then Card { image = image, index = index, single = true } else ui.div {}
			end, { w_full = true, h_full = true })
		end

		local function image_details(): Node
			return ui.presence(function()
				local image = selected()
				local index = state.index:get()
				return if image and metadata:get() ~= false
					then `{index}:{image.id}:{image.url}:{tostring(unlocked(image, index))}` else ""
			end, function(key: string): Node
				if key == "" then return ui.div {} end
				local image = selected()
				if not image then return ui.div {} end
				local visible = unlocked(image, state.index:get())
				return ui.column {
					gap = "$space.1",
					ui.row {
						gap = "$space.2", items = "center", flex_wrap = true,
						Badge { LABEL[image.rating], tone = if image.rating == "safe" then "success" else "warning" },
						if visible and image.artist then Text { `Artist · {image.artist}`, style = "caption", literal = true } else nil,
						if visible and image.source then Button {
							"Source", size = "xs", tone = "ghost",
							on_click = function()
								local now = current_image()
								if now and now.url == image.url then zeron.open_url(image.source :: string) end
							end,
						} else nil,
					},
					if visible and #image.tags > 0 then Text {
						`Tags · {table.concat(image.tags, ", ")}`, style = "caption", tone = "secondary",
						literal = true, truncate = true,
					} else nil,
				}
			end)
		end

		local function save()
			local image = current_image()
			if not image or busy_save:peek() then return end
			downloads.save(image, format:peek() or "original", function()
				local now = current_image()
				return now ~= nil and now.url == image.url
			end)
		end

		local function disabled(): boolean
			return current_image() == nil
		end

		local function refresh()
			state.load(false)
		end

		if props.embedded then
			return ui.column {
				id="nekos-gallery",w_full=true,h_full=true,min_h=0,gap="$space.2",p="$space.2",
				on_resize=function(size) local w=math.floor(size.w); if w>0 and w~=width:peek() then width:set(w) end end,
				image_details(),
				ui.div {grow=1,min_h=0,w_full=true,gallery_list()},
				Button {"Load More",label="Load more images",size="xs",tone="ghost",disabled=function() return state.loading:get() or state.cooling:get() or state.images:len()>=state.max_images end,on_click=function() state.load(true) end},
			}
		end

		return ui.column {
			id = "nekos-gallery",
			on_visible = visibility,
			w_full = true,
			h_full = true,
			min_h = 0,
			on_resize = function(size)
				local w = math.floor(size.w)
				if w > 0 and w ~= width:peek() then width:set(w) end
			end,
			p = "$space.5",
			gap = "$space.3",
			ui.row {
				w_full = true, items = "center", gap = "$space.3", flex_wrap = true,
				Text { "Nekos Anime Images", style = "title", role = "heading" },
				ui.div { grow = 1 },
				action("Settings", "settings", "ghost", function()
					if props.close then props.close() end
					open_settings()
				end),
				if props.close then action("Close", "close", "ghost", props.close) else nil,
			},
			ui.row {
				w_full = true, items = "center", gap = "$space.2", flex_wrap = true,
				action("Refresh", "refresh", "primary", refresh, function() return state.loading:get() or state.cooling:get() end),
				if player then action("Open panel", "arrow-up-right", "ghost", function()
					if state.images:len() > 0 then player.present(state.images:peek(), state.index:peek()) end
					player.open(panel)
				end) else nil,
				action("Next Image", "arrow-right", "secondary", next_image, function()
					local count = state.images:len()
					return count == 0 or (state.index:get() >= count
						and (state.loading:get() or state.cooling:get() or count >= state.max_images))
				end),
				ui.div { grow = 1 },
				Text {
					function()
						local count = state.images:len()
						if state.loading:get() and count == 0 then return "Loading images…" end
						if count == 0 then return "" end
						return `Image {state.index:get()} of {count}`
					end,
					style = "caption", tone = "secondary",
				},
			},
			Text { "Nekos API content ratings may be inaccurate.", style = "caption", tone = "secondary", wrap = true },
			ui.show(function() return state.images:len() > 0 end, ui.column {
				w_full = true, gap = "$space.2", p = "$space.3", rounded = "$radius.lg",
				ui.row {
					w_full = true, items = "center", gap = "$space.2", flex_wrap = true,
					action("Download", "download", "secondary", save, function() return disabled() or busy_save:get() end),
					action("Copy URL", "copy", "ghost", function()
						local image = current_image()
						if image then
							ui.clipboard.write(image.url)
							zeron.toast("Image URL copied")
						end
					end, disabled),
					action("Open Original", "arrow-up-right", "ghost", function()
						local image = current_image()
						if image then zeron.open_url(image.url) end
					end, disabled),
				},
				image_details(),
			}),
			ui.div {
				w_full = true, grow = 1, min_h = 0,
				ui.presence(function()
					if state.images:len() == 0 then return if state.loading:get() then "loading" else "empty" end
					return if mode:get() == "single" then "single" else "gallery"
				end, function(view: string): Node
					if view == "gallery" then return gallery_list() end
					if view == "single" then return single_image() end
					return Empty {
						icon = "gallery", fill = true,
						title = if view == "loading" then "Loading images…" else "No images to show",
						body = if view == "loading" then nil else function() return state.message:get() end,
					}
				end, { w_full = true, h_full = true }),
			},
			ui.show(function() return state.images:len() > 0 end, ui.row {
				w_full = true, items = "center", flex_wrap = true, gap = "$space.2",
				Button {
					function() return if state.loading:get() then "Loading…" else "Load More" end,
					size = "sm", tone = "secondary",
					disabled = function() return state.loading:get() or state.cooling:get() or state.images:len() >= state.max_images end,
					on_click = function() state.load(true) end,
				},
				ui.show(function() return state.message:get() ~= "" or state.images:len() >= state.max_images end, Text {
					function()
						return if state.images:len() >= state.max_images then "Gallery limit reached. Refresh for a new batch."
							else state.message:get()
					end,
					style = "caption", tone = "secondary", wrap = true, min_w = 0, shrink = 1,
				}),
			}),
		}
	end)
	return Gallery
end

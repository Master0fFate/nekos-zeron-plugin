--!strict
local M = {}

export type Image = {
	id: string,
	url: string,
	rating: string,
	artist: string?,
	tags: { string },
	source: string?,
}

export type Filters = {
	ratings: { string },
	allowed: { [string]: boolean },
	tags: { string },
	excluded: { [string]: boolean },
	artist: string,
	limit: number,
	deduplicate: boolean,
}

local RATINGS = { "safe", "suggestive", "borderline", "explicit" }
-- Some live records marked safe contain tags that indicate explicit content.
local UNSAFE_SAFE_TAGS = {
	dick = true,
	penis = true,
	pussy = true,
	vagina = true,
	exposed_girl_breasts = true,
	exposed_breasts = true,
	sex = true,
	masturbation = true,
	blowjob = true,
	hentai = true,
}
local ENDPOINT = "https://api.nekosapi.com/v4/images/random"

local function trim(value: string): string
	return (string.match(value, "^%s*(.-)%s*$") or "")
end

local function text(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local clean = trim(value)
	return if clean ~= "" then clean else nil
end

function M.number(value: any, default: number, min: number, max: number): number
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

local function tags(value: any): ({ string }, { [string]: boolean })
	local list, lookup = {}, {}
	if type(value) == "string" then
		for tag in string.gmatch(value, "[^,]+") do
			local clean = string.lower(trim(tag))
			if clean ~= "" and not lookup[clean] then
				table.insert(list, clean)
				lookup[clean] = true
			end
		end
	end
	return list, lookup
end

function M.filters(settings: { [string]: any }): Filters
	local ratings, allowed = {}, {}
	for _, rating in RATINGS do
		local enabled = if rating == "safe"
			then settings.safe ~= false
			else settings.enable_nsfw == true and settings[rating] == true
		if enabled then
			table.insert(ratings, rating)
			allowed[rating] = true
		end
	end
	local included = tags(settings.included_tags)
	local _, excluded = tags(settings.excluded_tags)
	return {
		ratings = ratings,
		allowed = allowed,
		tags = included,
		excluded = excluded,
		artist = text(settings.artist) or "",
		limit = M.number(settings.limit, 12, 1, 100),
		deduplicate = settings.deduplicate ~= false,
	}
end

local function encode(value: string): string
	return (string.gsub(value, "([^A-Za-z0-9._~-])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

function M.url(filters: Filters): string?
	if #filters.ratings == 0 then
		return nil
	end
	local params = { "limit=" .. encode(tostring(filters.limit)), "rating=" .. encode(table.concat(filters.ratings, ",")) }
	if #filters.tags > 0 then
		table.insert(params, "tags=" .. encode(table.concat(filters.tags, ",")))
	end
	if filters.artist ~= "" then
		table.insert(params, "artist=" .. encode(filters.artist))
	end
	return ENDPOINT .. "?" .. table.concat(params, "&")
end

local function https_url(value: any): string?
	if type(value) == "string" and #value <= 4096 and string.match(value, "^https://[^/%s?#]+") and not string.find(value, "[%s%c]") then
		return value
	end
	return nil
end

function M.image_url(value: any): string?
	local url = https_url(value)
	if not url then
		return nil
	end
	local host = string.lower(string.match(url, "^https://([^/]+)") or "")
	if host == "cdn.nekosapi.com" or host == "s3.nyeki.dev" then
		return url
	end
	return nil
end

function M.images(payload: any, filters: Filters): { Image }?
	if type(payload) ~= "table" then
		return nil
	end
	for k in payload do
		if type(k) ~= "number" or k < 1 or k > #payload or k % 1 ~= 0 then
			return nil
		end
	end

	local images = {}
	for _, raw in ipairs(payload) do
		if type(raw) ~= "table" then
			continue
		end
		local record = raw :: { [string]: any }
		local rating = record.rating
		if type(rating) ~= "string" or not filters.allowed[rating] then
			continue
		end
		local url = M.image_url(record.url)
		if not url then
			continue
		end
		local image_tags, excluded = {}, false
		if type(record.tags) == "table" then
			for _, value in ipairs(record.tags :: { any }) do
				local tag = text(value)
				if tag then
					local normalized = string.lower(tag)
					if filters.excluded[normalized] or (rating == "safe" and UNSAFE_SAFE_TAGS[normalized]) then
						excluded = true
						break
					end
					table.insert(image_tags, tag)
				end
			end
		end
		if not excluded then
			table.insert(images, {
				id = if type(record.id) == "number" or type(record.id) == "string" then tostring(record.id) else url,
				url = url,
				rating = rating,
				artist = text(record.artist_name),
				tags = image_tags,
				source = https_url(record.source_url),
			})
		end
	end
	return images
end

local MONTHS = { Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12 }

function M.retry_seconds(value: any, now: number): number
	if type(value) == "string" then
		local delay = tonumber(value)
		if delay and delay >= 0 and delay < math.huge then
			return math.max(1, math.ceil(delay))
		end
		local day, month, year, hour, minute, second = string.match(
			value, "^%a+, (%d%d) (%a%a%a) (%d%d%d%d) (%d%d):(%d%d):(%d%d) GMT$"
		)
		if day and MONTHS[month] then
			local ok, deadline = pcall(function()
				return os.time({
					year = tonumber(year) :: number, month = MONTHS[month], day = tonumber(day) :: number,
					hour = tonumber(hour) :: number, min = tonumber(minute) :: number, sec = tonumber(second) :: number,
				})
			end)
			if ok and deadline then
				return math.max(1, deadline - now)
			end
		end
	end
	return 30
end

return M

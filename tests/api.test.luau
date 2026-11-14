-- Run with the standalone Luau CLI.
local api = require("../api")

local function record(id, rating, tags)
	return {
		id = id, rating = rating, tags = tags or {},
		url = `https://cdn.nekosapi.com/nekos-api/images/original/{id}.webp`,
		artist_name = "Test artist", source_url = "https://example.org/source",
	}
end

local records = {
	record(1, "safe", { "Sky", "cat ears" }),
	record(2, "suggestive"),
	record(3, "borderline"),
	record(4, "explicit"),
	record(5, "safe", { "Exposed_girl_breasts" }),
	record(6, "unrated"),
	record(7, nil),
	{ id = 8, rating = "safe", url = "https://example.org/elsewhere.webp" },
}

local defaults = api.filters({})
assert(api.url(defaults) == "https://api.nekosapi.com/v4/images/random?limit=12&rating=safe")
local safe = assert(api.images(records, api.filters({ suggestive = true, borderline = true, explicit = true })))
assert(#safe == 1 and safe[1].id == "1")
assert(safe[1].artist == "Test artist" and safe[1].source == "https://example.org/source")
assert(string.find(safe[1].url, "%.webp$"))

local all = api.filters({ enable_nsfw = true, suggestive = true, borderline = true, explicit = true })
assert(#assert(api.images(records, all)) == 4)
assert(string.find(assert(api.url(all)), "rating=safe%%2Csuggestive%%2Cborderline%%2Cexplicit"))
assert(#assert(api.images(records, api.filters({ enable_nsfw = true, safe = false, explicit = true }))) == 1)
assert(api.url(api.filters({ enable_nsfw = true, safe = false })) == nil)
assert(api.url(api.filters({ safe = false, explicit = true })) == nil)

local filtered = api.filters({
	included_tags = " Sky , cat ears, SKY ", excluded_tags = " sky ",
	artist = "  Á & #  ", limit = 150,
})
assert(api.url(filtered) == "https://api.nekosapi.com/v4/images/random?limit=100&rating=safe&tags=sky%2Ccat%20ears&artist=%C3%81%20%26%20%23")
assert(#assert(api.images(records, filtered)) == 0)
assert(api.url(api.filters({ limit = 0 })) == "https://api.nekosapi.com/v4/images/random?limit=1&rating=safe")
assert(api.images({ error = "wrong shape" }, defaults) == nil)
assert(api.images("not JSON", defaults) == nil)
assert(#assert(api.images({}, defaults)) == 0)
assert(api.retry_seconds("12", 0) == 12)
assert(api.retry_seconds("Sat, 14 Nov 2026 19:00:15 GMT", 1794682800) == 15)
assert(api.retry_seconds(nil, 0) == 30)
print("Passed API filters, metadata, response validation, encoding and cooldown.")

--!strict
local geometry = require("../pip_geometry")

local window = { width = 1180, height = 850 }
local initial = geometry.fit(window)
assert(initial.x == 868 and initial.y == 568 and initial.w == 300 and initial.h == 270)

local moved = geometry.fit(window, { x = -10, y = 900, w = 300, h = 270 })
assert(moved.x == 12 and moved.y == 568)

local shrunk = geometry.resize(window, initial, -300, -300)
assert(shrunk.w == 210 and shrunk.h == 170)

local expanded = geometry.resize(window, { x = 100, y = 100, w = 300, h = 270 }, 300, 400)
assert(expanded.x == 100 and expanded.y == 100 and expanded.w == 600 and expanded.h == 670)

local small = geometry.fit({ width = 320, height = 240 }, expanded)
assert(small.x == 12 and small.y == 12 and small.w == 296 and small.h == 216)
local resize_small = geometry.resize({ width = 320, height = 240 }, small, 100, 100)
assert(resize_small.w == 296 and resize_small.h == 216)

print("Passed default PiP placement, drag bounds and resize limits.")

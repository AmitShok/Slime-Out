-- Animated reticle parts. The game assembles them (4 mirrored brackets,
-- pulsing centre, hit marker, reload ring) so the reticle can breathe,
-- spread with recoil and react to hits while staying pixel-perfect.
-- Run: Aseprite.exe -b --script-param root=<project> --script build_reticle.lua

local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local lib = require("pixel_lib")

local out = root .. "/assets/floor38/ui/"
local src = root .. "/art_src/"

-- Top-left corner bracket; mirrored for the other three corners.
lib.build_strip({
  { name = "bracket", grid = {
    "kkkkkk.",
    "kwwwwwk",
    "kwsskk.",
    "kwsk...",
    "kwk....",
    "kwk....",
    ".k.....",
  }},
}, 7, 7, src .. "reticle_bracket.aseprite", out .. "reticle_bracket.png")

-- Style pieces. "corner" pieces are mirrored into the 4 diagonals, "axis"
-- pieces are rotated in 90-degree steps (both stay pixel-perfect).
lib.build_strip({
  { name = "tick", grid = {
    ".k.",
    "kwk",
    "kwk",
    "kwk",
    "kwk",
    ".k.",
  }},
}, 3, 6, src .. "reticle_tick.aseprite", out .. "reticle_tick.png")

lib.build_strip({
  { name = "chevron", grid = {
    "kk...kk",
    "kwk.kwk",
    ".kwkwk.",
    "..kwk..",
    "...k...",
  }},
}, 7, 5, src .. "reticle_chevron.aseprite", out .. "reticle_chevron.png")

-- Round style: hand-placed top-left quarter of a clean 1px pixel circle
-- (runs 2-2-1-1-2 so the curve reads smooth), centred on the piece's
-- bottom-right corner, with gaps at the axes. Outline is added around it.
do
  local S = 8
  local ring = { {5,1},{6,1},{3,2},{4,2},{2,3},{2,4},{1,5},{1,6} }
  local cells = {}
  for y = 0, S - 1 do cells[y] = {} for x = 0, S - 1 do cells[y][x] = "." end end
  for _, p in ipairs(ring) do cells[p[2]][p[1]] = "w" end
  for _, p in ipairs(ring) do
    for oy = -1, 1 do
      for ox = -1, 1 do
        local x, y = p[1] + ox, p[2] + oy
        if x >= 0 and x < S and y >= 0 and y < S and cells[y][x] == "." then
          cells[y][x] = "k"
        end
      end
    end
  end
  local grid = {}
  for y = 0, S - 1 do
    local row = {}
    for x = 0, S - 1 do row[#row + 1] = cells[y][x] end
    grid[#grid + 1] = table.concat(row)
  end
  lib.build_strip({ { name = "arc", grid = grid } }, S, S, src .. "reticle_arc.aseprite", out .. "reticle_arc.png")
end
-- Centre variants (idle + pulse each), plus a hollow ring used as the
-- pointer on paused screens. Frame order is relied on by ReticleView.
lib.build_strip({
  { name = "dot", grid = {
    ".......",
    ".......",
    "...k...",
    "..kwk..",
    "...k...",
    ".......",
    ".......",
  }},
  { name = "dot_pulse", grid = {
    ".......",
    "...k...",
    "..kwk..",
    ".kwywk.",
    "..kwk..",
    "...k...",
    ".......",
  }},
  { name = "menu", grid = {
    "..kkk..",
    ".kwwwk.",
    "kwk.kwk",
    "kwk.kwk",
    "kwk.kwk",
    ".kwwwk.",
    "..kkk..",
  }},
  { name = "plus", grid = {
    "...k...",
    "..kwk..",
    ".kkwkk.",
    "kwwwwwk",
    ".kkwkk.",
    "..kwk..",
    "...k...",
  }},
  { name = "plus_pulse", grid = {
    "...k...",
    "..kwk..",
    ".kkwkk.",
    "kwwywwk",
    ".kkwkk.",
    "..kwk..",
    "...k...",
  }},
  { name = "ring", grid = {
    "..kkk..",
    ".kwwwk.",
    "kwkkkwk",
    "kwkwkwk",
    "kwkkkwk",
    ".kwwwk.",
    "..kkk..",
  }},
  { name = "ring_pulse", grid = {
    "..kkk..",
    ".kwwwk.",
    "kwkkkwk",
    "kwkykwk",
    "kwkkkwk",
    ".kwwwk.",
    "..kkk..",
  }},
}, 7, 7, src .. "reticle_center.aseprite", out .. "reticle_center.png")
-- Hit marker: four diagonal ticks around the centre.
lib.build_strip({
  { name = "hit", grid = {
    "kk.......kk",
    "kwk.....kwk",
    ".kwk...kwk.",
    "..kk...kk..",
    "...........",
    "...........",
    "...........",
    "..kk...kk..",
    ".kwk...kwk.",
    "kwk.....kwk",
    "kk.......kk",
  }},
}, 11, 11, src .. "reticle_hit.aseprite", out .. "reticle_hit.png")

-- Reload ring: 12 frames filling clockwise from 12 o'clock.
local SIZE, C, R = 15, 7, 6
local frames = {}
for f = 1, 12 do
  local grid = {}
  for y = 0, SIZE - 1 do
    local row = {}
    for x = 0, SIZE - 1 do
      local dx, dy = x - C, y - C
      local d = math.sqrt(dx * dx + dy * dy)
      local ch = "."
      if d >= R - 0.5 and d < R + 0.5 then
        local angle = math.atan(dx, -dy) -- 0 at top, clockwise
        if angle < 0 then angle = angle + 2 * math.pi end
        ch = (angle <= f / 12 * 2 * math.pi) and "y" or "d"
      elseif d >= R - 1.5 and d < R + 1.5 then
        ch = "k"
      end
      row[#row + 1] = ch
    end
    grid[#grid + 1] = table.concat(row)
  end
  frames[f] = { name = "fill" .. f, grid = grid }
end
lib.build_strip(frames, SIZE, SIZE, src .. "reticle_reload.aseprite", out .. "reticle_reload.png")

lib.preview(out .. "reticle_center.png", src .. "preview_reticle_center.png", 12)
lib.preview(out .. "reticle_arc.png", src .. "preview_reticle_arc.png", 16)
lib.preview(out .. "reticle_reload.png", src .. "preview_reticle_reload.png", 8)

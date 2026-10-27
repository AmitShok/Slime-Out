-- "Bullet heaven" juice sprites: tracers, muzzle flare, casings, goo decals,
-- pickups, auto-weapon sprites and the sky-lightning bolt.
-- Goo/droplet art is drawn in greys so the game can tint it per slime.
-- Run: Aseprite.exe -b --script-param root=<project> --script build_juice.lua
local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local px = require("pixel_lib")
local out = root .. "/assets/floor38/fx/"
local pick = root .. "/assets/floor38/pickups/"
local src = root .. "/art_src/"

local function strip(name, w, h, frames, dest)
  local entries = {}
  for i, grid in ipairs(frames) do entries[i] = { name = name .. "_" .. i, grid = grid } end
  px.build_strip(entries, w, h, src .. name .. ".aseprite", dest .. name .. ".png")
end

local function remap(grid, map)
  local result = {}
  for i, row in ipairs(grid) do result[i] = row:gsub(".", function(c) return map[c] or c end) end
  return result
end

strip("tracer", 12, 3, { {
  ".....oyyyw..",
  "rooooyywwwww",
  ".....oyyyw..",
} }, out)

strip("muzzle_flare", 9, 9, {
  {
    "....w....",
    "...wyw...",
    "..wyyyw..",
    ".wyywyyw.",
    "wyywwwyyw",
    ".wyywyyw.",
    "..wyyyw..",
    "...wyw...",
    "....w....",
  },
  {
    ".........",
    "....o....",
    "...oyo...",
    "..oywyo..",
    ".oywwwyo.",
    "..oywyo..",
    "...oyo...",
    "....o....",
    ".........",
  },
}, out)

strip("casing", 4, 2, { {
  "hYYy",
  "hhYh",
} }, out)

local smoke = {
  "..sss..",
  ".swsss.",
  "swwsssS",
  "sssssSS",
  "ssssSSS",
  ".sSSSS.",
  "..SSS..",
}
strip("smoke_puff", 7, 7, {
  smoke,
  remap(smoke, { s = "S", w = "s", S = "d" }),
  {
    ".......",
    "..SSS..",
    ".SsSSd.",
    ".SSSdd.",
    ".SSddd.",
    "..ddd..",
    ".......",
  },
}, out)

strip("goo", 16, 9, {
  {
    "......ss........",
    "..s..ssSs...s...",
    ".....sssSss.....",
    "...ssswssssSs...",
    "..sswwsssssSSs..",
    "...sssssssSSs.s.",
    "s...sSssSSs.....",
    ".....sSSs.......",
    "................",
  },
  {
    "................",
    ".....ssssss.....",
    "...ssswwsssss...",
    "..sswwssssssSs..",
    "..sssssssssSSs..",
    "...sssssssSSs...",
    ".....sSSSSs.....",
    "................",
    "................",
  },
  {
    "..s.........s...",
    "....ss...ss.....",
    "...sswsssSss..s.",
    ".s.sssssssSs....",
    "...ssSssssSSs...",
    "....sSSs.sSs..s.",
    "..s..........s..",
    "................",
    "................",
  },
}, out)

strip("droplet", 3, 3, { {
  ".s.",
  "sws",
  ".s.",
} }, out)

-- XP gems: one shape, three colour tiers, two shimmer frames each.
local GEM = {
  {
    "...k...",
    "..kAk..",
    ".kAWMk.",
    "kAAMMDk",
    ".kMMDk.",
    "..kDk..",
    "...k...",
  },
  {
    "...k...",
    "..kWk..",
    ".kAAMk.",
    "kAAMMDk",
    ".kMMDk.",
    "..kDk..",
    "...k...",
  },
}
local tiers = {
  gem_small = { A = "c", M = "b", D = "B", W = "w" },
  gem_medium = { A = "l", M = "g", D = "t", W = "w" },
  gem_large = { A = "y", M = "o", D = "r", W = "w" },
}
for name, map in pairs(tiers) do
  strip(name, 7, 7, { remap(GEM[1], map), remap(GEM[2], map) }, pick)
end

strip("heart_pickup", 9, 8, { {
  ".kkk.kkk.",
  "kwrrkrrrk",
  "krrrrrrpk",
  "krrrrrrpk",
  ".krrrrpk.",
  "..krrpk..",
  "...kpk...",
  "....k....",
} }, pick)

strip("magnet_pickup", 9, 8, { {
  ".kkk.kkk.",
  "kwsk.kssk",
  "kSSk.kSSk",
  "kork.kork",
  "kork.kork",
  "korrkrrpk",
  ".korrrpk.",
  "..kkkkk..",
} }, pick)

strip("orb", 9, 9, {
  {
    "...BBB...",
    "..BbbbB..",
    ".BbcccbB.",
    "BbcwwccbB",
    "BbcwwwcbB",
    "BbccwccbB",
    ".BbcccbB.",
    "..BbbbB..",
    "...BBB...",
  },
  {
    "...BBB...",
    "..BbbbB..",
    ".BbccwbB.",
    "BbccwwcbB",
    "BbcwwwcbB",
    "BbcccccbB",
    ".BbcccbB.",
    "..BbbbB..",
    "...BBB...",
  },
  {
    ".........",
    "...BBB...",
    "..BcccB..",
    ".BcwwccB.",
    ".BcwwwcB.",
    ".BccwccB.",
    "..BcccB..",
    "...BBB...",
    ".........",
  },
}, out)

local DRONE_BODY = {
  "....kkkk....",
  "...kSssSk...",
  "..kSsswsSk..",
  "..kSsrrsSk..",
  "..kSSssSSk..",
  "...kkSSkk...",
  "....k..k....",
  "...kk..kk...",
}
local function drone(rotor)
  local grid = { rotor }
  for _, row in ipairs(DRONE_BODY) do grid[#grid + 1] = row end
  return grid
end
strip("drone", 12, 9, { drone("ssss....ssss"), drone("..ss....ss..") }, out)

-- Sky lightning: hand-placed zigzag paths, drawn core -> glow -> halo.
local BOLT_W, BOLT_H = 11, 40
local paths = {
  { 5, 5, 5, 6, 7, 8, 8, 8, 5, 3, 2, 2, 2, 3, 3, 6, 8, 8, 8, 7, 4, 3, 3, 3, 4, 6, 8, 8, 7, 4, 2, 2, 2, 3, 5, 6, 6, 6, 5, 5 },
  { 5, 5, 4, 3, 2, 2, 2, 4, 7, 8, 8, 8, 7, 4, 3, 3, 3, 5, 7, 8, 8, 6, 3, 2, 2, 2, 4, 6, 7, 7, 7, 5, 3, 3, 4, 5, 5, 5, 5, 5 },
}
local spr = Sprite(BOLT_W, BOLT_H, ColorMode.RGB)
spr:newEmptyFrame()
for f, path in ipairs(paths) do
  local cel = spr:newCel(spr.layers[1], spr.frames[f])
  local layers = { { 2, "b" }, { 1, "c" }, { 0, "w" } }
  for _, layer in ipairs(layers) do
    for y = 0, BOLT_H - 1 do
      local cx = path[y + 1]
      local prev_x = path[math.max(1, y)]
      local spread = layer[1] + ((y >= BOLT_H - 4) and 1 or 0)
      -- Join sideways jumps so the bolt reads as sharp, connected kinks.
      for x = math.min(cx, prev_x) - spread, math.max(cx, prev_x) + spread do
        if x >= 0 and x < BOLT_W then
          cel.image:drawPixel(x, y, px.hex_to_color(px.palette[layer[2]]))
        end
      end
    end
  end
end
spr:saveAs(src .. "sky_bolt.aseprite")
app.command.ExportSpriteSheet {
  ui = false, askOverwrite = false, type = SpriteSheetType.HORIZONTAL,
  textureFilename = out .. "sky_bolt.png",
}
spr:close()
print("juice built")

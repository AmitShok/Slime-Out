-- Explosion animation (48x48 x 8) and slime palette-swap variants.
-- Run: Aseprite.exe -b --script-param root=<project> --script build_fx_enemies.lua
local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local px = require("pixel_lib")

local function col(key)
  local hex = px.palette[key]
  return app.pixelColor.rgba(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), 255)
end

-- Explosion -------------------------------------------------------------
-- Each frame is a list of puff clusters. A cluster is cel-shaded as one
-- mass: shadow silhouette first, then a mid tone nudged up-left, then a
-- highlight core, so overlapping puffs read as a single billowing shape.
local SIZE = 48
local frames = {
  { clusters = {
      { ramp = { "o", "y", "w" }, puffs = { { 24, 24, 6 } } },
    },
    sparks = {},
  },
  { clusters = {
      { ramp = { "o", "y", "w" }, puffs = { { 24, 24, 10 }, { 24, 14, 5 }, { 33, 19, 5 }, { 33, 29, 5 }, { 24, 34, 5 }, { 15, 29, 5 }, { 15, 19, 5 } } },
    },
    sparks = { { 6, 10, "y" }, { 41, 8, "y" }, { 43, 37, "o" }, { 5, 39, "o" }, { 24, 3, "y" } },
  },
  { clusters = {
      { ramp = { "r", "o", "y" }, puffs = { { 24, 23, 12 }, { 14, 19, 7 }, { 34, 18, 8 }, { 33, 32, 7 }, { 15, 31, 7 }, { 24, 11, 6 }, { 24, 35, 6 } } },
      { ramp = { "y", "y", "w" }, puffs = { { 23, 22, 6 }, { 30, 20, 3 } } },
    },
    sparks = { { 3, 7, "y" }, { 44, 5, "o" }, { 45, 41, "y" }, { 2, 42, "o" }, { 24, 1, "o" }, { 46, 22, "y" } },
  },
  { clusters = {
      { ramp = { "p", "r", "o" }, puffs = { { 24, 23, 12 }, { 13, 18, 8 }, { 35, 17, 8 }, { 34, 33, 8 }, { 14, 32, 8 }, { 24, 9, 7 }, { 24, 37, 7 } } },
      { ramp = { "o", "y", "y" }, puffs = { { 22, 21, 5 }, { 31, 25, 3 }, { 15, 18, 2 } } },
    },
    sparks = { { 1, 5, "o" }, { 46, 3, "r" }, { 47, 44, "o" }, { 0, 45, "r" } },
  },
  { clusters = {
      { ramp = { "k", "d", "S" }, puffs = { { 13, 17, 8 }, { 35, 15, 8 }, { 34, 33, 8 }, { 14, 32, 8 }, { 24, 9, 7 }, { 24, 38, 7 }, { 24, 24, 9 } } },
      { ramp = { "r", "o", "y" }, puffs = { { 23, 23, 4 }, { 31, 28, 2 } } },
    },
    sparks = { { 20, 30, "o" }, { 29, 17, "o" }, { 12, 22, "r" } },
  },
  { clusters = {
      { ramp = { "d", "S", "s" }, puffs = { { 12, 14, 6 }, { 36, 12, 6 }, { 35, 31, 5 }, { 13, 30, 5 }, { 24, 6, 5 }, { 24, 24, 6 }, { 18, 19, 4 }, { 30, 18, 4 } } },
      { ramp = { "p", "r", "r" }, puffs = { { 24, 25, 2 } } },
    },
    sparks = {},
  },
  { clusters = {
      { ramp = { "d", "S", "s" }, puffs = { { 11, 10, 4 }, { 37, 8, 4 }, { 36, 26, 3 }, { 12, 25, 3 }, { 24, 4, 3 }, { 24, 19, 4 }, { 17, 14, 3 }, { 31, 13, 3 } } },
    },
    sparks = {},
  },
  { clusters = {
      { ramp = { "S", "s", "s" }, puffs = { { 10, 7, 2 }, { 38, 5, 2 }, { 24, 15, 2 }, { 24, 2, 1 } } },
    },
    sparks = {},
  },
}

local function inside(puffs, x, y, shrink, shift_scale, radius_scale)
  for _, p in ipairs(puffs) do
    local r = p[3] * (radius_scale or 1) - (shrink or 0)
    if r > 0 then
      local s = (shift_scale or 0) * p[3]
      local dx = x + 0.5 - (p[1] - s)
      local dy = y + 0.5 - (p[2] - s)
      if dx * dx + dy * dy <= r * r then return true end
    end
  end
  return false
end

local function draw_cluster(image, cluster)
  local dark, mid, light = col(cluster.ramp[1]), col(cluster.ramp[2]), col(cluster.ramp[3])
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do
      if inside(cluster.puffs, x, y) then
        local c = dark
        if inside(cluster.puffs, x, y, 1, 0.12) then c = mid end
        if inside(cluster.puffs, x, y, 0, 0.3, 0.5) then c = light end
        image:drawPixel(x, y, c)
      end
    end
  end
end

local spr = Sprite(SIZE, SIZE, ColorMode.RGB)
for i = 2, #frames do spr:newEmptyFrame() end
for i, f in ipairs(frames) do
  local cel = spr:newCel(spr.layers[1], spr.frames[i])
  for _, cluster in ipairs(f.clusters) do draw_cluster(cel.image, cluster) end
  for _, s in ipairs(f.sparks) do
    cel.image:drawPixel(s[1], s[2], col(s[3]))
    cel.image:drawPixel(s[1] + 1, s[2], col(s[3]))
  end
  spr.frames[i].duration = (i <= 2) and 0.04 or 0.07
end
local tag = spr:newTag(1, #frames)
tag.name = "explode"
spr:saveAs(root .. "/art_src/explosion.aseprite")
app.command.ExportSpriteSheet {
  ui = false, askOverwrite = false, type = SpriteSheetType.HORIZONTAL,
  textureFilename = root .. "/assets/floor38/fx/explosion.png",
}
spr:close()

-- Slime variants --------------------------------------------------------
local SLIME_SRC = { "65b1b8", "4d8ab3", "425b9e", "33418a", "1d235d", "9e2e46" }
local variants = {
  slime_swift = { "a7f070", "6cc75a", "38b764", "257179", "16343c", "9e2e46" },
  slime_brute = { "ef7d57", "d9594c", "b13e53", "7e2a4f", "3a1230", "3a1230" },
  slime_king  = { "c890e8", "a66ccf", "8350b0", "5d3290", "2c1450", "9e2e46" },
  slime_spitter  = { "ffe27a", "f2bd4b", "d9932e", "a3601f", "4a2410", "5d275d" },
  slime_splitter = { "f5a3c7", "e07aa8", "c0508a", "8a2f68", "3f1030", "5d275d" },
  slime_charger  = { "c0cbdc", "8b9bb4", "5a6988", "3a4466", "181425", "9e2e46" },
}

local function hex_rgb(hex)
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local src_path = root .. "/assets/mystic forest/sprites/characters/slime.png"
for name, targets in pairs(variants) do
  local s = app.open(src_path)
  local img = s.cels[1].image
  local map = {}
  for i, from in ipairs(SLIME_SRC) do
    local r, g, b = hex_rgb(from)
    map[r * 65536 + g * 256 + b] = { hex_rgb(targets[i]) }
  end
  for it in img:pixels() do
    local v = it()
    local a = app.pixelColor.rgbaA(v)
    if a > 0 then
      local key = app.pixelColor.rgbaR(v) * 65536 + app.pixelColor.rgbaG(v) * 256 + app.pixelColor.rgbaB(v)
      local t = map[key]
      if t then it(app.pixelColor.rgba(t[1], t[2], t[3], a)) end
    end
  end
  s:saveAs(root .. "/art_src/" .. name .. ".aseprite")
  s:saveCopyAs(root .. "/assets/floor38/enemies/" .. name .. ".png")
  s:close()
end

local prev = app.params["preview"]
if prev then
  px.preview(root .. "/assets/floor38/fx/explosion.png", prev .. "/explosion_preview.png", 4)
  px.preview(root .. "/assets/floor38/enemies/slime_brute.png", prev .. "/brute_preview.png", 2)
end
print("fx + enemies built")

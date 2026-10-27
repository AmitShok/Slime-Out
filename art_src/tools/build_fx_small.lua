-- Small hand-authored FX sprites + shockwave ring.
-- Run: Aseprite.exe -b --script-param root=<project> --script build_fx_small.lua
local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local px = require("pixel_lib")
local out = root .. "/assets/floor38/fx/"
local src = root .. "/art_src/"

px.build_strip({
  { name = "spark_a", grid = {
    "...c...",
    "...c...",
    "..cwc..",
    "ccwwwcc",
    "..cwc..",
    "...c...",
    "...c...",
  }},
  { name = "spark_b", grid = {
    "c.....c",
    ".c...c.",
    "..cwc..",
    "..www..",
    "..cwc..",
    ".c...c.",
    "c.....c",
  }},
  { name = "spark_c", grid = {
    ".......",
    ".......",
    "...b...",
    "..bcb..",
    "...b...",
    ".......",
    ".......",
  }},
}, 7, 7, src .. "spark.aseprite", out .. "spark.png")

px.build_strip({
  { name = "flame_1", grid = {
    "...o...",
    "...o...",
    "..oyo..",
    "..oyo..",
    ".oyyyo.",
    ".oywyo.",
    "roywyor",
    ".royor.",
    "..rrr..",
  }},
  { name = "flame_2", grid = {
    "..o....",
    "...o...",
    "..oo...",
    "..oyo..",
    ".oyyo..",
    ".oywyo.",
    "roywyor",
    ".royor.",
    "..rrr..",
  }},
  { name = "flame_3", grid = {
    "....o..",
    "...o...",
    "...oo..",
    "..oyo..",
    "..oyyo.",
    ".oywyo.",
    "roywyor",
    ".royor.",
    "..rrr..",
  }},
  { name = "flame_4", grid = {
    ".......",
    "...o...",
    "..oyo..",
    "..oyo..",
    ".oyyyo.",
    ".oywyo.",
    "roywyor",
    ".royor.",
    "..rrr..",
  }},
}, 7, 9, src .. "flame.aseprite", out .. "flame.png")

px.build_strip({
  { name = "glob_1", grid = {
    "..kkkk..",
    ".kyyyyk.",
    "kywyyYYk",
    "kyyyyYYk",
    "kyyyYYYk",
    "kYyyYYYk",
    ".kYYYhk.",
    "..kkkk..",
  }},
  { name = "glob_2", grid = {
    "........",
    "..kkkk..",
    ".kyyyyk.",
    "kywyyYYk",
    "kyyyYYYk",
    "kYYYYYhk",
    ".kkkkkk.",
    "........",
  }},
}, 8, 8, src .. "acid_glob.aseprite", out .. "acid_glob.png")

px.build_strip({
  { name = "splat_1", grid = {
    "................",
    "......kkkk......",
    "....kkyyyYkk....",
    "...kyywyyYYhk...",
    "...khYYYYYhhk...",
    "....kkhhhhkk....",
    "......kkkk......",
    "................",
  }},
  { name = "splat_2", grid = {
    "..y..........y..",
    "................",
    ".kk..kkkkkk..kk.",
    "kyYkkyyywyYkkYhk",
    "khhkYYYYYYhhkhhk",
    ".kk.kkhhhhkk.kk.",
    "................",
    "....y......y....",
  }},
  { name = "splat_3", grid = {
    "................",
    "................",
    "................",
    "..kkkkkkkkkkkk..",
    ".khYYhhYYhhhYhk.",
    "..kkkkkkkkkkkk..",
    "................",
    "................",
  }},
}, 16, 8, src .. "acid_splat.aseprite", out .. "acid_splat.png")

px.build_strip({
  { name = "marker_1", grid = {
    "....rrrrrrrr....",
    "..rr........rr..",
    ".r............r.",
    "r..............r",
    "r..............r",
    ".r............r.",
    "..rr........rr..",
    "....rrrrrrrr....",
  }},
  { name = "marker_2", grid = {
    "................",
    "....oooooooo....",
    "..oo........oo..",
    ".o............o.",
    ".o............o.",
    "..oo........oo..",
    "....oooooooo....",
    "................",
  }},
}, 16, 8, src .. "target_marker.aseprite", out .. "target_marker.png")

px.build_strip({
  { name = "alert", grid = {
    ".kkk.",
    "kwyyk",
    "kyyyk",
    ".kyk.",
    ".kyk.",
    "..k..",
    ".kkk.",
    ".kyk.",
    ".kkk.",
  }},
}, 5, 9, src .. "alert.aseprite", out .. "alert.png")

-- Shockwave: expanding ring, bright core edge fading to blue.
local RING = 40
local rings = {
  { r = 6, t = 3, outer = "c", inner = "w" },
  { r = 10, t = 3, outer = "c", inner = "w" },
  { r = 14, t = 2, outer = "b", inner = "c" },
  { r = 17, t = 2, outer = "B", inner = "b" },
  { r = 19, t = 1, outer = "S", inner = "S" },
}
local spr = Sprite(RING, RING, ColorMode.RGB)
for i = 2, #rings do spr:newEmptyFrame() end
for i, ring in ipairs(rings) do
  local cel = spr:newCel(spr.layers[1], spr.frames[i])
  for y = 0, RING - 1 do
    for x = 0, RING - 1 do
      local dx, dy = x + 0.5 - RING / 2, y + 0.5 - RING / 2
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= ring.r and d > ring.r - ring.t then
        local key = (d > ring.r - 1) and ring.outer or ring.inner
        cel.image:drawPixel(x, y, px.hex_to_color(px.palette[key]))
      end
    end
  end
  spr.frames[i].duration = 0.05
end
spr:newTag(1, #rings).name = "shockwave"
spr:saveAs(src .. "shockwave.aseprite")
app.command.ExportSpriteSheet {
  ui = false, askOverwrite = false, type = SpriteSheetType.HORIZONTAL,
  textureFilename = out .. "shockwave.png",
}
spr:close()
print("small fx built")

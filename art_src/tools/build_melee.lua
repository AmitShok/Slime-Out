-- Knight / Engineer content: melee weapons (drawn pointing right, grip on
-- the left), the slash arc FX, the flying sword wave and the icons for the
-- character-specific upgrades.
-- Run: Aseprite.exe -b --script-param root=<project> --script build_melee.lua

local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local lib = require("pixel_lib")

lib.palette["A"] = "eef2f7" -- steel highlight
lib.palette["a"] = "b4bdcc" -- steel
lib.palette["m"] = "7a869c" -- steel shade
lib.palette["M"] = "48506a" -- steel dark
lib.palette["W"] = "9a6a3f" -- wood
lib.palette["X"] = "6a4528" -- wood shade
lib.palette["L"] = "7a2838" -- grip wrap

local function pad(grid, w, h)
  local out = {}
  for i = 1, h do
    local row = grid[i] or ""
    if #row > w then error("row too wide (" .. #row .. "): " .. row) end
    out[i] = row .. string.rep(".", w - #row)
  end
  return out
end

local function single(name, grid, w, h)
  lib.build_strip({ { name = name, grid = pad(grid, w, h) } }, w, h,
    root .. "/art_src/" .. name .. ".aseprite", root .. "/assets/floor38/melee/" .. name .. ".png")
  lib.preview(root .. "/assets/floor38/melee/" .. name .. ".png", root .. "/art_src/preview_" .. name .. ".png", 8)
end

-- Weapons ---------------------------------------------------------------------
-- Sword: grip (1,3), tip (21,3)
single("sword", {
  "....kk",
  "...kYYk" .. string.rep("k", 13),
  "kkkkYYk" .. string.rep("A", 13) .. "kk",
  "kLXLYYk" .. string.rep("a", 14) .. "k",
  "kkkkYYk" .. string.rep("m", 13) .. "kk",
  "...kYYk" .. string.rep("k", 13),
  "....kk",
}, 22, 7)

-- Spear: grip (6,2), tip (28,2)
single("spear", {
  string.rep(".", 21) .. "kkk",
  string.rep("k", 21) .. "kAAkk",
  "k" .. string.rep("W", 19) .. "XYaaaAAk",
  string.rep("k", 21) .. "kmmkk",
  string.rep(".", 21) .. "kkk",
}, 29, 5)

-- Battle axe: grip (3,5), tip (19,5)
single("battle_axe", {
  "..............kkk",
  ".............kAAAk",
  ".............kAaaAk",
  "..............kaaaAk",
  "kkkkkkkkkkkkkkkmaaak",
  "kLXLWWWWWWWWWWXYmaak",
  "kkkkkkkkkkkkkkkmaaak",
  "..............kaaaAk",
  ".............kAaaAk",
  ".............kAAAk",
  "..............kkk",
}, 20, 11)

-- War hammer: grip (3,4), tip (19,4)
single("war_hammer", {
  "...............kkkk",
  "..............kAAAAk",
  "..............kAaaak",
  "kkkkkkkkkkkkkkkAaamk",
  "kLXLWWWWWWWWWXYAamMk",
  "kkkkkkkkkkkkkkkaammk",
  "..............kammMk",
  "..............kmmMMk",
  "...............kkkk",
}, 20, 9)

-- Slash arc: 4 frames, 40x40, pivot = (6,20) (the wielder). White/silver so
-- the game can tint it per weapon (and push it into HDR for bloom).
do
  local W, H, CX, CY, R = 40, 40, 6, 20, 30
  local frames = {}
  local spans = { { -70, -20, 1.0 }, { -70, 70, 1.0 }, { -10, 70, 0.75 }, { 30, 70, 0.4 } }
  for f, span in ipairs(spans) do
    local grid = {}
    for y = 0, H - 1 do
      local row = {}
      for x = 0, W - 1 do
        local dx, dy = x + 0.5 - CX, y + 0.5 - CY
        local d = math.sqrt(dx * dx + dy * dy)
        local a = math.deg(math.atan(dy, dx))
        local ch = "."
        local thick = 6 * span[3]
        if a >= span[1] and a <= span[2] and d <= R and d >= R - thick then
          local edge = R - d
          -- Thicker in the middle of the swing, tapering to the ends.
          local mid = 1.0 - math.abs((a - (span[1] + span[2]) * 0.5) / ((span[2] - span[1]) * 0.5 + 0.001))
          if edge < 1.2 then ch = "w"
          elseif edge < 2.6 and mid > 0.15 then ch = "s"
          elseif edge < thick * (0.35 + mid * 0.65) then ch = "S"
          end
          if f == 4 and (x + y) % 2 == 0 then ch = "." end
        end
        row[#row + 1] = ch
      end
      grid[#grid + 1] = table.concat(row)
    end
    frames[f] = { name = "slash" .. f, grid = grid }
  end
  lib.build_strip(frames, W, H, root .. "/art_src/slash.aseprite", root .. "/assets/floor38/melee/slash.png")
  lib.preview(root .. "/assets/floor38/melee/slash.png", root .. "/art_src/preview_slash.png", 6)
end

-- Flying sword wave (Sword Wave upgrade), travels to the right.
single("sword_wave", {
  "..kkk",
  "...kwck",
  "....kwck",
  ".....kwck",
  ".....kwwck",
  "......kwck",
  "......kwck",
  "......kwck",
  ".....kwwck",
  ".....kwck",
  "....kwck",
  "...kwck",
  "..kkk",
}, 11, 13)

-- Upgrade icons (16x16, one row) ----------------------------------------------
local function blank16()
  local g = {}
  for y = 1, 16 do g[y] = string.rep(".", 16) end
  return g
end
local function stamp(g, motif, ox, oy)
  for y, row in ipairs(motif) do
    for x = 1, #row do
      local ch = row:sub(x, x)
      if ch ~= "." then
        local gy, gx = oy + y, ox + x
        if gy >= 1 and gy <= 16 and gx >= 1 and gx <= 16 then
          g[gy] = g[gy]:sub(1, gx - 1) .. ch .. g[gy]:sub(gx + 1)
        end
      end
    end
  end
  return g
end

local SWORD = {
  "..........kk",
  ".........kwk",
  "........kwAk",
  ".......kwAk",
  "......kwAk",
  ".....kwAk",
  "..k.kwAk",
  "..kkwAk",
  "...kYk",
  "..kYkYk",
  ".kLk.kk",
  "kLk",
  "kk",
}
local SPEAR = {
  "..........kk",
  ".........kAk",
  "........kAAk",
  ".......kAak",
  "......kWk",
  ".....kWk",
  "....kWk",
  "...kWk",
  "..kWk",
  ".kWk",
  "kWk",
  "kk",
}
local SPARK = { "..y..", ".yyy.", "yywyy", ".yyy.", "..y.." }
local DROP = { "..k..", ".krk.", ".krk.", "krrrk", "krwrk", "krrrk", ".kkk." }
local FLAME = { "...k...", "..kyk..", ".kyyok.", ".koyok.", "kooyrok", "koyyrok", "kroorrk", ".krrrk.", "..kkk.." }
local CRESCENT = {
  "..kkk", "...kcck", "....kcck", ".....kcck", "......kcwk", "......kcwk",
  "......kcwk", "......kcwk", ".....kcck", "....kcck", "...kcck", "..kkk",
}
local ARC = {
  "kkk", ".kssk", "..kssk", "...kswk", "....kswk", "....kswk",
  "....kswk", "....kswk", "...kswk", "..kssk", ".kssk", "kkk",
}
local SHIELD = {
  ".kkkkkkkkkk.", "kwwwwssssssk", "kwsssssssSSk", "kwssbbbbsSSk", "kwssbBBbsSSk",
  "kwssbBBbsSSk", ".kssbbbbsSk.", ".kSssssssSk.", "..kSssssSk..", "...kSssSk...", "....kSSk....", ".....kk.....",
}
local DRONE = { "kkk....kkk", ".k.kkkk.k.", "..kssssk..", ".kscbbcsk.", "..kSSSSk..", "...kkkk..." }
local BOLT = { "...ky", "..kyk", ".kyk.", "kyyyk", ".kyk.", "kyk..", "yk..." }
local BURST = { "o..o..o", ".o.o.o.", "..yyy..", "ooywyoo", "..yyy..", ".o.o.o.", "o..o..o" }
local PLUS = { ".kk.", "kllk", "kllk", ".kk." }
local PLUS_BIG = { "..kk..", "..kl..", "kkllkk", "kllllk", "..kl..", "..kk.." }
local LINES = { "www..", "", ".sss.", "", "ww..." }
local BOMB = { "...ky", "..kk.", ".kkkk", "kddddk", "kdSddk", "kddddk", ".kkkk." }

local icons = {
  { name = "whetstone", parts = { { SWORD, 2, 2 }, { SPARK, 10, 9 } } },
  { name = "swift_strikes", parts = { { SWORD, 4, 1 }, { LINES, 0, 9 } } },
  { name = "long_reach", parts = { { SPEAR, 2, 2 } } },
  { name = "wide_arc", parts = { { ARC, 7, 2 }, { SWORD, 0, 3 } } },
  { name = "heavy_blows", parts = { { SWORD, 1, 3 }, { BURST, 8, 0 } } },
  { name = "vampiric_edge", parts = { { SWORD, 1, 1 }, { DROP, 10, 8 } } },
  { name = "flame_edge", parts = { { SWORD, 1, 3 }, { FLAME, 8, 0 } } },
  { name = "iron_skin", parts = { { SHIELD, 2, 2 } } },
  { name = "sword_wave", parts = { { CRESCENT, 6, 2 }, { CRESCENT, 1, 2 } } },
  { name = "overclock", parts = { { DRONE, 1, 7 }, { BOLT, 10, 1 } } },
  { name = "heavy_payload", parts = { { DRONE, 0, 1 }, { BOMB, 8, 8 } } },
  { name = "drone_bay", parts = { { DRONE, 0, 4 }, { PLUS_BIG, 10, 0 } } },
}
local entries = {}
for _, icon in ipairs(icons) do
  local g = blank16()
  for _, part in ipairs(icon.parts) do stamp(g, part[1], part[2], part[3]) end
  entries[#entries + 1] = { name = icon.name, grid = g }
end
lib.build_strip(entries, 16, 16, root .. "/art_src/upgrade_icons_2.aseprite", root .. "/assets/floor38/ui/upgrade_icons_2.png")
lib.preview(root .. "/assets/floor38/ui/upgrade_icons_2.png", root .. "/art_src/preview_upgrade_icons_2.png", 6)
print("melee art built")

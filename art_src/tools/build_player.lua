-- Character body sheets (Gunner, Knight, Engineer): 32x32 frames, sel-out (coloured) outlines, 4-tone
-- material ramps, no arms (hands are drawn on the gun in game).
-- Rows: 0 idle_down, 1 idle_side, 2 idle_up (8 frames, blink on 7)
--       3 run_down, 4 run_side, 5 run_up (6 frames), 6 death (4 frames)
-- Side frames face right.
-- Run: Aseprite.exe -b --script-param root=<project> --script build_player.lua
local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local px = require("pixel_lib")

local SIZE = 32
local FEET_Y = 30

-- Hero palette (independent of the shared UI palette).
local GUNNER_PAL = {
  S = "fde0c4", s = "f2c09a", z = "d4936d", Z = "a8644a",           -- skin
  H = "a6774c", h = "7a5236", j = "553621", J = "33201a",           -- hair
  w = "f4f4f4", e = "1a1c2c", b = "4d8ab3",                         -- eyes
  R = "e05a5a", r = "b13e53", q = "7a2838",                         -- scarf
  G = "b5c47a", g = "8a9c56", v = "5f7038", V = "3a4626",           -- jacket
  L = "a0673f", l = "6e4428", Y = "ffcd75",                         -- leather, buckle
  P = "5a74c0", p = "3b5196", n = "2a3a70", N = "1b2548",           -- trousers
  K = "6b5545", k = "45362c", x = "2a201b",                         -- boots
  ["_"] = "1a1c2c60",                                               -- ground shadow
}

local GUNNER_HEAD = {
  down = {
    "....JJJJJJ....",
    "..JJhHHHhhJJ..",
    ".JhHHhhhhhhhJ.",
    ".JhHhhhhhhhjJ.",
    "JhhhhhhhhhhjjJ",
    "JhjhhjhhhjhjjJ",
    "JjhjssjssjsjjJ",
    "JjsSssssssSsjJ",
    "JzssewsswesszJ",
    "JzssebssbesszJ",
    "JZzssszzssszZJ",
    ".JZzsssssszZJ.",
    "..JJZZZZZZJJ..",
  },
  side = {
    "...JJJJJJ.....",
    "..JhHHHhhJJ...",
    ".JhHHhhhhhhJ..",
    "JhhHhhhhhhhjJ.",
    "JhhhhhhhjjjjJ.",
    "JhjhhhhjsSsjJ.",
    "JjhjhhjssSssZ.",
    "JjhhjzZssswesZ",
    "JjhjzZzsssbeZ.",
    ".JjjzzssssssZ.",
    ".JjZzsssssszZ.",
    "..JZzsssszZ...",
    "...JZZZZZZ....",
  },
  up = {
    "....JJJJJJ....",
    "..JJhHHHhhJJ..",
    ".JhHHhhhhhhhJ.",
    ".JhHhhhhhhhjJ.",
    "JhhhhhhhhhhjjJ",
    "JhHhhhhhhhjjjJ",
    "JhhhhjhhhhjjjJ",
    "JjhhhjhhhjjjjJ",
    "JjjhhjhhjjjjjJ",
    "JZjjjjjjjjjjZJ",
    ".JZjjjjjjjjZJ.",
    ".JZZzssssszZJ.",
    "..JJZZZZZZJJ..",
  },
}

local GUNNER_TORSO = {
  down = {
    "..qrrRRrrq..",
    ".VgqrrrrqgV.",
    "VGggvqqvgLgV",
    "VGgggvvgLggV",
    "VGgggvgLgggV",
    "VGggvgLggvgV",
    "VvgvgLggggvV",
    "VllllYYllllV",
    "NpppppppppnN",
  },
  side = {
    "...qrrRrq...",
    ".qqVrrrrqV..",
    "lLVGgggvgV..",
    "lLVGgggvlV..",
    "lLVGggvgLV..",
    "llVGggglvV..",
    ".lVvgggvvV..",
    "..VlllllYV..",
    "..NppppnnN..",
  },
  up = {
    "..qrrrrrrq..",
    ".VgqrrrrqgV.",
    "VGgllllllgvV",
    "VGglLLLLlgvV",
    "VGglLLLLlgvV",
    "VGgllYYllgvV",
    "VvglllllllvV",
    "VllllllllllV",
    "NpppppppppnN",
  },
}

local HIPS_FRONT = { ".NppppppppN." }
local HIPS_SIDE = { "...NppppN..." }

-- Front legs (rows 1..6 of the 7-row leg area); left = cols 0-5, right = 6-11.
local LEG_FRONT_L = {
  ".NpPN.",
  ".NpPN.",
  ".NnnN.",
  ".xkKx.",
  "xkKkx.",
  ".xxxx.",
}
local LEG_FRONT_R = {
  ".NpPN.",
  ".NpPN.",
  ".NnnN.",
  ".xkKx.",
  ".xkKkx",
  ".xxxx.",
}

local LEG_SIDE = {
  "NpPnN.",
  "NpPnN.",
  "NpPnN.",
  "NnnnN.",
  "xkKkx.",
  "xkKkkx",
  "xxxxxx",
}

-- The far leg is one shade darker so the stride reads in depth.
local function darker(grid)
  local map = { P = "p", p = "n", n = "N", K = "k", k = "x" }
  local out = {}
  for i, row in ipairs(grid) do out[i] = row:gsub("[Ppnkk K]", function(c) return map[c] or c end) end
  return out
end
local LEG_SIDE_FAR = darker(LEG_SIDE)

local function blink(head, eye_row)
  local out = {}
  for i, row in ipairs(head) do out[i] = row end
  out[eye_row] = out[eye_row]:gsub("[ew]", "s")
  out[eye_row + 1] = out[eye_row + 1]:gsub("[eb]", "Z")
  return out
end

-- Knight: plumed great-helm with a visor slit, breastplate, tabard, cape.
-- Slots: armour = G g v V, plume = H h j J, tabard/cape = R r q, skin = S s z Z.
local KNIGHT_PAL = {
  S = "fde0c4", s = "f2c09a", z = "d4936d", Z = "a8644a",
  H = "f0605a", h = "c23d4a", j = "8a2438", J = "4f1a2b",
  w = "fff4c2", e = "1a1c2c", b = "4d8ab3",
  R = "5b8ee6", r = "3b5dc9", q = "29366f",
  G = "e4e9f0", g = "a9b3c3", v = "707c92", V = "3c4458",
  L = "8a5a35", l = "5c3a22", Y = "ffcd75",
  P = "9aa3b5", p = "6e7a8f", n = "4b5468", N = "2c3242",
  K = "7a6352", k = "4f3d31", x = "2a201b",
  ["_"] = "1a1c2c60",
}
local KNIGHT_HEAD = {
  down = {
    ".....JhHJ.....",
    "....JhHHhJ....",
    "...VVJjhjVV...",
    "..VgGGggggvV..",
    ".VgGGgggggvvV.",
    ".VgGggggggvvV.",
    ".VgggggggggvV.",
    ".VgVVVVVVVVgV.",
    ".VgVwVVVVwVgV.",
    ".VggggVVggggV.",
    ".VvgggVVgggvV.",
    "..VvvvvvvvvV..",
    "...VVVVVVVV...",
  },
  side = {
    "...JhHJ.......",
    "..JhHHhJ......",
    "..VJjhjVVV....",
    ".VgGGggggvV...",
    "VgGGgggggvvV..",
    "VgGggggggvvV..",
    "VgggggggggvV..",
    "VggggggVVVVVV.",
    "VgggggVVwVVVV.",
    "VvgggggVVVVVV.",
    "VvggggggggvV..",
    ".VvvvvvvvvV...",
    "..VVVVVVVV....",
  },
  up = {
    ".....JhHJ.....",
    "....JhHHhJ....",
    "...VVJhhjVV...",
    "..VgGJhhjgvV..",
    ".VgGgJhjjgvvV.",
    ".VgGggJjggvvV.",
    ".VgggggggggvV.",
    ".VggggggggggV.",
    ".VggggggggvgV.",
    ".VvgggggggvvV.",
    ".VvvggggggvvV.",
    "..VvvvvvvvvV..",
    "...VVVVVVVV...",
  },
}
local KNIGHT_TORSO = {
  down = {
    "..VvggggvV..",
    "VGgVrRRrVgGV",
    "VGgVrRRrVggV",
    "VvgVrRRrVgvV",
    "VVgVrRrrVgVV",
    "VvgVrrrrVvvV",
    ".VVVqrrqVVV.",
    ".VllllYYlllV",
    "NpppppppppnN",
  },
  side = {
    "...VvggvV...",
    "..VGGgggvV..",
    ".VGGgggrrV..",
    ".VGggggrrV..",
    ".VGgggvrrV..",
    ".VvgggvrqV..",
    "..VvvvvqqV..",
    "..VllllYlV..",
    "..NppppnnN..",
  },
  up = {
    "..VvggggvV..",
    "VGgrrrrrrgGV",
    "VGgrRRRRrggV",
    "VvgrRRRRrgvV",
    "VVgrRRRrrgVV",
    "VvgrrrrrrvvV",
    ".VVqrrrrqVV.",
    ".VqqrrrrqqV.",
    "NpqqqqqqqqnN",
  },
}
local GAUNTLET_HAND = {
  ".VV.",
  "VGgV",
  "VgvV",
  ".VV.",
}

-- Engineer: cap with goggles, overalls, bandana, tool belt.
-- Slots: overalls = G g v V, hair = H h j J, cap/bandana = R r q, skin = S s z Z.
local ENGINEER_PAL = {
  S = "f0c49a", s = "d9a173", z = "b07448", Z = "7d4d2c",
  H = "6b5442", h = "4d3a2c", j = "33261c", J = "1f1712",
  w = "f4f4f4", e = "1a1c2c", b = "73eff7",
  R = "4fd6c7", r = "2a9d8f", q = "1c5f5a",
  G = "ffb45e", g = "e5862e", v = "a85a1e", V = "5e3012",
  L = "6e5440", l = "4a3628", Y = "ffcd75",
  P = "6f86a6", p = "4f6382", n = "374560", N = "222b3e",
  K = "6b5545", k = "45362c", x = "2a201b",
  ["_"] = "1a1c2c60",
}
local function with_rows(base, top)
  local out = {}
  for i, row in ipairs(base) do out[i] = top[i] or row end
  return out
end
local ENGINEER_HEAD = {
  down = with_rows(GUNNER_HEAD.down, {
    "...qqqqqqqq...",
    "..qrRRRRRrrq..",
    ".qrRRRRrrrrrq.",
    ".qLLbbLLbbLLq.",
    "JhLbwbLLbwbLjJ",
    "JhjLLLhhLLLjjJ",
  }),
  side = with_rows(GUNNER_HEAD.side, {
    "...qqqqqqq....",
    "..qrRRRRRrq...",
    ".qrRRRRRRrrqqq",
    "qLLLLLLLbbLq..",
    "JhhhhhhLbwbL..",
  }),
  up = with_rows(GUNNER_HEAD.up, {
    "...qqqqqqqq...",
    "..qrRRRRRrrq..",
    ".qrRRRRRrrrrq.",
    ".qLLLLLLLLLLq.",
  }),
}
local ENGINEER_TORSO = {
  down = {
    "..qrrRRrrq..",
    ".VgqrrrrqgV.",
    "VGgYgggggYgV",
    "VGgLgggggLgV",
    "VGgLgggggLgV",
    "VGgggLLLggvV",
    "VvgggLYLgvvV",
    "VLLLLLLLLLLV",
    "NpppppppppnN",
  },
  side = GUNNER_TORSO.side,
  up = GUNNER_TORSO.up,
}

local PAL, HEAD, TORSO, HAND = GUNNER_PAL, GUNNER_HEAD, GUNNER_TORSO, SKIN_HAND
local HEAD_BLINK = nil
local SHADOW = {
  ".........______________.........",
  "........________________........",
  ".........______________.........",
}

local SKIN_HAND = {
  ".ZZ.",
  "ZSsZ",
  "ZszZ",
  ".ZZ.",
}

-- Buffer helpers -----------------------------------------------------------
local function blank()
  local buf = {}
  for y = 0, SIZE - 1 do
    buf[y] = {}
    for x = 0, SIZE - 1 do buf[y][x] = "." end
  end
  return buf
end

local function stamp(buf, grid, ox, oy, min_y)
  for y, row in ipairs(grid) do
    for x = 1, #row do
      local ch = row:sub(x, x)
      local by, bx = oy + y - 1, ox + x - 1
      if ch ~= "." and by >= (min_y or 0) and by < SIZE and bx >= 0 and bx < SIZE then
        buf[by][bx] = ch
      end
    end
  end
end

local LEG_Y = FEET_Y - 6       -- leg area top (hips row)
local TORSO_Y = LEG_Y - 8
local HEAD_Y = TORSO_Y - 12

local function front_legs(buf, lift_l, lift_r)
  stamp(buf, LEG_FRONT_L, 10, LEG_Y + 1 - lift_l, LEG_Y + 1)
  stamp(buf, LEG_FRONT_R, 16, LEG_Y + 1 - lift_r, LEG_Y + 1)
  stamp(buf, HIPS_FRONT, 10, LEG_Y)
end

local function side_legs(buf, near_dx, near_lift, far_dx, far_lift)
  stamp(buf, LEG_SIDE_FAR, 13 + far_dx, LEG_Y - far_lift, LEG_Y)
  stamp(buf, LEG_SIDE, 13 + near_dx, LEG_Y - near_lift, LEG_Y)
  stamp(buf, HIPS_SIDE, 10, LEG_Y)
end

local function upper(buf, dir, bob, head)
  stamp(buf, head or HEAD[dir], 9, HEAD_Y + bob)
  stamp(buf, TORSO[dir], 10, TORSO_Y + bob)
end

local function frame(dir, legs_fn, bob, head)
  local buf = blank()
  legs_fn(buf)
  upper(buf, dir, bob, head)
  return buf
end

local function with_shadow(buf, wide)
  local out = blank()
  stamp(out, SHADOW, 0, FEET_Y - 1)
  if wide then
    stamp(out, SHADOW, -4, FEET_Y - 1)
    stamp(out, SHADOW, 4, FEET_Y - 1)
  end
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do
      if buf[y][x] ~= "." then out[y][x] = buf[y][x] end
    end
  end
  return out
end

local function lying(buf)
  local rot = blank()
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do rot[x][SIZE - 1 - y] = buf[y][x] end
  end
  local max_y = 0
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do if rot[y][x] ~= "." then max_y = y end end
  end
  local out = blank()
  local shift = FEET_Y - max_y
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do
      local sy = y - shift
      if sy >= 0 and sy < SIZE then out[y][x] = rot[sy][x] end
    end
  end
  return out
end

-- Animations ---------------------------------------------------------------
local IDLE_BOB = { 0, 0, 0, 0, 1, 1, 1, 1 }
local RUN_BOB = { 1, 1, 0, 1, 1, 0 }
local FRONT_LIFT_L = { 0, 1, 2, 1, 0, 0 }
local FRONT_LIFT_R = { 1, 0, 0, 0, 1, 2 }
local SIDE_NEAR_DX = { -3, -1, 1, 3, 1, -1 }
local SIDE_NEAR_LIFT = { 0, 1, 1, 0, 0, 0 }
local SIDE_FAR_DX = { 3, 1, -1, -3, -1, 1 }
local SIDE_FAR_LIFT = { 0, 0, 0, 0, 1, 1 }

local function build(def)
PAL, HEAD, TORSO, HAND = def.pal, def.head, def.torso, def.hand
HEAD_BLINK = { down = blink(HEAD.down, 9), side = blink(HEAD.side, 8), up = HEAD.up }
local rows = {}
for _, dir in ipairs({ "down", "side", "up" }) do
  local frames = {}
  for i = 1, 8 do
    local head = (i == 8) and HEAD_BLINK[dir] or HEAD[dir]
    local legs = (dir == "side") and function(b) side_legs(b, 0, 0, 1, 0) end or function(b) front_legs(b, 0, 0) end
    frames[i] = frame(dir, legs, IDLE_BOB[i], head)
  end
  rows[#rows + 1] = frames
end
for _, dir in ipairs({ "down", "side", "up" }) do
  local frames = {}
  for i = 1, 6 do
    local legs
    if dir == "side" then
      legs = function(b) side_legs(b, SIDE_NEAR_DX[i], SIDE_NEAR_LIFT[i], SIDE_FAR_DX[i], SIDE_FAR_LIFT[i]) end
    else
      legs = function(b) front_legs(b, FRONT_LIFT_L[i], FRONT_LIFT_R[i]) end
    end
    frames[i] = frame(dir, legs, RUN_BOB[i])
  end
  rows[#rows + 1] = frames
end

-- Death: flinch, crumple to knees, fall, rest.
local crumple = blank()
front_legs(crumple, 2, 2)
upper(crumple, "down", 4, HEAD_BLINK.down)
local fallen = lying(frame("side", function(b) side_legs(b, 0, 0, 1, 0) end, 0, HEAD_BLINK.side))
rows[#rows + 1] = { frame("down", function(b) front_legs(b, 0, 0) end, 1, HEAD_BLINK.down), crumple, fallen, fallen }

-- Write --------------------------------------------------------------------
local draw = function(image, buf, ox, oy, name)
  for y = 0, SIZE - 1 do
    for x = 0, SIZE - 1 do
      local ch = buf[y][x]
      if ch ~= "." then
        local hex = PAL[ch]
        if not hex then error(name .. ": unknown hero palette key '" .. ch .. "'") end
        image:drawPixel(ox + x, oy + y, px.hex_to_color(hex))
      end
    end
  end
end

local check = function(grid, w, name)
  for i, row in ipairs(grid) do
    if #row ~= w then error(string.format("%s row %d is %d wide (want %d): %s", name, i - 1, #row, w, row)) end
  end
end
for dir, g in pairs(HEAD) do check(g, 14, def.name .. "_head_" .. dir) end
for dir, g in pairs(TORSO) do check(g, 12, def.name .. "_torso_" .. dir) end
check(LEG_FRONT_L, 6, "leg_l"); check(LEG_FRONT_R, 6, "leg_r"); check(LEG_SIDE, 6, "leg_side")
check(SHADOW, 32, "shadow")

local spr = Sprite(SIZE * 8, SIZE * #rows, ColorMode.RGB)
local img = spr.cels[1].image
for r, frames in ipairs(rows) do
  for f, buf in ipairs(frames) do
    draw(img, with_shadow(buf, r == #rows and f >= 3), (f - 1) * SIZE, (r - 1) * SIZE, "row" .. r)
  end
end
spr:saveAs(root .. "/art_src/" .. def.file .. ".aseprite")
spr:saveCopyAs(root .. "/assets/floor38/player/" .. def.file .. ".png")
spr:close()

local hand = Sprite(4, 4, ColorMode.RGB)
for y, row in ipairs(HAND) do
  for x = 1, #row do
    local ch = row:sub(x, x)
    if ch ~= "." then hand.cels[1].image:drawPixel(x - 1, y - 1, px.hex_to_color(PAL[ch])) end
  end
end
hand:saveAs(root .. "/art_src/" .. def.hand_file .. ".aseprite")
hand:saveCopyAs(root .. "/assets/floor38/player/" .. def.hand_file .. ".png")
hand:close()
px.preview(root .. "/assets/floor38/player/" .. def.file .. ".png", root .. "/art_src/preview_" .. def.file .. ".png", 4)
print(def.name .. " built")
end

build({ name = "gunner", file = "hero", hand_file = "hand", pal = GUNNER_PAL, head = GUNNER_HEAD, torso = GUNNER_TORSO, hand = SKIN_HAND })
build({ name = "knight", file = "knight", hand_file = "hand_knight", pal = KNIGHT_PAL, head = KNIGHT_HEAD, torso = KNIGHT_TORSO, hand = GAUNTLET_HAND })
build({ name = "engineer", file = "engineer", hand_file = "hand_engineer", pal = ENGINEER_PAL, head = ENGINEER_HEAD, torso = ENGINEER_TORSO, hand = SKIN_HAND })

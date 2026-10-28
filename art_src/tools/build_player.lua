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

-- Secondary-motion overlays (frames: 1 hang, 2 sway, 3 flow, 4 streaming).
-- x/y are offsets from the torso's top-left; side tails draw behind the body.
local SCARF_TAIL = {
  side = { x = -4, y = 0, frames = {
    { "....q", "...qr", "...r." },
    { "...qr", "..qr.", "..r.." },
    { "..qqr", ".qrr.", "qr..." },
    { ".qqrr", "qrr..", "r...." },
  }},
  up = { x = 5, y = 1, frames = {
    { ".rq", ".rq", ".q." },
    { "rq.", "rq.", "q.." },
    { ".rq", "rq.", "q.." },
    { "rq.", "q..", "..." },
  }},
}
local KNIGHT_CAPE = {
  side = { x = -3, y = 1, frames = {
    { "...q", "..qr", "..qr", "..qr", "..qr", "...q" },
    { "..qq", ".qrr", ".qrr", "..qr", "..qr", "...q" },
    { ".qqr", "qrr.", "qrr.", ".qr.", "..q.", "...." },
    { "qqrr", "qrr.", "rr..", "q...", "....", "...." },
  }},
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

local LEG_Y = FEET_Y - 8       -- hip joints (legs are 8 px: room for real knees)
local TORSO_Y = LEG_Y - 8
local HEAD_Y = TORSO_Y - 12

-- Jointed legs ---------------------------------------------------------------
-- Each leg is a thigh + shin solved with 2-bone IK from a hip joint (which
-- moves with the torso bob / lean, so legs never detach) to an ankle on a
-- foot path, then rasterised as an outlined, shaded limb with a boot.
-- Current hip offset, set by compose() before it draws the legs.
local LEG_TB, LEG_LEAN = 0, 0
local THIGH, SHIN = 3.5, 3.5
local ANKLE_Y = FEET_Y - 2      -- boots are 3 rows: ankle, foot, sole

local function seg_dist(px_, py_, ax, ay, bx, by)
  local vx, vy = bx - ax, by - ay
  local len2 = vx * vx + vy * vy
  local t = 0
  if len2 > 0 then t = math.max(0, math.min(1, ((px_ - ax) * vx + (py_ - ay) * vy) / len2)) end
  local cx, cy = ax + vx * t, ay + vy * t
  return math.sqrt((px_ - cx) ^ 2 + (py_ - cy) ^ 2)
end

local function paint(buf, ax, ay, bx, by, r, ch)
  for y = math.floor(math.min(ay, by) - r - 1), math.ceil(math.max(ay, by) + r + 1) do
    for x = math.floor(math.min(ax, bx) - r - 1), math.ceil(math.max(ax, bx) + r + 1) do
      if y >= 0 and y < SIZE and x >= 0 and x < SIZE and seg_dist(x + 0.5, y + 0.5, ax, ay, bx, by) <= r then
        buf[y][x] = ch
      end
    end
  end
end

-- Knee from hip H and ankle A; `forward` picks which way the knee bends.
local function solve_knee(hx, hy, ax, ay, forward)
  local dx, dy = ax - hx, ay - hy
  local d = math.sqrt(dx * dx + dy * dy)
  d = math.max(0.01, math.min(d, THIGH + SHIN - 0.01))
  local a = (THIGH * THIGH - SHIN * SHIN + d * d) / (2 * d)
  local h = math.sqrt(math.max(0, THIGH * THIGH - a * a))
  local mx, my = hx + a * dx / d, hy + a * dy / d
  local nx, ny = -dy / d, dx / d
  local k1x, k1y = mx + nx * h, my + ny * h
  local k2x, k2y = mx - nx * h, my - ny * h
  if (k1x - k2x) * forward > 0 then return k1x, k1y end
  return k2x, k2y
end

-- Draws one limb hip -> knee -> ankle. far = darker (depth).
local function limb(buf, hx, hy, kx, ky, ax, ay, far)
  local fill, light = far and "n" or "p", far and "p" or "P"
  paint(buf, hx, hy, kx, ky, 1.95, "N")
  paint(buf, kx, ky, ax, ay, 1.95, "N")
  paint(buf, hx, hy, kx, ky, 1.15, fill)
  paint(buf, kx, ky, ax, ay, 1.15, fill)
  -- Light catches the front/top edge of the trousers.
  paint(buf, hx - 0.6, hy, kx - 0.6, ky, 0.45, light)
  paint(buf, kx - 0.6, ky, ax - 0.6, ay, 0.45, light)
end

local BOOT_SIDE = { "kKk..", "xKKKk", "xxxxx" }
local BOOT_SIDE_LIFT = { "kKk.", "xKKk", ".xxx" }
local BOOT_FRONT = { "kKKk", "xKkx", "xxxx" }
local BOOT_FRONT_LIFT = { "kKKk", "xxxx" }
local function darker_boot(grid)
  local out = {}
  for i, row in ipairs(grid) do out[i] = row:gsub("K", "k") end
  return out
end

-- Side view (facing right). dx = ankle offset from the body centre, lift =
-- how far the foot is off the ground.
local function side_leg(buf, dx, lift, far)
  local hx, hy = 15.5 + LEG_LEAN, LEG_Y + LEG_TB + 0.5
  local ax, ay = 15.5 + dx, ANKLE_Y + 0.5 - lift
  local kx, ky = solve_knee(hx, hy, ax, ay, 1)
  limb(buf, hx, hy, kx, ky, ax, ay, far)
  local boot = lift > 0.6 and BOOT_SIDE_LIFT or BOOT_SIDE
  if far then boot = darker_boot(boot) end
  stamp(buf, boot, math.floor(ax) - 1, math.floor(ay))
end

function side_legs(buf, near_dx, near_lift, far_dx, far_lift)
  side_leg(buf, far_dx, far_lift, true)
  side_leg(buf, near_dx, near_lift, false)
end

-- Front / back view: legs below the hips; a lifted foot foreshortens the
-- leg (knee coming toward the camera) and shows the sole.
local function front_leg(buf, hip_x, lift)
  local hx, hy = hip_x, LEG_Y + LEG_TB + 0.5
  local ax, ay = hip_x + (hip_x < 16 and -0.3 or 0.3), ANKLE_Y + 0.5 - lift
  local kx, ky = (hx + ax) * 0.5 + (hip_x < 16 and -0.6 or 0.6) * math.min(lift, 2) * 0.5, (hy + ay) * 0.5
  limb(buf, hx, hy, kx, ky, ax, ay, false)
  if lift > 0.6 then paint(buf, kx, ky, kx, ky, 0.7, "P") end   -- knee catches light
  stamp(buf, lift > 0.6 and BOOT_FRONT_LIFT or BOOT_FRONT, math.floor(ax) - 1, math.floor(ay))
end

function front_legs(buf, lift_l, lift_r)
  front_leg(buf, 13.5, lift_l)
  front_leg(buf, 18.5, lift_r)
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
-- Sheet rows: 0-2 idle (8), 3-5 run (8), 6 death (6), 7-9 dash (4),
-- 10 hurt (down a,b / side a,b / up a,b). Must match Player._frames_for and
-- the bob/lean tables in player_1.gd.
--
-- Juice baked into the art:
--  * overlapping action: the head lags the torso bob by one frame
--  * side run leans forward 1 px, dash 2 px, hurt jolts back
--  * secondary motion: scarf / bandana tails and the Knight's cape flap,
--    the Knight's plume sways
local IDLE_TORSO = { 0, 0, 0, 1, 1, 1, 1, 0 }
local IDLE_HEAD  = { 0, 0, 0, 0, 1, 1, 1, 1 }
local IDLE_TAIL  = { 1, 1, 1, 1, 2, 2, 1, 1 }
local IDLE_PLUME = { 0, 0, 0, 0, 1, 1, 0, 0 }

local RUN_TORSO = { 0, 1, 1, 0, 0, 1, 1, 0 }
local RUN_HEAD  = { 0, 0, 1, 1, 0, 0, 1, 1 }
local RUN_TAIL  = { 3, 4, 3, 2, 3, 4, 3, 2 }
local RUN_PLUME = { 0, 0, 1, 0, 0, 0, -1, 0 }
local RUN_LEAN = 1
-- Side: near leg plants forward on frame 1 and sweeps back; it lifts while
-- swinging forward again. The far leg is half a cycle behind.
-- Foot path over a stride (phase 0..1): stance sweeps the planted foot back
-- along the ground, swing lifts it on an arc and brings it forward (eased).
local STRIDE, LIFT = 3.0, 2.6
local function foot(phase)
  phase = phase % 1
  if phase < 0.5 then
    local u = phase / 0.5
    return STRIDE - 2 * STRIDE * u, 0
  end
  local u = (phase - 0.5) / 0.5
  local eased = u * u * (3 - 2 * u)
  return -STRIDE + 2 * STRIDE * eased, math.sin(math.pi * u) * LIFT
end
local SIDE_NEAR_DX, SIDE_NEAR_LIFT, SIDE_FAR_DX, SIDE_FAR_LIFT = {}, {}, {}, {}
local FRONT_LIFT_L, FRONT_LIFT_R = {}, {}
for i = 1, 8 do
  local p = (i - 1) / 8
  SIDE_NEAR_DX[i], SIDE_NEAR_LIFT[i] = foot(p)
  SIDE_FAR_DX[i], SIDE_FAR_LIFT[i] = foot(p + 0.5)
  local _, l = foot(p + 0.5)
  local _, r = foot(p)
  FRONT_LIFT_L[i], FRONT_LIFT_R[i] = l, r
end

local DASH_TORSO = { 1, 1, 1, 1 }
local DASH_HEAD  = { 1, 1, 2, 1 }
local DASH_LEAN = 2

local function sway_head(head, rows, dx)
  if dx == 0 then return head end
  local out = {}
  for i, row in ipairs(head) do
    if i <= rows then
      if dx > 0 then out[i] = string.rep(".", dx) .. row:sub(1, #row - dx)
      else out[i] = row:sub(1 - dx) .. string.rep(".", -dx) end
    else
      out[i] = row
    end
  end
  return out
end

local function build(def)
PAL, HEAD, TORSO, HAND = def.pal, def.head, def.torso, def.hand
local closed = def.closed or "s"
local function shut(head, eye_row)
  local out = {}
  for i, row in ipairs(head) do out[i] = row end
  out[eye_row] = out[eye_row]:gsub("[ew]", closed)
  out[eye_row + 1] = out[eye_row + 1]:gsub("[eb]", "Z")
  return out
end
HEAD_BLINK = { down = shut(HEAD.down, 9), side = shut(HEAD.side, 8), up = HEAD.up }

-- One frame: legs, then (behind the body) side tail, head, torso, back tail.
local function compose(dir, legs_fn, o)
  local buf = blank()
  local lean = (dir == "side") and (o.lean or 0) or 0
  local tb, hb = o.tb or 0, o.hb or 0
  LEG_TB, LEG_LEAN = tb, lean
  legs_fn(buf)
  local tail = def.tail and o.tail and def.tail[dir]
  if tail and dir == "side" then
    stamp(buf, tail.frames[o.tail], 10 + lean + tail.x, TORSO_Y + tb + tail.y)
  end
  local head = o.head or HEAD[dir]
  if def.plume_rows and o.plume then
    head = sway_head(head, def.plume_rows, (dir == "side") and math.min(o.plume, 0) - (o.trail or 0) or o.plume)
  end
  stamp(buf, head, 9 + lean, HEAD_Y + hb)
  stamp(buf, TORSO[dir], 10 + lean, TORSO_Y + tb)
  if tail and dir ~= "side" then
    stamp(buf, tail.frames[o.tail], 10 + tail.x, TORSO_Y + tb + tail.y)
  end
  return buf
end

local function legs_idle(dir)
  if dir == "side" then return function(b) side_legs(b, 1, 0, -1.5, 0) end end
  return function(b) front_legs(b, 0, 0) end
end

local rows = {}
-- Idle: breathing, head settles a frame late, tail drifts, blink on 8.
for _, dir in ipairs({ "down", "side", "up" }) do
  local frames = {}
  for i = 1, 8 do
    frames[i] = compose(dir, legs_idle(dir), {
      tb = IDLE_TORSO[i], hb = IDLE_HEAD[i], tail = IDLE_TAIL[i], plume = IDLE_PLUME[i],
      head = (i == 8) and HEAD_BLINK[dir] or nil,
    })
  end
  rows[#rows + 1] = frames
end
-- Run: 8-frame contact/down/pass/up cycle.
for _, dir in ipairs({ "down", "side", "up" }) do
  local frames = {}
  for i = 1, 8 do
    local legs
    if dir == "side" then
      legs = function(b) side_legs(b, SIDE_NEAR_DX[i], SIDE_NEAR_LIFT[i], SIDE_FAR_DX[i], SIDE_FAR_LIFT[i]) end
    else
      legs = function(b) front_legs(b, FRONT_LIFT_L[i], FRONT_LIFT_R[i]) end
    end
    frames[i] = compose(dir, legs, {
      tb = RUN_TORSO[i], hb = RUN_HEAD[i], lean = RUN_LEAN, tail = RUN_TAIL[i],
      plume = RUN_PLUME[i], trail = 1,
    })
  end
  rows[#rows + 1] = frames
end

-- Death: hit, stagger, knees, fall, bounce, rest.
local hit = compose("down", legs_idle("down"), { tb = 0, hb = -1, head = HEAD_BLINK.down, tail = 2 })
local stagger = compose("down", function(b) front_legs(b, 0, 1) end, { tb = 2, hb = 2, head = HEAD_BLINK.down, tail = 1 })
local crumple = blank()
LEG_TB, LEG_LEAN = 4, 0
front_legs(crumple, 2.5, 2.5)
stamp(crumple, HEAD_BLINK.down, 9, HEAD_Y + 4)
stamp(crumple, TORSO.down, 10, TORSO_Y + 4)
local fallen = lying(compose("side", function(b) side_legs(b, 1, 0, -1.5, 0) end, { head = HEAD_BLINK.side }))
local bounced = blank()
for y = 1, SIZE - 1 do for x = 0, SIZE - 1 do bounced[y - 1][x] = fallen[y][x] end end
rows[#rows + 1] = { hit, stagger, crumple, fallen, bounced, fallen }

-- Dash: tucked legs, low and leaning hard, tail streaming.
for _, dir in ipairs({ "down", "side", "up" }) do
  local frames = {}
  for i = 1, 4 do
    local legs
    if dir == "side" then
      local near_lift = (i == 3) and 3 or 2
      local reach = (i == 3) and 4.5 or 4
      legs = function(b) side_legs(b, reach, 1.5, -reach, near_lift) end
    else
      local l, r = (i % 2 == 1) and 2 or 1, (i % 2 == 1) and 1 or 2
      legs = function(b) front_legs(b, l, r) end
    end
    frames[i] = compose(dir, legs, { tb = DASH_TORSO[i], hb = DASH_HEAD[i], lean = DASH_LEAN, tail = 4, plume = -1, trail = 1 })
  end
  rows[#rows + 1] = frames
end

-- Hurt: (a) jolted back with eyes squeezed shut, (b) recoil crouch.
local hurt = {}
for _, dir in ipairs({ "down", "side", "up" }) do
  hurt[#hurt + 1] = compose(dir, legs_idle(dir), { tb = 0, hb = -1, lean = -1, head = HEAD_BLINK[dir], tail = 2, plume = 1 })
  hurt[#hurt + 1] = compose(dir, legs_idle(dir), { tb = 1, hb = 1, lean = 0, head = HEAD_BLINK[dir], tail = 1 })
end
rows[#rows + 1] = hurt
local DEATH_ROW = 7
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
    draw(img, with_shadow(buf, r == DEATH_ROW and f >= 4), (f - 1) * SIZE, (r - 1) * SIZE, "row" .. r)
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

build({ name = "gunner", file = "hero", hand_file = "hand", pal = GUNNER_PAL, head = GUNNER_HEAD, torso = GUNNER_TORSO, hand = SKIN_HAND, tail = SCARF_TAIL })
build({ name = "knight", file = "knight", hand_file = "hand_knight", pal = KNIGHT_PAL, head = KNIGHT_HEAD, torso = KNIGHT_TORSO, hand = GAUNTLET_HAND, tail = KNIGHT_CAPE, plume_rows = 2, closed = "V" })
build({ name = "engineer", file = "engineer", hand_file = "hand_engineer", pal = ENGINEER_PAL, head = ENGINEER_HEAD, torso = ENGINEER_TORSO, hand = SKIN_HAND, tail = SCARF_TAIL })

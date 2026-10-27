-- Arena decoration: ground clutter and ambient FX drawn to match the
-- Mystic Forest pack palette (grass 509b66, foliage 53a03b, dirt 9d7658).
-- Run: Aseprite.exe -b --script-param root=<project> --script build_arena.lua

local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local lib = require("pixel_lib")

-- Pack-matched keys (added on top of the shared palette).
lib.palette["G"] = "69b57f" -- grass light
lib.palette["m"] = "509b66" -- grass base
lib.palette["D"] = "296640" -- grass dark
lib.palette["X"] = "163c2b" -- grass darkest
lib.palette["F"] = "53a03b" -- foliage
lib.palette["f"] = "347b2c" -- foliage shade
lib.palette["a"] = "9d7658" -- dirt light
lib.palette["A"] = "755338" -- dirt
lib.palette["P"] = "503625" -- dirt dark
lib.palette["O"] = "21110d" -- brown outline
lib.palette["i"] = "f5a5c0" -- petal pink
lib.palette["I"] = "d36b9a" -- petal pink shade
lib.palette["x"] = "1a1c2c50" -- soft contact shadow

-- Rows may be shorter than the cell; they are padded on the right.
local function pad(grid, w)
  local out = {}
  for i, row in ipairs(grid) do
    if #row > w then error("row too wide: " .. row) end
    out[i] = (row .. string.rep(".", w - #row)):gsub(" ", ".")
  end
  return out
end

local decor = {
  { name = "flowers_white", grid = {
    "",
    "",
    "         w",
    "        wyw",
    "   w     w",
    "  wyw    D",
    "   w    GD",
    "   D     D   w",
    "   DG       wyw",
    "    D        w",
    "      w      DG",
    "     wyw    D",
    "      w",
    "      D",
    "     GD",
    "      D",
  }},
  { name = "flowers_yellow", grid = {
    "",
    "",
    "",
    "     y",
    "    yYy   y",
    "     y   yYy",
    "     D    y",
    "    GD    D",
    "     D    DG  y",
    "  y  D    D  yYy",
    " yYy          y",
    "  y          GD",
    "  D           D",
    "  DG",
    "  D",
    "",
  }},
  { name = "flowers_pink", grid = {
    "",
    "",
    "",
    "      i",
    "     iyi",
    "    iIiIi  i",
    "     IyI  iyi",
    "      D    i",
    "      DG   D",
    "  i   D   GD",
    " iyi       D",
    "  iI",
    "  D",
    " GD",
    "  D",
    "",
  }},
  { name = "flowers_blue", grid = {
    "",
    "",
    "",
    "",
    "   b      b",
    "  bwb    bwb",
    "   B      B  b",
    "   D      D bwb",
    "   DG    GD  B",
    "   D      D  D",
    "             DG",
    "      b      D",
    "     bwb",
    "      B",
    "      DG",
    "      D",
  }},
  { name = "mushrooms", grid = {
    "",
    "",
    "",
    "",
    "    kkkk",
    "   krrwrk",
    "  krwrrrrk",
    "  krrrrwrk",
    "  kppppppk  kkk",
    "   kkeekk  krwrk",
    "     eE   kprrpk",
    "     eE    kkekk",
    "    xeEx     eE",
    "     xx     xeEx",
    "             xx",
    "",
  }},
  { name = "pebbles", grid = {
    "",
    "",
    "",
    "",
    "",
    "      kk",
    "     kssk",
    "     kSSk   kk",
    "      kk   ksSk",
    "      xx   kSdk",
    "   kk       kk",
    "  ksSk      xx",
    "  kSdk",
    "   kk",
    "   xx",
    "",
  }},
  { name = "grass_tuft", grid = {
    "",
    "",
    "",
    "",
    "",
    "      G",
    "  G   G   G",
    "  Gm  Gm  G  G",
    "   m GmD Gm G",
    "   mDGmD mD m",
    "   DmGmDGmDmD",
    "  GDmDmmDmDmD",
    "   DXmDXDmXD",
    "    XDXDXDX",
    "     xxxxx",
    "",
  }},
  { name = "grass_tuft_small", grid = {
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "      G   G",
    "   G  Gm G",
    "    mGmD m G",
    "    DmGmDmD",
    "   GDmDmDmD",
    "    XDXDXX",
    "     xxxx",
    "",
    "",
  }},
  { name = "clover", grid = {
    "",
    "",
    "",
    "",
    "     DD",
    "    DGGD DD",
    "    DGDGDGGD",
    "     DDGDGDD",
    "   DD  DD DD",
    "  DGGD  X   DD",
    "  DGDGDD   DGGD",
    "   DDGGD   DGDGD",
    "     DD     DDD",
    "      X      X",
    "",
    "",
  }},
  { name = "leaves", grid = {
    "",
    "",
    "",
    "",
    "        oo",
    "       ooh",
    "  YY    hh",
    " YYYh",
    "  hh        oo",
    "           Yooh",
    "     oY     hh",
    "    oooh",
    "     hh",
    "",
    "",
    "",
  }},
  { name = "stones_moss", grid = {
    "",
    "",
    "",
    "",
    "",
    "     kkkkk",
    "    kGmGssk",
    "   kmDsssSSk",
    "   ksssSSSdk",
    "   kSSSSSddk",
    "    kdddddk",
    "    xxxxxxx",
    "",
    "",
    "",
    "",
  }},
  { name = "twig", grid = {
    "",
    "",
    "",
    "",
    "",
    "",
    "          OO",
    "    OO   OaO",
    "   OaaOOOaAO",
    "    OAaaaAAO",
    "  OOOAAAAOO",
    " OaAAOOOO",
    "  OOO xxx",
    "",
    "",
    "",
  }},
}

local W, H = 16, 16
local function strip(entries, w, h, name)
  local list = {}
  for i, e in ipairs(entries) do
    list[i] = { name = e.name, grid = pad(e.grid, w) }
    while #list[i].grid < h do table.insert(list[i].grid, string.rep(".", w)) end
  end
  local ase = root .. "/art_src/" .. name .. ".aseprite"
  local png = root .. "/assets/floor38/arena/" .. name .. ".png"
  lib.build_strip(list, w, h, ase, png)
  lib.preview(png, root .. "/art_src/preview_" .. name .. ".png", 8)
end

strip(decor, W, H, "arena_decor")

-- Firefly: soft glowing mote, 2-frame flicker (8x8).
strip({
  { name = "on", grid = {
    "",
    "",
    "   y",
    "  ywy",
    "   y",
  }},
  { name = "dim", grid = {
    "",
    "",
    "",
    "   w",
    "",
  }},
}, 8, 8, "firefly")

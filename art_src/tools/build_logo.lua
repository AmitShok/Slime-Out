-- "SLIME-OUT" title logo: hand-drawn bold letter masks, shaded in the
-- slime's blues (light top -> deep bottom), a white glint, goo drips hanging
-- off the bottom edge, and a dark outline. One letter per frame so the menu
-- can animate them individually (wave bob, squash, dripping goo).
-- Run: Aseprite.exe -b --script-param root=<project> --script build_logo.lua

local root = app.params["root"]
package.path = root .. "/art_src/tools/?.lua;" .. package.path
local lib = require("pixel_lib")

-- 8 rows tall; drips = { {column, length}, ... } hanging below row 7.
local letters = {
  { name = "S", drips = { {1, 3} }, mask = {
    ".######.",
    "########",
    "##......",
    "#######.",
    ".#######",
    "......##",
    "########",
    ".######.",
  }},
  { name = "L", drips = { {4, 4} }, mask = {
    "##......",
    "##......",
    "##......",
    "##......",
    "##......",
    "##......",
    "########",
    "########",
  }},
  { name = "I", drips = { {1, 2} }, mask = {
    "####",
    ".##.",
    ".##.",
    ".##.",
    ".##.",
    ".##.",
    ".##.",
    "####",
  }},
  { name = "M", drips = { {0, 2}, {6, 4} }, mask = {
    "##....##",
    "###..###",
    "########",
    "##.##.##",
    "##....##",
    "##....##",
    "##....##",
    "##....##",
  }},
  { name = "E", drips = { {3, 3} }, mask = {
    "########",
    "########",
    "##......",
    "######..",
    "######..",
    "##......",
    "########",
    "########",
  }},
  { name = "dash", drips = { {2, 2} }, mask = {
    "......",
    "......",
    "......",
    "######",
    "######",
    "......",
    "......",
    "......",
  }},
  { name = "O", drips = { {5, 4} }, mask = {
    ".######.",
    "########",
    "##....##",
    "##....##",
    "##....##",
    "##....##",
    "########",
    ".######.",
  }},
  { name = "U", drips = { {1, 2}, {5, 3} }, mask = {
    "##....##",
    "##....##",
    "##....##",
    "##....##",
    "##....##",
    "##....##",
    "########",
    ".######.",
  }},
  { name = "T", drips = { {3, 4} }, mask = {
    "########",
    "########",
    "...##...",
    "...##...",
    "...##...",
    "...##...",
    "...##...",
    "...##...",
  }},
}

local W, H = 12, 14   -- frame: 1px outline margin + up to 4 rows of drips
local entries = {}
local widths = {}
for _, letter in ipairs(letters) do
  local cells = {}
  for y = 0, H - 1 do cells[y] = {} for x = 0, W - 1 do cells[y][x] = "." end end
  local mw = #letter.mask[1]
  -- Fill with a 3-tone ramp by row.
  for y, row in ipairs(letter.mask) do
    for x = 1, #row do
      if row:sub(x, x) == "#" then
        local r = y - 1
        cells[r + 1][x] = (r <= 1) and "c" or ((r >= 6) and "B" or "b")
      end
    end
  end
  -- Drips: a 2px column, right side shorter so it tapers, then a bead.
  for _, d in ipairs(letter.drips) do
    local x = d[1] + 1
    for i = 0, d[2] - 1 do
      cells[9 + i][x] = "B"
      if i < d[2] - 1 then cells[9 + i][x + 1] = "B" end
    end
    cells[9][x] = "b"
  end
  -- Glint on the first two top-left fill pixels.
  for y = 1, 2 do
    for x = 1, W - 2 do
      if cells[y][x] ~= "." then
        cells[y][x] = "w"
        break
      end
    end
  end
  -- Outline every empty cell touching the letter (8-neighbourhood).
  local filled = {}
  for y = 0, H - 1 do filled[y] = {} for x = 0, W - 1 do filled[y][x] = cells[y][x] ~= "." end end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if not filled[y][x] then
        for oy = -1, 1 do
          for ox = -1, 1 do
            local ny, nx = y + oy, x + ox
            if ny >= 0 and ny < H and nx >= 0 and nx < W and filled[ny][nx] then
              cells[y][x] = "k"
            end
          end
        end
      end
    end
  end
  local grid = {}
  for y = 0, H - 1 do
    local row = {}
    for x = 0, W - 1 do row[#row + 1] = cells[y][x] end
    grid[#grid + 1] = table.concat(row)
  end
  entries[#entries + 1] = { name = letter.name, grid = grid }
  widths[#widths + 1] = mw + 2
end

lib.build_strip(entries, W, H, root .. "/art_src/logo_letters.aseprite", root .. "/assets/floor38/ui/logo_letters.png")
lib.preview(root .. "/assets/floor38/ui/logo_letters.png", root .. "/art_src/preview_logo.png", 6)
print("widths: " .. table.concat(widths, ","))

-- Shared helpers for Floor 38 hand-authored pixel art.
-- Art is authored as character grids against a fixed palette, then
-- built into real .aseprite files (one frame per sprite) and exported.

local M = {}

-- Sweetie-16 based palette (+ brass ramp for ammo).
M.palette = {
  ["k"] = "1a1c2c", -- outline
  ["p"] = "5d275d", -- deep purple
  ["r"] = "b13e53", -- red
  ["o"] = "ef7d57", -- orange
  ["y"] = "ffcd75", -- yellow
  ["l"] = "a7f070", -- lime
  ["g"] = "38b764", -- green
  ["t"] = "257179", -- teal
  ["n"] = "29366f", -- navy
  ["B"] = "3b5dc9", -- blue
  ["b"] = "41a6f6", -- light blue
  ["c"] = "73eff7", -- cyan
  ["w"] = "f4f4f4", -- white
  ["s"] = "94b0c2", -- silver
  ["S"] = "566c86", -- slate
  ["d"] = "333c57", -- dark slate
  ["Y"] = "d9a03a", -- brass mid
  ["h"] = "a0672a", -- brass shade
  -- Hero
  ["e"] = "f2c09a", -- skin
  ["E"] = "c98b6b", -- skin shade
  ["j"] = "6b4630", -- hair
  ["H"] = "3d2a1e", -- hair dark
  ["u"] = "8a9c56", -- jacket light
  ["v"] = "5f7038", -- jacket
  ["V"] = "3f4a26", -- jacket shade
  ["z"] = "1a1c2c6e", -- ground shadow (translucent)
}

local function hex_to_color(hex)
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  local a = #hex >= 8 and tonumber(hex:sub(7, 8), 16) or 255
  return app.pixelColor.rgba(r, g, b, a)
end
M.hex_to_color = hex_to_color

function M.draw_grid(image, grid, w, h, ox, oy, name)
  ox = ox or 0
  oy = oy or 0
  if #grid ~= h then
    error(string.format("%s: expected %d rows, got %d", name, h, #grid))
  end
  for y, row in ipairs(grid) do
    if #row ~= w then
      error(string.format("%s: row %d has %d chars (expected %d): '%s'", name, y - 1, #row, w, row))
    end
    for x = 1, #row do
      local ch = row:sub(x, x)
      if ch ~= "." then
        local hex = M.palette[ch]
        if not hex then
          error(string.format("%s: unknown palette key '%s' at row %d", name, ch, y - 1))
        end
        image:drawPixel(ox + x - 1, oy + y - 1, hex_to_color(hex))
      end
    end
  end
end

-- Builds a multi-frame sprite (one named frame per entry, tagged), saves the
-- .aseprite source and exports a horizontal strip PNG.
function M.build_strip(entries, w, h, ase_path, png_path)
  local spr = Sprite(w, h, ColorMode.RGB)
  for i = 2, #entries do spr:newEmptyFrame() end
  for i, entry in ipairs(entries) do
    local cel = spr:newCel(spr.layers[1], spr.frames[i])
    M.draw_grid(cel.image, entry.grid, w, h, 0, 0, entry.name)
  end
  -- Tags are added after all frames exist so they don't stretch.
  for i, entry in ipairs(entries) do
    local tag = spr:newTag(i, i)
    tag.name = entry.name
  end
  spr:saveAs(ase_path)
  app.command.ExportSpriteSheet {
    ui = false,
    askOverwrite = false,
    type = SpriteSheetType.HORIZONTAL,
    textureFilename = png_path,
    dataFilename = "",
    dataFormat = SpriteSheetDataFormat.JSON_ARRAY,
  }
  spr:close()
end

-- Upscaled preview for review (not shipped).
function M.preview(png_path, out_path, scale)
  local spr = app.open(png_path)
  app.command.SpriteSize { ui = false, scale = scale, method = "nearest" }
  spr:saveCopyAs(out_path)
  spr:close()
end

return M

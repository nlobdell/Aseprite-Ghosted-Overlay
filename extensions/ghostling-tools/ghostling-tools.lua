local GhostlingTools = {
  version = "1.0.0",
}

local TEMPLATE_WIDTH = 210
local TEMPLATE_HEIGHT = 260
local GRID_TILE_SIZE = 3
local CHECKERED_CUSTOM_BG = 5
local BASE_REFERENCE_SIZE = Size(210, 210)
local SLOT_OPTIONS = { "hat", "face", "neck", "body" }
local SLOT_ANCHORS = {
  hat = Point(105, 72),
  face = Point(105, 97),
  neck = Point(105, 137),
  body = Point(105, 164),
}

local REF_BODY_LAYER = "REF Base Body"
local REF_HEAD_LAYER = "REF Base Head"
local REF_GUIDE_LAYER = "REF Slot Guide"
local EXPORT_BACK_LAYER = "EXPORT Back"
local EXPORT_FRONT_LAYER = "EXPORT Front"
local ANCHOR_LAYER = "ANCHOR Mount"

local function join_path(...)
  local parts = { ... }
  local current = parts[1]
  for index = 2, #parts do
    current = app.fs.joinPath(current, parts[index])
  end
  return current
end

local function plugin_path(...)
  assert(GhostlingTools.plugin and GhostlingTools.plugin.path, "Ghostling Tools plugin is not initialized")
  return join_path(GhostlingTools.plugin.path, ...)
end

local function positive_int(value, fallback)
  local number = math.floor(tonumber(value) or fallback or 0)
  if number < 1 then
    return fallback or 1
  end
  return number
end

local function normalize_newlines(text)
  return tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
end

local function trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function wrap_text_line(text, max_width)
  local remaining = trim(text)
  local lines = {}
  max_width = max_width or 72

  while #remaining > max_width do
    local split = nil
    for index = max_width, math.max(1, max_width - 24), -1 do
      local chr = remaining:sub(index, index)
      if chr == " " or chr == "\t" or chr == "/" or chr == "\\" or chr == ":" then
        split = index
        break
      end
    end

    if not split then
      split = max_width
    end

    local head = trim(remaining:sub(1, split))
    if head ~= "" then
      table.insert(lines, head)
    end
    remaining = trim(remaining:sub(split + 1))
  end

  if remaining ~= "" then
    table.insert(lines, remaining)
  end

  if #lines == 0 then
    lines[1] = ""
  end

  return lines
end

local function compact_traceback_line(text)
  local line = trim(normalize_newlines(text))
  line = line:gsub("^%-+", "")
  line = trim(line)
  line = line:gsub("\\", "/")
  line = line:gsub("^%[string \".-\"%]:", "")
  line = line:gsub("^.-/data/extensions/ghostling%-tools/", "")
  line = line:gsub("^.-/build/bin/data/extensions/ghostling%-tools/", "")
  line = line:gsub("^.-/Aseprite%-Custom/", "")
  line = line:gsub("^.-(ghostling%-tools%.lua:%d+:%s*)", "%1")
  line = line:gsub("^.-(ghostling%-tools%.lua:%d+)", "%1")
  return trim(line)
end

local function format_error_lines(err)
  local raw_lines = {}
  for line in (normalize_newlines(err) .. "\n"):gmatch("(.-)\n") do
    table.insert(raw_lines, line)
  end

  local lines = {}
  local summary = compact_traceback_line(raw_lines[1] or "")
  if summary == "" then
    summary = "Ghostling Tools hit an unknown error."
  end

  for _, line in ipairs(wrap_text_line(summary)) do
    table.insert(lines, line)
  end

  local trace = {}
  for index = 2, #raw_lines do
    local line = compact_traceback_line(raw_lines[index])
    if line ~= "" and line ~= "stack traceback:" and
       not line:find("xpcall", 1, true) and
       not line:find("run_command", 1, true) then
      if line:find("ghostling-tools.lua", 1, true) then
        table.insert(trace, line)
      end
    end
  end

  if #trace == 0 then
    for index = 2, #raw_lines do
      local line = compact_traceback_line(raw_lines[index])
      if line ~= "" and line ~= "stack traceback:" and
         not line:find("xpcall", 1, true) and
         not line:find("run_command", 1, true) then
        table.insert(trace, line)
      end
    end
  end

  if #trace > 0 then
    table.insert(lines, "")
    table.insert(lines, "Where:")
    for index = 1, math.min(#trace, 4) do
      for _, line in ipairs(wrap_text_line(trace[index])) do
        table.insert(lines, line)
      end
    end
  end

  return lines
end

local function validate_slot(slot)
  local normalized = tostring(slot or ""):lower()
  for _, candidate in ipairs(SLOT_OPTIONS) do
    if normalized == candidate then
      return normalized
    end
  end
  error("Choose a Ghostling slot: hat, face, neck, or body.")
end

local function slot_display_name(slot)
  local normalized = validate_slot(slot)
  return normalized:gsub("^%l", string.upper)
end

local function template_title(slot)
  return "New Ghostling - " .. slot_display_name(slot)
end

local function ensure_sprite(opts)
  return (opts and opts.sprite) or app.activeSprite
end

local function document_title(sprite)
  if sprite and sprite.filename and sprite.filename ~= "" then
    return app.fs.fileTitle(sprite.filename)
  end
  return "ghostling-cosmetic"
end

local function set_sprite_slot(sprite, slot)
  sprite.properties("ghostling_tools").slot = validate_slot(slot)
end

local function get_sprite_slot(sprite)
  local slot = sprite.properties("ghostling_tools").slot
  if slot == nil or slot == "" then
    return "hat"
  end
  return validate_slot(slot)
end

local function find_layer(sprite, name)
  for _, layer in ipairs(sprite.layers) do
    if layer.name == name then
      return layer
    end
  end
  return nil
end

local function base_reference_origin(width, height)
  return Point(
    math.floor((math.max(width, BASE_REFERENCE_SIZE.width) - BASE_REFERENCE_SIZE.width) / 2),
    math.max(0, height - BASE_REFERENCE_SIZE.height))
end

local function create_reference_layer(sprite, anchor_layer, name, filename, opts)
  opts = opts or {}

  app.layer = anchor_layer
  app.command.NewLayer {
    name = name,
    reference = true,
    before = true,
  }

  local layer = app.layer
  local image = Image { fromFile = filename }
  if opts.size then
    image:resize(opts.size.width, opts.size.height)
  end

  local position = opts.position or Point(0, 0)
  sprite:newCel(layer, 1, image, position)
  layer.opacity = opts.opacity or 180
  if opts.visible ~= nil then
    layer.isVisible = opts.visible
  end
  if opts.note then
    layer.data = opts.note
  end
  return layer
end

local function create_guide_marker()
  local image = Image(7, 7, ColorMode.RGB)
  local colors = {
    app.pixelColor.rgba(129, 197, 255, 255),
    app.pixelColor.rgba(255, 255, 255, 255),
  }
  for index = 0, 6 do
    image:putPixel(3, index, colors[(index % 2) + 1])
    image:putPixel(index, 3, colors[((index + 1) % 2) + 1])
  end
  image:putPixel(3, 3, app.pixelColor.rgba(255, 221, 96, 255))
  return image
end

local function create_slot_guide_layer(sprite, anchor_layer, slot, origin)
  local slot_anchor = SLOT_ANCHORS[slot]
  local image = create_guide_marker()

  app.layer = anchor_layer
  app.command.NewLayer {
    name = REF_GUIDE_LAYER,
    reference = true,
    before = true,
  }

  local layer = app.layer
  local guide_position = Point(origin.x + slot_anchor.x - 3, origin.y + slot_anchor.y - 3)
  sprite:newCel(layer, 1, image, guide_position)
  layer.opacity = 220
  layer.data = "Reference marker for the selected Ghostling slot anchor."
  return layer
end

local function default_output_stem(sprite)
  local slug = document_title(sprite)
    :lower()
    :gsub("[^%w]+", "-")
    :gsub("^-+", "")
    :gsub("-+$", "")
  local directory = "."
  if sprite and sprite.filename and sprite.filename ~= "" then
    directory = app.fs.filePath(sprite.filename)
  end
  return join_path(directory, slug)
end

local function add_dialog_copy(dlg, lines)
  for _, line in ipairs(lines) do
    dlg:label { text = line }
    dlg:newrow()
  end
end

local function ensure_layer_cel(layer, frame_number)
  if not layer then return nil end
  return layer:cel(frame_number)
end

local function image_has_visible_pixels(image)
  if not image then return false end
  local shrink = image:shrinkBounds()
  return shrink ~= nil and shrink.width > 0 and shrink.height > 0
end

local function trim_piece(layer, frame_number, sprite)
  local cel = ensure_layer_cel(layer, frame_number)
  if not cel or not image_has_visible_pixels(cel.image) then
    return nil
  end

  local bounds = cel.image:shrinkBounds()
  if not bounds or bounds.width <= 0 or bounds.height <= 0 then
    return nil
  end

  local doc_rect = {
    x = cel.position.x + bounds.x,
    y = cel.position.y + bounds.y,
    width = bounds.width,
    height = bounds.height,
  }
  if doc_rect.x < 0 or doc_rect.y < 0 or
     doc_rect.x + doc_rect.width > sprite.width or
     doc_rect.y + doc_rect.height > sprite.height then
    error(layer.name .. " has pixels outside the document canvas. Move that art inside the canvas before exporting.")
  end

  local image = Image(bounds.width, bounds.height, cel.image.colorMode)
  image:drawImage(cel.image, Point(-bounds.x, -bounds.y))
  return {
    image = image,
    docRect = doc_rect,
  }
end

local function find_mount_pixel(layer, frame_number, sprite)
  local cel = ensure_layer_cel(layer, frame_number)
  if not cel or not cel.image then
    error("Place exactly one opaque pixel on ANCHOR Mount before exporting.")
  end

  local pixel_count = 0
  local point = nil
  for y = 0, cel.image.height - 1 do
    for x = 0, cel.image.width - 1 do
      local pixel = cel.image:getPixel(x, y)
      if app.pixelColor.rgbaA(pixel) > 0 then
        pixel_count = pixel_count + 1
        point = Point(cel.position.x + x, cel.position.y + y)
      end
    end
  end

  if pixel_count ~= 1 or point == nil then
    error("Place exactly one opaque pixel on ANCHOR Mount before exporting.")
  end
  if point.x < 0 or point.y < 0 or point.x >= sprite.width or point.y >= sprite.height then
    error("Keep the mount pixel inside the document canvas.")
  end
  return point
end

local function get_base_rect(sprite, frame_number)
  local layer = find_layer(sprite, REF_BODY_LAYER)
  if not layer or not layer.isReference then
    error("Keep the REF Base Body reference layer so export can calculate the base rectangle.")
  end

  local cel = ensure_layer_cel(layer, frame_number)
  if not cel or not cel.image then
    error("REF Base Body needs its base reference image before export can continue.")
  end

  local rect = {
    x = cel.position.x,
    y = cel.position.y,
    width = cel.image.width,
    height = cel.image.height,
  }
  if rect.x < 0 or rect.y < 0 or
     rect.x + rect.width > sprite.width or
     rect.y + rect.height > sprite.height then
    error("REF Base Body must stay inside the document canvas.")
  end
  return rect
end

local function ensure_export_directory(filename)
  local directory = app.fs.filePath(filename)
  if directory ~= "" then
    app.fs.makeAllDirectories(directory)
  end
end

local function write_json_file(filename, value)
  ensure_export_directory(filename)
  local handle = io.open(filename, "w")
  if not handle then
    error("Could not write export metadata to " .. filename)
  end
  handle:write(json.encode(value))
  handle:close()
end

local function save_piece_image(piece, filename)
  ensure_export_directory(filename)
  if not piece.image:saveAs(filename) then
    error("Could not write Ghostling image export to " .. filename)
  end
  return filename
end

local function export_paths_from_stem(output_stem)
  if not output_stem or output_stem == "" then
    error("Choose a package stem before exporting.")
  end
  local directory = app.fs.filePath(output_stem)
  local title = app.fs.fileTitle(output_stem)
  if title == "" then
    title = output_stem
  end
  if directory == "" then
    return {
      front = title .. "-front.png",
      back = title .. "-back.png",
      metadata = title .. ".ghostling.json",
    }
  end
  return {
    front = join_path(directory, title .. "-front.png"),
    back = join_path(directory, title .. "-back.png"),
    metadata = join_path(directory, title .. ".ghostling.json"),
  }
end

local function show_template_dialog()
  if not app.isUIAvailable then
    return {
      slot = "hat",
      width = TEMPLATE_WIDTH,
      height = TEMPLATE_HEIGHT,
    }
  end

  local dlg = Dialog("New Ghostling Cosmetic")
  add_dialog_copy(dlg, {
    "Set up a Ghostling cosmetic document with bottom-aligned base references,",
    "export layers, and a hidden mount-pixel layer.",
    "Choose the slot first. Keep the default canvas unless you need extra room",
    "above or beside the 210x210 base reference.",
  })
  dlg:separator()
  dlg:combobox {
    id = "slot",
    label = "Ghostling slot",
    options = SLOT_OPTIONS,
    option = "hat",
  }
  dlg:number {
    id = "width",
    label = "Canvas width",
    text = tostring(TEMPLATE_WIDTH),
    decimals = 0,
  }
  dlg:number {
    id = "height",
    label = "Canvas height",
    text = tostring(TEMPLATE_HEIGHT),
    decimals = 0,
  }
  dlg:newrow()
  add_dialog_copy(dlg, {
    "Paint exportable art on EXPORT Front or EXPORT Back.",
    "Place exactly one opaque pixel on ANCHOR Mount.",
  })
  dlg:newrow()
  dlg:button { id = "ok", text = "&Create Template" }
  dlg:button { id = "cancel", text = "&Cancel" }
  dlg:show()

  if not dlg.data.ok then
    return nil
  end

  return {
    slot = dlg.data.slot,
    width = positive_int(dlg.data.width, TEMPLATE_WIDTH),
    height = positive_int(dlg.data.height, TEMPLATE_HEIGHT),
  }
end

local function show_export_dialog(sprite)
  if not app.isUIAvailable then
    return {
      outputStem = default_output_stem(sprite),
    }
  end

  local dlg = Dialog("Export Ghostling Cosmetic Package")
  add_dialog_copy(dlg, {
    "Choose a package stem for the exported Ghostling cosmetic.",
    "Export keeps the PNGs plus the .ghostling.json package format.",
  })
  dlg:file {
    id = "outputStem",
    label = "Package stem",
    save = true,
    entry = true,
    filename = default_output_stem(sprite),
  }
  dlg:newrow()
  add_dialog_copy(dlg, {
    "Outputs: <stem>-front.png, <stem>-back.png,",
    "and <stem>.ghostling.json",
    "Only non-empty EXPORT Front and EXPORT Back layers are written.",
    "Leave a layer empty if you do not need that side.",
  })
  dlg:newrow()
  dlg:button { id = "ok", text = "&Export Package" }
  dlg:button { id = "cancel", text = "&Cancel" }
  dlg:show()

  if not dlg.data.ok then
    return nil
  end

  return {
    outputStem = dlg.data.outputStem,
  }
end

function GhostlingTools.createTemplate(opts)
  opts = opts or {}
  local slot = validate_slot(opts.slot or "hat")
  local width = positive_int(opts.width, TEMPLATE_WIDTH)
  local height = positive_int(opts.height, TEMPLATE_HEIGHT)
  if width < BASE_REFERENCE_SIZE.width then
    error("Canvas width must be at least 210 pixels so the base reference fits.")
  end
  if height < BASE_REFERENCE_SIZE.height then
    error("Canvas height must be tall enough to fit the 210x210 base reference.")
  end

  local sprite = Sprite(width, height, ColorMode.RGB)
  sprite.filename = template_title(slot)
  sprite.gridBounds = Rectangle(0, 0, GRID_TILE_SIZE, GRID_TILE_SIZE)
  sprite.pixelRatio = Size(1, 1)
  sprite.data = "Built with Ghostling Tools. Paint exported art on EXPORT Front/Back and place exactly one opaque mount pixel on ANCHOR Mount."
  set_sprite_slot(sprite, slot)

  local doc_pref = app.preferences.document(sprite)
  doc_pref.grid.bounds = Rectangle(0, 0, GRID_TILE_SIZE, GRID_TILE_SIZE)
  doc_pref.bg.type = CHECKERED_CUSTOM_BG
  doc_pref.bg.size = Size(GRID_TILE_SIZE, GRID_TILE_SIZE)

  app.sprite = sprite
  local base_origin = base_reference_origin(width, height)
  local front_layer = nil

  app.transaction("Create Ghostling template", function()
    front_layer = sprite.layers[1]
    front_layer.name = EXPORT_FRONT_LAYER
    front_layer.color = Color(91, 192, 121)
    front_layer.data = "Front-most exported cosmetic art."

    local back_layer = sprite:newLayer()
    back_layer.name = EXPORT_BACK_LAYER
    back_layer.color = Color(86, 171, 232)
    back_layer.data = "Optional behind-the-head or behind-the-body cosmetic art."

    local anchor_layer = sprite:newLayer()
    anchor_layer.name = ANCHOR_LAYER
    anchor_layer.color = Color(255, 194, 74)
    anchor_layer.data = "Place exactly one opaque pixel where this cosmetic mounts to the Ghostling."
    anchor_layer.isVisible = false

    create_reference_layer(
      sprite,
      front_layer,
      REF_BODY_LAYER,
      plugin_path("assets", "BaseGhostling210-V2-body.png"),
      {
        size = BASE_REFERENCE_SIZE,
        position = base_origin,
        opacity = 180,
        note = "Reference only. Export uses this layer position as the baseRect origin.",
      })

    create_reference_layer(
      sprite,
      front_layer,
      REF_HEAD_LAYER,
      plugin_path("assets", "BaseGhostling210-V2-head.png"),
      {
        size = BASE_REFERENCE_SIZE,
        position = base_origin,
        opacity = 170,
        note = "Reference only. This helps line cosmetics up against the Ghostling head.",
      })

    create_slot_guide_layer(sprite, front_layer, slot, base_origin)
  end)

  app.sprite = sprite
  app.layer = front_layer
  app.frame = sprite.frames[1]
  app.refresh()
  return sprite
end

function GhostlingTools.exportPackage(opts)
  opts = opts or {}
  local sprite = ensure_sprite(opts)
  if not sprite then
    error("Open or create a Ghostling cosmetic before exporting.")
  end

  local frame_number = opts.frameNumber or 1
  local slot = get_sprite_slot(sprite)
  local base_rect = get_base_rect(sprite, frame_number)
  local mount = find_mount_pixel(find_layer(sprite, ANCHOR_LAYER), frame_number, sprite)
  local front_piece = trim_piece(find_layer(sprite, EXPORT_FRONT_LAYER), frame_number, sprite)
  local back_piece = trim_piece(find_layer(sprite, EXPORT_BACK_LAYER), frame_number, sprite)
  if not front_piece and not back_piece then
    error("Paint art on EXPORT Front or EXPORT Back before exporting.")
  end

  local output_stem = opts.outputStem or opts.stem or default_output_stem(sprite)
  local paths = export_paths_from_stem(output_stem)
  local metadata = {
    kind = "ghostling-cosmetic",
    schemaVersion = 1,
    slot = slot,
    canvas = {
      width = sprite.width,
      height = sprite.height,
    },
    baseRect = base_rect,
    mount = {
      x = mount.x,
      y = mount.y,
    },
    pieces = {},
  }

  local outputs = {
    front = nil,
    back = nil,
    metadata = paths.metadata,
  }

  if front_piece then
    outputs.front = save_piece_image(front_piece, paths.front)
    metadata.pieces.front = { docRect = front_piece.docRect }
  end
  if back_piece then
    outputs.back = save_piece_image(back_piece, paths.back)
    metadata.pieces.back = { docRect = back_piece.docRect }
  end
  write_json_file(paths.metadata, metadata)

  return {
    slot = slot,
    frontPath = outputs.front,
    backPath = outputs.back,
    metadataPath = outputs.metadata,
    metadata = metadata,
  }
end

local function run_command(callback)
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    if app.isUIAvailable then
      app.alert {
        title = "Ghostling Tools",
        text = format_error_lines(err),
      }
      return nil
    end
    error(err)
  end
  return true
end

local function command_new_template()
  local opts = show_template_dialog()
  if not opts then
    return
  end

  run_command(function()
    GhostlingTools.createTemplate(opts)
  end)
end

local function command_export_package()
  local opts = show_export_dialog(app.activeSprite)
  if not opts then
    return
  end

  run_command(function()
    GhostlingTools.exportPackage(opts)
  end)
end

local function has_active_sprite()
  return app.activeSprite ~= nil
end

function init(plugin)
  GhostlingTools.plugin = plugin
  GhostlingTools._formatErrorLines = format_error_lines
  _G.GhostlingTools = GhostlingTools

  plugin:newCommand {
    id = "GhostlingNewCosmetic",
    title = "New Ghostling Cosmetic...",
    group = "file_new",
    onclick = command_new_template,
  }

  plugin:newCommand {
    id = "GhostlingExportCosmeticPackage",
    title = "Export Ghostling Cosmetic Package...",
    group = "file_export_1",
    onclick = command_export_package,
    onenabled = has_active_sprite,
  }
end

function exit(plugin)
  if _G.GhostlingTools == GhostlingTools then
    _G.GhostlingTools = nil
  end
end

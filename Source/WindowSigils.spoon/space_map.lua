
local CoordinateSet = dofile(hs.spoons.resourcePath("coordinate_set.lua"))

local SpaceMap = {}
SpaceMap.__index = SpaceMap

function SpaceMap:new(screens, windows)
  local obj = {}
  setmetatable(obj, self)
  obj:_initialize(screens, windows)
  return obj
end

function SpaceMap:_add_frame(frame)
  self.xs:add(frame.x1)
  self.xs:add(frame.x2 + 1)
  self.ys:add(frame.y1)
  self.ys:add(frame.y2 + 1)
end

function SpaceMap:_add_framed_entities(framed_entities)
  for _, framed_entity in ipairs(framed_entities) do
    self:_add_frame(framed_entity:frame())
  end
end

function SpaceMap:_mark_cells_occupied(top, left, bottom, right)
  for i=top, bottom do
    for j=left, right do
      self.occupied[i][j] = true
    end
  end
end

function SpaceMap:_mark_frame_cells_occupied(frame)
  local left = self.xs:offset(frame.x1)
  local top = self.ys:offset(frame.y1)
  local right = self.xs:offset(frame.x2 + 1)
  local bottom = self.ys:offset(frame.y2 + 1)
  self:_mark_cells_occupied(top, left, bottom - 1, right - 1)
end

function SpaceMap:_build_occupied_map(windows)
  self.occupied = {}
  for i = 1, #self.ys do
    self.occupied[i] = {}
    for j = 1, #self.xs do
      self.occupied[i][j] = false
    end
  end

  for _, window in ipairs(windows) do
    self:_mark_frame_cells_occupied(window:frame())
  end
end

function SpaceMap:_initialize(screens, windows)
  self.xs = CoordinateSet:new()
  self.ys = CoordinateSet:new()
  self:_add_framed_entities(screens)
  self:_add_framed_entities(windows)
  self.xs:sort()
  self.ys:sort()
  self:_build_occupied_map(windows)
end

function SpaceMap:_find_empty_extent(top, left, i_end, j_end)
  local bottom = top
  while bottom + 1 <= i_end and not self.occupied[bottom + 1][left] do
    bottom = bottom + 1
  end

  local right = nil
  for i = top, bottom do
    local row_right = left
    while row_right + 1 <= j_end and not self.occupied[i][row_right + 1] do
      row_right = row_right + 1
    end
    if right == nil or row_right < right then
      right = row_right
    end
  end
  return bottom, right
end

function SpaceMap:empty_rects_on_screen(screen_frame)
  local screen_top = self.ys:offset(screen_frame.y)
  local screen_left = self.xs:offset(screen_frame.x)
  local screen_bottom = self.ys:offset(screen_frame.y2 + 1) - 1
  local screen_right = self.xs:offset(screen_frame.x2 + 1) - 1
  local empty_rects = {}
  for top = screen_top, screen_bottom do
    for left = screen_left, screen_right do
      if not self.occupied[top][left] then
        bottom, right = self:_find_empty_extent(top, left, screen_bottom, screen_right)
        self:_mark_cells_occupied(top, left, bottom, right)
        local frame = hs.geometry.rect({
          x1 = self.xs[left],
          y1 = self.ys[top],
          x2 = self.xs[right + 1] - 1,
          y2 = self.ys[bottom + 1] - 1
        })
        table.insert(empty_rects, frame)
      end
    end
  end
  return empty_rects
end

return SpaceMap


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

function SpaceMap:_build_occupied_map(windows)
  self.occupied = {}
  for i = 1, #self.ys do
    self.occupied[i] = {}
    for j = 1, #self.xs do
      self.occupied[i][j] = false
    end
  end

  for _, window in ipairs(windows) do
    local frame = window:frame()
    local x_start = self.xs:offset(frame.x1)
    local y_start = self.ys:offset(frame.y1)
    local x_end = self.xs:offset(frame.x2 + 1)
    local y_end = self.ys:offset(frame.y2 + 1)

    if x_start ~= nil and y_start ~= nil and x_end ~= nil and y_end ~= nil then
      for j=x_start, x_end - 1, 1 do
        for i=y_start, y_end - 1, 1 do
          self.occupied[i][j] = true
        end
      end
    end
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

return SpaceMap


local CoordinateSet = dofile(hs.spoons.resourcePath("coordinate_set.lua"))

local SpaceMap = {}
SpaceMap.__index = SpaceMap

function SpaceMap:new(...)
  local logger = hs.logger.new('SpaceMap', 'debug')
  local obj = {
    xs = CoordinateSet:new(),
    ys = CoordinateSet:new(),
  }
  setmetatable(obj, self)
  obj:initialize(...)
  return obj
end

function SpaceMap:add_frame(frame)
  self.xs:add(frame.x1)
  self.xs:add(frame.x2 + 1)
  self.ys:add(frame.y1)
  self.ys:add(frame.y2 + 1)
end

function SpaceMap:add_framed_entities(framed_entities)
  for _, framed_entity in ipairs(framed_entities) do
    self:add_frame(framed_entity:frame())
  end
end

function SpaceMap:initialize(...)
  for _, framed_entity_array in ipairs(table.pack(...)) do
    self:add_framed_entities(framed_entity_array)
  end
  self.xs:sort()
  self.ys:sort()
end

return SpaceMap

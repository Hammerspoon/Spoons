
local CoordinateSet = dofile(hs.spoons.resourcePath("coordinate_set.lua"))

local SpaceMap = {}
SpaceMap.__index = SpaceMap

function SpaceMap:new()
  local obj = {
    xs = CoordinateSet:new(),
    ys = CoordinateSet:new(),
  }
  setmetatable(obj, self)
  return obj
end

function SpaceMap:add_frame(frame)
  self.xs:add(frame.x1)
  self.xs:add(frame.x2 + 1)
  self.ys:add(frame.y1)
  self.ys:add(frame.y2 + 1)
end

return SpaceMap

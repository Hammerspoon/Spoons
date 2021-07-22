
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

return SpaceMap

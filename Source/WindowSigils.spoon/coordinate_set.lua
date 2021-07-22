--
-- An ordered set of ordered coordinates, e.g. xs or ys.  Coordinates
-- should be added, then 'sort' called before 'offset' is called to find
-- a coordinate's index.
--

local CoordinateSet = {}

function CoordinateSet:new()
  local o = {
    coordinates = {},
    xref = {},
  }
  setmetatable(o, self)
  return o
end

function CoordinateSet:add(coordinate)
  if not self.xref[coordinate] then
    self.xref[coordinate] = true
    table.insert(self.coordinates, coordinate)
  end
end

function CoordinateSet:sort()
  table.sort(self.coordinates)
end

function CoordinateSet:__index(i)
  if type(i) == "number" then
    return self.coordinates[i]
  end
  return CoordinateSet[i]
end

function CoordinateSet:__len()
  return #self.coordinates
end

function CoordinateSet:offset(value)
  if not self.xref[value] then
    return nil
  end
  local lo = 1
  local hi = #self.coordinates
  local mid
  while lo <= hi do
    mid = hs.math.floor((lo + hi) / 2)
    if self.coordinates[mid] == value then
      return mid
    elseif self.coordinates[mid] < value then
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  return mid
end

return CoordinateSet

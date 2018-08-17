local spaces       = require('hs._asm.undocumented.spaces')
local activeScreen = require('ext.screen').activeScreen
local module       = {}

module.activeSpaceIndex = function(screenSpaces)
  return hs.fnutils.indexOf(screenSpaces, spaces.activeSpace()) or 1
end

module.screenSpaces = function(currentScreen)
  currentScreen = currentScreen or activeScreen()
  return spaces.layout()[currentScreen:spacesUUID()]
end

module.spaceFromIndex = function(index)
  local currentScreen = activeScreen()
  return module.screenSpaces(currentScreen)[index]
end

module.spaceInDirection = function(direction)
  local screenSpaces = module.screenSpaces()
  local activeIdx    = module.activeSpaceIndex(screenSpaces)
  local targetIdx    = direction == 'west' and activeIdx - 1 or activeIdx + 1

  return screenSpaces[targetIdx]
end

module.isSpaceFullscreenApp = function(spaceID)
  return spaceID ~= nil and #spaces.spaceOwners(spaceID) > 0
end

return module

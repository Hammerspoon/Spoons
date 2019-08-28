local obj = {}
obj.__index = obj
obj.name = "Command"

-- Load dependencies
local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end
obj.spoonPath = script_path()

Validate = dofile(obj.spoonPath.."/validator.lua")
Resize = dofile(obj.spoonPath.."/resize.lua")

-- Command:leftHalf(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.leftHalf = function(windowFrame, screenFrame)
  local newFrame

  if Validate:leftHalf(windowFrame, screenFrame) then
    newFrame = Resize:leftTwoThirds(windowFrame, screenFrame)
  elseif Validate:leftTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:leftThird(windowFrame, screenFrame)
  else
    newFrame = Resize:leftHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:fullscreen(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.fullScreen = function(windowFrame, screenFrame)
  local newFrame = Resize:fullScreen(windowFrame, screenFrame)
  return newFrame
end

-- Command:center(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.center = function(windowFrame, screenFrame)
  local newFrame = Resize:center(windowFrame, screenFrame)
  return newFrame
end

-- Command:topHalf(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.topHalf = function(windowFrame, screenFrame)
  local newFrame

  if Validate:topHalf(windowFrame, screenFrame) then
    newFrame = Resize:topTwoThirds(windowFrame, screenFrame)
  elseif Validate:topTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:topThird(windowFrame, screenFrame)
  else
    newFrame = Resize:topHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:bottomHalf(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.bottomHalf = function(windowFrame, screenFrame)
  local newFrame

  if Validate:bottomHalf(windowFrame, screenFrame) then
    newFrame = Resize:bottomTwoThirds(windowFrame, screenFrame)
  elseif Validate:bottomTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:bottomThird(windowFrame, screenFrame)
  else
    newFrame = Resize:bottomHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:topLeft(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.topLeft = function(windowFrame, screenFrame)
  local newFrame

  if Validate:topLeftHalf(windowFrame, screenFrame) then
    newFrame = Resize:topLeftTwoThirds(windowFrame, screenFrame)
  elseif Validate:topLeftTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:topLeftThird(windowFrame, screenFrame)
  else
    newFrame = Resize:topLeftHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:topRight(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.topRight = function(windowFrame, screenFrame)
  local newFrame

  if Validate:topRightHalf(windowFrame, screenFrame) then
    newFrame = Resize:topRightTwoThirds(windowFrame, screenFrame)
  elseif Validate:topRightTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:topRightThird(windowFrame, screenFrame)
  else
    newFrame = Resize:topRightHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:bottomRight(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.bottomRight = function(windowFrame, screenFrame)
  local newFrame

  if Validate:bottomRightHalf(windowFrame, screenFrame) then
    newFrame = Resize:bottomRightTwoThirds(windowFrame, screenFrame)
  elseif Validate:bottomRightTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:bottomRightThird(windowFrame, screenFrame)
  else
    newFrame = Resize:bottomRightHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:bottomLeft(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.bottomLeft = function(windowFrame, screenFrame)
  local newFrame

  if Validate:bottomLeftHalf(windowFrame, screenFrame) then
    newFrame = Resize:bottomLeftTwoThirds(windowFrame, screenFrame)
  elseif Validate:bottomLeftTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:bottomLeftThird(windowFrame, screenFrame)
  else
    newFrame = Resize:bottomLeftHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:rightHalf(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.rightHalf = function(windowFrame, screenFrame)
  local newFrame

  if Validate:rightHalf(windowFrame, screenFrame) then
    newFrame = Resize:rightTwoThirds(windowFrame, screenFrame)
  elseif Validate:rightTwoThirds(windowFrame, screenFrame) then
    newFrame = Resize:rightThird(windowFrame, screenFrame)
  else
    newFrame = Resize:rightHalf(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:enlarge(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.enlarge = function(windowFrame, screenFrame)
  local newFrame = Resize:enlarge(windowFrame, screenFrame)
  return newFrame
end

-- Command:shrink(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.shrink = function(windowFrame, screenFrame)
  local newFrame = Resize:shrink(windowFrame, screenFrame)
  return newFrame
end

-- Command:nextThird(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.nextThird = function(windowFrame, screenFrame)
  local newFrame

  if Validate:leftThird(windowFrame, screenFrame) then
    newFrame = Resize:centerVerticalThird(windowFrame, screenFrame)
  elseif Validate:centerVerticalThird(windowFrame, screenFrame) then
    newFrame = Resize:rightThird(windowFrame, screenFrame)
  elseif Validate:rightThird(windowFrame, screenFrame) then
    newFrame = Resize:topThird(windowFrame, screenFrame)
  elseif Validate:topThird(windowFrame, screenFrame) then
    newFrame = Resize:centerHorizontalThird(windowFrame, screenFrame)
  elseif Validate:centerHorizontalThird(windowFrame, screenFrame) then
    newFrame = Resize:bottomThird(windowFrame, screenFrame)
  else
    newFrame = Resize:leftThird(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:prevThird(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.prevThird = function(windowFrame, screenFrame)
  local newFrame

  if Validate:leftThird(windowFrame, screenFrame) then
    newFrame = Resize:bottomThird(windowFrame, screenFrame)
  elseif Validate:bottomThird(windowFrame, screenFrame) then
    newFrame = Resize:centerHorizontalThird(windowFrame, screenFrame)
  elseif Validate:centerHorizontalThird(windowFrame, screenFrame) then
    newFrame = Resize:topThird(windowFrame, screenFrame)
  elseif Validate:topThird(windowFrame, screenFrame) then
    newFrame = Resize:rightThird(windowFrame, screenFrame)
  elseif Validate:rightThird(windowFrame, screenFrame) then
    newFrame = Resize:centerVerticalThird(windowFrame, screenFrame)
  else
    newFrame = Resize:leftThird(windowFrame, screenFrame)
  end

  return newFrame
end

-- Command:nextScreen(windowFrame, screenFrame)
-- Method
-- Inspects current screen frame position, determines how to resize given frame
-- and calls corresponding resize method
--
-- Returns:
-- * A screenFrame to be rendered
obj.nextDisplay = function(windowFrame, screenFrame)
  local currentWindow = hs.window.focusedWindow()
  local currentScreen = currentWindow:screen()
  local nextScreen = currentScreen:next()
  local nextScreenFrame = nextScreen:frame()
  local newFrame

  if Validate:inScreenBounds(windowFrame, nextScreenFrame) then
    newFrame = Resize:center(windowFrame, nextScreenFrame)
  else
    newFrame = Resize:fullScreen(windowFrame, nextScreenFrame)
  end

  return newFrame
end

obj.prevDisplay = function(windowFrame, screenFrame)
  local currentWindow = hs.window.focusedWindow()
  local currentScreen = currentWindow:screen()
  local prevScreen = currentScreen:previous()
  local prevScreenFrame = prevScreen:frame()
  local newFrame

  if Validate:inScreenBounds(windowFrame, prevScreenFrame) then
    newFrame = Resize:center(windowFrame, prevScreenFrame)
  else
    newFrame = Resize:fullScreen(windowFrame, prevScreenFrame)
  end

  return newFrame
end

return obj

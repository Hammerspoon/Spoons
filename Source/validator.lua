 local obj = {}
 obj.__index = obj
 obj.name = "Validator"

function obj:topHalf(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == screen.w and
         window.h == (screen.h // 2)
end

function obj:topThird(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == screen.w and
         window.h == (screen.h // 3)
end

function obj:topTwoThirds(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == screen.w and
         window.h == ((screen.h // 3) * 2)
end

function obj:topLeftHalf(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == screen.w // 2 and
         window.h == screen.h // 2
end

function obj:topLeftThird(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == (screen.w // 3) and
         window.h == screen.h // 2
end

function obj:topLeftTwoThirds(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == ((screen.w // 3) * 2) and
         window.h == screen.h // 2
end

function obj:topRightHalf(window, screen)
  return window.x == (screen.w // 2) + screen.x and
         window.y == screen.y and
         window.w == screen.w // 2 and
         window.h == screen.h // 2
end

function obj:topRightThird(window, screen)
  return window.x == (((screen.w // 3) * 2) + screen.x) and
         window.y == screen.y and
         window.w == (screen.w // 3) and
         window.h == screen.h // 2
end

function obj:topRightTwoThirds(window, screen)
  return window.x == ((screen.w // 3) + screen.x) and
         window.y == screen.y and
         window.w == ((screen.w // 3) * 2) and
         window.h == screen.h // 2
end

function obj:bottomHalf(window, screen)
  return window.x == screen.x and
         window.y == (screen.h // 2) + screen.y and
         window.w == screen.w and
         window.h == screen.h // 2
end

function obj:bottomThird(window, screen)
  return window.x == screen.x and
         window.y == (((screen.h // 3) * 2) + screen.y) and
         window.w == screen.w and
         window.h == (screen.h // 3)
end

function obj:bottomTwoThirds(window, screen)
  return window.x == screen.x and
         window.y == ((screen.h // 3) + screen.y) and
         window.w == screen.w and
         window.h == ((screen.h // 3) * 2)
end

function obj:bottomLeftHalf(window, screen)
  return window.x == screen.x and
         window.y == screen.h // 2 + screen.y and
         window.w == screen.w // 2 and
         window.h == screen.h // 2
end

function obj:bottomLeftThird(window, screen)
  return window.x == screen.x and
         window.y == (screen.h // 2) + screen.y and
         window.w == (screen.w // 3) and
         window.h == screen.h // 2
end

function obj:bottomLeftTwoThirds(window, screen)
  return window.x == screen.x and
         window.y == (screen.h // 2) + screen.y and
         window.w == ((screen.w // 3) * 2) and
         window.h == screen.h // 2
end

function obj:bottomRightThird(window, screen)
  return window.x == ((screen.w // 3) * 2) and
         window.y == (screen.h // 2) + screen.y and
         window.w == (screen.w // 3) and
         window.h == screen.h // 2
end

function obj:bottomRightTwoThirds(window, screen)
  return window.x == (screen.w // 3) + screen.x and
         window.y == (screen.h // 2) + screen.y and
         window.w == ((screen.w // 3) * 2) and
         window.h == screen.h // 2
end

function obj:bottomRightHalf(window, screen)
  return window.x == (screen.w // 2) + screen.x and
         window.y == (screen.h // 2) + screen.y and
         window.w == screen.w // 2 and
         window.h == screen.h // 2
end

function obj:leftHalf(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == screen.w // 2 and
         window.h == screen.h
end

function obj:leftThird(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == (screen.w // 3) and
         window.h == screen.h
end

function obj:leftTwoThirds(window, screen)
  return window.x == screen.x and
         window.y == screen.y and
         window.w == ((screen.w // 3) * 2) and
         window.h == screen.h
end

function obj:rightHalf(window, screen)
  return window.x == (screen.w // 2) + screen.x and
         window.y == screen.y and
         window.w == screen.w // 2 and
         window.h == screen.h
end

function obj:rightThird(window, screen)
  return window.x == ((screen.w // 3) * 2 + screen.x) and
         window.y == screen.y and
         window.w == (screen.w // 3) and
         window.h == screen.h
end

function obj:rightTwoThirds(window, screen)
  return window.x == ((screen.w // 3) + screen.x) and
         window.y == screen.y and
         window.w == ((screen.w // 3) * 2) and
         window.h == screen.h
end

function obj:centerHorizontalThird(window, screen)
  return window.x == screen.x and
         window.y == (screen.h // 3) and
         window.w == screen.w and
         window.h == (screen.h // 3)
end

function obj:centerVerticalThird(window, screen)
  return window.x == (screen.w // 3) and
         window.y == screen.y and
         window.w == (screen.w // 3) and
         window.h == screen.h
end

function obj:inScreenBounds(window, screen)
  return window.w <= screen.w and
         window.h <= screen.h
end

return obj

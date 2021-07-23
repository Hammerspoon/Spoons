local EmptyWindow = {}
EmptyWindow.__index = EmptyWindow

function EmptyWindow:new(frame)
  local obj = {
    _frame = frame
  }
  setmetatable(obj, self)
  return obj
end

function EmptyWindow:id()
  return -1
end

function EmptyWindow:isVisible()
  return true
end

function EmptyWindow:frame()
  return self._frame
end

function EmptyWindow:setFrame(frame, speed)
end

return EmptyWindow

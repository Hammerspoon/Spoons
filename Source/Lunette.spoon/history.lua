local obj = {}
obj.__index = obj

obj.history = {}
obj.currentLoc = 1
obj.capacity = 100

function obj:init()
  return obj
end

function obj:push(prevState, nextState)
  local event = {}
  event["prev"] = prevState
  event["next"] = nextState

  table.insert(obj.history, 1, event)
  obj.currentLoc = 1

  pruneStack()
end

function pruneStack()
  if obj:histCount() == obj.capacity then
    table.remove(obj.history, obj.capacity)
  end
end

function obj:pop()
  local event = obj.history[1]
  table.remove(obj.history, 1)

  return event.prev
end

function obj:histCount()
  local histCount = 0

  for _ in pairs(obj.history) do
    histCount = histCount + 1
  end

  return histCount
end

function obj:retrievePrevState()
  local state = obj.history[obj.currentLoc]
  obj.currentLoc = obj.currentLoc + 1

  return state.prev
end

function obj:retrieveNextState()
  obj.currentLoc = obj.currentLoc - 1
  local state = obj.history[obj.currentLoc]

  return state.next
end

return obj

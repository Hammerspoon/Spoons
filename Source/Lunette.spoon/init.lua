--- === Lunette ===
---
--- Zero-config Spectacle Keybindings for Hammerspoon
--- Download: [https://github.com/scottwhudson/Lunette/blob/master/Spoons/Lunette.spoon.zip](https://github.com/scottwhudson/Lunette/blob/master/Spoons/Lunette.spoon.zip)
local obj = {}
obj.__index = obj

--- Metadata
obj.name = "Lunette"
obj.version = "0.3.1"
obj.author = "Scott Hudson <scott.w.hudson@gmail.com>"
obj.license = "MIT"
obj.homepage = "https://github.com/scottwhudson/Lunette"

--- disable animation
hs.window.animationDuration = 0

--- Internal function used to find our location, so we know where to load files from
local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end
obj.spoonPath = script_path()

obj.Command = dofile(obj.spoonPath.."/command.lua")
obj.history = dofile(obj.spoonPath.."/history.lua"):init()

obj.DefaultMapping = {
  leftHalf = {
    {{"cmd", "alt"}, "left"},
  },
  rightHalf = {
    {{"cmd", "alt"}, "right"},
  },
  topHalf = {
    {{"cmd", "alt"}, "up"},
  },
  bottomHalf = {
    {{"cmd", "alt"}, "down"},
  },
  topLeft = {
    {{"ctrl", "cmd"}, "Left"},
  },
  topRight = {
    {{"ctrl", "cmd"}, "Right"},
  },
  bottomLeft = {
    {{"ctrl", "cmd", "shift"}, "Left"},
  },
  bottomRight = {
    {{"ctrl", "cmd", "shift"}, "Right"},
  },
  fullScreen = {
    {{"cmd", "alt"}, "F"},
  },
  center = {
    {{"cmd", "alt"}, "C"},
  },
  nextThird = {
    {{"ctrl", "alt"}, "Right"},
  },
  prevThird = {
    {{"ctrl", "alt"}, "Left"},
  },
  enlarge = {
    {{"ctrl", "alt", "shift"}, "Right"},
  },
  shrink = {
    {{"ctrl", "alt", "shift"}, "Left"},
  },
  undo = {
    {{"alt", "cmd"}, "Z"},
  },
  redo = {
    {{"alt", "cmd", "shift"}, "Z"},
  },
  nextDisplay = {
    {{"ctrl", "alt", "cmd"}, "Right"},
  },
  prevDisplay = {
    {{"ctrl", "alt", "cmd"}, "Left"},
  }
}

function obj:bindHotkeys(userBindings)
  print("Lunette: Binding Hotkeys")

  local userBindings = userBindings or {}
  local bindings = self.DefaultMapping

  for command, mappings in pairs(userBindings) do
    bindings[command] = mappings
  end

  for command, mappings in pairs(bindings) do
    if mappings then
      for i, binding in ipairs(mappings) do
        hs.hotkey.bind(binding[1], binding[2], function()
          self:exec(command)
        end)
      end
    end
  end
end

function obj:exec(commandName)
  local window = hs.window.focusedWindow()
  local windowFrame = window:frame()
  local screen = window:screen()
  local screenFrame = screen:frame()
  local currentFrame = window:frame()
  local newFrame

  if commandName == "undo" then
    newFrame = self.history:retrievePrevState()
  elseif commandName == "redo" then
    newFrame = self.history:retrieveNextState()
  else
    print("Lunette: " .. commandName)
    print(self.Command[commandName])
    newFrame = self.Command[commandName](windowFrame, screenFrame)
    self.history:push(currentFrame, newFrame)
  end

  window:setFrame(newFrame)
end

return obj

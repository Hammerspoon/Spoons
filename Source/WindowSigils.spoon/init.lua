--- === WindowSigils ===
---
--- Assign every window a sigil for quick access.
---
--- A letter or digit is rendered in the titlebar of every window, and actions can be bound
--- inside a "sigil" mode with different modifiers.  For example, with no modifiers, the
--- the sigil key can focus the window.  If the 'enter' action is bound to control-w, then
--- 'control-w c' will focus the window with sigil 'c'.
---
--- The keys 'h', 'j', 'k', and 'l' are reserved for the window west, south, north, and
--- east of the currently focused window in standard Vi-like fashion, and so are not
--- assigned as sigils.
---
--- By default, two keys (other than the sigils) are bound in the mode: escape leaves the
--- mode without doing anything, and '.' sends the sigil key to the focused window.  This
--- allows sending 'control-w' to the underlying window by typing 'control-w .'.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowSigils.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowSigils.spoon.zip)
---
--- Usage example:
--- ```
--- sigils = hs.loadSpoon("WindowSigils")
--- sigils:configure({
---   hotkeys = {
---     enter = {{"control"}, "W"}
---   },
---   mode_keys = {
---     [{{'shift'}, 'i'}] = ignore_notification,
---     [{{}, 'v'}]        = paste_as_keystrokes,
---     [{{}, ','}]        = rerun_last_command,
---   },
---   sigil_actions = {
---     [{}]       = focus_window,
---     [{'ctrl'}] = swap_window,
---     [{'alt'}]  = warp_window,
---   }
--- })
--- sigils:start()
--- ```

local obj={}
obj.__index = obj

-- Metadata
obj.name = "WindowSigils"
obj.version = "0.1"
obj.author = "Jason Felice <jason.m.felice@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowSigils.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('WindowSigils')

obj.sigils = {
  "a", "b", "c", "d", "e", "f", "g", "i", "m", "n", "o", "p", "q", "r", "s", "t", "u",
  "v", "w", "x", "y", "z", ";", ",", "/", "0", "1", "2", "3", "4", "5", "6", "7",
  "8", "9",
}

--- WindowSigils:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for WindowSigils
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * enter - Enter the sigil mode
function obj:bindHotkeys(mapping)
  if mapping['enter'] then
    mods, key = table.unpack(mapping['enter'])
    self.mode = hs.hotkey.modal.new(mods, key)
    self.mode:bind({}, 'escape', function() self.mode:exit() end)
    self.mode:bind({}, '.', function()
      self.mode:exit()
      self.mode.k:disable()
      hs.eventtap.keyStroke(mods, key)
      self.mode.k:enable()
    end)
  end
end

--- WindowSigils:configure(configuration)
--- Method
--- Configures the spoon.
---
--- Parameters:
---  * configuration - :
---    * hotkeys -
---    * mode_keys - a table of key specs (e.g. {{'shift'}, 'n'}) to functions.  The keys are
---      mapped inside the sigil mode and the key is no longer used as a window sigil.
---    * sigil_actions - a table of mod specs (e.g. {'alt'}) to functions.  When the sigil is
---      used in the sigil mode with the specified modifier pressed, the function is invoked
---      with a window object.
function obj:configure(configuration)
  if configuration['hotkeys'] then
    self:bindHotkeys(configuration['hotkeys'])
  end
  if configuration['mode_keys'] then
    for keyspec,fn in pairs(configuration['mode_keys']) do
      local mods, key = table.unpack(keyspec)
      self:bindModeKey(mods, key, fn)
    end
  end
  if configuration['sigil_actions'] then
    for mods,fn in pairs(configuration['sigil_actions']) do
      self:bindSigilAction(mods, fn)
    end
  end
end

--- WindowSigils:bindModeKey(mods, key, action)
--- Method
--- Bind an extra action to be triggered by a key in the sigil mode.
---
--- Parameters:
---  * mods - The key modifiers
---  * key - The key
---  * action - A function, called with no parameters.
function obj:bindModeKey(mods, key, action)
  local sigil_to_remove = hs.fnutils.indexOf(self.sigils, key)
  if sigil_to_remove then
    table.remove(self.sigils, sigil_to_remove)
  end
  self.mode:bind(mods, key, function()
    self.mode:exit()
    action()
  end)
end

local directions = {
  h = 'West',
  j = 'South',
  k = 'North',
  l = 'East'
}

--- WindowSigils:bindSigilAction(mods, action)
--- Method
--- Bind an action to be triggered in the sigil mode when a window's sigil key is pressed.
---
--- Parameters:
---  * mods - The modifiers which must be held to trigger this action.
---  * action - A function which takes a window object and performs this action.
function obj:bindSigilAction(mods, action)
  local function make_action(sigil)
    return function()
      self.mode:exit()
      local window = self:window(sigil)
      if window then
        action(window)
      end
    end
  end
  for key,direction in pairs(directions) do
    self.mode:bind(mods, key, make_action(direction))
  end
  for _,sigil in ipairs(self.sigils) do
    self.mode:bind(mods, sigil, make_action(sigil))
  end
end

--- WindowSigils:start()
--- Method
--- Starts rendering the sigils and handling hotkeys
---
--- Parameters:
---  * None
function obj:start()
  self.window_filter = hs.window.filter.new({override={
    visible = true,
  }}):setDefaultFilter({
    visible = true,
  })
  self.window_filter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowDestroyed,
    hs.window.filter.windowMoved,
    hs.window.filter.windowAllowed,
    hs.window.filter.windowRejected,
    hs.window.filter.windowNotVisible,
    hs.window.filter.windowVisible,
  }, function()
    self:refresh()
  end)

  self.screens = hs.fnutils.map(hs.screen.allScreens(), function(screen)
    local bounds = screen:frame()
    local canvas = hs.canvas.new(bounds)
    canvas:show()
    return {
      screen = screen,
      canvas = canvas
    }
  end)

  self:refresh()
end

--- WindowSigils:stop()
--- Method
--- Stops rendering the sigils and handling hotkeys
---
--- Parameters:
---  * None
function obj:stop()
  self.window_filter = nil
end


--- WindowSigils:orderedWindows()
--- Method
--- A list of windows, in the order sigils are assigned.
---
--- Parameters:
---  * None
function obj:orderedWindows()
  local windows = self.window_filter:getWindows()
  table.sort(windows, function(a, b)
    local af, bf = a:frame(), b:frame()
    if af.x < bf.x then return true end
    if af.x > bf.x then return false end
    return af.y < bf.y
  end)
  return windows
end

--- WindowSigils:window(sigil)
--- Method
--- Find the window with the given index or sigil.
---
--- Parameters:
---  * sigil - If a number, the index of the window; if a string, the sigil of the window.
---    Can also be 'North', 'East', 'South', or 'West' to find a window related to the
---    currently focused window.
function obj:window(sigil)
  if type(sigil) == 'number' then
    return self:orderedWindows()[sigil]
  elseif sigil == 'North' then
    return hs.window.focusedWindow():windowsToNorth(nil, true, true)[1]
  elseif sigil == 'East' then
    return hs.window.focusedWindow():windowsToEast(nil, true, true)[1]
  elseif sigil == 'South' then
    return hs.window.focusedWindow():windowsToSouth(nil, true, true)[1]
  elseif sigil == 'West' then
    return hs.window.focusedWindow():windowsToWest(nil, true, true)[1]
  else
    for i,k in ipairs(self.sigils) do
      if k == sigil then
        return self:orderedWindows()[i]
      end
    end
  end
  return nil
end

--- WindowSigils:refresh()
--- Method
--- Rerender all window sigils.
---
--- Parameters:
---  * None
function obj:refresh()
  for _, screen_data in ipairs(self.screens) do
    local bounds = screen_data.screen:frame()

    local function make_frame(wframe)
      local rect = hs.geometry.toUnitRect(wframe, bounds)
      return { x = tostring(rect.x), y = tostring(rect.y), w = tostring(rect.w), h = tostring(rect.h) }
    end

    local new_elements = {}
    local windows = self:orderedWindows()
    for i, window in ipairs(windows) do
      local wframe = window:frame()
      table.insert(new_elements, {
        action = "fill",
        fillColor = { alpha = 0.3, green = 1.0, blue = 1.0 },
        frame = make_frame{x = wframe.x + 70, y = wframe.y + 1, w = 20, h = 19},
        type = "rectangle",
        withShadow = true,
      })
      table.insert(new_elements, {
        type = "text",
        text = self.sigils[i],
        textFont = "Menlo Regular",
        textSize = 18,
        textLineBreak = 'truncateTail',
        frame = make_frame{x = wframe.x + 73, y = wframe.y - 3, w = 17, h = 19 + 7},
      })
    end
    if #new_elements > 0 then
      screen_data.canvas:replaceElements(new_elements)
    end
  end
end

return obj

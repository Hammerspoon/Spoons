--- === QuakeApps ===
---
--- Toggle "quake-style" apps: summon, place, and auto-hide by action.
---
--- Configurable properties (with default values):
---     apps = {},
---     defaultHeight = 0.45,
---     defaultWidth = 1.0,
---
--- Example:
--- ```
--- spoon.QuakeApps.apps = {
---   terminal = {
---     bundleID = "net.kovidgoyal.kitty",
---     placement = "topHalf",
---     hotkey = { { "cmd" }, "`" },
---   },
---   browser = {
---     app = "Google Chrome",
---     placement = "middle",
---     width = 0.7,
---     hotkey = { { "cmd", "alt" }, "b" },
---   },
--- }
--- ```
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/QuakeApps.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/QuakeApps.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "QuakeApps"
obj.version = "0.1.0"
obj.author = "Ilya Zakirzyanov"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/Hammerspoon/hammerspoon"

--- QuakeApps.apps
--- Variable
--- Per-action app configuration used by `bindHotkeys()` and `toggle()`.
---
--- Parameters:
---  * action (table key) - Action name, e.g. `terminal`
---  * app config (table value):
---    * bundleID - App bundle ID (recommended), e.g. `net.kovidgoyal.kitty`
---    * app - App name (fallback if bundleID is not provided)
---    * placement - Optional preset: `topHalf`, `middle`, `fullScreen`, `left`, `right`
---    * hotkey - Hotkey in the form `{ {"cmd"}, "`" }`
---    * width - Optional width ratio from 0 to 1
---    * height - Optional height ratio from 0 to 1
---    * marginTop - Optional top offset in pixels
---    * screen - Optional screen name
---    * autoHide - Hide when app loses focus (default true behavior)
---    * onShow - Optional hook (function or shell command string)
---    * onHide - Optional hook (function or shell command string)
---
--- Returns:
---  * A table of app definitions
obj.apps = {}

--- QuakeApps.defaultHeight
--- Variable
--- Default height ratio used when app config does not specify `height`.
---
--- Parameters:
---  * value - A number between 0 and 1
---
--- Returns:
---  * Current default height ratio
obj.defaultHeight = 0.45

--- QuakeApps.defaultWidth
--- Variable
--- Default width ratio used when app config does not specify `width`.
---
--- Parameters:
---  * value - A number between 0 and 1
---
--- Returns:
---  * Current default width ratio
obj.defaultWidth = 1.0

obj._hotkeys = {}
obj._watcher = nil

local function clampFraction(value, fallback)
  local n = tonumber(value) or fallback
  if n <= 0 then
    return fallback
  end
  if n > 1 then
    return 1
  end
  return n
end

local function findScreenByName(name)
  if not name then
    return nil
  end
  for _, screen in ipairs(hs.screen.allScreens()) do
    if screen:name() == name then
      return screen
    end
  end
  return nil
end

local function runHook(hook)
  if not hook then
    return
  end
  if type(hook) == "function" then
    hook()
    return
  end
  if type(hook) == "string" and hook ~= "" then
    hs.execute(hook, true)
  end
end

local function frameForPlacement(screenFrame, cfg, defaultWidth, defaultHeight)
  local placement = cfg.placement
  if placement == "fullScreen" then
    return { x = screenFrame.x, y = screenFrame.y, w = screenFrame.w, h = screenFrame.h }
  end

  if placement == "left" then
    return { x = screenFrame.x, y = screenFrame.y, w = math.floor(screenFrame.w / 2), h = screenFrame.h }
  end

  if placement == "right" then
    local halfWidth = math.floor(screenFrame.w / 2)
    return { x = screenFrame.x + halfWidth, y = screenFrame.y, w = screenFrame.w - halfWidth, h = screenFrame.h }
  end

  if placement == "middle" then
    local widthRatio = clampFraction(cfg.width, 0.6)
    local width = math.floor(screenFrame.w * widthRatio)
    return {
      x = screenFrame.x + math.floor((screenFrame.w - width) / 2),
      y = screenFrame.y,
      w = width,
      h = screenFrame.h,
    }
  end

  if placement == "topHalf" then
    return { x = screenFrame.x, y = screenFrame.y, w = screenFrame.w, h = math.floor(screenFrame.h / 2) }
  end

  local widthRatio = clampFraction(cfg.width, defaultWidth)
  local heightRatio = clampFraction(cfg.height, defaultHeight)
  local width = math.floor(screenFrame.w * widthRatio)
  local height = math.floor(screenFrame.h * heightRatio)
  return {
    x = screenFrame.x + math.floor((screenFrame.w - width) / 2),
    y = screenFrame.y + (tonumber(cfg.marginTop) or 0),
    w = width,
    h = height,
  }
end

function obj:_getAppConfig(action)
  return self.apps[action]
end

function obj:_findRunningApp(cfg)
  if cfg.bundleID then
    return hs.application.get(cfg.bundleID)
  end
  if cfg.app then
    return hs.application.find(cfg.app)
  end
  return nil
end

function obj:_launchOrFocus(cfg)
  if cfg.bundleID then
    hs.application.launchOrFocusByBundleID(cfg.bundleID)
    return hs.application.get(cfg.bundleID)
  end
  if cfg.app then
    hs.application.launchOrFocus(cfg.app)
    return hs.application.find(cfg.app)
  end
  return nil
end

function obj:_managed(app)
  if not app then
    return nil
  end

  local bundleID = app:bundleID()
  local name = app:name()
  for _, cfg in pairs(self.apps) do
    local bundleMatch = cfg.bundleID and bundleID and cfg.bundleID == bundleID
    local nameMatch = cfg.app and name and cfg.app == name
    if bundleMatch or nameMatch then
      return cfg
    end
  end
  return nil
end

function obj:_placeAppWindow(app, cfg)
  if not app then
    return
  end

  local win = app:mainWindow()
  if not win then
    hs.timer.doAfter(0.1, function()
      self:_placeAppWindow(app, cfg)
    end)
    return
  end

  local targetScreen = findScreenByName(cfg.screen) or win:screen() or hs.screen.mainScreen()
  local screenFrame = targetScreen:frame()
  local appFrame = frameForPlacement(screenFrame, cfg, self.defaultWidth, self.defaultHeight)
  win:setFrame(appFrame, 0)
  win:focus()
end

--- QuakeApps:toggle(action)
--- Method
--- Toggles a configured app: show/focus/place when hidden, hide when frontmost.
---
--- Parameters:
---  * action - A string key from `QuakeApps.apps`
---
--- Returns:
---  * The QuakeApps object
function obj:toggle(action)
  local cfg = self:_getAppConfig(action)
  if not cfg then
    hs.alert.show("QuakeApps: unknown action " .. tostring(action))
    return self
  end

  local app = self:_findRunningApp(cfg)
  if app and app:isFrontmost() and not app:isHidden() then
    app:hide()
    runHook(cfg.onHide)
    return self
  end

  app = self:_launchOrFocus(cfg)
  hs.timer.doAfter(0.0, function()
    if app and app:isRunning() then
      self:_placeAppWindow(app, cfg)
      runHook(cfg.onShow)
    end
  end)

  return self
end

--- QuakeApps:bindHotkeys()
--- Method
--- Binds all hotkeys declared in `QuakeApps.apps`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The QuakeApps object
function obj:bindHotkeys()
  for action, cfg in pairs(self.apps) do
    if cfg.hotkey and cfg.hotkey[1] and cfg.hotkey[2] then
      local mods = cfg.hotkey[1]
      local key = cfg.hotkey[2]
      local hk = hs.hotkey.bind(mods, key, function()
        self:toggle(action)
      end)
      table.insert(self._hotkeys, hk)
    end
  end
  return self
end

--- QuakeApps:stop()
--- Method
--- Stops watchers and removes all previously bound hotkeys.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The QuakeApps object
function obj:stop()
  for _, hk in ipairs(self._hotkeys) do
    hk:delete()
  end
  self._hotkeys = {}

  if self._watcher then
    self._watcher:stop()
    self._watcher = nil
  end

  return self
end

--- QuakeApps:start()
--- Method
--- Initializes hotkeys and starts app deactivation watcher for auto-hide.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The QuakeApps object
function obj:start()
  self:stop()
  self:bindHotkeys()

  self._watcher = hs.application.watcher.new(function(_, eventType, appObj)
    if eventType ~= hs.application.watcher.deactivated then
      return
    end

    local cfg = self:_managed(appObj)
    if not cfg then
      return
    end
    if cfg.autoHide == false then
      return
    end

    if appObj and appObj:isRunning() and not appObj:isHidden() then
      appObj:hide()
      runHook(cfg.onHide)
    end
  end)
  self._watcher:start()

  return self
end

return obj

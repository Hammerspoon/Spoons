--- === MusicAppMediaFix ===
---
--- Override macOS behaviour and send all media keys (play/prev/next) to
--- the last active of a specified list of apps
local obj = { __gc = true }
--obj.__index = obj
setmetatable(obj, obj)
obj.__gc = function(t)
    t:stop()
end

-- Metadata
obj.name = "MusicAppMediaFix"
obj.version = "1.0"
obj.author = "Matheus Salmi <mathsalmi@gmail.com>, Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- MusicAppMediaFix.mediaApps
--- Variable
--- List of applications to control with the media keys
obj.mediaApps = { "Music" }

obj.eventtap = nil
obj.appWatcher = nil
obj.currentApp = nil

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

function obj:init()
    self.currentApp = self.mediaApps[1]
    self.eventtap = hs.eventtap.new({hs.eventtap.event.types.systemDefined}, self.mediaKeyCallback)
    self.appWatcher = hs.application.watcher.new(self.appWatcherCallback)
end

function obj.mediaKeyCallback(event)
    local data = event:systemKey()

    -- ignore everything but media keys
    if data["key"] ~= "PLAY" and data["key"] ~= "FAST" and data["key"] ~= "REWIND" then
        return false, nil
    end

    -- handle action
    if data["down"] == false or data["repeat"] == true then
        for i, app in pairs(obj.mediaApps) do
          if app ~= obj.currentApp then
              hs.osascript.applescript('tell application "' .. app .. '" to pause')
          end
        end
        if data["key"] == "PLAY" then
            hs.applescript('tell application "' .. obj.currentApp .. '" to playpause')
        elseif data["key"] == "FAST" then
            hs.applescript('tell application "' .. obj.currentApp .. '" to next track')
        elseif data["key"] == "REWIND" then
            hs.applescript('tell application "' .. obj.currentApp .. '" to previous track')
        end
    end

    -- consume event
    return true, nil
end

function obj.appWatcherCallback(appName, eventType, app)
    if hs.fnutils.contains(obj.mediaApps, appName)
         and (eventType == hs.application.watcher.activated) then
       obj.currentApp = appName
       print("Sending media key events to " .. appName)
    end
end

--- MusicAppMediaFix:start()
--- Method
--- Starts the hs.eventtap that powers this Spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The MusicAppMediaFix object
function obj:start()
    if self.eventtap:isEnabled() ~= true then
        self.eventtap:start()
    end
    self.appWatcher:start()
    return self
end

--- MusicAppMediaFix:stop()
--- Method
--- Stops the hs.eventtap that powers this Spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The MusicAppMediaFix object
function obj:stop()
    if self.eventtap:isEnabled() then
        self.eventtap:stop()
    end
    self.appWatcher:stop()
    return self
end

return obj

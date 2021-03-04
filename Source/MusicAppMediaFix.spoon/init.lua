--- === MusicAppMediaFix ===
---
--- Override macOS behaviour and send all media keys (play/prev/next) to Music.app
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

obj.eventtap = nil

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

function obj:init()
    self.eventtap = hs.eventtap.new({hs.eventtap.event.types.systemDefined}, self.mediaKeyCallback)
end

function obj.mediaKeyCallback(event)
    local data = event:systemKey()

    -- ignore everything but media keys
    if data["key"] ~= "PLAY" and data["key"] ~= "FAST" and data["key"] ~= "REWIND" then
        return false, nil
    end

    -- handle action
    if data["down"] == false or data["repeat"] == true then
        if data["key"] == "PLAY" then
            hs.applescript('tell application "Music" to playpause')
        elseif data["key"] == "FAST" then
            hs.applescript('tell application "Music" to next track')
        elseif data["key"] == "REWIND" then
            hs.applescript('tell application "Music" to previous track')
        end
    end

    -- consume event
    return true, nil
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
    return self
end

return obj

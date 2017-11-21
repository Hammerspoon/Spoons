--- === HighSierraiTunesMediaFix ===
---
--- Override High Sierra behaviour and send all media keys (play/prev/next) to iTunes
local obj = { __gc = true }
--obj.__index = obj
setmetatable(obj, obj)
obj.__gc = function(t)
    t:stop()
end

-- Metadata
obj.name = "HighSierraiTunesMediaFix"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
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
    self.eventtap = hs.eventtap.new({hs.eventtap.event.types.NSSystemDefined}, self.mediaKeyCallback)
end

function obj.mediaKeyCallback(event)
    local delete = false

    local data = event:systemKey()

    if data["down"] == false or data["repeat"] == true then
        if data["key"] == "PLAY" then
            hs.itunes.playpause()
            delete = true
        elseif data["key"] == "FAST" then
            hs.itunes.next()
            delete = true
        elseif data["key"] == "REWIND" then
            hs.itunes.previous()
            delete = true
        end
    end

    return delete, nil
end

--- HighSierraiTunesMediaFix:start()
--- Method
--- Starts the hs.eventtap that powers this Spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The HighSierraiTunesMediaFix object
function obj:start()
    if self.eventtap:isEnabled() ~= true then
        self.eventtap:start()
    end
    return self
end

--- HighSierraiTunesMediaFix:stop()
--- Method
--- Stops the hs.eventtap that powers this Spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The HighSierraiTunesMediaFix object
function obj:stop()
    if self.eventtap:isEnabled() then
        self.eventtap:stop()
    end
    return self
end

return obj

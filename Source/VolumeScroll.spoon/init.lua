--- === VolumeScroll ===
---
--- Use mouse scroll wheel and modifiers to adjust volume.
---
--- Example usage:
---
--- ```
--- hs.loadSpoon("VolumeScroll")
--- spoon.VolumeScroll:start({ "cmd", "alt" })
--- ```
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/VolumeScroll.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/VolumeScroll.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "VolumeScroll"
obj.version = "1.1"
obj.author = "Garth Mortensen (voldemortensen)"
obj.twitter = "@voldemortensen"
obj.github = "@voldemortensen"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- VolumeScroll:init()
--- Method
--- Initialize spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The VolumeScroll object
function obj:init()
    self.mods = { "cmd" }
    return self
end

--- VolumeScroll:start([mods])
--- Method
--- Start event watcher.
---
--- Parameters:
---  * mods - an optional table containing the modifiers to bind in scrolling, e.g. `{ "cmd", "alt" }`. Defaults to `{ "cmd" }`
---
--- Returns:
---  * The VolumeScroll object
---
--- Notes:
---  * This is a method, so it must be called with a colon, e.g. `spoon.VolumeScroll:start({ "cmd", "alt" })`
function obj:start(mods)
    if type(mods) == 'table' then
        self.mods = mods
    end

    self.scrollWatcher = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(event)
        if event:getFlags():containExactly(self.mods) then
            local direction = event:getProperty(hs.eventtap.event.properties.scrollWheelEventFixedPtDeltaAxis1)
            local device = hs.audiodevice.defaultOutputDevice()
            local volume = device and device:outputVolume()
            if volume then
                if direction > 0 then
                    device:setOutputVolume(math.min(volume + 1, 100))
                elseif direction < 0 then
                    device:setOutputVolume(math.max(volume - 1, 0))
                end
            end
            return true
        end
        return false
    end)

    self.scrollWatcher:start()
    return self
end

--- VolumeScroll:stop()
--- Method
--- Stop the scroll watcher
---
--- Parameters:
---  * None
---
--- Returns:
---  * The VolumeScroll object
function obj:stop()
    if self.scrollWatcher then
        self.scrollWatcher:stop()
        self.scrollWatcher = nil
    end
    return self
end

return obj

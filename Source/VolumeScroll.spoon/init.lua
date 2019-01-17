--- === VolumeScroll ===
---
--- Use mouse scroll wheel and modifiers to adjust volume.
---

local obj={}
obj.__index = obj

-- Metadata
obj.name = "VolumeScroll"
obj.version = "1.0"
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
---
--- Returns:
---  * void
function obj:init()
    self.modifiers = hs.eventtap.event.newScrollEvent({0,0}, {'cmd'})
    self.flags = self.modifiers:getFlags()
end

--- VolumeScroll:start()
--- Method
--- Start event watcher.
---
--- Parameters:
---  * mods - a table containing the modifiers to bind in scrolling
---
--- Returns:
---  * void
function obj:start(mods)
    if mods ~= nil and type(mods) == 'table' then
        self.modifiers = hs.eventtap.event.newScrollEvent({0,0}, mods)
        self.flags = self.modifiers:getFlags()
    end

    self.scrollWatcher = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(event)
        local currentMods = event:getFlags()
        if self:sameMods(currentMods) then
            local direction = event:getProperty(hs.eventtap.event.properties.scrollWheelEventFixedPtDeltaAxis1)
            local device = hs.audiodevice.current()
            if direction > 0 then
                if device.volume < 100 then
                    device.device:setOutputVolume(device.volume + 1)
                end
            elseif direction < 0 then
                if device.volume > 0 then
                    device.device:setOutputVolume(device.volume - 1)
                end
            end
            return true
        end
        return false
    end)

    self.scrollWatcher:start()
end

--- VolumeScroll:stop()
--- Method
--- Stop the scroll watcher
---
--- Parameters:
---
--- Returns:
---  * void
function obj:stop()
    self.scrollWatcher:stop()
end

--- VolumeScroll:sameMods()
--- Method
--- Determine if a table of modifiers are the same modifiers passed into :start()
---
--- Parameters:
---  * mods - a table of modifiers
---
--- Returns:
---  * boolean - true if mods are same, false otherwise
function obj:sameMods(mods)
    if type(mods) ~= type(self.flags) then return false end
    if type(mods) ~= 'table' then return false end
    if self:tableLength(mods) ~= self:tableLength(self.flags) then return false end

    for key1, value1 in pairs(mods) do
        local value2 = self.flags[key1]
        if value1 ~= value2 then
            return false
        end
    end

    return true
end

--- VolumeScroll:tableLength(T)
--- Method
--- Determine the number of items in a table
---
--- Parameters:
---  * T - a table
---
--- Returns:
---  * number or boolean - the number of items in the table, false if T is not a table
function obj:tableLength(T)
    if type(T) == 'table' then
        local count = 0
        for _ in pairs(T) do count = count + 1 end
        return count
    else
        return false
    end
end

return obj

--- === AutoMuteOnSleep ===
---
--- Automatically set to 0 the volume of all output audio devices except Bluetooth devices when Mac goes to sleep.
--- Useful to avoid blasting sound when opening a Macbook in the public transport.
--- Note: This is primarily intended for portable Mac devices, which have internal speakers.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AutoMuteOnSleep.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AutoMuteOnSleep.spoon.zip)


local obj={}
obj.__index = obj

-- Metadata
obj.name = "AutoMuteOnSleep"
obj.version = "1.0"
obj.author = "devnoname120 <devnoname120@gmail.com"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.sleepWatcher = nil

local function muteNonBluetoothOutputDevices(state)
    if state == hs.caffeinate.watcher.systemDidWake or state == hs.caffeinate.watcher.systemWillSleep then
        local devices = hs.audiodevice.allOutputDevices()
    
        for _, device in ipairs(devices) do
            if device and device:transportType() ~= 'Bluetooth' then
                device:setVolume(0) or device:setMuted(true)
            end
        end
    end
end


function obj:init()
    self.sleepWatcher = hs.caffeinate.watcher.new(muteNonBluetoothOutputDevices)
end

function obj:start()
    self.sleepWatcher:start()
end

function obj:stop()
    self.sleepWatcher:stop()
end

return obj

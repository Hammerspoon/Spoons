--- === AllBrightness ===
---
--- Listens for keyboard brightness keypresses and alters brightness on all supported displays.
--- Note: This is primarily intended for Macs with no internal display, but should work for those with an internal display.
--- Note: External displays will only respond to brightness change requests if they were either made by Apple, or are LG UltraFine displays (which were designed by Apple).
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AllBrightness.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AllBrightness.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "AllBrightness"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.eventtap = nil
obj.brightness = nil
obj.steps = 17

function obj:init()
    self.eventtap = hs.eventtap.new({hs.eventtap.event.types.NSSystemDefined},
        function(mainEvent)
            local event = mainEvent:systemKey()
            if (not event or next(event) == nil) then
                -- This isn't an event we care about, quit now and let it propagate
                return false
            end

            obj.brightness = hs.screen.allScreens()[1]:getBrightness()
            local newBrightness = obj.brightness

            if (event['key'] == "BRIGHTNESS_UP") then
                if (event['repeat'] or not event['down']) then
                    newBrightness = newBrightness + 1/obj.steps
                end
            end

            if (event['key'] == "BRIGHTNESS_DOWN") then
                if (event['repeat'] or not event['down']) then
                    newBrightness = newBrightness - 1/obj.steps
                end
            end

            if newBrightness > 1.0 then
                newBrightness = 1.0
            end

            if newBrightness < 0.0 then
                newBrightness = 0.0
            end

            for _,screen in pairs(hs.screen.allScreens()) do
                --print("  set on: "..screen:name())
                screen:setBrightness(newBrightness)
            end

            obj.brightness = hs.screen.allScreens()[1]:getBrightness()
        end)
end

--- AllBrightness:start()
--- Function
--- Starts listening for keyboard brightness keys
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:start()
    self.brightness = hs.screen.allScreens()[1]:getBrightness()
    self.eventtap:start()
end

--- AllBrightness:stop()
--- Function
--- Stops listening for keyboard brightness keys
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:stop()
    self.eventtap:stop()
end

return obj

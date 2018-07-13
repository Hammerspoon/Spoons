
--- === MountedVolumes ===
---
--- Displays a list of mounted volumes and a pie chart for each indicating free space on the desktop
---
--- Download: https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MountedVolumes.spoon.zip

-- local logger  = require("hs.logger")
local canvas  = require("hs.canvas")
local stext   = require("hs.styledtext")
local fs      = require("hs.fs")
local fnutils = require("hs.fnutils")
local timer   = require("hs.timer")
local alert   = require("hs.alert")
local spoons  = require("hs.spoons")

local obj    = {
-- Metadata
    name      = "MountedVolumes",
    author    = "A-Ron",
    homepage  = "https://github.com/Hammerspoon/Spoons",
    license   = "MIT - https://opensource.org/licenses/MIT",
    spoonPath = debug.getinfo(1, "S").source:match("^@(.+/).+%.lua$"),
}
obj.version   = "0.2"
local metadataKeys = {} ; for k, v in fnutils.sortByKeys(obj) do table.insert(metadataKeys, k) end


local unitDetails = {
    [false] = { factor = 1024, labels = { "KiB", "MiB", "GiB", "TiB" } },
    [true]  = { factor = 1000, labels = { "KB",  "MB",  "GB",  "TB"  } },
}

local round = function(number, scale)
    scale = scale or 2
    return math.floor(number * (10^scale) + .5) / (10^scale)
end

local isnan = function(x) return x ~= x end

local getStats = function()
    local results = {}
    for i,v in fnutils.sortByKeys(fs.volume.allVolumes()) do
        local total, avail, label = v.NSURLVolumeTotalCapacityKey, v.NSURLVolumeAvailableCapacityKey, "bytes"
        for i2 = #unitDetails[obj.unitsInSI].labels, 1, -1 do
            local scale = unitDetails[obj.unitsInSI].factor ^ i2
            local newTotal = round(v.NSURLVolumeTotalCapacityKey     / scale)
            local newAvail = round(v.NSURLVolumeAvailableCapacityKey / scale)
            if newTotal > 1 and newAvail > 1 and not isnan(newAvail / newTotal) then
                total, avail, label = newTotal, newAvail, unitDetails[obj.unitsInSI].labels[i2]
                break
            end
        end

        table.insert(results, {
            v.NSURLVolumeNameKey,
            total,
            avail,
-- ejectability is a pain to figure out... and even this misses internal partitions which are not
-- the boot partition (e.g. BOOTCAMP)
            (v.NSURLVolumeIsRemovableKey or v.NSURLVolumeIsEjectableKey or not v.NSURLVolumeIsInternalKey)
                and true or false, -- normalize the above into a predictable value
            i,
            label,
        })
    end
    return results
end

obj.__index  = obj
obj.canvas   = canvas.new{}:mouseCallback(function(c, m, i, x, y)
    if m == "mouseUp" then
        local path = i:match("^eject:(.*)$")
        if path then
            if not fs.volume.eject(path) then
                alert("Unable to eject " .. path .. " at this time", 4)
            end
        end
    end
end):behavior{ "canJoinAllSpaces" }:level(canvas.windowLevels.desktopIcon + 1)

local updateVolumes = function(...)
    while (#obj.canvas > 0) do obj.canvas:removeElement() end
    obj.canvas:appendElements{
        id               = "background",
        type             = "rectangle",
        fillColor        = obj.backgroundColor,
        strokeColor      = obj.backgroundBorder,
        roundedRectRadii = { xRadius = obj.cornerRadius, yRadius = obj.cornerRadius },
        clipToPath       = true, -- makes for sharper edges
    }

    local volumeData = getStats()
    local legends, height, width = {}, 0, 0
    for i,v in ipairs(volumeData) do
        table.insert(legends, stext.new(
            string.format("%s\n%s of %s %s\nAvailable", v[1], v[3], v[2], v[6]),
            obj.textStyle
        ))
        local tmp = obj.canvas:minimumTextSize(legends[#legends])
        height, width = math.max(tmp.h, height), math.max(tmp.w, width)
    end

    local ejectText     = stext.new("⏏", {
        font = stext.defaultFonts.menuBar ,
        color = { white = obj.enableEjectButton and 0 or .3 },
    })
    local ejectTextSize = obj.canvas:minimumTextSize(ejectText)

    local offset = { x = 10, y = 10 }
    for i,v in ipairs(volumeData) do
        obj.canvas:appendElements{
            {
                type       = "circle",
                action     = "fill",
                fillColor  = obj.capacityColor,
                radius     = height / 2,
                center     = { x = offset.x + height / 2, y = offset.y + height / 2 },
                clipToPath = true,
            }, {
                type       = "arc",
                action     = "fill",
                fillColor  = obj.availableColor,
                radius     = height / 2,
                center     = { x = offset.x + height / 2, y = offset.y + height / 2 },
                startAngle = 0,
                endAngle   = 360 * (v[3] / v[2]),
                clipToPath = true,
            }, {
                type       = "text",
                text       = legends[i],
                frame      = {
                    x = offset.x + height + 10,
                    y = offset.y,
                    h = height,
                    w = width,
                }
            }, {
                type         = "text",
                id           = "eject:" .. v[5],
                text         = v[4] and ejectText or "",
                frame        = {
                    x = offset.x + height + width + 20,
                    y = offset.y + (height - ejectTextSize.h) / 2,
                    h = ejectTextSize.h,
                    w = ejectTextSize.w,
                },
                trackMouseUp = obj.enableEjectButton and v[4],
            }
        }
        offset.y = offset.y + height + 10
    end

    local newFrame = { x = obj.location.x, y = obj.location.y }
    newFrame.h = 10 + #volumeData * (height + 10)
    newFrame.w = 10 + height + 10 + width + 10 + ejectTextSize.w + 10
    if not obj.growsDownwards then newFrame.y = obj.location.y - newFrame.h end
    obj.canvas:frame(newFrame):show()
end

-- see obj.start
-- we use hs.timer.doAfter because the checkInterval may change and we want the next firing to reflect the new interval
local usageCheckUpdater
usageCheckUpdater = function(...)
    updateVolumes()
    obj._usageTimer = timer.doAfter(obj.checkInterval, usageCheckUpdater)
end

-- --- MountedVolumes.logger
-- --- Variable
-- --- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
-- obj.logger = logger.new(obj.name)

--- MountedVolumes.unitsInSI
--- Variable
--- Boolean, default false, indicating whether capacity is displayed in SI units (1 GB = 10^9 bytes) or Gibibytes (1 GiB = 2^30 bytes).
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.unitsInSI = false

--- MountedVolumes.textStyle
--- Variable
--- A table specifying the style as defined in `hs.styledtext` to display the volume name and usage details with. Defaults to:
---
---     {
---         font = { name = "Menlo", size = 10 },
---         color = { alpha = 1.0 },
---         paragraphStyle = { alignment = "center" },
---     }
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.textStyle = {
    font = { name = "Menlo", size = 10 },
    color = { alpha = 1.0 },
    paragraphStyle = { alignment = "center" },
}

--- MountedVolumes.enableEjectButton
--- Variable
--- A boolean, default true, indicating whether the eject button displayed next to removable volumes is enabled.
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.enableEjectButton = true

--- MountedVolumes.capacityColor
--- Variable
--- A table, as defined in `hs.drawing.color`, specifying the color to use for the in use portion of the volume's capacity pie chart. Defaults to `hs.drawing.color.x11.orangered`
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.capacityColor  = { list = "x11", name = "orangered" }

--- MountedVolumes.freeColor
--- Variable
--- A table, as defined in `hs.drawing.color`, specifying the color to use for the free portion of the volume's capacity pie chart. Defaults to `hs.drawing.color.x11.mediumspringgreen`
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.availableColor = { list = "x11", name = "mediumspringgreen" }

--- MountedVolumes.location
--- Variable
--- A table specifying the location on the screen of the starting corner of the display. Defaults to `{ x = 20, y = 22 }`.
--- See also `MountedValues.growsDownwards`.
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.location = { x = 20, y = 22 }

--- MountedVolumes.growsDownwards
--- Variable
--- A boolean, default true, indicating whether the displayed list grows downwards or upwards as more volumes are mounted.
--- Note that if this value is true, then `MountedVolumes.location` specifies the upper left corner of the display.  If this value is false, then `MountedVolumes.location` specifies the bottom left corner of the display.
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.growsDownwards = true

--- MountedVolumes.checkInterval
--- Variable
--- A number, default 120, specifying how often in seconds the free space on mounted volumes should be polled for current usage data.
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.checkInterval = 120

--- MountedVolumes.backgroundColor
--- Variable
--- A table, as defined in `hs.drawing.color`, specifying the color of the volume lists background. Defaults to `{ alpha = .7, white = .5 }`
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.backgroundColor = { alpha = .7, white = .5 }

--- MountedVolumes.backgroundBorder
--- Variable
--- A table, as defined in `hs.drawing.color`, specifying the color of the volume lists border. Defaults to `{ alpha = .5 }`
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.backgroundBorder = { alpha = .5 }

--- MountedVolumes.cornerRadius
--- Variable
--- A number, default 5, specifying how rounded the corners of the volume list background should be.
---
--- Changes will take effect when the next volume change occurs, when the next usage check occurs (see `MountedVolumes.checkInterval`), or when `MountedVolumes:show` is invoked, whichever occurs first.
obj.cornerRadius = 5

--- MountedVolumes:show()
--- Method
--- Display the volumes panel on the background and update it as volumes are mounted and unmounted.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The MountedVolumes object
---
--- Notes:
---  * If you make a change to any of the variables defining the visual appearance of the volume list, you can force the change to take immediate effect by invoking this method, even if the volume list is already being displayed.
obj.show = function(self)
    self = self or obj -- correct for calling this as a function
    if not obj._watcher then
        obj._watcher    = fs.volume.new(updateVolumes):start()
        obj._usageTimer = timer.doAfter(obj.checkInterval, usageCheckUpdater)
    end
    updateVolumes()
    return self
end

--- MountedVolumes:hide()
--- Method
--- Hide the volumes panel on the background and stop watching for volume changes
---
--- Parameters:
---  * None
---
--- Returns:
---  * The MountedVolumes object
obj.hide = function(self)
    self = self or obj -- correct for calling this as a function
    if obj._watcher then
        obj._watcher:stop()
        obj._watcher = nil
        obj._usageTimer:stop()
        obj._usageTimer = nil
    end
    obj.canvas:hide()
    return self
end

--- MountedVolumes:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for MountedVolumes
---
--- Parameters:
---  * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
---    * "show"   - Show the volume list
---    * "hide"   - Hide the volume list
---    * "toggle" - If the volume list is visible then hide it; otherwise show the list.
---
--- Returns:
---  * None
---
--- Notes:
---  * the `mapping` table is a table of one or more key-value pairs of the format `command = { { modifiers }, key }` where:
---    * `command`   - is one of the commands listed above
---    * `modifiers` - is a table containing keyboard modifiers, as specified in `hs.hotkey.bind()`
---    * `key`       - is a string containing the name of a keyboard key, as specified in `hs.hotkey.bind()`
obj.bindHotkeys = function(self, mapping)
    local def = {
        show = obj.show,
        hide = obj.hide,
        toggle = function() if obj._watcher then obj.hide() else obj.show() end end,
    }
    spoons.bindHotkeysToSpec(def, mapping)
end

return setmetatable(obj, {
    __tostring = function(self)
        local result, fieldSize = "", 0
        for i, v in ipairs(metadataKeys) do fieldSize = math.max(fieldSize, #v) end
        for i, v in ipairs(metadataKeys) do
            result = result .. string.format("%-"..tostring(fieldSize) .. "s %s\n", v, self[v])
        end
        return result
    end,
})

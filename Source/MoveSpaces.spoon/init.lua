--- === MoveSpaces ===
---
--- Move window to the space to the right or left
---
--- Much of the code was written by Szymon Kaliski <hi@szymonkaliski.com>, converted to spoon by Tyler Thrailkill <tyler.b.thrailkill@gmail.com>
---
--- https://github.com/snowe2010

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "MoveSpaces"
obj.version = "1.0"
obj.author = "Tyler Thrailkill <tyler.b.thrailkill@gmail.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

local spaces = require('hs._asm.undocumented.spaces')
local spaceInDirection = dofile(obj.spoonPath .. "/ext/spaces.lua").spaceInDirection
local isSpaceFullscreenApp = dofile(obj.spoonPath .. "/ext/spaces.lua").isSpaceFullscreenApp
local focusScreen = dofile(obj.spoonPath .. "/ext/screen.lua").focusScreen

local cache  = {
    mousePosition   = nil,
    windowPositions = hs.settings.get('windowPositions') or {}
}

local module = { cache = cache }

local function moveToSpace(win, direction)
    local clickPoint = win:zoomButtonRect()
    local sleepTime = 1000
    local targetSpace = spaceInDirection(direction)

    -- check if all conditions are ok to move the window
    local shouldMoveWindow =
        hs.fnutils.every(
        {
            clickPoint ~= nil,
            targetSpace ~= nil,
            not isSpaceFullscreenApp(targetSpace),
            not cache.movingWindowToSpace
        },
        function(test)
            return test
        end
    )

    if not shouldMoveWindow then
        return
    end

    cache.movingWindowToSpace = true

    cache.mousePosition = cache.mousePosition or hs.mouse.getAbsolutePosition()

    clickPoint.x = clickPoint.x + clickPoint.w + 5
    clickPoint.y = clickPoint.y + clickPoint.h / 2

    -- fix for Chrome UI
    if win:application():title() == "Google Chrome" then
        clickPoint.y = clickPoint.y - clickPoint.h
    end

    -- focus screen before switching window
    focusScreen(win:screen())

    hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, clickPoint):post()
    hs.timer.usleep(sleepTime)

    hs.eventtap.keyStroke({"cmd", "ctrl"}, direction == "east" and "right" or "left")

    hs.timer.waitUntil(
        function()
            return spaces.activeSpace() == targetSpace
        end,
        function()
            hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, clickPoint):post()

            -- resetting mouse after small timeout is needed for focusing screen to work properly
            hs.mouse.setAbsolutePosition(cache.mousePosition)
            cache.mousePosition = nil

            -- reset cache
            cache.movingWindowToSpace = false
        end,
        0.01 -- check every 1/100 of a second
    )
end

function obj:bindHotkeys(keys)
    hs.hotkey.bindSpec(
        keys["space_right"],
        function()
            moveToSpace(hs.window.frontmostWindow(), "east")
        end
    )
    hs.hotkey.bindSpec(
        keys["space_left"],
        function()
            moveToSpace(hs.window.frontmostWindow(), "west")
        end
    )
end

return obj

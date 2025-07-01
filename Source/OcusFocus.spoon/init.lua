--- === OcusFocus ===
---
--- Prevents background apps from stealing focus, while allowing user-triggered switches like Cmd+Tab, Dock clicks, and iTerm2 hotkey (e.g., Shift+Space).
--- Also prevents Dock-launched apps from stealing focus if the user switched elsewhere while the app was launching.

local obj = {}
obj.__index = obj

obj.name = "OcusFocus"
obj.version = "1.0"
obj.author = "Felipe Rohde <feliperohde@gmail.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/Hammerspoon/Spoons"

local lastFocusedWindow = nil
local isUserSwitching = false
local blockInput = false
local allowNextActivation = false
local allowNextApp = nil

-- Dock launch context
local dockLaunchedApp = nil
local dockLaunchTime = nil
local dockLaunchWindowCancelThreshold = 0.5 -- seconds

-- Customize this for your own hotkey (e.g., iTerm2 trigger)
local hotkeyModifiers = { "shift" }
local hotkeyKey = "space"
local hotkeyAppName = "iTerm2"

-- Apps that are always allowed to steal focus
local focusStealWhitelist = {
    ["Finder"] = true,
    ["SystemUIServer"] = true,
    ["System Preferences"] = true,
    ["System Settings"] = true,
    ["SecurityAgent"] = true,
    ["com.apple.authorizationhost"] = true,
    ["com.apple.loginwindow"] = true,
    ["Safari"] = true,
    ["Google Chrome"] = true,
    ["1Password"] = true
}

local function isAllowedToStealFocus(app)
    local appName = app:name()
    if focusStealWhitelist[appName] then return true end

    if allowNextApp and appName == allowNextApp then
        allowNextApp = nil
        return true
    end

    -- Dock-launched app logic
    if dockLaunchedApp and appName == dockLaunchedApp then
        local elapsed = hs.timer.secondsSinceEpoch() - (dockLaunchTime or 0)
        if elapsed <= dockLaunchWindowCancelThreshold then
            return false -- too soon, user may have canceled
        end
        -- else: too late to cancel
        dockLaunchedApp = nil
    end

    local win = app:focusedWindow()
    if not win then return false end

    local role = win:role()
    local subrole = win:subrole()

    return (
        subrole == "AXDialog"
        or subrole == "AXSystemDialog"
        or role == "AXFloatingWindow"
    )
end

local function registerUserSwitch()
    isUserSwitching = true
    hs.timer.doAfter(0.1, function()
        local win = hs.window.focusedWindow()
        if win then lastFocusedWindow = win end
        isUserSwitching = false
    end)
end

--- OcusFocus:start()
function obj:start()
    -- Modifier keys: Cmd+Tab, etc.
    self.modKeyWatcher = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(evt)
        local flags = evt:getFlags()
        if flags["cmd"] or flags["ctrl"] or flags["alt"] or flags["shift"] then
            allowNextActivation = true
            dockLaunchedApp = nil -- user canceled dock app
        end
        return false
    end)
    self.modKeyWatcher:start()

    -- Mouse click (e.g. Dock click)
    self.mouseClickWatcher = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown }, function(evt)
        local pos = hs.mouse.getAbsolutePosition()
        local appIconUnderCursor = hs.application.frontmostApplication()
        if appIconUnderCursor then
            dockLaunchedApp = appIconUnderCursor:name()
            dockLaunchTime = hs.timer.secondsSinceEpoch()
        end
        allowNextActivation = true
        return false
    end)
    self.mouseClickWatcher:start()

    -- Hotkey watcher for iTerm2 (or other apps)
    self.customHotkeyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(evt)
        local flags = evt:getFlags()
        local key = evt:getCharacters(true)
        local match = hs.fnutils.every(hotkeyModifiers, function(mod)
            return flags[mod]
        end)
        if match and key:lower() == hotkeyKey then
            allowNextApp = hotkeyAppName
        end
        return false
    end)
    self.customHotkeyWatcher:start()

    -- Input blocker to prevent interference during correction
    self.blockInputTap = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.rightMouseDown
    }, function(evt)
        if blockInput then return true end
        return false
    end)
    self.blockInputTap:start()

    -- App watcher
    self.appWatcher = hs.application.watcher.new(function(appName, eventType, app)
        if eventType == hs.application.watcher.activated then
            local current = hs.window.focusedWindow()

            if isUserSwitching or allowNextActivation then
                registerUserSwitch()
                allowNextActivation = false
                return
            end

            if isAllowedToStealFocus(app) then
                lastFocusedWindow = current
                return
            end

            -- Restore previous window
            if lastFocusedWindow and current and current:id() ~= lastFocusedWindow:id() then
                blockInput = true
                hs.timer.doAfter(0.05, function()
                    if lastFocusedWindow then
                        lastFocusedWindow:becomeMain()
                        lastFocusedWindow:focus()
                    end
                    hs.timer.doAfter(0.15, function()
                        blockInput = false
                    end)
                end)
            end
        end
    end)
    self.appWatcher:start()
end

--- OcusFocus:stop()
function obj:stop()
    if self.modKeyWatcher then self.modKeyWatcher:stop() end
    if self.mouseClickWatcher then self.mouseClickWatcher:stop() end
    if self.customHotkeyWatcher then self.customHotkeyWatcher:stop() end
    if self.blockInputTap then self.blockInputTap:stop() end
    if self.appWatcher then self.appWatcher:stop() end
end

return obj
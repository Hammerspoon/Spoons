--- === WindowManagerPlus.api ===
---
--- API module for WindowManagerPlus
---
--- This module provides the main API interface for WindowManagerPlus, including
--- hotkey bindings, layout management, and window manager lifecycle control.

local API = {}
API.__index = API

--- WindowManagerPlus.api:new(spoon)
--- Constructor
--- Creates a new API instance
---
--- Parameters:
---  * spoon - The WindowManagerPlus spoon instance
---
--- Returns:
---  * API object
function API:new(spoon)
    return setmetatable({spoon = spoon}, self)
end

--- WindowManagerPlus.api:cycleLayout()
--- Method
--- Cycles through available layouts
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Updates the layout for the current space
---  * Shows an alert with the new layout name
function API:cycleLayout()
    local current = self.spoon:getLayoutForCurrentSpace()
    local newIndex = (current % #self.spoon.layouts) + 1
    self.spoon:setLayoutForCurrentSpace(newIndex)
    self.spoon.core:showAlert("Layout: " .. self.spoon.layouts[newIndex]:upper())
    self.spoon.state.layoutChanged = true
    self.spoon:updateLayout()
end

--- WindowManagerPlus.api:chooseLayout()
--- Method
--- Shows a chooser dialog for layout selection
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Displays a Hammerspoon chooser with all available layouts
---  * The current layout is marked with "Current" subtitle
function API:chooseLayout()
    local choices = {}
    for i, name in ipairs(self.spoon.layouts) do
        table.insert(choices, {
            text = name:upper(),
            subText = name == self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()] and "Current" or "",
            index = i
        })
    end
    
    hs.chooser.new(function(choice)
        if choice then
            self.spoon:setLayoutForCurrentSpace(choice.index)
            self.spoon.state.layoutChanged = true
            self.spoon:updateLayout()
        end
    end):choices(choices):show()
end

--- WindowManagerPlus.api:togglePerSpaceLayouts()
--- Method
--- Toggles per-space layout memory
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * When enabled, each macOS Space remembers its own layout
---  * When disabled, all Spaces use the same layout
function API:togglePerSpaceLayouts()
    self.spoon.config.usePerSpaceLayouts = not self.spoon.config.usePerSpaceLayouts
    self.spoon.core:showAlert("Per-space layouts: " .. (self.spoon.config.usePerSpaceLayouts and "ON" or "OFF"))
    self.spoon:saveSettings()
end

--- WindowManagerPlus.api:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for WindowManagerPlus functions
---
--- Parameters:
---  * mapping - A table of hotkey mappings where keys are function names and values are hotkey definitions
---
--- Returns:
---  * The WindowManagerPlus spoon instance for method chaining
---
--- Notes:
---  * Available functions:
---    * Core: focus, toggleFloatingWindow
---    * Layout: cycleLayout, chooseLayout, togglePerSpaceLayouts, toggleLayoutOrientation
---    * Resizing: resizeLeft, resizeRight, resizeUp, resizeDown, balanceLayout
---    * Floating: floatingPositionUp/Down/Left/Right, floatingFullscreen, floatingNextScreen
---    * Window: showLayoutInfo, rotateWindowsClockwise/CounterClockwise, moveToPosition1-6
---
--- Example:
--- ```lua
--- wm:bindHotkeys({
---     cycleLayout = {{"alt", "cmd"}, "space"},
---     focus = {{"alt", "cmd"}, "j"}
--- })
--- ```
function API:bindHotkeys(mapping)
    local core, spoon = self.spoon.core, self.spoon
    
    local def = {
        -- Core functions
        focus = function() core:focusNextWindow() end,
        toggleFloatingWindow = function() core:toggleFloatingWindow() end,
        
        -- Layout management
        cycleLayout = function() self:cycleLayout() end,
        chooseLayout = function() self:chooseLayout() end,
        togglePerSpaceLayouts = function() self:togglePerSpaceLayouts() end,
        toggleLayoutOrientation = function() core:toggleLayoutOrientation() end,
        
        -- Legacy bindings
        toggleSplitDirection = function() core:toggleSplitDirection() end,
        toggleMasterOrientation = function() core:toggleMasterOrientation() end,
        
        -- Window resizing
        resizeLeft = function() core:resizeFocusedWindow("left") end,
        resizeRight = function() core:resizeFocusedWindow("right") end,
        resizeUp = function() core:resizeFocusedWindow("up") end,
        resizeDown = function() core:resizeFocusedWindow("down") end,
        balanceLayout = function() core:balanceBSP() end,
        balanceBSP = function() core:balanceBSP() end, -- Legacy
        
        -- Floating window management
        floatingPositionUp = function() core:floatingWindowPosition("up") end,
        floatingPositionDown = function() core:floatingWindowPosition("down") end,
        floatingPositionLeft = function() core:floatingWindowPosition("left") end,
        floatingPositionRight = function() core:floatingWindowPosition("right") end,
        floatingFullscreen = function() core:floatingWindowFullscreen() end,
        floatingNextScreen = function() core:floatingWindowNextScreen() end,
        floatingHalfLeft = function() core:floatingWindowHalves("left_half") end,
        floatingHalfRight = function() core:floatingWindowHalves("right_half") end,
        floatingHalfTop = function() core:floatingWindowHalves("top_half") end,
        floatingHalfBottom = function() core:floatingWindowHalves("bottom_half") end,
        floatingCenter = function() core:floatingWindowHalves("center") end,
        floatingMaximize = function() core:floatingWindowHalves("maximize") end,
        
        -- Layout info and window management
        showLayoutInfo = function() core:showLayoutInfo() end,
        rotateWindowsClockwise = function() core:rotateWindows(true) end,
        rotateWindowsCounterClockwise = function() core:rotateWindows(false) end,

    }
    
    -- Generate position functions dynamically
    for i = 1, 6 do
        def["moveToPosition" .. i] = function() core:moveToPosition(i) end
    end
    
    hs.spoons.bindHotkeysToSpec(def, mapping)
    return spoon
end

--- WindowManagerPlus.api:start()
--- Method
--- Starts the window manager
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowManagerPlus spoon instance
---
--- Notes:
---  * Sets up window filters and event watchers
---  * Initializes floating window detection
---  * Performs initial layout update
function API:start()
    local spoon = self.spoon
    
    -- Safety function to get timing values with defaults
    local function getTiming(key, default)
        if spoon.config and spoon.config.timing and type(spoon.config.timing[key]) == "number" then
            return spoon.config.timing[key]
        else
            print("WARNING: Using default for timing." .. key .. " = " .. default)
            return default
        end
    end
    
    local updateLayout = function() 
        if not spoon.state.ignoreNextUpdate then
            local delay = getTiming("layoutUpdateDelay", 0.08)
            hs.timer.doAfter(delay, function() 
                spoon:updateLayout(false) 
            end)
        end
    end
    
    -- Create a filter for tab-aware applications
    local tabApps = {
        ["Finder"] = true,
        ["Terminal"] = true,
        ["iTerm2"] = true,
        ["Safari"] = true,
        ["Google Chrome"] = true,
        ["Firefox"] = true,
        ["Microsoft Edge"] = true,
        ["Arc"] = true,
    }
    
    -- Main window filter with selective event handling
    local windowFilter = hs.window.filter.default
    
    -- For non-tab apps, subscribe to all events
    windowFilter:setAppFilter(".*", {
        rejectTitles = {"^$"}, -- Reject empty titles
        allowRoles = {"AXStandardWindow"},
    })
    
    -- Subscribe to events that should trigger layout updates
    windowFilter:subscribe({
        hs.window.filter.windowCreated,
        hs.window.filter.windowDestroyed,
        hs.window.filter.windowMinimized,
        hs.window.filter.windowUnminimized,
    }, updateLayout)
    
    -- Special handling for windowsChanged event
    windowFilter:subscribe(hs.window.filter.windowsChanged, function(win, appName)
        -- Skip update if it's a tab app and window count hasn't changed
        if win and tabApps[appName or win:application():name()] then
            local currentWindows = spoon.helpers:getRelevantWindows()
            if #currentWindows == #spoon.state.windows then
                return -- Skip update - likely just a tab change
            end
        end
        updateLayout()
    end)

    windowFilter:subscribe(hs.window.filter.windowFocused, function(win)
        if win then 
            win:raise()
            spoon.ui:updateAll()
        end
    end)

    windowFilter:subscribe(hs.window.filter.windowMoved, function(win) 
        if win and not (spoon.state.floatingWindows[win:id()] or spoon.state.ignoreNextUpdate) then
            -- Check if this is a real move vs a tab-related repositioning
            local app = win:application()
            if app and tabApps[app:name()] then
                -- For tab apps, only update if the window actually moved significantly
                local lastFrame = spoon.state.lastWindowFrames and spoon.state.lastWindowFrames[win:id()]
                local currentFrame = win:frame()
                
                if lastFrame and math.abs(lastFrame.x - currentFrame.x) < 5 and 
                   math.abs(lastFrame.y - currentFrame.y) < 5 then
                    return -- Skip minor movements that might be tab-related
                end
            end
            
            local delay = getTiming("layoutUpdateDelay", 0.08)
            hs.timer.doAfter(delay, function() 
                spoon:updateLayout(true)
            end)
        end
    end)

    -- Space change watcher
    self.spaceWatcher = hs.spaces.watcher.new(function() 
        local delay = getTiming("spaceChangeDelay", 0.12)
        hs.timer.doAfter(delay, function() 
            spoon.state.layoutChanged = true
            spoon:updateLayout() 
        end) 
    end):start()

    -- Dialog and system window filters
    local function setupFloatingFilter(appFilters, allowRoles)
        local filter = hs.window.filter.new(false)
        if allowRoles then
            filter:setAppFilter(".*", {allowRoles = allowRoles})
        else
            for app, enabled in pairs(appFilters) do
                filter:setAppFilter(app, enabled)
            end
        end
        
        filter:subscribe(hs.window.filter.windowCreated, function(win)
            if win then
                spoon.state.floatingWindows[win:id()] = true
                if allowRoles then -- Center dialogs
                    local frame, screen = win:frame(), hs.screen.mainScreen():frame()
                    frame.x = screen.x + (screen.w - frame.w) / 2
                    frame.y = screen.y + (screen.h - frame.h) / 2
                    win:setFrame(frame)
                end
            end
        end)
    end
    
    -- Setup dialog filter
    setupFloatingFilter(nil, {"AXDialog", "AXSheet", "AXSystemDialog"})
    
    -- Setup system apps filter
    setupFloatingFilter({
        ["System Preferences"] = true,
        ["System Settings"] = true,
        ["Activity Monitor"] = true,
        ["Console"] = true,
        ["Disk Utility"] = true,
        ["Keychain Access"] = true
    })

    -- Initialize frame tracking for tab detection
    spoon.state.lastWindowFrames = {}
    hs.timer.doEvery(1, function()
        local frames = {}
        for _, win in ipairs(hs.window.allWindows()) do
            if win and win:id() then
                frames[win:id()] = win:frame()
            end
        end
        spoon.state.lastWindowFrames = frames
    end)

    -- Initial setup
    local initialDelay = getTiming("initialSetupDelay", 0.15)
    hs.timer.doAfter(initialDelay, function()
        spoon.state.layoutChanged = true
        spoon:updateLayout()
        spoon.core:showAlert("WindowManager+ Ready")
    end)

    return spoon
end

--- WindowManagerPlus.api:setExcludedApps(appList)
--- Method
--- Sets the list of excluded applications
---
--- Parameters:
---  * appList - A table of application names to exclude from window management
---
--- Returns:
---  * The WindowManagerPlus spoon instance
---
--- Notes:
---  * Excluded apps will not be managed by WindowManagerPlus
---  * Can be a list table {"App1", "App2"} or key-value table {App1 = true, App2 = true}
function API:setExcludedApps(appList)
    self.spoon.config.excludedApps = {}
    if type(appList) == "table" then
        for k, v in pairs(appList) do
            local key, val = type(k) == "number" and v or k, type(k) == "number" and true or v
            self.spoon.config.excludedApps[key] = val
            self.spoon.config.excludedApps[string.lower(key)] = val
        end
    end
    return self.spoon
end

--- WindowManagerPlus.api:configure(config)
--- Method
--- Configures WindowManagerPlus settings
---
--- Parameters:
---  * config - A table of configuration options
---
--- Returns:
---  * The WindowManagerPlus spoon instance
---
--- Notes:
---  * See README.md for all available configuration options
---  * Configuration is merged with existing settings
function API:configure(config)
    for k, v in pairs(config) do
        if k == "excludedApps" then
            self:setExcludedApps(v)
        else
            self.spoon.config[k] = v
        end
    end
    self.spoon:processColors()
    return self.spoon
end

return API
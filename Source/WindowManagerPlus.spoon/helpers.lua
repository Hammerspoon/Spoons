--- === WindowManagerPlus.helpers ===
---
--- Helper functions for WindowManagerPlus
---
--- This module provides window detection, filtering, and utility functions
--- for determining which windows should be managed by WindowManagerPlus.

local Helpers = {}
Helpers.__index = Helpers

--- WindowManagerPlus.helpers:new(spoon)
--- Constructor
--- Creates a new Helpers instance
---
--- Parameters:
---  * spoon - The WindowManagerPlus spoon instance
---
--- Returns:
---  * Helpers object
function Helpers:new(spoon)
    return setmetatable({spoon = spoon}, self)
end

--- WindowManagerPlus.helpers:isRelevantWindow(win)
--- Method
--- Determines if a window should be managed by WindowManagerPlus
---
--- Parameters:
---  * win - hs.window object to check
---
--- Returns:
---  * Boolean - true if window should be managed, false otherwise
---
--- Notes:
---  * Checks multiple criteria to filter windows:
---    * Must be standard, visible window
---    * Application must not be in excludedApps list
---    * Title must not contain status/settings keywords
---    * Window must be larger than smallWindowThreshold
---  * Windows that fail checks may be marked as floating
---  * This is the main filtering function for window management
function Helpers:isRelevantWindow(win)
    if not win or not win:isStandard() or not win:isVisible() then return false end
    
    local app = win:application()
    if not app then return false end
    
    local appName = app:name()
    if not appName then return false end
    
    -- Check excluded apps
    local excluded = self.spoon.config.excludedApps
    if excluded[appName] or excluded[string.lower(appName)] then return false end
    
    local title = win:title() or ""
    local lowerTitle = string.lower(title)
    
    -- Check keywords and mark as floating if found
    local function checkKeywords(keywords)
        for _, keyword in ipairs(keywords) do
            if string.find(lowerTitle, string.lower(keyword)) then
                self.spoon.state.floatingWindows[win:id()] = true
                return true
            end
        end
        return false
    end
    
    -- Check status and settings keywords
    if checkKeywords(self.spoon.config.statusKeywords) or 
       checkKeywords(self.spoon.config.settingsKeywords) then
        return false
    end
    
    -- Advanced settings detection
    if self:isSettingsWindow(win, appName, title) then
        self.spoon.state.floatingWindows[win:id()] = true
        return false
    end
    
    -- Check small window threshold
    local frame = win:frame()
    local threshold = self.spoon.config.smallWindowThreshold
    if frame.w < threshold.width and frame.h < threshold.height then
        self.spoon.state.floatingWindows[win:id()] = true
        return false
    end
    
    return true
end

--- WindowManagerPlus.helpers:isSettingsWindow(win, appName, title)
--- Method
--- Advanced detection for settings/preferences windows
---
--- Parameters:
---  * win - hs.window object to check
---  * appName - Name of the application
---  * title - Window title
---
--- Returns:
---  * Boolean - true if window appears to be a settings window
---
--- Notes:
---  * Uses multiple heuristics to detect settings windows:
---    * Window subrole (AXDialog, AXSystemDialog)
---    * Title patterns (preferences, settings, options, etc.)
---    * App-specific patterns (e.g., "AppName Preferences")
---    * Size-based detection for small windows with settings keywords
---  * Supports multiple languages for settings keywords
---  * This catches settings windows that might not be caught by simple keyword matching
function Helpers:isSettingsWindow(win, appName, title)
    -- Check window subrole
    local subrole = win:subrole()
    if subrole then
        local lowerSubrole = string.lower(subrole)
        if subrole == "AXSystemDialog" or subrole == "AXDialog" or
           string.find(lowerSubrole, "pref") or string.find(lowerSubrole, "setting") then
            return true
        end
    end
    
    -- App-specific patterns - consolidated into table
    local appPatterns = {
        [appName .. " Preferences"] = true,
        [appName .. " Settings"] = true,
        [appName .. " Options"] = true,
        ["System Preferences"] = (appName == "System Preferences"),
        ["System Settings"] = (appName == "System Settings"),
        ["Preferences"] = true,
        ["Settings"] = true,
    }
    
    if appPatterns[title] then return true end
    
    -- Pattern matching - consolidated arrays
    local settingsPatterns = {
        "^preferences$", "^settings$", "^options$", "^configuration$",
        "preferences$", "settings$", "options$", " settings$", " preferences$",
        "^about ", "^inspector ", "^properties ", "account settings",
        "privacy settings", "security settings", "network settings",
        "display settings", "audio settings", "keyboard settings"
    }
    
    local lowerTitle = string.lower(title)
    for _, pattern in ipairs(settingsPatterns) do
        if string.match(lowerTitle, pattern) then return true end
    end
    
    -- Size-based detection with keywords
    local frame = win:frame()
    if frame.w < 800 and frame.h < 600 then
        local settingsWords = {"setting", "preference", "config", "option"}
        for _, word in ipairs(settingsWords) do
            if string.find(lowerTitle, word) then return true end
        end
    end
    
    return false
end

--- WindowManagerPlus.helpers:getRelevantWindows()
--- Method
--- Gets all windows that should be managed
---
--- Parameters:
---  * None
---
--- Returns:
---  * Array of hs.window objects that are relevant and not floating
---
--- Notes:
---  * Filters all windows through isRelevantWindow
---  * Excludes windows marked as floating
---  * Returns windows in the order they appear on screen
---  * This is the main function for getting windows to tile
function Helpers:getRelevantWindows()
    local windows = {}
    for _, win in ipairs(hs.window.allWindows()) do
        if self:isRelevantWindow(win) and not self.spoon.state.floatingWindows[win:id()] then
            table.insert(windows, win)
        end
    end
    return windows
end

--- WindowManagerPlus.helpers:getScreenFrame()
--- Method
--- Gets the usable screen area with gap applied
---
--- Parameters:
---  * None
---
--- Returns:
---  * Table with x, y, w, h representing the usable screen area
---
--- Notes:
---  * Applies the configured gap to all edges of the screen
---  * Returns coordinates for the main screen
---  * The returned frame is where windows will be tiled
function Helpers:getScreenFrame()
    local screen = hs.screen.mainScreen():frame()
    local gap = self.spoon.config.gap
    return {
        x = screen.x + gap,
        y = screen.y + gap,
        w = screen.w - (gap * 2),
        h = screen.h - (gap * 2)
    }
end

return Helpers
--- === WindowManagerPlus ===
---
--- A powerful window management system for macOS via Hammerspoon
---
--- WindowManagerPlus provides multiple tiling layouts (BSP, Master/Stack, Stacking, Floating)
--- with intelligent window detection, per-space layout memory, and visual indicators.
---
--- Download: https://gitlab.com/snicolis/windowmanagerplus
---
--- Example configuration:
--- ```lua
--- local wm = hs.loadSpoon("WindowManagerPlus")
--- wm:configure({
---     gap = 8,
---     usePerSpaceLayouts = true,
---     excludedApps = {"Calculator", "System Preferences"}
--- }):bindHotkeys({
---     cycleLayout = {{"alt", "cmd"}, "space"},
---     focus = {{"alt", "cmd"}, "j"},
---     toggleFloatingWindow = {{"alt", "cmd"}, "f"},
---     resizeLeft = {{"alt", "ctrl"}, "left"},
---     resizeRight = {{"alt", "ctrl"}, "right"}
--- }):start()
--- ```

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowManagerPlus"
obj.version = "0.1.0"
obj.author = "Stamatios Nicolis <snicolis@gmail.com>"
obj.homepage = "https://gitlab.com/snicolis/windowmanagerplus"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowManagerPlus.config
--- Variable
--- Configuration table for WindowManagerPlus
---
--- The configuration table supports the following keys:
---  * `gap` - Pixel gap between windows (default: 8)
---  * `excludedApps` - Table of application names to exclude from management
---  * `statusKeywords` - Keywords for detecting status windows (default: {"status", "copy", "progress", "loading", "downloading"})
---  * `settingsKeywords` - Keywords for detecting settings windows
---  * `usePerSpaceLayouts` - Whether to remember layouts per Space (default: true)
---  * `resizing` - Table with `step` (resize increment), `minRatio`, `maxRatio` for split ratios
---  * `timing` - Table with various timing delays in seconds
---  * `smallWindowThreshold` - Table with `width` and `height` for auto-floating small windows
---  * `focusedWindowIndicator` - Table configuring the focus indicator appearance
---  * `stackIndicators` - Table configuring stack layout indicators
---  * `alerts` - Table configuring alert appearance and behavior
---  * `modeColors` - Table of colors for each layout mode (hex strings or color tables)
obj.config = {
    gap = 8,
    excludedApps = {},
    statusKeywords = {"status", "copy", "progress", "loading", "downloading"},
    settingsKeywords = {
        -- English
        "settings", "preferences", "prefs", "options", "configuration", "config", 
        "setup", "properties", "about", "inspector", "info", "information",
        -- App-specific patterns
        "preference", "setting", "option", "configure", "account", "profile",
        "general", "advanced", "privacy", "security", "network", "display",
        -- Other languages
        "préférences", "einstellungen", "configuración", "impostazioni", "設定", "环境设置"
    },
    usePerSpaceLayouts = true,
    
    -- Consolidated sub-configs
    resizing = {step = 0.05, minRatio = 0.15, maxRatio = 0.85},
    timing = {layoutUpdateDelay = 0.08, spaceChangeDelay = 0.12, initialSetupDelay = 0.15, windowLockDuration = 0.4},
    smallWindowThreshold = {width = 450, height = 320},
    focusedWindowIndicator = {width = 50, height = 4, opacity = 0.9, borderRadius = 2},
    stackIndicators = {enabled = true, position = "bottomLeft", width = 40, height = 5, spacing = 5, maxIndicators = 10, borderRadius = 2.5},
    alerts = {enabled = true, position = "bottom", duration = 0.8, fadeIn = 0.15, fadeOut = 0.25, strokeWidth = 0, 
              fillColor = {white = 0.05, alpha = 0.85}, textColor = {white = 0.95, alpha = 1}, textSize = 15, radius = 8},
    
    -- Mode colors
    modeColors = {
        bsp = {red = 0.929, green = 0.682, blue = 0.286, alpha = 1},
        master = {red = 0.286, green = 0.729, blue = 0.929, alpha = 1},
        floating = {red = 0.820, green = 0.286, blue = 0.357, alpha = 1},
        stacking = {red = 0.0, green = 0.475, blue = 0.549, alpha = 1},
    }
}

--- WindowManagerPlus.layouts
--- Variable
--- Available layout modes
---
--- The following layouts are available:
---  * `bsp` - Binary Space Partitioning tree layout
---  * `master` - Master/Stack layout with one main window
---  * `stacking` - Full-screen stacking layout
---  * `floating` - Free-form floating windows
obj.layouts = {"bsp", "master", "stacking", "floating"}

--- WindowManagerPlus.settingsFile
--- Variable
--- Path to the settings persistence file
---
--- Default: `~/.hammerspoon/wm_settings.json`
obj.settingsFile = os.getenv("HOME") .. "/.hammerspoon/wm_settings.json"

--- WindowManagerPlus.state
--- Variable
--- Internal state tracking (read-only)
---
--- This table contains the current state of the window manager.
--- Users should not modify this directly.
obj.state = {
    currentLayout = 1, windows = {}, floatingWindows = {}, floatingSteps = {}, splitRatios = {},
    splitDirections = {}, windowTree = {}, spaceLayouts = {}, spaceWindowOrder = {},
    layoutChanged = false, ignoreNextUpdate = false, alertUUID = nil, lastWindowFrames = {}
}

-- Load modules
local Core = dofile(hs.spoons.resourcePath("core.lua"))
local UI = dofile(hs.spoons.resourcePath("ui.lua"))
local Helpers = dofile(hs.spoons.resourcePath("helpers.lua"))
local API = dofile(hs.spoons.resourcePath("api.lua"))

--- WindowManagerPlus:hexToColor(hex, alpha)
--- Method
--- Converts hex color string to Hammerspoon color table
---
--- Parameters:
---  * hex - Hex color string (e.g., "#FF6B35")
---  * alpha - Optional alpha value (0-1, default: 1.0)
---
--- Returns:
---  * Color table with red, green, blue, alpha values (0-1)
---
--- Notes:
---  * Used internally for color configuration processing
function obj:hexToColor(hex, alpha)
    if type(hex) == "table" then return hex end
    
    hex = hex:gsub("#", "")
    return {
        red = tonumber(hex:sub(1, 2), 16) / 255,
        green = tonumber(hex:sub(3, 4), 16) / 255,
        blue = tonumber(hex:sub(5, 6), 16) / 255,
        alpha = alpha or 1.0
    }
end

--- WindowManagerPlus:processColors()
--- Method
--- Processes color configuration values
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Converts hex strings to color tables
---  * Called automatically during init and configure
function obj:processColors()
    -- Convert hex colors in modeColors
    for layout, color in pairs(self.config.modeColors) do
        if type(color) == "string" then
            self.config.modeColors[layout] = self:hexToColor(color)
        end
    end
    
    -- Convert alert colors
    local alerts = self.config.alerts
    if type(alerts.fillColor) == "string" then
        alerts.fillColor = self:hexToColor(alerts.fillColor, 0.85)
    end
    if type(alerts.textColor) == "string" then
        alerts.textColor = self:hexToColor(alerts.textColor, 1.0)
    end
end

--- WindowManagerPlus:init()
--- Method
--- Initializes the WindowManagerPlus spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowManagerPlus object
---
--- Notes:
---  * Called automatically when the spoon is loaded
---  * Loads settings and initializes all modules
function obj:init()
    self:processColors()
    
    -- Initialize modules
    self.helpers = Helpers:new(self)
    self.ui = UI:new(self)
    self.core = Core:new(self)
    self.api = API:new(self)
    
    self:loadSettings()
    
    -- Apply space-specific settings
    if self.config.usePerSpaceLayouts then
        local spaceID = self:getCurrentSpaceID()
        if spaceID and self.state.spaceLayouts[spaceID] then
            self.state.currentLayout = self.state.spaceLayouts[spaceID]
        end
    end
    
    return self
end

--- WindowManagerPlus:getCurrentSpaceID()
--- Method
--- Gets the current macOS Space ID
---
--- Parameters:
---  * None
---
--- Returns:
---  * String Space ID or nil if unable to determine
---
--- Notes:
---  * Used internally for per-space layout management
function obj:getCurrentSpaceID()
    local screen = hs.screen.mainScreen()
    return screen and tostring(hs.spaces.activeSpaceOnScreen(screen))
end

--- WindowManagerPlus:getLayoutForCurrentSpace()
--- Method
--- Gets the layout index for the current Space
---
--- Parameters:
---  * None
---
--- Returns:
---  * Number - Layout index (1-4)
---
--- Notes:
---  * Returns the per-space layout if enabled, otherwise the global layout
function obj:getLayoutForCurrentSpace()
    if not self.config.usePerSpaceLayouts then return self.state.currentLayout end
    local spaceID = self:getCurrentSpaceID()
    return spaceID and self.state.spaceLayouts[spaceID] or self.state.currentLayout
end

--- WindowManagerPlus:setLayoutForCurrentSpace(layoutIndex)
--- Method
--- Sets the layout for the current Space
---
--- Parameters:
---  * layoutIndex - Number (1-4) indicating the layout to use
---
--- Returns:
---  * None
---
--- Notes:
---  * Updates both the global and per-space layout settings
function obj:setLayoutForCurrentSpace(layoutIndex)
    self.state.currentLayout = layoutIndex
    if self.config.usePerSpaceLayouts then
        local spaceID = self:getCurrentSpaceID()
        if spaceID then self.state.spaceLayouts[spaceID] = layoutIndex end
    end
end

--- WindowManagerPlus:saveWindowOrderForCurrentSpace()
--- Method
--- Saves the current window order for the active Space
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Used internally to preserve window order across layout changes
function obj:saveWindowOrderForCurrentSpace()
    local spaceID = self:getCurrentSpaceID()
    if not spaceID or not self.state.windows then return end
    
    local windowOrder = {}
    for i, win in ipairs(self.state.windows) do
        if win and win:id() and win:isStandard() then
            local app = win:application()
            if app then
                table.insert(windowOrder, {
                    id = win:id(), app = app:name(), title = win:title() or "",
                    bundleID = app:bundleID() or "", index = i
                })
            end
        end
    end
    
    self.state.spaceWindowOrder[spaceID] = windowOrder
end

--- WindowManagerPlus:restoreWindowOrderForCurrentSpace()
--- Method
--- Restores the saved window order for the current Space
---
--- Parameters:
---  * None
---
--- Returns:
---  * Boolean - true if order was restored, false otherwise
---
--- Notes:
---  * Used internally during layout updates
function obj:restoreWindowOrderForCurrentSpace()
    local spaceID = self:getCurrentSpaceID()
    if not spaceID or not self.state.spaceWindowOrder[spaceID] then return false end
    
    local savedOrder = self.state.spaceWindowOrder[spaceID]
    local currentWindows = self.helpers:getRelevantWindows()
    
    -- Create window map and restore order
    local windowMap = {}
    for _, win in ipairs(currentWindows) do windowMap[win:id()] = win end
    
    local orderedWindows, usedIds = {}, {}
    
    -- First pass: restore existing windows in saved order
    for _, saved in ipairs(savedOrder) do
        if windowMap[saved.id] and not usedIds[saved.id] then
            table.insert(orderedWindows, windowMap[saved.id])
            usedIds[saved.id] = true
        end
    end
    
    -- Second pass: add remaining windows
    for _, win in ipairs(currentWindows) do
        if not usedIds[win:id()] then
            table.insert(orderedWindows, win)
        end
    end
    
    if #orderedWindows > 0 then
        self.state.windows = orderedWindows
        return true
    end
    
    return false
end

--- WindowManagerPlus:updateLayout(preserveOrder)
--- Method
--- Updates the window layout
---
--- Parameters:
---  * preserveOrder - Boolean, whether to preserve window order (default: auto-detect)
---
--- Returns:
---  * None
---
--- Notes:
---  * This is the main layout update function
---  * Automatically handles per-space layouts and window order preservation
function obj:updateLayout(preserveOrder)
    if self.config.usePerSpaceLayouts then
        local spaceID = self:getCurrentSpaceID()
        if spaceID then
            self.state.currentLayout = self.state.spaceLayouts[spaceID] or self.state.currentLayout
        end
    end
    
    if not preserveOrder then
        preserveOrder = self:restoreWindowOrderForCurrentSpace()
    end
    
    self.core:updateLayout(preserveOrder)
    self:saveSettings()
end

--- WindowManagerPlus:loadSettings()
--- Method
--- Loads settings from the persistence file
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Called automatically during init
---  * Settings are stored in JSON format
function obj:loadSettings()
    local file = io.open(self.settingsFile, "r")
    if not file then return end
    
    local content = file:read("*all")
    file:close()
    
    local success, settings = pcall(hs.json.decode, content)
    if not success or not settings then return end
    
    -- Load state (excluding runtime-only fields)
    local excludedStateKeys = {alertUUID = true, floatingWindows = true, floatingSteps = true, lastWindowFrames = true}
    for k, v in pairs(settings) do
        if self.state[k] ~= nil and not excludedStateKeys[k] then
            self.state[k] = v
        end
    end
    
    -- Convert floating window/step IDs from strings to numbers
    local function convertIds(source, target)
        if source then
            for k, v in pairs(source) do
                target[tonumber(k)] = v
            end
        end
    end
    
    convertIds(settings.floatingWindows, self.state.floatingWindows)
    convertIds(settings.floatingSteps, self.state.floatingSteps)
    
    -- Load config with deep merge
    if settings.config then
        for k, v in pairs(settings.config) do
            if type(v) == "table" and type(self.config[k]) == "table" then
                for nested_k, nested_v in pairs(v) do
                    self.config[k][nested_k] = nested_v
                end
            else
                self.config[k] = v
            end
        end
    end
end

--- WindowManagerPlus:saveSettings()
--- Method
--- Saves current settings to the persistence file
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Called automatically after configuration changes
---  * Only saves user-configurable settings, not runtime state
function obj:saveSettings()
    -- Convert floating IDs to strings for JSON serialization
    local function convertIdsToStrings(source)
        local result = {}
        for id, v in pairs(source) do
            result[tostring(id)] = v
        end
        return result
    end
    
    local settings = {
        -- State
        currentLayout = self.state.currentLayout,
        splitRatios = self.state.splitRatios,
        splitDirections = self.state.splitDirections,
        floatingWindows = convertIdsToStrings(self.state.floatingWindows),
        floatingSteps = convertIdsToStrings(self.state.floatingSteps),
        spaceLayouts = self.state.spaceLayouts,
        spaceWindowOrder = self.state.spaceWindowOrder,
        
        -- Config (only user-modifiable parts)
        config = {
            usePerSpaceLayouts = self.config.usePerSpaceLayouts,
            settingsKeywords = self.config.settingsKeywords,
            resizing = self.config.resizing,
            timing = self.config.timing,
            smallWindowThreshold = self.config.smallWindowThreshold,
            focusedWindowIndicator = self.config.focusedWindowIndicator,
            alerts = self.config.alerts,
            stackIndicators = self.config.stackIndicators
        }
    }
    
    local success, json = pcall(hs.json.encode, settings)
    if success and json then
        local file = io.open(self.settingsFile, "w")
        if file then
            file:write(json)
            file:close()
        end
    end
end

--- WindowManagerPlus:configure(config)
--- Method
--- Configures WindowManagerPlus settings
---
--- Parameters:
---  * config - Table of configuration options (see WindowManagerPlus.config for available keys)
---
--- Returns:
---  * The WindowManagerPlus object for method chaining
---
--- Notes:
---  * Configuration is merged with existing settings
---  * Colors can be specified as hex strings or color tables
---
--- Example:
--- ```lua
--- wm:configure({
---     gap = 10,
---     modeColors = {
---         bsp = "#FF6B35",
---         master = "#4ECDC4"
---     }
--- })
--- ```
function obj:configure(config)
    return self.api:configure(config)
end

--- WindowManagerPlus:bindHotkeys(mapping)
--- Method
--- Binds hotkeys to WindowManagerPlus functions
---
--- Parameters:
---  * mapping - Table of hotkey definitions where keys are function names
---
--- Returns:
---  * The WindowManagerPlus object for method chaining
---
--- Notes:
---  * See api.lua for all available function names
---  * Hotkey format: {modifiers, key}
---
--- Example:
--- ```lua
--- wm:bindHotkeys({
---     cycleLayout = {{"alt", "cmd"}, "space"},
---     focus = {{"alt", "cmd"}, "j"},
---     toggleFloatingWindow = {{"alt", "cmd"}, "f"}
--- })
--- ```
function obj:bindHotkeys(mapping)
    return self.api:bindHotkeys(mapping)
end

--- WindowManagerPlus:start()
--- Method
--- Starts the window manager
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowManagerPlus object
---
--- Notes:
---  * Must be called after configuration and hotkey binding
---  * Sets up all event watchers and performs initial layout
---
--- Example:
--- ```lua
--- hs.loadSpoon("WindowManagerPlus")
---    :configure({gap = 8})
---    :bindHotkeys({cycleLayout = {{"alt", "cmd"}, "space"}})
---    :start()
--- ```
function obj:start()
    return self.api:start()
end

return obj
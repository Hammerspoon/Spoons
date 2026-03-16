--- === WindowManagerPlus.ui ===
---
--- UI module for WindowManagerPlus
---
--- This module provides visual indicators and feedback for WindowManagerPlus, including
--- focused window indicators, stack indicators, and visual feedback elements.

local UI = {}
UI.__index = UI

--- WindowManagerPlus.ui:new(spoon)
--- Constructor
--- Creates a new UI instance
---
--- Parameters:
---  * spoon - The WindowManagerPlus spoon instance
---
--- Returns:
---  * UI object
---
--- Notes:
---  * Initializes canvas objects for visual indicators
---  * Canvas objects are created as needed and cleaned up automatically
function UI:new(spoon)
    local o = setmetatable({}, self)
    o.spoon = spoon
    o.focusedWindowCanvas = nil
    o.stackIndicatorsCanvas = nil
    return o
end

--- WindowManagerPlus.ui:updateFocusedWindowIndicator()
--- Method
--- Updates the visual indicator for the currently focused window
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Creates a small colored indicator at the bottom center of the focused window
---  * The indicator color matches the current layout mode
---  * Not shown in stacking layout (since all windows overlap)
---  * Automatically cleaned up when focus changes
---  * Uses config values: focusedWindowIndicator.width, height, opacity, borderRadius
function UI:updateFocusedWindowIndicator()
    -- Clean up existing indicator
    if self.focusedWindowCanvas then 
        self.focusedWindowCanvas:delete()
        self.focusedWindowCanvas = nil
    end

    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout == "stacking" then return end

    local win = hs.window.focusedWindow()
    if not win or not self.spoon.helpers:isRelevantWindow(win) then return end

    local frame = win:frame()
    local color = self.spoon.config.modeColors[layout]

    -- Safe config access with defaults
    local indicatorConfig = self.spoon.config.focusedWindowIndicator or {}
    local indicatorWidth = indicatorConfig.width or 50
    local indicatorHeight = indicatorConfig.height or 4
    local opacity = indicatorConfig.opacity or 0.9
    local borderRadius = indicatorConfig.borderRadius or 2

    -- Create a small indicator at the bottom center of the window
    local x = frame.x + (frame.w - indicatorWidth) / 2
    local y = frame.y + frame.h - indicatorHeight

    self.focusedWindowCanvas = hs.canvas.new({
        x = x,
        y = y,
        w = indicatorWidth,
        h = indicatorHeight
    })
    
    self.focusedWindowCanvas:level(hs.canvas.windowLevels.overlay)
    
    -- Create element with safe rounded rect radii
    local element = {
        type = "rectangle",
        action = "fill",
        fillColor = {
            red = color.red or 0.5,
            green = color.green or 0.5,
            blue = color.blue or 0.5,
            alpha = opacity
        }
    }
    
    -- Only add roundedRectRadii if borderRadius is valid
    if type(borderRadius) == "number" and borderRadius > 0 then
        element.roundedRectRadii = { 
            xRadius = borderRadius, 
            yRadius = borderRadius 
        }
    end
    
    self.focusedWindowCanvas:appendElements({element})
    self.focusedWindowCanvas:show()
end

--- WindowManagerPlus.ui:updateStackIndicators()
--- Method
--- Updates the visual indicators for stacked windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Only shown in stacking layout mode
---  * Displays small rectangles representing each window in the stack
---  * The focused window indicator is highlighted in the layout color
---  * Other windows shown in neutral gray
---  * Position configurable: bottomLeft, bottomRight, topLeft, topRight
---  * Uses config values: stackIndicators.enabled, position, width, height, spacing, maxIndicators, borderRadius
function UI:updateStackIndicators()
    -- Clean up existing indicators
    if self.stackIndicatorsCanvas then
        self.stackIndicatorsCanvas:delete()
        self.stackIndicatorsCanvas = nil
    end

    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "stacking" then 
        return 
    end

    -- Safe config access with defaults
    local stackConfig = self.spoon.config.stackIndicators or {}
    if not stackConfig.enabled then return end

    local windows = self.spoon.state.windows
    if #windows == 0 then return end

    local screen = hs.screen.mainScreen():frame()
    local focusedWindow = hs.window.focusedWindow()
    
    -- Safe config values with defaults
    local position = stackConfig.position or "bottomLeft"
    local indicatorWidth = stackConfig.width or 40
    local indicatorHeight = stackConfig.height or 5
    local spacing = stackConfig.spacing or 5
    local maxIndicators = stackConfig.maxIndicators or 10
    local borderRadius = stackConfig.borderRadius or 2.5
    local gap = self.spoon.config.gap or 8
    
    -- Calculate position based on config
    local startX, startY
    local numToShow = math.min(#windows, maxIndicators)
    local totalWidth = (indicatorWidth + spacing) * numToShow - spacing
    
    if position == "bottomLeft" then
        startX = screen.x + gap
        startY = screen.y + screen.h - gap - indicatorHeight
    elseif position == "bottomRight" then
        startX = screen.x + screen.w - gap - totalWidth
        startY = screen.y + screen.h - gap - indicatorHeight
    elseif position == "topLeft" then
        startX = screen.x + gap
        startY = screen.y + gap
    else -- topRight
        startX = screen.x + screen.w - gap - totalWidth
        startY = screen.y + gap
    end

    self.stackIndicatorsCanvas = hs.canvas.new({
        x = startX,
        y = startY,
        w = totalWidth,
        h = indicatorHeight
    })
    self.stackIndicatorsCanvas:level(hs.canvas.windowLevels.overlay)

    -- Draw indicators for each window
    local elements = {}
    for i = 1, numToShow do
        local win = windows[i]
        local isFocused = focusedWindow and win:id() == focusedWindow:id()
        
        -- Use layout color for focused window, gray for others
        local stackingColor = self.spoon.config.modeColors.stacking or {red = 0.0, green = 0.475, blue = 0.549, alpha = 1}
        local color = isFocused and stackingColor or {red = 0.5, green = 0.5, blue = 0.5, alpha = 0.5}

        local element = {
            type = "rectangle",
            action = "fill",
            fillColor = color,
            frame = {
                x = (i - 1) * (indicatorWidth + spacing),
                y = 0,
                w = indicatorWidth,
                h = indicatorHeight
            }
        }
        
        -- Only add roundedRectRadii if borderRadius is valid
        if type(borderRadius) == "number" and borderRadius > 0 then
            element.roundedRectRadii = { 
                xRadius = borderRadius, 
                yRadius = borderRadius 
            }
        end
        
        table.insert(elements, element)
    end
    
    self.stackIndicatorsCanvas:appendElements(elements)
    self.stackIndicatorsCanvas:show()
end

--- WindowManagerPlus.ui:updateAll()
--- Method
--- Updates all visual indicators
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Convenience method that updates both focused window and stack indicators
---  * Called automatically when window focus changes or layout updates
---  * Safe to call frequently - handles cleanup of existing indicators
function UI:updateAll()
    self:updateFocusedWindowIndicator()
    self:updateStackIndicators()
end

--- WindowManagerPlus.ui:cleanup()
--- Method
--- Cleans up all visual indicators
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Removes all canvas objects and frees resources
---  * Called automatically when the spoon is stopped
---  * Safe to call multiple times
function UI:cleanup()
    if self.focusedWindowCanvas then 
        self.focusedWindowCanvas:delete()
        self.focusedWindowCanvas = nil
    end
    if self.stackIndicatorsCanvas then 
        self.stackIndicatorsCanvas:delete()
        self.stackIndicatorsCanvas = nil
    end
end

return UI
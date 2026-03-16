--- === WindowManagerPlus.core ===
---
--- Core functionality for WindowManagerPlus
---
--- This module contains the main layout algorithms, window management functions,
--- and user interaction handlers for WindowManagerPlus.

local Core = {}
Core.__index = Core

--- WindowManagerPlus.core:new(spoon)
--- Constructor
--- Creates a new Core instance
---
--- Parameters:
---  * spoon - The WindowManagerPlus spoon instance
---
--- Returns:
---  * Core object
function Core:new(spoon)
    return setmetatable({spoon = spoon}, self)
end

-- Alert Management

--- WindowManagerPlus.core:showAlert(message)
--- Method
--- Shows a styled alert message
---
--- Parameters:
---  * message - String message to display
---
--- Returns:
---  * None
---
--- Notes:
---  * Alerts can be disabled via config.alerts.enabled
---  * Alert appearance is customizable via config.alerts
function Core:showAlert(message)
    if not self.spoon.config.alerts.enabled then return end
    
    if self.spoon.state.alertUUID then
        hs.alert.closeSpecific(self.spoon.state.alertUUID)
    end
    
    local config = self.spoon.config.alerts
    local alertConfig = {
        strokeWidth = config.strokeWidth,
        fillColor = config.fillColor,
        textColor = config.textColor,
        textSize = config.textSize,
        radius = config.radius,
        fadeInDuration = config.fadeIn,
        fadeOutDuration = config.fadeOut
    }
    
    if config.position == "bottom" then alertConfig.atScreenEdge = 2 end
    self.spoon.state.alertUUID = hs.alert.show(message, alertConfig, config.duration)
end

-- Helper Functions

--- WindowManagerPlus.core:getWindowIndex(winId)
--- Method
--- Gets the index of a window in the current window list
---
--- Parameters:
---  * winId - Window ID to search for
---
--- Returns:
---  * Number index or nil if not found
---
--- Notes:
---  * Used internally for window position operations
function Core:getWindowIndex(winId)
    for i, w in ipairs(self.spoon.state.windows) do
        if w:id() == winId then return i end
    end
end

--- WindowManagerPlus.core:isVerticalSplit(splitDirection, screen)
--- Method
--- Determines if a split should be vertical based on direction and screen aspect ratio
---
--- Parameters:
---  * splitDirection - String: "vertical", "horizontal", or nil (auto)
---  * screen - Screen frame table with x, y, w, h
---
--- Returns:
---  * Boolean - true for vertical split, false for horizontal
---
--- Notes:
---  * Auto mode uses screen aspect ratio (vertical if width > height * 1.2)
function Core:isVerticalSplit(splitDirection, screen)
    return splitDirection == "vertical" or 
           (splitDirection ~= "horizontal" and screen.w > screen.h * 1.2)
end

--- WindowManagerPlus.core:adjustRatio(ratio, increase)
--- Method
--- Adjusts a split ratio by the configured step amount
---
--- Parameters:
---  * ratio - Current ratio (0-1)
---  * increase - Boolean, true to increase, false to decrease
---
--- Returns:
---  * Number - New ratio clamped between minRatio and maxRatio
---
--- Notes:
---  * Step size is configured via config.resizing.step
function Core:adjustRatio(ratio, increase)
    local config = self.spoon.config.resizing
    local step = increase and config.step or -config.step
    return math.max(config.minRatio, math.min(config.maxRatio, ratio + step))
end

--- WindowManagerPlus.core:layoutStack(area, windows, isVertical)
--- Method
--- Arranges windows in a stack within the given area
---
--- Parameters:
---  * area - Table with x, y, w, h defining the stack area
---  * windows - Array of window objects to stack
---  * isVertical - Boolean, true for vertical stack, false for horizontal
---
--- Returns:
---  * None
---
--- Notes:
---  * Used by master layout for the stack area
---  * Respects gap configuration between windows
function Core:layoutStack(area, windows, isVertical)
    if #windows == 0 then return end
    local gap = self.spoon.config.gap
    local count = #windows
    
    if isVertical then
        local height = (area.h - gap * (count - 1)) / count
        for i, win in ipairs(windows) do
            win:setFrame({
                x = area.x,
                y = area.y + (i - 1) * (height + gap),
                w = area.w,
                h = height
            })
        end
    else
        local width = (area.w - gap * (count - 1)) / count
        for i, win in ipairs(windows) do
            win:setFrame({
                x = area.x + (i - 1) * (width + gap),
                y = area.y,
                w = width,
                h = area.h
            })
        end
    end
end

-- Layout Functions

--- WindowManagerPlus.core:layoutBsp(screen, windows)
--- Method
--- Applies Binary Space Partitioning layout
---
--- Parameters:
---  * screen - Screen frame to layout within
---  * windows - Array of windows to arrange
---
--- Returns:
---  * None
---
--- Notes:
---  * Uses different algorithms for 2, 3, and 4+ windows
---  * Maintains split ratios and directions from state
function Core:layoutBsp(screen, windows)
    local count = #windows
    if count == 0 then return end
    if count == 1 then 
        windows[1]:setFrame(screen)
        return 
    end
    
    if count == 2 then
        self:layout2Windows(screen, windows)
    elseif count == 3 then
        self:layout3Windows(screen, windows)
    else
        self:layoutBalanced(screen, windows)
    end
end

--- WindowManagerPlus.core:layout2Windows(screen, windows)
--- Method
--- Layouts exactly 2 windows with configurable split
---
--- Parameters:
---  * screen - Screen frame
---  * windows - Array of exactly 2 windows
---
--- Returns:
---  * None
---
--- Notes:
---  * Split direction from state.splitDirections["main"]
---  * Split ratio from state.splitRatios["main"]
function Core:layout2Windows(screen, windows)
    local ratio = self.spoon.state.splitRatios["main"] or 0.5
    local isVertical = self:isVerticalSplit(self.spoon.state.splitDirections["main"], screen)
    local gap = self.spoon.config.gap
    
    local frames = {}
    if isVertical then
        frames[1] = {x = screen.x, y = screen.y, w = screen.w * ratio - gap/2, h = screen.h}
        frames[2] = {x = screen.x + screen.w * ratio + gap/2, y = screen.y, 
                     w = screen.w * (1 - ratio) - gap/2, h = screen.h}
    else
        frames[1] = {x = screen.x, y = screen.y, w = screen.w, h = screen.h * ratio - gap/2}
        frames[2] = {x = screen.x, y = screen.y + screen.h * ratio + gap/2, 
                     w = screen.w, h = screen.h * (1 - ratio) - gap/2}
    end
    
    for i, frame in ipairs(frames) do
        windows[i]:setFrame(frame)
    end
end

--- WindowManagerPlus.core:layout3Windows(screen, windows)
--- Method
--- Layouts exactly 3 windows with special arrangements
---
--- Parameters:
---  * screen - Screen frame
---  * windows - Array of exactly 3 windows
---
--- Returns:
---  * None
---
--- Notes:
---  * Supports horizontal mode: 1 top, 2 bottom
---  * Supports left_main mode: 1 left, 2 right stacked
---  * Supports right_main mode: 2 left stacked, 1 right
function Core:layout3Windows(screen, windows)
    local mainRatio = self.spoon.state.splitRatios["main"] or 0.5
    local secondaryRatio = self.spoon.state.splitRatios["secondary"] or 0.5
    local gap = self.spoon.config.gap
    local layoutMode = self.spoon.state.splitDirections["layout_mode"] or "left_main"
    local isHorizontal = self.spoon.state.splitDirections["main"] == "horizontal"
    
    if isHorizontal then
        -- Top window, bottom two side-by-side
        windows[1]:setFrame({x = screen.x, y = screen.y, w = screen.w, h = screen.h * mainRatio - gap/2})
        
        local bottomY = screen.y + screen.h * mainRatio + gap/2
        local bottomH = screen.h * (1 - mainRatio) - gap/2
        local bottomW = screen.w * secondaryRatio
        
        windows[2]:setFrame({x = screen.x, y = bottomY, w = bottomW - gap/2, h = bottomH})
        windows[3]:setFrame({x = screen.x + bottomW + gap/2, y = bottomY, 
                            w = screen.w - bottomW - gap/2, h = bottomH})
    else
        -- Vertical layouts
        local mainFrame, stackArea = {}, {}
        local rightX = screen.x + screen.w * mainRatio + gap/2
        local rightW = screen.w * (1 - mainRatio) - gap/2
        local rightH = screen.h * secondaryRatio
        
        if layoutMode == "right_main" then
            -- Left two stacked, right main
            local leftW = screen.w * (1 - mainRatio) - gap/2
            windows[1]:setFrame({x = screen.x, y = screen.y, w = leftW, h = rightH - gap/2})
            windows[3]:setFrame({x = screen.x, y = screen.y + rightH + gap/2, 
                                w = leftW, h = screen.h - rightH - gap/2})
            windows[2]:setFrame({x = rightX, y = screen.y, w = rightW, h = screen.h})
        else
            -- Default: left main, right two stacked
            windows[1]:setFrame({x = screen.x, y = screen.y, w = screen.w * mainRatio - gap/2, h = screen.h})
            windows[2]:setFrame({x = rightX, y = screen.y, w = rightW, h = rightH - gap/2})
            windows[3]:setFrame({x = rightX, y = screen.y + rightH + gap/2, 
                                w = rightW, h = screen.h - rightH - gap/2})
        end
    end
end

--- WindowManagerPlus.core:layoutBalanced(screen, windows)
--- Method
--- Layouts 4+ windows using recursive binary space partitioning
---
--- Parameters:
---  * screen - Screen frame
---  * windows - Array of 4 or more windows
---
--- Returns:
---  * None
---
--- Notes:
---  * Recursively splits space in half for balanced tree
---  * Maintains window tree structure in state.windowTree
function Core:layoutBalanced(screen, windows)
    if #windows <= 1 then
        if #windows == 1 then 
            windows[1]:setFrame(screen)
            self.spoon.state.windowTree[windows[1]:id()] = {parent = "root", position = "single", direction = "none"}
        end
        return
    end
    
    self.spoon.state.windowTree = {}
    
    local function splitRecursive(wins, frame, splitId)
        if #wins == 0 then return end
        if #wins == 1 then
            wins[1]:setFrame(frame)
            if not self.spoon.state.windowTree[wins[1]:id()] then
                self.spoon.state.windowTree[wins[1]:id()] = {parent = splitId, position = "single", direction = "none"}
            end
            return
        end
        
        local isVertical = self:isVerticalSplit(self.spoon.state.splitDirections[splitId], frame)
        local midPoint = math.ceil(#wins / 2)
        local ratio = self.spoon.state.splitRatios[splitId] or 0.5
        local gap = self.spoon.config.gap
        
        local firstGroup, secondGroup = {}, {}
        for i = 1, midPoint do table.insert(firstGroup, wins[i]) end
        for i = midPoint + 1, #wins do table.insert(secondGroup, wins[i]) end
        
        local frame1, frame2
        if isVertical then
            local width = frame.w * ratio
            frame1 = {x = frame.x, y = frame.y, w = width - gap/2, h = frame.h}
            frame2 = {x = frame.x + width + gap/2, y = frame.y, w = frame.w - width - gap/2, h = frame.h}
        else
            local height = frame.h * ratio
            frame1 = {x = frame.x, y = frame.y, w = frame.w, h = height - gap/2}
            frame2 = {x = frame.x, y = frame.y + height + gap/2, w = frame.w, h = frame.h - height - gap/2}
        end
        
        local direction = isVertical and "vertical" or "horizontal"
        for _, win in ipairs(firstGroup) do
            self.spoon.state.windowTree[win:id()] = {parent = splitId, position = "first", direction = direction}
        end
        for _, win in ipairs(secondGroup) do
            self.spoon.state.windowTree[win:id()] = {parent = splitId, position = "second", direction = direction}
        end
        
        splitRecursive(firstGroup, frame1, splitId .. "_1")
        splitRecursive(secondGroup, frame2, splitId .. "_2")
    end
    
    splitRecursive(windows, screen, "balanced")
end

--- WindowManagerPlus.core:layoutMaster(screen, windows)
--- Method
--- Applies Master/Stack layout
---
--- Parameters:
---  * screen - Screen frame
---  * windows - Array of windows (first is master)
---
--- Returns:
---  * None
---
--- Notes:
---  * Master orientation: left, right, top, or bottom
---  * Stack windows are arranged opposite to master
---  * Master ratio configurable via state.splitRatios["master"]
function Core:layoutMaster(screen, windows)
    if #windows == 0 then return end
    if #windows == 1 then 
        windows[1]:setFrame(screen)
        return 
    end
    
    local gap = self.spoon.config.gap
    local masterRatio = self.spoon.state.splitRatios["master"] or 0.6
    local orientation = self.spoon.state.splitDirections["master_orientation"] or "left"
    local master = windows[1]
    local stack = {table.unpack(windows, 2)}
    
    local masterFrame, stackArea = {}, {}
    
    if orientation == "left" then
        masterFrame = {x = screen.x, y = screen.y, w = screen.w * masterRatio - gap/2, h = screen.h}
        stackArea = {x = screen.x + screen.w * masterRatio + gap/2, y = screen.y, 
                    w = screen.w * (1 - masterRatio) - gap/2, h = screen.h}
        self:layoutStack(stackArea, stack, true)
    elseif orientation == "right" then
        stackArea = {x = screen.x, y = screen.y, w = screen.w * (1 - masterRatio) - gap/2, h = screen.h}
        masterFrame = {x = screen.x + screen.w * (1 - masterRatio) + gap/2, y = screen.y, 
                      w = screen.w * masterRatio - gap/2, h = screen.h}
        self:layoutStack(stackArea, stack, true)
    elseif orientation == "top" then
        masterFrame = {x = screen.x, y = screen.y, w = screen.w, h = screen.h * masterRatio - gap/2}
        stackArea = {x = screen.x, y = screen.y + screen.h * masterRatio + gap/2, 
                    w = screen.w, h = screen.h * (1 - masterRatio) - gap/2}
        self:layoutStack(stackArea, stack, false)
    else -- "bottom"
        stackArea = {x = screen.x, y = screen.y, w = screen.w, h = screen.h * (1 - masterRatio) - gap/2}
        masterFrame = {x = screen.x, y = screen.y + screen.h * (1 - masterRatio) + gap/2, 
                      w = screen.w, h = screen.h * masterRatio - gap/2}
        self:layoutStack(stackArea, stack, false)
    end
    
    master:setFrame(masterFrame)
end

--- WindowManagerPlus.core:layoutStacking(screen, windows)
--- Method
--- Applies stacking layout (all windows fullscreen)
---
--- Parameters:
---  * screen - Screen frame
---  * windows - Array of windows to stack
---
--- Returns:
---  * None
---
--- Notes:
---  * All windows are made fullscreen
---  * Focused window is raised to top
function Core:layoutStacking(screen, windows)
    for _, win in ipairs(windows) do
        win:setFrame(screen)
    end
    local focused = hs.window.focusedWindow()
    if focused then focused:raise() end
end

--- WindowManagerPlus.core:layoutFloating(screen, windows)
--- Method
--- Applies floating layout (no automatic positioning)
---
--- Parameters:
---  * screen - Screen frame (unused)
---  * windows - Array of windows (unused)
---
--- Returns:
---  * None
---
--- Notes:
---  * Windows maintain their current positions
---  * Use floating window commands to position windows
function Core:layoutFloating(screen, windows)
    -- Windows maintain their current positions
end

-- Master Layout Controls

--- WindowManagerPlus.core:toggleMasterOrientation()
--- Method
--- Cycles through master window orientations
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Cycles: left → top → right → bottom → left
---  * Only works in master layout
function Core:toggleMasterOrientation()
    local orientations = {"left", "top", "right", "bottom"}
    local current = self.spoon.state.splitDirections["master_orientation"] or "left"
    
    local currentIndex = 1
    for i, orientation in ipairs(orientations) do
        if orientation == current then currentIndex = i; break end
    end
    
    local newOrientation = orientations[(currentIndex % #orientations) + 1]
    self.spoon.state.splitDirections["master_orientation"] = newOrientation
    self.spoon.state.layoutChanged = true
    self:updateLayout(true)
    
    self:showAlert("Master: " .. newOrientation:gsub("^%l", string.upper))
    self.spoon:saveSettings()
end

--- WindowManagerPlus.core:resizeMaster(direction)
--- Method
--- Resizes the master area in master layout
---
--- Parameters:
---  * direction - String: "left", "right", "up", or "down"
---
--- Returns:
---  * None
---
--- Notes:
---  * Adjusts master ratio based on direction and orientation
---  * Shows current ratio as percentage
function Core:resizeMaster(direction)
    local win = hs.window.focusedWindow()
    if not win or self.spoon.state.floatingWindows[win:id()] then return end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "master" then 
        self:showAlert("Master resize only works in Master layout")
        return 
    end
    
    local windows = self.spoon.state.windows
    if #windows < 2 then return end
    
    local isMaster = (windows[1]:id() == win:id())
    local masterRatio = self.spoon.state.splitRatios["master"] or 0.6
    local orientation = self.spoon.state.splitDirections["master_orientation"] or "left"
    
    local canResize, increase, newOrientation = false, false, orientation
    
    if direction == "left" or direction == "right" then
        if orientation == "left" or orientation == "right" then
            canResize = true
            increase = (orientation == "left" and ((isMaster and direction == "right") or (not isMaster and direction == "left"))) or
                      (orientation == "right" and ((isMaster and direction == "left") or (not isMaster and direction == "right")))
        else
            canResize = true
            newOrientation = direction == "left" and "right" or "left"
            increase = direction == "right"
        end
    else -- up or down
        if orientation == "top" or orientation == "bottom" then
            canResize = true
            increase = (orientation == "top" and ((isMaster and direction == "down") or (not isMaster and direction == "up"))) or
                      (orientation == "bottom" and ((isMaster and direction == "up") or (not isMaster and direction == "down")))
        else
            canResize = true
            newOrientation = direction == "up" and "bottom" or "top"
            increase = direction == "down"
        end
    end
    
    if canResize then
        if newOrientation ~= orientation then
            self.spoon.state.splitDirections["master_orientation"] = newOrientation
            self:showAlert("Master: " .. newOrientation:gsub("^%l", string.upper))
        end
        
        local newRatio = self:adjustRatio(masterRatio, increase)
        self.spoon.state.splitRatios["master"] = newRatio
        self.spoon.state.layoutChanged = true
        self:updateLayout(true)
        
        local showRatio = function()
            self:showAlert(string.format("Master: %d%%", newRatio * 100))
        end
        
        if newOrientation ~= orientation then
            hs.timer.doAfter(0.3, showRatio)
        else
            showRatio()
        end
        
        self.spoon:saveSettings()
    else
        self:showAlert("Cannot resize in this direction")
    end
end

-- Resize Functions

--- WindowManagerPlus.core:resizeFocusedWindow(direction)
--- Method
--- Resizes the focused window in its split
---
--- Parameters:
---  * direction - String: "left", "right", "up", or "down"
---
--- Returns:
---  * None
---
--- Notes:
---  * Works differently in BSP vs Master layouts
---  * In BSP: resizes the split containing the window
---  * In Master: delegates to resizeMaster
function Core:resizeFocusedWindow(direction)
    local win = hs.window.focusedWindow()
    if not win or self.spoon.state.floatingWindows[win:id()] then return end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    
    if layout == "master" then
        self:resizeMaster(direction)
        return
    elseif layout ~= "bsp" then 
        return 
    end
    
    local winId = win:id()
    local windowCount = #self.spoon.state.windows
    
    if windowCount < 2 then return end
    
    local focusedIndex = self:getWindowIndex(winId)
    if not focusedIndex then return end
    
    local changed, ratio, splitName = false, 0, ""
    
    if windowCount == 2 then
        changed, ratio, splitName = self:resize2Windows(direction, focusedIndex)
    elseif windowCount == 3 then
        changed, ratio, splitName = self:resize3Windows(direction, focusedIndex)  
    else
        changed, ratio, splitName = self:resizeTreeWindows(direction, winId)
    end
    
    if changed then
        self.spoon.state.splitRatios[splitName] = ratio
        self:updateLayout(true)
        self:showAlert(string.format("%s: %d%%", splitName == "main" and "Main" or "Split", ratio * 100))
        self.spoon:saveSettings()
    end
end

--- WindowManagerPlus.core:resize2Windows(direction, focusedIndex)
--- Method
--- Handles resize for 2-window BSP layout
---
--- Parameters:
---  * direction - Resize direction
---  * focusedIndex - Index of focused window (1 or 2)
---
--- Returns:
---  * changed - Boolean, whether resize occurred
---  * ratio - New split ratio
---  * splitName - Name of the split ("main")
function Core:resize2Windows(direction, focusedIndex)
    local screen = self.spoon.helpers:getScreenFrame()
    local isVertical = self:isVerticalSplit(self.spoon.state.splitDirections["main"], screen)
    local ratio = self.spoon.state.splitRatios["main"] or 0.5
    local isMainWindow = focusedIndex == 1
    
    if (isVertical and (direction == "left" or direction == "right")) or
       (not isVertical and (direction == "up" or direction == "down")) then
        local increase = (isMainWindow and (direction == "right" or direction == "down")) or 
                        (not isMainWindow and (direction == "left" or direction == "up"))
        return true, self:adjustRatio(ratio, increase), "main"
    end
    
    return false, ratio, "main"
end

--- WindowManagerPlus.core:resize3Windows(direction, focusedIndex)
--- Method
--- Handles resize for 3-window BSP layout
---
--- Parameters:
---  * direction - Resize direction
---  * focusedIndex - Index of focused window (1, 2, or 3)
---
--- Returns:
---  * changed - Boolean, whether resize occurred
---  * ratio - New split ratio
---  * splitName - Name of the split ("main" or "secondary")
function Core:resize3Windows(direction, focusedIndex)
    local layoutMode = self.spoon.state.splitDirections["layout_mode"] or "left_main"
    local isHorizontal = self.spoon.state.splitDirections["main"] == "horizontal"
    local mainRatio = self.spoon.state.splitRatios["main"] or 0.5
    local secondaryRatio = self.spoon.state.splitRatios["secondary"] or 0.5
    
    if isHorizontal then
        if focusedIndex == 1 then
            if direction == "up" or direction == "down" then
                return true, self:adjustRatio(mainRatio, direction == "down"), "main"
            end
        else
            if direction == "up" or direction == "down" then
                return true, self:adjustRatio(mainRatio, direction == "down"), "main"
            elseif direction == "left" or direction == "right" then
                local increase = (focusedIndex == 2 and direction == "right") or (focusedIndex == 3 and direction == "left")
                return true, self:adjustRatio(secondaryRatio, increase), "secondary"
            end
        end
    else
        local isMainWindow = (layoutMode == "left_main" and focusedIndex == 1) or 
                            (layoutMode == "right_main" and focusedIndex == 2)
        
        if direction == "left" or direction == "right" then
            local increase = (layoutMode == "left_main" and ((isMainWindow and direction == "right") or (not isMainWindow and direction == "left"))) or
                           (layoutMode == "right_main" and ((isMainWindow and direction == "left") or (not isMainWindow and direction == "right")))
            return true, self:adjustRatio(mainRatio, increase), "main"
        elseif not isMainWindow and (direction == "up" or direction == "down") then
            local increase = ((layoutMode == "left_main" and ((focusedIndex == 2 and direction == "down") or (focusedIndex == 3 and direction == "up"))) or
                            (layoutMode == "right_main" and ((focusedIndex == 1 and direction == "down") or (focusedIndex == 3 and direction == "up"))))
            return true, self:adjustRatio(secondaryRatio, increase), "secondary"
        end
    end
    
    return false, 0, ""
end

--- WindowManagerPlus.core:resizeTreeWindows(direction, winId)
--- Method
--- Handles resize for 4+ window BSP layout using tree structure
---
--- Parameters:
---  * direction - Resize direction
---  * winId - ID of focused window
---
--- Returns:
---  * changed - Boolean, whether resize occurred
---  * ratio - New split ratio
---  * splitName - Name of the split being resized
function Core:resizeTreeWindows(direction, winId)
    local winData = self.spoon.state.windowTree[winId]
    if not winData or not winData.parent then return false, 0, "" end
    
    local splitId = winData.parent
    local ratio = self.spoon.state.splitRatios[splitId] or 0.5
    
    if (winData.direction == "vertical" and (direction == "left" or direction == "right")) or
       (winData.direction == "horizontal" and (direction == "up" or direction == "down")) then
        local increase = (winData.position == "first" and (direction == "right" or direction == "down")) or
                        (winData.position == "second" and (direction == "left" or direction == "up"))
        return true, self:adjustRatio(ratio, increase), splitId
    end
    
    -- Enhanced tree resize with coordination logic
    local targetSplits = {}
    local resizeDirection = (direction == "left" or direction == "right") and "vertical" or "horizontal"
    
    for currentSplitId, currentRatio in pairs(self.spoon.state.splitRatios) do
        if currentSplitId ~= splitId then
            local splitWindows = {}
            for _, win in ipairs(self.spoon.state.windows) do
                local testWinData = self.spoon.state.windowTree[win:id()]
                if testWinData and testWinData.parent == currentSplitId and 
                   testWinData.direction == resizeDirection then
                    table.insert(splitWindows, {win = win, data = testWinData})
                end
            end
            
            if #splitWindows > 0 then
                targetSplits[currentSplitId] = {ratio = currentRatio, windows = splitWindows}
            end
        end
    end
    
    if next(targetSplits) then
        local windowIndex = self:getWindowIndex(winId)
        if windowIndex then
            local bestSplitId, bestScore = nil, -1
            
            for currentSplitId, splitInfo in pairs(targetSplits) do
                local score = 0
                for _, winInfo in ipairs(splitInfo.windows) do
                    local otherIndex = self:getWindowIndex(winInfo.win:id())
                    if otherIndex then
                        score = score + (1 / (math.abs(otherIndex - windowIndex) + 1))
                    end
                end
                
                if score > bestScore then
                    bestScore = score
                    bestSplitId = currentSplitId
                end
            end
            
            if bestSplitId then
                local splitInfo = targetSplits[bestSplitId]
                local windowCount = #self.spoon.state.windows
                local increase = windowIndex <= windowCount / 2 and (direction == "right" or direction == "down") or
                               (direction == "left" or direction == "up")
                
                return true, self:adjustRatio(splitInfo.ratio, increase), bestSplitId
            end
        end
    end
    
    return false, 0, ""
end

-- Window Management

--- WindowManagerPlus.core:updateLayout(preserveOrder)
--- Method
--- Updates the window layout for the current space
---
--- Parameters:
---  * preserveOrder - Boolean, whether to preserve window order
---
--- Returns:
---  * None
---
--- Notes:
---  * Main layout update function called by all layout changes
---  * Handles floating windows separately
---  * Updates UI indicators
function Core:updateLayout(preserveOrder)
    if not self.spoon.state.windows then self.spoon.state.windows = {} end
    
    local windows = preserveOrder and #self.spoon.state.windows > 0 and 
                   self:validateWindows() or self.spoon.helpers:getRelevantWindows()
    
    self.spoon.state.windows = windows
    local screen = self.spoon.helpers:getScreenFrame()
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    
    local layouts = {
        bsp = function() self:layoutBsp(screen, windows) end,
        master = function() self:layoutMaster(screen, windows) end,
        stacking = function() self:layoutStacking(screen, windows) end,
        floating = function() self:layoutFloating(screen, windows) end
    }
    
    if layouts[layout] then layouts[layout]() end
    
    self:handleFloatingWindows()
    self.spoon.ui:updateAll()
    self.spoon:saveWindowOrderForCurrentSpace()
    self.spoon.state.layoutChanged = false
end

--- WindowManagerPlus.core:validateWindows()
--- Method
--- Validates and reorders the current window list
---
--- Parameters:
---  * None
---
--- Returns:
---  * Array of valid windows in preserved order
---
--- Notes:
---  * Removes closed windows from the list
---  * Adds new windows at the end
function Core:validateWindows()
    local validWindows, validIds = {}, {}
    
    for _, win in ipairs(self.spoon.helpers:getRelevantWindows()) do
        validIds[win:id()] = win
    end
    
    for _, win in ipairs(self.spoon.state.windows) do
        if validIds[win:id()] then
            table.insert(validWindows, validIds[win:id()])
            validIds[win:id()] = nil
        end
    end
    
    for _, win in pairs(validIds) do
        table.insert(validWindows, win)
    end
    
    return validWindows
end

--- WindowManagerPlus.core:handleFloatingWindows()
--- Method
--- Ensures floating windows stay on top
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Raises all floating windows above tiled windows
---  * Removes invalid floating window entries
function Core:handleFloatingWindows()
    for id, _ in pairs(self.spoon.state.floatingWindows) do
        local win = hs.window.get(id)
        if win and self.spoon.helpers:isRelevantWindow(win) then
            win:raise()
        else
            self.spoon.state.floatingWindows[id] = nil
        end
    end
end

--- WindowManagerPlus.core:toggleLayoutOrientation()
--- Method
--- Universal orientation toggle for current layout
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * In BSP: toggles split direction
---  * In Master: toggles master orientation
---  * No effect in other layouts
function Core:toggleLayoutOrientation()
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    
    if layout == "bsp" then
        self:toggleSplitDirection()
    elseif layout == "master" then
        self:toggleMasterOrientation()
    else
        self:showAlert("Toggle orientation works in BSP and Master layouts")
    end
end

-- Split Direction Control

--- WindowManagerPlus.core:toggleSplitDirection()
--- Method
--- Toggles the split direction for BSP layout
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Behavior varies by window count:
---    * 2 windows: cycles vertical → horizontal → auto
---    * 3 windows: cycles between layout modes
---    * 4+ windows: toggles split at focused window
function Core:toggleSplitDirection()
    local win = hs.window.focusedWindow()
    if not win or self.spoon.state.floatingWindows[win:id()] then 
        self:showAlert("No tiled window focused")
        return 
    end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "bsp" then 
        self:showAlert("Split direction only works in BSP layout")
        return 
    end
    
    local windowCount = #self.spoon.state.windows
    
    if windowCount == 2 then
        self:toggle2WindowSplit()
    elseif windowCount == 3 then
        self:toggle3WindowLayout()
    else
        self:toggleTreeSplit(win:id())
    end
    
    self:updateLayout(true)
    self.spoon:saveSettings()
end

--- WindowManagerPlus.core:toggle2WindowSplit()
--- Method
--- Toggles split direction for 2-window layout
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Core:toggle2WindowSplit()
    local current = self.spoon.state.splitDirections["main"]
    local states = {vertical = "horizontal", horizontal = nil, [nil] = "vertical"}
    local messages = {vertical = "Horizontal", horizontal = "Auto", [nil] = "Vertical"}
    
    self.spoon.state.splitDirections["main"] = states[current]
    self:showAlert("Split: " .. messages[current])
end

--- WindowManagerPlus.core:toggle3WindowLayout()
--- Method
--- Toggles layout mode for 3-window layout
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Core:toggle3WindowLayout()
    local current = self.spoon.state.splitDirections["main"]
    local layoutMode = self.spoon.state.splitDirections["layout_mode"] or "left_main"
    
    if current == "horizontal" then
        self.spoon.state.splitDirections["main"] = nil
        self.spoon.state.splitDirections["layout_mode"] = "left_main"
        self:showAlert("Layout: Left Main")
    elseif layoutMode == "left_main" then
        self.spoon.state.splitDirections["layout_mode"] = "right_main"
        self:showAlert("Layout: Right Main")
    else
        self.spoon.state.splitDirections["main"] = "horizontal"
        self.spoon.state.splitDirections["layout_mode"] = "left_main"
        self:showAlert("Layout: Horizontal")
    end
end

--- WindowManagerPlus.core:toggleTreeSplit(winId)
--- Method
--- Toggles split direction in tree layout (4+ windows)
---
--- Parameters:
---  * winId - ID of the window whose split to toggle
---
--- Returns:
---  * None
function Core:toggleTreeSplit(winId)
    local winData = self.spoon.state.windowTree[winId]
    if winData and winData.parent then
        local splitId = winData.parent
        local current = self.spoon.state.splitDirections[splitId]
        local states = {vertical = "horizontal", horizontal = nil, [nil] = "vertical"}
        local messages = {vertical = "Horizontal", horizontal = "Auto", [nil] = "Vertical"}
        
        self.spoon.state.splitDirections[splitId] = states[current]
        self:showAlert("Split: " .. messages[current])
    else
        self:showAlert("Cannot determine split")
    end
end

-- Balance and Window Operations

--- WindowManagerPlus.core:balanceBSP()
--- Method
--- Resets all split ratios to default
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * In BSP: resets all splits to 50/50
---  * In Master: resets master to 60%
function Core:balanceBSP()
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    
    if layout == "bsp" then
        self.spoon.state.splitRatios = {}
        self:showAlert("Layout Balanced")
    elseif layout == "master" then
        self.spoon.state.splitRatios["master"] = 0.6
        self:showAlert("Master Balanced (60%)")
    else
        self:showAlert("Balance only works in BSP and Master layouts")
        return
    end
    
    self.spoon.state.layoutChanged = true
    self:updateLayout()
    self.spoon:saveSettings()
end

--- WindowManagerPlus.core:rotateWindows(clockwise)
--- Method
--- Rotates window positions
---
--- Parameters:
---  * clockwise - Boolean, true for clockwise rotation
---
--- Returns:
---  * None
---
--- Notes:
---  * Works in BSP and Master layouts only
---  * Preserves window sizes, changes positions
function Core:rotateWindows(clockwise)
    if not self.spoon.state.windows or #self.spoon.state.windows < 2 then
        self:showAlert("Need at least 2 windows")
        return
    end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "bsp" and layout ~= "master" then
        self:showAlert("Rotation only works in BSP and Master layouts")
        return
    end
    
    local windows = self.spoon.state.windows
    local rotated = {}
    
    self.spoon.state.ignoreNextUpdate = true
    
    if clockwise then
        rotated[1] = windows[#windows]
        for i = 1, #windows - 1 do rotated[i + 1] = windows[i] end
    else
        for i = 2, #windows do rotated[i - 1] = windows[i] end
        rotated[#windows] = windows[1]
    end
    
    self.spoon.state.windows = rotated
    local screen = self.spoon.helpers:getScreenFrame()
    
    if layout == "bsp" then
        self:layoutBsp(screen, rotated)
    elseif layout == "master" then
        self:layoutMaster(screen, rotated)
    end
    
    self:showAlert(clockwise and "Rotated →" or "Rotated ←")
    self.spoon:saveWindowOrderForCurrentSpace()
    self.spoon:saveSettings()
    
    hs.timer.doAfter(self.spoon.config.timing.windowLockDuration, function()
        self.spoon.state.ignoreNextUpdate = false
    end)
end

--- WindowManagerPlus.core:moveToPosition(position)
--- Method
--- Moves focused window to a specific position
---
--- Parameters:
---  * position - Number, target position (1-based)
---
--- Returns:
---  * None
---
--- Notes:
---  * Works in BSP and Master layouts
---  * Position 1 is leftmost/topmost
function Core:moveToPosition(position)
    local win = hs.window.focusedWindow()
    if not win or self.spoon.state.floatingWindows[win:id()] then 
        self:showAlert("Cannot move this window")
        return 
    end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "bsp" and layout ~= "master" then
        self:showAlert("Move to position works in BSP and Master layouts")
        return
    end
    
    local windows = self.spoon.state.windows
    if #windows == 0 or position < 1 or position > #windows then 
        self:showAlert(string.format("Position must be 1-%d", #windows))
        return 
    end
    
    local currentIndex = self:getWindowIndex(win:id())
    if not currentIndex or currentIndex == position then
        self:showAlert("Already at position " .. position)
        return
    end
    
    self.spoon.state.ignoreNextUpdate = true
    
    local reordered = {}
    local movingWindow = windows[currentIndex]
    local sourceIdx = 1
    
    for targetIdx = 1, #windows do
        if targetIdx == position then
            reordered[targetIdx] = movingWindow
        else
            if sourceIdx == currentIndex then sourceIdx = sourceIdx + 1 end
            reordered[targetIdx] = windows[sourceIdx]
            sourceIdx = sourceIdx + 1
        end
    end
    
    self.spoon.state.windows = reordered
    local screen = self.spoon.helpers:getScreenFrame()
    
    if layout == "bsp" then
        self:layoutBsp(screen, reordered)
    elseif layout == "master" then
        self:layoutMaster(screen, reordered)
    end
    
    self:showAlert(string.format("Position %d", position))
    self.spoon:saveWindowOrderForCurrentSpace()
    self.spoon:saveSettings()
    
    hs.timer.doAfter(self.spoon.config.timing.windowLockDuration, function()
        self.spoon.state.ignoreNextUpdate = false
    end)
end

--- WindowManagerPlus.core:toggleFloatingWindow()
--- Method
--- Toggles floating state of focused window
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Floating windows are excluded from tiling
---  * Centered when made floating
function Core:toggleFloatingWindow()
    local win = hs.window.focusedWindow()
    if not win or not self.spoon.helpers:isRelevantWindow(win) then return end
    
    local winId = win:id()
    if self.spoon.state.floatingWindows[winId] then
        self.spoon.state.floatingWindows[winId] = nil
        self:showAlert("Window Tiled")
    else
        self.spoon.state.floatingWindows[winId] = true
        local frame, screen = win:frame(), hs.screen.mainScreen():frame()
        frame.x = screen.x + (screen.w - frame.w) / 2
        frame.y = screen.y + (screen.h - frame.h) / 2
        win:setFrame(frame)
        self:showAlert("Window Floating")
    end
    
    self.spoon.state.layoutChanged = true
    self:updateLayout()
    self.spoon:saveSettings()
end

--- WindowManagerPlus.core:focusNextWindow()
--- Method
--- Focuses the next window in order
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Cycles through windows in layout order
---  * Updates UI indicators
function Core:focusNextWindow()
    local current = hs.window.focusedWindow()
    local windows = self.spoon.state.windows
    
    if #windows == 0 then return end
    
    local nextIndex = 1
    if current then
        local currentIndex = self:getWindowIndex(current:id())
        if currentIndex then
            nextIndex = (currentIndex % #windows) + 1
        end
    end
    
    if windows[nextIndex] then
        windows[nextIndex]:focus()
        windows[nextIndex]:raise()
        self.spoon.ui:updateAll()
    end
end

-- Floating Window Management

-- Floating Window Management

-- Internal utilities for floating window positioning
-- Contains helper functions and data for floating window operations
local FloatingUtils = {
    steps = {1, 0.8, 0.66, 0.5, 0.33, 0.2},
    positions = {
        left = function(screen, w, h) return {x = screen.x, y = screen.y, w = w, h = screen.h} end,
        right = function(screen, w, h) return {x = screen.x + screen.w - w, y = screen.y, w = w, h = screen.h} end,
        up = function(screen, w, h) return {x = screen.x, y = screen.y, w = screen.w, h = h} end,
        down = function(screen, w, h) return {x = screen.x, y = screen.y + screen.h - h, w = screen.w, h = h} end,
        ["up-left"] = function(screen, w, h) return {x = screen.x, y = screen.y, w = w, h = h} end,
        ["up-right"] = function(screen, w, h) return {x = screen.x + screen.w - w, y = screen.y, w = w, h = h} end,
        ["down-left"] = function(screen, w, h) return {x = screen.x, y = screen.y + screen.h - h, w = w, h = h} end,
        ["down-right"] = function(screen, w, h) return {x = screen.x + screen.w - w, y = screen.y + screen.h - h, w = w, h = h} end
    },
    
    getDimensions = function(self, screen, position, widthStep, heightStep)
        local w, h = screen.w * self.steps[widthStep], screen.h * self.steps[heightStep]
        if position == "left" or position == "right" then h = screen.h
        elseif position == "up" or position == "down" then w = screen.w end
        return w, h
    end,
    
    getAlertMessage = function(self, position, widthStep, heightStep)
        local w, h = self.steps[widthStep] * 100, self.steps[heightStep] * 100
        
        if position == "left" then return string.format("Left: %d%%W×100%%H", w)
        elseif position == "right" then return string.format("Right: %d%%W×100%%H", w)
        elseif position == "up" then return string.format("Top: 100%%W×%d%%H", h)
        elseif position == "down" then return string.format("Bottom: 100%%W×%d%%H", h)
        else
            local parts = {}
            for part in string.gmatch(position, "[^-]+") do
                table.insert(parts, part:gsub("^%l", string.upper))
            end
            return string.format("%s: %d%%W×%d%%H", table.concat(parts, "-"), w, h)
        end
    end,
    
    getNextPosition = function(self, currentSide, direction, state)
        if not currentSide then
            state.widthStep, state.heightStep = 1, 1
            return direction
        elseif currentSide == direction then
            if direction == "left" or direction == "right" then
                state.widthStep = (state.widthStep % #self.steps) + 1
            else
                state.heightStep = (state.heightStep % #self.steps) + 1
            end
            return direction
        elseif not string.find(currentSide, "-") then
            if (currentSide == "left" or currentSide == "right") and (direction == "up" or direction == "down") then
                state.heightStep = 1
                return direction .. "-" .. currentSide
            elseif (currentSide == "up" or currentSide == "down") and (direction == "left" or direction == "right") then
                state.widthStep = 1
                return currentSide .. "-" .. direction
            else
                state.widthStep, state.heightStep = 1, 1
                return direction
            end
        else
            local parts = {}
            for part in string.gmatch(currentSide, "[^-]+") do table.insert(parts, part) end
            local vertical, horizontal = parts[1], parts[2]
            
            if direction == "left" or direction == "right" then
                if direction == horizontal then
                    state.widthStep = (state.widthStep % #self.steps) + 1
                    return currentSide
                else
                    state.widthStep = 1
                    return vertical .. "-" .. direction
                end
            else
                if direction == vertical then
                    state.heightStep = (state.heightStep % #self.steps) + 1
                    return currentSide
                else
                    state.heightStep = 1
                    return direction .. "-" .. horizontal
                end
            end
        end
    end
}

--- WindowManagerPlus.core:floatingWindowPosition(direction)
--- Method
--- Positions floating window at screen edges/corners
---
--- Parameters:
---  * direction - String: "up", "down", "left", or "right"
---
--- Returns:
---  * None
---
--- Notes:
---  * Cycles through size steps when pressing same direction
---  * Combines directions for corner positioning
---  * Only works in floating layout
function Core:floatingWindowPosition(direction)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "floating" then 
        self:showAlert("Floating positioning only works in Floating layout")
        return 
    end
    
    local screen = hs.screen.mainScreen():frame()
    local winId = win:id()
    
    if not self.spoon.state.floatingSteps then self.spoon.state.floatingSteps = {} end
    if not self.spoon.state.floatingSteps[winId] then
        self.spoon.state.floatingSteps[winId] = {currentSide = nil, widthStep = 1, heightStep = 1}
    end
    
    local state = self.spoon.state.floatingSteps[winId]
    local newSide = FloatingUtils:getNextPosition(state.currentSide, direction, state)
    local w, h = FloatingUtils:getDimensions(screen, newSide, state.widthStep, state.heightStep)
    local frame = FloatingUtils.positions[newSide](screen, w, h)
    
    state.currentSide = newSide
    win:setFrame(frame)
    self:showAlert(FloatingUtils:getAlertMessage(newSide, state.widthStep, state.heightStep))
end

--- WindowManagerPlus.core:floatingWindowFullscreen()
--- Method
--- Cycles floating window through fullscreen sizes
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Cycles: 100% → 80% → 60% → 40% → 20% → 100%
---  * Window stays centered
---  * Only works in floating layout
function Core:floatingWindowFullscreen()
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "floating" then 
        self:showAlert("Floating fullscreen only works in Floating layout")
        return 
    end
    
    local screen = hs.screen.mainScreen():frame()
    local winId = win:id()
    
    if not self.spoon.state.floatingSteps then self.spoon.state.floatingSteps = {} end
    if not self.spoon.state.floatingSteps[winId] then self.spoon.state.floatingSteps[winId] = {} end
    
    local currentStep = self.spoon.state.floatingSteps[winId]["fullscreen"] or 0
    local steps = {1.0, 0.8, 0.6, 0.4, 0.2}
    
    currentStep = (currentStep % #steps) + 1
    self.spoon.state.floatingSteps[winId]["fullscreen"] = currentStep
    
    local ratio = steps[currentStep]
    local newWidth, newHeight = screen.w * ratio, screen.h * ratio
    
    win:setFrame({
        x = screen.x + (screen.w - newWidth) / 2,
        y = screen.y + (screen.h - newHeight) / 2,
        w = newWidth,
        h = newHeight
    })
    self:showAlert(string.format("Fullscreen: %d%%", ratio * 100))
end

--- WindowManagerPlus.core:floatingWindowHalves(position)
--- Method
--- Positions floating window at standard positions
---
--- Parameters:
---  * position - String: "left_half", "right_half", "top_half", "bottom_half", "center", or "maximize"
---
--- Returns:
---  * None
---
--- Notes:
---  * Standard window positions for quick access
---  * Center uses 70% of screen size
---  * Only works in floating layout
function Core:floatingWindowHalves(position)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "floating" then 
        self:showAlert("Floating halves only works in Floating layout")
        return 
    end
    
    local screen = hs.screen.mainScreen():frame()
    local frames = {
        left_half = {x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h},
        right_half = {x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h},
        top_half = {x = screen.x, y = screen.y, w = screen.w, h = screen.h / 2},
        bottom_half = {x = screen.x, y = screen.y + screen.h / 2, w = screen.w, h = screen.h / 2},
        center = function()
            local ratio = 0.7
            local w, h = screen.w * ratio, screen.h * ratio
            return {x = screen.x + (screen.w - w) / 2, y = screen.y + (screen.h - h) / 2, w = w, h = h}
        end,
        maximize = screen
    }
    
    local messages = {
        left_half = "Left Half", right_half = "Right Half",
        top_half = "Top Half", bottom_half = "Bottom Half",
        center = "Centered", maximize = "Maximized"
    }
    
    local frame = type(frames[position]) == "function" and frames[position]() or frames[position]
    if frame then
        win:setFrame(frame)
        self:showAlert(messages[position])
        
        -- Reset steps when manually positioning
        local winId = win:id()
        if self.spoon.state.floatingSteps and self.spoon.state.floatingSteps[winId] then
            self.spoon.state.floatingSteps[winId] = {}
        end
    end
end

--- WindowManagerPlus.core:floatingWindowNextScreen()
--- Method
--- Moves floating window to next screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Cycles through available screens
---  * Only works in floating layout
function Core:floatingWindowNextScreen()
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    if layout ~= "floating" then 
        self:showAlert("Move to next screen only works in Floating layout")
        return 
    end
    
    local currentScreen = win:screen()
    local nextScreen = currentScreen:next()
    
    if nextScreen and nextScreen ~= currentScreen then
        win:moveToScreen(nextScreen)
        self:showAlert("Moved to " .. nextScreen:name())
    else
        self:showAlert("Only one screen available")
    end
end

--- WindowManagerPlus.core:showLayoutInfo()
--- Method
--- Shows information about current layout
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Shows layout name, window count, and configuration
---  * More detailed for BSP and Master layouts
function Core:showLayoutInfo()
    local layout = self.spoon.layouts[self.spoon:getLayoutForCurrentSpace()]
    local windowCount = #self.spoon.state.windows
    
    if layout == "master" then
        local orientation = self.spoon.state.splitDirections["master_orientation"] or "left"
        local masterRatio = self.spoon.state.splitRatios["master"] or 0.6
        self:showAlert(string.format("Master: %s (%d%%, %d windows)", 
                      orientation:gsub("^%l", string.upper), masterRatio * 100, windowCount))
        return
    end
    
    if layout ~= "bsp" then
        self:showAlert(string.format("Layout: %s (%d windows)", layout, windowCount))
        return
    end
    
    local info = string.format("BSP: %d windows", windowCount)
    
    if windowCount == 2 then
        local direction = self.spoon.state.splitDirections["main"] or "auto"
        local ratio = self.spoon.state.splitRatios["main"] or 0.5
        info = string.format("BSP: %s split (%d%%)", direction, ratio * 100)
    elseif windowCount == 3 then
        local layoutMode = self.spoon.state.splitDirections["layout_mode"] or "left_main"
        local isHorizontal = self.spoon.state.splitDirections["main"] == "horizontal"
        info = isHorizontal and "BSP: Horizontal layout" or 
               string.format("BSP: %s", layoutMode:gsub("_", " "))
    end
    
    self:showAlert(info)
end

return Core
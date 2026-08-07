--- === InputMethodIndicator ===
---
--- Show input method indicator in the current mouse position.
--- It is a small but noticable dot near the cursor.
--- It can be very useful when you are using a non-ABC input method and often needs to switch between ABC and the non-ABC input method.
--- You can use it as follows in the init.lua:
--- hs.loadSpoon("InputMethodIndicator")
--- spoon.InputMethodIndicator:start(nil)
--- note: config parameter is a table, pass nil to use the default config
--- the default config is as follows:
--- {
---     ABCColor = "#62C555",  -- the dot color when the input method is ABC
---     LocalLanguageColor = "#ED6A5E", -- the dot color when the input method is not ABC
---     mode = "nearMouse", -- the mode of the indicator
---     showOnChangeDuration = 3, -- seconds to show the indicator when the input method is changed
---     checkInterval = .01, -- seconds to check the input method
---     dotSize = 6, -- the size of the dot
---     deltaY=7, -- the distance between the dot and the center of the selection or mouse
--- }
--- the mode can be "nearMouse","onChange","adaptive", the default mode is "adaptive"
--- "nearMouse" means the indicator will always show near the mouse
--- "onChange" means the indicator will show when the input method is changed and hide after showOnChangeDuration seconds
--- "adaptive" means the indicator will show near the textarea when typing, otherwise it will show near the mouse
--- Note: the "adaptive" mode is not perfect, it may not work in some apps because of the limitation of the accessibility API

local obj = {}
local _store = {}
setmetatable(obj, {
    __index = function(_, k)
        return _store[k]
    end,
    __newindex = function(t, k, v)
        rawset(_store, k, v)
        if t._init_done then
            if t._attribs[k] then
                t:init()
            end
        end
    end
})
obj.__index = obj

-- Metadata
obj.name = "InputMethodIndicator"
obj.version = "1.0"
obj.author = "lunaticsky <2013599@mail.nankai.edu.cn>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local logger = hs.logger.new("InputMethodIndicator")
obj.logger = logger

-- Defaults
obj._attribs = {
    ABCColor = "#62C555",
    LocalLanguageColor = "#ED6A5E",
    mode = "adaptive",
    showOnChangeDuration = 3,
    checkInterval = .01,
    dotSize = 6,
    deltaY=7,
}
for k, v in pairs(obj._attribs) do
    obj[k] = v
end

--- InputMethodIndicator:init()
--- Method
--- init.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The InputMethodIndicator object
function obj:init()
    local mousePosition = hs.mouse.absolutePosition()
    if not self.canvas then
        self.canvas = hs.canvas.new({
            x = mousePosition.x - self.dotSize / 2,
            y = mousePosition.y - 2*self.deltaY,
            w = self.dotSize,
            h = self.dotSize
        })
    end
    local sourceID = hs.keycodes.currentSourceID()
    print(sourceID)
    if (sourceID == "com.apple.keylayout.ABC") then
        self.color = self.ABCColor
        self.lastLayout = sourceID
    else
        self.color = self.LocalLanguageColor
        self.lastLayout = sourceID
    end
    self.canvas[1] = {
        action = "fill",
        type = "circle",
        fillColor = {
            hex = self.color
        },
        frame = {
            x = 0,
            y = 0,
            h = self.dotSize,
            w = self.dotSize
        }
    }
    self._init_done = true
    return self
end

function obj:hideCanvasTimer()
    return hs.timer.doAfter(self.showOnChangeDuration, function()
        self.canvas:hide()
    end)
end

function obj:showCanvasOnChanged()
    local sourceID = hs.keycodes.currentSourceID()
    if (sourceID == self.lastLayout) then
        return
    end
    self.setColor(self, sourceID)
    self.canvas:show()
    if not self.hideCanvasTimer:running() then
        self.hideCanvasTimer:start()
    else
        self.hideCanvasTimer:stop()
        self.hideCanvasTimer:start()
    end
end
function obj:setColor(sourceID)
    -- change the color of the circle according to the input layout
    if (sourceID == "com.apple.keylayout.ABC") then
        self.color = self.ABCColor
    else
        self.color = self.LocalLanguageColor
    end
    self.lastLayout = sourceID
    self.canvas[1].fillColor = {
        hex = self.color
    }
end

function obj:showNearMouse()
    local cp = hs.mouse.absolutePosition()
    -- change the position of the canvas
    self.canvas:topLeft({
        x = cp.x - self.dotSize / 2,
        y = cp.y - 15
    })
end

function obj:adaptiveChangePosition()
    local systemWideElement = hs.axuielement.systemWideElement()
    local focusedElement = systemWideElement.AXFocusedUIElement
    if focusedElement then
        local selectedRange = focusedElement.AXSelectedTextRange
        if selectedRange then
            local selectionBounds = focusedElement:parameterizedAttributeValue("AXBoundsForRange", selectedRange)
            -- print the position and size of the selection,which is a table
            if selectionBounds then
                if selectionBounds.h == 0 or selectionBounds.y < 0 then
                    self:showNearMouse()
                else
                    self.canvas:topLeft({
                        x = selectionBounds.x - self.dotSize / 2,
                        y = selectionBounds.y - self.deltaY
                    })
                end
            else
                self:showNearMouse()
            end
        else
            self:showNearMouse()
        end
    end
end

function obj:adaptiveTimer()
    return hs.timer.doEvery(self.checkInterval, function()
        self:adaptiveChangePosition()
        self:setColor(hs.keycodes.currentSourceID())
    end)
end

function obj:showOnChangeTimer()
    return hs.timer.doEvery(self.checkInterval, function()
        self:adaptiveChangePosition()
        self:showCanvasOnChanged()
    end)
end

function obj:showNearMouseTimer()
    return hs.timer.doEvery(self.checkInterval, function()
        self:showNearMouse()
        self:setColor(hs.keycodes.currentSourceID())
    end)
end
--- InputMethodIndicator:start(config)
--- Method
--- Start InputMethodIndicator.
---
--- Parameters:
---  * config - A table contains config options for the module
---    * ABCColor - the dot color when the input method is ABC
---    * LocalLanguageColor - the dot color when the input method is not ABC
---    * mode - the mode of the indicator
---    * showOnChangeDuration - seconds to show the indicator when the input method is changed
---    * checkInterval - seconds to check the input method
---    * dotSize - the size of the dot
---    * deltaY - the distance between the dot and the center of the selection or mouse
function obj:start(config)
    -- check whether the config is a table
    if config then
        if type(config) ~= "table" then
            hs.alert.show("Config must be a table")
            logger.e("Config must be a table")
            return
        end
        for k, v in pairs(config) do
            if self[k] then
                self[k] = v
            else
                logger.e("Invalid config key: " .. k)
            end
        end
    end
    if self.mode == "onChange" then
        self.hideCanvasTimer = self:hideCanvasTimer()
        self.showOnChangeTimer = self:showOnChangeTimer()
    elseif self.mode == "adaptive" then
        self.canvas:show()
        self.adaptiveTimer = self:adaptiveTimer()
    elseif self.mode == "nearMouse" then
        self.canvas:show()
        self.showNearMouseTimer = self:showNearMouseTimer()
    else
        hs.alert.show("Invalid mode")
        logger.e("Invalid mode")
        return
    end
end

--- InputMethodIndicator:stop()
--- Method
--- Stop InputMethodIndicator.
---
--- Parameters:
---  * None
function obj:stop()
    self.canvas:hide()
    self.canvas = nil
    if self.showOnChangeTimer then
        self.showOnChangeTimer:stop()
        self.showOnChangeTimer = nil
    end
    if self.adaptiveTimer then
        self.adaptiveTimer:stop()
        self.adaptiveTimer = nil
    end
    if self.showNearMouseTimer then
        self.showNearMouseTimer:stop()
        self.showNearMouseTimer=nil
    end
end

return obj

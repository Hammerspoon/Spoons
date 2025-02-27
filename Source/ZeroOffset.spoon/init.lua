--- === ZeroOffset ===
---
--- Display UTC time in the menu bar
---
--- Download: [https://github.com/gavinest/ZeroOffset/blob/main/Spoons/ZeroOffset.spoon.zip](https://github.com/gavinest/ZeroOffset/blob/main/Spoons/ZeroOffset.spoon.zip)

local obj = {
    hs = hs,
}
obj.__index = obj

-- Metadata
obj.name = "ZeroOffset"
obj.version = "0.0.0"
obj.author = "Gavin Estenssoro"
obj.homepage = "https://github.com/gavinest/ZeroOffset"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- ZeroOffset:init()
--- Method
--- Initial setup for ZeroOffset
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ZeroOffset object
function obj:init()
    self.menuBarItem = nil
    self.hotKeyToggle = nil
    self.showUtc = false
    self.timer = self.hs.timer.new(1, function() self:updateMenuText() end)
    return self
end

--- ZeroOffset:start()
--- Method
--- Starts ZeroOffset
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ZeroOffset object
function obj:start()
    if self.menuBarItem then self:stop() end
    self.menuBarItem = self.hs.menubar.new()
    self.menuBarItem:setClickCallback(function() self:clicked() end)

    if self.hotKeyToggle then self.hotKeyToggle:enable() end

    self:toggleShowUtc()
    return self
end

--- ZeroOffset:stop()
--- Method
--- Stops ZeroOffset
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ZeroOffset object
function obj:stop()
    self.timer:stop()

    if self.menuBarItem then
        self.menuBarItem:delete()
        self.menuBarItem = nil
    end

    if self.hotKeyToggle then
        self.hotKeyToggle:disable()
        self.hotKeyToggle = nil
    end
    return self
end

--- ZeroOffset:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ZeroOffset
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * toggle - This will toggle the display of the UTC time in menubar
---
--- Returns:
---  * The ZeroOffset object
function obj:bindHotkeys(mapping)
    if self.hotKeyToggle then self.hotKeyToggle:delete() end
    local toggleMods = mapping["toggle"][1]
    local toggleKey = mapping["toggle"][2]
    self.hotKeyToggle = self.hs.hotkey.new(toggleMods, toggleKey, function() self:clicked() end)
    return self
end

function obj:toggleShowUtc()
    if self.showUtc then
        self:updateMenuText()
        self.timer:start()
        self.menuBarItem:setIcon(nil)
    else
        self.timer:stop()
        self.menuBarItem:setTitle(nil)
        local iconPath = self.hs.spoons.resourcePath("icon.png")
        self.menuBarItem:setIcon(self.hs.image.imageFromPath(iconPath):setSize({w=24,h=24}))
    end
    self.showUtc = not self.showUtc
end

function obj:clicked()
    self:toggleShowUtc()
end

function obj:updateMenuText()
    local utc_time = os.date("!%Y-%m-%d %H:%M:%S")
    self.menuBarItem:setTitle(utc_time .. ' UTC')
end

return obj

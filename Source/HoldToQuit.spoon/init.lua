--- === HoldToQuit ===
---
--- Instead of pressing ⌘Q, hold ⌘Q to close applications.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "HoldToQuit"
obj.version = "1.0"
obj.author = "Matthias Strauss <matthias.strauss@mayflower.de>"
obj.github = "@MattFromGer"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- HoldToQuit.duration
--- Variable
--- Integer containing the duration (in seconds) how long to hold
--- the hotkey. Default 1.
obj.duration = 1

--- HoldToQuit.defaultHotkey
--- Variable
--- Default hotkey mapping
obj.defaultHotkey = {
    quit = { {"cmd"}, "Q" }
}

--- HoldToQuit.hotkeyQbj
--- Variable
--- Hotkey object
obj.hotkeyQbj = nil

--- HoldToQuit.timer
--- Variable
--- Timer for counting the holding time
obj.timer = nil

--- HoldToQuit.killCurrentApp
--- Method
--- Kill the frontmost application
---
--- Parameters:
---  * None
function obj:killCurrentApp()
    local app = hs.application.frontmostApplication()
    app:kill()
end

--- HoldToQuit:init()
--- Method
--- Initialize spoon
---
--- Parameters:
---  * None
function obj:init()
    self.timer = hs.timer.delayed.new(self.duration, self.killCurrentApp)
end

--- HoldToQuit:onKeyDown()
--- Method
--- Start timer on keyDown
---
--- Parameters:
---  * None
function obj:onKeyDown()
    self.timer:start()
end

--- HoldToQuit:onKeyUp()
--- Method
--- Stop Timer & show alert message
---
--- Parameters:
---  * None
function obj:onKeyUp()
    if self.timer:running() then
        self.timer:stop()
        local app = hs.application.frontmostApplication()
        hs.alert.show("Hold ⌘Q to quit " .. app:name())
    end
end

--- HoldToQuit:start()
--- Method
--- Start HoldToQuit with default hotkey
---
--- Parameters:
---  * None
function obj:start()
    if (self.hotkeyQbj) then
        self.hotkeyQbj:enable()
    else
        local mod = self.defaultHotkey["quit"][1]
        local key = self.defaultHotkey["quit"][2]
        self.hotkeyQbj = hs.hotkey.bind(mod, key, function() obj:onKeyDown() end, function() obj:onKeyUp() end)
    end
end

--- HoldToQuit:stop()
--- Method
--- Disable HoldToQuit hotkey
---
--- Parameters:
---  * None
function obj:stop()
    if (self.hotkeyQbj) then
        self.hotkeyQbj:disable()
    end
end

--- HoldToQuit:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for HoldToQuit
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * show - This will define the quit hotkey
function obj:bindHotkeys(mapping)
    if (self.hotkeyQbj) then
        self.hotkeyQbj:delete()
    end
    
    local mod = mapping["quit"][1]
    local key = mapping["quit"][2]
    self.hotkeyQbj = hs.hotkey.bind(mod, key, function() obj:onKeyDown() end, function() obj:onKeyUp() end)

    return self
end

return obj

--- === ForceTouchMapper ===
---
--- Maps force touch clicks in specified apps to a hot key
---
--- Example use:
--- `spoon.SpoonInstall:andUse("ForceTouchMapper", {
---    config = {apps = {["com.microsoft.VSCode"] = {keyStroke = {{"cmd"}, 'y'}}}}
--- })`
--- which will invoke `cmd+y` keystroke when you force click some definition in VS Code.
---
--- I have this key binding in VS Code for peek definition
---
--- `{
---    "key": "cmd+y",
---    "command": "editor.action.peekDefinition",
---    "when": "editorHasDefinitionProvider && editorTextFocus && !inReferenceSearchEditor && !isInEmbeddedEditor"
---  }`
---,
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ForceTouchMapper.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ForceTouchMapper.spoon.zip)
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ForceTouchMapper"
obj.version = "1.0"
obj.author = "Krystof Celba <krystof@celba.me>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- ForceTouchMapper.apps
--- Variable
--- Table of bundle ids of apps in which you want to map forcetouch to keyStroke
obj.apps = {["com.microsoft.VSCode"] = {keyStroke = {{"cmd"}, 'y'}}}

function obj:pressure_handler(event)
    local event_type = event:getType(true)

    local td = event:getTouchDetails()
    local app = hs.application.frontmostApplication()

    if self.apps[app:bundleID()] ~= nil and td.stage == 2 and event_type ==
        hs.eventtap.event.types.pressure then
        local pressure = td.pressure
        if pressure > 0.0 then return false end

        return true, {
            hs.eventtap.keyStroke(table.unpack(
                                      self.apps[app:bundleID()].keyStroke))
        }
    end
    return false
end

--- ForceTouchMapper:start()
--- Method
--- Start ForceTouchMapper
---
--- Parameters:
---  * None
function obj:start()
    self.eventtap = {}
    self.eventtap = hs.eventtap.new({hs.eventtap.event.types.gesture},
                                    hs.fnutils.partial(self.pressure_handler,
                                                       self))
    self.eventtap:start()
    return self
end

function obj:stop()
    self.eventtap:stop()
end

return obj

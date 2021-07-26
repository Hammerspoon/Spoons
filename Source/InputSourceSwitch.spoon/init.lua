--- === InputSourceSwitch ===
---
--- Automatically switch the input source when switching applications.
---
--- Example:
--- ```
--- hs.loadSpoon("InputSourceSwitch")
---
--- spoon.InputSourceSwitch:setApplications({
---     ["WeChat"] = "Pinyin - Simplified",
---     ["Mail"] = "ABC"
--- })
---
--- spoon.InputSourceSwitch:start()
--- ```
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/InputSourceSwitch.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/InputSourceSwitch.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "InputSourceSwitch"
obj.version = "1.0"
obj.author = "eks5115 <eks5115@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local log = hs.logger.new('InputSourceSwitch','debug')
log.d('Init')

-- Internal function used to get enabled input sources
local function getEnabledInputSourcesMap()
    local map = {}
    local handle = io.popen(hs.configdir.."/Spoons/InputSourceSwitch.spoon/bin/InputSourceSelector list-enabled")
    for line in handle:lines() do
        local v, k = string.match(line, "(%S+) %((.+)%)")
        map[k] = v
    end
    handle:close()
    return map
end

local function setAppInputSource(appName, sourceID, event)
    -- hs.window.filter.windowCreated
    event = event or hs.window.filter.windowFocused

    hs.window.filter.new(appName):subscribe(event, function()
        r = hs.keycodes.currentSourceID(sourceID)
    end)
end

--- InputSourceSwitch.inputSourceMap
--- Variable
--- Mapping the input source to the source id
---
--- Default value: enabled input sources
obj.inputSourcesMap = getEnabledInputSourcesMap()

--- InputSourceSwitch.applicationMap
--- Variable
--- Mapping the application name to the input source
obj.applicationsMap = {}

--- InputSourceSwitch:setApplications()
--- Method
--- Set that mapping the application name to the input source
---
--- Parameters:
---  * applications - A table containing that mapping the application name to the input source
---     key is the application name and value is the input source name
---     example:
--- ```
--- {
---     ["WeChat"] = "Pinyin - Simplified",
---     ["Mail"] = "ABC"
--- }
--- ```
function obj:setApplications(applications)
    for key, value in pairs(applications) do
        obj.applicationsMap[key] = value
    end
end

--- InputSourceSwitch:start()
--- Method
--- Start InputSourceSwitch
---
--- Parameters:
---  * None
function obj:start()
    for k,v in pairs(self.applicationsMap) do
        setAppInputSource(k, self.inputSourcesMap[v])
    end
    return self
end

return obj

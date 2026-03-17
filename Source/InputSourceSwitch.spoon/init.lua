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
---     ["Mail"] = "ABC",
---     -- Use application watcher for apps that window filter can't capture
---     ["kitty-quick-access"] = { source = "ABC", watcher = "application" }
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
obj.version = "1.1"
obj.author = "eks5115 <eks5115@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local log = hs.logger.new('InputSourceSwitch','debug')
log.d('Init')

-- Internal function used to get enabled input sources
local function isLayout(layoutName)
    local layouts = hs.keycodes.layouts()
    for key, value in pairs(layouts) do
        if (value == layoutName) then
            return true
        end
    end

    return false
end

local function isMethod(methodName)
    local methods = hs.keycodes.methods()
    for key, value in pairs(methods) do
        if (value == methodName) then
            return true
        end
    end

    return false
end

local function switchInputSource(sourceName, appName)
    local r = true

    if (isLayout(sourceName)) then
        r = hs.keycodes.setLayout(sourceName)
    elseif isMethod(sourceName) then
        r = hs.keycodes.setMethod(sourceName)
    else
        hs.alert.show(string.format('sourceName: %s is not layout or method', sourceName))
    end

    if (not r) then
        hs.alert.show(string.format('set %s to %s failure', appName, sourceName))
    end
end

local function setAppInputSourceWithWindowFilter(appName, sourceName, event)
    event = event or hs.window.filter.windowFocused

    hs.window.filter.new(appName):subscribe(event, function()
        switchInputSource(sourceName, appName)
    end)
end

local function setAppInputSourceWithAppWatcher(appName, sourceName)
    local watcher = hs.application.watcher.new(function(name, eventType, appObj)
        if eventType == hs.application.watcher.activated and name == appName then
            switchInputSource(sourceName, appName)
        end
    end)
    watcher:start()
    return watcher
end

--- InputSourceSwitch.applicationMap
--- Variable
--- Mapping the application name to the input source
obj.applicationsMap = {}

-- Store application watchers to prevent garbage collection
obj.appWatchers = {}

--- InputSourceSwitch:setApplications()
--- Method
--- Set that mapping the application name to the input source
---
--- Parameters:
---  * applications - A table containing that mapping the application name to the input source
---     key is the application name
---     value can be:
---       - a string: the input source name (uses window filter, default)
---       - a table: { source = "input source name", watcher = "window" | "application" }
---     example:
--- ```
--- {
---     ["WeChat"] = "Pinyin - Simplified",
---     ["Mail"] = "ABC",
---     ["kitty-quick-access"] = { source = "ABC", watcher = "application" }
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
    for appName, config in pairs(self.applicationsMap) do
        local sourceName, watcherType

        if type(config) == "string" then
            sourceName = config
            watcherType = "window"
        else
            sourceName = config.source
            watcherType = config.watcher or "window"
        end

        if watcherType == "application" then
            self.appWatchers[appName] = setAppInputSourceWithAppWatcher(appName, sourceName)
        else
            setAppInputSourceWithWindowFilter(appName, sourceName)
        end
    end
    return self
end

return obj

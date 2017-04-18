--- === Seal ===
---
--- Pluggable launch bar

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Seal"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.chooser = nil
obj.hotkeyShow = nil
obj.plugins = {}
obj.commands = {}
obj.queryChangedTimer = nil

-- Internal function used to find our location, so we know where to load plugins from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

--- Seal:loadPlugins(plugins)
--- Method
--- Loads a list of Seal plugins
---
--- Parameters:
---  * plugins - A list containing the names of plugins to load
---
--- Returns:
---  * The Seal object
---
--- Notes:
---  * The plugins live inside the Seal.spoon directory
---  * The plugin names in the list, should not have `seal_` at the start, or `.lua` at the end
---  * Some plugins may immediately begin doing background work (e.g. Spotlight searches)
function obj:loadPlugins(plugins)
    self.chooser = hs.chooser.new(self.completionCallback)
    self.chooser:choices(self.choicesCallback)
    self.chooser:queryChangedCallback(self.queryChangedCallback)

    for k,plugin_name in pairs(plugins) do
        print("-- Loading Seal plugin: " .. plugin_name)
        plugin = dofile(self.spoonPath.."/seal_"..plugin_name..".lua")
        plugin.seal = self
        table.insert(obj.plugins, plugin)
        for cmd,cmdInfo in pairs(plugin:commands()) do
            print("-- Adding Seal command: "..cmd)
            obj.commands[cmd] = cmdInfo
        end
    end
    return self
end

--- Seal:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for Seal
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * show - This will cause Seal's UI to be shown
---
--- Returns:
---  * The Seal object
function obj:bindHotkeys(mapping)
    if (self.hotkeyShow) then
        self.hotkeyShow:delete()
    end
    local showMods = mapping["show"][1]
    local showKey = mapping["show"][2]
    self.hotkeyShow = hs.hotkey.new(showMods, showKey, function() self:show() end)

    return self
end

--- Seal:start()
--- Method
--- Starts Seal
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Seal object
function obj:start()
    print("-- Starting Seal")
    if self.hotkeyShow then
        self.hotkeyShow:enable()
    end
    return self
end

--- Seal:stop()
--- Method
--- Stops Seal
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Seal object
---
--- Notes:
---  * Some Seal plugins will continue performing background work even after this call (e.g. Spotlight searches)
function obj:stop()
    print("-- Stopping Seal")
    self.chooser:hide()
    if self.hotkeyShow then
        self.hotkeyShow:disable()
    end
    return self
end

--- Seal:show()
--- Method
--- Shows the Seal UI
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This may be useful if you wish to show Seal in response to something other than its hotkey
function obj:show()
    self.chooser:show()
    return self
end

function obj.completionCallback(rowInfo)
    if rowInfo == nil then
        return
    end
    if rowInfo["type"] == "plugin_cmd" then
        obj.chooser:query(rowInfo["cmd"])
        return
    end
    for k,plugin in pairs(obj.plugins) do
        if plugin.__name == rowInfo["plugin"] then
            plugin.completionCallback(rowInfo)
            break
        end
    end
end

function obj.choicesCallback()
    -- TODO: Sort each of these clusters of choices, alphabetically
    choices = {}
    query = obj.chooser:query()
    cmd = nil
    query_words = {}
    if query == "" then
        return choices
    end
    for word in string.gmatch(query, "%S+") do
        if cmd == nil then
            cmd = word
        else
            table.insert(query_words, word)
        end
    end
    query_words = table.concat(query_words, " ")
    -- First get any direct command matches
    for command,cmdInfo in pairs(obj.commands) do
        cmd_fn = cmdInfo["fn"]
        if cmd:lower() == command:lower() then
            if (query_words or "") == "" then
                query_words = ".*"
            end
            fn_choices = cmd_fn(query_words)
            if fn_choices ~= nil then
                for j,choice in pairs(fn_choices) do
                    table.insert(choices, choice)
                end
            end
        end
    end
    -- Now get any bare matches
    for k,plugin in pairs(obj.plugins) do
        bare = plugin:bare()
        if bare then
            for i,choice in pairs(bare(query)) do
                table.insert(choices, choice)
            end
        end
    end
    -- Now add in any matching commands
    -- TODO: This only makes sense to do if we can select the choice without dismissing the chooser, which requires changes to HSChooser
    for command,cmdInfo in pairs(obj.commands) do
        if string.match(command, query) and #query_words == 0 then
            choice = {}
            choice["text"] = cmdInfo["name"]
            choice["subText"] = cmdInfo["description"]
            choice["type"] = "plugin_cmd"
            table.insert(choices,choice)
        end
    end

    return choices
end

function obj.queryChangedCallback(query)
    if obj.queryChangedTimer then
        obj.queryChangedTimer:stop()
    end
    obj.queryChangedTimer = hs.timer.doAfter(0.2, function() obj.chooser:refreshChoicesCallback() end)
end

return obj


local obj = {}
obj.__index = obj
obj.__name = "seal_apps"
obj.appCache = {}
obj.appSearchPaths = {
    "/Applications",
    "~/Applications",
    "/Developer/Applications",
    "/Applications/Xcode.app/Contents/Applications",
    "/System/Library/PreferencePanes",
    "/Library/PreferencePanes",
    "~/Library/PreferencePanes",
    "/System/Library/CoreServices/Applications",
    "/usr/local/Cellar",
}

local modifyNameMap = function(info, add)
    for _, item in ipairs(info) do
        if add then
            bundleID = item.kMDItemCFBundleIdentifier
            icon = nil
            if bundleID then
                icon = hs.image.imageFromAppBundle(bundleID)
            end
            obj.appCache[item.kMDItemDisplayName] = {
                path = item.kMDItemPath,
                bundleID = bundleID,
                icon = icon
            }
        else
            obj.appCache[item.kMDItemDisplayName] = nil
        end
    end
end

local updateNameMap = function(obj, msg, info)
    if info then
        -- all three can occur in either message, so check them all!
        if info.kMDQueryUpdateAddedItems   then modifyNameMap(info.kMDQueryUpdateAddedItems,   true)  end
        if info.kMDQueryUpdateChangedItems then modifyNameMap(info.kMDQueryUpdateChangedItems, true)  end
        if info.kMDQueryUpdateRemovedItems then modifyNameMap(info.kMDQueryUpdateRemovedItems, false) end
    else
        -- shouldn't happen for didUpdate or inProgress
        print("~~~ userInfo from SpotLight was empty for " .. msg)
    end
end

obj.spotlight = hs.spotlight.new():queryString([[ kMDItemContentType = "com.apple.application-bundle" ]])
                                  :callbackMessages("didUpdate", "inProgress")
                                  :setCallback(updateNameMap)
                                  :searchScopes(obj.appSearchPaths)
                                  :start()

function obj:commands()
    return {kill = {
        cmd = "kill",
        fn = obj.choicesKillCommand,
        plugin = obj.__name,
        name = "Kill",
        description = "Kill an application"
        }
    }
end

function obj:bare()
    return self.choicesApps
end

function obj.choicesApps(query)
    local choices = {}
    if query == nil or query == "" then
        return choices
    end
    for name,app in pairs(obj.appCache) do
        if string.match(name:lower(), query:lower()) then
            local choice = {}
            local instances = {}
            if app["bundleID"] then
                instances = hs.application.applicationsForBundleID(app["bundleID"])
            end
            if #instances > 0 then
                choice["text"] = name .. " (Running)"
            else
                choice["text"] = name
            end
            choice["subText"] = app["path"]
            if app["icon"] then
                choice["image"] = app["icon"]
            end
            choice["path"] = app["path"]
            choice["uuid"] = obj.__name.."__"..(app["bundleID"] or name)
            choice["plugin"] = obj.__name
            choice["type"] = "launchOrFocus"
            table.insert(choices, choice)
        end
    end
    return choices
end

function obj.choicesKillCommand(query)
    local choices = {}
    if query == nil then
        return choices
    end
    local apps = hs.application.runningApplications()
    for k, app in pairs(apps) do
        local name = app:name()
        if string.match(name:lower(), query:lower()) and app:mainWindow() then
            local choice = {}
            choice["text"] = "Kill "..name
            choice["subText"] = app:path().." PID: "..app:pid()
            choice["pid"] = app:pid()
            choice["plugin"] = obj.__name
            choice["type"] = "kill"
            table.insert(choices, choice)
        end
    end
    return choices
end

function obj.completionCallback(rowInfo)
    if rowInfo["type"] == "launchOrFocus" then
        hs.application.launchOrFocus(rowInfo["path"])
    elseif rowInfo["type"] == "kill" then
        hs.application.get(rowInfo["pid"]):kill()
    end
end

return obj

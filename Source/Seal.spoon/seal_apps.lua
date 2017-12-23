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
   "/Library/Scripts",
   "~/Library/Scripts"
}

local modifyNameMap = function(info, add)
   for _, item in ipairs(info) do
      if add then
         bundleID = item.kMDItemCFBundleIdentifier
         icon = nil
         if bundleID then
            icon = hs.image.imageFromAppBundle(bundleID)
         end
         local displayname = item.kMDItemDisplayName
         displayname = displayname:gsub("%.app$", "", 1)
         if string.find(item.kMDItemPath, "%.prefPane$") then
            displayname = item.kMDItemDisplayName .. " preferences"
            icon = hs.image.iconForFile(item.kMDItemPath)
         end
         obj.appCache[displayname] = {
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

obj.spotlight = hs.spotlight.new():queryString([[ (kMDItemContentType = "com.apple.application-bundle") || (kMDItemContentType = "com.apple.systempreference.prefpane")  || (kMDItemContentType = "com.apple.applescript.text")  || (kMDItemContentType = "com.apple.applescript.script") ]])
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
                  },
           reveal = {
              cmd = "reveal",
              fn = obj.choicesRevealCommand,
              plugin = obj.__name,
              name = "Reveal",
              description = "Reveal an application in the Finder"
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
         choice["image"] = hs.image.imageFromAppBundle(app:bundleID())
         table.insert(choices, choice)
      end
   end
   return choices
end

function obj.choicesRevealCommand(query)
   local choices = {}
   if query == nil then
      return choices
   end
   local apps = obj.choicesApps(query)
   for k, app in pairs(apps) do
      local name = app.text
      if string.match(name:lower(), query:lower()) then
         local choice = {}
         choice["text"] = "Reveal "..name
         choice["path"] = app.path
         choice["subText"] = app.path
         choice["plugin"] = obj.__name
         choice["type"] = "reveal"
         if app.image then
            choice["image"] = app.image
         end
         table.insert(choices, choice)
      end
   end
   return choices
end

function obj.completionCallback(rowInfo)
   if rowInfo["type"] == "launchOrFocus" then
      if string.find(rowInfo["path"], "%.applescript$") or string.find(rowInfo["path"], "%.scpt$") then
         hs.execute(string.format("/usr/bin/osascript '%s'", rowInfo["path"]))
      else
         hs.execute(string.format("/usr/bin/open '%s'", rowInfo["path"]))
      end
   elseif rowInfo["type"] == "kill" then
      hs.application.get(rowInfo["pid"]):kill()
   elseif rowInfo["type"] == "reveal" then
      hs.osascript.applescript(string.format([[tell application "Finder" to reveal (POSIX file "%s")]], rowInfo["path"]))
      hs.application.launchOrFocus("Finder")
   end
end

return obj

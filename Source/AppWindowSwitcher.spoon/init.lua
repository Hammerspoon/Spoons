--- === AppWindowSwitcher ===
---
--- macOS application aware, keyboard driven window switcher. Spoon 
--- on top of Hammerspoon.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AppWindowSwitcher.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AppWindowSwitcher.spoon.zip)
---
--- Switches windows by focusing and raising them. All windows matching a 
--- bundelID, a list of bundleID's, an application name matchtext, 
--- or a list of application name matchtexts are switched by cycling 
--- them. Cycling applies to visible windows of currently focused space 
--- only. The spoon does not launch applications, it operates on open 
--- windows of running applications.
---
--- Example `~/.hammerspoon/init.lua` configuration:
---
--- ```
--- hs.loadSpoon("AppWindowSwitcher")
---     -- :setLogLevel("debug") -- uncomment for console debug log
---     :bindHotkeys({
---         ["com.apple.Terminal"]        = {hyper, "t"},
---         [{"com.apple.Safari",
---           "com.google.Chrome",
---           "com.kagi.kagimacOS",
---           "com.microsoft.edgemac", 
---           "org.mozilla.firefox"}]     = {hyper, "q"},
---         ["Hammerspoon"]               = {hyper, "h"},
---         [{"O", "o"}]                  = {hyper, "o"},
---     })
--- ```
--- In this example, 
--- * `hyper-t` cycles all terminal windows (matching a single bundleID),
--- * `hyper-q` cycles all windows of the five browsers (matching either 
---   of the bundleIDs)
--- * `hyper-h` brings the Hammerspoon console forward (matching the 
---   application title),
--- * `hyper-o` cycles all windows whose application title starts 
---   with "O" or "o".
---
--- The cycling logic works as follows:
--- * If the focused window is part of the application matching a hotkey,
---   then the last window (in terms of macOS windows stacking) of the matching 
---   application(s) will be brought forward and focused.
--- * If the focused window is not part of the application matching a
---   hotkey, then the first window (in terms of macOS windows stacking) i
---   of the matching applications will be brought forward and focused.

require("hs.hotkey")
require("hs.window")
require("hs.inspect")
require("hs.fnutils")

local obj={}
obj.__index = obj

-- Metadata
obj.name = "AppWindowSwitcher"
obj.version = "0.0"
obj.author = "B Viefhues"
obj.homepage = "https://github.com/bviefhues/AppWindowSwitcher.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"


-- AppWindowSwitcher.log
-- Variable
-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.log = hs.logger.new("AppWindowSwitcher")

-- prefix match for text. Returns true if text starts with prefix.
function obj.startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

-- Matches window properties with matchtexts array of texts
-- Returns true if:
-- * windows application bundleID is an element of matchtexts, or
-- * windows application title starts with an element of matchtext
function obj.match(window, matchtexts)
    bundleID = window:application():bundleID()
    if hs.fnutils.contains(matchtexts, bundleID) then
        obj.log.d("bundleID matches:", bundleID)
        return true
    end
    title = window:application():title()
    for _, matchtext in pairs(matchtexts) do
        if obj.startswith(title, matchtext) then
            obj.log.d("title matches:", title, matchtext)
            return true
        end
    end
    return false
end

--- AppWindowSwitcher:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for AppWindowSwitcher
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for each application to manage 
---
--- Notes:
--- The mapping table accepts these formats per table element:
--- * A single text to match:
---   `["<matchtext>"] = {mods, key}` 
--- * A list of texts, to assign multiple applications to one hotkey:
---   `[{"<matchtext>", "<matchtext>", ...}] = {mods, key}`
--- * `<matchtext>` can be either a bundleID, or a text which is substring matched against a windows application title start. 
---
--- Returns:
---  * The AppWindowSwitcher object
function obj:bindHotkeys(mapping)
    for matchtexts, modsKey in pairs(mapping) do
        obj.log.d("Mapping " .. hs.inspect(matchtexts) .. 
                  " to " .. hs.inspect(modsKey))

        if type(matchtexts) == "string" then
            matchtexts = {matchtexts} -- further code assumes a table
        end
        mods, key = table.unpack(modsKey)
        hs.hotkey.bind(mods, key, function() 
            local focusedWindowBundleID = 
                hs.window.focusedWindow():application():bundleID() 

            newW = nil
            if obj.match(hs.window.focusedWindow(), matchtexts) then
                -- app has focus, find last matching window
                for _, w in pairs(hs.window.orderedWindows()) do
                    if obj.match(w, matchtexts) then
                        newW = w -- remember last match
                    end
                end
            else
                -- app does not have focus, find first matching window
                for _, w in pairs(hs.window.orderedWindows()) do
                    if obj.match(w, matchtexts) then
                        newW = w
                        break -- break on first match
                    end
                end
            end
            if newW then
                newW:raise():focus()
            else
                hs.alert.show("No window open for " .. 
                    hs.inspect(matchtexts))
            end
        end)
    end

    return self
end

--- AppWindowSwitcher:setLogLevel(level) -> self
--- Method
--- Set the log level of the spoon logger.
---
--- Parameters:
---  * Log level - `"debug"` to enable console debug output
---
--- Returns:
---  * The AppWindowSwitcher object
function obj:setLogLevel(level)
    obj.log.setLogLevel(level)
    return self
end

return obj

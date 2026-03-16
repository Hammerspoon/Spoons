--- === DockClick ===
---
--- Emulates clicking the currently active application in the dock to avoid hunting for app icons.
---
--- This spoon is useful for quickly restoring the primary window of the frontmost application
--- by simulating a click on its dock icon. This is particularly helpful when you want to bring
--- back a closed or hidden window.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/DockClick.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/DockClick.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "DockClick"
obj.version = "1.0"
obj.author = "Silas Burger"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- DockClick:clickFrontmost()
--- Method
--- Finds and clicks the currently active application in the dock
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This method uses accessibility features to interact with the dock
---  * The method will match partial application names (e.g., "Chrome" matches "Google Chrome")
---  * If the active application is not found in the dock, nothing happens
function obj:clickFrontmost()
	-- Get the Dock element
	local axuielement = require("hs.axuielement")
	local dockElement = axuielement.applicationElement("com.apple.dock")

	-- Function to get the currently active application
	local function getFrontmostApp()
		local frontApp = hs.application.frontmostApplication()
		if obj.logger then
			obj.logger.d("Currently active application: " .. frontApp:name())
		end
		return frontApp:name()
	end

	-- Function to get the list of application names in the Dock
	local function getDockAppNames()
		local appNames = {}

		-- Loop through the children of the Dock element
		for _, child in ipairs(dockElement[1]) do
			if child.AXSubrole == "AXApplicationDockItem" then
				table.insert(appNames, child.AXTitle) -- App name is stored in AXTitle
			end
		end
		return appNames
	end

	-- Helper function to remove trailing numbers and spaces
	local function trimTrailingNumbers(str)
		return string.gsub(str, "[%s%d]+$", "")
	end

	-- Comparison function with partial string match
	local function findAppInDock(activeAppName, dockApps)
		-- Convert to lowercase
		local activeAppName = trimTrailingNumbers(activeAppName:lower())

		for _, appName in ipairs(dockApps) do
			local dockAppName = trimTrailingNumbers(appName:lower())

			-- Partial string matching: check if the simplified active app name is part of any dock app name
			if dockAppName:find(activeAppName, 1, true) then
				if obj.logger then
					obj.logger.d("Matched dock item: " .. appName)
				end
				return appName
			end
		end
		return nil
	end

	-- Press dock child based on name
	local function pressDockChild(appName)
		for _, child in ipairs(dockElement[1]) do
			if child.AXSubrole == "AXApplicationDockItem" then
				if child.AXTitle == appName then
					child:performAction("AXPress") -- Simulates a click on the Dock item
					if obj.logger then
						obj.logger.d("Pressed dock item: " .. appName)
					end
					return
				end
			end
		end
	end

	-- Get the Dock applications
	local dockAppNames = getDockAppNames()

	-- Check if the active application is in the Dock
	local currentlyActiveApp = getFrontmostApp()
	local dockAppName = findAppInDock(currentlyActiveApp, dockAppNames)
	if dockAppName then
		if obj.logger then
			obj.logger.d("The active app is in the Dock.")
		end
		pressDockChild(dockAppName)
	else
		if obj.logger then
			obj.logger.d("The active app is NOT in the Dock.")
		end
	end
end

--- DockClick:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for DockClick
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * click - Restore the window of the currently active application by clicking its icon in the dock (default: cmd+alt+w)
---
--- Returns:
---  * The DockClick object
---
--- Notes:
---  * If no mapping is provided, the default hotkey (cmd+alt+w) is used
---  * Example usage:
---    ```lua
---    spoon.DockClick:bindHotkeys({
---      click = {{"cmd", "alt"}, "w"}
---    })
---    ```
function obj:bindHotkeys(mapping)
	if mapping and mapping.click then
		-- Use the provided mapping
		local def = {
			click = hs.fnutils.partial(self.clickFrontmost, self),
		}
		hs.spoons.bindHotkeysToSpec(def, mapping)
	else
		-- Bind default hotkey (cmd + alt + w) if no mapping is provided
		hs.hotkey.bind({ "cmd", "alt" }, "w", function()
			self:clickFrontmost()
		end)
	end
	return self
end

--- DockClick:init()
--- Method
--- Initializes the DockClick spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The DockClick object
---
--- Notes:
---  * Currently this method does nothing, but is reserved for future use
function obj:init()
	-- Optional: Initialize a logger for debugging
	-- obj.logger = hs.logger.new('DockClick', 'debug')
	return self
end

return obj

--- === PersonalHotspot ===
---
--- Connect, disconnect, or toggle connection to/from a personal hotspot. Optionally kills/opens a list of apps on connect/disconnect respectively.
---
--- Example configuration (using SpoonInstall.spoon):
--- ```
--- spoon.SpoonInstall:andUse(
---   "PersonalHotspot",
---   {
---     config = {
---       hotspotName = "John Appleseed’s iPhone",
---       appsToKill = {
---         "Arq",
---         "Arq Agent",
---         "Dropbox"
---       }
---     },
---     hotkeys = {
---       toggle = {{"cmd", "option", "ctrl"}, "h"}
---     }
---   }
--- )
--- ```
---
--- If `PersonalHotspot.hotspotName` isn't set, the first personal hotspot in the Wi-Fi menu will be selected, and `PersonalHotspot.hotspotName` will be set to the name of that hotspot.


-----------------------
-- Setup Environment --
-----------------------
-- Create locals for all needed globals so we have access to them
local pairs  = pairs
local string = string
local hs   = {
  application = hs.application,
  fnutils     = hs.fnutils,
  hotkey      = hs.hotkey,
  notify      = hs.notify,
  osascript   = hs.osascript,
  wifi        = hs.wifi
}


-- Empty environment in this scope, this prevents module from polluting global scope
local _ENV = {}


-------------
-- Private --
-------------

-- Core functionality of this spoon. See comments in js code.
local function controlHotspot(wifiMenuItem, timeout)
  local _, wifiMenuItemClicked = hs.osascript.javascript(string.format(
    [[
    const wifiMenuItemName = '%s'
    const timeout = %f

    // Get Wi-Fi menu bar item and menu from System menu bar
    const systemMenuBar = Application('System Events')
      .processes['SystemUIServer']
      .menuBars[0]
    const wifiMenuBarItem = systemMenuBar
      .entireContents()
      .find(function(x) {return x.description().startsWith('Wi-Fi')})
    const wifiMenu = wifiMenuBarItem.menus[0]

    // Open Wi-Fi menu
    wifiMenuBarItem.click()

    // Search Wi-Fi menu for wifiMenuItemName every 0.1s until we find it or we hit the timeout
    var wifiMenuItemIndex = -1
    for (i = timeout; i > 0; i -= 0.25) {
      wifiMenuItemIndex = wifiMenu
        .entireContents()
        .findIndex(function(x) {return x.title().startsWith(wifiMenuItemName)})
      if (wifiMenuItemIndex >= 0) break
      delay(0.25)
    }

    // Close menu if menu item wasn't found or adjust index if specific hotspot wasn't given
    var hotspotMenuItemIndex = -1
    if (wifiMenuItemIndex == -1) {
      wifiMenu.cancel()
    } else if (wifiMenuItemName == "Personal Hotspot") {
      hotspotMenuItemIndex = wifiMenuItemIndex + 1
    } else {
      hotspotMenuItemIndex = wifiMenuItemIndex
    }

    // Click to conncet/disconnect to/from hotspot and return name of menu item that was clicked
    // This will error if no menu item was found, which is what we want
    const hotspotName = wifiMenu.menuItems[hotspotMenuItemIndex].title()
    wifiMenu.menuItems[hotspotMenuItemIndex].click()
    hotspotName
    ]],
    wifiMenuItem,
    timeout)
  )
  return wifiMenuItemClicked
end


------------
-- Public --
------------
-- luacheck: no global

-- Spoon metadata
name     = "PersonalHotspot"
version  = "1.0" -- obj.version = "1.0"
author   = "Malo Bourgon"
license  = "MIT - https://opensource.org/licenses/MIT"
homepage = "https://github.com/malob/PersonalHotspot.spoon"

--- PersonalHotspot.appsToKill (List)
--- Variable
--- A list of strings representing applications to kill/open, when `PersonalHotspot:connect()` and `PersonalHotspot:disconnect()` are called respectively.
---
--- Each string should be either:
---  * a bundle ID string as per `hs.application:bundleID()`, or
---  * an application name string as per `hs.application:name()`.
appsToKill = {}

--- PersonalHotspot.hotspotName (String)
--- Variable
--- The name of the personal hotspot you want to connect/disconnect from, e.g., "John Appleseed’s iPhone".
---
--- You can see the names of available hotspots by clicking on the Wi-Fi icon in the macOS menu bar and looking for menu items under the "Personal Hotspot(s)" heading.
hotspotName = nil

--- PersonalHotspot.timeout (Number)
--- Variable
--- The number of seconds to wait for personal hotspot to appear in Wi-Fi menu before attempting to connect/disconnect. Default is 3 seconds.
timeout = 3

--- PersonalHotspot:connect() -> Self
--- Method
--- Tries to connect to the personal hotspot named in `PersonalHotspot.hotspotName`. If `PersonalHotspot.hotspotName` is `nil`, the first hotspot in the Wi-Fi menu will be selected, and `PersonalHotspot.hotspotName` will be assigned to the name of that hotspot. Once connected to the hotspot, the applications specified in `PersonalHotspot.appsToKill` are killed.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Self
---
--- Notes:
---  * If there are no hotspots with the name in `PersonalHotspot.hotspotName`, or if `PersonalHotspot.hotspotName` is `nil` and there are no hotspots in the Wi-Fi menu, the Wi-Fi menu will be closed after `PersonalHotspot.timeout` seconds.
function connect(self)
  local wifiMenuItemClicked = controlHotspot(hotspotName or "Personal Hotspot", timeout)

  if wifiMenuItemClicked then
    if not hotspotName then
      hotspotName = wifiMenuItemClicked
    end
    hs.fnutils.ieach(
      appsToKill,
      function(x)
        local app = hs.application.get(x)
        if app then app:kill() end
      end
    )
  else
    hs.notify.show("Personal Hotspot", "", "Hotspot not found in Wi-Fi menu")
  end

  return self
end

--- PersonalHotspot:disconnect() -> Self
--- Method
--- If currently connected to the personal hotspot named in `PersonalHotspot.hotspotName`, this method will disconnect from that hotspot and open the applications specified in `PersonalHostspot.appsToKill`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Self
function disconnect(self)
  if controlHotspot("Disconnect from " .. hotspotName, timeout) then
    hs.fnutils.ieach(
      appsToKill,
      function(x) hs.application.open(x) end
    )
  else
    hs.notify.show("Personal Hotspot", "", "Error disconnecting from hotspot")
  end

  return self
end

--- PersonalHotspot:toggle() -> Self
--- Method
--- Toggles personal hotspot connection.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Self
---
--- Notes:
---  * If the current wireless network name is `PersonalHotspot.hotspotName` this method calls `PersonalHotspot:disconnect()`, otherwise this method will call `PersonalHotspot:connect()`.
function toggle(self)
  if hs.wifi.currentNetwork() == hotspotName then
    self:disconnect()
  else
    self:connect()
  end

  return self
end

--- PersonalHotspot:bindHotkeys(mapping) -> Self
--- Method
--- Binds hotkey mappings for this spoon.
---
--- Parameters:
---  * mapping (Table) - A table with keys who's names correspond to methods of this spoon, and values that represent hotkey mappings. For example:
---    * `{ toggle = { {"cmd", "option", "ctrl" }, "h" }`
---
--- Returns:
---  * Self
function bindHotkeys(self, mapping)
  for k, v in pairs(mapping) do
    hs.hotkey.bind(v[1], v[2], function() return self[k](self, k) end)
  end

  return self
end

-- Return the globals now in the environment, which is the module/spoon.
return _ENV

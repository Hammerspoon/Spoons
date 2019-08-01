--- === USBDeviceActions ===
---
--- Open/close apps or run an arbitrary function when a USB device is connected/disconnected.
---
--- Example configuration (using SpoonInstall.spoon):
--- ```
--- function toggleKeyboardLayout(x)
---   if x then
---     hs.keycodes.setLayout("U.S.")
---   else
---     hs.keycodes.setLayout("Colemak")
---   end
--- end
---
--- spoonInstall:andUse(
---   "USBDeviceActions",
---   {
---     config = {
---       devices = {
---         ScanSnapiX500EE            = { apps = { "ScanSnap Manager Evernote Edition" } },
---         Planck                     = { fn = toggleKeyboardLayout },
---         ["Corne Keyboard (crkbd)"] = { fn = toggleKeyboardLayout }
---       }
---     },
---     start = true
---   }
--- )
--- ```


-----------------------
-- Setup Environment --
-----------------------
-- Create locals for all needed globals so we have access to them
local type = type
local hs   = {
  application = hs.application,
  fnutils     = hs.fnutils,
  usb         = hs.usb,
  inspect     = hs.inspect
}

-- Empty environment in this scope, this prevents module from polluting global scope
local _ENV = {}


-------------
-- Private --
-------------
local watcher = nil

local function takeAction(appOrFn, eventType)
  local isFn = type(appOrFn) == "function"
  if eventType == "added" then
    if isFn then appOrFn(true); else hs.application.open(appOrFn) end
  elseif eventType == "removed" then
    if isFn then appOrFn(false)
    else
      local app = hs.application.get(appOrFn)
      if app then app:kill() end
    end
  end
end

local function usbEventCallback(devices, eventData)
  local deviceActions = devices[eventData.productName]
  if not deviceActions then return end

  local actionFn = function(x) takeAction(x, eventData.eventType) end
  if deviceActions.apps then hs.fnutils.ieach(deviceActions.apps, actionFn) end
  if deviceActions.fn then actionFn(deviceActions.fn) end
end


------------
-- Public --
------------
-- luacheck: no global

-- Spoon metadata
name     = "USBDeviceActions"
version  = "1.0" -- obj.version = "1.0"
author   = "Malo Bourgon"
license  = "MIT - https://opensource.org/licenses/MIT"
homepage = "https://github.com/malob/USBDeviceActions.spoon"

--- USBDeviceActions.devices (Table)
--- Variable
--- A table where the keys should correspond to `productName`s of USB devices and the values should be tables containing the keys `apps` and/or `fn`. (You can find the `productName` for a connected USB device using `hs.usb.attachedDevices()`).
---
--- The value of the `apps` key should contain a list of apps that will be launched/killed when the USB device is connected/disconnected. The value of the `fn` key should be a single parameter function that will be passed `true`/`false` when the USB device is connected/disconnected.
---
--- Example:
--- ```
--- {
---   ScanSnapiX500EE            = { apps = { "ScanSnap Manager Evernote Edition" } },
---   Planck                     = { fn = toggleKeyboardLayout },
---   ["Corne Keyboard (crkbd)"] = { fn = toggleKeyboardLayout }
--- }
--- ```
devices = {}

--- USBDeviceActions:init() -> Self
--- Method
--- Creates an `hs.usb.watcher` with a callback that will execute the specified actions for the USB devices in `USBDeviceActions.devices` when they are connected/disconnected, but doesn't start the watcher.
---
--- Returns:
---  * Self
function init(self)
  local callback = function(x) usbEventCallback(devices, x) end
  watcher = hs.usb.watcher.new(callback)
  return self
end

--- USBDeviceActions:start() -> Self
--- Method
--- Starts the `hs.usb.watcher` created by `USBDeviceActions:init()`.
---
--- Returns:
---  * Self
function start(self)
  watcher:start()
  return self
end

--- USBDeviceActions:stop() -> Self
--- Method
--- Stops the `hs.usb.watcher` created by `USBDeviceActions:init()`.
---
--- Returns:
---  * Self
function stop(self)
  watcher:stop()
  return self
end

-- Return the globals now in the environment, which is the module/spoon.
return _ENV

--- === EjectMenu ===
---
--- A much-needed eject menu for your Mac menu bar. Allows ejecting
--- individual or all non-internal disks. Ejection can also be
--- triggered on sleep, on lid close, or using a hotkey.
--- Using the Command key modifier causes the menu to open
--- the given volume in the Finder instead of ejecting it.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EjectMenu.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EjectMenu.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "EjectMenu"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>, Mark Juers <mpjuers@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Watcher for system sleep events
obj.caff_watcher = nil
-- Watcher for screen change events
obj.screen_watcher = nil
-- Watcher for keyboard events (to change the menubar icon)
obj.flags_watcher = nil
-- Menubar icon
obj.menubar = nil

--- EjectMenu.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('EjectMenu')

--- EjectMenu.never_eject
--- Variable
--- List containing volume paths that should never be ejected. Default value: empty list
obj.never_eject = { }

--- EjectMenu.notify
--- Variable
--- Boolean, whether to produce a notification about the volumes that get ejected. Default value: `false`
obj.notify = false

--- EjectMenu.eject_on_sleep
--- Variable
--- Boolean, whether to eject volumes before the system goes to sleep. Default value: true
obj.eject_on_sleep = true

--- EjectMenu.eject_on_lid_close
--- Variable
--- Boolean, whether to eject volumes when the laptop lid is closed with an external display connected.
---
--- Notes:
---  * There is no "lid close" event, so we detect when the internal display gets disabled.
---  * This method is somewhat unreliable (e.g. it also triggers when the internal display goes to sleep due to inactivity), so its default value is `false`
obj.eject_on_lid_close = false

--- EjectMenu.show_in_menubar
--- Variable
--- Boolean, whether to show a menubar button to eject all drives. Default value: true
obj.show_in_menubar = true

--- EjectMenu.other_eject_events
--- Variable
--- List of additional system events on which the volumes should be ejected.
---
--- Notes:
---  * The values must be [http://www.hammerspoon.org/docs/hs.caffeinate.watcher.html](`hs.caffeinate.watcher`) constant values. Default value: empty list
obj.other_eject_events = { }

--- EjectMenu:shouldEject(path, info)
--- Method
--- Determine if a volume should be ejected.
---
--- Parameters:
---  * path - the mount path of the volume.
---  * info - a table containing a data structure as returned by `hs.fs.volume.allVolumes()`.
---
--- Returns:
---  * A boolean indicating whether the volume should be ejected.
function obj:shouldEject(path, info)
  self.logger.df("Checking whether volume %s should be ejected", path)
  return not (hs.fnutils.contains(self.never_eject, path) or info["NSURLVolumeIsInternalKey"])
end

--- EjectMenu:volumesToEject()
--- Method
--- Return table of volumes to be ejected when "Eject All" is invoked.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table in the same format as returned by `hs.fs.volume.allVolumes()` but containing only those volumes for which `EjectMenu:shouldEject()` returns `true`.
---  * An integer indicating how many volumes are in the table.
function obj:volumesToEject()
  local volumes = hs.fs.volume.allVolumes()
  local ejectMenuDrives = {}
  local count = 0
  for path, v in pairs(volumes) do
    if self:shouldEject(path, v) then
      ejectMenuDrives[path] = v
      count = count + 1
    end
  end
  return ejectMenuDrives, count
end

-- Internal function to display a notification
function obj.showNotification(title, subtitle, msg, persistent)
  local withdraw_time = 5
  if persistent then
    withdraw_time = 0
  end
  hs.notify.new(
    {
      title = title,
      subTitle = subtitle,
      informativeText = msg,
      withdrawAfter = withdraw_time
  }):send()
end

--- EjectMenu:ejectVolumes()
--- Method
--- Eject all volumes
---
--- Parameters:
---  * persistent_notifs: a boolean indicating whether notifications (if shown) should be persistent.
function obj:ejectVolumes(persistent_notifs)
  local v, count = self:volumesToEject()
  self.logger.df("Ejecting volumes")
  local all_ejected = true
  for path,info in pairs(v) do
    local result,msg = hs.fs.volume.eject(path)
    if result then
      if self.notify then
        self.showNotification("EjectMenu", "Volume " .. path .. " ejected.", "", persistent_notifs)
      end
      self.logger.df("Volume %s was ejected.", path)
    else
      self.showNotification("EjectMenu", "Error ejecting " .. path, msg)
      self.logger.ef("Error ejecting volume %s: %s", path, msg)
      all_ejected = false
    end
  end
  if count > 0 and all_ejected then
    self.showNotification("EjectMenu", "All volumes unmounted.", "", persistent_notifs)
  end
  return self
end

-- EjectMenu:execMenuItem(mods, table)
-- Method
-- Defines and executes menu item based on which modifiers are held.
--
-- Parameters
--  * mods: A table containing which modifiers are held in {key = bool} format only if 'bool' is true. Other modifiers are omitted.
--  * table: The menu item being activated.
function obj:execMenuItem (mods, table)
  if (
    mods['cmd'] == true and
      mods['ctrl'] == false and
      mods['alt'] == false and
      mods['shift'] == false and
      mods['fn'] == false
  ) then
    hs.osascript.applescript(
      'tell application "Finder"'
        .. ' to open ("' .. table['path'] .. '" as POSIX file)'
    )
    hs.appfinder.appFromName("Finder"):activate()
  else
    self.logger.df("Will eject %s", table['path'])
    hs.fs.volume.eject(table['path'])
    self.showNotification("EjectMenu", "Volume " .. table['path'] .. " ejected.", "", false)
  end
end

-- EjectMenu:initEjectMenu(mods)
-- Method
-- Initializes eject menu when clicked.
--
-- Parameters
--  * mods: a table containing {mod = bool} for all modifiers, where bool can be be either 'true' or 'false' (unlike execMenuItem). If a modifier is in effect, the given volume is opened in the Finder rather than ejected.
--
-- Returns
--  * ejectMenuTable: a table containing entries and functions for ejectable drives.
function obj:initEjectMenu (mods)
  local ejectMenuDrives, count = self:volumesToEject()
  local ejectMenuTable = {
    {title = "Eject All",
     fn = function () self:ejectVolumes(false) end,
     disabled = (count == 0)
    },
    {title = '-'}
  }
  if count > 0 then
    for drive, v in pairs(ejectMenuDrives) do
      self.logger.d(drive .. " is ejectable.")
      table.insert(
        ejectMenuTable,
        {
          title = v['NSURLVolumeLocalizedNameKey'],
          path = drive,
          fn = function (mods, table) self:execMenuItem(mods, table) end
        }
      )
    end
  else
    self.logger.d("No external drives.")
  end
  return ejectMenuTable
end

--- EjectMenu:bindHotkeys(mapping, ejectAll)
--- Method
--- Binds hotkeys for EjectMenu
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---  * ejectAll - eject all volumes.
function obj:bindHotkeys(mapping)
  local spec = { ejectAll = hs.fnutils.partial(self.ejectVolumes, self) }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
end

-- EjectMenu:changeEjectMenuIcon(mods)
-- Method
-- Changes eject menu icon depending on which modifiers are held.
--
-- Parameters
--  * mods: A table containing for which the keys are the modifiers being held and the values are 'true'.
function obj:changeEjectMenuIcon (mods)
  if mods:containExactly({'cmd'}) then
    self.menubar:setTitle('⮑')
  elseif mods:containExactly({}) then
    self.menubar:setTitle('⏏')
  end
end

--- EjectMenu:start()
--- Method
--- Start the watchers for power events and screen changes, to trigger volume ejection.
---
--- Parameters:
---  * None
function obj:start()
  if self.eject_on_sleep then
    self.caff_watcher = hs.caffeinate.watcher.new(
      function (e)
        self.logger.df("Received hs.caffeinate.watcher event %d", e)
        if (e == hs.caffeinate.watcher.systemWillSleep) or hs.fnutils.contains(self.other_eject_events, e) then
          self.logger.df("  About to go to sleep")
          self:ejectVolumes(true)
        end
    end):start()
  end
  if self.eject_on_lid_close then
    self.screen_watcher = hs.screen.watcher.new(
      function ()
        self.logger.df("Received hs.screen.watcher event")
        local screens = hs.screen.allScreens()
        self.logger.df("  Screens: %s", hs.inspect(screens))
        if #screens > 0 and hs.fnutils.every(screens,
                                             function (s) return s:name() ~= "Color LCD" end) then
          self.logger.df("  'Color LCD' display is gone but other screens remain - detecting this as 'lid close'")
          self:ejectVolumes(true)
        end
      end
    ):start()
  end
  if self.show_in_menubar then
    self.menubar = hs.menubar.new():setTitle("⏏"):
    setMenu(function (mods) return self:initEjectMenu(mods) end)
    self.flags_watcher = hs.eventtap.new(
      {hs.eventtap.event.types.flagsChanged},
      function (event) self:changeEjectMenuIcon(event:getFlags()) end
    ):start()
  end
  return self
end

--- EjectMenu:stop()
--- Method
--- Stop the watchers
---
--- Parameters:
---  * None
function obj:stop()
  if self.caff_watcher then
    self.caff_watcher:stop()
    self.caff_watcher = nil
  end
  if self.screen_watcher then
    self.screen_watcher:stop()
    self.screen_watcher = nil
  end
  if self.menubar then
    self.menubar:delete()
    self.menubar = nil
  end
  if self.flags_watcher then
    self.flags_watcher:stop()
    self.flags_watcher = nil
  end
  return self
end

return obj

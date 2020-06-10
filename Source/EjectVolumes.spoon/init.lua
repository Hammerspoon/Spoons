--- === EjectVolumes ===
---
--- Eject all non-internal disks. Can be triggered on sleep, on lid close, using a menubar icon or a hotkey.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EjectVolumes.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EjectVolumes.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "EjectVolumes"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Watcher for system sleep events
obj.caff_watcher = nil
-- Watcher for screen change events
obj.screen_watcher = nil
-- Menubar icon
obj.menubar = nil

--- EjectVolumes.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('EjectVolumes')

--- EjectVolumes.never_eject
--- Variable
--- List containing volume paths that should never be ejected. Default value: empty list
obj.never_eject = { }

--- EjectVolumes.notify
--- Variable
--- Boolean, whether to produce a notification about the volumes that get ejected. Default value: `false`
obj.notify = false

--- EjectVolumes.eject_on_sleep
--- Variable
--- Boolean, whether to eject volumes before the system goes to sleep. Default value: true
obj.eject_on_sleep = true

--- EjectVolumes.eject_on_lid_close
--- Variable
--- Boolean, whether to eject volumes when the laptop lid is closed. Default value: true
obj.eject_on_lid_close = true

--- EjectVolumes.show_in_menubar
--- Variable
--- Boolen, whether to show a menubar button to eject all drives. Default value: true
obj.show_in_menubar = true

--- EjectVolumes.other_eject_events
--- Variable
--- List of additional system events on which the volumes should be ejected. The
--- values must be
--- [http://www.hammerspoon.org/docs/hs.caffeinate.watcher.html](`hs.caffeinate.watcher`)
--- constant values. Default value: empty list
obj.other_eject_events = { }

--- EjectVolumes:shouldEject(path, info)
--- Method
--- Determine if a volume should be ejected.
---
--- Parameters:
---  * path - the mount path of the volume.
---  * info - a table containing a data structure as returned by `hs.fs.volume.allVolumes()`.
--- Returns:
---  * A boolean indicating whether the volume should be ejected.
function obj:shouldEject(path, info)
  self.logger.df("Checking whether volume %s should be ejected", path)
  return not (hs.fnutils.contains(self.never_eject, path) or info["NSURLVolumeIsInternalKey"])
end

function obj.showNotification(title, subtitle, msg)
  hs.notify.new(
    {
      title = title,
      subTitle = subtitle,
      informativeText = msg,
      withdrawAfter = 0
  }):send()
end

--- EjectVolumes:ejectVolumes()
--- Method
--- Eject all volume
function obj:ejectVolumes()
  local v = hs.fs.volume.allVolumes()
  self.logger.df("Ejecting volumes")
  for path,info in pairs(v) do
    if self:shouldEject(path,info) then
      local result,msg = hs.fs.volume.eject(path)
      if result then
        if self.notify then
          self.showNotification("EjectVolumes", "Volume " .. path .. " ejected.", "")
        end
        self.logger.f("Volume %s was ejected.", path)
      else
        self.showNotification("EjectVolumes", "Error ejecting " .. path, msg)
        self.logger.ef("Error ejecting volume %s: %s", path, msg)
      end
    end
  end
  return self
end

--- EjectVolumes:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for EjectVolumes
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * eject_volumes - eject all volumes.
function obj:bindHotkeys(mapping)
  local spec = { eject_volumes = hs.fnutils.partial(self.ejectVolumes, self) }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
end

--- EjectVolumes:start()
--- Method
--- Start the watchers for power events and screen changes, to trigger volume ejection.
function obj:start()
  if self.eject_on_sleep then
    self.caff_watcher = hs.caffeinate.watcher.new(
      function (e)
        self.logger.df("Received hs.caffeinate.watcher event %d", e)
        if self.eject_on_sleep or hs.fnutils.contains(self.other_eject_events, e) then
          self.logger.df("  About to go to sleep")
          self:ejectVolumes()
        end
      end):start()
  end
  if self.eject_on_lid_close then
    self.screen_watcher = hs.screen.watcher.new(
      function ()
        self.logger.df("Received hs.screen.watcher event")
        if (hs.fnutils.every(hs.screen.allScreens(),
                             function (s) return s:name() ~= "Color LCD" end)) then
          self.logger.df("  'Color LCD' display is gone")
          self:ejectVolumes()
        end
      end
    ):start()
  end
  if self.show_in_menubar then
    self.menubar = hs.menubar.new():
      setIcon(hs.image.imageFromName("NSNavEjectButton.normal")):
      setClickCallback(hs.fnutils.partial(self.ejectVolumes, self))
  end
end

--- EjectVolumes:stop()
--- Method
--- Stop the watchers
function obj:stop()
  if self.caff_watcher then
    self.caff_watcher:stop()
    self.caff_watcher = nil
  end
  if self.screen_watcher then
    self.screen_watcher:stop()
    self.screen_watcher = nil
  end
  if obj.show_in_menubar then
    self.menubar:delete()
    self.menubar = nil
  end
end

return obj

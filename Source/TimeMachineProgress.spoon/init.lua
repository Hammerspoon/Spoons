--- === TimeMachineProgress ===
---
--- Show Time Machine backup progress in a menubar indicator.
---
--- If no backup is in progress, the indicator disappears. When a
--- backup is in preparation of in progress, the indicator is shown,
--- indicating current state/progress of the backup.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TimeMachineProgress.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TimeMachineProgress.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "TimeMachineProgress"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- TimeMachineProgress.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('TimeMachineProgress')

--- TimeMachineProgress.refresh_interval
--- Variable
--- Integer specifying how often the indicator should be refreshed. Defaults to 5 seconds.
obj.refresh_interval = 5

--- TimeMachineProgress.backupIcon
--- Variable
--- Image to use for the menubar icon.
---
--- Notes:
--   * Defaults to the default macOS Time Machine menubar icon stored in `/System/Library/CoreServices/Menu Extras/TimeMachine.menu/Contents/Resources/TMBackingUp.pdf`. If this fails, it defaults to the Time Machine application icon, obtained as `hs.image.imageFromAppBundle('com.apple.backup.launcher'):setSize({w=18,h=18})`.
obj.backupIcon = hs.image.imageFromPath("/System/Library/CoreServices/Menu Extras/TimeMachine.menu/Contents/Resources/TMBackingUp.pdf") or
                 hs.image.imageFromAppBundle('com.apple.backup.launcher'):setSize({w=18,h=18})

-- Internal variables
obj.menuBarItem = nil
obj.timer = nil
obj.menu = nil

-- Status emulation - for debugging - developer use only!

-- If this variable is not nil, its contents is used instead of the live output from `tmutil status` to determine the display. Useful for debugging.
obj.emulatedoutput = nil

-- Assign these sample values to obj.emulatedoutput to simulate different backup situations
obj._nobackup = [[{
    ClientID = "com.apple.backupd";
    Percent = 1;
    Running = 0;
}
]]

obj._preparingbackup = [[{
    BackupPhase = ThinningPreBackup;
    ClientID = "com.apple.backupd";
    DateOfStateChange = "2018-03-01 05:41:00 +0000";
    DestinationID = "B8371B75-9630-484E-BA38-816CE0A5AF43";
    DestinationMountPoint = "/Volumes/UM00104-external";
    Percent = "-1";
    Running = 1;
    Stopping = 0;
}]]

obj._runningbackup = [[{
    BackupPhase = Copying;
    ClientID = "com.apple.backupd";
    DateOfStateChange = "2018-02-28 09:48:14 +0000";
    DestinationID = "B8371B75-9630-484E-BA38-816CE0A5AF43";
    DestinationMountPoint = "/Volumes/UM00104-external";
    Percent = "0.4705918869508601";
    Progress =     {
        TimeRemaining = 37157;
        "_raw_totalBytes" = 57210248107;
        bytes = 29914087344;
        files = 616013;
        totalBytes = 62931272917;
        totalFiles = 796246;
    };
    Running = 1;
    Stopping = 0;
    "_raw_Percent" = "0.5228798743898445";
}]]

-- Internal function to return the current menu. The menu itself is updated by
-- TimeMachineProgress:refresh()
function obj._returnMenu()
  return obj.menu
end

--- TimeMachineProgress:refresh()
--- Method
--- Update the indicator and menu according to the current backup status.
---
--- Parameters:
---  * None
function obj:refresh()
  local out = nil
  if obj.emulatedoutput then
    out = obj.emulatedoutput
  else
    out = hs.execute("/usr/bin/tmutil status | /usr/bin/tail -n +2")
  end
  self.logger.df("tmutil status output: %s\n", out)
  -- Write output to a file and read it using hs.plist
  local outfile = hs.execute("/usr/bin/mktemp"):match( "^%s*(.-)%s*$" )
  local f = assert(io.open(outfile, "w")); f:write(out); f:close()
  data = hs.plist.read(outfile)
  os.remove(outfile)

  self.logger.df("Formatted data read by hs.plist: %s\n", hs.inspect(data))

  if data['Running'] ~= '1' then
    -- If no backup is running, delete the menubar
    self.logger.df("Backup not running, removing menubar item")
    if self.menuBarItem then self.menuBarItem:delete() end
    self.menuBarItem = nil
  else
    -- When a backup is underway things get fun
    self.logger.df("Backup is running")

    -- Initialize menubar item if needed
    if (not self.menuBarItem) then
      self.menuBarItem = hs.menubar.new()
      self.menuBarItem:setIcon(self.backupIcon, false)
      self.menuBarItem:setMenu(self._returnMenu)
    end

    -- Identify special states: preparing backup and stopping backup.
    local stopping = (data['Stopping'] == '1')
    local preparing = (not stopping) and (data['Percent'] == '-1' or data['Percent'] == '0')

    -- Depending on macOS version the 'Progress' data may be stored in a
    -- subitem, we promote it to the top level
    if (data['Progress']) then data = data['Progress'] end

    -- Determine menubar title, tooltip, and top menu entry depending on status
    local title
    local tooltip
    local topmenu
    if stopping then
      title = "(stop)"
      tooltip = "Stopping Backup…"
      topmenu = tooltip
    elseif preparing then
      title = "(prep)"
      tooltip = "Preparing Backup…"
      topmenu = tooltip
    else
      title = string.format("%.2f%%", tonumber(data['Percent'])*100)
      -- The macOS Time Machine menu item uses 1000-byte multipliers (instead of
      -- the more correct 1024) for its display, we use it as well so that it
      -- matches.
      GBfactor = 1000*1000*1000
      currentGB = tonumber(data['bytes'])/GBfactor
      totalGB = tonumber(data['totalBytes'])/GBfactor
      tooltip = string.format("%.2fGB of %.2fGB", currentGB, totalGB)
      topmenu = string.format("Backing up: %s", tooltip)
    end

    -- Set the menubar title and tooltip
    self.logger.df("Setting up menubar title to '%s'", title)
    self.menuBarItem:setTitle(title)
    self.menuBarItem:setTooltip(tooltip)

    -- Finally, we construct the menu based on the current status. It is stored
    -- in obj.menu and returned upon click by obj._returnMenu so that it's not
    -- updated while the user has the menu open.
    local __separator__ = { title = "-" }
    obj.menu = {
      -- Top entry shows the current status, disabled
      { title = topmenu, disabled = true },
      __separator__,
      -- "Skip This Backup" is disabled if the status is "Stopping" already
      { title = "Skip This Backup",
        disabled = stopping,
        fn = function()
          hs.task.new("/usr/bin/tmutil", nil, {"stopbackup"}):start()
        end
      },
      -- The rest are fixed, same as in the built-in TM menubar
      { title = "Enter Time Machine",
        fn = function()
          hs.application.launchOrFocus("Time Machine")
        end
      },
      __separator__,
      { title = "Open Time Machine Preferences…",
        fn = function()
          hs.task.new("/usr/bin/open", nil,
                      {"/System/Library/PreferencePanes/TimeMachine.prefPane"}):start()
        end
      }
    }
  end
  return self
end

--- TimeMachineProgress:start()
--- Method
--- Starts the indicator
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TimeMachineProgress object
function obj:start()
  self:stop()

  self.timer = hs.timer.doEvery(self.refresh_interval,
                                function() self:refresh() end)

  return self
end

--- TimeMachineProgress:stop()
--- Method
--- Stops the indicator
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TimeMachineProgress object
function obj:stop()
  if self.menuBarItem then
    self.menuBarItem:delete()
  end
  if self.timer then
    self.timer:stop()
  end

  self.menuBarItem = nil
  self.timer = nil

  return self
end

return obj

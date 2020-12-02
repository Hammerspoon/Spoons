--- === TurboBoost ===
---
--- A spoon to load/unload the Turbo Boost Disable kernel extension
--- from https://github.com/rugarciap/Turbo-Boost-Switcher.
---
--- Note: this spoon by default uses sudo to load/unload the kernel
--- extension, so for it to work from Hammerspoon, you need to
--- configure sudo to be able to load/unload the extension without a
--- password, or configure the load_kext_cmd and unload_kext_cmd
--- variables to use some other mechanism that prompts you for the
--- credentials.
---
--- For example, the following configuration (stored in
--- /etc/sudoers.d/turboboost) can be used to allow loading and
--- unloading the module without a password:
--- ```
--- Cmnd_Alias    TURBO_OPS = /sbin/kextunload /Applications/Turbo Boost Switcher.app/Contents/Resources/DisableTurboBoost.64bits.kext, /usr/bin/kextutil /Applications/Turbo Boost Switcher.app/Contents/Resources/DisableTurboBoost.64bits.kext
---
--- %admin ALL=(ALL) NOPASSWD: TURBO_OPS
--- ```
---
--- If you use this, please support the author of Turbo Boost Disabler
--- by purchasing the Pro version of the app!
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TurboBoost.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TurboBoost.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "TurboBoost"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- TurboBoost.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('TurboBoost')

obj.menuBarItem = nil
obj.wakeupWatcher = nil

--- TurboBoost.disable_on_start
--- Variable
--- Boolean to indicate whether Turbo Boost should be disabled when
--- the Spoon starts. Default value: `false`.
obj.disable_on_start = false

--- TurboBoost.reenable_on_stop
--- Variable
--- Boolean to indicate whether Turbo Boost should be reenabled when
--- the Spoon stops. Default value: `true`.
obj.reenable_on_stop = true

--- TurboBoost.kext_paths
--- Variable
--- List with paths to check for the DisableTurboBoost.kext file. The first one
--- to be found is used by default unless DisableTurboBoost.kext_path is set
--- explicitly.
---
--- Default value: `{"/Applications/Turbo Boost Switcher.app/Contents/Resources/DisableTurboBoost.64bits.kext", "/Applications/tbswitcher_resources/DisableTurboBoost.64bits.kext"}`
obj.kext_paths_to_try = {"/Applications/Turbo Boost Switcher.app/Contents/Resources/DisableTurboBoost.64bits.kext",
                         "/Applications/tbswitcher_resources/DisableTurboBoost.64bits.kext"}

--- TurboBoost.kext_path
--- Variable
--- Where the DisableTurboBoost.kext file is located.
---
---Default value: whichever one of `TurboBoost.kext_paths` exists.
obj.kext_path = nil

-- Load-time initialization of kext_path, so that it can be overriden by an
-- explicit assignment later.
for i,path in ipairs(obj.kext_paths_to_try) do
  if hs.fs.attributes(path) then
    obj.kext_path = path
  end
end

--- TurboBoost.load_kext_cmd
--- Variable
--- Command to execute to load the DisableTurboBoost kernel
--- extension. This command must execute with root privileges and
--- either query the user for the credentials, or be configured
--- (e.g. with sudo) to run without prompting. The string "%s" in this
--- variable gets replaced with the value of
--- TurboBoost.kext_path. Default value: `"/usr/bin/sudo /usr/bin/kextutil '%s'"`
obj.load_kext_cmd = "/usr/bin/sudo /usr/bin/kextutil '%s'"

--- TurboBoost.unload_kext_cmd
--- Variable
--- Command to execute to unload the DisableTurboBoost kernel
--- extension. This command must execute with root privileges and
--- either query the user for the credentials, or be configured
--- (e.g. with sudo) to run without prompting. The string "%s" in this
--- variable gets replaced with the value of
--- TurboBoost.kext_path. Default value: `"/usr/bin/sudo /sbin/kextunload '%s'"`
obj.unload_kext_cmd = "/usr/bin/sudo /sbin/kextunload '%s'"

--- TurboBoost.check_kext_cmd
--- Variable
--- Command to execute to check whether the DisableTurboBoost kernel
--- extension is loaded. Default value: `"/usr/sbin/kextstat | grep com.rugarciap.DisableTurboBoost"`
obj.check_kext_cmd = "/usr/sbin/kextstat | grep com.rugarciap.DisableTurboBoost"

--- TurboBoost.notify
--- Variable
--- Boolean indicating whether notifications should be generated when
--- Turbo Boost is enabled/disabled. Default value: `true`
obj.notify = true

--- TurboBoost.enabled_icon_path
--- Variable
--- Where to find the icon to use for the "Enabled" icon. Default value
--- uses the icon from the Turbo Boost application:
--- `"/Applications/Turbo Boost Switcher.app/Contents/Resources/icon.tiff"`
obj.enabled_icon_path = "/Applications/Turbo Boost Switcher.app/Contents/Resources/icon.tiff"

--- TurboBoost.disabled_icon_path
--- Variable
--- Where to find the icon to use for the "Disabled" icon. Default value
--- uses the icon from the Turbo Boost application:
--- `"/Applications/Turbo Boost Switcher.app/Contents/Resources/icon_off.tiff"`
obj.disabled_icon_path = "/Applications/Turbo Boost Switcher.app/Contents/Resources/icon_off.tiff"

--- TurboBoost:setState(state)
--- Method
--- Sets whether Turbo Boost should be disabled (kernel extension
--- loaded) or enabled (normal state, kernel extension not loaded).
---
--- Parameters:
---  * state - A boolean, false if Turbo Boost should be disabled
---    (load kernel extension), true if it should be enabled (unload
---    kernel extension if loaded).
---  * notify - Optional boolean indicating whether a notification
---    should be produced. If not given, the value of
---    TurboBoost.notify is used.
---
--- Returns:
---  * Boolean indicating new state
function obj:setState(state, notify)
  local curstatus = self:status()
  if curstatus ~= state then
    local cmd = string.format(obj.load_kext_cmd, obj.kext_path)
    if state then
      cmd = string.format(obj.unload_kext_cmd, obj.kext_path)
    end
    self.logger.df("Will execute command '%s'", cmd)
    if notify == nil then
      notify = obj.notify
    end
    out,st,ty,rc = hs.execute(cmd)
    if not st then
      self.logger.ef("Error executing '%s'. Output: %s", cmd, out)
    else
      self:setDisplay(state)
      if notify then
        hs.notify.new({
            title = "Turbo Boost " .. (state and "enabled" or "disabled"),
            subTitle = "",
            informativeText = "",
            setIdImage = hs.image.imageFromPath(self.iconPathForState(state))
        }):send()
      end
    end
  end
  return self:status()
end

--- TurboBoost:status()
--- Method
--- Check whether Turbo Boost is enabled
---
--- Returns:
---  * true if TurboBoost is enabled (kernel ext not loaded), false otherwise.
function obj:status()
  local cmd = obj.check_kext_cmd
  out,st,ty,rc = hs.execute(cmd)
  return (not st)
end

--- TurboBoost:toggle()
--- Method
--- Toggle TurboBoost status
---
--- Returns:
---  * New TurboBoost status, after the toggle
function obj:toggle()
  self:setState(not self:status())
  return self:status()
end

--- TurboBoost:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for TurboBoost
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * hello - Say Hello
function obj:bindHotkeys(mapping)
  local spec = { toggle = hs.fnutils.partial(self.toggle, self) }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
end

--- TurboBoost:start()
--- Method
--- Starts TurboBoost
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TurboBoost object
function obj:start()
    if self.menuBarItem or self.wakeupWatcher then self:stop() end
    self.menuBarItem = hs.menubar.new()
    self.menuBarItem:setClickCallback(self.clicked)
    self:setDisplay(self:status())
    self.wakeupWatcher = hs.caffeinate.watcher.new(self.wokeUp):start()
    if self.disable_on_start then
      self:setState(false)
    end
    return self
end

--- TurboBoost:stop()
--- Method
--- Stops TurboBoost
---
--- Parameters:
---  * None
---
--- Returns:
---  * The TurboBoost object
function obj:stop()
  if self.reenable_on_stop then
    self:setState(true)
  end
  if self.menuBarItem then self.menuBarItem:delete() end
  self.menuBarItem = nil
  if self.wakeupWatcher then self.wakeupWatcher:stop() end
  self.wakeupWatcher = nil

  return self
end

function obj.iconPathForState(state)
  if state then
    return obj.enabled_icon_path
  else
    return obj.disabled_icon_path
  end
end

function obj:setDisplay(state)
  obj.menuBarItem:setIcon(obj.iconPathForState(state))
end

function obj.clicked()
  hs.timer.doAfter(0, function() obj:setDisplay(obj:toggle()) end)
end

-- This function is called when the machine wakes up and, if the
-- module was loaded, it unloads/reloads it to disable Turbo Boost
-- again
function obj.wokeUp(event)
  obj.logger.df("In obj.wokeUp, event = %d\n", event)
  if event == hs.caffeinate.watcher.systemDidWake then
    obj.logger.d("  Received systemDidWake event!\n")
    hs.timer.doAfter(0,
                     function()
                       if not obj:status() then
                         obj.logger.d("  Toggling TurboBoost on and back off\n")
                         hs.timer.doAfter(0.5, function() obj:setState(true) end)
                         hs.timer.doAfter(2.0, function() obj:setState(false) end)
                       end
                     end)
  end
end

return obj

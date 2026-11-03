--- === KeepMacAwake ===
---
--- Start, check and stop Keep Mac Awake sessions from Hammerspoon.
---
--- Keep Mac Awake (https://keepmacawake.com) is a menu bar app that keeps a MacBook with Apple silicon awake with the lid closed during a session, on macOS 26 or later. It has a free trial. This Spoon runs only its `keepmacawake` command (`start`, `status`, `stop`) and shows the command's answer in an alert; it needs the app installed.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/KeepMacAwake.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/KeepMacAwake.spoon.zip)
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "KeepMacAwake"
obj.version = "1.0"
obj.author = "Keep Mac Awake"
obj.homepage = "https://keepmacawake.com"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- KeepMacAwake.cliPath
--- Variable
--- The path of the `keepmacawake` command. Default: `/usr/local/bin/keepmacawake`, where the app's installer puts it.
obj.cliPath = "/usr/local/bin/keepmacawake"

--- KeepMacAwake.alertSeconds
--- Variable
--- How many seconds the alert with the command's answer stays on screen. Default: 4.
obj.alertSeconds = 4

local NOT_INSTALLED = "Keep Mac Awake is not installed. Get it at keepmacawake.com (free trial)."

-- Runs the command with the given arguments, then shows its answer and calls
-- callback(exitCode, message) when given.
function obj:_run(arguments, callback)
    if not hs.fs.attributes(self.cliPath) then
        hs.alert.show(NOT_INSTALLED, self.alertSeconds)
        if callback then callback(nil, NOT_INSTALLED) end
        return nil
    end
    local args = {}
    for _, argument in ipairs(arguments) do table.insert(args, argument) end
    table.insert(args, "--no-input")
    local task = hs.task.new(self.cliPath, function(exitCode, stdOut, stdErr)
        local message = ((stdOut or "") .. (stdErr or "")):gsub("%s+$", "")
        if message == "" then
            message = exitCode == 0 and "Done." or ("Keep Mac Awake could not do it (exit code " .. tostring(exitCode) .. ").")
        end
        hs.alert.show(message, self.alertSeconds)
        if callback then callback(exitCode, message) end
    end, args)
    task:start()
    return task
end

--- KeepMacAwake:start([hours], [callback])
--- Method
--- Starts a Keep Mac Awake session
---
--- Parameters:
---  * hours - An optional whole number of hours from 1 to 168, or the string "unlimited" for a session without a time limit. Default: 8
---  * callback - An optional function called with the command's exit code and its message
---
--- Returns:
---  * The KeepMacAwake object
---
--- Notes:
---  * A timed session ends on its own. The command refuses with a message, shown in the alert, when a session already runs, when AC power is needed or when the trial limits the session's length
function obj:start(hours, callback)
    hours = hours or 8
    if hours == "unlimited" then
        self:_run({ "start", "--unlimited" }, callback)
    elseif type(hours) == "number" and hours == math.floor(hours) and hours >= 1 and hours <= 168 then
        self:_run({ "start", "--hours", tostring(math.floor(hours)) }, callback)
    else
        hs.alert.show("Pick 1 to 168 hours.", self.alertSeconds)
        if callback then callback(nil, "Pick 1 to 168 hours.") end
    end
    return self
end

--- KeepMacAwake:stop([callback])
--- Method
--- Stops the running Keep Mac Awake session, so the Mac sleeps as usual again
---
--- Parameters:
---  * callback - An optional function called with the command's exit code and its message
---
--- Returns:
---  * The KeepMacAwake object
function obj:stop(callback)
    self:_run({ "stop" }, callback)
    return self
end

--- KeepMacAwake:status([callback])
--- Method
--- Shows whether a Keep Mac Awake session runs and its time left
---
--- Parameters:
---  * callback - An optional function called with the command's exit code and its message
---
--- Returns:
---  * The KeepMacAwake object
function obj:status(callback)
    self:_run({ "status" }, callback)
    return self
end

--- KeepMacAwake:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for KeepMacAwake
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for any of the following items:
---   * start - Start a session of 8 hours
---   * startUnlimited - Start a session without a time limit
---   * stop - Stop the session
---   * status - Show the status
---
--- Returns:
---  * The KeepMacAwake object
function obj:bindHotkeys(mapping)
    local actions = {
        start = function() self:start(8) end,
        startUnlimited = function() self:start("unlimited") end,
        stop = function() self:stop() end,
        status = function() self:status() end,
    }
    hs.spoons.bindHotkeysToSpec(actions, mapping)
    return self
end

return obj

--- === Tunnelblick ===
---
--- connect to a Tunnelblick OpenVPN connection using a shortcut
--- Uses applescript to interact with Tunnelblick's window
---
--- written by Tyler Thrailkill <tyler.b.thrailkill@gmail.com>
---
--- https://github.com/snowe2010

local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'Tunnelblick'
obj.version = '1.0'
obj.author = 'Tyler Thrailkill <tyler.b.thrailkill@gmail.com>'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

--- Tunnelblick.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Tunnelblick')

--- Tunnelblick.password_fn
--- Variable
--- Function returning the password to login to the vpn connection with
obj.password_fn = nil

--- Tunnelblick.username
--- Variable
--- String username to log in with
obj.username = nil

--- Tunnelblick.connection_name
--- Variable
--- String connection name
obj.connection_name = nil

--- Tunnelblick:connect()
--- Method
--- Performs the connection operation using a username, password, and connection_name
---
--- Parameters:
---  * None
function obj:connect()
    assert(self.username, "username must be set!")
    assert(self.password_fn, "password_fn must be set!")
    assert(self.connection_name, "connection_name must be set!")

    code, output, descriptor =
        hs.osascript.applescript(
        string.format(
            [[
        tell application "Tunnelblick"
            get configurations
            connect "%s"
        end tell

        tell application "System Events"
        tell process "Tunnelblick"
            set frontmost to true
            tell window 1
                set value of text field 1 to "%s"
                set value of text field 2 to "%s"
                click button "OK"
            end tell
        end tell
        end tell
        ]],
            obj.connection_name,
            obj.username,
            obj.password_fn()
        )
    )
    obj.logger.df('Tunnelblick Applescript Output: Code: %s  Output: %s Descriptor: %s', code, output, descriptor)
end

--- Tunnelblick:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for Tunnelblick
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * login - login to tunnelblick shortcut
function obj:bindHotkeys(keys)
    assert(keys['login'], "Hotkey variable is 'login'")

    hs.hotkey.bindSpec(
        keys['login'],
        'Login to Tunnelblick',
        function()
            self:connect()
        end
    )
end

return obj

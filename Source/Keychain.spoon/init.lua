--- === Keychain ===
---
--- Load items from Keychain. Provides no hotkeys and maintains no state
---
--- Tyler Thrailkill <tyler.b.thrailkill@gmail.com>
---
--- https://github.com/snowe2010

local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'Keychain'
obj.version = '1.0'
obj.author = 'Tyler Thrailkill <tyler.b.thrailkill@gmail.com>'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

--- Keychain.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Keychain')

--- Keychain:login_keychain(name)
--- Method
--- Retrieve an item from the Login Keychain
---
--- Parameters:
---  * name - The name of the item in the Login Keychain you want to retrieve
function obj:login_keychain(name)
    -- 'name' should be saved in the login keychain
    local cmd="/usr/bin/security 2>&1 >/dev/null find-generic-password -gl " .. name .. " | sed -En '/^password: / s,^password: \"(.*)\"$,\\1,p'"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return (result:gsub("^%s*(.-)%s*$", "%1"))
end

return obj

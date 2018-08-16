--- === Token ===
---
--- generate google authenticator token value keystrokes
--- Retrieve a google authenticator token seed from keychain and use this to calculate the current value
--- Simulate keystrokes for this token value
---
--- written by Teun Vink <github@teun.tv>, converted to spoon by Tyler Thrailkill <snowe>
---
--- https://github.com/teunvink/hammerspoon

local obj={}
obj.__index = obj

-- Metadata
obj.name = "Token"
obj.version = "2.0"
obj.author = "Tyler Thrailkill <tyler.b.thrailkill@gmail.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- Token.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Token')

--- Token.secret_key
--- Variable
--- String indicating the Keychain name of the Shared Key used in the OTP HMAC-SHA1 generation
obj.secret_key = nil

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

local gauth = dofile(obj.spoonPath.."/gauth.lua")

-- code is based on:
--   https://github.com/imzyxwvu/lua-gauth/blob/master/gauth.lua (with small modifications)
--   https://github.com/kikito/sha.lua

-- read a password from a keychain
local function item_from_keychain(name)
    -- 'name' should be saved in the login keychain
    local cmd="/usr/bin/security 2>&1 >/dev/null find-generic-password -gl " .. name .. " | sed -En '/^password: / s,^password: \"(.*)\"$,\\1,p'"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return (result:gsub("^%s*(.-)%s*$", "%1"))
end

--- Token:token_keystroke()
--- Method
--- read a token secret key from keychain, generate a code and make keystrokes for it
function obj:token_keystroke()
    local token = self.get_token()
    -- generate keystrokes for the result
    hs.eventtap.keyStrokes(token)
end

--- Token:get_token()
--- Method
--- Retrieves the token using an HOTP/TOTP Secret Key stored in the keychain
function obj:get_token()
    local secret_key = item_from_keychain(obj.secret_key)
    local hash = gauth.GenCode(secret_key, math.floor(os.time() / 30))
    return ("%06d"):format(hash)
end

--- Token:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for Token
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * generate - generate and type token
function obj:bindHotkeys(keys)
    hs.hotkey.bindSpec(keys["generate"], function()
        self.token_keystroke()
    end)
end

return obj
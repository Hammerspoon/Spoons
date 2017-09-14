--- === PasswordGenerator ===
---
--- Generate a password and copy to the clipboard.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/PasswordGenerator.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/PasswordGenerator.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "PasswordGenerator"
obj.version = "1.0"
obj.author = "Jon Lorusso <jonlorusso@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local getSetting = function(label, default) return hs.settings.get(obj.name.."."..label) or default end

math.randomseed(os.time())

local pasteboard = require("hs.pasteboard") -- http://www.hammerspoon.org/docs/hs.pasteboard.html
local hashfn   = require("hs.hash").MD5

--- PasswordGenerator.password_generator_function
--- Variable
--- Function used to generate passwords
obj.password_generator_function = function() return hashfn(math.random()) end

--- PasswordGenerator.password_length
--- Variable
--- Length of generated passwords
obj.password_length = getSetting('password_length', 20)

--- PasswordGenerator:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for PasswordGenerator
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * copy - Generate password and copy to clipboard
---   * paste - Generate password and paste
function obj:bindHotkeys(mapping)
   local def = {
     copy = hs.fnutils.partial(self.copyPassword, self),
     paste = hs.fnutils.partial(self.pastePassword, self),
   }
   hs.spoons.bindHotkeysToSpec(def, mapping)
end

--- PasswordGenerator:copyPassword()
--- Method
--- Generates a password and copies to clipboard
---
--- Parameters:
---  * None
---
---  Returns:
---   * The generated password
function obj:copyPassword()
   password = self.password_generator_function()
   password = string.sub(password, 1, self.password_length)
   pasteboard.setContents(password)
   return password
end

--- PasswordGenerator:pastePassword()
--- Method
--- Generates a password and types it
---
--- Parameters:
---  * None
---
---  Returns:
---   * The generated password
function obj:pastePassword()
   password = self.password_generator_function()
   password = string.sub(password, 1, self.password_length)
   hs.eventtap.keyStrokes(password)
   return password
end

return obj


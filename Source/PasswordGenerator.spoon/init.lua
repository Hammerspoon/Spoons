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

local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end
obj.spoonPath = script_path()

local getSetting = function(label, default) return hs.settings.get(obj.name.."."..label) or default end

math.randomseed(os.time())

local pasteboard = require("hs.pasteboard") -- http://www.hammerspoon.org/docs/hs.pasteboard.html
local hashfn   = require("hs.hash").MD5

function default_generator(obj)
  password = hashfn(math.random())
  password = string.sub(password, 1, obj.password_length)
  return password
end

local xkcdwords = {}
function xkcd_generator(obj)

  local function leet(text)
    chars = {
      a = "4",
      e = "3",
      l = "1",
      o = "0",
      s = "5",
      i = "|"
    }

    result = ""
    for c in text:gmatch"." do
      n = chars[c]
      if n == nil then
        n = c
      end
      result = result .. n
    end

    return result
  end

  local wordcount=obj.word_count
  local leetpos = obj.word_leet
  local chars = obj.word_separators
  local separators = {}
  chars:gsub(".",function(c) table.insert(separators,c) end)
  local separator = separators[math.random(#separators)]

  if next(xkcdwords) == nil then
    local file = io.open(script_path() .. "/xkcdwords.txt", "r");
    for line in file:lines() do
      table.insert (xkcdwords, line);
    end
  end

  pwd = ""
  for i=1,wordcount do
    word = xkcdwords[ math.random(#xkcdwords) ]
    if i==leetpos then
      word = leet(word)
    end
    pwd = pwd .. word
    if i<wordcount then
      pwd = pwd .. separator 
    end
  end

  return pwd
end

local styles = {
  default = default_generator,
  xkcd = xkcd_generator
}



--- PasswordGenerator.password_style
--- Variable
--- Style for the generated password.
--  Possible values:
--      default = basic random generated string
--      xkcd    = password in style of https://xkcd.com/936/
obj.password_style = getSetting('password_style', "default")

--- PasswordGenerator.password_generator_function
--- Variable
--- Explicit function used to generate passwords, if nil style is used instead.
obj.password_generator_function = nil

--- PasswordGenerator.password_length
--- Variable
--- Length of generated passwords. Is ignored by style xkcd.
obj.password_length = getSetting('password_length', 20)

--- PasswordGenerator.word_count
--- Variable
--- Number of words in generated passwords. Used by xkcd.
obj.word_count = getSetting('word_count', 3)

--- PasswordGenerator.word_leet
--- Variable
--- Which word number will have its word `733t` transformed.
--- Useful to ensure the word will at least have a one numeric value.
--- Defaults to 0
obj.word_leet = getSetting('word_leet', 0)

--- PasswordGenerator.word_separators
--- Variable
--- String of separators to use between words.
--- If multiple characters one will be chosen by random.
--- Used by xkcd. Default is " _-,$"
obj.word_separators = getSetting('word_separators', " _-,$")

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


function obj:getPasswordGenerator()
  if password_generator_function then
    print("returning the function")
    return password_generator_function
  else
    print("using the style " .. obj.password_style)
    pgf = styles[obj.password_style]
    return pgf
  end
  
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
   password = self:getPasswordGenerator()(self)
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
  print(self:getPasswordGenerator())
   password = self:getPasswordGenerator()(self)
   hs.eventtap.keyStrokes(password)
   return password
end

return obj


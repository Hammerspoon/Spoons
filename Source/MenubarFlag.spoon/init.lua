--- === MenubarFlag ===
---
--- Color the menubar according to the current keyboard layout
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MenubarFlag.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MenubarFlag.spoon.zip)
---
--- Functionality inspired by [ShowyEdge](https://pqrs.org/osx/ShowyEdge/index.html.en)

local obj={}
obj.__index = obj

local scr = require "hs.screen"
local draw = require "hs.drawing"
local geom = require "hs.geometry"
local keyc = require "hs.keycodes"
local col = draw.color.x11
local logger = hs.logger.new('MenubarFlag')

-- Metadata
obj.name = "MenubarFlag"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- MenubarFlag.allScreens
--- Variable
--- Display on all monitors or just the current one?
obj.allScreens = true

--- MenubarFlag.indicatorHeight
--- Variable
--- Specify 0.0-1.0 to specify a percentage of the height of the menu bar, larger values indicate a fixed height in pixels
obj.indicatorHeight = 1.0

--- MenubarFlag.indicatorAlpha
--- Variable
--- Indicator transparency (1.0 - fully opaque)
obj.indicatorAlpha = 0.3

--- MenubarFlag.indicatorInAllSpaces
--- Variable
--- Show the indicator in all spaces? (this includes full-screen mode)
obj.indicatorInAllSpaces = true

--- MenubarFlag.colors
--- Variable
--- Configuration of indicator colors
---
--- Each indicator is made of an arbitrary number of segments,
--- distributed evenly across the width of the screen. The table below
--- indicates the colors to use for a given keyboard layout. The index
--- is the name of the layout as it appears in the input source menu.
--- If a layout is not found, then the indicators are removed when that
--- layout is active.
---
--- Inidicator specs can be static flag-like:
--- ```
---   Spanish = {col.green, col.white, col.red},
---   German = {col.black, col.red, col.yellow},
--- ```
--- or complex, programmatically-generated:
--- ```
--- ["U.S."] = (
---    function() res={} 
---       for i = 0,10,1 do
---          table.insert(res, col.blue)
---          table.insert(res, col.white)
---          table.insert(res, col.red)
---       end
---       return res
---    end)()
--- ```
--- or solid colors:
--- ```
---   Spanish = {col.red},
---   German = {col.yellow},
--- ```
obj.colors = {
   Spanish = {col.green, col.white, col.red},
   German = {col.black, col.red, col.yellow},
}

----------------------------------------------------------------------

local prevlayout = nil
local ind = nil

function initIndicators()
   if ind ~= nil then
      delIndicators()
   end
   ind = {}
end

function delIndicators()
   if ind ~= nil then
      for i,v in ipairs(ind) do
         if v ~= nil then
            v:delete()
         end
      end
      ind = nil
   end
end

--- MenubarFlag:getInputSource()
--- Method
--- Get current keyboard layout using the `defaults` command

--- MenubarFlag:somePublicMethod(param)
--- Method
--- Documentation for a public API method and its parameters
---
--- Parameters:
---  * param - Description of the parameter
function obj:somePublicMethod(param)
   hs.alert.show(string.format("somePublicMethod called! param=%s", param))
   return self
end

--- MenubarFlag:sayHello()
--- Method
--- Greet the user
function obj:sayHello()
   hs.alert.show("Hello!")
   return self
end

--- BrewInfo:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for MenubarFlag
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * hello - Say Hello
function obj:bindHotkeys(mapping)
   if mapping["hello"] then
      if (self.key_hello) then
         self.key_hello:delete()
      end
      self.key_hello = hs.hotkey.bindSpec(mapping["hello"], function() self:sayHello() end)
   end
end

return obj

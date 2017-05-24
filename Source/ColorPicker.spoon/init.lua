--- === ColorPicker ===
---
--- Show a color sample/picker
---
--- Clicking on any color will copy its name to the clipboard, cmd-click will copy its RGB code.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ColorPicker.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ColorPicker.spoon.zip)

local obj={}
obj.__index = obj

local draw = require('hs.drawing')

-- Metadata
obj.name = "ColorPicker"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- ColorPicker.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('ColorPicker')

--- ColorPicker.show_in_menubar
--- Variable
--- If `true`, show an icon in the menubar to trigger the color picker
obj.show_in_menubar = true

--- ColorPicker.menubar_title
--- Variable
--- Title to show in the menubar if `show_in_menubar` is true. Defaults to `"\u{1F308}"`, which is the [Rainbow Emoji](http://emojipedia.org/rainbow/)
obj.menubar_title = "\u{1F308}"

-- This is where the drawing objects are stored. After first use, the
-- created objects are cached (only shown/hidden as needed) so that
-- they are shown much faster in future uses.
-- obj.toggleColorSamples() can handle multiple color tables at once,
-- so these global caches are tables.
local swatches = {}

-- Are the indicators displayed at the moment?
local indicators_shown = false

-- Storage for the temporary keybinding for ESC to dismiss the colorpicker
local esckey = nil

-- Return the sorted keys of a table
function sortedkeys(tab)
   local keys={}
   -- Create sorted list of keys
   for k,v in pairs(tab) do table.insert(keys, k) end
   table.sort(keys)
   return keys
end

-- Algorithm to choose whether white/black as the most contrasting to a given
-- color, from http://gamedev.stackexchange.com/a/38561/73496
function contrastingColor(color)
   local black = { red=0.000,green=0.000,blue=0.000,alpha=1 }
   local white = { red=1.000,green=1.000,blue=1.000,alpha=1 }
   local c=draw.color.asRGB(color)
   if type(c) == "table" then
      local L = 0.2126*(c.red*c.red) + 0.7152*(c.green*c.green) + 0.0722*(c.blue*c.blue)
      if L <= 0.5 then
         return white
      end
   end
   return black
end

-- Get the frame for a single swatch
function getSwatchFrame(frame, hsize, vsize, column, row)
   return hs.geometry.rect(frame.x+(column*hsize), frame.y+(row*vsize), hsize, vsize)
end

-- Copy the name/code of the color to the clipboard, and remove the colors
-- from the screen.
function copyAndRemove(name, hex, tablename)
   local mods = hs.eventtap.checkKeyboardModifiers()
   hs.pasteboard.setContents(mods.cmd and hex or name)
   obj.toggleColorSamples(tablename)
end

-- Draw a single square on the screen
function drawSwatch(tablename, swatchFrame, colorname, col)
   local swatch = draw.rectangle(swatchFrame)
   swatch:setFill(true)
      :setFillColor(col)
      :setStroke(false)
      :setLevel(draw.windowLevels.overlay)
      :show()
   table.insert(swatches[tablename], swatch)
   if colorname ~= "" then
      color=draw.color.asRGB(col)
      local hex = "#" .. string.format("%02x%02x%02x", math.floor(255*color.red), math.floor(255*color.green), math.floor(255*color.blue))
      local str = hs.styledtext.new(string.format("%s\n%s", colorname, hex),
                                    { paragraphStyle = {alignment = "center"}, font={size=16.0}, color=contrastingColor(col) } )
      local text = hs.drawing.text(swatchFrame, str)
         :setLevel(draw.windowLevels.overlay+1)
         :setClickCallback(nil, hs.fnutils.partial(copyAndRemove, colorname, hex, tablename))
         :show()
      table.insert(swatches[tablename],text)
   end
end

--- ColorPicker.toggleColorSamples(tablename)
--- Method
--- Toggle display on the screen of a grid with all the colors in the given colortable
---
--- Parameters:
---  * tablename - name of the colortable to display
function obj.toggleColorSamples(tablename)
   local colortable = hs.drawing.color.lists()[tablename]
   if not colortable then
      obj.logger.ef("Invalid color table '%s'", tablename)
      return
   end
   local screen = hs.screen.mainScreen()
   local frame = screen:frame()
   
   if indicators_shown then
      if esckey then esckey:disable() end
      esckey=nil
   else
      esckey = hs.hotkey.bindSpec({ {}, "escape" }, hs.fnutils.partial(obj.toggleColorSamples, tablename))
   end
   
   if swatches[tablename] ~= nil then
      -- If the objects exist already, just show/hide them as needed
      for i,obj in ipairs(swatches[tablename]) do
         if indicators_shown then
            obj:hide()
         else
            obj:show()
         end
      end
      indicators_shown = not indicators_shown
   else
      swatches[tablename] = {}
      -- Create sorted list of colors
      keys = sortedkeys(colortable)

      -- Scale number of rows/columns according to the screen's aspect ratio
      local rows = math.floor(math.sqrt(#keys)*(frame.w/frame.h))
      local columns = math.ceil(math.sqrt(#keys)/(frame.w/frame.h))
      local hsize = math.floor(frame.w / columns)
      local vsize = math.floor(frame.h / rows)

      for i = 1,(rows*columns),1 do   -- fill the entire square
         local colorname = keys[i]
         local column = math.floor((i-1)/rows)
         local row = i-1-(column*rows)
         local swatchFrame = getSwatchFrame(frame,hsize,vsize,column,row)
         if colorname ~= nil then     -- with the corresponding color swatch
            local color = colortable[colorname]
            drawSwatch(tablename,swatchFrame,colorname,color)
         else  -- or with a gray swatch to fill up the rectangle
            local gray = { red=0.500,green=0.500,blue=0.500,alpha=1 }
            drawSwatch(tablename,swatchFrame,"",gray)
         end
      end
      indicators_shown = true
   end
end

function choosetable()
   local tab={}
   local lists=draw.color.lists()
   local keys=sortedkeys(lists)
   for i,v in ipairs(keys) do
      table.insert(tab, {title = v, fn = hs.fnutils.partial(obj.toggleColorSamples, v)})
   end
   return tab
end

function obj:start()
   self.choosermenu = hs.menubar.new(false):setMenu(choosetable)
   if self.show_in_menubar then
      self.choosermenu:setTitle(self.menubar_title):returnToMenuBar()
   end
end

--- ColorPicker:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ColorPicker
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * show - Show color picker menu
function obj:bindHotkeys(mapping)
   local def = { show = function() self.choosermenu:popupMenu(hs.mouse.getAbsolutePosition()) end }
   hs.spoons.bindHotkeysToSpec(def, mapping)
end

return obj

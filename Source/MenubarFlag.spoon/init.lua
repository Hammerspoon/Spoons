--- === MenubarFlag ===
---
--- Color the menubar according to the current keyboard layout
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MenubarFlag.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MenubarFlag.spoon.zip)
---
--- Functionality inspired by [ShowyEdge](https://pqrs.org/osx/ShowyEdge/index.html.en)

local obj={}
obj.__index = obj

local draw = require "hs.drawing"
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
--- Boolean to specify whether the indicators should be shown on all monitors or just the current one. Defaults to `true`
obj.allScreens = true

--- MenubarFlag.indicatorHeight
--- Variable
--- Number to specify the height of the indicator. Specify 0.0-1.0 to specify a percentage of the height of the menu bar, larger values indicate a fixed height in pixels. Defaults to 1.0
obj.indicatorHeight = 1.0

--- MenubarFlag.indicatorAlpha
--- Variable
--- Number to specify the indicator transparency (0.0 - invisible; 1.0 - fully opaque). Defaults to 0.3
obj.indicatorAlpha = 0.3

--- MenubarFlag.indicatorInAllSpaces
--- Variable
--- Boolean to specify whether the indicator should be shown in all spaces (this includes full-screen mode)
obj.indicatorInAllSpaces = true

--- MenubarFlag.colors
--- Variable
--- Table that contains the configuration of indicator colors
---
--- The table below indicates the colors to use for a given keyboard
--- layout. The index is the name of the layout as it appears in the
--- input source menu. The value of each indicator is a table made of
--- an arbitrary number of segments, which will be distributed evenly
--- across the width of the screen. Each segment must be a valid
--- `hs.drawing.color` specification (most commonly, you should just
--- use the named colors from within the tables). If a layout is not
--- found, then the indicators are removed when that layout is active.
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
--- Contributions of indicator specs are welcome!
obj.colors = {
   Spanish = {col.red, col.yellow, col.red},
   German = {col.black, col.red, col.yellow},
}

----------------------------------------------------------------------

-- Internal variables
local prevlayout = nil
local ind = nil

-- Initialize the empty indicator table
function initIndicators()
   if ind ~= nil then
      delIndicators()
   end
   ind = {}
end

-- Delete existing indicator objects
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

--- MenubarFlag:drawIndicators(src)
--- Method
--- Draw the indicators corresponding to the given layout name
---
--- Params:
---  * src - name of the layout to draw. If the given element exists in `MenubarFlag.colors`, it will be drawn. If it does not exist, then the indicators will be removed from the screen.
---
--- Returns:
---  * The MenubarFlag object
function obj:drawIndicators(src)
   if src ~= prevlayout then
      initIndicators()

      def = self.colors[src]
      logger.df("Indicator definition for %s: %s", src, hs.inspect(def))
      if def ~= nil then
         if self.allScreens then
            screens = hs.screen.allScreens()
         else
            screens = { hs.screen.mainScreen() }
         end
         for i,screen in ipairs(screens) do
            local screeng = screen:fullFrame()
            local width = screeng.w / #def
            for i,v in ipairs(def) do
               if self.indicatorHeight >= 0.0 and self.indicatorHeight <= 1.0 then
                  height = self.indicatorHeight*(screen:frame().y - screeng.y)
               else
                  height = self.indicatorHeight
               end
               c = draw.rectangle(hs.geometry.rect(screeng.x+(width*(i-1)), screeng.y,
                                                   width, height))
               c:setFillColor(v)
               c:setFill(true)
               c:setAlpha(self.indicatorAlpha)
               c:setLevel(draw.windowLevels.overlay)
               c:setStroke(false)
               if self.indicatorInAllSpaces then
                  c:setBehavior(draw.windowBehaviors.canJoinAllSpaces)
               end
               c:show()
               table.insert(ind, c)
            end
         end
      else
         logger.df("Removing indicators for %s because there is no color definitions for it.", src)
         delIndicators()
      end
   end

   prevlayout = src

   return self
end

--- MenubarFlag:getLayoutAnddrawindicators
--- Method
--- Draw indicators for the current keyboard layout
---
--- Params:
---  * None
---
--- Returns:
---  * The MenubarFlag object
function obj:getLayoutAndDrawIndicators()
   return self:drawIndicators(hs.keycodes.currentLayout())
end

--- MenubarFlag:start()
--- Method
--- Start the keyboard layout watcher to draw the menubar indicators.
function obj:start()
   initIndicators()
   self:getLayoutAndDrawIndicators()
   hs.keycodes.inputSourceChanged(function(...) self:getLayoutAndDrawIndicators(...) end)
   return self
end

--- MenubarFlag:stop()
--- Method
--- Remove indicators and stop the keyboard layout watcher
function obj:stop()
   delIndicators()
   hs.keycodes.inputSourceChanged(nil)
   return self
end

return obj

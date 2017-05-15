--- === WindowGrid ===
---
--- Configure and assign hotkey for `hs.grid`
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowGrid.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowGrid.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "WindowGrid"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Internal variable: Key binding for showing the grid
obj.key_show_grid = nil

--- WindowGrid.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('WindowGrid')

--- WindowGrid.gridGeometries
--- Variable
--- Table containing a list of arguments to be passed to grid.setGrid(). Each element in the table is itself a table with 1-3 arguments as defined for [hs.grid.setGrid()](http://www.hammerspoon.org/docs/hs.grid.html#setGrid). Defaults to an empty list, which results in the default 3x3 grid for all screen from `hs.grid`.
obj.gridGeometries = {}

--- WindowGrid:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for WindowGrid
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * show_grid - show the grid overlay
function obj:bindHotkeys(mapping)
   if mapping["show_grid"] then
      if (self.key_show_grid) then
         self.key_show_grid:delete()
      end
      self.key_show_grid = hs.hotkey.bindSpec(mapping["show_grid"], hs.grid.toggleShow)
   end
end

--- WindowGrid:start()
--- Method
--- Sets the grid configuration according to `WindowGrid.gridGeometries`.
function obj:start()
   for i,v in ipairs(self.gridGeometries) do
      self.logger.df("setGrid(%s, %s)", v[1], v[2], v[3])
      hs.grid.setGrid(v[1], v[2], v[3])
   end
end

return obj

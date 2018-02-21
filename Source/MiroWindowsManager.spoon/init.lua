-- Copyright (c) 2018 Miro Mannino
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this 
-- software and associated documentation files (the "Software"), to deal in the Software 
-- without restriction, including without limitation the rights to use, copy, modify, merge,
-- publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
-- to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies
-- or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.

--- === MiroWindowsManager ===
---
--- With this script you will be able to move the window in halves and in corners using your keyboard and mainly using arrows. You would also be able to resize them by thirds, quarters, or halves.
--- 
--- Official homepage for more info and documentation: [https://github.com/miromannino/miro-windows-manager](https://github.com/miromannino/miro-windows-manager)
---
--- Download: [https://github.com/miromannino/miro-windows-manager/raw/master/MiroWindowsManager.spoon.zip](https://github.com/miromannino/miro-windows-manager/raw/master/MiroWindowsManager.spoon.zip)
---

local obj={}
obj.__index = obj

-- Metadata
obj.name = "MiroWindowsManager"
obj.version = "1.1"
obj.author = "Miro Mannino <miro.mannino@gmail.com>"
obj.homepage = "https://github.com/miromannino/miro-windows-management"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- MiroWindowsManager.sizes
--- Variable
--- The sizes that the window can have. 
--- The sizes are expressed as dividend of the entire screen's size.
--- For example `{2, 3, 3/2}` means that it can be 1/2, 1/3 and 2/3 of the total screen's size
obj.sizes = {2, 3, 3/2}

--- MiroWindowsManager.fullScreenSizes
--- Variable
--- The sizes that the window can have in full-screen. 
--- The sizes are expressed as dividend of the entire screen's size.
--- For example `{1, 4/3, 2}` means that it can be 1/1 (hence full screen), 3/4 and 1/2 of the total screen's size
obj.fullScreenSizes = {1, 4/3, 2}

--- MiroWindowsManager.GRID
--- Variable
--- The screen's size using `hs.grid.setGrid()`
--- This parameter is used at the spoon's `:init()`
obj.GRID = {w = 24, h = 24}

obj._pressed = {
  up = false,
  down = false,
  left = false,
  right = false
}

function obj:_nextStep(dim, offs, cb)
  if hs.window.focusedWindow() then
    local axis = dim == 'w' and 'x' or 'y'
    local oppDim = dim == 'w' and 'h' or 'w'
    local oppAxis = dim == 'w' and 'y' or 'x'
    local win = hs.window.frontmostWindow()
    local id = win:id()
    local screen = win:screen()

    cell = hs.grid.get(win, screen)

    local nextSize = self.sizes[1]
    for i=1,#self.sizes do
      if cell[dim] == self.GRID[dim] / self.sizes[i] and
        (cell[axis] + (offs and cell[dim] or 0)) == (offs and self.GRID[dim] or 0)
        then
          nextSize = self.sizes[(i % #self.sizes) + 1]
        break
      end
    end

    cb(cell, nextSize)
    if cell[oppAxis] ~= 0 and cell[oppAxis] + cell[oppDim] ~= self.GRID[oppDim] then
      cell[oppDim] = self.GRID[oppDim]
      cell[oppAxis] = 0
    end

    hs.grid.set(win, cell, screen)
  end
end

function obj:_nextFullScreenStep()
  if hs.window.focusedWindow() then
    local win = hs.window.frontmostWindow()
    local id = win:id()
    local screen = win:screen()

    cell = hs.grid.get(win, screen)

    local nextSize = self.fullScreenSizes[1]
    for i=1,#self.fullScreenSizes do
      if cell.w == self.GRID.w / self.fullScreenSizes[i] and 
         cell.h == self.GRID.h / self.fullScreenSizes[i] and
         cell.x == (self.GRID.w - self.GRID.w / self.fullScreenSizes[i]) / 2 and
         cell.y == (self.GRID.h - self.GRID.h / self.fullScreenSizes[i]) / 2 then
        nextSize = self.fullScreenSizes[(i % #self.fullScreenSizes) + 1]
        break
      end
    end

    cell.w = self.GRID.w / nextSize
    cell.h = self.GRID.h / nextSize
    cell.x = (self.GRID.w - self.GRID.w / nextSize) / 2
    cell.y = (self.GRID.h - self.GRID.h / nextSize) / 2

    hs.grid.set(win, cell, screen)
  end
end

function obj:_fullDimension(dim)
  if hs.window.focusedWindow() then
    local win = hs.window.frontmostWindow()
    local id = win:id()
    local screen = win:screen()
    cell = hs.grid.get(win, screen)

    if (dim == 'x') then
      cell = '0,0 ' .. self.GRID.w .. 'x' .. self.GRID.h
    else  
      cell[dim] = self.GRID[dim]
      cell[dim == 'w' and 'x' or 'y'] = 0
    end

    hs.grid.set(win, cell, screen)
  end
end

--- MiroWindowsManager:bindHotkeys()
--- Method
--- Binds hotkeys for Miro's Windows Manager
--- Parameters:
---  * mapping - A table containing hotkey details for the following items:
---   * up: for the up action (usually {hyper, "up"})
---   * right: for the right action (usually {hyper, "right"})
---   * down: for the down action (usually {hyper, "down"})
---   * left: for the left action (usually {hyper, "left"})
---   * fullscreen: for the full-screen action (e.g. {hyper, "f"})
---
--- A configuration example can be:
--- ```
--- local hyper = {"ctrl", "alt", "cmd"}
--- spoon.MiroWindowsManager:bindHotkeys({
---   up = {hyper, "up"},
---   right = {hyper, "right"},
---   down = {hyper, "down"},
---   left = {hyper, "left"},
---   fullscreen = {hyper, "f"}
--- })
--- ```
function obj:bindHotkeys(mapping)
  hs.inspect(mapping)
  print("Bind Hotkeys for Miro's Windows Manager")

  hs.hotkey.bind(mapping.down[1], mapping.down[2], function ()
    self._pressed.down = true
    if self._pressed.up then 
      self:_fullDimension('h')
    else
      self:_nextStep('h', true, function (cell, nextSize)
        cell.y = self.GRID.h - self.GRID.h / nextSize
        cell.h = self.GRID.h / nextSize
      end)
    end
  end, function () 
    self._pressed.down = false
  end)

  hs.hotkey.bind(mapping.right[1], mapping.right[2], function ()
    self._pressed.right = true
    if self._pressed.left then 
      self:_fullDimension('w')
    else
      self:_nextStep('w', true, function (cell, nextSize)
        cell.x = self.GRID.w - self.GRID.w / nextSize
        cell.w = self.GRID.w / nextSize
      end)
    end
  end, function () 
    self._pressed.right = false
  end)

  hs.hotkey.bind(mapping.left[1], mapping.left[2], function ()
    self._pressed.left = true
    if self._pressed.right then 
      self:_fullDimension('w')
    else
      self:_nextStep('w', false, function (cell, nextSize)
        cell.x = 0
        cell.w = self.GRID.w / nextSize
      end)
    end
  end, function () 
    self._pressed.left = false
  end)

  hs.hotkey.bind(mapping.up[1], mapping.up[2], function ()
    self._pressed.up = true
    if self._pressed.down then 
        self:_fullDimension('h')
    else
      self:_nextStep('h', false, function (cell, nextSize)
        cell.y = 0
        cell.h = self.GRID.h / nextSize
      end)
    end
  end, function () 
    self._pressed.up = false
  end)

  hs.hotkey.bind(mapping.fullscreen[1], mapping.fullscreen[2], function ()
    self:_nextFullScreenStep()
  end)

end

function obj:init()
  print("Initializing Miro's Windows Manager")
  hs.grid.setGrid(obj.GRID.w .. 'x' .. obj.GRID.h)
  hs.grid.MARGINX = 0
  hs.grid.MARGINY = 0
end

return obj

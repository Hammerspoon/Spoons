--- === RoundedCorners ===
---
--- Give your screens rounded corners
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/RoundedCorners.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/RoundedCorners.spoon.zip)
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "RoundedCorners"
obj.version = "1.1"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.corners = {}
obj.topCorners = {}
obj.screenWatcher = nil
obj.spacesWatcher = nil

--- RoundedCorners.allScreens
--- Variable
--- Controls whether corners are drawn on all screens or just the primary screen. Defaults to true
obj.allScreens = true

--- RoundedCorners.radius
--- Variable
--- Controls the radius of the rounded corners, in points. Defaults to 12
obj.radius = 12


--- RoundedCorners.fullscreenOffset
--- Variable
--- Controls the offset of the top corners when in fullscreen, in points. Defaults to 0
--- Place just under the MenuBar in Tahoe: 33
obj.fullscreenOffset = 0

--- RoundedCorners.level
--- Variable
--- Controls which level of the screens the corners are drawn at. See `hs.canvas.windowLevels` for more information. Defaults to `screenSaver + 1`
obj.level = hs.canvas.windowLevels["screenSaver"] + 1

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

function obj:init()
    self.screenWatcher = hs.screen.watcher.new(function() self:screensChanged() end)
    self.spacesWatcher = hs.spaces.watcher.new(function() self:spacesChanged() end)
end

--- RoundedCorners:start()
--- Method
--- Starts RoundedCorners
---
--- Parameters:
---  * None
---
--- Returns:
---  * The RoundedCorners object
---
--- Notes:
---  * This will draw the rounded screen corners and start watching for changes in screen sizes/layouts, reacting accordingly
function obj:start()
    self.screenWatcher:start()
    self.spacesWatcher:start()
    self:render()
    return self
end

--- RoundedCorners:stop()
--- Method
--- Stops RoundedCorners
---
--- Parameters:
---  * None
---
--- Returns:
---  * The RoundedCorners object
---
--- Notes:
---  * This will remove all rounded screen corners and stop watching for changes in screen sizes/layouts
function obj:stop()
    self.screenWatcher:stop()
    self.spacesWatcher:stop()
    self:deleteAllCorners()
    return self
end

-- Delete only the dynamic top corners
function obj:deleteTopCorners()
    hs.fnutils.each(self.topCorners, function(corner) corner:delete() end)
    self.topCorners = {}
end

-- React to the spaces having changed
function obj:spacesChanged()
    self:deleteTopCorners()
    self:render(true)
end

-- Delete all the corners
function obj:deleteAllCorners()
    self:deleteTopCorners()
    hs.fnutils.each(self.corners, function(corner) corner:delete() end)
    self.corners = {}
end

-- React to the screens having changed
function obj:screensChanged()
    self:deleteAllCorners()
    self:render()
end

-- Get the screens to draw on, given the user's settings
function obj:getScreens()
    if self.allScreens then
        return hs.screen.allScreens()
    else
        return {hs.screen.primaryScreen()}
    end
end

-- Draw a single corner
function obj:draw(data, radius, offset, behavior) 
    return hs.canvas.new({x=data.frame.x,y=data.frame.y+offset,w=radius,h=radius}):appendElements(
        { action="build", type="rectangle", },
        { action="clip", type="circle", center=data.center, radius=radius, reversePath=true, },
        { action="fill", type="rectangle", frame={x=0, y=0, w=radius, h=radius, }, fillColor={ alpha=1, }},
        { type="resetClip", }
    ):behavior({hs.canvas.windowBehaviors.stationary, behavior}):level(self.level):show()
end

-- Draw the corners
function obj:render(topOnly)
    local radius = self.radius
    local mission = hs.spaces.focusedSpace() == 1
    hs.fnutils.each(self:getScreens(), function(screen)
        local windows = hs.window.filter.new():setScreens(screen:id()):getWindows()
        local offset = not mission and screen:id() == 1 and #windows > 0 and windows[1]:isFullscreen() and self.fullscreenOffset or 0
        local screenFrame = screen:fullFrame()
        local cornerData = {
          { frame={x=screenFrame.x, y=screenFrame.y}, center={x=radius,y=radius} },
          { frame={x=screenFrame.x + screenFrame.w - radius, y=screenFrame.y}, center={x=0,y=radius} },
          { frame={x=screenFrame.x, y=screenFrame.y + screenFrame.h - radius}, center={x=radius,y=0} },
          { frame={x=screenFrame.x + screenFrame.w - radius, y=screenFrame.y + screenFrame.h - radius}, center={x=0,y=0} },
        }
        for i, data in pairs(cornerData) do
            if (offset > 0 and i < 3) then  
                self.topCorners[#self.topCorners+1] = obj:draw(data, radius, offset)
            elseif (not topOnly) then
                self.corners[#self.corners+1] = obj:draw(data, radius, 0, hs.canvas.windowBehaviors.canJoinAllSpaces)
            end
        end
    end)
end

return obj

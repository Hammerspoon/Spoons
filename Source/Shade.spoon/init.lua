--- === Shade ===
---
--- Creates a semitransparent overlay to reduce screen brightness.
---
--- Download: https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Shade.spoon.zip

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Shade"
obj.version = "0.2"
obj.author = "Leonardo Shibata"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"




--String containing an ASCII diagram to be rendered as a menu bar icon for when Shade is OFF.
obj.iconOff = "ASCII:" ..
". . . . . . . . . . . . . . . . . . . . .\n" ..
". . . . . . . . . . . . . . . . . . . . .\n" ..
". . . . . . . . . . . . . . . . . . . . .\n" ..
". . . 1 # # # # # # # # # # # # # 1 . . .\n" ..
". . . 4 . . . . . . . . . . . . . 2 . . .\n" ..
". . . # 5 = = = = = = = = = = = 5 # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . # 6 = = = = = = = = = = = 6 # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . # 7 = = = = = = = = = = = 7 # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . # . . . . . . . . . . . . . # . . .\n" ..
". . . 4 . . . . . . . . . . . . . # . . .\n" ..
". . . 3 # # # # # # # # # # # # 3 2 . . .\n" ..
". . . . . . . . . . . . . . . . . . . . .\n" ..
". . . . . . . . . . . . . . . . . . . . .\n" ..
". . . . . . . . . . . . . . . . . . . . ."




--String containing an ASCII diagram to be rendered as a menu bar icon for when Shade is ON.
obj.iconOn = "ASCII:" ..
  ". . . . . . . . . . . . . . . . . . . . .\n" ..
  ". . . . . . . . . . . . . . . . . . . . .\n" ..
  ". . . . . . . . . . . . . . . . . . . . .\n" ..
  ". . . 1 # # # # # # # # # # # # # 1 . . .\n" ..
  ". . . 4 . . . . . . . . . . . . . 2 . . .\n" ..
  ". . . # 5 = = = = = = = = = = = 5 # . . .\n" ..
  ". . . # . . . . . . . . . . . . . # . . .\n" ..
  ". . . # 6 = = = = = = = = = = = 6 # . . .\n" ..
  ". . . # . . . . . . . . . . . . . # . . .\n" ..
  ". . . # 7 = = = = = = = = = = = 7 # . . .\n" ..
  ". . . # . . . . . . . . . . . . . # . . .\n" ..
  ". . . # 8 = = = = = = = = = = = 8 # . . .\n" ..
  ". . . # . . . . . . . . . . . . . # . . .\n" ..
  ". . . # 9 = = = = = = = = = = = 9 # . . .\n" ..
  ". . . # . . . . . . . . . . . . . # . . .\n" ..
  ". . . # a = = = = = = = = = = = a # . . .\n" ..
  ". . . 4 . . . . . . . . . . . . . # . . .\n" ..
  ". . . 3 # # # # # # # # # # # # 3 2 . . .\n" ..
  ". . . . . . . . . . . . . . . . . . . . .\n" ..
  ". . . . . . . . . . . . . . . . . . . . .\n" ..
  ". . . . . . . . . . . . . . . . . . . . ."




--Find out screen size. Currently using only the primary screen
obj.screenSize = hs.screen.primaryScreen()

--Returns a hs.geometry rect describing screen's frame in absolute coordinates, including the dock and menu. 
obj.shade = hs.drawing.rectangle(obj.screenSize:fullFrame())







--- Shade.shadeTransparency
--- Variable
--- Contains the alpha (transparency) of the overlay, from 0.0 (completely
--- transparent to 1.0 (completely opaque). Default is 0.5.
obj.shadeTransparency = 0.5







--shade characteristics
--white - the ratio of white to black from 0.0 (completely black) to 1.0 (completely white); default = 0.
--alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
obj.shade:setFillColor({["white"]=0, ["alpha"] = obj.shadeTransparency })
obj.shade:setStroke(false):setFill(true)



--set to cover the whole screen, all spaces and expose
obj.shade:bringToFront(true):setBehavior(17)





--- Shade.shadeIsOn
--- Variable
--- Flag for Shade status, 'false' means shade off, 'true' means on.
obj.shadeIsOn = nil





--- Shade:init()
--- Method
--- Sets up the Spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:init()
  --create icon on the menu bar and set flag to 'false'
  self.shadeMenuIcon = hs.menubar.new()
  self.shadeMenuIcon:setIcon(obj.iconOff)
  -- self.shadeMenuIcon:setClickCallback(obj.toggleShade)
  self.shadeMenuIcon:setTooltip('Shade')

  --when clicked show menu with different transparency options (25, 50 and 75%)
  menuTable = {
                { 
                  title = "25%",
                  fn = function()
                    obj.shadeTransparency = .25
                    obj.start()
                  end 
                },
                { 
                  title = "50%", 
                  fn = function() 
                    obj.shadeTransparency = .5
                    obj.start()  
                  end 
                },
                { 
                  title = "75%",
                  fn = function() 
                    obj.shadeTransparency = .75
                    obj.start() 
                  end 
                },
                {
                  title = "off",
                  fn = function()
                    obj.stop()
                    self.checked = true 
                  end
                },
              }

  self.shadeMenuIcon:setMenu(menuTable)


  self.shadeIsOn = false
end


--- Shade:start()
--- Method
--- Turn the shade on, darkening the screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:start()
  --In case there is already a shade on the screen, first hide this one
  obj.shade:hide()
  
  --Find out screen size. Currently using only the primary screen
  obj.screenSize = hs.screen.primaryScreen()

  --Returns a hs.geometry rect describing screen's frame in absolute coordinates, including the dock and menu. 
  obj.shade = hs.drawing.rectangle(obj.screenSize:fullFrame())
  
  obj.shade:setFillColor({["alpha"] = obj.shadeTransparency })
  obj.shade:show()
  obj.shadeIsOn = true
  obj.shadeMenuIcon:setIcon(obj.iconOn)
end


--- Shade:stop()
--- Method
--- Turn the shade off, brightening the screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:stop()
  obj.shade:hide()
  obj.shadeIsOn = false
  obj.shadeMenuIcon:setIcon(obj.iconOff)
end




--- Shade:toggleShade()
--- Function
--- Turns shade on/off
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:toggleShade()
   
	--Is Shade off? If so, turn it on darkening the screen
	if obj.shadeIsOn == false then
		obj.start()

	--If shade is on, turn it off brightening the screen
	elseif obj.shadeIsOn == true then
		obj.stop()

	else
		-- print('you shouldnt be here') --for debug purposes
	end

end








--- Shade:bindHotkeys(map)
--- Method
--- Binds hotkeys for Shade
---
--- Parameters:
---  * map - A table containing hotkey modifier/key details for the following item:
---   * toggleShade - This will toggle the shade on/off, and update the menubar graphic
--- E.g.: { toggleShade = {"cmd","alt","ctrl"},"s" }
---
--- Returns:
---  * None
function obj:bindHotkeys(map)
  local def = { toggleShade = obj.toggleShade }
  hs.spoons.bindHotkeysToSpec(def, map)
end



--check if there was any change in screen resolution
obj.screenWatcher = hs.screen.watcher.new(function()
  if obj.shadeIsOn == true then
    -- hs.alert.show("screen change")
    obj.shade:hide()
    obj.start()
  end
end)
obj.screenWatcher:start()




--[[ Features being tested (start)

  hs.fnutils.each(allScreens, function(screen) print(screen:id()) end)
  hs.fnutils.each(allScreens, function(screen) print(screen:fullFrame()) end)
  hs.fnutils.each(allScreens, function(screen) print(hs.inspect(screen:fullFrame().table)) end)

--]] --Features being tested (end)










return obj




--- === Shade ===
---
--- Creates a semitransparent overlay to reduce screen brightness.
---
--- Download: 

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Shade"
obj.version = "0.1"
obj.author = "Leonardo Shibata"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"


--String containing an ASCII diagram to be rendered as a menu bar icon for when Shade is OFF.
local iconOff = "ASCII:" ..
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
local iconOn = "ASCII:" ..
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
local screen = hs.screen.primaryScreen()

--Returns a hs.geometry rect describing screen's frame in absolute coordinates, including the dock and menu. 
local shade = hs.drawing.rectangle(screen:fullFrame())


--- Shade.shadeTransparency
--- Variable
--- Contains the alpha (transparency) of the overlay, from 0.0 (completely
--- transparent to 1.0 (completely opaque). Default is 0.5.
obj.shadeTransparency = 0.5

--shade characteristics
--white - the ratio of white to black from 0.0 (completely black) to 1.0 (completely white)
--alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
shade:setFillColor({["white"]=0, ["alpha"] = obj.shadeTransparency })
shade:setStroke(false):setFill(true)

--set to cover the whole screen, all spaces and exposé
shade:bringToFront(true):setBehavior(17)


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
  self.shadeMenuIcon:setIcon(iconOff)
  self.shadeMenuIcon:setClickCallback(obj.toggleShade)
  self.shadeMenuIcon:setTooltip('Shade')
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
  shade:setFillColor({["alpha"] = obj.shadeTransparency })
  shade:show()
  obj.shadeIsOn = true
  obj.shadeMenuIcon:setIcon(iconOn)
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
  shade:hide()
  obj.shadeIsOn = false
  obj.shadeMenuIcon:setIcon(iconOff)
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
		--print('you shouldnt be here') --for debug purposes
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



--[[ Features being tested (start)

--]] --Features being tested (end)







return obj




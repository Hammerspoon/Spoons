--- === ModalMgr ===
---
--- Modal keybindings environment management. Just an wrapper of `hs.hotkey.modal`.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ModalMgr.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ModalMgr.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ModalMgr"
obj.version = "1.0"
obj.author = "ashfinal <ashfinal@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.modal_tray = nil
obj.which_key = nil
obj.modal_list = {}
obj.active_list = {}
obj.supervisor = nil

-- customize width and height of Cheatsheet
obj.width_factor = 0.30
obj.height_factor = 0.30
-- minimum sizes
obj.min_width = 200
obj.min_height = 200

-- alighment for right column
obj.alignmentRightColumn = 'right'
obj.fillByRow = false

function obj:init()
    hsupervisor_keys = hsupervisor_keys or {{"cmd", "shift", "ctrl"}, "Q"}
    obj.supervisor = hs.hotkey.modal.new(hsupervisor_keys[1], hsupervisor_keys[2], 'Initialize Modal Environment')
    obj.supervisor:bind(hsupervisor_keys[1], hsupervisor_keys[2], "Reset Modal Environment", function() obj.supervisor:exit() end)
    hshelp_keys = hshelp_keys or {{"alt", "shift"}, "/"}
    obj.supervisor:bind(hshelp_keys[1], hshelp_keys[2], "Toggle Help Panel", function() obj:toggleCheatsheet({all=obj.supervisor}) end)
    obj.modal_tray = hs.canvas.new({x = 0, y = 0, w = 0, h = 0})
    obj.modal_tray:level(hs.canvas.windowLevels.tornOffMenu)
    obj.modal_tray[1] = {
        type = "circle",
        action = "fill",
        fillColor = {hex = "#FFFFFF", alpha = 0.7},
    }
    obj.which_key = hs.canvas.new({x = 0, y = 0, w = 0, h = 0})
    obj.which_key:level(hs.canvas.windowLevels.tornOffMenu)
    obj.which_key[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = {hex = "#EEEEEE", alpha = 0.95},
        roundedRectRadii = {xRadius = 10, yRadius = 10},
    }
end

--- ModalMgr:new(id)
--- Method
--- Create a new modal keybindings environment
---
--- Parameters:
---  * id - A string specifying ID of new modal keybindings

function obj:new(id)
    obj.modal_list[id] = hs.hotkey.modal.new()
end


-- this function draws the text on the window
--
-- by default, it fills by row
-- but it can be customized to fill by column
function insertIntoSheet(position, st, row, column, n)
   local textAlign = "left"
   local xpos
   local ypos
   -- height available for one item, in percentage
   -- add one for a small margin of at least 1/2 element at the bottom
   local h = 100 / (math.ceil(n*1.0/2) + 1)
   local w = "47%"
   local xposLeft = "3%"
   local xposRight = "50%"
   if obj.fillByRow then
      if position %2 == 1 then
         xpos = xposLeft
         ypos = tostring(math.floor(h * position / 2)) .. "%"
      else
         -- this one goes to the right
         textAlign =  obj.alignmentRigthColumn
         xpos = xposRight
         ypos = tostring(math.floor(h * (position-1) / 2)) .. "%"
      end
   else
      local actualPos
      if position > math.ceil(n / 2) then
         -- this one goes to the right
         textAlign =  obj.alignmentRightColumn
         xpos = xposRight
         actualPos = position - math.ceil(n*1.0/2)
      else
         xpos = xposLeft
         actualPos = position 
      end
      ypos = tostring(math.floor(actualPos * h)) .. "%"
   end

--   print(ypos, n, h)
   obj.which_key[position + 1] = {
      type = "text",
      text = st,
      textFont = "Courier-Bold",
      textSize = 16,
      textColor = {hex = "#2390FF", alpha = 1},
      textAlignment = textAlign,
      frame = {
         x = xpos,
         y = ypos,
         --         w = tostring((1 - 80 / (cres.w / 5 * 3)) / 2),
         w = w,
         h = tostring(math.floor(h)) .. "%"
      }
   }

end

--- ModalMgr:toggleCheatsheet([idList], [force])
--- Method
--- Toggle the cheatsheet display of current modal environments's keybindings.
---
--- Parameters:
---  * iterList - An table specifying IDs of modal environments or active_list. Optional, defaults to all active environments.
---  * force - A optional boolean value to force show cheatsheet, defaults to `nil` (automatically).

function obj:toggleCheatsheet(iterList, force)
    if obj.which_key:isShowing() and not force then
        obj.which_key:hide()
    else
        local cscreen = hs.screen.mainScreen()
        local cres = cscreen:fullFrame()

        local framew = math.max(math.floor(cres.w  * obj.width_factor),obj.min_width)
        local frameh = math.max(math.floor(cres.h  * obj.height_factor), obj.min_height)
        obj.which_key:frame({
              w = framew,
              h = frameh,
              x = cres.x + (cres.w - framew) /2,
              y = cres.y + (cres.h - frameh) /2
        })
        local keys_pool = {}
        local tmplist = iterList or obj.active_list
        for i, v in pairs(tmplist) do
            if type(v) == "string" then
                -- It appears to be idList
                for _, m in ipairs(obj.modal_list[v].keys) do
                    table.insert(keys_pool, m.msg)
                end
            elseif type(i) == "string" then
                -- It appears to be active_list
                for _, m in pairs(v.keys) do
                    table.insert(keys_pool, m.msg)
                end
            end
        end
        --        if obj.orderByColumn then
        if true then
           for idx, val in ipairs(keys_pool) do
              insertIntoSheet(idx,val, idx, 0, #keys_pool)
           end
        end
        obj.which_key:show()
    end
end

--- ModalMgr:activate(idList, [trayColor], [showKeys])
--- Method
--- Activate all modal environment in `idList`.
---
--- Parameters:
---  * idList - An table specifying IDs of modal environments
---  * trayColor - An optional string (e.g. #000000) specifying the color of modalTray, defaults to `nil`.
---  * showKeys - A optional boolean value to show all available keybindings, defaults to `nil`.

function obj:activate(idList, trayColor, showKeys)
    for _, val in ipairs(idList) do
        obj.modal_list[val]:enter()
        obj.active_list[val] = obj.modal_list[val]
    end
    if trayColor then
        local cscreen = hs.screen.mainScreen()
        local cres = cscreen:fullFrame()
        obj.modal_tray:frame({
            x = cres.w - math.ceil(cres.w / 32),
            y = cres.h - math.ceil(cres.w / 32),
            w = math.ceil(cres.w / 32 / 2),
            h = math.ceil(cres.w / 32 / 2)
        })
        obj.modal_tray[1].fillColor = {hex = trayColor, alpha = 0.7}
        obj.modal_tray:show()
    end
    if showKeys then
        obj:toggleCheatsheet(idList, true)
    end
end

--- ModalMgr:deactivate(idList)
--- Method
--- Deactivate modal environments in `idList`.
---
--- Parameters:
---  * idList - An table specifying IDs of modal environments

function obj:deactivate(idList)
    for _, val in ipairs(idList) do
        obj.modal_list[val]:exit()
        obj.active_list[val] = nil
    end
    obj.modal_tray:hide()
    for i = 2, #obj.which_key do
        obj.which_key:removeElement(2)
    end
    obj.which_key:hide()
end

--- ModalMgr:deactivateAll()
--- Method
--- Deactivate all active modal environments.
---
--- Parameters:
---  * None

function obj:deactivateAll()
    local i = 1
    local tab = {}
    for k, _ in pairs(obj.active_list) do
      tab[i] = k
      i = i + 1
    end
    obj:deactivate(tab)
end

return obj

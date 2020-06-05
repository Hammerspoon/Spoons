--- === Eject Menu ===
---
--- An much-needed eject menu for your Mac menu bar.
--- Configurable properties.
---  ejectAllHotkey
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EjectMenu.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EjectMenu.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'EjectMenu'
obj.version = '0.0.1'
obj.author = 'Mark Juers <mpjuers@gmail.com>'
obj.homepage = 'https://github.com/Hammerspoon/Spoons'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

function obj:init ()
    ejectMenu = hs.menubar.new():setTitle("⏏")
    flagsEvent = hs.eventtap.new(
        {hs.eventtap.event.types.flagsChanged},
        function (event) self:changeEjectMenuIcon(event:getFlags()) end
    )
    ejectMenu:setMenu(function (mods) return self:initEjectMenu(mods) end)
end

function obj:bindHotKeys (map)
    local def = {
        ejectAll = function () self:ejectAll() end
    }
    hs.spoons.bindHotkeysToSpec(def, map)
end

function obj:changeEjectMenuIcon (mods)
    if mods:containExactly({'cmd'}) then
        ejectMenu:setTitle('⮑')
    elseif mods:containExactly({}) then
        ejectMenu:setTitle('⏏')
    end
    return(0)
end

function obj:ejectAll ()
    hs.osascript.applescript(
        'tell application "Finder" to eject (every disk whose ejectable is true and local volume is true and free space is not equal to 0)'
    )
    hs.notify.show('All drives unmounted.', '', '')
end

function obj:execMenuItem (mods, table)
    if (
            mods['cmd'] == true and
            mods['ctrl'] == false and
            mods['alt'] == false and
            mods['shift'] == false and
            mods['fn'] == false
        ) then
        hs.osascript.applescript('tell application "Finder" to open ("/Volumes/' .. table['title'] .. '/" as POSIX file)')
    else
        hs.osascript.applescript('tell application "Finder" to eject disk "' .. table['title'] .. '"')
        hs.notify.show(table['title'] .. ' unmounted.', '', '')
    end
end

function obj:initEjectMenu (mods)
    local ejectMenuDrives = select(
        2, hs.osascript.applescript(
            'tell application "Finder" to get the name of (every disk whose ejectable is true)'
        )
    )
    local ejectMenuTable = {
        {title = "Eject All", fn = function () self:ejectAll() end},
        {title = '-'}
    }
    if pcall(function () next(ejectMenuDrives) end) then
        for k, drive in pairs(ejectMenuDrives) do
            print(drive .. " is ejectable.")
            table.insert(
                ejectMenuTable,
                {
                    title = drive, 
                    fn = function (mods, table) self:execMenuItem(mods, table) end
                }
            )
        end
    else
        print("No external drives.")
    end
    return ejectMenuTable
end
--
function obj:start ()
    flagsEvent:start()
end

function obj:stop ()
    flagsEvent:stop()
end

return obj

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
obj.version = '0.1'
obj.author = 'Mark Juers <mpjuers@gmail.com>'
obj.homepage = 'https://github.com/Hammerspoon/Spoons'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

-- EjectMenu:init()
-- method
-- Initializes eject menu with available drives.
--
-- Returns
-- nil

function obj:init ()
    ejectMenu = hs.menubar.new():setTitle("⏏")
    flagsEvent = hs.eventtap.new(
        {hs.eventtap.event.types.flagsChanged},
        function (event) self:changeEjectMenuIcon(event:getFlags()) end
    )
    ejectMenu:setMenu(function (mods) return self:initEjectMenu(mods) end)
end

-- EjectMenu:bindHotKeys(map)
-- method
-- Binds hotkeys.
--
-- parameters
-- * map: a table specifying mappings in the format {name = {{{modifiers}, key}}
--
-- returns
-- nil
--
function obj:bindHotKeys (map)
    local def = {
        ejectAll = function () self:ejectAll() end
    }
    hs.spoons.bindHotkeysToSpec(def, map)
end

-- EjectMenu:changeEjectMenuIcon(mods)
-- method
-- Changes eject menu icon depending on which modifiers are held.
--
--parameteres
--* mods: A table containing for which the keys are the modifiers being held
--  and the values are 'true'.
--
-- returns
-- nil

function obj:changeEjectMenuIcon (mods)
    if mods:containExactly({'cmd'}) then
        ejectMenu:setTitle('⮑')
    elseif mods:containExactly({}) then
        ejectMenu:setTitle('⏏')
    end
    return(0)
end

-- EjectMenu:ejectAll()
-- Ejects all external drives.
--
-- returns
-- nil

function obj:ejectAll ()
    local volumes = hs.fs.volume.allVolumes()
    for path, v in pairs(volumes) do
        if obj:shouldEject(path, v) then
            hs.fs.volume.eject(path)
        end
    end
    hs.notify.show('All drives unmounted.', '', '')
end

-- EjectMenu:execMenuItem(mods, table)
-- method
-- Defines and executes menu item based on which modifiers are held.
--
-- parameters
--* mods: A table containing which modifiers are held in {key = bool} format
--  only if 'bool' is true. Other modifiers are omitted.
--* table: The menu item being activated.
--
-- returns
-- nil

function obj:execMenuItem (mods, table)
    if (
            mods['cmd'] == true and
            mods['ctrl'] == false and
            mods['alt'] == false and
            mods['shift'] == false and
            mods['fn'] == false
        ) then
        hs.osascript.applescript(
            'tell application "Finder"' 
            .. ' to open ("' .. table['title'] .. '" as POSIX file)'
        )
    else
        hs.fs.volume.eject(table['title'])
        hs.notify.show(table['title'] .. ' unmounted.', '', '')
    end
end

-- EjectMenu:initEjectMenu(mods)
-- method
-- Initializes eject menu when clicked.
--
-- parameters
--* mods: a table containing {mod = bool} for all modifiers, where bool can be
--  be either 'true' or 'false' (unlike execMenuItem)
--
-- returns
-- ejectMenuTable: a table containing entries and functions for ejectable drives.

function obj:initEjectMenu (mods)
    local volumes = hs.fs.volume.allVolumes()
    local ejectMenuDrives = {}
    for path, v in pairs(volumes) do
        if self:shouldEject(path, v) then
            ejectMenuDrives[path] = v
        end
    end
    local ejectMenuTable = {
        {title = "Eject All", fn = function () self:ejectAll() end},
        {title = '-'}
    }
    if pcall(function () next(ejectMenuDrives) end) then
        for drive, v in pairs(ejectMenuDrives) do
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

--- EjectVolumes:shouldEject(path, info)
--- Method
--- Determine if a volume should be ejected.
---
--- Parameters:
---  * path - the mount path of the volume.
---  * info - a table containing a data structure as returned by `hs.fs.volume.allVolumes()`.
--- Returns:
---  * A boolean indicating whether the volume should be ejected.
function obj:shouldEject(path, info)
    return not info["NSURLVolumeIsInternalKey"]
end

-- EjectMenu:start()
-- method
-- Starts modifier watcher.
--
-- return
-- nil
function obj:start ()
    flagsEvent:start()
end

-- EjectMenu:stop()
-- method
-- Stops modifier watcher.
--
-- return
-- nil
function obj:stop ()
    flagsEvent:stop()
end

return obj

--- === ArrangeDesktop ===
---
--- Utilities for arranging your desktop how you like it.
---
--- Positioning logic adapted from https://github.com/dploeger/hammerspoon-window-manager

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ArrangeDesktop"
obj.version = "1.0.0"
obj.author = "Luis Cruz <sprak3000+github@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- ArrangeDesktop.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('ArrangeDesktop')

--- ArrangeDesktop.arrangements
--- Variable
--- Contains the configured desktop arrangements
obj.arrangements = {}

-- Internal method - Positions all windows for an application based on the given criteria.
--
-- Parameters
-- * app - table of the application instance
-- * appTitle - the name of the application, e.g., Slack, Firefox, etc.
-- * screen - table of the position of the screen (x, y integer pair) to place the application window into
-- * frame - table of the frame details for the application window, e.g., {w=12, h=12, x=12, y=12}
function obj:_positionApp(app, appTitle, screen, frame)
    obj.logger.d('Positioning ' .. appTitle)

    app:activate()
    local windows = hs.window.filter.new(appTitle):getWindows()

    for k, v in pairs(windows) do
        obj.logger.d('Positioning window ' .. v:id() .. ' of app ' .. appTitle)
        v:moveToScreen(screen)
        v:setFrame(frame, 0)
    end
end

--- ArrangeDesktop:arrange
--- Method
--- Arrange the desktop based on a given configuration
---
--- Parameters:
--- * arrangement - table of arrangement data
function obj:arrange(arrangement)
    for monitorUUID, monitorDetails in pairs(obj.arrangements[arrangement]) do
        if hs.screen.find(monitorUUID) ~= nil then
            for appName, position in pairs(monitorDetails['apps']) do
                app = hs.application.get(appName)
                if app ~= nil then
                    obj:_positionApp(app, appName, monitorUUID, position)
                end
            end
        end
    end
end

--- ArrangeDesktop:addMenuItems
--- Method
--- Add menu items to a table for each configured desktop arrangment.
---
--- Parameters:
--- * menuItems - table of menu items
--- * arrangements - table of desktop arrangements
---
--- Returns:
--- table of menu items
function obj:addMenuItems(menuItems, arrangements)
    if menuItems == nil then
        menuItems = {}
    end

    table.insert(menuItems, { title = "Log Current Desktop Arrangement", fn = function() obj:logCurrentArrangement() end })

    if obj.arrangements ~= nil then
        for k, v in pairs(obj.arrangements) do
            table.insert(menuItems, { title = "Use " .. k .. " desktop arrangement", fn = function() obj:arrange(k) end })
        end
    end

    return menuItems
end

--- ArrangeDesktop:logCurrentArrangement()
--- Method
--- Build up the configuration for the current desktop arrangement and log it to the Hammerspoon console.
function obj:logCurrentArrangement()
    local frameTemplate = '{ w = wVal, h = hVal, x = xVal, y = yVal }'
    local cmdTemplate = '    positionApp(\'appName\', monitorUUID, frame)'
    local output = { "\n['<ARRANGEMENT NAME>'] = {" }

    for k, v in pairs(hs.screen.allScreens()) do
        table.insert(output, "    ['" .. v:getUUID() .. "'] = {")
        table.insert(output, "        ['Montior Name'] = '" .. v:name() .. "',")
        table.insert(output, "        ['apps'] = {")

        local windows = hs.window.filter.new(true):setScreens(v:getUUID()):getWindows()
        for wi, wv in pairs(windows) do
            local frame = frameTemplate

            wv:focus()
            for i, t in pairs(wv:frame()) do
                local pattern = string.gsub(i, '_', '') .. 'Val'
                frame = string.gsub(frame, pattern, t)
            end

            table.insert(output, "            ['" .. wv:application():title() .. "'] = " .. frame .. "")
        end

        table.insert(output, "        },")
        table.insert(output, "    },")
    end

    table.insert(output, '}')

    obj.logger.i('--------------------------------------------------------------------------------')
    obj.logger.i(table.concat(output, "\n"))
    obj.logger.i('--------------------------------------------------------------------------------')
end

return obj

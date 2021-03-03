--- === JSON Menu ===
---
--- Add menu to macOS menubar based on provided JSON path.

local obj={}
obj.__index = obj

-- Metadata
obj.name = "JSONMenu"
obj.version = "0.1"
obj.author = "Sven Wilhelm <refnode@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"


obj.spoonPath = hs.spoons.scriptPath()
obj.title = "JSONMenu"
obj.tooltip = "JSONMenu Tooltip"
obj.config_file = hs.spoons.resourcePath("menu.json")
obj.menubar = nil
obj.system_menubar = true
obj.logger = hs.logger.new('JSONMenu')

function obj:init()
    self.menubar = hs.menubar.new(self.system_menubar)
    return self
end

function obj:start()
    obj:rebuild()
    return self
end

function obj:stop()
    self.menubar:removeFromMenuBar()
end

--- JSONMenu.menuItemCallback(url)
--- Method
--- Return callback function to dispatch url with Spoon URLDispatcher.
---
--- Parameters:
---  * url - A string containing the URL
local function menuItemCallback(url)
    -- https://www.hammerspoon.org/docs/hs.http.html#urlParts
    local parts = hs.http.urlParts(url)
    return function()
        spoon.URLDispatcher:dispatchURL(parts.scheme, parts.host, {}, parts.absoluteString)
        return
    end
end

local function buildMenu(items)
    local menu_items = {}
    for k, v in pairs(items) do
        title = v.title
        fn = nil
        image = nil
        if v.url ~= "" and v.url ~= nil then
            fn = menuItemCallback(v.url)
        end
        table.insert(
            menu_items, {
                title = v.title,
                fn = fn,
        })
    end
    return menu_items
end

function obj:rebuild()
    local menu_items = {}
    local items = hs.json.read(self.config_file)
    for k, v in pairs(items) do
        title = v.title
        self.logger.i(title)
        fn = nil
        image = nil
        if v.menu ~= "" and v.menu ~= nil then
            sub_menu = buildMenu(v.menu)
            table.insert(menu_items, { title = v.title, menu = sub_menu })
        elseif v.url ~= "" and v.url ~= nil then
            fn = menuItemCallback(v.url)
            table.insert(menu_items, { title = v.title, fn = fn })
        else
            table.insert(menu_items, { title = v.title })
        end
    end
    self.menubar:setMenu(menu_items)
    self.menubar:setTitle(self.title)
    self.menubar:setTooltip(self.tooltip)
    return self
end

return obj

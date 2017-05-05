--- === Emojis ===
---
--- Let users choose emojis by name/keyword
local obj = {}
obj.__index = obj

-- luacheck: globals utf8

-- Metadata
obj.name = "Emojis"
obj.version = "1.0"
obj.author = "Adriano Di Luzio <adrianodl@hotmail.it>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Internal function used to find our location, so we know where to load files from

local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end
obj.spoonPath = script_path()

obj.choices = {}
obj.chooser = nil
obj.hotkey = nil

local wf = hs.window.filter.defaultCurrentSpace

function obj.callback(choice)
    local lastFocused = wf:getWindows(wf.sortByFocusedLast)
    if #lastFocused > 0 then lastFocused[1]:focus() end
    if not choice then return end
    hs.eventtap.keyStrokes(utf8.char(choice['char']))
end

function obj:init()
    self.choices = {}
    for _, emoji in pairs(hs.json.decode(io.open(self.spoonPath .. '/emojis/emojis.json'):read())) do
        local subText = emoji.shortname
        if #emoji.keywords > 0 then subText = table.concat(emoji['keywords'], ', ') .. ', ' .. subText end
        table.insert(self.choices,
            {text=emoji['name']:gsub("^%l", string.upper),
                subText=subText,
                image=hs.image.imageFromPath(self.spoonPath .. '/emojis/png/' .. emoji['unicode'] .. '.png'),
                char=tonumber(emoji['code_decimal']:sub(3, -2)),
                order=tonumber(emoji['emoji_order']),
            })
    end
    table.sort(self.choices, function(a, b) return a['order'] < b['order'] end)

    self.chooser = hs.chooser.new(self.callback)
    self.chooser:rows(5)
    self.chooser:searchSubText(true)
    self.chooser:choices(self.choices)
end

--- Emojis:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for Emojis
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * toggle - This will toggle the emoji chooser
---
--- Returns:
---  * The Emojis object
function obj:bindHotkeys(mapping)
    if self.hotkey then self.hotkey:delete() end
    local toggleMods = mapping['toggle'][1]
    local toggleKey = mapping['toggle'][2]

    self.hotkey = hs.hotkey.new(
        toggleMods, toggleKey,
        function() if self.chooser:isVisible() then
            self.chooser:hide() else self.chooser:show() end end
    ):enable()

    return self
end

return obj

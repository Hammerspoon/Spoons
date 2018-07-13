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

dofile(obj.spoonPath .. "/table.lua")

local wf = hs.window.filter.defaultCurrentSpace

function obj.callback(choice)
    local lastFocused = wf:getWindows(wf.sortByFocusedLast)
    if #lastFocused > 0 then
        lastFocused[1]:focus()
    end
    if not choice then
        return
    end
    assert(choice.char)
    hs.eventtap.keyStrokes(hs.utf8.codepointToUTF8(table.unpack(choice.char))) -- luacheck: ignore
end

function obj:init()
    -- is the emojis file available?
    print("Starting Emojis Spoon...")
    local mod, err = table.load(script_path() .. "emojis_json_lua.lua") -- luacheck: ignore
    if err then
        print("Emojis Spoon: table's not here, generating it from json.")
        mod = nil
    end
    if mod then
        self.choices = mod
    else
        self.choices = {}
        for _, emoji in pairs(hs.json.decode(io.open(self.spoonPath .. "/emojis/emojis.json"):read())) do
            local subText = emoji.shortname
            if #emoji.keywords > 0 then
                subText = table.concat(emoji["keywords"], ", ") .. ", " .. subText
            end
            local chars =
                hs.fnutils.imap(
                hs.fnutils.split(emoji.code_points.output, "-"),
                function(s)
                    return tonumber(s, 16)
                end
            )

            table.insert(
                self.choices,
                {
                    text = emoji["name"]:gsub("^%l", string.upper),
                    subText = subText,
                    image_path = emoji["code_points"]["base"],
                    -- image = hs.image.imageFromPath(
                    --     self.spoonPath .. "/emojis/png/" .. emoji["code_points"]["base"] .. ".png"
                    -- ),
                    char = chars,
                    order = tonumber(emoji["order"])
                }
            )
        end
        table.sort(
            self.choices,
            function(a, b)
                return a["order"] < b["order"]
            end
        )

        print("Emojis Spoon: Saving emojis... ")
        table.save(self.choices, self.spoonPath .. "/emojis_json_lua.lua") -- luacheck: ignore
        print("Emojis Spoon: ... saved")
    end
    -- inject all images now
    for _, ch in pairs(self.choices) do
        if ch["image_path"] then
            ch["image"] = hs.image.imageFromPath(self.spoonPath .. "/emojis/png/" .. ch["image_path"] .. ".png")
        end
    end

    self.chooser = hs.chooser.new(self.callback)
    self.chooser:rows(5)
    self.chooser:searchSubText(true)
    self.chooser:choices(self.choices)
    print("Emojis Spoon: Startup completed")
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
    if self.hotkey then
        self.hotkey:delete()
    end
    local toggleMods = mapping["toggle"][1]
    local toggleKey = mapping["toggle"][2]

    self.hotkey =
        hs.hotkey.new(
        toggleMods,
        toggleKey,
        function()
            if self.chooser:isVisible() then
                self.chooser:hide()
            else
                self.chooser:show()
            end
        end
    ):enable()

    return self
end

return obj

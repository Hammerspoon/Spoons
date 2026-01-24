--- BibleVerse Spoon - displays random Bible verses as desktop widget.
local obj = {}
obj.__index = obj
obj.name = "BibleVerse"
obj.version = "2.0"
obj.author = "Oleksandr"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/auraz/BibleVerseSpoon"

local verse = dofile(hs.spoons.resourcePath("verse.lua"))
local widget = dofile(hs.spoons.resourcePath("widget.lua"))
local default_config = dofile(hs.spoons.resourcePath("config.lua"))

obj.config = {}
for k, v in pairs(default_config) do obj.config[k] = v end

local state = { canvas = nil, timer = nil, watcher = nil }

function obj:refresh()
    verse.fetch(self.config.translation, function(data)
        if not data then return end
        local text = verse.clean_text(data.text)
        local ref = verse.format_reference(data, self.config.translation)
        state.canvas = widget.render(state, text, ref, self.config, data)
    end)
    return self
end

function obj:start()
    self:refresh()
    state.timer = hs.timer.doEvery(self.config.refresh_interval, function() self:refresh() end)
    state.watcher = hs.caffeinate.watcher.new(function(e)
        if e == hs.caffeinate.watcher.systemDidWake then self:refresh() end
    end)
    state.watcher:start()
    return self
end

function obj:stop()
    if state.timer then state.timer:stop() end
    if state.watcher then state.watcher:stop() end
    widget.destroy(state.canvas)
    state = { canvas = nil, timer = nil, watcher = nil }
    return self
end

return obj

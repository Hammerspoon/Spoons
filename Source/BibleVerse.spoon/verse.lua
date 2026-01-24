--- Verse fetching and parsing functions.
local translations = dofile(hs.spoons.resourcePath("translations.lua"))

local M = {}
local API_BASE = "https://bolls.life/get-random-verse/"

function M.clean_text(raw)
    return raw:gsub("<[^>]+>", ""):gsub("&nbsp;", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function M.get_book_name(book_num, translation)
    local books = translations[translation]
    return books and books[book_num] or ("Book " .. book_num)
end

function M.format_reference(data, translation)
    return M.get_book_name(data.book, translation) .. " " .. data.chapter .. ":" .. data.verse
end

function M.fetch(translation, callback)
    local function try_fetch()
        hs.http.asyncGet(API_BASE .. translation .. "/", nil, function(status, body)
            if status ~= 200 then callback(nil) return end
            local data = hs.json.decode(body)
            if data.book < 40 or data.book > 66 then try_fetch() return end
            callback(data)
        end)
    end
    try_fetch()
end

return M

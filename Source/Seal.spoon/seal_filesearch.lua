--- === Seal.plugins.filesearch ===
---
--- A plugin to add file search capabilities, making Seal act as a spotlight file search
local obj = {}
obj.__index = obj
obj.__name = "seal_filesearch"

--- Seal.plugins.filesearch.fileSearchPaths
--- Variable
--- Table containing the paths to search for files
---
--- Notes:
---  * You will need to authorize hammerspoon to access the folders in this list in order for this to work.
obj.fileSearchPaths = {"~/", "~/Downloads", "~/Documents", "~/Movies", "~/Desktop", "~/Music", "~/Pictures"}

--- Seal.plugins.filesearch.maxResults
--- Variable
--- Maximum number of results to display
obj.maxQueryResults = 40

--- Seal.plugins.filesearch.displayResultsTimeout
--- Variable
--- Maximum time to wait before displaying the results
--- Defaults to 0.2s (200ms).
---
--- Notes:
---  * higher value might give you more results but will give a less snappy experience
obj.displayResultsTimeout = 0.2

---
-- Private variables
---
obj.fileSearchOptions = {
    searchPaths = obj.fileSearchPaths,
    searchTimeout = obj.displayResultsTimeout,
    maxSearchResults = obj.maxQueryResults
}
obj.currentFileSearch = nil
obj.displayedQueryResults = {}
obj.currentQuery = nil
obj.currentQueryResults = nil

-- hammerspoon passes .* as empty query
EMPTY_QUERY = ".*"

local log = hs.logger.new('seal_filesearch', 'info')

---
-- Spotlight Helper class
---
SpotlightFileSearch = {}

function SpotlightFileSearch:new(query, callback, options)
    object = {}
    setmetatable(object, self)
    self.__index = self
    self.query = query
    self.callback = callback
    self.searchPaths = options.searchPaths
    self.searchTimeout = options.searchTimeout
    self.maxSearchResults = options.maxSearchResults
    self.searchResults = {}
    self.running = false
    return object
end

function SpotlightFileSearch:start()
    log.d("starting spotlight filesearch for query " .. self.query)
    self.spotlight = hs.spotlight.new()
    self.spotlight:searchScopes(self.searchPaths)
    self.spotlight:callbackMessages("inProgress", "didFinish")
    self.spotlight:setCallback(hs.fnutils.partial(self.handleSpotlightCallback, self))
    self.spotlight:queryString(self:buildSpotlightQuery())
    self.searchTimer = hs.timer.doAfter(self.searchTimeout, hs.fnutils.partial(self.runCallback, self))
    self.spotlight:start()
    self.running = true
end

function SpotlightFileSearch:stop()
    log.d("stopping spotlight filesearch for query " .. self.query)
    if not self.running then
        return
    end
    if self.spotlight:isRunning() then
        self.spotlight:stop()
    end
    if self.searchTimer ~= nil and self.searchTimer:running() then
        self.searchTimer:stop()
    end
    self.running = false
end

--

function SpotlightFileSearch:buildSpotlightQuery()
    local queryWords = hs.fnutils.split(self.query, "%s+")
    local searchFilters = hs.fnutils.map(queryWords, function(word)
        return [[kMDItemFSName like[c] "*]] .. word .. [[*"]]
    end)
    local spotlightQuery = table.concat(searchFilters, [[ && ]])
    return spotlightQuery
end

function SpotlightFileSearch:handleSpotlightCallback(_, msg, info)
    log.d("received spotlight callback " .. msg .. " for query " .. self.query)
    if not self.running then
        log.d("ignoring spotlight callback for non-running query " .. self.query)
        return
    end
    if msg == "inProgress" and info.kMDQueryUpdateAddedItems ~= nil then
        self:updateSearchResults(info.kMDQueryUpdateAddedItems)
    end

    if msg == "didFinish" or #self.searchResults >= self.maxSearchResults then
        self:runCallback()
    end

end

function SpotlightFileSearch:updateSearchResults(results)
    log.d("received " .. #results .. " spotlight results for query " .. self.query)
    for _, item in ipairs(results) do
        if #self.searchResults >= self.maxSearchResults then
            break
        end
        table.insert(self.searchResults, item)
    end
end

function SpotlightFileSearch:runCallback()
    log.d("calling spotlight filesearch callback with " .. #self.searchResults .. " results for query .. " .. self.query)
    if not self.running then
        log.d("skipping calling spotlight filesearch callback for non-running query " .. self.query)
        return
    end
    self:stop()
    self.callback(self.query, self.searchResults)
end

---
-- Private functions
---

local convertSpotlightResultToQueryResult = function(item)
    local icon = hs.image.iconForFile(item.kMDItemPath)
    local bundleID = item.kMDItemCFBundleIdentifier
    if (not icon) and (bundleID) then
        icon = hs.image.imageFromAppBundle(bundleID)
    end
    return {
        text = item.kMDItemDisplayName,
        subText = item.kMDItemPath,
        path = item.kMDItemPath,
        uuid = obj.__name .. "__" .. (bundleID or item.kMDItemDisplayName),
        plugin = obj.__name,
        type = "open",
        image = icon
    }
end

local handleFileSearchResults = function(query, searchResults)
    if query == obj.currentQuery then
        obj.currentQueryResults = hs.fnutils.map(searchResults, convertSpotlightResultToQueryResult)
        obj.seal.chooser:refreshChoicesCallback()
    end
end

---
-- Public methods
---

function obj:commands()
    return {
        filesearch = {
            cmd = "'",
            fn = obj.fileSearch,
            name = "Search file",
            description = "Search file",
            plugin = obj.__name
        }
    }
end

function obj:bare()
    return nil
end

function obj.completionCallback(rowInfo)
    if rowInfo["type"] == "open" then
        if string.find(rowInfo["path"], "%.applescript$") or string.find(rowInfo["path"], "%.scpt$") then
            hs.task.new("/usr/bin/osascript", nil, {rowInfo["path"]}):start()
        else
            hs.task.new("/usr/bin/open", nil, {rowInfo["path"]}):start()
        end
    end
end

function obj.fileSearch(query)
    if query ~= obj.currentQuery then
        if obj.currentFileSearch ~= nil then
            obj.currentFileSearch:stop()
            obj.currentFileSearch = nil
        end

        if query == EMPTY_QUERY then
            obj.currentQuery = ""
            obj.currentQueryResults = {}
            obj.displayedQueryResults = {}
        else
            -- Seal want the results synchronously, but spotlight will return then asynchronously
            -- to workaround that, we launch the spotlight search in the background and
            -- return the currently displayed results (so that Seal doesn't change the current results list)
            -- We force a refresh later once we have the results
            obj.currentQuery = query
            obj.currentQueryResults = nil
            obj.currentFileSearch = SpotlightFileSearch:new(query, handleFileSearchResults, obj.fileSearchOptions)
            obj.currentFileSearch:start()
        end

    elseif obj.currentQueryResults ~= nil then
        -- If we are here, it's mean the force refreshed has been triggered after receving spotlight results
        -- we just return the results we accumulated from spotlight
        obj.displayedQueryResults = obj.currentQueryResults
    end

    return obj.displayedQueryResults

end

return obj

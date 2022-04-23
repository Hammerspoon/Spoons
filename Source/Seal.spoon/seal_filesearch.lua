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

-- Variables
obj.currentQuery = nil
obj.currentQueryResults = {}
obj.currentQueryResultsDisplayed = false
obj.showQueryResultsTimer = nil

obj.spotlight = hs.spotlight.new()

-- hammerspoon passes .* as empty query
EMPTY_QUERY = ".*"

-- Private functions

local stopCurrentSearch = function()
    if obj.spotlight:isRunning() then
        obj.spotlight:stop()
    end
    if obj.showQueryResultsTimer ~= nil and obj.showQueryResultsTimer:running() then
        obj.showQueryResultsTimer:stop()
    end
end

local displayQueryResults = function()
    stopCurrentSearch()
    if not obj.currentQueryResultsDisplayed then
        obj.currentQueryResultsDisplayed = true
        -- we force seal to refresh the choices so we can serve the real query results
        obj.seal.chooser:refreshChoicesCallback()
    end
end

local buildSpotlightQuery = function(query)
    local queryWords = hs.fnutils.split(query, "%s+")
    local searchFilters = hs.fnutils.map(queryWords, function(word)
        return [[kMDItemFSName like[c] "*]] .. word .. [[*"]]
    end)
    local spotligthQuery = table.concat(searchFilters, [[ && ]])
    return spotligthQuery
end

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

local updateQueryResults = function(items)
    for _, item in ipairs(items) do
        if #obj.currentQueryResults >= obj.maxQueryResults then
            break
        end
        table.insert(obj.currentQueryResults, convertSpotlightResultToQueryResult(item))
    end
end

local handleSpotlightCallback = function(_, msg, info)
    if msg == "inProgress" and info.kMDQueryUpdateAddedItems ~= nil then
        updateQueryResults(info.kMDQueryUpdateAddedItems)
    end

    if msg == "didFinish" or #obj.currentQueryResults >= obj.maxQueryResults then
        displayQueryResults()
    end
end

-- Public methods

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
    stopCurrentSearch()

    if query == EMPTY_QUERY then
        obj.currentQuery = ""
        obj.currentQueryResults = {}
        return {}
    end

    if query ~= obj.currentQuery then
        -- Seal want the results synchronously, but spotlight will return then asynchronously
        -- to workaround that, we launch the spotlight search in the background and
        -- return the previous results (so that Seal doesn't change the current results list)
        -- We force a refresh later once we have the results
        local previousResults = obj.currentQueryResults
        obj.currentQuery = query
        obj.currentQueryResults = {}
        obj.currentQueryResultsDisplayed = false

        obj.spotlight:queryString(buildSpotlightQuery(query)):start()
        obj.showQueryResultsTimer = hs.timer.doAfter(obj.displayResultsTimeout, displayQueryResults)

        return previousResults
    else
        -- If we are here, it's mean the force refreshed has been triggered after receving spotlight results
        -- we just return the results we accumulated from spotlight
        return obj.currentQueryResults
    end

end

obj.spotlight:searchScopes(obj.fileSearchPaths):callbackMessages("inProgress", "didFinish"):setCallback(
    handleSpotlightCallback)

return obj

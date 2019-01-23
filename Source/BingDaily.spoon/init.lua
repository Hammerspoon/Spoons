--- === BingDaily ===
---
--- Use Bing daily picture as your wallpaper, automatically.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/BingDaily.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/BingDaily.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "BingDaily"
obj.version = "1.0"
obj.author = "ashfinal <ashfinal@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- BingDaily.changeAllSpaces
--- Variable
--- If `true` Spoon will set background image to all desktops (spaces).
--- MacOS doesn't have nice API for it, so
--- we're using hack - set watcher to space change and set Bing image to active space
--- Default: false
obj.changeAllSpaces = false

-- Path to recently downloaded image from Bing
obj.recentImage = nil
-- Space watcher object
obj.spaceWatcher = nil

local function setDesktopImgFromRecent()
    if obj.recentImage and obj.recentImage ~= hs.screen.mainScreen():desktopImageURL() then
        hs.screen.mainScreen():desktopImageURL(obj.recentImage)
    end
end

local function curl_callback(exitCode, stdOut, stdErr)
    if exitCode == 0 then
        obj.task = nil
        obj.last_pic = hs.http.urlParts(obj.full_url).lastPathComponent
        obj.recentImage = "file://" .. os.getenv("HOME") .. "/.Trash/" .. hs.http.urlParts(obj.full_url).lastPathComponent
        setDesktopImgFromRecent()
    else
        print(stdOut, stdErr)
    end
end

local function bingRequest()
    local user_agent_str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/603.2.4 (KHTML, like Gecko) Version/10.1.1 Safari/603.2.4"
    local json_req_url = "http://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1"
    hs.http.asyncGet(json_req_url, {["User-Agent"]=user_agent_str}, function(stat,body,header)
        if stat == 200 then
            if pcall(function() hs.json.decode(body) end) then
                local decode_data = hs.json.decode(body)
                local pic_url = decode_data.images[1].url
                local pic_name = hs.http.urlParts(pic_url).lastPathComponent
                if obj.last_pic ~= pic_name then
                    obj.full_url = "https://www.bing.com" .. pic_url
                    if obj.task then
                        obj.task:terminate()
                        obj.task = nil
                    end
                    local localpath = os.getenv("HOME") .. "/.Trash/" .. hs.http.urlParts(obj.full_url).lastPathComponent
                    obj.task = hs.task.new("/usr/bin/curl", curl_callback, {"-A", user_agent_str, obj.full_url, "-o", localpath})
                    obj.task:start()
                end
            end
        else
            print("Bing URL request failed!")
        end
    end)
end

function obj:init()
end

function obj:start()
    if obj.timer == nil then
        obj.timer = hs.timer.doEvery(3*60*60, function() bingRequest() end)
        obj.timer:setNextTrigger(5)
    else
        obj.timer:start()
    end

    if obj.changeAllSpaces then
        obj.spaceWatcher = hs.spaces.watcher.new(setDesktopImgFromRecent)
        obj.spaceWatcher:start()
    end
end

function obj:stop()
    if obj.spaceWatcher then obj.spaceWatcher:stop() end
    if obj.timer then obj.timer:stop() end
end

return obj

--- === BingDaily ===
---
--- Use Bing daily picture as your wallpaper, automatically.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/BingDaily.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/BingDaily.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "BingDaily"
obj.version = "1.1"
obj.author = "ashfinal <ashfinal@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- BingDaily.uhd_resolution
--- Variable
--- If `true`, download image in UHD resolution instead of HD. Defaults to `false`.
obj.uhd_resolution = false

--- BingDaily.screens
--- Variable
--- Set this to a function that returns a list of screens on which to configure
--- the desktop image, instead of hs.screen.allScreens
obj.screens = hs.screen.allScreens

--- BingDaily.runAt
--- Variable
--- Set this to a time at which the wallpaper should be refreshed daily, eg,
--- `"06:00"`. If this is not set, the wallpaper will be updated every 3 hours. If
--- this is used, you must call `spoon.BingDaily:start()` after configuring.
obj.runAt = nil

local function curl_callback(exitCode, stdOut, stdErr)
    if exitCode == 0 then
        obj.task = nil
        obj.last_pic = obj.file_name
        local localpath = os.getenv("HOME") .. "/.Trash/" .. obj.file_name
        for _,screen in ipairs(obj.screens()) do
            screen:desktopImageURL("file://" .. localpath)
        end
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
                if obj.uhd_resolution then
                    pic_url = pic_url:gsub("1920x1080", "UHD")
                end
                local pic_name = "pic-temp-spoon.jpg"
                for k, v in pairs(hs.http.urlParts(pic_url).queryItems) do
                    if v.id then
                        pic_name = v.id
                        break
                    end
                end
                if obj.last_pic ~= pic_name then
                    obj.file_name = pic_name
                    obj.full_url = "https://www.bing.com" .. pic_url
                    if obj.task then
                        obj.task:terminate()
                        obj.task = nil
                    end
                    local localpath = os.getenv("HOME") .. "/.Trash/" .. obj.file_name
                    obj.task = hs.task.new("/usr/bin/curl", curl_callback, {"-sSf", "-A", user_agent_str, obj.full_url, "-o", localpath})
                    obj.task:start()
                end
            end
        else
            print("Bing URL request failed!")
        end
    end)
end

function obj:start()
    if obj.timer ~= nil then
        obj.timer:stop()
    end
    if obj.runAt ~= nil then
        obj.timer = hs.timer.doAt(obj.runAt, "1d", bingRequest)
    else
        obj.timer = hs.timer.doEvery(3*60*60, bingRequest)
        obj.timer:setNextTrigger(5)
    end
end

function obj:init()
    obj:start()
end

function obj:refresh()
    bingRequest()
end

return obj

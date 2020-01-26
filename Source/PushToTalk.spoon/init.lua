--- === PushToTalk ===
---
--- Implements push-to-talk and push-to-mute functionality with `fn` key.
--- I implemented this after reading Gitlab remote handbook https://about.gitlab.com/handbook/communication/ about Shush utility.
---
--- My workflow:
---
--- When Zoom starts, PushToTalk automatically changes mic state from `default`
--- to `push-to-talk`, so I need to press `fn` key to unmute myself and speak.
--- If I need to actively chat in group meeting or it's one-on-one meeting,
--- I'm switching to `push-to-mute` state, so mic will be unmute by default and `fn` key mutes it.
---
--- PushToTalk has menubar with colorful icons so you can easily see current mic state.
---
--- Sample config: `spoon.SpoonInstall:andUse("PushToTalk", {start = true, config = { app_switcher = { ['zoom.us'] = 'push-to-talk' }}})`
--- and separate keybinding to toggle states with lambda function `function() spoon.PushToTalk.toggleStates({'push-to-talk', 'release-to-talk'}) end`
---
--- Check out my config: https://github.com/skrypka/hammerspoon_config/blob/master/init.lua

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "PushToTalk"
obj.version = "0.1"
obj.author = "Roman Khomenko <roman.dowakin@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.defaultState = 'unmute'

obj.state = obj.defaultState
obj.pushed = false
--- PushToTalk.app_switcher
--- Variable
--- Takes mapping from application name to mic state.
--- For example this `{ ['zoom.us'] = 'push-to-talk' }` will switch mic to `push-to-talk` state when Zoom app starts.
obj.app_switcher = {}

local function showState()
    local device = hs.audiodevice.defaultInputDevice()
    local muted = false
    if obj.state == 'unmute' then
        obj.menubar:setIcon(hs.spoons.resourcePath("speak.pdf"))
    elseif obj.state == 'mute' then
        obj.menubar:setIcon(hs.spoons.resourcePath("muted.pdf"))
        muted = true
    elseif obj.state == 'push-to-talk' then
        if obj.pushed then
            obj.menubar:setIcon(hs.spoons.resourcePath("record.pdf"), false)
        else
            obj.menubar:setIcon(hs.spoons.resourcePath("unrecord.pdf"))
            muted = true
        end
    elseif obj.state == 'release-to-talk' then
        if obj.pushed then
            obj.menubar:setIcon(hs.spoons.resourcePath("unrecord.pdf"))
            muted = true
        else
            obj.menubar:setIcon(hs.spoons.resourcePath("record.pdf"), false)
        end
    end

    device:setMuted(muted)
end

function obj.setState(s)
    obj.state = s
    showState()
end

obj.menutable = {
    { title = "UnMuted", fn = function() obj.setState('unmute') end },
    { title = "Muted", fn = function() obj.setState('mute') end },
    { title = "Push-to-talk (fn)", fn = function() obj.setState('push-to-talk') end },
    { title = "Release-to-talk (fn)", fn = function() obj.setState('release-to-talk') end },
}

local function appWatcher(appName, eventType, appObject)
    local new_app_state = obj.app_switcher[appName];
    if (new_app_state) then
        if (eventType == hs.application.watcher.launching) then
            obj.setState(new_app_state)
        elseif (eventType == hs.application.watcher.terminated) then
            obj.setState(obj.defaultState)
        end
    end
end

local function eventTapWatcher(event)
    device = hs.audiodevice.defaultInputDevice()
    if event:getFlags()['fn'] then
        obj.pushed = true
    else
        obj.pushed = false
    end
    showState()
end

--- PushToTalk:init()
--- Method
--- Initial setup. It's empty currently
function obj:init()
end

--- PushToTalk:init()
--- Method
--- Starts menu and key watcher
function obj:start()
    self:stop()
    obj.appWatcher = hs.application.watcher.new(appWatcher)
    obj.appWatcher:start()

    obj.eventTapWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, eventTapWatcher)
    obj.eventTapWatcher:start()

    obj.menubar = hs.menubar.new()
    obj.menubar:setMenu(obj.menutable)
    obj.setState(obj.state)
end

--- PushToTalk:stop()
--- Method
--- Stops PushToTalk
function obj:stop()
    if obj.appWatcher then obj.appWatcher:stop() end
    if obj.eventTapWatcher then obj.eventTapWatcher:stop() end
    if obj.menubar then obj.menubar:delete() end
end

--- PushToTalk:toggleStates()
--- Method
--- Cycle states in order
---
--- Parameters:
---  * states - A array of states to toggle. For example: `{'push-to-talk', 'release-to-talk'}`
function obj:toggleStates(states)
    new_state = states[1]
    for i, v in pairs(states) do
        if v == obj.state then
            new_state = states[(i % #states) + 1]
        end
    end
    obj.setState(new_state)
end

return obj

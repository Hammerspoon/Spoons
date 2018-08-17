--- === MicMute ===
---
--- Microphone Mute Toggle and status indicator
---
--- Download: []()

local obj={}
obj.__index = obj

-- Metadata
obj.name = "MicMute"
obj.version = "1.0"
obj.author = "dctucker <dctucker@github.com>"
obj.homepage = "https://dctucker.com"
obj.license = "MIT - https://opensource.org/licenses/MIT"

function obj:updateMicMute(muted)
	if muted == -1 then
		muted = hs.audiodevice.defaultInputDevice():muted()
	end
	if muted then
		obj.mute_menu:setTitle("📵 Muted")
	else
		obj.mute_menu:setTitle("🎙 On")
	end
end

function obj:toggleMicMute()
	local mic = hs.audiodevice.defaultInputDevice()
	local zoom = hs.application'Zoom'
	if mic:muted() then
		mic:setMuted(false)
		if zoom then
			local ok = zoom:selectMenuItem'Unmute Audio'
			if not ok then
				hs.timer.doAfter(0.5, function()
					zoom:selectMenuItem'Unmute Audio'
				end)
			end
		end
	else
		mic:setMuted(true)
		if zoom then
			local ok = zoom:selectMenuItem'Mute Audio'
			if not ok then
				hs.timer.doAfter(0.5, function()
					zoom:selectMenuItem'Mute Audio'
				end)
			end
		end
	end
	obj:updateMicMute(-1)
end

function obj:init()
	obj.mute_menu = hs.menubar.new()
	obj.mute_menu:setClickCallback(function()
		obj:toggleMicMute()
	end)
	obj:updateMicMute(-1)

	hs.audiodevice.watcher.setCallback(function(arg)
		if string.find(arg, "dIn ") then
			obj:updateMicMute(-1)
		end
	end)
	hs.audiodevice.watcher.start()
end

return obj

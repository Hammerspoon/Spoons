--- === MicMute ===
---
--- Microphone Mute Toggle and status indicator
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MicMute.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/MicMute.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "MicMute"
obj.version = "1.0"
obj.author = "dctucker <dctucker@github.com>"
obj.homepage = "https://dctucker.com"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- User configuration

-- MicMute.display_mode
-- Variable
-- One of: 'text', 'icon', 'both'. It indicates if a text and/or an icon will be shown in the menubar.
obj.display_mode = 'text'

-- MicMute.title_on
-- Variable
-- The text that will be displayed in the menubar when the microphone is on and MicMute.display_mode is either 'text' or 'both'.
obj.title_on  = "🎙 On"

-- MicMute.title_off
-- Variable
-- The text that will be displayed in the menubar when the microphone is off and MicMute.display_mode is either 'text' or 'both'.
obj.title_off = "📵 Muted"

-- MicMute.icon_on
-- Variable
-- The icon that will be displayed in the menubar when the microphone is on and MicMute.display_mode is either 'icon' or 'both'.
obj.icon_on = hs.image.imageFromName('NSTouchBarAudioInputTemplate')

-- MicMute.icon_off
-- Variable
-- The icon that will be displayed in the menubar when the microphone is off and MicMute.display_mode is either 'icon' or 'both'.
obj.icon_off = hs.image.imageFromName('NSTouchBarAudioInputMuteTemplate')

obj.__displayText = obj.display_mode == 'text' or obj.display_mode == 'both'
obj.__displayIcon = obj.display_mode == 'icon' or obj.display_mode == 'both'


function obj:updateMicMute(muted)
	if muted == -1 then
		muted = hs.audiodevice.defaultInputDevice():muted()
	end
	if muted then
		if self.__displayIcon then; obj.mute_menu:setIcon(obj.icon_off); end
		if self.__displayText then; obj.mute_menu:setTitle(obj.title_off); end
	else
		if self.__displayIcon then; obj.mute_menu:setIcon(obj.icon_on); end
		if self.__displayText then; obj.mute_menu:setTitle(obj.title_on); end
	end
end

--- MicMute:toggleMicMute()
--- Method
--- Toggle mic mute on/off
---
--- Parameters:
---  * None
function obj:toggleMicMute()
	local mic = hs.audiodevice.defaultInputDevice()
	local zoom = hs.application'Zoom'
	if mic:muted() then
		mic:setInputMuted(false)
		if zoom then
			local ok = zoom:selectMenuItem'Unmute Audio'
			if not ok then
				hs.timer.doAfter(0.5, function()
					zoom:selectMenuItem'Unmute Audio'
				end)
			end
		end
	else
		mic:setInputMuted(true)
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

--- MicMute:bindHotkeys(mapping, latch_timeout)
--- Method
--- Binds hotkeys for MicMute
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * toggle - This will cause the microphone mute status to be toggled. Hold for momentary, press quickly for toggle.
---  * latch_timeout - Time in seconds to hold the hotkey before momentary mode takes over, in which the mute will be toggled again when hotkey is released. Latch if released before this time. 0.75 for 750 milliseconds is a good value.
function obj:bindHotkeys(mapping, latch_timeout)
	if (self.hotkey) then
		self.hotkey:delete()
	end
	local mods = mapping["toggle"][1]
	local key = mapping["toggle"][2]

	if latch_timeout then
		self.hotkey = hs.hotkey.bind(mods, key, function()
			self:toggleMicMute()
			self.time_since_mute = hs.timer.secondsSinceEpoch()
		end, function()
			if hs.timer.secondsSinceEpoch() > self.time_since_mute + latch_timeout then
				self:toggleMicMute()
			end
		end)
	else
		self.hotkey = hs.hotkey.bind(mods, key, function()
			self:toggleMicMute()
		end)
	end

	return self
end


function obj:init()
	obj.time_since_mute = 0
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

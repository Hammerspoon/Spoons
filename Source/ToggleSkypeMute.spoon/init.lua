--- === ToggleSkypeMute ===
---
--- Provide keybindings for muting/unmuting Skype or Skype for Business
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ToggleSkypeMute.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ToggleSkypeMute.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "ToggleSkypeMute"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- ToggleSkypeMute.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('ToggleSkypeMute')

obj.notifications = true

--- ToggleSkypeMute:toggle(app)
--- Method
--- Toggle Skype between muted/unmuted, whether it is focused or not
---
--- Parameters:
---  * app - name of the application to mute/unmute. Supported values are "Skype" and "Skype for Business". Defaults to "Skype".
---
--- Returns:
---  * None
function obj:toggle(app)
   local which = app or "Skype"
   local skype = hs.appfinder.appFromName(app)
   if not skype then
      return
   end

   local lastapp = nil
   if not skype:isFrontmost() then
      lastapp = hs.application.frontmostApplication()
      skype:activate()
   end

   local mutepath = {"Conversations", "Mute Microphone"}
   local unmutepath = {"Conversations", "Unmute Microphone"}
   local muteitem = skype:findMenuItem(mutepath)
   if muteitem and muteitem.enabled and skype:selectMenuItem(mutepath) then
      if self.notifications then hs.notify.show("Muted " .. app, "", "") end
   elseif skype:selectMenuItem(unmutepath) then
      if self.notifications then hs.notify.show("Unmuted " .. app, "", "") end
   else
      if self.notifications then hs.notify.show("No active conversation in " .. app, "", "") end
   end

   if lastapp then
      lastapp:activate()
   end
end

--- ToggleSkypeMute:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ToggleSkypeMute
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * hello - Say Hello
function obj:bindHotkeys(mapping)
   local def = {
      toggle_skype = function() self:toggle("Skype") end,
      toggle_skype_for_business = function() self:toggle("Skype for Business") end
   }
   hs.spoons.bindHotkeysToSpec(def, mapping)
end

return obj

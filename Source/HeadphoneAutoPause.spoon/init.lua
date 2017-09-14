--- === HeadphoneAutoPause ===
---
--- Play/pause music players when headphones are connected/disconnected
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/HeadphoneAutoPause.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/HeadphoneAutoPause.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "HeadphoneAutoPause"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- HeadphoneAutoPause.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('HeadphoneAutoPause')

--- HeadphoneAutoPause.control
--- Variable
--- Table containing one key per application, with the value indicating whether HeadphoneAutoPause should try to pause/unpause that application in response to the headphone being plugged/unplugged. The key name must ideally correspond to the name of the corresponding `hs.*` module. Default value:
--- ```
--- {
---    itunes = true,
---    spotify = true,
---    deezer = true,
---    vox = false -- Vox has built-in headphone detection support
--- }
--- ```
obj.control = {
   itunes = true,
   spotify = true,
   deezer = true,
   vox = false
}

--- HeadphoneAutoPause.autoResume
--- Variable
--- Boolean value indicating if music should be automatically resumed when headphones are plugged in again. Only works if music was automatically paused when headphones were unplugged.
---
--- Default value: `true`
obj.autoResume = true

--- HeadphoneAutoPause.defaultControlFns(app)
--- Method
--- Generate the most common set of application control definition.
---
--- Parameters:
---  * app - name of the application, with its correct letter casing (i.e. "iTunes"). The name as provided will be used to find the running application, and its lowercase version will be used to find the corresponding `hs.*` module.
---
--- Returns:
---  * A table in the correct format for `HeadphoneAutoPause.controlfns`, using the lower-case value of `app` as the module name (for example, if app = "iTunes", the module loaded will be `hs.itunes`, and assuming the functions `isPlaying()`, `play()` and `pause()` exist in that module.
function obj.defaultControlFns(app)
   local lcapp=string.lower(app)
   return({ appname = app,
            isPlaying = hs[lcapp].isPlaying,
            play = hs[lcapp].play,
            pause = hs[lcapp].pause })
end

--- HeadphoneAutoPause.controlfns
--- Variable
--- Table containing control functions for each application to control.
--- The keys must correspond to the values in `HeadphoneAutoPause.control`, and the value is a table with the following elements:
---  * `appname` - application name (case-sensitive, as the application appears to the system)
---  * `isPlaying` - function that returns a true value if the application is playing
---  * `play` - function that starts playback in the application
---  * `pause` - function that pauses playback in the application
---
--- The default value includes definitions for iTunes, Spotify, Deezer and Vox, using the corresponding functions from `hs.itunes`, `hs.spotify`, `hs.deezer` and `hs.vox`, respectively.
obj.controlfns = {
   itunes = obj.defaultControlFns('iTunes'),
   spotify = obj.defaultControlFns('Spotify'),
   deezer = obj.defaultControlFns('Deezer'),
   vox = { appname = 'Vox',
           isPlaying = function() return (hs.vox.getPlayerState() == 1) end,
           play = hs.vox.play,
           pause = hs.vox.pause,
   }
}

-- Internal cache of previous playback state when headhpones are
-- unplugged, to allow resuming playback automatically only if the app
-- was previously playing.
local wasplaying = {}
-- Internal cache of audio devices and their watcher functions
local devs = {}

--- HeadphoneAutoPause:audiodevwatch(dev_uid, event_name)
--- Method
--- Callback function to use as an audio device watcher, to pause/unpause the application on headphones plugged/unplugged
function obj:audiodevwatch(dev_uid, event_name)
   self.logger.df("Audiodevwatch args: %s, %s", dev_uid, event_name)
   dev = hs.audiodevice.findDeviceByUID(dev_uid)
   if event_name == 'jack' then
      if dev:jackConnected() then
         self.logger.d("Headphones connected")
         if self.autoResume then
            for app, playercontrol in pairs(self.controlfns) do
               if self.control[app] and hs.appfinder.appFromName(playercontrol.appname) and wasplaying[app] then
                  self.logger.df("Resuming playback in %s", playercontrol.appname)
                  hs.notify.show("Headphones plugged", "Resuming " .. playercontrol.appname .. " playback", "")
                  playercontrol.play()
               end
            end
         end
      else
         self.logger.d("Headphones disconnected")
         -- Cache current state to know whether we should resume
         -- when the headphones are connected again
         for app, playercontrol in pairs(self.controlfns) do
            if self.control[app] and hs.appfinder.appFromName(playercontrol.appname) then
               wasplaying[app] = playercontrol.isPlaying()
               if wasplaying[app] then
                  self.logger.df("Pausing %s", playercontrol.appname)
                  hs.notify.show("Headphones unplugged", "Pausing " .. playercontrol.appname, "")
                  playercontrol.pause()
               end
            end
         end
      end
   end
end

--- HeadphoneAutoPause:start()
--- Method
--- Start headphone detection on all audio devices that support it
function obj:start()
   for i,dev in ipairs(hs.audiodevice.allOutputDevices()) do
      if dev:jackConnected() ~= nil then
         if dev.watcherCallback ~= nil then
            self.logger.df("Setting up watcher for audio device %s (UID %s)", dev:name(), dev:uid())
            devs[dev:uid()]=dev:watcherCallback(hs.fnutils.partial(self.audiodevwatch, self))
            devs[dev:uid()]:watcherStart()
         else
            self.logger.w("Your version of Hammerspoon does not support audio device watchers - please upgrade")
         end
      end
   end
end

--- HeadphoneAutoPause:stop()
--- Method
--- Stop headphone detection
function obj:stop()
   for id,dev in pairs(devs) do
      if dev and dev:watcherIsRunning() then
         dev:watcherStop()
         devs[id]=nil 
      end
   end
end

return obj

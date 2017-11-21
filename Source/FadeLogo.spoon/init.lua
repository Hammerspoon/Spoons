--- === FadeLogo ===
---
--- Show a fading-and-zooming image in the center of the screen
---
--- By default the Hammerspoon logo is shown. Typical use is to show it as an indicator when your configuration finishes loading, by adding the following to the bottom of your `~/.hammerspoon/init.lua` file:
--- ```
---   hs.loadSpoon('FadeLogo'):start()
--- ```
--- Which looks like this: http://imgur.com/a/TbZOl
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FadeLogo.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FadeLogo.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "FadeLogo"
obj.version = "0.3"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- FadeLogo.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('FadeLogo')

--- FadeLogo.image
--- Variable
--- Image to display. Must be an `hs.image` object. Defaults to `hs.image.imageFromName(hs.image.systemImageNames.ApplicationIcon)` (the Hammerspoon app icon)
obj.image = hs.image.imageFromName(hs.image.systemImageNames.ApplicationIcon)

--- FadeLogo.image_size
--- Variable
--- `hs.geometry` object specifying the initial size of the image to display in the center of the screen. The image object will be resizes proportionally to fit in this size. Defaults to `hs.geometry.size(w=200, h=200)`
obj.image_size = hs.geometry.size(200, 200)

--- FadeLogo.image_alpha
--- Variable
--- Initial transparency of the image. Defaults to 1.0.
obj.image_alpha = 1.0

--- FadeLogo.zoom
--- Variable
--- Do zoom-and-fade if `true`, otherwise do a regular fade
obj.zoom = true

--- FadeLogo.fade_in_time
--- Variable
--- Number of seconds over which to fade in the image. Defaults to 0.3.
obj.fade_in_time = 0.3

--- FadeLogo.fade_out_time
--- Variable
--- Number of seconds over which to fade out the image. Defaults to 0.5.
obj.fade_out_time = 0.5

--- FadeLogo.run_time
--- Variable
--- Number of seconds to leave the image on the screen when `start()` is called.
obj.run_time = 2.0

--- FadeLogo.zoom_scale_factor
--- Variable
--- Factor by which to scale the image at every iteration during the zoom-and-fade. Defaults to 1.1.
obj.zoom_scale_factor = 1.1

--- FadeLogo.zoom_scale_timer
--- Variable
--- Seconds between the zooming iterations
obj.zoom_scale_timer = 0.01

----------------------------------------------------------------------

-- Internal variable to hold the canvas where the image is drawn
obj.canvas = nil

--- FadeLogo:delete()
--- Method
--- Hide and delete the canvas
function obj:delete()
   if self.canvas then
      self.canvas = self.canvas:delete()
   end
end

--- FadeLogo:show()
--- Method
--- Display the image, fading it in over `fade_in_time` seconds
function obj:show()
   if self.canvas then self:delete() end
   local frame = hs.screen.mainScreen():frame()
   local imgsz = self.image_size
   self.canvas = hs.canvas.new(frame)
   self.canvas[1] = {
      type = 'image',
      image = self.image,
      frame = {
         x = (frame.w - imgsz.w) / 2,
         y = (frame.h - imgsz.h) / 2,
         w = imgsz.w,
         h = imgsz.h,
      },
      imageAlpha = self.image_alpha,
   }
   self.canvas:show(self.fade_in_time)
end

--- FadeLogo:hide()
--- Method
--- Hide the image without zoom, fading it out over `fade_out_time` seconds
function obj:hide()
   self.canvas:hide(self.fade_out_time)
end

--- FadeLogo:zoom_and_fade()
--- Method
--- Zoom-and-fade the image over `fade_out_time` seconds
function obj:zoom_and_fade()
   local canvas=self.canvas
   local size=hs.geometry.new(canvas[1].frame)
   -- This timer will zoom the image while it is fading
   local timer
   timer=hs.timer.doEvery(
      self.zoom_scale_timer,
      function()
         if canvas:isShowing() then
            size:scale(self.zoom_scale_factor)
            canvas[1].frame = {x = size.x, y = size.y, w = size.w, h = size.h }
         else
            timer:stop()
            timer = nil
            self:delete()
         end
   end)
   canvas:hide(self.fade_out_time)
end

--- FadeLogo:start()
--- Method
--- Show the image, wait `run_time` seconds, and then zoom-and-fade it out.
function obj:start(howlong)
   if not howlong then howlong = self.run_time end
   self:show()
   obj._timer = hs.timer.doAfter(howlong, hs.fnutils.partial(self.zoom and self.zoom_and_fade or self.hide, self))
end

return obj

--- === FadeLogo ===
---
--- Show a fading logo
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FadeLogo.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FadeLogo.spoon.zip)

local obj={}
obj.__index = obj

-- Metadata
obj.name = "FadeLogo"
obj.version = "0.1"
obj.author = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- FadeLogo.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('FadeLogo')

obj.image = hs.image.imageFromAppBundle('org.hammerspoon.Hammerspoon')
obj.image_size = {w=200, h=200}
obj.image_alpha = 1.0

obj.show_delay = 0.3
obj.fade_delay = 0.5
obj.default_run = 2.0
obj.scale_factor = 1.1
obj.scale_timer_freq = 0.005
obj.zoom = true

obj.canvas = nil

local scrframe = hs.screen.mainScreen():frame()

function obj:show()
   self.canvas:show(self.show_delay)
end

function obj:hide()
   self.canvas:hide(self.fade_delay)
end

function obj:zoom_and_fade()
   local size=hs.geometry.new(spoon.FadeLogo.canvas:frame())
   local timer=hs.timer.doWhile(
      function() return spoon.FadeLogo.canvas:isShowing() end,
      function()
         spoon.FadeLogo.canvas:frame(size)
         size:scale(self.scale_factor)
      end, self.scale_timer_freq)
   self.canvas:hide(self.fade_delay)
end

function obj:start(howlong)
   if not howlong then howlong = self.default_run end
   self:show()
   hs.timer.doAfter(howlong, hs.fnutils.partial(self.zoom and self.zoom_and_fade or self.hide, self))
end

function obj:init()
   self.canvas = hs.canvas.new(hs.geometry.rect(scrframe.center.x-(self.image_size.w/2), scrframe.center.y-(self.image_size.h/2),
                                                self.image_size.w, self.image_size.h))
   self.canvas[1] = {
      type = 'image',
      image = self.image,
      imageScaling = 'scaleProportionally',
      imageAlpha = self.image_alpha,
   }
end

return obj

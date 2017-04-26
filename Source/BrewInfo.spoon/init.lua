--- === BrewInfo ===
---
--- Display pop-up with Homebrew Formula info, or open their URL
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/BreInfo.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/BrewInfo.spoon.zip)
---
--- You can bind keys to automatically display the output of `brew
--- info` of the currently-selected package name, or to open its
--- homepage. I use it to quickly explore new packages from the output
--- of `brew update`.

local mod={}
mod.__index = mod

-- Metadata
mod.name = "BrewInfo"
mod.version = "1.0"
mod.author = "Diego Zamboni <diego@zzamboni.org>"
mod.homepage = "https://github.com/Hammerspoon/Spoons"
mod.license = "MIT - https://opensource.org/licenses/MIT"

mod.key_show_brew_info = nil
mod.key_open_brew_url = nil

--- BrewInfo.brew_info_delay_sec
--- Variable
--- An integer specifying how long the alerts generated by BrewInfo will stay onscreen
mod.brew_info_delay_sec = 3

--- BrewInfo.brew_info_style
--- Variable
--- A table in conformance with the [hs.alert.defaultStyle](http://www.hammerspoon.org/docs/hs.alert.html#defaultStyle[]) format that specifies the style used by the alerts. Default value: `{ textFont = "Courier New", textSize = 14, radius = 10 }`
mod.brew_info_style = {
   textFont = "Courier New",
   textSize = 14,
   radius = 10
}

-- Internal function to get the currently selected text
function current_selection()
   local elem=hs.uielement.focusedElement()
   if elem then
      return elem:selectedText()
   else
      return nil
   end
end

-- Internal method to show an alert in the configured style
function mod:show(text)
   hs.alert.show(text, self.brew_info_style, self.brew_info_delay_sec)
   return self
end

--- BrewInfo:showBrewInfo(pkg)
--- Method
--- Displays an alert with the output of `brew info <pkg>`
---
--- Parameters:
---  * pkg - name of the package to query
function mod:showBrewInfo(pkg)
   if pkg and pkg ~= "" then
      local info, st, t, rc=hs.execute("/usr/local/bin/brew info " .. pkg)
      if st == nil then
         info = "No information found about formula '" .. pkg .. "'!"
      end
      self:show(info)
   else
      self:show("No package selected.")
   end
   return self
end

--- BrewInfo:showBrewInfoCurSel()
--- Method
--- Display `brew info` using the selected text as the package name
function mod:showBrewInfoCurSel()
   return self:showBrewInfo(current_selection())
end

--- BrewInfo:openBrewURL(pkg)
--- Method
--- Opens the homepage for Formula `pkg`
---
--- Parameters:
---  * pkg - name of the package to query
function mod:openBrewURL(pkg)
   if pkg and pkg ~= "" then
      local j, st, t, rc=hs.execute("/usr/local/bin/brew info --json=v1 " .. pkg )
      if st ~= nil then
         local jd=hs.json.decode(j)
         if jd ~= nil then
            local url=jd[1].homepage
            if url ~= nil then
               hs.urlevent.openURLWithBundle(url, hs.urlevent.getDefaultHandler("http"))
               return
            end
         end
      end
      self:show("An error occurred obtaining information about '" .. pkg .. "'")
   else
      self:show("No package selected.")
   end
   return self
end

--- BrewInfo:openBrewURLCurSel()
--- Method
--- Display `brew info` using the selected text as the package name
function mod:openBrewURLCurSel()
   return self:openBrewURL(current_selection())
end

--- BrewInfo:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for BrewInfo
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * show_brew_info - Show output of `brew info` using the selected text as package name
---   * open_brew_url - Open the homepage of the formula whose name is currently selected
function mod:bindHotkeys(mapping)
   if mapping["show_brew_info"] then
      if (self.key_show_brew_info) then
         self.key_show_brew_info:delete()
      end
      self.key_show_brew_info = hs.hotkey.bindSpec(mapping["show_brew_info"], function() self:showBrewInfoCurSel() end)
   end
   if mapping["open_brew_url"] then
      if (self.key_open_brew_url) then
         self.key_open_brew_url:delete()
      end
      self.key_open_brew_url = hs.hotkey.bindSpec(mapping["open_brew_url"], function() self:openBrewURLCurSel() end)
   end
end

return mod

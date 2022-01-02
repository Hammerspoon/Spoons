--- Friendly Reminder to remind you to hydrate.
---
--- This spoon will display a reminder to hydrate every X minutes.
--- You can change the interval in the `reminder_interval_minutes` variable.
--- You can also customize the day of the week to remind you by setting the `reminder_day_of_week` variable.
---
--- Usage:
--- ```
---     hs.loadSpoon("Hydrate")
---     spoon.Hydrate.reminder_interval_minutes = 60
---     spoon.Hydrate.reminder_days = {"Monday", "Wednesday", "Friday"}
---     spoon.Hydrate:start()
--- ```
---

local obj={}
obj.__index = obj


local Notifier = {}
Notifier.__index = Notifier

-- Metadata
obj.name = "Hydrate"
obj.version = "0.1"
obj.author = "Luiz Marques <luizfelipe.unesp@gmail.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- Hydrate.reminder_interval_minutes
--- Variable
--- Interval in minutes to show the reminder. Default is 30 minutes.
obj.reminder_interval_minutes = 30

--- Hydrate.reminder_days
--- Variable
--- Days of the week to show the reminder. Default is every day.
obj.reminder_days = {
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
}

--- Hydrate.Notifier
--- Method
--- Constructor for the Notifier
---
--- Returns:
---  * The Notifier object
function Notifier:new(parent)
    self.parent = parent
    self.title = "Water Notification"
    self.sound = "Bottle"
    return self
end

--- Notifier:sendNotification(message)
--- Method
--- Sends a notification with the given message
---
--- Parameters:
---  * message - The message to be sent
function Notifier:sendNotification(message)
    self.notification = hs.notify.new({
        title=self.title,
        informativeText=message,
        autoWithdraw=true,
        soundName=self.sound,
        hasActionButton=false,
        hasReplyButton=false,
        withdrawAfter=30,
    }):send()
end


-- Internal function to check if a given value is in a table
local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- Internal function TO unpack table values to be printable
local function tableValues(...) return (hs.inspect(table.pack(...))) end

--- Hydrate:init()
--- Method
--- Initialize spoon
function obj:init()
    print("Initializing " .. self.name .. " " .. self.version)
    self.notifier = Notifier:new(self)
end

--- Hydrate:start()
--- Method
--- Start event handler
function obj:start()
    self.reminder_interval = hs.timer.minutes(self.reminder_interval_minutes) -- seconds
    print("Reminder will run  " .. tableValues(self.reminder_days) .. " every " .. self.reminder_interval_minutes .. " minutes")
    self:handleWaterNotifications()
    return self
end


--- Hydrate.handleWaterNotifications
--- Method
--- Handle notification as a timer event that runs every `self.reminder_interval` minutes
function obj:handleWaterNotifications()
    print("Starting reminder timer")
    hs.timer.doEvery(self.reminder_interval, function()
        if has_value(self.reminder_days, os.date("%A")) then
            msg = "Drink Water, your kidney will thank you!"
                self.notifier:sendNotification(msg)
        end
    end)
end

return obj

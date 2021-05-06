--- === WatchForMeeting ===
---
--- A Spoon to answer the question
--- > Are you in a meeting?
--- 
--- Watches to see if:
--- 1) Zoom is running
--- 2) Are you on a call
--- 3) Are you on mute, is your camera on, and/or are you screen sharing
--- 
--- And then lets you share that information.
--- 
--- # Installation & Basic Usage
--- Download the [Latest Release](https://github.com/asp55/WatchForMeeting/releases/latest) and unzip to `~/.hammerspoon/Spoons/`
--- 
--- To get going right out of the box, in your `~/.hammerspoon/init.lua` add these lines:
--- ```
--- hs.loadSpoon("WatchForMeeting")
--- spoon.WatchForMeeting:start()
--- ```
--- 
--- This will start the spoon monitoring for zoom calls, and come with the default status page, and menubar configurations.
--- 


--We'll store some stuff in an internal table

local _internal = {}

-- create a namespace

local WatchForMeeting={}
WatchForMeeting.__index = WatchForMeeting


-- Metadata
WatchForMeeting.name = "WatchForMeeting"
WatchForMeeting.version = "1.0.0"
WatchForMeeting.author = "Andrew Parnell <aparnell@gmail.com>"
WatchForMeeting.homepage = "https://github.com/asp55/WatchForMeeting"
WatchForMeeting.license = "MIT - https://opensource.org/licenses/MIT"



-------------------------------------------
-- Declare Variables
-------------------------------------------


--- WatchForMeeting.logger
--- Variable
--- hs.logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
WatchForMeeting.logger = hs.logger.new('WatchMeeting')




-- private variable to track if spoon is already running or not. (Makes it easier to find local variables)
_internal.running = false

   -------------------------------------------
   -- Special Variables (stored in _internal and accessed through metamethods defined below)
   -------------------------------------------

   --- WatchForMeeting.sharing
   --- Variable
   --- A Table containing the settings that control sharing.
   ---
   --- | Key | Description | Default |
   --- | --- | ----------- | ------- |
   --- | enabled | Whether or not sharing is enabled.<br/><br/>When false, the spoon will still monitor meeting status to [meetingState](#meetingState), but you will need to write your own automations for what to do with that info. | _true_ |
   --- | useServer | Do you want to use an external server? (See *Configuration Options* below) | _false_ |
   --- | | ↓ _required info when `useServer=false`_ | |
   --- | port | What port to run the self hosted server when WatchForMeeting.sharing.useServer is false. | _8080_ |
   --- | | ↓ _required info when `useServer=true`_ | |
   --- | serverURL | The complete url for the external server, including port. IE: `http://localhost:8080` | _nil_ |
   --- | key | UUID to identify the room. Value is provided when the room is added on the server side. | _nil_ |
   --- | maxConnectionAttempts | Maximum number of connection attempts when using an external server. When less than 0, infinite retrys | _-1_ |
   --- | waitBeforeRetry | Time, in seconds, between connection attempts when using an external server | _5_ |
   ---
   --- # Configuration Options
   --- ## Default
   --- In order to minimize dependencies, by default this spoon uses a [hs.httpserver](https://www.hammerspoon.org/docs/hs.httpserver.html) to host the status page. This comes with a significant downside of: only the last client to load the page will receive status updates. Any previously connected clients will remain stuck at the last update they received before that client connected.
   --- 
   --- Once you are running the spoon, assuming you haven't changed the port (and nothing else is running at that location) you can reach your status page at http://localhost:8080
   --- 
   --- ## Better - MeetingStatusServer
   --- For a better experience I recommend utilizing an external server to receive updates via websockets, and broadcast them to as many clients as you wish to connect.
   --- 
   --- For that purpose I've built [http://github.com/asp55/MeetingStatusServer](http://github.com/asp55/MeetingStatusServer) which runs on node.js and can either be run locally as its own thing, or hosted remotely.
   --- 
   --- If using the external server, you will to create a key to identify your "room" and then provide that information to the spoon. 
   --- In that case, before `spoon.WatchForMeeting:start()` add the following to your `~/.hammerspoon/init.lua`
   --- 
   --- ```
   --- spoon.WatchForMeeting.sharing.useServer = true
   --- spoon.WatchForMeeting.sharing.serverURL="[YOUR SERVER URL]"
   --- spoon.WatchForMeeting.sharing.key="[YOUR KEY]"
   --- ```
   --- 
   --- or 
   --- 
   --- ```
   --- spoon.WatchForMeeting.sharing = {
   ---   useServer = true,
   ---   serverURL = "[YOUR SERVER URL]",
   ---   key="[YOUR KEY]"
   --- }
   --- ```
   --- 
   --- ## Disable
   --- If you don't want to broadcast your status to a webpage, simply disable sharing
   --- ```
   ---   spoon.WatchForMeeting.sharing = {
   ---     enabled = false
   ---   }
   --- ```
   --- 

   _internal.sharingDefaults = {
      enabled = true, 
      useServer = false, 
      port = 8080, 
      serverURL = nil, 
      key = nil, 
      maxConnectionAttempts = -1,  --when less than 0, infinite retrys
      waitBeforeRetry = 5, 
   }
   _internal.sharing = setmetatable({}, {__index=_internal.sharingDefaults})


   --- WatchForMeeting.menubar
   --- Variable
   --- A Table containing the settings that control sharing.
   ---
   --- | Key | Description | Default | 
   --- | --- | ----------- | ------- | 
   --- | enabled | Whether or not to show the menu bar. | _true_ | 
   --- | color | Whether or not to use color icons. | _true_ |
   --- | detailed | Whether or not to use the detailed icon set. | _true_ |
   --- | showFullState | Whether the menubar icon should represent the full state<br/>(IE: Mic On/Off, Video On/Off, & Screen Sharing) | _true_ |
   --- 
   --- 
   --- ## Icons
   --- 
   --- <table>
   ---   <thead>
   ---   <tr>
   ---   <th>
   ---     <code>WatchForMeeting.menuBar = {...}</code> &#8594;
   ---   </th>
   ---   <th><code>color=true,</code><br/><code>detailed=true,</code></th>
   ---   <th><code>color=true,</code><br/><code>detailed=false,</code></th>
   ---   <th><code>color=false,</code><br/><code>detailed=true,</code></th>
   ---   <th><code>color=false,</code><br/><code>detailed=false,</code></th>
   ---   </tr>
   ---   <tr>
   ---   <th>State (See: <a href="#meetingState">WatchForMeeting.meetingState</a>) &#8595;
   ---   </th>
   ---   <th colspan="4"><code>showFullState=true</code> or <code>showFullState=false</code></th>
   ---   </tr>
   ---   </thead>
   ---   <tbody>
   ---     <tr>
   ---       <td>Available</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Free.png" alt="Free slash Available" height="16" /></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Free.png" alt="Free slash Available" height="16" /></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Free.png" alt="Free slash Available" height="16" /></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Free.png" alt="Free slash Available" height="16" /></td>
   ---     </tr>
   ---     <tr>
   ---       <td>Busy</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting.png" alt="In meeting, no additional status" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting.png" alt="In meeting, no additional status" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting.png" alt="In meeting, no additional status" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting.png" alt="In meeting, no additional status" height="16"></td>
   ---     </tr>
   ---   <tr>
   ---   <td></td>
   ---   <th colspan="4"><code>showFullState=true</code> only</th>
   ---   </tr>
   ---     <tr>
   ---       <td>Busy + Mic On</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic.png" alt="In meeting, mic:on, video:off, screensharing:off" height="16"></td>
   ---     </tr>
   ---     <tr>
   ---       <td>Busy + Video On</td>
   ---     <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Vid.png" alt="In meeting, mic:off, video:on, screensharing:off" height="16"></td>
   ---     </tr>
   ---     <tr>
   ---       <td>Busy + Screen Sharing</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Screen.png" alt="In meeting, mic:off, video:off, screensharing:on" height="16"></td>
   ---     </tr>
   ---     <tr>
   ---       <td>Busy + Mic On + Video On</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Vid.png" alt="In meeting, mic:on, video:on, screensharing:off" height="16"></td>
   ---     </tr>
   ---     <tr>
   ---       <td>Busy + Mic On + Screen Sharing</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Screen.png" alt="In meeting, mic:on, video:off, screensharing:on" height="16"></td>
   ---     </tr>
   ---     <tr>
   ---       <td>Busy + Video On + Screen Sharing</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Vid-Screen.png" alt="In meeting, mic:off, video:on, screensharing:on" height="16"></td>
   ---     </tr>
   ---     <tr>
   ---       <td>Busy + Mic On + Video On + Screen Sharing</td>
   ---       <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Detailed/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Color/Minimal/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Detailed/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
   --- <td><img src="https://raw.githubusercontent.com/asp55/WatchForMeeting/main/menubar-icons/Template/Minimal/Meeting-Mic-Vid-Screen.png" alt="In meeting, mic:on, video:on, screensharing:on" height="16"></td>
   ---     </tr>
   ---   </tbody>
   --- </table>


   _internal.menubarDefaults = {
      enabled = true, 
      color = true, 
      detailed = true,
      showFullState = true
   }
   _internal.menubar__newIndex = function (table, key, value)
      if(key=="enabled") then
         if(value) then
            _internal.meetingMenuBar:returnToMenuBar()
            _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
         else
            _internal.meetingMenuBar:removeFromMenuBar()
         end
      else
         _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
      end
   end

   _internal.menubar = setmetatable({}, {__index=_internal.menubarDefaults, __newindex=_internal.menubar__newIndex})

   --- WatchForMeeting.mode
   --- Variable
   --- Number representing which mode WatchForMeeting should be running
   ---
   --- - *0* - Automatic (default)
   --- -- Monitors Zoom and updates status accordingly
   --- - *1* - Busy
   --- -- Fakes a meeting. (Marks as in meeting, and signals that the mic is live, camera is on, and screen is sharing.) Useful when meeting type is not supported (Currently any platform that isn't zoom.)
   _internal.mode = 0

   --- WatchForMeeting.zoom
   --- Variable
   --- (Read-only) The hs.application for zoom if it is running, otherwise nil
   _internal.zoom = nil

   --- WatchForMeeting.meetingState
   --- Variable
   --- (Read-only) Either false (when not in a meeting) or a table (when in a meeting)
   ---
   --- | Value                                                                   | Description  |
   --- | ----------------------------------------------------------------------- | -----------  |
   --- | `false`                                                                 | Available    | 
   --- | `{mic_open = [Boolean],  video_on = [Boolean], sharing = [Boolean] }`   | Busy         |
   _internal.meetingState = false



   -- MetaMethods
   WatchForMeeting = setmetatable(WatchForMeeting, {
      __index = function (table, key)
         if(key=="zoom" or key=="meetingState" or key=="menubar" or key=="mode" or key=="sharing") then
            return _internal[key]
         else
            return rawget( table, key )
         end
      end,
      __newindex = function (table, key, value)
         if(key=="zoom" or key=="meetingState") then
            --skip writing zoom or meeting state to watchformeeting
         elseif(key=="menubar") then
            _internal.menubar = setmetatable(value, {__index=_internal.menubarDefaults, __newindex=_internal.menubar__newIndex})
            if(_internal.menubar.enabled) then 
               _internal.meetingMenuBar:returnToMenuBar()
               _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
            else
               _internal.meetingMenuBar:removeFromMenuBar()
            end
         elseif(key=="mode") then
            if(value == 1) then 
               table:fake()
            else 
               table:auto() 
            end
         elseif(key=="sharing") then

            _internal.sharing = setmetatable(value, {__index=_internal.sharingDefaults})
         else
            return rawset(table, key, value)
         end
      end
   })

-------------------------------------------
-- End of Declare Variables
-------------------------------------------

-------------------------------------------
-- Menu Bar
-------------------------------------------

_internal.meetingMenuBar = hs.menubar.new(false)


function _internal.updateMenuIcon(status, faking)
   if(_internal.menubar.enabled) then 
      local iconPath = 'menubar-icons/'

      if(_internal.menubar.color) then
         iconPath = iconPath..'Color/'
      else
         iconPath = iconPath..'Template/'
      end

      if(_internal.menubar.detailed) then
         iconPath = iconPath..'Detailed/'
      else
         iconPath = iconPath..'Minimal/'
      end
      
      local iconFile = ""
      if(status) then 
         iconFile = "Meeting"
         if(_internal.menubar.showFullState and (status.mic_open or status.video_on or status.sharing)) then
            if(status.mic_open) then iconFile = iconFile.."-Mic" end
            if(status.video_on) then iconFile = iconFile.."-Vid" end
            if(status.sharing) then iconFile = iconFile.."-Screen" end
         end
         if(faking) then iconFile = iconFile.."-Faking" end
         iconFile = iconFile..".pdf"
      else
         iconFile = "Free.pdf"
      end

      _internal.meetingMenuBar:setIcon(hs.spoons.resourcePath(iconPath..iconFile),not _internal.menubar.color)
   end
end

-------------------------------------------
-- End of Menu Bar
-------------------------------------------


-------------------------------------------
-- Web Server
-------------------------------------------
_internal.server = nil 
_internal.websocketStatus = "closed"

local function composeJsonUpdate(meetingState) 
   local message = {action="update", inMeeting=meetingState}
   return hs.json.encode(message)
end

local monitorfile = io.open(hs.spoons.resourcePath("monitor.html"), "r")
local htmlContent = monitorfile:read("*a")
monitorfile:close()

local function selfhostHttpCallback()
   local websocketPath = "ws://"..hs.network.interfaceDetails(hs.network.primaryInterfaces())["IPv4"]["Addresses"][1]..":"..WatchForMeeting.sharing.port.."/ws"
   htmlContent = string.gsub(htmlContent,"%%websocketpath%%",websocketPath)
   return htmlContent, 200, {}
end

local function selfhostWebsocketCallback(msg)
   return composeJsonUpdate(_internal.meetingState)
end
-------------------------------------------
-- End Web Server
-------------------------------------------

-------------------------------------------
-- Zoom Monitor
-------------------------------------------

local function currentlyInMeeting()
   local inMeetingState = (_internal.zoom ~= nil and _internal.zoom:getMenuItems()[2].AXTitle == "Meeting")
   return inMeetingState
end

--declare startStopWatchMeeting before watchMeeting, define it after.
local startStopWatchMeeting = function() end

local watchMeeting = hs.timer.new(0.5, function()

   -- If the second menu isn't called "Meeting" then zoom is no longer in a meeting
    if(currentlyInMeeting() == false) then
      _internal.updateMenuIcon(false)
      -- No longer in a meeting, stop watching the meeting
      startStopWatchMeeting()
      
      if(_internal.server and _internal.websocketStatus == "open") then _internal.server:send(composeJsonUpdate(_internal.meetingState)) end
      return
    else 
      _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
      --Watch for zoom menu items
      local _mic_open = _internal.zoom:findMenuItem({"Meeting", "Unmute Audio"})==nil
      local _video_on = _internal.zoom:findMenuItem({"Meeting", "Start Video"})==nil
      local _sharing = _internal.zoom:findMenuItem({"Meeting", "Start Share"})==nil
      if((_internal.meetingState.mic_open ~= _mic_open) or (_internal.meetingState.video_on ~= _video_on) or (_internal.meetingState.sharing ~= _sharing)) then
         _internal.meetingState = {mic_open = _mic_open, video_on = _video_on, sharing = _sharing}
         WatchForMeeting.logger.d("In Meeting: ", (_internal.meetingState and true)," Open Mic: ",_internal.meetingState.mic_open," Video-ing:",_internal.meetingState.video_on," Sharing",_internal.meetingState.sharing)
         if(_internal.server and _internal.websocketStatus == "open") then _internal.server:send(composeJsonUpdate(_internal.meetingState)) end
      end
   end
end)

startStopWatchMeeting = function()
   if(not _internal.faking) then
      if(_internal.meetingState == false and currentlyInMeeting() == true) then
         _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
         WatchForMeeting.logger.d("Start Meeting")
            _internal.meetingState = {}
            watchMeeting:start()
            watchMeeting:fire()
      elseif(_internal.meetingState and currentlyInMeeting() == false) then
         _internal.updateMenuIcon(false)
         WatchForMeeting.logger.d("End Meeting")
         watchMeeting:stop()
         _internal.meetingState = false
         if(_internal.server and _internal.websocketStatus == "open") then _internal.server:send(composeJsonUpdate(_internal.meetingState)) end
      end
   else
      watchMeeting:stop()
   end
end


local function checkMeetingStatus(window, name, event)
	WatchForMeeting.logger.d("Check Meeting Status",window,name,event)
   _internal.zoom = window:application()   
   startStopWatchMeeting()
end

-- Monitor zoom for running meeting
hs.application.enableSpotlightForNameSearches(true)
_internal.zoomWindowFilter = hs.window.filter.new(false,"ZoomWindowFilterLog",0):setAppFilter('zoom.us')
_internal.zoomWindowFilter:subscribe(hs.window.filter.hasWindow,checkMeetingStatus,true)
_internal.zoomWindowFilter:subscribe(hs.window.filter.hasNoWindows,checkMeetingStatus)
_internal.zoomWindowFilter:subscribe(hs.window.filter.windowDestroyed,checkMeetingStatus)
_internal.zoomWindowFilter:subscribe(hs.window.filter.windowTitleChanged,checkMeetingStatus)
_internal.zoomWindowFilter:pause() 

-------------------------------------------
-- End of Zoom Monitor
-------------------------------------------


_internal.connectionAttempts = 0
_internal.connectionError = false


--Declare function before start connection because they're circular
local function retryConnection()
end
local function stopConnection()
   if(_internal.server) then
      if(getmetatable(_internal.server).stop) then _internal.server:stop() end
      if(getmetatable(_internal.server).close) then _internal.server:close() end
   end
end

local function serverWebsocketCallback(type, message)
   if(type=="open") then
      _internal.websocketStatus = "open"
      _internal.connectionAttempts = 0

      local draft = {action="identify", key=WatchForMeeting.sharing.key, type="room", status={inMeeting=_internal.meetingState}} 
      _internal.server:send(hs.json.encode(draft))
   elseif(type == "closed" and _internal.running) then
      _internal.websocketStatus = "closed"
      if(_internal.connectionError) then
         WatchForMeeting.logger.d("Lost connection to websocket, will not reattempt due to error")
      else
         WatchForMeeting.logger.d("Lost connection to websocket, attempting to reconnect in "..WatchForMeeting.sharing.waitBeforeRetry.." seconds")
         retryConnection()
      end
   elseif(type == "fail") then
      _internal.websocketStatus = "fail"
      if(WatchForMeeting.sharing.maxConnectionAttempts > 0) then
         WatchForMeeting.logger.d("Could not connect to websocket server. attempting to reconnect in "..WatchForMeeting.sharing.waitBeforeRetry.." seconds. (Attempt ".._internal.connectionAttempts.."/"..WatchForMeeting.sharing.maxConnectionAttempts..")")
      else
         WatchForMeeting.logger.d("Could not connect to websocket server. attempting to reconnect in "..WatchForMeeting.sharing.waitBeforeRetry.." seconds. (Attempt ".._internal.connectionAttempts..")")
      end
      retryConnection()
   elseif(type == "received") then
      local parsed = hs.json.decode(message);
      if(parsed.error) then
         _internal.connectionError = true;
         if(parsed.errorType == "badkey") then
            stopConnection()
            hs.showError("")
            WatchForMeeting.logger.e("WatchForMeeting.sharing.key not valid. Make sure that key has been established on the server.")
         end
      else
         WatchForMeeting.logger.d("Websocket Message received: ", hs.inspect.inspect(parsed));
      end

   else
      WatchForMeeting.logger.d("Websocket Callback "..type, message) 
   end
end


local function startConnection() 
   if(WatchForMeeting.sharing) then
      if(WatchForMeeting.sharing.useServer) then
         WatchForMeeting.logger.d("Connecting to server at "..WatchForMeeting.sharing.serverURL)
         _internal.connectionAttempts = _internal.connectionAttempts + 1
         _internal.websocketStatus = "connecting"
         _internal.server = hs.websocket.new(WatchForMeeting.sharing.serverURL, serverWebsocketCallback);
      else
         WatchForMeeting.logger.d("Starting Self Hosted Server on port "..WatchForMeeting.sharing.port)
         _internal.server = hs.httpserver.new()
         _internal.server:websocket("/ws", selfhostWebsocketCallback)
         _internal.websocketStatus = "open"
         _internal.server:setPort(WatchForMeeting.sharing.port)
         _internal.server:setCallback(selfhostHttpCallback)
         _internal.server:start()
      end
   end
end

--redefine retryConnection now that startConnection & stopConnection exist.
retryConnection = function()
   if(WatchForMeeting.sharing.maxConnectionAttempts > 0 and _internal.connectionAttempts >= WatchForMeeting.sharing.maxConnectionAttempts) then 
      WatchForMeeting.logger.e("Maximum Connection Attempts failed")
      stopConnection()
   elseif(_internal.connectionError) then
      stopConnection()
   else
      hs.timer.doAfter(WatchForMeeting.sharing.waitBeforeRetry, startConnection) 
   end
end


function validateShareSettings()
   WatchForMeeting.logger.d("validateShareSettings")
   if(WatchForMeeting.sharing.useServer and (WatchForMeeting.sharing.serverURL==nil or WatchForMeeting.sharing.key==nil)) then
      hs.showError("")
      if(WatchForMeeting.sharing.serverURL==nil) then WatchForMeeting.logger.e("WatchForMeeting.sharing.serverURL required when using a server") end
      if(WatchForMeeting.sharing.key==nil) then WatchForMeeting.logger.e("WatchForMeeting.sharing.key required when using a server") end
      return false
   elseif(not WatchForMeeting.sharing.useServer and WatchForMeeting.sharing.port==nil) then
      hs.showError("")
      WatchForMeeting.logger.e("WatchForMeeting.sharing.port required when self hosting")
      return false
   else
      return true
   end
end


-------------------------------------------
-- Methods
-------------------------------------------


--- WatchForMeeting:start() -> WatchForMeeting
--- Method
--- Starts a WatchForMeeting object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:start()
   if(not _internal.running) then
      _internal.running = true
      if(self.sharing.enabled and validateShareSettings()) then
         startConnection()
      end
 
      if(self.menubar.enabled) then
         _internal.meetingMenuBar:returnToMenuBar()
      end
 
      if(_internal.mode == 1 ) then
         self:fake()
      else
         self:auto()
      end
   end
 
   return self
end
 
--- WatchForMeeting:stop()
--- Method
--- Stops a WatchForMeeting object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:stop()
   _internal.running = false
   stopConnection()
 
   _internal.meetingMenuBar:removeFromMenuBar()
   _internal.zoomWindowFilter:pause()
   return self
end
 
--- WatchForMeeting:start()
--- Method
--- Restarts a WatchForMeeting object
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:restart()
   self:stop()
   return self:start()
end



--- WatchForMeeting:auto()
--- Method
--- Monitors Zoom and updates status accordingly
---
--- Parameters:
---  * None
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:auto()
   _internal.mode = 0

   if(_internal.running) then
      _internal.faking = false
      _internal.meetingState = false
      startStopWatchMeeting()
      
      _internal.meetingMenuBar:setMenu({
         { title = "Meeting Status:", disabled = true },
         { title = "Automatic", checked = true  },
         { title = "Busy", checked = false, fn=function() WatchForMeeting:fake() end }
      })
   
   
      --Update everything
      _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
      if(_internal.server and _internal.websocketStatus == "open") then _internal.server:send(composeJsonUpdate(_internal.meetingState)) end
   
      --turn on the zoom window monitor
      _internal.zoomWindowFilter:resume()
   end
   
   return self
end
 

--- WatchForMeeting:fake(mic_open, video_on, sharing)
--- Method
--- Disables monitoring and reports as being in a meeting. 
--- Useful when meeting type is not supported (currently any platform that isn't zoom.)
---
--- Parameters:
---  * mic_open - A boolean indicating if the mic is open
---  * video_on - A boolean indicating if the video camera is on
---  * sharing - A boolean indicating if screen sharing is on
---
--- Returns:
---  * The spoon.WatchForMeeting object
function WatchForMeeting:fake(_mic_open, _video_on, _sharing)
   _internal.mode = 1
 
   if(_internal.running) then
      _internal.faking = true
      _internal.meetingState = {mic_open = _mic_open, video_on = _video_on, sharing = _sharing}
      startStopWatchMeeting()

      local meetingMenu = {
         { title = "Meeting Status:", disabled = true },
         { title = "Automatic", checked = false, fn=function() WatchForMeeting:auto() end  },
         { title = "Busy", checked = true },
         { title = "-"}
      }
      if(not (_mic_open and _video_on and _sharing)) then
         table.insert(meetingMenu, { title = "Select All", fn=function() WatchForMeeting:fake(true, true, true) end })
      else
         table.insert(meetingMenu, { title = "Select None", fn=function() WatchForMeeting:fake(false, false, false) end })
      end

      table.insert(meetingMenu, { title = "Mic On", indent=1, checked = _internal.meetingState.mic_open, fn=function() WatchForMeeting:fake(not _mic_open, _video_on, _sharing) end})
      table.insert(meetingMenu, { title = "Video On", indent=1, checked = _internal.meetingState.video_on, fn=function() WatchForMeeting:fake(_mic_open, not _video_on, _sharing) end })
      table.insert(meetingMenu, { title = "Sharing Screen", indent=1, checked = _internal.meetingState.sharing, fn=function() WatchForMeeting:fake(_mic_open, _video_on, not _sharing) end })


      if(_mic_open or _video_on or _sharing) then
         table.insert(meetingMenu, { title = "Clear", fn=function() WatchForMeeting:fake(false, false, false) end })
      end
      _internal.meetingMenuBar:setMenu(meetingMenu)
   
      _internal.zoomWindowFilter:pause()
   
      if(_internal.server and _internal.websocketStatus == "open") then _internal.server:send(composeJsonUpdate(_internal.meetingState)) end
      _internal.updateMenuIcon(_internal.meetingState, _internal.faking)
   end
 
   return self
end


-------------------------------------------
-- End of Methods
-------------------------------------------

return WatchForMeeting

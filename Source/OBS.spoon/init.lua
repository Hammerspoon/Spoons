--- === OBS ===
---
--- Control OBS and react to its events, via the obs-websocket plugin.
---
--- Install and configure the obs-websocket plugin first from [their project](https://github.com/obsproject/obs-websocket/releases)
---
--- Note: This Spoon will only work with Hammerspoon 0.9.100 or later.
---
--- Note: This Spoon will only work with obs-websocket 5.0.1 or later, which also requires OBS Studio v27 or later.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/OBS.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/OBS.spoon.zip)
---
--- Example:
--- ```
--- -- This example will start OBS, connect to it, and then start streaming once connected
--- obs = hs.loadSpoon("OBS")
--- obsCallback = function(eventType, eventIntent, eventData)
---   print(eventType)
---   print(eventIntent)
---   print(hs.inspect(eventData))
---
---   if eventType == "SpoonOBSConnected" then
---     obs:request("StartStream")
---   end
--- end
--- obs:init(obsCallback, "localhost", 4444, "password")
--- obs:start()
--- ```

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "OBS"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Connection parameters
obj.host = nil
obj.port = nil
obj.password = nil
obj.eventSubscriptions = nil

-- Event callback
obj.eventCallback = nil

-- Websocket connection
obj.ws = nil

-- Remote info
obj.rpcVersion = 1

-- Logging object
obj.logger = hs.logger.new("OBS.spoon", "info")

--- OBS.eventSubscriptionValues
--- Constant
--- A table of the possible values for the `eventSubscriptions` parameter to [OBS:init()](#init)
---
--- Notes:
---  * The keys are:
---    * `None` - No events
---    * `General` - General events
---    * `Config` - Configuration events
---    * `Scenes` - Scene events
---    * `Inputs` - Input events
---    * `Transitions` - Transition events
---    * `Filters` - Filter events
---    * `Outputs` - Output events
---    * `SceneItems` - Scene item events
---    * `MediaInputs` - Media input events
---    * `Vendors` - Vendor events
---    * `UI` - UI events
---    * `All` - All of the above events
---    * `InputVolumeMeters` - Input volume meter events
---    * `InputActiveStateChanged` - Input active state changed events
---    * `InputShowStateChanged` - Input show state changed events
---    * `SceneItemTransformChanged` - Scene item transform changed events
---  * For more information about these event categories and the events they contain, see the [obs-websocket documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#events)
---  * To combine these as a bitmask, use boolean operators, e.g. `OBS.eventSubscriptionValues.General | OBS.eventSubscriptionValues.Scenes`
---  * The final four values are considered "high volume" events, so are not included in `OBS.eventSubscriptionValues.All` by default
obj.eventSubscriptionValues = {
    ["None"] = 0,
    ["General"] = 1 << 0,
    ["Config"] = 1 << 1,
    ["Scenes"] = 1 << 2,
    ["Inputs"] = 1 << 3,
    ["Transitions"] = 1 << 4,
    ["Filters"] = 1 << 5,
    ["Outputs"] = 1 << 6,
    ["SceneItems"] = 1 << 7,
    ["MediaInputs"] = 1 << 8,
    ["Vendors"] = 1 << 9,
    ["UI"] = 1 << 10,
    ["InputVolumeMeters"] = 1 << 16,
    ["InputActiveStateChanged"] = 1 << 17,
    ["InputShowStateChanged"] = 1 << 18,
    ["SceneItemTransformChanged"] = 1 << 19,
}
local tmp = obj.eventSubscriptionValues
obj.eventSubscriptionValues["All"] = tmp.General | tmp.Config | tmp.Scenes | tmp.Inputs | tmp.Transitions | tmp.Filters | tmp.Outputs | tmp.SceneItems | tmp.MediaInputs | tmp.Vendors | tmp.UI

--- OBS:shouldReconnect
--- Variable
--- Controls whether the websocket connection should be re-established if it is lost. Defaults to `true`
obj.shouldReconnect = true
-- but we need to know when we chose to close the connection, and not reconnect
obj._isClosing = false

--- OBS:reconnectDelay
--- Variable
--- Controls how long to wait, in seconds, before attempting to reconnect to OBS. Defaults to `5`
obj.reconnectDelay = 5

--- OBS:init(eventCallback, host, port[, password, eventSubscriptions])
--- Method
--- Initialisation method
---
--- Parameters:
---  * `eventCallback` - A function to be called when an event is received from OBS. The function will be passed a table containing the event data. The keys of the table are:
---    * `eventType` - The type of event, e.g. `StudioModeStateChanged`
---    * `eventIntent` - The event subscription value that caused this event to be sent, e.g. `OBS.eventSubscriptionValues.General`
---    * `eventData` - A table containing the event data, e.g. `{ "studioModeEnabled": true }`
---  * `host` - The hostname or IP address of the machine running OBS
---  * `port` - The port number that obs-websocket is listening on
---  * `password` - An optional password string that obs-websocket is configured to use
---  * `eventSubscriptions` - An optional number containing the bitmask of the events to subscribe to, see [OBS.eventSubscriptionValues](#eventSubscriptionValues)
---
--- Returns:
---  * None
---
--- Notes:
---  * This method does not connect to OBS, it just sets up the connection parameters for later use
---  * By default, no events are subscribed to, so you will need to set `eventSubscriptions` to something useful if you want to receive events
---  * If you do not wish to supply an `eventCallback`, pass `nil` instead
---  * The events that OBS can produce are documented in the [obs-websocket documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#events)
---  * There are some additional values for `eventType`, specific to this Spoon:
---    * `SpoonOBSConnected` - This event is sent when the websocket connection to OBS is established. All other fields will be `nil`.
---    * `SpoonOBSDisconnected` - This event is sent when the websocket connection to OBS is lost. All other fields will be nil. Return false to inhibit automatic reconnection.
---    * `SpoonRequestResponse` - This event is sent to pass replies to requests made via [OBS:request()](#request). Its `eventIntent` will be nil and the format of its `eventData` table will be:
---      * `requestId` - The ID of the request that this is a reply to
---      * `requestType` - The request type that was made
---      * `requestStatus` - A table containing:
---        * `result` - A bool, `true` if the request succeeded, otherwise `false`
---        * `code` - A number containing the response code
---        * `comment` - An optional string that may contain additional information about the response
---      * `responseData` - An table that contains the response data, if any
---    * `SpoonBatchRequestResponse` - This event is sent to pass replies to batch requests made via [OBS:requestBatch()](#requestBatch). Its `eventIntent` will be nil and the format of its `eventData` table will be:
---      * `requestId` - The ID of the request batch that this is a reply to
---      * `results` - A table containing the results of each request in the batch. Each entry in the table will be a table with the same format as `SpoonRequestResponse`
function obj:init(eventCallback, host, port, password, eventSubscriptions)
    self.eventCallback = eventCallback
    self.host = host
    self.port = port
    self.password = password
    self.eventSubscriptions = eventSubscriptions or self.eventSubscriptionValues.None
end

--- OBS:start()
--- Method
--- Connects to OBS
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:start()
    self._isClosing = false

    self.ws = hs.websocket.new("ws://" .. self.host .. ":" .. self.port, function(event, rawmsg)
        self.logger.df("Received event '%s': %s", event, rawmsg)

        if (event == "open") then
            return
        end

        if (event == "closed") then
            self.logger.f("Connection to OBS closed")
            if (self.eventCallback ~= nil and self.eventCallback("SpoonOBSDisconnected") == false) then
                return
            end

            if (self.shouldReconnect == true) then
                hs.timer.doAfter(self.reconnectDelay, function()
                    if (self._isClosing == false) then
                        self:start()
                    end
                    self._isClosing = false
                end)
            end
            return
        end

        if (event == "fail") then
            self.logger.f("Connection to OBS lost")
            if (self.eventCallback ~= nil and self.eventCallback("SpoonOBSDisconnected") == false) then
                return
            end

            if (self.shouldReconnect == true) then
                self.logger.f("Failed to connect to OBS, will try again in %d seconds", self.reconnectDelay)
                hs.timer.doAfter(self.reconnectDelay, function()
                    if (self._isClosing == false) then
                        self:start()
                    end
                    self._isClosing = false
                end)
            end
            return
        end

        if (event == "received") then
            local msg = hs.json.decode(rawmsg)

            if (msg["op"] == 0) then -- Hello OpCode
                local payload = {
                    ["op"] = 1,
                    ["d"]  = {
                        ["rpcVersion"] = self.rpcVersion,
                        ["eventSubscrpitions"] = self.eventSubscriptions
                    }
                }

                if (msg["d"]["authentication"] ~= nil) then
                    self.logger.df("Performing authentication")

                    local b64secret = hs.base64.encode(hs.hash.bSHA256(self.password .. msg["d"]["authentication"]["salt"]))
                    local sha256resp = hs.hash.bSHA256(b64secret .. msg["d"]["authentication"]["challenge"])
                    local response = hs.base64.encode(sha256resp)
                    payload["d"]["authentication"] = response
                else
                    self.logger.df("No authentication required")
                end

                self:_wsSend(hs.json.encode(payload))
                return
            end

            if (msg["op"] == 2) then -- Identified OpCode
                self.logger.f("Connected to OBS")
                if (self.eventCallback ~= nil) then
                    self.eventCallback("SpoonOBSConnected")
                end
                return
            end

            if (msg["op"] == 5) then -- Event OpCode
                if (self.eventCallback ~= nil) then
                    self.eventCallback(msg["d"]["eventType"], msg["d"]["eventIntent"], msg["d"]["eventData"])
                end
                return
            end

            if (msg["op"] == 7) then -- RequestResponse OpCode
                if (self.eventCallback ~= nil) then
                    self.eventCallback("SpoonRequestResponse", nil, msg["d"])
                end
                return
            end

            if (msg["op"] == 9) then -- RequestBatchResponse OpCode
                if (self.eventCallback ~= nil) then
                    self.eventCallback("SpoonBatchRequestResponse", nil, msg["d"])
                end
                return
            end
        end
    end)
end

--- OBS:stop()
--- Method
--- Disconnects from OBS
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:stop()
    self._isClosing = true
    self.ws:close()
    self.ws = nil
end

--- OBS:updateEventSubscriptions(eventSubscriptions)
--- Method
--- Updates the event subscriptions
---
--- Parameters:
---  * `eventSubscriptions` - A bitmask of the events to subscribe to, see [OBS.eventSubscriptionValues](#eventSubscriptionValues)
---
--- Returns:
---  * None
function obj:updateEventSubscriptions(eventSubscriptions)
    self.eventSubscriptions = eventSubscriptions
    local payload = {
        ["op"] = 3,
        ["d"]  = {
            ["eventSubscrpitions"] = self.eventSubscriptions
        }
    }
    self:_wsSend(hs.json.encode(payload))
end

--- OBS:addEventSubsciption(event)
--- Method
--- Adds an event subscription
---
--- Parameters:
---  * `event` - The event to subscribe to, see [OBS.eventSubscriptionValues](#eventSubscriptionValues)
---
--- Returns:
---  * None
---
--- Notes:
---  * If you wish to add multiple event subscriptions you can use the `|` operator to combine them, e.g. `spoon.OBS:addEventSubscription(spoon.OBS.eventSubscriptionValues.Config | spoon.OBS.eventSubscriptionValues.Scenes)`
function obj:addEventSubscription(event)
    local eventSubscriptions = self.eventSubscriptions | event
    self:updateEventSubscriptions(eventSubscriptions)
end

--- OBS:removeEventSubsciption(event)
--- Method
--- Removes an event subscription
---
--- Parameters:
---  * `event` - The event to unsubscribe from, see [OBS.eventSubscriptionValues](#eventSubscriptionValues)
---
--- Returns:
---  * None
---
--- Notes:
---  * If you wish to remove multiple event subscriptions you can use the `&` operator to combine them, e.g. `spoon.OBS:removeEventSubscription(spoon.OBS.eventSubscriptionValues.Config | spoon.OBS.eventSubscriptionValues.Scenes)`
function obj:removeEventSubscription(event)
    local eventSubscriptions = self.eventSubscriptions & ~event
    self:updateEventSubscriptions(eventSubscriptions)
end

--- OBS:request(requestType[, requestData[, requestId]])
--- Method
--- Sends a request to OBS
---
--- Parameters:
---  * `requestType` - A string containing the type of request to send
---  * `requestData` - An optional table containing the data to send with the request, or nil
---  * `requestId` - An optional string containing the ID of the request
---
--- Returns:
---  * The `requestId` that was sent
---
--- Notes:
---  * If `requestId` is not specified then a random UUID will be generated.
---  * The `requestId` will be passed to your event callback (provided to [OBS:init()](#init)) when the response is received.
---  * Values for `requestType` can be found in the [obs-websocket documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#requests)
function obj:request(requestType, requestData, requestId)
    local requestId = requestId or hs.host.uuid()
    local payload = {
        ["op"] = 6,
        ["d"]  = {
            ["requestType"] = requestType,
            ["requestId"] = requestId
        }
    }

    if (requestData ~= nil) then
        payload["d"]["requestData"] = requestData
    end

    self:_wsSend(hs.json.encode(payload))
    return requestId
end

--- OBS:requestBatch(requests[, haltOnFailure])
--- Method
--- Sends a batch of requests to OBS
---
--- Parameters:
---  * `requests` - A table containing the requests to send
---  * `haltOnFailure` - An optional boolean indicating whether to halt the batch if a request fails, defaults to false
---
--- Returns:
---  * The `requestId` that was sent for the batch
---
--- Notes:
---  * Each request should be a table with the keys:
---    * `requestType` - A string containing the type of request to send, see [OBS:request()](#request)
---    * `requestData` - An optional table containing the data to send with the request, or `nil`
---    * `requestId` - An optional string containing a unique ID for the request
---  * Unlike [OBS:request()](#request) the `requestId` is an auto-generated UUID
---
--- Example:
--- ```lua
--- spoon.OBS:requestBatch({
---  {["requestType"] = "StartVirtualCam"},
---  {["requestType"] = "SetCurrentProgramScene", ["requestData"] = { ["sceneName"] = "FancyScene" }}
--- })
--- ```
function obj:requestBatch(requests, haltOnFailure)
    local requestId = hs.host.uuid()
    local payload = {
        ["op"] = 8,
        ["d"]  = {
            ["requestId"] = requestId,
            ["requests"] = requests
        }
    }
    if (haltOnFailure) then
        payload["d"]["haltOnFailure"] = haltOnFailure
    end

    self:_wsSend(hs.json.encode(payload))
    return requestId
end

--- OBS:setLogLevel(level)
--- Method
--- Sets the logging level for the OBS Spoon
---
--- Parameters:
---  * `level` - A string containing the logging level to use, see [hs.logger.setLogLevel](https://www.hammerspoon.org/docs/hs.logger.html#setLogLevel) for possible values
---
--- Returns:
---  * None
function obj:setLogLevel(level)
    self.logger.setLogLevel(level)
end

-- Private methods
function obj:_wsSend(payload)
    self.logger.df("Sending payload: %s", payload)
    self.ws:send(payload, false)
end

-- Pass our Spoon up to Hammerspoon
return obj

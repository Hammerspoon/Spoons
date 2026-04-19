--- === ElgatoKeyLight ===
---
--- Controls Elgato Key Lights via their local HTTP REST API.
--- Auto-discovers lights with Bonjour/mDNS, turns them on when the camera
--- activates, and exposes hotkeys for brightness up/down and power toggle.

local obj = {}
obj.__index = obj

obj.name    = "ElgatoKeyLight"
obj.version = "1.0"
obj.author  = "Giovanni Lanzani"
obj.license = "MIT"

-- ── Public configuration ────────────────────────────────────────────────────

--- ElgatoKeyLight.brightnessStep
--- Variable
--- The percentage points to add/subtract per key press. Default: 10
obj.brightnessStep = 10

--- ElgatoKeyLight.temperatureStep
--- Variable
--- Mired units to add/subtract per key press. Default: 20 (≈ ~300-500 K per step).
--- Higher Mired = warmer; lower Mired = cooler.
obj.temperatureStep = 20

--- ElgatoKeyLight.defaultBrightness
--- Variable
--- Brightness (1-100) used when the light is turned on by the camera watcher.
obj.defaultBrightness = 50

--- ElgatoKeyLight.defaultTemperature
--- Variable
--- Colour temperature in Mired (143 = 7000 K cool, 344 = 2900 K warm).
--- Default 200 ≈ 5000 K / neutral daylight.
obj.defaultTemperature = 200

--- ElgatoKeyLight.autoOnWithCamera
--- Variable
--- When true, lights turn on automatically whenever a camera starts being used.
obj.autoOnWithCamera = true

-- ── Internal state ───────────────────────────────────────────────────────────

local lights       = {}   -- array of { host=, port=, brightness=, temperature=, on= }
local browser      = nil
local cameraWatchers = {}

local PORT = 9123
local ENDPOINT = "/elgato/lights"

-- ── HTTP helpers ─────────────────────────────────────────────────────────────

local function lightURL(light)
  return string.format("http://%s:%d%s", light.host, light.port or PORT, ENDPOINT)
end

local function getLight(light, callback)
  hs.http.asyncGet(lightURL(light), nil, function(status, body, _)
    if status ~= 200 then return end
    local ok, data = pcall(hs.json.decode, body)
    if ok and data and data.lights and data.lights[1] then
      local l = data.lights[1]
      light.on          = l.on == 1
      light.brightness  = l.brightness
      light.temperature = l.temperature
      if callback then callback(light) end
    end
  end)
end

local function setLight(light, params)
  -- Merge params into cached state
  if params.on          ~= nil then light.on          = params.on end
  if params.brightness  ~= nil then light.brightness  = math.max(3, math.min(100, params.brightness)) end
  if params.temperature ~= nil then light.temperature = math.max(143, math.min(344, params.temperature)) end

  local payload = hs.json.encode({
    numberOfLights = 1,
    lights = {{
      on          = light.on and 1 or 0,
      brightness  = light.brightness  or obj.defaultBrightness,
      temperature = light.temperature or obj.defaultTemperature,
    }}
  })

  hs.http.doAsyncRequest(lightURL(light), "PUT", payload,
    { ["Content-Type"] = "application/json" },
    function(status, _, _)
      if status ~= 200 then
        print(string.format("[ElgatoKeyLight] PUT %s returned %d", lightURL(light), status))
      end
    end)
end

local function forAllLights(fn)
  for _, light in ipairs(lights) do fn(light) end
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- ElgatoKeyLight:turnOn()
--- Method
--- Turns all discovered lights on at the configured default brightness.
function obj:turnOn()
  forAllLights(function(light)
    -- Fetch current state first so we preserve temperature
    getLight(light, function(l)
      setLight(l, {
        on         = true,
        brightness = l.brightness or obj.defaultBrightness,
      })
    end)
  end)
end

--- ElgatoKeyLight:turnOff()
--- Method
--- Turns all discovered lights off.
function obj:turnOff()
  forAllLights(function(light)
    setLight(light, { on = false })
  end)
end

--- ElgatoKeyLight:toggle()
--- Method
--- Toggles all lights on/off based on the first light's state.
function obj:toggle()
  local first = lights[1]
  if not first then return end
  if first.on then
    self:turnOff()
  else
    self:turnOn()
  end
end

--- ElgatoKeyLight:brightnessUp()
--- Method
--- Increases brightness by brightnessStep on all lights.
function obj:brightnessUp()
  forAllLights(function(light)
    local current = light.brightness or obj.defaultBrightness
    setLight(light, {
      on         = true,
      brightness = current + obj.brightnessStep,
    })
  end)
end

--- ElgatoKeyLight:brightnessDown()
--- Method
--- Decreases brightness by brightnessStep on all lights. Turns off if ≤ 0.
function obj:brightnessDown()
  forAllLights(function(light)
    local current   = light.brightness or obj.defaultBrightness
    local newBright = current - obj.brightnessStep
    if newBright <= 0 then
      setLight(light, { on = false })
    else
      setLight(light, { brightness = newBright })
    end
  end)
end

--- ElgatoKeyLight:temperatureUp()
--- Method
--- Makes the light warmer (higher Mired) by temperatureStep on all lights.
function obj:temperatureUp()
  forAllLights(function(light)
    local current = light.temperature or obj.defaultTemperature
    setLight(light, { temperature = current + obj.temperatureStep })
  end)
end

--- ElgatoKeyLight:temperatureDown()
--- Method
--- Makes the light cooler (lower Mired) by temperatureStep on all lights.
function obj:temperatureDown()
  forAllLights(function(light)
    local current = light.temperature or obj.defaultTemperature
    setLight(light, { temperature = current - obj.temperatureStep })
  end)
end

--- ElgatoKeyLight:addLight(host[, port])
--- Method
--- Manually register a light by IP address, in addition to any auto-discovered ones.
function obj:addLight(host, port)
  table.insert(lights, {
    host        = host,
    port        = port or PORT,
    on          = false,
    brightness  = obj.defaultBrightness,
    temperature = obj.defaultTemperature,
  })
  -- Prime the cache with the real state
  getLight(lights[#lights], nil)
  return self
end

-- ── Bonjour discovery ────────────────────────────────────────────────────────

local function alreadyKnown(host)
  for _, l in ipairs(lights) do
    if l.host == host then return true end
  end
  return false
end

local function startDiscovery()
  browser = hs.bonjour.new()
  browser:findServices("_elg._tcp.", function(b, msg, moreExpected, svc)
    if msg == "service" then
      svc:resolve(5, function(resolved, resolveMsg)
        if resolveMsg ~= "resolved" then return end
        local host = resolved:hostname():gsub("%.$", "")  -- strip trailing dot from mDNS name
        local port = resolved:port()
if not alreadyKnown(host) then
          table.insert(lights, {
            host        = host,
            port        = port,
            on          = false,
            brightness  = obj.defaultBrightness,
            temperature = obj.defaultTemperature,
          })
          getLight(lights[#lights], nil)
        end
      end)
    end
  end)
end

-- ── Camera watcher ────────────────────────────────────────────────────────────

local function onCameraInUseChanged(camera, prop, _, _)
  if prop ~= "gone" then return end
  if not obj.autoOnWithCamera then return end

  if camera:isInUse() then
    obj:turnOn()
  else
    -- Check if any *other* camera is still in use before turning off.
    local anyInUse = false
    for _, cam in ipairs(hs.camera.allCameras()) do
      if cam:name() ~= camera:name() and cam:isInUse() then anyInUse = true; break end
    end
    if not anyInUse then
      obj:turnOff()
    end
  end
end

local function startCameraWatchers()
  -- Clear stale watchers
  for _, cam in ipairs(cameraWatchers) do
    cam:setPropertyWatcherCallback(nil)
    cam:stopPropertyWatcher()
  end
  cameraWatchers = {}

  for _, cam in ipairs(hs.camera.allCameras()) do
    cam:setPropertyWatcherCallback(onCameraInUseChanged)
    cam:startPropertyWatcher()
    table.insert(cameraWatchers, cam)
  end
end

-- Re-attach watchers when cameras are plugged/unplugged
local function setupGlobalCameraWatcher()
  hs.camera.setWatcherCallback(function(_, _)
    startCameraWatchers()
  end)
  hs.camera.startWatcher()
end

-- ── Hotkeys ──────────────────────────────────────────────────────────────────

local hotkeys = {}

--- ElgatoKeyLight:bindHotkeys(mapping)
--- Method
--- Binds hotkeys. Recognised keys:
---   toggle          – turn all lights on/off
---   brightnessUp    – increase brightness
---   brightnessDown  – decrease brightness
---   temperatureUp   – warmer colour (higher Mired)
---   temperatureDown – cooler colour (lower Mired)
---   turnOff         – unconditionally turn off all lights
---
--- Example:
---   spoon.ElgatoKeyLight:bindHotkeys({
---     toggle          = { {"ctrl","alt","cmd"}, "l" },
---     brightnessUp    = { {"ctrl","alt","cmd"}, "=" },
---     brightnessDown  = { {"ctrl","alt","cmd"}, "-" },
---     temperatureUp   = { {"ctrl","alt","cmd"}, "]" },
---     temperatureDown = { {"ctrl","alt","cmd"}, "[" },
---     turnOff         = { {"ctrl","alt","cmd"}, "0" },
---   })
function obj:bindHotkeys(mapping)
  for _, hk in ipairs(hotkeys) do hk:delete() end
  hotkeys = {}

  local function bind(action, fn)
    local m = mapping[action]
    if m then
      table.insert(hotkeys, hs.hotkey.bind(m[1], m[2], fn))
    end
  end

  bind("toggle",          function() self:toggle() end)
  bind("brightnessUp",    function() self:brightnessUp() end)
  bind("brightnessDown",  function() self:brightnessDown() end)
  bind("temperatureUp",   function() self:temperatureUp() end)
  bind("temperatureDown", function() self:temperatureDown() end)
  bind("turnOff",         function() self:turnOff() end)

  return self
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

--- ElgatoKeyLight:start()
--- Method
--- Starts Bonjour discovery and camera monitoring.
function obj:start()
  startDiscovery()
  startCameraWatchers()
  setupGlobalCameraWatcher()
  return self
end

--- ElgatoKeyLight:stop()
--- Method
--- Stops all watchers and releases resources.
function obj:stop()
  if browser then browser:stop(); browser = nil end

  for _, cam in ipairs(cameraWatchers) do
    cam:setPropertyWatcherCallback(nil)
    cam:stopPropertyWatcher()
  end
  cameraWatchers = {}
  hs.camera.stopWatcher()

  for _, hk in ipairs(hotkeys) do hk:delete() end
  hotkeys = {}

  lights = {}
  return self
end

return obj

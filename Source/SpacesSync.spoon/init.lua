--- === SpacesSync ===
---
--- Synchronize macOS Spaces across monitors.
---
--- When you switch Spaces on one monitor, all other monitors in the same
--- sync group follow to the matching Space index.
---
--- Monitors are identified by position number (reading order:
--- left-to-right, top-to-bottom). Define sync groups as sets of position
--- numbers.
---
--- **Requirements:**
---  * macOS Sequoia 15.0+ (uses private `hs.spaces` APIs)
---  * Two or more monitors with multiple Spaces configured
---  * "Displays have separate Spaces" must be ON (System Settings > Desktop & Dock > Mission Control)
---  * "Automatically rearrange Spaces based on most recent use" should be OFF
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpacesSync.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpacesSync.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "SpacesSync"
obj.version = "0.2"
obj.author = "John Randall <john@johnrandall.com>"
obj.homepage = "https://github.com/johntrandall/hammerspoon-spaces-sync"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- SpacesSync.logger
--- Variable
--- Logger object used within the Spoon. Set the log level to control verbosity.
---
--- Default log level: `info`. Set to `debug` for verbose watcher state dumps
--- and per-target dispatch details. Set to `warning` to suppress routine sync
--- messages.
---
--- Example:
--- ```lua
--- spoon.SpacesSync.logger.setLogLevel('debug')
--- ```
obj.logger = hs.logger.new('SpacesSync', 'info')

-- ============================================================================
-- VERSION REQUIREMENTS
-- ============================================================================

local TESTED_OS = { major = 15, minor = 5, patch = 0 }
local MIN_OS_MAJOR = 15
local TESTED_HS = "1.1.1"

local function getOSVersion()
  local raw = hs.host.operatingSystemVersion()
  return {
    major = raw.major,
    minor = raw.minor,
    patch = raw.patch,
    str = raw.major .. "." .. raw.minor .. "." .. raw.patch,
  }
end

local function getHSVersion()
  return hs.processInfo.version or "unknown"
end

local function compareVersions(a, b)
  local function parts(v)
    local t = {}
    for n in tostring(v):gmatch("(%d+)") do t[#t + 1] = tonumber(n) end
    return t
  end
  local pa, pb = parts(a), parts(b)
  for i = 1, math.max(#pa, #pb) do
    local va, vb = pa[i] or 0, pb[i] or 0
    if va < vb then return -1 end
    if va > vb then return 1 end
  end
  return 0
end

-- ============================================================================
-- CONFIGURABLE VARIABLES
-- ============================================================================

--- SpacesSync.syncGroups
--- Variable
--- List of sync groups. Each group is a list of monitor position numbers.
--- Positions are assigned in reading order (left-to-right, top-to-bottom).
--- Monitors not in any group are independent.
---
--- Default value: `{ {1, 2} }`
---
--- Examples:
---  * `{ {1, 2} }` — monitors 1 and 2 sync together
---  * `{ {1, 2}, {3, 4} }` — two independent pairs
---  * `{ {1, 2, 3} }` — three monitors sync together
obj.syncGroups = { { 1, 2 } }

--- SpacesSync.switchDelay
--- Variable
--- Delay in seconds between each `hs.spaces.gotoSpace()` call.
--- macOS silently drops rapid back-to-back space switches.
---
--- Default value: `0.3`
obj.switchDelay = 0.3

--- SpacesSync.debounceSeconds
--- Variable
--- Seconds to wait after all switches complete before re-enabling the watcher.
--- Prevents the watcher from reacting to our own programmatic space switches.
---
--- Default value: `0.8`
obj.debounceSeconds = 0.8

--- SpacesSync.defaultHotkeys
--- Variable
--- Default hotkey mapping. Use with `:bindHotkeys()` for a quick setup:
---
--- ```lua
--- spoon.SpacesSync:bindHotkeys(spoon.SpacesSync.defaultHotkeys)
--- ```
---
--- Default value:
--- ```lua
--- {
---   toggle = {{"ctrl", "alt", "cmd"}, "Y"},
--- }
--- ```
obj.defaultHotkeys = {
  toggle = { {"ctrl", "alt", "cmd"}, "Y" },
}

-- ============================================================================
-- INTERNALS
-- ============================================================================

local state = {
  enabled = false,
  lastActiveSpaces = {},
  syncInProgress = false,
  spaceWatcher = nil,
  debounceTimer = nil,
  pendingSyncTimer = nil,  -- tracks the chained doAfter in syncNext
  osBlocked = false,
}

local positionToUUID = {}
local uuidToPosition = {}
local totalScreens = 0

-- ============================================================================
-- POSITION MAP
-- ============================================================================

local function rebuildPositionMap()
  local screens = hs.screen.allScreens()
  local sorted = {}
  for _, s in ipairs(screens) do
    local f = s:frame()
    table.insert(sorted, { uuid = s:getUUID(), x = f.x, y = f.y })
  end
  table.sort(sorted, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)

  positionToUUID = {}
  uuidToPosition = {}
  totalScreens = #sorted
  for i, entry in ipairs(sorted) do
    positionToUUID[i] = entry.uuid
    uuidToPosition[entry.uuid] = i
  end
end

local function getDisplayLabel(uuid)
  local screen = hs.screen.find(uuid)
  local name = screen and screen:name() or uuid:sub(1, 8)
  local pos = uuidToPosition[uuid]
  if pos then
    return name .. " [pos " .. pos .. "/" .. totalScreens .. "]"
  end
  return name
end

-- ============================================================================
-- SYNC GROUP LOOKUP
-- ============================================================================

local function getTargetsFor(triggerUUID)
  local pos = uuidToPosition[triggerUUID]
  if not pos then return nil end

  for _, group in ipairs(obj.syncGroups) do
    local inGroup = false
    for _, gpos in ipairs(group) do
      if gpos == pos then inGroup = true; break end
    end
    if inGroup then
      local targets = {}
      for _, gpos in ipairs(group) do
        if gpos ~= pos then
          local targetUUID = positionToUUID[gpos]
          if targetUUID then
            table.insert(targets, targetUUID)
          else
            obj.logger.w("Group references pos " .. gpos .. " but only " .. totalScreens .. " screens connected")
          end
        end
      end
      return targets
    end
  end
  return nil
end

-- ============================================================================
-- SPACE HELPERS
-- ============================================================================

local function getSpaceIndex(uuid, spaceID)
  local screen = hs.screen.find(uuid)
  if not screen then return nil end
  local spaces = hs.spaces.spacesForScreen(screen)
  if not spaces then return nil end
  for i, sid in ipairs(spaces) do
    if sid == spaceID then return i end
  end
  return nil
end

local function getSpaceAtIndex(uuid, index)
  local screen = hs.screen.find(uuid)
  if not screen then return nil end
  local spaces = hs.spaces.spacesForScreen(screen)
  if not spaces then return nil end
  return spaces[index]
end

local function getSpaceCount(uuid)
  local screen = hs.screen.find(uuid)
  if not screen then return 0 end
  local spaces = hs.spaces.spacesForScreen(screen)
  return spaces and #spaces or 0
end

-- ============================================================================
-- SYNC ENGINE
-- ============================================================================

local function syncTarget(triggerUUID, triggerSpaceID, targetUUID)
  local label = getDisplayLabel(targetUUID)
  local targetCount = getSpaceCount(targetUUID)

  local triggerIndex = getSpaceIndex(triggerUUID, triggerSpaceID)
  if not triggerIndex then
    obj.logger.d("  " .. label .. ": SKIP (trigger space index not found)")
    return
  end

  if triggerIndex > targetCount then
    obj.logger.i("  " .. label .. " (" .. targetCount .. " spaces): SKIP (no space at index " .. triggerIndex .. ")")
    return
  end

  local targetSpaceID = getSpaceAtIndex(targetUUID, triggerIndex)
  if not targetSpaceID then
    obj.logger.d("  " .. label .. ": SKIP (getSpaceAtIndex returned nil)")
    return
  end

  local targetScreen = hs.screen.find(targetUUID)
  if not targetScreen then
    obj.logger.d("  " .. label .. ": SKIP (screen not found)")
    return
  end

  local currentSpace = hs.spaces.activeSpaceOnScreen(targetScreen)
  local currentIdx = getSpaceIndex(targetUUID, currentSpace) or "?"
  if currentSpace == targetSpaceID then
    obj.logger.d("  " .. label .. ": already at index " .. triggerIndex)
    return
  end

  obj.logger.i("  " .. label .. ": index " .. tostring(currentIdx) .. " -> " .. triggerIndex)

  local ok, err = pcall(function()
    hs.spaces.gotoSpace(targetSpaceID)
  end)

  if ok then
    obj.logger.d("  " .. label .. ": dispatched")
  else
    obj.logger.e("  " .. label .. ": ERROR — " .. tostring(err))
  end
end

-- ============================================================================
-- WATCHER
-- ============================================================================

local function setupWatcher()
  if state.spaceWatcher then
    state.spaceWatcher:stop()
  end

  state.lastActiveSpaces = hs.spaces.activeSpaces() or {}

  state.spaceWatcher = hs.spaces.watcher.new(function()
    if not state.enabled then return end
    if state.syncInProgress then
      obj.logger.d("WATCHER: ignored (sync in progress)")
      return
    end

    local currentSpaces = hs.spaces.activeSpaces() or {}

    if obj.logger.level >= 4 then -- debug level
      local parts = {}
      for uuid, spaceID in pairs(currentSpaces) do
        local idx = getSpaceIndex(uuid, spaceID) or "?"
        table.insert(parts, getDisplayLabel(uuid) .. "=idx" .. tostring(idx))
      end
      obj.logger.d("WATCHER: " .. table.concat(parts, ", "))
    end

    -- Find which display changed
    local changedUUID, changedSpaceID, newIndex

    for uuid, spaceID in pairs(currentSpaces) do
      local lastSpaceID = state.lastActiveSpaces[uuid]
      if lastSpaceID and lastSpaceID ~= spaceID then
        local oi = getSpaceIndex(uuid, lastSpaceID) or "?"
        local ni = getSpaceIndex(uuid, spaceID) or "?"
        obj.logger.d("CHANGED: " .. getDisplayLabel(uuid) .. " index " .. tostring(oi) .. " -> " .. tostring(ni))

        if not changedUUID then
          changedUUID = uuid
          changedSpaceID = spaceID
          newIndex = ni
        else
          obj.logger.d("  (multiple changed; syncing first only)")
        end
      end
    end

    if not changedUUID then
      state.lastActiveSpaces = currentSpaces
      return
    end

    -- Find targets for the triggering monitor
    local targets = getTargetsFor(changedUUID)
    if not targets or #targets == 0 then
      obj.logger.d("SKIP: " .. getDisplayLabel(changedUUID) .. " not in any sync group")
      state.lastActiveSpaces = currentSpaces
      return
    end

    local targetNames = {}
    for _, targetUUID in ipairs(targets) do
      table.insert(targetNames, getDisplayLabel(targetUUID))
    end
    obj.logger.i("SYNC: " .. getDisplayLabel(changedUUID) .. " (trigger) -> index " .. tostring(newIndex) .. " | targets: " .. table.concat(targetNames, ", "))

    state.syncInProgress = true

    local function syncNext(i)
      if i > #targets then
        state.lastActiveSpaces = hs.spaces.activeSpaces() or {}

        if obj.logger.level >= 4 then -- debug level
          local parts = {}
          for uuid, spaceID in pairs(state.lastActiveSpaces) do
            local idx = getSpaceIndex(uuid, spaceID) or "?"
            table.insert(parts, getDisplayLabel(uuid) .. "=idx" .. tostring(idx))
          end
          obj.logger.d("DONE: " .. table.concat(parts, ", "))
        end

        if state.debounceTimer then state.debounceTimer:stop() end
        state.debounceTimer = hs.timer.doAfter(obj.debounceSeconds, function()
          state.syncInProgress = false
          state.lastActiveSpaces = hs.spaces.activeSpaces() or {}
          obj.logger.d("Watcher re-enabled")
        end)
        return
      end

      syncTarget(changedUUID, changedSpaceID, targets[i])
      state.pendingSyncTimer = hs.timer.doAfter(obj.switchDelay, function()
        state.pendingSyncTimer = nil
        syncNext(i + 1)
      end)
    end

    syncNext(1)
  end)

  state.spaceWatcher:start()
  obj.logger.d("Watcher started")
end

local function stopWatcher()
  if state.spaceWatcher then
    state.spaceWatcher:stop()
    state.spaceWatcher = nil
    obj.logger.d("Watcher stopped")
  end
end

-- ============================================================================
-- ENVIRONMENT CHECKS
-- ============================================================================

local function checkEnvironment()
  state.osBlocked = false

  -- Check macOS version
  local osVer = getOSVersion()
  if osVer.major < MIN_OS_MAJOR then
    obj.logger.e("macOS " .. MIN_OS_MAJOR .. "+ required (you have " .. osVer.str .. "). Space sync will not activate.")
    state.osBlocked = true
  else
    local testedStr = TESTED_OS.major .. "." .. TESTED_OS.minor .. "." .. TESTED_OS.patch
    if osVer.major ~= TESTED_OS.major or osVer.minor ~= TESTED_OS.minor or osVer.patch ~= TESTED_OS.patch then
      obj.logger.w("Tested on macOS " .. testedStr .. ", you have " .. osVer.str .. ". hs.spaces uses private APIs — behavior may differ.")
    end
  end

  -- Check Hammerspoon version
  local hsVer = getHSVersion()
  if compareVersions(hsVer, TESTED_HS) < 0 then
    obj.logger.w("Tested on Hammerspoon " .. TESTED_HS .. ", you have " .. hsVer .. ". Older versions may behave differently.")
  end

  -- Check macOS Mission Control settings
  local separateSpaces = hs.execute("defaults read com.apple.spaces spans-displays 2>/dev/null"):gsub("%s+", "")
  if separateSpaces == "1" then
    obj.logger.e("'Displays have separate Spaces' is OFF. All monitors share one Space — nothing to sync. Enable it in System Settings > Desktop & Dock > Mission Control (requires logout).")
    state.osBlocked = true
  end

  local mruSpaces = hs.execute("defaults read com.apple.dock mru-spaces 2>/dev/null"):gsub("%s+", "")
  if mruSpaces == "1" then
    obj.logger.w("'Automatically rearrange Spaces based on most recent use' is ON. This reorders Space indices and will break sync. Disable it in System Settings > Desktop & Dock > Mission Control.")
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--- SpacesSync:init()
--- Method
--- Initializes the SpacesSync spoon. Called automatically by `hs.loadSpoon()`.
--- Does not start syncing — call `:start()` to begin.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SpacesSync object
function obj:init()
  return self
end

--- SpacesSync:start()
--- Method
--- Starts Space syncing.
--- Checks macOS version and Mission Control settings, builds the monitor
--- position map, and enables the Space watcher.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SpacesSync object
function obj:start()
  -- Clean up any in-flight state from a previous start()
  if state.enabled then
    self:stop()
  end

  -- Preload extensions to avoid lazy-load latency during sync.
  -- require() alone returns Hammerspoon's lazy proxy without loading the
  -- Objective-C bridge. Touching one function on each module forces the
  -- actual load so it doesn't happen mid-sync.
  require("hs.screen");      local _ = hs.screen.allScreens
  require("hs.spaces");      _ = hs.spaces.activeSpaces
  -- hs.application is loaded as a transitive dependency of hs.spaces.gotoSpace()
  require("hs.application"); _ = hs.application.frontmostApplication
  require("hs.timer");       _ = hs.timer.secondsSinceEpoch

  obj.logger.i("Starting (SpacesSync " .. obj.version .. ")")

  -- Validate configuration
  if type(obj.syncGroups) ~= "table" then
    obj.logger.e("syncGroups must be a table, got " .. type(obj.syncGroups))
    return self
  end
  for gi, group in ipairs(obj.syncGroups) do
    if type(group) ~= "table" then
      obj.logger.e("syncGroups[" .. gi .. "] must be a table, got " .. type(group))
      return self
    end
    if #group < 2 then
      obj.logger.w("syncGroups[" .. gi .. "] has " .. #group .. " member(s) — need at least 2 to sync")
    end
    -- Check for overlapping groups
    for _, pos in ipairs(group) do
      if type(pos) ~= "number" or pos < 1 or pos ~= math.floor(pos) then
        obj.logger.e("syncGroups[" .. gi .. "] contains invalid position: " .. tostring(pos) .. " (must be a positive integer)")
        return self
      end
    end
  end
  -- Detect overlapping groups (same position in multiple groups)
  local positionSeen = {}
  for gi, group in ipairs(obj.syncGroups) do
    for _, pos in ipairs(group) do
      if positionSeen[pos] then
        obj.logger.w("Position " .. pos .. " appears in group " .. positionSeen[pos] .. " and group " .. gi .. " — only the first group will be used for triggers from this monitor")
      else
        positionSeen[pos] = gi
      end
    end
  end
  if type(obj.switchDelay) ~= "number" or obj.switchDelay < 0 then
    obj.logger.e("switchDelay must be a non-negative number, got " .. tostring(obj.switchDelay))
    return self
  end
  if obj.switchDelay < 0.1 then
    obj.logger.w("switchDelay=" .. obj.switchDelay .. "s — macOS may drop rapid gotoSpace() calls (0.3s recommended)")
  end
  if type(obj.debounceSeconds) ~= "number" or obj.debounceSeconds < 0 then
    obj.logger.e("debounceSeconds must be a non-negative number, got " .. tostring(obj.debounceSeconds))
    return self
  end
  if obj.debounceSeconds < 0.3 then
    obj.logger.w("debounceSeconds=" .. obj.debounceSeconds .. "s — watcher may react to its own switches (0.8s recommended)")
  end

  checkEnvironment()

  if state.osBlocked then
    obj.logger.e("Environment checks failed. Space sync will not activate.")
    hs.alert.show("SpacesSync: blocked (see console)")
    return self
  end

  rebuildPositionMap()

  -- Log position map
  obj.logger.i("Screens (" .. totalScreens .. ", reading order):")
  for pos = 1, totalScreens do
    local uuid = positionToUUID[pos]
    if uuid then
      obj.logger.i("  pos " .. pos .. ": " .. getDisplayLabel(uuid))
    end
  end

  -- Log sync groups
  for gi, group in ipairs(obj.syncGroups) do
    local members = {}
    for _, pos in ipairs(group) do
      local uuid = positionToUUID[pos]
      if uuid then
        table.insert(members, "pos " .. pos .. " (" .. getDisplayLabel(uuid) .. ")")
      else
        table.insert(members, "pos " .. pos .. " (not connected)")
      end
    end
    obj.logger.i("Group " .. gi .. ": " .. table.concat(members, ", "))
  end

  -- Log independent monitors
  for pos = 1, totalScreens do
    local uuid = positionToUUID[pos]
    if uuid and not getTargetsFor(uuid) then
      obj.logger.i("Independent: pos " .. pos .. " (" .. getDisplayLabel(uuid) .. ")")
    end
  end

  state.enabled = true
  state.syncInProgress = false
  state.lastActiveSpaces = hs.spaces.activeSpaces() or {}
  setupWatcher()
  hs.alert.show("SpacesSync: ON")
  obj.logger.i("Enabled")

  return self
end

--- SpacesSync:stop()
--- Method
--- Stops Space syncing and cleans up watchers and timers.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SpacesSync object
function obj:stop()
  state.enabled = false
  state.syncInProgress = false
  stopWatcher()
  if state.pendingSyncTimer then
    state.pendingSyncTimer:stop()
    state.pendingSyncTimer = nil
  end
  if state.debounceTimer then
    state.debounceTimer:stop()
    state.debounceTimer = nil
  end
  hs.alert.show("SpacesSync: OFF")
  obj.logger.i("Disabled")
  return self
end

--- SpacesSync:toggle()
--- Method
--- Toggles Space syncing on or off.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SpacesSync object
function obj:toggle()
  if state.enabled then
    self:stop()
  else
    self:start()
  end
  return self
end

--- SpacesSync:isEnabled()
--- Method
--- Returns whether Space syncing is currently active.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean
function obj:isEnabled()
  return state.enabled
end

--- SpacesSync:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for SpacesSync.
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * toggle - Toggle Space syncing on/off
---
--- Returns:
---  * The SpacesSync object
---
--- Notes:
---  * For a quick setup with defaults, use:
---    `spoon.SpacesSync:bindHotkeys(spoon.SpacesSync.defaultHotkeys)`
function obj:bindHotkeys(mapping)
  local def = {
    toggle = function() self:toggle() end,
  }
  hs.spoons.bindHotkeysToSpec(def, mapping)
  return self
end

return obj

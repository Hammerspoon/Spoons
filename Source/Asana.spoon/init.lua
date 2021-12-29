--- === Asana ===
---
--- Simple spoon that creates a new task in Asana with a given name in a given workspace.
---
--- Example configuration (using SpoonInstall.spoon and Seal.spoon):
--- ```
--- -- Load configuration constants used throughout the code
--- consts = require "configConsts" -- just a table
---
--- -- Load Asana spoon and configure it with API key
--- spoon.SpoonInstall:andUse("Asana", { config = { apiKey = consts.asanaApiKey } })
---
--- -- Load Seal and setup user actions to add task to Asana workspaces
--- spoon.SpoonInstall:andUse(
---   "Seal",
---   {
---     fn = function(x)
---       x:loadPlugins({"apps", "calc", "useractions", "rot13"})
---       x.plugins.useractions.actions = {
---         ["New Asana task in " .. consts.asanaWorkWorkspaceName] = {
---           fn = function(y) spoon.Asana:createTask(y, consts.asanaWorkWorkspaceName) end,
---           keyword = "awork"
---         },
---         ["New Asana task in " .. consts.asanaPersonalWorkspaceName] = {
---           fn = function(y) spoon.Asana:createTask(y, consts.asanaPersonalWorkspaceName) end,
---           keyword = "ahome"
---         }
---       }
---       x:refreshAllCommands()
---     end,
---     start = true,
---     hotkeys = { toggle = { "cmd", "space" } }
---   }
--- )
--- ```
---
--- With this setup, adding a new task to Asana is as easy pressing `Command + Space` to launch Seal and entering, e.g., "awork Do that thing I forgot to do".

-----------------------
-- Setup Environment --
-----------------------
-- Create locals for all needed globals so we have access to them
local pairs,ipairs,type,require = pairs,ipairs,type,require

local stringFormat = string.format
local hs = {
  fnutils = hs.fnutils,
  http    = hs.http,
  json    = hs.json,
  notify  = hs.notify,
  logger  = hs.logger,
  inspect = hs.inspect
}

-- Empty environment in this scope, this prevents module from polluting global scope
local _ENV = {}


-------------
-- Private --
-------------
local baseUrl      = "https://app.asana.com/api/1.0"
local reqHeader    = {}
local workspaceIds = {}
local userId       = ""

-- Fetches workspace ids and user id
local function fetchRequiredIds()
  reqHeader = {["Authorization"] = "Bearer " .. apiKey}

  local _, res = hs.http.get(baseUrl .. "/users/me", reqHeader)
  res = hs.json.decode(res)
  userId = res.data.gid
  hs.fnutils.each(
    res.data.workspaces,
    function(x)
      workspaceIds[x.name] = x.gid
    end
  )
end

local function getTaskParameter(val, prefix)
   local v = hs.json.encode(val)
   return "\"" .. prefix .. "\": " .. v
end 

------------
-- Public --
------------
-- luacheck: no global

-- Spoon metadata
name     = "Asana"
version  = "0.2" -- obj.version = "0.1"
author   = "Malo Bourgon"
license  = "MIT - https://opensource.org/licenses/MIT"
homepage = "https://github.com/malob/Asana.spoon"


--- Asana.apiKey (String)
--- Variable
--- A "personal access token" for Asana. You can create one here: https://app.asana.com/0/developer-console
apiKey = ""


-- Thanks to mnz
function tableCopy(tabl)
   local t = {}
   for k,v in pairs(tabl) do
      t[k] = type(v)=="table" and tableCopy(v) or v
   end 
   return t
end

-- Thanks to mnz
function tableMerge(tbl1,tbl2)
   local t = {}
   for k,v in pairs(tbl1) do t[k] = type(v)=="table" and tableCopy(v) or v end
   for k,v in pairs(tbl2) do t[k] = type(v)=="table" and tableCopy(v) or v end 
   return t
end

function getTaskBody(tbl1,tbl2)
   s = stringFormat('{"data": %s}', hs.json.encode(tableMerge(tbl1,tbl2), false))
   return s 
end

--- Asana:createTask(taskName, workspaceName) -> Self
--- Method
--- Creates a new task named `taskName` in the workspace `workspaceName`.
---
--- Parameters:
---  * taskName (String)      - The title of the Asana task.
---  * WorkspaceName (String) - The name of the workspace in which to create the task.
---  * taskParameters (Table) - This is what will be sent as the `data` field of the POST body.
---
---  taskParmeters can be defined in the `configConsts.lua` or be rendered direcly in the 
---  hammerspoon `init.lua` file where the task is registered.
--- 
--- Returns:
---  * Self
---
--- Examples:
---  ```
---  spoon.Asana.createTask("Do that thing I forgot about", "My Company Workspace")
---  ```
function createTask(self, taskName, workspaceName, taskParameters)
  if workspaceIds == {} or userId == "" then fetchRequiredIds() end

  log = hs.logger.new('Asana', 'info')

  local endPoint = baseUrl .. "/tasks"
  local body = getTaskBody({
     workspace = workspaceIds[workspaceName], name = taskName
  }, taskParameters)

  -- Add content type so the server will know how to read the body
  reqHeader = tableMerge(reqHeader, {['Content-Type'] = "application/json; charset=UTF8"})
  
  hs.http.asyncPost(
  endPoint,
  body,
  reqHeader,
  function(code, responseBody)
     if code == 201 then
        hs.notify.show("Asana", "", "New task added to workspace: " .. workspaceName)
     else
        local errorStr = stringFormat("%i: Error adding task.", code)
        hs.notify.show("Asana", "", errorStr)
        log.e(errorStr)
        log.e("responseBody = " .. responseBody)
     end
  end
  )
  return self
end

-- Return the globals now in the environment, which is the module/spoon.
return _ENV

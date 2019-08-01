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

local stringFormat = string.format
local hs = {
  fnutils = hs.fnutils,
  http    = hs.http,
  json    = hs.json,
  notify  = hs.notify
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
  userId = res.data.id
  hs.fnutils.each(
    res.data.workspaces,
    function(x)
      workspaceIds[x.name] = x.id
    end
  )
end


------------
-- Public --
------------
-- luacheck: no global

-- Spoon metadata
name     = "Asana"
version  = "0.1" -- obj.version = "0.1"
author   = "Malo Bourgon"
license  = "MIT - https://opensource.org/licenses/MIT"
homepage = "https://github.com/malob/Asana.spoon"


--- Asana.apiKey (String)
--- Variable
--- A "personal access token" for Asana. You can create one here: https://app.asana.com/0/developer-console
apiKey = ""

--- Asana:createTask(taskName, workspaceName) -> Self
--- Method
--- Creates a new task named `taskName` in the workspace `workspaceName`.
---
--- Example:
--- ```
--- spoon.Asana.createTask("Do that thing I forgot about", "My Company Workspace")
--- ```
---
--- Parameters:
---  * taskName (String)      - The title of the Asana task.
---  * WorkspaceName (String) - The name of the workspace in which to create the task.
---
--- Returns:
---  * Self
function createTask(self, taskName, workspaceName)
  if workspaceIds == {} or userId == "" then fetchRequiredIds() end

  hs.http.asyncPost(
    stringFormat(
      "%s/tasks?assignee=%i&workspace=%i&name=%s",
      baseUrl,
      userId,
      workspaceIds[workspaceName],
      hs.http.encodeForQuery(taskName)
    ),
    "", -- requires empty body
    reqHeader,
    function(code)
      if code == 201 then
        hs.notify.show("Asana", "", "New task added to workspace: " .. workspaceName)
      else
        hs.notify.show("Asana", "", "Error adding task")
      end
    end
  )
  return self
end

-- Return the globals now in the environment, which is the module/spoon.
return _ENV

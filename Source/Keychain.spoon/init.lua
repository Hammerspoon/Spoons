--- === Keychain ===
---
--- Get and Add items from Keychain. Provides no hotkeys and maintains no state
---
--- Example usage:
--- ```lua
---    spoon.Keychain.addItem{service="mynas.local", account="myname", password="secret"}
---    item = spoon.Keychain.getItem{service="mynas.local", account="myname"}
---    print(item.password)
--- ```
---
--- Tyler Thrailkill <tyler.b.thrailkill@gmail.com>
---
--- https://github.com/snowe2010

local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'Keychain'
obj.version = '1.0'
obj.author = 'Tyler Thrailkill <tyler.b.thrailkill@gmail.com>'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

--- Keychain.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Keychain')

local keyTocmd = {
  account = "-a",
  creator = "-c",
  type = "-C",
  kind = "-D",
  comment = "-j",
  label = "-l",
  service = "-s",
  password = "-w"
}

local shortcutToName = {
  acct = "account",
  type = "class",
  ["0x00000007"] = "label",
  svce = "service",
  password = "password"
}

-- Maps the weird short codes to more lua/human friendly name.
-- if k is not found then the key is ignored.
local function filterKeys(k,v, result)
  local var = shortcutToName[k]

  if  var ~= nil then
    v,_ = string.gsub(v, '"(.*)"', "%1") -- remove quotes
    result[var] = v
  else
    -- print("Ignored " .. k .. "=" .. v)
  end

end


--- Keychain:login_keychain(name)
--- Deprecated
--- Retrieve an item from the Login Keychain, returns nil if not found.
---
--- Parameters:
---  * name - The name of the item in the Login Keychain you want to retrieve
---
--- Notes:
---  * Use getItem() instead.
function obj:login_keychain(name)
  result = getItem{label=name}
  if result ~= nil then
    result = result['password']
  end
  return result
end


--- Keychain:getItem(options)
--- Method
--- Retrieve an item from the Login Keychain. Return nil if not found and otherwise a table with found data.
---
--- Parameters:
---  * options is a table with values for what keys to try locate with.
---   * account - account name
---   * creator - creator, must be 4 characters
---   * type - type, must be 4 characters
---   * kind - kind of item
---   * comment - comment 
---   * label - label (defaults to service name)
---   * service - service name
---
--- Notes:
---  * If multiple possibles matches just the first one is found.
function obj:getItem(options)
  local cmd="/usr/bin/security 2>&1 find-generic-password -g"

    for key, value in pairs(keyTocmd) do
      if options[key] ~= nil then
        cmd = cmd .. " " .. value .. " '" .. options[key] .. "'"
      end
    end

    local handle = io.popen(cmd)
    local result = {}

    for line in handle:lines() do
      k,v = string.match(line, "^%s+(.*) ?<.*>=(.*)$")
      if k ~= nil then
        k,_ = string.gsub(k, '"(.*)"', "%1") -- remove quotes
        k,_ = string.gsub(k , "%s$", "") -- trim leading space
        if v ~= "<NULL>" then
          filterKeys(k,v,result)
        end
      else
        k,v = string.match(line, "^(%S+): (.*)$")
        if k ~= nil then
          filterKeys(k,v,result)
        else
          -- noop
          -- only item through here should be "attributes:"
          -- that we don't care about.
          -- print("NO IDEA" .. line)
        end
      end
    end

    local rc = {handle:close()}
    if rc[3] ~=0 then
      return nil
    else
      return result
    end
end

--- Keychain:addItem(options)
--- Method
--- Add generic password to keychain.
---
--- Parameters:
---  * options is a table with values for what keys to try locate with.
---   * password - the password
---   * account - account name (required)
---   * creator - creator, must be 4 characters
---   * type - type, must be 4 characters
---   * kind - kind of item
---   * comment - comment 
---   * label - label (defaults to service name)
---   * service - service name (required)
function obj:addPassword(options)
  
  local cmd="/usr/bin/security add-generic-password"

  for key, value in pairs(keyTocmd) do
    if options[key] ~= nil then
      cmd = cmd .. " " .. value .. " '" .. options[key] .. "'"
    end
  end

  cmd = cmd .. "-w '" .. options.password .. "'"
  local handle = io.popen(cmd)
  local result = handle:read("*a")
 
  handle:close()
  return result
end

return obj

local obj = {}
obj.__index = obj
obj.__name = "seal_viscosity"

function obj:commands()
    return {vpn = {
        cmd = "vpn",
        fn = obj.choicesVPNCommand,
        name = "Viscosity",
        description = "Manage Viscosity connections",
        plugin = obj.__name
        }
    }
end

function obj:bare()
    return nil
end

function obj.getVPNConnections()
    connections = {}
    code, output, descriptor = hs.osascript.applescript([[
        -- Return a string of the_list joined with delimiter
        on join_list(the_list, delimiter)
            set the_string to ""
            set old_delims to AppleScript's text item delimiters
            repeat with the_item in the_list
                if the_string is equal to "" then
                    set the_string to the_string & the_item
                else
                    set the_string to the_string & delimiter & the_item
                end if
            end repeat
            set AppleScript's text item delimiters to old_delims
            return the_string
        end join_list

        tell application "Viscosity"
            set vpn_connections to {}
            repeat with the_connection in connections
                set the end of vpn_connections to (name of the_connection) & tab & (state of the_connection)
            end repeat
            return my join_list(vpn_connections, linefeed)
        end tell
    ]])

    if code == false or output == nil or output == "" then
        return connections
    end

    for line in output:gmatch("[^\r\n]+") do
        parts = {}
        for part in line:gmatch("%S+") do
            table.insert(parts, part)
        end
        state = parts[#parts]
        table.remove(parts, #parts)
        name = table.concat(parts, " ")
        table.insert(connections, {name=name, state=state})
    end
    return connections
end

function obj.disconnectVPN(name)
    code, output, descriptor = hs.osascript.applescript(string.format([[
        -- Return true if VPN is active
        on vpn_is_active(vpn_name)
            tell application "Viscosity"
                repeat with the_connection in connections
                    if (name of the_connection) is equal to vpn_name then
                        if (state of the_connection) is equal to "Connected" then
                            return true
                        else
                            return false
                        end if
                    end if
                end repeat
            end tell
            return false
        end vpn_is_active

        on run argv
            set vpn_name to "%s"
            if my vpn_is_active(vpn_name) then
                tell application "Viscosity"
                    disconnect vpn_name
                end tell
            end if
        end run
    ]], name))
end

function obj.connectVPN(name)
    code, output, descriptor = hs.osascript.applescript(string.format([[
        -- Return true if VPN is active
        on vpn_is_active(vpn_name)
            tell application "Viscosity"
                repeat with the_connection in connections
                    if (name of the_connection) is equal to vpn_name then
                        if (state of the_connection) is equal to "Connected" then
                            return true
                        else
                            return false
                        end if
                    end if
                end repeat
            end tell
            return false
        end vpn_is_active

        -- Connect to specified VPN
        on connect_vpn(vpn_name)
            tell application "Viscosity"
                connect vpn_name
            end tell
        end connect_vpn

        on run argv
            set vpn_name to "%s"
            if my vpn_is_active(vpn_name) then
                log "VPN " & quote & vpn_name & quote & " is already active."
                return
            end if
            connect_vpn(vpn_name)
        end run
    ]], name))
end

function obj.choicesVPNCommand(query)
    local choices = {}
    local connections = obj.getVPNConnections()
    local img_connected = hs.image.imageFromPath(obj.seal.spoonPath.."/viscosity_locked.png")
    local img_disconnected = hs.image.imageFromPath(obj.seal.spoonPath.."/viscosity_unlocked.png")

    for k,v in pairs(connections) do
        name = v["name"]
        if string.match(name:lower(), query:lower()) then
            state = v["state"]
            local choice = {}
            choice["text"] = name
            choice["subText"] = state
            if state == "Connected" then
                choice["image"] = img_connected
            else
                choice["image"] = img_disconnected
            end
            choice["name"] = name
            choice["state"] = state
            choice["plugin"] = obj.__name
            choice["type"] = "toggle"
            table.insert(choices, choice)
        end
    end
    return choices
end

function obj.completionCallback(rowInfo)
    if rowInfo["type"] == "toggle" then
        if rowInfo["state"] == "Connected" then
            obj.disconnectVPN(rowInfo["name"])
        else
            obj.connectVPN(rowInfo["name"])
        end
    end
end

return obj

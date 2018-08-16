-- gauth.lua - do google authenticator calculation
-- written by Teun Vink <github@teun.tv>
-- https://github.com/teunvink/hammerspoon
--
-- modified version of https://github.com/teunvink/hammerspoon/blob/master/gauth.lua:
--   uses internal binary AND operator 
--   uses Hammerspoon's hs.hash.hmacSHA1 instead of a separate sha1 library

local obj={}
obj.__index = obj
-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

local basexx = dofile(obj.spoonPath.."basexx.lua")

-- binary AND operator
local band = function(a, b)
    return a & b
end


-- convert a hex string to binary string
local function hex_to_binary(hex)
  return hex:gsub('..', function(hexval)
    return string.char(tonumber(hexval, 16))
  end)
end


local GAuth = {}

function GAuth.GenCode(skey, value)
    local skey = basexx.from_base32(skey)
    local value = string.char(
        0, 0, 0, 0,
        band(value, 0xFF000000) / 0x1000000,
        band(value, 0xFF0000) / 0x10000,
        band(value, 0xFF00) / 0x100,
        band(value, 0xFF))
    local hash = hex_to_binary(hs.hash.hmacSHA1(skey, value))
    local offset = band(hash:sub(-1):byte(1, 1), 0xF)
    local function bytesToInt(a,b,c,d)
        return a*0x1000000 + b*0x10000 + c*0x100 + d
    end
    hash = bytesToInt(hash:byte(offset + 1, offset + 4))
    hash = band(hash, 0x7FFFFFFF) % 1000000
    return ("%06d"):format(hash)
end

return GAuth

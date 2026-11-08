--- === IPData ===
---
--- IP address lookups from a hotkey, powered by [ipdata](https://ipdata.co).
---
--- Select or copy an address anywhere, press the hotkey, and a card shows where it is, who
--- operates it, who owns it and, with an API key, whether it is a VPN, proxy, Tor exit or known
--- threat. A second hotkey shows your own public IPv4 and IPv6 addresses, and an optional
--- menubar item keeps your IP in view.
---
--- No account is needed: ipdata's free service allows 1,000 city-level lookups per day from
--- your connection. An API key from https://dashboard.ipdata.co unlocks the full record.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/IPData.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/IPData.spoon.zip)
---
--- Example configuration:
--- ```
--- hs.loadSpoon("IPData")
--- spoon.IPData:bindHotkeys({ lookup = {{"cmd", "alt"}, "i"}, myip = {{"cmd", "alt"}, "m"} })
--- spoon.IPData.apiKey = "your-key"   -- optional, or click "Add API key…" on a card
--- spoon.IPData:startMenubar()        -- optional: flag and IPv4 in the menubar
--- ```

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "IPData"
obj.version = "1.0"
obj.author = "ipdata"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- IPData.apiKey
--- Variable
--- Optional ipdata API key (string); unlocks the full record. Default: nil.
---
--- With a key, lookups call `https://api.ipdata.co` (or the EU endpoint, see `IPData.endpoint`)
--- and return company, carrier, time zone, currency, languages and threat intelligence with
--- trust, VPN, proxy and threat scores. Without a key the free service at `https://ipdata.co`
--- is used. A key set here takes priority over one saved with `IPData:setApiKey()` (which
--- "Add API key…" on a card and in the menubar menu opens).
obj.apiKey = nil

--- IPData.endpoint
--- Variable
--- Which keyed endpoint to call: "global" (api.ipdata.co) or "eu" (eu-api.ipdata.co). Default: "global".
---
--- Only used when `IPData.apiKey` is set. "eu" keeps requests inside the EU.
obj.endpoint = "global"

--- IPData.cardTimeout
--- Variable
--- Seconds after which the result card closes by itself. Default: 12.
---
--- 0 keeps it open until Escape is pressed or the mouse is clicked outside it. The countdown
--- pauses while the pointer is over the card.
obj.cardTimeout = 12

--- IPData.cardPosition
--- Variable
--- Where the card appears: "mouse" (next to the pointer) or "center". Default: "mouse".
---
--- "mouse" mirrors the Chrome extension's card under a selection; "center" puts the card in
--- the middle of the main screen.
obj.cardPosition = "mouse"

--- IPData.appearance
--- Variable
--- Card appearance: "system" (follows macOS), "light" or "dark". Default: "system".
---
--- The sun/moon button in a card's corner switches it and remembers the choice in Hammerspoon's
--- settings; switching back to the appearance macOS is using returns to "system". A value set in
--- init.lua takes priority.
obj.appearance = ({ light = "light", dark = "dark" })[hs.settings.get("ipdata.appearance") or ""] or "system"

--- IPData.showAsAlert
--- Variable
--- When true, results are shown as a one-line `hs.alert` instead of the card. Default: false.
---
--- The line reads "City, Country · ASxxxx Operator", preceded by the flag and the address.
obj.showAsAlert = false

--- IPData.cacheTTL
--- Variable
--- Seconds a lookup result stays in the in-memory cache. Default: 3600 (one hour).
---
--- Your own addresses are cached for two minutes regardless of this value.
obj.cacheTTL = 3600

--- IPData.menubarRefresh
--- Variable
--- Seconds between menubar refreshes once `IPData:startMenubar()` has been called. Default: 600.
obj.menubarRefresh = 600

--- IPData.logger
--- Variable
--- The `hs.logger` instance used by the Spoon. Default: `hs.logger.new("ipdata")`.
---
--- Raise its level with `spoon.IPData.logger.setLogLevel("debug")` to see every request in
--- the console.
obj.logger = hs.logger.new("ipdata")

-- ---------------------------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------------------------

-- The free service answers on ipdata.co (JSON for non-browser clients) and on ipdata.free;
-- ipdata.co is primary and ipdata.free the fallback when it cannot be reached.
local FREE_BASE = "https://ipdata.co"
local FREE_FALLBACK = "https://ipdata.free"
local KEYED_BASE = { global = "https://api.ipdata.co", eu = "https://eu-api.ipdata.co" }
-- Single-stack hostnames for "your connection": v4.ipdata.co only has an A record and
-- v6.ipdata.co only an AAAA record, so each answers with the address of that family.
local SELF_V4 = "https://v4.ipdata.co/"
local SELF_V6 = "https://v6.ipdata.co/"
local SITE_URL = "https://ipdata.co/"
local SETTINGS_KEY = "ipdata.apiKey" -- where setApiKey() keeps the key (hs.settings)
local APPEARANCE_KEY = "ipdata.appearance" -- where the card's sun/moon button keeps its choice
local USER_AGENT = "IPData.spoon/" .. obj.version .. " (Hammerspoon)"
local REQUEST_TIMEOUT = 8   -- seconds before a lookup is given up on
local SELF_TIMEOUT = 6      -- seconds for the v4/v6 self lookups (a missing family fails fast)
local SELF_TTL = 120        -- seconds the user's own addresses stay cached
local ALERT_SECONDS = 4     -- how long the hs.alert fallback stays on screen
local CARD_WIDTH = 320      -- points, the width of a macOS popover

-- ---------------------------------------------------------------------------------------------
-- IP address helpers (ported from the ipdata Chrome extension's lib/ip.js)
-- ---------------------------------------------------------------------------------------------

-- Four decimal octets, 0-255, no leading zeros.
local function isV4(s)
  if type(s) ~= "string" then return false end
  local a, b, c, d = s:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then return false end
  for _, o in ipairs({ a, b, c, d }) do
    if #o > 3 or (#o > 1 and o:sub(1, 1) == "0") or tonumber(o) > 255 then return false end
  end
  return true
end

-- Number of 16-bit groups in one side of an IPv6 address, or nil when the side is malformed.
-- An embedded IPv4 tail ("::ffff:1.2.3.4") counts as two groups and must come last.
local function v6Groups(part)
  if part == "" then return 0 end
  if part:sub(1, 1) == ":" or part:sub(-1) == ":" then return nil end
  local groups = {}
  for g in (part .. ":"):gmatch("([^:]*):") do groups[#groups + 1] = g end
  local n = 0
  for i, g in ipairs(groups) do
    if g == "" then return nil end
    if g:find(".", 1, true) then
      if i ~= #groups or not isV4(g) then return nil end
      n = n + 2
    else
      if #g > 4 or g:find("[^%x]") then return nil end
      n = n + 1
    end
  end
  return n
end

-- Standard IPv6 forms: full, "::" compressed, and IPv4-mapped or embedded tails.
local function isV6(s)
  if type(s) ~= "string" or not s:find(":", 1, true) then return false end
  s = s:lower()
  if s:find("[^%x:%.]") or s:find(":::", 1, true) then return false end
  local first = s:find("::", 1, true)
  if not first then return v6Groups(s) == 8 end
  if s:find("::", first + 2, true) then return false end          -- only one "::"
  local left, right = s:sub(1, first - 1), s:sub(first + 2)
  if left:find(".", 1, true) then return false end                -- an IPv4 tail ends the address
  local nl, nr = v6Groups(left), v6Groups(right)
  if not nl or not nr then return false end
  return nl + nr <= 7
end

-- 4, 6 or 0 for anything else.
local function version(s)
  if isV4(s) then return 4 end
  if isV6(s) then return 6 end
  return 0
end

local function isValid(s) return version(s) > 0 end

-- Turn a token found in text into a bare address, or nil. Handles "[2001:db8::1]:443",
-- "1.2.3.4:8080", "1.2.3.4/24", "https://1.2.3.4/x", "8.8.8.8," and friends.
local function clean(token)
  if type(token) ~= "string" then return nil end
  local t = token:match("^%s*(.-)%s*$")
  t = t:gsub("^%a[%w%+%.%-]*://", "")                 -- URL scheme
  t = t:gsub("^[%s\"'`<({]+", "")                      -- leading punctuation (not '[')
  t = t:match("^([^/?#]*)")                            -- path, query, CIDR suffix
  t = t:gsub("[%s\"'`>)}%.,;!?]+$", "")                -- trailing punctuation (not ']')
  local inner = t:match("^%[([^%]]+)%]$") or t:match("^%[([^%]]+)%]:%d%d?%d?%d?%d?$")
  if inner then
    t = inner
  else
    t = t:gsub("^%[", ""):gsub("%]$", "")
  end
  local host = t:match("^(%d+%.%d+%.%d+%.%d+):%d%d?%d?%d?%d?$")   -- "1.2.3.4:8080"
  if host then t = host end
  t = t:gsub("%%%w+$", "")                             -- IPv6 zone id ("fe80::1%en0")
  if not isValid(t) then return nil end
  if version(t) == 6 and not t:find("%x") then return nil end   -- "::" alone
  return t
end

-- First IP address found in a piece of text, or nil.
local function extract(text)
  if type(text) ~= "string" or text == "" then return nil end
  local direct = clean(text)
  if direct then return direct end
  for tok in text:gmatch("[^%s,;()<>\"'`|=]+") do
    if #tok >= 7 and #tok <= 80 then
      local got = clean(tok)
      if got then return got end
      -- "ip:1.2.3.4", "src=1.2.3.4" and similar prefixes
      for s, v4, e in tok:gmatch("()(%d+%.%d+%.%d+%.%d+)()") do
        local before, after = tok:sub(s - 1, s - 1), tok:sub(e, e)
        if not before:find("[%d%.]") and not after:find("[%d%.]") and clean(v4) then return clean(v4) end
      end
      local rest = tok:match("^[%a_%-]+:(.+)$")
      if rest then
        local g = clean(rest)
        if g then return g end
      end
    end
  end
  return nil
end

-- Human label for addresses that are not routable on the public internet, else nil.
local function reservedLabel(s)
  local v = version(s)
  if v == 4 then
    local o = {}
    for n in s:gmatch("%d+") do o[#o + 1] = tonumber(n) end
    if o[1] == 10 or (o[1] == 172 and o[2] >= 16 and o[2] <= 31) or (o[1] == 192 and o[2] == 168) then
      return "Private network address (RFC 1918)"
    end
    if o[1] == 127 then return "Loopback address" end
    if o[1] == 0 then return "Reserved address (0.0.0.0/8)" end
    if o[1] == 169 and o[2] == 254 then return "Link-local address" end
    if o[1] == 100 and o[2] >= 64 and o[2] <= 127 then return "Carrier-grade NAT address (100.64.0.0/10)" end
    if o[1] == 192 and o[2] == 0 and (o[3] == 0 or o[3] == 2) then return "Reserved or documentation address" end
    if o[1] == 198 and (o[2] == 18 or o[2] == 19) then return "Benchmarking address (198.18.0.0/15)" end
    if (o[1] == 198 and o[2] == 51 and o[3] == 100) or (o[1] == 203 and o[2] == 0 and o[3] == 113) then
      return "Documentation address"
    end
    if o[1] >= 224 and o[1] <= 239 then return "Multicast address" end
    if o[1] >= 240 then return "Reserved address (240.0.0.0/4)" end
    return nil
  elseif v == 6 then
    local l = s:lower()
    local mapped = l:match("^::ffff:(%d+%.%d+%.%d+%.%d+)$")
    if mapped then return reservedLabel(mapped) end
    if l == "::" then return "Unspecified address" end
    if l == "::1" then return "Loopback address" end
    if l:find("^f[cd]%x?%x?:") then return "Unique local address (fc00::/7)" end
    if l:find("^fe[89ab]%x?:") then return "Link-local address (fe80::/10)" end
    if l:find("^ff%x?%x?:") then return "Multicast address" end
    if l:find("^2001:db8:") then return "Documentation address (2001:db8::/32)" end
    return nil
  end
  return "Not an IP address"
end

--- IPData.extractIp(text)
--- Function
--- Finds the first IP address in a piece of text.
---
--- Parameters:
---  * text - A string: a bare address, a URL, a log line, "host:port", "[v6]:port", a CIDR
---    prefix, "key=value" pairs and similar.
---
--- Returns:
---  * The bare IPv4 or IPv6 address as a string, or nil when the text contains none.
obj.extractIp = extract

--- IPData.ipVersion(address)
--- Function
--- Tells whether a string is an IPv4 or an IPv6 address.
---
--- Parameters:
---  * address - A string.
---
--- Returns:
---  * 4, 6, or 0 when the string is not an IP address.
obj.ipVersion = version

--- IPData.reservedLabel(address)
--- Function
--- Describes addresses that are not routable on the public internet.
---
--- Parameters:
---  * address - An IPv4 or IPv6 address as a string.
---
--- Returns:
---  * A label such as "Private network address (RFC 1918)" or "Loopback address", nil for a
---    public address, and "Not an IP address" for anything else.
---
--- Notes:
---  * Such addresses are recognised locally and never sent to ipdata.
obj.reservedLabel = reservedLabel

-- ---------------------------------------------------------------------------------------------
-- Country names (ISO 3166-1 alpha-2 to English, from CLDR; the free tier returns the code only)
-- ---------------------------------------------------------------------------------------------

local COUNTRIES = {
  AC="Ascension Island", AD="Andorra", AE="United Arab Emirates", AF="Afghanistan", AG="Antigua & Barbuda",
  AI="Anguilla", AL="Albania", AM="Armenia", AN="Curaçao", AO="Angola", AQ="Antarctica", AR="Argentina",
  AS="American Samoa", AT="Austria", AU="Australia", AW="Aruba", AX="Åland Islands", AZ="Azerbaijan",
  BA="Bosnia & Herzegovina", BB="Barbados", BD="Bangladesh", BE="Belgium", BF="Burkina Faso", BG="Bulgaria",
  BH="Bahrain", BI="Burundi", BJ="Benin", BL="St. Barthélemy", BM="Bermuda", BN="Brunei", BO="Bolivia",
  BQ="Caribbean Netherlands", BR="Brazil", BS="Bahamas", BT="Bhutan", BU="Myanmar (Burma)", BV="Bouvet Island",
  BW="Botswana", BY="Belarus", BZ="Belize", CA="Canada", CC="Cocos (Keeling) Islands", CD="Congo - Kinshasa",
  CF="Central African Republic", CG="Congo - Brazzaville", CH="Switzerland", CI="Côte d’Ivoire",
  CK="Cook Islands", CL="Chile", CM="Cameroon", CN="China", CO="Colombia", CP="Clipperton Island",
  CQ="Sark", CR="Costa Rica", CU="Cuba", CV="Cape Verde", CW="Curaçao", CX="Christmas Island", CY="Cyprus",
  CZ="Czechia", DD="East Germany", DE="Germany", DG="Diego Garcia", DJ="Djibouti", DK="Denmark", DM="Dominica",
  DO="Dominican Republic", DY="Benin", DZ="Algeria", EA="Ceuta & Melilla", EC="Ecuador", EE="Estonia",
  EG="Egypt", EH="Western Sahara", ER="Eritrea", ES="Spain", ET="Ethiopia", EU="European Union", EZ="Eurozone",
  FI="Finland", FJ="Fiji", FK="Falkland Islands", FM="Micronesia", FO="Faroe Islands", FR="France",
  FX="Metropolitan France", GA="Gabon", GB="United Kingdom", GD="Grenada", GE="Georgia", GF="French Guiana",
  GG="Guernsey", GH="Ghana", GI="Gibraltar", GL="Greenland", GM="Gambia", GN="Guinea", GP="Guadeloupe",
  GQ="Equatorial Guinea", GR="Greece", GS="South Georgia & South Sandwich Islands", GT="Guatemala", GU="Guam",
  GW="Guinea-Bissau", GY="Guyana", HK="Hong Kong SAR China", HM="Heard & McDonald Islands", HN="Honduras",
  HR="Croatia", HT="Haiti", HU="Hungary", HV="Burkina Faso", IC="Canary Islands", ID="Indonesia", IE="Ireland",
  IL="Israel", IM="Isle of Man", IN="India", IO="British Indian Ocean Territory", IQ="Iraq", IR="Iran",
  IS="Iceland", IT="Italy", JE="Jersey", JM="Jamaica", JO="Jordan", JP="Japan", KE="Kenya", KG="Kyrgyzstan",
  KH="Cambodia", KI="Kiribati", KM="Comoros", KN="St. Kitts & Nevis", KP="North Korea", KR="South Korea",
  KW="Kuwait", KY="Cayman Islands", KZ="Kazakhstan", LA="Laos", LB="Lebanon", LC="St. Lucia", LI="Liechtenstein",
  LK="Sri Lanka", LR="Liberia", LS="Lesotho", LT="Lithuania", LU="Luxembourg", LV="Latvia", LY="Libya",
  MA="Morocco", MC="Monaco", MD="Moldova", ME="Montenegro", MF="St. Martin", MG="Madagascar",
  MH="Marshall Islands", MK="North Macedonia", ML="Mali", MM="Myanmar (Burma)", MN="Mongolia",
  MO="Macao SAR China", MP="Northern Mariana Islands", MQ="Martinique", MR="Mauritania", MS="Montserrat",
  MT="Malta", MU="Mauritius", MV="Maldives", MW="Malawi", MX="Mexico", MY="Malaysia", MZ="Mozambique",
  NA="Namibia", NC="New Caledonia", NE="Niger", NF="Norfolk Island", NG="Nigeria", NH="Vanuatu", NI="Nicaragua",
  NL="Netherlands", NO="Norway", NP="Nepal", NR="Nauru", NT="Neutral Zone", NU="Niue", NZ="New Zealand",
  OM="Oman", PA="Panama", PE="Peru", PF="French Polynesia", PG="Papua New Guinea", PH="Philippines",
  PK="Pakistan", PL="Poland", PM="St. Pierre & Miquelon", PN="Pitcairn Islands", PR="Puerto Rico",
  PS="Palestinian Territories", PT="Portugal", PW="Palau", PY="Paraguay", QA="Qatar", QO="Outlying Oceania",
  RE="Réunion", RH="Zimbabwe", RO="Romania", RS="Serbia", RU="Russia", RW="Rwanda", SA="Saudi Arabia",
  SB="Solomon Islands", SC="Seychelles", SD="Sudan", SE="Sweden", SG="Singapore", SH="St. Helena",
  SI="Slovenia", SJ="Svalbard & Jan Mayen", SK="Slovakia", SL="Sierra Leone", SM="San Marino", SN="Senegal",
  SO="Somalia", SR="Suriname", SS="South Sudan", ST="São Tomé & Príncipe", SU="Union of Soviet Socialist Republics",
  SV="El Salvador", SX="Sint Maarten", SY="Syria", SZ="Eswatini", TA="Tristan da Cunha",
  TC="Turks & Caicos Islands", TD="Chad", TF="French Southern Territories", TG="Togo", TH="Thailand",
  TJ="Tajikistan", TK="Tokelau", TL="Timor-Leste", TM="Turkmenistan", TN="Tunisia", TO="Tonga", TP="Timor-Leste",
  TR="Türkiye", TT="Trinidad & Tobago", TV="Tuvalu", TW="Taiwan", TZ="Tanzania", UA="Ukraine", UG="Uganda",
  UK="United Kingdom", UM="U.S. Outlying Islands", UN="United Nations", US="United States", UY="Uruguay",
  UZ="Uzbekistan", VA="Vatican City", VC="St. Vincent & Grenadines", VD="North Vietnam", VE="Venezuela",
  VG="British Virgin Islands", VI="U.S. Virgin Islands", VN="Vietnam", VU="Vanuatu", WF="Wallis & Futuna",
  WS="Samoa", XA="Pseudo-Accents", XB="Pseudo-Bidi", XK="Kosovo", YD="South Yemen", YE="Yemen", YT="Mayotte",
  YU="Yugoslavia", ZA="South Africa", ZM="Zambia", ZR="Zaire", ZW="Zimbabwe",
}

-- ---------------------------------------------------------------------------------------------
-- Response normalisation (ported from the Chrome extension's lib/ipdata.js)
-- ---------------------------------------------------------------------------------------------

local function str(v)
  if type(v) == "string" and v ~= "" then return v end
  return nil
end

local function num(v)
  if type(v) == "number" then return v end
  return nil
end

local function countryName(code)
  if not code then return nil end
  return COUNTRIES[code:upper()] or code
end

-- "GB" -> "🇬🇧" (regional indicator symbols).
local function flagEmoji(code)
  if type(code) ~= "string" or #code ~= 2 or code:find("%A") then return "" end
  local u = code:upper()
  return utf8.char(0x1F1E6 + u:byte(1) - 65, 0x1F1E6 + u:byte(2) - 65)
end

-- "+0100" / "-0530" -> seconds east of UTC.
local function offsetSeconds(offset)
  if type(offset) ~= "string" then return nil end
  local sign, hh, mm = offset:match("^([+-])(%d%d):?(%d%d)$")
  if not sign then return nil end
  local s = tonumber(hh) * 3600 + tonumber(mm) * 60
  if sign == "-" then return -s end
  return s
end

-- Current wall-clock time in the record's zone, from the keyed response's UTC offset.
local function localTime(tz)
  local off = offsetSeconds(tz.offset)
  if not off then return nil end
  local t = os.date("!%H:%M", os.time() + off)
  if str(tz.abbr) then t = t .. " " .. tz.abbr end
  return t
end

-- The first of its arguments that is a boolean, or nil.
local function flag(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "boolean" then return v end
  end
  return nil
end

-- Map both the free and the keyed response shapes onto one record.
local function normalize(raw, source)
  local cc = str(raw.country_code) or str(raw.country)
  local asn
  if type(raw.asn) == "table" then
    asn = raw.asn
  elseif raw.asn ~= nil and raw.asn ~= "" then
    asn = { asn = tostring(raw.asn), name = str(raw.org) }
  end
  local tz
  local tzTable = type(raw.time_zone) == "table" and raw.time_zone or {}
  local tzName = str(tzTable.name) or str(raw.timezone)
  if tzName then
    tz = { name = tzName, abbr = str(tzTable.abbr), offset = str(tzTable.offset), is_dst = tzTable.is_dst, local_time = localTime(tzTable) }
  end
  local is_eu
  if type(raw.is_eu) == "boolean" then is_eu = raw.is_eu end
  local carrier
  if type(raw.carrier) == "table" and str(raw.carrier.name) then carrier = raw.carrier end
  return {
    ip = raw.ip,
    version = version(raw.ip or ""),
    source = source,
    country_code = cc,
    country_name = str(raw.country_name) or countryName(cc),
    emoji = str(raw.emoji_flag) or flagEmoji(cc),
    is_eu = is_eu,
    continent = str(raw.continent_name),
    city = str(raw.city),
    region = str(raw.region),
    region_code = str(raw.region_code),
    postal = str(raw.postal),
    calling_code = raw.calling_code ~= nil and tostring(raw.calling_code) or nil,
    latitude = num(raw.latitude),
    longitude = num(raw.longitude),
    asn = asn,
    org = str(raw.org) or (asn and str(asn.name)) or nil,
    company = type(raw.company) == "table" and raw.company or nil,
    carrier = carrier,
    time_zone = tz,
    currency = type(raw.currency) == "table" and raw.currency or nil,
    languages = type(raw.languages) == "table" and raw.languages or nil,
    threat = type(raw.threat) == "table" and raw.threat or nil,
    connection = {
      mobile = flag(raw.mobile, raw.is_mobile),
      anycast = flag(raw.is_anycast),
      leased = flag(raw.is_leased),
      satellite = flag(raw.is_satellite),
    },
    count = tonumber(raw.count),
  }
end

-- ---------------------------------------------------------------------------------------------
-- Presentation helpers (operator / owner / verdict rules from the Chrome extension's render.js)
-- ---------------------------------------------------------------------------------------------

-- Concatenate the non-empty arguments.
local function join(sep, ...)
  local out = {}
  for i = 1, select("#", ...) do
    local p = select(i, ...)
    if p ~= nil and p ~= false and p ~= "" then out[#out + 1] = tostring(p) end
  end
  return table.concat(out, sep)
end

local TYPE_LABEL = { isp = "ISP", hosting = "Hosting", cdn = "CDN", edu = "Education", gov = "Government", mil = "Military", business = "Business" }
local function typeLabel(t)
  if type(t) ~= "string" or t == "" or t:lower() == "unknown" then return "" end
  return TYPE_LABEL[t:lower()] or t
end

local FLAGS = {
  { "is_known_attacker", "Known attacker", "bad" }, { "is_known_abuser", "Known abuser", "bad" }, { "is_tor", "Tor", "bad" },
  { "is_vpn", "VPN", "bad" }, { "is_proxy", "Proxy", "bad" }, { "is_anonymous", "Anonymous", "bad" },
  { "is_datacenter", "Datacenter", "warn" }, { "is_icloud_relay", "iCloud Relay", "warn" }, { "is_bogon", "Bogon", "warn" },
}
local function activeFlags(threat)
  local out = {}
  if type(threat) ~= "table" then return out end
  for _, f in ipairs(FLAGS) do
    if threat[f[1]] == true then out[#out + 1] = f end
  end
  return out
end

local function riskLabel(score)
  if score >= 60 then return "Low risk" end
  if score >= 40 then return "Moderate risk" end
  return "High risk"
end
local function riskClass(score)
  if score >= 60 then return "ok" end
  if score >= 40 then return "warn" end
  return "bad"
end

-- One-phrase verdict, following the rules ipdata.co uses for its badges.
local function verdict(threat)
  local s = type(threat.scores) == "table" and threat.scores or {}
  local named = {}
  for _, f in ipairs(activeFlags(threat)) do
    if f[1] ~= "is_anonymous" and #named < 2 then named[#named + 1] = f[2] end
  end
  if #named > 0 then return table.concat(named, ", ") end
  local v, p = s.vpn_score, s.proxy_score
  if type(v) == "number" and type(p) == "number" then
    if v >= 90 or p >= 90 or threat.is_anonymous == true then return "Anonymous" end
    if v >= 50 or p >= 50 then return "Possibly anonymous" end
    if v <= 10 and p <= 10 then return "Real end-user" end
  end
  if threat.is_anonymous == true then return "Anonymous" end
  return "No threat signals"
end

-- Registry placeholders such as "Provider Lir" are not a useful owner.
local PLACEHOLDER_NAMES = { unknown = true, ["n/a"] = true, na = true, none = true, private = true, placeholder = true, ["-"] = true }
local REGISTRY_WORDS = { "lir", "ripe ncc", "arin", "apnic", "lacnic", "afrinic", "iana" }
local function placeholderCompany(name)
  if not str(name) then return true end
  local n = name:match("^%s*(.-)%s*$"):lower()
  if PLACEHOLDER_NAMES[n] then return true end
  if #n < 24 then
    for _, w in ipairs(REGISTRY_WORDS) do
      if n:find("%f[%w]" .. w .. "%f[^%w]") then return true end
    end
  end
  return false
end

local function operatorOf(m)
  local a = m.asn or {}
  return { asn = str(a.asn), name = str(a.name) or m.org, type = typeLabel(a.type), domain = str(a.domain), route = str(a.route) }
end

-- The company record is the owner; without one (free tier, or a registry placeholder such as
-- "Provider Lir") the operator's organisation stands in, with its domain and route.
local function ownerOf(m)
  local c = m.company
  if c and not placeholderCompany(c.name) then
    return { name = str(c.name), domain = str(c.domain), network = str(c.network), type = typeLabel(c.type), fromCompany = true }
  end
  local a = m.asn or {}
  return { name = str(a.name) or m.org, domain = str(a.domain), network = str(a.route), type = "", fromCompany = false }
end

-- "Frankfurt am Main" and "Hesse, Germany · 60313", as the hero shows them.
local function placeOf(m)
  local headline = m.city or m.region or m.country_name or "Unknown location"
  local parts = {}
  if m.city and m.region and m.region ~= m.city then parts[#parts + 1] = m.region end
  if m.country_name and headline ~= m.country_name then parts[#parts + 1] = m.country_name end
  local line = table.concat(parts, ", ")
  if m.postal then line = line .. (line ~= "" and " · " or "") .. m.postal end
  if line == "" and m.continent then line = m.continent end
  local short = join(", ", m.city, m.country_name)
  if short == "" then short = headline end
  return { headline = headline, line = line, short = short }
end

local function operatorLine(m)
  local op = operatorOf(m)
  local s = join(" ", op.asn, op.name)
  if s == "" then return "Unknown operator" end
  return s
end

local function flagOf(m)
  if m and str(m.emoji) then return m.emoji end
  return "🌐"
end

-- 1234567 -> "1,234,567"
local function fmtInt(n)
  local s = tostring(math.floor(n))
  local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (r:gsub("^,", ""))
end

-- "3h 12m" until the free quota resets, or "".
local function resetIn(rate)
  if not rate or not rate.reset_at then return "" end
  local secs = rate.reset_at - os.time()
  if secs <= 0 then return "" end
  local h = math.floor(secs / 3600)
  local m = math.floor((secs % 3600) / 60 + 0.5)
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", m)
end

-- ---------------------------------------------------------------------------------------------
-- Card HTML: a macOS-style popover (system font and colours, inset grouped rows)
-- ---------------------------------------------------------------------------------------------

local DARK_TOKENS = "--bg: #1C1C1E; --group: #2C2C2E; --label: #FFFFFF; --secondary: rgba(235,235,245,.6); --tertiary: rgba(235,235,245,.3); --sep: rgba(84,84,88,.65); --border: rgba(255,255,255,.14); --fill: rgba(120,120,128,.24); --blue: #0A84FF; --green: #30D158; --orange: #FF9F0A; --red: #FF453A; --greenbg: rgba(48,209,88,.18); --orangebg: rgba(255,159,10,.18); --redbg: rgba(255,69,58,.18); --segon: #636366; --jnum: #30D158; --jbool: #FF9F0A; color-scheme: dark;"

local CSS = [==[
html, body { margin: 0; padding: 0; background: transparent; }
button { font: inherit; color: inherit; }
.ipd-card { --bg: #F2F2F7; --group: #FFFFFF; --label: #000000; --secondary: rgba(60,60,67,.6); --tertiary: rgba(60,60,67,.3); --sep: rgba(60,60,67,.29); --border: rgba(0,0,0,.12); --fill: rgba(120,120,128,.12); --blue: #007AFF; --green: #34C759; --orange: #FF9500; --red: #FF3B30; --greenbg: rgba(52,199,89,.16); --orangebg: rgba(255,149,0,.17); --redbg: rgba(255,59,48,.13); --segon: #FFFFFF; --jnum: #248A3D; --jbool: #C93400; color-scheme: light;
  position: relative; width: 320px; box-sizing: border-box; overflow: hidden; border-radius: 12px; border: 0.5px solid var(--border);
  background: var(--bg); color: var(--label); font: 13px/1.4 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased; -webkit-user-select: none; user-select: none; cursor: default; text-align: left; }
]==] .. ".ipd-card.ipd-dark { " .. DARK_TOKENS .. " }\n@media (prefers-color-scheme: dark) { .ipd-card:not(.ipd-light) { " .. DARK_TOKENS .. " } }\n" .. [==[
.ipd-card * { box-sizing: border-box; min-width: 0; }
.ipd-mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; }
.ipd-link { color: var(--blue); background: none; border: 0; padding: 0; cursor: pointer; font: inherit; }
.ipd-link:hover { text-decoration: underline; }
.ipd-icon { all: unset; cursor: pointer; width: 22px; height: 22px; display: inline-flex; align-items: center; justify-content: center; border-radius: 6px; color: var(--secondary); flex: none; }
.ipd-icon svg { width: 15px; height: 15px; display: block; }
.ipd-icon:hover { background: var(--fill); color: var(--label); }
.ipd-rowbtn { all: unset; cursor: pointer; }
.ipd-hero { display: flex; gap: 10px; padding: 12px 12px 10px; align-items: flex-start; }
.ipd-flag { flex: none; width: 34px; font-size: 30px; line-height: 1.15; text-align: center; }
.ipd-flag-sm { width: auto; font-size: 13px; line-height: 1; }
.ipd-hero-main { flex: 1; min-width: 0; }
.ipd-title { font-size: 15px; font-weight: 600; letter-spacing: -.01em; line-height: 1.25; overflow-wrap: anywhere; }
.ipd-sub { font-size: 12px; color: var(--secondary); margin-top: 1px; }
.ipd-ipline { display: flex; align-items: center; gap: 5px; margin-top: 6px; }
.ipd-ip { font-size: 12px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; -webkit-user-select: text; user-select: text; cursor: text; }
.ipd-tag { font-size: 10px; font-weight: 600; padding: 1px 5px; border-radius: 5px; background: var(--fill); color: var(--secondary); flex: none; }
.ipd-head { display: flex; align-items: center; gap: 8px; padding: 12px 12px 0; }
.ipd-head .ipd-ip { font-size: 12.5px; }
.ipd-section { font-size: 11px; font-weight: 600; letter-spacing: .04em; text-transform: uppercase; color: var(--secondary); margin: 2px 24px 5px; }
.ipd-group { margin: 0 12px 10px; background: var(--group); border-radius: 10px; overflow: hidden; }
.ipd-row { display: flex; gap: 10px; padding: 7px 12px; align-items: baseline; width: 100%; box-sizing: border-box; font: inherit; color: inherit; text-align: left; }
.ipd-row:not(:last-child) { background: linear-gradient(var(--sep), var(--sep)) 12px 100% / calc(100% - 12px) 0.5px no-repeat; }
.ipd-rowbtn:hover { background-color: var(--fill); }
.ipd-rowbtn .ipd-icon { margin-left: auto; align-self: center; }
.ipd-k { flex: 0 0 82px; font-size: 12px; color: var(--secondary); padding-top: 1px; }
.ipd-v { flex: 1; min-width: 0; font-size: 13px; overflow-wrap: anywhere; }
.ipd-dim, .ipd-v2 { color: var(--secondary); }
.ipd-v2 { font-size: 12px; margin-top: 1px; }
.ipd-score { display: inline-block; min-width: 26px; text-align: center; font-weight: 700; font-size: 12px; padding: 1px 6px; border-radius: 6px; margin-right: 7px; }
.ipd-score.ok { background: var(--greenbg); color: var(--green); } .ipd-score.warn { background: var(--orangebg); color: var(--orange); } .ipd-score.bad { background: var(--redbg); color: var(--red); }
.ipd-chips { display: flex; flex-wrap: wrap; gap: 6px; margin: 0 12px 10px; }
.ipd-chip { font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 999px; background: var(--fill); color: var(--secondary); }
.ipd-chip.bad { background: var(--redbg); color: var(--red); } .ipd-chip.warn { background: var(--orangebg); color: var(--orange); } .ipd-chip.ok { background: var(--greenbg); color: var(--green); }
.ipd-more summary { list-style: none; cursor: pointer; }
.ipd-more summary::-webkit-details-marker { display: none; }
.ipd-more summary .ipd-k { flex: 1; color: var(--label); font-size: 13px; padding-top: 0; }
.ipd-more:not([open]) > summary { background: none; }
.ipd-chev { margin-left: auto; color: var(--tertiary); align-self: center; transition: transform .15s; }
.ipd-chev svg { width: 12px; height: 12px; display: block; }
.ipd-more[open] .ipd-chev { transform: rotate(90deg); }
.ipd-foot { display: flex; align-items: center; gap: 8px; padding: 8px 12px; border-top: 0.5px solid var(--sep); font-size: 11px; color: var(--secondary); }
.ipd-pill { margin-left: auto; font-size: 10.5px; font-weight: 600; padding: 2px 8px; border-radius: 999px; background: var(--fill); color: var(--secondary); white-space: nowrap; border: 0; cursor: pointer; }
.ipd-pill:hover { color: var(--label); }
.ipd-pill.key { background: var(--greenbg); color: var(--green); } .ipd-pill.warn { background: var(--orangebg); color: var(--orange); }
.ipd-loading { display: flex; gap: 8px; align-items: center; padding: 12px; font-size: 12.5px; color: var(--secondary); }
.ipd-spinner { width: 14px; height: 14px; border: 2px solid var(--fill); border-top-color: var(--secondary); border-radius: 50%; animation: ipd-spin .8s linear infinite; flex: none; }
@keyframes ipd-spin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) { .ipd-spinner { animation: none; } .ipd-chev { transition: none; } }
.ipd-msg { margin: 10px 12px; padding: 8px 10px; border-radius: 10px; background: var(--group); font-size: 12.5px; }
.ipd-msg.bad { color: var(--red); background: var(--redbg); }
.ipd-msg.soft { color: var(--secondary); }
.ipd-msg + .ipd-msg { margin-top: -4px; }
.ipd-note { margin: -4px 12px 10px; font-size: 11.5px; color: var(--orange); }
.ipd-top { position: absolute; top: 8px; right: 8px; z-index: 2; display: flex; align-items: center; gap: 4px; }
.ipd-title { padding-right: 112px; }
.ipd-head { padding-right: 40px; }
.ipd-theme .i-sun { display: none; }
.ipd-card.ipd-dark .ipd-theme .i-sun { display: block; }
.ipd-card.ipd-dark .ipd-theme .i-moon { display: none; }
@media (prefers-color-scheme: dark) { .ipd-card:not(.ipd-light) .ipd-theme .i-sun { display: block; } .ipd-card:not(.ipd-light) .ipd-theme .i-moon { display: none; } }
.ipd-seg { display: inline-flex; background: var(--fill); border-radius: 6px; padding: 1.5px; gap: 1px; }
.ipd-seg button { border: 0; background: transparent; cursor: pointer; font-size: 10.5px; font-weight: 500; line-height: 1.35; color: var(--secondary); padding: 1px 7px; border-radius: 5px; }
.ipd-seg button.on { background: var(--segon); color: var(--label); box-shadow: 0 0.5px 1.5px rgba(0,0,0,.22); }
.ipd-jsonbody { display: none; }
.ipd-card.ipd-json-view .ipd-jsonbody { display: block; }
.ipd-card.ipd-json-view .ipd-cardbody { display: none; }
.ipd-json { margin: 0 12px 10px; background: var(--group); border-radius: 10px; overflow: hidden; }
.ipd-json-bar { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 4px 6px 4px 12px; border-bottom: 0.5px solid var(--sep); font-size: 11px; color: var(--secondary); }
.ipd-json-bar span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ipd-json-pre { margin: 0; padding: 9px 12px 10px; font-size: 11px; line-height: 1.5; max-height: 300px; overflow: auto; white-space: pre; color: var(--label); -webkit-user-select: text; user-select: text; cursor: text; }
.ipd-sections > details:not(:last-child) { background: linear-gradient(var(--sep), var(--sep)) 12px 100% / calc(100% - 12px) 0.5px no-repeat; }
.ipd-more[open] > summary .ipd-k { font-weight: 600; }
.ipd-hint { flex: 0 1 auto; max-width: 150px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 12px; color: var(--secondary); }
.ipd-hint.bad { color: var(--red); } .ipd-hint.warn { color: var(--orange); }
.ipd-more summary .ipd-chev { margin-left: 0; }
.ipd-sec .ipd-chips { margin: 0; padding: 9px 12px 11px; }
.ipd-scroll { max-height: 264px; overflow: auto; }
.j-k { color: var(--secondary); } .j-s { color: var(--blue); } .j-n { color: var(--jnum); } .j-b { color: var(--jbool); }
]==]

-- Small stroke icons in the style of SF Symbols (doc.on.doc, arrow.up.right, chevron.right, checkmark).
local ICON_COPY = '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5.5" y="5.5" width="8" height="8" rx="2"/><path d="M10.5 5V3.5a1 1 0 0 0-1-1h-6a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1H5"/></svg>'
local ICON_OPEN = '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 11.5l7-7M6 4.5h5.5V10"/></svg>'
local ICON_CHEV = '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3.5L10.5 8 6 12.5"/></svg>'
-- moon (shown in light appearance: click for dark) and sun.max (shown in dark: click for light)
local ICON_MOON = '<svg class="i-moon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M13.3 10.2A5.6 5.6 0 0 1 5.8 2.7a5.6 5.6 0 1 0 7.5 7.5z"/></svg>'
local ICON_SUN = '<svg class="i-sun" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><circle cx="8" cy="8" r="2.8"/><path d="M8 1.4v1.5M8 13.1v1.5M1.4 8h1.5M13.1 8h1.5M3.3 3.3l1.1 1.1M11.6 11.6l1.1 1.1M3.3 12.7l1.1-1.1M11.6 4.4l1.1-1.1"/></svg>'

-- Bridge between the page and Lua: clicks on [data-act] elements, Escape, hover (pauses the
-- timeout) and the rendered height (so the window fits the content) are posted to the
-- "ipdata" message handler of the hs.webview.usercontent controller.
local JS = [==[
(function () {
  var card = document.getElementById('ipd');
  var CHECK = '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 8.5l3 3 6-7"/></svg>';
  function post(m) { try { window.webkit.messageHandlers.ipdata.postMessage(m); } catch (e) {} }
  function report() { if (card) post({ action: 'size', height: Math.ceil(card.getBoundingClientRect().height) }); }
  document.addEventListener('click', function (e) {
    if (e.target && e.target.closest && e.target.closest('summary')) post({ action: 'keep' });
    var el = e.target && e.target.closest ? e.target.closest('[data-act]') : null;
    if (!el) return;
    e.preventDefault(); e.stopPropagation();
    var act = el.getAttribute('data-act');
    if (act === 'copy') {
      post({ action: 'copy', text: el.getAttribute('data-text') || '' });
      var old = el.innerHTML; el.innerHTML = CHECK; setTimeout(function () { el.innerHTML = old; }, 1200);
      return;
    }
    if (act === 'theme') {
      var sys = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      var cur = card.classList.contains('ipd-dark') ? 'dark' : card.classList.contains('ipd-light') ? 'light' : sys;
      var next = cur === 'dark' ? 'light' : 'dark';
      card.classList.remove('ipd-dark', 'ipd-light');
      if (next !== sys) card.classList.add('ipd-' + next);
      post({ action: 'theme', value: next, system: sys });
      return;
    }
    if (act === 'view') {
      var v = el.getAttribute('data-view');
      card.classList.toggle('ipd-json-view', v === 'json');
      Array.prototype.forEach.call(document.querySelectorAll('[data-act="view"]'), function (b) { b.classList.toggle('on', b.getAttribute('data-view') === v); });
      post({ action: 'view', value: v });
      return;
    }
    post({ action: act, url: el.getAttribute('data-url') || '', ip: el.getAttribute('data-ip') || '' });
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') post({ action: 'close' }); });
  if (card) {
    card.addEventListener('mouseenter', function () { post({ action: 'hover' }); });
    card.addEventListener('mouseleave', function () { post({ action: 'unhover' }); });
    if (window.ResizeObserver) new ResizeObserver(function () { report(); }).observe(card);
  }
  Array.prototype.forEach.call(document.querySelectorAll('details'), function (d) {
    d.addEventListener('toggle', function () { setTimeout(report, 0); });
  });
  window.addEventListener('load', report);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(report);
  report();
})();
]==]

local function esc(s)
  if s == nil then return "" end
  return (tostring(s):gsub("[&<>\"']", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&#39;" }))
end

local function urlEncode(s)
  return (tostring(s):gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- The Card / JSON segmented control.
local function segHtml()
  local json = obj._view == "json"
  return table.concat({
    '<div class="ipd-seg">',
    '<button class="', json and "" or "on", '" data-act="view" data-view="card">Card</button>',
    '<button class="', json and "on" or "", '" data-act="view" data-view="json">JSON</button>',
    '</div>',
  })
end

-- The whole document; `IPData.appearance` forces light or dark, otherwise the system decides.
-- Every card carries the sun/moon button in its corner; one with a JSON body also has the
-- Card / JSON switch beside it and opens in the last view chosen.
local function page(body, withJson)
  local cls = "ipd-card"
  if obj.appearance == "dark" then cls = cls .. " ipd-dark" elseif obj.appearance == "light" then cls = cls .. " ipd-light" end
  if obj._view == "json" then cls = cls .. " ipd-json-view" end
  return table.concat({
    '<!doctype html><html><head><meta charset="utf-8"><style>', CSS, '</style></head><body>',
    '<div class="', cls, '" id="ipd">',
    '<div class="ipd-top">', withJson and segHtml() or "",
    '<button class="ipd-icon ipd-theme" data-act="theme" title="Light or dark appearance">', ICON_MOON, ICON_SUN, '</button></div>',
    body, '</div><script>', JS, '</script></body></html>',
  })
end

local function openBtn(url, text, cls)
  return string.format('<button class="%s" data-act="open" data-url="%s">%s</button>', cls or "ipd-link", esc(url), esc(text))
end

local function iconBtn(act, icon, title, text, url)
  return string.format('<button class="ipd-icon" title="%s" data-act="%s" data-text="%s" data-url="%s">%s</button>',
    esc(title), act, esc(text or ""), esc(url or ""), icon)
end

local function flagHtml(m, small)
  return string.format('<span class="ipd-flag%s">%s</span>', small and " ipd-flag-sm" or "", esc(flagOf(m)))
end

-- One row of an inset group: label column, value, optional second line.
local function row(label, valueHtml, subHtml)
  return table.concat({
    '<div class="ipd-row"><div class="ipd-k">', esc(label), '</div><div class="ipd-v">', valueHtml,
    (subHtml and subHtml ~= "") and ('<div class="ipd-v2">' .. subHtml .. '</div>') or "", '</div></div>',
  })
end
local function group(rowsHtml) return '<div class="ipd-group">' .. rowsHtml .. '</div>' end
local function section(title) return '<div class="ipd-section">' .. esc(title) .. '</div>' end

local function headHtml(ip)
  return table.concat({
    '<div class="ipd-head"><span class="ipd-flag ipd-flag-sm">🌐</span>',
    ip and ('<span class="ipd-ip ipd-mono">' .. esc(ip) .. '</span>') or "",
    '</div>',
  })
end

local function loadingHtml(ip)
  return headHtml(ip) .. '<div class="ipd-loading"><span class="ipd-spinner"></span>' ..
    (ip and ("Looking up " .. esc(ip) .. "…") or "Detecting your addresses…") .. '</div>'
end

local function heroHtml(m, ip)
  local place = placeOf(m)
  return table.concat({
    '<div class="ipd-hero">', flagHtml(m),
    '<div class="ipd-hero-main"><div class="ipd-title">', esc(place.headline), '</div>',
    place.line ~= "" and ('<div class="ipd-sub">' .. esc(place.line) .. '</div>') or "",
    '<div class="ipd-ipline"><span class="ipd-ip ipd-mono" title="', esc(ip), '">', esc(ip), '</span>',
    m.version > 0 and ('<span class="ipd-tag">IPv' .. m.version .. '</span>') or "",
    iconBtn("copy", ICON_COPY, "Copy address", ip, nil),
    iconBtn("open", ICON_OPEN, "Open on ipdata.co", nil, SITE_URL .. ip),
    '</div></div></div>',
  })
end

local function trustRowHtml(m)
  local t = m.threat
  if not t then
    return row("Trust score", '<span class="ipd-dim">Needs an API key</span>', '<button class="ipd-link" data-act="setkey">Add API key…</button>')
  end
  local s = type(t.scores) == "table" and t.scores or {}
  if type(s.trust_score) == "number" then
    local score = s.trust_score
    return row("Trust score", string.format('<span class="ipd-score %s">%d</span>%s', riskClass(score), math.floor(score), esc(riskLabel(score))), esc(verdict(t)))
  end
  local act = activeFlags(t)
  if #act == 0 then return row("Threat", '<span class="ipd-score ok">✓</span>No threat signals', nil) end
  local names, cls = {}, "warn"
  for i, f in ipairs(act) do
    if i <= 2 then names[#names + 1] = f[2] end
    if f[3] == "bad" then cls = "bad" end
  end
  return row("Threat", string.format('<span class="ipd-score %s">!</span>%s', cls, esc(table.concat(names, ", "))), #act > 2 and esc("+" .. (#act - 2) .. " more") or nil)
end

-- Operator, Owner, Coordinates and Trust score rows.
local function mainGroupHtml(m)
  local op, owner = operatorOf(m), ownerOf(m)
  local rows = {}
  local opValue = esc(op.asn or op.name or "Unknown")
  if op.type ~= "" then opValue = opValue .. ' <span class="ipd-dim">· ' .. esc(op.type) .. '</span>' end
  rows[#rows + 1] = row("Operator", opValue, (op.asn and op.name) and esc(op.name) or nil)
  local ownerSub = join(" · ", owner.domain, owner.network)
  if ownerSub == "" then ownerSub = owner.type end
  rows[#rows + 1] = row("Owner", esc(owner.name or "Unknown"), ownerSub ~= "" and esc(ownerSub) or nil)
  if m.latitude and m.longitude then
    local url = string.format("https://maps.apple.com/?ll=%s,%s&q=%s", m.latitude, m.longitude, urlEncode(placeOf(m).short))
    rows[#rows + 1] = row("Coordinates", esc(string.format("%.2f, %.2f", m.latitude, m.longitude)), openBtn(url, "Open in Maps"))
  else
    rows[#rows + 1] = row("Coordinates", '<span class="ipd-dim">Unknown</span>', nil)
  end
  rows[#rows + 1] = trustRowHtml(m)
  return group(table.concat(rows))
end

-- Threat chips; empty without any flag set. Scores and blocklists have their own sections.
local function signalsHtml(m)
  local act = activeFlags(m.threat)
  if #act == 0 then return "" end
  local chips = {}
  for _, f in ipairs(act) do chips[#chips + 1] = string.format('<span class="ipd-chip %s">%s</span>', f[3], esc(f[2])) end
  return section("Threat signals") .. '<div class="ipd-chips">' .. table.concat(chips) .. '</div>'
end

-- One disclosure row of the sections group: title, an optional quiet hint on the right, and its
-- rows when opened.
local function sectionHtml(title, hint, hintClass, bodyHtml)
  return table.concat({
    '<details class="ipd-more"><summary class="ipd-row"><div class="ipd-k">', esc(title), '</div>',
    hint and string.format('<span class="ipd-hint%s">%s</span>', hintClass and (" " .. hintClass) or "", esc(hint)) or "",
    '<span class="ipd-chev">', ICON_CHEV, '</span></summary><div class="ipd-sec">', bodyHtml, '</div></details>',
  })
end

local function noteRow(html) return '<div class="ipd-row"><div class="ipd-v ipd-dim">' .. html .. '</div></div>' end
local ADD_KEY = '<button class="ipd-link" data-act="setkey">Add API key…</button>'
-- Blocklists, scores, flags and connection attributes only come with an API key.
local function lockedSection(title) return sectionHtml(title, "API key", nil, noteRow("Needs an API key · " .. ADD_KEY)) end

local function locationSection(m)
  local rows = {}
  local function add(k, v) if str(v) then rows[#rows + 1] = row(k, esc(v)) end end
  add("City", m.city)
  add("Region", join(" · ", m.region, m.region_code))
  add("Postal code", m.postal)
  add("Country", join(" · ", m.country_name, m.country_code))
  add("Continent", join(" · ", m.continent, m.is_eu and "EU member" or nil))
  if m.latitude and m.longitude then add("Coordinates", string.format("%.4f, %.4f", m.latitude, m.longitude)) end
  if m.time_zone then
    local offset = m.time_zone.offset and m.time_zone.offset:gsub("^([+-]%d%d):?(%d%d)$", "UTC%1:%2") or nil
    add("Time zone", join(" · ", m.time_zone.name, offset))
    add("Local time", m.time_zone.local_time)
  end
  if m.currency and str(m.currency.code) then
    add("Currency", join(" · ", join(" ", m.currency.code, str(m.currency.symbol)), str(m.currency.name)))
  end
  if m.languages then
    local names = {}
    for _, l in ipairs(m.languages) do
      local n = type(l) == "table" and (str(l.name) or str(l.code)) or nil
      if n then names[#names + 1] = n end
    end
    add("Languages", table.concat(names, ", "))
  end
  if m.calling_code then add("Calling code", "+" .. m.calling_code) end
  if #rows == 0 then rows[1] = noteRow("No location in this response") end
  return sectionHtml("Location", nil, nil, table.concat(rows))
end

-- "tor_exit_nodes" -> "Tor exit nodes"
local function humanize(key)
  local s = tostring(key):gsub("_", " ")
  return s:sub(1, 1):upper() .. s:sub(2)
end

local function blocklistsSection(m)
  local t = m.threat
  if not t then return lockedSection("Blocklists") end
  local rows = {}
  for _, b in ipairs(type(t.blocklists) == "table" and t.blocklists or {}) do
    if type(b) == "table" then
      local name, site = str(b.name) or str(b.site) or "unknown", str(b.site) or str(b.website)
      local title = (site and site:find("^https?://")) and openBtn(site, name) or esc(name)
      local kind = str(b.category) or str(b.type)
      local first, last = str(b.first_seen), str(b.last_seen)
      local seen = (first or last) and ((first or "?"):sub(1, 10) .. " → " .. (last or "?"):sub(1, 10)) or nil
      local days = tonumber(b.days_seen)
      local line = join(" · ", seen, days and (fmtInt(days) .. (days == 1 and " day" or " days")) or nil)
      rows[#rows + 1] = table.concat({
        '<div class="ipd-row"><div class="ipd-v">', title,
        kind and ('<span class="ipd-dim"> · ' .. esc(humanize(kind)) .. '</span>') or "",
        line ~= "" and ('<div class="ipd-v2">' .. esc(line) .. '</div>') or "", '</div></div>',
      })
    end
  end
  if #rows == 0 then return sectionHtml("Blocklists", "None", nil, noteRow("Not listed on any blocklist")) end
  return sectionHtml("Blocklists", tostring(#rows), "bad", '<div class="ipd-scroll">' .. table.concat(rows) .. '</div>')
end

local function scoresSection(m)
  local t = m.threat
  if not t then return lockedSection("Scores") end
  local s = type(t.scores) == "table" and t.scores or {}
  local rows = {}
  local function badge(cls, v) return string.format('<span class="ipd-score %s">%d</span>', cls, math.floor(v)) end
  if type(s.trust_score) == "number" then
    rows[#rows + 1] = row("Trust score", badge(riskClass(s.trust_score), s.trust_score) .. esc(riskLabel(s.trust_score)))
  end
  for _, k in ipairs({ { "threat_score", "Threat score" }, { "vpn_score", "VPN score" }, { "proxy_score", "Proxy score" } }) do
    local v = s[k[1]]
    -- For these, unlike the trust score, higher is worse.
    if type(v) == "number" then rows[#rows + 1] = row(k[2], badge(riskClass(100 - v), v)) end
  end
  if #rows == 0 then rows[1] = noteRow("No scores in this response") end
  return sectionHtml("Scores", nil, nil, table.concat(rows))
end

-- Every flag as a chip: set ones tinted by severity, the rest grey. A flag ipdata adds later shows up too.
local CLOUD_FLAGS = {
  { "is_tor", "Tor", "bad" }, { "is_vpn", "VPN", "bad" }, { "is_datacenter", "Datacenter", "warn" }, { "is_proxy", "Proxy", "bad" },
  { "is_icloud_relay", "iCloud Relay", "warn" }, { "is_anonymous", "Anonymous", "bad" }, { "is_known_attacker", "Known attacker", "bad" },
  { "is_known_abuser", "Known abuser", "bad" }, { "is_threat", "Threat", "bad" }, { "is_bogon", "Bogon", "warn" },
}
local function flagsSection(m)
  local t = m.threat
  if not t then return lockedSection("Flags") end
  local all, known, extra = {}, {}, {}
  for _, f in ipairs(CLOUD_FLAGS) do
    known[f[1]] = true
    if type(t[f[1]]) == "boolean" then all[#all + 1] = f end
  end
  for k, v in pairs(t) do
    if type(k) == "string" and k:find("^is_") and not known[k] and type(v) == "boolean" then extra[#extra + 1] = k end
  end
  table.sort(extra)
  for _, k in ipairs(extra) do all[#all + 1] = { k, humanize((k:gsub("^is_", ""))), "bad" } end
  local chips, set, worst = {}, 0, "warn"
  for _, f in ipairs(all) do
    local on = t[f[1]] == true
    if on then
      set = set + 1
      if f[3] == "bad" then worst = "bad" end
    end
    chips[#chips + 1] = string.format('<span class="ipd-chip%s">%s</span>', on and (" " .. f[3]) or "", esc(f[2]))
  end
  if #chips == 0 then return sectionHtml("Flags", nil, nil, noteRow("No flags in this response")) end
  return sectionHtml("Flags", set > 0 and (set .. " set") or "None set", set > 0 and worst or nil, '<div class="ipd-chips">' .. table.concat(chips) .. '</div>')
end

local function connectionSection(m)
  if not m.threat and m.source ~= "key" then return lockedSection("Connection") end
  local conn = m.connection or {}
  local rows, set = {}, {}
  local function yesNo(k, v)
    rows[#rows + 1] = row(k, v and "Yes" or '<span class="ipd-dim">No</span>')
    if v then set[#set + 1] = k end
  end
  local mobile = conn.mobile
  if mobile == nil and m.carrier then mobile = true end
  if mobile ~= nil then yesNo("Mobile", mobile) end
  if m.carrier then
    local c = m.carrier.name
    if m.carrier.mcc then c = c .. string.format(" (MCC %s, MNC %s)", tostring(m.carrier.mcc), tostring(m.carrier.mnc or "?")) end
    rows[#rows + 1] = row("Carrier", esc(c))
  end
  for _, k in ipairs({ { "anycast", "Anycast" }, { "leased", "Leased" }, { "satellite", "Satellite" } }) do
    if conn[k[1]] ~= nil then yesNo(k[2], conn[k[1]]) end
  end
  if #rows == 0 then return sectionHtml("Connection", nil, nil, noteRow("No connection attributes in this response")) end
  local hint = m.carrier and m.carrier.name or (#set > 0 and table.concat(set, ", ")) or nil
  return sectionHtml("Connection", hint, nil, table.concat(rows))
end

local function ownerSection(m)
  local o = ownerOf(m)
  local rows = { row("Name", esc(o.name or "Unknown")) }
  if o.domain then rows[#rows + 1] = row("Domain", openBtn("https://" .. o.domain, o.domain)) end
  if o.network then rows[#rows + 1] = row("Network", esc(o.network)) end
  if o.type ~= "" then rows[#rows + 1] = row("Type", esc(o.type)) end
  if not o.fromCompany then
    rows[#rows + 1] = noteRow(m.source == "key" and "The operator's organisation, as there is no usable company record"
      or ("The operator's organisation; the company record needs an API key · " .. ADD_KEY))
  end
  return sectionHtml("Owner", nil, nil, table.concat(rows))
end

local function operatorSection(m)
  local o = operatorOf(m)
  local rows = { row("Name", esc(o.name or "Unknown")) }
  local number = o.asn and o.asn:match("(%d+)")
  if o.asn then rows[#rows + 1] = row("ASN", number and openBtn("https://bgp.tools/as/" .. number, o.asn) or esc(o.asn)) end
  if o.type ~= "" then rows[#rows + 1] = row("Usage type", esc(o.type)) end
  if o.route then rows[#rows + 1] = row("Route", esc(o.route)) end
  if o.domain then rows[#rows + 1] = row("Domain", openBtn("https://" .. o.domain, o.domain)) end
  return sectionHtml("Operator", nil, nil, table.concat(rows))
end

local function sectionsHtml(m)
  return '<div class="ipd-group ipd-sections">' .. table.concat({
    locationSection(m), blocklistsSection(m), scoresSection(m), flagsSection(m), connectionSection(m), ownerSection(m), operatorSection(m),
  }) .. '</div>'
end

local function errorHtml(self, res)
  local soft = res.kind == "reserved" or res.kind == "invalid"
  local parts = { string.format('<div class="ipd-msg %s">%s</div>', soft and "soft" or "bad", esc(res.message or "Lookup failed")) }
  if res.kind == "quota" and res.source ~= "key" then
    local r = resetIn(res.rate or self._rate)
    parts[#parts + 1] = '<div class="ipd-msg soft">Daily free quota used' .. (r ~= "" and (" · resets in " .. esc(r)) or "") ..
      '. <button class="ipd-link" data-act="setkey">Add an API key</button> for unlimited lookups.</div>'
  elseif res.kind == "key" then
    parts[#parts + 1] = '<div class="ipd-msg soft"><button class="ipd-link" data-act="setkey">Change the API key…</button></div>'
  elseif res.kind == "quota" and res.source == "key" then
    parts[#parts + 1] = '<div class="ipd-msg soft">Check the plan\'s quota, or <button class="ipd-link" data-act="setkey">change the API key…</button></div>'
  end
  return table.concat(parts)
end

-- Re-indents JSON text with two spaces, keeping the key order ipdata sent.
local function prettyJson(text)
  local out, depth, i, n = {}, 0, 1, #text
  local function newline() out[#out + 1] = "\n" .. string.rep("  ", depth) end
  while i <= n do
    local c = text:sub(i, i)
    if c == '"' then
      local j = i + 1
      while j <= n do
        local d = text:sub(j, j)
        if d == "\\" then j = j + 2 elseif d == '"' then break else j = j + 1 end
      end
      out[#out + 1] = text:sub(i, j)
      i = j + 1
    elseif c == "{" or c == "[" then
      local close = (c == "{") and "}" or "]"
      local k = text:find("%S", i + 1)
      if k and text:sub(k, k) == close then
        out[#out + 1] = c .. close
        i = k + 1
      else
        out[#out + 1] = c
        depth = depth + 1
        newline()
        i = i + 1
      end
    elseif c == "}" or c == "]" then
      depth = math.max(0, depth - 1)
      newline()
      out[#out + 1] = c
      i = i + 1
    elseif c == "," then
      out[#out + 1] = ","
      newline()
      i = i + 1
    elseif c == ":" then
      out[#out + 1] = ": "
      i = i + 1
    elseif c:find("%s") then
      i = i + 1
    else
      local j = text:find("[%s,:%]}]", i) or (n + 1)
      out[#out + 1] = text:sub(i, j - 1)
      i = j
    end
  end
  return table.concat(out)
end

-- Syntax-coloured, escaped HTML for pretty-printed JSON: keys, strings, numbers and literals.
local function jsonHtml(pretty)
  local out, i, n = {}, 1, #pretty
  while i <= n do
    local c = pretty:sub(i, i)
    if c == '"' then
      local j = i + 1
      while j <= n do
        local d = pretty:sub(j, j)
        if d == "\\" then j = j + 2 elseif d == '"' then break else j = j + 1 end
      end
      local isKey = pretty:sub(j + 1, j + 1) == ":"
      out[#out + 1] = '<span class="' .. (isKey and "j-k" or "j-s") .. '">' .. esc(pretty:sub(i, j)) .. '</span>'
      i = j + 1
    elseif c:find("[%-%d]") then
      local j = pretty:find("[^%-%d%.eE%+]", i) or (n + 1)
      out[#out + 1] = '<span class="j-n">' .. esc(pretty:sub(i, j - 1)) .. '</span>'
      i = j
    elseif pretty:find("^true", i) or pretty:find("^false", i) or pretty:find("^null", i) then
      local w = pretty:match("^%a+", i)
      out[#out + 1] = '<span class="j-b">' .. w .. '</span>'
      i = i + #w
    else
      local j = pretty:find('["%-%dtfn]', i + 1) or (n + 1)
      out[#out + 1] = esc(pretty:sub(i, j - 1))
      i = j
    end
  end
  return table.concat(out)
end

-- The response exactly as ipdata sent it (re-indented), with the request it answered and a copy
-- button. The API key never appears: the bar shows host and address only.
local function jsonBoxHtml(res)
  local pretty = prettyJson(res.body)
  local path = (res.host or "ipdata.co") .. "/" .. (res.ip or "")
  return table.concat({
    '<div class="ipd-json"><div class="ipd-json-bar"><span class="ipd-mono">GET ', esc(path), '</span>',
    iconBtn("copy", ICON_COPY, "Copy JSON", pretty, nil), '</div>',
    '<pre class="ipd-json-pre ipd-mono">', jsonHtml(pretty), '</pre></div>',
  })
end

-- Whether a result has a response to show in the JSON view.
local function hasJson(res)
  return res and res.ok and type(res.body) == "string" and res.body:find("%S") ~= nil
end

-- Hero, rows, chips and sections for one lookup result (or its error), with the JSON body beside them.
local function resultBody(self, res)
  if not res.ok then return headHtml(res.ip) .. errorHtml(self, res) end
  local m = res.model
  return table.concat({
    heroHtml(m, res.ip or m.ip),
    res.degraded and '<div class="ipd-note">Daily city-level quota used; showing country-level data until it resets.</div>' or "",
    '<div class="ipd-cardbody">', mainGroupHtml(m), signalsHtml(m), sectionsHtml(m), '</div>',
    hasJson(res) and ('<div class="ipd-jsonbody">' .. jsonBoxHtml(res) .. '</div>') or "",
  })
end

-- Footer: credit and the quota pill (remaining free lookups, or "API key"); the pill opens the
-- API key prompt.
local function footHtml(self)
  local pill, cls, title = "Free tier", "", "Add an API key"
  if self:_keyed() then
    pill, cls, title = "API key", " key", "Change or remove the API key"
  elseif self._rate and self._rate.remaining then
    pill = "Free · " .. fmtInt(self._rate.remaining) .. " left"
    if self._rate.remaining == 0 then cls = " warn" end
    local r = resetIn(self._rate)
    if r ~= "" then title = "Resets in " .. r .. ". Click to add an API key" end
  end
  return table.concat({
    '<div class="ipd-foot">', openBtn("https://ipdata.co/?utm_source=hammerspoon", "Powered by ipdata"),
    '<button class="ipd-pill', cls, '" data-act="setkey" title="', esc(title), '">', esc(pill), '</button></div>',
  })
end

-- "Your connection": one row per family. A family that failed shows "No IPvX connectivity".
local function youRow(label, r)
  if not r or not r.ok then
    return '<div class="ipd-row"><div class="ipd-k">' .. label .. '</div><div class="ipd-v ipd-dim">No ' .. label .. ' connectivity</div></div>'
  end
  local m = r.model
  local meta = join(" · ", placeOf(m).short, (m.asn and str(m.asn.name)) or m.org)
  return table.concat({
    '<button class="ipd-row ipd-rowbtn" data-act="lookup" data-ip="', esc(m.ip), '" title="Look up ', esc(m.ip), '">',
    '<div class="ipd-k">', label, '</div><div class="ipd-v"><span class="ipd-mono">', esc(m.ip), '</span>',
    '<div class="ipd-v2">', flagHtml(m, true), ' ', esc(meta), '</div></div>',
    '<span class="ipd-icon" title="Copy" data-act="copy" data-text="', esc(m.ip), '">', ICON_COPY, '</span></button>',
  })
end
local function youHtml(my)
  return '<div class="ipd-cardbody">' .. section("Your connection") .. group(youRow("IPv4", my.v4) .. youRow("IPv6", my.v6)) .. '</div>'
end

-- One-line texts for the hs.alert fallback.
local function alertText(res)
  if not res.ok then
    return string.format("%s %s · %s", res.kind == "reserved" and "🔒" or "⚠️", res.ip or "", res.message or "Lookup failed")
  end
  local m = res.model
  return string.format("%s %s · %s · %s", flagOf(m), res.ip or m.ip, placeOf(m).short, operatorLine(m))
end
local function myAlertText(my, primary)
  if not primary then return "🌐 " .. (my.message or "Could not detect your IP address") end
  local v4 = (my.v4 and my.v4.ok) and ("IPv4 " .. my.v4.model.ip) or "No IPv4 connectivity"
  local v6 = (my.v6 and my.v6.ok) and ("IPv6 " .. my.v6.model.ip) or "No IPv6 connectivity"
  local m = primary.model
  return string.format("%s %s · %s · %s · %s", flagOf(m), v4, v6, placeOf(m).short, operatorLine(m))
end

-- ---------------------------------------------------------------------------------------------
-- HTTP
-- ---------------------------------------------------------------------------------------------

local function header(headers, name)
  if type(headers) ~= "table" then return nil end
  local want = name:lower()
  for k, v in pairs(headers) do
    if type(k) == "string" and k:lower() == want then return v end
  end
  return nil
end

-- Free-tier quota from the RateLimit-* headers, or nil.
local function rateFromHeaders(headers)
  local limit = tonumber(header(headers, "RateLimit-Limit"))
  if not limit then return nil end
  local reset = tonumber(header(headers, "RateLimit-Reset"))
  return {
    limit = limit,
    remaining = tonumber(header(headers, "RateLimit-Remaining")),
    reset_at = reset and (os.time() + reset) or nil,
    quota_status = header(headers, "X-Quota-Status"),
    updated = os.time(),
  }
end

local function errorFor(status, json)
  local msg = (type(json) == "table" and str(json.message)) or ""
  if status == 400 then return "invalid", (msg ~= "" and msg or "Not a valid public IP address") end
  if status == 401 then return "key", "The API key was rejected." end
  if status == 403 then return "quota", (msg ~= "" and msg or "Quota exceeded for this API key.") end
  if status == 404 then return "invalid", (msg ~= "" and msg or "Not found") end
  if status == 429 then return "quota", "Rate limited. Try again in a moment." end
  return "network", (msg ~= "" and msg or ("ipdata returned HTTP " .. tostring(status)))
end

local function decodeJson(body)
  if type(body) ~= "string" or body == "" then return nil end
  local ok, t = pcall(hs.json.decode, body)
  if ok and type(t) == "table" then return t end
  return nil
end

-- Worth retrying on the other free host: unreachable, a 5xx, or a non-JSON answer.
local function retryable(r)
  return not r.ok and (r.kind == "network" or (r.status and r.status >= 500))
end

-- The key in use: `obj.apiKey` (set in init.lua) first, then the one saved by setApiKey().
function obj:_apiKey()
  return str(self.apiKey) or str(hs.settings.get(SETTINGS_KEY))
end

function obj:_keyed()
  return self:_apiKey() ~= nil
end

function obj:_keyedUrl(ip, key)
  local base = KEYED_BASE[self.endpoint] or KEYED_BASE.global
  return base .. "/" .. ip .. "?api-key=" .. urlEncode(key or self:_apiKey())
end

-- hs.http.asyncGet with a timeout. fn(status, body, headers, timedOut); status < 0 on failure.
function obj:_request(url, timeout, fn)
  local done, timer = false, nil
  local function finish(...)
    if done then return end
    done = true
    if timer then timer:stop() end
    fn(...)
  end
  timer = hs.timer.doAfter(timeout, function() finish(-1, "ipdata did not respond in time", nil, true) end)
  local ok, err = pcall(hs.http.asyncGet, url, { Accept = "application/json", ["User-Agent"] = USER_AGENT },
    function(status, body, headers) finish(status, body, headers, false) end)
  if not ok then finish(-1, tostring(err), nil, false) end
end

-- Fetch one record and normalise it. fn receives a result table:
-- { ok = true, model, raw, rate, degraded, source, host } or
-- { ok = false, kind, message, status, rate, source, host }.
function obj:_fetchRecord(url, keyed, timeout, fn)
  local source = keyed and "key" or "free"
  local host = url:match("^https?://([^/]+)") or url
  self.logger.df("GET %s", keyed and (url:gsub("%?api%-key=.*$", "?api-key=***")) or url)
  self:_request(url, timeout, function(status, body, headers, timedOut)
    if type(status) ~= "number" or status < 0 then
      local message = timedOut and "ipdata did not respond in time" or "Could not reach ipdata (offline?)"
      self.logger.df("%s: %s", host, tostring(body))
      fn({ ok = false, kind = "network", message = message, status = status, source = source, host = host })
      return
    end
    local json = decodeJson(body)
    local rate = nil
    if not keyed then
      rate = rateFromHeaders(headers)
      if rate then self._rate = rate end
    end
    if status < 200 or status >= 300 then
      local kind, message = errorFor(status, json)
      fn({ ok = false, kind = kind, message = message, status = status, rate = rate, source = source, host = host })
      return
    end
    if not json or type(json.ip) ~= "string" then
      fn({ ok = false, kind = "network", message = "Unexpected response from ipdata", status = status, rate = rate, source = source, host = host })
      return
    end
    local model = normalize(json, source)
    local degraded = false
    if rate then
      local qs = str(rate.quota_status) and rate.quota_status:lower() or ""
      if qs:find("exceed") or qs:find("exhaust") or qs:find("degrad") or qs:find("limit") then degraded = true end
      if rate.remaining == 0 and json.city == nil and json.timezone == nil then degraded = true end
    end
    fn({ ok = true, model = model, raw = json, body = body, rate = rate, degraded = degraded, source = source, host = host })
  end)
end

-- ---------------------------------------------------------------------------------------------
-- Cache
-- ---------------------------------------------------------------------------------------------

obj._cache = {}

function obj:_cacheGet(key)
  local e = self._cache[key]
  if e and os.time() - e.at < (tonumber(self.cacheTTL) or 3600) then return e.res end
  self._cache[key] = nil
  return nil
end

function obj:_cachePut(key, res)
  self._cache[key] = { at = os.time(), res = res }
end

--- IPData:clearCache()
--- Method
--- Forgets every cached lookup, including your own addresses.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ipdata object
function obj:clearCache()
  self._cache = {}
  self._my = nil
  return self
end

-- ---------------------------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------------------------

--- IPData:fetch(ip, fn)
--- Method
--- Fetches the record for an address without showing anything.
---
--- Parameters:
---  * ip - An IPv4 or IPv6 address (a token such as "1.2.3.4:443" or "[2001:db8::1]:80" is
---    cleaned up first).
---  * fn - A function called once with a result table. On success it has `ok = true`, `model`
---    (the normalised record: ip, version, city, region, country_code, country_name, emoji,
---    latitude, longitude, asn, org, company, carrier, connection, time_zone, currency, languages,
---    threat), `raw` (the decoded response), `body` (the response text as ipdata sent it), `rate` (free tier: limit, remaining, reset_at),
---    `source` ("free" or "key") and `cached`. On failure it has `ok = false`, `kind`
---    ("invalid", "reserved", "network", "quota" or "key") and `message`.
---
--- Returns:
---  * The ipdata object
---
--- Notes:
---  * Results are cached for `IPData.cacheTTL` seconds. Private, loopback, link-local and
---    documentation addresses are recognised locally and never sent to ipdata.
function obj:fetch(ip, fn)
  fn = fn or function() end
  local addr = type(ip) == "string" and (clean(ip) or ip) or tostring(ip)
  if not isValid(addr) then
    fn({ ok = false, kind = "invalid", message = "Not a valid IP address", ip = addr })
    return self
  end
  local reserved = reservedLabel(addr)
  if reserved then
    fn({ ok = false, kind = "reserved", message = reserved, ip = addr })
    return self
  end
  local keyed = self:_keyed()
  local cacheKey = (keyed and ("key:" .. tostring(self.endpoint)) or "free") .. ":" .. addr
  local hit = self:_cacheGet(cacheKey)
  if hit then
    hit.cached = true
    fn(hit)
    return self
  end
  local function done(res)
    res.ip = addr
    if res.ok then self:_cachePut(cacheKey, res) end
    fn(res)
  end
  if keyed then
    self:_fetchRecord(self:_keyedUrl(addr), true, REQUEST_TIMEOUT, done)
  else
    self:_fetchRecord(FREE_BASE .. "/" .. addr, false, REQUEST_TIMEOUT, function(first)
      if not retryable(first) then return done(first) end
      self.logger.df("retrying on %s (%s)", FREE_FALLBACK, tostring(first.message))
      self:_fetchRecord(FREE_FALLBACK .. "/" .. addr, false, REQUEST_TIMEOUT, function(second)
        if second.ok then done(second) else done(first) end
      end)
    end)
  end
  return self
end

-- Bumps the display generation; a result whose generation is stale is not shown (the card was
-- closed, or another lookup started in the meantime).
function obj:_bump()
  self._gen = (self._gen or 0) + 1
  return self._gen
end

function obj:_showResult(res)
  if self.showAsAlert then
    hs.alert.show(alertText(res), ALERT_SECONDS)
  else
    self:_showHtml(page(resultBody(self, res) .. footHtml(self), hasJson(res)))
  end
end

--- IPData:lookup(ip, fn)
--- Method
--- Looks an address up and shows the result card.
---
--- Parameters:
---  * ip - An IPv4 or IPv6 address, or any text containing one.
---  * fn - An optional function called with the result table described in `IPData:fetch`.
---
--- Returns:
---  * The ipdata object
---
--- Notes:
---  * With `IPData.showAsAlert` set, a one-line alert is shown instead. Private, loopback,
---    link-local and documentation addresses are described locally without a request.
function obj:lookup(ip, fn)
  local addr = type(ip) == "string" and (clean(ip) or extract(ip)) or nil
  if not addr then
    hs.alert.show(string.format("“%s” is not an IP address", tostring(ip)), ALERT_SECONDS)
    if fn then fn({ ok = false, kind = "invalid", message = "Not an IP address", ip = tostring(ip) }) end
    return self
  end
  local gen = self:_bump()
  if not self.showAsAlert then self:_showHtml(page(loadingHtml(addr) .. footHtml(self))) end
  self:fetch(addr, function(res)
    if self.showAsAlert or self._gen == gen then self:_showResult(res) end
    if fn then fn(res) end
  end)
  return self
end

--- IPData:lookupSelection()
--- Method
--- Looks up the IP address in the current selection, or in the clipboard when nothing is selected.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ipdata object
---
--- Notes:
---  * The selection is read by sending ⌘C to the frontmost application; the previous clipboard
---    contents are restored afterwards. This is what the `lookup` hotkey calls.
function obj:lookupSelection()
  local pb = hs.pasteboard
  local before = pb.changeCount()
  local saved = pb.readAllData()
  hs.eventtap.keyStroke({ "cmd" }, "c")
  hs.timer.doAfter(0.2, function()
    local text
    if pb.changeCount() ~= before then
      text = pb.readString()
      if type(saved) == "table" and next(saved) ~= nil then pb.writeAllData(saved) else pb.clearContents() end
    end
    if type(text) ~= "string" or not text:find("%S") then text = pb.readString() end
    local ip = type(text) == "string" and extract(text) or nil
    if not ip then
      hs.alert.show("No IP address in the selection or clipboard", ALERT_SECONDS)
      return
    end
    self:lookup(ip)
  end)
  return self
end

-- ---------------------------------------------------------------------------------------------
-- Your own addresses
-- ---------------------------------------------------------------------------------------------

-- Both public addresses, each with its record, via the single-stack hosts in parallel. With a
-- key, each address found is then looked up on api.ipdata.co for the full record. fn receives
-- { ok, v4, v6, rate, message }; v4/v6 are result tables (ok = false for a family without
-- connectivity). Concurrent callers share one round of requests.
function obj:_fetchMy(force, fn)
  if not force and self._my and os.time() - self._my.at < SELF_TTL then
    fn(self._my.res)
    return
  end
  if self._myWaiters then
    self._myWaiters[#self._myWaiters + 1] = fn
    return
  end
  self._myWaiters = { fn }
  local out, pending = {}, 2
  local function deliver()
    self._my = { at = os.time(), res = out }
    local waiters = self._myWaiters
    self._myWaiters = nil
    for _, w in ipairs(waiters) do w(out) end
  end
  local function finish()
    local v4, v6 = out.v4, out.v6
    out.ok = (v4 and v4.ok) or (v6 and v6.ok) or false
    out.rate = (v4 and v4.rate) or (v6 and v6.rate) or nil
    if not out.ok then
      out.message = (v4 and v4.message) or (v6 and v6.message) or "Could not detect your IP address"
      return deliver()
    end
    if not self:_keyed() then return deliver() end
    local n = 0
    for _, fam in ipairs({ "v4", "v6" }) do
      if out[fam].ok then n = n + 1 end
    end
    for _, fam in ipairs({ "v4", "v6" }) do
      if out[fam].ok then
        self:fetch(out[fam].model.ip, function(k)
          if k.ok then out[fam] = k end
          n = n - 1
          if n == 0 then deliver() end
        end)
      end
    end
  end
  local function one(fam, r)
    out[fam] = r
    pending = pending - 1
    if pending == 0 then finish() end
  end
  self:_fetchRecord(SELF_V4, false, SELF_TIMEOUT, function(r) one("v4", r) end)
  self:_fetchRecord(SELF_V6, false, SELF_TIMEOUT, function(r) one("v6", r) end)
end

local function primaryOf(my)
  if my.v4 and my.v4.ok then return my.v4 end
  if my.v6 and my.v6.ok then return my.v6 end
  return nil
end

function obj:_showMy(my)
  local primary = primaryOf(my)
  if self.showAsAlert then
    hs.alert.show(myAlertText(my, primary), ALERT_SECONDS)
    return
  end
  local body
  if primary then
    body = resultBody(self, primary)
  else
    body = headHtml(nil) .. '<div class="ipd-msg soft">' .. esc(my.message or "Could not detect your IP address") .. '</div>'
  end
  self:_showHtml(page(body .. youHtml(my) .. footHtml(self), hasJson(primary)))
end

--- IPData:myIp(fn)
--- Method
--- Shows your public IPv4 and IPv6 addresses with the record of the primary one.
---
--- Parameters:
---  * fn - An optional function called with a table `{ ok, v4, v6, rate, message }` where `v4`
---    and `v6` are result tables as described in `IPData:fetch` (`ok = false` for a family
---    without connectivity).
---
--- Returns:
---  * The ipdata object
---
--- Notes:
---  * The two families are detected in parallel through `v4.ipdata.co` and `v6.ipdata.co`; a
---    family without connectivity shows "No IPv6 connectivity". This is what the `myip` hotkey
---    calls.
function obj:myIp(fn)
  local gen = self:_bump()
  if not self.showAsAlert then self:_showHtml(page(loadingHtml(nil) .. footHtml(self))) end
  self:_fetchMy(false, function(my)
    if self.showAsAlert or self._gen == gen then self:_showMy(my) end
    if fn then fn(my) end
  end)
  return self
end

-- ---------------------------------------------------------------------------------------------
-- The card window
-- ---------------------------------------------------------------------------------------------

-- Frame for a card of w x h points: next to the pointer (flipping to stay on screen) or centred.
-- Once sections are being opened it stays where it is, sliding up only as far as it must, and a
-- card taller than the screen scrolls inside its window.
function obj:_cardFrame(w, h)
  local c = self._card
  local f = c.screen:frame()
  h = math.min(h, f.h - 16)
  local x, y
  if c.keepTop then
    local cur = c.view:frame()
    x, y = cur.x, cur.y
  elseif self.cardPosition == "center" then
    x = f.x + (f.w - w) / 2
    y = f.y + (f.h - h) / 2
  else
    x, y = c.anchor.x + 16, c.anchor.y + 16
    if x + w > f.x + f.w - 8 then x = c.anchor.x - w - 16 end
    if y + h > f.y + f.h - 8 then y = c.anchor.y - h - 16 end
  end
  x = math.max(f.x + 8, math.min(x, f.x + f.w - w - 8))
  y = math.max(f.y + 8, math.min(y, f.y + f.h - h - 8))
  return hs.geometry.rect(math.floor(x), math.floor(y), w, h)
end

function obj:_armTimer()
  local c = self._card
  if not c then return end
  if c.timer then
    c.timer:stop()
    c.timer = nil
  end
  local secs = tonumber(self.cardTimeout) or 0
  if secs > 0 then
    c.timer = hs.timer.doAfter(secs, function() self:closeCard() end)
  end
end

-- Messages posted by the page (see JS above).
function obj:_onCardMessage(msg)
  local c = self._card
  local b = type(msg) == "table" and msg.body or nil
  if not c or type(b) ~= "table" then return end
  local act = b.action
  if act == "size" then
    local h = tonumber(b.height)
    if h and h > 40 then
      h = math.ceil(h)
      if h ~= c.h then
        c.h = h
        c.view:frame(self:_cardFrame(c.w, h))
      end
    end
  elseif act == "copy" then
    if type(b.text) == "string" and b.text ~= "" then hs.pasteboard.setContents(b.text) end
  elseif act == "open" then
    if type(b.url) == "string" and b.url:find("^https?://") then hs.urlevent.openURL(b.url) end
    hs.timer.doAfter(0, function() self:closeCard() end)
  elseif act == "lookup" then
    if type(b.ip) == "string" and b.ip ~= "" then hs.timer.doAfter(0, function() self:lookup(b.ip) end) end
  elseif act == "setkey" then
    hs.timer.doAfter(0, function() self:setApiKey() end)
  elseif act == "theme" then
    -- The page has already switched; remember the choice ("system" when it matches macOS).
    if b.value == "light" or b.value == "dark" then
      if b.value == b.system then
        self.appearance = "system"
        hs.settings.clear(APPEARANCE_KEY)
      else
        self.appearance = b.value
        hs.settings.set(APPEARANCE_KEY, b.value)
      end
    end
  elseif act == "keep" then
    c.keepTop = true
  elseif act == "view" then
    c.keepTop = true
    if b.value == "json" or b.value == "card" then self._view = b.value end
  elseif act == "close" then
    hs.timer.doAfter(0, function() self:closeCard() end)
  elseif act == "hover" then
    if c.timer then
      c.timer:stop()
      c.timer = nil
    end
  elseif act == "unhover" then
    self:_armTimer()
  end
end

-- Creates the card window (once) next to the pointer: a borderless, non-activating, transparent
-- hs.webview above other windows, plus an event tap that closes it on Escape or a click outside.
function obj:_openCard()
  if self._card then return self._card end
  local screen = (self.cardPosition ~= "center" and hs.mouse.getCurrentScreen()) or hs.screen.mainScreen()
  local c = { anchor = hs.mouse.absolutePosition(), screen = screen, w = CARD_WIDTH, h = 120 }
  self._card = c
  c.ucc = hs.webview.usercontent.new("ipdata")
  c.ucc:setCallback(function(msg) self:_onCardMessage(msg) end)
  c.view = hs.webview.new(self:_cardFrame(c.w, c.h), { developerExtrasEnabled = false, javaScriptEnabled = true }, c.ucc)
  c.view:windowStyle({ "borderless", "nonactivating" })
  c.view:level(hs.drawing.windowLevels.floating)
  c.view:behaviorAsLabels({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
  c.view:transparent(true)
  c.view:shadow(true)
  c.view:allowTextEntry(false)
  c.view:allowGestures(false)
  c.view:allowNewWindows(false)
  c.view:windowTitle("ipdata")
  c.view:show()
  local types = hs.eventtap.event.types
  c.tap = hs.eventtap.new({ types.leftMouseDown, types.rightMouseDown, types.keyDown }, function(ev)
    if ev:getType() == types.keyDown then
      if ev:getKeyCode() == hs.keycodes.map.escape then hs.timer.doAfter(0, function() self:closeCard() end) end
    else
      local p, f = ev:location(), c.view:frame()
      if not (p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h) then
        hs.timer.doAfter(0, function() self:closeCard() end)
      end
    end
    return false
  end)
  c.tap:start()
  return c
end

function obj:_showHtml(html)
  local c = self:_openCard()
  c.view:html(html)
  self:_armTimer()
end

--- IPData:closeCard()
--- Method
--- Closes the result card if one is showing.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ipdata object
function obj:closeCard()
  local c = self._card
  if not c then return self end
  self._card = nil
  self:_bump()
  if c.timer then c.timer:stop() end
  if c.tap then c.tap:stop() end
  if c.view then
    c.view:hide()
    c.view:delete()
  end
  return self
end

-- ---------------------------------------------------------------------------------------------
-- Menubar
-- ---------------------------------------------------------------------------------------------

local function copyItem(value, what)
  return function()
    hs.pasteboard.setContents(value)
    hs.alert.show("Copied " .. what, 1.5)
  end
end

function obj:_menubarMenu()
  local items = {}
  local function add(t) items[#items + 1] = t end
  local my = self._my and self._my.res or nil
  if not my then
    add({ title = "Detecting your addresses…", disabled = true })
  else
    local primary = primaryOf(my)
    if primary then
      local m = primary.model
      local place = placeOf(m).short
      add({ title = flagOf(m) .. "  " .. place, fn = copyItem(place, "location") })
      local op = operatorOf(m)
      local opText = join(" · ", operatorLine(m), op.type)
      add({ title = opText, fn = copyItem(operatorLine(m), "operator") })
      local owner = ownerOf(m)
      if owner.name and (owner.fromCompany or owner.name ~= op.name) then
        add({ title = "Owner: " .. owner.name, fn = copyItem(owner.name, "owner") })
      end
      local t = m.threat
      if t then
        local s = type(t.scores) == "table" and t.scores or {}
        local title
        if type(s.trust_score) == "number" then
          title = string.format("Trust score %d · %s", math.floor(s.trust_score), riskLabel(s.trust_score))
        else
          title = verdict(t)
        end
        add({ title = title, fn = function() hs.urlevent.openURL(SITE_URL .. m.ip) end })
      end
    else
      add({ title = my.message or "Could not detect your IP address", disabled = true })
    end
    add({ title = "-" })
    for _, fam in ipairs({ { "v4", "IPv4" }, { "v6", "IPv6" } }) do
      local r = my[fam[1]]
      if r and r.ok then
        add({ title = fam[2] .. "   " .. r.model.ip })
        add({ title = "Copy", indent = 1, fn = copyItem(r.model.ip, fam[2] .. " address") })
      else
        add({ title = "No " .. fam[2] .. " connectivity", disabled = true })
      end
    end
    if primary then
      local ip = primary.model.ip
      add({ title = "-" })
      add({ title = "Look up " .. ip, fn = function() self:lookup(ip) end })
      add({ title = "Open on ipdata.co", fn = function() hs.urlevent.openURL(SITE_URL .. ip) end })
    end
  end
  add({ title = "-" })
  add({ title = self:_keyed() and "Change API Key…" or "Add API Key…", fn = function() self:setApiKey() end })
  add({ title = "Refresh", fn = function() self:refreshMenubar() end })
  return items
end

function obj:_updateMenubar(my)
  local mb = self._menubar
  if not mb then return end
  local primary = primaryOf(my)
  if primary then
    local m = primary.model
    mb:setTitle(flagOf(m) .. " " .. m.ip)
    mb:setTooltip(placeOf(m).short .. " · " .. operatorLine(m))
  else
    mb:setTitle("ipdata · offline")
    mb:setTooltip(my.message or "Could not detect your IP address")
  end
end

--- IPData:refreshMenubar()
--- Method
--- Re-detects your addresses now and updates the menubar item.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ipdata object
---
--- Notes:
---  * Called every `IPData.menubarRefresh` seconds and after the Mac wakes while the menubar item
---    is active.
function obj:refreshMenubar()
  if not self._menubar then return self end
  self:_fetchMy(true, function(my) self:_updateMenubar(my) end)
  return self
end

--- IPData:startMenubar()
--- Method
--- Adds a menubar item showing the country flag and your public IPv4 address.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ipdata object
---
--- Notes:
---  * The item refreshes every `IPData.menubarRefresh` seconds and after wake. Its menu lists the
---    city, the operator, both addresses with "Copy" items, "Look up", "Open on ipdata.co",
---    "Add API Key…" and "Refresh".
function obj:startMenubar()
  if self._menubar then return self end
  local mb = hs.menubar.new()
  if not mb then
    self.logger.e("could not create the menubar item")
    return self
  end
  self._menubar = mb
  mb:setTitle("…")
  mb:setTooltip("ipdata · your public IP")
  mb:setMenu(function() return self:_menubarMenu() end)
  self:refreshMenubar()
  self._menubarTimer = hs.timer.doEvery(tonumber(self.menubarRefresh) or 600, function() self:refreshMenubar() end)
  self._wakeWatcher = hs.caffeinate.watcher.new(function(ev)
    if ev == hs.caffeinate.watcher.systemDidWake or ev == hs.caffeinate.watcher.screensDidWake then
      hs.timer.doAfter(5, function() self:refreshMenubar() end)
    end
  end)
  self._wakeWatcher:start()
  return self
end

--- IPData:stopMenubar()
--- Method
--- Removes the menubar item and stops its refresh timer.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The ipdata object
function obj:stopMenubar()
  if self._menubarTimer then
    self._menubarTimer:stop()
    self._menubarTimer = nil
  end
  if self._wakeWatcher then
    self._wakeWatcher:stop()
    self._wakeWatcher = nil
  end
  if self._menubar then
    self._menubar:delete()
    self._menubar = nil
  end
  return self
end

-- ---------------------------------------------------------------------------------------------
-- API key
-- ---------------------------------------------------------------------------------------------

-- "abcd…wxyz": enough to recognise a saved key without showing it.
local function maskKey(k)
  if #k <= 10 then return string.rep("•", #k) end
  return k:sub(1, 4) .. "…" .. k:sub(-4)
end

-- Checks a key with one small request. fn(verdict, message), verdict "ok", "rejected" or
-- "unverified" (ipdata could not be reached, or answered something other than yes or no).
function obj:_checkKey(key, fn)
  self:_request(self:_keyedUrl("8.8.8.8", key) .. "&fields=ip", REQUEST_TIMEOUT, function(status, body)
    if status == 200 then return fn("ok") end
    if status == 401 then return fn("rejected", "ipdata rejected this key") end
    if type(status) ~= "number" or status < 0 then return fn("unverified", "ipdata could not be reached") end
    local json = decodeJson(body)
    fn("unverified", (type(json) == "table" and str(json.message)) or ("HTTP " .. tostring(status)))
  end)
end

--- IPData:setApiKey([key])
--- Method
--- Adds, changes or removes the ipdata API key, saved in Hammerspoon's settings.
---
--- Parameters:
---  * key - An optional string: the key to save, or "" to remove the saved key. Omit it for the prompt.
---
--- Returns:
---  * The ipdata object
---
--- Notes:
---  * Without an argument a prompt asks for the key; "Add API key…" on a card, the pill in the
---    card's footer and "Add API Key…" in the menubar menu open it too. The key is checked with
---    one request to ipdata before it is saved, and a key ipdata rejects is not saved. An empty key
---    removes the saved one. `IPData.apiKey` set in init.lua takes priority over the saved key.
function obj:setApiKey(key)
  if key == nil then
    self:closeCard()
    local saved = str(hs.settings.get(SETTINGS_KEY))
    local info = "Paste your key from dashboard.ipdata.co. With a key, cards show the company, carrier, trust score and threat data."
    if saved then info = info .. "\n\nSaved key: " .. maskKey(saved) .. ". Leave the field empty and click Save to remove it." end
    if str(self.apiKey) then info = info .. "\n\nspoon.IPData.apiKey is set in init.lua and takes priority over a saved key." end
    local front = hs.application.frontmostApplication()
    hs.focus()
    local button, text = hs.dialog.textPrompt("ipdata API key", info, "", "Save", "Cancel")
    if front then front:activate() end
    if button ~= "Save" then return self end
    key = text
  end
  key = tostring(key or ""):gsub("%s", "")
  local function changed()
    self:clearCache()
    if self._menubar then self:refreshMenubar() end
  end
  if key == "" then
    hs.settings.clear(SETTINGS_KEY)
    changed()
    hs.alert.show("ipdata API key removed", 2)
    return self
  end
  hs.alert.show("Checking the ipdata API key…", 1.5)
  self:_checkKey(key, function(verdict, message)
    if verdict == "rejected" then
      hs.alert.show("⚠️ " .. message .. ". It was not saved.", 4)
      return
    end
    hs.settings.set(SETTINGS_KEY, key)
    changed()
    local note = str(self.apiKey) and " (the key in init.lua still takes priority)" or ""
    if verdict == "ok" then
      hs.alert.show("ipdata API key saved" .. note, 2.5)
    else
      hs.alert.show("ipdata API key saved without a check: " .. message .. note, 4)
    end
  end)
  return self
end

-- ---------------------------------------------------------------------------------------------
-- Hotkeys
-- ---------------------------------------------------------------------------------------------

--- IPData:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ipdata.
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * lookup - Look up the IP address in the current selection (or the clipboard)
---   * myip - Show your public IPv4 and IPv6 addresses
---   * apikey - Add, change or remove the ipdata API key (opens a prompt)
---
--- Returns:
---  * The ipdata object
function obj:bindHotkeys(mapping)
  local def = {
    lookup = hs.fnutils.partial(self.lookupSelection, self),
    myip = hs.fnutils.partial(self.myIp, self),
    apikey = function() self:setApiKey() end,
  }
  hs.spoons.bindHotkeysToSpec(def, mapping)
  return self
end

return obj

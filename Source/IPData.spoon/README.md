# IPData.spoon

IP address lookups from a hotkey, powered by [ipdata](https://ipdata.co). Select or copy an address anywhere on your Mac, press the hotkey, and a card shows where it is, who operates it, who owns it and, with an API key, whether it is a VPN, proxy, Tor exit or known threat. A second hotkey shows your own public IPv4 and IPv6 addresses, and an optional menubar item keeps your IP in view.

No account is needed: ipdata's free service allows 1,000 city-level lookups per day from your connection. An API key from [dashboard.ipdata.co](https://dashboard.ipdata.co) unlocks the full record.

## Install

1. Copy `IPData.spoon` to `~/.hammerspoon/Spoons/` (or download the zip from the Spoons repository and double-click it).
2. Add to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("IPData")
spoon.IPData:bindHotkeys({ lookup = {{"cmd", "alt"}, "i"}, myip = {{"cmd", "alt"}, "m"} })
-- optional
spoon.IPData.apiKey = "your-ipdata-api-key"   -- or click "Add API key…" on a card
spoon.IPData:startMenubar()
```

3. Reload the Hammerspoon config.

Hammerspoon needs Accessibility access (System Settings → Privacy & Security → Accessibility) for the hotkeys, the ⌘C that reads the selection and the Escape / click-outside handling of the card. The Spoon asks for nothing else: no Screen Recording, no Automation, no network beyond the ipdata hosts.

## What you get

**⌘⌥I (lookup)**: the Spoon copies the current selection (⌘C, the previous clipboard is restored afterwards), or falls back to the clipboard, finds the first IP address in it (also inside URLs, log lines, `host:port`, `[v6]:port`, CIDR prefixes and `key=value` pairs) and shows a macOS-style popover card, in the system font and colours, with the details as rows of an inset group like System Settings:

- header: flag emoji, city, region and country, the address with copy and open-on-ipdata.co buttons
- **Operator**: ASN number, usage type and name
- **Owner**: company name, domain and network; when there is no company record (free tier) or it is a registry placeholder such as "Provider Lir", the operator's organisation with its domain and route stands in
- **Coordinates** with an "Open in Maps" link
- **Trust score** as a tinted badge with risk band and verdict; without a key, "Needs an API key" with an **Add API key…** link
- threat chips (Tor, VPN, proxy, datacenter, known attacker, …), only when a flag is set
- seven disclosure rows that open in place: **Location** (city, region, postal code, country, continent, coordinates, time zone, local time, currency, languages, calling code), **Blocklists** (each list with its type, first and last seen, days seen), **Scores** (trust, threat, VPN, proxy), **Flags** (every flag, the set ones tinted), **Connection** (mobile, carrier, anycast, leased, satellite), **Owner** and **Operator** (name, domain, network or route, type). Blocklists, Scores, Flags and Connection need an API key; without one they offer **Add API key…**
- footer: "Powered by ipdata" and the remaining free lookups for today, from the `RateLimit-Remaining` header (click it to add an API key)
- a **Card / JSON** switch in the corner beside the sun/moon button: JSON shows the response exactly as ipdata sent it, re-indented with syntax colours, the request it answered and a copy button; the card remembers the view until Hammerspoon reloads
- a sun/moon button in the corner switches between light and dark and remembers the choice; switching back to the appearance macOS is using follows the system again

The card closes on Escape, on a click outside it, or after `cardTimeout` seconds (the countdown pauses while the pointer is over it). It follows the system appearance unless you pick light or dark with its sun/moon button (or set `appearance`).

**⌘⌥M (myip)**: your public IPv4 and IPv6 addresses, detected in parallel through `v4.ipdata.co` and `v6.ipdata.co`, with the record of the primary one. A family without connectivity shows "No IPv6 connectivity". Click an address row to look it up, or its copy button to copy it.

**Menubar** (`spoon.IPData:startMenubar()`): flag and IPv4 in the menubar, refreshed every 10 minutes and after wake. The menu lists city, operator, owner and trust score (click to copy), both addresses with "Copy" items, "Look up", "Open on ipdata.co" and "Refresh".

Private, loopback, link-local, carrier-grade NAT, multicast and documentation addresses are recognised locally and never sent anywhere. Lookups are cached for an hour.

## Configuration

| Field | Default | Meaning |
|---|---|---|
| `spoon.IPData.apiKey` | `nil` | ipdata API key. With one, lookups use `api.ipdata.co` and show company, carrier, threat and trust data. Takes priority over a key saved with **Add API key…**. |
| `spoon.IPData.endpoint` | `"global"` | `"eu"` uses `eu-api.ipdata.co` (EU data residency). Only with a key. |
| `spoon.IPData.cardTimeout` | `12` | Seconds before the card closes by itself; `0` keeps it open until Escape or a click outside. |
| `spoon.IPData.cardPosition` | `"mouse"` | `"mouse"` next to the pointer, `"center"` in the middle of the screen. |
| `spoon.IPData.appearance` | `"system"` | `"light"` or `"dark"` forces the card's appearance. The card's sun/moon button sets it too and remembers it; a value set here takes priority. |
| `spoon.IPData.showAsAlert` | `false` | `true` shows a one-line `hs.alert` ("City, Country · ASxxxx Operator") instead of the card. |
| `spoon.IPData.cacheTTL` | `3600` | Seconds a lookup stays cached. |
| `spoon.IPData.menubarRefresh` | `600` | Seconds between menubar refreshes. |
| `spoon.IPData.logger` | `hs.logger.new("ipdata")` | `spoon.IPData.logger.setLogLevel("debug")` logs every request. |

## Scripting

```lua
spoon.IPData:lookup("81.2.69.142")                 -- shows the card
spoon.IPData:fetch("81.2.69.142", function(res)    -- data only
  if res.ok then print(res.model.city, res.model.asn.asn, res.model.org) else print(res.kind, res.message) end
end)
spoon.IPData:myIp(function(my) print(my.v4 and my.v4.model.ip, my.v6 and my.v6.ok) end)
spoon.IPData.extractIp("src=1.2.3.4:443 dst=[2001:db8::1]:80")   -- "1.2.3.4"
spoon.IPData.reservedLabel("10.0.0.1")                             -- "Private network address (RFC 1918)"
spoon.IPData:setApiKey()          -- prompt; setApiKey("KEY") saves a key, setApiKey("") removes it
spoon.IPData:clearCache()
```

`fetch` and `lookup` deliver a result table: `ok`, `model` (ip, version, city, region, country_code, country_name, emoji, latitude, longitude, asn, org, company, carrier, connection, time_zone, currency, languages, threat), `raw` (the decoded response), `body` (the response text exactly as ipdata returned it), `rate` (free tier: limit, remaining, reset_at), `source` ("free" or "key"), `cached`; or `ok = false` with `kind` ("invalid", "reserved", "network", "quota", "key") and `message`.

## Free tier and API key

| | Free (`ipdata.co`, fallback `ipdata.free`) | API key (`api.ipdata.co` / `eu-api.ipdata.co`) |
|---|---|---|
| Fields | ip, city, region, country, coordinates, postal code, ASN, organisation, time zone | everything, including company, carrier, threat intelligence and scores |
| Quota | 1,000 city-level lookups per day from your connection, then country-level data until the daily reset | per plan |
| Footer | "Free · N left" | "API key" |

**Adding a key.** Click **Add API key…** in a card's Trust score row (or the pill in its footer), choose **Add API Key…** in the menubar menu, or bind the `apikey` hotkey (`spoon.IPData:bindHotkeys({ apikey = {{"cmd", "alt"}, "k"} })`). Paste the key from [dashboard.ipdata.co](https://dashboard.ipdata.co) and click Save. The Spoon checks it with one request and saves it in Hammerspoon's settings (`hs.settings`, kept in Hammerspoon's preferences file), so it survives reloads; a key ipdata rejects is not saved. Open the prompt again and save an empty field to remove the key.

## License

MIT. Flags are the system's emoji; the free tier requires the visible "Powered by ipdata" credit the card carries.

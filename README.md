# ICEDRAGON HUB

Multi-game Roblox hub (`tumbalakbseu2-oss/ICEDRAGON-HUB`) with an open Frost Key UI loader (`loader.lua`), non-HWID Cloudflare Worker key preflight (`icedragon-hub.andika8899a.workers.dev`), and homemade-obfuscated payloads served directly from VampAuth.

## Universal Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/tumbalakbseu2-oss/ICEDRAGON-HUB/main/loader.lua"))()
```

- Get Key: `https://vampauth.com/JUHQH1GGWXPPS4UU/flow`
- Saved keys are cached locally in `icedragon_hub_key.txt` (run `_G.ICEDRAGON_RESET_KEY()` to reset).

## Supported Games

| Game | PlaceId | GameId (Universe) | Delivery |
| --- | --- | --- | --- |
| Dragon Arena | `83694443310872` | `10771238997` | VampAuth Hosted Loader |
| Do Not Stop | `116779912472448` (+ sub-places) | `10772946647` | VampAuth Hosted Loader |

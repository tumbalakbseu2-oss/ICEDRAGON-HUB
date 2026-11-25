# ICEDRAGON HUB

Multi-game Roblox script hub managed under `tumbalakbseu2-oss/ICEDRAGON-HUB`, protected by VampAuth via Cloudflare Worker (`icedragon-hub.andika8899a.workers.dev`).

## Universal Loader (with Frost Key UI)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/tumbalakbseu2-oss/ICEDRAGON-HUB/main/loader.lua"))()
```

- Get Key: `https://vampauth.com/JUHQH1GGWXPPS4UU/flow`
- Saved keys are cached locally in `icedragon_hub_key.txt` (run `_G.ICEDRAGON_RESET_KEY()` to reset).

## Supported Games

| Game | PlaceId | GameId (Universe) | Script Path |
| --- | --- | --- | --- |
| Dragon Arena | `83694443310872` | `10771238997` | `games/dragon_arena_empire_hub.lua` |
| Do Not Stop | `116779912472448` (+ sub-places) | `10772946647` | `games/do_not_stop.lua` |

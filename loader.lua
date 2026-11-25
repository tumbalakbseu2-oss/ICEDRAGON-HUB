--!strict
-- ==============================================================================
-- ICEDRAGON HUB | MULTI-GAME UNIVERSAL LOADER
-- Repository: https://github.com/tumbalakbseu2-oss/ICEDRAGON-HUB
-- ==============================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local RAW_BASE = "https://raw.githubusercontent.com/tumbalakbseu2-oss/ICEDRAGON-HUB/main/"

-- Add new games by PlaceId (exact place) or GameId (universe across sub-places)
local GAMES_BY_PLACE_ID: { [number]: { Name: string, Path: string } } = {
    [83694443310872] = {
        Name = "Dragon Arena",
        Path = "games/dragon_arena_empire_hub.lua",
    },
}

local GAMES_BY_GAME_ID: { [number]: { Name: string, Path: string } } = {
    -- Example: [1234567890] = { Name = "Phighting", Path = "games/phighting.lua" },
}

local entry = GAMES_BY_PLACE_ID[game.PlaceId] or GAMES_BY_GAME_ID[game.GameId]
if not entry then
    warn(string.format(
        "[ICEDRAGON HUB] Unsupported game! PlaceId=%d | GameId=%d",
        tonumber(game.PlaceId) or 0,
        tonumber(game.GameId) or 0
    ))
    return
end

local url = RAW_BASE .. entry.Path
local okGet, source = pcall(function()
    return game:HttpGet(url)
end)

if not okGet or type(source) ~= "string" or #source == 0 then
    warn("[ICEDRAGON HUB] Failed to fetch " .. entry.Name .. " script from: " .. url)
    return
end

local fn, compileErr = loadstring(source, entry.Name)
if not fn then
    warn("[ICEDRAGON HUB] Compile error in " .. entry.Name .. ": " .. tostring(compileErr))
    return
end

print("[ICEDRAGON HUB] Loading " .. entry.Name .. "...")
local okRun, runErr = xpcall(fn, debug.traceback)
if not okRun then
    warn("[ICEDRAGON HUB] Runtime error in " .. entry.Name .. ": " .. tostring(runErr))
end

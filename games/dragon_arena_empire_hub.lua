--!strict
-- ==============================================================================
-- DRAGON ARENA | EMPIRE HUB
-- SUBTITLE: MADE BY ICEDRAGON (@ROBLOX_icedragonScript)
-- Target: Dragon Arena (PlaceId: 83694443310872)
-- UI Engine: WindUI (v1.6.66)
-- Styling: Ice Dragon Frost Edition (Glassmorphism 0.7 Transparency)
-- Official YouTube: https://www.youtube.com/@ROBLOX_icedragonScript
-- Official Discord: https://discord.gg/R2CSxzeCU
-- Architecture: Flamework Native Injection, Janitor Lifecycle, Mutually Exclusive Guards
-- ==============================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local YOUTUBE_URL = "https://www.youtube.com/@ROBLOX_icedragonScript"
local DISCORD_URL = "https://discord.gg/R2CSxzeCU"
local SUBSCRIBE_TEMPLATE = "dont forget subscribe like share comment " .. YOUTUBE_URL

local function SafeSetClipboard(text: string)
    local _ok, _err = pcall(function()
        local fn = (typeof(setclipboard) == "function" and setclipboard)
            or (typeof(toclipboard) == "function" and toclipboard)
        if fn then fn(text) end
    end)
end

SafeSetClipboard(SUBSCRIBE_TEMPLATE)

-- ------------------------------------------------------------------------------
-- 0. CLEANUP EXISTING EMPIRE HUB INSTANCES
-- ------------------------------------------------------------------------------
local _ok, _err = pcall(function()
    _G.SmartGachaRunning = false
    _G.AutoClaimersRunning = false
    _G.HarvestEventRunning = false
    _G.PlotCombatRunning = false
    _G.NestAutomationRunning = false

    if _G.EmpireHub then
        if _G.EmpireHub.State then _G.EmpireHub.State.Running = false end
        if _G.EmpireHub.Janitor then local _jok, _jerr = pcall(function() _G.EmpireHub.Janitor:Clean() end) end
        if _G.EmpireHub.Window then local _wok, _werr = pcall(function() _G.EmpireHub.Window:Destroy() end) end
        _G.EmpireHub = nil
    end

    local hui = (gethui and gethui()) or game:GetService("CoreGui")
    for _, child in ipairs(hui:GetChildren()) do
        if child.Name == "WindUI" or child.Name:sub(1, 7) == "WindUI/" or child.Name == "EmpireOpenButton" or child.Name == "VantaDragonArena" then
            local _ok, _err = pcall(function() child:Destroy() end)
        end
    end
end
)

-- ------------------------------------------------------------------------------
-- 1. CONNECTION JANITOR (Leak-Free Lifecycle Management)
-- ------------------------------------------------------------------------------
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    local self = setmetatable({}, Janitor)
    self._tasks = {}
    self._isCleaned = false
    return self
end

function Janitor:Add(taskItem, methodName)
    if self._isCleaned then return taskItem end
    if not taskItem then return nil end
    table.insert(self._tasks, { item = taskItem, method = methodName })
    return taskItem
end

function Janitor:Clean()
    if self._isCleaned then return end
    self._isCleaned = true

    for index = #self._tasks, 1, -1 do
        local entry = self._tasks[index]
        local item = entry.item
        local method = entry.method

        if type(item) == "function" then
            local _ok, _err = pcall(item)
        elseif typeof(item) == "RBXScriptConnection" then
            if item.Connected then local _cok, _cerr = pcall(function() item:Disconnect() end) end
        elseif typeof(item) == "Instance" then
            local _ok, _err = pcall(function() item:Destroy() end)
        elseif type(item) == "table" then
            if method and type(item[method]) == "function" then
                local _ok, _err = pcall(function() item[method](item) end)
            elseif type(item.Destroy) == "function" then
                local _ok, _err = pcall(function() item:Destroy() end)
            elseif type(item.Disconnect) == "function" then
                local _ok, _err = pcall(function() item:Disconnect() end)
            end
        end
        self._tasks[index] = nil
    end
    table.clear(self._tasks)
end

function Janitor:Destroy()
    self:Clean()
end

local MainJanitor = Janitor.new()

-- ------------------------------------------------------------------------------
-- 2. FLAMEWORK CONTROLLERS RESOLVER (Native Contract Binding)
-- ------------------------------------------------------------------------------
local godawork = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules")["@data-vegle"].godawork.out)
local Flamework = godawork.Flamework

local fightController        = Flamework.resolveDependency("8e4") -- FightController
local harvestMapController   = Flamework.resolveDependency("jAd") -- HarvestMapController
local harvestFightController = Flamework.resolveDependency("3G8") -- HarvestFightController
local orbController          = Flamework.resolveDependency("1Mb") -- OrbController
local indexController        = Flamework.resolveDependency("kyL") -- IndexController
local teamController         = Flamework.resolveDependency("ppJ") -- TeamController
local pedestalController     = Flamework.resolveDependency("Jd0") -- EggPedestalController
local plotController         = Flamework.resolveDependency("B6z") -- PlotController
local eggController          = Flamework.resolveDependency("Pda") -- EggController
local waveController         = Flamework.resolveDependency("nOk") -- WaveRewardController
local dailyController        = Flamework.resolveDependency("1ER") -- DailyRewardController
local codeController         = Flamework.resolveDependency("eEk") -- CodeController
local nestController         = Flamework.resolveDependency("WwA") -- NestController
local dragonController       = Flamework.resolveDependency("aBn") -- DragonController
local breedController        = Flamework.resolveDependency("R6E") -- BreedController
local wheelController        = Flamework.resolveDependency("kG6") -- WheelController
local wishingWellController  = Flamework.resolveDependency("vKl") -- WishingWellController
local currencyController     = pedestalController and pedestalController.currencyController

local _okStat, statUpgradeController = pcall(function() return Flamework.resolveDependency("687") end)
if not _okStat then statUpgradeController = nil end
local _okPlotUp, plotUpgradeController = pcall(function() return Flamework.resolveDependency("P7E") end)
if not _okPlotUp then plotUpgradeController = nil end

if not statUpgradeController or not plotUpgradeController then
    local _flameUv = debug.getupvalues and debug.getupvalues(Flamework.resolveDependency)
    local _modding = _flameUv and _flameUv[4]
    local _singletons = _modding and _modding.getSingletons and _modding.getSingletons()
    if _singletons then
        for ctor, inst in pairs(_singletons) do
            if not statUpgradeController and tostring(ctor) == "StatUpgradeController" then
                statUpgradeController = inst
            elseif not plotUpgradeController and tostring(ctor) == "PlotUpgradeController" then
                plotUpgradeController = inst
            end
        end
    end
end

local STAT_UPGRADE_PRICES = {
    eggLuck = { 6000, 16000, 40000, 80000, 150000, 270000, 470000, 800000, 1300000, 5000000 },
    rollingPedestals = { 5000, 25000, 150000, 1200000, 5000000, 25000000 },
}

local function GetStatUpgradeInfo(statName: string): (number, number?)
    if not statUpgradeController or not plotController then
        return 0, nil
    end
    local myPlot = plotController:getPlot()
    local lvl = 0
    if myPlot and statUpgradeController.getPlotLevel then
        local _ok, res = pcall(function()
            return statUpgradeController:getPlotLevel(myPlot, statName)
        end)
        if _ok and type(res) == "number" then
            lvl = res
        end
    end
    local priceTable = STAT_UPGRADE_PRICES[statName]
    local nextPrice = priceTable and priceTable[lvl + 1] or nil
    return lvl, nextPrice
end

-- Hook controller methods to silence false server rejection spam
local dummyPromise = {
    andThen = function(self, fn) return self end,
    catch = function(self, fn) return self end,
    await = function() return true end
}
if waveController and not waveController._vantaGuarded then
    waveController._vantaGuarded = true
    local origClaim = waveController.claimPatch
    waveController.claimPatch = function(self, ...)
        if waveController.hasPatchRewards and not waveController:hasPatchRewards() then
            return dummyPromise
        end
        return origClaim(self, ...)
    end
end
if dailyController and not dailyController._vantaGuarded then
    dailyController._vantaGuarded = true
    local origDaily = dailyController.claim
    dailyController.claim = function(self, ...)
        if dailyController.getSecondsUntilNextDay and dailyController:getSecondsUntilNextDay() > 0 then
            return dummyPromise
        end
        return origDaily(self, ...)
    end
end
if nestController and not nestController._vantaGuarded then
    nestController._vantaGuarded = true
    local origPlace = nestController.placeDragon
    nestController.placeDragon = function(self, nestId, dragonId, ...)
        if nestController.getContent then
            local c = nestController:getContent(nestId)
            if c and c.kind ~= "empty" then return dummyPromise end
        end
        if breedController and breedController.isBreeding and breedController:isBreeding(dragonId) then return dummyPromise end
        if fightController and fightController.isFightingDragon and fightController:isFightingDragon(dragonId) then return dummyPromise end
        if nestController.isNested and nestController:isNested(dragonId) then return dummyPromise end
        return origPlace(self, nestId, dragonId, ...)
    end
end

local function HasCoins(amount: number): boolean
    if currencyController and currencyController.hasMinAmountOf then
        local _ok, has = pcall(function() return currencyController:hasMinAmountOf("coins", amount) end)
        if _ok and has ~= nil then return has end
    end
    local raw = LocalPlayer.leaderstats and LocalPlayer.leaderstats:FindFirstChild("Coins") and LocalPlayer.leaderstats.Coins.Value
    if typeof(raw) == "number" then
        return raw >= amount
    elseif typeof(raw) == "string" then
        local numStr, suffix = string.match(raw, "^([%d%.]+)%s*([KkMmBbTt]?)$")
        if numStr then
            local n = tonumber(numStr) or 0
            suffix = string.upper(suffix or "")
            if suffix == "K" then n = n * 1e3
            elseif suffix == "M" then n = n * 1e6
            elseif suffix == "B" then n = n * 1e9
            elseif suffix == "T" then n = n * 1e12
            end
            return n >= amount
        end
    end
    return true
end

local function PullGachaLever()
    local myPlot = plotController and plotController:getPlot()
    local leverPart = myPlot and myPlot:FindFirstChild("EggPedestal")
        and myPlot.EggPedestal:FindFirstChild("Console")
        and myPlot.EggPedestal.Console:FindFirstChild("Lever")
        and myPlot.EggPedestal.Console.Lever:FindFirstChild("Primary")

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hrp and leverPart and (hrp.Position - leverPart.Position).Magnitude > 6 then
        hrp.CFrame = leverPart.CFrame + Vector3.new(0, 1.5, 2.5)
        task.wait(0.15)
    end

    local usedPrompt = false
    local prompt = leverPart and leverPart:FindFirstChildOfClass("ProximityPrompt")
    if prompt and prompt.Enabled then
        if fireproximityprompt then
            local _fok = pcall(function() fireproximityprompt(prompt) end)
            if _fok then usedPrompt = true end
        end
        if not usedPrompt and getconnections then
            for _, conn in ipairs(getconnections(prompt.Triggered)) do
                local _cok = pcall(function() conn:Fire() end)
                if _cok then usedPrompt = true end
            end
        end
    end

    if not usedPrompt and pedestalController then
        local _pok, _perr = pcall(function()
            local p = pedestalController:pull()
            if p and p.catch then p:catch(function() end) end
        end)
    end
end

local function IsDragonBusy(dragonId: string, checkNested: boolean): boolean
    if breedController and breedController.isBreeding and breedController:isBreeding(dragonId) then
        return true
    end
    if teamController and teamController.isEquipped and teamController:isEquipped(dragonId) then
        return true
    end
    if fightController and fightController.isFightingDragon and fightController:isFightingDragon(dragonId) then
        return true
    end
    if checkNested and nestController and nestController.isNested and nestController:isNested(dragonId) then
        return true
    end
    return false
end

local function PlaceIdleDragonsInNests(reserveForEggs: boolean): number
    if not nestController or not dragonController then return 0 end
    local freeNests = nestController:getFreeNests()
    if not freeNests or #freeNests == 0 then return 0 end
    if reserveForEggs and #freeNests <= 1 then return 0 end

    table.sort(freeNests, function(a, b)
        local aFloor, aIdx = string.match(tostring(a), "(%d+)%-(%d+)")
        local bFloor, bIdx = string.match(tostring(b), "(%d+)%-(%d+)")
        local aVal = (tonumber(aFloor) or 0) * 100 + (tonumber(aIdx) or 0)
        local bVal = (tonumber(bFloor) or 0) * 100 + (tonumber(bIdx) or 0)
        return aVal < bVal
    end)

    local maxToFill = reserveForEggs and (#freeNests - 1) or #freeNests
    local dragons = dragonController:getDragons() or {}
    local eligible = {}
    for _, drag in ipairs(dragons) do
        if drag and drag.id and not IsDragonBusy(drag.id, true) then
            table.insert(eligible, drag)
        end
    end
    if #eligible == 0 then return 0 end

    table.sort(eligible, function(a, b)
        local pa = (dragonController.getPower and dragonController:getPower(a.id)) or (a.level or 0)
        local pb = (dragonController.getPower and dragonController:getPower(b.id)) or (b.level or 0)
        return pa > pb
    end)

    local placedCount = 0
    local dragIdx = 1
    for i = 1, maxToFill do
        local nestId = freeNests[i]
        local drag = eligible[dragIdx]
        if not nestId or not drag then break end
        local c = nestController:getContent(nestId)
        if c and c.kind == "empty" then
            local p = nestController:placeDragon(nestId, drag.id)
            if p and p.catch then p:catch(function() end) end
            if p and p.await then pcall(function() p:await() end) end
            task.wait(0.2)
            local after = nestController:getContent(nestId)
            if after and after.kind == "dragon" then
                placedCount += 1
                dragIdx += 1
            else
                -- If dragon failed placement, advance dragIdx to try next candidate rather than spinning on same dragon
                dragIdx += 1
            end
        end
    end
    return placedCount
end

local cachedWellPlot = nil
local cachedWellModel = nil
local function GetWishingWellModel(): Instance?
    local myPlot = plotController and plotController:getPlot()
    if not myPlot then return nil end
    if cachedWellPlot == myPlot and cachedWellModel and cachedWellModel.Parent then
        return cachedWellModel
    end
    cachedWellPlot = myPlot
    cachedWellModel = myPlot:FindFirstChild("WishingWell", true)
    return cachedWellModel
end


-- ------------------------------------------------------------------------------
-- 3. CENTRALIZED STATE STORE
-- ------------------------------------------------------------------------------
local HubState = {
    Running = true,

    -- Mode Pertarungan (Mutually Exclusive / Anti-Bentrok)
    AutoHarvestEvent = false,
    AutoPlotCombat = false,

    -- Opsi Pertarungan
    CombatFastSpeed = true,
    CombatAutoRevive = true,
    CombatSkipCutscenes = true,

    -- Smart Gacha & Filter
    AutoSmartGacha = false,
    GachaMinLevel = 4,
    GachaElements = {
        earth = true,
        fire = true,
        water = true,
        ice = true,
        secret = true,
        exclusive = true,
        event = true
    },
    GachaUnindexedOnly = false,
    AutoClaimIndex = true,

    -- Sarang & Tim Naga
    AutoUnlockNests = false,
    AutoPlaceEggs = true,
    AutoOpenEggs = true,
    AutoCollectHatched = false,
    AutoPlaceDragons = true,
    AutoEquipBest = true,
    AutoBreeding = false,

    -- Hadiah & Otomatisasi
    AutoDropVacuum = true,
    AutoClaimWaves = true,
    AutoClaimDaily = true,
    AutoSpinWheel = true,
    AutoWishingWell = true,
    AutoUpgradeEggLuck = false,
    AutoUpgradePedestals = false,
    AutoUnlockFloors = true,

    -- Visuals & ESP
    ESPPlayers = false,
    ESPEggs = false,
    ESPOrbs = false,
    ESPDragons = false,
    ESPDistance = true,
}

local KNOWN_CODES = {
    "RELEASE", "DRAGON", "ARENA", "THANKSGIVING", "HARVEST", "UPDATE1", "FREEBOOST", "EGG"
}

-- References for UI Elements to enable programmatic sync
local UIElements = {
    ToggleHarvest = nil,
    TogglePlot = nil,
    ToggleFastEvent = nil,
    ToggleFastPlot = nil,
    ToggleReviveEvent = nil,
    ToggleRevivePlot = nil,
    ToggleSkipEvent = nil,
    ToggleSkipPlot = nil,
    StatusParagraph = nil,
}
local isSyncingUI = false

-- ------------------------------------------------------------------------------
-- 4. ANTI-BENTROK SWITCHER (Mutually Exclusive Arena Logic)
-- ------------------------------------------------------------------------------
local function ActivateHarvestEvent(enabled: boolean)
    if isSyncingUI then return end
    if enabled then
        -- 1. Matikan Plot Combat jika sedang aktif agar tidak bentrok
        if HubState.AutoPlotCombat then
            HubState.AutoPlotCombat = false
            if UIElements.TogglePlot then
                isSyncingUI = true
                local _ok, _err = pcall(function() UIElements.TogglePlot:Set(false) end)
                isSyncingUI = false
            end
            local _ok, _err = pcall(function() fightController:stopFight() end)
        end

        HubState.AutoHarvestEvent = true

        -- 2. Teleport ke Event Map jika belum di map
        if not harvestMapController:isInMap() then
            local _ok, _err = pcall(function() harvestMapController:teleport() end)
            task.wait(1)
        end

        -- 3. Mulai pertarungan event
        if not harvestFightController:isFighting() then
            local _ok, _err = pcall(function() harvestFightController:startFight() end)
        end
    else
        HubState.AutoHarvestEvent = false
        if harvestFightController:isFighting() then
            local _ok, _err = pcall(function() fightController:stopFight() end)
        end
    end
end

local function ActivatePlotCombat(enabled: boolean)
    if isSyncingUI then return end
    if enabled then
        -- 1. Matikan Harvest Event jika sedang aktif agar tidak bentrok
        if HubState.AutoHarvestEvent then
            HubState.AutoHarvestEvent = false
            if UIElements.ToggleHarvest then
                isSyncingUI = true
                local _ok, _err = pcall(function() UIElements.ToggleHarvest:Set(false) end)
                isSyncingUI = false
            end
            local _ok, _err = pcall(function() fightController:stopFight() end)
            if harvestMapController:isInMap() then
                local _ok, _err = pcall(function() harvestMapController:returnToPlot() end)
                task.wait(1.5)
            end
        end

        -- 2. Pastikan arena diarahkan ke plot dan auto-fight aktif
        local _aok, _aerr = pcall(function()
            fightController:setHomeArena("plot")
            fightController:setAutoFight(true)
        end)

        HubState.AutoPlotCombat = true

        -- 3. Mulai pertarungan plot
        if not fightController:isFightingIn("plot") then
            local _ok, _err = pcall(function() fightController:startFight("plot") end)
        end
    else
        HubState.AutoPlotCombat = false
        if fightController:isFightingIn("plot") then
            local _ok, _err = pcall(function() fightController:stopFight() end)
        end
    end
end

local function SetCombatOption(key: string, val: boolean, siblingElement: any?)
    if isSyncingUI then return end
    HubState[key] = val
    if siblingElement then
        isSyncingUI = true
        local _sok = pcall(function() siblingElement:Set(val) end)
        isSyncingUI = false
    end
end

-- ------------------------------------------------------------------------------
-- 5. BACKGROUND DAEMONS (Lifecycle Managed via Janitor)
-- ------------------------------------------------------------------------------

-- Loop A: Pertarungan & Auto Utility (Throttled, Contract-Accurate)
local lastFastSpeedAttempt = 0
local lastReviveAttempt = 0
local collectedOrbsCache: { [string]: number } = {}

local function HandleSharedCombatAssists()
    if not fightController then return end
    local now = os.clock()

    if HubState.CombatFastSpeed and not fightController:isFastSpeedSelected() then
        if now - lastFastSpeedAttempt >= 12.0 then
            lastFastSpeedAttempt = now
            local _fok = pcall(function()
                local p = fightController:setFastSpeed(true)
                if p and p.catch then p:catch(function() end) end
            end)
        end
    end

    if HubState.CombatSkipCutscenes then
        local _cok = pcall(function()
            if fightController.canShowBossNotif and fightController:canShowBossNotif() then
                fightController:markBossNotifSeen()
            end
            local st = fightController.getState and fightController:getState()
            if st and st.phase == "bossCutscene" and fightController.endBossCutscene then
                fightController:endBossCutscene()
            end
        end)
    end

    if HubState.CombatAutoRevive then
        local _rok = pcall(function()
            local lr = fightController.getLastResult and fightController:getLastResult()
            if lr and lr.canRevive and (not fightController:isFighting()) and (now - lastReviveAttempt >= 4.0) then
                lastReviveAttempt = now
                local p = fightController:revive()
                if p and p.catch then p:catch(function() end) end
            end
        end)
    end
end

local combatThread = task.spawn(function()
    while HubState.Running do
        task.wait(0.4)
        local _ok, _err = pcall(function()
            -- Mode Event Aktif
            if HubState.AutoHarvestEvent then
                if not harvestMapController:isInMap() then
                    local _tok = pcall(function() harvestMapController:teleport() end)
                    task.wait(1)
                end

                if not harvestFightController:isFighting() then
                    local _sok = pcall(function() harvestFightController:startFight() end)
                end

                HandleSharedCombatAssists()

            -- Mode Plot Aktif (Auto Play Biasa)
            elseif HubState.AutoPlotCombat then
                if fightController and not fightController:isAutoFightSelected() then
                    local _uok = pcall(function()
                        local p = fightController:setAutoFight(true)
                        if p and p.catch then p:catch(function() end) end
                    end)
                end

                if fightController and not fightController:isFightingIn("plot") then
                    local _sok = pcall(function() fightController:startFight("plot") end)
                end

                HandleSharedCombatAssists()
            end

            -- Sedot Koin & Orb Universal (De-duplicated dengan TTL 2 detik)
            if HubState.AutoDropVacuum and orbController then
                local orbsFolder = Workspace:FindFirstChild("Orbs")
                if orbsFolder then
                    local now = os.clock()
                    for k, ts in pairs(collectedOrbsCache) do
                        if now - ts > 2.0 then
                            collectedOrbsCache[k] = nil
                        end
                    end
                    for _, orb in ipairs(orbsFolder:GetChildren()) do
                        local oName = orb.Name
                        if not collectedOrbsCache[oName] then
                            collectedOrbsCache[oName] = now
                            local p = orbController:collect(oName)
                            if p and p.catch then p:catch(function() end) end
                        end
                    end
                end
            end
        end)
    end
end
)
MainJanitor:Add(function() task.cancel(combatThread) end)

-- Loop B: Smart Egg Gacha (Rate-Limited, Exact Plot Resolution, Robux Prompt Proof)
local lastPullTime = 0
local gachaThread = task.spawn(function()
    while HubState.Running do
        task.wait(0.5)
        if HubState.AutoSmartGacha and pedestalController and plotController then
            local _ok, _err = pcall(function()
                local inEventMap = harvestMapController and harvestMapController.isInMap and harvestMapController:isInMap()
                -- 1. Pastikan karakter berada di dekat Lever Pedestal milik sendiri (skip teleport jika sedang di map event)
                local myPlot = plotController:getPlot()
                local leverPart = myPlot and myPlot:FindFirstChild("EggPedestal")
                    and myPlot.EggPedestal:FindFirstChild("Console")
                    and myPlot.EggPedestal.Console:FindFirstChild("Lever")
                    and myPlot.EggPedestal.Console.Lever:FindFirstChild("Primary")

                if not inEventMap then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and leverPart and (hrp.Position - leverPart.Position).Magnitude > 8 then
                        hrp.CFrame = leverPart.CFrame + Vector3.new(0, 3, 2)
                        task.wait(0.2)
                    end
                end

                -- 2. Evaluasi Tawaran Telur yang Sedang Tersedia
                local pedestal = pedestalController:getPedestal()
                local anyOfferMatch = false

                if pedestal and pedestal.offers then
                    for _, offer in pairs(pedestal.offers) do
                        local egg = offer.egg
                        if egg and not offer.purchased then
                            local lvl = egg.level or 0
                            local elem = string.lower(tostring(egg.element or ""))
                            local species = egg.species or ""

                            local lvlMatch = (lvl >= HubState.GachaMinLevel)
                            local elemMatch = (HubState.GachaElements[elem] == true)
                            local unindexedMatch = true

                            if HubState.GachaUnindexedOnly and indexController then
                                local _uok = pcall(function()
                                    if indexController:isDiscovered(species) then
                                        unindexedMatch = false
                                    end
                                end)
                            end

                            local canAfford = HasCoins(offer.price or 0)

                            if lvlMatch and elemMatch and unindexedMatch then
                                anyOfferMatch = true
                                if canAfford then
                                    local _bok = pcall(function()
                                        local p = pedestalController:buyEgg(offer)
                                        if p and p.catch then p:catch(function() end) end
                                    end)
                                    task.wait(0.4)
                                end
                            end
                        end
                    end
                end

                -- 3. Tarik Lever jika cooldown >= 2.8s terpenuhi dan tidak ada offer yang cocok menunggu dibeli
                local now = os.clock()
                if (now - lastPullTime >= 2.8) and (not anyOfferMatch) then
                    lastPullTime = now
                    PullGachaLever()
                end
            end)
        else
            task.wait(0.8)
        end
    end
end
)
MainJanitor:Add(function() task.cancel(gachaThread) end)

-- Loop C: Sarang, Menetas, Penempatan Naga, Tim & Breeding (Zero-Spam Local State Sync)
local lastEquipTime = 0
local nestThread = task.spawn(function()
    while HubState.Running do
        task.wait(1.5)
        local _ok, _err = pcall(function()
            if not nestController then return end

            -- 1. Buka Pad Sarang Terkunci jika koin cukup
            if HubState.AutoUnlockNests and nestController.nestManager then
                local _uok = pcall(function()
                    local owned = nestController:getOwnedNests()
                    local buyOrder = nestController.nestManager:getBuyOrder()
                    for _, nestId in ipairs(buyOrder) do
                        if not nestController:isOwned(nestId) then
                            local price = nestController.nestManager:getNextNestPrice(#owned)
                            if price and HasCoins(price) then
                                local p = nestController:buyNest(nestId)
                                if p and p.catch then p:catch(function() end) end
                                task.wait(0.3)
                            end
                            break
                        end
                    end
                end)
            end

            local ownedList = nestController:getOwnedNests() or {}

            -- 2. Pasang Telur yang Belum Diinkubasi ke Sarang Kosong (Prioritas 1-5+)
            if HubState.AutoPlaceEggs and eggController then
                local _eok = pcall(function()
                    local unplaced = eggController:getUnplacedEggs()
                    if unplaced and #unplaced > 0 then
                        local emptyNests = {}
                        for _, nId in ipairs(ownedList) do
                            local c = nestController:getContent(nId)
                            if not c or c.kind == "empty" then
                                table.insert(emptyNests, nId)
                            end
                        end

                        table.sort(emptyNests, function(a, b)
                            local aFloor, aIdx = string.match(tostring(a), "(%d+)%-(%d+)")
                            local bFloor, bIdx = string.match(tostring(b), "(%d+)%-(%d+)")
                            local aVal = (tonumber(aFloor) or 0) * 100 + (tonumber(aIdx) or 0)
                            local bVal = (tonumber(bFloor) or 0) * 100 + (tonumber(bIdx) or 0)
                            local aIsIncubation = (tonumber(aIdx) or 0) >= 5
                            local bIsIncubation = (tonumber(bIdx) or 0) >= 5
                            if aIsIncubation ~= bIsIncubation then
                                return aIsIncubation
                            end
                            return aVal < bVal
                        end)

                        for _, egg in ipairs(unplaced) do
                            local targetNest = table.remove(emptyNests, 1)
                            if not targetNest then break end
                            local eggId = egg.id or egg
                            local _pok = pcall(function()
                                local p = nestController:placeEgg(targetNest, eggId)
                                if p and p.catch then p:catch(function() end) end
                                if p and p.await then p:await() end
                            end)
                            task.wait(0.3)
                        end
                    end
                end)
            end

            -- 3. Buka Telur yang Sudah Selesai Waktu Inkubasinya
            if HubState.AutoOpenEggs then
                local now = os.time()
                for _, nId in ipairs(ownedList) do
                    local content = nestController:getContent(nId)
                    if content and content.kind == "egg" then
                        local secsLeft = nestController.getHatchSecondsLeft and nestController:getHatchSecondsLeft(nId)
                        local ready = (secsLeft ~= nil and secsLeft <= 0)
                            or (content.hatchEndTime and now >= content.hatchEndTime)
                        if ready then
                            local _ook = pcall(function()
                                local p = nestController:openEgg(nId)
                                if p and p.catch then p:catch(function() end) end
                                if p and p.await then p:await() end
                            end)
                            task.wait(0.3)
                        end
                    end
                end
            end

            -- 4. Otomatis Tempatkan Naga Menganggur ke Sarang (Sisakan 1 sarang jika AutoPlaceEggs aktif)
            if HubState.AutoPlaceDragons and dragonController then
                local _pok = pcall(function()
                    PlaceIdleDragonsInNests(HubState.AutoPlaceEggs)
                end)
            end

            -- 5. Ambil Bayi Naga yang Telah Menetas dari Sarang Inkubasi (Hanya jika AutoPlaceDragons nonaktif)
            if HubState.AutoCollectHatched and not HubState.AutoPlaceDragons then
                for _, nId in ipairs(ownedList) do
                    local content = nestController:getContent(nId)
                    if content and content.kind == "dragon" then
                        local _, idx = string.match(tostring(nId), "(%d+)%-(%d+)")
                        local nestNum = tonumber(idx) or 0
                        if nestNum >= 5 then
                            local _tok = pcall(function()
                                local p = nestController:takeDragon(nId)
                                if p and p.catch then p:catch(function() end) end
                                if p and p.await then p:await() end
                            end)
                            task.wait(0.25)
                        end
                    end
                end
            end

            -- 6. Pasang Naga Terkuat ke Tim Bertarung (Throttled 4.5s)
            if HubState.AutoEquipBest and teamController then
                local nowClk = os.clock()
                if nowClk - lastEquipTime >= 4.5 then
                    lastEquipTime = nowClk
                    local _qok = pcall(function()
                        if not teamController.isLoaded or teamController:isLoaded() then
                            local p = teamController:equipBest()
                            if p and p.catch then p:catch(function() end) end
                        end
                    end)
                end
            end

            -- 7. Auto Breeding (Otomatis Mengawinkan Naga Menganggur untuk Menaikkan Level)
            if HubState.AutoBreeding and breedController and dragonController then
                local _bok = pcall(function()
                    if breedController:getFreeFrames() > 0 then
                        local dragons = dragonController:getDragons() or {}
                        local eligible = {}
                        for _, drag in pairs(dragons) do
                            if drag and drag.id and not IsDragonBusy(drag.id, true) then
                                table.insert(eligible, drag)
                            end
                        end

                        table.sort(eligible, function(a, b)
                            return (a.level or 0) > (b.level or 0)
                        end)

                        if #eligible >= 2 then
                            local d1 = eligible[1]
                            local d2 = eligible[2]
                            local p = breedController:startBreed(d1.id, d2.id)
                            if p and p.catch then p:catch(function() end) end
                            if p and p.await then p:await() end
                            task.wait(0.4)
                        end
                    end
                end)
            end
        end)
    end
end
)
MainJanitor:Add(function() task.cancel(nestThread) end)

-- Loop D: Klaim Hadiah Berkala, Plot Upgrades & Live Status Telemetry
local function UpdateLiveStatus()
    if not UIElements.StatusParagraph then return end
    local _ok = pcall(function()
        local coinsRaw = LocalPlayer.leaderstats and LocalPlayer.leaderstats:FindFirstChild("Coins") and LocalPlayer.leaderstats.Coins.Value
        local coinsText = tostring(coinsRaw or "0")

        local prog = fightController and fightController.getProgress and fightController:getProgress()
        local st = fightController and fightController.getState and fightController:getState()
        local bestWave = (prog and prog.highestWave) or 0
        local curWave = (st and st.wave) or bestWave
        local harvestWave = (prog and prog.harvest and prog.harvest.highestWave) or 0

        local activeMode = "Idle"
        if HubState.AutoHarvestEvent then
            activeMode = "Harvest Event"
        elseif HubState.AutoPlotCombat then
            activeMode = "Plot Combat"
        end

        local dragons = (dragonController and dragonController.getDragons and dragonController:getDragons()) or {}
        local teamPower = (teamController and teamController.getTeamPower and teamController:getTeamPower()) or 0
        local totalBreeds = (breedController and breedController.getTotalCompleted and breedController:getTotalCompleted()) or 0
        local luckLvl = GetStatUpgradeInfo("eggLuck")
        local pedLvl = GetStatUpgradeInfo("rollingPedestals")

        local summary = string.format(
            "Mode: %s | Coins: %s\nWave: %s (Best Plot: %s | Harvest Best: %s)\nDragons: %d | Team Power: %s | Total Breeds: %d/20\nPlot Upgrades: Egg Luck Lv.%d | Pedestals Lv.%d",
            activeMode,
            coinsText,
            tostring(curWave),
            tostring(bestWave),
            tostring(harvestWave),
            #dragons,
            tostring(math.floor(teamPower)),
            totalBreeds,
            luckLvl,
            pedLvl
        )
        if UIElements.StatusParagraph.SetDesc then
            UIElements.StatusParagraph:SetDesc(summary)
        end
    end)
end

local claimTick = 0
local claimThread = task.spawn(function()
    while HubState.Running do
        task.wait(2.5)
        claimTick += 1
        UpdateLiveStatus()
        if claimTick % 2 ~= 0 then
            continue
        end
        local _ok, _err = pcall(function()
            -- 1. Wave Rewards (Hanya klaim jika ada hadiah siap)
            if HubState.AutoClaimWaves and waveController then
                local hasRewards = (waveController.hasPatchRewards and waveController:hasPatchRewards())
                    or (waveController.getClaimableCount and waveController:getClaimableCount() > 0)
                if hasRewards then
                    local p = waveController:claimPatch()
                    if p and p.catch then p:catch(function() end) end
                end
            end

            -- 2. Daily Rewards (Hanya klaim jika timer <= 0 dan claimable)
            if HubState.AutoClaimDaily and dailyController then
                local secs = (dailyController.getSecondsUntilNextDay and dailyController:getSecondsUntilNextDay()) or 999999
                if secs <= 0 then
                    local nextDay = (dailyController.getNextDay and dailyController:getNextDay()) or 1
                    local isClaimable = (not dailyController.isClaimable) or dailyController:isClaimable(nextDay)
                    if isClaimable then
                        local p = dailyController:claim()
                        if p and p.catch then p:catch(function() end) end
                    end
                end
            end

            -- 3. Auto Claim Index Boosts (Berjalan independen meskipun AutoSmartGacha mati)
            if HubState.AutoClaimIndex and indexController then
                local claimable = (indexController.getClaimableCount and indexController:getClaimableCount()) or 0
                if claimable > 0 then
                    local p = indexController:claimAll()
                    if p and p.catch then p:catch(function() end) end
                end
            end

            -- 4. Wheel Spin
            if HubState.AutoSpinWheel and wheelController then
                local _wok = pcall(function()
                    if wheelController.canSpin and wheelController:canSpin() then
                        local p = wheelController:spinAsync()
                        if p and p.catch then p:catch(function() end) end
                    end
                end)
            end

            -- 5. Wishing Well (Exact args: wellModel, pos)
            if HubState.AutoWishingWell and wishingWellController and plotController then
                local _wwok = pcall(function()
                    local myPlot = plotController:getPlot()
                    if myPlot and wishingWellController.isPlotUnlocked and wishingWellController:isPlotUnlocked(myPlot) then
                        local wellModel = GetWishingWellModel()
                        if wellModel then
                            local pending = wishingWellController.getPlotPendingReward and wishingWellController:getPlotPendingReward(myPlot)
                            if pending ~= nil then
                                local p = wishingWellController:collect(wellModel)
                                if p and p.catch then p:catch(function() end) end
                            else
                                local wishes = (wishingWellController.getPlotWishes and wishingWellController:getPlotWishes(myPlot)) or 0
                                if wishes > 0 then
                                    local pos = (wellModel:IsA("Model") and wellModel.PrimaryPart and wellModel.PrimaryPart.Position) or Vector3.zero
                                    local p = wishingWellController:wish(wellModel, pos)
                                    if p and p.catch then p:catch(function() end) end
                                end
                            end
                        end
                    end
                end)
            end

            -- 6. Auto Plot Upgrades (Floor 1 + Wizard Tower, Luck, Pedestals)
            if HubState.AutoUnlockFloors and plotUpgradeController then
                local _pok = pcall(function()
                    if plotUpgradeController.canUnlockNext and plotUpgradeController:canUnlockNext() then
                        local nextLvl = ((plotUpgradeController.getLevel and plotUpgradeController:getLevel()) or 0) + 1
                        local p = plotUpgradeController:upgrade(nextLvl)
                        if p and p.catch then p:catch(function() end) end
                    end
                end)
            end

            if HubState.AutoUpgradeEggLuck and statUpgradeController then
                local _sok = pcall(function()
                    local lvl, nextPrice = GetStatUpgradeInfo("eggLuck")
                    if nextPrice and HasCoins(nextPrice) then
                        local p = statUpgradeController:upgrade("eggLuck", lvl + 1)
                        if p and p.catch then p:catch(function() end) end
                    end
                end)
            end

            if HubState.AutoUpgradePedestals and statUpgradeController then
                local _sok = pcall(function()
                    local lvl, nextPrice = GetStatUpgradeInfo("rollingPedestals")
                    if nextPrice and HasCoins(nextPrice) then
                        local p = statUpgradeController:upgrade("rollingPedestals", lvl + 1)
                        if p and p.catch then p:catch(function() end) end
                    end
                end)
            end
        end)
    end
end
)
MainJanitor:Add(function() task.cancel(claimThread) end)

-- Loop E: ESP Rendering Daemon (Zero-Leak Pruning, Targeted Plot Scan, Highlight Cap)
local espHighlights = {}
local espBillboards = {}
local espKeySeq = 0
local espInstanceKeys = setmetatable({}, { __mode = "k" })

local function GetEspKey(prefix: string, inst: Instance): string
    local key = espInstanceKeys[inst]
    if not key then
        espKeySeq += 1
        key = prefix .. tostring(espKeySeq)
        espInstanceKeys[inst] = key
    end
    return key
end

local function ClearESP(tableRef)
    for target, inst in pairs(tableRef) do
        if inst and inst.Parent then
            local _dok = pcall(function() inst:Destroy() end)
        end
        tableRef[target] = nil
    end
end

local function PruneESP(tableRef, seenKeys: { [string]: boolean })
    for key, inst in pairs(tableRef) do
        if not seenKeys[key] or not inst or not inst.Parent then
            if inst and inst.Parent then
                local _dok = pcall(function() inst:Destroy() end)
            end
            tableRef[key] = nil
        end
    end
end

MainJanitor:Add(function()
    ClearESP(espHighlights)
    ClearESP(espBillboards)
end)

local function GetOrCreateHighlight(target: Instance, key: string, fillColor: Color3, outlineColor: Color3, hlCountRef: { n: number })
    local existing = espHighlights[key]
    if existing and existing.Parent then
        hlCountRef.n += 1
        return existing
    end
    if hlCountRef.n >= 28 then
        return nil
    end
    hlCountRef.n += 1
    local hl = Instance.new("Highlight")
    hl.Name = "Empire_ESP_HL"
    hl.FillColor = fillColor
    hl.OutlineColor = outlineColor
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0.1
    hl.Adornee = target
    hl.Parent = target
    espHighlights[key] = hl
    return hl
end

local function GetOrCreateBillboard(adornee: Instance, key: string, text: string, color: Color3, offset: Vector3?)
    local existing = espBillboards[key]
    if existing and existing.Parent then
        local lbl = existing:FindFirstChild("TextLabel")
        if lbl and lbl:IsA("TextLabel") then
            lbl.Text = text
        end
        return existing
    end
    local bb = Instance.new("BillboardGui")
    bb.Name = "Empire_ESP_BB"
    bb.Adornee = adornee
    bb.Size = UDim2.fromOffset(160, 42)
    bb.StudsOffset = offset or Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 600

    local tl = Instance.new("TextLabel")
    tl.Name = "TextLabel"
    tl.BackgroundTransparency = 1
    tl.Size = UDim2.fromScale(1, 1)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 13
    tl.TextColor3 = color
    tl.TextStrokeTransparency = 0.2
    tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    tl.Text = text
    tl.Parent = bb

    bb.Parent = adornee
    espBillboards[key] = bb
    return bb
end

local espThread = task.spawn(function()
    while HubState.Running do
        local anyEsp = HubState.ESPPlayers or HubState.ESPEggs or HubState.ESPOrbs or HubState.ESPDragons
        if not anyEsp then
            if next(espHighlights) ~= nil then ClearESP(espHighlights) end
            if next(espBillboards) ~= nil then ClearESP(espBillboards) end
            task.wait(0.4)
            continue
        end

        local _ok, _err = pcall(function()
            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local myPos = myHrp and myHrp.Position or Vector3.zero
            local seenKeys: { [string]: boolean } = {}
            local hlCountRef = { n = 0 }

            -- 1. Player ESP
            if HubState.ESPPlayers then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local char = p.Character
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then
                            local dist = math.floor((myPos - hrp.Position).Magnitude)
                            local key = "player_" .. p.Name
                            seenKeys[key] = true
                            GetOrCreateHighlight(char, key, Color3.fromRGB(0, 240, 255), Color3.fromRGB(255, 255, 255), hlCountRef)

                            local tag = p.DisplayName .. " (@" .. p.Name .. ")"
                            if HubState.ESPDistance then
                                tag = tag .. "\n[" .. dist .. "m | HP: " .. math.floor(hum.Health) .. "]"
                            end
                            GetOrCreateBillboard(hrp, key, tag, Color3.fromRGB(0, 240, 255), Vector3.new(0, 3.2, 0))
                        end
                    end
                end
            end

            -- 2. Egg Pedestal ESP (Targeted Plots Scan — Unique Instance Keys)
            if HubState.ESPEggs then
                local plotsFolder = Workspace:FindFirstChild("Plots")
                if plotsFolder then
                    for _, plot in ipairs(plotsFolder:GetChildren()) do
                        local ep = plot:FindFirstChild("EggPedestal")
                        if ep then
                            for _, desc in ipairs(ep:GetDescendants()) do
                                if desc.Name == "StrawTop" and desc:IsA("BasePart") and desc.Parent and string.find(desc.Parent.Name, "EggSlot") then
                                    local prompt = desc:FindFirstChildOfClass("ProximityPrompt")
                                    if prompt and prompt.Enabled then
                                        local eggName = prompt.ObjectText ~= "" and prompt.ObjectText or "Egg"
                                        local action = prompt.ActionText ~= "" and prompt.ActionText or "Steal"
                                        local key = GetEspKey("egg_", desc.Parent)
                                        seenKeys[key] = true
                                        local dist = math.floor((myPos - desc.Position).Magnitude)

                                        GetOrCreateHighlight(desc, key, Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 255, 255), hlCountRef)
                                        local tag = eggName .. " (" .. action .. ")"
                                        if HubState.ESPDistance then
                                            tag = tag .. "\n[" .. dist .. "m]"
                                        end
                                        GetOrCreateBillboard(desc, key, tag, Color3.fromRGB(255, 215, 0), Vector3.new(0, 2.2, 0))
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- 3. Drops & Orbs ESP
            if HubState.ESPOrbs then
                local orbsFolder = Workspace:FindFirstChild("Orbs")
                if orbsFolder then
                    for _, orb in ipairs(orbsFolder:GetChildren()) do
                        if orb:IsA("BasePart") or orb:IsA("Model") then
                            local targetPart = orb:IsA("BasePart") and orb or orb.PrimaryPart or orb:FindFirstChildWhichIsA("BasePart")
                            if targetPart then
                                local key = GetEspKey("orb_", orb)
                                seenKeys[key] = true
                                local dist = math.floor((myPos - targetPart.Position).Magnitude)
                                GetOrCreateHighlight(orb, key, Color3.fromRGB(255, 50, 200), Color3.fromRGB(255, 255, 255), hlCountRef)
                                local tag = "Orb (" .. orb.Name .. ")"
                                if HubState.ESPDistance then
                                    tag = tag .. "\n[" .. dist .. "m]"
                                end
                                GetOrCreateBillboard(targetPart, key, tag, Color3.fromRGB(255, 100, 220), Vector3.new(0, 1.8, 0))
                            end
                        end
                    end
                end
            end

            -- 4. Stationed Dragons ESP
            if HubState.ESPDragons then
                local plotNests = Workspace:FindFirstChild("PlotNests")
                if plotNests then
                    for _, dModel in ipairs(plotNests:GetChildren()) do
                        if dModel:IsA("Model") and string.find(dModel.Name, "Dragon") then
                            local primary = dModel.PrimaryPart or dModel:FindFirstChildWhichIsA("BasePart")
                            if primary then
                                local key = GetEspKey("dragon_", dModel)
                                seenKeys[key] = true
                                local dist = math.floor((myPos - primary.Position).Magnitude)
                                GetOrCreateHighlight(dModel, key, Color3.fromRGB(50, 255, 120), Color3.fromRGB(255, 255, 255), hlCountRef)
                                local tag = dModel.Name
                                if HubState.ESPDistance then
                                    tag = tag .. "\n[" .. dist .. "m]"
                                end
                                GetOrCreateBillboard(primary, key, tag, Color3.fromRGB(50, 255, 120), Vector3.new(0, 2.5, 0))
                            end
                        end
                    end
                end
            end

            -- Prune all stale / despawned / toggled-off ESP objects
            PruneESP(espHighlights, seenKeys)
            PruneESP(espBillboards, seenKeys)
        end)
        task.wait(0.3)
    end
end
)
MainJanitor:Add(function() task.cancel(espThread) end)

-- ------------------------------------------------------------------------------
-- 6. WINDUI ENGINE LOADER & THEME (FROM SCROOMS.LUA)
-- ------------------------------------------------------------------------------
local function LoadWindUI()
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end)
    if ok and lib then return lib end

    ok, lib = pcall(function()
        return loadstring(game:HttpGet("https://tree-hub.vercel.app/api/UI/WindUI"))()
    end)
    if ok and lib then return lib end

    error("[Empire Hub] Gagal memuat library WindUI.", 0)
end

local WindUI = LoadWindUI()

WindUI:AddTheme({
    Name = "IceDragon",
    Accent = Color3.fromHex("#00e5ff"),
    Dialog = Color3.fromHex("#0b263b"),
    Text = Color3.fromHex("#f0faff"),
    Placeholder = Color3.fromHex("#70b2d9"),
    Background = Color3.fromHex("#05131f"),
    Button = Color3.fromHex("#0099cc"),
    Icon = Color3.fromHex("#38d2f7"),
    Toggle = Color3.fromHex("#00f2ff"),
    Slider = Color3.fromHex("#00e5ff"),
    Checkbox = Color3.fromHex("#00e5ff"),
    PanelBackground = Color3.fromHex("#0a2538"),
    PanelBackgroundTransparency = 0.8,
    ElementBackground = Color3.fromHex("#0e2b40"),
    ElementBackgroundTransparency = 0,
})

local function Notify(title: string, desc: string, duration: number?)
    local _ok, _err = pcall(function()
        WindUI:Notify({
            Title = title,
            Content = desc,
            Duration = duration or 3
        })
    end)
end

-- ------------------------------------------------------------------------------
-- 7. WINDOW CONSTRUCTOR & TRANSPARENCY (GLASSMORPHISM 0.7)
-- ------------------------------------------------------------------------------
local Window = WindUI:CreateWindow({
    Title = "DRAGON ARENA | EMPIRE HUB",
    Icon = "rbxassetid://10723415903",
    Author = "MADE BY ICEDRAGON",
    Folder = "Empire_DragonArena",
    Size = UDim2.fromOffset(630, 520),
    MinSize = Vector2.new(540, 420),
    Theme = "IceDragon",
    HidePanelBackground = false,
    NewElements = true,
    Acrylic = false,
    HideSearchBar = false,
    SideBarWidth = 200,
    OpenButton = { ShowIconOnly = true }
})

WindUI.TransparencyValue = 0.7
Window:ToggleTransparency(true)
Window:DisableTopbarButtons({ "Fullscreen" })

local _ok, _err = pcall(function()
    Window:EditOpenButton({
        Title = "DRAGON ARENA | EMPIRE HUB",
        Icon = "rbxassetid://10723415903",
        OnlyIcon = false,
        OnlyMobile = false,
        Draggable = true,
        Scale = 1,
    })
end)

MainJanitor:Add(function()
    local _ok, _err = pcall(function() Window:Destroy() end)
end)

-- ------------------------------------------------------------------------------
-- 8. TABS DECLARATION
-- ------------------------------------------------------------------------------
local Tabs = {
    Home    = Window:Tab({ Title = "Support", Icon = "home" }),
    Event   = Window:Tab({ Title = "Harvest Event", Icon = "sparkles" }),
    Combat  = Window:Tab({ Title = "Plot Combat", Icon = "swords" }),
    Gacha   = Window:Tab({ Title = "Egg Gacha", Icon = "egg" }),
    Nests   = Window:Tab({ Title = "Nests & Dragons", Icon = "shield" }),
    Visuals = Window:Tab({ Title = "Visuals & ESP", Icon = "eye" }),
    Rewards = Window:Tab({ Title = "Rewards & Claims", Icon = "gift" }),
}

-- ------------------------------------------------------------------------------
-- TAB 1: SUPPORT & COMMUNITY
-- ------------------------------------------------------------------------------
Tabs.Home:Section({ Title = "Official IceDragon Support", TextSize = 16 })
Tabs.Home:Divider()

Tabs.Home:Paragraph({
    Title = "Official Creator: IceDragonScript",
    Desc = "Support the creator by subscribing to the official YouTube channel!\n\nChannel Link: https://www.youtube.com/@ROBLOX_icedragonScript\nDon't forget to like, subscribe, and share with your friends!"
})

Tabs.Home:Button({
    Title = "Copy YouTube Channel Link",
    Desc = "Copy the official IceDragon YouTube channel URL to your clipboard",
    Callback = function()
        SafeSetClipboard(YOUTUBE_URL)
        Notify("Link Copied!", "Don't forget to support and like!", 4)
    end
})

Tabs.Home:Button({
    Title = "Copy Discord Community Link",
    Desc = "Join our official Discord community for script updates and help",
    Callback = function()
        SafeSetClipboard(DISCORD_URL)
        Notify("Discord Copied!", "See you in our community server!", 4)
    end
})

Tabs.Home:Divider()
UIElements.StatusParagraph = Tabs.Home:Paragraph({
    Title = "Account & Game Status",
    Desc = "Checking live game status from server..."
})

-- ------------------------------------------------------------------------------
-- TAB 2: HARVEST HUNT EVENT
-- ------------------------------------------------------------------------------
Tabs.Event:Section({ Title = "Harvest Hunt Event Automation", TextSize = 16 })
Tabs.Event:Divider()

UIElements.ToggleHarvest = Tabs.Event:Toggle({
    Title = "Auto Play Event (Harvest Hunt)",
    Desc = "Automatically goes to the event map and fights monster waves for exclusive rewards. (Turns OFF Plot Combat to prevent conflict)",
    Value = HubState.AutoHarvestEvent,
    Callback = function(val)
        ActivateHarvestEvent(val)
    end
})

UIElements.ToggleFastEvent = Tabs.Event:Toggle({
    Title = "Fast Battle Speed (2.5x)",
    Desc = "Speeds up your dragons' attacks and battle pace by 2.5 times",
    Value = HubState.CombatFastSpeed,
    Callback = function(val)
        SetCombatOption("CombatFastSpeed", val, UIElements.ToggleFastPlot)
        if fightController then
            local _sok = pcall(function()
                local p = fightController:setFastSpeed(val)
                if p and p.catch then p:catch(function() end) end
            end)
        end
    end
})

UIElements.ToggleReviveEvent = Tabs.Event:Toggle({
    Title = "Auto Revive (Never Lose)",
    Desc = "Instantly revives all fallen dragons so your wave progress never resets",
    Value = HubState.CombatAutoRevive,
    Callback = function(val)
        SetCombatOption("CombatAutoRevive", val, UIElements.ToggleRevivePlot)
    end
})

UIElements.ToggleSkipEvent = Tabs.Event:Toggle({
    Title = "Skip Boss Dialog & Animations",
    Desc = "Immediately skips boss cutscenes and dialog popups to save time",
    Value = HubState.CombatSkipCutscenes,
    Callback = function(val)
        SetCombatOption("CombatSkipCutscenes", val, UIElements.ToggleSkipPlot)
    end
})

Tabs.Event:Divider()

Tabs.Event:Button({
    Title = "Teleport to Event Map Now",
    Desc = "Directly teleports your character to the Thanksgiving event area",
    Callback = function()
        local _ok = pcall(function() harvestMapController:teleport() end)
        Notify("Event Teleport", "Your character has been moved to the Harvest Hunt map.", 3)
    end
})

Tabs.Event:Button({
    Title = "Return to Plot Home",
    Desc = "Leaves the event map and returns to your personal base plot",
    Callback = function()
        local _ok = pcall(function() harvestMapController:returnToPlot() end)
        Notify("Return Home", "Your character has returned to your plot.", 3)
    end
})

-- ------------------------------------------------------------------------------
-- TAB 3: PLOT COMBAT (BASE ARENA)
-- ------------------------------------------------------------------------------
Tabs.Combat:Section({ Title = "Plot Base Combat Arena (Auto Play Biasa)", TextSize = 16 })
Tabs.Combat:Divider()

UIElements.TogglePlot = Tabs.Combat:Toggle({
    Title = "Auto Play Biasa (Plot Arena)",
    Desc = "Automatically fights normal monster waves at your base plot to earn coins. (Turns OFF Harvest Event to prevent conflict)",
    Value = HubState.AutoPlotCombat,
    Callback = function(val)
        ActivatePlotCombat(val)
    end
})

Tabs.Combat:Button({
    Title = "Start Auto Play Biasa Now",
    Desc = "Instantly returns to your plot, activates auto-advance waves, and starts fighting",
    Callback = function()
        if UIElements.TogglePlot then
            UIElements.TogglePlot:Set(true)
        else
            ActivatePlotCombat(true)
        end
        Notify("Auto Play Biasa", "Started normal wave farming at base plot!", 3)
    end
})

UIElements.ToggleFastPlot = Tabs.Combat:Toggle({
    Title = "Fast Battle Speed (2.5x)",
    Desc = "Speeds up plot arena combat by 2.5 times",
    Value = HubState.CombatFastSpeed,
    Callback = function(val)
        SetCombatOption("CombatFastSpeed", val, UIElements.ToggleFastEvent)
        if fightController then
            local _sok = pcall(function()
                local p = fightController:setFastSpeed(val)
                if p and p.catch then p:catch(function() end) end
            end)
        end
    end
})

UIElements.ToggleRevivePlot = Tabs.Combat:Toggle({
    Title = "Auto Revive (Never Lose)",
    Desc = "Instantly revives your dragons when defeated so wave progress never resets",
    Value = HubState.CombatAutoRevive,
    Callback = function(val)
        SetCombatOption("CombatAutoRevive", val, UIElements.ToggleReviveEvent)
    end
})

UIElements.ToggleSkipPlot = Tabs.Combat:Toggle({
    Title = "Skip Boss Dialog & Animations",
    Desc = "Skips all boss intros and cutscenes at your base plot",
    Value = HubState.CombatSkipCutscenes,
    Callback = function(val)
        SetCombatOption("CombatSkipCutscenes", val, UIElements.ToggleSkipEvent)
    end
})

-- ------------------------------------------------------------------------------
-- TAB 4: SMART EGG GACHA & INDEX FILTER
-- ------------------------------------------------------------------------------
Tabs.Gacha:Section({ Title = "Smart Egg Spinner & Whitelist Filter", TextSize = 16 })
Tabs.Gacha:Divider()

Tabs.Gacha:Toggle({
    Title = "Smart Egg Roll & Buy",
    Desc = "Automatically pulls egg lever and buys only eggs matching your level and element filters",
    Value = HubState.AutoSmartGacha,
    Callback = function(val)
        HubState.AutoSmartGacha = val
    end
})

Tabs.Gacha:Button({
    Title = "Pull Lever Now (Manual Spin)",
    Desc = "Instantly pulls the pedestal lever on your plot to roll new eggs",
    Callback = function()
        PullGachaLever()
        Notify("Lever Pulled", "Pedestal lever pulled! Rolling new eggs...", 3)
    end
})

Tabs.Gacha:Slider({
    Title = "Minimum Egg Level Filter",
    Desc = "Only buy eggs at or above this level (e.g. Level 4+). Lower level eggs are skipped to save coins",
    Value = {
        Min = 1,
        Max = 5,
        Default = HubState.GachaMinLevel,
    },
    Callback = function(val)
        local n = tonumber(val)
        if n then
            HubState.GachaMinLevel = math.floor(n)
            Notify("Level Filter", "Only buying Level " .. tostring(HubState.GachaMinLevel) .. "+ eggs.", 2)
        end
    end
})

Tabs.Gacha:Dropdown({
    Title = "Allowed Egg Elements Whitelist",
    Desc = "Select which elements are allowed to be bought. Unselected elements are skipped",
    Multi = true,
    Values = { "Earth", "Fire", "Water", "Ice", "Secret", "Exclusive", "Event" },
    Value = { "Earth", "Fire", "Water", "Ice", "Secret", "Exclusive", "Event" },
    Callback = function(selected)
        local newMap = {}
        if type(selected) == "table" then
            for k, v in pairs(selected) do
                if type(k) == "number" and type(v) == "string" then
                    newMap[string.lower(v)] = true
                elseif type(k) == "string" and v == true then
                    newMap[string.lower(k)] = true
                end
            end
        end
        HubState.GachaElements = newMap
    end
})

Tabs.Gacha:Toggle({
    Title = "Only Buy Unindexed Dragons (Index Hunter)",
    Desc = "Only buys eggs of dragon species not yet recorded in your Index collection",
    Value = HubState.GachaUnindexedOnly,
    Callback = function(val)
        HubState.GachaUnindexedOnly = val
    end
})

Tabs.Gacha:Toggle({
    Title = "Auto Claim Index Power Boosts",
    Desc = "Automatically claims the x2 power boost whenever a new dragon is discovered",
    Value = HubState.AutoClaimIndex,
    Callback = function(val)
        HubState.AutoClaimIndex = val
    end
})

Tabs.Gacha:Button({
    Title = "Claim All Index Boosts Now",
    Desc = "Instantly claims all available new dragon boosts in your Index",
    Callback = function()
        local _ok, _err = pcall(function() indexController:claimAll() end)
        Notify("Index Claimed", "All ready Index power boosts have been collected!", 3)
    end
})

-- ------------------------------------------------------------------------------
-- TAB 5: NESTS & DRAGON TEAM
-- ------------------------------------------------------------------------------
Tabs.Nests:Section({ Title = "Nest Pads & Dragon Team Management", TextSize = 16 })
Tabs.Nests:Divider()

Tabs.Nests:Toggle({
    Title = "Auto Place Dragons to Nests",
    Desc = "Automatically places your idle inventory dragons onto empty nest pads to defend your plot",
    Value = HubState.AutoPlaceDragons,
    Callback = function(val)
        HubState.AutoPlaceDragons = val
    end
})

Tabs.Nests:Toggle({
    Title = "Auto Incubate Eggs (Place in Nests)",
    Desc = "Automatically transfers bought eggs from your inventory into empty nests to start incubation",
    Value = HubState.AutoPlaceEggs,
    Callback = function(val)
        HubState.AutoPlaceEggs = val
    end
})

Tabs.Nests:Toggle({
    Title = "Auto Open Ready Eggs",
    Desc = "Automatically hatches eggs in your nests once their incubation timer completes",
    Value = HubState.AutoOpenEggs,
    Callback = function(val)
        HubState.AutoOpenEggs = val
    end
})

Tabs.Nests:Toggle({
    Title = "Auto Collect Hatched Dragons",
    Desc = "Automatically collects newly hatched baby dragons from nests into your inventory so nests stay free",
    Value = HubState.AutoCollectHatched,
    Callback = function(val)
        HubState.AutoCollectHatched = val
    end
})

Tabs.Nests:Toggle({
    Title = "Auto Unlock Nest Pads",
    Desc = "Automatically buys and unlocks locked nest pads in sequence as soon as you have enough coins",
    Value = HubState.AutoUnlockNests,
    Callback = function(val)
        HubState.AutoUnlockNests = val
    end
})

Tabs.Nests:Button({
    Title = "Deploy All Dragons to Nests",
    Desc = "Stations all available idle dragons into empty nests for plot defense",
    Callback = function()
        local placed = 0
        local _ok = pcall(function()
            placed = PlaceIdleDragonsInNests(false)
        end)
        if placed > 0 then
            Notify("Defense Stations", placed .. " idle dragon(s) assigned to empty nests!", 3)
        else
            Notify("Defense Stations", "No empty nests or idle dragons available to place.", 3)
        end
    end
})

Tabs.Nests:Toggle({
    Title = "Auto Equip Best Dragons",
    Desc = "Automatically equips your highest power dragons into the combat lineup",
    Value = HubState.AutoEquipBest,
    Callback = function(val)
        HubState.AutoEquipBest = val
    end
})

Tabs.Nests:Button({
    Title = "Equip Best Dragons Now",
    Desc = "Instantly sets up your highest damage team formation",
    Callback = function()
        local _ok = pcall(function()
            local p = teamController:equipBest()
            if p and p.catch then p:catch(function() end) end
        end)
        Notify("Team Updated", "Your highest power dragon team has been equipped!", 3)
    end
})

Tabs.Nests:Divider()
Tabs.Nests:Section({ Title = "Dragon Breeding Fusion (Auto Kawin)", TextSize = 16 })

Tabs.Nests:Toggle({
    Title = "Auto Breed Dragons (Auto Kawin)",
    Desc = "Automatically pairs up and breeds your strongest available dragons whenever a breeding frame is free to create massive level dragons",
    Value = HubState.AutoBreeding,
    Callback = function(val)
        HubState.AutoBreeding = val
    end
})

Tabs.Nests:Button({
    Title = "Start Breed Now (Manual Pair)",
    Desc = "Immediately pairs and breeds your two highest level available dragons right now",
    Callback = function()
        local _ok = pcall(function()
            if breedController and dragonController then
                if breedController:getFreeFrames() <= 0 then
                    Notify("Cannot Breed", "All breeding slots are currently occupied!", 3)
                    return
                end
                local dragons = dragonController:getDragons() or {}
                local eligible = {}
                for _, drag in pairs(dragons) do
                    if drag and drag.id and not IsDragonBusy(drag.id, true) then
                        table.insert(eligible, drag)
                    end
                end

                table.sort(eligible, function(a, b)
                    return (a.level or 0) > (b.level or 0)
                end)

                if #eligible >= 2 then
                    local d1 = eligible[1]
                    local d2 = eligible[2]
                    local p = breedController:startBreed(d1.id, d2.id)
                    if p and p.catch then p:catch(function() end) end
                    if p and p.await then p:await() end
                    Notify("Breeding Started!", "Breeding " .. d1.species .. " & " .. d2.species .. "!", 3)
                else
                    Notify("Cannot Breed", "Need at least 2 idle dragons (not fighting, nested, or already breeding).", 3)
                end
            end
        end)
    end
})

-- ------------------------------------------------------------------------------
-- TAB 6: VISUALS & ESP (WALLHACK & RADAR)
-- ------------------------------------------------------------------------------
Tabs.Visuals:Section({ Title = "Wallhack, Chams & Radar (ESP)", TextSize = 16 })
Tabs.Visuals:Divider()

Tabs.Visuals:Toggle({
    Title = "Player ESP (Chams & Tags)",
    Desc = "Highlights all other players in the server through walls with cyan chams, display names, and HP",
    Value = HubState.ESPPlayers,
    Callback = function(val)
        HubState.ESPPlayers = val
    end
})

Tabs.Visuals:Toggle({
    Title = "Egg Pedestal ESP (Stealable Eggs)",
    Desc = "Highlights all eggs currently placed on pedestals in other players' plots with glowing gold chams",
    Value = HubState.ESPEggs,
    Callback = function(val)
        HubState.ESPEggs = val
    end
})

Tabs.Visuals:Toggle({
    Title = "Orbs & Drops ESP",
    Desc = "Highlights dropped coins, elemental orbs, and rare pickups across the map in magenta",
    Value = HubState.ESPOrbs,
    Callback = function(val)
        HubState.ESPOrbs = val
    end
})

Tabs.Visuals:Toggle({
    Title = "Stationed Dragons ESP",
    Desc = "Highlights all defense dragons stationed in nest pads across all plots in emerald green",
    Value = HubState.ESPDragons,
    Callback = function(val)
        HubState.ESPDragons = val
    end
})

Tabs.Visuals:Toggle({
    Title = "Show Distance In Meters (Studs)",
    Desc = "Displays the exact distance in studs on all overhead ESP labels",
    Value = HubState.ESPDistance,
    Callback = function(val)
        HubState.ESPDistance = val
    end
})

-- ------------------------------------------------------------------------------
-- TAB 7: REWARDS & AUTOMATIONS
-- ------------------------------------------------------------------------------
Tabs.Rewards:Section({ Title = "Automatic Reward Claimers & Codes", TextSize = 16 })
Tabs.Rewards:Divider()

Tabs.Rewards:Toggle({
    Title = "Instant Drop Vacuum (Drop Magnet)",
    Desc = "Directly vacuums all dropped coins, orbs, and event items across the ground without walking",
    Value = HubState.AutoDropVacuum,
    Callback = function(val)
        HubState.AutoDropVacuum = val
    end
})

Tabs.Rewards:Toggle({
    Title = "Auto Claim Wave Rewards",
    Desc = "Automatically collects milestone rewards every time you reach a new wave record",
    Value = HubState.AutoClaimWaves,
    Callback = function(val)
        HubState.AutoClaimWaves = val
    end
})

Tabs.Rewards:Toggle({
    Title = "Auto Claim Daily Rewards",
    Desc = "Automatically collects your daily login reward as soon as it becomes available",
    Value = HubState.AutoClaimDaily,
    Callback = function(val)
        HubState.AutoClaimDaily = val
    end
})

Tabs.Rewards:Toggle({
    Title = "Free Wheel Spin",
    Desc = "Automatically spins the reward wheel whenever free spins are available",
    Value = HubState.AutoSpinWheel,
    Callback = function(val)
        HubState.AutoSpinWheel = val
    end
})

Tabs.Rewards:Toggle({
    Title = "Use Wishing Well",
    Desc = "Automatically drops coins into the wishing well and collects free bonus rewards",
    Value = HubState.AutoWishingWell,
    Callback = function(val)
        HubState.AutoWishingWell = val
    end
})

Tabs.Rewards:Divider()

Tabs.Rewards:Section({ Title = "Plot Upgrades & Signboards", TextSize = 16 })
Tabs.Rewards:Divider()

Tabs.Rewards:Toggle({
    Title = "Auto Upgrade Egg Rolling Luck",
    Desc = "Automatically buys +50% Egg Rolling Luck from your plot signboard when coins are sufficient",
    Value = HubState.AutoUpgradeEggLuck,
    Callback = function(val)
        HubState.AutoUpgradeEggLuck = val
    end
})

Tabs.Rewards:Toggle({
    Title = "Auto Upgrade Rolling Pedestals",
    Desc = "Automatically buys additional Egg Rolling Pedestals on your plot to hatch more eggs simultaneously",
    Value = HubState.AutoUpgradePedestals,
    Callback = function(val)
        HubState.AutoUpgradePedestals = val
    end
})

Tabs.Rewards:Toggle({
    Title = "Auto Unlock Floors & Wizard Tower",
    Desc = "Automatically unlocks Floor 1 and Wizard Tower boosts as soon as 20 dragon breeds are completed",
    Value = HubState.AutoUnlockFloors,
    Callback = function(val)
        HubState.AutoUnlockFloors = val
    end
})

local function HandleManualStatUpgrade(statName: string, displayLabel: string)
    if not statUpgradeController then return end
    local lvl, nextPrice = GetStatUpgradeInfo(statName)
    if not nextPrice then
        Notify(displayLabel .. " Maxed", displayLabel .. " is already at maximum level (" .. tostring(lvl) .. ")!", 3)
        return
    end
    if not HasCoins(nextPrice) then
        Notify(displayLabel .. " Locked", "Need " .. tostring(nextPrice) .. " coins for Lv." .. tostring(lvl + 1) .. "!", 3)
        return
    end
    local p = statUpgradeController:upgrade(statName, lvl + 1)
    if p and p.catch then p:catch(function() end) end
    if p and p.await then
        local _ok, err = p:await()
        if _ok then
            Notify(displayLabel .. " Upgraded", displayLabel .. " upgraded to Lv." .. tostring(lvl + 1) .. "!", 3)
        else
            Notify(displayLabel .. " Failed", tostring(err or "Upgrade rejected"), 3)
        end
    end
end

Tabs.Rewards:Button({
    Title = "Upgrade Egg Luck Now",
    Desc = "Manually triggers the +50% Egg Rolling Luck signboard upgrade on your plot",
    Callback = function()
        HandleManualStatUpgrade("eggLuck", "Egg Luck")
    end
})

Tabs.Rewards:Button({
    Title = "Upgrade Rolling Pedestals Now",
    Desc = "Manually triggers the Rolling Pedestals upgrade on your plot signboard",
    Callback = function()
        HandleManualStatUpgrade("rollingPedestals", "Pedestals")
    end
})

Tabs.Rewards:Button({
    Title = "Unlock Floor 1 Now (Wizard Tower)",
    Desc = "Manually unlocks Floor 1 and Wizard Tower if requirements (20 breeds, 30K coins) are met",
    Callback = function()
        if plotUpgradeController then
            if plotUpgradeController.canUnlockNext and plotUpgradeController:canUnlockNext() then
                local nextLvl = ((plotUpgradeController.getLevel and plotUpgradeController:getLevel()) or 0) + 1
                local p = plotUpgradeController:upgrade(nextLvl)
                if p and p.catch then p:catch(function() end) end
                if p and p.await then
                    local _ok, err = p:await()
                    if _ok then
                        Notify("Floor 1 Unlocked", "Floor 1 and Wizard Tower have been unlocked!", 4)
                    else
                        Notify("Unlock Failed", tostring(err or "Failed to unlock"), 3)
                    end
                end
            else
                local totalBreeds = (breedController and breedController.getTotalCompleted and breedController:getTotalCompleted()) or 0
                Notify("Floor 1 Locked", "Requirements not met! Need 20 Total Breeds (" .. tostring(totalBreeds) .. "/20) and 30K coins.", 4)
            end
        end
    end
})

Tabs.Rewards:Divider()

Tabs.Rewards:Button({
    Title = "Redeem All Promo Codes",
    Desc = "Tries redeeming all active promo codes sequentially for free coins and boosts",
    Callback = function()
        Notify("Redeeming Codes", "Processing promo code redemptions...", 2)
        task.spawn(function()
            for _, code in ipairs(KNOWN_CODES) do
                local _ok = pcall(function()
                    local p = codeController:tryRedeem(code)
                    if p and p.catch then p:catch(function() end) end
                end)
                task.wait(0.3)
            end
            Notify("Redemption Complete", "All active promo codes have been redeemed!", 3)
        end)
    end
})

-- ------------------------------------------------------------------------------
-- 9. EXPOSE GLOBALS & FINALIZE
-- ------------------------------------------------------------------------------
_G.EmpireHub = {
    Janitor = MainJanitor,
    State = HubState,
    Window = Window,
    UIElements = UIElements,
    Helpers = {
        GetStatUpgradeInfo = GetStatUpgradeInfo,
        PullGachaLever = PullGachaLever,
        PlaceIdleDragonsInNests = PlaceIdleDragonsInNests,
        IsDragonBusy = IsDragonBusy,
        UpdateLiveStatus = UpdateLiveStatus,
        ActivateHarvestEvent = ActivateHarvestEvent,
        ActivatePlotCombat = ActivatePlotCombat,
        GetWishingWellModel = GetWishingWellModel,
        HasCoins = HasCoins,
    }
}

UpdateLiveStatus()
Notify("EMPIRE HUB LOADED!", "Welcome! Don't forget to support and like ICEDRAGON!", 4)
print("[VANTA] DRAGON ARENA | EMPIRE HUB successfully initialized with WindUI v1.6.66.")

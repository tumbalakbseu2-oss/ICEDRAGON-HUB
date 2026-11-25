--[[
    DO NOT STOP | ICEDRAGON
    Autonomous WindUI Suite (0.7 Ice Blue Transparency)
    Cross-Map Ready: Lobby, Route1610, Map02..Map09 (Update 2), Endless
    Verified against Shared.Config, CarController, CarInput, Chassis, RoadPath, TouchAssist
]]

-- 1. Clean Unload of Previous Instance
if getgenv()._ICEDRAGON_LOADED and type(getgenv()._ICEDRAGON_UNLOAD) == "function" then
    pcall(getgenv()._ICEDRAGON_UNLOAD)
    task.wait(0.15)
end

-- 2. Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 3. Support Links (IceDragon Template)
local YOUTUBE_URL = "http://www.youtube.com/@ROBLOX_icedragonScript"
local DISCORD_URL = "https://discord.gg/FSNv577TN"
local SUBSCRIBE_TEMPLATE = "dont forget subscribe like share comment " .. YOUTUBE_URL

local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        pcall(setclipboard, tostring(text))
    elseif type(toclipboard) == "function" then
        pcall(toclipboard, tostring(text))
    end
end

copyToClipboard(SUBSCRIBE_TEMPLATE)

-- 4. Load WindUI
local WindUISuccess, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not WindUISuccess or type(WindUI) ~= "table" then
    warn("[ICEDRAGON] Failed to load WindUI:", tostring(WindUI))
    return
end

-- 5. Register Custom Ice Blue Theme (0.7 Transparency)
local IceTheme = {
    Name = "IceDragon",
    Accent = Color3.fromRGB(165, 242, 255),
    Background = Color3.fromRGB(10, 24, 38),
    PanelBackground = Color3.fromRGB(15, 36, 56),
    ElementBackground = Color3.fromRGB(20, 48, 72),
    Text = Color3.fromRGB(235, 248, 255),
    Placeholder = Color3.fromRGB(130, 185, 215),
    Button = Color3.fromRGB(70, 175, 230),
    Toggle = Color3.fromRGB(120, 220, 255),
    Slider = Color3.fromRGB(145, 230, 255),
    Icon = Color3.fromRGB(165, 242, 255),
    Dialog = Color3.fromRGB(12, 30, 48),
    Checkbox = Color3.fromRGB(145, 230, 255),
    PanelBackgroundTransparency = 0.7,
    ElementBackgroundTransparency = 0.5,
}

pcall(function()
    WindUI:AddTheme(IceTheme)
    WindUI:SetTheme("IceDragon")
end)

local Window = WindUI:CreateWindow({
    Title = "DO NOT STOP | ICEDRAGON",
    Icon = "snowflake",
    Author = "by ICEDRAGON",
    Folder = "DoNotStopIceDragon",
    Size = UDim2.fromOffset(600, 480),
    Transparent = true,
    Theme = "IceDragon",
})

pcall(function()
    Window:EditOpenButton({
        Title = "DO NOT STOP | ICEDRAGON",
        Icon = "snowflake",
        CornerRadius = UDim.new(0, 16),
        StrokeThickness = 2,
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
        Position = UDim2.new(0.5, 0, 0, 86),
        Color = ColorSequence.new(
            Color3.fromRGB(165, 242, 255),
            Color3.fromRGB(50, 145, 215)
        ),
    })
    Window:SetToggleKey(Enum.KeyCode.RightShift)
end)

-- 6. State & Cleanup Registry
local State = {
    AutoDrive = false,
    LookaheadStuds = 56,
    MaxCruiseSpeed = 116, -- Safe under RecordTopAverage (120) / RecordBanAverage (140)
    MinCornerSpeed = 95,  -- Stays ahead of Map03 Fields Runner (94.76) on tight bends
    CornerSafety = 1.00,
    AmbushDodge = true,
    PaceAssist = true,    -- Prevents uphill/Frost speed drops below Runner pace

    SpeedBoost = false,
    BoostHoldKey = false, -- When true, only boosts while holding LeftShift
    BoostTargetSpeed = 134, -- Safe under SpeedWatch Allow 1.2x (~140) & RecordBanAverage (140)
    BoostCornerTrim = true,

    GripPatch = false,
    AntiTumble = false,
    AntiStagger = false,

    AutoCrank = false,
    AutoIntruder = false,
    AutoCrawler = false,
    AutoListener = false,
    AmbushAlert = false,

    RoadRibbon = false,
    MonsterHighlight = false,
    ClearFog = false,
    FullBright = false,
    AntiJumpscare = false,

    LobbyWalkSpeedEnabled = false,
    LobbyWalkSpeed = 24,
    SelectedMap = "Route1610",
    AutoVoteRetry = false,

    AntiAFK = true,
    Disable3DRender = false,
}

local Connections = {}
local DrawingLines = {}
local ActiveHighlights = {}
local OriginalHooks = {}
local OriginalTuneValues = {}
local CurrentAimState = { active = false, yaw = 0, pitch = 0 }
local CurrentCrankShield = false
local CurrentCrawlerDoorShield = false
local lastDoorHoldSent = false
local OriginalLighting = {
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    AtmosphereDensity = nil,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Top = Lighting.ColorShift_Top,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ExposureCompensation = Lighting.ExposureCompensation,
}
local AtmosphereInst = Lighting:FindFirstChildOfClass("Atmosphere")
if AtmosphereInst then
    OriginalLighting.AtmosphereDensity = AtmosphereInst.Density
end

local fullBrightCaptured = false
local function captureFullBrightDefaults()
    if fullBrightCaptured then
        return
    end
    OriginalLighting.Brightness = Lighting.Brightness
    OriginalLighting.ClockTime = Lighting.ClockTime
    OriginalLighting.GlobalShadows = Lighting.GlobalShadows
    OriginalLighting.Ambient = Lighting.Ambient
    OriginalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
    OriginalLighting.ColorShift_Top = Lighting.ColorShift_Top
    OriginalLighting.ColorShift_Bottom = Lighting.ColorShift_Bottom
    OriginalLighting.ExposureCompensation = Lighting.ExposureCompensation
    fullBrightCaptured = true
end

local function applyFullBrightProperties()
    Lighting.Brightness = 2.5
    Lighting.ClockTime = 14
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(190, 190, 190)
    Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
    Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
    Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
    Lighting.ExposureCompensation = 0.35
end

local function restoreFullBrightDefaults()
    if not fullBrightCaptured then
        return
    end
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.ClockTime = OriginalLighting.ClockTime
    Lighting.GlobalShadows = OriginalLighting.GlobalShadows
    Lighting.Ambient = OriginalLighting.Ambient
    Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    Lighting.ColorShift_Top = OriginalLighting.ColorShift_Top
    Lighting.ColorShift_Bottom = OriginalLighting.ColorShift_Bottom
    Lighting.ExposureCompensation = OriginalLighting.ExposureCompensation
    fullBrightCaptured = false
end

local function trackConn(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

-- 7. Safe Client Module & Shared Config Resolvers
local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)

local function safeRequire(inst)
    if not inst then
        return nil
    end
    local ok, mod = pcall(require, inst)
    return ok and mod or nil
end

local MapConfig = safeRequire(Shared and Shared:FindFirstChild("Config") and Shared.Config:FindFirstChild("Map"))
local WorldConfig = safeRequire(Shared and Shared:FindFirstChild("Config") and Shared.Config:FindFirstChild("World"))
local CodesConfig = safeRequire(Shared and Shared:FindFirstChild("Config") and Shared.Config:FindFirstChild("Codes"))
local IntruderConfig = safeRequire(Shared and Shared:FindFirstChild("Config") and Shared.Config:FindFirstChild("Intruder"))
local ListenerConfig = safeRequire(Shared and Shared:FindFirstChild("Config") and Shared.Config:FindFirstChild("Listener"))
local RoadPath = safeRequire(Shared and Shared:FindFirstChild("Rules") and Shared.Rules:FindFirstChild("RoadPath"))
local TouchAssist = safeRequire(Shared and Shared:FindFirstChild("Rules") and Shared.Rules:FindFirstChild("Rally") and Shared.Rules.Rally:FindFirstChild("TouchAssist"))
local DriftAssistMod = safeRequire(Shared and Shared:FindFirstChild("Rules") and Shared.Rules:FindFirstChild("Rally") and Shared.Rules.Rally:FindFirstChild("DriftAssist"))

local ClientScripts = LocalPlayer:WaitForChild("PlayerScripts", 5) and LocalPlayer.PlayerScripts:FindFirstChild("Client")
local CarController = safeRequire(ClientScripts and ClientScripts:FindFirstChild("CarController"))
local CarInput = safeRequire(ClientScripts and ClientScripts:FindFirstChild("CarInput"))
local ChassisMod = safeRequire(ClientScripts and ClientScripts:FindFirstChild("Chassis"))
local IntruderClient = safeRequire(ClientScripts and ClientScripts:FindFirstChild("Intruder"))
local FlashlightClient = safeRequire(ClientScripts and ClientScripts:FindFirstChild("Flashlight"))

local function getRig()
    if not CarController then
        return nil
    end
    if type(CarController.rig) == "function" then
        local ok, rig = pcall(CarController.rig)
        return ok and rig or nil
    end
    return CarController.rig
end

local function getRemote(name)
    return RemotesFolder and RemotesFolder:FindFirstChild(name)
end

local function getRunFolder()
    local runs = workspace:FindFirstChild("Runs")
    return runs and runs:FindFirstChild(tostring(LocalPlayer.UserId)) or nil
end

local function getMyCar()
    local cars = workspace:FindFirstChild("Cars")
    if not cars then
        return nil
    end
    return cars:FindFirstChild("Car_" .. tostring(LocalPlayer.UserId))
end

local function getMyChassis()
    local car = getMyCar()
    return car and car:FindFirstChild("Chassis") or nil
end

local function isNitroKeyHeld()
    return not UserInputService:GetFocusedTextBox() and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
end

local function getListenerStealthLimit(runFolder)
    if not runFolder then
        return false, nil, "", 0
    end
    local phase = runFolder:GetAttribute("ListenerPhase")
    if phase == "Patrol" or phase == "Alert" or phase == "Charge" or phase == "Search" or phase == "Return" then
        local quiet = (ListenerConfig and type(ListenerConfig.Quiet) == "number") and ListenerConfig.Quiet or 48
        local hearDist = (ListenerConfig and type(ListenerConfig.Hear) == "number") and ListenerConfig.Hear or 420
        local heard = tonumber(runFolder:GetAttribute("ListenerHeard")) or 0
        -- Beyond Hear+95 studs in calm Patrol, Listener nearness == 0; wait until approaching hearing range
        if phase == "Patrol" and heard <= 0.01 then
            local ch = getMyChassis()
            local lx = tonumber(runFolder:GetAttribute("ListenerX"))
            local lz = tonumber(runFolder:GetAttribute("ListenerZ"))
            if ch and lx and lz and (lx ~= 0 or lz ~= 0) then
                local dist = math.sqrt((lx - ch.Position.X) ^ 2 + (lz - ch.Position.Z) ^ 2)
                if dist > hearDist + 95 then
                    return false, nil, phase, heard
                end
            end
        end
        local safeLimit = (phase == "Alert" or phase == "Charge" or heard >= 0.7)
            and math.max(quiet - 4.0, 38)
            or (quiet - 2.2)
        return true, safeLimit, phase, heard
    end
    return false, nil, tostring(phase or ""), 0
end

local function isBoostActiveNow()
    if not State.SpeedBoost then
        return false
    end
    if State.BoostHoldKey and not isNitroKeyHeld() then
        return false
    end
    if State.AutoListener then
        local listening = getListenerStealthLimit(getRunFolder())
        if listening then
            return false
        end
    end
    return true
end

-- 8. RoadPath, Corner Envelope & TouchAssist Cache (Cross-Map + Endless Epoch Safe)
local CachedRoad, CachedBends, CachedCornerCurvatures, CachedSignedCurvatures, CachedEpoch, CachedPiecesCount = nil, nil, nil, nil, -1, -1

local function computeCornerCurvatures(samples)
    local n = #samples
    local curvatures = table.create(n, 0)
    local signedCurvatures = table.create(n, 0)
    for i = 1, n do
        local a = samples[math.max(i - 1, 1)]
        local b = samples[math.min(i + 1, n)]
        local ds = math.max(b.s - a.s, 1)
        local dotFwd = math.clamp(a.fx * b.fx + a.fz * b.fz, -1, 1)
        local k = math.acos(dotFwd) / ds
        curvatures[i] = k
        -- roadRight = (-a.fz, a.fx); dotTurn > 0 means road bends right (+steer)
        local dotTurn = b.fx * (-a.fz) + b.fz * a.fx
        signedCurvatures[i] = (dotTurn >= 0 and 1 or -1) * k
    end
    return curvatures, signedCurvatures
end

local function sampleIndexAtS(samples, s)
    local lo, hi = 1, #samples
    while hi - lo > 1 do
        local mid = (lo + hi) // 2
        if samples[mid].s <= s then
            lo = mid
        else
            hi = mid
        end
    end
    return lo
end

local CachedStaticHazards, CachedHazardsWorld, CachedHazardsPieces = nil, nil, -1

local function getStaticHazards()
    local pieceCount = (WorldConfig and type(WorldConfig.Pieces) == "table") and #WorldConfig.Pieces or -1
    if CachedStaticHazards and CachedHazardsWorld == WorldConfig and CachedHazardsPieces == pieceCount then
        return CachedStaticHazards
    end
    local hazards = {}
    if not WorldConfig then
        CachedStaticHazards = hazards
        CachedHazardsWorld = nil
        CachedHazardsPieces = -1
        return hazards
    end

    local raw = {}
    local function addRaw(startS, endS, blockLat, safeMag, lead, forcedLat)
        table.insert(raw, {
            startS = startS,
            endS = endS,
            blockLat = blockLat,
            safeMag = safeMag,
            lead = lead or 74,
            forcedLat = forcedLat,
        })
    end

    if type(WorldConfig.Ambushes) == "table" then
        for _, entry in ipairs(WorldConfig.Ambushes) do
            if type(entry[1]) == "number" and type(entry[2]) == "number" and math.abs(entry[2]) <= 9.5 then
                addRaw(entry[1] - 4, entry[1] + 6, entry[2], 5.2, 68, nil)
            end
        end
    end

    if type(WorldConfig.Barricades) == "table" then
        for _, entry in ipairs(WorldConfig.Barricades) do
            if type(entry[1]) == "number" and type(entry[2]) == "number" and math.abs(entry[2]) <= 9.5 then
                local halfW = math.abs(tonumber(entry[3]) or 6) * 0.5
                local mag = math.max(5.5, math.min(7.5, halfW + 3.6))
                addRaw(entry[1] - 4, entry[1] + 5, entry[2], mag, 82, nil)
            end
        end
    end

    if type(WorldConfig.Wrecks) == "table" then
        for _, entry in ipairs(WorldConfig.Wrecks) do
            if type(entry[1]) == "number" and type(entry[2]) == "number" and math.abs(entry[2]) <= 11.2 then
                local mag = math.max(0, 6.8 - math.abs(entry[2]) * 0.35)
                if mag > 0.25 then
                    addRaw(entry[1] - 8, entry[1] + 8, entry[2], mag, 62, nil)
                end
            end
        end
    end

    -- Circular off-center sinkholes (e.g. Tournament Chasms [2..4])
    if type(WorldConfig.Chasms) == "table" then
        for _, ch in ipairs(WorldConfig.Chasms) do
            if type(ch.s) == "number" and type(ch.radius) == "number" and type(ch.lateral) == "number" then
                local rad = math.max(ch.radius, 4)
                local innerEdge = math.abs(ch.lateral) - rad
                local clearMag = math.clamp(7.0 - math.min(innerEdge, 4) * 0.35, 5.8, 7.6)
                addRaw(ch.s - rad * 0.85, ch.s + rad * 0.85, ch.lateral, clearMag, 84, nil)
            end
        end
    end

    local raceway = WorldConfig.Raceway
    if type(raceway) == "table" then
        if type(raceway.Collapse) == "table" then
            for _, col in ipairs(raceway.Collapse) do
                if type(col[1]) == "number" and type(col[2]) == "number" and col[2] ~= 0 then
                    -- Solid FallenTruss blocks from edge down to |lat| ~ 0.1
                    addRaw(col[1] - 7, col[1] + 5, col[2] * 6.8, 7.0, 86, nil)
                end
            end
        end
        if type(raceway.PileUp) == "table" then
            for _, pu in ipairs(raceway.PileUp) do
                if type(pu[1]) == "number" and type(pu[2]) == "number" and pu[2] ~= 0 then
                    addRaw(pu[1] - 7, pu[1] + 5, pu[2] * 6.5, 7.0, 86, nil)
                end
            end
        end
        if type(raceway.Hauler) == "table" and type(raceway.Hauler.Foot) == "number" then
            local h = raceway.Hauler
            local endS = (type(h.Deck) == "table" and tonumber(h.Deck[2])) or (h.Foot + 68)
            addRaw(h.Foot - 4, endS, h.Lateral or -8.25, 6.2, 85, nil)
        end
        if type(raceway.Board) == "table" and type(raceway.Board.Foot) == "number" then
            local b = raceway.Board
            local endS = (type(b.Cars) == "table" and tonumber(b.Cars[2])) or (b.Lip and (b.Lip + 24)) or (b.Foot + 50)
            local rampLat = tonumber(b.Lateral) or 8.5
            addRaw(b.Foot - 4, endS, -rampLat, math.abs(rampLat), 92, math.clamp(rampLat, -8.5, 8.5))
        end
    end

    table.sort(raw, function(a, b)
        return a.startS < b.startS
    end)

    -- Merge adjacent hazards on the same side (e.g. Barricade + FallenTruss, Barricade + Chasm)
    for _, item in ipairs(raw) do
        local prev = hazards[#hazards]
        local sameSide = prev and (
            (item.forcedLat ~= nil and prev.forcedLat == item.forcedLat)
            or (item.forcedLat == nil and prev.forcedLat == nil and math.sign(item.blockLat) == math.sign(prev.blockLat))
        )
        if prev and sameSide and item.startS <= prev.endS + 22 then
            prev.endS = math.max(prev.endS, item.endS)
            prev.safeMag = math.max(prev.safeMag, item.safeMag)
            prev.lead = math.max(prev.lead, item.lead)
        else
            table.insert(hazards, item)
        end
    end

    CachedStaticHazards = hazards
    CachedHazardsWorld = WorldConfig
    CachedHazardsPieces = pieceCount
    return hazards
end

local function isInCenterCorridor(s)
    local raceway = WorldConfig and WorldConfig.Raceway
    if type(raceway) ~= "table" then
        return false
    end
    local fault = raceway.Fault
    if type(fault) == "table" and type(fault.Foot) == "number" then
        local farEnd = fault.Apron or fault.Far or (fault.Lip and (fault.Lip + 140)) or (fault.Foot + 220)
        if s >= fault.Foot - 95 and s <= farEnd + 15 then
            return true
        end
    end
    local shed = raceway.Shed
    if type(shed) == "table" and type(shed[1]) == "number" and type(shed[2]) == "number" then
        if s >= shed[1] - 75 and s <= shed[2] + 25 then
            return true
        end
    end
    return false
end

local function obstacleAvoidanceLateral(s, road)
    if not WorldConfig then
        return 0
    end
    if isInCenterCorridor(s) then
        return 0
    end

    local halfSafe = math.max(((WorldConfig.RoadWidth or 24) * 0.5) - 3.2, 5.5)
    local bestShift, bestScore = 0, 0
    local inSlalom = false

    -- Earliest-unpassed static hazard solver: releases right after rear bumper clears endS+6.5
    local hazards = getStaticHazards()
    local activeIdx = nil
    for i, h in ipairs(hazards) do
        if s <= h.endS + 6.5 then
            activeIdx = i
            break
        end
    end

    if activeIdx then
        local h = hazards[activeIdx]
        local nextH = hazards[activeIdx + 1]
        if nextH and (nextH.startS - h.endS) <= 145 then
            inSlalom = true
        end
        local prevH = hazards[activeIdx - 1]
        if prevH and (h.startS - prevH.endS) <= 145 then
            inSlalom = true
        end

        local lead = h.lead or 74
        local enterStart = h.startS - lead
        if s >= enterStart then
            local fullAt = h.startS - 18
            local w = (s < fullAt) and math.clamp((s - enterStart) / math.max(fullAt - enterStart, 1), 0, 1) or 1
            local target
            if h.forcedLat then
                target = math.clamp(h.forcedLat, -halfSafe, halfSafe) * w
            else
                local dir = (math.abs(h.blockLat) > 0.2) and -math.sign(h.blockLat) or 1
                target = math.clamp(dir * h.safeMag * w, -halfSafe, halfSafe)
            end
            bestShift = target
            bestScore = math.abs(target)
        elseif prevH and s <= prevH.endS + 26 and (h.startS - prevH.endS) > 145 then
            local tailW = 1 - (s - prevH.endS) / 26
            if tailW > 0 then
                local dir = (math.abs(prevH.blockLat) > 0.2) and -math.sign(prevH.blockLat) or 1
                local target = prevH.forcedLat
                    and math.clamp(prevH.forcedLat, -halfSafe, halfSafe) * tailW
                    or math.clamp(dir * prevH.safeMag * tailW, -halfSafe, halfSafe)
                bestShift = target
                bestScore = math.abs(target)
            end
        end
    elseif #hazards > 0 then
        local lastH = hazards[#hazards]
        if s > lastH.endS and s <= lastH.endS + 26 then
            local tailW = 1 - (s - lastH.endS) / 26
            local dir = (math.abs(lastH.blockLat) > 0.2) and -math.sign(lastH.blockLat) or 1
            local target = lastH.forcedLat
                and math.clamp(lastH.forcedLat, -halfSafe, halfSafe) * tailW
                or math.clamp(dir * lastH.safeMag * tailW, -halfSafe, halfSafe)
            bestShift = target
            bestScore = math.abs(target)
        end
    end

    -- Avoid dynamic SteepleThrow crates & Update 2 road hazards (e.g. Thrown/Crawler props)
    local cm = workspace:FindFirstChild("ClientMonsters")
    if cm and road and RoadPath then
        local thrown = cm:FindFirstChild("Thrown")
        if thrown then
            for _, item in ipairs(thrown:GetDescendants()) do
                if item:IsA("BasePart") then
                    local obsS, obsLat = RoadPath.project(road, item.Position.X, item.Position.Z)
                    if obsS and obsLat and math.abs(obsLat) < 6.0 and obsS >= s - 8 and obsS <= s + 60 then
                        local dir = (math.abs(obsLat) > 0.25) and -math.sign(obsLat) or 1
                        local w = math.clamp(1 - math.max(obsS - s - 25, 0) / 35, 0.35, 1)
                        local shift = math.clamp(dir * 5.2 * w, -halfSafe, halfSafe)
                        if math.abs(shift) > bestScore then
                            bestScore = math.abs(shift)
                            bestShift = shift
                        end
                    end
                end
            end
        end
        for _, m in ipairs(cm:GetChildren()) do
            local mName = m.Name
            if mName ~= "Runner" and mName ~= "Ambusher" and mName ~= "Thrown" and mName ~= "Shard" then
                local pos
                if m:IsA("BasePart") then
                    pos = m.Position
                elseif m:IsA("Model") then
                    local pp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                    pos = pp and pp.Position or m:GetPivot().Position
                end
                if pos then
                    local obsS, obsLat = RoadPath.project(road, pos.X, pos.Z)
                    if obsS and obsLat and math.abs(obsLat) < 6.5 and obsS >= s - 6 and obsS <= s + 65 then
                        local dir = (math.abs(obsLat) > 0.25) and -math.sign(obsLat) or 1
                        local w = math.clamp(1 - math.max(obsS - s - 25, 0) / 40, 0.35, 1)
                        local shift = math.clamp(dir * 5.4 * w, -halfSafe, halfSafe)
                        if math.abs(shift) > bestScore then
                            bestScore = math.abs(shift)
                            bestShift = shift
                        end
                    end
                end
            end
        end
    end

    -- Dodge The Crawler "Rise" road pit (Crawler.HitRadius = 4.1, Fair.DodgeEnds = true on Map03+)
    local runFolder = getRunFolder()
    if runFolder and road and RoadPath and runFolder:GetAttribute("CrawlerPhase") == "Rise" then
        local cSpot = runFolder:GetAttribute("CrawlerSpot")
        if typeof(cSpot) == "Vector3" and cSpot.Magnitude > 1 then
            local spotS, spotLat = RoadPath.project(road, cSpot.X, cSpot.Z)
            if spotS and spotLat and spotS >= s - 10 and spotS <= s + 95 and math.abs(spotLat) <= 10.5 then
                local dir = (spotLat >= 0) and -1 or 1
                local w = math.clamp(1 - math.max(spotS - s - 45, 0) / 50, 0.45, 1)
                local safeLat = math.clamp(spotLat + dir * 7.8 * w, -halfSafe, halfSafe)
                return safeLat
            end
        end
    end

    -- Dodge prowling/charging The Listener on road (Touch = 6.5, Catch = 13)
    if runFolder and road and RoadPath and (State.AutoListener or State.AmbushDodge) then
        local listening, _, lPhase = getListenerStealthLimit(runFolder)
        if listening then
            local lx = tonumber(runFolder:GetAttribute("ListenerX"))
            local lz = tonumber(runFolder:GetAttribute("ListenerZ"))
            if lx and lz and (lx ~= 0 or lz ~= 0) then
                local lS, lLat = RoadPath.project(road, lx, lz)
                if lS and lLat and lS >= s - 14 and lS <= s + 95 and math.abs(lLat) < 11.5 then
                    local dir = (lLat >= 0) and -1 or 1
                    local w = math.clamp(1 - math.max(lS - s - 40, 0) / 55, 0.45, 1)
                    local clearDist = (lPhase == "Alert" or lPhase == "Charge") and 11.5 or 8.5
                    local safeLat = math.clamp(lLat + dir * clearDist * w, -halfSafe, halfSafe)
                    if math.abs(safeLat) > bestScore then
                        bestScore = math.abs(safeLat)
                        bestShift = safeLat
                    end
                end
            end
        end
    end

    return bestShift, inSlalom
end

local function getActiveRoad()
    if MapConfig and MapConfig.IsLobby then
        return nil, nil
    end
    if not (WorldConfig and RoadPath and WorldConfig.Pieces) then
        return nil, nil
    end
    local epoch = WorldConfig.Endless and WorldConfig.Endless.epoch or 0
    local n = #WorldConfig.Pieces
    if not CachedRoad or epoch ~= CachedEpoch or n ~= CachedPiecesCount then
        local ok, road = pcall(RoadPath.build, WorldConfig)
        if ok and road then
            CachedRoad = road
            CachedEpoch = epoch
            CachedPiecesCount = n
            if type(road.samples) == "table" and #road.samples > 1 then
                CachedCornerCurvatures, CachedSignedCurvatures = computeCornerCurvatures(road.samples)
                if TouchAssist and TouchAssist.bends then
                    local totalLen = road.length or WorldConfig.FinishS or 8000
                    local okB, bends = pcall(TouchAssist.bends, { Step = 8, Window = 24 }, road.samples, totalLen)
                    CachedBends = okB and bends or nil
                end
            else
                CachedCornerCurvatures = nil
            end
        end
    end
    return CachedRoad, CachedBends
end

-- 9. Hooks & Physics Helpers
local function applyCarHooks()
    if ChassisMod and type(ChassisMod.Tumble) == "function" and not OriginalHooks.ChassisTumble then
        OriginalHooks.ChassisTumble = ChassisMod.Tumble
        ChassisMod.Tumble = function(self, ...)
            if getgenv()._ICEDRAGON_LOADED and State.AntiTumble then
                return false, 0
            end
            return OriginalHooks.ChassisTumble(self, ...)
        end
    end

    if CarController then
        for _, fnName in ipairs({ "stagger", "shove", "rock", "bump" }) do
            if type(CarController[fnName]) == "function" and not OriginalHooks[fnName] then
                OriginalHooks[fnName] = CarController[fnName]
                CarController[fnName] = function(...)
                    if getgenv()._ICEDRAGON_LOADED and State.AntiStagger then
                        return
                    end
                    return OriginalHooks[fnName](...)
                end
            end
        end
    end

    if FlashlightClient and type(FlashlightClient.beam) == "function" and not OriginalHooks.FlashlightBeam then
        OriginalHooks.FlashlightBeam = FlashlightClient.beam
        FlashlightClient.beam = function(...)
            if getgenv()._ICEDRAGON_LOADED and State.AutoIntruder and IntruderClient and IntruderClient.active then
                local holderOk = type(FlashlightClient.holder) == "function" and FlashlightClient.holder()
                if holderOk then
                    local cam = workspace.CurrentCamera
                    local chassis = getMyChassis()
                    local origin = (chassis and chassis.CFrame:PointToWorldSpace(Vector3.new(0, 1.75, 0.4))) or (cam and cam.CFrame.Position)
                    local face = IntruderClient.face
                    if origin and typeof(face) == "Vector3" then
                        local diff = face - origin
                        if diff.Magnitude > 0.01 then
                            return origin, diff.Unit
                        end
                    end
                end
            end
            return OriginalHooks.FlashlightBeam(...)
        end
    end

    -- Enable Analog steering smoothing during Auto-Drive & stealth-limit throttle/brake during Listener encounters
    if CarInput and type(CarInput.Read) == "function" and not OriginalHooks.CarInputRead then
        OriginalHooks.CarInputRead = CarInput.Read
        CarInput.Read = function(...)
            local res = OriginalHooks.CarInputRead(...)
            if getgenv()._ICEDRAGON_LOADED and type(res) == "table" and not res.Hold then
                if State.AutoDrive then
                    res.Analog = true
                elseif State.AutoListener then
                    local rf = getRunFolder()
                    if rf and rf:GetAttribute("State") == "Driving" then
                        local listening, quietLimit = getListenerStealthLimit(rf)
                        if listening and quietLimit then
                            local ch = getMyChassis()
                            local spd = ch and ch.AssemblyLinearVelocity.Magnitude or 0
                            if spd > quietLimit - 1.5 then
                                res.Throttle = 0
                            end
                            if spd > quietLimit then
                                res.Brake = math.max(res.Brake or 0, math.clamp((spd - quietLimit) / 6, 0.25, 0.95))
                            end
                        end
                    end
                end
            end
            return res
        end
    end

    -- Intercept native Flashlight.lua / WindowCrank.lua / Crawler.lua cancel/hit fires cleanly
    if not OriginalHooks.Namecall and type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
        local okHook, hookedOld = pcall(function()
            local oldNc
            local wrap = (type(newcclosure) == "function") and newcclosure or function(f) return f end
            oldNc = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                local method = getnamecallmethod()
                if getgenv()._ICEDRAGON_LOADED and (method == "FireServer") and (CurrentAimState.active or CurrentCrankShield or State.AutoCrawler) then
                    if not (type(checkcaller) == "function" and checkcaller()) and typeof(self) == "Instance" and self.Parent == RemotesFolder then
                        local rName = self.Name
                        if State.AutoIntruder and CurrentAimState.active then
                            if rName == "Flashlight" then
                                local arg1 = ...
                                if arg1 == false then
                                    return
                                end
                            elseif rName == "FlashAim" then
                                return oldNc(self, CurrentAimState.yaw, CurrentAimState.pitch, true)
                            end
                        end
                        if State.AutoCrank and CurrentCrankShield and rName == "Crank" then
                            local arg1 = ...
                            if arg1 == false then
                                return
                            end
                        end
                        if State.AutoCrawler then
                            if rName == "CrawlerHit" then
                                return
                            elseif CurrentCrawlerDoorShield and rName == "DoorHold" then
                                local arg1 = ...
                                if arg1 == false then
                                    return
                                end
                            end
                        end
                    end
                end
                return oldNc(self, ...)
            end))
            return oldNc
        end)
        if okHook and type(hookedOld) == "function" then
            OriginalHooks.Namecall = hookedOld
        end
    end
end

local CachedCleanSurfaces, CachedCleanSrc = nil, nil
local OverlayByRawTune = {}
local RawTuneByOverlay = {}
local OverlayMeta = {}
local smoothDesiredLat = 0
local LastAutoMaxSpeed = 116
local LastAutoLatDelta = 0

local function syncTuneOverlay(forceRestore)
    local rig = getRig()
    local shouldAttach = (not forceRestore) and (State.GripPatch or State.SpeedBoost)
    if shouldAttach then
        if not (rig and rig.Tune) then
            return
        end
        local rawTune = RawTuneByOverlay[rig.Tune] or rig.Tune
        local overlay = OverlayByRawTune[rawTune]
        local meta = overlay and OverlayMeta[overlay]
        if not overlay then
            overlay = table.clone(rawTune)
            meta = {}
            if type(rawTune.Tyres) == "table" then
                local tyres = table.clone(rawTune.Tyres)
                tyres.LateralGrip = math.max((rawTune.Tyres.LateralGrip or 1.1) * 1.80, 2.15)
                tyres.LongitudinalGrip = math.max((rawTune.Tyres.LongitudinalGrip or 1.1) * 1.75, 2.10)
                tyres.PeakSlip = math.max(rawTune.Tyres.PeakSlip or 6.5, 12.5)
                tyres.Plateau = math.max(rawTune.Tyres.Plateau or 0.98, 1.0)
                tyres.Tail = math.max(rawTune.Tyres.Tail or 0.94, 0.99)
                tyres.ForceLift = math.max(rawTune.Tyres.ForceLift or 0.4, 0.90)
                meta.BoostTyres = tyres
            end
            if type(rawTune.Steering) == "table" then
                local steering = table.clone(rawTune.Steering)
                steering.MinAngle = math.max(rawTune.Steering.MinAngle or 4.5, 9.0)
                steering.YawGripOverlap = math.max(rawTune.Steering.YawGripOverlap or 1.05, 1.45)
                steering.BetaFree = math.max(rawTune.Steering.BetaFree or 11, 18)
                meta.BoostSteering = steering
            end
            if type(rawTune.Engine) == "table" then
                meta.BoostEngine = table.clone(rawTune.Engine)
            end
            if type(rawTune.Drag) == "table" then
                meta.BoostDrag = table.clone(rawTune.Drag)
            end
            if type(rawTune.Surfaces) == "table" then
                if CachedCleanSrc ~= rawTune.Surfaces or not CachedCleanSurfaces then
                    local cleanSurfaces = {}
                    for k, v in pairs(rawTune.Surfaces) do
                        if type(v) == "table" then
                            cleanSurfaces[k] = {
                                Lateral = math.max(v.Lateral or 1, 1.38),
                                Longitudinal = math.max(v.Longitudinal or 1, 1.34),
                                Drag = 0,
                                DragPerSpeed = 0,
                                Roughness = 0.08,
                                Sink = 0,
                            }
                        else
                            cleanSurfaces[k] = v
                        end
                    end
                    CachedCleanSrc = rawTune.Surfaces
                    CachedCleanSurfaces = cleanSurfaces
                end
                meta.CleanSurfaces = CachedCleanSurfaces
            end
            OverlayByRawTune[rawTune] = overlay
            RawTuneByOverlay[overlay] = rawTune
            OverlayMeta[overlay] = meta
            OriginalTuneValues.Saved = true
        end

        -- Grip + Steering layer
        if State.GripPatch then
            if meta.BoostTyres then overlay.Tyres = meta.BoostTyres end
            if meta.BoostSteering and type(rawTune.Steering) == "table" then
                meta.BoostSteering.Assist = State.AutoDrive and 0.02 or 0.12
                meta.BoostSteering.AssistMax = State.AutoDrive and 3 or 6
                meta.BoostSteering.Rate = State.AutoDrive and (rawTune.Steering.Rate or 4.5) or math.max(rawTune.Steering.Rate or 4.5, 6.8)
                meta.BoostSteering.ReturnRate = State.AutoDrive and (rawTune.Steering.ReturnRate or 7.0) or math.max(rawTune.Steering.ReturnRate or 7.0, 10.5)
                meta.BoostSteering.Stability = State.AutoDrive and (rawTune.Steering.Stability or 2.6) or math.min(rawTune.Steering.Stability or 2.6, 2.1)
                overlay.Steering = meta.BoostSteering
            end
            if meta.CleanSurfaces then overlay.Surfaces = meta.CleanSurfaces end
            overlay.DriftAssist = nil
            overlay.RoadKeep = nil
            if rig.Keep then
                rig.Keep.keepSteer = 0
                rig.Keep.keepExcess = 0
            end
            if rig.Drift then
                if DriftAssistMod and type(DriftAssistMod.reset) == "function" then
                    pcall(DriftAssistMod.reset, rig.Drift)
                else
                    rig.Drift.dir = 0
                    rig.Drift.share = 0
                    rig.Drift.hold = 0
                    rig.Drift.brakeMemory = 0
                end
            end
        else
            overlay.Tyres = rawTune.Tyres
            overlay.Steering = rawTune.Steering
            overlay.Surfaces = rawTune.Surfaces
            overlay.DriftAssist = rawTune.DriftAssist
            overlay.RoadKeep = State.AutoDrive and nil or rawTune.RoadKeep
        end

        -- Engine + Drag Boost layer (matches CarTune Power/Top^2 relation; yields automatically for Listener stealth)
        if isBoostActiveNow() then
            local ratio = math.clamp(State.BoostTargetSpeed / 116, 1.05, 1.65)
            if meta.BoostEngine and type(rawTune.Engine) == "table" then
                meta.BoostEngine.Force = (rawTune.Engine.Force or 1.88) * (ratio * ratio * 1.15)
                meta.BoostEngine.RpmRise = (rawTune.Engine.RpmRise or 14) * 1.45
                meta.BoostEngine.Redline = (rawTune.Engine.Redline or 7400) * math.max(ratio, 1.08)
                meta.BoostEngine.Limiter = (rawTune.Engine.Limiter or 7600) * math.max(ratio, 1.08)
                overlay.Engine = meta.BoostEngine
            end
            if meta.BoostDrag and type(rawTune.Drag) == "table" then
                meta.BoostDrag.Air = (rawTune.Drag.Air or 0.00024) / (ratio * ratio)
                overlay.Drag = meta.BoostDrag
            end
        else
            overlay.Engine = rawTune.Engine
            overlay.Drag = rawTune.Drag
        end

        if rig.Tune ~= overlay then
            rig.Tune = overlay
        end
    else
        if rig and rig.Tune and RawTuneByOverlay[rig.Tune] then
            rig.Tune = RawTuneByOverlay[rig.Tune]
        end
        table.clear(OverlayByRawTune)
        table.clear(RawTuneByOverlay)
        table.clear(OverlayMeta)
        CachedCleanSurfaces = nil
        CachedCleanSrc = nil
        OriginalTuneValues.Saved = false
    end
end

local function syncGripPatch(enabled)
    syncTuneOverlay(enabled == false)
end

local function syncAutoDriveOverride()
    if not (CarInput and type(CarInput.setOverride) == "function") then
        return
    end
    if not State.AutoDrive then
        smoothDesiredLat = 0
        LastAutoMaxSpeed = State.MaxCruiseSpeed
        LastAutoLatDelta = 0
        pcall(CarInput.setOverride, nil)
        pcall(syncGripPatch, State.GripPatch)
        return
    end
    pcall(syncGripPatch, State.GripPatch)

    pcall(CarInput.setOverride, function()
        local chassis = getMyChassis()
        local road = select(1, getActiveRoad())
        if not (chassis and road and RoadPath) then
            return 0, 0, 0, false
        end

        local pos = chassis.Position
        local speed = chassis.AssemblyLinearVelocity.Magnitude
        local currentS = RoadPath.project(road, pos.X, pos.Z)
        local rx, _, rz, rfx, rfz = RoadPath.pointAt(road, currentS, 0)
        local lateralErr = (pos.X - rx) * (-rfz) + (pos.Z - rz) * rfx

        local obsLat, inSlalom = 0, false
        if State.AmbushDodge then
            obsLat, inSlalom = obstacleAvoidanceLateral(currentS, road)
        end
        local reversingSide = (obsLat * smoothDesiredLat < -2) or (math.abs(obsLat - smoothDesiredLat) > 4.5)
        local latLerp = (reversingSide or inSlalom) and 0.42 or 0.24
        smoothDesiredLat = smoothDesiredLat + (obsLat - smoothDesiredLat) * latLerp
        local latDelta = lateralErr - smoothDesiredLat
        LastAutoLatDelta = latDelta

        -- Measure upcoming curvature & signed turn preview ahead
        local samples = road.samples
        local maxKNow = 0
        local previewSignedSum, previewCount = 0, 0
        if CachedCornerCurvatures and type(samples) == "table" and #samples > 1 then
            local idxNow = sampleIndexAtS(samples, currentS)
            for i = idxNow, #samples do
                local dS = samples[i].s - currentS
                if dS > 75 then
                    break
                end
                local k = CachedCornerCurvatures[i] or 0
                if k > maxKNow then
                    maxKNow = k
                end
                if dS >= 4 and dS <= 22 and CachedSignedCurvatures then
                    previewSignedSum = previewSignedSum + (CachedSignedCurvatures[i] or 0)
                    previewCount = previewCount + 1
                end
            end
        end
        local previewSignedK = (previewCount > 0) and (previewSignedSum / previewCount) or 0

        -- Tighten Pure-Pursuit lookahead on curves WITHOUT stretching chord when recovering mid-bend
        local curveFactor = math.clamp(1 - math.max(maxKNow - 0.0025, 0) * 65, 0.36, 1)
        local nomLook = math.clamp(State.LookaheadStuds, 34, 50)
        local baseLook = math.clamp(speed * 0.38, 22, nomLook) * curveFactor
        baseLook = math.max(baseLook, 17)
        local maxMerge = (maxKNow >= 0.005) and 28 or 52
        local mergeFloor = math.min(math.abs(latDelta) * 1.4 + 16, maxMerge)
        local lookDist = math.max(baseLook, mergeFloor)
        local targetS = currentS + lookDist

        local tx, _, tz = RoadPath.pointAt(road, targetS, smoothDesiredLat)
        -- Use horizontally-flattened XZ vehicle heading (immune to terrain roll/hill pitch)
        local lv = chassis.CFrame.LookVector
        local flatFwd = Vector3.new(lv.X, 0, lv.Z)
        if flatFwd.Magnitude < 0.05 then
            flatFwd = Vector3.new(rfx, 0, rfz)
        end
        flatFwd = flatFwd.Unit
        local flatRight = Vector3.new(-flatFwd.Z, 0, flatFwd.X)
        local toTarget = Vector3.new(tx - pos.X, 0, tz - pos.Z)
        local localX = toTarget:Dot(flatRight)
        local localFwd = toTarget:Dot(flatFwd)
        local planarDist = math.max(math.sqrt(localX * localX + localFwd * localFwd), 1)

        local rig = getRig()
        local steer
        if localFwd < 2 then
            steer = (localX >= 0) and 1 or -1
        else
            local wheelbase = (rig and rig.Wheelbase) or 9
            local maxLockRad = math.rad(math.max((rig and rig.MaxAngleNow) or 34, 2))
            local alpha = math.atan2(localX, localFwd)
            local deltaPP = math.atan(2 * wheelbase * math.sin(alpha) / planarDist)

            -- Curvature Feedforward + Stanley Road-Frame Alignment + Lateral Drift Damping
            local roadUnit = Vector3.new(rfx, 0, rfz)
            if roadUnit.Magnitude > 0.01 then
                roadUnit = roadUnit.Unit
            else
                roadUnit = flatFwd
            end
            local roadRightX, roadRightZ = -roadUnit.Z, roadUnit.X
            local fwdDotRight = flatFwd.X * roadRightX + flatFwd.Z * roadRightZ
            local fwdDotFwd = flatFwd.X * roadUnit.X + flatFwd.Z * roadUnit.Z
            local headingErr = math.atan2(fwdDotRight, fwdDotFwd) -- + = nose points RIGHT of road -> steer LEFT (-)
            local deltaFF = math.atan(wheelbase * previewSignedK)
            local deltaCross = -math.atan(2.5 * latDelta / math.max(speed, 16))
            local vel = chassis.AssemblyLinearVelocity
            local latVel = vel.X * roadRightX + vel.Z * roadRightZ
            local latVelDamp = math.clamp(-latVel * 0.0085, -0.14, 0.14)
            local deltaStanley = deltaFF - headingErr + deltaCross + latVelDamp

            local blendedDelta = deltaStanley * 0.62 + deltaPP * 0.38
            steer = math.clamp(blendedDelta / maxLockRad, -1, 1)
        end

        -- Pre-corner braking envelope matched to Brakes.Force (~32..38 studs/s^2 decel) & R=82..100 curves
        local boostEngaged = isBoostActiveNow()
        local maxSpeed = boostEngaged and math.max(State.MaxCruiseSpeed, State.BoostTargetSpeed) or State.MaxCruiseSpeed
        local effectiveFloor = State.GripPatch and math.clamp(State.MinCornerSpeed, 70, maxSpeed)
            or math.clamp(State.MinCornerSpeed - 14, 66, maxSpeed)
        if (not boostEngaged or State.BoostCornerTrim) and CachedCornerCurvatures and type(samples) == "table" and #samples > 1 then
            local latGrip = (rig and rig.Tune and rig.Tune.Tyres and rig.Tune.Tyres.LateralGrip) or 1.085
            local grav = (rig and rig.Tune and rig.Tune.Gravity) or 60
            local safeLatAccel = State.GripPatch
                and math.clamp(104 * (State.CornerSafety / 1.00), 80, 140)
                or math.clamp(latGrip * grav * State.CornerSafety * 0.88, 56, 80)
            local decel = boostEngaged and 32 or 38
            local startIdx = sampleIndexAtS(samples, currentS)
            for i = startIdx, #samples do
                local distAhead = samples[i].s - currentS
                if distAhead > 260 then
                    break
                end
                local k = CachedCornerCurvatures[i]
                if k and k > 0.0005 then
                    local cornerCap = math.max(math.sqrt(safeLatAccel / k), effectiveFloor)
                    local brakeEnvelope = math.sqrt(cornerCap * cornerCap + 2 * decel * math.max(distAhead - 8, 0))
                    if brakeEnvelope < maxSpeed then
                        maxSpeed = math.max(brakeEnvelope, effectiveFloor)
                    end
                end
            end
        end

        -- Raceway Fault jump: NEVER lift before Lip; hold >= 122 to clear the 108-stud gap
        local raceway = WorldConfig and WorldConfig.Raceway
        local fault = type(raceway) == "table" and raceway.Fault
        local onFaultLaunch = type(fault) == "table" and type(fault.Foot) == "number"
            and currentS >= (fault.Foot - 150) and currentS <= ((fault.Lip or fault.Foot + 70) + 6)
        local overFaultGap = type(fault) == "table" and type(fault.Lip) == "number" and type(fault.Far) == "number"
            and currentS > (fault.Lip + 1) and currentS < (fault.Far + 4)

        if onFaultLaunch or overFaultGap then
            maxSpeed = math.max(maxSpeed, 124)
        elseif inSlalom and math.abs(latDelta) > 3.6 then
            maxSpeed = math.min(maxSpeed, 102)
        elseif math.abs(latDelta) > 6.5 then
            maxSpeed = math.min(maxSpeed, math.max(effectiveFloor, 94))
        end

        local listening, quietLimit = false, nil
        if State.AutoListener and not onFaultLaunch and not overFaultGap then
            listening, quietLimit = getListenerStealthLimit(getRunFolder())
            if listening and quietLimit then
                maxSpeed = math.min(maxSpeed, quietLimit)
            end
        end
        LastAutoMaxSpeed = maxSpeed

        local diff = speed - maxSpeed
        local throttle, brake = 0, 0
        if onFaultLaunch or overFaultGap then
            throttle = 1
            brake = 0
            local grounded = rig and rig.State and tonumber(rig.State.Grounded) or 4
            if overFaultGap and grounded == 0 then
                steer = steer * 0.25
            end
        elseif diff < -1.0 then
            throttle = 1
        elseif diff < 0 then
            throttle = math.clamp(-diff, 0.35, 1)
        elseif listening and diff > 0.6 then
            brake = math.clamp(diff / 5.0, 0.25, 1.0)
        elseif diff > 1.5 then
            brake = math.clamp((diff - 1.5) / 8.5, 0.14, 0.92)
        end

        return throttle, brake, steer, false
    end)
end

-- 10. Global Unloader & Handle
getgenv()._ICEDRAGON_LOADED = true
getgenv()._ICEDRAGON_UNLOAD = function()
    getgenv()._ICEDRAGON_LOADED = false
    getgenv()._ICEDRAGON = nil
    CurrentAimState.active = false
    CurrentCrankShield = false
    CurrentCrawlerDoorShield = false
    if lastDoorHoldSent then
        lastDoorHoldSent = false
        local doorHold = getRemote("DoorHold")
        if doorHold then
            pcall(function() doorHold:FireServer(false) end)
        end
    end

    for k, v in pairs(State) do
        if type(v) == "boolean" then
            State[k] = false
        end
    end

    if CarInput and type(CarInput.setOverride) == "function" then
        pcall(CarInput.setOverride, nil)
    end
    pcall(syncGripPatch, false)

    if ChassisMod and OriginalHooks.ChassisTumble then
        ChassisMod.Tumble = OriginalHooks.ChassisTumble
    end
    if CarController then
        for _, fnName in ipairs({ "stagger", "shove", "rock", "bump" }) do
            if OriginalHooks[fnName] then
                CarController[fnName] = OriginalHooks[fnName]
            end
        end
    end
    if FlashlightClient and OriginalHooks.FlashlightBeam then
        FlashlightClient.beam = OriginalHooks.FlashlightBeam
    end
    if CarInput and OriginalHooks.CarInputRead then
        CarInput.Read = OriginalHooks.CarInputRead
        OriginalHooks.CarInputRead = nil
    end
    smoothDesiredLat = 0
    if OriginalHooks.Namecall and type(hookmetamethod) == "function" then
        pcall(hookmetamethod, game, "__namecall", OriginalHooks.Namecall)
        OriginalHooks.Namecall = nil
    end

    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)

    for _, line in ipairs(DrawingLines) do
        pcall(function() line:Remove() end)
    end
    table.clear(DrawingLines)

    for _, hl in ipairs(ActiveHighlights) do
        pcall(function() hl:Destroy() end)
    end
    table.clear(ActiveHighlights)

    pcall(function()
        Lighting.FogEnd = OriginalLighting.FogEnd
        Lighting.FogStart = OriginalLighting.FogStart
        if AtmosphereInst and OriginalLighting.AtmosphereDensity ~= nil then
            AtmosphereInst.Density = OriginalLighting.AtmosphereDensity
        end
        restoreFullBrightDefaults()
        RunService:Set3dRenderingEnabled(true)
    end)

    pcall(function()
        if Window and type(Window.Destroy) == "function" then
            Window:Destroy()
        end
    end)
end

-- 11. Tabs Setup
local UIControls = {}
local function activateHardModePreset(enableAutoDrive)
    if UIControls.GripPatch then UIControls.GripPatch:Set(true) end
    if UIControls.AntiTumble then UIControls.AntiTumble:Set(true) end
    if UIControls.AntiStagger then UIControls.AntiStagger:Set(true) end
    if UIControls.PaceAssist then UIControls.PaceAssist:Set(true) end
    if UIControls.AmbushDodge then UIControls.AmbushDodge:Set(true) end
    if UIControls.AutoCrank then UIControls.AutoCrank:Set(true) end
    if UIControls.AutoIntruder then UIControls.AutoIntruder:Set(true) end
    if UIControls.AutoCrawler then UIControls.AutoCrawler:Set(true) end
    if UIControls.AutoListener then UIControls.AutoListener:Set(true) end
    if UIControls.AmbushAlert then UIControls.AmbushAlert:Set(true) end
    if UIControls.AntiJumpscare then UIControls.AntiJumpscare:Set(true) end
    if UIControls.FullBright then UIControls.FullBright:Set(true) end
    if UIControls.MonsterHighlight then UIControls.MonsterHighlight:Set(true) end
    if enableAutoDrive and UIControls.AutoDrive then
        UIControls.AutoDrive:Set(true)
    end
    WindUI:Notify({
        Title = "Map 3+ Hard Preset Active",
        Content = "Grip, Anti-Tumble/Stagger, PaceGuard, Auto-Crank, Intruder, Crawler & Listener enabled!",
        Duration = 4,
    })
end

local Tabs = {
    Drive = Window:Tab({ Title = "Drive & Tune", Icon = "car" }),
    Survival = Window:Tab({ Title = "Survival", Icon = "shield-alert" }),
    Visuals = Window:Tab({ Title = "ESP & Visuals", Icon = "eye" }),
    Lobby = Window:Tab({ Title = "Lobby & Shop", Icon = "shopping-bag" }),
    AFK = Window:Tab({ Title = "AFK & Safety", Icon = "cpu" }),
    Support = Window:Tab({ Title = "Support", Icon = "heart" }),
}

-- ============================================================================
-- TAB 1: DRIVE & TUNE
-- ============================================================================
Tabs.Drive:Section({ Title = "Map 3+ Hard Quick Setup" })

Tabs.Drive:Button({
    Title = "Activate Map 3+ Hard Full Survival (+ Auto-Drive)",
    Desc = "Enables GripPatch, Anti-Tumble/Stagger, PaceAssist, Auto-Crank/Intruder/Crawler/Listener, FullBright & Auto-Drive.",
    Callback = function()
        activateHardModePreset(true)
    end,
})

Tabs.Drive:Section({ Title = "Cross-Map Auto-Drive (CarInput Seam)" })

UIControls.AutoDrive = Tabs.Drive:Toggle({
    Title = "Auto-Drive (RoadPath + TouchAssist)",
    Desc = "Curvature-adaptive Pure-Pursuit & Tournament slalom/jump solver across Route1610 - Map09, Tournament & Endless.",
    Value = false,
    Callback = function(v)
        State.AutoDrive = v
        syncAutoDriveOverride()
    end,
})

Tabs.Drive:Slider({
    Title = "Lookahead Distance (Studs)",
    Step = 1,
    Value = { Min = 30, Max = 110, Default = State.LookaheadStuds },
    Callback = function(v)
        State.LookaheadStuds = tonumber(v) or 56
    end,
})

Tabs.Drive:Slider({
    Title = "Cruise Speed Cap (Safe < 120 Avg)",
    Desc = "Config.Run.RecordTopAverage = 120 | RecordBanAverage = 140.",
    Step = 1,
    Value = { Min = 50, Max = 135, Default = State.MaxCruiseSpeed },
    Callback = function(v)
        State.MaxCruiseSpeed = tonumber(v) or 116
    end,
})

Tabs.Drive:Slider({
    Title = "Min Corner Speed Floor",
    Desc = "Map 3 Runner runs 92-95 studs/s on Fields/Forest; keep >= 94 to avoid catches.",
    Step = 1,
    Value = { Min = 70, Max = 112, Default = State.MinCornerSpeed },
    Callback = function(v)
        State.MinCornerSpeed = tonumber(v) or 95
    end,
})

Tabs.Drive:Slider({
    Title = "Cornering Aggression (Safe LatAccel)",
    Step = 0.05,
    Value = { Min = 0.75, Max = 1.35, Default = State.CornerSafety },
    Callback = function(v)
        State.CornerSafety = tonumber(v) or 1.00
    end,
})

UIControls.AmbushDodge = Tabs.Drive:Toggle({
    Title = "Dodge Obstacles / Wrecks / Crates",
    Value = true,
    Callback = function(v)
        State.AmbushDodge = v
    end,
})

UIControls.PaceAssist = Tabs.Drive:Toggle({
    Title = "Pace Assist (Prevent Uphill / Frost Slowdowns)",
    Desc = "Maintains >= 97 studs/s (105 when Runner close) safely within SpeedWatch.",
    Value = State.PaceAssist,
    Callback = function(v)
        State.PaceAssist = v
    end,
})

Tabs.Drive:Section({ Title = "Speed Booster & Nitro" })

UIControls.SpeedBoost = Tabs.Drive:Toggle({
    Title = "Speed Booster (Engine + Velocity Boost)",
    Desc = "Boosts Engine.Force, reduces Drag.Air, and accelerates to Boost Target Speed (yields for Listener).",
    Value = false,
    Callback = function(v)
        State.SpeedBoost = v
        pcall(syncTuneOverlay)
    end,
})

UIControls.BoostHoldKey = Tabs.Drive:Toggle({
    Title = "Hold LeftShift Only (Nitro Key Mode)",
    Desc = "When ON, Speed Booster only fires while holding LeftShift (ideal for bursts > 140).",
    Value = State.BoostHoldKey,
    Callback = function(v)
        State.BoostHoldKey = v
        pcall(syncTuneOverlay)
    end,
})

Tabs.Drive:Slider({
    Title = "Boost Target Speed (studs/s)",
    Desc = "Safe <= 136 (SpeedWatch Allow 1.2x ~140). Higher values work best for <= 4s Nitro bursts.",
    Step = 1,
    Value = { Min = 120, Max = 180, Default = State.BoostTargetSpeed },
    Callback = function(v)
        State.BoostTargetSpeed = tonumber(v) or 134
        pcall(syncTuneOverlay)
    end,
})

UIControls.BoostCornerTrim = Tabs.Drive:Toggle({
    Title = "Auto-Trim Boost in Tight Corners",
    Desc = "Auto-Drive still slows cleanly for R=85 hairpins while blasting straights at Boost Target Speed.",
    Value = State.BoostCornerTrim,
    Callback = function(v)
        State.BoostCornerTrim = v
    end,
})

Tabs.Drive:Section({ Title = "Chassis & Grip Tuning" })

UIControls.GripPatch = Tabs.Drive:Toggle({
    Title = "Surface Grip + Anti-DriftSnap Patch",
    Desc = "Fixes Hard-map Gravel/Frost grip and disables DriftAssist opposite-lock spinouts.",
    Value = false,
    Callback = function(v)
        State.GripPatch = v
        pcall(syncGripPatch, v)
    end,
})

UIControls.AntiTumble = Tabs.Drive:Toggle({
    Title = "Anti-Tumble (Chassis.Tumble Bypass)",
    Value = false,
    Callback = function(v)
        State.AntiTumble = v
        applyCarHooks()
    end,
})

UIControls.AntiStagger = Tabs.Drive:Toggle({
    Title = "Anti-Stagger / Shove / Rock / Bump",
    Value = false,
    Callback = function(v)
        State.AntiStagger = v
        applyCarHooks()
    end,
})

Tabs.Drive:Button({
    Title = "Instant Snap Back to Road Center",
    Desc = "Re-centers Chassis onto nearest RoadPath point without 3s cooldown.",
    Callback = function()
        local chassis = getMyChassis()
        local road = select(1, getActiveRoad())
        if not (chassis and road and RoadPath) then
            WindUI:Notify({ Title = "Snap Road", Content = "Not in an active run.", Duration = 3 })
            return
        end
        local s = RoadPath.project(road, chassis.Position.X, chassis.Position.Z)
        local x, y, z, fx, fz = RoadPath.pointAt(road, s, 0)
        local pos = Vector3.new(x, y + 3.5, z)
        local look = pos + Vector3.new(fx, 0, fz)
        chassis.AssemblyLinearVelocity = Vector3.zero
        chassis.AssemblyAngularVelocity = Vector3.zero
        chassis.CFrame = CFrame.lookAt(pos, look)
    end,
})

-- ============================================================================
-- TAB 2: SURVIVAL & DEFENSE
-- ============================================================================
Tabs.Survival:Section({ Title = "Monster Countermeasures (Solo & Duo)" })

Tabs.Survival:Button({
    Title = "Enable All Survival Defenses (Manual Drive Mode)",
    Desc = "Enables GripPatch, Anti-Tumble/Stagger, Auto-Crank, Intruder, Crawler, Listener, PaceAssist & FullBright.",
    Callback = function()
        activateHardModePreset(false)
    end,
})

UIControls.AutoCrank = Tabs.Survival:Toggle({
    Title = "Auto-Crank Knocker Shutter",
    Desc = "Automatically cranks & locks shutter closed during KnockerPhase Warn/Bang.",
    Value = false,
    Callback = function(v)
        State.AutoCrank = v
        applyCarHooks()
    end,
})

UIControls.AutoIntruder = Tabs.Survival:Toggle({
    Title = "Auto-Burn Intruder (Backseat Lock + FlashAim)",
    Desc = "Blocks native Flashlight cancels and locks FlashAim onto Intruder until fled.",
    Value = false,
    Callback = function(v)
        State.AutoIntruder = v
        applyCarHooks()
    end,
})

UIControls.AutoCrawler = Tabs.Survival:Toggle({
    Title = "Auto-Defend Crawler (Map 3+ Anti-Hit + Door QTE)",
    Desc = "Drops CrawlerHit contact reports and auto-completes DoorKey QTE / DoorHold during Pull.",
    Value = false,
    Callback = function(v)
        State.AutoCrawler = v
        applyCarHooks()
    end,
})

UIControls.AutoListener = Tabs.Survival:Toggle({
    Title = "Auto-Stealth The Listener (Update 2 | <= 048 Noise)",
    Desc = "Caps Manual & Auto-Drive under Listener.Quiet (048), yields SpeedBoost, and dodges crossing Listener.",
    Value = false,
    Callback = function(v)
        State.AutoListener = v
        applyCarHooks()
        pcall(syncTuneOverlay)
    end,
})

UIControls.AmbushAlert = Tabs.Survival:Toggle({
    Title = "Ambush Early Warning Notification",
    Value = false,
    Callback = function(v)
        State.AmbushAlert = v
    end,
})

-- ============================================================================
-- TAB 3: ESP & VISUALS
-- ============================================================================
Tabs.Visuals:Section({ Title = "Road & Threat Visuals" })

local TelemetryPara = Tabs.Visuals:Paragraph({
    Title = "Live Run Telemetry",
    Desc = "Waiting for active run...",
})

Tabs.Visuals:Toggle({
    Title = "Road Centerline Ribbon (Drawing Overlay)",
    Desc = "Projects upcoming RoadPath centerline through heavy fog.",
    Value = false,
    Callback = function(v)
        State.RoadRibbon = v
        if not v then
            for _, line in ipairs(DrawingLines) do
                pcall(function() line.Visible = false end)
            end
        end
    end,
})

UIControls.MonsterHighlight = Tabs.Visuals:Toggle({
    Title = "Monster Highlight ESP (All ClientMonsters)",
    Desc = "Highlights Runner, Ambusher, and any Update 2 ClientMonsters.",
    Value = false,
    Callback = function(v)
        State.MonsterHighlight = v
        if not v then
            for _, hl in ipairs(ActiveHighlights) do
                pcall(function() hl:Destroy() end)
            end
            table.clear(ActiveHighlights)
        end
    end,
})

Tabs.Visuals:Toggle({
    Title = "Clear Fog & Atmosphere",
    Value = false,
    Callback = function(v)
        State.ClearFog = v
        local atm = AtmosphereInst or Lighting:FindFirstChildOfClass("Atmosphere")
        if v then
            OriginalLighting.FogEnd = Lighting.FogEnd
            OriginalLighting.FogStart = Lighting.FogStart
            if atm then
                AtmosphereInst = atm
                OriginalLighting.AtmosphereDensity = atm.Density
            end
        else
            Lighting.FogEnd = OriginalLighting.FogEnd
            Lighting.FogStart = OriginalLighting.FogStart
            if atm and OriginalLighting.AtmosphereDensity ~= nil then
                atm.Density = OriginalLighting.AtmosphereDensity
            end
        end
    end,
})

UIControls.FullBright = Tabs.Visuals:Toggle({
    Title = "FullBright (No Darkness / Shadows)",
    Desc = "Locks bright midday lighting, ambient, and exposure while restoring originals on off/unload.",
    Value = false,
    Callback = function(v)
        State.FullBright = v
        if v then
            captureFullBrightDefaults()
            applyFullBrightProperties()
        else
            restoreFullBrightDefaults()
        end
    end,
})

UIControls.AntiJumpscare = Tabs.Visuals:Toggle({
    Title = "Anti-Jumpscare & Gloom Overlay Cleaner",
    Value = false,
    Callback = function(v)
        State.AntiJumpscare = v
    end,
})

-- ============================================================================
-- TAB 4: LOBBY & SHOP
-- ============================================================================
Tabs.Lobby:Section({ Title = "Promo Codes & Garage RPC" })

Tabs.Lobby:Button({
    Title = "Redeem All 4 Active Codes (850 Credits)",
    Desc = "RELEASE (250), DONOTSTOP (200), ROUTE1610 (150), LASTSTOP (250) [Lobby Only]",
    Callback = function()
        if MapConfig and not MapConfig.IsLobby then
            WindUI:Notify({ Title = "Lobby Only", Content = "Garage & Code RPCs only run in Lobby.", Duration = 3 })
            return
        end
        local garageRemote = getRemote("Garage")
        if not garageRemote then
            WindUI:Notify({ Title = "Garage RPC", Content = "Garage RemoteFunction not found.", Duration = 3 })
            return
        end
        task.spawn(function()
            local codes = {}
            if CodesConfig and type(CodesConfig.List) == "table" then
                for _, entry in ipairs(CodesConfig.List) do
                    table.insert(codes, entry.Code)
                end
            else
                codes = { "RELEASE", "DONOTSTOP", "ROUTE1610", "LASTSTOP" }
            end
            local gap = (CodesConfig and CodesConfig.Gap) or 2
            local redeemed = 0
            for _, code in ipairs(codes) do
                local ok, res = pcall(function()
                    return garageRemote:InvokeServer("redeem", code)
                end)
                if ok and type(res) == "table" and res.ok then
                    redeemed = redeemed + 1
                end
                task.wait(gap + 0.15)
            end
            WindUI:Notify({
                Title = "Codes Complete",
                Content = string.format("Processed %d codes (%d newly redeemed).", #codes, redeemed),
                Duration = 4,
            })
        end)
    end,
})

Tabs.Lobby:Button({
    Title = "Auto-Open Available Free Crates",
    Desc = "Queries Garage('state') and opens owned crates [Lobby Only].",
    Callback = function()
        if MapConfig and not MapConfig.IsLobby then
            WindUI:Notify({ Title = "Lobby Only", Content = "Garage Crate RPC only runs in Lobby.", Duration = 3 })
            return
        end
        local garageRemote = getRemote("Garage")
        if not garageRemote then
            return
        end
        task.spawn(function()
            local ok, stateRes = pcall(function()
                return garageRemote:InvokeServer("state")
            end)
            if not (ok and type(stateRes) == "table" and type(stateRes.crates) == "table") then
                WindUI:Notify({ Title = "Crates", Content = "No crate inventory returned.", Duration = 3 })
                return
            end
            local opened = 0
            for crateId, count in pairs(stateRes.crates) do
                if type(count) == "number" and count > 0 then
                    for _ = 1, count do
                        local okOpen, openRes = pcall(function()
                            return garageRemote:InvokeServer("open", crateId)
                        end)
                        if okOpen and type(openRes) == "table" and openRes.ok then
                            opened = opened + 1
                        end
                        task.wait(1.1)
                    end
                end
            end
            WindUI:Notify({ Title = "Crates", Content = "Opened " .. tostring(opened) .. " crates.", Duration = 3 })
        end)
    end,
})

Tabs.Lobby:Section({ Title = "Lobby QoL & Map Launcher" })

Tabs.Lobby:Toggle({
    Title = "Lobby WalkSpeed Boost",
    Desc = "Overrides slow default WalkSpeed (7) in Lobby.",
    Value = false,
    Callback = function(v)
        State.LobbyWalkSpeedEnabled = v
    end,
})

Tabs.Lobby:Slider({
    Title = "WalkSpeed Value",
    Step = 1,
    Value = { Min = 7, Max = 60, Default = State.LobbyWalkSpeed },
    Callback = function(v)
        State.LobbyWalkSpeed = tonumber(v) or 24
    end,
})

Tabs.Lobby:Dropdown({
    Title = "Target Map",
    Values = { "Route1610", "Map02", "Map03", "Map04", "Map05", "Map06", "Map07", "Endless" },
    Value = "Route1610",
    Callback = function(v)
        State.SelectedMap = v
    end,
})

Tabs.Lobby:Button({
    Title = "Send MapPick / StartRun",
    Callback = function()
        local mapPick = getRemote("MapPick")
        local startRun = getRemote("StartRun")
        if mapPick then
            pcall(function() mapPick:FireServer(State.SelectedMap) end)
        end
        if startRun then
            pcall(function() startRun:FireServer() end)
        end
    end,
})

Tabs.Lobby:Section({ Title = "Direct Place Teleport (Update 2 Places)" })

local UPDATE2_PLACES = {
    { Label = "Teleport -> Main Lobby (Update 2)", PlaceId = 116779912472448 },
    { Label = "Teleport -> Calliope Road (Very Hard)", PlaceId = 104171809510415 },
    { Label = "Teleport -> Serpent River Road (Extreme)", PlaceId = 117653142673937 },
}

for _, tpInfo in ipairs(UPDATE2_PLACES) do
    Tabs.Lobby:Button({
        Title = tpInfo.Label,
        Desc = "PlaceId: " .. tostring(tpInfo.PlaceId),
        Callback = function()
            local ok, err = pcall(function()
                TeleportService:Teleport(tpInfo.PlaceId, LocalPlayer)
            end)
            if not ok then
                WindUI:Notify({
                    Title = "Teleport Blocked",
                    Content = "Client teleport denied (" .. tostring(err) .. "). Join via Lobby UI instead.",
                    Duration = 4,
                })
            end
        end,
    })
end

-- ============================================================================
-- TAB 5: AFK & SAFETY
-- ============================================================================
Tabs.AFK:Section({ Title = "AFK Stability & Performance" })

Tabs.AFK:Toggle({
    Title = "Anti-AFK (VirtualUser Idled Guard)",
    Value = true,
    Callback = function(v)
        State.AntiAFK = v
    end,
})

Tabs.AFK:Toggle({
    Title = "Disable 3D Rendering (GPU Saver)",
    Value = false,
    Callback = function(v)
        State.Disable3DRender = v
        pcall(function()
            RunService:Set3dRenderingEnabled(not v)
        end)
    end,
})

Tabs.AFK:Toggle({
    Title = "Auto-Vote Retry / Next on Caught or Finish",
    Value = false,
    Callback = function(v)
        State.AutoVoteRetry = v
    end,
})

Tabs.AFK:Button({
    Title = "Unload ICEDRAGON Suite",
    Callback = function()
        if type(getgenv()._ICEDRAGON_UNLOAD) == "function" then
            getgenv()._ICEDRAGON_UNLOAD()
        end
    end,
})

-- ============================================================================
-- TAB 6: SUPPORT (ICEDRAGON TEMPLATE)
-- ============================================================================
Tabs.Support:Section({ Title = "IceDragon Official Community", TextSize = 18 })
Tabs.Support:Divider()

Tabs.Support:Paragraph({
    Title = "Developer & Brand Credits",
    Desc = "DO NOT STOP | ICEDRAGON Script\nCrafted with verified Luau reverse engineering.\nDo not forget to support, like, and subscribe on YouTube!",
})

Tabs.Support:Button({
    Title = "Copy YouTube Channel Link",
    Desc = YOUTUBE_URL,
    Callback = function()
        copyToClipboard(YOUTUBE_URL)
        WindUI:Notify({ Title = "Copied!", Content = YOUTUBE_URL, Duration = 4 })
    end,
})

Tabs.Support:Button({
    Title = "Copy Support / Subscribe Template",
    Desc = SUBSCRIBE_TEMPLATE,
    Callback = function()
        copyToClipboard(SUBSCRIBE_TEMPLATE)
        WindUI:Notify({ Title = "Copied!", Content = "Support & like template copied!", Duration = 4 })
    end,
})

Tabs.Support:Button({
    Title = "Copy Discord Server Invite",
    Desc = DISCORD_URL,
    Callback = function()
        copyToClipboard(DISCORD_URL)
        WindUI:Notify({ Title = "Copied!", Content = DISCORD_URL, Duration = 4 })
    end,
})

Tabs.Support:Slider({
    Title = "UI Transparency",
    Value = { Min = 0.0, Max = 1.0, Default = 0.7 },
    Step = 0.05,
    Callback = function(val)
        pcall(function()
            WindUI.TransparencyValue = tonumber(val)
        end)
    end,
})

-- ============================================================================
-- 12. BACKGROUND LOOPS & WATCHERS
-- ============================================================================
trackConn(LocalPlayer.Idled:Connect(function()
    if getgenv()._ICEDRAGON_LOADED and State.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

local lastCrankSent = false
local lastCrankPhase = ""
local lastCrankPulseAt = 0
local lastFlashSent = 0
local lastFlashOnSent = false
local lastDoorHoldAt = 0
local lastCrawlerQteId = 0
local lastCrawlerQteAt = 0
local lastHeartbeatAt = os.clock()
local lastAmbushWarned = 0
local lastListenerWarned = false
local lastVoteSent = 0
local lastTelemetryUpdate = 0

trackConn(RunService.Heartbeat:Connect(function()
    if not getgenv()._ICEDRAGON_LOADED then
        return
    end

    local now = os.clock()
    local dt = math.clamp(now - lastHeartbeatAt, 0.001, 0.1)
    lastHeartbeatAt = now

    -- Lobby WalkSpeed QoL (never fight seated driving state)
    if State.LobbyWalkSpeedEnabled and MapConfig and MapConfig.IsLobby then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= State.LobbyWalkSpeed then
            hum.WalkSpeed = State.LobbyWalkSpeed
        end
    end

    -- Anti-Jumpscare / Gloom Overlay
    if State.AntiJumpscare then
        local jumpscareGui = PlayerGui:FindFirstChild("Jumpscare")
        if jumpscareGui and jumpscareGui.Enabled then
            jumpscareGui.Enabled = false
        end
        local intruderFlash = PlayerGui:FindFirstChild("IntruderFlash")
        if intruderFlash and intruderFlash.Enabled then
            intruderFlash.Enabled = false
        end
        local scareGrade = Lighting:FindFirstChild("ScareGrade")
        if scareGrade and scareGrade:IsA("ColorCorrectionEffect") and scareGrade.Enabled then
            scareGrade.Enabled = false
        end
    end

    -- Maintain Anti-Tumble & Grip Patch across zone changes
    if State.AntiTumble then
        local rig = getRig()
        if rig and rig.TumbleUntil and rig.TumbleUntil > now then
            rig.TumbleUntil = 0
        end
    end
    if State.GripPatch or State.SpeedBoost then
        pcall(syncTuneOverlay, false)
    end

    local runFolder = getRunFolder()
    if runFolder then
        local runState = runFolder:GetAttribute("State")
        local listening, quietLimit, lPhase = false, nil, ""
        if State.AutoListener and runState == "Driving" then
            listening, quietLimit, lPhase = getListenerStealthLimit(runFolder)
            if listening and not lastListenerWarned then
                lastListenerWarned = true
                WindUI:Notify({
                    Title = "LISTENER STEALTH ACTIVE",
                    Content = string.format("Phase: %s | Holding speed <= %.0f (Quiet)", lPhase, quietLimit),
                    Duration = 3,
                })
            elseif not listening then
                lastListenerWarned = false
            end

            -- Smoothly clamp excess speed below Listener.Quiet so both Manual & Auto-Drive stay silent
            if listening and quietLimit then
                local chassis = getMyChassis()
                if chassis and not chassis.Anchored then
                    local vel = chassis.AssemblyLinearVelocity
                    local horiz = Vector3.new(vel.X, 0, vel.Z)
                    local hSpd = horiz.Magnitude
                    if hSpd > quietLimit + 0.35 then
                        local drop = math.min(hSpd - (quietLimit - 0.5), math.max(98 * dt, 1.5))
                        local newSpd = math.max(hSpd - drop, quietLimit - 0.5)
                        local dir = horiz.Unit
                        chassis.AssemblyLinearVelocity = Vector3.new(dir.X * newSpd, vel.Y, dir.Z * newSpd)
                    end
                end
            end
        else
            lastListenerWarned = false
        end

        -- Speed Booster (Engine + Smooth Velocity Thrust, automatically suppressed during Listener Stealth)
        local boostNow = isBoostActiveNow()
        if boostNow and runState == "Driving" and not listening then
            local chassis = getMyChassis()
            local rig = getRig()
            if chassis and not chassis.Anchored and rig and rig.State then
                local rState = rig.State
                local grounded = (type(rState.Grounded) == "number") and rState.Grounded or 0
                local brakeAmt = (type(rState.Brake) == "number") and rState.Brake or 0
                local thrAmt = (type(rState.Throttle) == "number") and rState.Throttle or 0
                if grounded >= 2 and brakeAmt <= 0.1 and not rState.Handbrake and (thrAmt > 0.05 or (State.BoostHoldKey and isNitroKeyHeld())) then
                    local boostDir
                    local boostTarget = State.BoostTargetSpeed
                    local road = select(1, getActiveRoad())
                    if State.AutoDrive and road and RoadPath then
                        local curS, curLat = RoadPath.project(road, chassis.Position.X, chassis.Position.Z)
                        if State.BoostCornerTrim then
                            boostTarget = math.min(boostTarget, LastAutoMaxSpeed)
                        end
                        local allowBoostLine = (not State.BoostCornerTrim) or (LastAutoMaxSpeed >= math.min(State.BoostTargetSpeed - 6, 124))
                        if allowBoostLine and math.abs(rig.SteerInput or 0) <= 0.42 and math.abs(curLat or 0) <= 7.0 and math.abs(LastAutoLatDelta) <= 7.0 then
                            local _, _, _, rfx, rfz = RoadPath.pointAt(road, curS, 0)
                            local rfDir = Vector3.new(rfx, 0, rfz)
                            if rfDir.Magnitude > 0.01 then
                                boostDir = rfDir.Unit
                            end
                        end
                    else
                        local lv = chassis.CFrame.LookVector
                        local flatFwd = Vector3.new(lv.X, 0, lv.Z)
                        if flatFwd.Magnitude > 0.05 then
                            boostDir = flatFwd.Unit
                        end
                    end

                    if boostDir then
                        local vel = chassis.AssemblyLinearVelocity
                        local fwdSpeed = vel.X * boostDir.X + vel.Z * boostDir.Z
                        if fwdSpeed >= 5 and fwdSpeed < boostTarget then
                            local boostAlpha = math.clamp(dt * 4.8, 0, 0.38)
                            local add = math.min((boostTarget - fwdSpeed) * boostAlpha, math.max(76 * dt, 0.7))
                            chassis.AssemblyLinearVelocity = Vector3.new(
                                vel.X + boostDir.X * add,
                                vel.Y,
                                vel.Z + boostDir.Z * add
                            )
                        end
                    end
                end
            end
        end

        -- Pace Assist (prevents uphill / Frost / corner bog-downs under Runner speed; yields to Listener Stealth)
        if State.PaceAssist and not listening and not boostNow and runState == "Driving" then
            local chassis = getMyChassis()
            local rig = getRig()
            local road = select(1, getActiveRoad())
            if chassis and not chassis.Anchored and rig and rig.State and road and RoadPath then
                local rState = rig.State
                local grounded = (type(rState.Grounded) == "number") and rState.Grounded or 0
                local brakeAmt = (type(rState.Brake) == "number") and rState.Brake or 0
                if grounded >= 2 and brakeAmt <= 0.1 and not rState.Handbrake and math.abs(rig.SteerInput or 0) <= 0.35 then
                    local pos = chassis.Position
                    local vel = chassis.AssemblyLinearVelocity
                    local curS, curLat = RoadPath.project(road, pos.X, pos.Z)
                    local _, _, _, rfx, rfz = RoadPath.pointAt(road, curS, 0)
                    local fwdDir = Vector3.new(rfx, 0, rfz)
                    if fwdDir.Magnitude > 0.01 and math.abs(curLat or 0) <= 6.0 and (not State.AutoDrive or math.abs(LastAutoLatDelta) <= 6.0) then
                        fwdDir = fwdDir.Unit
                        local fwdSpeed = vel.X * fwdDir.X + vel.Z * fwdDir.Z
                        if fwdSpeed > 14 then
                            local rActive = runFolder:GetAttribute("RunnerActive") == true
                            local carS = runFolder:GetAttribute("CarS") or curS
                            local runnerS = runFolder:GetAttribute("RunnerS") or -9999
                            local gap = carS - runnerS
                            local fault = WorldConfig and WorldConfig.Raceway and WorldConfig.Raceway.Fault
                            local onFaultApproach = type(fault) == "table" and type(fault.Foot) == "number"
                                and curS >= (fault.Foot - 150) and curS <= ((fault.Lip or fault.Foot + 70) + 6)
                            local speedCap = State.AutoDrive and LastAutoMaxSpeed or State.MaxCruiseSpeed
                            local desiredFloor = onFaultApproach
                                and math.max(124, speedCap)
                                or math.min(((rActive and gap < 85) and 105 or math.max(State.MinCornerSpeed + 2, 97)), math.min(speedCap, 114))
                            if fwdSpeed < desiredFloor then
                                local boostAlpha = math.clamp(dt * 4.5, 0, 0.35)
                                local add = math.min((desiredFloor - fwdSpeed) * boostAlpha, math.max(58 * dt, 0.6))
                                chassis.AssemblyLinearVelocity = Vector3.new(
                                    vel.X + fwdDir.X * add,
                                    vel.Y,
                                    vel.Z + fwdDir.Z * add
                                )
                            end
                        end
                    end
                end
            end
        end

        -- Auto-Crank Knocker (with Warn->Bang re-arm & open-shutter watchdog)
        if State.AutoCrank then
            local phase = runFolder:GetAttribute("KnockerPhase")
            local cranker = runFolder:GetAttribute("KnockerCranker")
            local kOpen = runFolder:GetAttribute("KnockerOpen")
            local isMyCrank = (cranker == nil or cranker == 0 or cranker == LocalPlayer.UserId)
            local shouldCrank = (phase == "Warn" or phase == "Bang") and isMyCrank and (kOpen == nil or kOpen > 0.01 or phase == "Warn")
            CurrentCrankShield = shouldCrank
            local crankRemote = getRemote("Crank")
            if crankRemote then
                local needPulse = shouldCrank and (
                    not lastCrankSent
                    or phase ~= lastCrankPhase
                    or (phase == "Bang" and (kOpen == nil or kOpen > 0.05) and (now - lastCrankPulseAt >= 0.32))
                )
                if needPulse then
                    lastCrankSent = true
                    lastCrankPhase = phase or ""
                    lastCrankPulseAt = now
                    pcall(function() crankRemote:FireServer(true) end)
                elseif not shouldCrank and lastCrankSent then
                    lastCrankSent = false
                    lastCrankPhase = phase or ""
                    pcall(function() crankRemote:FireServer(false) end)
                end
            end
        else
            CurrentCrankShield = false
            if lastCrankSent then
                lastCrankSent = false
                local crankRemote = getRemote("Crank")
                if crankRemote then
                    pcall(function() crankRemote:FireServer(false) end)
                end
            end
        end

        -- Auto-Burn Intruder (back-seat Stand coordinates + anti-cancel lock)
        if State.AutoIntruder then
            local phase = runFolder:GetAttribute("IntruderPhase")
            local burn = runFolder:GetAttribute("IntruderBurn") or 0
            local spot = runFolder:GetAttribute("IntruderSpot")
            local isTargetPhase = (phase == "Sit" or phase == "Leave") and burn < 1
            if isTargetPhase then
                local chassis = getMyChassis()
                local aimRemote = getRemote("FlashAim")
                local flashRemote = getRemote("Flashlight")
                if chassis then
                    local spotOffset = (IntruderConfig and IntruderConfig.Spots and type(spot) == "number" and IntruderConfig.Spots[spot]) or 0
                    local standTbl = IntruderConfig and IntruderConfig.Stand
                    local standZ = (type(standTbl) == "table" and tonumber(standTbl[3])) or 3.42
                    local targetPos = (IntruderClient and IntruderClient.active and typeof(IntruderClient.face) == "Vector3")
                        and IntruderClient.face
                        or chassis.CFrame:PointToWorldSpace(Vector3.new(spotOffset, 1.35, standZ))
                    local origin = chassis.CFrame:PointToWorldSpace(Vector3.new(0, 1.75, 0.4))
                    local dir = targetPos - origin
                    if dir.Magnitude > 0.01 then
                        local localDir = chassis.CFrame:VectorToObjectSpace(dir.Unit)
                        local yawDeg = math.floor(math.deg(math.atan2(-localDir.X, -localDir.Z)) + 0.5)
                        local pitchDeg = math.floor(math.deg(math.asin(math.clamp(localDir.Y, -1, 1))) + 0.5)
                        CurrentAimState.active = true
                        CurrentAimState.yaw = yawDeg
                        CurrentAimState.pitch = pitchDeg
                        if FlashlightClient then
                            pcall(function()
                                FlashlightClient.lit = true
                                if type(FlashlightClient.set) == "function" then
                                    FlashlightClient.set(true)
                                end
                            end)
                        end
                        if flashRemote and (runFolder:GetAttribute("FlashlightOn") ~= true or not lastFlashOnSent) then
                            lastFlashOnSent = true
                            pcall(function() flashRemote:FireServer(true) end)
                        end
                        if aimRemote and now - lastFlashSent >= 0.105 then
                            lastFlashSent = now
                            pcall(function() aimRemote:FireServer(yawDeg, pitchDeg, true) end)
                        end
                    end
                end
            else
                CurrentAimState.active = false
                if lastFlashOnSent then
                    lastFlashOnSent = false
                    local flashRemote = getRemote("Flashlight")
                    if flashRemote then
                        pcall(function() flashRemote:FireServer(false) end)
                    end
                end
            end
        else
            CurrentAimState.active = false
            if lastFlashOnSent then
                lastFlashOnSent = false
                local flashRemote = getRemote("Flashlight")
                if flashRemote then
                    pcall(function() flashRemote:FireServer(false) end)
                end
            end
        end

        -- Auto-Defend Crawler (Map03+: DoorKey QTE instant clear + DoorHold lock)
        if State.AutoCrawler then
            local cPhase = runFolder:GetAttribute("CrawlerPhase")
            local cHolder = runFolder:GetAttribute("CrawlerHolder")
            local cOpen = runFolder:GetAttribute("CrawlerOpen") or 0
            local cQteOn = runFolder:GetAttribute("CrawlerQteOn") == true
            local isMyDoor = (cHolder == nil or cHolder == 0 or cHolder == LocalPlayer.UserId)
            if cPhase == "Pull" and isMyDoor then
                if cQteOn then
                    CurrentCrawlerDoorShield = false
                    if lastDoorHoldSent then
                        lastDoorHoldSent = false
                        local doorHold = getRemote("DoorHold")
                        if doorHold then
                            pcall(function() doorHold:FireServer(false) end)
                        end
                    end
                    local qteId = runFolder:GetAttribute("CrawlerQte")
                    local qteKey = runFolder:GetAttribute("CrawlerQteKey")
                    if type(qteId) == "number" and qteId ~= 0 and type(qteKey) == "number" and qteKey > 0 and (qteId ~= lastCrawlerQteId or now - lastCrawlerQteAt >= 0.35) then
                        local doorKey = getRemote("DoorKey")
                        if doorKey then
                            lastCrawlerQteId = qteId
                            lastCrawlerQteAt = now
                            pcall(function() doorKey:FireServer(qteId, true) end)
                        end
                    end
                else
                    CurrentCrawlerDoorShield = true
                    local doorHold = getRemote("DoorHold")
                    if doorHold and (not lastDoorHoldSent or (cOpen > 0.02 and now - lastDoorHoldAt >= 0.35)) then
                        lastDoorHoldSent = true
                        lastDoorHoldAt = now
                        pcall(function() doorHold:FireServer(true) end)
                    end
                end
            else
                CurrentCrawlerDoorShield = false
                lastCrawlerQteId = 0
                if lastDoorHoldSent then
                    lastDoorHoldSent = false
                    local doorHold = getRemote("DoorHold")
                    if doorHold then
                        pcall(function() doorHold:FireServer(false) end)
                    end
                end
            end
        else
            CurrentCrawlerDoorShield = false
            lastCrawlerQteId = 0
            if lastDoorHoldSent then
                lastDoorHoldSent = false
                local doorHold = getRemote("DoorHold")
                if doorHold then
                    pcall(function() doorHold:FireServer(false) end)
                end
            end
        end

        -- Ambush Early Alert
        if State.AmbushAlert then
            local ambushIdx = runFolder:GetAttribute("Ambush") or 0
            if ambushIdx > 0 and ambushIdx ~= lastAmbushWarned then
                lastAmbushWarned = ambushIdx
                local entry = WorldConfig and WorldConfig.Ambushes and WorldConfig.Ambushes[ambushIdx]
                local realS = (type(entry) == "table" and tonumber(entry[1])) or ambushIdx
                WindUI:Notify({
                    Title = "AMBUSH AHEAD",
                    Content = string.format("Ambusher detected at S = %.0f", realS),
                    Duration = 3,
                })
            elseif ambushIdx == 0 then
                lastAmbushWarned = 0
            end
        end

        -- Auto-Vote Retry / Restart (Solo uses StartRun(false); Crew/Duo uses EndVote("restart"))
        if State.AutoVoteRetry then
            local rState = runFolder:GetAttribute("State")
            if (rState == "Caught" or rState == "Finish") and now - lastVoteSent > 3 then
                lastVoteSent = now
                local groupSize = LocalPlayer:GetAttribute("GroupSize")
                if type(groupSize) == "number" and groupSize > 1 then
                    local endVote = getRemote("EndVote")
                    if endVote then
                        pcall(function() endVote:FireServer("restart") end)
                    end
                else
                    local startRun = getRemote("StartRun")
                    if startRun then
                        pcall(function() startRun:FireServer(false) end)
                    end
                end
            end
        end

        -- Live Telemetry Readout (throttled 0.25s)
        if now - lastTelemetryUpdate >= 0.25 then
            lastTelemetryUpdate = now
            local carS = runFolder:GetAttribute("CarS") or 0
            local runnerS = runFolder:GetAttribute("RunnerS") or 0
            local runnerActive = runFolder:GetAttribute("RunnerActive") == true
            local gap = runnerActive and string.format("%.1f", carS - runnerS) or "Idle"
            local flank = tostring(runFolder:GetAttribute("Flank") or "-")
            local ambush = tostring(runFolder:GetAttribute("Ambush") or 0)
            local knocker = tostring(runFolder:GetAttribute("KnockerPhase") or "-")
            local intruder = tostring(runFolder:GetAttribute("IntruderPhase") or "-")
            local extraParts = {}
            for ak, av in pairs(runFolder:GetAttributes()) do
                local lower = ak:lower()
                if lower:find("listen") or lower:find("crawl") or lower:find("noise") or lower:find("sound") or lower:find("clown") then
                    table.insert(extraParts, ak .. "=" .. tostring(av))
                end
            end
            table.sort(extraParts)
            local extraLine = (#extraParts > 0) and ("\n" .. table.concat(extraParts, " | ")) or ""
            pcall(function()
                TelemetryPara:SetDesc(string.format(
                    "State: %s | CarS: %.1f | Runner Gap: %s | Flank: %s\nAmbush: %s | Knocker: %s | Intruder: %s%s",
                    tostring(runFolder:GetAttribute("State") or "?"),
                    carS,
                    gap,
                    flank ~= "" and flank or "-",
                    ambush,
                    knocker ~= "" and knocker or "-",
                    intruder ~= "" and intruder or "-",
                    extraLine
                ))
            end)
        end
    end

    -- Monster Highlight ESP (Dynamic across Update 1 & Update 2 ClientMonsters)
    if State.MonsterHighlight then
        for i = #ActiveHighlights, 1, -1 do
            local hl = ActiveHighlights[i]
            if not hl or not hl.Parent then
                table.remove(ActiveHighlights, i)
            end
        end
        local cm = workspace:FindFirstChild("ClientMonsters")
        if cm then
            for _, m in ipairs(cm:GetChildren()) do
                if (m:IsA("Model") or m:IsA("BasePart")) and not m:FindFirstChild("_IceDragonHL") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "_IceDragonHL"
                    local n = m.Name
                    if n == "Runner" then
                        hl.FillColor = Color3.fromRGB(255, 70, 70)
                    elseif n == "Ambusher" then
                        hl.FillColor = Color3.fromRGB(255, 190, 60)
                    else
                        hl.FillColor = Color3.fromRGB(215, 95, 255)
                    end
                    hl.OutlineColor = Color3.fromRGB(165, 242, 255)
                    hl.FillTransparency = 0.55
                    hl.Parent = m
                    table.insert(ActiveHighlights, hl)
                end
            end
        end
        local listenerModel = workspace:FindFirstChild("Listener")
        if listenerModel and listenerModel:IsA("Model") and not listenerModel:FindFirstChild("_IceDragonHL") then
            local hl = Instance.new("Highlight")
            hl.Name = "_IceDragonHL"
            hl.FillColor = Color3.fromRGB(255, 45, 95)
            hl.OutlineColor = Color3.fromRGB(255, 220, 120)
            hl.FillTransparency = 0.45
            hl.Parent = listenerModel
            table.insert(ActiveHighlights, hl)
        end
    elseif #ActiveHighlights > 0 then
        for _, hl in ipairs(ActiveHighlights) do
            pcall(function() hl:Destroy() end)
        end
        table.clear(ActiveHighlights)
    end

end))

trackConn(RunService.RenderStepped:Connect(function()
    if not getgenv()._ICEDRAGON_LOADED then
        return
    end

    -- Clear Fog continuous enforcement (after game Atmosphere updates)
    if State.ClearFog then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 99000
        local atm = AtmosphereInst or Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            atm.Density = 0
        end
    end

    -- FullBright continuous enforcement (after game Lighting updates)
    if State.FullBright then
        applyFullBrightProperties()
    end

    -- Road Centerline Drawing Ribbon
    if State.RoadRibbon and Drawing and type(Drawing.new) == "function" then
        local chassis = getMyChassis()
        local road = select(1, getActiveRoad())
        local cam = workspace.CurrentCamera
        if chassis and road and cam and RoadPath then
            local baseS = RoadPath.project(road, chassis.Position.X, chassis.Position.Z)
            local segments = 12
            local step = 16
            local prevScreen, prevVis
            for i = 0, segments do
                local x, y, z = RoadPath.pointAt(road, baseS + i * step, 0)
                local screen, vis = cam:WorldToViewportPoint(Vector3.new(x, y + 0.5, z))
                if i > 0 then
                    local line = DrawingLines[i]
                    if not line then
                        line = Drawing.new("Line")
                        line.Thickness = 2
                        line.Color = Color3.fromRGB(165, 242, 255)
                        line.Transparency = 0.85
                        DrawingLines[i] = line
                    end
                    if vis and prevVis and screen.Z > 0 and prevScreen.Z > 0 then
                        line.From = Vector2.new(prevScreen.X, prevScreen.Y)
                        line.To = Vector2.new(screen.X, screen.Y)
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                end
                prevScreen, prevVis = screen, vis
            end
        end
    elseif #DrawingLines > 0 then
        for _, line in ipairs(DrawingLines) do
            if line.Visible then
                pcall(function() line.Visible = false end)
            end
        end
    end
end))

applyCarHooks()

getgenv()._ICEDRAGON = {
    Window = Window,
    Tabs = Tabs,
    State = State,
    getRig = getRig,
    getRunFolder = getRunFolder,
    getActiveRoad = getActiveRoad,
    syncGripPatch = syncGripPatch,
    syncTuneOverlay = syncTuneOverlay,
    syncAutoDriveOverride = syncAutoDriveOverride,
}

-- Select initial tab (Drive & Tune) after WindUI finishes layout
task.defer(function()
    pcall(function() Tabs.Drive:Select() end)
    pcall(function() Window:SelectTab(1) end)
end)

WindUI:Notify({
    Title = "DO NOT STOP | ICEDRAGON",
    Content = "Loaded! Map: " .. tostring((MapConfig and MapConfig.Id) or "Unknown"),
    Duration = 4,
})

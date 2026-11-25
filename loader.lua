--!strict
-- ==============================================================================
-- ICEDRAGON HUB | OPEN KEY-GATE LOADER -> VAMPAUTH OBFUSCATED HOSTED LOADERS
-- Repository: https://github.com/tumbalakbseu2-oss/ICEDRAGON-HUB
-- Architecture:
--   1) Open Frost Key UI checks key status non-destructively via Cloudflare /preflight
--      (avoids HWID mismatch and avoids Error 267 kick on wrong key)
--   2) Hands script_key to your homemade-obfuscated VampAuth Hosted Loader
-- ==============================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local HUB_CONFIG = {
    Enabled = true,
    WorkerPreflightURL = "https://icedragon-hub.andika8899a.workers.dev/preflight",
    GetKeyURL = "https://vampauth.com/JUHQH1GGWXPPS4UU/flow",
    DiscordURL = "https://discord.gg/R2CSxzeCU",
    KeyFileName = "icedragon_hub_key.txt",
}

local GAMES_BY_PLACE_ID: { [number]: { Name: string, LoaderUrl: string } } = {
    [83694443310872] = {
        Name = "Dragon Arena",
        LoaderUrl = "https://vampauth.com/v1/loaders/ac523cb4ce98eecf592c0888b7667654.lua",
    },
    [116779912472448] = {
        Name = "Do Not Stop",
        LoaderUrl = "https://vampauth.com/v1/loaders/8236c1f2b46b6895de8fb13f0a420059.lua",
    },
}

local GAMES_BY_GAME_ID: { [number]: { Name: string, LoaderUrl: string } } = {
    [10771238997] = {
        Name = "Dragon Arena",
        LoaderUrl = "https://vampauth.com/v1/loaders/ac523cb4ce98eecf592c0888b7667654.lua",
    },
    [10772946647] = {
        Name = "Do Not Stop",
        LoaderUrl = "https://vampauth.com/v1/loaders/8236c1f2b46b6895de8fb13f0a420059.lua",
    },
}

-- ------------------------------------------------------------------------------
-- 1. VERIFY SUPPORTED GAME BEFORE OPENING KEY UI
-- ------------------------------------------------------------------------------
local targetGame = GAMES_BY_PLACE_ID[game.PlaceId] or GAMES_BY_GAME_ID[game.GameId]
if not targetGame then
    warn(string.format(
        "[ICEDRAGON HUB] Unsupported game! PlaceId=%d | GameId=%d",
        tonumber(game.PlaceId) or 0,
        tonumber(game.GameId) or 0
    ))
    return
end

-- ------------------------------------------------------------------------------
-- 2. CLIPBOARD + NON-HWID WORKER PREFLIGHT
-- ------------------------------------------------------------------------------
local function SafeSetClipboard(text: string)
    pcall(function()
        local fn = (typeof(setclipboard) == "function" and setclipboard)
            or (typeof(toclipboard) == "function" and toclipboard)
        if fn then fn(text) end
    end)
end

local function SafeGetClipboard(): string
    local ok, res = pcall(function()
        local fn = (typeof(getclipboard) == "function" and getclipboard)
        if fn then return fn() end
        return ""
    end)
    return (ok and type(res) == "string") and res or ""
end

local function ResolveHttpRequest()
    local genv = (typeof(getgenv) == "function" and getgenv()) or nil
    local fn = (genv and genv.request) or (typeof(request) == "function" and request)
        or (genv and genv.http_request) or (typeof(http_request) == "function" and http_request)
        or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    return fn
end

local function PreflightKeyViaWorker(rawKey: string): (boolean, any)
    local key = tostring(rawKey or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #key < 3 or #key > 64 then
        return false, "invalid_key"
    end

    local reqFn = ResolveHttpRequest()
    if type(reqFn) ~= "function" then
        -- Executor lacks custom request(); let VampAuth bootstrap verify directly
        return true, { preflight_skipped = true }
    end

    local okReq, res = pcall(reqFn, {
        Url = HUB_CONFIG.WorkerPreflightURL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
        },
        Body = HttpService:JSONEncode({ key = key }),
    })

    if not okReq or type(res) ~= "table" then
        -- Network fallback: allow direct VampAuth handoff if Worker unreachable
        return true, { preflight_skipped = true }
    end

    local status = tonumber(res.StatusCode or res.status_code) or 0
    local bodyText = tostring(res.Body or res.body or "")
    local okDec, data = pcall(function()
        return HttpService:JSONDecode(bodyText)
    end)

    if not okDec or type(data) ~= "table" then
        if status == 404 or status >= 500 then
            return true, { preflight_skipped = true }
        end
        return false, "HTTP_" .. tostring(status)
    end

    if status == 200 and data.valid == true then
        return true, data
    end

    return false, tostring(data.error or ("HTTP_" .. tostring(status)))
end

local function FormatKeyError(errCode: any): string
    local code = string.lower(tostring(errCode or "invalid_key"))
    if code:find("invalid_key") or code:find("not_found") then
        return "Key salah atau tidak ditemukan. Coba Get Key ulang."
    elseif code:find("key_expired") or code:find("expired") then
        return "Key sudah expired! Klik Get Key untuk perpanjang."
    elseif code:find("key_revoked") or code:find("revoked") then
        return "Key diblokir / dicabut oleh owner."
    elseif code:find("blacklisted") or code:find("banned") then
        return "Key / device masuk blacklist project ini."
    elseif code:find("rate_limited") or code:find("429") then
        return "Terlalu banyak percobaan. Tunggu ~60 detik."
    end
    return "Key ditolak: " .. tostring(errCode)
end

local function GetSavedKey(): string?
    local genv = (typeof(getgenv) == "function" and getgenv()) or nil
    local envKey = (genv and genv.script_key) or rawget(_G, "script_key")
    if type(envKey) == "string" and #envKey >= 3 and envKey ~= "PASTE-YOUR-KEY-HERE" then
        return (envKey:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(HUB_CONFIG.KeyFileName) then
        local ok, content = pcall(readfile, HUB_CONFIG.KeyFileName)
        if ok and type(content) == "string" and #content >= 3 then
            return (content:gsub("^%s+", ""):gsub("%s+$", ""))
        end
    end
    return nil
end

_G.ICEDRAGON_RESET_KEY = function()
    if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(HUB_CONFIG.KeyFileName) then
        pcall(delfile, HUB_CONFIG.KeyFileName)
    end
    local genv = (typeof(getgenv) == "function" and getgenv()) or nil
    if genv then genv.script_key = nil end
    _G.script_key = nil
    print("[ICEDRAGON HUB] Saved license key cleared.")
end

-- ------------------------------------------------------------------------------
-- 3. FROST KEY VERIFICATION UI GATE
-- ------------------------------------------------------------------------------
local verifiedKey: string? = nil

local function RunKeyGate(): boolean
    if not HUB_CONFIG.Enabled then
        local saved = GetSavedKey()
        verifiedKey = saved or ""
        return true
    end

    local savedKey = GetSavedKey()
    local initialNotice = "Enter your VampAuth key to launch " .. targetGame.Name .. ":"
    local initialColor = Color3.fromRGB(180, 215, 240)

    if savedKey then
        local ok, res = PreflightKeyViaWorker(savedKey)
        if ok then
            verifiedKey = savedKey
            print("[ICEDRAGON HUB] Key ready! Passing to VampAuth loader for " .. targetGame.Name .. "...")
            return true
        end
        initialNotice = "Saved key invalid: " .. FormatKeyError(res)
        initialColor = Color3.fromRGB(255, 130, 130)
        if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(HUB_CONFIG.KeyFileName) then
            pcall(delfile, HUB_CONFIG.KeyFileName)
        end
    end

    local uiParent: Instance? = nil
    pcall(function()
        local g = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
        if g then uiParent = g end
    end)
    if not uiParent then
        uiParent = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end
    if not uiParent then
        return false
    end

    local old = uiParent:FindFirstChild("IceDragonHubKeyUI")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "IceDragonHubKeyUI"
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = uiParent

    local Backdrop = Instance.new("Frame")
    Backdrop.Size = UDim2.new(1, 0, 1, 0)
    Backdrop.BackgroundColor3 = Color3.fromRGB(2, 8, 16)
    Backdrop.BackgroundTransparency = 0.45
    Backdrop.BorderSizePixel = 0
    Backdrop.Parent = ScreenGui

    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(0, 440, 0, 290)
    Card.Position = UDim2.new(0.5, -220, 0.5, -145)
    Card.BackgroundColor3 = Color3.fromRGB(5, 19, 31)
    Card.BackgroundTransparency = 0.08
    Card.BorderSizePixel = 0
    Card.Active = true
    Card.Parent = ScreenGui

    do
        local uis = game:GetService("UserInputService")
        local dragging, dragStart, startPos = false, nil :: Vector3?, nil :: UDim2?
        Card.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = inp.Position
                startPos = Card.Position
            end
        end)
        uis.InputChanged:Connect(function(inp)
            if dragging and dragStart and startPos and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                local delta = inp.Position - dragStart
                Card.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        uis.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 14)
    CardCorner.Parent = Card

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Color3.fromRGB(0, 229, 255)
    CardStroke.Thickness = 1.6
    CardStroke.Transparency = 0.25
    CardStroke.Parent = Card

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -56, 0, 30)
    TitleLbl.Position = UDim2.new(0, 20, 0, 16)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.Text = "ICEDRAGON HUB"
    TitleLbl.TextColor3 = Color3.fromRGB(220, 248, 255)
    TitleLbl.TextSize = 20
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = Card

    local SubtitleLbl = Instance.new("TextLabel")
    SubtitleLbl.Size = UDim2.new(1, -56, 0, 18)
    SubtitleLbl.Position = UDim2.new(0, 20, 0, 44)
    SubtitleLbl.BackgroundTransparency = 1
    SubtitleLbl.Font = Enum.Font.GothamMedium
    SubtitleLbl.Text = "Game: " .. targetGame.Name .. " • VampAuth Protected"
    SubtitleLbl.TextColor3 = Color3.fromRGB(0, 210, 245)
    SubtitleLbl.TextSize = 12
    SubtitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleLbl.Parent = Card

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -42, 0, 16)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(16, 40, 62)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(190, 225, 245)
    CloseBtn.TextSize = 13
    CloseBtn.Parent = Card
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(1, -40, 0, 32)
    StatusLbl.Position = UDim2.new(0, 20, 0, 74)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.Text = initialNotice
    StatusLbl.TextColor3 = initialColor
    StatusLbl.TextSize = 13
    StatusLbl.TextWrapped = true
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.Parent = Card

    local InputBox = Instance.new("Frame")
    InputBox.Size = UDim2.new(1, -40, 0, 42)
    InputBox.Position = UDim2.new(0, 20, 0, 114)
    InputBox.BackgroundColor3 = Color3.fromRGB(11, 38, 59)
    InputBox.BorderSizePixel = 0
    InputBox.Parent = Card
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 9)

    local InputStroke = Instance.new("UIStroke")
    InputStroke.Color = Color3.fromRGB(0, 180, 220)
    InputStroke.Thickness = 1
    InputStroke.Transparency = 0.45
    InputStroke.Parent = InputBox

    local KeyTextBox = Instance.new("TextBox")
    KeyTextBox.Size = UDim2.new(1, -78, 1, 0)
    KeyTextBox.Position = UDim2.new(0, 12, 0, 0)
    KeyTextBox.BackgroundTransparency = 1
    KeyTextBox.ClearTextOnFocus = false
    KeyTextBox.Font = Enum.Font.Code
    KeyTextBox.PlaceholderText = "Paste your VampAuth key here..."
    KeyTextBox.PlaceholderColor3 = Color3.fromRGB(110, 155, 185)
    KeyTextBox.Text = ""
    KeyTextBox.TextColor3 = Color3.fromRGB(240, 252, 255)
    KeyTextBox.TextSize = 13
    KeyTextBox.TextXAlignment = Enum.TextXAlignment.Left
    KeyTextBox.Parent = InputBox

    local PasteBtn = Instance.new("TextButton")
    PasteBtn.Size = UDim2.new(0, 56, 0, 28)
    PasteBtn.Position = UDim2.new(1, -62, 0.5, -14)
    PasteBtn.BackgroundColor3 = Color3.fromRGB(18, 62, 92)
    PasteBtn.Font = Enum.Font.GothamSemibold
    PasteBtn.Text = "Paste"
    PasteBtn.TextColor3 = Color3.fromRGB(190, 240, 255)
    PasteBtn.TextSize = 12
    PasteBtn.Parent = InputBox
    Instance.new("UICorner", PasteBtn).CornerRadius = UDim.new(0, 6)

    PasteBtn.MouseButton1Click:Connect(function()
        local clip = SafeGetClipboard()
        if #clip > 0 then
            KeyTextBox.Text = clip:gsub("^%s+", ""):gsub("%s+$", "")
            StatusLbl.Text = "Key pasted from clipboard!"
            StatusLbl.TextColor3 = Color3.fromRGB(160, 240, 210)
        else
            StatusLbl.Text = "Clipboard empty or unavailable."
            StatusLbl.TextColor3 = Color3.fromRGB(255, 200, 120)
        end
    end)

    local SubmitBtn = Instance.new("TextButton")
    SubmitBtn.Size = UDim2.new(1, -40, 0, 40)
    SubmitBtn.Position = UDim2.new(0, 20, 0, 170)
    SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 185, 230)
    SubmitBtn.Font = Enum.Font.GothamBold
    SubmitBtn.Text = "Verify & Launch " .. targetGame.Name
    SubmitBtn.TextColor3 = Color3.fromRGB(4, 16, 26)
    SubmitBtn.TextSize = 14
    SubmitBtn.Parent = Card
    Instance.new("UICorner", SubmitBtn).CornerRadius = UDim.new(0, 9)

    local GetKeyBtn = Instance.new("TextButton")
    GetKeyBtn.Size = UDim2.new(0.48, -24, 0, 34)
    GetKeyBtn.Position = UDim2.new(0, 20, 0, 222)
    GetKeyBtn.BackgroundColor3 = Color3.fromRGB(13, 45, 70)
    GetKeyBtn.Font = Enum.Font.GothamSemibold
    GetKeyBtn.Text = "Copy Get Key Link"
    GetKeyBtn.TextColor3 = Color3.fromRGB(185, 235, 255)
    GetKeyBtn.TextSize = 12
    GetKeyBtn.Parent = Card
    Instance.new("UICorner", GetKeyBtn).CornerRadius = UDim.new(0, 8)

    local DiscordBtn = Instance.new("TextButton")
    DiscordBtn.Size = UDim2.new(0.48, -24, 0, 34)
    DiscordBtn.Position = UDim2.new(0.52, 4, 0, 222)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(22, 42, 74)
    DiscordBtn.Font = Enum.Font.GothamSemibold
    DiscordBtn.Text = "Copy Discord Invite"
    DiscordBtn.TextColor3 = Color3.fromRGB(185, 215, 255)
    DiscordBtn.TextSize = 12
    DiscordBtn.Parent = Card
    Instance.new("UICorner", DiscordBtn).CornerRadius = UDim.new(0, 8)

    local FooterLbl = Instance.new("TextLabel")
    FooterLbl.Size = UDim2.new(1, -40, 0, 16)
    FooterLbl.Position = UDim2.new(0, 20, 1, -24)
    FooterLbl.BackgroundTransparency = 1
    FooterLbl.Font = Enum.Font.Gotham
    FooterLbl.Text = "Saved keys are cached in " .. HUB_CONFIG.KeyFileName .. " (_G.ICEDRAGON_RESET_KEY() to reset)"
    FooterLbl.TextColor3 = Color3.fromRGB(110, 155, 185)
    FooterLbl.TextSize = 11
    FooterLbl.Parent = Card

    local authGate = Instance.new("BindableEvent")
    local approved = false
    local finished = false
    local busy = false

    local function CompleteGate(didPass: boolean)
        if finished then return end
        finished = true
        approved = didPass
        pcall(function() ScreenGui:Destroy() end)
        authGate:Fire()
    end

    CloseBtn.MouseButton1Click:Connect(function()
        CompleteGate(false)
    end)

    GetKeyBtn.MouseButton1Click:Connect(function()
        SafeSetClipboard(HUB_CONFIG.GetKeyURL)
        StatusLbl.Text = "Get Key URL copied! Complete checkpoints in browser and paste your key."
        StatusLbl.TextColor3 = Color3.fromRGB(115, 235, 255)
    end)

    DiscordBtn.MouseButton1Click:Connect(function()
        SafeSetClipboard(HUB_CONFIG.DiscordURL)
        StatusLbl.Text = "Discord link copied to clipboard!"
        StatusLbl.TextColor3 = Color3.fromRGB(150, 200, 255)
    end)

    local function AttemptVerify()
        if busy or finished then return end
        local inputKey = (KeyTextBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if #inputKey < 3 then
            StatusLbl.Text = "Please enter a valid license key first!"
            StatusLbl.TextColor3 = Color3.fromRGB(255, 185, 100)
            return
        end

        busy = true
        SubmitBtn.Text = "Checking key..."
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 160)
        StatusLbl.Text = "Verifying key status..."
        StatusLbl.TextColor3 = Color3.fromRGB(160, 230, 255)

        task.spawn(function()
            local settled = false
            local okCall, valid, res = false, false, nil :: any

            task.delay(15, function()
                if not settled and not finished then
                    busy = false
                    SubmitBtn.Text = "Verify & Launch " .. targetGame.Name
                    SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 185, 230)
                    StatusLbl.Text = "Preflight timed out! Check your connection."
                    StatusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
                end
            end)

            okCall, valid, res = pcall(function()
                return PreflightKeyViaWorker(inputKey)
            end)
            settled = true
            if finished then return end

            if okCall and valid then
                verifiedKey = inputKey
                local skipped = type(res) == "table" and res.preflight_skipped == true
                StatusLbl.Text = skipped
                    and ("Launching VampAuth loader for " .. targetGame.Name .. "...")
                    or ("License valid! Launching " .. targetGame.Name .. "...")
                StatusLbl.TextColor3 = Color3.fromRGB(115, 255, 180)
                if not skipped and typeof(writefile) == "function" then
                    pcall(writefile, HUB_CONFIG.KeyFileName, inputKey)
                end
                task.wait(0.25)
                CompleteGate(true)
            else
                busy = false
                SubmitBtn.Text = "Verify & Launch " .. targetGame.Name
                SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 185, 230)
                StatusLbl.Text = FormatKeyError(okCall and res or valid)
                StatusLbl.TextColor3 = Color3.fromRGB(255, 115, 115)
            end
        end)
    end

    SubmitBtn.MouseButton1Click:Connect(AttemptVerify)
    KeyTextBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then AttemptVerify() end
    end)

    authGate.Event:Wait()
    authGate:Destroy()
    return approved
end

if not RunKeyGate() then
    return
end

-- ------------------------------------------------------------------------------
-- 4. HANDOFF TO OBFUSCATED VAMPAUTH HOSTED LOADER
-- ------------------------------------------------------------------------------
local activeKey = verifiedKey or ""
local genv = (typeof(getgenv) == "function" and getgenv()) or nil
if genv then
    genv.script_key = activeKey
end
_G.script_key = activeKey
script_key = activeKey

local okGet, loaderSource = pcall(function()
    return game:HttpGet(targetGame.LoaderUrl)
end)

if not okGet or type(loaderSource) ~= "string" or #loaderSource == 0 then
    warn("[ICEDRAGON HUB] Failed to fetch VampAuth loader for " .. targetGame.Name)
    return
end

local fn, compileErr = loadstring(loaderSource, targetGame.Name .. "_VampAuth")
if not fn then
    warn("[ICEDRAGON HUB] Compile error in VampAuth loader: " .. tostring(compileErr))
    return
end

print("[ICEDRAGON HUB] Executing VampAuth obfuscated hub for " .. targetGame.Name .. "...")
local okRun, runErr = xpcall(fn, debug.traceback)
if okRun then
    if #activeKey >= 3 and typeof(writefile) == "function" then
        pcall(writefile, HUB_CONFIG.KeyFileName, activeKey)
    end
else
    warn("[ICEDRAGON HUB] Runtime error in " .. targetGame.Name .. ": " .. tostring(runErr))
end

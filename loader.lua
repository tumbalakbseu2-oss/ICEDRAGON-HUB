--!strict
-- ==============================================================================
-- ICEDRAGON HUB | MULTI-GAME UNIVERSAL LOADER + CLOUDFLARE VAMPAUTH GATE
-- Repository: https://github.com/tumbalakbseu2-oss/ICEDRAGON-HUB
-- Note: Zero AuthSecret in client code. Verification goes through your Worker.
-- ==============================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local HUB_CONFIG = {
    Enabled = true, -- Set false only for local offline testing
    WorkerCheckURL = "https://icedragon-hub.andika8899a.workers.dev/check",
    GetKeyURL = "https://vampauth.com/JUHQH1GGWXPPS4UU/flow",
    DiscordURL = "https://discord.gg/R2CSxzeCU",
    KeyFileName = "icedragon_hub_key.txt",
    RawBase = "https://raw.githubusercontent.com/tumbalakbseu2-oss/ICEDRAGON-HUB/main/",
}

local GAMES_BY_PLACE_ID: { [number]: { Name: string, Path: string } } = {
    [83694443310872] = {
        Name = "Dragon Arena",
        Path = "games/dragon_arena_empire_hub.lua",
    },
    [116779912472448] = {
        Name = "Do Not Stop",
        Path = "games/do_not_stop.lua",
    },
}

local GAMES_BY_GAME_ID: { [number]: { Name: string, Path: string } } = {
    [10771238997] = {
        Name = "Dragon Arena",
        Path = "games/dragon_arena_empire_hub.lua",
    },
    [10772946647] = {
        Name = "Do Not Stop",
        Path = "games/do_not_stop.lua",
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
-- 2. CLIPBOARD + SHA-256 HWID + WORKER CLIENT
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

local SHA256Hex = (function()
    local bnot = bit32.bnot
    local band = bit32.band
    local bor = bit32.bor
    local bxor = bit32.bxor
    local rshift = bit32.rshift
    local rrotate = bit32.rrotate

    local K256 = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    local function toHex32(words: { number }): string
        local out = table.create(#words)
        for i = 1, #words do
            out[i] = string.format("%08x", band(words[i], 0xffffffff))
        end
        return table.concat(out)
    end

    return function(msg: string): string
        local len = #msg
        local padZero = (55 - len) % 64
        local bitLen = len * 8
        local hi = math.floor(bitLen / 0x100000000)
        local lo = bitLen % 0x100000000
        local padded = msg
            .. "\128"
            .. string.rep("\0", padZero)
            .. string.char(
                band(rshift(hi, 24), 0xff), band(rshift(hi, 16), 0xff), band(rshift(hi, 8), 0xff), band(hi, 0xff),
                band(rshift(lo, 24), 0xff), band(rshift(lo, 16), 0xff), band(rshift(lo, 8), 0xff), band(lo, 0xff)
            )

        local h0, h1, h2, h3, h4, h5, h6, h7 =
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        local w = table.create(64, 0)

        for idx = 1, #padded, 64 do
            for j = 1, 16 do
                local o = idx + (j - 1) * 4
                local b1, b2, b3, b4 = string.byte(padded, o, o + 3)
                w[j] = (((b1 * 256 + b2) * 256 + b3) * 256 + b4)
            end
            for j = 17, 64 do
                local v15 = w[j - 15]
                local v2 = w[j - 2]
                local s0 = bxor(rrotate(v15, 7), rrotate(v15, 18), rshift(v15, 3))
                local s1 = bxor(rrotate(v2, 17), rrotate(v2, 19), rshift(v2, 10))
                w[j] = (w[j - 16] + s0 + w[j - 7] + s1) % 0x100000000
            end

            local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
            for j = 1, 64 do
                local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
                local ch = bxor(band(e, f), band(bnot(e), g))
                local temp1 = (h + S1 + ch + K256[j] + w[j]) % 0x100000000
                local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
                local maj = bxor(band(a, b), band(a, c), band(b, c))
                local temp2 = (S0 + maj) % 0x100000000

                h = g
                g = f
                f = e
                e = (d + temp1) % 0x100000000
                d = c
                c = b
                b = a
                a = (temp1 + temp2) % 0x100000000
            end

            h0 = (h0 + a) % 0x100000000
            h1 = (h1 + b) % 0x100000000
            h2 = (h2 + c) % 0x100000000
            h3 = (h3 + d) % 0x100000000
            h4 = (h4 + e) % 0x100000000
            h5 = (h5 + f) % 0x100000000
            h6 = (h6 + g) % 0x100000000
            h7 = (h7 + h) % 0x100000000
        end

        return toHex32({ h0, h1, h2, h3, h4, h5, h6, h7 })
    end
end)()

local function ResolveHWIDHash(): string
    local ok, cid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    local rawId = (ok and type(cid) == "string" and #cid > 0)
        and cid
        or ("roblox-uid-" .. tostring(LocalPlayer and LocalPlayer.UserId or 0))
    return SHA256Hex(rawId)
end

local function ResolveHttpRequest()
    local genv = (typeof(getgenv) == "function" and getgenv()) or nil
    local fn = (genv and genv.request) or (typeof(request) == "function" and request)
        or (genv and genv.http_request) or (typeof(http_request) == "function" and http_request)
        or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    return fn
end

local function CheckKeyViaWorker(rawKey: string, hwid: string): (boolean, any)
    local key = tostring(rawKey or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #key == 0 or #key > 128 then
        return false, "invalid_request"
    end
    if HUB_CONFIG.WorkerCheckURL:find("YOUR%-WORKER%-SUBDOMAIN") then
        return false, "worker_not_configured"
    end

    local reqFn = ResolveHttpRequest()
    if type(reqFn) ~= "function" then
        return false, "executor_unsupported"
    end

    local okReq, res = pcall(reqFn, {
        Url = HUB_CONFIG.WorkerCheckURL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
        },
        Body = HttpService:JSONEncode({
            key = key,
            hwid = hwid,
        }),
    })

    if not okReq or type(res) ~= "table" then
        return false, "connection_failed"
    end

    local status = tonumber(res.StatusCode or res.status_code) or 0
    local bodyText = tostring(res.Body or res.body or "")
    local okDec, data = pcall(function()
        return HttpService:JSONDecode(bodyText)
    end)

    if not okDec or type(data) ~= "table" then
        return false, "HTTP_" .. tostring(status)
    end

    if status == 200 and data.valid == true and data.status == "valid" then
        return true, data
    end

    return false, tostring(data.error or ("HTTP_" .. tostring(status)))
end

local function FormatKeyError(errCode: any): string
    local code = string.lower(tostring(errCode or "invalid_key"))
    if code:find("worker_not_configured") then
        return "Worker URL belum diisi di loader.lua!"
    elseif code:find("server_misconfigured") then
        return "Secret VAMPAUTH_AUTH_SECRET belum diset di Cloudflare Worker!"
    elseif code:find("invalid_key") or code:find("not_found") then
        return "Key salah atau tidak ditemukan. Coba Get Key ulang."
    elseif code:find("key_expired") or code:find("expired") then
        return "Key sudah expired! Klik Get Key untuk perpanjang."
    elseif code:find("hwid_mismatch") or code:find("mismatch") then
        return "Key sudah terikat ke device lain (HWID Mismatch)."
    elseif code:find("key_revoked") or code:find("revoked") then
        return "Key diblokir / dicabut oleh owner."
    elseif code:find("blacklisted") or code:find("banned") then
        return "Device masuk blacklist project ini."
    elseif code:find("rate_limited") or code:find("429") then
        return "Terlalu banyak percobaan. Tunggu ~60 detik."
    elseif code:find("connection_failed") or code:find("service_unavailable") then
        return "Gagal terhubung ke Cloudflare Worker / VampAuth."
    end
    return "Verifikasi gagal: " .. tostring(errCode)
end

local function GetSavedKey(): string?
    local genv = (typeof(getgenv) == "function" and getgenv()) or nil
    local envKey = (genv and genv.script_key) or rawget(_G, "script_key")
    if type(envKey) == "string" and #envKey > 3 and envKey ~= "PASTE-YOUR-KEY-HERE" then
        return (envKey:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(HUB_CONFIG.KeyFileName) then
        local ok, content = pcall(readfile, HUB_CONFIG.KeyFileName)
        if ok and type(content) == "string" and #content > 3 then
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
local function RunKeyGate(): boolean
    if not HUB_CONFIG.Enabled then
        return true
    end

    local hwid = ResolveHWIDHash()
    local savedKey = GetSavedKey()
    local initialNotice = "Enter your VampAuth key to unlock " .. targetGame.Name .. ":"
    local initialColor = Color3.fromRGB(180, 215, 240)

    if savedKey then
        local ok, res = CheckKeyViaWorker(savedKey, hwid)
        if ok then
            print("[ICEDRAGON HUB] Saved key valid! Loading " .. targetGame.Name .. "...")
            return true
        end
        initialNotice = "Saved key invalid: " .. FormatKeyError(res)
        initialColor = Color3.fromRGB(255, 130, 130)
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
    SubtitleLbl.Text = "Target: " .. targetGame.Name .. " • VampAuth Worker"
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
    KeyTextBox.Text = savedKey or ""
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
        if #inputKey < 4 then
            StatusLbl.Text = "Please enter a valid license key first!"
            StatusLbl.TextColor3 = Color3.fromRGB(255, 185, 100)
            return
        end

        busy = true
        SubmitBtn.Text = "Verifying via Worker..."
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 160)
        StatusLbl.Text = "Checking license with IceDragon Auth Worker..."
        StatusLbl.TextColor3 = Color3.fromRGB(160, 230, 255)

        task.spawn(function()
            local settled = false
            local okCall, valid, res = false, false, nil :: any

            task.delay(15, function()
                if not settled and not finished then
                    busy = false
                    SubmitBtn.Text = "Verify & Launch " .. targetGame.Name
                    SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 185, 230)
                    StatusLbl.Text = "Request timed out! Check internet / Worker URL."
                    StatusLbl.TextColor3 = Color3.fromRGB(255, 120, 120)
                end
            end)

            okCall, valid, res = pcall(function()
                return CheckKeyViaWorker(inputKey, hwid)
            end)
            settled = true
            if finished then return end

            if okCall and valid then
                StatusLbl.Text = "License valid! Loading " .. targetGame.Name .. "..."
                StatusLbl.TextColor3 = Color3.fromRGB(115, 255, 180)
                if typeof(writefile) == "function" then
                    pcall(writefile, HUB_CONFIG.KeyFileName, inputKey)
                end
                local genv = (typeof(getgenv) == "function" and getgenv()) or nil
                if genv then genv.script_key = inputKey else _G.script_key = inputKey end
                task.wait(0.35)
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
-- 4. FETCH & EXECUTE VERIFIED GAME HUB
-- ------------------------------------------------------------------------------
local url = HUB_CONFIG.RawBase .. targetGame.Path
local okGet, source = pcall(function()
    return game:HttpGet(url)
end)

if not okGet or type(source) ~= "string" or #source == 0 then
    warn("[ICEDRAGON HUB] Failed to fetch " .. targetGame.Name .. " script from: " .. url)
    return
end

local fn, compileErr = loadstring(source, targetGame.Name)
if not fn then
    warn("[ICEDRAGON HUB] Compile error in " .. targetGame.Name .. ": " .. tostring(compileErr))
    return
end

print("[ICEDRAGON HUB] Loading " .. targetGame.Name .. "...")
local okRun, runErr = xpcall(fn, debug.traceback)
if not okRun then
    warn("[ICEDRAGON HUB] Runtime error in " .. targetGame.Name .. ": " .. tostring(runErr))
end

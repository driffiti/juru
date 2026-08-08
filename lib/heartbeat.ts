export function buildBootstrap(nonce: string): string {
  return `-- juru.lol loader
local __juru_nonce = "${nonce}"
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local function __juru_req()
    return (syn and syn.request)
        or (Delta and Delta.request)
        or (Electron and Electron.request)
        or http_request
        or request
        or (fluxus and fluxus.request)
end

local function __juru_identify_executor()
    local name, version = "Unknown", ""
    pcall(function()
        if identifyexecutor then
            local n, v = identifyexecutor()
            name = n or name; version = v or version
        elseif getexecutorname then
            name = getexecutorname() or name
        elseif syn then name = "Synapse X"
        elseif KRNL_LOADED then name = "Krnl"
        elseif Fluxus then name = "Fluxus"
        elseif Delta then name = "Delta"
        elseif Electron then name = "Electron"
        elseif is_sirhurt_closure then name = "SirHurt"
        elseif Comet then name = "Comet"
        elseif OXYGEN_U then name = "Oxygen U"
        end
    end)
    return name, version
end

local function __juru_hwid()
    local ok, id = pcall(function()
        if gethwid then return gethwid() end
        if syn and syn.get_hwid then return syn.get_hwid() end
        if get_hwid then return get_hwid() end
        if getdeviceid then return getdeviceid() end
        if Delta and Delta.fingerprint then return Delta.fingerprint() end
        local r = game:GetService("RbxAnalyticsService"):GetClientId()
        if r and r ~= "" then return r end
    end)
    return (ok and id) and tostring(id) or "unknown-hwid"
end

local function __juru_alert(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "juru.lol", Text = msg, Duration = 5 })
    end)
end

local __juru_exec_name, __juru_exec_version = __juru_identify_executor()
local __juru_hwid_val = __juru_hwid()
local __juru_lp = Players.LocalPlayer
local __juru_http = __juru_req()
if not __juru_http then
    __juru_alert("Your executor doesn't support HTTP requests.")
    return
end

local function __juru_unlock(key, nonce_val)
    local ok, res = pcall(__juru_http, {
        Url = "https://juru.lol/api/unlock",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["User-Agent"] = "Roblox/WinInet" },
        Body = HttpService:JSONEncode({
            key = key, hwid = __juru_hwid_val, nonce = nonce_val,
            placeId = game.PlaceId, jobId = game.JobId,
            userId = __juru_lp and __juru_lp.UserId or 0,
            playerName = __juru_lp and __juru_lp.Name or "unknown",
            displayName = __juru_lp and __juru_lp.DisplayName or "unknown",
            executor = __juru_exec_name, executorVersion = __juru_exec_version,
        }),
    })
    if not ok or not res or not res.Body then return nil end
    local dok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
    return dok and decoded or nil
end

local function __juru_fresh_nonce()
    local ok, res = pcall(__juru_http, {
        Url = "https://juru.lol/api/nonce", Method = "GET",
        Headers = { ["User-Agent"] = "Roblox/WinInet" },
    })
    if not ok or not res or not res.Body then return __juru_nonce end
    local dok, d = pcall(function() return HttpService:JSONDecode(res.Body) end)
    return (dok and d and d.nonce) or __juru_nonce
end

local function __juru_run(script_str)
    local fn = loadstring(script_str); script_str = nil
    if newcclosure then fn = newcclosure(fn) end
    local rok = pcall(fn)
    if not rok then __juru_alert("Script failed to run.") end
end

-- ─── Minimal theme ─────────────────────────────────────────────────────────
local C  = Color3.fromRGB
local U2 = UDim2.new
local UO = UDim2.fromOffset
local US = UDim2.fromScale

local PURPLE = C(170, 100, 255)
local BG     = C(14, 12, 20)
local BG2    = C(20, 16, 30)
local INPUT  = C(10, 8, 16)
local TEXT   = C(235, 230, 255)
local MUTED  = C(140, 130, 165)
local RED    = C(239, 68, 68)
local GREEN  = C(52, 211, 153)

local function corner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
    return c
end

local function stroke(col, t, a, p)
    local s = Instance.new("UIStroke")
    s.Color = col; s.Thickness = t or 1; s.Transparency = a or 0; s.Parent = p
    return s
end

local function tween(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function __juru_show_panel()
    local parentGui
    pcall(function() if gethui then parentGui = gethui() end end)
    if not parentGui then pcall(function() parentGui = CoreGui end) end
    if not parentGui then parentGui = __juru_lp:WaitForChild("PlayerGui", 8) end
    if not parentGui then return end

    local old = parentGui:FindFirstChild("__JuruPanel")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "__JuruPanel"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = parentGui end)
    if not sg.Parent then
        pcall(function() sg.Parent = __juru_lp.PlayerGui end)
    end

    local overlay = Instance.new("Frame")
    overlay.Size = US(1, 1)
    overlay.BackgroundColor3 = C(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 1
    overlay.Parent = sg

    local panel = Instance.new("Frame")
    panel.Size = UO(380, 240)
    panel.Position = US(0.5, 0.52)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.BackgroundColor3 = BG
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 2
    panel.Parent = sg
    corner(12, panel)
    local pStroke = stroke(PURPLE, 1, 0.55, panel)

    tween(overlay, 0.2, { BackgroundTransparency = 0.5 })
    tween(panel, 0.22, { BackgroundTransparency = 0, Position = US(0.5, 0.5) })

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UO(20, 18)
    title.Size = UO(200, 24)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.RichText = true
    title.Text = '<font color="#aa64ff">juru</font><font color="#ebe6ff">.lol</font>'
    title.ZIndex = 3
    title.Parent = panel

    local close = Instance.new("TextButton")
    close.Size = UO(28, 28)
    close.Position = U2(1, -40, 0, 16)
    close.BackgroundColor3 = BG2
    close.Text = "×"
    close.TextColor3 = MUTED
    close.Font = Enum.Font.GothamBold
    close.TextSize = 18
    close.AutoButtonColor = false
    close.BorderSizePixel = 0
    close.ZIndex = 4
    close.Parent = panel
    corner(8, close)
    close.MouseEnter:Connect(function()
        tween(close, 0.1, { BackgroundColor3 = C(35, 25, 50), TextColor3 = TEXT })
    end)
    close.MouseLeave:Connect(function()
        tween(close, 0.1, { BackgroundColor3 = BG2, TextColor3 = MUTED })
    end)

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UO(20, 44)
    sub.Size = U2(1, -40, 0, 16)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextColor3 = MUTED
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = "Enter your key"
    sub.ZIndex = 3
    sub.Parent = panel

    local inputBg = Instance.new("Frame")
    inputBg.Size = U2(1, -40, 0, 42)
    inputBg.Position = UO(20, 72)
    inputBg.BackgroundColor3 = INPUT
    inputBg.BorderSizePixel = 0
    inputBg.ZIndex = 3
    inputBg.Parent = panel
    corner(8, inputBg)
    local inStroke = stroke(C(55, 40, 85), 1, 0, inputBg)

    local box = Instance.new("TextBox")
    box.Size = U2(1, -24, 1, 0)
    box.Position = UO(12, 0)
    box.BackgroundTransparency = 1
    box.PlaceholderText = "JURU-XXXX-XXXX"
    box.PlaceholderColor3 = C(70, 60, 95)
    box.Text = ""
    box.TextColor3 = TEXT
    box.Font = Enum.Font.Code
    box.TextSize = 15
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.ZIndex = 4
    box.Parent = inputBg

    box.Focused:Connect(function()
        tween(inStroke, 0.12, { Color = PURPLE })
    end)
    box.FocusLost:Connect(function()
        tween(inStroke, 0.12, { Color = C(55, 40, 85) })
    end)

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Position = UO(20, 120)
    status.Size = U2(1, -40, 0, 16)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextColor3 = RED
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Text = ""
    status.ZIndex = 3
    status.Parent = panel

    local gk = Instance.new("TextButton")
    gk.Size = UO(160, 40)
    gk.Position = UO(20, 148)
    gk.BackgroundColor3 = BG2
    gk.Text = "Get Key"
    gk.TextColor3 = MUTED
    gk.Font = Enum.Font.GothamMedium
    gk.TextSize = 13
    gk.AutoButtonColor = false
    gk.BorderSizePixel = 0
    gk.ZIndex = 4
    gk.Parent = panel
    corner(8, gk)
    stroke(C(55, 40, 85), 1, 0, gk)
    gk.MouseEnter:Connect(function()
        tween(gk, 0.1, { TextColor3 = TEXT, BackgroundColor3 = C(28, 22, 42) })
    end)
    gk.MouseLeave:Connect(function()
        tween(gk, 0.1, { TextColor3 = MUTED, BackgroundColor3 = BG2 })
    end)

    local ex = Instance.new("TextButton")
    ex.Size = UO(170, 40)
    ex.Position = UO(190, 148)
    ex.BackgroundColor3 = PURPLE
    ex.Text = "Execute"
    ex.TextColor3 = C(255, 255, 255)
    ex.Font = Enum.Font.GothamBold
    ex.TextSize = 14
    ex.AutoButtonColor = false
    ex.BorderSizePixel = 0
    ex.ZIndex = 4
    ex.Parent = panel
    corner(8, ex)
    ex.MouseEnter:Connect(function()
        if ex.Active then tween(ex, 0.1, { BackgroundColor3 = C(185, 120, 255) }) end
    end)
    ex.MouseLeave:Connect(function()
        if ex.Active then tween(ex, 0.1, { BackgroundColor3 = PURPLE }) end
    end)

    local foot = Instance.new("TextLabel")
    foot.BackgroundTransparency = 1
    foot.Position = UO(0, 204)
    foot.Size = U2(1, 0, 0, 20)
    foot.Font = Enum.Font.Gotham
    foot.TextSize = 11
    foot.TextColor3 = C(80, 70, 105)
    foot.Text = "discord.gg/getjuru"
    foot.ZIndex = 3
    foot.Parent = panel

    -- drag zone (top bar area)
    local dragging, dragStart, startPos, dragInput
    local dragZone = Instance.new("Frame")
    dragZone.BackgroundTransparency = 1
    dragZone.Size = U2(1, -50, 0, 50)
    dragZone.ZIndex = 5
    dragZone.Parent = panel

    dragZone.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragZone.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            dragInput = inp
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if inp == dragInput and dragging then
            local d = inp.Position - dragStart
            panel.Position = U2(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    local function closePanel()
        tween(overlay, 0.15, { BackgroundTransparency = 1 })
        tween(panel, 0.15, { BackgroundTransparency = 1 })
        task.delay(0.18, function() if sg then sg:Destroy() end end)
    end
    close.MouseButton1Click:Connect(closePanel)

    gk.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("discord.gg/getjuru") end)
        pcall(function() GuiService:OpenBrowserWindow("https://discord.gg/getjuru") end)
        local prev = gk.Text
        gk.Text = "Copied"
        task.delay(1.5, function() if gk and gk.Parent then gk.Text = prev end end)
    end)

    ex.MouseButton1Click:Connect(function()
        local key = box.Text:gsub("%s+", ""):upper()
        if key == "" then
            status.Text = "Enter a key."
            status.TextColor3 = RED
            return
        end
        status.Text = ""
        ex.Text = "..."
        ex.Active = false
        tween(ex, 0.1, { BackgroundColor3 = C(100, 60, 160) })

        task.spawn(function()
            local result = __juru_unlock(key, __juru_fresh_nonce())
            ex.Active = true
            tween(ex, 0.1, { BackgroundColor3 = PURPLE })

            if not result then
                ex.Text = "Execute"
                status.TextColor3 = RED
                status.Text = "Could not reach juru.lol"
                return
            end
            if not result.valid then
                ex.Text = "Execute"
                status.TextColor3 = RED
                status.Text = result.reason or "Invalid key"
                return
            end

            ex.Text = "OK"
            tween(ex, 0.2, { BackgroundColor3 = GREEN })
            status.TextColor3 = GREEN
            status.Text = "Unlocked"
            task.delay(0.35, function()
                closePanel()
                task.delay(0.2, function() __juru_run(result.script) end)
            end)
        end)
    end)
end

-- ── Entry point ──────────────────────────────────────────────────────────────
-- Robustly read SCRIPT_KEY from wherever the executor may have stored it.
local preset = ""
pcall(function()
    -- getgenv() covers variables set at the global executor scope
    if getgenv then preset = getgenv().SCRIPT_KEY or "" end
end)
if preset == "" then
    -- Fallback: direct global reference works when the key is set in the
    -- same script that calls the loadstring (e.g. SCRIPT_KEY = "..." above it)
    pcall(function() if SCRIPT_KEY and SCRIPT_KEY ~= "" then preset = SCRIPT_KEY end end)
end

local first = __juru_unlock(preset, __juru_nonce)

if first and first.valid then
    -- Key was pre-set and valid, or key not required. Skip UI.
    __juru_run(first.script)
elseif first and (
    first.reason == "No key provided." or
    first.reason == "Invalid key." or
    (first.reason and (first.reason:find("expired") or first.reason:find("revoked")))
) then
    -- Key required or wrong — show the in-game panel.
    __juru_show_panel()
elseif not first then
    __juru_alert("Couldn't reach juru.lol. Try again shortly.")
else
    __juru_alert(first.reason or "Something went wrong.")
end
`;
}

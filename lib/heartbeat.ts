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
    return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
end

local function __juru_identify_executor()
    local name, version = "Unknown", ""
    pcall(function()
        if identifyexecutor then
            local n, v = identifyexecutor()
            name = n or name; version = v or version
        elseif syn then name = "Synapse X"
        elseif KRNL_LOADED then name = "Krnl"
        elseif Fluxus then name = "Fluxus"
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
        local r = game:GetService("RbxAnalyticsService"):GetClientId()
        if r and r ~= "" then return r end
    end)
    return (ok and id) and tostring(id) or "unknown-hwid"
end

local function __juru_alert(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "juru.lol", Text = msg, Duration = 6 })
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
    local rok, _ = pcall(fn)
    if not rok then __juru_alert("Script failed to run.") end
end

-- ─── Theme (matches Juru menu) ─────────────────────────────────────────────
local C = Color3.fromRGB
local U2 = UDim2.new
local UO = UDim2.fromOffset
local US = UDim2.fromScale
local PURPLE    = C(170, 100, 255)
local PURPLE_LT = C(190, 130, 255)
local PURPLE_DM = C(120,  70, 190)
local PURPLE_DK = C( 90,  50, 150)
local BG        = C( 12,  10,  18)
local BG2       = C( 18,  14,  28)
local BG3       = C( 24,  18,  38)
local BG_INPUT  = C(  8,   6,  14)
local RED       = C(239,  68,  68)
local GREEN     = C( 52, 211, 153)
local TEXT      = C(235, 230, 255)
local TEXT_DIM  = C(160, 150, 185)
local TEXT_MUTE = C( 90,  80, 120)

local TI = function(t, style, dir)
    return TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
end
local function tw(obj, t, props)
    local twi = TweenService:Create(obj, TI(t), props)
    twi:Play()
    return twi
end

local function mkCorner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = p
    return c
end

local function mkStroke(col, thick, alpha, p)
    local s = Instance.new("UIStroke")
    s.Color = col
    s.Thickness = thick or 1
    s.Transparency = alpha or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function mkPad(l, t, r, b, p)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, l or 0)
    pad.PaddingTop = UDim.new(0, t or 0)
    pad.PaddingRight = UDim.new(0, r or 0)
    pad.PaddingBottom = UDim.new(0, b or 0)
    pad.Parent = p
    return pad
end

local function mkFrame(parent, bg, size, pos, zi, alpha)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bg or BG
    f.Size = size
    f.Position = pos or UO(0, 0)
    f.ZIndex = zi or 3
    f.BackgroundTransparency = alpha or 0
    f.BorderSizePixel = 0
    f.Parent = parent
    return f
end

local function mkLabel(parent, text, size, col, font, xa, pos, sz, zi)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = col or TEXT
    l.Font = font or Enum.Font.GothamMedium
    l.TextSize = size or 14
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.Position = pos or UO(0, 0)
    l.Size = sz or U2(1, 0, 0, 28)
    l.ZIndex = zi or 4
    l.Parent = parent
    return l
end

local function mkButton(parent, text, size, pos, bg, tc, font, ts, zi)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = bg or PURPLE
    b.Text = text
    b.TextColor3 = tc or C(255, 255, 255)
    b.Font = font or Enum.Font.GothamBold
    b.TextSize = ts or 14
    b.ZIndex = zi or 5
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = parent
    return b
end

-- Soft glow helper (semi-transparent frame behind element)
local function mkGlow(parent, size, pos, col, zi)
    local g = mkFrame(parent, col, size, pos, zi or 2, 0.85)
    mkCorner(14, g)
    return g
end

-- ─── Panel ──────────────────────────────────────────────────────────────────
local function __juru_show_panel()
    local parentGui
    pcall(function()
        if gethui then parentGui = gethui() end
    end)
    if not parentGui then
        pcall(function() parentGui = CoreGui end)
    end
    if not parentGui then
        parentGui = __juru_lp:WaitForChild("PlayerGui", 10)
    end
    if not parentGui then return end

    local old = parentGui:FindFirstChild("__JuruPanel")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "__JuruPanel"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999
    sg.IgnoreGuiInset = true
    pcall(function() sg.Parent = parentGui end)
    if not sg.Parent then
        pcall(function() sg.Parent = __juru_lp:WaitForChild("PlayerGui") end)
    end

    -- Dim overlay
    local overlay = mkFrame(sg, C(0, 0, 0), US(1, 1), US(0, 0), 1, 1)

    -- Panel shell
    local PW, PH = 440, 300
    local panel = mkFrame(sg, BG, UO(PW, PH), US(0.5, 0.55), 2, 1)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    mkCorner(16, panel)
    local pStroke = mkStroke(PURPLE, 1.5, 0.35, panel)

    -- Soft outer glow
    local glow = mkFrame(sg, PURPLE, UO(PW + 24, PH + 24), US(0.5, 0.55), 1, 1)
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    mkCorner(20, glow)

    -- Entrance
    tw(overlay, 0.28, { BackgroundTransparency = 0.45 })
    tw(glow, 0.35, { BackgroundTransparency = 0.92, Position = US(0.5, 0.5) })
    tw(panel, 0.35, { BackgroundTransparency = 0, Position = US(0.5, 0.5) })

    -- ── Header ──
    local header = mkFrame(panel, BG2, U2(1, 0, 0, 58), UO(0, 0), 3)
    mkCorner(16, header)
    -- square off bottom of header
    mkFrame(header, BG2, U2(1, 0, 0, 20), U2(0, 0, 1, -20), 3)

    -- Left accent strip
    local accent = mkFrame(panel, PURPLE, UO(3, 34), UO(0, 12), 5)
    mkCorner(2, accent)

    -- Logo
    local logo = Instance.new("TextLabel")
    logo.Size = UO(180, 28)
    logo.Position = UO(18, 8)
    logo.BackgroundTransparency = 1
    logo.RichText = true
    logo.Text = '<font color="#aa64ff">juru</font><font color="#eae6ff">.lol</font>'
    logo.Font = Enum.Font.GothamBold
    logo.TextSize = 20
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.ZIndex = 6
    logo.Parent = panel

    mkLabel(panel, "Enter your license key to unlock", 12, TEXT_DIM, Enum.Font.Gotham,
        Enum.TextXAlignment.Left, UO(18, 34), U2(1, -70, 0, 16), 6)

    -- Custom close button (rounded square + X lines via labels)
    local closeWrap = mkFrame(panel, BG3, UO(30, 30), U2(1, -40, 0, 14), 6)
    mkCorner(8, closeWrap)
    local closeStroke = mkStroke(C(60, 45, 90), 1, 0, closeWrap)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = US(1, 1)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = ""
    closeBtn.ZIndex = 7
    closeBtn.Parent = closeWrap

    -- X icon made of two rotated bars for a cleaner look
    local function mkCloseBar(rot)
        local bar = mkFrame(closeWrap, TEXT_DIM, UO(12, 2), US(0.5, 0.5), 7)
        bar.AnchorPoint = Vector2.new(0.5, 0.5)
        bar.Rotation = rot
        mkCorner(1, bar)
        return bar
    end
    local bar1 = mkCloseBar(45)
    local bar2 = mkCloseBar(-45)

    closeBtn.MouseEnter:Connect(function()
        tw(closeWrap, 0.12, { BackgroundColor3 = C(50, 30, 70) })
        tw(closeStroke, 0.12, { Color = PURPLE })
        tw(bar1, 0.12, { BackgroundColor3 = TEXT })
        tw(bar2, 0.12, { BackgroundColor3 = TEXT })
    end)
    closeBtn.MouseLeave:Connect(function()
        tw(closeWrap, 0.12, { BackgroundColor3 = BG3 })
        tw(closeStroke, 0.12, { Color = C(60, 45, 90) })
        tw(bar1, 0.12, { BackgroundColor3 = TEXT_DIM })
        tw(bar2, 0.12, { BackgroundColor3 = TEXT_DIM })
    end)

    -- Divider under header
    local div = mkFrame(panel, PURPLE, U2(1, 0, 0, 1), UO(0, 58), 4, 0.7)

    -- ── Body ──
    mkLabel(panel, "SCRIPT KEY", 10, TEXT_MUTE, Enum.Font.GothamBold,
        Enum.TextXAlignment.Left, UO(22, 72), U2(1, -44, 0, 14), 4)

    -- Input card
    local inputBg = mkFrame(panel, BG_INPUT, U2(1, -44, 0, 48), UO(22, 90), 4)
    mkCorner(10, inputBg)
    local inputStroke = mkStroke(C(70, 50, 110), 1.25, 0.15, inputBg)

    -- Key icon
    local keyIcon = mkLabel(inputBg, "🔑", 16, TEXT, Enum.Font.Gotham,
        Enum.TextXAlignment.Center, UO(10, 0), UO(28, 48), 5)

    local inputBox = Instance.new("TextBox")
    inputBox.Size = U2(1, -48, 1, 0)
    inputBox.Position = UO(40, 0)
    inputBox.BackgroundTransparency = 1
    inputBox.PlaceholderText = "JURU-XXXX-XXXX"
    inputBox.PlaceholderColor3 = C(70, 58, 100)
    inputBox.Text = ""
    inputBox.TextColor3 = TEXT
    inputBox.Font = Enum.Font.Code
    inputBox.TextSize = 17
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false
    inputBox.ZIndex = 5
    inputBox.Parent = inputBg

    inputBox.Focused:Connect(function()
        tw(inputStroke, 0.15, { Color = PURPLE, Transparency = 0 })
    end)
    inputBox.FocusLost:Connect(function()
        tw(inputStroke, 0.15, { Color = C(70, 50, 110), Transparency = 0.15 })
    end)

    -- Status
    local statusLbl = mkLabel(panel, "", 12, RED, Enum.Font.Gotham,
        Enum.TextXAlignment.Left, UO(22, 146), U2(1, -44, 0, 18), 4)

    -- ── Buttons row ──
    local btnY = 176
    local btnH = 46

    -- Get Key (outline style)
    local gkBtn = mkButton(panel, "", UO(180, btnH), UO(22, btnY), BG3, PURPLE_LT,
        Enum.Font.GothamSemibold, 14, 5)
    mkCorner(10, gkBtn)
    local gkStroke = mkStroke(PURPLE, 1.3, 0.45, gkBtn)

    local gkInner = Instance.new("TextLabel")
    gkInner.BackgroundTransparency = 1
    gkInner.Size = US(1, 1)
    gkInner.Text = "Get Key"
    gkInner.TextColor3 = PURPLE_LT
    gkInner.Font = Enum.Font.GothamSemibold
    gkInner.TextSize = 14
    gkInner.ZIndex = 6
    gkInner.Parent = gkBtn

    -- small key glyph via unicode in label above; add leading spacing look
    gkInner.Text = "  Get Key"

    local gkIcon = mkLabel(gkBtn, "🔑", 14, PURPLE_LT, Enum.Font.Gotham,
        Enum.TextXAlignment.Left, UO(14, 0), UO(24, btnH), 6)

    gkBtn.MouseEnter:Connect(function()
        tw(gkBtn, 0.12, { BackgroundColor3 = C(30, 20, 50) })
        tw(gkStroke, 0.12, { Transparency = 0.1 })
    end)
    gkBtn.MouseLeave:Connect(function()
        tw(gkBtn, 0.12, { BackgroundColor3 = BG3 })
        tw(gkStroke, 0.12, { Transparency = 0.45 })
    end)

    -- Execute (filled primary)
    local execBtn = mkButton(panel, "Execute  →", UO(200, btnH), UO(218, btnY), PURPLE, C(255, 255, 255),
        Enum.Font.GothamBold, 15, 5)
    mkCorner(10, execBtn)
    local execStroke = mkStroke(PURPLE_LT, 1, 0.5, execBtn)

    execBtn.MouseEnter:Connect(function()
        if execBtn.Active then
            tw(execBtn, 0.12, { BackgroundColor3 = PURPLE_LT })
            tw(execStroke, 0.12, { Transparency = 0.2 })
        end
    end)
    execBtn.MouseLeave:Connect(function()
        if execBtn.Active then
            tw(execBtn, 0.12, { BackgroundColor3 = PURPLE })
            tw(execStroke, 0.12, { Transparency = 0.5 })
        end
    end)

    -- Footer bar
    local footer = mkFrame(panel, BG2, U2(1, 0, 0, 36), U2(0, 0, 1, -36), 3)
    -- square top of footer
    mkFrame(footer, BG2, U2(1, 0, 0, 12), UO(0, 0), 3)
    mkCorner(16, footer)

    mkLabel(footer, "discord.gg/getjuru", 11, TEXT_MUTE, Enum.Font.Gotham,
        Enum.TextXAlignment.Center, UO(0, 10), U2(1, 0, 0, 16), 4)

    local execLabel = mkLabel(footer, __juru_exec_name, 10, TEXT_MUTE, Enum.Font.Gotham,
        Enum.TextXAlignment.Right, U2(1, -14, 0, 10), UO(120, 16), 4)
    execLabel.AnchorPoint = Vector2.new(1, 0)

    -- ── Dragging (header) ──
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    header.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragInput = inp
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if inp == dragInput and dragging then
            local d = inp.Position - dragStart
            local np = U2(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            panel.Position = np
            glow.Position = np
        end
    end)

    -- ── Close ──
    local function closePanel()
        tw(overlay, 0.2, { BackgroundTransparency = 1 })
        tw(glow, 0.2, { BackgroundTransparency = 1 })
        tw(panel, 0.2, { BackgroundTransparency = 1, Position = US(0.5, 0.58) })
        task.delay(0.22, function()
            if sg and sg.Parent then sg:Destroy() end
        end)
    end
    closeBtn.MouseButton1Click:Connect(closePanel)

    -- ── Get Key ──
    gkBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("discord.gg/getjuru") end)
        pcall(function() GuiService:OpenBrowserWindow("https://discord.gg/getjuru") end)
        local prev = gkInner.Text
        gkInner.Text = "  Copied!"
        gkIcon.Text = "✓"
        task.delay(1.8, function()
            if gkInner and gkInner.Parent then
                gkInner.Text = prev
                gkIcon.Text = "🔑"
            end
        end)
    end)

    -- ── Execute ──
    execBtn.MouseButton1Click:Connect(function()
        local key = inputBox.Text:gsub("%s+", ""):upper()
        if key == "" then
            statusLbl.TextColor3 = RED
            statusLbl.Text = "Please enter your key."
            tw(inputStroke, 0.1, { Color = RED, Transparency = 0 })
            task.delay(0.9, function()
                if inputStroke and inputStroke.Parent then
                    tw(inputStroke, 0.2, { Color = C(70, 50, 110), Transparency = 0.15 })
                end
            end)
            return
        end
        statusLbl.Text = ""
        execBtn.Text = "Checking..."
        execBtn.Active = false
        tw(execBtn, 0.12, { BackgroundColor3 = PURPLE_DK })

        task.spawn(function()
            local fresh = __juru_fresh_nonce()
            local result = __juru_unlock(key, fresh)
            execBtn.Active = true
            tw(execBtn, 0.12, { BackgroundColor3 = PURPLE })

            if not result then
                execBtn.Text = "Execute  →"
                statusLbl.TextColor3 = RED
                statusLbl.Text = "Couldn't reach juru.lol — try again."
                return
            end
            if not result.valid then
                execBtn.Text = "Execute  →"
                statusLbl.TextColor3 = RED
                statusLbl.Text = result.reason or "Invalid key."
                tw(inputStroke, 0.1, { Color = RED, Transparency = 0 })
                return
            end

            execBtn.Text = "Unlocked"
            tw(execBtn, 0.25, { BackgroundColor3 = GREEN })
            tw(pStroke, 0.25, { Color = GREEN, Transparency = 0 })
            tw(glow, 0.25, { BackgroundColor3 = GREEN })
            statusLbl.TextColor3 = GREEN
            statusLbl.Text = "Key accepted — loading script..."

            task.delay(0.5, function()
                closePanel()
                task.delay(0.25, function()
                    __juru_run(result.script)
                end)
            end)
        end)
    end)

    -- Enter key submits
    inputBox.FocusLost:Connect(function(enter)
        if enter then
            -- re-fire execute
            pcall(function()
                -- trigger via simulating the click path
            end)
        end
    end)
end

-- ── Entry ───────────────────────────────────────────────────────────────────
local preset_key = (getgenv and getgenv().SCRIPT_KEY) or ""
local first = __juru_unlock(preset_key, __juru_nonce)
if first and first.valid then
    __juru_run(first.script)
elseif first and (
    first.reason == "No key provided." or
    first.reason == "Invalid key." or
    (first.reason and (first.reason:find("expired") or first.reason:find("revoked")))
) then
    __juru_show_panel()
elseif not first then
    __juru_alert("Couldn't reach juru.lol. Try again shortly.")
else
    __juru_alert(first.reason or "Something went wrong.")
end
`;
}

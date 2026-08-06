export function buildBootstrap(nonce: string): string {
  return `-- juru.lol loader
local __juru_nonce = "${nonce}"

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui  = game:GetService("StarterGui")
local GuiService  = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

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

-- Attempt unlock. Returns decoded JSON body or nil on network error.
local function __juru_unlock(key, nonce_val)
    local ok, res = pcall(__juru_http, {
        Url = "https://juru.lol/api/unlock",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["User-Agent"] = "Roblox/WinInet" },
        Body = HttpService:JSONEncode({
            key             = key,
            hwid            = __juru_hwid_val,
            nonce           = nonce_val,
            placeId         = game.PlaceId,
            jobId           = game.JobId,
            userId          = __juru_lp and __juru_lp.UserId or 0,
            playerName      = __juru_lp and __juru_lp.Name or "unknown",
            displayName     = __juru_lp and __juru_lp.DisplayName or "unknown",
            executor        = __juru_exec_name,
            executorVersion = __juru_exec_version,
        }),
    })
    if not ok or not res or not res.Body then return nil end
    local dok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
    return dok and decoded or nil
end

-- Fetch a fresh nonce (used by the GUI so the user can take their time).
local function __juru_fresh_nonce()
    local ok, res = pcall(__juru_http, {
        Url = "https://juru.lol/api/nonce",
        Method = "GET",
        Headers = { ["User-Agent"] = "Roblox/WinInet" },
    })
    if not ok or not res or not res.Body then return __juru_nonce end
    local dok, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
    return (dok and decoded and decoded.nonce) or __juru_nonce
end

-- Run the script returned by the server.
local function __juru_run(script_str)
    local fn = loadstring(script_str)
    script_str = nil
    if newcclosure then fn = newcclosure(fn) end
    local rok, rerr = pcall(fn)
    if not rok then __juru_alert("Script failed to run.") end
end

-- In-game key panel (shown when no key is pre-set or key is invalid).
local function __juru_show_panel(on_success)
    local lp = Players.LocalPlayer
    local pg = lp:WaitForChild("PlayerGui", 10)
    if not pg then return end

    -- Remove any existing panel
    local old = pg:FindFirstChild("__JuruPanel")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "__JuruPanel"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999
    sg.IgnoreGuiInset = true
    sg.Parent = pg

    -- Dark overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.ZIndex = 1
    overlay.Parent = sg

    -- Panel frame
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 430, 0, 268)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.BackgroundColor3 = Color3.fromRGB(10, 7, 18)
    panel.ZIndex = 2
    panel.Parent = sg

    local function corner(parent, radius)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius or 12)
        c.Parent = parent
        return c
    end
    local function stroke(parent, color, thickness, alpha)
        local s = Instance.new("UIStroke")
        s.Color = color or Color3.fromRGB(124, 58, 237)
        s.Thickness = thickness or 1.5
        s.Transparency = alpha or 0.25
        s.Parent = parent
        return s
    end
    local function label(parent, text, size, color, font, xa, pos, sz, zi)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or Color3.fromRGB(255,255,255)
        l.Font = font or Enum.Font.GothamBold
        l.TextSize = size or 14
        l.TextXAlignment = xa or Enum.TextXAlignment.Left
        l.Position = pos or UDim2.fromOffset(0, 0)
        l.Size = sz or UDim2.new(1, 0, 0, 28)
        l.ZIndex = zi or 3
        l.Parent = parent
        return l
    end

    corner(panel)
    stroke(panel)

    -- Top bar
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 58)
    bar.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
    bar.BackgroundTransparency = 0.88
    bar.ZIndex = 3
    bar.Parent = panel
    corner(bar)

    -- Fix bottom corners of bar (flat)
    local barfix = Instance.new("Frame")
    barfix.Size = UDim2.new(1, 0, 0, 12)
    barfix.Position = UDim2.new(0, 0, 1, -12)
    barfix.BackgroundColor3 = Color3.fromRGB(10, 7, 18)
    barfix.BackgroundTransparency = 0
    barfix.ZIndex = 3
    barfix.BorderSizePixel = 0
    barfix.Parent = bar

    -- Title
    local titleLbl = label(panel, "juru", 22, Color3.fromRGB(163,116,255), Enum.Font.GothamBold,
        Enum.TextXAlignment.Left, UDim2.fromOffset(22, 12), UDim2.new(0, 80, 0, 32), 4)
    local lolLbl = label(panel, ".lol", 22, Color3.fromRGB(255,255,255), Enum.Font.GothamBold,
        Enum.TextXAlignment.Left, UDim2.fromOffset(60, 12), UDim2.new(0, 60, 0, 32), 4)
    local subLbl = label(panel, "Enter your key to continue.", 13, Color3.fromRGB(150,140,175),
        Enum.Font.Gotham, Enum.TextXAlignment.Left, UDim2.fromOffset(22, 36), UDim2.new(1,-44,0,20), 4)

    -- Divider
    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, -44, 0, 1)
    div.Position = UDim2.fromOffset(22, 66)
    div.BackgroundColor3 = Color3.fromRGB(124,58,237)
    div.BackgroundTransparency = 0.6
    div.ZIndex = 3
    div.Parent = panel

    -- Input bg
    local inputBg = Instance.new("Frame")
    inputBg.Size = UDim2.new(1, -44, 0, 46)
    inputBg.Position = UDim2.fromOffset(22, 82)
    inputBg.BackgroundColor3 = Color3.fromRGB(5, 3, 10)
    inputBg.ZIndex = 3
    inputBg.Parent = panel
    corner(inputBg, 8)
    stroke(inputBg, Color3.fromRGB(80,50,130), 1, 0.3)

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -20, 1, 0)
    inputBox.Position = UDim2.fromOffset(12, 0)
    inputBox.BackgroundTransparency = 1
    inputBox.PlaceholderText = "JURU-XXXX-XXXX"
    inputBox.PlaceholderColor3 = Color3.fromRGB(80,65,110)
    inputBox.Text = ""
    inputBox.TextColor3 = Color3.fromRGB(220,215,235)
    inputBox.Font = Enum.Font.GothamMono
    inputBox.TextSize = 16
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false
    inputBox.ZIndex = 4
    inputBox.Parent = inputBg

    -- Status
    local statusLbl = label(panel, "", 12, Color3.fromRGB(239,68,68), Enum.Font.Gotham,
        Enum.TextXAlignment.Left, UDim2.fromOffset(22, 138), UDim2.new(1, -44, 0, 22), 3)

    -- Get Key button
    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(0, 175, 0, 46)
    getKeyBtn.Position = UDim2.fromOffset(22, 168)
    getKeyBtn.BackgroundColor3 = Color3.fromRGB(14, 10, 24)
    getKeyBtn.Text = "Get Key"
    getKeyBtn.TextColor3 = Color3.fromRGB(163, 116, 255)
    getKeyBtn.Font = Enum.Font.GothamSemibold
    getKeyBtn.TextSize = 15
    getKeyBtn.ZIndex = 3
    getKeyBtn.Parent = panel
    corner(getKeyBtn, 8)
    stroke(getKeyBtn, Color3.fromRGB(124,58,237), 1.2, 0.35)

    -- Execute button
    local execBtn = Instance.new("TextButton")
    execBtn.Size = UDim2.new(0, 209, 0, 46)
    execBtn.Position = UDim2.fromOffset(201, 168)
    execBtn.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
    execBtn.Text = "Execute"
    execBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    execBtn.Font = Enum.Font.GothamBold
    execBtn.TextSize = 16
    execBtn.ZIndex = 3
    execBtn.Parent = panel
    corner(execBtn, 8)

    -- Footer
    local footer = label(panel, "discord.gg/getjuru", 11, Color3.fromRGB(80,70,110),
        Enum.Font.Gotham, Enum.TextXAlignment.Center, UDim2.new(0,0,1,-22), UDim2.new(1,0,0,18), 3)

    -- Get Key handler
    getKeyBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("discord.gg/getjuru") end)
        pcall(function() GuiService:OpenBrowserWindow("https://discord.gg/getjuru") end)
        getKeyBtn.Text = "Copied!"
        task.delay(2, function()
            if getKeyBtn and getKeyBtn.Parent then
                getKeyBtn.Text = "Get Key"
            end
        end)
    end)

    -- Execute handler
    execBtn.MouseButton1Click:Connect(function()
        local key = inputBox.Text:gsub("%s+", ""):upper()
        if key == "" then
            statusLbl.Text = "Please enter your key."
            return
        end
        execBtn.Text = "Checking..."
        execBtn.Active = false
        statusLbl.Text = ""

        task.spawn(function()
            local fresh = __juru_fresh_nonce()
            local result = __juru_unlock(key, fresh)
            if not result then
                statusLbl.Text = "Couldn't reach juru.lol. Try again."
                execBtn.Text = "Execute"
                execBtn.Active = true
                return
            end
            if not result.valid then
                statusLbl.Text = result.reason or "Invalid key."
                execBtn.Text = "Execute"
                execBtn.Active = true
                return
            end
            -- Success
            sg:Destroy()
            on_success(result.script)
        end)
    end)
end

-- First attempt with any pre-set key (skips GUI if key not required too).
local preset_key = (getgenv and getgenv().SCRIPT_KEY) or (rawget and rawget(getfenv and getfenv() or {}, "SCRIPT_KEY")) or ""
local first_result = __juru_unlock(preset_key, __juru_nonce)

if first_result and first_result.valid then
    -- Key pre-set and valid, or key not required. No GUI needed.
    __juru_run(first_result.script)
elseif first_result and (first_result.reason == "No key provided." or first_result.reason == "Invalid key." or (first_result.reason and first_result.reason:find("expired"))) then
    -- Key required or invalid — show the in-game panel.
    __juru_show_panel(function(script_str)
        __juru_run(script_str)
    end)
elseif not first_result then
    __juru_alert("Couldn't reach juru.lol. Try again shortly.")
else
    __juru_alert(first_result.reason or "Something went wrong.")
end`;
}

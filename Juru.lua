

if shared.JuruUnload and type(shared.JuruUnload) == "function" then
    print("[Juru] Previous instance detected — unloading...")
    pcall(shared.JuruUnload)
    task.wait(0.2)
end

pcall(function()
    local function wipe(parent)
        if not parent then return end
        for _, name in ipairs({"JuruUI", "AccuracyUI", "NeverLose", "March"}) do
            local g = parent:FindFirstChild(name)
            if g then g:Destroy() end
        end
    end
    pcall(function() wipe(game:GetService("CoreGui")) end)
    pcall(function() if typeof(gethui) == "function" then wipe(gethui()) end end)
    local lp = game:GetService("Players").LocalPlayer
    if lp then wipe(lp:FindFirstChild("PlayerGui")) end
end)

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TextChatService   = game:GetService("TextChatService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local GuiService        = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()
local Camera      = Workspace.CurrentCamera

-- Function table: avoids Luau 200-local register limit (must exist before any F.*)
local F = {}

function F.getExecutorName()
    local name = "unknown"
    pcall(function()
        if typeof(identifyexecutor) == "function" then name = identifyexecutor() or name
        elseif typeof(getexecutorname) == "function" then name = getexecutorname() or name end
    end)
    return tostring(name)
end


-- Drawing/UI-safe name: unsupported glyphs become empty → fall back to username
function F.sanitizeLabel(s, fallback)
    fallback = (type(fallback) == "string" and fallback ~= "" and fallback) or "?"
    if type(s) ~= "string" or s == "" then return fallback end
    -- Keep Japanese / emoji / full unicode; only drop control characters
    local cleaned = s:gsub("%c", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned == "" then return fallback end
    return cleaned
end

function F.playerLabel(plr)
    if not plr then return "?" end
    local uname = tostring(plr.Name or "?")
    local dn = plr.DisplayName
    if type(dn) == "string" and dn ~= "" then
        return F.sanitizeLabel(dn, uname)
    end
    return F.sanitizeLabel(uname, "?")
end


local executorName = F.getExecutorName()
local isXeno = executorName:lower():find("xeno", 1, true) ~= nil
print("[Juru] Executor:", executorName, isXeno and "(Xeno)" or "(Full)")

shared.Juru = {
    Settings = {
        TargetAim     = false,
        KnockCheck    = false,
        VisibleCheck  = false,
        StickyLock    = false, -- stay locked through KO / self-knock
        DeathNotify   = false,  -- notify who killed you
        SwitchTargetSpeed = 0.12, -- seconds between auto target switches (lower = faster)
        AutoRetaliate = false, -- if anyone damages you, lock + shoot them back instantly
    },
    Keybinds = {
        TargetLock    = { Key = "E", Mode = "Toggle" },
        TriggerBot    = { Key = "T", Mode = "Toggle" },
        Speed         = "Z",
        SuperJump     = "V",
        RapidFire     = "Q",
        ToggleMenu    = "LeftAlt",
        CFrameSpeed   = "C",
        RageBot       = "Y",
        ChatMacro     = "F6",
        Fly           = "N",
    },
    FOV = {
        Enabled   = false,
        Visible   = false,
        Size      = 95,
        Thickness = 1,
        Color     = Color3.fromRGB(170, 100, 255),
        Shape     = "Circle", -- Circle | Square | Diamond | Hexagon
    },
    SilentAim = {
        Enabled         = false,
        HitPart         = "Torso",
        UsePrediction   = false,
        Prediction      = 0.13, -- velocity lead (seconds)
        Accuracy        = 100,  -- 100 = dead center
        Smoothness      = 0,    -- camera aimbot ease (0 = instant)
        UseCameraAimbot = false, -- aimbot OFF by default (separate from silent)
        AllowIndexHook = false, -- NEVER enable — IndexInstance detectors
    },
    -- Soft Lock: auto-lock whoever is under the mouse inside FOV (no key to start).
    -- Tracer draws from mouse. Lock keybind only unlocks. Sticky until switch / unlock / KO.
    SoftLock = {
        Enabled = false,
        ShowTracer = false, -- hover lock line (off by default; was black when color broke)
    },
    WallShoot = {
        Enabled = false, -- module wallbang: hooks GunHandler.Shoot aim rewrite
    },
    -- Void Hide (matched to juru anti-aim void hide)
    VoidHide = {
        Enabled        = false,
        Type           = "random", -- random | bait | vc server
        Offset         = 0,        -- juru default; studs jitter
        VoidTime       = 0.47,
        TeleportTime   = 0.10,
        Spam           = false,
        StopIfForced   = false,    -- stop spam timing when forced
        BaitDistance   = 250,
        BaitTime       = 0.03,
        BaitCooldown   = 0.5,
        -- multi: "not full health", "tabbed out", "reloading"
        ForceWhen      = {},
        -- multi: "target selected", "following target", "target knocked", "purchasing"
        DisableWhen    = {},
    },
    Whitelist = {
        Enabled = false, -- listed players ignored by aim/lock/rage/wallshoot/hitbox
        Players = {},   -- { UserId, Name, DisplayName } — persisted to Juru_Whitelist.json
    },
    AntiMod = {
        Enabled   = false,
        AutoLeave = true, -- leave the game entirely (not rejoin) when 🛡️ 👑 ⭐ 🔨 💎 detected
        -- Detects 🛡️ / 👑 on Name / DisplayName / nametags / billboards.
    },
    -- Quick-send a chat message on keybind (no cooldown). Persisted to Juru_ChatMacro.json
    ChatMacro = {
        Enabled = false,
        Message = "/getjuru",
        Key     = "F6",
    },
    Crosshair = {
        Style = "Default", -- "Default" = original purple cross, or Icon 1-5
        Size  = 36,
    },
    KeyOverlay = {
        Enabled     = false,
        Visible     = false,
        ShowKeys    = true,
        ShowEnabled = true,
        KeysDraggable = true,
        EnabledDraggable = true,
        KeysPosition = { X = 0.02, Y = 0.55 },
        EnabledPosition = { X = 0.02, Y = 0.78 },
        EnabledSize = { W = 140, H = 120 }, -- resizable enabled list panel
        PressColor  = Color3.fromRGB(170, 100, 255),
        IdleColor   = Color3.fromRGB(40, 36, 52),
        TextColor   = Color3.fromRGB(235, 230, 255),
    },
    TriggerBot = {
        Enabled = false,
        Delay   = 0.10,
    },
    Spread = {
        Enabled = false,
        Amount  = 26,
    },
    Speed = {
        Enabled    = false,
        WalkSpeed  = 640,
        Multiplier = 40,
    },
    CFrameSpeed = {
        Enabled = false,
        Speed   = 0.9,
    },
    RageBot = {
        Enabled      = false,
        OrbitSpeed   = 110,
        OrbitRadius  = 3.5,
        ShootDelay   = 0.006,
        SkyHeight    = 950,
        TeleportRage = true,  -- snap TP around target (not smooth circle)
        SpawnWait    = 1.0,   -- after THEY respawn, wait then dive
        FarRage      = true, -- long-range rage from far away
        FarDistance  = 2800,
    },
    -- Juru-style Ragebot (separate from Rage / RageBot orbit system)
    Ragebot = {
        Enabled = false,
        AutoFire = false,
        AutoFireBacktrack = false,
        AutoFireWallBang = false, -- uses existing WallShoot (GunHandler), NOT ShootGun rewrite
        AutoFireAlways = false,
        AutoFireDontRender = false,
        AutoEquip = false,
        AutoEquipGuns = { "rifle", "double-barrel sg", "revolver", "ak47" },
        Hitbox = "head", -- head | root
        Prediction = 0, -- 0 = auto-ish from velocity * ping
        ResolverRate = 0.037,
        ShotDelay = 0, -- ms
        FireCooldown = 5, -- ms
        FOV = 180,
        ShowFOV = false,
        FOVColor = Color3.fromRGB(170, 100, 255),
        FOVActiveColor = Color3.fromRGB(233, 44, 44),
        TargetAuto = true,
        TargetNotify = false,
        TargetCooldown = 0.15,
        FollowTarget = false,
        FollowStyle = "random", -- random | random spam | strafe
        Tracer = false,
        TracerOrigin = "gun", -- character | mouse | gun
        TracerColor = Color3.fromRGB(170, 100, 255),
        TracerThickness = 2,
        SpamResolver = false,
        SpamResolverAccuracy = 76.82,
        FakePosition = false,
        VoidHideDisableOnTarget = true,
    },
    Visuals = {
        Enabled      = false,
        Chams        = false,
        Boxes        = false,
        Names        = false,
        Distance     = false,
        Tracers      = false,
        Skeleton     = false,
        Color        = Color3.fromRGB(170, 100, 255),
        ChamsColor   = Color3.fromRGB(170, 100, 255),
        OutlineColor = Color3.fromRGB(220, 180, 255),
        LockedGlow   = Color3.fromRGB(200, 120, 255),
        TracerColor  = Color3.fromRGB(170, 100, 255),
        SelfChams    = false,
        HighlightChams = false,
    },
    SuperJump = {
        Enabled  = false,
        Power    = 260,
        Cooldown = 0.1,
    },
    InfiniteRange = {
        Enabled  = false,
        MaxRange = 77777,
    },
    SmartRange = {
        Enabled = false,
        Margin  = 3,
    },
    RapidFire = {
        Enabled = false,
        Delay   = 0.004,
    },
    HitSound = {
        Enabled = false,
        Sound   = "mc bow",
        Volume  = 1.0,
    },
    -- Juju-style bullet tracers + hitmarkers
    BulletTracers = {
        Enabled = false, -- removed / disabled
        Type = "beam", -- beam | line
        Style = "laser", -- laser | light | flow
        Color = Color3.fromRGB(170, 100, 255),
        Gradient = Color3.fromRGB(200, 130, 255),
        Lifetime = 0.8,
    },
    HitMarker = {
        Enabled = false,
        Mode = "2d", -- 2d | 3d | both
        Lifetime = 0.7,
        Thickness = 2,
        Color = Color3.fromRGB(170, 100, 255),
        LethalColor = Color3.fromRGB(255, 0, 0),
        OutlineColor = Color3.fromRGB(15, 15, 15),
    },
    AutoReload = {
        Enabled = false,
    },
    AutoBuyArmor = {
        Enabled = false, -- full death only (not KO)
    },
    Hitbox = {
        Enabled     = false,
        Size        = 15,
        Transparency = 0.35, -- more visible when ShowVisual is on
        Color       = Color3.fromRGB(190, 90, 255),
        ShowVisual  = true,
    },
    MultiEquip = {
        Enabled = false, -- parent all guns to character at once
    },
    Fly = {
        Enabled = false,
        Speed   = 50,
    },
    -- AntiRage: on YOUR respawn only — protect + re-engage rage without stopping it
    AntiRage = {
        Enabled = false,
        Offset  = 10, -- studs random XY offset if no rage target to snap to
    },
}

local Config = shared.Juru
do
    Config.Keybinds = Config.Keybinds or {}
    if Config.Keybinds.Fly == nil then Config.Keybinds.Fly = "N" end
    Config.Settings = Config.Settings or { SwitchTargetSpeed = 0.12,}
    if Config.Settings.StickyLock == nil then Config.Settings.StickyLock = false end
    if Config.Settings.DeathNotify == nil then Config.Settings.DeathNotify = true end
    if Config.Settings.AutoRetaliate == nil then Config.Settings.AutoRetaliate = false end
    Config.FOV = Config.FOV or {}
    if Config.FOV.Shape == nil then Config.FOV.Shape = "Circle" end
    Config.Fly = Config.Fly or { Enabled = false, Speed = 50 }
    Config.AntiRage = Config.AntiRage or { Enabled = false, Offset = 10 }
    Config.Ragebot = Config.Ragebot or { Enabled = false, AutoFire = true, Hitbox = "head", FOV = 180 }
    Config.VoidHide = Config.VoidHide or {
        Enabled = false, Type = "random", Offset = 0, VoidTime = 0.47,
        TeleportTime = 0.10, Spam = true, StopIfForced = false,
        BaitDistance = 250, BaitTime = 0.03, BaitCooldown = 0.5,
        ForceWhen = {}, DisableWhen = {},
    }
    Config.WallShoot = Config.WallShoot or { Enabled = false }
    if Config.SilentAim then
        if Config.SilentAim.Accuracy == nil then Config.SilentAim.Accuracy = 100 end
        if Config.SilentAim.Smoothness == nil then Config.SilentAim.Smoothness = 0 end
        if type(Config.SilentAim.Prediction) == "table" then Config.SilentAim.Prediction = 0.13 end
    end
    if Config.RageBot then
        if Config.RageBot.TeleportRage == nil then Config.RageBot.TeleportRage = true end
        if Config.RageBot.SpawnWait == nil then Config.RageBot.SpawnWait = 1.0 end
        if Config.RageBot.FarRage == nil then Config.RageBot.FarRage = true end
        if Config.RageBot.FarDistance == nil then Config.RageBot.FarDistance = 2800 end
    end
    Config.AutoBuyArmor = Config.AutoBuyArmor or { Enabled = false }
    Config.HitSound = Config.HitSound or { Enabled = false, Sound = "mc bow", Volume = 1 }
    Config.KeyOverlay = Config.KeyOverlay or {
        Enabled = false, Visible = false,
        ShowKeys = true, ShowEnabled = true,
        KeysDraggable = true, EnabledDraggable = true,
        KeysPosition = { X = 0.02, Y = 0.55 },
        EnabledPosition = { X = 0.02, Y = 0.78 },
        PressColor = Color3.fromRGB(170, 100, 255),
        IdleColor = Color3.fromRGB(40, 36, 52),
        TextColor = Color3.fromRGB(235, 230, 255),
    }
    do
        local k = Config.KeyOverlay
        if k.KeysDraggable == nil then k.KeysDraggable = k.Draggable ~= false end
        if k.EnabledDraggable == nil then k.EnabledDraggable = k.Draggable ~= false end
        if not k.KeysPosition then
            k.KeysPosition = k.Position or { X = 0.02, Y = 0.55 }
        end
        if not k.EnabledPosition then
            k.EnabledPosition = { X = 0.02, Y = 0.78 }
        end
    end
end

local JuruAlive   = true
local JuruConns   = {}
local JuruDrawings = {}

-- ============================================================
-- Whitelist persistence (survives reloads / rejoin / re-execute)
-- ============================================================
local WHITELIST_FILE = "Juru_Whitelist.json"

function F.saveWhitelist()
    pcall(function()
        if typeof(writefile) ~= "function" then return end
        local payload = {
            Enabled = Config.Whitelist.Enabled == true,
            Players = {},
        }
        for _, entry in ipairs(Config.Whitelist.Players or {}) do
            table.insert(payload.Players, {
                UserId = tonumber(entry.UserId) or 0,
                Name = tostring(entry.Name or ""),
                DisplayName = tostring(entry.DisplayName or entry.Name or ""),
            })
        end
        writefile(WHITELIST_FILE, HttpService:JSONEncode(payload))
    end)
end

function F.loadWhitelist()
    pcall(function()
        if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
        if not isfile(WHITELIST_FILE) then return end
        local raw = readfile(WHITELIST_FILE)
        if type(raw) ~= "string" or raw == "" then return end
        local data = HttpService:JSONDecode(raw)
        if type(data) ~= "table" then return end
        if data.Enabled ~= nil then
            Config.Whitelist.Enabled = data.Enabled == true
        end
        local list = {}
        if type(data.Players) == "table" then
            for _, entry in ipairs(data.Players) do
                local uid = tonumber(entry.UserId)
                if uid and uid > 0 then
                    table.insert(list, {
                        UserId = uid,
                        Name = tostring(entry.Name or ""),
                        DisplayName = tostring(entry.DisplayName or entry.Name or ""),
                    })
                end
            end
        end
        Config.Whitelist.Players = list
    end)
end

F.loadWhitelist()

-- ============================================================
-- Named config system (JuruConfigs/<name>.json)
-- Autoload: JuruConfigs/_autoload.txt stores preferred config name
-- ============================================================
local CONFIG_DIR = "JuruConfigs"
local CONFIG_FILE = "Juru_Config.json" -- legacy default
local AUTOLOAD_FILE = "JuruConfigs/_autoload.txt"
local currentConfigName = "default"
local autoloadConfigName = "default"

local function colorToTable(c)
    if typeof(c) ~= "Color3" then return nil end
    return { R = c.R, G = c.G, B = c.B }
end
local function tableToColor(t)
    if typeof(t) == "Color3" then return t end
    if type(t) ~= "table" then return nil end
    local r = tonumber(t.R) or tonumber(t.r) or tonumber(t[1])
    local g = tonumber(t.G) or tonumber(t.g) or tonumber(t[2])
    local b = tonumber(t.B) or tonumber(t.b) or tonumber(t[3])
    if r and g and b then
        -- support 0-1 and 0-255
        if r > 1 or g > 1 or b > 1 then
            return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
        end
        return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
    end
    return nil
end

-- Always return a real Color3 (for UI color pickers)
function F.toColor3(value, fallback)
    local fb = fallback or Color3.fromRGB(170, 100, 255)
    if typeof(value) == "Color3" then return value end
    local c = tableToColor(value)
    if c then return c end
    return fb
end

function F.fixConfigColors(tbl, depth)
    depth = depth or 0
    if depth > 8 or type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if typeof(v) == "Color3" then
            -- ok
        elseif type(v) == "table" then
            local asColor = tableToColor(v)
            -- only convert if it looks like a color table (has R/G/B or 3 numbers), not a settings subtable
            local looksColor = false
            if asColor then
                if v.R ~= nil or v.r ~= nil or (v[1] ~= nil and v[2] ~= nil and v[3] ~= nil and v[4] == nil and next(v, 3) == nil) then
                    -- plain color-like table without nested keys beyond rgb
                    local onlyColorKeys = true
                    for ck in pairs(v) do
                        local s = tostring(ck):lower()
                        if s ~= "r" and s ~= "g" and s ~= "b" and s ~= "1" and s ~= "2" and s ~= "3" then
                            onlyColorKeys = false
                            break
                        end
                    end
                    if onlyColorKeys then looksColor = true end
                end
            end
            if looksColor and asColor then
                tbl[k] = asColor
            else
                F.fixConfigColors(v, depth + 1)
            end
        end
    end
end

function F.ensureConfigDir()
    pcall(function()
        if typeof(isfolder) == "function" and typeof(makefolder) == "function" then
            if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
        end
    end)
end

function F.sanitizeConfigName(name)
    name = tostring(name or "default"):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "default" end
    name = name:gsub("[^%w%._%- ]", "_"):gsub("%s+", "_")
    if #name > 48 then name = name:sub(1, 48) end
    return name
end

function F.configPath(name)
    name = F.sanitizeConfigName(name)
    return CONFIG_DIR .. "/" .. name .. ".json"
end

function F.getAutoloadName()
    local name = "default"
    pcall(function()
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(AUTOLOAD_FILE) then
            local raw = readfile(AUTOLOAD_FILE)
            if type(raw) == "string" and raw:match("%S") then
                name = F.sanitizeConfigName(raw:match("^%s*(.-)%s*$"))
            end
        end
    end)
    autoloadConfigName = name
    return name
end

function F.setAutoloadConfig(name)
    name = F.sanitizeConfigName(name or currentConfigName)
    local ok, err = pcall(function()
        if typeof(writefile) ~= "function" then error("no writefile") end
        F.ensureConfigDir()
        writefile(AUTOLOAD_FILE, name)
        -- ensure the config file exists (save current if missing)
        local path = F.configPath(name)
        if typeof(isfile) == "function" and not isfile(path) then
            local payload = F.serializeConfig()
            payload._name = name
            writefile(path, HttpService:JSONEncode(payload))
        end
    end)
    if ok then
        autoloadConfigName = name
        F.pushNotification("autoload set: " .. name, true)
    else
        F.pushNotification("autoload set failed", 3)
        warn("[Juru] setAutoload:", err)
    end
    return ok
end

function F.getAutoloadConfigName()
    return autoloadConfigName or F.getAutoloadName()
end

function F.serializeConfig()
    local function walk(src, depth)
        depth = depth or 0
        if depth > 6 then return nil end
        local t = type(src)
        if t == "boolean" or t == "number" or t == "string" then return src end
        if typeof(src) == "Color3" then return colorToTable(src) end
        if t == "table" then
            local out = {}
            for k, v in pairs(src) do
                local tk = type(k)
                if tk == "string" or tk == "number" then
                    local sv = walk(v, depth + 1)
                    if sv ~= nil then out[k] = sv end
                end
            end
            return out
        end
        return nil
    end
    return {
        _name = currentConfigName,
        _version = 1,
        settings = walk(Config),
    }
end

function F.applyConfigTable(data)
    if type(data) ~= "table" then return end
    local src = data.settings or data
    local function merge(dst, srcT, depth)
        depth = depth or 0
        if depth > 6 or type(dst) ~= "table" or type(srcT) ~= "table" then return end
        for k, v in pairs(srcT) do
            local asColor = (type(v) == "table") and tableToColor(v) or nil
            local colorLike = false
            if asColor and type(v) == "table" then
                local only = true
                for ck in pairs(v) do
                    local s = tostring(ck):lower()
                    if s ~= "r" and s ~= "g" and s ~= "b" and ck ~= 1 and ck ~= 2 and ck ~= 3 then
                        only = false
                        break
                    end
                end
                colorLike = only
            end
            if colorLike and asColor then
                dst[k] = asColor
            elseif type(v) == "table" and type(dst[k]) == "table" then
                merge(dst[k], v, depth + 1)
            elseif type(v) == "table" and (dst[k] == nil or typeof(dst[k]) == "Color3") then
                if colorLike and asColor then
                    dst[k] = asColor
                elseif dst[k] == nil then
                    dst[k] = v
                elseif typeof(dst[k]) == "Color3" and asColor then
                    dst[k] = asColor
                end
            elseif type(v) ~= "table" then
                dst[k] = v
            end
        end
    end
    merge(Config, src)
    F.fixConfigColors(Config)
    if type(data._name) == "string" and data._name ~= "" then
        currentConfigName = F.sanitizeConfigName(data._name)
    end
end

function F.listConfigs()
    F.ensureConfigDir()
    local names = {}
    pcall(function()
        if typeof(listfiles) == "function" then
            local files = listfiles(CONFIG_DIR) or {}
            for _, f in ipairs(files) do
                local n = tostring(f):match("([^/\\\\]+)%.json$")
                if n and n ~= "_autoload" then table.insert(names, n) end
            end
        end
    end)
    pcall(function()
        if typeof(isfile) == "function" and isfile(CONFIG_FILE) then
            local has = false
            for _, n in ipairs(names) do if n == "default" then has = true end end
            if not has then table.insert(names, "default") end
        end
    end)
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    if #names == 0 then table.insert(names, "default") end
    return names
end

function F.saveConfig(name)
    name = F.sanitizeConfigName(name or currentConfigName)
    currentConfigName = name
    local ok, err = pcall(function()
        if typeof(writefile) ~= "function" then error("no writefile") end
        F.ensureConfigDir()
        local payload = F.serializeConfig()
        payload._name = name
        payload._savedAt = os.time()
        local path = F.configPath(name)
        local encoded = HttpService:JSONEncode(payload)
        writefile(path, encoded)
        -- always mirror latest to CONFIG_FILE as backup
        pcall(function() writefile(CONFIG_FILE, encoded) end)
        print("[Juru] writefile ok:", path, #encoded, "bytes")
    end)
    if ok then
        F.pushNotification("saved config: " .. name, true)
    else
        F.pushNotification("config save failed", 3)
        warn("[Juru] saveConfig:", err)
    end
    return ok
end

function F.loadConfig(name)
    name = F.sanitizeConfigName(name or currentConfigName)
    local ok, err = pcall(function()
        if typeof(readfile) ~= "function" then error("no readfile") end
        local path = F.configPath(name)
        local raw = nil
        if typeof(isfile) == "function" and isfile(path) then
            raw = readfile(path)
        elseif name == "default" and typeof(isfile) == "function" and isfile(CONFIG_FILE) then
            raw = readfile(CONFIG_FILE)
        else
            error("missing " .. path)
        end
        local data = HttpService:JSONDecode(raw)
        F.applyConfigTable(data)
        -- DO NOT forceRuntimeOff — that wiped the loaded settings
        currentConfigName = name
        -- re-apply active systems from loaded Config
        pcall(function()
            if Config.SilentAim and Config.SilentAim.Enabled then
                if F.tryInstallSilentAim then F.tryInstallSilentAim() end
                wallShootHooked = false
                if F.tryInstallWallShoot then F.tryInstallWallShoot() end
            end
            if Config.WallShoot and Config.WallShoot.Enabled then
                wallShootHooked = false
                if F.tryInstallWallShoot then F.tryInstallWallShoot() end
            end
            if Config.SilentAim and Config.SilentAim.UseCameraAimbot then
                if F.bindCameraAimbot then F.bindCameraAimbot() end
            end
            if Config.Ragebot and Config.Ragebot.Enabled and F.rbStart then
                F.rbStart()
            end
            if Config.RageBot and Config.RageBot.Enabled and F.startRageBot then
                rageBotEnabled = true
                F.startRageBot()
            end
        end)
    end)
    if ok then
        F.pushNotification("loaded config: " .. name, true)
        print("[Juru] Loaded config:", name)
    else
        F.pushNotification("config load failed", 3)
        warn("[Juru] loadConfig:", err)
    end
    return ok
end

function F.deleteConfig(name)
    name = F.sanitizeConfigName(name)
    if name == "default" then
        F.pushNotification("cannot delete default", 3)
        return false
    end
    local ok = pcall(function()
        local path = F.configPath(name)
        if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(path) then
            delfile(path)
        end
    end)
    if ok then
        F.pushNotification("deleted config: " .. name, 2)
    end
    return ok
end

function F.getCurrentConfigName()
    return currentConfigName or "default"
end

function F.forceRuntimeOff()
    isLocking = false
    currentTarget = nil
    triggerEnabled = false
    SpeedEnabled = false
    cFrameSpeedEnabled = false
    superJumpActive = false
    rageBotEnabled = false
    rageTargetPlayer = nil
    flyEnabled = false
    rapidFireActive = false
    pcall(function() if F.rbStop then F.rbStop() end end)
    pcall(function() if F.stopRageBot then F.stopRageBot() end end)
    pcall(function() if F.unbindCameraAimbot then F.unbindCameraAimbot() end end)
    if Config.Speed then Config.Speed.Enabled = false end
    if Config.CFrameSpeed then Config.CFrameSpeed.Enabled = false end
    if Config.Fly then Config.Fly.Enabled = false end
    if Config.SuperJump then Config.SuperJump.Enabled = false end
    if Config.TriggerBot then Config.TriggerBot.Enabled = false end
    if Config.RageBot then Config.RageBot.Enabled = false end
    if Config.Ragebot then Config.Ragebot.Enabled = false; Config.Ragebot.AutoFire = false; Config.Ragebot.ShowFOV = false end
    if Config.RapidFire then Config.RapidFire.Enabled = false end
    if Config.SilentAim then
        Config.SilentAim.Enabled = false
        Config.SilentAim.UseCameraAimbot = false
        Config.SilentAim.AllowIndexHook = false
    end
    if Config.WallShoot then Config.WallShoot.Enabled = false end
    if Config.SoftLock then Config.SoftLock.Enabled = false; Config.SoftLock.ShowTracer = false end
    if Config.Settings then
        Config.Settings.AutoRetaliate = false
        Config.Settings.StickyLock = false
    end
    if Config.Hitbox then Config.Hitbox.Enabled = false; Config.Hitbox.ShowVisual = false end
    if Config.MultiEquip then Config.MultiEquip.Enabled = false end
    if Config.Visuals then
        Config.Visuals.Enabled = false
        Config.Visuals.Boxes = false
        Config.Visuals.Names = false
        Config.Visuals.Distance = false
        Config.Visuals.Tracers = false
        Config.Visuals.Skeleton = false
        Config.Visuals.Chams = false
        Config.Visuals.SelfChams = false
        Config.Visuals.HighlightChams = false
    end
    if Config.FOV then Config.FOV.Enabled = false; Config.FOV.Visible = false end
    if Config.HitMarker then Config.HitMarker.Enabled = false end
    if Config.LocalFx then Config.LocalFx.Enabled = false end
    if Config.KeyOverlay then Config.KeyOverlay.Enabled = false end
    if Config.HitSound then Config.HitSound.Enabled = false end
    if Config.AutoReload then Config.AutoReload.Enabled = false end
    if Config.SmartRange then Config.SmartRange.Enabled = false end
    if Config.Spread then Config.Spread.Enabled = false end
    if Config.AntiRage then Config.AntiRage.Enabled = false end
    if Config.AntiMod then Config.AntiMod.Enabled = false end
    if Config.VoidHide then Config.VoidHide.Enabled = false end
    if Config.ChatMacro then Config.ChatMacro.Enabled = false end
    if Config.AutoBuyArmor then Config.AutoBuyArmor.Enabled = false end
    if Config.InfiniteRange then Config.InfiniteRange.Enabled = false end
    if Config.BulletTracers then Config.BulletTracers.Enabled = false end
    -- hide drawings immediately
    pcall(function()
        if fovCircle then fovCircle.Visible = false end
        if tracerLine then tracerLine.Visible = false end
        for _, esp in pairs(espLabels or {}) do
            if F.hideEspDrawings then F.hideEspDrawings(esp) end
        end
        for uid in pairs(chamsHighlights or {}) do
            if F.destroyPlayerChams then F.destroyPlayerChams(uid) end
        end
        if F.clearSelfChamSpheres then F.clearSelfChamSpheres() end
    end)
    -- restore original gun shoot (no silent/wall rewrite while everything off)
    pcall(function()
        if wallShootRestore then wallShootRestore() end
        wallShootHooked = false
        wallShootRestore = nil
    end)
    isLocking = false
    currentTarget = nil
    shared._juruLastLockUid = nil
end

function F.resetConfigDefaults()
    pcall(function()
        local function walk(tbl, depth)
            depth = depth or 0
            if depth > 5 or type(tbl) ~= "table" then return end
            for k, v in pairs(tbl) do
                if type(k) == "string" and type(v) == "boolean" then
                    local lk = k:lower()
                    if lk == "enabled" or lk == "visible" or lk == "showfov" or lk == "selfchams"
                        or lk == "chams" or lk == "boxes" or lk == "names" or lk == "distance"
                        or lk == "tracers" or lk == "skeleton" or lk == "autofire" or lk == "autoequip"
                        or lk == "teleportrage" or lk == "farrange" or lk == "spam" then
                        tbl[k] = false
                    end
                elseif type(v) == "table" then
                    walk(v, depth + 1)
                end
            end
        end
        walk(Config)
        F.forceRuntimeOff()
    end)
    F.pushNotification("all features OFF (defaults)", 2)
end

-- Startup: force off first; menu will autoload after UI if set
task.defer(function()
    pcall(function()
        F.ensureConfigDir()
        if F.forceRuntimeOff then F.forceRuntimeOff() end
        print("[Juru] Cold start — waiting for menu autoload if set")
    end)
    -- Always start with movement OFF until keybind is pressed (avoids character kicks)
    pcall(function()
        SpeedEnabled = false
        cFrameSpeedEnabled = false
        if Config.Speed then Config.Speed.Enabled = false end
        if Config.CFrameSpeed then Config.CFrameSpeed.Enabled = false end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed > 50 then
            hum.WalkSpeed = 16
        end
    end)
end)

function F.isWhitelisted(player)
    if not Config.Whitelist or not Config.Whitelist.Enabled then return false end
    if not player then return false end
    local uid = player.UserId
    for _, entry in ipairs(Config.Whitelist.Players or {}) do
        if entry.UserId == uid then return true end
        -- fallback name match if UserId somehow missing
        if entry.Name and entry.Name ~= "" and (
            player.Name:lower() == entry.Name:lower()
            or (player.DisplayName and player.DisplayName:lower() == entry.Name:lower())
        ) then
            return true
        end
    end
    return false
end

function F.whitelistAddPlayer(plr)
    if not plr or plr == LocalPlayer then return false, "invalid" end
    if not Config.Whitelist.Players then Config.Whitelist.Players = {} end
    for _, entry in ipairs(Config.Whitelist.Players) do
        if entry.UserId == plr.UserId then
            return false, "already"
        end
    end
    table.insert(Config.Whitelist.Players, {
        UserId = plr.UserId,
        Name = plr.Name,
        DisplayName = (plr.DisplayName and plr.DisplayName ~= "" and plr.DisplayName) or plr.Name,
    })
    F.saveWhitelist()
    return true
end

function F.whitelistRemoveByUserId(uid)
    uid = tonumber(uid)
    if not uid then return false end
    local list = Config.Whitelist.Players or {}
    for i = #list, 1, -1 do
        if list[i].UserId == uid then
            table.remove(list, i)
            F.saveWhitelist()
            return true
        end
    end
    return false
end

function F.whitelistRemovePlayer(plr)
    if not plr then return false end
    return F.whitelistRemoveByUserId(plr.UserId)
end

function F.whitelistClear()
    Config.Whitelist.Players = {}
    F.saveWhitelist()
end

function F.whitelistLabelText()
    local list = Config.Whitelist.Players or {}
    if #list == 0 then return "Whitelist empty" end
    local names = {}
    for i, e in ipairs(list) do
        if i > 8 then
            table.insert(names, ("… +%d more"):format(#list - 8))
            break
        end
        local dn = e.DisplayName or e.Name or tostring(e.UserId)
        table.insert(names, dn)
    end
    return table.concat(names, ", ")
end

function F.jConnect(signal, fn)
    local c = signal:Connect(function(...)
        if not JuruAlive then return end
        return fn(...)
    end)
    table.insert(JuruConns, c)
    return c
end

function F.jDraw(className)
    local obj
    if JujuDrawing and type(JujuDrawing.new) == "function" then
        local ok, o = pcall(JujuDrawing.new, className)
        if ok and o then obj = o end
    end
    if not obj and Drawing and Drawing.new then
        obj = Drawing.new(className)
    end
    if obj then table.insert(JuruDrawings, obj) end
    return obj
end

local currentTarget      = nil
local isLocking          = false
local triggerEnabled     = false
local SpeedEnabled       = false
local BaseSpeed          = 16
local charReadyAt        = 0
local lastTriggerClick   = 0
local superJumpActive    = false
local cFrameSpeedEnabled = false
local rageBotEnabled     = false
local rageTargetPlayer   = nil
local rageTargetList     = {}
local lastShotTime       = 0
local myRecentShot       = false
local rapidFireActive    = false
local lastRageShot       = 0
local rageAngle          = 0
local rageTpAccum         = 0
local rageTargetSpawnWaitUntil = 0
local rageTrackedSpawnChar = nil

function F.isFarRage()
    local r = Config and Config.RageBot
    if not r then return false end
    local v = r.FarRage
    if v == true or v == 1 or v == "true" or v == "on" then return true end
    local ok, tv = pcall(function()
        return Toggles and Toggles.FarRage and Toggles.FarRage.Value
    end)
    return ok and tv and true or false
end

-- Always land far from the target (random angle * FarDistance). Never melee orbit.
function F.farRageHop(myHRP, aimPos, farDist)
    if not myHRP then return end
    farDist = tonumber(farDist) or (Config.RageBot and tonumber(Config.RageBot.FarDistance)) or 2800
    farDist = math.max(farDist, 1200)
    local tpos = nil
    pcall(function()
        if rageTargetPlayer and rageTargetPlayer.Character then
            local h = rageTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if h then tpos = h.Position end
        end
    end)
    local ang = math.random() * math.pi * 2
    local dist = farDist * (0.95 + math.random() * 0.4)
    local yOff = 140 + math.random() * 320
    local pos
    if tpos then
        pos = Vector3.new(tpos.X + math.cos(ang) * dist, tpos.Y + yOff, tpos.Z + math.sin(ang) * dist)
    else
        pos = Vector3.new(math.cos(ang) * dist, yOff, math.sin(ang) * dist)
    end
    if aimPos then
        myHRP.CFrame = CFrame.new(pos, aimPos)
    else
        myHRP.CFrame = CFrame.new(pos)
    end
    pcall(function()
        myHRP.AssemblyLinearVelocity = Vector3.new()
        myHRP.AssemblyAngularVelocity = Vector3.new()
    end)
end

local rageReloading      = false
local rageReloadUntil    = 0
local wasSpectating      = false
local rageSavedCFrame    = nil
local flyEnabled         = false
local flyBV, flyBG       = nil, nil

local DrawingAvailable = false
local JujuDrawing = nil
-- Prefer juju custom drawing API when available (same as juju recode)
pcall(function()
    if typeof(Drawing) == "table" or typeof(Drawing) == "userdata" then
        local t = Drawing.new("Line")
        t.Visible = false
        t:Remove()
        DrawingAvailable = true
    end
end)
pcall(function()
    local src = game:HttpGet("https://raw.githubusercontent.com/khenn791/lmao/refs/heads/main/api.lua")
    if type(src) == "string" and #src > 100 then
        local api = loadstring(src)()
        if api then
            JujuDrawing = api
            getgenv().fake_drawing = api
            DrawingAvailable = true
            print("[Juru] Loaded juju drawing API")
        end
    end
end)


-- Prefer hidden UI containers. NEVER use PlayerGui (client ACs scan it).
function F.getUiParent()
    local parent = nil
    pcall(function()
        if typeof(gethui) == "function" then
            parent = gethui()
        end
    end)
    if parent then return parent end
    pcall(function()
        parent = game:GetService("CoreGui")
    end)
    if parent then return parent end
    -- last resort only
    return LocalPlayer:WaitForChild("PlayerGui")
end

function F.protectGui(gui)
    if not gui then return end
    pcall(function()
        if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
        end
    end)
    pcall(function()
        if typeof(protect_gui) == "function" then
            protect_gui(gui)
        end
    end)
    pcall(function()
        if typeof(hidgui) == "function" then
            hidgui(gui)
        end
    end)
end

function F.randomGuiName()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local s = ""
    for i = 1, 12 do
        local idx = math.random(1, #chars)
        s = s .. chars:sub(idx, idx)
    end
    return s
end

local mainGui = Instance.new("ScreenGui")
mainGui.Name = F.randomGuiName()
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.IgnoreGuiInset = true
mainGui.DisplayOrder = 100 -- avoid max-int exploit signature
mainGui.Enabled = true
F.protectGui(mainGui)
pcall(function()
    mainGui.Parent = F.getUiParent()
end)
if not mainGui.Parent then
    pcall(function() mainGui.Parent = game:GetService("CoreGui") end)
end

-- ============================================================
-- Crosshair presets (custom GitHub icons)
-- Spin is hardcoded per icon here — NOT a menu toggle.
-- Set Spin = true/false on each entry to control rotation.
-- ============================================================
local CROSSHAIR_PRESETS = {
    -- Original purple spinning cross (no Url = default lines)
    ["Default"] = {
        Url  = nil,
        Spin = true,
    },
    ["Hello Kitty"] = {
        Url  = "https://raw.githubusercontent.com/driffiti/Images/main/Hello.png",
        Spin = false,
    },
    ["Nazi"] = {
        Url  = "https://raw.githubusercontent.com/driffiti/Images/main/Swas.png",
        Spin = true,
    },
    ["Crosshair"] = {
        Url  = "https://raw.githubusercontent.com/driffiti/Images/main/crosshair.png",
        Spin = false,
    },
    ["Focus"] = {
        Url  = "https://raw.githubusercontent.com/driffiti/Images/main/focus.png",
        Spin = false,
    },
    ["Penis"] = {
        Url  = "https://raw.githubusercontent.com/driffiti/Images/main/penis.png",
        Spin = true,
    },
}

local crossImageCache = {} -- url -> resolved Image string (getcustomasset path)

function F.httpGetBinary(url)
    local body = nil
    pcall(function()
        body = game:HttpGet(url)
    end)
    if type(body) == "string" and #body > 64 then return body end
    pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if typeof(req) == "function" then
            local res = req({ Url = url, Method = "GET" })
            if res and type(res.Body) == "string" and #res.Body > 64 then
                body = res.Body
            end
        end
    end)
    return body
end

function F.resolveCrosshairImage(url)
    if not url or url == "" then return "" end
    if crossImageCache[url] ~= nil then return crossImageCache[url] end

    local resolved = ""
    local ok = pcall(function()
        if typeof(getcustomasset) ~= "function" or typeof(writefile) ~= "function" then
            error("no getcustomasset/writefile")
        end
        local fname = "Juru_Crosshair_" .. (url:match("([^/]+%.png)") or url:match("([^/]+)$") or "icon.png")
        fname = fname:gsub("[^%w%._%-]", "_")

        local hasFile = (typeof(isfile) == "function" and isfile(fname))
        if not hasFile then
            local data = F.httpGetBinary(url)
            if type(data) ~= "string" or #data < 64 then
                error("download failed")
            end
            writefile(fname, data)
        end
        resolved = getcustomasset(fname)
    end)

    if not ok or resolved == "" then
        print("[Juru] Crosshair image load failed (need getcustomasset + writefile):", url)
        crossImageCache[url] = ""
        return ""
    end

    crossImageCache[url] = resolved
    print("[Juru] Crosshair image ready:", url)
    return resolved
end

local crossHolder = Instance.new("Frame")
crossHolder.Name = "CrossHolder"
crossHolder.Size = UDim2.new(0, 36, 0, 36)
crossHolder.BackgroundTransparency = 1
crossHolder.AnchorPoint = Vector2.new(0.5, 0.5)
crossHolder.Visible = true
crossHolder.ZIndex = 10000
crossHolder.Parent = mainGui

local spinFrame = Instance.new("Frame")
spinFrame.Name = "SpinFrame"
spinFrame.Size = UDim2.new(1, 0, 1, 0)
spinFrame.BackgroundTransparency = 1
spinFrame.AnchorPoint = Vector2.new(0.5, 0.5)
spinFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
spinFrame.Visible = true
spinFrame.ZIndex = 10001
spinFrame.Parent = crossHolder

-- Legacy default cross lines (hidden when using a custom icon)
local defaultLines = {}
function F.makeLine(size, pos)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = Color3.fromRGB(170, 100, 255)
    f.BorderSizePixel = 0
    f.Visible = false
    f.ZIndex = 10002
    f.Parent = spinFrame
    table.insert(defaultLines, f)
    return f
end
F.makeLine(UDim2.new(0, 2, 0, 11), UDim2.new(0.5, 0, 0, 5.5))
F.makeLine(UDim2.new(0, 2, 0, 11), UDim2.new(0.5, 0, 1, -5.5))
F.makeLine(UDim2.new(0, 11, 0, 2), UDim2.new(0, 5.5, 0.5, 0))
F.makeLine(UDim2.new(0, 11, 0, 2), UDim2.new(1, -5.5, 0.5, 0))

local dot = Instance.new("Frame")
dot.Name = "Dot"
dot.Size = UDim2.new(0, 3, 0, 3)
dot.Position = UDim2.new(0.5, 0, 0.5, 0)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dot.BorderSizePixel = 0
dot.Visible = false
dot.ZIndex = 10003
dot.Parent = spinFrame
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local crossIcon = Instance.new("ImageLabel")
crossIcon.Name = "CrossIcon"
crossIcon.Size = UDim2.new(1, 0, 1, 0)
crossIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
crossIcon.AnchorPoint = Vector2.new(0.5, 0.5)
crossIcon.BackgroundTransparency = 1
crossIcon.BorderSizePixel = 0
crossIcon.ScaleType = Enum.ScaleType.Fit
crossIcon.Visible = true
crossIcon.ZIndex = 10002
crossIcon.Parent = spinFrame

local crossText = Instance.new("TextLabel")
crossText.Name = "CrossText"
crossText.Size = UDim2.new(0, 280, 0, 18)
crossText.Position = UDim2.new(1, 10, 0.5, -9)
crossText.BackgroundTransparency = 1
crossText.Font = Enum.Font.GothamBold
crossText.TextSize = 13
crossText.TextXAlignment = Enum.TextXAlignment.Left
crossText.TextStrokeTransparency = 0.35
crossText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
crossText.TextTransparency = 0
crossText.RichText = true
crossText.Visible = true
crossText.ZIndex = 10004
crossText.Parent = crossHolder

local spinAng = 0
local currentCrossSpin = true

function F.applyCrosshairStyle()
    if not Config.Crosshair then
        Config.Crosshair = { Style = "Default", Size = 36 }
    end
    local style = Config.Crosshair.Style or "Default"
    local size = tonumber(Config.Crosshair.Size) or 36
    local preset = CROSSHAIR_PRESETS[style] or CROSSHAIR_PRESETS["Default"]

    if crossHolder then
        crossHolder.Size = UDim2.new(0, size, 0, size)
    end

    currentCrossSpin = preset and preset.Spin == true

    if preset and preset.Url then
        for _, line in ipairs(defaultLines) do
            line.Visible = false
        end
        if dot then dot.Visible = false end
        if crossIcon then
            crossIcon.Visible = true
            -- Load async so menu / frame never stalls
            local url = preset.Url
            task.spawn(function()
                local img = F.resolveCrosshairImage(url)
                if not JuruAlive then return end
                -- still selected?
                local cur = Config.Crosshair and Config.Crosshair.Style
                local curPreset = cur and CROSSHAIR_PRESETS[cur]
                if not curPreset or curPreset.Url ~= url then return end
                if img and img ~= "" then
                    crossIcon.Image = img
                    crossIcon.Visible = true
                    for _, line in ipairs(defaultLines) do line.Visible = false end
                    if dot then dot.Visible = false end
                else
                    -- fallback to purple default if download failed
                    crossIcon.Visible = false
                    for _, line in ipairs(defaultLines) do line.Visible = true end
                    if dot then dot.Visible = true end
                    F.pushNotification("crosshair image failed to load", false)
                end
            end)
        end
    else
        -- Original purple crosshair
        if crossIcon then
            crossIcon.Visible = false
            crossIcon.Image = ""
        end
        for _, line in ipairs(defaultLines) do
            line.Visible = true
        end
        if dot then dot.Visible = true end
    end

    if spinFrame and not currentCrossSpin then
        spinFrame.Rotation = 0
        spinAng = 0
    end
end

task.defer(F.applyCrosshairStyle)

function F.forceCrosshairVisible()
    if not JuruAlive then return end

    if not mainGui or not mainGui.Parent then
        pcall(function()
            if mainGui then mainGui:Destroy() end
        end)
        mainGui = Instance.new("ScreenGui")
        mainGui.Name = F.randomGuiName()
        mainGui.ResetOnSpawn = false
        mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        mainGui.IgnoreGuiInset = true
        mainGui.DisplayOrder = 999999
        mainGui.Enabled = true
        F.protectGui(mainGui)
        pcall(function() mainGui.Parent = F.getUiParent() end)
        if not mainGui.Parent then
            pcall(function() mainGui.Parent = game:GetService("CoreGui") end)
        end

        if crossHolder and crossHolder.Parent ~= mainGui then
            crossHolder.Parent = mainGui
        end
        -- re-apply style after gui rebuild
        task.defer(F.applyCrosshairStyle)
    end

    mainGui.Enabled = true
    mainGui.DisplayOrder = 999999

    if crossHolder then
        if not crossHolder.Parent then crossHolder.Parent = mainGui end
        crossHolder.Visible = true
        crossHolder.BackgroundTransparency = 1
    end
    if spinFrame then
        if not spinFrame.Parent then spinFrame.Parent = crossHolder end
        spinFrame.Visible = true
    end
    if crossText then
        if not crossText.Parent then crossText.Parent = crossHolder end
        crossText.Visible = true
        crossText.TextTransparency = 0
        crossText.TextStrokeTransparency = 0.35
    end

    -- Keep style consistent every frame (gun equip must not bring default lines back)
    local style = Config.Crosshair and Config.Crosshair.Style or "Default"
    local preset = CROSSHAIR_PRESETS[style]
    local useIcon = preset and preset.Url and crossIcon and crossIcon.Image ~= nil and crossIcon.Image ~= ""
    if useIcon then
        if crossIcon then
            if not crossIcon.Parent then crossIcon.Parent = spinFrame end
            crossIcon.Visible = true
        end
        for _, line in ipairs(defaultLines) do
            line.Visible = false
        end
        if dot then dot.Visible = false end
    elseif preset and preset.Url then
        -- icon selected but image not loaded yet — hide purple lines so game default isn't "replaced" by ours confusingly
        if crossIcon then crossIcon.Visible = true end
        for _, line in ipairs(defaultLines) do line.Visible = false end
        if dot then dot.Visible = false end
    else
        if crossIcon then crossIcon.Visible = false end
        for _, line in ipairs(defaultLines) do line.Visible = true end
        if dot then dot.Visible = true end
    end
end

local _lastForceCross = 0
F.jConnect(RunService.RenderStepped, function(dt)
    -- Only rebuild GUI if it was destroyed (rare) — not every frame
    if not mainGui or not mainGui.Parent then
        if tick() - _lastForceCross > 0.5 then
            _lastForceCross = tick()
            F.forceCrosshairVisible()
        end
    end

    if spinFrame then
        if currentCrossSpin then
            spinAng = (spinAng + dt * 160) % 360
            spinFrame.Rotation = spinAng
        else
            spinFrame.Rotation = 0
        end
    end

    local m = UserInputService:GetMouseLocation()
    if crossHolder then
        crossHolder.Position = UDim2.new(0, m.X, 0, m.Y)
    end

    if crossText then
        local lockedName = ""
        if isLocking and currentTarget and currentTarget.Parent then
            local plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
            if plr then
                lockedName = F.playerLabel(plr)
            end
        end
        if lockedName ~= "" then
            crossText.Text = string.format(
                '<font color="rgb(210, 180, 238)">juru</font> <font color="rgb(189, 245, 189)">locked: %s</font>',
                lockedName
            )
        else
            crossText.Text = '<font color="rgb(210, 180, 238)">juru</font><font color="rgb(189, 245, 189)">.lol</font>'
        end
    end
end)

-- Do NOT parent to PlayerGui — client anticheats scan it ("exploit GUI in PlayerGui")
if not mainGui.Parent then
    F.protectGui(mainGui)
    pcall(function() mainGui.Parent = F.getUiParent() end)
end



-- base64_decode polyfill (executors vary)
if typeof(base64_decode) ~= "function" then
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    function base64_decode(data)
        data = string.gsub(data, '[^'..b..'=]', '')
        return (data:gsub('.', function(x)
            if x == '=' then return '' end
            local r,f='', (b:find(x)-1)
            for i=6,1,-1 do r=r..(f%2^i - f%2^(i-1) > 0 and '1' or '0') end
            return r
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
            if #x ~= 8 then return '' end
            local c=0
            for i=1,8 do c=c + (x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
        end))
    end
end

-- ============================================================
-- JURU NOTIFICATION / HITSOUND / RAPIDFIRE (extracted from juru)
-- ============================================================
do
    local clock = os.clock
    local delay = task.delay
    local spawn = task.spawn
    local clamp = math.clamp
    local floor = math.floor
    local sqrt = math.sqrt
    local color3_fromrgb = Color3.fromRGB
    local color3_lerp = function(a, b, t) return a:Lerp(b, t) end
    local vector2_new = Vector2.new
    local udim2_new = UDim2.new
    local circular = Enum.EasingStyle.Circular
    local exponential = Enum.EasingStyle.Exponential
    local quad = Enum.EasingStyle.Quad
    local out = Enum.EasingDirection.Out
    local show_transparency = {Transparency = 1}
    local hide_transparency = {Transparency = 0}

    local function remove(tbl, index)
        local length = #tbl
        for i = index, length - 1 do
            tbl[i] = tbl[i + 1]
        end
        tbl[length] = nil
    end

    local pixel_image_data = base64_decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAAYdEVYdFNvZnR3YXJlAFBhaW50Lk5FVCA1LjEuMvu8A7YAAAC2ZVhJZklJKgAIAAAABQAaAQUAAQAAAEoAAAAbAQUAAQAAAFIAAAAoAQMAAQAAAAIAAAAxAQIAEAAAAFoAAABphwQAAQAAAGoAAAAAAAAA8nYBAOgDAADydgEA6AMAAFBhaW50Lk5FVCA1LjEuMgADAACQBwAEAAAAMDIzMAGgAwABAAAAAQAAAAWgBAABAAAAlAAAAAAAAAACAAEAAgAEAAAAUjk4AAIABwAEAAAAMDEwMAAAAACOO8FX0xe8TgAAAAxJREFUGFdj+P//PwAF/gL+pzWBhAAAAABJRU5ErkJggg==")
    local shadow_image_data = base64_decode("iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAQAAABpN6lAAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAAmJLR0QA/4ePzL8AAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAHdElNRQfiAQkTIxqKm+UhAAACvElEQVR42u2dzY7aMBhFjxPHEzJQBolRq77/27XSwBCSkD/PwinS7LpBVwrfeYLjI4Ozuy6Cw+HIyHBkOMCxTiIQmYnMzEQi0S9Hz/EUePIlxDpJB58YGRiZmJlTgIKCQMkLYYmwTtLhe2509AwM6QbkFJRUbKnYEChWHGCgp6WhpoF0AzI8gYodB/bs2BDI1aYPYqKn5cIZR7oPkyejoGTLgZ+888aOEq82fRAjHRdOlEBkZGTwODwvVOx55zdH9rxSqE0fxMCVMxXQ0dHS4TwZOYENO9448osDW4La9EH01GyAhhOfBHKy9Ar4JcGeA0d2Kw5QAu3yT+fJcB7IyJdn8JUtO36sOAB0vFISKNJz7+9fgelTKBAIlGrThxEI3z743Fpf/P/GAqgF1FgAtYAaC6AWUGMB1AJqLIBaQI0FUAuosQBqATUWQC2gxgKoBdRYALWAGgugFlBjAdQCaiyAWkCNBVALqLEAagE1FkAtoMYCqAXUWAC1gBoLoBZQYwHUAmosgFpAjQVQC6ixAGoBNRZALaDGAqgF1FgAtYAaC6AWUGMB1AJqLIBaQI0FUAuosQBqATUWQC2gxgKoBdRYALWAGgugFlBjAdQCaiyAWkCNBVALqLEAagE1FkAtoMYCqAXUWAC1gBoLoBZQYwHUAmosgFpAjQVQC6ixAGoBNRZALaDGAqgF1FgAtYAaC6AWUGMB1AJqLIBaQI0nfpsi7enp1VIPI53uPriaVmfT9ORAT8eVmhJWvDZ3oea6TK5OzOkGzIz3Lc4N0K04QM0HZy609IzMRM98nyI9UQHt6ic3/3JaEkzMnsjIjYYzJdA8xejqH8403BjTDRjoqHFAx+lJZnc/qOkYmP3yD9AAkY7PJxpe7hnTT2BiAGZG2ieb3p6ILj75+LqL4O7Dq245/HoDpAjx32cQ8QtpRORenSWX2AAAABl0RVh0U29mdHdhcmUAcGFpbnQubmV0IDQuMC4xOdTWsmQAAAAASUVORK5CYII=")

    -- heartbeat list for juru tween
    local juru_heartbeat = {}
    local active_tweens = {
        Color = {}, Color3 = {}, Size = {}, tween_position = {}, Position = {},
        tween_size = {}, Transparency = {}, FillTransparency = {}, OutlineTransparency = {},
        BackgroundTransparency = {}, ImageTransparency = {}, FillColor = {}, OutlineColor = {},
        [11] = {}, [15] = {}
    }

    local function tween(object, properties, easing_style, _, tween_duration)
        local start_time = clock()
        local tween_functions = {}
        for property, value in pairs(properties) do
            local tweens = active_tweens[property]
            if not tweens then
                active_tweens[property] = {}
                tweens = active_tweens[property]
            end
            local old_tween = tweens[object]
            if old_tween then
                for i = 1, #juru_heartbeat do
                    if juru_heartbeat[i] == old_tween then
                        remove(juru_heartbeat, i)
                        break
                    end
                end
            end
            local old_value = object[property]
            if property == "Color" or property == "Color3" or property == "FillColor" or property == "OutlineColor" then
                tween_functions[property] = function()
                    local t = ((clock() - start_time)/tween_duration)
                    local e = easing_style == exponential and (t == 1 and 1 or 1 - 2 ^ (-10 * t)) or easing_style == quad and t^2 or sqrt(1 - (t - 1) ^ 2)
                    object[property] = color3_lerp(old_value, value, e)
                end
            elseif property == "tween_position" or property == "tween_size" then
                tween_functions[property] = function()
                    local t = ((clock() - start_time)/tween_duration)
                    local tween_value = easing_style == exponential and (t == 1 and 1 or 1 - 2 ^ (-10 * t)) or easing_style == quad and t^2 or sqrt(1 - (t - 1) ^ 2)
                    local new = (value - old_value)
                    new = udim2_new(new.X.Scale * tween_value, new.X.Offset * tween_value, new.Y.Scale * tween_value, new.Y.Offset * tween_value)
                    object[property] = old_value + new
                end
            else
                tween_functions[property] = function()
                    local t = ((clock() - start_time)/tween_duration)
                    local e = easing_style == exponential and (t == 1 and 1 or 1 - 2 ^ (-10 * t)) or easing_style == quad and t^2 or sqrt(1 - (t - 1) ^ 2)
                    object[property] = old_value + (value - old_value) * e
                end
            end
        end
        for property, tf in pairs(tween_functions) do
            juru_heartbeat[#juru_heartbeat+1] = tf
            active_tweens[property][object] = tf
        end
        delay(tween_duration, function()
            for property, tf in pairs(tween_functions) do
                for i = 1, #juru_heartbeat do
                    if juru_heartbeat[i] == tf then
                        remove(juru_heartbeat, i)
                        pcall(function() object[property] = properties[property] end)
                        break
                    end
                end
            end
        end)
    end

    F.jConnect(RunService.Heartbeat, function()
        for i = 1, #juru_heartbeat do
            pcall(juru_heartbeat[i])
        end
    end)

    -- Prefer juru custom drawing API (supports Image.Data / Rounding)
    local drawing_lib = Drawing
    pcall(function()
        drawing_lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/khenn791/lmao/refs/heads/main/api.lua"))()
    end)

    local create1 = drawing_lib.new
    local drawing_proxy = {}
    drawing_proxy.__index = drawing_proxy

    function drawing_proxy.new(class, properties)
        local object = create1(class)
        local proxy = setmetatable({
            position = udim2_new(0, 0, 0, 0),
            real_position = vector2_new(0, 0),
            size = class == "Text" and 12 or udim2_new(0, 0, 0, 0),
            real_size = class == "Text" and 12 or vector2_new(0, 0),
            object = object,
            children = {},
            parent = false,
            is_rendering = false,
            skip = class == "Circle",
            visible = false,
            destroy = function()
                pcall(function() object:Destroy() end)
                pcall(function() object:Remove() end)
            end
        }, drawing_proxy)

        local z_index = properties.ZIndex
        properties.ZIndex = z_index and z_index + 20 or 20
        for property, value in pairs(properties) do
            proxy[property] = value
        end
        return proxy
    end

    local function update_proxy_position(proxy, position)
        local parent = rawget(proxy, "parent")
        local real_position = parent and parent.real_position or vector2_new(position.X.Offset, position.Y.Offset)
        if parent then
            local parent_position = parent.real_position
            local real_parent_size = parent.real_size
            real_position = vector2_new(
                (parent_position.X + real_parent_size.X * position.X.Scale) + position.X.Offset,
                (parent_position.Y + real_parent_size.Y * position.Y.Scale) + position.Y.Offset
            )
        end
        proxy.object.Position = real_position
        proxy.real_position = real_position
        local children = proxy.children
        for i = 1, #children do
            local child = children[i]
            update_proxy_position(child, child.position)
        end
    end

    local function update_proxy_visibility(proxy, visible)
        local children = proxy.children
        local parent = rawget(proxy, "parent")
        local object = proxy.object
        if parent and not parent.is_rendering then
            proxy.is_rendering = false
            object.Visible = false
        else
            object.Visible = visible
            proxy.is_rendering = visible
        end
        for i = 1, #children do
            local child = children[i]
            update_proxy_visibility(child, child.visible)
        end
    end

    local function update_proxy_size(proxy, size)
        if type(proxy) ~= "table" or type(proxy.real_size) == "number" then return end
        local parent = rawget(proxy, "parent")
        local real_size = parent and parent.real_size or vector2_new(size.X.Offset, size.Y.Offset)
        if parent then
            local parent_size = parent.real_size
            real_size = vector2_new(
                (parent_size.X * size.X.Scale) + size.X.Offset,
                (parent_size.Y * size.Y.Scale) + size.Y.Offset
            )
        end
        proxy.object.Size = real_size
        proxy.real_size = real_size
        local children = proxy.children
        for i = 1, #children do
            local child = children[i]
            update_proxy_size(child, child.size)
            update_proxy_position(child, child.position)
        end
    end

    function drawing_proxy:__newindex(property, value)
        if property == "Position" or property == "tween_position" then
            self.position = value
            update_proxy_position(self, value)
        elseif property == "Parent" then
            if value then
                local children = value.children
                children[#children+1] = self
            end
            self.parent = value
            update_proxy_position(self, self.position)
            update_proxy_visibility(self, self.visible)
            if type(self.size) ~= "number" and not self.skip then
                update_proxy_size(self, self.size)
            end
        elseif property == "Visible" then
            self.visible = value
            update_proxy_visibility(self, value)
        elseif (property == "Size" or property == "tween_size") and type(value) ~= "number" and not self.skip then
            self.size = value
            update_proxy_size(self, value)
        else
            self.object[property] = value
        end
    end

    function drawing_proxy:__index(property)
        return property == "tween_size" and self.size
            or property == "tween_position" and self.position
            or property == "Destroy" and self.destroy
            or self.object[property]
    end

    -- menu stub used only for notifications (exact juru colors)
    local menu = {
        notifications = {},
        colors = {
            shadow = color3_fromrgb(170, 100, 255),
            accent = color3_fromrgb(170, 100, 255),
            active_text = color3_fromrgb(197, 197, 197),
            border = color3_fromrgb(24, 25, 24),
            section = color3_fromrgb(6, 6, 6),
            background = color3_fromrgb(0, 0, 0),
            success = color3_fromrgb(170, 100, 255),
            error = color3_fromrgb(39, 60, 96),
            alert = color3_fromrgb(30, 51, 61),
        }
    }
    local colors = menu.colors
    local do_notifications = true
    local camera = Workspace.CurrentCamera

    local notification_types = {
        [1] = {
            color3_fromrgb(174, 255, 0),
            base64_decode("iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAYdEVYdFNvZnR3YXJlAFBhaW50Lk5FVCA1LjEuMvu8A7YAAAC2ZVhJZklJKgAIAAAABQAaAQUAAQAAAEoAAAAbAQUAAQAAAFIAAAAoAQMAAQAAAAIAAAAxAQIAEAAAAFoAAABphwQAAQAAAGoAAAAAAAAAYAAAAAEAAABgAAAAAQAAAFBhaW50Lk5FVCA1LjEuMgADAACQBwAEAAAAMDIzMAGgAwABAAAAAQAAAAWgBAABAAAAlAAAAAAAAAACAAEAAgAEAAAAUjk4AAIABwAEAAAAMDEwMAAAAADp1fY4ytpsegAAAFFJREFUOE/NzEsOgCAMRdGy/0UrlxSDtY90RDwD/hc7rvlccnW+rIdrhFL4ieBrKYvGzDAv40cqQlOXuwjpoyhGeA5UnEV4HcZYRSli+PY3zG4fbDP68uskQAAAAABJRU5ErkJggg==")
        },
        [2] = {
            color3_fromrgb(255, 225, 0),
            base64_decode("iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADdYAAA3WAZBveZwAAAAYdEVYdFNvZnR3YXJlAFBhaW50Lk5FVCA1LjEuMvu8A7YAAAC2ZVhJZklJKgAIAAAABQAaAQUAAQAAAEoAAAAbAQUAAQAAAFIAAAAoAQMAAQAAAAIAAAAxAQIAEAAAAFoAAABphwQAAQAAAGoAAAAAAAAAiF8BAOgDAACIXwEA6AMAAFBhaW50Lk5FVCA1LjEuMgADAACQBwAEAAAAMDIzMAGgAwABAAAAAQAAAAWgBAABAAAAlAAAAAAAAAACAAEAAgAEAAAAUjk4AAIABwAEAAAAMDEwMAAAAAC1cWHl18YwawAAAGdJREFUOE+dkUsOgDAIRMWd9z+sSxUyNAKZ/t5mSmBKoQfjAQgLAg1kg3zg2Dihy5Sb2PNyV9pRCxWEhWBk3ZSca8aeyfnXbC/HjDPdHK+14VeMim2tY7qgNzRAjf4VNM8SIzZnFHkB8alA8IwiGIYAAAAASUVORK5CYII=")
        },
        [3] = {
            color3_fromrgb(255, 60, 63),
            base64_decode("iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAMAAAAolt3jAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAGUExURf///wAAAFXC034AAAACdFJOU/8A5bcwSgAAAAlwSFlzAAAPgAAAD4ABMkKt4wAAABh0RVh0U29mdHdhcmUAUGFpbnQuTkVUIDUuMS4y+7wDtgAAALZlWElmSUkqAAgAAAAFABoBBQABAAAASgAAABsBBQABAAAAUgAAACgBAwABAAAAAgAAADEBAgAQAAAAWgAAAGmHBAABAAAAagAAAAAAAADMiQEA6AMAAMyJAQDoAwAAUGFpbnQuTkVUIDUuMS4yAAMAAJAHAAQAAAAwMjMwAaADAAEAAAABAAAABaAEAAEAAACUAAAAAAAAAAIAAQACAAQAAABSOTgAAgAHAAQAAAAwMTAwAAAAAAd06aoHBh5lAAAAPElEQVQYV22LQQ4AMAjC8P+fHqg4l4yDthERQHRIUGzONd9rGTLk9SRcb38tc7mFkRpy5VTtKY1zltERByNGAFUDKq+CAAAAAElFTkSuQmCC")
        },
        [4] = {
            color3_fromrgb(255, 60, 63),
            base64_decode("iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAMAAAAolt3jAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAGUExURf///wAAAFXC034AAAACdFJOU/8A5bcwSgAAAAlwSFlzAAAOwgAADsIBFShKgAAAABh0RVh0U29mdHdhcmUAUGFpbnQuTkVUIDUuMS4y+7wDtgAAALZlWElmSUkqAAgAAAAFABoBBQABAAAASgAAABsBBQABAAAAUgAAACgBAwABAAAAAgAAADEBAgAQAAAAWgAAAGmHBAABAAAAagAAAAAAAADydgEA6AMAAPJ2AQDoAwAAUGFpbnQuTkVUIDUuMS4yAAMAAJAHAAQAAAAwMjMwAaADAAEAAAABAAAABaAEAAEAAACUAAAAAAAAAAIAAQACAAQAAABSOTgAAgAHAAQAAAAwMTAwAAAAAI47wVfTF7xOAAAAP0lEQVQYV22NSQoAIBDDnP9/WpNW8GBwaZyCa2TdO+choQJRgouM2vN2UFLx1V0eNQUkk9rnI4IQ21OuUj7MbDBmAHXXCP83AAAAAElFTkSuQmCC")
        }
    }

    do
        local update_notifications = LPH_NO_VIRTUALIZE(function()
            local notifications = menu["notifications"]
            local size = camera["ViewportSize"]["Y"]*0.88
            if #notifications > 6 then
                notifications[1]:dismiss()
            end
            for i = 1, #notifications do
                local notification = notifications[i]
                local inside = notification["inside"]
                local position = inside["Position"]
                local new_position = udim2_new(0, position["X"], 0, size - (i*29))
                if position ~= new_position then
                    tween(inside, {tween_position = new_position}, exponential, out, 0.14)
                end
            end
        end)

        local colors = menu["colors"]

        local notification = {}
        notification["__index"] = notification

        menu["new_notification"] = function(text, type, time, data)
            if do_notifications then
                local color
                if typeof(time) == "Color3" then
                    color = time
                elseif type == 1 then
                    color = notification_types[1][1] -- lime green (success / hit)
                elseif type == 2 then
                    color = notification_types[2][1] -- yellow (alert / info)
                elseif type == 3 or type == 4 then
                    color = notification_types[3][1] -- red (error)
                else
                    color = colors["accent"]
                end
                local inside = drawing_proxy["new"]("Image", {
                    ["Data"] = pixel_image_data,
                    ["Rounding"] = 7,
                    ["Size"] = udim2_new(1, -2, 1, -2),
                    ["Position"] = udim2_new(0, 1, 0, 1),
                    ["Color"] = colors["background"],
                    ["Transparency"] = 0,
                    ["ZIndex"] = 1101,
                    ["Visible"] = true,
                })
                local image = drawing_proxy["new"]("Image", {
                    ["Parent"] = inside,
                    ["Position"] = udim2_new(0, 5, 0, 5),
                    ["Size"] = udim2_new(0, 12, 0, 12),
                    ["Color"] = color,
                    ["Transparency"] = 0,
                    ["Data"] = data or notification_types[type][2],
                    ["Rounding"] = 4,
                    ["ZIndex"] = 1102,
                    ["Visible"] = true,
                })
                local text = drawing_proxy["new"]("Text", {
                    ["Parent"] = inside,
                    ["Position"] = udim2_new(0, 26, 0, 5),
                    ["Color"] = colors["active_text"],
                    ["Text"] = text,
                    ["Size"] = 12,
                    ["Font"] = 1,
                    ["ZIndex"] = 1102,
                    ["Transparency"] = 0,
                    ["Visible"] = true,
                })
                local shadow = drawing_proxy["new"]("Image", {
                    ["Parent"] = inside,
                    ["Data"] = shadow_image_data,
                    ["Rounding"] = 8,
                    ["Color"] = color,
                    ["Transparency"] = 0,
                    ["ZIndex"] = 1100,
                    ["Visible"] = true,
                    ["Position"] = udim2_new(0, 0, 0, 0),
                })

                local x_size = 32 + text["TextBounds"]["X"]
                local size = udim2_new(0, x_size, 0, 24)

                inside["Size"] = size

                local shadow_size = floor(x_size/13)
                shadow["Size"] = size + udim2_new(0, shadow_size, 0, 6)
                shadow["Position"] = udim2_new(0, -shadow_size/2, 0, -3)

                local new_notification = setmetatable({
                    ["inside"] = inside,
                    ["image"] = image,
                    ["text"] = text,
                    ["shadow"] = shadow,
                    ["start"] = clock(),
                    ["active"] = true
                }, notification)

                delay(clamp(time and typeof(time) == "number" and time or 2, 0.5, 7), function()
                    if new_notification["active"] then
                        new_notification:dismiss()
                    end
                end)

                local notifications = menu["notifications"]
                local viewport_size = camera["ViewportSize"]

                inside["Position"] = udim2_new(0, (viewport_size["X"]*0.5) - (x_size*0.5), 0, viewport_size["Y"]*0.88 - (#notifications*29 - 5))

                tween(inside, {Transparency = 0.89}, circular, out, 0.12)
                tween(image, show_transparency, circular, out, 0.12)
                tween(text, show_transparency, circular, out, 0.12)
                tween(shadow, {Transparency = 0.16}, circular, out, 0.12)

                notifications[#notifications+1] = new_notification

                spawn(update_notifications)
            end
        end

        function notification:dismiss()
            local inside = self["inside"]
            local image = self["image"]
            local text = self["text"]
            local shadow = self["shadow"]
            tween(inside, hide_transparency, circular, out, 0.12)
            tween(image, hide_transparency, circular, out, 0.12)
            tween(text, hide_transparency, circular, out, 0.12)
            tween(shadow, hide_transparency, circular, out, 0.12)
            self["active"] = false

            local notifications = menu["notifications"]
            for i = 1, #notifications do
                if notifications[i] == self then
                    remove(notifications, i)
                    break
                end
            end

            delay(0.12, function()
                inside:Destroy()
                image:Destroy()
                text:Destroy()
                shadow:Destroy()
                spawn(update_notifications)
            end)
        end
    end


    -- Bridge: F.pushNotification → juru-style typed colours
    -- true/1 = green (hit), 2 = yellow (info), 3 = red (error)
    -- "lock" / "white" / Color3 = custom colour (lock uses white)
    function F.pushNotification(text, isHitOrType, lifetime)
        if type(text) ~= "string" then return end
        local ntype = 2
        local color_override = nil
        if typeof(isHitOrType) == "Color3" then
            color_override = isHitOrType
            ntype = 1
        elseif isHitOrType == "lock" or isHitOrType == "white" then
            color_override = Color3.fromRGB(255, 255, 255)
            ntype = 1
        elseif isHitOrType == true or isHitOrType == 1 then
            ntype = 1
        elseif isHitOrType == 2 then
            ntype = 2
        elseif isHitOrType == 3 or isHitOrType == 4 then
            ntype = 3
        elseif isHitOrType == false or isHitOrType == nil then
            ntype = 2
        end
        local t = lifetime
        if typeof(t) ~= "number" then t = 2 end
        -- juru: 3rd arg can be Color3 (overrides type colour)
        if color_override then
            menu.new_notification(text, ntype, color_override)
            -- still auto-dismiss: fire a timed dismiss via second call path
            -- new_notification treats Color3 as colour and uses default 2s lifetime internally when time is Color3
        else
            menu.new_notification(text, ntype, t)
        end
    end

    F.newNotification = menu.new_notification
    shared._juru_menu_notifications = menu
end

-- ============================================================
-- ============================================================
-- HIT SOUNDS (juru PlayOnRemove + Play fallbacks)
-- ============================================================
do
    -- Prefer raw.githubusercontent.com (executors often fail on github.com redirects)
    local HIT_URLS = {
        ["primordial"] = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/primordial.ogg",
        ["neverlose"]  = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/neverlose.ogg",
        ["sparkle"]    = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/sparkle.ogg",
        ["mc bow"]     = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/mc%20bow.ogg",
        ["skeet"]      = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/skeet.ogg",
        ["break"]      = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/break.ogg",
        ["rust"]       = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/rust.ogg",
        ["sexy"]       = "https://raw.githubusercontent.com/hncddrtggqazcrezggs/juju/main/sexy.ogg",
    }

    -- Public Roblox fallbacks if download/getcustomasset fails
    local HIT_FALLBACK_ASSET = {
        ["primordial"] = "rbxassetid://5153733828",
        ["neverlose"]  = "rbxassetid://5153733828",
        ["sparkle"]    = "rbxassetid://5153733828",
        ["mc bow"]     = "rbxassetid://12222124",
        ["skeet"]      = "rbxassetid://5153733828",
        ["break"]      = "rbxassetid://12222208",
        ["rust"]       = "rbxassetid://5153733828",
        ["sexy"]       = "rbxassetid://5153733828",
    }

    local hit_sounds = {}
    local hit_sound_data = nil

    local function safeName(name)
        return tostring(name or "sound"):gsub("[^%w%-%_]", "_"):sub(1, 40)
    end

    local function download_bytes(url)
        local body = nil
        -- 1) request APIs (binary-safe, follows redirects better)
        pcall(function()
            local req = (syn and syn.request) or (http and http.request) or http_request or request
            if typeof(req) == "function" then
                local res = req({
                    Url = url,
                    Method = "GET",
                    Headers = { ["User-Agent"] = "Mozilla/5.0" },
                })
                if res then
                    local b = res.Body or res.body
                    if type(b) == "string" and #b > 64 then body = b end
                end
            end
        end)
        if type(body) == "string" and #body > 64 then return body end
        -- 2) custom binary helper if present
        pcall(function()
            if F.httpGetBinary then body = F.httpGetBinary(url) end
        end)
        if type(body) == "string" and #body > 64 then return body end
        -- 3) game:HttpGet
        pcall(function() body = game:HttpGet(url) end)
        if type(body) == "string" and #body > 64 then return body end
        return nil
    end

    local function ensure_folder()
        pcall(function()
            if typeof(isfolder) == "function" and typeof(makefolder) == "function" then
                if not isfolder("juru") then makefolder("juru") end
                if not isfolder("juru/assets") then makefolder("juru/assets") end
            end
        end)
    end

    local function isOgg(data)
        return type(data) == "string" and #data > 64 and data:sub(1, 4) == "OggS"
    end

    local function load_hit_sound(name)
        name = tostring(name or "mc bow")
        if hit_sounds[name] then return hit_sounds[name] end
        ensure_folder()

        local ok, asset = pcall(function()
            local cachePath = "juru/assets/" .. safeName(name) .. ".ogg"
            local data = nil

            -- try cache (reject empty/corrupt)
            if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(cachePath) then
                local cached = readfile(cachePath)
                if isOgg(cached) then
                    data = cached
                else
                    pcall(function() if delfile then delfile(cachePath) end end)
                end
            end

            if not data then
                local url = HIT_URLS[name]
                if not url then error("unknown sound " .. name) end
                data = download_bytes(url)
                if not isOgg(data) then
                    -- one more try via github redirect URL form
                    local alt = url:gsub("raw%.githubusercontent%.com/", "github.com/"):gsub("/main/", "/raw/main/")
                    data = download_bytes(alt)
                end
                if not isOgg(data) then error("no data") end
                pcall(function()
                    if typeof(writefile) == "function" then writefile(cachePath, data) end
                end)
            end

            if typeof(getcustomasset) ~= "function" then error("no getcustomasset") end
            if typeof(writefile) ~= "function" then error("no writefile") end

            local tmp = "juru_hit_" .. safeName(name) .. "_" .. tostring(math.random(10000, 99999)) .. ".ogg"
            writefile(tmp, data)
            local id = getcustomasset(tmp)
            pcall(function() if delfile then delfile(tmp) end end)
            if type(id) ~= "string" or id == "" then error("empty id") end
            return id
        end)

        if ok and type(asset) == "string" and asset ~= "" then
            hit_sounds[name] = asset
            return asset
        end

        -- fallback public rbxassetid
        local fb = HIT_FALLBACK_ASSET[name] or "rbxassetid://5153733828"
        warn("[Juru] hit sound FAILED:", name, tostring(asset), "→ fallback", fb)
        hit_sounds[name] = fb
        return fb
    end

    function F.playHitSound()
        local cfg = Config.HitSound
        if not cfg or cfg.Enabled == false then return end
        local name = cfg.Sound or "mc bow"
        if not hit_sound_data then
            hit_sound_data = load_hit_sound(name)
        end
        if not hit_sound_data then
            hit_sounds[name] = nil
            hit_sound_data = load_hit_sound(name)
        end
        if not hit_sound_data then
            warn("[Juru] no hit sound asset for", name)
            return
        end
        local vol = math.clamp(tonumber(cfg.Volume) or 1, 0.1, 5)

        local function playOn(parent)
            if not parent then return end
            local s = Instance.new("Sound")
            s.Name = "JuruHit"
            s.SoundId = hit_sound_data
            s.Volume = vol
            s.PlaybackSpeed = 1
            s.Looped = false
            s.RollOffMode = Enum.RollOffMode.Linear
            s.RollOffMaxDistance = 1e6
            s.RollOffMinDistance = 1e6
            s.EmitterSize = 100
            s.Parent = parent
            s:Play()
            task.delay(5, function()
                pcall(function() s:Stop() end)
                pcall(function() s:Destroy() end)
            end)
        end

        -- juru PlayOnRemove
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = hit_sound_data
            s.Volume = vol
            s.PlayOnRemove = true
            s.Name = " "
            s.Parent = sound_service
            s:Destroy()
        end)

        pcall(function() playOn(sound_service) end)
        pcall(function() playOn(workspace.CurrentCamera) end)
        pcall(function()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            playOn(hrp)
        end)
        pcall(function() playOn(LocalPlayer:FindFirstChild("PlayerGui")) end)
    end

    function F.setHitSound(name)
        if not Config.HitSound then Config.HitSound = { Enabled = true, Sound = "mc bow", Volume = 1 } end
        Config.HitSound.Sound = name
        hit_sounds[name] = nil
        hit_sound_data = load_hit_sound(name)
        if hit_sound_data and Config.HitSound.Enabled ~= false then
            F.playHitSound()
        end
    end

    task.spawn(function()
        task.wait(0.5)
        local loaded = 0
        for name in pairs(HIT_URLS) do
            local id = load_hit_sound(name)
            if id and not tostring(id):find("rbxassetid://") then
                loaded = loaded + 1
            elseif id then
                loaded = loaded + 1 -- fallback counts as available
            end
            task.wait(0.05)
        end
        local sel = (Config.HitSound and Config.HitSound.Sound) or "mc bow"
        hit_sound_data = hit_sounds[sel] or load_hit_sound(sel)
        if hit_sound_data then
            print("[Juru] Hit sounds ready (" .. tostring(loaded) .. " packs, selected: " .. tostring(sel) .. ")")
        else
            warn("[Juru] Hit sounds unavailable (writefile/getcustomasset/http blocked)")
        end
    end)
end

-- ============================================================
-- RAPID FIRE (old method only: Activate spam while holding M1)
-- ============================================================
do
    local lastRfTick = 0

    function F.rfResetPatches() end
    function F.rfApplyEnabled(_value) end

    -- RF is OFF unless Config.RapidFire.Enabled is true. No Activate spam when off.
    F.jConnect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            F.markShot()
            if Config.RapidFire and Config.RapidFire.Enabled == true then
                rapidFireActive = true
            else
                rapidFireActive = false
            end
        end
    end)
    F.jConnect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            rapidFireActive = false
        end
    end)

    F.jConnect(RunService.Heartbeat, function()
        if not JuruAlive then return end
        -- hard off
        if not Config.RapidFire or Config.RapidFire.Enabled ~= true then
            if rapidFireActive then rapidFireActive = false end
            return
        end
        if not rapidFireActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        local delay = math.max(0.03, tonumber(Config.RapidFire.Delay) or 0.05)
        local now = tick()
        if now - lastRfTick < delay then return end
        lastRfTick = now
        pcall(function() tool:Activate() end)
        F.markShot()
    end)
end


function F._init_keyOverlay()
-- ============================================================
-- Key Overlay HUD (WASD / Space / LMB / RMB + enabled features)
-- ============================================================
local keyOverlayGui = nil
local keysRoot = nil
local enabledRoot = nil
local keyCells = {}
local enabledListLabel = nil
local keysDragging, enabledDragging, enabledResizing = false, false, false
local enabledResizeStart, enabledResizeOrig = Vector2.new(), Vector2.new()
local keysDragOffset, enabledDragOffset = Vector2.new(), Vector2.new()

local KO_SIZE = 34
local KO_GAP = 5
local KO_MOUSE = 28
local KO_SPC_H = 18


local KEY_OVERLAY_FILE = "Juru_KeyOverlay.json"

function F.saveKeyOverlayLayout()
    local c = Config.KeyOverlay
    if not c then return end
    pcall(function()
        if typeof(writefile) ~= "function" then return end
        local payload = {
            KeysPosition = c.KeysPosition,
            EnabledPosition = c.EnabledPosition,
            EnabledSize = c.EnabledSize,
            KeysDraggable = c.KeysDraggable,
            EnabledDraggable = c.EnabledDraggable,
        }
        writefile(KEY_OVERLAY_FILE, HttpService:JSONEncode(payload))
    end)
end

function F.loadKeyOverlayLayout()
    pcall(function()
        if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
        if not isfile(KEY_OVERLAY_FILE) then return end
        local raw = readfile(KEY_OVERLAY_FILE)
        local data = HttpService:JSONDecode(raw)
        if type(data) ~= "table" then return end
        Config.KeyOverlay = Config.KeyOverlay or {}
        local c = Config.KeyOverlay
        if type(data.KeysPosition) == "table" then
            c.KeysPosition = { X = tonumber(data.KeysPosition.X) or 0.02, Y = tonumber(data.KeysPosition.Y) or 0.55 }
        end
        if type(data.EnabledPosition) == "table" then
            c.EnabledPosition = { X = tonumber(data.EnabledPosition.X) or 0.02, Y = tonumber(data.EnabledPosition.Y) or 0.78 }
        end
        if type(data.EnabledSize) == "table" then
            c.EnabledSize = { W = tonumber(data.EnabledSize.W) or 140, H = tonumber(data.EnabledSize.H) or 120 }
        end
        if data.KeysDraggable ~= nil then c.KeysDraggable = data.KeysDraggable and true or false end
        if data.EnabledDraggable ~= nil then c.EnabledDraggable = data.EnabledDraggable and true or false end
    end)
end

function F.keyOverlayCfg()
    if not Config.KeyOverlay then
        Config.KeyOverlay = {
            Enabled = false, Visible = false,
            ShowKeys = true, ShowEnabled = true,
            KeysDraggable = true, EnabledDraggable = true,
            KeysPosition = { X = 0.02, Y = 0.55 },
            EnabledPosition = { X = 0.02, Y = 0.78 },
            PressColor = Color3.fromRGB(170, 100, 255),
            IdleColor = Color3.fromRGB(40, 36, 52),
            TextColor = Color3.fromRGB(235, 230, 255),
        }
    end
    local k = Config.KeyOverlay
    if k.KeysDraggable == nil then k.KeysDraggable = true end
    if k.EnabledDraggable == nil then k.EnabledDraggable = true end
    if not k.KeysPosition then k.KeysPosition = { X = 0.02, Y = 0.55 } end
    if not k.EnabledPosition then k.EnabledPosition = { X = 0.02, Y = 0.78 } end
    if not k.EnabledSize then k.EnabledSize = { W = 140, H = 120 } end
    return k
end

-- Load saved overlay layout once at startup
task.defer(function()
    F.loadKeyOverlayLayout()
end)


function F.makeKeyCell(parent, text, size, textSize)
    local f = Instance.new("Frame")
    f.Size = size or UDim2.new(0, KO_SIZE, 0, KO_SIZE)
    f.BackgroundColor3 = Color3.fromRGB(40, 36, 52)
    f.BorderSizePixel = 0
    f.ZIndex = 50
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)
    local lab = Instance.new("TextLabel")
    lab.BackgroundTransparency = 1
    lab.Size = UDim2.new(1, 0, 1, 0)
    lab.Font = Enum.Font.GothamBold
    lab.TextSize = textSize or 12
    lab.TextColor3 = Color3.fromRGB(235, 230, 255)
    lab.Text = text
    lab.ZIndex = 51
    lab.Parent = f
    return f, lab
end

function F.destroyKeyOverlay()
    if keyOverlayGui then
        pcall(function() keyOverlayGui:Destroy() end)
    end
    keyOverlayGui = nil
    keysRoot = nil
    enabledRoot = nil
    keyCells = {}
    enabledListLabel = nil
    keysDragging, enabledDragging = false, false
end

function F.wirePanelDrag(frame, which)
    frame.InputBegan:Connect(function(input)
        if enabledResizing then return end
        local c = F.keyOverlayCfg()
        local can = (which == "keys" and c.KeysDraggable) or (which == "enabled" and c.EnabledDraggable)
        if not can or not c.Enabled then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local mouse = UserInputService:GetMouseLocation()
        local abs = frame.AbsolutePosition
        if which == "keys" then
            keysDragging = true
            keysDragOffset = Vector2.new(mouse.X - abs.X, mouse.Y - abs.Y)
        else
            enabledDragging = true
            enabledDragOffset = Vector2.new(mouse.X - abs.X, mouse.Y - abs.Y)
        end
    end)
end

function F.buildKeyOverlay()
    F.destroyKeyOverlay()
    local cfg = F.keyOverlayCfg()
    if not cfg.Enabled then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = F.randomGuiName()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 50
    gui.Enabled = cfg.Visible ~= false
    F.protectGui(gui)
    pcall(function() gui.Parent = F.getUiParent() end)
    if not gui.Parent then
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
    keyOverlayGui = gui

    local gridW = KO_SIZE * 3 + KO_GAP * 2

    -- ===== Keys panel (independent) =====
    local kRoot = Instance.new("Frame")
    kRoot.Name = "KeysRoot"
    kRoot.BackgroundTransparency = 1
    kRoot.BorderSizePixel = 0
    kRoot.Size = UDim2.new(0, gridW, 0, KO_SIZE * 2 + KO_GAP + KO_SPC_H + KO_GAP + KO_MOUSE)
    kRoot.ZIndex = 40
    local kpos = cfg.KeysPosition or { X = 0.02, Y = 0.55 }
    kRoot.Position = UDim2.new(kpos.X or 0.02, 0, kpos.Y or 0.55, 0)
    kRoot.Visible = cfg.ShowKeys ~= false
    kRoot.Parent = gui
    keysRoot = kRoot
    F.wirePanelDrag(kRoot, "keys")

    local function place(id, keyEnum, mouseEnum, x, y, w, h, label, tsize)
        local frame, lab = F.makeKeyCell(kRoot, label or id, UDim2.new(0, w, 0, h), tsize)
        frame.Position = UDim2.new(0, x, 0, y)
        keyCells[id] = {
            frame = frame,
            label = lab,
            def = { id = id, key = keyEnum, mouse = mouseEnum },
        }
        -- allow drag start from key cells too
        F.wirePanelDrag(frame, "keys")
    end

    place("W", Enum.KeyCode.W, nil, KO_SIZE + KO_GAP, 0, KO_SIZE, KO_SIZE, "W", 13)
    local y2 = KO_SIZE + KO_GAP
    place("A", Enum.KeyCode.A, nil, 0, y2, KO_SIZE, KO_SIZE, "A", 13)
    place("S", Enum.KeyCode.S, nil, KO_SIZE + KO_GAP, y2, KO_SIZE, KO_SIZE, "S", 13)
    place("D", Enum.KeyCode.D, nil, (KO_SIZE + KO_GAP) * 2, y2, KO_SIZE, KO_SIZE, "D", 13)
    local y3 = y2 + KO_SIZE + KO_GAP
    place("SPC", Enum.KeyCode.Space, nil, 0, y3, gridW, KO_SPC_H, "", 10)
    local y4 = y3 + KO_SPC_H + KO_GAP
    -- LMB/RMB: same height as KO_MOUSE, wider so they nearly meet with a small gap
    local mouseGap = 4
    local mouseW = math.floor((gridW - mouseGap) / 2)
    place("LMB", nil, Enum.UserInputType.MouseButton1, 0, y4, mouseW, KO_MOUSE, "LMB", 10)
    place("RMB", nil, Enum.UserInputType.MouseButton2, mouseW + mouseGap, y4, mouseW, KO_MOUSE, "RMB", 10)

    -- ===== Enabled features panel (independent) =====
    local eSize = cfg.EnabledSize or { W = 140, H = 120 }
    local eW = math.clamp(tonumber(eSize.W) or 140, 80, 400)
    local eH = math.clamp(tonumber(eSize.H) or 120, 40, 500)

    local eRoot = Instance.new("Frame")
    eRoot.Name = "EnabledRoot"
    eRoot.BackgroundTransparency = 1 -- fully transparent panel
    eRoot.BorderSizePixel = 0
    eRoot.Size = UDim2.fromOffset(eW, eH)
    eRoot.ClipsDescendants = false
    eRoot.ZIndex = 40
    local epos = cfg.EnabledPosition or { X = 0.02, Y = 0.78 }
    eRoot.Position = UDim2.new(epos.X or 0.02, 0, epos.Y or 0.78, 0)
    eRoot.Visible = cfg.ShowEnabled ~= false
    eRoot.Parent = gui
    enabledRoot = eRoot
    F.wirePanelDrag(eRoot, "enabled")

    local function enabledTextSizeFor(h)
        return math.clamp(math.floor(10 + (h - 40) * 0.12), 11, 42)
    end

    enabledListLabel = Instance.new("TextLabel")
    enabledListLabel.BackgroundTransparency = 1
    enabledListLabel.Size = UDim2.new(1, -10, 1, -10)
    enabledListLabel.Position = UDim2.fromOffset(5, 5)
    enabledListLabel.Font = Enum.Font.Gotham
    enabledListLabel.TextSize = enabledTextSizeFor(eH)
    enabledListLabel.TextScaled = false
    enabledListLabel.TextXAlignment = Enum.TextXAlignment.Left
    enabledListLabel.TextYAlignment = Enum.TextYAlignment.Top
    enabledListLabel.TextColor3 = Color3.fromRGB(210, 205, 230)
    enabledListLabel.TextStrokeTransparency = 0.5
    enabledListLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    enabledListLabel.TextWrapped = true
    enabledListLabel.Text = ""
    enabledListLabel.ZIndex = 41
    enabledListLabel.Parent = eRoot
    F.wirePanelDrag(enabledListLabel, "enabled")

    -- Resize handle (bottom-right) — Active required for input on transparent parents
    eRoot.Active = true
    local resize = Instance.new("TextButton")
    resize.Name = "ResizeHandle"
    resize.Size = UDim2.fromOffset(18, 18)
    resize.Position = UDim2.new(1, -18, 1, -18)
    resize.BackgroundColor3 = Color3.fromRGB(180, 120, 255)
    resize.BackgroundTransparency = 0.15
    resize.BorderSizePixel = 0
    resize.Text = ""
    resize.AutoButtonColor = false
    resize.ZIndex = 60
    resize.Active = true
    resize.Parent = eRoot
    Instance.new("UICorner", resize).CornerRadius = UDim.new(0, 3)
    resize.MouseButton1Down:Connect(function()
        enabledDragging = false
        enabledResizing = true
        local mouse = UserInputService:GetMouseLocation()
        enabledResizeStart = Vector2.new(mouse.X, mouse.Y)
        enabledResizeOrig = Vector2.new(eRoot.AbsoluteSize.X, eRoot.AbsoluteSize.Y)
    end)
    resize.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            enabledDragging = false
            enabledResizing = true
            local mouse = UserInputService:GetMouseLocation()
            enabledResizeStart = Vector2.new(mouse.X, mouse.Y)
            enabledResizeOrig = Vector2.new(eRoot.AbsoluteSize.X, eRoot.AbsoluteSize.Y)
        end
    end)

    F.jConnect(UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local c = F.keyOverlayCfg()
        local mouse = UserInputService:GetMouseLocation()
        local vs = Camera.ViewportSize
        if enabledResizing and enabledRoot then
            local dx = mouse.X - enabledResizeStart.X
            local dy = mouse.Y - enabledResizeStart.Y
            local nw = math.clamp(enabledResizeOrig.X + dx, 80, 500)
            local nh = math.clamp(enabledResizeOrig.Y + dy, 40, 600)
            enabledRoot.Size = UDim2.fromOffset(nw, nh)
            c.EnabledSize = { W = nw, H = nh }
            if enabledListLabel then
                -- Gotham text grows with panel height
                enabledListLabel.TextSize = math.clamp(math.floor(10 + (nh - 40) * 0.12), 11, 42)
            end
            return
        end
        if keysDragging and keysRoot and c.KeysDraggable then
            local x = math.clamp(mouse.X - keysDragOffset.X, 0, vs.X - 40)
            local y = math.clamp(mouse.Y - keysDragOffset.Y, 0, vs.Y - 40)
            keysRoot.Position = UDim2.new(0, x, 0, y)
            c.KeysPosition = { X = x / math.max(vs.X, 1), Y = y / math.max(vs.Y, 1) }
        elseif keysDragging and not c.KeysDraggable then
            keysDragging = false
        end
        if enabledDragging and enabledRoot and c.EnabledDraggable then
            local x = math.clamp(mouse.X - enabledDragOffset.X, 0, vs.X - 40)
            local y = math.clamp(mouse.Y - enabledDragOffset.Y, 0, vs.Y - 40)
            enabledRoot.Position = UDim2.new(0, x, 0, y)
            c.EnabledPosition = { X = x / math.max(vs.X, 1), Y = y / math.max(vs.Y, 1) }
        elseif enabledDragging and not c.EnabledDraggable then
            enabledDragging = false
        end
    end)
    F.jConnect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if keysDragging or enabledDragging or enabledResizing then
                F.saveKeyOverlayLayout()
            end
            keysDragging = false
            enabledDragging = false
            enabledResizing = false
        end
    end)
end

function F.isKeyOverlayHeld(def)
    if def.key then
        return UserInputService:IsKeyDown(def.key)
    end
    if def.mouse then
        return UserInputService:IsMouseButtonPressed(def.mouse)
    end
    return false
end

function F.getEnabledFeaturesText()
    local lines = {}
    local function add(on, name)
        if on then table.insert(lines, "• " .. name) end
    end
    add(Config.SilentAim and Config.SilentAim.Enabled, "Silent Aim")
    add(Config.SilentAim and Config.SilentAim.UseCameraAimbot, "Camera Aim")
    add(Config.SoftLock and Config.SoftLock.Enabled, "Soft Lock")
    add(Config.WallShoot and Config.WallShoot.Enabled, "Wall Bang")
    add(Config.Ragebot and Config.Ragebot.Enabled, "Ragebot")
    add(isLocking, "Target Lock")
    add(triggerEnabled, "Trigger Bot")
    add(SpeedEnabled and Config.Speed and Config.Speed.Enabled, "Speed")
    add(cFrameSpeedEnabled and Config.CFrameSpeed and Config.CFrameSpeed.Enabled, "CFrame Speed")
    add(superJumpActive and Config.SuperJump and Config.SuperJump.Enabled, "Super Jump")
    add(flyEnabled, "Fly")
    add(rageBotEnabled, "Rage")
    add(Config.AntiRage and Config.AntiRage.Enabled, "AntiRage")
    add(Config.RapidFire and Config.RapidFire.Enabled and rapidFireActive, "Rapid Fire")
    add(Config.Hitbox and Config.Hitbox.Enabled, "Hitbox")
    add(Config.Visuals and Config.Visuals.Enabled, "Visuals")
    add(Config.AntiMod and Config.AntiMod.Enabled, "AntiMod")
    if #lines == 0 then return "" end
    return table.concat(lines, "\n")
end

local _keyOvHeld = {} -- id -> last held state (skip redundant color writes)
local _keyOvEnabledAt = 0
local _keyOvLastEnabledTxt = ""

function F.updateKeyOverlay()
    local cfg = F.keyOverlayCfg()
    if not cfg.Enabled then
        if keyOverlayGui then F.destroyKeyOverlay() end
        return
    end
    if not keyOverlayGui or not keyOverlayGui.Parent then
        F.buildKeyOverlay()
        _keyOvHeld = {}
    end
    if not keyOverlayGui then return end
    keyOverlayGui.Enabled = cfg.Visible ~= false

    if keysRoot then keysRoot.Visible = cfg.ShowKeys ~= false end
    if enabledRoot then enabledRoot.Visible = cfg.ShowEnabled ~= false end

    if cfg.ShowKeys ~= false then
        local press = cfg.PressColor or Color3.fromRGB(170, 100, 255)
        local idle = cfg.IdleColor or Color3.fromRGB(40, 36, 52)
        local textCol = cfg.TextColor or Color3.fromRGB(235, 230, 255)
        for id, cell in pairs(keyCells) do
            local held = F.isKeyOverlayHeld(cell.def)
            if _keyOvHeld[id] ~= held then
                _keyOvHeld[id] = held
                if cell.frame then
                    cell.frame.BackgroundColor3 = held and press or idle
                end
                if cell.label then
                    cell.label.TextColor3 = held and Color3.fromRGB(255, 255, 255) or textCol
                end
            end
        end
    end

    -- Enabled list is text-only — refresh at ~4 Hz, not every frame
    if enabledListLabel and cfg.ShowEnabled ~= false then
        local now = tick()
        if now - _keyOvEnabledAt >= 0.25 then
            _keyOvEnabledAt = now
            local txt = F.getEnabledFeaturesText()
            if txt ~= _keyOvLastEnabledTxt then
                _keyOvLastEnabledTxt = txt
                enabledListLabel.Text = txt
            end
        end
    end
end

task.defer(function()
    task.wait(0.4)
    if JuruAlive then F.buildKeyOverlay() end
end)

F.jConnect(RunService.RenderStepped, function()
    if not JuruAlive then return end
    F.updateKeyOverlay()
end)



end
F._init_keyOverlay()

-- Safe character helpers (games differ: no HRP, delayed spawn, custom rigs)
function F.getCharacter(player)
    player = player or LocalPlayer
    if not player then return nil end
    local ok, char = pcall(function() return player.Character end)
    if ok and char and char.Parent then return char end
    return nil
end

function F.getHumanoid(charOrPlayer)
    local char = charOrPlayer
    if typeof(charOrPlayer) == "Instance" and charOrPlayer:IsA("Player") then
        char = F.getCharacter(charOrPlayer)
    end
    if not char then return nil end
    local ok, hum = pcall(function() return char:FindFirstChildOfClass("Humanoid") end)
    if ok then return hum end
    return nil
end

function F.getHRP(charOrPlayer)
    local char = charOrPlayer
    if typeof(charOrPlayer) == "Instance" and charOrPlayer:IsA("Player") then
        char = F.getCharacter(charOrPlayer)
    end
    if not char then return nil end
    local ok, part = pcall(function()
        return char:FindFirstChild("HumanoidRootPart")
            or char.PrimaryPart
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("Head")
            or char:FindFirstChildWhichIsA("BasePart")
    end)
    if ok then return part end
    return nil
end

-- True if instance is still usable (avoids "expired" / destroyed errors)
function F.isValidPart(inst)
    if typeof(inst) ~= "Instance" then return false end
    local ok, alive = pcall(function()
        return inst.Parent ~= nil and inst:IsDescendantOf(game)
    end)
    return ok and alive == true
end

function F.safePartPosition(part)
    if not F.isValidPart(part) then return nil end
    local ok, pos = pcall(function() return part.Position end)
    if ok and typeof(pos) == "Vector3" then return pos end
    return nil
end

function F.waitForCharacter(player, timeout)
    player = player or LocalPlayer
    timeout = timeout or 8
    local char = F.getCharacter(player)
    if char then
        F.getHRP(char) -- best-effort
        return char
    end
    local t0 = tick()
    while tick() - t0 < timeout do
        char = F.getCharacter(player)
        if char then
            pcall(function()
                char:WaitForChild("HumanoidRootPart", math.max(0.1, timeout - (tick() - t0)))
            end)
            return char
        end
        task.wait(0.1)
    end
    return F.getCharacter(player)
end

function F.getAimPart(character)
    if not character then return nil end
    local prefer = (Config.SilentAim and Config.SilentAim.HitPart) or "Torso"
    local ok, part = pcall(function()
        if prefer == "Head" then
            return character:FindFirstChild("Head")
                or character:FindFirstChild("UpperTorso")
                or character:FindFirstChild("HumanoidRootPart")
                or character.PrimaryPart
        elseif prefer == "Root" then
            return character:FindFirstChild("HumanoidRootPart")
                or character.PrimaryPart
                or character:FindFirstChild("UpperTorso")
                or character:FindFirstChild("Head")
        end
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
            or character.PrimaryPart
            or character:FindFirstChild("Head")
            or character:FindFirstChildWhichIsA("BasePart")
    end)
    if ok then return part end
    return nil
end


function F.stickyLockOn()
    return Config.Settings and Config.Settings.StickyLock == true
end

function F.isPlayerKnockedOrKO(player)
    if not Config.Settings.KnockCheck then return false end
    if player and player.Character then
        local be = player.Character:FindFirstChild("BodyEffects")
        if be then
            if be:FindFirstChild("K.O") and be["K.O"].Value then return true end
            if be:FindFirstChild("Knocked") and be.Knocked.Value then return true end
        end
    end
    return false
end

function F.isSelfKnocked()
    if LocalPlayer.Character then
        local be = LocalPlayer.Character:FindFirstChild("BodyEffects")
        if be then
            if be:FindFirstChild("K.O") and be["K.O"].Value then return true end
            if be:FindFirstChild("Knocked") and be.Knocked.Value then return true end
        end
    end
    return false
end

function F.isInFOV(character)
    if not Config.FOV.Enabled then return true end
    if not character then return false end
    local part = F.getAimPart(character) or character:FindFirstChild("Head")
    if not part then return false end
    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return false end
    local mousePos = UserInputService:GetMouseLocation()
    local dx = math.abs(pos.X - mousePos.X)
    local dy = math.abs(pos.Y - mousePos.Y)
    local r = Config.FOV.Size or 95
    local shape = (Config.FOV.Shape or "Circle"):lower()
    if shape == "square" then
        return dx <= r and dy <= r
    elseif shape == "diamond" then
        return (dx + dy) <= r
    end
    -- circle / hexagon: radial
    return math.sqrt(dx * dx + dy * dy) <= r
end

function F.getPredictedPosition(part)
    local pos = F.safePartPosition(part)
    if not pos then return Vector3.new() end
    if Config.SilentAim and Config.SilentAim.UsePrediction then
        local vel = Vector3.new()
        pcall(function()
            if not F.isValidPart(part) then return end
            vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
        end)
        local pred = Config.SilentAim.Prediction
        if type(pred) == "table" then
            pos = pos + Vector3.new(vel.X * (pred.X or 0), vel.Y * (pred.Y or 0), vel.Z * (pred.Z or 0))
        else
            pos = pos + vel * (tonumber(pred) or 0.13)
        end
    end
    local acc = (Config.SilentAim and tonumber(Config.SilentAim.Accuracy)) or 100
    if acc < 100 then
        local err = (100 - math.clamp(acc, 0, 100)) / 100 * 2.5
        pos = pos + Vector3.new(
            (math.random() - 0.5) * 2 * err,
            (math.random() - 0.5) * err,
            (math.random() - 0.5) * 2 * err
        )
    end
    return pos
end

function F.findClosestTarget()
    local closest, shortest = nil, math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local cam = Workspace.CurrentCamera or Camera
    if not cam then return nil end
    for _, player in pairs(Players:GetPlayers()) do
        pcall(function()
            if player == LocalPlayer or F.isWhitelisted(player) then return end
            local char = F.getCharacter(player)
            if not char or F.isPlayerKnockedOrKO(player) then return end
            if not F.getHRP(char) then return end
            local targetPart = F.getAimPart(char)
            if not F.isValidPart(targetPart) then return end
            local worldPos = F.safePartPosition(targetPart)
            if not worldPos then return end
            local pos, onScreen = cam:WorldToViewportPoint(worldPos)
            if not onScreen then return end
            local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
            if F.isInFOV(char) and dist < shortest then
                shortest = dist
                closest = targetPart
            end
        end)
    end
    return closest
end

function F.forceLockOnPlayer(plr)
    local canLock = (Config.SilentAim and Config.SilentAim.Enabled == true)
        or (Config.SilentAim and Config.SilentAim.UseCameraAimbot == true)
        or (Config.SoftLock and Config.SoftLock.Enabled == true)
        or (Config.Ragebot and Config.Ragebot.Enabled == true)
        or (Config.RageBot and Config.RageBot.Enabled == true)
        or (rageBotEnabled == true)
    if not canLock then
        return false
    end
    if not plr or plr == LocalPlayer then return false end
    local char = F.getCharacter(plr)
    if not char then return false end
    local part = F.getAimPart(char)
    if not part then return false end
    currentTarget = part
    isLocking = true
    shared._juruLastLockUid = plr.UserId
    return true
end

function F.clearTargetLock()
    if rageBotEnabled and rageTargetPlayer then return end
    isLocking = false
    currentTarget = nil
    -- keep _juruLastLockUid for sticky re-acquire after intentional unlock only clear if not sticky? keep it
end

local stickyTracked = {}
function F.ensureStickyRespawnTrack(plr)
    if not plr or stickyTracked[plr.UserId] then return end
    stickyTracked[plr.UserId] = true
    F.jConnect(plr.CharacterAdded, function(char)
        if not JuruAlive or not F.stickyLockOn() then return end
        if shared._juruLastLockUid ~= plr.UserId then return end
        if rageBotEnabled then return end
        task.wait(0.2)
        if F.stickyLockOn() and shared._juruLastLockUid == plr.UserId then
            F.forceLockOnPlayer(plr)
        end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then F.ensureStickyRespawnTrack(p) end
end
F.jConnect(Players.PlayerAdded, function(p)
    if p ~= LocalPlayer then F.ensureStickyRespawnTrack(p) end
end)

function F.softLockEnabled()
    return Config.SoftLock and Config.SoftLock.Enabled == true
end

-- Soft Lock: hover-to-lock inside FOV. Sticky with hysteresis so it doesn't flicker.
function F.updateSoftLock()
    if not JuruAlive or not F.softLockEnabled() then return end
    if rageBotEnabled then return end

    -- Drop invalid / whitelisted current target (knocked only if StickyLock off)
    if isLocking and currentTarget then
        local char = currentTarget.Parent
        local plr = char and Players:GetPlayerFromCharacter(char)
        local dropKnock = (not F.stickyLockOn()) and plr and F.isPlayerKnockedOrKO(plr)
        if not char or not plr or not plr.Parent or dropKnock or F.isWhitelisted(plr) then
            F.clearTargetLock()
        else
            -- refresh aim part on same character (or wait for respawn if sticky + KO)
            local part = F.getAimPart(char)
            if part then currentTarget = part end
        end
    end

    local closest = F.findClosestTarget()
    if not closest or not closest.Parent then return end

    local newPlr = Players:GetPlayerFromCharacter(closest.Parent)
    if not newPlr then return end

    if not isLocking or not currentTarget or not currentTarget.Parent then
        currentTarget = closest
        isLocking = true
        lastSwitchTargetTick = tick()
        return
    end

    -- switch target speed gate (only when changing to a different player)
    do
        local curPlr0 = Players:GetPlayerFromCharacter(currentTarget.Parent)
        if curPlr0 and newPlr and curPlr0 ~= newPlr then
            local spd = 0.12
            if Config.Settings and tonumber(Config.Settings.SwitchTargetSpeed) then
                spd = tonumber(Config.Settings.SwitchTargetSpeed)
            end
            if tick() - (lastSwitchTargetTick or 0) < spd then
                return
            end
            lastSwitchTargetTick = tick()
        end
    end

    local curPlr = Players:GetPlayerFromCharacter(currentTarget.Parent)
    if not curPlr or curPlr == newPlr then
        currentTarget = closest
        isLocking = true
        return
    end

    -- Switch only when the new target is meaningfully closer to the mouse (hysteresis)
    local mousePos = UserInputService:GetMouseLocation()
    local function screenDist(part)
        if not part then return math.huge end
        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then return math.huge end
        return (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
    end
    local dNew = screenDist(closest)
    local dCur = screenDist(F.getAimPart(currentTarget.Parent) or currentTarget)
    if dNew < dCur * 0.82 then
        currentTarget = closest
        isLocking = true
    end
end

function F.getSilentAimCFrame()
    if not isLocking or not currentTarget or not currentTarget.Parent then return nil end
    local player = Players:GetPlayerFromCharacter(currentTarget.Parent)
    if not player or F.isPlayerKnockedOrKO(player) or F.isWhitelisted(player) then return nil end
    local part = F.getAimPart(currentTarget.Parent) or currentTarget
    if not part then return nil end
    local pos = F.getPredictedPosition(part)
    if (Config.SilentAim.HitPart or "Torso") ~= "Head" then
        pos = pos + Vector3.new(0, 1.35, 0)
    end
    return CFrame.new(pos)
end

function F.restoreOwnCamera()
    pcall(function()
        local cam = Workspace.CurrentCamera
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and cam then
            cam.CameraSubject = hum
            cam.CameraType = Enum.CameraType.Custom
            Camera = cam
        end
    end)
    wasSpectating = false
end

local manualSpectatePlayer = nil -- sticky manual spectate target (Players tab)

function F.spectatePlayer(plr, manual)
    if not plr or not plr.Parent then return false end
    local cam = Workspace.CurrentCamera
    local tChar = plr.Character
    local thum = tChar and tChar:FindFirstChildOfClass("Humanoid")
    if thum and cam then
        cam.CameraSubject = thum
        cam.CameraType = Enum.CameraType.Custom
        Camera = cam
        wasSpectating = true
        if manual then
            manualSpectatePlayer = plr
        end
        return true
    end
    return false
end

function F.stopManualSpectate()
    manualSpectatePlayer = nil
    F.restoreOwnCamera()
end

function F.updateSpectate()
    -- Rage spectate (non-Xeno)
    if rageBotEnabled and rageTargetPlayer and not isXeno then
        if F.spectatePlayer(rageTargetPlayer, false) then return end
    end
    -- Manual spectate from Players tab — keep camera on them (rebind on respawn)
    if manualSpectatePlayer and manualSpectatePlayer.Parent then
        local thum = manualSpectatePlayer.Character and manualSpectatePlayer.Character:FindFirstChildOfClass("Humanoid")
        local cam = Workspace.CurrentCamera
        if thum and cam then
            if cam.CameraSubject ~= thum then
                cam.CameraSubject = thum
                cam.CameraType = Enum.CameraType.Custom
                Camera = cam
            end
            wasSpectating = true
            return
        end
        -- character missing (dead) — wait for respawn, don't restore yet
        return
    end
    if wasSpectating and not manualSpectatePlayer then
        F.restoreOwnCamera()
    end
end


-- ============================================================
-- Aim Viewer: spectate target + local-only aim pole from their gun
-- ============================================================
local aimViewerPlayer = nil
local aimViewerEnabled = false
local aimPolePart = nil
local aimPoleAtt0, aimPoleAtt1 = nil, nil
local aimPoleBeam = nil

function F.destroyAimPole()
    pcall(function() if aimPoleBeam then aimPoleBeam:Destroy() end end)
    pcall(function() if aimPolePart then aimPolePart:Destroy() end end)
    pcall(function() if aimPoleAtt0 then aimPoleAtt0:Destroy() end end)
    pcall(function() if aimPoleAtt1 then aimPoleAtt1:Destroy() end end)
    aimPolePart, aimPoleBeam, aimPoleAtt0, aimPoleAtt1 = nil, nil, nil, nil
end

function F.ensureAimPole()
    if aimPolePart and aimPolePart.Parent then return end
    F.destroyAimPole()
    local p = Instance.new("Part")
    p.Name = "JuruAimPole"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(255, 60, 90)
    p.Transparency = 0.15
    p.Size = Vector3.new(0.12, 0.12, 80)
    p.CastShadow = false
    p.Parent = Workspace
    aimPolePart = p
end

function F.getAimViewerMuzzle(char)
    if not char then return nil, nil end
    local tool = char:FindFirstChildOfClass("Tool")
    local origin, look = nil, nil
    if tool then
        local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
        if handle then
            origin = handle.Position
            -- Prefer barrel look: tool Handle CFrame LookVector, else head
            look = handle.CFrame.LookVector
        end
    end
    local head = char:FindFirstChild("Head")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not origin and head then
        origin = head.Position
    end
    if not origin and hrp then
        origin = hrp.Position + Vector3.new(0, 1.5, 0)
    end
    if not look then
        if head then
            look = head.CFrame.LookVector
        elseif hrp then
            look = hrp.CFrame.LookVector
        end
    end
    -- If they have a tool, blend slightly with head aim (common for lock visuals)
    if tool and head and look then
        local hl = head.CFrame.LookVector
        look = (look * 0.35 + hl * 0.65).Unit
        origin = origin or head.Position
    end
    return origin, look
end

function F.updateAimViewer()
    if not aimViewerEnabled or not aimViewerPlayer or not aimViewerPlayer.Parent then
        F.destroyAimPole()
        return
    end
    local char = aimViewerPlayer.Character
    if not char then
        F.destroyAimPole()
        return
    end
    local origin, look = F.getAimViewerMuzzle(char)
    if not origin or not look then
        F.destroyAimPole()
        return
    end
    F.ensureAimPole()
    if not aimPolePart then return end
    local length = 120
    local mid = origin + look * (length * 0.5)
    aimPolePart.Size = Vector3.new(0.1, 0.1, length)
    aimPolePart.CFrame = CFrame.lookAt(mid, mid + look)
    aimPolePart.Color = Color3.fromRGB(255, 50, 90)
    aimPolePart.Transparency = 0.12
end

function F.setAimViewer(plr, on)
    if on and plr and plr.Parent and plr ~= LocalPlayer then
        aimViewerEnabled = true
        aimViewerPlayer = plr
        -- Spectate them
        if not isXeno then
            pcall(function() F.spectatePlayer(plr, true) end)
        end
        F.ensureAimPole()
        F.updateAimViewer()
        return true
    end
    aimViewerEnabled = false
    aimViewerPlayer = nil
    F.destroyAimPole()
    return false
end

function F.stopAimViewer(restoreCam)
    aimViewerEnabled = false
    aimViewerPlayer = nil
    F.destroyAimPole()
    if restoreCam ~= false then
        pcall(function() F.stopManualSpectate() end)
    end
end

F.jConnect(RunService.RenderStepped, function()
    if not JuruAlive then return end
    if aimViewerEnabled then
        F.updateAimViewer()
    end
end)


function F.pickRageTarget()
    local list = (#rageTargetList > 0) and rageTargetList or (rageTargetPlayer and {rageTargetPlayer} or {})
    for _, plr in ipairs(list) do
        if plr and plr.Parent and F.getCharacter(plr) and not F.isWhitelisted(plr) then
            local hum = F.getHumanoid(plr)
            if hum and hum.Health > 0 and not F.isPlayerKnockedOrKO(plr) then
                return plr
            end
        end
    end
    for _, plr in ipairs(list) do
        if plr and plr.Parent and not F.isWhitelisted(plr) then return plr end
    end
    return nil
end

local pendingHitChar = nil
local pendingHitUntil = 0
local hitDmgBuffer = {}

function F.resolveAimedCharacter()
    if isLocking and currentTarget and currentTarget.Parent then
        return currentTarget.Parent
    end
    if rageBotEnabled and rageTargetPlayer and rageTargetPlayer.Character then
        return rageTargetPlayer.Character
    end
    return nil
end

function F.markShot()
    lastShotTime = tick()
    myRecentShot = true
    pendingHitChar = F.resolveAimedCharacter()
    pendingHitUntil = tick() + 1.25
    task.delay(1.3, function()
        if tick() - lastShotTime >= 1.2 then myRecentShot = false end
    end)
end

function F.isCreatorMe(humanoid)
    if not humanoid then return false end
    for _, name in ipairs({"creator", "Creator", "creatorTag", "Killer", "LastHit", "DamageOwner", "Attacker", "LastAttacker"}) do
        local tag = humanoid:FindFirstChild(name)
        if tag then
            if tag:IsA("ObjectValue") and tag.Value == LocalPlayer then return true end
            if tag:IsA("StringValue") and (tag.Value == LocalPlayer.Name or tag.Value == tostring(LocalPlayer.UserId)) then return true end
        end
    end
    local char = humanoid.Parent
    if char then
        local be = char:FindFirstChild("BodyEffects")
        if be then
            for _, name in ipairs({"creator", "Creator", "Attacker", "LastAttacker"}) do
                local tag = be:FindFirstChild(name)
                if tag then
                    if tag:IsA("ObjectValue") and tag.Value == LocalPlayer then return true end
                    if tag:IsA("StringValue") and (tag.Value == LocalPlayer.Name or tag.Value == tostring(LocalPlayer.UserId)) then return true end
                end
            end
        end
    end
    return false
end

function F.isDamageFromMe(player, humanoid)
    if F.isCreatorMe(humanoid) then return true end
    local now = tick()
    if pendingHitChar and player.Character == pendingHitChar and now <= pendingHitUntil then
        return true
    end
    if myRecentShot or (now - lastShotTime) <= 1.25 then
        if isLocking and currentTarget and currentTarget.Parent == player.Character then
            return true
        end
        if rageBotEnabled and rageTargetPlayer == player then
            return true
        end
    end
    return false
end

function F.flushHitBuffers()
    local now = tick()
    for uid, buf in pairs(hitDmgBuffer) do
        if now >= buf.flushAt and buf.dmg >= 1 then
            F.pushNotification(string.format("hit %s for -%d health", buf.name, math.floor(buf.dmg + 0.5)), true)
            F.playHitSound()
            hitDmgBuffer[uid] = nil
        end
    end
end

function F.tryHitNotify(player, humanoid, dmg)
    if dmg < 0.5 then return end
    if not F.isDamageFromMe(player, humanoid) then return end
    local uid = player.UserId
    local name = F.playerLabel(player)
    local buf = hitDmgBuffer[uid]
    if buf then
        buf.dmg = buf.dmg + dmg
        buf.flushAt = tick() + 0.08
        buf.name = name
    else
        hitDmgBuffer[uid] = { dmg = dmg, name = name, flushAt = tick() + 0.08 }
    end
    -- juju-style hitmarker
    pcall(function()
        local lethal = humanoid and humanoid.Health <= 0
        local pos = _lastLocalShotPos
        if not pos and player.Character then
            local h = player.Character:FindFirstChild("Head")
            if h then pos = h.Position end
        end
        F.showHitMarker(pos, lethal)
    end)
end

F.jConnect(RunService.Heartbeat, function()
    F.flushHitBuffers()
end)

function F.trackPlayerHealth(player)
    if player == LocalPlayer then return end
    local function onCharacter(char)
        local humanoid = char:WaitForChild("Humanoid", 8)
        if not humanoid then return end
        local prev = humanoid.Health
        F.jConnect(humanoid.HealthChanged, function(newHealth)
            local oldH = prev
            if newHealth < oldH - 0.05 then
                local dmg = oldH - newHealth
                prev = newHealth
                F.tryHitNotify(player, humanoid, dmg)
            else
                prev = newHealth
            end
        end)
        task.spawn(function()
            while humanoid and humanoid.Parent and JuruAlive do
                local h = humanoid.Health
                if h < prev - 0.5 then
                    local dmg = prev - h
                    prev = h
                    F.tryHitNotify(player, humanoid, dmg)
                elseif h > prev then
                    prev = h
                end
                task.wait(0.03)
            end
        end)
    end
    if player.Character then onCharacter(player.Character) end
    F.jConnect(player.CharacterAdded, onCharacter)
end
for _, p in ipairs(Players:GetPlayers()) do F.trackPlayerHealth(p) end
F.jConnect(Players.PlayerAdded, F.trackPlayerHealth)



-- ============================================================
-- Juju-style bullet tracers + hitmarkers
-- ============================================================
local _tracerFolder = nil
local function getTracerFolder()
    if _tracerFolder and _tracerFolder.Parent then return _tracerFolder end
    local parent = nil
    pcall(function()
        if typeof(gethui) == "function" then parent = gethui() end
    end)
    if not parent then
        parent = game:GetService("CoreGui")
    end
    local f = parent:FindFirstChild("JuruTracers")
    if not f then
        f = Instance.new("Folder")
        f.Name = "JuruTracers"
        pcall(function() f.Parent = parent end)
    end
    _tracerFolder = f
    return f
end

local _beamTemplates = nil
local function getBeamTemplates()
    if _beamTemplates then return _beamTemplates end
    local function mk(props)
        local b = Instance.new("Beam")
        b.FaceCamera = true
        b.Width0 = props.w or 0.15
        b.Width1 = props.w or 0.15
        b.LightEmission = props.le or 1
        b.Brightness = props.br or 3
        if props.tex then b.Texture = props.tex end
        if props.speed then b.TextureSpeed = props.speed end
        if props.mode then b.TextureMode = props.mode end
        return b
    end
    _beamTemplates = {
        laser = mk({ w = 0.12, le = 2, br = 4 }),
        light = mk({ w = 0.25, le = 1, br = 2 }),
        flow = mk({
            w = 0.2, le = 3, br = 5,
            tex = "rbxassetid://12788927812",
            speed = 2.5,
            mode = Enum.TextureMode.Wrap,
        }),
    }
    return _beamTemplates
end

function F.spawnBulletTracer(fromPos, toPos)
    -- removed
end

function F.showHitMarker(worldPos, lethal)
    if not (Config.HitMarker and Config.HitMarker.Enabled ~= false) then return end
    local cfg = Config.HitMarker
    local mode = cfg.Mode or "2d"
    local lifetime = tonumber(cfg.Lifetime) or 0.7
    local thickness = tonumber(cfg.Thickness) or 2
    local color = lethal and F.toColor3(cfg.LethalColor, Color3.fromRGB(255, 0, 0))
        or F.toColor3(cfg.Color, Color3.fromRGB(170, 100, 255))
    local outlineCol = F.toColor3(cfg.OutlineColor, Color3.fromRGB(15, 15, 15))

    local function drawX(getCenter, is3d)
        local lines, outlines = {}, {}
        local useDrawing = false
        pcall(function()
            if Drawing and Drawing.new then
                for i = 1, 4 do
                    local o = Drawing.new("Line")
                    o.Thickness = thickness + 2
                    o.Color = outlineCol
                    o.ZIndex = 99
                    o.Visible = true
                    outlines[i] = o
                    local l = Drawing.new("Line")
                    l.Thickness = thickness
                    l.Color = color
                    l.ZIndex = 100
                    l.Visible = true
                    lines[i] = l
                end
                useDrawing = true
            end
        end)
        if not useDrawing then return end
        local t0 = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - t0
            if not JuruAlive or elapsed > lifetime + 0.25 then
                pcall(function() conn:Disconnect() end)
                for i = 1, 4 do
                    pcall(function() if lines[i] then lines[i]:Remove() end end)
                    pcall(function() if outlines[i] then outlines[i]:Remove() end end)
                end
                return
            end
            local cx, cy, vis = getCenter()
            if not vis then
                for i = 1, 4 do
                    if lines[i] then lines[i].Visible = false end
                    if outlines[i] then outlines[i].Visible = false end
                end
                return
            end
            -- exact juju 2d hitmarker geometry
            local alpha = 1
            if elapsed > lifetime then
                alpha = math.clamp(1 - (elapsed - lifetime) / 0.3, 0, 1)
            end
            local segs = {
                { Vector2.new(cx - 10, cy - 10), Vector2.new(cx - 5, cy - 5) },
                { Vector2.new(cx + 10, cy - 10), Vector2.new(cx + 5, cy - 5) },
                { Vector2.new(cx - 10, cy + 10), Vector2.new(cx - 5, cy + 5) },
                { Vector2.new(cx + 10, cy + 10), Vector2.new(cx + 5, cy + 5) },
            }
            for i = 1, 4 do
                if lines[i] then
                    lines[i].From, lines[i].To = segs[i][1], segs[i][2]
                    lines[i].Transparency = 1 - alpha
                    lines[i].Visible = true
                end
                if outlines[i] then
                    outlines[i].From, outlines[i].To = segs[i][1], segs[i][2]
                    outlines[i].Transparency = 1 - alpha
                    outlines[i].Visible = true
                end
            end
        end)
    end

    if mode == "2d" or mode == "both" then
        drawX(function()
            local cam = Workspace.CurrentCamera
            if not cam then return 0, 0, false end
            local v = cam.ViewportSize
            return v.X * 0.5, v.Y * 0.5, true
        end, false)
    end
    if (mode == "3d" or mode == "both") and typeof(worldPos) == "Vector3" then
        drawX(function()
            local cam = Workspace.CurrentCamera
            if not cam then return 0, 0, false end
            local sp, on = cam:WorldToViewportPoint(worldPos)
            return sp.X, sp.Y, on and sp.Z > 0
        end, true)
    end
end

local _lastLocalShotAt = 0
local _lastLocalShotPos = nil

function F.onLocalShotVisual(fromPos, toPos)
    _lastLocalShotAt = tick()
    _lastLocalShotPos = toPos
    pcall(F.spawnBulletTracer, fromPos, toPos)
end


-- Tracer on Tool.Activated while aiming (covers non-GunHandler games)

-- Bullet tracers removed

-- M1 bullet tracer removed


-- ============================================================
-- Death notify: who killed LocalPlayer
-- ============================================================
local lastLocalDamagerLabel = nil
local lastLocalDamagerAt = 0

function F.playerFromAny(v)
    if not v then return nil end
    if typeof(v) == "Instance" then
        if v:IsA("Player") then return v end
        if v:IsA("Model") then return Players:GetPlayerFromCharacter(v) end
        if v:IsA("BasePart") and v.Parent then
            return Players:GetPlayerFromCharacter(v.Parent) or Players:GetPlayerFromCharacter(v.Parent.Parent)
        end
        if v:IsA("Tool") then
            local ch = v.Parent
            if ch and ch:IsA("Model") then return Players:GetPlayerFromCharacter(ch) end
            if v.Parent and v.Parent:IsA("Player") then return v.Parent end -- backpack
        end
    elseif type(v) == "string" and v ~= "" then
        local p = Players:FindFirstChild(v)
        if p and p:IsA("Player") then return p end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name:lower() == v:lower() or (plr.DisplayName and plr.DisplayName:lower() == v:lower()) then
                return plr
            end
        end
    elseif type(v) == "number" then
        return Players:GetPlayerByUserId(v)
    end
    return nil
end

function F.labelFromPlayer(plr)
    if not plr then return nil end
    if type(plr) == "string" then return plr end
    return F.playerLabel(plr)
end

function F.resolveAttackerLabel(char, hum)
    local killerPlr = nil
    local killerStr = nil

    local function take(tag)
        if not tag or killerPlr or killerStr then return end
        if tag:IsA("ObjectValue") and tag.Value then
            local p = F.playerFromAny(tag.Value)
            if p and p ~= LocalPlayer then killerPlr = p end
        elseif tag:IsA("StringValue") and tag.Value ~= "" then
            local p = F.playerFromAny(tag.Value)
            if p and p ~= LocalPlayer then
                killerPlr = p
            elseif tag.Value:lower() ~= (LocalPlayer.Name or ""):lower() then
                killerStr = tag.Value
            end
        elseif (tag:IsA("NumberValue") or tag:IsA("IntValue")) and tag.Value ~= 0 then
            local p = Players:GetPlayerByUserId(tag.Value)
            if p and p ~= LocalPlayer then killerPlr = p end
        end
    end

    local names = {
        "creator", "Creator", "creatorTag", "CreatorTag",
        "Killer", "killer", "LastHit", "LastHitBy", "DamageOwner",
        "Attacker", "LastAttacker", "Slasher", "Player", "STag",
        "ShotBy", "LastShot", "Owner", "Combat", "Tag"
    }
    if hum then
        for _, name in ipairs(names) do take(hum:FindFirstChild(name)) end
        -- any ObjectValue under humanoid
        pcall(function()
            for _, d in ipairs(hum:GetChildren()) do
                if killerPlr then break end
                if d:IsA("ObjectValue") or d:IsA("StringValue") or d:IsA("NumberValue") or d:IsA("IntValue") then
                    take(d)
                end
            end
        end)
    end

    local be = char and (char:FindFirstChild("BodyEffects") or char:FindFirstChild("Body Effects"))
    if be then
        for _, name in ipairs(names) do take(be:FindFirstChild(name)) end
        pcall(function()
            for _, d in ipairs(be:GetDescendants()) do
                if killerPlr then break end
                local n = d.Name:lower()
                if d:IsA("ObjectValue") or d:IsA("StringValue") or d:IsA("NumberValue") or d:IsA("IntValue") then
                    if n:find("creat", 1, true) or n:find("kill", 1, true) or n:find("attack", 1, true)
                        or n:find("hit", 1, true) or n:find("tag", 1, true) or n:find("owner", 1, true)
                        or n:find("slash", 1, true) or n:find("shot", 1, true) then
                        take(d)
                    end
                end
            end
        end)
    end

    -- Whole character scan (some games parent tags under tools / folders)
    if not killerPlr and char then
        pcall(function()
            for _, d in ipairs(char:GetDescendants()) do
                if killerPlr then break end
                if d:IsA("ObjectValue") then
                    local n = d.Name:lower()
                    if n:find("creat", 1, true) or n:find("kill", 1, true) or n:find("attack", 1, true) or n == "tag" then
                        take(d)
                    end
                end
            end
        end)
    end

    -- Recent tracked damager (from HealthChanged)
    if not killerPlr and not killerStr and lastLocalDamagerLabel and (tick() - lastLocalDamagerAt) < 6 then
        return lastLocalDamagerLabel
    end

    -- Closest enemy with a tool equipped (fallback)
    if not killerPlr and not killerStr and char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local best, bestD = nil, 180
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local tool = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
                    local thrp = F.getHRP(plr)
                    if tool and thrp then
                        local d = (thrp.Position - hrp.Position).Magnitude
                        if d < bestD then bestD = d; best = plr end
                    end
                end
            end
            if best then killerPlr = best end
        end
    end

    if killerPlr then return F.labelFromPlayer(killerPlr) end
    if killerStr then return F.sanitizeLabel(killerStr, killerStr) end
    return "unknown"
end

function F.noteLocalDamager(char, hum)
    local label = F.resolveAttackerLabel(char, hum)
    if label and label ~= "unknown" then
        lastLocalDamagerLabel = label
        lastLocalDamagerAt = tick()
    end
end

function F.notifyDeathKiller(killerName, kind)
    if not (Config.Settings and Config.Settings.DeathNotify) then return end
    local label = killerName and tostring(killerName) or "unknown"
    -- One delayed re-resolve for knocks (creator tag often appears a frame late)
    if label == "unknown" and kind == "knock" then
        task.delay(0.12, function()
            if not JuruAlive then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local again = F.resolveAttackerLabel(c, h)
            if again and again ~= "unknown" then
                F.pushNotification("knocked by: " .. again, false)
                print("[Juru] Notify — knocked by:", again)
            end
        end)
    end
    local prefix = (kind == "knock") and "knocked by: " or "killed by: "
    F.pushNotification(prefix .. label, false)
    print("[Juru] Notify —", prefix .. label)
end


function F.tryBuyArmor()
    if not (Config.AutoBuyArmor and Config.AutoBuyArmor.Enabled) then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Shop / armor stand CFrame (user-provided)
    local armorCF = CFrame.new(
        -607.978455, 7.44964886, -788.494263,
        -1.1920929e-07, 0, 1.00000012,
        0, 1, 0,
        -1.00000012, 0, -1.1920929e-07
    )
    local savedCF = hrp.CFrame

    pcall(function()
        hrp.CFrame = armorCF
        hrp.AssemblyLinearVelocity = Vector3.new()
        hrp.AssemblyAngularVelocity = Vector3.new()
    end)

    -- Brief settle so the shop UI / proximity can load
    task.wait(0.15)

    local function clickGuiButton(btn)
        if not btn or not btn.Parent then return false end
        local ok = false
        pcall(function()
            if typeof(firesignal) == "function" then
                if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
                if btn.MouseButton1Down then firesignal(btn.MouseButton1Down) end
                if btn.Activated then firesignal(btn.Activated) end
                ok = true
            end
        end)
        pcall(function()
            if typeof(getconnections) == "function" then
                for _, sigName in ipairs({"MouseButton1Click", "MouseButton1Down", "Activated", "MouseButton1Up"}) do
                    local sig = btn[sigName]
                    if sig then
                        for _, c in ipairs(getconnections(sig)) do
                            pcall(function() c:Fire() end)
                            pcall(function() if c.Function then c.Function() end end)
                        end
                        ok = true
                    end
                end
            end
        end)
        pcall(function()
            -- VirtualInputManager fallback
            local vim = game:GetService("VirtualInputManager")
            local abs = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            local x = abs.X + size.X / 2
            local y = abs.Y + size.Y / 2
            vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
            ok = true
        end)
        return ok
    end

    local function nameLooksArmor(s)
        if type(s) ~= "string" then return false end
        local l = s:lower()
        return l:find("armor", 1, true) or l:find("armour", 1, true) or l:find("kevlar", 1, true)
    end

    -- 1) ClickDetector / ProximityPrompt near the stand
    pcall(function()
        local origin = armorCF.Position
        for _, d in ipairs(Workspace:GetDescendants()) do
            if (d:IsA("ClickDetector") or d:IsA("ProximityPrompt")) then
                local part = d.Parent
                if part and part:IsA("BasePart") and (part.Position - origin).Magnitude < 25 then
                    if d:IsA("ClickDetector") and typeof(fireclickdetector) == "function" then
                        pcall(fireclickdetector, d)
                        pcall(fireclickdetector, d, d.MaxActivationDistance)
                    elseif d:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                        pcall(fireproximityprompt, d)
                    end
                end
            end
        end
    end)

    task.wait(0.1)

    -- 2) GUI buttons with armor in name/text
    local roots = {}
    pcall(function() table.insert(roots, LocalPlayer:FindFirstChild("PlayerGui")) end)
    pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
    for _, root in ipairs(roots) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    local label = (d.Text or "") .. " " .. d.Name
                    local okTxt = nameLooksArmor(label)
                    if not okTxt then
                        for _, c in ipairs(d:GetChildren()) do
                            if c:IsA("TextLabel") or c:IsA("TextButton") then
                                if nameLooksArmor(c.Text) or nameLooksArmor(c.Name) then
                                    okTxt = true
                                    break
                                end
                            end
                        end
                    end
                    if okTxt and d.Visible and d.AbsoluteSize.Magnitude > 5 then
                        clickGuiButton(d)
                    end
                end
            end
        end
    end

    -- 3) Still fire common remotes as backup
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        for _, d in ipairs(rs:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local ln = d.Name:lower()
                if ln:find("armor", 1, true) or ln:find("armour", 1, true) or ln:find("shop", 1, true) or ln:find("main", 1, true) then
                    if d:IsA("RemoteEvent") then
                        pcall(function() d:FireServer("BuyArmor") end)
                        pcall(function() d:FireServer("Armor") end)
                        pcall(function() d:FireServer("BuyArmour") end)
                    else
                        pcall(function() d:InvokeServer("BuyArmor") end)
                    end
                end
            end
        end
    end)

    task.wait(0.2)
    -- Return only if not mid-rage (rage will reposition itself)
    if not rageBotEnabled then
        pcall(function()
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h then h.CFrame = savedCF end
        end)
    end
    F.pushNotification("armor buy attempted", false)
end

function F.hookLocalDeath(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    local deathFired, knockFired = false, false
    local prevHp = hum.Health

    local function onDied()
        if deathFired or not JuruAlive then return end
        deathFired = true
        if Config.Settings and Config.Settings.DeathNotify then
            local who = F.resolveAttackerLabel(char, hum)
            if who == "unknown" and lastLocalDamagerLabel and (tick() - lastLocalDamagerAt) < 8 then
                who = lastLocalDamagerLabel
            end
            F.notifyDeathKiller(who, "kill")
        end
        if Config.AutoBuyArmor and Config.AutoBuyArmor.Enabled then
            pendingArmorBuy = true
        end
    end

    local function onKnocked()
        if knockFired or deathFired or not JuruAlive then return end
        knockFired = true
        if not (Config.Settings and Config.Settings.DeathNotify) then return end
        local who = F.resolveAttackerLabel(char, hum)
        if who == "unknown" and lastLocalDamagerLabel and (tick() - lastLocalDamagerAt) < 8 then
            who = lastLocalDamagerLabel
        end
        F.notifyDeathKiller(who, "knock")
        -- tags often lag KO by a bit — refresh once more
        task.delay(0.25, function()
            if not JuruAlive or deathFired then return end
            local again = F.resolveAttackerLabel(char, hum)
            if again and again ~= "unknown" and again ~= who then
                F.pushNotification("knocked by: " .. again, false)
            end
        end)
    end

    F.jConnect(hum.Died, onDied)
    F.jConnect(hum.HealthChanged, function(h)
        if h < prevHp - 0.2 then
            F.noteLocalDamager(char, hum)
        end
        prevHp = h
        if h <= 0 then onDied() end
    end)

    local function wireBodyEffects(be)
        if not be then return end
        local function check()
            if not JuruAlive then return end
            local ko = be:FindFirstChild("K.O") or be:FindFirstChild("KO")
            local knocked = be:FindFirstChild("Knocked")
            local isKo = false
            if ko and ko:IsA("BoolValue") and ko.Value then isKo = true end
            if knocked and knocked:IsA("BoolValue") and knocked.Value then isKo = true end
            if isKo then onKnocked() end
        end
        check()
        for _, name in ipairs({"K.O", "KO", "Knocked"}) do
            local v = be:FindFirstChild(name)
            if v and v:IsA("BoolValue") then
                F.jConnect(v:GetPropertyChangedSignal("Value"), check)
            end
        end
        F.jConnect(be.ChildAdded, function(c)
            if c.Name == "K.O" or c.Name == "KO" or c.Name == "Knocked" then
                if c:IsA("BoolValue") then
                    F.jConnect(c:GetPropertyChangedSignal("Value"), check)
                end
                task.defer(check)
            end
        end)
    end

    local be = char:FindFirstChild("BodyEffects")
    if be then
        wireBodyEffects(be)
    else
        F.jConnect(char.ChildAdded, function(c)
            if c.Name == "BodyEffects" then wireBodyEffects(c) end
        end)
    end
end
if LocalPlayer.Character then task.spawn(F.hookLocalDeath, LocalPlayer.Character) end
F.jConnect(LocalPlayer.CharacterAdded, function(char)
    task.spawn(F.hookLocalDeath, char)
    if pendingArmorBuy and Config.AutoBuyArmor and Config.AutoBuyArmor.Enabled then
        pendingArmorBuy = false
        task.spawn(function()
            task.wait(0.35) -- wait for HRP
            F.tryBuyArmor()
        end)
    end
end)

shared._juruChatSpy = true

function F.forceChatVisible()
    pcall(function()
        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
        StarterGui:SetCore("ChatActive", true)
    end)
    pcall(function()
        TextChatService.ChatWindowConfiguration.Enabled = true
        TextChatService.ChatInputBarConfiguration.Enabled = true
        pcall(function()
            TextChatService.ChatWindowConfiguration.HeightRatio = 0.4
        end)
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, name in ipairs({"Chat", "ChatGui", "RoactChat", "ExperienceChat"}) do
            local g = pg:FindFirstChild(name)
            if g then
                if g:IsA("ScreenGui") or g:IsA("GuiMain") then
                    g.Enabled = true
                end
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("GuiObject") then
                        local ln = d.Name:lower()
                        if ln:find("channel") or ln:find("message") or ln:find("scroller")
                            or ln:find("window") or ln:find("chat") then
                            d.Visible = true
                        end
                    end
                end
            end
        end
    end)
end

if shared._juruChatSpy then
    F.forceChatVisible()
end

local fovCircle, tracerLine
local fovPolyLines = {} -- for non-circle FOV shapes

if DrawingAvailable then
    fovCircle = F.jDraw("Circle")
    fovCircle.Visible = false
    fovCircle.Thickness = 1
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Color = Config.FOV.Color

    for i = 1, 6 do
        local ln = F.jDraw("Line")
        ln.Visible = false
        ln.Thickness = 1
        ln.Color = Config.FOV.Color
        table.insert(fovPolyLines, ln)
    end

    tracerLine = F.jDraw("Line")
    tracerLine.Visible = false
    tracerLine.Thickness = 1.5
    tracerLine.Color = Config.Visuals.TracerColor
end

function F.hideAllFOVDraw()
    if fovCircle then fovCircle.Visible = false end
    for _, ln in ipairs(fovPolyLines) do
        ln.Visible = false
    end
end

function F.updateFOVCircle()
    if not DrawingAvailable then return end
    if not Config.FOV.Enabled or not Config.FOV.Visible then
        F.hideAllFOVDraw()
        return
    end
    local m = UserInputService:GetMouseLocation()
    local r = Config.FOV.Size or 95
    local th = Config.FOV.Thickness or 1
    local col = Config.FOV.Color
    local shape = (Config.FOV.Shape or "Circle"):lower()

    if shape == "circle" then
        for _, ln in ipairs(fovPolyLines) do ln.Visible = false end
        if fovCircle then
            fovCircle.Position = Vector2.new(m.X, m.Y)
            fovCircle.Radius = r
            fovCircle.Thickness = th
            fovCircle.Color = col
            fovCircle.Visible = true
        end
        return
    end

    if fovCircle then fovCircle.Visible = false end

    local pts = {}
    if shape == "square" then
        pts = {
            Vector2.new(m.X - r, m.Y - r),
            Vector2.new(m.X + r, m.Y - r),
            Vector2.new(m.X + r, m.Y + r),
            Vector2.new(m.X - r, m.Y + r),
        }
    elseif shape == "diamond" then
        pts = {
            Vector2.new(m.X, m.Y - r),
            Vector2.new(m.X + r, m.Y),
            Vector2.new(m.X, m.Y + r),
            Vector2.new(m.X - r, m.Y),
        }
    else -- hexagon
        for i = 0, 5 do
            local a = (math.pi / 3) * i - math.pi / 6
            table.insert(pts, Vector2.new(m.X + math.cos(a) * r, m.Y + math.sin(a) * r))
        end
    end

    local n = #pts
    for i = 1, 6 do
        local ln = fovPolyLines[i]
        if i <= n then
            local a, b = pts[i], pts[(i % n) + 1]
            ln.From = a
            ln.To = b
            ln.Thickness = th
            ln.Color = col
            ln.Visible = true
        else
            ln.Visible = false
        end
    end
end

function F.getNeckScreenPos()
    local char = LocalPlayer.Character
    if not char then return nil end
    local neck = char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
    if not neck then return nil end
    local pos = Camera:WorldToViewportPoint(neck.Position)
    return Vector2.new(pos.X, pos.Y)
end

function F.updateTracer()
    if not tracerLine then return end
    local aimOn = (Config.SilentAim and Config.SilentAim.Enabled == true)
        or (Config.SilentAim and Config.SilentAim.UseCameraAimbot == true)
        or (Config.SoftLock and Config.SoftLock.Enabled == true)
        or (Config.Ragebot and Config.Ragebot.Enabled == true)
    if not aimOn then
        tracerLine.Visible = false
        return
    end
    if not isLocking or not currentTarget or not currentTarget.Parent then
        tracerLine.Visible = false
        return
    end
    -- Soft-lock hover: hide tracer unless ShowTracer is on (avoids random black line)
    if F.softLockEnabled() and not (Config.SoftLock and Config.SoftLock.ShowTracer) then
        -- still show if locked via keybind sticky? soft lock IS the lock method
        -- only hide pure soft-lock hover line when ShowTracer false
        tracerLine.Visible = false
        return
    end
    local fromPos
    if F.softLockEnabled() then
        local m = UserInputService:GetMouseLocation()
        fromPos = Vector2.new(m.X, m.Y)
    else
        fromPos = F.getNeckScreenPos()
    end
    if not fromPos then tracerLine.Visible = false return end
    local head = currentTarget.Parent:FindFirstChild("Head") or currentTarget
    if not head then tracerLine.Visible = false return end
    local toPos3 = Camera:WorldToViewportPoint(head.Position)
    local toScreen = Vector2.new(toPos3.X, toPos3.Y)
    if toPos3.Z < 0 then
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local dir = (toScreen - center)
        if dir.Magnitude > 0 then toScreen = center - dir.Unit * 500 end
    end
    tracerLine.From = fromPos
    tracerLine.To = toScreen
    local tc = F.toColor3(
        (Config.Visuals and Config.Visuals.TracerColor)
            or (Config.Colors and Config.Colors.Tracer)
            or (Config.FOV and Config.FOV.Color),
        Color3.fromRGB(170, 100, 255)
    )
    -- never pure black (looks like "broken" tracer)
    if tc.R + tc.G + tc.B < 0.05 then
        tc = Color3.fromRGB(170, 100, 255)
    end
    tracerLine.Color = tc
    tracerLine.Visible = true
end

local espLabels = {}
local chamsHighlights = {}
local lockedLights = {}
local selfHighlight = nil

function F.isFirstPerson()
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local okMode, mode = pcall(function()
        return LocalPlayer.CameraMode
    end)
    if okMode and mode == Enum.CameraMode.LockFirstPerson then
        return true
    end
    -- Zoom-style check: camera very close to head = first person
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if head then
        local dist = (cam.CFrame.Position - head.Position).Magnitude
        if dist < 1.5 then return true end
    end
    return false
end

function F.clearLocalTransparency(char)
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            part.LocalTransparencyModifier = 0
        elseif part:IsA("Accessory") or part:IsA("Model") then
            for _, c in ipairs(part:GetChildren()) do
                if c:IsA("BasePart") then c.LocalTransparencyModifier = 0 end
            end
        end
    end
end

-- Self-chams body transparency (third person only — never force LTM in first person)
local _selfChamsFP = nil -- cached last first-person state to avoid re-scanning
function F.makeLocalTransparent(char)
    if not char then return end
    local fp = F.isFirstPerson()
    if fp then
        if _selfChamsFP ~= true then
            F.clearLocalTransparency(char)
            _selfChamsFP = true
        end
        return
    end
    if _selfChamsFP == false then return end -- already applied
    _selfChamsFP = false
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.LocalTransparencyModifier = 0.85
        elseif part:IsA("Accessory") then
            for _, c in ipairs(part:GetChildren()) do
                if c:IsA("BasePart") then c.LocalTransparencyModifier = 0.85 end
            end
        end
    end
end

function F.clearLockedLight(userId)
    if lockedLights[userId] then
        lockedLights[userId]:Destroy()
        lockedLights[userId] = nil
    end
end

function F.addESPToPlayer(player)
    if player == LocalPlayer or not DrawingAvailable then return end
    if espLabels[player.UserId] then return end
    local function mkText()
        local t = F.jDraw("Text")
        t.Size = 14
        t.Center = true
        t.Outline = true
        t.OutlineColor = Color3.fromRGB(0, 0, 0)
        t.Color = (Config.Visuals and Config.Visuals.Color) or Color3.fromRGB(170, 100, 255)
        t.Visible = false
        t.ZIndex = 1000
        return t
    end
    local function mkLine()
        local l = F.jDraw("Line")
        l.Thickness = 1
        l.Color = (Config.Visuals and Config.Visuals.Color) or Color3.fromRGB(170, 100, 255)
        l.Visible = false
        l.ZIndex = 999
        return l
    end
    local function mkSquare()
        local s = F.jDraw("Square")
        s.Thickness = 1
        s.Filled = false
        s.Color = (Config.Visuals and Config.Visuals.Color) or Color3.fromRGB(170, 100, 255)
        s.Visible = false
        s.ZIndex = 998
        return s
    end
    local esp = {
        player = player,
        nameTag = mkText(),
        distTag = mkText(),
        box = mkSquare(),
        tracer = mkLine(),
        bones = {},
    }
    -- skeleton: head-torso, torso-root, torso-arms, root-legs (8 lines)
    for i = 1, 12 do
        esp.bones[i] = mkLine()
    end
    espLabels[player.UserId] = esp
end

function F.hideEspDrawings(esp)
    if not esp then return end
    if esp.nameTag then esp.nameTag.Visible = false end
    if esp.distTag then esp.distTag.Visible = false end
    if esp.box then esp.box.Visible = false end
    if esp.tracer then esp.tracer.Visible = false end
    if esp.bones then
        for _, b in ipairs(esp.bones) do
            if b then b.Visible = false end
        end
    end
end

function F.removeESPFromPlayer(player)
    if not player then return end
    local esp = espLabels[player.UserId]
    if esp then
        pcall(function() if esp.nameTag then esp.nameTag:Remove() end end)
        pcall(function() if esp.distTag then esp.distTag:Remove() end end)
        pcall(function() if esp.box then esp.box:Remove() end end)
        pcall(function() if esp.tracer then esp.tracer:Remove() end end)
        if esp.bones then
            for _, b in ipairs(esp.bones) do
                pcall(function() if b then b:Remove() end end)
            end
        end
        espLabels[player.UserId] = nil
    end
    F.destroyPlayerChams(player.UserId)
    F.clearLockedLight(player.UserId)
end

-- ============================================================
-- EXACT juju-style chams: BoxHandleAdornment on R15 body parts
-- + optional Highlight (parented to hui, NOT Character)
-- ============================================================
local CHAMS_BODY_PARTS = {
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local CHAMS_OFFSET = Vector3.new(0.01, 0.01, 0.01)

local function getChamsParent()
    local ok, hui = pcall(function()
        if typeof(gethui) == "function" then return gethui() end
    end)
    if ok and hui then return hui end
    local cg = game:GetService("CoreGui")
    local folder = cg:FindFirstChild("JuruChamsFolder")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "JuruChamsFolder"
        pcall(function() folder.Parent = cg end)
        if not folder.Parent then
            folder.Parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
        end
    end
    return folder
end

function F.destroyPlayerChams(userId)
    local entry = chamsHighlights[userId]
    if not entry then return end
    if type(entry) == "table" then
        if entry.boxes then
            for _, box in pairs(entry.boxes) do
                pcall(function() if box then box:Destroy() end end)
            end
        end
        if entry.highlight then
            pcall(function() entry.highlight:Destroy() end)
        end
        -- legacy flat map of boxes
        for k, v in pairs(entry) do
            if typeof(v) == "Instance" then
                pcall(function() v:Destroy() end)
            end
        end
    elseif typeof(entry) == "Instance" then
        pcall(function() entry:Destroy() end)
    end
    chamsHighlights[userId] = nil
end

function F.ensureChams(player)
    if player == LocalPlayer then return end
    if not Config.Visuals or not Config.Visuals.Enabled then return end
    if Config.Visuals.Chams == false then
        F.destroyPlayerChams(player.UserId)
        return
    end
    local char = F.getCharacter(player)
    if not char or not char.Parent then
        F.destroyPlayerChams(player.UserId)
        return
    end

    local locked = isLocking and currentTarget and currentTarget.Parent == char
    local col = locked and (Config.Visuals.LockedGlow or Color3.fromRGB(170, 100, 255))
        or (Config.Visuals.ChamsColor or Color3.fromRGB(190, 150, 255))
    -- clearer fill, still drawn through walls
    local tr = locked and 0.35 or 0.55
    local parent = getChamsParent()

    local entry = chamsHighlights[player.UserId]
    if type(entry) ~= "table" or not entry.boxes then
        F.destroyPlayerChams(player.UserId)
        entry = { boxes = {}, highlight = nil }
        chamsHighlights[player.UserId] = entry
    end

    local used = {}
    for _, partName in ipairs(CHAMS_BODY_PARTS) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local box = entry.boxes[partName]
            if not box or not box.Parent then
                box = Instance.new("BoxHandleAdornment")
                box.Name = "JuruCham_" .. partName
                box.AlwaysOnTop = true
                box.ZIndex = 5
                box.AdornCullingMode = Enum.AdornCullingMode.Never
                box.Parent = parent
                entry.boxes[partName] = box
            end
            box.Adornee = part
            -- slight inflate for cleaner silhouette
            local inflate = Vector3.new(0.06, 0.06, 0.06)
            box.Size = part.Size + inflate
            box.Color3 = col
            box.Transparency = tr
            box.Visible = true
            box.AlwaysOnTop = true
            used[partName] = true
        end
    end
    for name, box in pairs(entry.boxes) do
        if not used[name] then
            pcall(function() box:Destroy() end)
            entry.boxes[name] = nil
        end
    end

    -- juju highlight layer (parent hui, adornee character)
    if Config.Visuals.HighlightChams == true then
        local hl = entry.highlight
        if not hl or not hl.Parent then
            hl = Instance.new("Highlight")
            hl.Name = "JuruHL"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = parent
            entry.highlight = hl
        end
        hl.Adornee = char
        hl.FillColor = col
        hl.OutlineColor = Config.Visuals.OutlineColor or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = locked and 0.45 or 0.65
        hl.OutlineTransparency = locked and 0.15 or 0.25
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = true
    elseif entry.highlight then
        entry.highlight.Enabled = false
    end

    if locked then
        if not lockedLights[player.UserId] then
            local light = Instance.new("PointLight")
            light.Name = "LockGlow"
            light.Color = col
            light.Brightness = 2.2
            light.Range = 11
            local head = char:FindFirstChild("Head")
            if head then light.Parent = head end
            lockedLights[player.UserId] = light
        end
    else
        F.clearLockedLight(player.UserId)
    end
end

local selfChamBoxes = {}
local selfChamHighlight = nil

function F.clearSelfChamSpheres()
    for _, box in pairs(selfChamBoxes) do
        pcall(function() if box then box:Destroy() end end)
    end
    table.clear(selfChamBoxes)
    if selfChamHighlight then
        pcall(function() selfChamHighlight:Destroy() end)
        selfChamHighlight = nil
    end
    if selfHighlight then
        pcall(function() selfHighlight:Destroy() end)
        selfHighlight = nil
    end
end

function F.ensureSelfChams()
    local char = LocalPlayer.Character
    if not char then return end

    if not Config.Visuals.SelfChams then
        F.clearLocalTransparency(char)
        _selfChamsFP = nil
        F.clearSelfChamSpheres()
        return
    end

    if F.isFirstPerson() then
        F.makeLocalTransparent(char)
        F.clearSelfChamSpheres()
        return
    end

    F.makeLocalTransparent(char)

    local parent = getChamsParent()
    local col = (Config.Visuals and Config.Visuals.ChamsColor) or Color3.fromRGB(190, 140, 255)
    local used = {}
    for _, partName in ipairs(CHAMS_BODY_PARTS) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local box = selfChamBoxes[partName]
            if not box or not box.Parent then
                box = Instance.new("BoxHandleAdornment")
                box.Name = "JuruSelfCham_" .. partName
                box.AlwaysOnTop = true
                box.ZIndex = 1
                box.AdornCullingMode = Enum.AdornCullingMode.Automatic
                box.Parent = parent
                selfChamBoxes[partName] = box
            end
            box.Adornee = part
            box.Size = part.Size + CHAMS_OFFSET
            box.Color3 = col
            box.Transparency = 0.5
            box.Visible = true
            used[partName] = true
        end
    end
    for name, box in pairs(selfChamBoxes) do
        if not used[name] then
            pcall(function() box:Destroy() end)
            selfChamBoxes[name] = nil
        end
    end

    -- local highlight like juju character_highlight
    if not selfChamHighlight or not selfChamHighlight.Parent then
        selfChamHighlight = Instance.new("Highlight")
        selfChamHighlight.Name = "JuruSelfHL"
        selfChamHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        selfChamHighlight.FillTransparency = 0.55
        selfChamHighlight.OutlineTransparency = 0.3
        selfChamHighlight.Parent = parent
    end
    selfChamHighlight.Adornee = char
    selfChamHighlight.FillColor = col
    selfChamHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    selfChamHighlight.Enabled = true
end

local _lastChamsRefresh = 0
local SKELETON_PAIRS = {
    {"Head", "UpperTorso"}, {"Head", "Torso"},
    {"UpperTorso", "LowerTorso"}, {"Torso", "HumanoidRootPart"},
    {"UpperTorso", "LeftUpperArm"}, {"UpperTorso", "RightUpperArm"},
    {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"LeftUpperArm", "LeftLowerArm"}, {"RightUpperArm", "RightLowerArm"},
    {"LeftLowerArm", "LeftHand"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LowerTorso", "RightUpperLeg"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"RightUpperLeg", "RightLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"}, {"RightLowerLeg", "RightFoot"},
}

function F.refreshESP()
    if not Config.Visuals or not Config.Visuals.Enabled then
        for _, esp in pairs(espLabels) do F.hideEspDrawings(esp) end
        for uid, _ in pairs(chamsHighlights) do F.destroyPlayerChams(uid) end
        return
    end
    local showNames = Config.Visuals.Names == true
    local showDist = Config.Visuals.Distance == true
    local showBoxes = Config.Visuals.Boxes == true
    local showTracers = Config.Visuals.Tracers == true
    local showSkel = Config.Visuals.Skeleton == true
    local col = Config.Visuals.Color or Color3.fromRGB(170, 100, 255)
    local tracerCol = F.toColor3(Config.Visuals.TracerColor or (Config.Colors and Config.Colors.Tracer), col)
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local vp = Camera.ViewportSize
    local screenBottom = Vector2.new(vp.X * 0.5, vp.Y)

    local doChams = (tick() - _lastChamsRefresh) >= 0.2
    if doChams then _lastChamsRefresh = tick() end

    for userId, esp in pairs(espLabels) do
        local player = esp.player
        if not player or not player.Parent then
            F.removeESPFromPlayer(player)
        elseif player.Character and player.Character.Parent then
            local char = player.Character
            local head = char:FindFirstChild("Head")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not head or not hum or hum.Health <= 0 then
                F.hideEspDrawings(esp)
                if chamsHighlights[userId] then chamsHighlights[userId].Enabled = false end
                if doChams then F.clearLockedLight(userId) end
            else
                local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.3, 0))
                local hrpPos = hrp and select(1, Camera:WorldToViewportPoint(hrp.Position)) or headPos
                local visible = onScreen and headPos.Z > 0

                -- Names
                if esp.nameTag then
                    if showNames and visible then
                        esp.nameTag.Position = Vector2.new(headPos.X, headPos.Y - 18)
                        esp.nameTag.Text = F.playerLabel(player)
                        esp.nameTag.Color = col
                        esp.nameTag.Visible = true
                    else
                        esp.nameTag.Visible = false
                    end
                end

                -- Distance
                if esp.distTag then
                    if showDist and visible and myHRP and hrp then
                        local dist = (myHRP.Position - hrp.Position).Magnitude
                        esp.distTag.Position = Vector2.new(headPos.X, headPos.Y + 2)
                        esp.distTag.Text = string.format("[%dm]", math.floor(dist + 0.5))
                        esp.distTag.Color = col
                        esp.distTag.Size = 12
                        esp.distTag.Visible = true
                    else
                        esp.distTag.Visible = false
                    end
                end

                -- Boxes (2D AABB from head + feet)
                if esp.box then
                    if showBoxes and visible and hrp then
                        local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.9, 0))
                        local bot = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        local h = math.abs(bot.Y - top.Y)
                        local w = h * 0.55
                        local cx = (top.X + bot.X) * 0.5
                        local cy = math.min(top.Y, bot.Y)
                        if h > 4 and h < 800 then
                            esp.box.Position = Vector2.new(cx - w * 0.5, cy)
                            esp.box.Size = Vector2.new(w, h)
                            esp.box.Color = col
                            esp.box.Visible = true
                        else
                            esp.box.Visible = false
                        end
                    else
                        esp.box.Visible = false
                    end
                end

                -- Tracers (screen bottom → feet)
                if esp.tracer then
                    if showTracers and visible and hrp then
                        local feet = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        esp.tracer.From = screenBottom
                        esp.tracer.To = Vector2.new(feet.X, feet.Y)
                        esp.tracer.Color = tracerCol
                        esp.tracer.Visible = true
                    else
                        esp.tracer.Visible = false
                    end
                end

                -- Skeleton
                if esp.bones then
                    if showSkel and visible then
                        local bi = 1
                        for _, pair in ipairs(SKELETON_PAIRS) do
                            if bi > #esp.bones then break end
                            local a = char:FindFirstChild(pair[1])
                            local b = char:FindFirstChild(pair[2])
                            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                                local pa, oa = Camera:WorldToViewportPoint(a.Position)
                                local pb, ob = Camera:WorldToViewportPoint(b.Position)
                                if oa and ob and pa.Z > 0 and pb.Z > 0 then
                                    local line = esp.bones[bi]
                                    line.From = Vector2.new(pa.X, pa.Y)
                                    line.To = Vector2.new(pb.X, pb.Y)
                                    line.Color = col
                                    line.Visible = true
                                    bi = bi + 1
                                end
                            end
                        end
                        for i = bi, #esp.bones do
                            esp.bones[i].Visible = false
                        end
                    else
                        for _, b in ipairs(esp.bones) do b.Visible = false end
                    end
                end

                if doChams then
                    F.ensureChams(player)
                end
            end
        else
            F.hideEspDrawings(esp)
            if chamsHighlights[userId] then chamsHighlights[userId].Enabled = false end
        end
    end
    if doChams then
        F.ensureSelfChams()
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if F.getCharacter(player) then
            task.defer(function()
                pcall(F.waitForCharacter, player, 5)
                pcall(F.addESPToPlayer, player)
            end)
        end
        F.jConnect(player.CharacterAdded, function(char)
            pcall(F.removeESPFromPlayer, player)
            task.spawn(function()
                pcall(function()
                    if char then char:WaitForChild("HumanoidRootPart", 5) end
                end)
                task.wait(0.15)
                pcall(F.addESPToPlayer, player)
            end)
        end)
        F.jConnect(player.CharacterRemoving, function() pcall(F.removeESPFromPlayer, player) end)
    end
end
F.jConnect(Players.PlayerAdded, function(player)
    if player == LocalPlayer then return end
    F.jConnect(player.CharacterAdded, function(char)
        pcall(F.removeESPFromPlayer, player)
        task.spawn(function()
            pcall(function()
                if char then char:WaitForChild("HumanoidRootPart", 5) end
            end)
            task.wait(0.15)
            pcall(F.addESPToPlayer, player)
        end)
    end)
    F.jConnect(player.CharacterRemoving, function() pcall(F.removeESPFromPlayer, player) end)
end)
F.jConnect(Players.PlayerRemoving, F.removeESPFromPlayer)

F.jConnect(LocalPlayer.CharacterAdded, function(char)
    _selfChamsFP = nil
    task.spawn(function()
        pcall(function()
            if char then char:WaitForChild("HumanoidRootPart", 5) end
        end)
        task.wait(0.2)
        if selfHighlight then pcall(function() selfHighlight:Destroy() end); selfHighlight = nil end
        pcall(F.ensureSelfChams)
    end)
end)

-- ============================================================
-- AntiMod: detect 🛡️ 👑 ⭐ 🔨 💎 on Name / DisplayName / nametags.
-- Leaves the game entirely (does not rejoin).
-- ============================================================
local antiModTriggered = false
-- Multiple unicode forms of shield / crown (emoji variation selectors differ)
local MOD_MARKERS = {
    -- shield
    "🛡️", "🛡", "\u{1F6E1}", "\u{1F6E1}\u{FE0F}",
    -- crown
    "👑", "\u{1F451}",
    -- star
    "⭐", "⭐️", "\u{2B50}", "\u{2B50}\u{FE0F}",
    -- hammer
    "🔨", "\u{1F528}", "\u{1F528}\u{FE0F}",
    -- diamond
    "💎", "\u{1F48E}",
}

function F.textHasModMarker(str)
    if type(str) ~= "string" or str == "" then return false end
    for _, m in ipairs(MOD_MARKERS) do
        if m ~= "" and str:find(m, 1, true) then
            return true
        end
    end
    -- Fallback: utf8 scan for shield / crown / star / hammer
    local ok, hit = pcall(function()
        for _, cp in utf8.codes(str) do
            if cp == 0x1F6E1 -- shield
                or cp == 0x1F451 -- crown
                or cp == 0x2B50  -- star
                or cp == 0x1F528 -- hammer
                or cp == 0x1F48E -- diamond
            then
                return true
            end
        end
        return false
    end)
    return ok and hit == true
end

-- light=true: Name/DisplayName/Humanoid only (for periodic scans)
-- light=false: also nametag TextLabels under Head (on join only)
function F.collectInGameNames(player, light)
    local names = {}
    local function add(s)
        if type(s) == "string" and s ~= "" then
            table.insert(names, s)
        end
    end
    if not player then return names end

    add(player.Name)
    add(player.DisplayName)

    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() add(hum.DisplayName) end)
        end
        if not light then
            -- Only scan BillboardGuis under character (not entire tree)
            for _, d in ipairs(char:GetChildren()) do
                if d:IsA("BillboardGui") or d:IsA("Accessory") then
                    for _, c in ipairs(d:GetDescendants()) do
                        if c:IsA("TextLabel") or c:IsA("TextButton") then
                            add(c.Text)
                        end
                    end
                end
            end
            local head = char:FindFirstChild("Head")
            if head then
                for _, c in ipairs(head:GetChildren()) do
                    if c:IsA("BillboardGui") then
                        for _, t in ipairs(c:GetDescendants()) do
                            if t:IsA("TextLabel") then add(t.Text) end
                        end
                    end
                end
            end
        end
    end
    return names
end

function F.playerLooksLikeMod(player, light)
    if not player or player == LocalPlayer then return false, nil end
    for _, name in ipairs(F.collectInGameNames(player, light)) do
        if F.textHasModMarker(name) then
            return true, name
        end
    end
    return false, nil
end

function F.leaveGameEntirely()
    pcall(function()
        LocalPlayer:Kick("Juru AntiMod — staff detected (🛡️/👑/⭐/🔨/💎)")
    end)
    pcall(function()
        game:Shutdown()
    end)
end

function F.antiModReact(player, matchedName)
    if antiModTriggered or not JuruAlive then return end
    if not (Config.AntiMod and Config.AntiMod.Enabled) then return end
    antiModTriggered = true

    local label = matchedName or (player and ((player.DisplayName ~= "" and player.DisplayName) or player.Name)) or "?"
    F.pushNotification("⚠ mod detected: " .. tostring(label), false)
    print("[Juru] AntiMod triggered:", player and player.Name, matchedName)

    if Config.AntiMod.AutoLeave ~= false then
        task.spawn(function()
            task.wait(0.15)
            F.leaveGameEntirely()
        end)
    end
end

function F.scanPlayerForMod(player)
    if not player or player == LocalPlayer then return end
    if not (Config.AntiMod and Config.AntiMod.Enabled) then return end
    if antiModTriggered then return end

    local function check()
        if antiModTriggered or not JuruAlive then return end
        if not (Config.AntiMod and Config.AntiMod.Enabled) then return end
        local isMod, matched = F.playerLooksLikeMod(player)
        if isMod then
            F.antiModReact(player, matched)
        end
    end

    task.spawn(function()
        -- Fewer checks to avoid FPS spikes (nametag lag still covered)
        for _, delay in ipairs({ 0, 0.5, 1.5, 3.0 }) do
            if delay > 0 then task.wait(delay) end
            if antiModTriggered or not player.Parent then return end
            check()
        end
    end)

    F.jConnect(player.CharacterAdded, function(char)
        task.spawn(function()
            for _, delay in ipairs({ 0.4, 1.2 }) do
                task.wait(delay)
                if antiModTriggered or not player.Parent then return end
                check()
            end
        end)
        -- Throttled DescendantAdded: max 1 check / 0.75s
        local lastDescCheck = 0
        pcall(function()
            F.jConnect(char.DescendantAdded, function(d)
                if not (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("BillboardGui")) then return end
                if tick() - lastDescCheck < 0.75 then return end
                lastDescCheck = tick()
                task.defer(check)
            end)
        end)
    end)

    pcall(function()
        F.jConnect(player:GetPropertyChangedSignal("DisplayName"), check)
    end)
end

local antiModWatchStarted = false
local antiModSeenJoins = {} -- UserId -> true (dedupe join logs/scans)

function F.startAntiModWatch()
    if antiModWatchStarted then return end
    antiModWatchStarted = true

    if Config.AntiMod and Config.AntiMod.Enabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                antiModSeenJoins[plr.UserId] = true
                F.scanPlayerForMod(plr)
            end
        end
    end

    F.jConnect(Players.PlayerAdded, function(player)
        if player == LocalPlayer then return end
        if antiModSeenJoins[player.UserId] then return end
        antiModSeenJoins[player.UserId] = true
        if not (Config.AntiMod and Config.AntiMod.Enabled) then return end
        print("[Juru] AntiMod: player joined", player.Name, player.DisplayName)
        F.scanPlayerForMod(player)
    end)
    F.jConnect(Players.PlayerRemoving, function(player)
        if player then antiModSeenJoins[player.UserId] = nil end
    end)

    local antiModLastScan = 0
    F.jConnect(RunService.Heartbeat, function()
        if not JuruAlive or antiModTriggered then return end
        if not (Config.AntiMod and Config.AntiMod.Enabled) then return end
        if tick() - antiModLastScan < 12 then return end
        antiModLastScan = tick()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local isMod, matched = F.playerLooksLikeMod(plr, true)
                if isMod then
                    F.antiModReact(plr, matched)
                    break
                end
            end
        end
    end)
end

F.startAntiModWatch()

-- ============================================================
-- Chat Macro: send a saved message on keybind (no cooldown)
-- ============================================================
local CHAT_MACRO_FILE = "Juru_ChatMacro.json"

function F.saveChatMacro()
    pcall(function()
        if typeof(writefile) ~= "function" then return end
        if not Config.ChatMacro then return end
        writefile(CHAT_MACRO_FILE, HttpService:JSONEncode({
            Enabled = Config.ChatMacro.Enabled == true,
            Message = tostring(Config.ChatMacro.Message or "/getjuru"),
            Key     = tostring(Config.ChatMacro.Key or Config.Keybinds.ChatMacro or "F6"),
        }))
    end)
end

function F.loadChatMacro()
    pcall(function()
        if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return end
        if not isfile(CHAT_MACRO_FILE) then return end
        local raw = readfile(CHAT_MACRO_FILE)
        if type(raw) ~= "string" or raw == "" then return end
        local data = HttpService:JSONDecode(raw)
        if type(data) ~= "table" then return end
        if not Config.ChatMacro then Config.ChatMacro = { Enabled = false, Message = "/getjuru", Key = "F6" } end
        if data.Enabled ~= nil then Config.ChatMacro.Enabled = data.Enabled == true end
        if type(data.Message) == "string" and data.Message ~= "" then Config.ChatMacro.Message = data.Message end
        if type(data.Key) == "string" and data.Key ~= "" then
            Config.ChatMacro.Key = data.Key
            Config.Keybinds.ChatMacro = data.Key
        end
    end)
end

F.loadChatMacro()

function F.sendChatMessage(text)
    if type(text) ~= "string" or text == "" then return false end
    local sent = false

    -- New TextChatService channels
    pcall(function()
        local channels = TextChatService:FindFirstChild("TextChannels")
        if channels then
            local ch = channels:FindFirstChild("RBXGeneral")
                or channels:FindFirstChild("General")
                or channels:FindFirstChildWhichIsA("TextChannel")
            if ch and ch.SendAsync then
                ch:SendAsync(text)
                sent = true
            end
        end
    end)

    -- Legacy chat remote
    pcall(function()
        local ev = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        if ev then
            local say = ev:FindFirstChild("SayMessageRequest")
            if say then
                say:FireServer(text, "All")
                sent = true
            end
        end
    end)

    -- Fallback Players:Chat
    pcall(function()
        if LocalPlayer.Character then
            game:GetService("Players"):Chat(text)
            sent = true
        end
    end)

    return sent
end

function F.trySendChatMacro()
    if not JuruAlive then return end
    if not (Config.ChatMacro and Config.ChatMacro.Enabled) then return end
    local msg = Config.ChatMacro.Message
    if type(msg) ~= "string" or msg == "" then return end
    local ok = F.sendChatMessage(msg)
    print("[Juru] ChatMacro sent:", msg, ok and "ok" or "failed")
end

local silentHooked = false
local silentRestore = nil
local cameraAimbotBound = false

-- Apply camera look AFTER Roblox's camera module (priority Camera+1).
-- Fixes freeze while walking: old RenderStepped ran before camera follow,
-- so CFrame was overwritten with a stale position until you stopped moving.
function F.applyCameraAimbotLook()
    if not JuruAlive then return end
    -- Gate: Xeno always; full executors only when UseCameraAimbot is on
    if not isXeno then
        if not (Config.SilentAim and Config.SilentAim.UseCameraAimbot) then
            return
        end
    end

    local cam = Workspace.CurrentCamera
    if not cam then return end
    Camera = cam

    local part = nil
    if rageBotEnabled and rageTargetPlayer and rageTargetPlayer.Character then
        if not F.isPlayerKnockedOrKO(rageTargetPlayer) then
            part = F.getAimPart(rageTargetPlayer.Character)
        end
    elseif isLocking and currentTarget and currentTarget.Parent then
        part = F.getAimPart(currentTarget.Parent) or currentTarget
    end
    if not part then return end

    local predicted = F.getPredictedPosition(part)
    if (Config.SilentAim.HitPart or "Torso") ~= "Head" then
        predicted = predicted + Vector3.new(0, 1.35, 0)
    end

    -- Keep the camera module's updated position (follows character while walking),
    -- only override rotation toward the target.
    local pos = cam.CFrame.Position
    if (predicted - pos).Magnitude < 0.05 then return end
    local targetCF = CFrame.lookAt(pos, predicted)
    local smooth = (Config.SilentAim and tonumber(Config.SilentAim.Smoothness)) or 0
    if smooth <= 0 or isXeno then
        cam.CFrame = targetCF
    else
        -- higher smoothness = slower turn (alpha smaller)
        local alpha = math.clamp(1 / (1 + smooth * 0.35), 0.04, 1)
        cam.CFrame = cam.CFrame:Lerp(targetCF, alpha)
    end
end

function F.bindCameraAimbot()
    if cameraAimbotBound then return end
    local ok = pcall(function()
        RunService:BindToRenderStep("JuruCameraAimbot", Enum.RenderPriority.Camera.Value + 1, F.applyCameraAimbotLook)
    end)
    if ok then
        cameraAimbotBound = true
        print("[Juru] Camera aimbot bound at Camera+1 priority")
    else
        -- Fallback if BindToRenderStep unavailable
        F.jConnect(RunService.RenderStepped, F.applyCameraAimbotLook)
        cameraAimbotBound = true
        print("[Juru] Camera aimbot using RenderStepped fallback")
    end
end

function F.unbindCameraAimbot()
    pcall(function()
        RunService:UnbindFromRenderStep("JuruCameraAimbot")
    end)
    cameraAimbotBound = false
end

-- ============================================================
-- Fly
-- ============================================================
function F.setFly(on)
    flyEnabled = on == true
    if not Config.Fly then Config.Fly = { Enabled = false, Speed = 50 } end
    Config.Fly.Enabled = flyEnabled

    if not flyEnabled then
        pcall(function()
            if flyBV then flyBV:Destroy() end
            if flyBG then flyBG:Destroy() end
        end)
        flyBV, flyBG = nil, nil
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.PlatformStand = false end)
        end
        return
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        if flyBV then flyBV:Destroy() end
        if flyBG then flyBG:Destroy() end
    end)
    flyBV = Instance.new("BodyVelocity")
    flyBV.Name = "JuruFlyBV"
    flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBV.Velocity = Vector3.new()
    flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.Name = "JuruFlyBG"
    flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.P = 9e4
    flyBG.CFrame = hrp.CFrame
    flyBG.Parent = hrp
end

function F.toggleFly(forceState, silent)
    local nextState
    if forceState ~= nil then
        nextState = forceState == true
    else
        nextState = not flyEnabled
    end
    F.setFly(nextState)
    pcall(function()
        if Library and Library.Toggles and Library.Toggles.FlyEnabled then
            Library.Toggles.FlyEnabled:SetValue(nextState)
        end
    end)
    if not silent then
        F.pushNotification(nextState and "fly ON" or "fly OFF", false)
    end
    return nextState
end

function F.updateFly()
    if not flyEnabled then
        if flyBV or flyBG then
            pcall(function()
                if flyBV then flyBV:Destroy() end
                if flyBG then flyBG:Destroy() end
            end)
            flyBV, flyBG = nil, nil
        end
        return
    end
    local char = F.getCharacter(LocalPlayer)
    local hrp = F.getHRP(char)
    local hum = F.getHumanoid(char)
    if not hrp or not hum then return end
    if not flyBV or not flyBV.Parent then F.setFly(true) end
    if not flyBV then return end
    local spd = (Config.Fly and Config.Fly.Speed) or 50
    local cam = Workspace.CurrentCamera
    local move = Vector3.new()
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        move = move - Vector3.new(0, 1, 0)
    end
    if move.Magnitude > 0 then
        move = move.Unit * spd
    end
    flyBV.Velocity = move
    if flyBG then
        flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
    end
    hum.PlatformStand = true
end


F.jConnect(RunService.RenderStepped, function(dt)
    if not JuruAlive then return end
    F.updateFly()
end)

F.jConnect(LocalPlayer.CharacterAdded, function(char)
    SpeedEnabled = false
    cFrameSpeedEnabled = false
    charReadyAt = tick() + 1.0
    task.defer(function()
        pcall(function()
            task.wait(0.2)
            local c = char or LocalPlayer.Character
            if not c or not c.Parent then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hum and (hum.WalkSpeed or 0) > 30 then
                hum.WalkSpeed = BaseSpeed or 16
            end
        end)
    end)
    if flyEnabled and Config.Fly and Config.Fly.Enabled then
        task.wait(0.6)
        if tick() >= (charReadyAt or 0) then
            pcall(F.setFly, true)
        end
    end
end)
pcall(function()
    if LocalPlayer.Character then
        charReadyAt = tick() + 0.75
    end
end)

function F.tryInstallSilentAim()
    -- Silent = GunHandler AimPosition rewrite ONLY.
    -- Does NOT enable camera aimbot (that is a separate toggle).
    if Config.SilentAim then
        Config.SilentAim.AllowIndexHook = false
        -- do NOT touch UseCameraAimbot here
    end
    silentHooked = true
    -- Install / refresh shoot rewrite so AimPosition is redirected when locking
    pcall(function()
        if F.tryInstallWallShoot then
            wallShootHooked = false
            F.tryInstallWallShoot()
        end
    end)
    print("[Juru] Silent aim ready (AimPosition rewrite — camera aimbot NOT forced)")
end

-- Do NOT auto-enable silent/camera at boot
-- F.tryInstallSilentAim()

-- ============================================================
-- WallShoot: hook GunHandler.Shoot — uses existing lock / rage /
-- FOV target. No separate FOV or silent-aim system.
-- ============================================================
local wallShootRestore = nil
local wallShootHooked = false

function F.getWallShootTargetPart()
    local part = nil
    pcall(function()
        if isLocking and F.isValidPart(currentTarget) then
            local char = currentTarget.Parent
            local plr = char and Players:GetPlayerFromCharacter(char)
            if plr and not F.isPlayerKnockedOrKO(plr) and not F.isWhitelisted(plr) then
                part = F.getAimPart(char) or currentTarget
            end
        end
    end)
    if F.isValidPart(part) then return part end
    pcall(function()
        if rageBotEnabled and rageTargetPlayer then
            local char = F.getCharacter(rageTargetPlayer)
            if char and not F.isPlayerKnockedOrKO(rageTargetPlayer) and not F.isWhitelisted(rageTargetPlayer) then
                part = F.getAimPart(char)
            end
        end
    end)
    if F.isValidPart(part) then return part end
    return F.findClosestTarget()
end

local WEAPON_AC_STATS = {
    ["[Revolver]"] = { Damage = 34.8, Range = 250 },
    ["[Double-Barrel SG]"] = { Damage = 28.6, Range = 95 },
    ["[TacticalShotgun]"] = { Damage = 29.3, Range = 75 },
}

function F.getEquippedGunStats()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil, nil end
    local cfg = WEAPON_AC_STATS[tool.Name]
    if cfg then return tool, cfg end
    local d = tool:FindFirstChild("Damage")
    local r = tool:FindFirstChild("Range")
    if d and r then return tool, { Damage = d.Value, Range = r.Value } end
    return tool, nil
end

function F.getWeaponMaxRange()
    local tool, cfg = F.getEquippedGunStats()
    if cfg and tonumber(cfg.Range) then return tonumber(cfg.Range), tool end
    if tool then
        local r = tool:FindFirstChild("Range")
        if r and tonumber(r.Value) then return tonumber(r.Value), tool end
    end
    return 250, tool
end

function F.applySmartRangeOrigin(params, targetPos)
    if not (Config.SmartRange and Config.SmartRange.Enabled) then return end
    if type(params) ~= "table" or typeof(targetPos) ~= "Vector3" then return end
    local maxR = select(1, F.getWeaponMaxRange()) or 250
    local margin = tonumber(Config.SmartRange.Margin) or 3
    local limit = math.max(8, maxR - margin)
    local origin = params.Origin
    if typeof(origin) ~= "Vector3" then
        local hrp = F.getHRP and F.getHRP(LocalPlayer)
        if hrp and F.safePartPosition then
            origin = F.safePartPosition(hrp)
        elseif LocalPlayer.Character then
            local h = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if h then origin = h.Position end
        end
    end
    if typeof(origin) ~= "Vector3" then return end
    local delta = targetPos - origin
    local dist = delta.Magnitude
    if dist <= limit or dist < 0.01 then return end
    params.Origin = targetPos - delta.Unit * limit
end

function F.tryInstallWallShoot()
    if wallShootHooked then return true end

    local function findGunHandler()
        local RS = game:GetService("ReplicatedStorage")
        local candidates = {}
        local function add(inst)
            if inst then table.insert(candidates, inst) end
        end
        -- only direct known paths (avoid full GetDescendants scan)
        local modules = RS:FindFirstChild("Modules")
        if modules then
            add(modules:FindFirstChild("GunHandler"))
            add(modules:FindFirstChild("GunClient"))
        end
        add(RS:FindFirstChild("GunHandler"))
        for _, mod in ipairs(candidates) do
            local ok, gh = pcall(require, mod)
            if ok and type(gh) == "table" then
                if type(gh.Shoot) == "function" then
                    return gh, "Shoot", mod
                end
                if type(gh.Fire) == "function" then
                    return gh, "Fire", mod
                end
                if type(gh.shoot) == "function" then
                    return gh, "shoot", mod
                end
            end
        end
        return nil
    end

    local ok = pcall(function()
        local GunHandler, methodName, mod = findGunHandler()
        if not GunHandler then error("no GunHandler module") end
        local originalShoot = GunHandler[methodName]
        if type(originalShoot) ~= "function" then error("Shoot not a function") end
        GunHandler[methodName] = function(params, ...)
            local args = table.pack(...)
            local function callOriginal()
                local ok, a, b, c, d = pcall(function()
                    return originalShoot(params, table.unpack(args, 1, args.n))
                end)
                if ok then return a, b, c, d end
                -- "expired" / destroyed — try bare call once more without rewrite
                return nil
            end
            -- OLD wallbang method (real server damage path):
            --   Silent only  → AimPosition only (never force Hit → no phantom HP)
            --   Wallbang on  → AimPosition + Hit/Target/Normal (classic)
            --   No Result1 / Instance / ForcedOrigin spoof (those caused fake damage)
            local wantSilent = Config.SilentAim and Config.SilentAim.Enabled == true and isLocking == true
            local wantWall = Config.WallShoot and Config.WallShoot.Enabled == true
            local wantSmart = Config.SmartRange and Config.SmartRange.Enabled == true and not wantWall
            if not JuruAlive then
                return callOriginal()
            end
            if not (wantSilent or wantWall or wantSmart) then
                return callOriginal()
            end
            local part = nil
            pcall(function() part = F.getWallShootTargetPart() end)
            if not part and wantSilent then
                pcall(function()
                    if currentTarget and F.isValidPart and F.isValidPart(currentTarget) then
                        part = F.getAimPart(currentTarget.Parent) or currentTarget
                    end
                end)
            end
            if F.isValidPart and F.isValidPart(part) and type(params) == "table" then
                pcall(function()
                    local pos = F.getPredictedPosition(part)
                    if typeof(pos) ~= "Vector3" then return end
                    local hitPartName = (Config.SilentAim and Config.SilentAim.HitPart) or "Torso"
                    if hitPartName == "Head" then
                        -- aim exact head center
                    elseif hitPartName == "Torso" or hitPartName == "UpperTorso" then
                        pos = pos + Vector3.new(0, 0.5, 0)
                    end
                    -- always set aim (silent + wallbang)
                    params.AimPosition = pos

                    -- classic wallbang ONLY when toggle is on (no client phantom hits)
                    if wantWall then
                        params.Hit = part
                        params.Target = part
                        params.Normal = Vector3.new(0, 1, 0)
                        if params.BeamTarget ~= nil then
                            params.BeamTarget = part
                        end
                    else
                        -- silent aim: AimPosition only — do not force Hit/Target (stops client-sided fake kills)
                        if params.Hit ~= nil then params.Hit = nil end
                        if params.Target ~= nil then params.Target = nil end
                    end

                    -- smart range only when NOT wallbanging (origin shift can desync wall hits)
                    if wantSmart and F.applySmartRangeOrigin then
                        F.applySmartRangeOrigin(params, pos)
                    end

-- tracer removed
                end)
            end
            return callOriginal()
        end
        wallShootRestore = function()
            pcall(function() GunHandler[methodName] = originalShoot end)
        end
        wallShootHooked = true
        print("[Juru] Wall Bang hooked:", mod:GetFullName(), methodName)
    end)

    if not ok then
        -- retry shortly (modules sometimes load late)
        task.delay(2, function()
            if wallShootHooked then return end
            if (Config.SilentAim and Config.SilentAim.Enabled) or (Config.WallShoot and Config.WallShoot.Enabled) then
                pcall(F.tryInstallWallShoot)
            end
        end)
        task.delay(5, function()
            if wallShootHooked then return end
            if (Config.SilentAim and Config.SilentAim.Enabled) or (Config.WallShoot and Config.WallShoot.Enabled) then
                pcall(F.tryInstallWallShoot)
            end
        end)
        print("[Juru] Wall Bang: GunHandler not ready yet (will retry)")
        return false
    end
    return true
end

-- Do not install wall/silent hook until user enables Silent or Wall Bang
-- F.tryInstallWallShoot()

-- ============================================================
-- Void Hide: HRP desync (Heartbeat void → RenderStepped restore)
-- ============================================================
local in_void = false
local voidHideLast = 0
local voidHideLastBait = 0
local voidHideBaitPos = nil
local voidHideConn = nil
local voidHideRenderConn = nil
local voidHideSavedCF = nil
local voidHideSavedVel = nil
local voidHidePendingRestore = false

function F.isInVoid()
    return in_void == true
end

function F.stopVoidHide()
    in_void = false
    voidHidePendingRestore = false
    voidHideSavedCF = nil
    voidHideSavedVel = nil
    if voidHideConn then
        pcall(function() voidHideConn:Disconnect() end)
        voidHideConn = nil
    end
    if voidHideRenderConn then
        pcall(function() voidHideRenderConn:Disconnect() end)
        voidHideRenderConn = nil
    end
end

local function voidHideHas(list, name)
    if type(list) ~= "table" then return false end
    for _, v in ipairs(list) do
        if v == name then return true end
    end
    if list[name] == true then return true end
    return false
end

local function voidHideIsReloading()
    local char = LocalPlayer.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false end
    local reloading = tool:FindFirstChild("Reloading") or tool:FindFirstChild("IsReloading")
    if reloading and reloading:IsA("BoolValue") then
        return reloading.Value == true
    end
    local attr = false
    pcall(function()
        if tool:GetAttribute("Reloading") == true then attr = true end
    end)
    return attr
end

-- Safe random in large range (Luau math.random chokes on ±2e9 spans)
local function voidRand(mag)
    mag = mag or 5e6
    return (math.random() * 2 - 1) * mag
end

function F.startVoidHide()
    F.stopVoidHide()
    if not (Config.VoidHide and Config.VoidHide.Enabled) then return end

    local is_window_active = (typeof(isrbxactive) == "function" and isrbxactive)
        or (typeof(iswindowactive) == "function" and iswindowactive)
        or function() return true end

    -- Restore on RenderStepped so client view stays normal
    voidHideRenderConn = F.jConnect(RunService.RenderStepped, function()
        if not voidHidePendingRestore then return end
        voidHidePendingRestore = false
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and voidHideSavedCF then
            pcall(function()
                hrp.CFrame = voidHideSavedCF
                if voidHideSavedVel then
                    if hrp.AssemblyLinearVelocity ~= nil then
                        hrp.AssemblyLinearVelocity = voidHideSavedVel
                    else
                        hrp.Velocity = voidHideSavedVel
                    end
                end
            end)
        end
        in_void = false
    end)

    voidHideConn = F.jConnect(RunService.Heartbeat, function()
        if not JuruAlive or not (Config.VoidHide and Config.VoidHide.Enabled) then
            in_void = false
            return
        end

        local cfg = Config.VoidHide
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            in_void = false
            return
        end

        local force_when = cfg.ForceWhen or {}
        local disable_when = cfg.DisableWhen or {}

        local forced = false
        if voidHideHas(force_when, "reloading") and voidHideIsReloading() then forced = true end
        if voidHideHas(force_when, "tabbed out") and not is_window_active() then forced = true end
        if voidHideHas(force_when, "not full health") and hum.Health < hum.MaxHealth then forced = true end

        if not forced then
            if voidHideHas(disable_when, "target selected") and isLocking and currentTarget then
                return
            end
            if voidHideHas(disable_when, "following target") and rageBotEnabled and rageTargetPlayer then
                return
            end
            if voidHideHas(disable_when, "target knocked") and rageBotEnabled and rageTargetPlayer
                and F.isPlayerKnockedOrKO and F.isPlayerKnockedOrKO(rageTargetPlayer) then
                return
            end
        end

        local void_time = tonumber(cfg.VoidTime) or 0.47
        local tp_time = tonumber(cfg.TeleportTime) or 0.10
        local offset = tonumber(cfg.Offset) or 0
        if offset < 0 then offset = 0 end
        local vtype = cfg.Type or "random"
        local spam = cfg.Spam == true
        local stop_if_forced = cfg.StopIfForced == true
        local now = os.clock()

        local old_cf = hrp.CFrame
        local old_vel
        pcall(function() old_vel = hrp.AssemblyLinearVelocity end)
        if not old_vel then
            pcall(function() old_vel = hrp.Velocity end)
        end

        local do_void = true
        if spam and (not stop_if_forced or not forced) then
            if now - voidHideLast > void_time then
                voidHideLast = now
                do_void = false
            elseif now - voidHideLast < tp_time then
                do_void = false
            end
        end

        voidHideSavedCF = old_cf
        voidHideSavedVel = old_vel
        in_void = do_void

        if do_void then
            local targetCF
            if vtype == "bait" then
                local bait_range = tonumber(cfg.BaitDistance) or 250
                local bait_time = tonumber(cfg.BaitTime) or 0.03
                local bait_cd = tonumber(cfg.BaitCooldown) or 0.5
                local difference = now - voidHideLastBait
                if difference > bait_cd then
                    voidHideLastBait = now
                    voidHideBaitPos = CFrame.new(
                        old_cf.Position + Vector3.new(
                            voidRand(bait_range),
                            (math.random() * 400) - 200,
                            voidRand(bait_range)
                        )
                    )
                end
                if difference < bait_time and voidHideBaitPos then
                    targetCF = voidHideBaitPos
                else
                    -- void between baits
                    targetCF = CFrame.new(Vector3.new(voidRand(8e6), 5000 + math.random() * 2e5, voidRand(8e6)))
                end
            elseif vtype == "vc server" then
                targetCF = CFrame.new(Vector3.new(0, voidRand(8e6), 0))
            else
                -- random extreme (safe magnitude for engine)
                targetCF = CFrame.new(Vector3.new(voidRand(8e6), 1000 + math.random() * 5e5, voidRand(8e6)))
            end

            if offset > 0 then
                targetCF = targetCF + Vector3.new(
                    voidRand(offset),
                    voidRand(offset),
                    voidRand(offset)
                )
            end
            targetCF = targetCF * CFrame.Angles(
                math.rad(math.random(1, 359)),
                math.rad(math.random(1, 359)),
                math.rad(math.random(1, 359))
            )
            pcall(function()
                hrp.CFrame = targetCF
            end)
        elseif offset > 0 then
            -- non-void half of spam: small jitter only
            pcall(function()
                hrp.CFrame = (old_cf + Vector3.new(voidRand(offset), voidRand(offset), voidRand(offset)))
                    * CFrame.Angles(math.rad(math.random(1, 359)), math.rad(math.random(1, 359)), math.rad(math.random(1, 359)))
            end)
        end

        voidHidePendingRestore = true
    end)

    print("[Juru] Void Hide started")
end



function F._init_juruRagebot()
-- ============================================================
-- JURU-STYLE RAGEBOT (separate from Rage orbit system)
-- No FireServer("ShootGun") rewrite — wallbang uses Config.WallShoot
-- ============================================================
local rbEnabled = false
local rbTarget = nil -- Player
local rbAimPos = nil -- Vector3
local rbLastFire = 0
local rbLastSwitch = 0
local rbPosHistory = {} -- [userId] = { {t, pos}, ... }
local rbLastGoodPos = {} -- [userId] = Vector3
local rbFovCircle, rbFovOutline = nil, nil
local rbTracerLine, rbTracerOutline = nil, nil
local rbStrafeAng = 0

local function rbCfg()
    return Config.Ragebot or {}
end

function F.rbStop()
    rbEnabled = false
    rbTarget = nil
    rbAimPos = nil
    if Config.Ragebot then Config.Ragebot.Enabled = false end
    if rbFovCircle then pcall(function() rbFovCircle.Visible = false end) end
    if rbFovOutline then pcall(function() rbFovOutline.Visible = false end) end
    if rbTracerLine then pcall(function() rbTracerLine.Visible = false end) end
    if rbTracerOutline then pcall(function() rbTracerOutline.Visible = false end) end
end

function F.rbStart()
    local c = rbCfg()
    c.Enabled = true
    rbEnabled = true
    if c.AutoFireWallBang then
        if not Config.WallShoot then Config.WallShoot = { Enabled = true } end
        Config.WallShoot.Enabled = true
        pcall(function() if F.tryInstallWallShoot then F.tryInstallWallShoot() end end)
    end
    print("[Juru] Ragebot started (juru-style, no ShootGun hook)")
end

local function rbGunNames()
    local c = rbCfg()
    local list = c.AutoEquipGuns or { "rifle" }
    local map = {}
    for _, n in ipairs(list) do
        map[tostring(n):lower()] = true
    end
    return map
end

function F.rbEquipGun()
    local char = LocalPlayer.Character
    if not char then return end
    if char:FindFirstChildOfClass("Tool") then return end
    local want = rbGunNames()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            for key in pairs(want) do
                if n:find(key, 1, true) or n:find(key:gsub("%s+", ""), 1, true) then
                    pcall(function() tool.Parent = char end)
                    return
                end
            end
        end
    end
    -- fallback any tool
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() tool.Parent = char end)
            return
        end
    end
end

local function rbRecordPos(plr, pos)
    if not plr or not pos then return end
    local uid = plr.UserId
    local hist = rbPosHistory[uid]
    if not hist then
        hist = {}
        rbPosHistory[uid] = hist
    end
    local now = tick()
    hist[#hist + 1] = { now, pos }
    while #hist > 30 do table.remove(hist, 1) end
    -- spam resolver: keep last "good" (not void-magnitude) pos
    if pos.Magnitude < 1e6 then
        rbLastGoodPos[uid] = pos
    end
end

local function rbResolvePos(plr, part)
    local c = rbCfg()
    local pos = part.Position
    rbRecordPos(plr, pos)
    if c.SpamResolver and pos.Magnitude > 1e6 then
        local good = rbLastGoodPos[plr.UserId]
        if good then
            local acc = (tonumber(c.SpamResolverAccuracy) or 77) / 100
            pos = good:Lerp(pos, 1 - acc)
        end
    end
    -- backtrack: use position from ~resolver_rate ago
    if c.AutoFireBacktrack then
        local hist = rbPosHistory[plr.UserId]
        local rate = tonumber(c.ResolverRate) or 0.037
        if hist and #hist > 1 then
            local want = tick() - rate
            local best = hist[1][2]
            for i = 1, #hist do
                if hist[i][1] <= want then best = hist[i][2] end
            end
            pos = best
        end
    end
    -- prediction
    local pred = tonumber(c.Prediction) or 0
    local vel = Vector3.new()
    pcall(function()
        vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
    end)
    if pred <= 0 then
        -- auto: small lead from velocity
        pos = pos + vel * 0.12
    elseif pred < 2000 then
        pos = pos + vel * (pred / 1000)
    end
    return pos
end

local function rbGetHitPart(char)
    local c = rbCfg()
    if (c.Hitbox or "head") == "root" then
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
    end
    return char:FindFirstChild("Head")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function rbInFOV(worldPos)
    local c = rbCfg()
    local fov = tonumber(c.FOV) or 180
    if fov >= 179 then return true end
    local cam = workspace.CurrentCamera
    if not cam then return true end
    local dir = (worldPos - cam.CFrame.Position)
    if dir.Magnitude < 1 then return true end
    local ang = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(dir.Unit), -1, 1)))
    return ang <= (fov * 0.5)
end

function F.rbPickTarget()
    local c = rbCfg()
    local cam = workspace.CurrentCamera
    local best, bestScore = nil, math.huge
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and not F.isWhitelisted(plr) then
            if not F.isPlayerKnockedOrKO(plr) then
                local part = rbGetHitPart(plr.Character)
                if part then
                    local pos = part.Position
                    if rbInFOV(pos) then
                        local sp, on = cam:WorldToViewportPoint(pos)
                        local score
                        if on then
                            score = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                        else
                            score = 5000 + (pos - cam.CFrame.Position).Magnitude
                        end
                        if score < bestScore then
                            bestScore = score
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end

function F.rbSetTarget(plr, silent)
    if plr and (plr == LocalPlayer or F.isWhitelisted(plr)) then return end
    rbTarget = plr
    if not silent and rbCfg().TargetNotify then
        if plr then
            F.pushNotification("ragebot target: " .. F.playerLabel(plr), true)
        else
            F.pushNotification("ragebot target cleared", 2)
        end
    end
end

local function rbFollow(myHRP, targetHRP, dt)
    local c = rbCfg()
    if not c.FollowTarget or not myHRP or not targetHRP then return end
    local style = c.FollowStyle or "random"
    local tpos = targetHRP.Position
    if style == "strafe" then
        rbStrafeAng = (rbStrafeAng or 0) + (dt or 0.016) * 3.2
        local r = 6
        local pos = tpos + Vector3.new(math.cos(rbStrafeAng) * r, 2, math.sin(rbStrafeAng) * r)
        myHRP.CFrame = CFrame.new(pos, tpos)
    elseif style == "random spam" then
        if math.random() < 0.35 then
            local ang = math.random() * math.pi * 2
            local r = 3 + math.random() * 8
            myHRP.CFrame = CFrame.new(tpos + Vector3.new(math.cos(ang) * r, 1 + math.random() * 4, math.sin(ang) * r), tpos)
        end
    else -- random
        if math.random() < 0.08 then
            local ang = math.random() * math.pi * 2
            local r = 4 + math.random() * 6
            myHRP.CFrame = CFrame.new(tpos + Vector3.new(math.cos(ang) * r, 2, math.sin(ang) * r), tpos)
        else
            myHRP.CFrame = CFrame.new(myHRP.Position, tpos)
        end
    end
end

local function rbEnsureDrawings()
    if not DrawingAvailable then return end
    if not rbFovCircle then
        rbFovCircle = F.jDraw("Circle")
        rbFovCircle.Filled = false
        rbFovCircle.Thickness = 1
        rbFovCircle.NumSides = 64
        rbFovCircle.Visible = false
        rbFovOutline = F.jDraw("Circle")
        rbFovOutline.Filled = false
        rbFovOutline.Thickness = 3
        rbFovOutline.NumSides = 64
        rbFovOutline.Color = Color3.new(0, 0, 0)
        rbFovOutline.Visible = false
    end
    if not rbTracerLine then
        rbTracerOutline = F.jDraw("Line")
        rbTracerOutline.Thickness = 4
        rbTracerOutline.Color = Color3.new(0, 0, 0)
        rbTracerOutline.Visible = false
        rbTracerLine = F.jDraw("Line")
        rbTracerLine.Thickness = 2
        rbTracerLine.Visible = false
    end
end

local function rbUpdateVisuals()
    local c = rbCfg()
    if not rbEnabled or not c.Enabled then
        if rbFovCircle then rbFovCircle.Visible = false end
        if rbFovOutline then rbFovOutline.Visible = false end
        if rbTracerLine then rbTracerLine.Visible = false end
        if rbTracerOutline then rbTracerOutline.Visible = false end
        return
    end
    rbEnsureDrawings()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local mouse = UserInputService:GetMouseLocation()
    if c.ShowFOV and rbFovCircle then
        local fov = tonumber(c.FOV) or 180
        local rad = 50
        if fov < 179 then
            -- approximate pixel radius from FOV
            rad = math.tan(math.rad(fov * 0.5)) * (cam.ViewportSize.Y * 0.5) * 0.55
            rad = math.clamp(rad, 20, cam.ViewportSize.Y)
        else
            rad = math.min(cam.ViewportSize.X, cam.ViewportSize.Y) * 0.48
        end
        local col = F.toColor3(
            rbTarget and (c.FOVActiveColor or Color3.fromRGB(233, 44, 44)) or (c.FOVColor or Color3.fromRGB(170, 100, 255)),
            Color3.fromRGB(170, 100, 255)
        )
        rbFovCircle.Position = mouse
        rbFovCircle.Radius = rad
        rbFovCircle.Color = col
        rbFovCircle.Visible = true
        if rbFovOutline then
            rbFovOutline.Position = mouse
            rbFovOutline.Radius = rad
            rbFovOutline.Visible = true
        end
    elseif rbFovCircle then
        rbFovCircle.Visible = false
        if rbFovOutline then rbFovOutline.Visible = false end
    end
    if c.Tracer and rbTracerLine and rbAimPos then
        local origin = mouse
        local style = c.TracerOrigin or "gun"
        if style == "character" then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local sp, on = cam:WorldToViewportPoint(hrp.Position)
                if on then origin = Vector2.new(sp.X, sp.Y) end
            end
        elseif style == "gun" then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            local handle = tool and (tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart"))
            if handle then
                local sp, on = cam:WorldToViewportPoint(handle.Position)
                if on then origin = Vector2.new(sp.X, sp.Y) end
            end
        end
        local sp2, on2 = cam:WorldToViewportPoint(rbAimPos)
        if on2 then
            local dest = Vector2.new(sp2.X, sp2.Y)
            local th = tonumber(c.TracerThickness) or 2
            rbTracerOutline.From = origin
            rbTracerOutline.To = dest
            rbTracerOutline.Thickness = th + 2
            rbTracerOutline.Visible = true
            rbTracerLine.From = origin
            rbTracerLine.To = dest
            rbTracerLine.Thickness = th
            rbTracerLine.Color = c.TracerColor or Color3.fromRGB(170, 100, 255)
            rbTracerLine.Visible = true
        else
            rbTracerLine.Visible = false
            rbTracerOutline.Visible = false
        end
    elseif rbTracerLine then
        rbTracerLine.Visible = false
        if rbTracerOutline then rbTracerOutline.Visible = false end
    end
end

-- Main ragebot loop — does NOT touch rageBotEnabled / Config.RageBot
F.jConnect(RunService.Heartbeat, function(dt)
    local c = rbCfg()
    if not c.Enabled then
        if rbEnabled then F.rbStop() end
        return
    end
    rbEnabled = true

    -- optional: disable void hide while we have a target
    if c.VoidHideDisableOnTarget and rbTarget and Config.VoidHide and Config.VoidHide.Enabled then
        -- do not force-stop; void hide has its own disable-when
    end

    if c.AutoEquip then
        F.rbEquipGun()
    end

    -- target selection
    local now = tick()
    local needPick = false
    if not rbTarget or not rbTarget.Parent or not rbTarget.Character or F.isPlayerKnockedOrKO(rbTarget) or F.isWhitelisted(rbTarget) then
        needPick = true
    end
    if c.TargetAuto and needPick then
        local cd = tonumber(c.TargetCooldown)
            or (Config.Settings and tonumber(Config.Settings.SwitchTargetSpeed))
            or 0.12
        if now - rbLastSwitch >= cd then
            rbLastSwitch = now
            local pick = F.rbPickTarget()
            if pick ~= rbTarget then
                F.rbSetTarget(pick, not c.TargetNotify)
            end
        end
    end

    if not rbTarget or not rbTarget.Character then
        rbAimPos = nil
        rbUpdateVisuals()
        return
    end

    local part = rbGetHitPart(rbTarget.Character)
    if not part then
        rbAimPos = nil
        rbUpdateVisuals()
        return
    end

    rbAimPos = rbResolvePos(rbTarget, part)
    if not rbInFOV(rbAimPos) then
        rbUpdateVisuals()
        return
    end

    -- soft lock for wallbang / silent using existing systems without starting orbit rage
    if c.AutoFireWallBang then
        if not Config.WallShoot then Config.WallShoot = { Enabled = true } end
        if not Config.WallShoot.Enabled then
            Config.WallShoot.Enabled = true
            pcall(function() if F.tryInstallWallShoot then F.tryInstallWallShoot() end end)
        end
    end
    -- point existing silent/lock at this target without enabling rageBotEnabled
    pcall(function()
        if F.forceLockOnPlayer then
            F.forceLockOnPlayer(rbTarget)
        end
    end)

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local targetHRP = F.getHRP(rbTarget)
    if myHRP and targetHRP then
        rbFollow(myHRP, targetHRP, dt)
    end

    -- auto fire (Activate only — no ShootGun rewrite)
    if c.AutoFire then
        local tool = myChar and myChar:FindFirstChildOfClass("Tool")
        if not tool and c.AutoEquip then
            F.rbEquipGun()
            tool = myChar and myChar:FindFirstChildOfClass("Tool")
        end
        local cooldown = (tonumber(c.FireCooldown) or 5) / 1000
        local shotDelay = (tonumber(c.ShotDelay) or 0) / 1000
        local gap = math.max(cooldown, shotDelay)
        if tool and c.AutoFire and (now - rbLastFire) >= gap then
            if shotDelay > 0 then
                task.wait(shotDelay)
            end
            pcall(function() tool:Activate() end)
            F.markShot()
            rbLastFire = tick()
        end
    end

    rbUpdateVisuals()
end)

F.jConnect(Players.PlayerRemoving, function(plr)
    if rbTarget == plr then
        F.rbSetTarget(nil, false)
    end
    if plr then
        rbPosHistory[plr.UserId] = nil
        rbLastGoodPos[plr.UserId] = nil
    end
end)



end
F._init_juruRagebot()

-- Camera aimbot only when user enables Aimbot toggle (not at boot)
-- if not isXeno then F.bindCameraAimbot() end

if not isXeno then
    pcall(function()
        local oldRandom
        oldRandom = hookfunction(math.random, function(...)
            if not JuruAlive then return oldRandom(...) end
            local args = {...}
            local skip = false
            pcall(function() if checkcaller and checkcaller() then skip = true end end)
            if skip then return oldRandom(...) end
            if (#args == 0) or (args[1] == -0.05 and args[2] == 0.05) or (args[1] == -0.1) or (args[1] == -0.05) then
                if Config.Spread.Enabled then
                    return oldRandom(...) * (Config.Spread.Amount / 100)
                end
            end
            return oldRandom(...)
        end)
    end)
end


-- ============================================================
-- Auto Retaliate: INSTANT equip gun + lock + shoot on damage
-- ============================================================
local _retalLast = 0
local _retalLastHealth = nil
local _retalShotUntil = 0

function F.findRecentAttacker()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local be = char:FindFirstChild("BodyEffects")
    local candidates = {}
    local function push(plr)
        if plr and plr:IsA("Player") and plr ~= LocalPlayer and plr.Parent then
            table.insert(candidates, plr)
        end
    end
    local function checkTag(tag)
        if not tag then return end
        if tag:IsA("ObjectValue") then
            local v = tag.Value
            if typeof(v) == "Instance" then
                if v:IsA("Player") then push(v)
                elseif v:IsA("Model") then push(Players:GetPlayerFromCharacter(v)) end
            end
        elseif tag:IsA("StringValue") and tag.Value ~= "" then
            local p = Players:FindFirstChild(tag.Value)
            if p and p:IsA("Player") then push(p) end
            for _, plr in ipairs(Players:GetPlayers()) do
                if tostring(plr.UserId) == tag.Value or plr.Name == tag.Value or (plr.DisplayName and plr.DisplayName == tag.Value) then
                    push(plr)
                end
            end
        elseif tag:IsA("NumberValue") or tag:IsA("IntValue") then
            local plr = Players:GetPlayerByUserId(tonumber(tag.Value) or 0)
            push(plr)
        end
    end
    local tagNames = {"creator", "Creator", "creatorTag", "CreatorTag", "Killer", "LastHit", "DamageOwner", "Attacker", "LastAttacker", "Shooting", "LastShotBy"}
    if hum then
        for _, n in ipairs(tagNames) do checkTag(hum:FindFirstChild(n)) end
        for _, c in ipairs(hum:GetChildren()) do
            local nl = c.Name:lower()
            if nl:find("creat", 1, true) or nl:find("kill", 1, true) or nl:find("attack", 1, true) or nl:find("hit", 1, true) then
                checkTag(c)
            end
        end
    end
    if be then
        for _, n in ipairs(tagNames) do checkTag(be:FindFirstChild(n)) end
        for _, c in ipairs(be:GetChildren()) do
            local nl = c.Name:lower()
            if nl:find("creat", 1, true) or nl:find("kill", 1, true) or nl:find("attack", 1, true) or nl:find("hit", 1, true) then
                checkTag(c)
            end
        end
    end
    -- fallback: nearest living enemy looking at us / holding tool
    if #candidates == 0 then
        local myHRP = char:FindFirstChild("HumanoidRootPart")
        if myHRP then
            local best, bestD = nil, 450
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and not F.isWhitelisted(plr) and not F.isPlayerKnockedOrKO(plr) then
                    local tchar = plr.Character
                    local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
                    local thum = tchar and tchar:FindFirstChildOfClass("Humanoid")
                    if thrp and thum and thum.Health > 0 then
                        local d = (thrp.Position - myHRP.Position).Magnitude
                        if d < bestD then
                            -- prefer players holding a tool (likely shooting)
                            local hasTool = tchar:FindFirstChildOfClass("Tool") ~= nil
                            local score = d - (hasTool and 80 or 0)
                            if score < bestD then
                                bestD = score
                                best = plr
                            end
                        end
                    end
                end
            end
            if best then return best end
        end
    end
    local best, bestD = nil, math.huge
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    for _, plr in ipairs(candidates) do
        if plr and plr.Parent and not F.isWhitelisted(plr) and not F.isPlayerKnockedOrKO(plr) then
            local thrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if thrp and myHRP then
                local d = (thrp.Position - myHRP.Position).Magnitude
                if d < bestD then bestD = d; best = plr end
            elseif not best then
                best = plr
            end
        end
    end
    return best
end

function F.retaliateNow(attacker)
    if not attacker or not attacker.Parent then return end
    if F.isWhitelisted(attacker) then return end
    local char = LocalPlayer.Character
    if not char then return end
    -- 1) equip gun(s) FIRST
    pcall(function()
        if F.ensureGunsEquipped then F.ensureGunsEquipped()
        elseif F.equipAnyGun then F.equipAnyGun() end
    end)
    -- 2) lock instantly
    pcall(function() F.forceLockOnPlayer(attacker) end)
    isLocking = true
    -- 3) shoot ALL equipped tools immediately + burst
    local function fireAll()
        local c = LocalPlayer.Character
        if not c then return end
        for _, tool in ipairs(c:GetChildren()) do
            if tool:IsA("Tool") then
                pcall(function() tool:Activate() end)
            end
        end
        pcall(function() F.markShot() end)
    end
    fireAll()
    fireAll()
    _retalShotUntil = tick() + 0.55
    -- short burst while locked
    task.spawn(function()
        for _ = 1, 8 do
            if not JuruAlive then return end
            if tick() > _retalShotUntil then break end
            pcall(function()
                if F.ensureGunsEquipped then F.ensureGunsEquipped() end
            end)
            pcall(function() F.forceLockOnPlayer(attacker) end)
            fireAll()
            task.wait(0.04)
        end
    end)
end

function F.autoRetaliateTick()
    if not (Config.Settings and Config.Settings.AutoRetaliate) then return end
    if tick() - _retalLast < 0.04 then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        _retalLastHealth = nil
        return
    end
    local h = hum.Health
    if _retalLastHealth == nil then
        _retalLastHealth = h
        return
    end
    if h >= _retalLastHealth - 0.01 then
        -- still track healing / small noise
        if h > _retalLastHealth then _retalLastHealth = h end
        return
    end
    -- took damage — react INSTANTLY
    local lost = _retalLastHealth - h
    _retalLastHealth = h
    _retalLast = tick()
    local attacker = F.findRecentAttacker()
    if not attacker then return end
    F.retaliateNow(attacker)
end

-- also bind HealthChanged for zero-frame reaction
local function bindRetalHealth(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        hum = char and char:WaitForChild("Humanoid", 5)
    end
    if not hum then return end
    _retalLastHealth = hum.Health
    F.jConnect(hum.HealthChanged, function(newH)
        if not JuruAlive then return end
        if not (Config.Settings and Config.Settings.AutoRetaliate) then
            _retalLastHealth = newH
            return
        end
        local prev = _retalLastHealth
        _retalLastHealth = newH
        if prev and newH < prev - 0.01 and tick() - _retalLast >= 0.03 then
            _retalLast = tick()
            local attacker = F.findRecentAttacker()
            if attacker then F.retaliateNow(attacker) end
        end
    end)
end

F.jConnect(RunService.Heartbeat, function()
    if not JuruAlive then return end
    F.autoRetaliateTick()
end)

if LocalPlayer.Character then
    task.defer(bindRetalHealth, LocalPlayer.Character)
end
F.jConnect(LocalPlayer.CharacterAdded, function(char)
    _retalLastHealth = nil
    task.defer(bindRetalHealth, char)
end)

-- ============================================================
-- Hitbox expander (actual HRP Size expand only — no metatable index spoof)
-- ============================================================
local hbeRestore = nil
local hbeOriginalSizes = {} -- [UserId] = Vector3
local DEFAULT_HRP_SIZE = Vector3.new(2, 2, 1)

function F.isOtherPlayerHRP(part)
    if not part or typeof(part) ~= "Instance" then return false end
    if not part:IsA("BasePart") then return false end
    if part.Name ~= "HumanoidRootPart" then return false end
    local char = part.Parent
    if not char then return false end
    local plr = Players:GetPlayerFromCharacter(char)
    return plr ~= nil and plr ~= LocalPlayer
end

function F.restoreAllHitboxes()
    for uid, orig in pairs(hbeOriginalSizes) do
        local plr = Players:GetPlayerByUserId(uid)
        if plr and F.getCharacter(plr) then
            local hrp = F.getHRP(plr)
            if hrp then
                pcall(function()
                    hrp.Size = orig or DEFAULT_HRP_SIZE
                    hrp.Transparency = 1
                    hrp.CanCollide = false
                    hrp.Color = Color3.fromRGB(163, 162, 165)
                    hrp.Material = Enum.Material.Plastic
                end)
            end
        end
        hbeOriginalSizes[uid] = nil
    end
end

function F.applyHitboxToCharacter(char, player)
    if not char or not char.Parent or not player or player == LocalPlayer then return end
    if F.isWhitelisted(player) then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then return end
    local uid = player.UserId
    -- Store the true size once (before we expand). Prefer default if already expanded.
    if not hbeOriginalSizes[uid] then
        local s = hrp.Size
        if s.X > 4 or s.Y > 4 or s.Z > 4 then
            hbeOriginalSizes[uid] = DEFAULT_HRP_SIZE
        else
            hbeOriginalSizes[uid] = s
        end
    end
    local sz = Config.Hitbox.Size or 15
    local targetSize = Vector3.new(sz, sz, sz)
    -- Only touch Size / visual — do NOT change Material, Shape, Massless, etc.
    -- Those break client movement replication and freeze other players on your screen.
    if hrp.Size ~= targetSize then
        hrp.Size = targetSize
    end
    if hrp.CanCollide then
        hrp.CanCollide = false
    end
    if Config.Hitbox.ShowVisual then
        local col = Config.Hitbox.Color or Color3.fromRGB(190, 90, 255)
        local tr = tonumber(Config.Hitbox.Transparency)
        if tr == nil then tr = 0.35 end
        tr = math.clamp(tr, 0.05, 0.85)
        hrp.Color = col
        hrp.Transparency = tr
        -- neon makes expanded HRP much easier to see through walls
        pcall(function()
            if hrp.Material ~= Enum.Material.ForceField then
                hrp.Material = Enum.Material.ForceField
            end
        end)
    else
        if hrp.Transparency ~= 1 then hrp.Transparency = 1 end
        pcall(function()
            if hrp.Material == Enum.Material.ForceField then
                hrp.Material = Enum.Material.Plastic
            end
        end)
    end
end

function F.stripHitboxFromCharacter(char, player)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local uid = player and player.UserId
    local orig = (uid and hbeOriginalSizes[uid]) or DEFAULT_HRP_SIZE
    pcall(function()
        hrp.Size = orig
        hrp.Transparency = 1
        hrp.CanCollide = false
        hrp.Material = Enum.Material.Plastic
    end)
    if uid then hbeOriginalSizes[uid] = nil end
end

-- No __index Size spoof — IndexInstance detectors flag getrawmetatable game.__index hooks.
-- Hitbox expand still works via real Size changes in applyHitboxToCharacter.
print("[Juru] Hitbox expander: real Size expand only (no index spoof)")

local _lastHbe = 0
F.jConnect(RunService.Heartbeat, function()
    if not Config.Hitbox then return end
    if tick() - _lastHbe < 0.2 then return end
    _lastHbe = tick()

    local expandAll = Config.Hitbox.Enabled
    local rageOnly = (not expandAll) and rageBotEnabled and rageTargetPlayer
        and rageTargetPlayer.Parent and rageTargetPlayer.Character

    if not expandAll and not rageOnly then
        if next(hbeOriginalSizes) ~= nil then
            F.restoreAllHitboxes()
        end
        return
    end

    if expandAll then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                F.applyHitboxToCharacter(plr.Character, plr)
            end
        end
    else
        local target = rageTargetPlayer
        for uid, _ in pairs(hbeOriginalSizes) do
            if not target or uid ~= target.UserId then
                local plr = Players:GetPlayerByUserId(uid)
                if plr and plr.Character then
                    F.stripHitboxFromCharacter(plr.Character, plr)
                else
                    hbeOriginalSizes[uid] = nil
                end
            end
        end
        if target and target.Character then
            F.applyHitboxToCharacter(target.Character, target)
        end
    end
end)

F.jConnect(Players.PlayerRemoving, function(plr)
    if plr and hbeOriginalSizes[plr.UserId] then
        hbeOriginalSizes[plr.UserId] = nil
    end
end)




function F.TriggerBot()
    if not Config.TriggerBot.Enabled or not triggerEnabled then return end
    if tick() - lastTriggerClick < Config.TriggerBot.Delay then return end
    if not isLocking or not currentTarget or not currentTarget.Parent then return end
    local player = Players:GetPlayerFromCharacter(currentTarget.Parent)
    if not player or F.isPlayerKnockedOrKO(player) then return end
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    tool:Activate()
    F.markShot()
    lastTriggerClick = tick()
end

function F.getToolAmmo(tool)
    if not tool then return nil end
    local names = {"Ammo", "ammo", "Clip", "clip", "Magazine", "Bullets", "CurrentAmmo", "AmmoCount", "MaxAmmo"}
    for _, n in ipairs(names) do
        local v = tool:FindFirstChild(n)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then return v.Value end
        local cfg = tool:FindFirstChild("Configuration") or tool:FindFirstChild("GunConfig") or tool:FindFirstChild("Settings")
        if cfg then
            local r = cfg:FindFirstChild(n)
            if r and (r:IsA("NumberValue") or r:IsA("IntValue")) then return r.Value end
        end
    end
    local ok, attr = pcall(function() return tool:GetAttribute("Ammo") or tool:GetAttribute("ammo") end)
    if ok and type(attr) == "number" then return attr end
    return nil
end

function F.isGunTool(tool)
    -- treat every Tool as equippable (user preference: equip everything)
    return tool ~= nil and tool:IsA("Tool")
end

function F.collectTools()
    local list = {}
    local seen = {}
    local function add(t)
        if t and t:IsA("Tool") and not seen[t] then
            seen[t] = true
            table.insert(list, t)
        end
    end
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do add(t) end
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do add(t) end
    end
    -- StarterGear sometimes mirrors owned tools
    local sg = LocalPlayer:FindFirstChild("StarterGear")
    if sg then
        for _, t in ipairs(sg:GetChildren()) do add(t) end
    end
    return list
end

function F.equipAnyGun()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if char:FindFirstChildOfClass("Tool") then return true end
    local prefer, fallback = nil, nil
    local bag = LocalPlayer:FindFirstChild("Backpack")
    for _, t in ipairs(F.collectTools()) do
        if t:IsA("Tool") and (t.Parent == bag or t.Parent == char) then
            local n = t.Name:lower()
            if n:find("double", 1, true) or n:find("tactical", 1, true) or n:find("shotgun", 1, true) then
                prefer = t
                break
            end
            if not fallback then fallback = t end
        end
    end
    local pick = prefer or fallback
    if pick then
        pcall(function()
            if pick.Parent ~= char then
                pick.Parent = char
            end
        end)
        pcall(function() hum:EquipTool(pick) end)
        return true
    end
    return false
end

-- Multi Equip: force ALL tools onto character (multi-wield)
function F.equipAllGuns()
    local char = F.getCharacter(LocalPlayer)
    if not char then
        warn("[Juru] equipAllGuns: no character")
        return 0
    end
    local hum = F.getHumanoid(char)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then
        warn("[Juru] equipAllGuns: no backpack")
        return 0
    end

    -- Equip every tool in backpack / character
    local list = {}
    local seen = {}
    local function add(t)
        if t and t:IsA("Tool") and not seen[t] then
            seen[t] = true
            table.insert(list, t)
        end
    end
    for _, t in ipairs(bp:GetChildren()) do add(t) end
    for _, t in ipairs(char:GetChildren()) do add(t) end
    if #list == 0 then
        warn("[Juru] equipAllGuns: no tools found")
        return 0
    end

    local count = 0
    -- Method 1: direct Parent to character (classic multi-equip)
    for _, tool in ipairs(list) do
        pcall(function()
            if tool.Parent ~= char then
                tool.Parent = char
            end
            if tool.Parent == char then
                count = count + 1
            end
        end)
    end

    -- Method 2: Humanoid:EquipTool each (some anti-cheats only allow this path)
    if hum then
        for _, tool in ipairs(list) do
            pcall(function()
                if tool.Parent == bp or tool.Parent == char then
                    hum:EquipTool(tool)
                    if tool.Parent ~= char then
                        tool.Parent = char
                    end
                    if tool.Parent == char then count = math.max(count, 1) end
                end
            end)
        end
    end

    -- Method 3: short delayed re-parent (game scripts often strip extras 1 frame later)
    task.spawn(function()
        for _ = 1, 6 do
            if not JuruAlive then return end
            local c = LocalPlayer.Character
            local bag = LocalPlayer:FindFirstChild("Backpack")
            if not c or not bag then return end
            for _, tool in ipairs(bag:GetChildren()) do
                if tool:IsA("Tool") and F.isGunTool(tool) then
                    pcall(function() tool.Parent = c end)
                end
            end
            task.wait(0.03)
        end
    end)

    print("[Juru] equipAllGuns: moved", count, "tools (", #list, "candidates)")
    return count
end

function F.multiEquipEnabled()
    return Config.MultiEquip and Config.MultiEquip.Enabled == true
end

function F.ensureGunsEquipped()
    if F.multiEquipEnabled() then
        local n = F.equipAllGuns()
        if n > 0 then return true end
        return F.equipAnyGun()
    end
    return F.equipAnyGun()
end

local lastKeyPress = {}
function F.pressKey(keyCode, cooldown)
    cooldown = cooldown or 0.12
    local name = tostring(keyCode)
    if tick() - (lastKeyPress[name] or 0) < cooldown then return false end
    lastKeyPress[name] = tick()
    task.spawn(function()
        pcall(function()
            local vk = ({ [Enum.KeyCode.R] = 0x52, [Enum.KeyCode.G] = 0x47 })[keyCode]
            if vk and typeof(keypress) == "function" then
                keypress(vk)
                task.wait(0.06)
                if typeof(keyrelease) == "function" then keyrelease(vk) end
            end
        end)
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, keyCode, false, game)
            task.wait(0.06)
            vim:SendKeyEvent(false, keyCode, false, game)
        end)
    end)
    return true
end

function F.skyHop(myHRP, height)
    if not myHRP then return end
    local x = (math.random() - 0.5) * 1200
    local z = (math.random() - 0.5) * 1200
    local y = (height or 750) + (math.random() - 0.5) * 80
    myHRP.CFrame = CFrame.new(x, y, z)
    myHRP.AssemblyLinearVelocity = Vector3.new()
end

F.jConnect(RunService.RenderStepped, function()

    if rageBotEnabled and rageTargetPlayer and rageTargetPlayer.Parent then
        if not F.isPlayerKnockedOrKO(rageTargetPlayer) then
            F.forceLockOnPlayer(rageTargetPlayer)
        end
    else
    end

    if F.isSelfKnocked() and isLocking and not F.stickyLockOn() and not (rageBotEnabled and rageTargetPlayer) then
        currentTarget = nil
        isLocking = false
    end

    if isLocking and currentTarget then
        if not currentTarget.Parent or not currentTarget:IsDescendantOf(Workspace) then
            if not (rageBotEnabled and rageTargetPlayer) then
                currentTarget = nil
                isLocking = false
            end
        else
            local plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
            if not plr then
                if not (rageBotEnabled and rageTargetPlayer) then
                    currentTarget = nil
                    isLocking = false
                end
            elseif F.isPlayerKnockedOrKO(plr) and not F.stickyLockOn() then
                if not (rageBotEnabled and rageTargetPlayer == plr) then
                    currentTarget = nil
                    isLocking = false
                end
            end
        end
    end


    if not rageBotEnabled then
        local lockCfg = Config.Keybinds.TargetLock
        local canLock = (Config.SilentAim and Config.SilentAim.Enabled == true)
            or (Config.SilentAim and Config.SilentAim.UseCameraAimbot == true)
            or (Config.SoftLock and Config.SoftLock.Enabled == true)
            or (Config.Ragebot and Config.Ragebot.Enabled == true)
        if canLock and type(lockCfg) == "table" and lockCfg.Mode == "Hold" then
            local keyName = lockCfg.Key or "E"
            local keyCode = Enum.KeyCode[keyName]
            if keyCode and UserInputService:IsKeyDown(keyCode) then
                if not isLocking or not currentTarget or not currentTarget.Parent then
                    local target = F.findClosestTarget()
                    if target then
                        currentTarget = target
                        isLocking = true
                    end
                end
            end
        end
    end

    F.TriggerBot()

    if SpeedEnabled and Config.Speed and Config.Speed.Enabled and tick() >= (charReadyAt or 0) then
        pcall(function()
            local c = LocalPlayer.Character
            if not c or not c.Parent then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local t = math.clamp(tonumber(Config.Speed.WalkSpeed) or 640, 16, 800)
            if math.abs((hum.WalkSpeed or 0) - t) > 0.5 then
                hum.WalkSpeed = t
            end
        end)
    end

    F.updateSoftLock()
    F.updateFOVCircle()
    F.updateTracer()
    -- ESP / spectate: ~30 Hz is enough (saves CPU vs full RenderStepped rate)
    local _rs = F._rsEspAccum or 0
    _rs = _rs + 1
    if _rs >= 2 then
        _rs = 0
        F.refreshESP()
        F.updateSpectate()
    end
    F._rsEspAccum = _rs
end)

-- Super jump: works while CFrame speed is on (preserves Y; cooldown gate)
local _superJumpUntil = 0
F.jConnect(RunService.Heartbeat, function()
    if not Config.SuperJump.Enabled or not superJumpActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end
    local keyName = Config.Keybinds.SuperJump
    local keyCode = Enum.KeyCode[tostring(keyName)]
    if not (keyCode and UserInputService:IsKeyDown(keyCode)) then return end
    if tick() < _superJumpUntil then return end
    -- Allow jump when grounded OR when CFrame speed is active (MoveDirection / air)
    local grounded = hum:GetState() == Enum.HumanoidStateType.Landed
        or hum:GetState() == Enum.HumanoidStateType.Running
        or hum.FloorMaterial ~= Enum.Material.Air
    local cframeOn = cFrameSpeedEnabled and Config.CFrameSpeed and Config.CFrameSpeed.Enabled
    if grounded or cframeOn then
        local power = Config.SuperJump.Power or 260
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(
                root.AssemblyLinearVelocity.X,
                power,
                root.AssemblyLinearVelocity.Z
            )
        end)
        pcall(function()
            root.Velocity = Vector3.new(root.Velocity.X, power, root.Velocity.Z)
        end)
        _superJumpUntil = tick() + (Config.SuperJump.Cooldown or 0.1)
    end
end)

-- SmartRange uses Origin shift; Tool.Range rewrite removed (AC).


-- (rapid fire handled by juru RF block above)


-- CFrame speed: preserve vertical velocity so Super Jump works at the same time
F.jConnect(RunService.Heartbeat, function()
    if not cFrameSpeedEnabled or not Config.CFrameSpeed or not Config.CFrameSpeed.Enabled then return end
    if tick() < (charReadyAt or 0) then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    local speed = Config.CFrameSpeed.Speed or 0.9
    local vel = hrp.AssemblyLinearVelocity
    if not vel then vel = hrp.Velocity end
    local yVel = vel.Y
    local move = hum.MoveDirection
    if move.Magnitude > 0 then
        hrp.CFrame = hrp.CFrame + move * (speed / 0.5)
    end
    RunService.RenderStepped:Wait()
    -- Restore horizontal from pre-move, keep current/boosted Y (super jump)
    local curY = yVel
    pcall(function()
        local now = hrp.AssemblyLinearVelocity
        if now and math.abs(now.Y) > math.abs(yVel) then
            curY = now.Y
        end
    end)
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, curY, vel.Z)
    end)
    pcall(function()
        hrp.Velocity = Vector3.new(vel.X, curY, vel.Z)
    end)
end)

F.jConnect(RunService.Heartbeat, function(dt)
    if not rageBotEnabled then return end
    if rageReloading then return end

    local focus = F.pickRageTarget()
    if not focus then
        if Config.AntiRage and Config.AntiRage.Enabled and rageTargetPlayer and rageTargetPlayer.Parent then
            local myChar0 = LocalPlayer.Character
            local myHRP0 = myChar0 and myChar0:FindFirstChild("HumanoidRootPart")
            if myHRP0 then
                if F.isFarRage() then
                    F.farRageHop(myHRP0, nil, Config.RageBot and Config.RageBot.FarDistance)
                else
                    F.skyHop(myHRP0, (Config.RageBot and Config.RageBot.SkyHeight) or 750)
                end
            end
            return
        end
        F.stopRageBot(false)
        return
    end
    rageTargetPlayer = focus

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local cfg = Config.RageBot or {}
    local radius = cfg.OrbitRadius or 3
    local orbitSpd = cfg.OrbitSpeed or 55
    local shootDelay = cfg.ShootDelay or 0.015
    local skyH = cfg.SkyHeight or 750
    local farDist = tonumber(cfg.FarDistance) or 2800
    local farMode = F.isFarRage()

    -- Respawn wait on target
    do
        local tChar0 = focus.Character
        if tChar0 and tChar0 ~= rageTrackedSpawnChar then
            local prevDead = rageTrackedSpawnChar ~= nil
            rageTrackedSpawnChar = tChar0
            if prevDead then
                local waitS = tonumber(cfg.SpawnWait) or 1.0
                rageTargetSpawnWaitUntil = tick() + math.max(0, waitS)
            end
        elseif not tChar0 then
            rageTrackedSpawnChar = nil
        end
        if rageTargetSpawnWaitUntil > 0 and tick() < rageTargetSpawnWaitUntil then
            -- Hold: stay far (or sky) AND keep spectating them during the delay
            if farMode then
                F.farRageHop(myHRP, nil, farDist)
            else
                F.skyHop(myHRP, skyH)
            end
            if not isXeno then
                pcall(function() F.updateSpectate() end)
            end
            return
        elseif rageTargetSpawnWaitUntil > 0 and tick() >= rageTargetSpawnWaitUntil then
            rageTargetSpawnWaitUntil = 0
            rageTpAccum = 99
        end
    end

    local tChar = rageTargetPlayer.Character
    local downed = F.isPlayerKnockedOrKO(rageTargetPlayer)

    if tChar and tChar:FindFirstChild("HumanoidRootPart") and not downed then
        local thum = tChar:FindFirstChildOfClass("Humanoid")
        if thum and thum.Health > 0 then
            F.forceLockOnPlayer(rageTargetPlayer)

            local head = tChar:FindFirstChild("Head")
            local targetHRP = tChar.HumanoidRootPart
            local aimPos = F.getPredictedPosition(head or targetHRP)

            if farMode then
                -- FAR ONLY — never run close orbit code
                if Config.WallShoot then Config.WallShoot.Enabled = true end
                pcall(function() if F.tryInstallWallShoot then F.tryInstallWallShoot() end end)
                if not isXeno then
                    pcall(function() F.updateSpectate() end)
                end
                local minDist = math.max(900, farDist * 0.75)
                local tooClose = (myHRP.Position - targetHRP.Position).Magnitude < minDist
                rageTpAccum = (rageTpAccum or 0) + (dt or 0.016) * 0.8
                if rageTpAccum >= 1 or tooClose then
                    rageTpAccum = 0
                    F.farRageHop(myHRP, aimPos, farDist)
                else
                    -- only rotate look; do not move closer
                    myHRP.CFrame = CFrame.new(myHRP.Position, aimPos)
                end
            else
                -- Close Teleport Rage
                local tpRate = math.max(8, orbitSpd)
                rageTpAccum = (rageTpAccum or 0) + (dt or 0.016) * (tpRate / 10)
                local needSnap = rageTpAccum >= 1 or (myHRP.Position - targetHRP.Position).Magnitude > (radius + 8)
                if needSnap or cfg.TeleportRage ~= false then
                    if needSnap then rageTpAccum = 0 end
                    local ang = math.random() * math.pi * 2
                    local r = math.max(1.5, radius) * (0.7 + math.random() * 0.6)
                    local ox = math.cos(ang) * r
                    local oz = math.sin(ang) * r
                    local oy = (math.random() < 0.72) and (8 + math.random() * 22) or (1.5 + math.random() * 3)
                    myHRP.CFrame = CFrame.new(targetHRP.Position + Vector3.new(ox, oy, oz), aimPos)
                    myHRP.AssemblyLinearVelocity = Vector3.new()
                else
                    myHRP.CFrame = CFrame.new(myHRP.Position, aimPos)
                end
                if not isXeno then
                    pcall(function() F.updateSpectate() end)
                end
            end

            local tool = myChar:FindFirstChildOfClass("Tool")
            if not tool then
                F.equipAnyGun()
                tool = myChar:FindFirstChildOfClass("Tool")
            end
            if tool and tick() - lastRageShot >= shootDelay then
                pcall(function() tool:Activate() end)
                pcall(function() tool:Activate() end)
                pcall(function() tool:Activate() end)
                F.markShot()
                lastRageShot = tick()
            end
            return
        end
    end

    local nextAlive = F.pickRageTarget()
    if nextAlive and nextAlive ~= focus and nextAlive.Character and not F.isPlayerKnockedOrKO(nextAlive) then
        rageTargetPlayer = nextAlive
        F.forceLockOnPlayer(nextAlive)
        return
    end

    isLocking = false
    currentTarget = nil
    if farMode then
        F.farRageHop(myHRP, nil, farDist)
        if not isXeno then pcall(function() F.updateSpectate() end) end
    else
        F.skyHop(myHRP, skyH)
    end
end)

F.jConnect(RunService.Heartbeat, function()
    if not rageBotEnabled or not rageTargetPlayer then return end
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    if rageReloading then
        F.skyHop(myHRP, 800)
        F.pressKey(Enum.KeyCode.R, 0.4)
        local tool = myChar:FindFirstChildOfClass("Tool")
        local ammo = F.getToolAmmo(tool)
        if (ammo ~= nil and ammo > 0) or tick() >= rageReloadUntil then
            rageReloading = false
        end
        return
    end

    local tool = myChar:FindFirstChildOfClass("Tool")
    if not tool then
        F.equipAnyGun()
        tool = myChar:FindFirstChildOfClass("Tool")
    end
    local ammo = F.getToolAmmo(tool)
    if ammo ~= nil and ammo <= 0 then
        F.pressKey(Enum.KeyCode.R, 0.3)
        rageReloading = true
        rageReloadUntil = tick() + 2.8
    end
end)

local lastAutoReload = 0
F.jConnect(RunService.Heartbeat, function()
    if not JuruAlive then return end
    if not (Config.AutoReload and Config.AutoReload.Enabled) then return end
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local ammo = F.getToolAmmo(tool)
    if ammo == nil then return end
    if ammo <= 0 and tick() - lastAutoReload >= 0.35 then
        lastAutoReload = tick()
        F.pressKey(Enum.KeyCode.R, 0.3)
    end
end)

F.jConnect(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then F.markShot() end
end)

function F.hookToolActivate(char)
    if not char then return end
    local function onTool(tool)
        if not tool:IsA("Tool") then return end
        F.jConnect(tool.Activated, function() F.markShot() end)
    end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then onTool(c) end
    end
    F.jConnect(char.ChildAdded, function(c)
        if c:IsA("Tool") then onTool(c) end
    end)
end
if LocalPlayer.Character then F.hookToolActivate(LocalPlayer.Character) end
F.jConnect(LocalPlayer.CharacterAdded, F.hookToolActivate)

function F.playerDropdownLabel(plr)
    if not plr then return "?" end
    local uname = tostring(plr.Name or "?")
    local safe = F.playerLabel(plr)
    if safe:lower() == uname:lower() then
        return uname
    end
    return string.format("%s (@%s)", safe, uname)
end

function F.getPlayerDropdownValues()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, F.playerDropdownLabel(plr))
        end
    end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    if #list == 0 then
        table.insert(list, "(no players)")
    end
    return list
end

function F.resolvePlayerFromDropdown(val)
    if typeof(val) == "Instance" and val:IsA("Player") then return val end
    if type(val) ~= "string" or val == "" or val == "(no players)" then return nil end
    -- Exact label match first: "Display (@Username)"
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and F.playerDropdownLabel(plr) == val then
            return plr
        end
    end
    -- Extract @Username from label
    local uname = val:match("%(@([^%)]+)%)")
    if uname then
        local p = Players:FindFirstChild(uname)
        if p and p:IsA("Player") then return p end
    end
    return F.findPlayerByQuery(val)
end

function F.findPlayerByQuery(query)
    if not query or query == "" then return nil end
    query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
    -- strip "display (@user)" style
    local atUser = query:match("%(@([^%)]+)%)")
    if atUser then query = atUser end
    local best, bestScore = nil, -1
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local name = plr.Name:lower()
            local display = (plr.DisplayName or ""):lower()
            local score = -1
            if name == query or display == query then
                score = 100
            elseif name:sub(1, #query) == query or display:sub(1, #query) == query then
                score = 80
            elseif name:find(query, 1, true) or display:find(query, 1, true) then
                score = 50
            end
            if score > bestScore then
                bestScore = score
                best = plr
            end
        end
    end
    return best
end

function F.teleportToPlayer(plr)
    if not plr then return false end
    local targetHRP = F.getHRP(plr)
    local myHRP = F.getHRP(LocalPlayer)
    if not targetHRP or not myHRP then return false end
    pcall(function()
        myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
    end)
    return true
end

function F.saveRageOrigin()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        -- only save if not already sky-high (avoid stacking void)
        if hrp.Position.Y < 400 then
            rageSavedCFrame = hrp.CFrame
        elseif not rageSavedCFrame then
            rageSavedCFrame = CFrame.new(hrp.Position.X, 20, hrp.Position.Z)
        end
    end
end

function F.restoreFromRage()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dest = rageSavedCFrame
    if not dest then
        -- fallback: drop to ground under current XZ
        local pos = hrp.Position
        dest = CFrame.new(pos.X, math.min(pos.Y, 50), pos.Z)
    end
    -- raycast down for floor
    pcall(function()
        local origin = Vector3.new(dest.Position.X, math.max(dest.Position.Y, 200), dest.Position.Z)
        local ray = Workspace:Raycast(origin, Vector3.new(0, -2000, 0))
        if ray then
            dest = CFrame.new(ray.Position + Vector3.new(0, 4, 0))
        end
    end)
    hrp.CFrame = dest
    hrp.AssemblyLinearVelocity = Vector3.new()
    hrp.AssemblyAngularVelocity = Vector3.new()
    rageSavedCFrame = nil
end


-- ============================================================
-- AntiRage: on respawn / un-knock — instant gun + lock + rage resume
-- No ForceField, no health edits, no fly, no rejoin.
-- ============================================================
local antiRageToken = 0
local pendingArmorBuy = false
local antiRageWasKnocked = false

function F.antiRageEnabled()
    return Config.AntiRage and Config.AntiRage.Enabled == true
end

function F.antiRageReposition(char)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Never pull into melee range during Far Rage
    if F.isFarRage() and rageBotEnabled then
        return
    end
    local offset = (Config.AntiRage and Config.AntiRage.Offset) or 10
    local dest = nil
    if rageBotEnabled and rageTargetPlayer and rageTargetPlayer.Parent then
        local tChar = rageTargetPlayer.Character
        local thrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if thrp and not F.isPlayerKnockedOrKO(rageTargetPlayer) then
            local ang = math.random() * math.pi * 2
            local r = 3.5 + math.random() * 2.5
            dest = CFrame.new(thrp.Position + Vector3.new(math.cos(ang) * r, 2.5, math.sin(ang) * r), thrp.Position)
        end
    end
    if not dest then
        local pos = hrp.Position
        dest = CFrame.new(
            pos.X + (math.random() - 0.5) * 2 * offset,
            pos.Y + 3,
            pos.Z + (math.random() - 0.5) * 2 * offset
        )
    end
    pcall(function()
        hrp.CFrame = dest
        hrp.AssemblyLinearVelocity = Vector3.new()
        hrp.AssemblyAngularVelocity = Vector3.new()
    end)
end

-- Instant re-engage: equip + lock + optional snap (no waits)
function F.antiRageEngage(char)
    if not JuruAlive or not F.antiRageEnabled() then return end
    if not char or not char.Parent then return end
    if not (rageBotEnabled and rageTargetPlayer and rageTargetPlayer.Parent) then return end
    if F.isSelfKnocked() then return end

    rageReloading = false
    pcall(function() F.equipAnyGun() end)
    F.forceLockOnPlayer(rageTargetPlayer)
    F.antiRageReposition(char)
    if not isXeno then
        pcall(function() F.updateSpectate() end)
    end
end

function F.antiRageOnRespawn(char)
    if not JuruAlive or not F.antiRageEnabled() then return end
    if not char then return end
    antiRageToken = antiRageToken + 1
    local token = antiRageToken
    antiRageWasKnocked = false

    -- Poll only until HRP exists (minimal), then engage immediately
    task.spawn(function()
        local hrp
        for _ = 1, 50 do
            if not JuruAlive or token ~= antiRageToken then return end
            hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then break end
            task.wait() -- next frame only
        end
        if not hrp or token ~= antiRageToken then return end
        F.antiRageEngage(char)
    end)

    -- Un-knock: as soon as K.O/Knocked clears, re-engage
    task.spawn(function()
        local be = char:WaitForChild("BodyEffects", 8)
        if not be or token ~= antiRageToken then return end
        local function onKnockChanged()
            if not JuruAlive or token ~= antiRageToken then return end
            local knocked = F.isSelfKnocked()
            if knocked then
                antiRageWasKnocked = true
            elseif antiRageWasKnocked then
                antiRageWasKnocked = false
                -- just stood up — instant re-engage
                F.antiRageEngage(char)
            end
        end
        for _, name in ipairs({"K.O", "KO", "Knocked"}) do
            local v = be:FindFirstChild(name)
            if v and v:IsA("BoolValue") then
                F.jConnect(v:GetPropertyChangedSignal("Value"), onKnockChanged)
            end
        end
        F.jConnect(be.ChildAdded, function(c)
            if (c.Name == "K.O" or c.Name == "KO" or c.Name == "Knocked") and c:IsA("BoolValue") then
                F.jConnect(c:GetPropertyChangedSignal("Value"), onKnockChanged)
            end
        end)
        -- light poll fallback (some games set KO without firing reliably)
        while JuruAlive and token == antiRageToken and char.Parent do
            onKnockChanged()
            task.wait(0.15)
        end
    end)
end

F.jConnect(LocalPlayer.CharacterAdded, function(char)
    task.spawn(F.antiRageOnRespawn, char)
end)

function F.startRageBot()
    rageBotEnabled = true
    if Config.RageBot then Config.RageBot.Enabled = true end
end

function F.stopRageBot(notify)
    if not rageBotEnabled then return end
    rageBotEnabled = false
    rageTargetPlayer = nil
    pcall(F.rbStop)
    rageTargetList = {}
    rageReloading = false
    F.restoreOwnCamera()
    pcall(F.restoreFromRage)
    if notify ~= false then
        F.pushNotification("rage bot OFF", false)
    end
end


function F.startRageOnPlayer(plr)
    if not plr or not plr.Parent then return false end
    if F.isWhitelisted(plr) then
        F.pushNotification("player is whitelisted", false)
        return false
    end
    F.saveRageOrigin()
    rageBotEnabled = true
    rageTargetPlayer = plr
    rageTargetList = { plr }
    rageTpAccum = 99
    F.forceLockOnPlayer(plr)
    if F.isFarRage() then
        if Config.WallShoot then Config.WallShoot.Enabled = true end
        pcall(function() if F.tryInstallWallShoot then F.tryInstallWallShoot() end end)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local aim = nil
        pcall(function()
            local h = plr.Character and (plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart"))
            if h then aim = h.Position end
        end)
        F.farRageHop(hrp, aim, Config.RageBot and Config.RageBot.FarDistance)
        -- Still spectate during far rage (camera on them, body stays far)
        if isXeno then
            F.restoreOwnCamera()
        else
            F.updateSpectate()
        end
    else
        if isXeno then
            F.restoreOwnCamera()
        else
            F.updateSpectate()
        end
    end
    local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
    local mode = F.isFarRage() and " (FAR)" or ""
    F.pushNotification("rage ON: " .. nm .. mode, false)
    return true
end

function F.handleCommand(msg)
    if type(msg) ~= "string" then return end
    local text = msg:gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, 1) ~= "!" then return end

    local args = {}
    for word in text:gmatch("%S+") do
        table.insert(args, word)
    end
    local cmd = (args[1] or ""):lower()

    if cmd == "!tp" then
        local query = table.concat(args, " ", 2)
        if query == "" then
            F.pushNotification("usage: !tp name", false)
            return
        end
        local plr = F.findPlayerByQuery(query)
        if not plr then
            F.pushNotification("player not found", false)
            return
        end
        if F.teleportToPlayer(plr) then
            local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
            F.pushNotification("tped to " .. nm, false)
        else
            F.pushNotification("tp failed", false)
        end
    elseif cmd == "!lock" then
        local query = table.concat(args, " ", 2)
        if query == "" then
            F.pushNotification("usage: !lock name", "lock")
            return
        end
        local plr = F.findPlayerByQuery(query)
        if not plr or not plr.Character then
            F.pushNotification("player not found", false)
            return
        end
        if F.isWhitelisted(plr) then
            F.pushNotification("player is whitelisted", false)
            return
        end
        if F.forceLockOnPlayer(plr) then
            local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
            F.pushNotification("locked to " .. nm, "lock")
        end
    elseif cmd == "!wl" or cmd == "!whitelist" then
        local sub = (args[2] or ""):lower()
        if sub == "list" or sub == "" and not args[2] then
            local list = Config.Whitelist.Players or {}
            if #list == 0 then
                F.pushNotification("whitelist empty", false)
            else
                F.pushNotification(F.whitelistLabelText(), false)
            end
            return
        end
        if sub == "clear" then
            F.whitelistClear()
            F.pushNotification("whitelist cleared", false)
            return
        end
        if sub == "on" then
            Config.Whitelist.Enabled = true
            F.saveWhitelist()
            F.pushNotification("whitelist ON", false)
            return
        end
        if sub == "off" then
            Config.Whitelist.Enabled = false
            F.saveWhitelist()
            F.pushNotification("whitelist OFF", false)
            return
        end
        local query = table.concat(args, " ", 2)
        local plr = F.findPlayerByQuery(query)
        if not plr then
            F.pushNotification("player not found", false)
            return
        end
        local ok, reason = F.whitelistAddPlayer(plr)
        local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
        if ok then
            F.pushNotification("whitelisted " .. nm, false)
            if isLocking and currentTarget and currentTarget.Parent then
                local locked = Players:GetPlayerFromCharacter(currentTarget.Parent)
                if locked == plr then isLocking = false; currentTarget = nil end
            end
            if rageTargetPlayer == plr then
                F.stopRageBot(false)
                F.pushNotification("rage stopped (whitelisted)", false)
            end
        elseif reason == "already" then
            F.pushNotification(nm .. " already whitelisted", false)
        else
            F.pushNotification("whitelist failed", false)
        end
    elseif cmd == "!unwl" or cmd == "!unwhitelist" then
        local query = table.concat(args, " ", 2)
        if query == "" then
            F.pushNotification("usage: !unwl name", false)
            return
        end
        local plr = F.findPlayerByQuery(query)
        if plr and F.whitelistRemovePlayer(plr) then
            local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
            F.pushNotification("removed " .. nm, false)
        else
            -- try remove by stored name if not in server
            local removed = false
            for _, e in ipairs(Config.Whitelist.Players or {}) do
                local n = (e.Name or ""):lower()
                local d = (e.DisplayName or ""):lower()
                local q = query:lower()
                if n == q or d == q or n:find(q, 1, true) or d:find(q, 1, true) then
                    F.whitelistRemoveByUserId(e.UserId)
                    F.pushNotification("removed " .. (e.DisplayName or e.Name), false)
                    removed = true
                    break
                end
            end
            if not removed then F.pushNotification("not on whitelist", false) end
        end
    elseif cmd == "!fov" then
        local n = tonumber(args[2])
        if not n then
            F.pushNotification("usage: !fov number (current " .. tostring(Config.FOV.Size) .. ")", false)
            return
        end
        Config.FOV.Size = n
        F.pushNotification("fov set to " .. n, false)
    elseif cmd == "!re" or cmd == "!reset" then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    elseif cmd == "!rj" or cmd == "!rejoin" then
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    elseif cmd == "!rage" then
        local query = table.concat(args, " ", 2)
        if query == "" then
            if rageBotEnabled then
                F.stopRageBot(true)
            else
                F.pushNotification("usage: !rage name", false)
            end
            return
        end
        local names = {}
        for part in query:gmatch("[^,]+") do
            local n = part:gsub("^%s+", ""):gsub("%s+$", "")
            if n ~= "" then table.insert(names, n) end
        end
        local found = {}
        for _, n in ipairs(names) do
            local plr = F.findPlayerByQuery(n)
            if plr and not F.isWhitelisted(plr) then table.insert(found, plr) end
        end
        if #found == 0 then
            F.pushNotification("player not found / all whitelisted", false)
            return
        end
        F.saveRageOrigin()
        rageTargetList = found
        rageTargetPlayer = found[1]
        rageBotEnabled = true
        rageTpAccum = 99
        F.forceLockOnPlayer(rageTargetPlayer)
        if F.isFarRage() then
            if Config.WallShoot then Config.WallShoot.Enabled = true end
            pcall(function() if F.tryInstallWallShoot then F.tryInstallWallShoot() end end)
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local aim = nil
            pcall(function()
                local h = rageTargetPlayer.Character and (rageTargetPlayer.Character:FindFirstChild("Head") or rageTargetPlayer.Character:FindFirstChild("HumanoidRootPart"))
                if h then aim = h.Position end
            end)
            F.farRageHop(hrp, aim, Config.RageBot and Config.RageBot.FarDistance)
            if isXeno then F.restoreOwnCamera() else F.updateSpectate() end
        else
            if isXeno then F.restoreOwnCamera() else F.updateSpectate() end
        end
        local label = {}
        for _, p in ipairs(found) do
            table.insert(label, (p.DisplayName ~= "" and p.DisplayName) or p.Name)
        end
        local mode = F.isFarRage() and " (FAR)" or ""
        F.pushNotification("rage ON: " .. table.concat(label, ", ") .. mode, false)
    end
end

local cmdLock = false
function F.handleCommandSafe(msg)
    if cmdLock then return end
    if type(msg) ~= "string" or msg:sub(1, 1) ~= "!" then return end
    cmdLock = true
    pcall(F.handleCommand, msg)
    task.delay(0.35, function() cmdLock = false end)
end

pcall(function()
    F.jConnect(LocalPlayer.Chatted, function(msg)
        F.handleCommandSafe(msg)
    end)
end)
pcall(function()
    if TextChatService then
        F.jConnect(TextChatService.SendingMessage, function(message)
            if message and message.Text then
                F.handleCommandSafe(message.Text)
            end
        end)
    end
end)

F.jConnect(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local function keyMatches(bind)
        if type(bind) == "table" then
            return input.KeyCode == Enum.KeyCode[tostring(bind.Key)]
        end
        return input.KeyCode == Enum.KeyCode[tostring(bind)]
    end


    if keyMatches(Config.Keybinds.TargetLock) then
        -- Lock only when Silent Aim, Camera Aimbot, or Soft Lock is enabled
        local canLock = (Config.SilentAim and Config.SilentAim.Enabled == true)
            or (Config.SilentAim and Config.SilentAim.UseCameraAimbot == true)
            or (Config.SoftLock and Config.SoftLock.Enabled == true)
            or (Config.Ragebot and Config.Ragebot.Enabled == true)
            or (rageBotEnabled == true)
        if not canLock then
            if isLocking and not (rageBotEnabled and rageTargetPlayer) then
                F.clearTargetLock()
                F.pushNotification("unlocked (enable Silent/Aimbot first)", "lock")
            end
            -- do not acquire lock while all aim features are off
        elseif F.softLockEnabled() then
            -- Soft Lock: keybind only unlocks (auto-lock handles acquire)
            if isLocking and not (rageBotEnabled and rageTargetPlayer) then
                F.clearTargetLock()
                F.pushNotification("unlocked", "lock")
            end
        else
            local lockMode = (type(Config.Keybinds.TargetLock) == "table" and Config.Keybinds.TargetLock.Mode) or "Toggle"
            if lockMode == "Hold" then
                local target = F.findClosestTarget()
                if target then
                    currentTarget = target
                    isLocking = true
                    local plr = Players:GetPlayerFromCharacter(target.Parent)
                    if plr then
                        local nm = (plr.DisplayName and plr.DisplayName ~= "") and plr.DisplayName or plr.Name
                        F.pushNotification("locked to " .. nm, "lock")
                    end
                end
            else
                if isLocking then
                    if not (rageBotEnabled and rageTargetPlayer) then
                        F.clearTargetLock()
                        F.pushNotification("unlocked", "lock")
                    end
                else
                    local target = F.findClosestTarget()
                    if target then
                        currentTarget = target
                        isLocking = true
                        local plr = Players:GetPlayerFromCharacter(target.Parent)
                        if plr then
                            local nm = (plr.DisplayName and plr.DisplayName ~= "") and plr.DisplayName or plr.Name
                            F.pushNotification("locked to " .. nm, "lock")
                        end
                    end
                end
            end
        end
    end


    if keyMatches(Config.Keybinds.TriggerBot) then
        triggerEnabled = not triggerEnabled
    end


    if keyMatches(Config.Keybinds.Speed) then
        if not Config.Speed then Config.Speed = { WalkSpeed = 640 } end
        Config.Speed.Enabled = true
        SpeedEnabled = not SpeedEnabled
        if not SpeedEnabled then
            pcall(function()
                local c = LocalPlayer.Character
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = BaseSpeed end
            end)
            F.pushNotification("speed OFF", 2)
        else
            F.pushNotification("speed ON", 2)
        end
    end


    if keyMatches(Config.Keybinds.SuperJump) then
        superJumpActive = not superJumpActive
    end


    if keyMatches(Config.Keybinds.RapidFire) then
        Config.RapidFire.Enabled = not Config.RapidFire.Enabled
        pcall(function()
            if F.rfApplyEnabled then F.rfApplyEnabled(Config.RapidFire.Enabled) end
        end)
        pcall(function()
            if Toggles and Toggles.RapidFireEnabled and Toggles.RapidFireEnabled.SetValue then
                Toggles.RapidFireEnabled:SetValue(Config.RapidFire.Enabled)
            end
        end)
        F.pushNotification(Config.RapidFire.Enabled and "rapid fire on" or "rapid fire off", false)
    end


    if keyMatches(Config.Keybinds.CFrameSpeed) then
        if not Config.CFrameSpeed then Config.CFrameSpeed = { Speed = 0.9 } end
        Config.CFrameSpeed.Enabled = true
        cFrameSpeedEnabled = not cFrameSpeedEnabled
        F.pushNotification(cFrameSpeedEnabled and "cframe speed ON" or "cframe speed OFF", 2)
    end


    if keyMatches(Config.ChatMacro and Config.ChatMacro.Key or Config.Keybinds.ChatMacro) then
        F.trySendChatMacro()
    end

    if keyMatches(Config.Keybinds.Fly) then
        F.toggleFly(nil, false)
    end


    if keyMatches(Config.Keybinds.RageBot) then
        if not rageBotEnabled then
            local plr = nil
            if currentTarget and currentTarget.Parent then
                plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
            end
            if not plr and rageTargetPlayer and rageTargetPlayer.Parent then
                plr = rageTargetPlayer
            end
            if plr then
                F.saveRageOrigin()
                rageBotEnabled = true
                rageTargetPlayer = plr
                rageTargetList = { plr }
                F.forceLockOnPlayer(plr)
                            if isXeno then
                    F.restoreOwnCamera()
                else
                    F.updateSpectate()
                end
                local nm = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
                F.pushNotification("rage bot ON: " .. nm, false)
            else
                F.pushNotification("lock someone first", "lock")
            end
        else
            F.stopRageBot(true)
        end
    end
end)

F.jConnect(UserInputService.InputEnded, function(input, processed)
    if processed then return end
    if F.softLockEnabled() then return end -- soft lock ignores hold release
    if type(Config.Keybinds.TargetLock) == "table"
        and Config.Keybinds.TargetLock.Mode == "Hold"
        and input.KeyCode == Enum.KeyCode[tostring(Config.Keybinds.TargetLock.Key)] then
        if not (rageBotEnabled and rageTargetPlayer) then
            F.clearTargetLock()
        end
    end
end)

-- ============================================================
-- MENU CAMERA / MOUSE UNLOCK + LOCAL FX
-- ============================================================
local menuOpen = false
local localFxParts = {}
local _menuMouseUntil = 0 -- briefly free mouse after toggle; never permanent

function F.setMenuOpen(open)
    -- free mouse briefly when menu is interacted with; never permanently kill camera
    menuOpen = open and true or false
    pcall(function()
        if menuOpen then
            _menuMouseUntil = tick() + 0.45
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
            local cam = workspace.CurrentCamera
            if cam then
                pcall(function() cam.CameraType = Enum.CameraType.Custom end)
            end
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.CameraOffset = Vector3.new()
                    -- do NOT force Classic camera mode every time — that blocks looking around
                end
            end)
        else
            UserInputService.MouseIconEnabled = true
        end
    end)
end

-- Only free mouse for a short window after menu toggle (so camera still works in-game)
F.jConnect(RunService.RenderStepped, function()
    if tick() > _menuMouseUntil then return end
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
end)

function F.clearLocalFx()
    for _, p in pairs(localFxParts) do
        pcall(function() p:Destroy() end)
    end
    table.clear(localFxParts)
end

function F.applyLocalFx()
    F.clearLocalFx()
    local cfg = Config.LocalFx
    if not cfg or not cfg.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not hrp then return end

    local att = Instance.new("Attachment")
    att.Name = "JuruFx"
    att.Parent = hrp
    table.insert(localFxParts, att)

    if cfg.Particles ~= false then
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "JuruParticles"
        pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        pe.Rate = tonumber(cfg.Rate) or 40
        pe.Lifetime = NumberRange.new(0.4, 1.0)
        pe.Speed = NumberRange.new(0.5, 3)
        pe.SpreadAngle = Vector2.new(30, 30)
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 0),
        })
        pe.Color = ColorSequence.new(cfg.Color or Color3.fromRGB(170, 100, 255))
        pe.LightEmission = 0.6
        pe.Parent = att
        table.insert(localFxParts, pe)
    end

    if cfg.Trail then
        local a0 = Instance.new("Attachment")
        a0.Name = "JuruTrail0"
        a0.Position = Vector3.new(0, 1, 0)
        a0.Parent = hrp
        local a1 = Instance.new("Attachment")
        a1.Name = "JuruTrail1"
        a1.Position = Vector3.new(0, -1, 0)
        a1.Parent = hrp
        local trail = Instance.new("Trail")
        trail.Attachment0 = a0
        trail.Attachment1 = a1
        trail.Lifetime = 0.35
        trail.MinLength = 0.1
        trail.Color = ColorSequence.new(cfg.Color or Color3.fromRGB(170, 100, 255))
        trail.Transparency = NumberSequence.new(0.3, 1)
        trail.Parent = hrp
        table.insert(localFxParts, a0)
        table.insert(localFxParts, a1)
        table.insert(localFxParts, trail)
    end

    if cfg.Highlight then
        local hl = Instance.new("Highlight")
        hl.Name = "JuruLocalHL"
        hl.FillColor = cfg.Color or Color3.fromRGB(170, 100, 255)
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.6
        hl.OutlineTransparency = 0.2
        hl.Parent = char
        table.insert(localFxParts, hl)
    end
end

F.jConnect(LocalPlayer.CharacterAdded, function()
    task.wait(0.5)
    if Config.LocalFx and Config.LocalFx.Enabled then
        F.applyLocalFx()
    end
end)

-- ============================================================
-- MILLENIUM UI — Juru
-- https://github.com/i77lhm/Libraries (Millenium/Library.lua)
-- ============================================================
local library
do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Millenium/Library.lua"))()
    end)
    if ok and res then
        library = res
        print("[Juru] Millenium library loaded")
    else
        warn("[Juru] Millenium load failed:", res)
    end
end

if not library then
    warn("[Juru] Menu unavailable — Millenium failed to load")
else
    local placeName = "Game"
    pcall(function()
        placeName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    pcall(function()
        if placeName == "Game" then placeName = game.Name end
    end)

    -- Soft defaults off at UI build (autoload restores after)
    pcall(function()
        if F.forceRuntimeOff then F.forceRuntimeOff() end
        rapidFireActive = false
        if Config.RapidFire then Config.RapidFire.Enabled = false end
        if Config.SilentAim then
            Config.SilentAim.Enabled = false
            Config.SilentAim.UseCameraAimbot = false
            Config.SilentAim.AllowIndexHook = false
        end
        if Config.WallShoot then Config.WallShoot.Enabled = false end
        if Config.Ragebot then Config.Ragebot.Enabled = false end
        if Config.RageBot then Config.RageBot.Enabled = false end
        if Config.Visuals then
            Config.Visuals.Enabled = false
            Config.Visuals.Boxes = false
            Config.Visuals.Names = false
            Config.Visuals.Distance = false
            Config.Visuals.Chams = false
        end
        if Config.TriggerBot then Config.TriggerBot.Enabled = false end
        if Config.FOV then Config.FOV.Enabled = false; Config.FOV.Visible = false end
        if Config.Hitbox then Config.Hitbox.Enabled = false end
        pcall(F.rbStop)
        pcall(F.stopRageBot)
    end)
    pcall(function() F.fixConfigColors(Config) end)

    -- Force dropdown labels to use options.name (library hardcodes "Dropdown")
    do
        local _dropdown = library.dropdown
        function library:dropdown(options)
            options = options or {}
            local label = options.name or options.Name or "Dropdown"
            options.name = label
            local cfg = _dropdown(self, options)
            -- cfg may be the config table with items
            pcall(function()
                if type(cfg) == "table" and cfg.items and cfg.items.name then
                    cfg.items.name.Text = tostring(label)
                end
            end)
            -- also scan newest dropdown name label in this section
            pcall(function()
                local elements = self.items and self.items.elements
                if not elements then return end
                for _, child in ipairs(elements:GetChildren()) do
                    if child:IsA("TextButton") then
                        for _, d in ipairs(child:GetDescendants()) do
                            if d:IsA("TextLabel") and d.Text == "Dropdown" then
                                d.Text = tostring(label)
                            end
                        end
                    end
                end
            end)
            return cfg
        end
    end

    -- Force tab icons from properties.icon (library hardcodes a default otherwise)
    do
        local _tab = library.tab
        function library:tab(properties)
            properties = properties or {}
            local icon = properties.icon or properties.Icon
            local a, b, c, d, e = _tab(self, properties)
            if icon and self.items and self.items.button_holder then
                local buttons = {}
                for _, ch in ipairs(self.items.button_holder:GetChildren()) do
                    if ch:IsA("TextButton") then
                        table.insert(buttons, ch)
                    end
                end
                local last = buttons[#buttons]
                if last then
                    for _, d in ipairs(last:GetDescendants()) do
                        if d:IsA("ImageLabel") then
                            d.Image = icon
                            d.ImageColor3 = Color3.fromRGB(200, 200, 210)
                        end
                    end
                end
            end
            return a, b, c, d, e
        end
    end

    local window = library:window({
        name = "juru",
        suffix = ".lol",
        gameInfo = "juru.lol · " .. tostring(placeName),
        size = UDim2.new(0, 700, 0, 565),
    })
    -- Full purple theme (accent + UI recolor)
    local PURPLE = Color3.fromRGB(170, 100, 255)
    local PURPLE_LIGHT = Color3.fromRGB(200, 150, 255)
    local PURPLE_SOFT = Color3.fromRGB(180, 120, 255)
    local function applyPurpleTheme()
        pcall(function() library:update_theme("accent", PURPLE) end)
        pcall(function()
            if library.themes and library.themes.preset then
                library.themes.preset.accent = PURPLE
            end
        end)
        local parent = (gethui and gethui()) or game:GetService("CoreGui")
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("Frame") or d:IsA("TextButton") or d:IsA("ScrollingFrame") then
                        local c = d.BackgroundColor3
                        if c.B > 0.55 and c.R < 0.75 and c.G > 0.35 and c.G < 0.9 then
                            d.BackgroundColor3 = PURPLE
                        elseif c.R > 0.5 and c.B > 0.5 and c.G < 0.7 and c.R < 0.95 then
                            d.BackgroundColor3 = PURPLE_SOFT
                        end
                    end
                    if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                        local c = d.TextColor3
                        if (c.B > 0.55 and c.R < 0.85 and c.G > 0.3) or (c.R > 0.45 and c.B > 0.55 and c.G < 0.75) then
                            d.TextColor3 = PURPLE_LIGHT
                        end
                    end
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                        local c = d.ImageColor3
                        if (c.B > 0.45 and c.R < 0.9) or (c.R > 0.4 and c.B > 0.4 and c.G < 0.8) then
                            d.ImageColor3 = PURPLE
                        end
                    end
                    if d:IsA("UIStroke") then
                        local c = d.Color
                        if c.B > 0.4 or (c.R > 0.4 and c.B > 0.35) then
                            d.Color = PURPLE_SOFT
                        end
                    end
                end
            end
        end
    end
    task.defer(applyPurpleTheme)
    task.delay(0.35, applyPurpleTheme)
    task.delay(1.2, applyPurpleTheme)

    -- Remove "days left" text, force top branding, set tab icons
    task.defer(function()
        local function fixLabels(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t = tostring(d.Text or "")
                    if t:lower():find("days left") then
                        d.Text = "juru.lol"
                        d.RichText = false
                    end
                    if t:find("32 days") then
                        d.Text = "juru.lol"
                        d.RichText = false
                    end
                end
            end
        end
        local parent = (gethui and gethui()) or game:GetService("CoreGui")
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                fixLabels(gui)
            end
        end
        -- Custom tab icons (ImageLabels next to tab names)
        local iconIds = {
            "rbxassetid://6034767608", -- combat fallback
            "rbxassetid://6034767608",
            "rbxassetid://6034767608",
            "rbxassetid://6034767608",
            "rbxassetid://6034767608",
            "rbxassetid://6034767608",
        }
        -- Prefer distinct public icons
        iconIds = {
            "rbxassetid://10734950309", -- combat/settings gear style
            "rbxassetid://18821914323", -- rage
            "rbxassetid://108952102602834", -- visuals globe
            "rbxassetid://18821914323", -- players
            "rbxassetid://90336395745819", -- misc
            "rbxassetid://18865373378", -- keys
        }
        local idx = 1
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("ImageLabel") and d.Size and d.Size.X.Offset == 22 and d.Size.Y.Offset == 22 then
                        if iconIds[idx] then
                            d.Image = iconIds[idx]
                            d.ImageColor3 = Color3.fromRGB(200, 200, 210)
                            idx = idx + 1
                        end
                    end
                end
            end
        end
    end)
    local function stripDaysLeft()
        local parent = (gethui and gethui()) or game:GetService("CoreGui")
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local t = tostring(d.Text or "")
                        local tl = t:lower()
                        if (tl:find("day") and tl:find("left")) or t:find("32 days") or t:find("days left") then
                            d.RichText = false
                            d.Text = "juru.lol"
                        end
                    end
                end
            end
        end
    end
    task.defer(stripDaysLeft)
    task.delay(0.2, stripDaysLeft)
    task.delay(0.5, stripDaysLeft)
    task.delay(1.5, stripDaysLeft)
    task.spawn(function()
        for _ = 1, 40 do
            task.wait(0.2)
            stripDaysLeft()
        end
    end)

    ------------------------------------------------------------
    -- COMBAT
    ------------------------------------------------------------
    window:seperator({ name = "Combat" })
    -- Aimbot · Aim · Rage (all rage tools live under Rage)
    local aimbotTab, aimTab, rageMain, rageExtra = window:tab({
        name = "Combat",
        icon = "rbxassetid://10709791437",
        tabs = { "Aimbot", "Aim", "Rage", "Orbit" },
    })

    do -- Aimbot = Silent + Camera + Targeting only
        local colL = aimbotTab:column({})
        local colR = aimbotTab:column({})
        local silent = colL:section({ name = "Silent Aim", default = true, size = 0.55 })
        silent:label({
            name = "Silent Aim",
            info = "AimPosition rewrite only. Enable, then press E to lock.",
        })
        silent:toggle({
            name = "Enable Silent Aim",
            default = false,
            seperator = true,
            callback = function(v)
                Config.SilentAim.Enabled = v == true
                if v then
                    pcall(F.tryInstallSilentAim)
                    wallShootHooked = false
                    pcall(F.tryInstallWallShoot)
                end
            end,
        })
        silent:dropdown({
            name = "Silent Hit Part",
            items = { "Head", "Torso", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
            default = Config.SilentAim.HitPart or "Torso",
            multi = false,
            seperator = true,
            callback = function(v) Config.SilentAim.HitPart = tostring(v) end,
        })
        silent:toggle({
            name = "Prediction",
            default = false,
            seperator = true,
            callback = function(v) Config.SilentAim.UsePrediction = v == true end,
        })
        silent:slider({
            name = "Pred Amount",
            min = 0, max = 50, default = math.floor((tonumber(Config.SilentAim.Prediction) or 0.13) * 100),
            seperator = true,
            callback = function(v) Config.SilentAim.Prediction = v / 100 end,
        })
        silent:slider({
            name = "Accuracy",
            min = 1, max = 100, default = tonumber(Config.SilentAim.Accuracy) or 100,
            seperator = true,
            callback = function(v) Config.SilentAim.Accuracy = v end,
        })

        local aimbot = colL:section({ name = "Camera Aimbot", default = true, size = 0.45 })
        aimbot:toggle({
            name = "Enable Aimbot",
            default = false,
            seperator = true,
            callback = function(v)
                Config.SilentAim.UseCameraAimbot = v == true
                if v then
                    Config.SilentAim.AllowIndexHook = false
                    pcall(F.bindCameraAimbot)
                else
                    pcall(F.unbindCameraAimbot)
                end
            end,
        })
        aimbot:slider({
            name = "Smoothness",
            min = 0, max = 100, default = math.floor((tonumber(Config.SilentAim.Smoothness) or 0) * 100),
            seperator = true,
            callback = function(v) Config.SilentAim.Smoothness = v / 100 end,
        })
        aimbot:keybind({
            name = "Lock Key",
            seperator = true,
            callback = function() end,
        })

        local tgt = colR:section({ name = "Targeting", default = true, size = 1 })
        tgt:toggle({
            name = "Sticky Lock",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Settings then Config.Settings = {} end
                Config.Settings.StickyLock = v == true
            end,
        })
        tgt:toggle({
            name = "Soft Lock",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.SoftLock then Config.SoftLock = { Enabled = false, ShowTracer = false } end
                Config.SoftLock.Enabled = v == true
            end,
        })
        tgt:toggle({
            name = "Soft Lock Tracer",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.SoftLock then Config.SoftLock = {} end
                Config.SoftLock.ShowTracer = v == true
            end,
        })
        tgt:toggle({
            name = "Knock Check",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Settings then Config.Settings = {} end
                Config.Settings.KnockCheck = v == true
            end,
        })
        tgt:toggle({
            name = "Visible Check",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Settings then Config.Settings = {} end
                Config.Settings.VisibleCheck = v == true
            end,
        })
        tgt:toggle({
            name = "Auto Retaliate",
            default = false,
            seperator = false,
            callback = function(v)
                if not Config.Settings then Config.Settings = {} end
                Config.Settings.AutoRetaliate = v == true
            end,
        })
    end

    do -- Aim = FOV + Hitbox
        local colL = aimTab:column({})
        local colR = aimTab:column({})
        local fov = colL:section({ name = "FOV", default = true, size = 1 })
        fov:toggle({
            name = "FOV Enabled",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.FOV then Config.FOV = {} end
                Config.FOV.Enabled = v == true
            end,
        })
        fov:toggle({
            name = "Show FOV",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.FOV then Config.FOV = {} end
                Config.FOV.Visible = v == true
            end,
        })
        fov:slider({
            name = "FOV Size",
            min = 10, max = 500, default = (Config.FOV and Config.FOV.Size) or 95,
            seperator = true,
            callback = function(v)
                if not Config.FOV then Config.FOV = {} end
                Config.FOV.Size = v
            end,
        })
        fov:dropdown({
            name = "FOV Shape",
            items = { "Circle", "Square", "Diamond", "Hexagon" },
            default = (Config.FOV and Config.FOV.Shape) or "Circle",
            multi = false,
            seperator = true,
            callback = function(v)
                if not Config.FOV then Config.FOV = {} end
                Config.FOV.Shape = tostring(v)
            end,
        })
        fov:colorpicker({
            name = "FOV Color",
            default = F.toColor3(Config.FOV and Config.FOV.Color, Color3.fromRGB(170, 100, 255)),
            seperator = true,
            callback = function(c)
                c = F.toColor3(c, Color3.fromRGB(170, 100, 255))
                if not Config.FOV then Config.FOV = {} end
                Config.FOV.Color = c
                if fovCircle then fovCircle.Color = c end
            end,
        })

        local hbe = colR:section({ name = "Hitbox Expander", default = true, size = 1 })
        hbe:toggle({
            name = "Hitbox Expand",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Hitbox then Config.Hitbox = { Size = 15, Transparency = 0.9, ShowVisual = false } end
                Config.Hitbox.Enabled = v == true
                if not v then pcall(function() F.restoreAllHitboxes() end) end
            end,
        })
        hbe:slider({
            name = "Hitbox Size",
            min = 3, max = 40, default = (Config.Hitbox and Config.Hitbox.Size) or 15,
            seperator = true,
            callback = function(v)
                if not Config.Hitbox then Config.Hitbox = {} end
                Config.Hitbox.Size = v
            end,
        })
        hbe:toggle({
            name = "Hitbox Visual",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Hitbox then Config.Hitbox = {} end
                Config.Hitbox.ShowVisual = v == true
            end,
        })
        hbe:slider({
            name = "Visual Opacity",
            min = 10, max = 90, default = math.floor((1 - ((Config.Hitbox and Config.Hitbox.Transparency) or 0.35)) * 100),
            seperator = true,
            callback = function(v)
                if not Config.Hitbox then Config.Hitbox = {} end
                -- higher opacity = lower transparency
                Config.Hitbox.Transparency = 1 - (v / 100)
            end,
        })
        hbe:colorpicker({
            name = "Hitbox Color",
            default = F.toColor3(Config.Hitbox and Config.Hitbox.Color, Color3.fromRGB(190, 90, 255)),
            seperator = false,
            callback = function(c)
                if not Config.Hitbox then Config.Hitbox = {} end
                Config.Hitbox.Color = F.toColor3(c, Color3.fromRGB(190, 90, 255))
            end,
        })
    end

    do -- Rage main = Wallbang + Ragebot + Triggerbot
        local colL = rageMain:column({})
        local colR = rageMain:column({})
        local wall = colL:section({ name = "Wall Bang", default = true, size = 0.55 })
        wall:toggle({
            name = "Enable Wall Bang",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.WallShoot then Config.WallShoot = {} end
                Config.WallShoot.Enabled = v == true
                if v then wallShootHooked = false; pcall(F.tryInstallWallShoot) end
            end,
        })
        wall:toggle({
            name = "Smart Range",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.SmartRange then Config.SmartRange = { Margin = 3 } end
                Config.SmartRange.Enabled = v == true
            end,
        })
        wall:slider({
            name = "Range Margin",
            min = 1, max = 40, default = (Config.SmartRange and Config.SmartRange.Margin) or 3,
            seperator = true,
            callback = function(v)
                if not Config.SmartRange then Config.SmartRange = {} end
                Config.SmartRange.Margin = v
            end,
        })
        wall:toggle({
            name = "Spread",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Spread then Config.Spread = {} end
                Config.Spread.Enabled = v == true
            end,
        })
        wall:slider({
            name = "Spread Amount",
            min = 0, max = 100, default = (Config.Spread and Config.Spread.Amount) or 26,
            seperator = false,
            callback = function(v)
                if not Config.Spread then Config.Spread = {} end
                Config.Spread.Amount = v
            end,
        })

        local trig = colL:section({ name = "Triggerbot", default = true, size = 0.45 })
        trig:toggle({
            name = "Enable Triggerbot",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.TriggerBot then Config.TriggerBot = {} end
                Config.TriggerBot.Enabled = v == true
                triggerEnabled = v == true
            end,
        })
        trig:slider({
            name = "Trigger Delay (ms)",
            min = 0, max = 500, default = math.floor(((Config.TriggerBot and Config.TriggerBot.Delay) or 0.05) * 1000),
            seperator = true,
            callback = function(v)
                if not Config.TriggerBot then Config.TriggerBot = {} end
                Config.TriggerBot.Delay = v / 1000
            end,
        })

        local rb = colR:section({ name = "Ragebot", default = true, size = 1 })
        rb:toggle({
            name = "Enable Ragebot",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                if v then
                    Config.Ragebot.Enabled = true
                    pcall(F.rbStart)
                else
                    Config.Ragebot.Enabled = false
                    pcall(F.rbStop)
                end
            end,
        })
        rb:toggle({
            name = "Auto Fire",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.AutoFire = v == true
            end,
        })
        rb:toggle({
            name = "Rage Wall Bang",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.AutoFireWallBang = v == true
            end,
        })
        rb:toggle({
            name = "Auto Equip",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.AutoEquip = v == true
            end,
        })
        rb:dropdown({
            name = "Ragebot Hitbox",
            items = { "head", "root" },
            default = (Config.Ragebot and Config.Ragebot.Hitbox) or "head",
            multi = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.Hitbox = tostring(v)
            end,
        })
        rb:slider({
            name = "Ragebot FOV",
            min = 5, max = 360, default = (Config.Ragebot and tonumber(Config.Ragebot.FOV)) or 180,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.FOV = v
            end,
        })
        rb:toggle({
            name = "Show Rage FOV",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.ShowFOV = v == true
            end,
        })
        rb:slider({
            name = "Fire Cooldown (ms)",
            min = 0, max = 300, default = (Config.Ragebot and tonumber(Config.Ragebot.FireCooldown)) or 5,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.FireCooldown = v
            end,
        })
        rb:toggle({
            name = "Auto Target",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.TargetAuto = v == true
            end,
        })
        rb:toggle({
            name = "Follow Target",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Ragebot then Config.Ragebot = {} end
                Config.Ragebot.FollowTarget = v == true
            end,
        })
        rb:button({
            name = "Clear Rage Target",
            callback = function()
                if F.rbSetTarget then F.rbSetTarget(nil, false) end
                pcall(F.rbStop)
            end,
        })
    end

    do -- Orbit sub-tab (rage movement)
        local colL = rageExtra:column({})
        local colR = rageExtra:column({})
        local orbit = colL:section({ name = "Orbit", default = true, size = 1 })
        orbit:toggle({
            name = "Orbit Rage",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.RageBot then Config.RageBot = {} end
                Config.RageBot.Enabled = v == true
                rageBotEnabled = v == true
                if v then pcall(F.startRageBot) else pcall(F.stopRageBot) end
            end,
        })
        orbit:toggle({
            name = "Teleport Rage",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.RageBot then Config.RageBot = {} end
                Config.RageBot.TeleportRage = v == true
            end,
        })
        orbit:slider({
            name = "Orbit Speed",
            min = 10, max = 300, default = (Config.RageBot and Config.RageBot.OrbitSpeed) or 110,
            seperator = true,
            callback = function(v) if Config.RageBot then Config.RageBot.OrbitSpeed = v end end,
        })
        orbit:slider({
            name = "Orbit Radius",
            min = 1, max = 20, default = (Config.RageBot and Config.RageBot.OrbitRadius) or 3.5,
            interval = 0.1,
            seperator = true,
            callback = function(v) if Config.RageBot then Config.RageBot.OrbitRadius = v end end,
        })
        orbit:toggle({
            name = "Far Rage",
            default = false,
            seperator = true,
            callback = function(v) if Config.RageBot then Config.RageBot.FarRage = v == true end end,
        })
        orbit:slider({
            name = "Far Distance",
            min = 100, max = 5000, default = (Config.RageBot and Config.RageBot.FarDistance) or 2800,
            seperator = true,
            callback = function(v) if Config.RageBot then Config.RageBot.FarDistance = v end end,
        })

        local anti = colR:section({ name = "Anti Rage", default = true, size = 1 })
        anti:toggle({
            name = "Anti Rage",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.AntiRage then Config.AntiRage = {} end
                Config.AntiRage.Enabled = v == true
            end,
        })
        anti:label({
            name = "Info",
            info = "Protects on your respawn and helps re-engage rage targets. Off by default.",
        })
    end

    window:seperator({ name = "Visuals" })
    local visEsp, visFx = window:tab({
        name = "Visuals",
        icon = "rbxassetid://108952102602834",
        tabs = { "ESP", "Effects" },
    })

    do -- ESP
        local colL = visEsp:column({})
        local colR = visEsp:column({})
        local esp = colL:section({ name = "ESP", default = true, size = 1 })
        esp:toggle({ name = "ESP Enabled", default = false, seperator = true, callback = function(v) Config.Visuals.Enabled = v == true end })
        esp:toggle({ name = "Boxes", default = false, seperator = true, callback = function(v) Config.Visuals.Boxes = v == true end })
        esp:toggle({ name = "Names", default = false, seperator = true, callback = function(v) Config.Visuals.Names = v == true end })
        esp:toggle({ name = "Distance", default = false, seperator = true, callback = function(v) Config.Visuals.Distance = v == true end })
        esp:toggle({ name = "Tracers", default = false, seperator = true, callback = function(v) Config.Visuals.Tracers = v == true end })
        esp:toggle({ name = "Skeleton", default = false, seperator = true, callback = function(v) Config.Visuals.Skeleton = v == true end })
        esp:toggle({ name = "Chams", default = false, seperator = true, callback = function(v) Config.Visuals.Chams = v == true end })
        esp:toggle({ name = "Self Chams", default = false, seperator = false, callback = function(v) Config.Visuals.SelfChams = v == true end })

        local cols = colR:section({ name = "Colors", default = true, size = 1 })
        cols:colorpicker({
            name = "ESP Text",
            default = F.toColor3(Config.Visuals.Color, Color3.fromRGB(170, 100, 255)),
            seperator = true,
            callback = function(c) Config.Visuals.Color = F.toColor3(c, Color3.fromRGB(170, 100, 255)) end,
        })
        cols:colorpicker({
            name = "Chams",
            default = F.toColor3(Config.Visuals.ChamsColor, Color3.fromRGB(170, 100, 255)),
            seperator = true,
            callback = function(c) Config.Visuals.ChamsColor = F.toColor3(c, Color3.fromRGB(170, 100, 255)) end,
        })
        cols:colorpicker({
            name = "Outline",
            default = F.toColor3(Config.Visuals.OutlineColor, Color3.fromRGB(255, 255, 255)),
            seperator = true,
            callback = function(c) Config.Visuals.OutlineColor = F.toColor3(c, Color3.fromRGB(255, 255, 255)) end,
        })
        cols:colorpicker({
            name = "Locked Glow",
            default = F.toColor3(Config.Visuals.LockedGlow, Color3.fromRGB(170, 100, 255)),
            seperator = true,
            callback = function(c) Config.Visuals.LockedGlow = F.toColor3(c, Color3.fromRGB(170, 100, 255)) end,
        })
        cols:colorpicker({
            name = "Lock Tracer",
            default = F.toColor3(Config.Visuals.TracerColor, Color3.fromRGB(170, 100, 255)),
            seperator = true,
            callback = function(c)
                c = F.toColor3(c, Color3.fromRGB(170, 100, 255))
                Config.Visuals.TracerColor = c
                if tracerLine then tracerLine.Color = c end
            end,
        })
    end

    do -- Effects
        local colL = visFx:column({})
        local colR = visFx:column({})
        local fx = colL:section({ name = "Effects", default = true, size = 1 })
        fx:toggle({
            name = "Hit Marker",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.HitMarker then Config.HitMarker = {} end
                Config.HitMarker.Enabled = v == true
            end,
        })
        fx:dropdown({
            name = "Hit Marker Mode",
            items = { "2d", "3d", "both" },
            default = "2d",
            multi = false,
            seperator = true,
            callback = function(v)
                if not Config.HitMarker then Config.HitMarker = {} end
                Config.HitMarker.Mode = tostring(v)
            end,
        })
        fx:toggle({
            name = "Local Effects",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.LocalFx then Config.LocalFx = {} end
                Config.LocalFx.Enabled = v == true
                if v then pcall(F.applyLocalFx) else pcall(F.clearLocalFx) end
            end,
        })
        fx:toggle({
            name = "Key Overlay",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.KeyOverlay then Config.KeyOverlay = {} end
                Config.KeyOverlay.Enabled = v == true
            end,
        })
        fx:toggle({
            name = "Hit Sound",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.HitSound then Config.HitSound = {} end
                Config.HitSound.Enabled = v == true
            end,
        })
        fx:dropdown({
            name = "Hit Sound",
            items = { "mc bow", "primordial", "neverlose", "sparkle", "skeet", "break", "rust", "sexy" },
            default = "mc bow",
            multi = false,
            seperator = false,
            callback = function(v) if F.setHitSound then F.setHitSound(tostring(v)) end end,
        })
        local tip = colR:section({ name = "Tip", default = true, size = 1 })
        tip:label({
            name = "Resize",
            info = "Drag the bottom-right corner of the menu to resize if sections feel tight. Scroll inside sections.",
        })
    end

    window:seperator({ name = "Players" })
    local playersList, playersWl = window:tab({
        name = "Players",
        icon = "rbxassetid://18821914323",
        tabs = { "List", "Whitelist" },
    })

    do
        local function buildPlayerList()
            local names = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local label = plr.DisplayName
                    if label ~= plr.Name then
                        label = label .. " (@" .. plr.Name .. ")"
                    end
                    table.insert(names, label)
                end
            end
            table.sort(names)
            if #names == 0 then table.insert(names, "(no players)") end
            return names
        end
        local function resolvePlayerFromLabel(label)
            if not label or label == "(no players)" then return nil end
            local uname = label:match("@([^%)]+)") or label
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Name == uname or plr.DisplayName == label or plr.Name == label then return plr end
                if (plr.DisplayName .. " (@" .. plr.Name .. ")") == label then return plr end
            end
            return Players:FindFirstChild(uname)
        end
        local selectedPlayerLabel = nil
        local playerList = buildPlayerList()

        local colL = playersList:column({})
        local colR = playersList:column({})
        local listSec = colL:section({ name = "Player List", default = true, size = 1 })
        listSec:dropdown({
            name = "Select Player",
            items = playerList,
            default = playerList[1],
            multi = false,
            seperator = true,
            callback = function(v) selectedPlayerLabel = tostring(v) end,
        })
        listSec:button({
            name = "Refresh List",
            callback = function()
                print("[Juru] Players:", table.concat(buildPlayerList(), ", "))
            end,
        })
        listSec:button({
            name = "Lock Target",
            callback = function()
                local plr = resolvePlayerFromLabel(selectedPlayerLabel)
                if plr and F.forceLockOnPlayer then F.forceLockOnPlayer(plr) end
            end,
        })
        listSec:button({
            name = "Unlock",
            callback = function()
                if F.clearTargetLock then F.clearTargetLock() end
                isLocking = false
                currentTarget = nil
            end,
        })
        listSec:button({
            name = "Spectate",
            callback = function()
                local plr = resolvePlayerFromLabel(selectedPlayerLabel)
                if not plr then return end
                if F.forceManualSpectate then
                    pcall(F.forceManualSpectate, plr)
                else
                    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum then Workspace.CurrentCamera.CameraSubject = hum end
                end
            end,
        })
        listSec:button({
            name = "Stop Spectate",
            callback = function()
                if F.stopManualSpectate then pcall(F.stopManualSpectate) end
            end,
        })

        local rageAct = colR:section({ name = "Rage Actions", default = true, size = 1 })
        rageAct:button({
            name = "Set Ragebot Target",
            callback = function()
                local plr = resolvePlayerFromLabel(selectedPlayerLabel)
                if plr and F.rbSetTarget then F.rbSetTarget(plr, false) end
            end,
        })
        rageAct:button({
            name = "Orbit This Player",
            callback = function()
                local plr = resolvePlayerFromLabel(selectedPlayerLabel)
                if not plr then return end
                rageTargetPlayer = plr
                rageBotEnabled = true
                if Config.RageBot then Config.RageBot.Enabled = true end
                if F.forceLockOnPlayer then F.forceLockOnPlayer(plr) end
                if F.startRageBot then pcall(F.startRageBot) end
            end,
        })
        rageAct:button({
            name = "Clear Rage Target",
            callback = function()
                if F.rbSetTarget then F.rbSetTarget(nil, false) end
                pcall(F.rbStop)
                pcall(F.stopRageBot)
                rageTargetPlayer = nil
                rageBotEnabled = false
            end,
        })
    end

    do
        local col = playersWl:column({})
        local wl = col:section({ name = "Whitelist", default = true, size = 1 })
        wl:toggle({
            name = "Whitelist Enabled",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Whitelist then Config.Whitelist = { Players = {} } end
                Config.Whitelist.Enabled = v == true
            end,
        })
        wl:button({
            name = "Add Locked / Current Target",
            callback = function()
                local plr = nil
                if currentTarget and currentTarget.Parent then
                    plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
                end
                if plr and F.whitelistAddPlayer then F.whitelistAddPlayer(plr) end
            end,
        })
        wl:button({
            name = "Remove Locked Target",
            callback = function()
                local plr = nil
                if currentTarget and currentTarget.Parent then
                    plr = Players:GetPlayerFromCharacter(currentTarget.Parent)
                end
                if plr and F.whitelistRemovePlayer then F.whitelistRemovePlayer(plr) end
            end,
        })
        wl:button({
            name = "Clear Whitelist",
            callback = function()
                if F.whitelistClear then F.whitelistClear() end
            end,
        })
        wl:label({
            name = "Tip",
            info = "Select a player on the List tab, then use Lock / Rage actions. Whitelist ignores aim & rage on listed users.",
        })
    end

    ------------------------------------------------------------
    -- MISC: Movement · Utility · Keys
    ------------------------------------------------------------
    window:seperator({ name = "Misc" })
    local moveTab, utilTab, keysTab = window:tab({
        name = "Misc",
        icon = "rbxassetid://90336395745819",
        tabs = { "Movement", "Utility", "Keys" },
    })

    do -- Movement
        local colL = moveTab:column({})
        local colR = moveTab:column({})
        local move = colL:section({ name = "Movement", default = true, size = 1 })
        move:toggle({
            name = "Walk Speed (allow)",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Speed then Config.Speed = { WalkSpeed = 640 } end
                Config.Speed.Enabled = v == true
                if not v then SpeedEnabled = false end
            end,
        })
        move:slider({
            name = "Speed Value",
            min = 16, max = 1000, default = (Config.Speed and Config.Speed.WalkSpeed) or 640,
            seperator = true,
            callback = function(v)
                if not Config.Speed then Config.Speed = {} end
                Config.Speed.WalkSpeed = v
            end,
        })
        move:toggle({
            name = "CFrame Speed (allow)",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.CFrameSpeed then Config.CFrameSpeed = {} end
                Config.CFrameSpeed.Enabled = v == true
                if not v then cFrameSpeedEnabled = false end
            end,
        })
        move:slider({
            name = "CFrame Amount",
            min = 1, max = 50, default = math.floor(((Config.CFrameSpeed and Config.CFrameSpeed.Speed) or 0.9) * 10),
            seperator = true,
            callback = function(v)
                if not Config.CFrameSpeed then Config.CFrameSpeed = {} end
                Config.CFrameSpeed.Speed = v / 10
            end,
        })
        move:toggle({
            name = "Super Jump (allow)",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.SuperJump then Config.SuperJump = {} end
                Config.SuperJump.Enabled = v == true
                if not v then superJumpActive = false end
            end,
        })
        move:slider({
            name = "Jump Power",
            min = 50, max = 500, default = (Config.SuperJump and Config.SuperJump.Power) or 260,
            seperator = true,
            callback = function(v)
                if not Config.SuperJump then Config.SuperJump = {} end
                Config.SuperJump.Power = v
            end,
        })
        local fly = colR:section({ name = "Fly", default = true, size = 1 })
        fly:toggle({
            name = "Fly (allow)",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Fly then Config.Fly = {} end
                Config.Fly.Enabled = v == true
                if not v then flyEnabled = false end
            end,
        })
        fly:slider({
            name = "Fly Speed",
            min = 10, max = 200, default = (Config.Fly and Config.Fly.Speed) or 50,
            seperator = false,
            callback = function(v)
                if not Config.Fly then Config.Fly = {} end
                Config.Fly.Speed = v
            end,
        })
    end

    do -- Utility
        local colL = utilTab:column({})
        local colR = utilTab:column({})
        local combat = colL:section({ name = "Combat Utils", default = true, size = 1 })
        combat:toggle({
            name = "Rapid Fire",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.RapidFire then Config.RapidFire = {} end
                Config.RapidFire.Enabled = v == true
                if not v then rapidFireActive = false end
            end,
        })
        combat:slider({
            name = "RF Delay (ms)",
            min = 30, max = 200, default = math.floor(((Config.RapidFire and Config.RapidFire.Delay) or 0.05) * 1000),
            seperator = true,
            callback = function(v)
                if not Config.RapidFire then Config.RapidFire = {} end
                Config.RapidFire.Delay = v / 1000
            end,
        })
        combat:toggle({
            name = "Multi Equip",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.MultiEquip then Config.MultiEquip = {} end
                Config.MultiEquip.Enabled = v == true
            end,
        })
        combat:button({
            name = "Equip All Guns",
            callback = function() if F.equipAllGuns then F.equipAllGuns() end end,
        })
        combat:toggle({
            name = "Auto Reload",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.AutoReload then Config.AutoReload = {} end
                Config.AutoReload.Enabled = v == true
            end,
        })
        combat:toggle({
            name = "Auto Buy Armor",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.AutoBuyArmor then Config.AutoBuyArmor = {} end
                Config.AutoBuyArmor.Enabled = v == true
            end,
        })
        combat:button({
            name = "Clear Target Lock",
            callback = function()
                if F.clearTargetLock then F.clearTargetLock() end
                isLocking = false
                currentTarget = nil
            end,
        })

        local protect = colR:section({ name = "Protection / Misc", default = true, size = 1 })
        protect:toggle({
            name = "Anti Mod",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.AntiMod then Config.AntiMod = {} end
                Config.AntiMod.Enabled = v == true
            end,
        })
        protect:toggle({
            name = "Anti Mod Auto Leave",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.AntiMod then Config.AntiMod = {} end
                Config.AntiMod.AutoLeave = v == true
            end,
        })
        protect:toggle({
            name = "Void Hide",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.VoidHide then Config.VoidHide = {} end
                Config.VoidHide.Enabled = v == true
                if v then pcall(F.startVoidHide) else pcall(F.stopVoidHide) end
            end,
        })
        protect:toggle({
            name = "Chat Macro",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.ChatMacro then Config.ChatMacro = { Message = "/getjuru", Key = "F6" } end
                Config.ChatMacro.Enabled = v == true
            end,
        })
        protect:toggle({
            name = "Death Notify",
            default = false,
            seperator = true,
            callback = function(v)
                if not Config.Settings then Config.Settings = {} end
                Config.Settings.DeathNotify = v == true
            end,
        })
        protect:button({
            name = "Unload Juru",
            callback = function()
                if shared.JuruUnload then pcall(shared.JuruUnload) end
            end,
        })
    end

    do -- Keys
        local col = keysTab:column({})
        local keys = col:section({ name = "Keybinds", default = true, size = 1 })
        keys:keybind({ name = "Speed Key", seperator = true, callback = function() end })
        keys:keybind({ name = "CFrame Key", seperator = true, callback = function() end })
        keys:keybind({ name = "Jump Key", seperator = true, callback = function() end })
        keys:keybind({ name = "Fly Key", seperator = true, callback = function() end })
        keys:keybind({ name = "Rapid Fire Key", seperator = true, callback = function() end })
        keys:keybind({ name = "Orbit Key", seperator = false, callback = function() end })
    end

    -- Single config UI (Millenium Settings) + Autoload + Juru feature snapshot
    pcall(function()
        window:seperator({ name = "Settings" })
        local main = window:tab({ name = "Configs", icon = "rbxassetid://10734950309", tabs = { "Main" } })
        local column = main:column({})
        local section = column:section({ name = "Configs", size = 1, default = true })
        local config_holder = section:list({
            options = { "default" },
            callback = function(option) end,
            flag = "config_name_list",
        })
        pcall(function() library:update_config_list() end)

        local column2 = main:column({})
        local settings = column2:section({ name = "Settings", size = 1, default = true })
        settings:textbox({ name = "Config name:", flag = "config_name_text" })
        settings:button({
            name = "Save",
            callback = function()
                local flags = library.flags or {}
                local n = flags["config_name_text"]
                if type(n) ~= "string" or not n:match("%S") then
                    n = flags["config_name_list"] or currentConfigName or "default"
                end
                n = tostring(n):gsub("^%s+", ""):gsub("%s+$", "")
                if n == "" then n = "default" end
                local okUi, errUi = pcall(function()
                    if typeof(makefolder) == "function" then
                        pcall(makefolder, library.directory)
                        pcall(makefolder, library.directory .. "/configs")
                    end
                    if typeof(writefile) ~= "function" then error("no writefile") end
                    local payload = library:get_config()
                    writefile(library.directory .. "/configs/" .. n .. ".cfg", payload)
                    pcall(function() library:update_config_list() end)
                end)
                local okJ = false
                pcall(function()
                    if F.saveConfig then okJ = F.saveConfig(n) end
                end)
                print("[Juru] Save", n, "ui=", okUi, "features=", okJ, errUi)
                pcall(function()
                    if F.pushNotification then
                        F.pushNotification(okUi or okJ and ("saved " .. n) or "save failed", true)
                    end
                end)
            end,
        })
        settings:button({
            name = "Load",
            callback = function()
                local flags = library.flags or {}
                local n = flags["config_name_list"] or flags["config_name_text"] or currentConfigName or "default"
                n = tostring(n)
                local okUi = pcall(function()
                    local path = library.directory .. "/configs/" .. n .. ".cfg"
                    if typeof(isfile) == "function" and isfile(path) then
                        library:load_config(readfile(path))
                    end
                    pcall(function() library:update_config_list() end)
                end)
                local okJ = false
                pcall(function()
                    if F.loadConfig then okJ = F.loadConfig(n) end
                end)
                print("[Juru] Load", n, "ui=", okUi, "features=", okJ)
            end,
        })
        settings:button({
            name = "Delete",
            callback = function()
                local flags = library.flags or {}
                local n = flags["config_name_list"] or "default"
                n = tostring(n)
                pcall(function()
                    delfile(library.directory .. "/configs/" .. n .. ".cfg")
                    library:update_config_list()
                end)
                pcall(function() if F.deleteConfig then F.deleteConfig(n) end end)
            end,
        })
        settings:button({
            name = "Set Autoload",
            callback = function()
                local flags = library.flags or {}
                local n = flags["config_name_list"] or flags["config_name_text"] or "default"
                n = tostring(n)
                pcall(function() if F.setAutoloadConfig then F.setAutoloadConfig(n) end end)
                pcall(function()
                    if writefile then
                        writefile(library.directory .. "/autoload.txt", n)
                    end
                end)
                print("[Juru] Autoload set:", n)
            end,
        })
        settings:button({
            name = "Clear Autoload",
            callback = function()
                pcall(function()
                    if writefile then writefile((F and F.configPath and "JuruConfigs/_autoload.txt") or "JuruConfigs/_autoload.txt", "") end
                end)
                pcall(function()
                    if writefile then writefile(library.directory .. "/autoload.txt", "") end
                end)
                print("[Juru] Autoload cleared")
            end,
        })
        settings:colorpicker({
            name = "Menu Accent",
            color = Color3.fromRGB(170, 100, 255),
            callback = function(color, alpha)
                pcall(function() library:update_theme("accent", color) end)
            end,
        })
        settings:keybind({
            name = "Menu Bind",
            callback = function(bool)
                pcall(function() window.toggle_menu(bool) end)
            end,
            default = true,
        })
    end)

    -- ALWAYS force every feature OFF on first menu load (toggles stay off, nothing runs)
    pcall(function() if F.forceRuntimeOff then F.forceRuntimeOff() end end)
    pcall(function()
        -- belt-and-suspenders: every flag off
        for _, key in ipairs({
            "SilentAim","WallShoot","SoftLock","Ragebot","RageBot","TriggerBot","Hitbox",
            "Visuals","FOV","HitMarker","LocalFx","KeyOverlay","HitSound","AutoReload",
            "SmartRange","Spread","AntiRage","AntiMod","VoidHide","ChatMacro","AutoBuyArmor",
            "InfiniteRange","BulletTracers","RapidFire","Speed","CFrameSpeed","Fly","SuperJump",
            "MultiEquip","Settings"
        }) do
            local t = Config[key]
            if type(t) == "table" then
                for k, v in pairs(t) do
                    if type(v) == "boolean" then t[k] = false end
                end
            end
        end
        isLocking = false
        currentTarget = nil
        rageBotEnabled = false
        rageTargetPlayer = nil
        triggerEnabled = false
        rapidFireActive = false
        SpeedEnabled = false
        cFrameSpeedEnabled = false
        superJumpActive = false
        flyEnabled = false
        if F.refreshESP then F.refreshESP() end
        if tracerLine then tracerLine.Visible = false end
        if F.hideAllFOVDraw then F.hideAllFOVDraw() end
        if wallShootRestore then pcall(wallShootRestore) end
        wallShootHooked = false
    end)

    -- Autoload Millenium UI theme only — NEVER auto-enable Juru combat/visual features
    pcall(function()
        local name = nil
        pcall(function()
            local p = library.directory .. "/autoload.txt"
            if isfile and isfile(p) then
                local raw = readfile(p)
                if type(raw) == "string" and raw:match("%S") then
                    name = raw:match("^%s*(.-)%s*$")
                end
            end
        end)
        if name and name ~= "" then
            local path = library.directory .. "/configs/" .. name .. ".cfg"
            pcall(function()
                if isfile and isfile(path) then
                    library:load_config(readfile(path))
                end
            end)
            -- do NOT F.loadConfig here — that was turning silent/esp/wall on while toggles looked off
            print("[Juru] UI autoload only:", name, "(features stay OFF until you toggle)")
        end
    end)

    -- final hard off after any UI load
    pcall(function() if F.forceRuntimeOff then F.forceRuntimeOff() end end)
    pcall(function() library:update_theme("accent", Color3.fromRGB(170, 100, 255)) end)
    pcall(function()
        if library.themes and library.themes.preset then
            library.themes.preset.accent = Color3.fromRGB(170, 100, 255)
        end
    end)
    -- re-apply purple after all tabs built
    task.defer(function()
        pcall(function() library:update_theme("accent", Color3.fromRGB(170, 100, 255)) end)
    end)
    task.delay(0.5, function()
        pcall(function() library:update_theme("accent", Color3.fromRGB(170, 100, 255)) end)
    end)

    -- Replace any leftover hardcoded "Dropdown" labels
    task.defer(function()
        local parent = (gethui and gethui()) or game:GetService("CoreGui")
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text == "Dropdown" then
                        -- leave if we couldn't map; wrapper should have fixed most
                    end
                end
            end
        end
    end)

    print("[Juru] Millenium menu ready · juru.lol · purple theme · all features OFF")
end -- Millenium loaded



shared.JuruUnload = function()
    print("[Juru] Unloading...")
    JuruAlive = false

    isLocking = false
    currentTarget = nil
    triggerEnabled = false
    SpeedEnabled = false
    superJumpActive = false
    cFrameSpeedEnabled = false
    rageBotEnabled = false
    rageTargetPlayer = nil
    rapidFireActive = false
    pcall(function() if Config.RapidFire then Config.RapidFire.Enabled = false end end)
    pcall(F.restoreAllHitboxes)
    pcall(F.rfResetPatches)
    pcall(function() if hbeRestore then hbeRestore() end end)
    pcall(function() if wallShootRestore then wallShootRestore() end end)
    pcall(F.stopVoidHide)
    pcall(F.saveWhitelist)
    pcall(F.rbStop)
    pcall(F.stopRageBot)
    pcall(F.unbindCameraAimbot)

    pcall(function()
        local cam = Workspace.CurrentCamera
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and cam then
            hum.WalkSpeed = BaseSpeed
            cam.CameraSubject = hum
            cam.CameraType = Enum.CameraType.Custom
        end
    end)

    for _, c in ipairs(JuruConns) do
        pcall(function() if c and c.Disconnect then c:Disconnect() end end)
    end
    pcall(function() table.clear(JuruConns) end)

    for _, d in ipairs(JuruDrawings) do
        pcall(function()
            if d then
                d.Visible = false
                if d.Remove then d:Remove() end
            end
        end)
    end
    pcall(function() table.clear(JuruDrawings) end)

    for userId, light in pairs(lockedLights or {}) do
        pcall(function() if light then light:Destroy() end end)
        lockedLights[userId] = nil
    end
    pcall(function() if F.clearSelfChamSpheres then F.clearSelfChamSpheres() end end)
    pcall(function() if selfHighlight then selfHighlight:Destroy() end end)
    selfHighlight = nil

    if silentRestore then pcall(silentRestore) end
    pcall(function() UserInputService.MouseIconEnabled = true end)

    -- Destroy CompKiller / Juru GUIs
    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, g in ipairs(cg:GetChildren()) do
            local n = g.Name:lower()
            if n:find("juru") or n:find("comp") then
                pcall(function() g:Destroy() end)
            end
        end
    end)

    shared.JuruUnload = nil
    print("[Juru] Unloaded")
end

pcall(function() if F.forceRuntimeOff then F.forceRuntimeOff() end end)
print("[Juru] Loaded · all features OFF · open menu to enable")

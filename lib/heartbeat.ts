export function buildBootstrap(nonce: string): string {
  return `-- juru.lol loader (auto-generated, do not edit)
local __juru_nonce = "${nonce}"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local function __juru_request()
    return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
end

local function __juru_identify_executor()
    local name, version = "Unknown", ""
    pcall(function()
        if identifyexecutor then
            local n, v = identifyexecutor()
            name = n or name
            version = v or version
        elseif syn then
            name = "Synapse X"
        elseif KRNL_LOADED then
            name = "Krnl"
        elseif Fluxus then
            name = "Fluxus"
        elseif is_sirhurt_closure then
            name = "SirHurt"
        elseif Comet then
            name = "Comet"
        elseif OXYGEN_U then
            name = "Oxygen U"
        end
    end)
    return name, version
end

local function __juru_hwid()
    local ok, id = pcall(function()
        if gethwid then return gethwid() end
        if syn and syn.get_hwid then return syn.get_hwid() end
        if get_hwid then return get_hwid() end
        local rbxId = game:GetService("RbxAnalyticsService"):GetClientId()
        if rbxId and rbxId ~= "" then return rbxId end
        return nil
    end)
    if ok and id then return tostring(id) end
    return "unknown-hwid"
end

local function __juru_alert(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "juru.lol",
            Text = msg,
            Duration = 6,
        })
    end)
end

local __juru_exec_name, __juru_exec_version = __juru_identify_executor()
local __juru_key = (getgenv and getgenv().SCRIPT_KEY) or SCRIPT_KEY or ""
local __juru_running = true

-- Returns true if the server has requested a kick for this player.
local function __juru_ping()
    local kicked = false
    pcall(function()
        local req = __juru_request()
        if not req then return end
        local LocalPlayer = Players.LocalPlayer
        local res = req({
            Url = "https://juru.lol/api/ping",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/WinInet",
            },
            Body = HttpService:JSONEncode({
                placeId = game.PlaceId,
                jobId = game.JobId,
                playerCount = #Players:GetPlayers(),
                userId = LocalPlayer and LocalPlayer.UserId or 0,
                playerName = LocalPlayer and LocalPlayer.Name or "unknown",
                displayName = LocalPlayer and LocalPlayer.DisplayName or "unknown",
                executor = __juru_exec_name,
                executorVersion = __juru_exec_version,
                key = __juru_key,
            }),
        })
        if res and res.Body then
            local ok, decoded = pcall(function()
                return HttpService:JSONDecode(res.Body)
            end)
            if ok and decoded and decoded.kick then
                kicked = true
            end
        end
    end)
    return kicked
end

-- Fire the first ping immediately, then loop every 45s.
-- If the server sets kick=true we stop the loop and kick the player.
local function __juru_do_kick()
    __juru_running = false
    pcall(function()
        local LocalPlayer = Players.LocalPlayer
        if LocalPlayer then
            LocalPlayer:Kick("You have been removed by the script owner.")
        end
    end)
end

if __juru_ping() then
    __juru_do_kick()
    return
end

task.spawn(function()
    while __juru_running and task.wait(45) do
        if __juru_ping() then
            __juru_do_kick()
            break
        end
    end
end)

-- Key check + fetch the real script.
local __juru_req = __juru_request()
if not __juru_req then
    __juru_alert("Your executor doesn't support HTTP requests.")
    return
end

local __juru_local_player = Players.LocalPlayer

local __juru_ok, __juru_res = pcall(__juru_req, {
    Url = "https://juru.lol/api/unlock",
    Method = "POST",
    Headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "Roblox/WinInet",
    },
    Body = HttpService:JSONEncode({
        key = __juru_key,
        hwid = __juru_hwid(),
        nonce = __juru_nonce,
        placeId = game.PlaceId,
        jobId = game.JobId,
        userId = __juru_local_player and __juru_local_player.UserId or 0,
        playerName = __juru_local_player and __juru_local_player.Name or "unknown",
        displayName = __juru_local_player and __juru_local_player.DisplayName or "unknown",
        executor = __juru_exec_name,
        executorVersion = __juru_exec_version,
    }),
})

if not __juru_ok or not __juru_res or not __juru_res.Body then
    __juru_alert("Couldn't reach juru.lol. Try again shortly.")
    return
end

local __juru_decode_ok, __juru_decoded = pcall(function()
    return HttpService:JSONDecode(__juru_res.Body)
end)

if not __juru_decode_ok or not __juru_decoded then
    __juru_alert("juru.lol returned something unexpected.")
    return
end

if not __juru_decoded.valid then
    __juru_alert(__juru_decoded.reason or "Invalid key.")
    return
end

local __juru_run_ok, __juru_run_err = pcall(function()
    local __juru_fn = loadstring(__juru_decoded.script)
    __juru_decoded.script = nil
    __juru_decoded = nil
    if newcclosure then
        __juru_fn = newcclosure(__juru_fn)
    end
    __juru_fn()
end)

if not __juru_run_ok then
    __juru_alert("Script failed to run.")
end`;
}

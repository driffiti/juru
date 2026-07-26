// The heartbeat is baked directly into every response from
// /script/loader/juru.lua — nothing needs to be pasted into the script
// content in /admin. It reports place id / job id / player count / who's
// running it to /api/ping every 45s so the dashboard can show live
// servers, the players in them, and join links.

export const HEARTBEAT_LUA = `-- juru.lol heartbeat (auto-injected, do not remove)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local function __juru_ping()
    pcall(function()
        local req = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
        if not req then return end

        local LocalPlayer = Players.LocalPlayer

        req({
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
            }),
        })
    end)
end

__juru_ping()
task.spawn(function()
    while task.wait(45) do
        __juru_ping()
    end
end)`;

export function buildServedScript(customScript: string): string {
  return `${HEARTBEAT_LUA}\n\n-- ==== your script ====\n${customScript}`;
}

// The heartbeat is now baked directly into every response from
// /script/loader/juru.lua — nothing needs to be pasted into the script
// content in /admin anymore. It reports place id / job id / player count
// to /api/ping every 45s so the dashboard can show live servers + join links.

export const HEARTBEAT_LUA = `-- juru.lol heartbeat (auto-injected, do not remove)
local function __juru_ping()
    local ok, req = pcall(function()
        return (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
    end)
    if not ok or not req then return end
    pcall(req, {
        Url = "https://juru.lol/api/ping",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = game:GetService("HttpService"):JSONEncode({
            placeId = game.PlaceId,
            jobId = game.JobId,
            playerCount = #game:GetService("Players"):GetPlayers(),
        }),
    })
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

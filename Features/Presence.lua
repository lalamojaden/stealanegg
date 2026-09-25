--================================================--
-- JADEN | VPS PRESENCE
--================================================--

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

local API_BASE = "https://api.cruzzcomunity.com"

local REGISTER_URL =
    API_BASE .. "/api/lab/register"

local HEARTBEAT_URL =
    API_BASE .. "/api/lab/heartbeat"

local LAB_KEY = "0c6d9b03b0d061727bb557447256544f3de0b84503d03227791209d9a937306e"

local httpRequest =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request

local function GetExecutor()
    local executor = "Unknown"

    pcall(function()
        if identifyexecutor then
            executor = identifyexecutor()
        elseif getexecutorname then
            executor = getexecutorname()
        elseif getexecutor then
            executor = getexecutor()
        end
    end)

    return tostring(executor)
end

local function Register()
    if not httpRequest or not Player then
        return false
    end

    local okEncode, body = pcall(function()
        return HttpService:JSONEncode({
            userId = tostring(Player.UserId),

            username = Player.Name,
            name = Player.Name,

            displayName = Player.DisplayName,

            placeId = tostring(game.PlaceId),
            jobId = game.JobId,

            executor = GetExecutor(),

            clientVersion = "JADEN-1.0"
        })
    end)

    if not okEncode then
        return false
    end

    local ok, response = pcall(function()
        return httpRequest({
            Url = REGISTER_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["x-lab-key"] = LAB_KEY,
            },
            Body = body
        })
    end)

    if not ok or not response then
        return false
    end

    local status =
        tonumber(response.StatusCode or response.Status) or 0

    return status >= 200 and status < 300
end

local function Heartbeat()
    if not httpRequest or not Player then
        return false
    end

    local okEncode, body = pcall(function()
        return HttpService:JSONEncode({
            userId = tostring(Player.UserId),
            placeId = tostring(game.PlaceId),
            jobId = game.JobId,
        })
    end)

    if not okEncode then
        return false
    end

    local ok, response = pcall(function()
        return httpRequest({
            Url = HEARTBEAT_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["x-lab-key"] = LAB_KEY,
            },
            Body = body
        })
    end)

    if not ok or not response then
        return false
    end

    local status =
        tonumber(response.StatusCode or response.Status) or 0

    return status >= 200 and status < 300
end

_G.JADEN_Presence = {
    Register = Register,
    Heartbeat = Heartbeat
}

task.spawn(function()
    -- Register once
    Register()

    while true do
        task.wait(18)
        Heartbeat()
    end
end)

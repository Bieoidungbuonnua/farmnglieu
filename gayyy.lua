-- ╔══════════════════════════════════════════════╗
-- ║         MTRCHILL - KEY SYSTEM v1.0          ║
-- ╚══════════════════════════════════════════════╝

-- ── CONFIG ───────────────────────────────────────────
script_key = script_key or "";

local API_URL    = "https://mtrchill.top/api/verify_key.php"
local API_SECRET = "A7xQ9mL2vR8kT1zW5pN3cY6uH4eJ0bFs"
-- ─────────────────────────────────────────────────────

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local player      = Players.LocalPlayer

-- ── Logger ───────────────────────────────────────────
local function log(msg)
    print("[mtrchill] " .. msg)
end

-- ── HWID ─────────────────────────────────────────────
local function get_hwid()
    -- Lấy executor HWID nếu có (hỗ trợ Synapse X, KRNL, Fluxus...)
    local ok, hwid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and hwid and hwid ~= "" then
        return tostring(hwid)
    end
    return tostring(player.UserId)
end

-- ── Verify Key qua API ───────────────────────────────
local function verify_key(key)
    log("check key")

    if key == nil or key == "" then
        log("ERROR - key is empty, fill in script_key")
        return false
    end

    local body = HttpService:JSONEncode({
        key_code = key,
        hwid     = get_hwid(),
        action   = "open",
    })

    local ok, response = pcall(function()
        if syn and syn.request then
            return syn.request({
                Url     = API_URL,
                Method  = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-API-Secret"] = API_SECRET,
                },
                Body    = body,
            })
        elseif http and http.request then
            return http.request({
                Url     = API_URL,
                Method  = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-API-Secret"] = API_SECRET,
                },
                Body    = body,
            })
        elseif request then
            return request({
                Url     = API_URL,
                Method  = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-API-Secret"] = API_SECRET,
                },
                Body    = body,
            })
        else
            error("No HTTP executor function found")
        end
    end)

    if not ok then
        log("ERROR - cannot reach API: " .. tostring(response))
        return false
    end

    -- Parse response body
    local data
    local parse_ok = pcall(function()
        local raw = type(response) == "table" and response.Body or tostring(response)
        data = HttpService:JSONDecode(raw)
    end)

    if not parse_ok or not data then
        log("ERROR - invalid API response")
        return false
    end

    if data.success then
        log("key valid")
        return true, data
    else
        log("INVALID - " .. (data.message or "unknown error"))
        return false
    end
end

-- ── Check tab ────────────────────────────────────────
local function check_tab(data)
    log("check tab execute")

    if data then
        local used  = tostring(data.tab_used  or "?")
        local limit = tostring(data.tab_limit or "?")
        log("valid (" .. used .. "/" .. limit .. " tabs)")
    else
        log("valid")
    end

    return true
end

-- ── Main ─────────────────────────────────────────────
local function main()
    local valid, data = verify_key(script_key)

    if not valid then
        log("key verification failed - script stopped")
        log("get key at discord: discord.gg/yourserver")
        return
    end

    local tab_ok = check_tab(data)

    if not tab_ok then
        log("tab check failed - script stopped")
        return
    end

    log("done verify keys - execute script")

    -- ════════════════════════════════════════════════
    --   PASTE YOUR MAIN SCRIPT BELOW THIS LINE
    -- ════════════════════════════════════════════════
-- 🌊 Auto Join Marine Team in Blox Fruits
repeat wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- Hàm để join team Marine
local function joinMarine()
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local chooseTeam = remotes:WaitForChild("CommF_")
    -- "Pirates" là tên team cần join
    chooseTeam:InvokeServer("SetTeam", "Pirates")
    chooseTeam:InvokeServer("SetTeam", "Pirates") -- Gọi 2 lần để chắc chắn join thành công
end

-- Gọi hàm join khi player spawn
player.CharacterAdded:Connect(function()
    task.delay(1, joinMarine)
end)

-- Nếu player chưa có character (mới vào game)
if player.Character then
    task.delay(1, joinMarine)
end

print("[✅] Auto join team Marine đã kích hoạt!") 
    -- ════════════════════════════════════════════════
end

main()

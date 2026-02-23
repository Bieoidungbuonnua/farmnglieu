-- ── CONFIG ───────────────────────────────────────────
script_key    = script_key or "";
local API_URL    = "https://mtrchill.top/api/verify_key.php"
local API_SECRET = "A7xQ9mL2vR8kT1zW5pN3cY6uH4eJ0bFs"
local DISCORD    = "discord.gg/myserver"  -- << ĐỔI LINK SERVER
local HEARTBEAT_INTERVAL = 30             -- giây gửi heartbeat 1 lần
local TAB_TIMEOUT        = 60             -- giây không heartbeat = xóa tab
-- ─────────────────────────────────────────────────────

local HttpService   = game:GetService("HttpService")
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local player        = Players.LocalPlayer

-- ── Logger ───────────────────────────────────────────
local function log(msg)
    print("[mtrchill] " .. msg)
end

-- ── Kick ─────────────────────────────────────────────
local function kick(msg)
    player:Kick("\n" .. msg)
end

-- ── HWID (tự chọn cái tốt nhất) ──────────────────────
local function get_hwid()
    -- Ưu tiên 1: syn.fingerprint (Synapse X - hardware level)
    if syn and syn.fingerprint then
        local ok, v = pcall(syn.fingerprint)
        if ok and v and v ~= "" then return "SYN-" .. tostring(v) end
    end

    -- Ưu tiên 2: KRNL/Fluxus identifyexecutor + ClientId
    local executor = "UNK"
    if identifyexecutor then
        local ok, v = pcall(identifyexecutor)
        if ok and v then executor = tostring(v):sub(1,3):upper() end
    end

    -- Ưu tiên 3: RbxAnalyticsService ClientId (per-device, stable)
    local ok, clientId = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and clientId and clientId ~= "" then
        return executor .. "-" .. tostring(clientId)
    end

    -- Fallback: UserId (per-account, không lý tưởng nhưng vẫn dùng được)
    return "USR-" .. tostring(player.UserId)
end

-- ── HTTP Request wrapper ──────────────────────────────
local function http_request(url, method, headers, body)
    local ok, response = pcall(function()
        if syn and syn.request then
            return syn.request({ Url=url, Method=method, Headers=headers, Body=body })
        elseif http and http.request then
            return http.request({ Url=url, Method=method, Headers=headers, Body=body })
        elseif request then
            return request({ Url=url, Method=method, Headers=headers, Body=body })
        else
            error("No HTTP function found")
        end
    end)
    if not ok then return nil, tostring(response) end
    return response, nil
end

-- ── Gọi API ───────────────────────────────────────────
local function call_api(action, key_code, hwid)
    local body = HttpService:JSONEncode({
        key_code = key_code,
        hwid     = hwid,
        action   = action,
    })
    local headers = {
        ["Content-Type"] = "application/json",
        ["X-API-Secret"] = API_SECRET,
    }
    local response, err = http_request(API_URL, "POST", headers, body)
    if not response then
        return nil, "Cannot reach API: " .. (err or "unknown")
    end
    local data
    local ok = pcall(function()
        local raw = type(response) == "table" and response.Body or tostring(response)
        data = HttpService:JSONDecode(raw)
    end)
    if not ok or not data then
        return nil, "Invalid API response"
    end
    return data, nil
end

-- ── Main ─────────────────────────────────────────────
local function main()
    local hwid = get_hwid()

    -- ── Bước 1: Verify key ──
    log("check key")

    if script_key == nil or script_key == "" then
        log("ERROR - key is empty")
        kick("You Dont Have Keys Or Key Invalid\nJoin " .. DISCORD)
        return
    end

    local data, err = call_api("open", script_key, hwid)

    if not data then
        log("ERROR - " .. (err or "unknown"))
        kick("You Dont Have Keys Or Key Invalid\nJoin " .. DISCORD)
        return
    end

    -- ── Bước 2: Xử lý kết quả ──
    if not data.success then
        local msg = data.message or ""

        if msg:lower():find("expired") then
            log("INVALID - key expired")
            kick("Your Keys Expired\nJoin " .. DISCORD)

        elseif msg:lower():find("blacklist") then
            log("INVALID - key blacklisted")
            kick("Your Keys Blacklists\nJoin " .. DISCORD)

        elseif msg:lower():find("banned") then
            log("INVALID - account banned")
            kick("Your Account Has Been Banned\nJoin " .. DISCORD)

        elseif msg:lower():find("tab limit") then
            log("INVALID - tab limit reached")
            kick("Tab Limit Reached (" .. tostring(data.tab_used or "?") .. "/" .. tostring(data.tab_limit or "?") .. ")\nClose other Roblox instances")

        elseif msg:lower():find("hwid") then
            log("INVALID - HWID mismatch")
            kick("HWID Mismatch - Key locked to another device\nJoin " .. DISCORD)

        else
            log("INVALID - " .. msg)
            kick("You Dont Have Keys Or Key Invalid\nJoin " .. DISCORD)
        end
        return
    end

    -- ── Bước 3: Key hợp lệ ──
    log("key valid")

    local used  = tostring(data.tab_used  or "?")
    local limit = tostring(data.tab_limit or "?")
    log("check tab execute")
    log("valid (" .. used .. "/" .. limit .. " tabs)")
    log("done verify keys - execute script")

    -- ── Bước 4: Heartbeat (giữ tab alive, tự xóa sau TAB_TIMEOUT giây) ──
    local heartbeat_running = true
    local heartbeat_conn

    heartbeat_conn = RunService.Heartbeat:Connect(function() end) -- placeholder
    heartbeat_conn:Disconnect()

    task.spawn(function()
        while heartbeat_running do
            task.wait(HEARTBEAT_INTERVAL)
            if not heartbeat_running then break end
            local hb_data, hb_err = call_api("heartbeat", script_key, hwid)
            if not hb_data or not hb_data.success then
                log("heartbeat failed - " .. (hb_err or (hb_data and hb_data.message) or "unknown"))
            end
        end
    end)

    -- Cleanup khi player leave
    Players.PlayerRemoving:Connect(function(p)
        if p == player then
            heartbeat_running = false
            call_api("close", script_key, hwid)
        end
    end)

    game:BindToClose(function()
        heartbeat_running = false
        call_api("close", script_key, hwid)
    end)

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

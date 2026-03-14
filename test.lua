-- ╔══════════════════════════════════════════════════════╗
-- ║         MTRCHILL KEY SYSTEM v4.0 - Lua Client       ║
-- ╚══════════════════════════════════════════════════════╝

script_key = script_key or "";

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local lp          = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local API_HOST   = "http://stardust.pikamc.vn:25765"
local API_KEY    = "testapikeyyyyyydasd"
local API_SECRET = "testapikeyy32asdt23daa"
local DISCORD    = "discord.gg/yourserver"
local HB_TICK    = 5   -- heartbeat mỗi 5 giây

-- ── Logger & Kick ─────────────────────────────────────────────────────────────
local function log(m) print("[keysystem] " .. tostring(m)) end
local function kick(msg) lp:Kick("\n❌ " .. msg .. "\n\nDiscord: " .. DISCORD) end

-- ── HMAC-SHA256 ───────────────────────────────────────────────────────────────
local bit  = bit32 or (bit and bit) or require("bit")
local band, bxor, rshift, lshift = bit.band, bit.bxor, bit.rshift, bit.lshift

local function rrotate(x, n)
    return band(bxor(rshift(x, n), lshift(x, 32 - n)), 0xFFFFFFFF)
end

local K256 = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

local function sha256(msg)
    local ml = #msg * 8
    msg = msg .. "\128" .. string.rep("\0", (56 - (#msg + 1) % 64) % 64)
    for i = 7, 0, -1 do
        msg = msg .. string.char(band(rshift(ml, i * 8), 0xFF))
    end
    local h = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
               0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    for i = 1, #msg, 64 do
        local w = {}
        for t = 1, 16 do
            local a,b,c,d = msg:byte(i+(t-1)*4, i+(t-1)*4+3)
            w[t] = band(lshift(a,24)+lshift(b,16)+lshift(c,8)+d, 0xFFFFFFFF)
        end
        for t = 17, 64 do
            local s0 = bxor(rrotate(w[t-15],7), rrotate(w[t-15],18), rshift(w[t-15],3))
            local s1 = bxor(rrotate(w[t-2],17), rrotate(w[t-2],19),  rshift(w[t-2],10))
            w[t] = band(w[t-16]+s0+w[t-7]+s1, 0xFFFFFFFF)
        end
        local a,b,c,d,e,f,g,hv = table.unpack(h)
        for t = 1, 64 do
            local S1    = bxor(rrotate(e,6), rrotate(e,11), rrotate(e,25))
            local ch    = bxor(band(e,f), band(0xFFFFFFFF-e, g))
            local temp1 = band(hv+S1+ch+K256[t]+w[t], 0xFFFFFFFF)
            local S0    = bxor(rrotate(a,2), rrotate(a,13), rrotate(a,22))
            local maj   = bxor(band(a,b), band(a,c), band(b,c))
            local temp2 = band(S0+maj, 0xFFFFFFFF)
            hv=g; g=f; f=e
            e=band(d+temp1, 0xFFFFFFFF)
            d=c; c=b; b=a; a=band(temp1+temp2, 0xFFFFFFFF)
        end
        h[1]=band(h[1]+a,0xFFFFFFFF); h[2]=band(h[2]+b,0xFFFFFFFF)
        h[3]=band(h[3]+c,0xFFFFFFFF); h[4]=band(h[4]+d,0xFFFFFFFF)
        h[5]=band(h[5]+e,0xFFFFFFFF); h[6]=band(h[6]+f,0xFFFFFFFF)
        h[7]=band(h[7]+g,0xFFFFFFFF); h[8]=band(h[8]+hv,0xFFFFFFFF)
    end
    local r = ""
    for _, v in ipairs(h) do r = r .. string.format("%08x", v) end
    return r
end

local function hmacSha256(secret, message)
    if #secret > 64 then secret = sha256(secret) end
    secret = secret .. string.rep("\0", 64 - #secret)
    local opad = secret:gsub(".", function(c) return string.char(bxor(c:byte(), 0x5c)) end)
    local ipad = secret:gsub(".", function(c) return string.char(bxor(c:byte(), 0x36)) end)
    return sha256(opad .. sha256(ipad .. message))
end

-- ── Executor & HWID ──────────────────────────────────────────────────────────
local function getExecutor()
    if identifyexecutor then local ok,n=pcall(identifyexecutor) if ok and n then return tostring(n) end end
    if getexecutorname  then local ok,n=pcall(getexecutorname)  if ok and n then return tostring(n) end end
    if syn and syn.request then return "Synapse" end
    if KRNL_LOADED         then return "KRNL"    end
    return "Unknown"
end

local function getHwid()
    local exec = getExecutor()
    local base = ""
    if exec:lower():find("synapse") and syn and syn.fingerprint then
        local ok, v = pcall(syn.fingerprint)
        if ok and v and v ~= "" then base = "SYN_" .. tostring(v) end
    end
    if base == "" then
        local ok, v = pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if ok and v and v ~= "" then base = exec:sub(1,3):upper() .. "_" .. tostring(v) end
    end
    if base == "" then base = "USR_" .. tostring(lp.UserId) end
    return base .. "_" .. tostring(lp.UserId):sub(-4)
end

-- ── HTTP POST ─────────────────────────────────────────────────────────────────
local _reqFn = nil
local function getReqFn()
    if _reqFn then return _reqFn end
    if syn  and syn.request  then _reqFn = syn.request;  return _reqFn end
    if http and http.request then _reqFn = http.request; return _reqFn end
    if request               then _reqFn = request;      return _reqFn end
    return nil
end

local function apiPost(endpoint, body, silent)
    local fn = getReqFn()
    if not fn then
        if not silent then log("[ ERR ] Không có http function") end
        return nil
    end
    local ok_enc, bodyStr = pcall(function() return HttpService:JSONEncode(body) end)
    if not ok_enc then return nil end

    local headers = {
        ["Content-Type"] = "application/json",
        ["x-api-key"]    = API_KEY,
    }

    local ok, res = pcall(fn, {
        Url     = API_HOST .. endpoint,
        Method  = "POST",
        Headers = headers,
        Body    = bodyStr,
    })
    if not ok then
        if not silent then log("[ ERR ] Request Error: " .. tostring(res)) end
        return nil
    end

    local raw  = type(res) == "table" and (res.Body or res.body) or tostring(res)
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then return nil end
    return data
end

-- ── Verify ────────────────────────────────────────────────────────────────────
local function verify(key, tabId)
    log("[ 1/4 ] Kiểm tra key...")
    if not key or key == "" then
        kick("Bạn chưa có key!\nDùng /redeem trong Discord."); return false
    end

    log("[ 2/4 ] Lấy HWID...")
    local hwid = getHwid()

    log("[ 3/4 ] Xác thực với server...")
    local data = apiPost("/api/consume-tab", { key_code = key, hwid = hwid, tab_id = tabId })

    if not data then
        kick("Không thể kết nối server.\nServer có thể đang offline.\nThử lại sau 1-2 phút.\nNếu vẫn lỗi liên hệ Admin."); return false
    end

    if not data.success then
        local code = tostring(data.code  or ""):lower()
        local err  = tostring(data.error or data.msg or ""):lower()

        if     code == "expired"      or err:find("expir")      then kick("Key Đã Hết Hạn!")
        elseif code == "blacklisted"  or err:find("blacklist")  then kick("Key Đã Bị Blacklist!\nLiên hệ Admin.")
        elseif code == "banned"       or err:find("ban")        then kick("Tài Khoản Đã Bị Ban!")
        elseif code == "tab_limit"    or err:find("tab")        then
            kick("Đã Đạt Giới Hạn Tab!\n("..tostring(data.tab_used or "?").."/"..tostring(data.tab_limit or "?")..")\nĐóng Roblox ở thiết bị khác.")
        elseif code == "not_found"    or err:find("not found")  then kick("Key Không Tồn Tại!")
        elseif code == "not_redeemed" or err:find("not redeem") then kick("Key Chưa Kích Hoạt!\nDùng /redeem trong Discord.")
        else kick("Key Không Hợp Lệ!") end
        return false
    end

    local tabLbl = (data.tab_limit == 0) and "∞" or tostring(data.tab_limit or "?")
    log("[ 4/4 ] Tab: " .. tostring(data.tab_used or "?") .. "/" .. tabLbl)
    log("[ DONE ] ✅ Key hợp lệ!")
    return true, hwid
end

-- ── Tab ID: unique cho mỗi instance Roblox ──────────────────────────────────
local function genTabId()
    math.randomseed(math.floor(tick() * 10000)) -- seed từ thời gian thực
    local t   = tostring(math.floor(tick() * 1000))
    local uid = tostring(lp.UserId)
    local rnd = tostring(math.random(100000, 999999))
    local rnd2= tostring(math.random(100000, 999999))
    return uid .. "_" .. t .. "_" .. rnd .. rnd2
end

-- ── Main ──────────────────────────────────────────────────────────────────────
local function main()
    local TAB_ID = genTabId() -- unique cho tab này, không đổi trong suốt session

    local ok, hwid = verify(script_key, TAB_ID)
    if not ok then return end

    local alive   = true
    local keySnap = script_key

    -- Heartbeat mỗi 5 giây, gửi tab_id riêng của tab này
    task.spawn(function()
        while alive do
            task.wait(HB_TICK)
            if not alive then break end
            apiPost("/api/heartbeat", { key_code = keySnap, tab_id = TAB_ID }, true)
        end
    end)

    -- Trả đúng tab này khi rời game
    Players.PlayerRemoving:Connect(function(p)
        if p == lp then
            alive = false
            apiPost("/api/reset-tab", { key_code = keySnap, tab_id = TAB_ID }, true)
        end
    end)

    -- Xóa thông tin nhạy cảm
    task.delay(1, function()
        API_KEY    = nil
        API_SECRET = nil
        script_key = nil
    end)

    -- ════════════════════════════════════════
    --   PASTE MAIN SCRIPT CỦA BẠN VÀO ĐÂY
    -- ════════════════════════════════════════
	print("hello")
    -- ════════════════════════════════════════
end

main()

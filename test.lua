-- ╔══════════════════════════════════════════════════════╗
-- ║         MTRCHILL KEY SYSTEM v4.0 - Lua Client       ║
-- ║  Auth: x-api-key + x-signature (HMAC-SHA256)        ║
-- ╚══════════════════════════════════════════════════════╝

script_key = script_key or "";
-- ── Services ──────────────────────────────────────────────────────────────────
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local lp          = Players.LocalPlayer

-- ── Config (thay 4 dòng này) ─────────────────────────────────────────────────
local API_HOST   = "http://stardust.pikamc.vn:25765"
local API_KEY    = "K9v@Tz4#LmP2x!Q8r$WsY7&bN3e*Hj6^UcD1fG"
local API_SECRET = "mR7!aZ2$Xc9^Lp4@Vt8#Qw6&En3*By5HuK1dJ"
local DISCORD    = "discord.gg/testing"
local HB_TICK    = 25

-- ── Logger ────────────────────────────────────────────────────────────────────
local function log(m) print("[keysystem] " .. tostring(m)) end
local function kick(msg) lp:Kick("\n❌ " .. msg .. "\n\nDiscord: " .. DISCORD) end

-- ── HMAC-SHA256 (pure Lua, giống code web.js dùng crypto.createHmac) ─────────
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

-- HMAC-SHA256: giống crypto.createHmac("sha256", secret).update(message).digest("hex")
local function hmacSha256(secret, message)
    if #secret > 64 then secret = sha256(secret) end
    -- convert hex secret to bytes nếu cần
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
    log("[ EXEC ] " .. exec)
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

-- ── HTTP helper ───────────────────────────────────────────────────────────────
local _reqFn = nil
local function getReqFn()
    if _reqFn then return _reqFn end
    if syn  and syn.request  then _reqFn = syn.request;  return _reqFn end
    if http and http.request then _reqFn = http.request; return _reqFn end
    if request               then _reqFn = request;      return _reqFn end
    return nil
end

-- POST JSON với x-api-key + x-signature
local function apiPost(endpoint, body, keyForSig)
    local fn = getReqFn()
    if not fn then log("[ ERR ] Không có http function"); return nil end

    local ok_enc, bodyStr = pcall(function() return HttpService:JSONEncode(body) end)
    if not ok_enc then log("[ ERR ] JSON encode thất bại"); return nil end

    -- Tính HMAC signature từ key (giống web.js: .update(key).digest("hex"))
    local sig = keyForSig and hmacSha256(API_SECRET, keyForSig) or nil

    local headers = {
        ["Content-Type"] = "application/json",
        ["x-api-key"]    = API_KEY,
    }
    if sig then headers["x-signature"] = sig end

    local ok, res = pcall(fn, {
        Url     = API_HOST .. endpoint,
        Method  = "POST",
        Headers = headers,
        Body    = bodyStr,
    })
    if not ok then log("[ ERR ] Request thất bại: " .. tostring(res)); return nil end

    local raw  = type(res) == "table" and (res.Body or res.body) or tostring(res)
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then log("[ ERR ] JSON decode thất bại: " .. tostring(raw):sub(1,80)); return nil end
    return data
end

-- ── Verify ────────────────────────────────────────────────────────────────────
local function verify(key)
    log("[ 1/4 ] Kiểm tra key...")
    if not key or key == "" then
        kick("Bạn chưa có key!\nDùng /redeem trong Discord."); return false
    end

    log("[ 2/4 ] Lấy HWID...")
    local hwid = getHwid()
    log("[ HWID ] " .. hwid)

    log("[ 3/4 ] Xác thực với server...")
    -- Gọi consume-tab (POST JSON, signature = HMAC của key_code)
    local data = apiPost("/api/consume-tab", { key_code = key, hwid = hwid }, key)

    if not data then
        kick("Không thể kết nối server. Thử lại sau."); return false
    end

    if not data.success then
        local code = tostring(data.code  or ""):lower()
        local err  = tostring(data.error or data.msg or ""):lower()
        log("[ ERR ] code=" .. code .. " err=" .. err)

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

-- ── Main ──────────────────────────────────────────────────────────────────────
local function main()
    local ok, hwid = verify(script_key)
    if not ok then return end

    local alive   = true
    local keySnap = script_key

    -- Heartbeat
    task.spawn(function()
        while alive do
            task.wait(HB_TICK)
            if not alive then break end
            apiPost("/api/consume-tab", { key_code = keySnap, hwid = hwid }, keySnap)
        end
    end)

    -- Trả tab khi rời game
    Players.PlayerRemoving:Connect(function(p)
        if p == lp then
            alive = false
            apiPost("/api/reset-tab", { key_code = keySnap }, keySnap)
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
getgenv().Settings = {
    ["Max Chests"] = 50; -- if you collected 65 chests, hop server
    ["Reset After Collect Chests"] = 14; -- if you collected 10 chests, it will reset for safe (anti kick)
    ["Katakuri Progress"] = 100; -- Auto hop until katakuri monsters progress left than 200
    ["Blacklist"] = {""}; -- comma
    ["Distance Check Any Player"] = 3; -- 750m
};

repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
if getgenv().WARCLOADER then StarterGui:SetCore("SendNotification", {Title = "Execution Blocked", Text = "The script is already running. Please wait 8 seconds", Duration = 5}) return end getgenv().WARCLOADER = true task.delay(10, (function() getgenv().WARCLOADER = nil end))
getgenv().WARCLOADER = true task.delay(10, (function() getgenv().WARCLOADER = nil end))

getgenv().cloneref = cloneref or clonereference or function(x) return x end
getgenv().isnetworkowner = isnetworkowner or isNetworkOwner or function() return true end
workspace = cloneref(workspace) or cloneref(Workspace) or (getrenv and (getrenv().workspace or getrenv().Workspace)) or cloneref(game:GetService("Workspace"))
PlaceId, JobId = game.PlaceId, game.JobId
getfenv = getfenv or _G or _ENV or shared or function() return {} end
IsOnMobile = false
Services = setmetatable({}, {__index = function(self, name)
    local s, c = pcall(function() return cloneref(game:GetService(name)) end)
    if s then rawset(self, name, c) return c
    else error("Invalid Roblox Service: " .. tostring(name))
    end
end})
COREGUI = Services.CoreGui
RunService = Services.RunService
VirtualUser = Services.VirtualUser
TweenService = Services.TweenService
HttpService = Services.HttpService
Players = Services.Players
ReplicatedStorage = Services.ReplicatedStorage
Lighting = Services.Lighting
CollectionService = Services.CollectionService
UserInputService = Services.UserInputService
VirtualInputManager = Services.VirtualInputManager
ReplicatedFirst = Services.ReplicatedFirst
StarterGui = Services.StarterGui
GuiService = Services.GuiService
TeleportService = Services.TeleportService
COMMF_ = ReplicatedStorage:WaitForChild("Remotes") and ReplicatedStorage.Remotes:WaitForChild("CommF_")
LocalPlayer = Players.LocalPlayer
LocalPlayer.CharacterAdded:Connect(function(v)
    Character = v Humanoid = v:WaitForChild("Humanoid")
    HumanoidRootPart = v:WaitForChild("HumanoidRootPart")
end)
if LocalPlayer.Character then
    Character = LocalPlayer.Character
    Humanoid = Character:FindFirstChild("Humanoid") or Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
end

StarterGui:SetCore("SendNotification", {Title = "Executed", Text = "Loading… Please wait", Duration = 5})
if not game:IsLoaded() or workspace.DistributedGameTime <= 10 then
    local WFGTL = COREGUI:FindFirstChild("WFGTL") or Instance.new("Hint", COREGUI)
    WFGTL.Text = "Just a moment... Waiting while the game loads - This won't take long!"
    task.wait(10 - workspace.DistributedGameTime)
    WFGTL:Destroy()
end
if not COMMF_ then repeat task.wait(1) until COMMF_ end
-- getgenv = (getgenv) or getgenv or function() return _G end
local gmod = require(ReplicatedStorage.GuideModule) and ReplicatedStorage:FindFirstChild("GuideModule") and gmod ~= (nil and {}) and gmod.Data ~= (nil and {}) and gmod.Data.NPCList ~= (nil and {})
task.spawn((function()
    xpcall(function()
        gethui().IgnoreGuiInset = true
    end, (function(err)
        xpcall((function()
            local g = COREGUI:FindFirstChild("ScreenGUI") or Instance.new("ScreenGui", COREGUI)
            g.Name = "ScreenGUI" g.IgnoreGuiInset = true
            hookfunction(gethui, function() return g end)
            task.delay(5, (function()StarterGui:SetCore("SendNotification", {Title = "Incompatible Executor", Text = "This executor may cause errors while running the script\n[ERROR CODE: UIGE]", Duration = 20})end))
        end), (function() warn("???") end))
    end))
end))
task.spawn(function()
    xpcall(function()
        if not LocalPlayer.Team then
            if LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") then
                repeat task.wait(1) until not LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
            end
            xpcall(function() COMMF_:InvokeServer("SetTeam", "Pirates")
            end, function() firesignal(LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container.Pirates) end)
            task.wait(2)
            -- pcall(function() require(ReplicatedStorage.Effect).new("BlindCam"):replicate({["Color"] = Color3.new(0, 0, 0); ["Duration"] = 2; ["Fade"] = 0.4; ["ZIndex"] = 1}) end)
        end
    end, function(err) warn("????", err) end)
end)
repeat task.wait(2) until Character and Character:FindFirstChild("HumanoidRootPart") and Character:FindFirstChildWhichIsA("Humanoid") and Character:IsDescendantOf(workspace.Characters) -- workspace.CurrentCamera.CameraSubject, Players.CharacterAdded:Wait()

local all = 0
local blacklisted = false;
for _, v in next, getgenv().Settings.Blacklist do
	if LocalPlayer.Name == v then
		blacklisted = true
	end
end
if blacklisted then return end
pcall(function() LocalPlayer.PlayerGui:FindFirstChild("Blank"):Destroy() end)
local BlankScreen = LocalPlayer.PlayerGui:FindFirstChild("Blank") or Instance.new("ScreenGui", LocalPlayer.PlayerGui)
BlankScreen.Name = "Blank" BlankScreen.ResetOnSpawn = false BlankScreen.DisplayOrder = -math.huge BlankScreen.IgnoreGuiInset = true
local Black = BlankScreen:FindFirstChild("Black Screen") or Instance.new("Frame", BlankScreen)
Black.Name = "Black Screen" Black.Size = UDim2.new(1, 0, 1, 0) Black.BackgroundColor3 = Color3.new(0, 0, 0) Black.ZIndex = -math.huge
local label = Instance.new("TextLabel", BlankScreen)
label.Name = "CenteredLabel"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.5, 0)
label.Size = UDim2.new(0.6, 0, 0.15, 0)
label.Text = string.rep("Nil ", 20)
label.TextScaled = true;
label.TextWrapped = true;
label.TextXAlignment = Enum.TextXAlignment.Center;
label.TextYAlignment = Enum.TextYAlignment.Center;
label.BackgroundTransparency = 1;
label.Font = Enum.Font.GothamSemibold;
label.TextSize = 48;
label.TextColor3 = Color3.fromRGB(255, 255, 255)
local leftButton = Instance.new("TextButton", gethui())
leftButton.Name = "LeftButton"
leftButton.AnchorPoint = Vector2.new(0, 0.5)
leftButton.Position = UDim2.new(0, 400, 0.7, 0)
leftButton.Size = UDim2.new(0, 150, 0, 150)
leftButton.Text = "Disable"
leftButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
leftButton.TextSize = 32;
if Black.Visible then RunService:Set3dRenderingEnabled(false) end
leftButton.MouseButton1Click:Connect(function()
    leftButton.Text = leftButton.Text == "Disable" and "Enable" or "Disable"
    RunService:Set3dRenderingEnabled(leftButton.Text == "Disable" and false or true)
	Black.Visible = not Black.Visible
end)
local function SetText(newText) label.Text = newText end
function CheckSea(v: number) return v == tonumber(workspace:GetAttribute("MAP"):match("%d+")) end
local remoteAttack, idremote
local seed = ReplicatedStorage.Modules.Net.seed:InvokeServer()
task.spawn((function() for _, v in next, ({ReplicatedStorage.Util, ReplicatedStorage.Common, ReplicatedStorage.Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX}) do
    for _, n in next, v:GetChildren() do if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id") end
    end v.ChildAdded:Connect(function(n) if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id")
    end end) end
end))
local mainfile = LocalPlayer.Name .. ".txt"
if not isfile(mainfile) then writefile(mainfile, "") end
print("file")
CheckLocation = (function(v)return LocalPlayer:GetAttribute("CurrentLocation") == v end)
CheckMap = (function(v) return workspace.Map:FindFirstChild(v) or false end)
CheckTool = (function(v)
    for _, x in next, {LocalPlayer.Backpack, Character} do
    for _, v2 in next, x:GetChildren() do if v2:IsA("Tool") and (v2.Name == v or v2.Name:find(v)) then return true end
    end end return false
end)
CheckMaterial = (function(x)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do if v.Type == "Material" then if v.Name == x then return v.Count end end
    end return 0
end)
CheckInventory = (function(...)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do
    for _, n in next, {...} do if v.Name == n then return true end end
    end return false
end)

KillAura = (function(vName)
    pcall(function() setscriptable(LocalPlayer, "SimulationRadius", true) end)
    pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
    for _, v in next, workspace.Enemies:GetChildren() do
        pcall(function()
            local hrp = v:FindFirstChild("HumanoidRootPart") or false
            if hrp and HumanoidRootPart and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 1250 then
                local cond = (vName and v.Name == vName) or not vName
                if cond then
                    v:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
                end
            end
        end)
    end
end)
CheckMoon = (function()
    local tex =
        (CheckSea(1) or CheckSea(3)) and ((game.Lighting:FindFirstChild("Sky") and game.Lighting.Sky.MoonTextureId)
        or (game.Lighting:FindFirstChild("Space_Skybox") and game.Lighting.Space_Skybox.MoonTextureId))
        or (CheckSea(2) and game.Lighting:FindFirstChild("FantasySky") and game.Lighting.FantasySky.MoonTextureId)
        or ""
    tex = tex:gsub("rbxassetid://", "http://www.roblox.com/asset/?id=")
    return ({
        ["http://www.roblox.com/asset/?id=15493317929"] = "Blue Moon";
        ["http://www.roblox.com/asset/?id=9709149431"] = "8/8";
        ["http://www.roblox.com/asset/?id=9709149052"] = "7/8";
        ["http://www.roblox.com/asset/?id=9709143733"] = "6/8";
        ["http://www.roblox.com/asset/?id=9709150401"] = "5/8";
        ["http://www.roblox.com/asset/?id=9709135895"] = "4/8";
        ["http://www.roblox.com/asset/?id=9709150086"] = "2/8";
        ["http://www.roblox.com/asset/?id=9709139597"] = "1/8";
        ["http://www.roblox.com/asset/?id=9709149680"] = "0/8";
})[tex] or "nil"
end)
CheckMonster = (function(...) local args = {...}
    local v2 = {workspace.Enemies, ReplicatedStorage}
    for i = 1, #args do local n = args[i]
        local m = workspace.Enemies:FindFirstChild(n) or ReplicatedStorage:FindFirstChild(n)
        if m and m:IsA("Model") and m.Name ~= "Blank Buddy" then
            local h = m:FindFirstChild("Humanoid") local r = m:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then return m end
        end
    end
    for c = 1, #v2 do local container = v2[c] local ms = container:GetChildren()
        for m = 1, #ms do local m = ms[m] local h = m:FindFirstChild("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if m:IsA("Model") and h and r and h.Health > 0 and m.Name ~= "Blank Buddy" then
                for i = 1, #args do local n = args[i]
                    if m.Name == n or m.Name:lower():find(n:lower()) then
                        return m
                    end
                end
            end
        end
    end
    return false
end)

EquipWeapon = (function(v)
    if not Character then return end
    local tool = Character:FindFirstChildWhichIsA("Tool")
    if tool and (tool.ToolTip and tool.ToolTip == v) then return end --((tool:GetAttribute("WeaponType") or "") == v
    for _, x in next, LocalPlayer.Backpack:GetChildren() do
        if x:IsA("Tool") and x.ToolTip == v then
            Humanoid:EquipTool(x)
            return
        end
    end
end)

local lastCallFA = tick()
FastAttack = (function(x)
    if not HumanoidRootPart or not Character:FindFirstChildWhichIsA("Humanoid") or Character.Humanoid.Health <= 0 or not Character:FindFirstChildWhichIsA("Tool") then return end
    local FAD = 0.01 -- throttle
    if FAD ~= 0 and tick() - lastCallFA <= FAD then return end
    local t = {}
    for _, e in next, workspace.Enemies:GetChildren() do
        local h = e:FindFirstChild("Humanoid") local hrp = e:FindFirstChild("HumanoidRootPart")
        if e ~= Character and (x and e.Name == x or not x) and h and hrp and h.Health > 0 and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 65 then t[#t + 1] = e end
    end
    local n = ReplicatedStorage.Modules.Net
    local h = {[2] = {}}
    local last
    for i = 1, #t do local v = t[i]
        local part = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart")
        if not h[1] then h[1] = part end
        h[2][#h[2] + 1] = {v, part} last = v
    end
    -- h[2][#h[2] + 1] = last
    n:FindFirstChild("RE/RegisterAttack"):FireServer()
    n:FindFirstChild("RE/RegisterHit"):FireServer(unpack(h))
    cloneref(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".",function(c)
        return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow()/10%10)+1))
    end), bit32.bxor(idremote+909090, seed*2), unpack(h))
    lastCallFA = tick()
end)
print('func')
local lastHop, inHopPP = tick(), false
HopServer = (function(mx) if mx then if mx >= Players.MaxPlayers then mx = Players.MaxPlayers - 1 end end
    if inHopPP then return false end
    if tick() - lastHop < 5 then return end lastHop = tick()
    mx = math.abs(mx) or 4 local id, c = PlaceId, ""
    pcall(SetText, "Hop Server")
    local THop = function()
        local r = pcall(function()
            local j = HttpService:JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/"..id.."/servers/Public?sortOrder=Asc&limit=100"..(c ~= "" and "&cursor="..c or "")))
            for _,v in next, j.data do if v.playing <= mx and v.id ~= JobId then TeleportService:TeleportToPlaceInstance(PlaceId, v.id, LocalPlayer) return true end
            end c = j.nextPageCursor or ""
        end)
        if not r or c == "" then warn("Couldn't find a server") end
    end
    spawn(function() pcall(function()
        while true do inHopPP = true THop() task.wait(30) end
    end) end)
end)
CheckLocation = (function(v) return LocalPlayer:GetAttribute("CurrentLocation") == v end)
local connection, tween, pathPart, isTweening = nil, nil, nil, false
function Tween(targetCFrame: CFrame | boolean, target: CFrame) --old tween, lastest update: 5 months ago
    pcall(function() Character.Humanoid.Sit = false end)
    if not Character.Humanoid or Character.Humanoid.Health <= 0 then pcall(function() workspace.TweenGhost:Destroy() end) connection, tween, pathPart, isTweening = nil, nil, nil, false return end
    if targetCFrame == false then
        if tween then pcall(function() tween:Cancel() end) tween = nil end
        if connection then connection:Disconnect() connection = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        isTweening = false
        return
    end
    if isTweening or not targetCFrame then return end
    isTweening = true
    local char = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    if not char then isTweening = false return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then isTweening = false return end
    humanoid.Sit = false
    target = target or root
    local distance = (targetCFrame.Position - target.Position).Magnitude
    pathPart = Instance.new("Part")
    pathPart.Name = "TweenGhost"
    pathPart.Transparency = 1
    pathPart.Anchored = true
    pathPart.CanCollide = false
    pathPart.CFrame = target.CFrame
    pathPart.Size = Vector3.new(50, 50, 50)
    pathPart.Parent = workspace
    tween = game:GetService("TweenService"):Create(pathPart, TweenInfo.new(distance / 250, Enum.EasingStyle.Linear), {CFrame = targetCFrame * (function()
        if target ~= root then
            return CFrame.new(0, 30, 0)
        end
        return CFrame.new(0, 5, 0)
    end)()})
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if target and pathPart then
            target.CFrame = pathPart.CFrame * (function()
                if target ~= root then
                    return CFrame.new(0, 30, 0)
                end
                return CFrame.new(0, 5, 0)
            end)()
        end
    end)
    tween.Completed:Connect(function()
        if connection then connection:Disconnect() connection = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        tween = nil
        isTweening = false
    end)

    tween:Play()
end

local lastGhost = tick()
BringMonster = (function(name, count) count = count or 3
    if count < 2 then return end
    pcall(function() setscriptable(LocalPlayer, "SimulationRadius", true) end)
    pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
    xpcall((function()
        local mob, t = {}, nil
        for _, v in next, workspace.Enemies:GetChildren() do
            local h = v:FindFirstChild("Humanoid")
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.Health > 0 and (not name or v.Name == name)
                and (HumanoidRootPart.Position - hrp.Position).Magnitude <= ((count or 3) * 250) then
                if not table.find(mob, function(chosen)
                    local chrp = chosen:FindFirstChild("HumanoidRootPart")
                    return chrp and (hrp.Position - chrp.Position).Magnitude <= 5
                end) then mob[#mob+1], t = v, t or hrp.CFrame
                end
                if #mob >= (count or 3) then break end
            end
        end
        if not t then return end
        for i = 1, #mob do
            local hrp = mob[i]:FindFirstChild("HumanoidRootPart")
            local h = mob[i]:FindFirstChild("Humanoid")
            if hrp and (not isnetworkowner or isnetworkowner(hrp)) then
                -- h.PlatformStand = false h.AutoRotate = false
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = t * CFrame.new((i-1) * 2, 0, 0)
            end
        end
    end), (function(r) warn("Modules Error [BM]: ".. r) end))
end)

TableQuests = setmetatable({}, {__index = function(_, k)
    local p, d, m, raw = HumanoidRootPart.Position
    for _, x in next, require(ReplicatedStorage.GuideModule).Data.NPCList do
        if x.InternalQuestName == k then
            local pos = x.Position
            if typeof(pos) == "Vector3" then
                local dist = (pos - p).Magnitude
                if not d or dist < d then d = dist m = pos raw = x.NPCName end
            elseif typeof(pos) == "table" then
                for _, v in next, pos do
                    if typeof(v) == "Vector3" then
                        local dist = (v - p).Magnitude
                        if not d or dist < d then d = dist m = v raw = x.NPCName end
                    end
                end
            end
        end
    end
    return m and {Position = m, Meters = d, RawNPCName = raw} or nil
end})

local lastKenCall=tick() -- pray
KillMonster=(function(x)
    xpcall(function()
        if workspace.Enemies:FindFirstChild(x) then
            for _,v in next,workspace.Enemies:GetChildren() do
                local vh=v:FindFirstChild("Humanoid") local vhrp=v:FindFirstChild("HumanoidRootPart")
                if vh and vh.Health > 0 and vhrp and v.Name==x then
                    local dx,dy,dz=HumanoidRootPart.Position.X-vhrp.Position.X, HumanoidRootPart.Position.Y-vhrp.Position.Y, HumanoidRootPart.Position.Z-vhrp.Position.Z
                    local sqrMag=dx*dx+dy*dy+dz*dz
                    if sqrMag<=4900 then
                        BringMonster(x, 3)
                        FastAttack(x)
                        if tick()-lastKenCall>=10 then lastKenCall=tick() ReplicatedStorage.Remotes.CommE:FireServer("Ken",true) end
                        Tween(CFrame.new(vhrp.Position + (vhrp.CFrame.LookVector * 20) + Vector3.new(0, vhrp.Position.Y > 60 and -20 or 20, 0)))
                        EquipWeapon("Melee")
                        return
                    end
                    Tween(vhrp.CFrame) return
                end
            end
        end
        for _,v in next,ReplicatedStorage:GetChildren() do
            local vhrp=v:FindFirstChild("HumanoidRootPart")
            if v:IsA("Model") and vhrp and v.Name==x then Tween(vhrp.CFrame) return end
        end
    end,function(e) warn("Modules ERROR:",e) end)
end)
local function CheckNearbyPlayers()
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP = v.Character.HumanoidRootPart
            local distance = (HumanoidRootPart.Position - targetHRP.Position).Magnitude
            if distance <= getgenv().Settings["Distance Check Any Player"] then
                return true, v
            end
        end
    end
    return false
end
local hookedNotification; hookedNotification = hookfunction(require(ReplicatedStorage.Notification).new,function(...)
    local args = ({...})[1]
    if CheckSea(3) then
        if args:find("Used materials") then
            pcall(function() delfile(mainfile) end)
        end
    end
    return hookedNotification(...)
end)
local CacheRemote = function()
    if workspace.NPCs:FindFirstChild("Shafi") then local pos = (workspace.NPCs.Shafi:GetPivot().Position - HumanoidRootPart.Position).Magnitude
        if pos < 30 then print(pos) SetText(pos) wait(4)
            local BSAT = COMMF_:InvokeServer("BuySanguineArt", true)
            if typeof(BSAT) == "string" and BSAT:find("Bring me") then SetText("Material CC")
                writefile(mainfile, "Material") COMMF_:InvokeServer("BuySanguineArt")
            elseif typeof(BSAT) == 0 then SetText("Changed") COMMF_:InvokeServer("BuySanguineArt")
                writefile(mainfile, "Completed-Sanguine Art")
            else --  typeof(BSAT) == 1 then
                SetText("Else CC")
                local CCS = COMMF_:InvokeServer("BuySanguineArt")
                writefile(mainfile, (CCS == 1 or CCS == 2) and "Completed-Sanguine Art" or "Material")
            end
        else SetText("Tween to Shafi [1]")
            xpcall(function() Tween(workspace.NPCs.Shafi:GetPivot())
            end, function() Tween(CFrame.new(-16515, 25, -190))
            end)
        end
    else SetText("Tween to Shafi [2]")
        xpcall(function() Tween(workspace.NPCs.Shafi:GetPivot())
        end, function() Tween(CFrame.new(-16515, 25, -190))
        end)
    end
end
spawn(function()
    while task.wait(0.2) do
        xpcall(function() local c = 0
            local cached = readfile(mainfile)
            print(cached.."Cached")
            if cached == "Completed-Sanguine Art" or CheckTool("Sanguine Art") then writefile(mainfile, "Completed-Sanguine Art") StarterGui:SetCore("SendNotification", {Title = "Done Sanguine Art", Text = "Bought Sanguine Art"}) task.wait(4) return
            elseif cached == "" or cached == "Changed" then
                if CheckSea(3) then
                    SetText("Cache First Time")
                    CacheRemote()
                else SetText("Teleport to Sea 3") COMMF_:InvokeServer("TravelZou") task.wait(10)
                end
            elseif cached == "" or cached == "Material" or cached == "false" then
                if CheckMaterial("Dark Fragment") >= 2 and CheckMaterial("Vampire Fang") >= 20 and CheckMaterial("Demonic Wisp") >= 20 then
                    if CheckSea(3) then
                        if LocalPlayer.Data.Fragments.Value >= 5000 then
                            if LocalPlayer.Data.Beli.Value >= 5E6 then Tween(false)
                                SetText("Cache")
                                CacheRemote()
                            else LocalPlayer:Kick("Please Farm Beli")
                            end
                        else
                            if CheckSea(3) then
                                if CheckMonster("Dough King") or CheckMonster("rip_indra") or CheckMonster("Cake Prince") then Tween(false)
                                    for _, v2 in next, {workspace.Enemies, ReplicatedStorage} do
                                        for _, v in next, v2:GetChildren() do
                                            if v.Name == "Dough King" or v.Name == "Cake Prince" or v.Name:find("rip_indra") then
                                                if v.Name ~= "rip_indra" then if not CheckLocation("Dimensional Shift") then firetouchinterest(LocalPlayer.Character.HumanoidRootPart, workspace.Map.CakeLoaf.BigMirror.Main, 0) task.wait(3) end end
                                                if v:FindFirstChildWhichIsA("Humanoid") and v.Humanoid.Health > 0 and v.HumanoidRootPart then
                                                    repeat task.wait() KillMonster(v.Name)
                                                    until not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0 or not v.HumanoidRootPart
                                                end
                                            end
                                        end
                                    end
                                else currentProgress = tonumber(COMMF_:InvokeServer("CakePrinceSpawner"):match("%d+") or 500) print(currentProgressb)
                                    if currentProgress <= getgenv().Settings["Katakuri Progress"] then
                                        if LocalPlayer.Data.Level.Value >= 2200 and (LocalPlayer.PlayerGui.Main.Quest.Visible and (function(q)
                                            for _, n in next, {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"} do
                                                if q:find(n) then return true end
                                            end
                                        end)(LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text)) or LocalPlayer.Data.Level.Value < 2200 then
                                            xpcall(function()
                                                Tween(workspace.Map.CakeLoaf.RespawnPart.CFrame)
                                            end, function()
                                                Tween(CFrame.new(-2100, 70, -12130))
                                            end)
                                            for _, v in next, workspace.Enemies:GetChildren() do
                                                if table.find({"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"}, v.Name) then
                                                    if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then Tween(false)
                                                        repeat task.wait()
                                                            SetText("Killing 500 monsters| Killing: ".. v.Name.. "\nCurrent progress: ".. currentProgress.. "/500")
                                                            KillMonster(v.Name)
                                                        until (LocalPlayer.Data.Level.Value >= 2200 and not LocalPlayer.PlayerGui.Main.Quest.Visible) or not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0
                                                    end
                                                end
                                            end
                                        else
                                            pcall(function()
                                                if (TableQuests["CakeQuest2"].Position - Character.HumanoidRootPart.Position).Magnitude > 30 then
                                                    task.defer(function()
                                                        SetText("Tweening To Katakuri Island | Get Quest: Cake Quest Giver")
                                                        Tween(false)
                                                        Tween(CFrame.new(TableQuests["CakeQuest2"].Position))
                                                    end)
                                                else
                                                    SetText("Get Quest Cake Prince: " .. TableQuests["CakeQuest2"].RawNPCName) task.wait(0.5)
                                                    COMMF_:InvokeServer("StartQuest", LocalPlayer.Data.Level.Value >= 2275 and "CakeQuest2" or tostring(GetQuest().NameQuest), LocalPlayer.Data.Level.Value >= 2275 and 2 or GetQuest().ID)
                                                end
                                            end)
                                        end
                                    else SetText("Hop for lower enemies for Katakuri") task.wait(3) HopServer(10)
                                    end
                                end
                            else
                                SetText("Teleport to Sea 3") task.wait(3) COMMF_:InvokeServer("TravelZou") task.wait(10)
                            end
                        end
                    else SetText("Teleport to Sea 3") COMMF_:InvokeServer("TravelZou") task.wait(10)
                    end
                elseif CheckMonster("Darkbeard") then for _, v2 in next, {workspace.Enemies, ReplicatedStorage} do for _, v in next, v2:GetChildren() do if v.Name == "Darkbeard" then repeat task.wait() SetText("Killing Darkbeard\nHealth: ".. math.floor(v.Humanoid.Health / v.Humanoid.MaxHealth * 100).."%") KillMonster(v.Name) until not v or not v:FindFirstChild("Humanoid") or v.Humanoid.Health <= 0 Tween(false) end end end
                elseif CheckTool("Fist of Darkness") then local Detection = workspace.Map.DarkbeardArena.Summoner.Detection
                    Tween(false) SetText("Spawn Darkbeard\nTweening") Tween(Detection.CFrame)
                    if (HumanoidRootPart.Position - Detection.Position).Magnitude <= 200 then
                        firetouchinterest(Detection, HumanoidRootPart, 0) task.wait(0.2)
                        firetouchinterest(Detection, HumanoidRootPart, 1)
                    end
                elseif CheckNearbyPlayers() then
                    SetText("Found Any Players") HopServer(8)
                else
                    if CheckMaterial("Dark Fragment") < 2 then
                        print("Chests")
                        if CheckSea(2) then Tween(false)
                            local chests = {} local m = CollectionService:GetTagged("_ChestTagged")
                            if all < getgenv().Settings["Max Chests"] and not CheckTool("Fist of Darkness") then
                                for _, v in next, CollectionService:GetTagged("_ChestTagged") do if v and v.CanTouch then local dist = (v.Position - HumanoidRootPart.Position).Magnitude table.insert(chests, {obj = v, dist = dist}) end end
                                    table.sort(chests, function(a, b) return a.dist < b.dist end)
                                    if not CheckTool("Fist of Darkness") then -- why I called this function 2 times?
                                        for i, t in next, chests do local v = t.obj
                                            if v:IsA("BasePart") and v.Name:find("Chest") then
                                                if v.CanTouch then SetText("Collect Chests")
                                                    repeat task.wait()
                                                        SetText("Collect Chests | Collected: " .. c.."/"..all .. "/"..getgenv().Settings["Max Chests"].." Chests")
                                                        if Character.Humanoid and Character.Humanoid.Health > 0 then Character:SetPrimaryPartCFrame(v.CFrame) task.delay(2, function() v.CanTouch = false end) end
                                                        pcall(function() if (Character.Humanoid.FloorMaterial ~= Enum.Material.Air or not table.find({Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Dead}, Character.Humanoid:GetState())) then Character:FindFirstChildWhichIsA("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping) end end)
                                                    until not v.CanTouch or CheckTool("Fist of Darkness") c += 1 all += 1
                                                    if all >= getgenv().Settings["Max Chests"] or CheckTool("Fist of Darkness") or CheckMonster("Darkbeard") then SetText("Stopped") break end
                                                    if c >= getgenv().Settings["Reset After Collect Chests"] and not CheckTool("Fist of Darkness") then Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead) SetText("Collect Chests | Reset: Collected: "..getgenv().Settings["Reset After Collect Chest"] .." Chests") c = 0 task.wait(1) end
                                                end
                                                if i % 250 == 0 then task.wait(0.01) end
                                            end
                                        end
                                    else
                                        Tween(false)
                                        SetText("Stopped: Found Special Item")
                                    end
                                if not CheckTool("Fist of Darkness") and not CheckMonster("Darkbeard") then HopServer(8) end 
                            end
                        else SetText("Travel to sea 2") task.wait(1) COMMF_:InvokeServer("TravelDressrosa")
                        end
                    elseif CheckMaterial("Vampire Fang") < 20 then SetText("Farming Vampire for get Vampire Fang")
                        if not CheckSea(2) then COMMF_:InvokeServer("TravelDressrosa") task.wait(5) end
                        if (LocalPlayer.PlayerGui.Main.Quest.Visible and (function(q)
                            for _, n in next, {"Vampire", "Zombie"} do
                                if q:find(n) then return true end
                            end
                        end)(LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text)) or LocalPlayer.Data.Level.Value < 2200 then
                            Tween(ReplicatedStorage.FortBuilderReplicatedSpawnPositionsFolder["Vampire"].CFrame)
                            for _, v in next, workspace.Enemies:GetChildren() do
                                if table.find({"Vampire", "Zombie"}, v.Name) then
                                    if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then Tween(false)
                                        repeat task.wait() KillMonster(v.Name)
                                        until not LocalPlayer.PlayerGui.Main.Quest.Visible or not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0
                                    end
                                end
                            end
                        else
                            pcall(function()
                                if (TableQuests["ZombieQuest"].Position - Character.HumanoidRootPart.Position).Magnitude > 30 then
                                    task.defer(function()
                                        SetText("Tweening To Zombie Island | Get Quest: Zombie Giver")
                                        Tween(false)
                                        Tween(CFrame.new(TableQuests["ZombieQuest"].Position))
                                    end)
                                else
                                    SetText("Get Quest Zombie: " .. TableQuests["ZombieQuest"].RawNPCName) task.wait(0.5)
                                    COMMF_:InvokeServer("StartQuest", "ZombieQuest", 2)
                                end
                            end)
                        end
                    elseif CheckMaterial("Demonic Wisp") < 20 then SetText("Farming Demonic Soul for get Demonic Wisp")
                        if not CheckSea(3) then COMMF_:InvokeServer("TravelZou") task.wait(5) end
                        Tween(ReplicatedStorage.FortBuilderReplicatedSpawnPositionsFolder["Demonic Soul"].CFrame)
                        if LocalPlayer.Data.Level.Value >= 2025 and (LocalPlayer.PlayerGui.Main.Quest.Visible and (function(q)
                            for _, n in next, {"Demonic Soul", "Posessed Mummy"} do
                                if q:find(n) then return true end
                            end
                        end)(LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text)) or LocalPlayer.Data.Level.Value < 2025 then Tween(false)
                            Tween(CFrame.new(-5670, 50, -970))
                            for _, v in next, workspace.Enemies:GetChildren() do
                                if table.find({"Demonic Soul", "Posessed Mummy"}, v.Name) then
                                    if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then Tween(false)
                                        repeat task.wait() KillMonster(v.Name)
                                        until (LocalPlayer.Data.Level.Value >= 2025 and not LocalPlayer.PlayerGui.Main.Quest.Visible) or not v or not v:FindFirstChildWhichIsA("Humanoid") or v.Humanoid.Health <= 0
                                    end
                                end
                            end
                        else
                            pcall(function()
                                if (TableQuests["HauntedQuest2"].Position - Character.HumanoidRootPart.Position).Magnitude > 30 then
                                    task.defer(function()
                                        SetText("Tweening To Bone Island | Get Quest: Bone Giver")
                                        Tween(false)
                                        Tween(CFrame.new(TableQuests["HauntedQuest2"].Position))
                                    end)
                                else
                                    SetText("Get Quest Bone: " .. TableQuests["HauntedQuest2"].RawNPCName) task.wait(0.5)
                                    COMMF_:InvokeServer("StartQuest", "HauntedQuest2", LocalPlayer.Data.Level.Value >= 2050 and 2 or 1)
                                end
                            end)
                        end
                    else SetText("Ơ Thiếu Material gì nhở?")
                    end
                end
            else SetText("Chả biết")
            end
        end, function(err)warn("Main Error ".. err)end)
    end
end)

task.spawn(function()
    while task.wait(4) do
        xpcall(function()
            if not Character.Humanoid or Character.Humanoid.Health <= 0 then pcall(function() workspace.TweenGhost:Destroy() end) connection, tween, pathPart, isTweening = nil, nil, nil, false return end
            if not Character:FindFirstChild("HasBuso") then COMMF_:InvokeServer("Buso") end
            for _, v in next, {"Buso", "Geppo", "Soru"} do
                if not CollectionService:HasTag(Character, v) then
                    if LocalPlayer.Data.Beli.Value >= ((function(t)
                        return t == "Geppo" and 1e4 or t == "Buso" and 2.5e4 or t == "Soru" and 1e5 or 0
                    end)(v)) then SetText("Buy Abilies: ".. v) COMMF_:InvokeServer("BuyHaki", v)
                    end
                end
            end
        end, function(err) warn("LL: ".. err) end)
    end
end)
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, message)
        if teleportResult == Enum.TeleportResult.GameFull then inHopPP = false
        elseif teleportResult == Enum.TeleportResult.IsTeleporting and (message:find("previous teleport")) then
            StarterGui:SetCore("SendNotification", {Title = "Death Hop Found", Text = message, Duration = 8})
            task.delay(10, function() game:Shutdown() end)
        end
        -- player.Name -- my LocalPlayer
        -- teleportResult -- Enum.TeleportResult
        -- message -- Request experience is full
    end)
GuiService.ErrorMessageChanged:Connect(newcclosure(function()
    if GuiService:GetErrorType() == Enum.ConnectionError.DisconnectErrors then
        while true do TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer) task.wait(5) end
    end
end))
    -- ════════════════════════════════════════
end

main()

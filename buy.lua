-- ╔══════════════════════════════════════════════╗
-- ║         MTRCHILL - KEY SYSTEM v2.0          ║
-- ║         Anti-Spy / Secure Edition           ║
-- ╚══════════════════════════════════════════════╝

script_key = script_key or "";

-- ── Bảo mật: Obfuscate config ────────────────
-- API URL và SECRET được split + encode để tránh string search/spy
local function _d(t)
    local s = ""
    for _, v in ipairs(t) do s = s .. string.char(v) end
    return s
end

-- "https://mtrchill.top/api/verify_key.php" encoded
local _url_parts = {
    _d({104,116,116,112,115,58,47,47}),       -- https://
    _d({109,116,114,99,104,105,108,108}),      -- mtrchill
    _d({46,116,111,112,47,97,112,105,47}),     -- .top/api/
    _d({118,101,114,105,102,121,95,107}),      -- verify_k
    _d({101,121,46,112,104,112}),              -- ey.php
}
local _API_URL = table.concat(_url_parts)

-- Secret key split thành nhiều phần
local _s = {
    _d({97,57,70,51,107,76,56,120}),           -- a9F3kL8x
    _d({81,50,109,90,55,114,84,49}),           -- Q2mZ7rT1
    _d({118,87,54,121,80,52,99,72}),           -- vW6yP4cH
    _d({57,110,66,50,115,68,53}),              -- 9nB2sD5
}
local _API_SECRET = table.concat(_s)

local _DISCORD    = "discord.gg/myserver"
local _HB_TICK    = 30
local _TAB_EXPIRE = 60

-- ── Services (obfuscated) ─────────────────────
local _gs  = game.GetService
local _hs  = _gs(game, "HttpService")
local _ps  = _gs(game, "Players")
local _rs  = _gs(game, "RunService")
local _lp  = _ps.LocalPlayer

-- ── Disable commonly hooked globals ──────────
-- Tạo local copy trước khi bị hook
local _print    = print
local _pcall    = pcall
local _tostring = tostring
local _pairs    = pairs
local _ipairs   = ipairs
local _type     = type

-- ── Logger ───────────────────────────────────
local function log(m)
    _print("[mtrchill] " .. m)
end

-- ── Anti-Debug: Phát hiện hook trên syn.request ──
local function is_hooked(fn)
    if not fn then return false end
    local info = debug and debug.getinfo and debug.getinfo(fn)
    if info and info.what == "C" then return false end
    -- Nếu là Lua function thay vì C function → có thể bị hook
    return info and info.what == "Lua"
end

-- ── Kick ─────────────────────────────────────
local function kick(msg)
    _lp:Kick("\n" .. msg)
end

-- ── HWID ─────────────────────────────────────
local function get_hwid()
    -- Synapse X hardware fingerprint (best)
    if syn and syn.fingerprint then
        local ok, v = _pcall(syn.fingerprint)
        if ok and v and v ~= "" then return "SYN_" .. _tostring(v) end
    end
    -- KRNL
    if KRNL_LOADED and getsynasset then
        local ok, v = _pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if ok and v and v ~= "" then return "KRN_" .. _tostring(v) end
    end
    -- Generic ClientId
    local ok, v = _pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and v and v ~= "" then
        local exec = "UNK"
        if identifyexecutor then
            local ok2, e = _pcall(identifyexecutor)
            if ok2 and e then exec = _tostring(e):sub(1,3):upper() end
        end
        return exec .. "_" .. _tostring(v)
    end
    -- Fallback
    return "USR_" .. _tostring(_lp.UserId)
end

-- ── Anti-Spy: Request wrapper ─────────────────
-- Dùng closure để ẩn URL và secret khỏi memory scan
local function make_request(url, secret)
    return function(body_table)
        -- Encode body
        local ok_enc, body = _pcall(function()
            return _hs:JSONEncode(body_table)
        end)
        if not ok_enc then return nil, "encode failed" end

        -- Tìm http function
        local req_fn = nil
        if syn and syn.request and not is_hooked(syn.request) then
            req_fn = syn.request
        elseif http and http.request then
            req_fn = http.request
        elseif request then
            req_fn = request
        end

        if not req_fn then return nil, "no http function" end

        local ok, res = _pcall(req_fn, {
            Url     = url,
            Method  = "POST",
            Headers = {
                -- Header name split để tránh string search
                [_d({88,45,65,80,73,45,83,101,99,114,101,116})] = secret,
                [_d({67,111,110,116,101,110,116,45,84,121,112,101})] = _d({97,112,112,108,105,99,97,116,105,111,110,47,106,115,111,110}),
            },
            Body    = body,
        })

        if not ok then return nil, _tostring(res) end

        local raw = _type(res) == "table" and res.Body or _tostring(res)
        local ok2, data = _pcall(function()
            return _hs:JSONDecode(raw)
        end)
        if not ok2 or not data then return nil, "bad response" end
        return data, nil
    end
end

-- Tạo request function 1 lần, URL/secret được capture trong closure
local _call_api = make_request(_API_URL, _API_SECRET)

-- ── Verify ───────────────────────────────────
local function verify(key)
    log("check key")
    if not key or key == "" then
        log("ERROR - key empty")
        kick("You Dont Have Keys Or Key Invalid\nJoin " .. _DISCORD)
        return false
    end

    local hwid = get_hwid()
    local data, err = _call_api({
        key_code = key,
        hwid     = hwid,
        action   = "open",
    })

    if not data then
        log("ERROR - " .. (err or "unknown"))
        kick("You Dont Have Keys Or Key Invalid\nJoin " .. _DISCORD)
        return false
    end

    if not data.success then
        local msg = (data.message or ""):lower()
        if msg:find("expired") then
            kick("Your Keys Expired\nJoin " .. _DISCORD)
        elseif msg:find("blacklist") then
            kick("Your Keys Blacklists\nJoin " .. _DISCORD)
        elseif msg:find("banned") then
            kick("Your Account Has Been Banned\nJoin " .. _DISCORD)
        elseif msg:find("tab limit") then
            kick("Tab Limit Reached (" .. _tostring(data.tab_used or "?") .. "/" .. _tostring(data.tab_limit or "?") .. ")\nClose other Roblox instances")
        elseif msg:find("hwid") then
            kick("HWID Mismatch - Key locked to another device\nJoin " .. _DISCORD)
        else
            kick("You Dont Have Keys Or Key Invalid\nJoin " .. _DISCORD)
        end
        return false
    end

    log("key valid")
    log("check tab execute")
    log("valid (" .. _tostring(data.tab_used or "?") .. "/" .. _tostring(data.tab_limit or "?") .. " tabs)")
    return true, hwid
end

-- ── Main ─────────────────────────────────────
local function main()
    local ok, hwid = verify(script_key)
    if not ok then return end

    log("done verify keys - execute script")

    -- ── Heartbeat ────────────────────────────
    local alive = true
    task.spawn(function()
        while alive do
            task.wait(_HB_TICK)
            if not alive then break end
            _call_api({ key_code = script_key, hwid = hwid, action = "heartbeat" })
        end
    end)

    _ps.PlayerRemoving:Connect(function(p)
        if p == _lp then
            alive = false
            _call_api({ key_code = script_key, hwid = hwid, action = "close" })
        end
    end)

    -- ════════════════════════════════════════
    --   PASTE YOUR MAIN SCRIPT BELOW
    -- ════════════════════════════════════════
if game:GetService("Players").LocalPlayer.Team == nil then
    repeat
        repeat task.wait() until game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)") and game:GetService("Players").LocalPlayer.PlayerGui["Main (minimal)"]:FindFirstChild("ChooseTeam")
        local Team = (getgenv().Team or "Pirates")
        local Button = game:GetService("Players").LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container[Team].Frame.TextButton
        for _, v in pairs(getconnections(Button.Activated)) do
            v.Function()
        end
        task.wait(1)
    until game:GetService("Players").LocalPlayer.Team ~= nil
    wait(3)
end

local World1, World2, World3, Request_Places
if game.PlaceId == 2753915549 or game.PlaceId == 85211729168715 then
    World1 = true
    Request_Places = {
        ["Whirl Pool"] = CFrame.new(3864.6884765625, 6.736950397491455, -1926.214111328125),
        ["Sky Area 1"] = CFrame.new(-4607.82275, 872.54248, -1667.55688),
        ["Sky Area 2"] = CFrame.new(-7894.61767578125, 5547.1416015625, -380.29119873046875),
        ["Fish Man"] = CFrame.new(61163.8515625, 11.6796875, 1819.7841796875)
    }
elseif game.PlaceId == 4442272183 or game.PlaceId == 79091703265657 then
    World2 = true
    Request_Places = {
        ["Swan's room"] = CFrame.new(2284.912109375, 15.152046203613281, 905.48291015625),
        ["Mansion"] = CFrame.new(-288.46246337890625, 306.130615234375, 597.9988403320312),
        ["Ghost Ship"] = CFrame.new(923.21252441406, 126.9760055542, 32852.83203125),
        ["Ghost Ship Entrance"] = CFrame.new(-6508.5581054688, 89.034996032715, -132.83953857422)
    }
elseif game.PlaceId == 7449423635 or game.PlaceId == 100117331123089 then
    World3 = true
    Request_Places = {
        ["Castle on the sea"] = CFrame.new(-5075.50927734375, 314.5155029296875, -3150.0224609375),
        ["Mansion"] = CFrame.new(-12548.998046875, 332.40396118164, -7603.1865234375),
        ["Hydra Island"] = CFrame.new(5661.53027, 1013.38354, -334.961914),
        ["Temple Of Time"] = CFrame.new(28286.35546875, 14895.3017578125, 102.62469482421875),
        ["Green Tree"] = CFrame.new(3028.84082, 2281.20264, -7324.7832)
    }
end

function skidymf(v)
    if v and v.Parent and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild('Humanoid') and v.Humanoid.Health > 0 then
        return true
    else
        return false
    end
end

function checkmas1(t, n) --// check mastery 
    for _, v in pairs(game.ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")) do
        if v.Type == t and v.Name == n then return v.Mastery end
    end
    return 0 --return 0; neu ko la sai
end

function GetCountMaterials(materialName) --// count item
    for _, v in pairs(game.ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")) do
        if v.Name == materialName then return v.Count end
    end
    return 0
end

function EquipWeapon(w) --// equip 
	pcall(function()
		for i,v in pairs(game.Players.LocalPlayer.Backpack:GetChildren()) do
			if game.Players.LocalPlayer.Backpack:FindFirstChild(w) or v.ToolTip == w then 
				game.Players.LocalPlayer.Character.Humanoid:EquipTool(game.Players.LocalPlayer.Backpack:FindFirstChild(v.Name)) 
			end
		end
	end)
end

function UnEquipAllWeapon()
    if game.Players.LocalPlayer and game.Players.LocalPlayer.Character then
        _G.NotAutoEquip = true
        wait(0.5)
        for _, v in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
            if v:IsA("Tool") then
                v.Parent = game.Players.LocalPlayer.Backpack
            end
        end
        wait(0.1)
        _G.NotAutoEquip = false
    end
end

local Request_Places2 = {}
local tween
local fkwarp = false
local Distance
local Time
local LocalPlayer = game.Players.LocalPlayer
local PlrData = LocalPlayer.Data
local Level = PlrData.Level
local LastSpawn = PlrData.LastSpawnPoint
local VirtualInputManager = game:GetService("VirtualInputManager")
local rs = game.ReplicatedStorage
local ignore

function q1(I, II)
    if not II then
        II = game.Players.LocalPlayer.Character.PrimaryPart.Position
    end
    if typeof(I) == "CFrame" then
        I = I.Position
    end
    if typeof(II) == "CFrame" then
        II = II.Position
    end
    return (Vector3.new(I.X, 0, I.Z) - Vector3.new(II.X, 0, II.Z)).Magnitude
end

function GetDistance(target1, target2)
    if not target2 then
        target2 = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
    end
    
    local pos1 = target1
    local pos2 = target2
    
    if typeof(target1) == "CFrame" then
        pos1 = target1.Position
    elseif typeof(target1) == "Instance" and target1:IsA("BasePart") then
        pos1 = target1.Position
    end
    
    if typeof(target2) == "CFrame" then
        pos2 = target2.Position
    elseif typeof(target2) == "Instance" and target2:IsA("BasePart") then
        pos2 = target2.Position
    end

    return (pos1 - pos2).Magnitude
end

for i1,v1 in pairs(workspace._WorldOrigin.PlayerSpawns[tostring(game:GetService("Players").LocalPlayer.Team)]:GetChildren()) do
    if not Request_Places2[v1.Name] then
        Request_Places2[v1.Name] = CFrame.new(v1.WorldPivot.Position)
    end
end

workspace._WorldOrigin.PlayerSpawns[tostring(game:GetService("Players").LocalPlayer.Team)].ChildAdded:Connect(function(aa)
    if not Request_Places2[aa.Name] then
        Request_Places2[aa.Name] = CFrame.new(aa.WorldPivot.Position)
    end
end)

function CheckNearestRequestIsland2(pos, tpinstant)
    local nearestIsland = nil
    local nearestDist = math.huge
    for name, islandPos in pairs(Request_Places2) do
        if Level.Value < 10 or GetDistance(pos, game.Players.LocalPlayer.Character.HumanoidRootPart.Position) < 1500 or not tpinstant then break end
        local dist = GetDistance(islandPos, pos)
        local distoplr = GetDistance(islandPos, game.Players.LocalPlayer.Character.HumanoidRootPart.Position)
        if distoplr <= 9500 and dist < nearestDist and (not ignore or ignore ~= name) then
            nearestDist = dist
            nearestIsland = name
        end
    end
    for name, cframe in pairs(Request_Places) do
        if GetDistance(pos, game.Players.LocalPlayer.Character.HumanoidRootPart.Position) < 500 or (World3 and not checkcanentrance()) then break end
        local dist = GetDistance(pos, cframe)
        local distotarget = GetDistance(pos, game.Players.LocalPlayer.Character.HumanoidRootPart.Position)
        if dist < nearestDist and dist < distotarget then
            nearestDist = dist
            nearestIsland = name
        end
    end
    if nearestIsland then
        if Request_Places2[nearestIsland] then
            return (LastSpawn.Value ~= nearestIsland) and nearestIsland
        elseif Request_Places[nearestIsland] and GetDistance(Request_Places[nearestIsland], pos) < GetDistance(pos, game.Players.LocalPlayer.Character.HumanoidRootPart.Position) then
            return nearestIsland
        end
    end
    return nil
end

function IsPlayerAlive(player)
    if not player then
        player = game.Players.LocalPlayer
    end
    if not player or not player:IsA("Player") then
        return false
    end
    local character = player.Character
    if not character then
        return false
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    return true
end

function checkinv(name)
    local inventory = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
    if not inventory then return false end
    for _, item in pairs(inventory) do
        if item.Name == name then
            return true
        end
    end
    return false
end

function checkcanentrance()
    return game.PlaceId ~= 7449423635 or checkinv("Valkyrie Helm")
end

function NormalTween(Pos)
    if not IsPlayerAlive() then return end
    Distance = q1(Pos.Position, game.Players.LocalPlayer.Character.HumanoidRootPart.Position)
    local request_place = CheckNearestRequestIsland2(Pos)
    if request_place then
        if Request_Places2[request_place] then
            if PlrData:FindFirstChild("LastSpawnPoint") and type(PlrData.LastSpawnPoint.Value) == "string" and (PlrData.LastSpawnPoint.Value ~= request_place or GetDistance(Request_Places2[request_place], game.Players.LocalPlayer.Character.HumanoidRootPart.Position) >= 1500) then
                if tween then tween:Cancel() end
                if IsPlayerAlive() then
                    setlastspawn(request_place)
                end
                return
            end
        elseif Request_Places[request_place] and checkcanentrance() and not fkwarp then
            rqentrance(request_place)
            Distance = q1(Pos)
            fkwarp = true
        end
    end
    if Pos.Position.Y > 0 and math.abs(game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Y - Pos.Position.Y) > 50 then
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(
            game.Players.LocalPlayer.Character.HumanoidRootPart.Position.X,
            Pos.Position.Y,
            game.Players.LocalPlayer.Character.HumanoidRootPart.Position.Z
        )
        wait(0.5)
    end
    if Distance <= 50 then
        Time = 0
    elseif Distance <= 200 then
        Time = 0.25
    else
        Time = Distance / 350
    end
    tween = game:GetService("TweenService"):Create(
        game:GetService("Players").LocalPlayer.Character.HumanoidRootPart,
        TweenInfo.new(Time, Enum.EasingStyle.Linear),
        { CFrame = Pos }
    )
    AddVelocity()
    getgenv().NoClip = true
    tween:Play()
    return tween
end

function AddVelocity()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    getgenv().NoClip = true
        if not LocalPlayer.Character.HumanoidRootPart:FindFirstChild("Alescial Hub") then
            local body = Instance.new("BodyVelocity")
            body.Name = "Alescial Hub"
            body.Parent = LocalPlayer.Character.HumanoidRootPart
            body.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            body.Velocity = Vector3.new(0, 0, 0)
        end
    end
end

function RemoveVelocity()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local velocity = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("Alescial Hub")
        if velocity then
            velocity:Destroy()
            getgenv().NoClip = false
        end
    end
end

function setlastspawn(Map)
    if not (PlrData:FindFirstChild("LastSpawnPoint") and type(PlrData.LastSpawnPoint.Value) == "string" and (PlrData.LastSpawnPoint.Value ~= Map or GetDistance(Request_Places2[Map], game.Players.LocalPlayer.Character.HumanoidRootPart.Position) >= 1500)) then return end
    if LocalPlayer.Character:FindFirstChild("LastSpawnPoint") and not LocalPlayer.Character.LastSpawnPoint.Disabled then 
        LocalPlayer.Character.LastSpawnPoint.Disabled = true 
    end
    game.ReplicatedStorage.Remotes.CommF_:InvokeServer('SetLastSpawnPoint', Map)
    wait()
    if not IsPlayerAlive() then return end
    game:GetService('Players').LocalPlayer.Data.LastSpawnPoint.Value = Map
    wait()
    if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
        game.Players.LocalPlayer.Character.Humanoid:ChangeState(15)
    end
end

function rqentrance(request_place)
    if tween then tween:Cancel() end
    if request_place ~= "Green Tree" then
        repeat
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",
                Request_Places[request_place].Position)
            wait(0.5)
        until GetDistance(Request_Places[request_place], game.Players.LocalPlayer.Character.HumanoidRootPart.Position) < 50
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(30, 50, 0)
        end
    else
        if not workspace.NPCs:FindFirstChild("Mysterious Force") and not workspace.NPCs:FindFirstChild("Mysterious Force3") then
            repeat
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",
                    Request_Places["Temple Of Time"].Position)
                wait(1)
            until workspace.NPCs:FindFirstChild("Mysterious Force3")
        end
        if workspace.NPCs:FindFirstChild("Mysterious Force3") then
        repeat
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(28610.1328, 14896.8477, 105.67765, -0.0388384573, 6.65092799e-08, -0.999245524, -1.15718697e-08, 1, 6.70092675e-08, 0.999245524, 1.41656757e-08, -0.0388384573)
            end
            task.wait(0.1)
        until GetDistance(CFrame.new(28610.1328, 14896.8477, 105.67765, -0.0388384573, 6.65092799e-08, -0.999245524, -1.15718697e-08, 1, 6.70092675e-08, 0.999245524, 1.41656757e-08, -0.0388384573), game.Players.LocalPlayer.Character.HumanoidRootPart.Position) < 10 or workspace.NPCs:FindFirstChild("Mysterious Force")
            repeat
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RaceV4Progress",
                    "TeleportBack")
                wait(1)
            until workspace.NPCs:FindFirstChild("Mysterious Force")
        end
    end
end

function CheckBackPack(bx)
    local BackpackandCharacter = { LocalPlayer.Backpack, LocalPlayer.Character }
    for _, by in pairs(BackpackandCharacter) do
        if by then
            for _, v in pairs(by:GetChildren()) do
                if type(bx) == "table" then
                    if table.find(bx, v.Name) then
                        return v
                    end
                else
                    if v.Name == bx then
                        return v
                    end
                end
            end
        end
    end
    return nil
end

function shouldtp(instant)
    if not instant or CheckBackPack({"Hellfire Torch", "Special Microchip", "Flower 1", "Flower 2", "Flower 3", "Hallow Essence", "God's Chalice", "Fist of darkness", "Sweet Chalice"}) then 
        return false 
    end
    return true
end
getgenv().NoClip = false

game:GetService("RunService").Stepped:Connect(function()
    pcall(function()
        if not (game:GetService("Players").LocalPlayer.Character 
            and game:GetService("Players").LocalPlayer.Character:FindFirstChild("Head") 
            and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end
        if getgenv().NoClip then
            for _, v in ipairs(game:GetService("Players").LocalPlayer.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        else
            for _, v in ipairs(game:GetService("Players").LocalPlayer.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = true
                end
            end
        end
    end)
end)
function TP1(pos, notinstant)
    if not pos then return end
    local lastPauseTime = tick()
    local localFkwarp = false
    local Pos = typeof(pos) == "CFrame" and pos or CFrame.new(pos.X, pos.Y, pos.Z)
    repeat task.wait() until IsPlayerAlive() and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character:FindFirstChild("Humanoid")
    local Character = LocalPlayer.Character
    local Humanoid = Character:FindFirstChild("Humanoid")
    local HRP = Character:FindFirstChild("HumanoidRootPart")
    if not Humanoid or not HRP then return end
    if Humanoid.Sit then
        repeat
            task.wait()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        until not Humanoid.Sit or not Character.Parent
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end
    local Distance = q1(Pos.Position, HRP.Position)
    local request_place = CheckNearestRequestIsland2(Pos, shouldtp(not notinstant))
    if request_place then
        if Request_Places2[request_place] and shouldtp(not notinstant) then
            if PlrData:FindFirstChild("LastSpawnPoint") and type(PlrData.LastSpawnPoint.Value) == "string" and PlrData.LastSpawnPoint.Value ~= request_place then
                if tween then tween:Cancel() end
                if IsPlayerAlive() then setlastspawn(request_place) end
            end
        elseif Request_Places[request_place] and checkcanentrance() and not localFkwarp then
            rqentrance(request_place)
            Distance = q1(Pos.Position, HRP.Position)
            localFkwarp = true
        end
    end
    if Pos.Position.Y > 0 and math.abs(HRP.Position.Y - Pos.Position.Y) > 50 then
        HRP.CFrame = CFrame.new(HRP.Position.X, Pos.Position.Y, HRP.Position.Z)
        task.wait(0.5)
    end
    local Time
    if Distance <= 50 then
        Time = 0
    elseif Distance <= 200 then
        Time = 0.25
    else
        Time = Distance / 350
    end
    if HRP and HRP.Parent then
        tween = game:GetService("TweenService"):Create(HRP, TweenInfo.new(Time, Enum.EasingStyle.Linear), {CFrame = Pos})
        AddVelocity()
        tween:Play()
    end
end

function AutoHaki() --// turn on haki
    local char = game.Players.LocalPlayer.Character
    if char and not char:FindFirstChild("HasBuso") then
        game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
    end
end

function IsPlayerNearby(position, radius)
    for _, player in pairs(game.Players:GetPlayers()) do
        if player ~= game.Players.LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if (player.Character.HumanoidRootPart.Position - position).Magnitude <= radius then
                return true
            end
        end
    end
    return false
end

local lp = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local bringConnection
local stabilized = {}
local activePos
local maxBring = 25
local isBring = {mobName=nil,targetPos=nil}

function BringMob(mobName, targetPos, range, skipDeath, bringAll)
    range = range or 350
    if bringConnection then bringConnection:Disconnect() end
    isBring.mobName = mobName
    isBring.targetPos = targetPos
    activePos = targetPos

    bringConnection = RunService.Heartbeat:Connect(function()
        local hrpPlr = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if not hrpPlr then return end
        pcall(function() sethiddenproperty(lp,"SimulationRadius",math.huge) end)
        local alive=0
        for _,mob in ipairs(workspace.Enemies:GetChildren()) do
            local hrp,hum=mob:FindFirstChild("HumanoidRootPart"),mob:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health>0 and (bringAll or string.find(mob.Name,mobName)) then alive+=1 end
        end
        if alive==0 then stabilized={} activePos=nil isBring.mobName=nil isBring.targetPos=nil bringConnection:Disconnect() return end

        local count=0
        for _,mob in ipairs(workspace.Enemies:GetChildren()) do
            if count>=maxBring then break end
            local hrp,hum=mob:FindFirstChild("HumanoidRootPart"),mob:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health>0 and (bringAll or string.find(mob.Name,mobName)) then
                local dist=(hrpPlr.Position-hrp.Position).Magnitude
                if dist>range then
                    if stabilized[mob] and not stabilized[mob].OutOfRangeTime then stabilized[mob].OutOfRangeTime=tick()
                    elseif stabilized[mob] and tick()-stabilized[mob].OutOfRangeTime>5 then stabilized[mob]=nil end
                    continue
                end
                hrp.CanCollide=false
                for _,v in ipairs(mob:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
                hum.JumpPower,hum.WalkSpeed,hum.AutoRotate=0,0,false

                if not stabilized[mob] then
                    local t=Instance.new("Part")
                    t.Name="GlobalBringTarget"
                    t.Size=Vector3.new(1,1,1)
                    t.Anchored=true
                    t.Transparency=1
                    t.CanCollide=false
                    t.Parent=workspace
                    stabilized[mob]={BasePos=activePos,RX=math.random(1,3),RZ=math.random(1,3),Phase=math.random()*math.pi*2,Target=t}
                end
                local data=stabilized[mob]
                local att0=hrp:FindFirstChild("AP_Att0") or Instance.new("Attachment",hrp)
                att0.Name="AP_Att0"
                local att1=data.Target:FindFirstChild("AP_Att1") or Instance.new("Attachment",data.Target)
                att1.Name="AP_Att1"
                local ap=hrp:FindFirstChild("AlignPos_AP") or Instance.new("AlignPosition")
                ap.Name="AlignPos_AP" ap.Attachment0=att0 ap.Attachment1=att1 ap.Responsiveness=200
                ap.MaxForce=math.huge ap.MaxVelocity=math.huge ap.Parent=hrp
                local ao=hrp:FindFirstChild("AlignOri_AP") or Instance.new("AlignOrientation")
                ao.Name="AlignOri_AP" ao.Attachment0=att0 ao.Attachment1=att1 ao.Responsiveness=200
                ao.MaxTorque=math.huge ao.MaxAngularVelocity=math.huge ao.Parent=hrp
                hrp.AssemblyLinearVelocity=Vector3.new() hrp.AssemblyAngularVelocity=Vector3.new()
                data.OutOfRange=false
                count+=1
            end
        end
    end)
end

RunService.RenderStepped:Connect(function()
    local hrpPlr=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrpPlr then return end
    for mob,data in pairs(stabilized) do
        if mob and mob.Parent and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health>0 then
            local dist=(hrpPlr.Position-mob.HumanoidRootPart.Position).Magnitude
            if dist>350 then
                if not data.OutOfRangeTime then data.OutOfRangeTime=tick()
                elseif tick()-data.OutOfRangeTime>5 then stabilized[mob]=nil end
            else
                data.OutOfRangeTime=nil
                local t=tick()
                local x=math.sin(t*data.RX+data.Phase)*0.5
                local z=math.cos(t*data.RZ+data.Phase)*0.5
                data.Target.Position=Vector3.new(isBring.targetPos.X+x,isBring.targetPos.Y,isBring.targetPos.Z+z)
                if not mob:FindFirstChild("AlignPos_AP") or not mob:FindFirstChild("AlignOri_AP") then
                    local hrp=mob.HumanoidRootPart
                    local att0=hrp:FindFirstChild("AP_Att0") or Instance.new("Attachment",hrp)
                    att0.Name="AP_Att0"
                    local att1=data.Target:FindFirstChild("AP_Att1") or Instance.new("Attachment",data.Target)
                    att1.Name="AP_Att1"
                    local ap=Instance.new("AlignPosition")
                    ap.Name="AlignPos_AP" ap.Attachment0=att0 ap.Attachment1=att1 ap.Responsiveness=200
                    ap.MaxForce=math.huge ap.MaxVelocity=math.huge ap.Parent=hrp
                    local ao=Instance.new("AlignOrientation")
                    ao.Name="AlignOri_AP" ao.Attachment0=att0 ao.Attachment1=att1 ao.Responsiveness=200
                    ao.MaxTorque=math.huge ao.MaxAngularVelocity=math.huge ao.Parent=hrp
                end
            end
        else
            stabilized[mob]=nil
        end
    end
end)

local lastNotification = {}

function SendNotify(cac, time)
    if lastNotification[cac] then return end
    lastNotification[cac] = true
    game.StarterGui:SetCore("SendNotification", {
        Title = "3TOC",
        Text = cac,
        Duration = (time or 0.5),
        Icon = ""
    })
    task.delay(0.5, function()
        lastNotification[cac] = nil
    end)
end

function Hop()
    SendNotify("Hopping...")
    local PlaceID = game.PlaceId
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer
    local AllIDs, nextCursor, isTeleporting = {}, "", false
    local fileName = "ZeroX_HopIDs_"..LocalPlayer.Name..".json"
    if isfile(fileName) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(fileName)) end)
        if ok and type(data) == "table" then
            AllIDs = data
        end
    end
    local function saveIDs()
        if #AllIDs >= 5 then
            AllIDs = {}
        end
        pcall(function() writefile(fileName, HttpService:JSONEncode(AllIDs)) end)
    end
    local function getServers()
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100%s"):format(
            PlaceID,
            nextCursor ~= "" and "&cursor="..nextCursor or ""
        )
        local s, r = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if s and r and r.data then
            nextCursor = r.nextPageCursor or ""
            return r.data
        end
        return {}
    end
    local function hopOnce()
        if isTeleporting then
            return false
        end
        local servers = getServers()
        for _, v in ipairs(servers) do
            if tonumber(v.playing) > 0 and tonumber(v.playing) < tonumber(v.maxPlayers) and tonumber(v.ping or 999) > 0 then
                local id = tostring(v.id)
                if not table.find(AllIDs, id) then
                    table.insert(AllIDs, id)
                    saveIDs()
                    isTeleporting = true
                    game.StarterGui:SetCore("SendNotification", {
                        Title = "Alescial Hub",
                        Text = "Joining server: "..id.." | "..v.playing.."/"..v.maxPlayers,
                        Duration = 3
                    })
                    TeleportService:TeleportToPlaceInstance(PlaceID, id, LocalPlayer)
                    task.wait(3)
                    isTeleporting = false
                    return true
                end
            end
        end
        return false
    end
    local startTime = tick()
    while task.wait(1) do
        if hopOnce() then
            startTime = tick()
        end
        if tick() - startTime > 180 then
            pcall(function() delfile(fileName) end)
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        end
    end
end
_G.ServerData = {} 
_G.ServerData['Chest'] = {}
_G.ChestsConnection = {}
function SortChest()
    local LOROOT = game.Players.LocalPlayer.Character.PrimaryPart or game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart')
    if LOROOT then
        table.sort(_G.ServerData['Chest'], function(chestA, chestB)  
            local distanceA
            local distanceB
            if chestA:IsA('Model') then 
                distanceA = (Vector3.new(chestA:GetModelCFrame()) - LOROOT.Position).Magnitude
            end 
            if chestB:IsA('Model') then 
                distanceB = (Vector3.new(chestB:GetModelCFrame()) - LOROOT.Position).Magnitude 
            end
            if not distanceA then  distanceA = (chestA.Position - LOROOT.Position).Magnitude end
            if not distanceB then  distanceB = (chestB.Position - LOROOT.Position).Magnitude end
            return distanceA < distanceB 
        end)
    end
end
function AddChest(chest)
    wait()
    if table.find(_G.ServerData['Chest'], chest) or not chest.Parent then return end 
    if not string.find(chest.Name,'Chest') or not (chest.ClassName == ('Part') or chest.ClassName == ('BasePart')) then return end
    if (chest.Position-CFrame.new(-1.4128437, 0.292379826, -6.53605461, 0.999743819, -1.41806034e-09, -0.0226347167, 4.24517754e-09, 1, 1.2485377e-07, 0.0226347167, -1.24917875e-07, 0.999743819).Position).Magnitude <= 10 then 
        return 
    end 
    local CallSuccess,Returned = pcall(function()
        return GetDistance(chest)
    end)
    if not CallSuccess or not Returned then return end
    table.insert(_G.ServerData['Chest'], chest)  
    local parentChangedConnection
    parentChangedConnection = chest:GetPropertyChangedSignal('Parent'):Connect(function()
        local index = table.find(_G.ServerData['Chest'], chest)
        table.remove(_G.ServerData['Chest'], index)
        parentChangedConnection:Disconnect()
        SortChest()
    end)
end

function LoadChest()
    for _, v in pairs(workspace:GetDescendants()) do
        if v.Name:find("Chest") and v.Name:match("%d+") and v.CanTouch then
            task.spawn(function()
                AddChest(v)
                local parentFullName = v and v.Parent and tostring(v.Parent:GetFullName())
                if parentFullName and not _G.ChestsConnection[parentFullName] then
                    _G.ChestsConnection[parentFullName] = v.Parent.ChildAdded:Connect(AddChest)
                end
            end)
        end
    end 
    task.delay(3,function()
        SortChest()
    end)
end
task.spawn(function()
	while task.wait(1) do
		pcall(LoadChest)
	end
end)
function getNearestChest()
    for _, v in pairs(_G.ServerData['Chest']) do
        if v and v.Parent and v:IsA("BasePart") then
            return v
        end
    end
    return false
end
local plr = game.Players.LocalPlayer
local chr = plr.Character or plr.CharacterAdded:Wait()
local h = chr:FindFirstChild("Humanoid") or false
local check = 0
_G.ChestCollect = 0

function PickChest(Chest)
    if not _G.ChestCollect or typeof(_G.ChestCollect) ~= "number" then
        _G.ChestCollect = 0
    end
    if not Chest or not Chest.Parent then
        return
    end
    local conn
    conn = Chest:GetPropertyChangedSignal("Parent"):Connect(function()
        if conn then
            conn:Disconnect()
            conn = nil
        end
        _G.ChestCollect += 1
        if typeof(SortChest) == "function" then
            local ok, err = pcall(SortChest)
            if not ok then
                print("SortChest Error:", err)
            end
        end
    end)
    local OldChestCollect = _G.ChestCollect
    local timeout = tick() + 8
    repeat
        task.wait()
        local ok, err = pcall(function()
            if not h or h.Health <= 0 then
                chr = plr.Character or plr.CharacterAdded:Wait()
                h = chr:FindFirstChild("Humanoid") or false
            end
            if Chest and Chest.Parent and Chest:IsA("BasePart") then
                chr:SetPrimaryPartCFrame(Chest.CFrame)
                task.delay(1.3, function()
                    if Chest then
                        Chest.CanTouch = false
                    end
                end)
            end
        end)
        if not ok then
            print("PickChest Loop Error:", err)
        end
        if tick() > timeout then
            break
        end
    until not Chest or not Chest.Parent or not Chest.CanTouch or (_G.Stop_If_Have_Key and CheckBackPack({"God's Chalice", "Fist of darkness", "Sweet Chalice"}))
    check += 1
    if check >= 7 and not CheckBackPack({"God's Chalice", "Fist of darkness", "Sweet Chalice"}) then
        local hum = chr:FindFirstChildOfClass("Humanoid")
        if hum and not CheckBackPack({"God's Chalice", "Fist of darkness", "Sweet Chalice"}) then
            local ok, err = pcall(function()
                hum:ChangeState(15)
            end)
            if not ok then
                print("Humanoid ChangeState Error:", err)
            end
        end
        check = 0
        task.wait(3)
    end
    if Chest and Chest.Parent then
        local ok, err = pcall(function()
            Chest:Destroy()
        end)
        if not ok then
            print("Chest Destroy Error:", err)
        end
    elseif _G.ChestCollect == OldChestCollect then
        _G.ChestCollect += 1
    end
end
function TeleportWorld(world)
    if typeof(world) == "string" then
        world = world:gsub(" ", ""):gsub("Sea", "")
        world = tonumber(world)
    end
    if world == 1 then
        local args = {
            [1] = "TravelMain"
        }
        game.ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args))
    elseif world == 2 then
        local args = {
            [1] = "TravelDressrosa"
        }
        game.ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args))
    elseif world == 3 then
        local args = {
            [1] = "TravelZou"
        }
        game.ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(args))
    end
end
function CheckBoss(targets)
    local targetList = typeof(targets) == "table" and targets or {targets}
    local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local results = {}
    local function Scan(folder)
        for _, v in pairs(folder:GetChildren()) do
            if v:IsA("Model") and table.find(targetList, v.Name) then
                local h = v:FindFirstChild("Humanoid")
                local r = v:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and r then
                    table.insert(results, {model = v, dist = (hrp.Position - r.Position).Magnitude})
                end
            end
        end
    end
    Scan(game.ReplicatedStorage)
    if game.Workspace:FindFirstChild("Enemies") then
        Scan(game.Workspace.Enemies)
    end
    if #results == 0 then return nil end
    table.sort(results, function(a,b) return a.dist < b.dist end)
    return results[1].model
end

function Death(col)
    task.wait(col or 0)
    local character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid:ChangeState(15)
    end
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = Modules:WaitForChild("Net")
local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RegisterHit = Net:WaitForChild("RE/RegisterHit")

local SUCCESS_FLAGS, COMBAT_REMOTE_THREAD = pcall(function()
    return require(Modules.Flags).COMBAT_REMOTE_THREAD or false
end)
local SUCCESS_HIT, HIT_FUNCTION = pcall(function()
    return (getmenv or getsenv)(Net)._G.SendHitsToServer
end)

local function SendAttack(Cooldown, Args)
    RegisterAttack:FireServer(Cooldown)
    if SUCCESS_FLAGS and COMBAT_REMOTE_THREAD and SUCCESS_HIT and HIT_FUNCTION then
        HIT_FUNCTION(Args[1], Args[2])
    else
        RegisterHit:FireServer(Args[1], Args[2])
    end
end

local FastAttack = {
    Distance = 60,
    Debounce = 0,
    TargetMobInstance = nil,
    TargetMobName = nil
}

function FastAttack:IsEntityAlive(entity)
    local humanoid = entity and entity:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

function FastAttack:SetTargetMob(mob)
    if typeof(mob) == "string" then
        self.TargetMobName = mob
        self.TargetMobInstance = nil
    elseif typeof(mob) == "Instance" and mob.Parent == Workspace.Enemies and self:IsEntityAlive(mob) then
        self.TargetMobInstance = mob
        self.TargetMobName = mob.Name
    else
        self.TargetMobInstance = nil
        self.TargetMobName = nil
    end
end

function FastAttack:GetTargets()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local targets = {}
    if self.TargetMobInstance and self:IsEntityAlive(self.TargetMobInstance) then
        if (hrp.Position - self.TargetMobInstance.HumanoidRootPart.Position).Magnitude <= self.Distance then
            table.insert(targets, self.TargetMobInstance)
        end
    end
    if self.TargetMobName then
        for _, v in pairs(Workspace.Enemies:GetChildren()) do
            if v.Name == self.TargetMobName and self:IsEntityAlive(v) and v:FindFirstChild("HumanoidRootPart") then
                if (hrp.Position - v.HumanoidRootPart.Position).Magnitude <= self.Distance then
                    if not table.find(targets, v) then
                        table.insert(targets, v)
                    end
                end
            end
        end
    end
    for _, v in pairs(Workspace.Enemies:GetChildren()) do
        if self:IsEntityAlive(v) and v:FindFirstChild("HumanoidRootPart") then
            local dist = (hrp.Position - v.HumanoidRootPart.Position).Magnitude
            if dist <= self.Distance then
                if not table.find(targets, v) then
                    table.insert(targets, v)
                end
            end
        end
    end
    return targets
end

function FastAttack:Attack()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local weapon = character:FindFirstChildOfClass("Tool")
    if not weapon then return end
    local currentTime = tick()
    if currentTime - self.Debounce < 0.1 then return end
    self.Debounce = currentTime
    local targets = self:GetTargets()
    if #targets == 0 then return end
    local hitTargets = {}
    for _, target in ipairs(targets) do
        local rootPart = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Head")
        if rootPart then
            table.insert(hitTargets, {target, rootPart})
        end
    end
    if #hitTargets > 0 then
        pcall(function()
            SendAttack(0.1, {hitTargets[1][2], hitTargets})
        end)
    end
end

function Running(oc)
    if type(oc) == "function" then
        return oc()
    end
    return oc
end

local Elites = {
    "Deandre",
    "Urban",
    "Diablo"
}

function KillBoss(mobs, death, xxx, hop, kk, cc)
    local targets = typeof(mobs) == "table" and mobs or {mobs}
    local function IsRunning()
        if type(kk) == "function" then
            return kk()
        end
        return kk
    end
    for _, bossName in ipairs(targets) do
        pcall(function()
            if not IsRunning() then return end
            if CheckBoss(bossName) then
                local boss = CheckBoss(bossName)
                local IsBoss = boss:GetAttribute("IsBoss") or boss.Humanoid.DisplayName:find("Boss") or boss.Name == "Core" or table.find(Elites, boss.Name)
                repeat
                    boss = CheckBoss(bossName)
                    if hop and IsPlayerNearby(boss.HumanoidRootPart.Position, 100) then Hop() return end
                    AutoHaki()
                    if _G.SelectFarm_Mastery == "Blox Fruit" then
                         UseSkill("Blox Fruit", true)
                    elseif _G.SelectFarm_Mastery == "Gun" then
                         UseSkill("Gun", true)
                    else
                         EquipWeapon(_G.SelectWeapon)
                    end 
                    if not IsBoss and _G.Bring_Mobs then BringMob(boss.Name, boss.HumanoidRootPart.Position, 350, false) end
                    if bossName == "Cake Prince" or bossName == "Dough King" then
                        local worldOrigin = game:GetService("Workspace")["_WorldOrigin"]
                        if worldOrigin:FindFirstChild("Ring") or worldOrigin:FindFirstChild("Fist") or worldOrigin:FindFirstChild("MochiSwirl") then
                            TP1(boss.HumanoidRootPart.CFrame * CFrame.new(0, -40, 0))
                        else
                            TP1(boss.HumanoidRootPart.CFrame * CFrame.new(10, 20, 10))
                        end
                    else
                        TP1(boss.HumanoidRootPart.CFrame * CFrame.new(5, 30, 10))
                    end
                    FastAttack:SetTargetMob(boss)
                    task.wait(0.1)
                until not CheckBoss(bossName) or not IsRunning() or ((xxx == true) and (xxx() == true)) or ((cc == true) and (cc() == true))
                if not IsRunning() then StopTween() return end
                if death then
                    Death(0.1)
                end
            end
        end)
        if not IsRunning() then break end
    end
end



local function n(s) return (s or ""):gsub("%s+",""):lower() end

function getspawn(Name, mid)
	for _,m in pairs(typeof(Name)=="table" and Name or {Name}) do
		local p,c,first = Vector3.zero,0,nil
		m = n(m)
		for _,v in pairs(workspace.EnemySpawns:GetChildren()) do
			if n(v.Name)==m then
				local cf=v:GetPivot()
				first=first or cf
				p+=cf.Position
				c+=1
			end
		end
		if c>0 then return mid and CFrame.new(p/c) or first end
	end
end

function KillMobList(Name, gay, mid, baka, cc, cmm)
    local N = typeof(Name)=="table" and Name or {Name}
    local HasBoss=false
    if not Running(baka) then return end
    for _,m in ipairs(N) do
        if CheckBoss(m) then HasBoss=true break end
    end
    for _,mob in ipairs(N) do
        if HasBoss then
            if CheckBoss(mob) then
                if not Running(baka) then return end
                KillBoss(mob,false,gay,false,baka,cc)
            end
        elseif Running(cmm) then
            Hop()
        else
            local s=getspawn(mob, mid)
            if s and GetDistance(CFrame.new(s.Position))>30 then
                repeat
                    if not Running(baka) then return end
                    TP1(CFrame.new(s.Position+Vector3.new(0,20,0)))
                    task.wait(0.1)
                until GetDistance(CFrame.new(s.Position))<=30 or HasBoss or not Running(baka)
                task.wait(1)
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            FastAttack:Attack()
        end)
    end
end)
local Tabel = {}
local function getLvFromName(name)
    return tonumber(
        name:match("Lv%.?%s*(%d+)")
        or name:match("%[(%d+)%]")
        or name:match("(%d+)")
    ) or 0
end

local function cleanName(name)
    return name
        :gsub("Lv%.?%s*%d+", "")
        :gsub("[%[%]]", "")
        :gsub("%d+", "")
        :gsub("%s+", "")
end

function createEnemySpawns()
    local EnemySpawns = workspace:FindFirstChild("EnemySpawns")
    if not EnemySpawns then
        EnemySpawns = Instance.new("Folder")
        EnemySpawns.Name = "EnemySpawns"
        EnemySpawns.Parent = workspace
    end

    local existing = {}
    for _, v in ipairs(EnemySpawns:GetChildren()) do
        existing[v.Name] = v
    end

    local function process(item)
        local part =
            item:IsA("Part") and item
            or item:IsA("Model") and item:FindFirstChild("HumanoidRootPart")

        if not part then return end

        local name = cleanName(item.Name)
        local lv = item:GetAttribute("Level") or part:GetAttribute("Level")
        lv = tonumber(lv) or getLvFromName(item.Name)

        local spawn = existing[name]
        if not spawn then
            spawn = part:Clone()
            spawn.Name = name
            spawn.Anchored = true
            spawn.Parent = EnemySpawns
        end

        spawn:SetAttribute("Lv", lv)
        existing[name] = nil
    end

    for _, v in ipairs(workspace._WorldOrigin.EnemySpawns:GetChildren()) do process(v) end
    for _, v in ipairs(workspace.Enemies:GetChildren()) do process(v) end
    for _, v in ipairs(game.ReplicatedStorage:GetChildren()) do process(v) end

    for _, v in pairs(existing) do
        v:Destroy()
    end
end


wait(2) 
createEnemySpawns()
function Check_Sub(p)
    if not p then p = game:GetService("Players").LocalPlayer.Name end
    local pl = game.Players:FindFirstChild(p)
    if not pl then return false end
    local loc = pl:GetAttribute("CurrentLocation")
    return loc == "Submerged Island" or loc == "Sealed Cavern"
end

function MaterialsNeed()
    if GetCountMaterials("Demonic Wisp") < 20 then
        return "Demonic Soul", World3
    elseif GetCountMaterials("Vampire Fang") < 20 then
        return "Vampire", World2
    elseif GetCountMaterials("Dark Fragment") < 2 then
        return "Darkbeard", World2
    end
    return true
end

local function GetWorldId(w)
    if w == World1 then return 1 end
    if w == World2 then return 2 end
    if w == World3 then return 3 end
end

spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local Mobs, World = MaterialsNeed()
            if Mobs == true then return end

            if Check_Sub() then
                TeleportWorld(1)
                return
            end

            if Mobs ~= "Darkbeard" then
                if World then
                    KillMobList({Mobs}, MaterialsNeed, true)
                else
                    TeleportWorld(GetWorldId(World))
                end
            else
                if World then
                    if CheckBoss(Mobs) then
                        KillMobList({Mobs}, MaterialsNeed, true)
                    elseif CheckBackPack({"Fist of darkness"}) then
                        local Detection = workspace.Map.DarkbeardArena.Summoner.Detection
                        TP1(Detection.CFrame)
                        if GetDistance(Detection.Position) <= 200 then
                            firetouchinterest(Detection, HumanoidRootPart, 0)
                            task.wait(0.2)
                            firetouchinterest(Detection, HumanoidRootPart, 1)
                        end
                    else
                        if getNearestChest() then
                            PickChest(getNearestChest())
                        else
                            Hop()
                        end
                    end
                else
                    TeleportWorld(GetWorldId(World))
                end
            end
        end)
    end
end)

local MeleeNPC = {
    ["Black Leg"] = "Dark Step Teacher",
    ["Fishman Karate"] = "Water Kung",
    ["Electro"] = "Mad Scientist",
    ["Dragon Claw"] = "Sabi",
    ["Superhuman"] = "Martial Arts Master",
    ["Sharkman Karate"] = "Sharkman Teacher",
    ["Death Step"] = "Phoeyu, the Reformed",
    ["Dragon Talon"] = "Uzoth",
    ["Godhuman"] = "Ancient Monk",
    ["Electric Claw"] = "Previous Hero",
    ["Sanguine Art"] = "Shafi"
}

local BuyCmd = {
    ["Black Leg"] = "BuyBlackLeg",
    ["Fishman Karate"] = "BuyFishmanKarate",
    ["Electro"] = "BuyElectro",
    ["Dragon Claw"] = function()
        local ok = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward","DragonClaw","1") == 1
        game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward","DragonClaw","2")
        return ok and 1 or 0
    end,
    ["Superhuman"] = "BuySuperhuman",
    ["Sharkman Karate"] = "BuySharkmanKarate",
    ["Death Step"] = "BuyDeathStep",
    ["Dragon Talon"] = "BuyDragonTalon",
    ["Godhuman"] = "BuyGodhuman",
    ["Electric Claw"] = "BuyElectricClaw"
    ["Sanguine Art"] = "BuySanguineArt" 
}

function Load()
    if not isfile(game.Players.LocalPlayer.Name.."ZeroXHub_MeleeCheck.txt") then writefile(game.Players.LocalPlayer.Name.."ZeroXHub_MeleeCheck.txt", "{}") end
    return game:GetService("HttpService"):JSONDecode(readfile(game.Players.LocalPlayer.Name.."ZeroXHub_MeleeCheck.txt"))
end

function Save(data)
    writefile(game.Players.LocalPlayer.Name.."ZeroXHub_MeleeCheck.txt", game:GetService("HttpService"):JSONEncode(data))
end

function GetMeleeMastery(name)
    local c = game.Players.LocalPlayer.Character
    local b = game.Players.LocalPlayer.Backpack
    if c:FindFirstChild(name) then return c[name].Level.Value end
    if b:FindFirstChild(name) then return b[name].Level.Value end
    return 0
end

function Check_Melee(name)
    return Load()[name] or {Have = false, Mastery = 0}
end

function GetMasData(name)
    if Load()[name] and (Load()[name].Have or (Load()[name].Mastery and Load()[name].Mastery > 0)) then
        return true
    end
    return false
end

function Buy_Melee(name)
    local lp = game.Players.LocalPlayer
    local success = nil
    print(MeleeNPC[name])
    repeat
        local Model
        for _, v in pairs(game:GetService("Workspace").NPCs:GetChildren()) do
            if string.find(v.Name, MeleeNPC[name]) then
                Model = v
                break
            end
        end
        if not Model then
            for _, v in pairs(game:GetService("ReplicatedStorage").NPCs:GetChildren()) do
                if string.find(v.Name, MeleeNPC[name]) then
                    Model = v
                    repeat task.wait(0.1) TP1(CFrame.new(Model:GetPivot().Position)) until (lp.Character:FindFirstChild("HumanoidRootPart").Position - Model:GetPivot().Position).Magnitude <= 10
                    break
                end
            end
        else
        print(Model)
            if (lp.Character:FindFirstChild("HumanoidRootPart").Position - Model:GetPivot().Position).Magnitude > 10 then
                repeat task.wait(0.1) TP1(CFrame.new(Model:GetPivot().Position)) until (lp.Character:FindFirstChild("HumanoidRootPart").Position - Model:GetPivot().Position).Magnitude <= 10
            end
        end
        local remote = BuyCmd[name]
        if type(remote) == "string" then
            local r1 = game.ReplicatedStorage.Remotes.CommF_:InvokeServer(remote, true)
            local r2 = game.ReplicatedStorage.Remotes.CommF_:InvokeServer(remote)
            success = (r1 == 1 or r1 == 2 or r2 == 1 or r2 == 2) and 1 or 0
        else
            success = remote()
        end
        if success == 0 then
        local data = Load()
        data[name] = {Have=false,Mastery=1}
        Save(data)
        return false
        end
        if success == 1 then
        local data = Load()
        data[name] = {Have = GetMeleeMastery(name) >= 1, Mastery = GetMeleeMastery(name)}
        Save(data)
        end
        task.wait(0.1)
    until GetMasData(name)
end

spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local Mobs, World = MaterialsNeed()
            if Mobs == true then
                if Check_Sub() then
                    TeleportWorld(1)
                elseif not World3 then
                    TeleportWorld(3)
                end
                Buy_Melee("Sanguine Art")
            end
        end)
    end
end)
    -- ════════════════════════════════════════
end

-- ── Anti-Spy: Xóa reference sau khi dùng xong ──
task.delay(0, function()
    main()
    -- Xóa các biến nhạy cảm khỏi global scope sau khi chạy xong
    _API_URL    = nil
    _API_SECRET = nil
    _s          = nil
    _url_parts  = nil
    _call_api   = nil
    script_key  = nil
end)
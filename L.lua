-- ═══════════════════════════════════════════════════════════
--  LUMACC AUTO-FARM v4.6 (MOBILE & DELTA EDITION)
--  + Фикс зависаний HTTP (Timeout)
--  + Авто-перезапуск при телепорте (queue_on_teleport)
--  + Плавающая кнопка для мобилок
-- ═══════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local HttpService      = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════
--  DELTA MOBILE FIX (HTTP Timeout & Teleport)
-- ═══════════════════════════════════════════════════════════
local HTTP_TIMEOUT = 5 
local _rawHttpFn = nil

pcall(function() if request then _rawHttpFn = request end end)
pcall(function() if not _rawHttpFn and http_request then _rawHttpFn = http_request end end)
pcall(function() if not _rawHttpFn and syn and syn.request then _rawHttpFn = syn.request end end)

if _rawHttpFn then
    local function safeRequest(opts)
        local result = nil
        local finished = false
        task.spawn(function()
            local ok, res = pcall(_rawHttpFn, opts)
            if ok and type(res) == "table" then result = res end
            finished = true
        end)
        local t0 = tick()
        while not finished and (tick() - t0) < HTTP_TIMEOUT do
            task.wait(0.1)
        end
        if not finished then
            return {StatusCode = 0, Body = "", Headers = {}} 
        end
        return result
    end
    if request then request = function(opts) return safeRequest(opts) end end
    if http_request then http_request = function(opts) return safeRequest(opts) end end
    if syn and syn.request then syn.request = function(opts) return safeRequest(opts) end end
end

-- Функция для перезапуска скрипта после телепорта (смены сервера)
if queue_on_teleport then
    queue_on_teleport([[
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Laxess/LUMACC/refs/heads/main/LUMACC.lua'))()
    ]])
end
-- ═══════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════
--  AUTH & HWID
-- ═══════════════════════════════════════════════════════════
local AUTH_FILE, INSTALL_FILE = "lumacc_auth.dat", "lumacc_install.dat"

local VALID_KEYS = {
    [string.char(76, 85, 77, 65, 67, 67, 45, 86, 73, 80, 45, 49, 49, 49, 49)] = { expires = "Never", tier = "VIP" },
    [string.char(76, 85, 77, 65, 67, 67, 45, 80, 82, 79, 45, 50, 50, 50, 50)] = { expires = "Never", tier = "PRO" },
    [string.char(76, 85, 77, 65, 67, 67, 45, 71, 79, 68, 45, 51, 51, 51, 51)] = { expires = "Never", tier = "GOD" },
    [string.char(76, 85, 77, 65, 67, 67, 45, 85, 76, 84, 82, 65, 45, 52, 52, 52, 52)] = { expires = "Never", tier = "ULTRA" },
    [string.char(76, 85, 77, 65, 67, 67, 45, 65, 68, 77, 73, 78, 45, 53, 53, 53, 53)] = { expires = "Never", tier = "ADMIN" },
}

local function checkKey(input)
    for key, data in pairs(VALID_KEYS) do
        if input == key then return true, data end
    end
    return false, nil
end

local function getHWID()
    if gethwid then local ok,h=pcall(gethwid); if ok and h and tostring(h)~="" then return tostring(h) end end
    if syn and syn.get_hwid then local ok,h=pcall(syn.get_hwid); if ok and h and tostring(h)~="" then return tostring(h) end end
    if get_hwid then local ok,h=pcall(get_hwid); if ok and h and tostring(h)~="" then return tostring(h) end end
    if isfile and isfile(INSTALL_FILE) then
        local ok,c=pcall(readfile,INSTALL_FILE); if ok and c and #c>0 then return c end
    end
    local id = tostring(LP.UserId).."-"..tostring(math.random(1e8,1e9-1)).."-"..tostring(os.time())
    if writefile then pcall(writefile, INSTALL_FILE, id) end
    return id
end

local function sendHWIDLog(manualKey)
    local webhookUrl = "https://discord.com/api/webhooks/1533557893591207998/b5kUc2KzWvBRyx0iD1pPT0jez5nFRRhwbt6zHXwqjf44OhZLkSgYMim3W2VaamJITKdA"
    local hwid = getHWID()
    local username = LP.Name
    local userId = tostring(LP.UserId)
    local executor = "Unknown"
    
    if identifyexecutor then
        local ok, name = pcall(identifyexecutor)
        if ok then executor = tostring(name) end
    elseif syn then executor = "Synapse"
    elseif krnl then executor = "Krnl"
    elseif fluxus then executor = "Fluxus" end

    local keyInfo, tierInfo, expireInfo = "None", "None", "None"
    local activeKey = manualKey
    
    if not activeKey then
        local ok, c = pcall(readfile, AUTH_FILE)
        if ok and c and #c > 0 then
            if base64 and base64.decode then
                local decoded = base64.decode(c)
                if decoded then 
                    local _, k = decoded:match("^([^|]+)|(.+)$")
                    if k then activeKey = k end 
                end
            else
                local _, k = c:match("^([^|]+)|(.+)$")
                if k then activeKey = k end
            end
        end
    end

    if activeKey then
        local isValid, data = checkKey(activeKey)
        if isValid then
            keyInfo = activeKey; tierInfo = data.tier; expireInfo = data.expires
        else
            keyInfo = activeKey .. " (Invalid)"
        end
    end

    local data = {
        ["content"] = "**LUMACC Injected**",
        ["embeds"] = {{
            ["title"] = "🔐 HWID & Key Log",
            ["color"] = 3447003,
            ["fields"] = {
                {["name"] = "User", ["value"] = string.format("%s (@%s)", username, LP.DisplayName), ["inline"] = true},
                {["name"] = "User ID", ["value"] = userId, ["inline"] = true},
                {["name"] = "Executor", ["value"] = executor, ["inline"] = true},
                {["name"] = "HWID", ["value"] = "```" .. tostring(hwid) .. "```", ["inline"] = false},
                {["name"] = "Key", ["value"] = "```" .. keyInfo .. "```", ["inline"] = true},
                {["name"] = "Tier", ["value"] = tierInfo, ["inline"] = true},
                {["name"] = "Expires", ["value"] = expireInfo, ["inline"] = true}
            },
            ["footer"] = {["text"] = "LUMACC Security System"}
        }}
    }
    
    local jsonData = HttpService:JSONEncode(data)
    local req = http_request or request or syn.request or (syn and syn.request) or http.request
    
    if req then
        pcall(function()
            req({
                Url = webhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData
            })
        end)
    else
        pcall(function() HttpService:PostAsync(webhookUrl, jsonData) end)
    end
end

local function enc(s) if base64 and base64.encode then return base64.encode(s) end return s end
local function dec(s)
    if base64 and base64.decode then local ok,r=pcall(base64.decode,s); if ok then return r end end
    return s
end
local function saveAuth(key)
    if not writefile then return false end
    return pcall(writefile, AUTH_FILE, enc(getHWID().."|"..key))
end
local function loadAuth()
    if not isfile or not readfile or not isfile(AUTH_FILE) then return nil end
    local ok,c=pcall(readfile,AUTH_FILE); if not ok or not c or #c==0 then return nil end
    local h,k = dec(c):match("^([^|]+)|(.+)$"); if not h or not k then return nil end
    return {hwid=h, key=k}
end
local function clearAuth()
    if delfile and isfile and isfile(AUTH_FILE) then pcall(delfile, AUTH_FILE) end
end
local function tryAutoLogin()
    local s = loadAuth(); if not s then return false end
    if s.hwid ~= getHWID() then clearAuth(); return false end
    local isValid, data = checkKey(s.key)
    if not isValid then clearAuth(); return false end
    return true
end

if tryAutoLogin() then
    task.spawn(function() sendHWIDLog() end)
end

-- ═══════════════════════════════════════════════════════════
--  KEY SCREEN (Адаптирован под мобилки)
-- ═══════════════════════════════════════════════════════════
local AUTO_LOGGED = tryAutoLogin()
local unlockEvent = Instance.new("BindableEvent")

if not AUTO_LOGGED then
    local failedAttempts, lockoutUntil, isSubmitting = 0, 0, false
    local blur = Instance.new("BlurEffect"); blur.Size = 0; blur.Parent = Lighting
    TweenService:Create(blur, TweenInfo.new(0.6), {Size = 24}):Play()

    local kg = Instance.new("ScreenGui")
    kg.Name="LUMACC_Key"; kg.ResetOnSpawn=false; kg.IgnoreGuiInset=true
    kg.DisplayOrder=2147483647; kg.Parent=PlayerGui

    local backdrop = Instance.new("Frame")
    backdrop.Size=UDim2.fromScale(1,1); backdrop.BackgroundColor3=Color3.new(0,0,0)
    backdrop.BackgroundTransparency=1; backdrop.BorderSizePixel=0; backdrop.Parent=kg
    TweenService:Create(backdrop, TweenInfo.new(0.6), {BackgroundTransparency=0.4}):Play()

    local card = Instance.new("Frame")
    card.Size=UDim2.fromOffset(420,360)
    card.Position=UDim2.fromScale(0.5,0.5)
    card.AnchorPoint=Vector2.new(0.5,0.5)
    card.BackgroundColor3=Color3.fromRGB(18,18,24)
    card.BorderSizePixel=0; card.Parent=kg
    Instance.new("UICorner", card).CornerRadius=UDim.new(0,18)
    
    local cardScale = Instance.new("UIScale")
    cardScale.Parent = card
    if UserInputService.TouchEnabled then
        cardScale.Scale = 0.7
    else
        cardScale.Scale = 0.3
    end

    local cardGrad = Instance.new("UIGradient")
    cardGrad.Color=ColorSequence.new(Color3.fromRGB(20,20,30),Color3.fromRGB(35,25,50))
    cardGrad.Rotation=135; cardGrad.Parent=card
    local cardStroke=Instance.new("UIStroke")
    cardStroke.Color=Color3.fromRGB(0,160,255); cardStroke.Thickness=1.5
    cardStroke.Transparency=0.4; cardStroke.Parent=card
    
    if not UserInputService.TouchEnabled then
        TweenService:Create(cardScale,TweenInfo.new(0.6,Enum.EasingStyle.Back),{Scale=1}):Play()
    end

    task.spawn(function()
        while card.Parent do
            TweenService:Create(cardStroke,TweenInfo.new(1.8),{Transparency=0}):Play()
            task.wait(1.8)
            TweenService:Create(cardStroke,TweenInfo.new(1.8),{Transparency=0.5}):Play()
            task.wait(1.8)
        end
    end)

    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,0,0,60); title.Position=UDim2.new(0,0,0,30)
    title.BackgroundTransparency=1; title.Text="LUMACC"
    title.Font=Enum.Font.GothamBlack; title.TextSize=44
    title.TextColor3=Color3.new(1,1,1); title.Parent=card
    local tg=Instance.new("UIGradient")
    tg.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(0,200,255)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(180,100,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,100,180)),
    }
    tg.Parent=title
    task.spawn(function()
        local o=0
        while title.Parent do o=(o+0.005)%1; tg.Offset=Vector2.new(o,0); task.wait(0.03) end
    end)

    local sub=Instance.new("TextLabel")
    sub.Size=UDim2.new(1,0,0,18); sub.Position=UDim2.new(0,0,0,92)
    sub.BackgroundTransparency=1; sub.Text="AUTO-FARM  •  MOBILE"
    sub.Font=Enum.Font.GothamBold; sub.TextSize=11
    sub.TextColor3=Color3.fromRGB(110,110,130); sub.Parent=card

    local keyInput=Instance.new("TextBox")
    keyInput.Size=UDim2.new(1,-80,0,52); keyInput.Position=UDim2.new(0,40,0,150)
    keyInput.BackgroundColor3=Color3.fromRGB(28,28,38)
    keyInput.PlaceholderText="Enter license key..."; keyInput.PlaceholderColor3=Color3.fromRGB(75,75,95)
    keyInput.Text=""; keyInput.TextColor3=Color3.new(1,1,1)
    keyInput.Font=Enum.Font.Code; keyInput.TextSize=18
    keyInput.ClearTextOnFocus=false; keyInput.Parent=card
    Instance.new("UICorner",keyInput).CornerRadius=UDim.new(0,10)
    local inputStroke=Instance.new("UIStroke")
    inputStroke.Color=Color3.fromRGB(60,60,80); inputStroke.Thickness=1.5; inputStroke.Parent=keyInput
    keyInput.Focused:Connect(function() TweenService:Create(inputStroke,TweenInfo.new(0.2),{Color=Color3.fromRGB(0,160,255),Thickness=2}):Play() end)
    keyInput.FocusLost:Connect(function() TweenService:Create(inputStroke,TweenInfo.new(0.2),{Color=Color3.fromRGB(60,60,80),Thickness=1.5}):Play() end)

    local submitBtn=Instance.new("TextButton")
    submitBtn.Size=UDim2.new(1,-80,0,50); submitBtn.Position=UDim2.new(0,40,0,216)
    submitBtn.BackgroundColor3=Color3.fromRGB(0,160,255); submitBtn.Text="UNLOCK"
    submitBtn.Font=Enum.Font.GothamBold; submitBtn.TextSize=15
    submitBtn.TextColor3=Color3.new(1,1,1); submitBtn.AutoButtonColor=false
    submitBtn.BorderSizePixel=0; submitBtn.Parent=card
    Instance.new("UICorner",submitBtn).CornerRadius=UDim.new(0,10)
    local sg=Instance.new("UIGradient")
    sg.Color=ColorSequence.new(Color3.fromRGB(0,160,255),Color3.fromRGB(120,80,255)); sg.Parent=submitBtn

    local status=Instance.new("TextLabel")
    status.Size=UDim2.new(1,-80,0,20); status.Position=UDim2.new(0,40,0,280)
    status.BackgroundTransparency=1; status.Font=Enum.Font.GothamMedium
    status.TextSize=12; status.TextColor3=Color3.fromRGB(150,150,170); status.Parent=card

    local function submitKey()
        if isSubmitting then return end
        if os.clock()<lockoutUntil then
            status.Text=string.format("⏳ Wait %.0fs", lockoutUntil-os.clock())
            status.TextColor3=Color3.fromRGB(255,200,60); return
        end
        if keyInput.Text=="" then
            status.Text="⚠ Enter a key"; status.TextColor3=Color3.fromRGB(255,200,60); return
        end
        isSubmitting=true
        
        local isValid, keyData = checkKey(keyInput.Text)
        if isValid then
            saveAuth(keyInput.Text)
            status.Text = "✓ GRANTED (" .. keyData.tier .. ")"; status.TextColor3=Color3.fromRGB(0,255,120)
            task.wait(0.7)
            
            task.spawn(function() sendHWIDLog(keyInput.Text) end)
            
            if not UserInputService.TouchEnabled then
                TweenService:Create(cardScale,TweenInfo.new(0.5,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Scale=0}):Play()
            end
            TweenService:Create(backdrop,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play()
            TweenService:Create(blur,TweenInfo.new(0.5),{Size=0}):Play()
            task.wait(0.6); kg:Destroy()
            task.delay(0.5,function() blur:Destroy() end)
            unlockEvent:Fire()
        else
            failedAttempts=failedAttempts+1
            if failedAttempts>=3 then lockoutUntil=os.clock()+5; failedAttempts=0; status.Text="⏳ Locked 5s"
            else status.Text=string.format("✗ Invalid (%d/3)",failedAttempts) end
            status.TextColor3=Color3.fromRGB(255,80,80); 
        end
        isSubmitting=false
    end
    submitBtn.MouseButton1Click:Connect(submitKey)
    keyInput.FocusLost:Connect(function(e) if e then submitKey() end end)
    task.delay(0.8,function() pcall(function() keyInput:CaptureFocus() end) end)
    unlockEvent.Event:Wait()
end

-- ═══════════════════════════════════════════════════════════
--  AUTO-FARM
-- ═══════════════════════════════════════════════════════════
function AUTO_FARM()
    local CFG = {
        flyEnabled      = true,
        noclipEnabled   = true,
        aimbotEnabled   = true,
        triggerbotEnabled = true,
        useMouseEmu     = true,
        shieldCheck     = true,
        forceUnder      = false,
        shieldDepth     = 2,
        flySpeed        = 240,
        
        orbitEnabled    = true,
        orbitSpeed      = 900,
        orbitMinRadius  = 4,
        orbitMaxRadius  = 9,
        orbitVertRange  = 4,
        
        backDistance    = 4.5,
        aboveHeight     = 8.0,
        smoothing       = 0.25,
        fireRange       = 30.0,
        fireRate        = 0.05,
        aimPart         = "Head",
        targetLockEnabled   = true,
        targetLockTeamCheck = true,
        targetLockFOV       = 160,
        antiAfk             = true,
        autoPick            = true,
        autoPlayAgain       = true,
        espHighlight        = true,
        espSkeleton         = true,
        espHead             = true,
    }
    local WANTED_WEAPONS={"Assault Rifle","Handgun","Knife","Grenade"}
    local alreadyPicked,lastPickedTime,clickCooldown={},0,0.25
    local lastPlayAgainClick,PLAY_AGAIN_COOLDOWN=0,3
    local targetHRP=nil
    local flyConn,bodyVel,bodyPos,noclipConn,savedWS=nil,nil,nil,nil,16
    local currentBackVec=Vector3.zero
    local trackedEntities={}
    local unloaded=false
    local flyStateReason="init"
    local orbitAngle=0
    local lastTarget=nil
    local lastShieldLog = 0
    local isShieldTransparent = false
    
    local roundReady = false 

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local currentTargetModel = nil
    local currentShielded = false
    local currentShieldType = nil
    local lastShieldRefresh = 0

    local function getHead(m)
        return m and (m:FindFirstChild("Head") or m:FindFirstChild("PhysicalHitboxHead") or m:FindFirstChild("HitboxHead") or m:FindFirstChild("SlideHitbox"))
    end
    local function getBody(m)
        return m and (m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m:FindFirstChild("PhysicalHitboxBody") or m:FindFirstChild("HitboxBody") or m:FindFirstChild("HumanoidRootPart"))
    end
    local function getAimPart(m) return CFG.aimPart=="Head" and getHead(m) or getBody(m) end
    
    local function isTeammate(m)
        if not m then return false end
        if m:FindFirstChild("HumanoidRootPart") and m.HumanoidRootPart:FindFirstChild("TeammateLabel") then return true end
        local p=Players:GetPlayerFromCharacter(m)
        return p and p~=LP and p.Team and LP.Team and p.Team==LP.Team
    end
    
    local function setLocalTransparency(state)
        local char = LP.Character
        if not char then return end
        if isShieldTransparent == state then return end
        isShieldTransparent = state
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.LocalTransparencyModifier = state and 1 or 0
            end
        end
    end

    local function hasShield(char)
        if not char then return false, nil end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false, nil end

        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("ForceField") then return true, "ForceField" end
            local lowName = obj.Name:lower()
            if lowName:find("shield") or lowName:find("bubble") then
                if obj:IsA("BoolValue") and obj.Value then return true, "BoolValue: "..obj.Name end
                if obj:IsA("BasePart") and obj.Transparency < 1 then return true, "Part: "..obj.Name end
            end
        end

        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj ~= char and obj:IsA("BasePart") then
                if (obj.Position - hrp.Position).Magnitude < 15 then
                    local lname = obj.Name:lower()
                    if lname:find("sdsdsd") or lname:find("panel") or lname:find("shield") or lname:find("bubble") then
                        return true, "Workspace: "..obj.Name
                    end
                end
            end
        end
        return false, nil
    end

    -- ФИКС СТРЕЛЬБЫ ДЛЯ МОБИЛОК
    local function fireOnce()
        local char = LP.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function() tool:Activate() end)
            end
        end
        
        if CFG.useMouseEmu and VirtualInputManager then
            local p = Camera.ViewportSize / 2
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0); task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
            end)
        end
    end
    
    local function findNearestEnemy()
        local myChar = LP.Character
        if not myChar then return nil end
        local myHRP = myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then return nil end
        
        local best, dist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and not isTeammate(p.Character) then
                    local targetPos = getAimPart(p.Character)
                    local pos = targetPos and targetPos.Position or (p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart.Position)
                    if pos then
                        local d = (pos - myHRP.Position).Magnitude
                        if d < dist then dist, best = d, p end
                    end
                end
            end
        end
        return best
    end

    task.spawn(function()
        while not unloaded do
            local p = findNearestEnemy()
            currentTargetModel = p and p.Character or nil
            targetHRP = currentTargetModel and currentTargetModel:FindFirstChild("HumanoidRootPart") or nil
            
            local playerCount = #Players:GetPlayers()
            
            if playerCount > 4 then
                flyStateReason = "server > 4 players"
            elseif playerCount <= 1 then
                flyStateReason = "empty server"
            elseif not p then
                flyStateReason = "no enemies"
            else
                flyStateReason = "active"
            end
            task.wait(0.1)
        end
    end)

    -- NOCLIP
    noclipConn = RunService.Stepped:Connect(function()
        if not CFG.noclipEnabled or not roundReady or #Players:GetPlayers() > 4 then return end
        local c=LP.Character; if not c then return end
        for _,p in ipairs(c:GetChildren()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end
        end
    end)

    -- FLY
    local function startFly()
        if flyConn then return end
        local c=LP.Character; if not c then return end
        local hrp=c:FindFirstChild("HumanoidRootPart")
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then return end
        savedWS=hum.WalkSpeed; if savedWS<=0 then savedWS=16 end
        hum.PlatformStand=true; hum.WalkSpeed=0
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        if bodyVel then bodyVel:Destroy() end
        bodyVel=Instance.new("BodyVelocity")
        bodyVel.MaxForce=Vector3.new(1e5,1e5,1e5)
        bodyVel.Velocity=Vector3.zero; bodyVel.Parent=hrp
        currentBackVec=-hrp.CFrame.LookVector*CFG.backDistance
        orbitAngle=0
        
        flyConn=RunService.Heartbeat:Connect(function(dt)
            if not CFG.flyEnabled or not roundReady or #Players:GetPlayers() > 4 then return end
            
            local tgt = currentTargetModel
            local th = targetHRP
            if not tgt or not th or not th.Parent then 
                if bodyVel then bodyVel.Velocity=Vector3.zero end 
                return 
            end
            
            local myChar=LP.Character
            local myHRP=myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHRP then if bodyVel then bodyVel.Velocity=Vector3.zero end return end
            if tgt ~= lastTarget then lastTarget=tgt; orbitAngle=0 end
            
            local aimPart = getAimPart(tgt) or th
            local orbitCenter = th.Position
            
            if aimPart and (th.Position - aimPart.Position).Magnitude > 2.5 then
                orbitCenter = aimPart.Position
            end
            
            if os.clock() - lastShieldRefresh > 0.5 then
                currentShielded, currentShieldType = hasShield(tgt)
                lastShieldRefresh = os.clock()
            end
            
            if CFG.forceUnder or (CFG.shieldCheck and currentShielded) then
                if bodyVel then bodyVel.Velocity=Vector3.zero end
                if not bodyPos then
                    bodyPos = Instance.new("BodyPosition")
                    bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bodyPos.P = 10000
                    bodyPos.D = 1000
                    bodyPos.Parent = myHRP
                end
                bodyPos.Position = th.Position - Vector3.new(0, CFG.shieldDepth, 0)
                flyStateReason = "under (" .. (currentShieldType or "manual") .. ")"
                setLocalTransparency(true)
                return
            else
                if bodyPos then bodyPos:Destroy(); bodyPos=nil end
                setLocalTransparency(false)
            end

            if not currentTargetModel then
                flyStateReason = "no target"
            elseif CFG.orbitEnabled then
                flyStateReason = "3D orbit"
            else
                flyStateReason = "active"
            end

            if CFG.orbitEnabled then
                orbitAngle = (orbitAngle + CFG.orbitSpeed * dt) % 360
                local rad = math.rad(orbitAngle)
                
                local radius = CFG.orbitMinRadius + (math.sin(rad) * 0.5 + 0.5) * (CFG.orbitMaxRadius - CFG.orbitMinRadius)
                local yOffset = math.sin(rad * 2) * CFG.orbitVertRange
                
                local desiredOffset = Vector3.new(math.cos(rad) * radius, yOffset, math.sin(rad) * radius)
                local targetPos = orbitCenter + desiredOffset
                
                rayParams.FilterDescendantsInstances = {myChar, tgt}
                local ray = Workspace:Raycast(orbitCenter, desiredOffset, rayParams)
                if ray then
                    targetPos = ray.Position - ray.Normal * 1
                end
                
                if bodyVel then bodyVel.Velocity=Vector3.zero end
                myHRP.CFrame=CFrame.lookAt(targetPos, aimPart.Position)
            else
                local desired
                if th.AssemblyLinearVelocity.Magnitude > 2.5 and th.AssemblyLinearVelocity.Unit:Dot(th.CFrame.LookVector) < -0.35 then 
                    desired=Vector3.new(0,CFG.aboveHeight,0)
                else 
                    desired=-th.CFrame.LookVector*CFG.backDistance+Vector3.new(0,0.5,0) 
                end
                currentBackVec=currentBackVec:Lerp(desired,1-CFG.smoothing)
                local tPos=orbitCenter+currentBackVec
                local diff=tPos-myHRP.Position
                if diff.Magnitude>0.05 then bodyVel.Velocity=diff.Unit*math.min(CFG.flySpeed,diff.Magnitude*12)
                else bodyVel.Velocity=Vector3.zero end
                local look=aimPart.Position-myHRP.Position
                if look.Magnitude>0.05 then myHRP.CFrame=CFrame.new(myHRP.Position,myHRP.Position+look.Unit) end
            end
        end)
    end

    local function stopFly()
        if flyConn then flyConn:Disconnect(); flyConn=nil end
        if bodyVel then bodyVel:Destroy(); bodyVel=nil end
        if bodyPos then bodyPos:Destroy(); bodyPos=nil end
        setLocalTransparency(false)
        local c=LP.Character
        if c and c:FindFirstChildOfClass("Humanoid") then c.Humanoid.PlatformStand=false; c.Humanoid.WalkSpeed=savedWS end
        lastTarget=nil
    end

    -- Монитор
    task.spawn(function()
        while not unloaded do
            local alive=false
            local myChar=LP.Character
            if myChar then
                local hum=myChar:FindFirstChildOfClass("Humanoid")
                local hrp=myChar:FindFirstChild("HumanoidRootPart")
                alive=hum and hrp and hum.Health>0
            end
            
            local playerCount = #Players:GetPlayers()
            
            if playerCount > 4 then
                if flyConn then stopFly() end;
                flyStateReason = "server > 4 players"
            elseif not alive then 
                if flyConn then stopFly() end; 
                flyStateReason="dead"
            elseif not targetHRP then 
                if flyConn then stopFly() end; 
            else
                if CFG.flyEnabled and not flyConn and roundReady then startFly() end 
            end
            task.wait(0.5)
        end
    end)

    -- AIMBOT
    RunService:BindToRenderStep("LUMACC_Aim",Enum.RenderPriority.Camera.Value+1,function()
        if not CFG.aimbotEnabled or not roundReady or not currentTargetModel or not currentTargetModel.Parent or #Players:GetPlayers() > 4 then return end
        local aim = getAimPart(currentTargetModel)
        if not aim then return end
        local camPos=Camera.CFrame.Position
        if (camPos-aim.Position).Magnitude>0.5 then 
            Camera.CFrame=CFrame.new(camPos,aim.Position) 
        end
    end)

    -- TRIGGERBOT
    task.spawn(function()
        while not unloaded do
            if CFG.triggerbotEnabled and roundReady and currentTargetModel and currentTargetModel.Parent and #Players:GetPlayers() <= 4 then
                local shielded = false
                if CFG.shieldCheck then
                    shielded, currentShieldType = hasShield(currentTargetModel)
                end
                
                if not shielded then
                    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local aimPart = getAimPart(currentTargetModel)
                    
                    if myHRP and aimPart then
                        local dist = (myHRP.Position - aimPart.Position).Magnitude
                        if dist <= CFG.fireRange then
                            local camPos = Camera.CFrame.Position
                            Camera.CFrame = CFrame.new(camPos, aimPart.Position)
                            
                            local lookDir = Camera.CFrame.LookVector
                            local dirToTarget = (aimPart.Position - camPos).Unit
                            
                            local isLooking = true
                            if not CFG.aimbotEnabled then
                                isLooking = lookDir:Dot(dirToTarget) > 0.95
                            end
                            
                            if isLooking then
                                local trigRay = RaycastParams.new()
                                trigRay.FilterType = Enum.RaycastFilterType.Exclude
                                trigRay.FilterDescendantsInstances = {LP.Character, Camera}
                                local rayRes = Workspace:Raycast(camPos, dirToTarget * dist, trigRay)
                                
                                if not rayRes or rayRes.Instance:IsDescendantOf(currentTargetModel) then
                                    pcall(fireOnce)
                                end
                            end
                        end
                    end
                end
            end
            task.wait(CFG.fireRate)
        end
    end)

    -- ESP
    local R15_BONES={
        {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"}
    }
    local function removeVisuals(m)
        if not m then return end
        local h=m:FindFirstChild("ESPHl"); if h then h:Destroy() end
        local f=m:FindFirstChild("ESPVis"); if f then f:Destroy() end
        trackedEntities[m]=nil
    end
    local function applyVisuals(m)
        if unloaded or m==LP.Character then return end
        local hrp=m:FindFirstChild("HumanoidRootPart")
        local hum=m:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        removeVisuals(m)
        local tm=isTeammate(m)
        local color=tm and Color3.fromRGB(60,160,255) or Color3.fromRGB(255,60,60)
        local hl=Instance.new("Highlight")
        hl.Name="ESPHl"; hl.FillColor=color
        hl.OutlineColor=Color3.new(1,1,1); hl.FillTransparency=0.55
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee=m; hl.Enabled=CFG.espHighlight; hl.Parent=m
        local folder=Instance.new("Folder"); folder.Name="ESPVis"; folder.Parent=m
        local head=getHead(m)
        local sph
        if head then
            sph=Instance.new("SphereHandleAdornment")
            sph.Adornee=head; sph.Radius=1.3
            sph.Color3=Color3.fromRGB(255,230,40)
            sph.Transparency=0.35; sph.AlwaysOnTop=true
            sph.Visible=CFG.espHead; sph.Parent=folder
        end
        local lines={}
        for _,pair in ipairs(R15_BONES) do
            local a,b=m:FindFirstChild(pair[1]),m:FindFirstChild(pair[2])
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                local l=Instance.new("LineHandleAdornment")
                l.Adornee=hrp; l.Color3=Color3.fromRGB(0,255,180)
                l.Thickness=2.2; l.Transparency=0.1; l.AlwaysOnTop=true
                l.Visible=CFG.espSkeleton; l.Parent=folder
                table.insert(lines,{a=a,b=b,adorn=l})
            end
        end
        trackedEntities[m]={lines=lines,head=sph,hrp=hrp,hum=hum}
    end
    local function trackPlayer(p)
        if p==LP or not p.Character then return end
        applyVisuals(p.Character)
        p.CharacterAdded:Connect(function(c) c:WaitForChild("HumanoidRootPart",5); task.wait(0.5); applyVisuals(c) end)
    end
    for _,p in ipairs(Players:GetPlayers()) do trackPlayer(p) end
    Players.PlayerAdded:Connect(trackPlayer)
    Players.PlayerRemoving:Connect(function(p) if p.Character then removeVisuals(p.Character) end end)

    RunService.Heartbeat:Connect(function()
        for m,d in pairs(trackedEntities) do
            if not m.Parent or not d.hum or d.hum.Health<=0 then removeVisuals(m)
            else
                for _,item in ipairs(d.lines) do
                    local a,b=item.a,item.b
                    if a and b and a.Parent and b.Parent then
                        item.adorn.CFrame=CFrame.lookAt(a.Position,b.Position)
                        item.adorn.Length=(a.Position-b.Position).Magnitude
                    end
                    item.adorn.Visible=CFG.espSkeleton
                end
                if d.head then d.head.Visible=CFG.espHead end
                local hl=m:FindFirstChild("ESPHl")
                if hl then hl.Enabled=CFG.espHighlight end
            end
        end
    end)

    -- AUTO-PICK
    local function getPickMenu()
        local pg=LP:FindFirstChild("PlayerGui")
        local m=pg and pg:FindFirstChild("MainGui")
        local mf=m and m:FindFirstChild("MainFrame")
        local pages=mf and mf:FindFirstChild("Pages")
        return pages and pages:FindFirstChild("PickWeapons")
    end

    local function clickBtn(btn)
        if not btn then return false end
        if firesignal then
            pcall(firesignal, btn.MouseButton1Click)
            pcall(firesignal, btn.Activated)
        end
        pcall(function() btn:Activate() end)
        local ok2 = pcall(function()
            if VirtualInputManager then
                local ap,asz=btn.AbsolutePosition,btn.AbsoluteSize
                VirtualInputManager:SendMouseButtonEvent(ap.X+asz.X/2,ap.Y+asz.Y/2,0,true,game,0); task.wait(0.06)
                VirtualInputManager:SendMouseButtonEvent(ap.X+asz.X/2,ap.Y+asz.Y/2,0,false,game,0)
            end
        end)
        return ok2
    end

    local function isWanted(n) 
        local clean = n:lower():gsub("^%s+",""):gsub("%s+$","")
        if clean:find("assault") or clean:find("rifle") then return true end
        if clean:find("handgun") or clean:find("pistol") then return true end
        if clean:find("knife") or clean:find("melee") then return true end
        if clean:find("grenade") or clean:find("frag") then return true end
        for _,w in ipairs(WANTED_WEAPONS) do 
            if w:lower() == clean then return true end 
        end 
        return false 
    end

    task.spawn(function()
        while not unloaded do
            if CFG.autoPick and #Players:GetPlayers() <= 4 then
                local menu=getPickMenu()
                if menu and menu.Visible then
                    local chosen=menu:FindFirstChild("ChosenWeapons")
                    local cnt=0
                    
                    if chosen then 
                        for _,s in ipairs(chosen:GetChildren()) do
                            if s.Name=="PickWeaponChosenSlot" then
                                local b=s:FindFirstChild("Button")
                                local pic=b and b:FindFirstChild("Picture")
                                if pic and pic.Image~="" then cnt=cnt+1 end
                            end
                        end
                    end
                    
                    if cnt >= #WANTED_WEAPONS then
                        roundReady = true
                    else
                        roundReady = false
                    end
                    
                    local list=menu:FindFirstChild("List")
                    local cont=list and list:FindFirstChild("Container")
                    
                    if cont and cnt<#WANTED_WEAPONS and (os.clock()-lastPickedTime)>clickCooldown then
                        for _,slot in ipairs(cont:GetChildren()) do
                            if slot.Name=="WeaponSlot" and slot.Visible then
                                local b=slot:FindFirstChild("Button")
                                local t=b and b:FindFirstChild("Title")
                                if b and t then
                                    local cleanText = t.Text:gsub("^%s+",""):gsub("%s+$","")
                                    
                                    if isWanted(cleanText) and not alreadyPicked[cleanText] then
                                        local ban=b:FindFirstChild("Banned")
                                        local lck=b:FindFirstChild("Locked")
                                        if not(ban and ban.Visible) and not(lck and lck.Visible) then
                                            clickBtn(b)
                                            lastPickedTime=os.clock()
                                            
                                            task.delay(0.2, function()
                                                if menu and menu.Parent then
                                                    local newCnt = 0
                                                    local newChosen = menu:FindFirstChild("ChosenWeapons")
                                                    if newChosen then
                                                        for _, s in ipairs(newChosen:GetChildren()) do
                                                            if s.Name == "PickWeaponChosenSlot" then
                                                                local pic = s:FindFirstChild("Button") and s.Button:FindFirstChild("Picture")
                                                                if pic and pic.Image ~= "" then newCnt = newCnt + 1 end
                                                            end
                                                        end
                                                    end
                                                    
                                                    if newCnt > cnt then
                                                        alreadyPicked[cleanText] = true
                                                    else
                                                        alreadyPicked[cleanText] = nil
                                                    end
                                                end
                                            end)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                else 
                    roundReady = true
                    alreadyPicked={} 
                end
            else
                roundReady = false
            end
            task.wait(0.1)
        end
    end)

    -- AUTO-PLAY-AGAIN
    local function normalize(s)
        if not s then return "" end
        local res = s:lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
        return res
    end
    local function findPlayAgain()
        local res
        local function scan(i,d)
            if res or d>14 then return end
            if not i:IsA("GuiObject") or not i.Visible then for _,c in ipairs(i:GetChildren()) do scan(c,d+1) end return end
            if i:IsA("TextButton") or i:IsA("ImageButton") then
                local texts={}
                if i:IsA("TextButton") then table.insert(texts, normalize(i.Text)) end
                for _,d2 in ipairs(i:GetDescendants()) do if d2:IsA("TextLabel") then table.insert(texts, normalize(d2.Text)) end end
                local pa,un,rp=false,false,false
                for _,t in ipairs(texts) do
                    if t=="играть снова" or t=="play again" or t=="playagain" then pa=true end
                    if t:find("недоступно") or t:find("unavailable") then un=true end
                    if t:find("повторная") or t:find("repeat") then rp=true end
                end
                if pa and not un and not rp then res=i; return end
            end
            for _,c in ipairs(i:GetChildren()) do scan(c,d+1) end
        end
        scan(PlayerGui,0); return res
    end
    task.spawn(function()
        while not unloaded do
            if CFG.autoPlayAgain and (os.clock()-lastPlayAgainClick)>PLAY_AGAIN_COOLDOWN then
                local b=findPlayAgain()
                if b then
                    if VirtualInputManager then
                        local ap,asz=b.AbsolutePosition,b.AbsoluteSize
                        pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(ap.X+asz.X/2,ap.Y+asz.Y-8,0,true,game,0); task.wait(0.05)
                            VirtualInputManager:SendMouseButtonEvent(ap.X+asz.X/2,ap.Y+asz.Y-8,0,false,game,0)
                        end)
                    else
                        pcall(function() b:Activate() end)
                    end
                    lastPlayAgainClick=os.clock()
                    roundReady = false
                end
            end
            task.wait(0.5)
        end
    end)

    -- ANTI-AFK
    task.spawn(function()
        while not unloaded do
            task.wait(10)
            if CFG.antiAfk then
                local char = LP.Character
                if char and char:FindFirstChildOfClass("Humanoid") then
                    pcall(function() char.Humanoid.Jump = true end)
                end
            end
        end
    end)

    -- ═══════════════════════════════════════════════════════
    -- 🎨 GUI (v4.6 MOBILE & DELTA)
    -- ═══════════════════════════════════════════════════════
    local gui=Instance.new("ScreenGui")
    gui.Name="LUMACC_AutoFarm"; gui.ResetOnSpawn=false
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=PlayerGui

    local fov=Instance.new("Frame")
    fov.AnchorPoint=Vector2.new(0.5,0.5); fov.Position=UDim2.fromScale(0.5,0.5)
    fov.Size=UDim2.fromOffset(CFG.targetLockFOV*2,CFG.targetLockFOV*2)
    fov.BackgroundTransparency=1; fov.Visible=false; fov.Parent=gui
    Instance.new("UICorner",fov).CornerRadius=UDim.new(1,0)
    local fs=Instance.new("UIStroke")
    fs.Color=Color3.fromRGB(255,60,60); fs.Thickness=1.2; fs.Transparency=0.3; fs.Parent=fov

    local win=Instance.new("Frame")
    win.Size=UDim2.fromOffset(620, 400); win.Position=UDim2.fromScale(0.5, 0.5)
    win.AnchorPoint=Vector2.new(0.5, 0.5); win.BackgroundColor3=Color3.fromRGB(18,18,24)
    win.BorderSizePixel=0; win.Active=true; win.Draggable=true
    win.Visible = false
    win.Parent=gui
    Instance.new("UICorner",win).CornerRadius=UDim.new(0,12)
    local wStroke=Instance.new("UIStroke"); wStroke.Color=Color3.fromRGB(50,50,70); wStroke.Parent=win

    local winScale = Instance.new("UIScale")
    winScale.Parent = win
    if UserInputService.TouchEnabled then
        winScale.Scale = 0.65 
    end
    
    local hdr=Instance.new("Frame")
    hdr.Size=UDim2.new(1,0,0,42); hdr.BackgroundColor3=Color3.fromRGB(24,24,34)
    hdr.BorderSizePixel=0; hdr.Parent=win
    Instance.new("UICorner",hdr).CornerRadius=UDim.new(0,12)
    local hdrFix=Instance.new("Frame")
    hdrFix.Size=UDim2.new(1,0,0,12); hdrFix.Position=UDim2.new(0,0,1,-12)
    hdrFix.BackgroundColor3=Color3.fromRGB(24,24,34); hdrFix.BorderSizePixel=0; hdrFix.Parent=hdr

    local title2=Instance.new("TextLabel")
    title2.Size=UDim2.new(1,-100,0,42); title2.Position=UDim2.new(0,14,0,0)
    title2.BackgroundTransparency=1
    title2.Text="LUMACC v4.6 (Delta Mobile)"
    title2.TextColor3=Color3.new(1,1,1)
    title2.Font=Enum.Font.GothamBold; title2.TextSize=15
    title2.TextXAlignment=Enum.TextXAlignment.Left; title2.Parent=hdr
    local tg2=Instance.new("UIGradient")
    tg2.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(0,200,255)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(180,100,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(255,100,180)),
    }
    tg2.Parent=title2
    task.spawn(function()
        local o=0
        while title2.Parent do o=(o+0.005)%1; tg2.Offset=Vector2.new(o,0); task.wait(0.03) end
    end)

    local closeBtn=Instance.new("TextButton")
    closeBtn.Size=UDim2.new(0,24,0,24); closeBtn.Position=UDim2.new(1,-34,0.5,-12)
    closeBtn.BackgroundColor3=Color3.fromRGB(255,60,60); closeBtn.Text="×"
    closeBtn.TextColor3=Color3.new(1,1,1); closeBtn.Font=Enum.Font.GothamBold
    closeBtn.TextSize=18; closeBtn.AutoButtonColor=false; closeBtn.BorderSizePixel=0
    closeBtn.Parent=hdr
    Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,6)
    closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)

    local sidebar=Instance.new("Frame")
    sidebar.Size=UDim2.new(0,140,1,-42); sidebar.Position=UDim2.new(0,0,0,42)
    sidebar.BackgroundColor3=Color3.fromRGB(22,22,30); sidebar.BorderSizePixel=0; sidebar.Parent=win
    local sbCorner=Instance.new("UICorner"); sbCorner.CornerRadius=UDim.new(0,12); sbCorner.Parent=sidebar
    local sbFix=Instance.new("Frame")
    sbFix.Size=UDim2.new(0,12,1,0); sbFix.Position=UDim2.new(1,-12,0,0)
    sbFix.BackgroundColor3=Color3.fromRGB(22,22,30); sbFix.BorderSizePixel=0; sbFix.Parent=sidebar
    
    local funpayBtn=Instance.new("TextButton")
    funpayBtn.Size=UDim2.new(1,-16,0,34); funpayBtn.Position=UDim2.new(0,8,1,-42)
    funpayBtn.BackgroundColor3=Color3.fromRGB(255,170,0); funpayBtn.Text="💸 FunPay"
    funpayBtn.TextColor3=Color3.new(1,1,1); funpayBtn.Font=Enum.Font.GothamBold
    funpayBtn.TextSize=12; funpayBtn.AutoButtonColor=false; funpayBtn.BorderSizePixel=0
    funpayBtn.Parent=sidebar
    Instance.new("UICorner",funpayBtn).CornerRadius=UDim.new(0,6)
    funpayBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard("https://funpay.com/users/12135849/")
            funpayBtn.Text="✅ Copied!"
            task.wait(2); funpayBtn.Text="💸 FunPay"
        else
            funpayBtn.Text="❌ No Clipboard"
            task.wait(2); funpayBtn.Text="💸 FunPay"
        end
    end)

    local content=Instance.new("Frame")
    content.Size=UDim2.new(1,-140,1,-42); content.Position=UDim2.new(0,140,0,42)
    content.BackgroundTransparency=1; content.Parent=win

    local pages, tabBtns = {}, {}
    local function mkPage(name)
        local p=Instance.new("ScrollingFrame")
        p.Name=name.."Page"; p.Size=UDim2.new(1,-20,1,-20); p.Position=UDim2.new(0,10,0,10)
        p.BackgroundTransparency=1; p.BorderSizePixel=0
        p.ScrollBarThickness=3; p.ScrollBarImageColor3=Color3.fromRGB(60,60,90)
        p.CanvasSize=UDim2.new(0,0,0,0); p.AutomaticCanvasSize=Enum.AutomaticSize.Y
        p.Visible=false; p.Parent=content
        local l=Instance.new("UIListLayout"); l.Padding=UDim.new(0,8); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Parent=p
        pages[name]=p
        return p
    end
    local pMain=mkPage("Main")
    local pCombat=mkPage("Combat")
    local pVisuals=mkPage("Visuals")
    local pMisc=mkPage("Misc")

    local function switchTab(name)
        for n,pg in pairs(pages) do pg.Visible=(n==name) end
        for n,btn in pairs(tabBtns) do
            TweenService:Create(btn,TweenInfo.new(0.2),{
                BackgroundColor3=(n==name) and Color3.fromRGB(35,35,50) or Color3.fromRGB(22,22,30),
                TextColor3=(n==name) and Color3.fromRGB(0,200,255) or Color3.fromRGB(130,130,150)
            }):Play()
        end
    end

    local function mkTabBtn(name, y)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(1,-16,0,34); b.Position=UDim2.new(0,8,0,y)
        b.BackgroundColor3=Color3.fromRGB(22,22,30); b.Text=" "..name
        b.TextColor3=Color3.fromRGB(130,130,150); b.Font=Enum.Font.GothamBold
        b.TextSize=13; b.TextXAlignment=Enum.TextXAlignment.Left
        b.AutoButtonColor=false; b.BorderSizePixel=0; b.Parent=sidebar
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
        b.MouseButton1Click:Connect(function() switchTab(name) end)
        tabBtns[name]=b
    end
    mkTabBtn("Main", 10); mkTabBtn("Combat", 50); mkTabBtn("Visuals", 90); mkTabBtn("Misc", 130)

    local function mkToggle(parent, text, key)
        local c=Instance.new("Frame")
        c.Size=UDim2.new(1,-8,0,36); c.BackgroundColor3=Color3.fromRGB(28,28,38)
        c.BorderSizePixel=0; c.Parent=parent
        Instance.new("UICorner",c).CornerRadius=UDim.new(0,8)
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(1,-60,1,0); l.Position=UDim2.new(0,12,0,0)
        l.BackgroundTransparency=1; l.Text=text
        l.TextColor3=Color3.fromRGB(230,230,240); l.Font=Enum.Font.GothamMedium
        l.TextSize=13; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=c
        local tr=Instance.new("Frame")
        tr.Size=UDim2.fromOffset(36,18); tr.Position=UDim2.new(1,-48,0.5,-9)
        tr.BackgroundColor3=CFG[key] and Color3.fromRGB(0,180,255) or Color3.fromRGB(50,50,65)
        tr.BorderSizePixel=0; tr.Parent=c
        Instance.new("UICorner",tr).CornerRadius=UDim.new(1,0)
        local kn=Instance.new("Frame")
        kn.Size=UDim2.fromOffset(12,12)
        kn.Position=CFG[key] and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
        kn.BackgroundColor3=Color3.new(1,1,1); kn.BorderSizePixel=0; kn.Parent=tr
        Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0)
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=c
        btn.MouseButton1Click:Connect(function()
            CFG[key]=not CFG[key]
            TweenService:Create(kn,TweenInfo.new(0.2),{Position=CFG[key] and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)}):Play()
            TweenService:Create(tr,TweenInfo.new(0.2),{BackgroundColor3=CFG[key] and Color3.fromRGB(0,180,255) or Color3.fromRGB(50,50,65)}):Play()
        end)
    end

    local function mkCycler(parent, text, get, set, values)
        local c=Instance.new("Frame")
        c.Size=UDim2.new(1,-8,0,32); c.BackgroundColor3=Color3.fromRGB(28,28,38)
        c.BorderSizePixel=0; c.Parent=parent
        Instance.new("UICorner",c).CornerRadius=UDim.new(0,8)
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(1,-16,1,0); l.Position=UDim2.new(0,12,0,0)
        l.BackgroundTransparency=1; l.Text=text..": "..tostring(get())
        l.TextColor3=Color3.fromRGB(180,200,255); l.Font=Enum.Font.GothamBold
        l.TextSize=12; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=c
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=c
        btn.MouseButton1Click:Connect(function()
            local cur=get(); local idx=1
            for i,v in ipairs(values) do if v==cur then idx=i; break end end
            idx=idx%#values+1; set(values[idx])
            l.Text=text..": "..tostring(values[idx])
        end)
    end

    local function mkSection(parent, text)
        local l=Instance.new("TextLabel")
        l.Size=UDim2.new(1,-8,0,20); l.BackgroundTransparency=1; l.Text=text
        l.TextColor3=Color3.fromRGB(0,180,255); l.Font=Enum.Font.GothamBold
        l.TextSize=10; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent
    end

    mkSection(pMain, "3D ORBIT (Dynamic)")
    mkToggle(pMain, "Orbit enabled", "orbitEnabled")
    mkCycler(pMain, "Speed (°/s)", function() return CFG.orbitSpeed end, function(v) CFG.orbitSpeed=v end, {90,180,360,540,900,1200})
    
    mkSection(pMain, "SHADOW")
    mkToggle(pMain, "Fly", "flyEnabled")
    mkToggle(pMain, "Noclip", "noclipEnabled")

    mkSection(pCombat, "AIM & FIRE")
    mkToggle(pCombat, "Aimbot (head)", "aimbotEnabled")
    mkToggle(pCombat, "Triggerbot", "triggerbotEnabled")
    mkToggle(pCombat, "Mouse Emulation", "useMouseEmu")
    mkToggle(pCombat, "Target lock", "targetLockEnabled")
    mkToggle(pCombat, "Team check", "targetLockTeamCheck")
    
    mkSection(pCombat, "SHIELD BYPASS")
    mkToggle(pCombat, "Wait shield (Auto)", "shieldCheck")
    mkToggle(pCombat, "Force Under (Manual)", "forceUnder")

    mkSection(pVisuals, "ESP")
    mkToggle(pVisuals, "Highlight ESP", "espHighlight")
    mkToggle(pVisuals, "Skeleton ESP", "espSkeleton")
    mkToggle(pVisuals, "Head marker", "espHead")

    mkSection(pMisc, "UTILITY")
    mkToggle(pMisc, "Anti-AFK", "antiAfk")
    mkToggle(pMisc, "Auto Weapon Pick", "autoPick")
    mkToggle(pMisc, "Auto Play Again", "autoPlayAgain")

    mkSection(pMisc, "AIM TARGET")
    local aimBtn=Instance.new("TextButton")
    aimBtn.Size=UDim2.new(1,-8,0,32); aimBtn.BackgroundColor3=Color3.fromRGB(28,28,38)
    aimBtn.Text="Aim: "..CFG.aimPart; aimBtn.Font=Enum.Font.GothamBold
    aimBtn.TextSize=12; aimBtn.TextColor3=Color3.fromRGB(255,200,60)
    aimBtn.AutoButtonColor=false; aimBtn.BorderSizePixel=0; aimBtn.Parent=pMisc
    Instance.new("UICorner",aimBtn).CornerRadius=UDim.new(0,8)
    aimBtn.MouseButton1Click:Connect(function()
        CFG.aimPart=CFG.aimPart=="Head" and "Body" or "Head"
        aimBtn.Text="Aim: "..CFG.aimPart
        aimBtn.TextColor3=CFG.aimPart=="Head" and Color3.fromRGB(255,200,60) or Color3.fromRGB(0,200,140)
    end)

    switchTab("Main")

    local stat=Instance.new("TextLabel")
    stat.Size=UDim2.new(1,-20,0,20); stat.Position=UDim2.new(0,10,1,-30)
    stat.BackgroundTransparency=1; stat.TextColor3=Color3.fromRGB(110,110,130)
    stat.Font=Enum.Font.GothamMedium; stat.TextSize=11
    stat.Text="FLY: WAITING (Pick weapons)"; stat.Parent=win

    task.spawn(function()
        while gui.Parent and not unloaded do
            local tgt=currentTargetModel
            local flyStatus=flyConn and "ON" or "OFF"
            
            local statusPrefix = "FLY: " .. flyStatus
            if #Players:GetPlayers() > 4 then
                statusPrefix = "FLY: OFF (Server > 4)"
            elseif not roundReady then
                statusPrefix = "FLY: WAITING (Weapon Pick)"
            elseif flyStateReason == "empty server" then
                statusPrefix = "FLY: OFF (Empty Server)"
            elseif flyStateReason == "no enemies" then
                statusPrefix = "FLY: OFF (No Enemies)"
            end
            
            stat.Text=string.format("%s | TARGET: %s",
                statusPrefix, tgt and tgt.Name or "—")
            fov.Visible = CFG.targetLockEnabled and win.Visible
            task.wait(0.5)
        end
    end)

    -- ПЛАВАЮЩАЯ КНОПКА ДЛЯ МОБИЛОК
    local openBtn = Instance.new("TextButton")
    openBtn.Name = "LUMACC_Toggle"
    openBtn.Size = UDim2.new(0, 50, 0, 50)
    openBtn.Position = UDim2.new(0, 20, 0.5, -25)
    openBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
    openBtn.Text = "L"
    openBtn.TextColor3 = Color3.new(1,1,1)
    openBtn.Font = Enum.Font.GothamBlack
    openBtn.TextSize = 24
    openBtn.AutoButtonColor = false
    openBtn.BorderSizePixel = 0
    openBtn.Active = true
    openBtn.Draggable = true
    openBtn.Parent = gui
    
    Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(255,255,255)
    btnStroke.Thickness = 2
    btnStroke.Transparency = 0.5
    btnStroke.Parent = openBtn
    
    openBtn.MouseButton1Click:Connect(function()
        win.Visible = not win.Visible
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
            win.Visible = not win.Visible
        end
    end)

    print("[LUMACC] AUTO-FARM v4.6 Mobile активен.")
end

AUTO_FARM()

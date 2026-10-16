--[=[
    Santa V.1 — Fixed
    Fixes applied:
    1. hrp.Velocity        -> hrp.AssemblyLinearVelocity  (aimbot prediction)
    2. root.Velocity       -> root.AssemblyLinearVelocity (fly, anti-aim desync)
    3. root.RotVelocity    -> root.AssemblyAngularVelocity (fly)
    4. wallBlocked dir     -> delta direct (no double magnitude mul)
    5. WorldToViewportPoint -> properly unpack onScreen bool
    6. stickyAim nil guard  on currentTarget.Character.Head
    7. Silent Aim hook      -> executor-safe rawset + namecall fallback
    8. Camera ref           -> auto-refresh on CurrentCamera change
    9. NameLabel/HealthLabel BackgroundTransparency missing -> added
]=]

-- ── Adonis Anti-Cheat Bypass ──────────────────────────────────────
local getinfo = getinfo or debug.getinfo
local DEBUG = false
local Hooked = {}
local Detected, Kill

pcall(function()
    setthreadidentity(2)
    for i, v in getgc(true) do
        if typeof(v) == "table" then
            local DetectFunc = rawget(v, "Detected")
            local KillFunc = rawget(v, "Kill")
            if typeof(DetectFunc) == "function" and not Detected then
                Detected = DetectFunc
                local Old; Old = hookfunction(Detected, function(Action, Info, NoCrash)
                    if Action ~= "_" and DEBUG then
                        warn(`Adonis AntiCheat flagged\nMethod: {Action}\nInfo: {Info}`)
                    end
                    return true
                end)
                table.insert(Hooked, Detected)
            end
            if rawget(v, "Variables") and rawget(v, "Process") and typeof(KillFunc) == "function" and not Kill then
                Kill = KillFunc
                local Old; Old = hookfunction(Kill, function(Info)
                    if DEBUG then warn(`Adonis AntiCheat tried to kill: {Info}`) end
                end)
                table.insert(Hooked, Kill)
            end
        end
    end
    local Old; Old = hookfunction(getrenv().debug.info, newcclosure(function(...)
        local LevelOrFunc, Info = ...
        if Detected and LevelOrFunc == Detected then
            if DEBUG then warn("Adonis sanity check broken") end
            return coroutine.yield(coroutine.running())
        end
        return Old(...)
    end))
end)
pcall(setthreadidentity, 7)
-- ── End Adonis Anti-Cheat Bypass ─────────────────────────────────

local Players     = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local function decode(t)
    local s = ""
    for _, v in ipairs(t) do s = s .. string.char(v) end
    return s
end

local KeyURL       = decode({104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,84,101,100,100,121,102,101,105,116,47,115,114,121,45,98,114,111,45,105,100,107,45,119,104,97,116,45,116,102,45,105,109,45,100,111,110,103,47,114,101,102,115,47,104,101,97,100,115,47,109,97,105,110,47,107,101,121,115,46,116,120,116})
local SaveFileName = "santa_v1_key.txt"

-- ════════ LOGGING ════════
-- Every stage prints OK or FAIL with the error, so the console shows exactly
-- how far the script got. Traceback is included on failure.
local function SantaLog(stage, ok, err)
    if ok then
        print("[Santa] OK    " .. stage)
    else
        warn("[Santa] FAIL  " .. stage .. "  ->  " .. tostring(err))
    end
end
local function SantaStep(stage, fn)
    local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
    SantaLog(stage, ok, err)
    return ok
end

local ScriptToRun = function()
    print("[Santa] START script")

local repo         = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local RunService          = game:GetService('RunService')
local UserInputService    = game:GetService('UserInputService')
local VirtualInputManager = game:GetService('VirtualInputManager')
local Lighting            = game:GetService('Lighting')
local CoreGui             = game:GetService("CoreGui")
local Stats               = game:GetService("Stats")
local LocalPlayer         = Players.LocalPlayer
local Mouse               = LocalPlayer:GetMouse()
local PlayerGui           = LocalPlayer:WaitForChild('PlayerGui')

-- FIX 8: Camera auto-refresh so aimbot/ESP survives teleport/respawn
local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

-- ── Watermark ────────────────────────────────────────────────────
local WM_Config = { Enabled=true, Text="Santa V.1", ShowFPS=true, ShowPing=true, ShowTime=true }

-- ── Target HUD ───────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TargetHUD_Gui"
ScreenGui.Parent = CoreGui or PlayerGui

local TargetFrame = Instance.new("Frame")
TargetFrame.Name = "TargetHUD"
TargetFrame.Size = UDim2.new(0,220,0,70)
TargetFrame.Position = UDim2.new(0.5,-110,0.75,0)
TargetFrame.BackgroundColor3 = Color3.fromRGB(20,20,25)
TargetFrame.BorderSizePixel = 0
TargetFrame.Visible = false
TargetFrame.Parent = ScreenGui
Instance.new("UICorner",TargetFrame).CornerRadius = UDim.new(0,8)

local AvatarImage = Instance.new("ImageLabel")
AvatarImage.Size = UDim2.new(0,50,0,50); AvatarImage.Position = UDim2.new(0,10,0,10)
AvatarImage.BackgroundColor3 = Color3.fromRGB(30,30,35); AvatarImage.BorderSizePixel = 0
AvatarImage.Parent = TargetFrame
Instance.new("UICorner",AvatarImage).CornerRadius = UDim.new(0,6)

local NameLabel = Instance.new("TextLabel")
NameLabel.Size = UDim2.new(0,140,0,20); NameLabel.Position = UDim2.new(0,68,0,10)
NameLabel.Text = "Target Name"; NameLabel.TextColor3 = Color3.fromRGB(255,255,255)
NameLabel.TextXAlignment = Enum.TextXAlignment.Left; NameLabel.Font = Enum.Font.SourceSansBold
NameLabel.TextSize = 16; NameLabel.BackgroundTransparency = 1 -- FIX 9
NameLabel.Parent = TargetFrame

local HealthLabel = Instance.new("TextLabel")
HealthLabel.Size = UDim2.new(0,140,0,15); HealthLabel.Position = UDim2.new(0,68,0,28)
HealthLabel.Text = "100 / 100 HP"; HealthLabel.TextColor3 = Color3.fromRGB(200,200,200)
HealthLabel.TextXAlignment = Enum.TextXAlignment.Left; HealthLabel.Font = Enum.Font.SourceSans
HealthLabel.TextSize = 13; HealthLabel.BackgroundTransparency = 1 -- FIX 9
HealthLabel.Parent = TargetFrame

local HealthBarBG = Instance.new("Frame")
HealthBarBG.Size = UDim2.new(0,140,0,8); HealthBarBG.Position = UDim2.new(0,68,0,48)
HealthBarBG.BackgroundColor3 = Color3.fromRGB(40,40,45); HealthBarBG.BorderSizePixel = 0
HealthBarBG.Parent = TargetFrame
Instance.new("UICorner",HealthBarBG).CornerRadius = UDim.new(0,4)

local HealthBarFill = Instance.new("Frame")
HealthBarFill.Size = UDim2.new(1,0,1,0); HealthBarFill.BackgroundColor3 = Color3.fromRGB(0,255,120)
HealthBarFill.BorderSizePixel = 0; HealthBarFill.Parent = HealthBarBG
Instance.new("UICorner",HealthBarFill).CornerRadius = UDim.new(0,4)

local targetHudEnabled = false
local function updateTargetHUD(targetPlayer)
    if not targetHudEnabled or not targetPlayer or not targetPlayer.Character then TargetFrame.Visible=false; return end
    local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health<=0 then TargetFrame.Visible=false; return end
    TargetFrame.Visible = true
    NameLabel.Text = targetPlayer.DisplayName or targetPlayer.Name
    AvatarImage.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..targetPlayer.UserId.."&width=150&height=150&format=png"
    local health = math.floor(humanoid.Health)
    local maxHealth = math.floor(humanoid.MaxHealth)
    local hp = math.clamp(health/maxHealth,0,1)
    HealthLabel.Text = health.." / "..maxHealth.." HP"
    HealthBarFill.Size = UDim2.new(hp,0,1,0)
    if hp>0.5 then HealthBarFill.BackgroundColor3=Color3.fromRGB(0,255,120)
    elseif hp>0.25 then HealthBarFill.BackgroundColor3=Color3.fromRGB(255,200,0)
    else HealthBarFill.BackgroundColor3=Color3.fromRGB(255,50,50) end
end

-- ── Crosshair forward-declare ────────────────────────────────────
local currentCHPosition = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

-- ── Aimbot ────────────────────────────────────────────────────────
local hue=0; local rainbowFov=false; local rainbowSpeed=0.005; local aimFov=100
local aiming=false; local predictionStr=0.065; local smoothing=0.05; local aimbotEnabled=false
local wallCheck=true; local stickyAim=false; local teamCheck=false; local healthCheck=false
local minHealth=0; local circleColor=Color3.fromRGB(255,192,253); local targetedColor=Color3.fromRGB(250,139,255)
local currentTarget=nil; local linkFovToCrosshair=false

local fovCircle = Drawing.new('Circle')
fovCircle.Thickness=2; fovCircle.Radius=aimFov; fovCircle.Filled=false
fovCircle.Color=circleColor; fovCircle.Visible=false

local function isTeammate(p) return teamCheck and p.Team==LocalPlayer.Team end

-- FIX 4: wallBlocked uses delta directly, no double-magnitude multiply
local function wallBlocked(char)
    local head = char:FindFirstChild('Head'); if not head then return true end
    local origin = Camera.CFrame.Position
    local delta  = head.Position - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(origin, delta, params) ~= nil
end

-- FIX 5: unpack onScreen from WorldToViewportPoint
local function getAimbotTarget()
    local best,bestCursor,bestDist = nil,aimFov,math.huge
    local camPos = Camera.CFrame.Position
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LocalPlayer or not p.Character then continue end
        local head = p.Character:FindFirstChild('Head')
        local hum  = p.Character:FindFirstChildOfClass('Humanoid')
        if not head or not hum then continue end
        if isTeammate(p) then continue end
        if healthCheck and hum.Health<minHealth then continue end
        local sp,onScreen = Camera:WorldToViewportPoint(head.Position)
        if not onScreen or sp.Z<=0 then continue end
        local screenPos  = Vector2.new(sp.X,sp.Y)
        local cursorDist = (screenPos-Vector2.new(Mouse.X,Mouse.Y)).Magnitude
        local playerDist = (head.Position-camPos).Magnitude
        if cursorDist<bestCursor and (not wallCheck or not wallBlocked(p.Character)) then
            if playerDist<bestDist then bestDist=playerDist; bestCursor=cursorDist; best=p end
        end
    end
    return best
end

-- FIX 1: AssemblyLinearVelocity for prediction
local function aimAt(p)
    local head = p.Character and p.Character:FindFirstChild('Head')
    local hrp  = p.Character and p.Character:FindFirstChild('HumanoidRootPart')
    if not head or not hrp then return end
    local predicted = head.Position + hrp.AssemblyLinearVelocity * predictionStr
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predicted), smoothing)
end

RunService.RenderStepped:Connect(function()
    if Library.Unloaded then return end
    if aimbotEnabled then
        fovCircle.Position = (linkFovToCrosshair and currentCHPosition) or Vector2.new(Mouse.X,Mouse.Y+50)
        if rainbowFov then hue=(hue+rainbowSpeed)%1; fovCircle.Color=Color3.fromHSV(hue,1,1)
        else fovCircle.Color=(aiming and currentTarget) and targetedColor or circleColor end
        if aiming then
            -- FIX 6: nil guard on currentTarget.Character.Head
            if stickyAim and currentTarget then
                local char = currentTarget.Character
                local head = char and char:FindFirstChild('Head')
                if not head then currentTarget=nil
                else
                    local sp,onScr = Camera:WorldToViewportPoint(head.Position)
                    local d = (Vector2.new(sp.X,sp.Y)-Vector2.new(Mouse.X,Mouse.Y)).Magnitude
                    if not onScr or d>aimFov or (wallCheck and wallBlocked(char)) or isTeammate(currentTarget) then currentTarget=nil end
                end
            end
            if not stickyAim or not currentTarget then currentTarget=getAimbotTarget() end
            if currentTarget then aimAt(currentTarget) end
        else currentTarget=nil end
    end
    updateTargetHUD(currentTarget)
end)

Mouse.Button2Down:Connect(function() if aimbotEnabled then aiming=true  end end)
Mouse.Button2Up:Connect(function()   if aimbotEnabled then aiming=false end end)

-- ── Triggerbot ────────────────────────────────────────────────────
local trigger = {enabled=false,teamCheck=false,delay=0,holdMode=false,clickInterval=0.05}
local lastClick = 0

local function getTriggerTarget()
    local t=Mouse.Target; if not t or not t.Parent then return nil end
    local char=t.Parent; if not char:FindFirstChild('Humanoid') then return nil end
    local p=Players:GetPlayerFromCharacter(char)
    if not p or p==LocalPlayer then return nil end
    if trigger.teamCheck and p.Team==LocalPlayer.Team then return nil end
    return p
end

RunService.RenderStepped:Connect(function()
    if not trigger.enabled then return end
    local can = not trigger.holdMode or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if can and getTriggerTarget() and (tick()-lastClick)>=(trigger.delay+trigger.clickInterval) then
        lastClick=tick()
        if mouse1click then mouse1click()
        else VirtualInputManager:SendMouseButtonEvent(Mouse.X,Mouse.Y,0,true,game,0); VirtualInputManager:SendMouseButtonEvent(Mouse.X,Mouse.Y,0,false,game,0) end
    end
end)

-- ── SpinBot & Anti-Aim ────────────────────────────────────────────
local spinEnabled=false; local spinSpeed=10; local spinMode='Linear'
local antiAim = {enabled=false,velocityDesync=false,veloX=0,veloY=1000,veloZ=0,jitter=false,jitterRange=5,pitch=0,yaw=0,roll=0}

RunService.RenderStepped:Connect(function(deltaTime)
    if Library.Unloaded then return end
    local char=LocalPlayer.Character; local root=char and char:FindFirstChild('HumanoidRootPart'); local hum=char and char:FindFirstChildOfClass('Humanoid')
    if hum then hum.AutoRotate = not (spinEnabled or antiAim.enabled) end
    if antiAim.enabled and root then
        root.CFrame = root.CFrame*CFrame.Angles(math.rad(antiAim.pitch),math.rad(antiAim.yaw),math.rad(antiAim.roll))
        if antiAim.jitter then root.CFrame = root.CFrame+Vector3.new((math.random()-0.5)*antiAim.jitterRange,0,(math.random()-0.5)*antiAim.jitterRange) end
    end
end)

-- Spinbot runs after physics (Heartbeat) and keeps the current position,
-- so it keeps spinning with Shift Lock on and while walking.
local spinAngle = 0
RunService.Heartbeat:Connect(function()
    if Library.Unloaded or not spinEnabled then return end
    local char=LocalPlayer.Character; local root=char and char:FindFirstChild('HumanoidRootPart'); local hum=char and char:FindFirstChildOfClass('Humanoid')
    if not root or not hum then return end
    hum.AutoRotate=false
    local deg = spinMode=='Jitter' and (math.random()*2-1)*spinSpeed or spinSpeed
    spinAngle = (spinAngle + math.rad(deg)) % (math.pi*2)
    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spinAngle, 0)
end)

-- FIX 2: AssemblyLinearVelocity for anti-aim desync
RunService.Heartbeat:Connect(function()
    if antiAim.enabled and antiAim.velocityDesync then
        local char=LocalPlayer.Character; local root=char and char:FindFirstChild('HumanoidRootPart')
        if root then
            local oldVelo=root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity=Vector3.new(antiAim.veloX,antiAim.veloY,antiAim.veloZ)
            RunService.RenderStepped:Wait()
            root.AssemblyLinearVelocity=oldVelo
        end
    end
end)

-- ── ESP Engine ───────────────────────────────────────────────────
local ESPToggles = {master=false,box=true,fill=false,name=true,distance=true,weapon=false,healthbar=true,skeleton=false,skeletonOutline=false}
local ESPOptions = {boundsType='static',boundsScale=100,color=Color3.fromRGB(0,255,140)}

local SKEL_PARTS = {'RightHand','LeftLowerArm','RightLowerArm','LeftUpperArm','RightUpperArm','LowerTorso','LeftLowerLeg','LeftUpperLeg','LeftFoot','RightFoot','RightLowerLeg','RightUpperLeg','UpperTorso','LeftHand','Head'}
local SKEL_LINES = {{'LeftUpperArm','UpperTorso'},{'LeftLowerArm','LeftUpperArm'},{'LeftLowerArm','LeftHand'},{'RightUpperArm','UpperTorso'},{'RightLowerArm','RightUpperArm'},{'RightHand','RightLowerArm'},{'LeftUpperLeg','LowerTorso'},{'LeftLowerLeg','LeftUpperLeg'},{'LeftFoot','LeftLowerLeg'},{'RightUpperLeg','LowerTorso'},{'RightLowerLeg','RightUpperLeg'},{'RightFoot','RightLowerLeg'},{'LowerTorso','UpperTorso'}}

local ESP = {}; ESP.__index = ESP
function ESP.new() return setmetatable({players={}},ESP) end
function ESP:createState(player)
    local s={player=player,character=nil,humanoid=nil,humanoidRootPart=nil,parts={},connections={},drawings={},squares={},lines={},text={}}
    for i=1,26 do local l=Drawing.new('Line'); l.Visible=false; l.Thickness=1; l.Color=Color3.new(1,1,1); table.insert(s.drawings,l); table.insert(s.lines,l) end
    for i=1,4 do local t=Drawing.new('Text'); t.Outline=true; t.Visible=false; t.Color=Color3.new(1,1,1); t.Center=true; t.Size=13; table.insert(s.drawings,t); table.insert(s.text,t) end
    for i=1,4 do local sq=Drawing.new('Square'); sq.Visible=false; table.insert(s.drawings,sq); table.insert(s.squares,sq) end
    s.squares[1].Thickness=1; s.squares[1].Color=Color3.new(0,0,0); s.squares[2].Thickness=1; s.squares[3].Filled=true; s.squares[4].Filled=true; s.squares[4].Color=Color3.new(0,0,0)
    return s
end
function ESP:updateState(player,char)
    local s=self.players[player]; if not s then return end
    s.character=char; s.humanoidRootPart=char:WaitForChild('HumanoidRootPart',5); s.humanoid=char:WaitForChild('Humanoid',5); s.parts={}
    if not s.humanoid or not s.humanoidRootPart then return end
    for _,n in ipairs(SKEL_PARTS) do local p=char:FindFirstChild(n); if p then s.parts[n]=p end end
end
function ESP:bounds(s)
    local hrp=s.humanoidRootPart; if not hrp then return nil end
    local top,ton=Camera:WorldToViewportPoint((hrp.CFrame*CFrame.new(0,3,0)).Position)
    local bot,bon=Camera:WorldToViewportPoint((hrp.CFrame*CFrame.new(0,-3.5,0)).Position)
    if not ton and not bon then return nil end
    local h=math.abs(top.Y-bot.Y); local w=h*0.6*(ESPOptions.boundsScale/100)
    return w,h,Vector2.new(top.X,top.Y)
end
function ESP:drawSkeleton(s)
    for _,l in ipairs(s.lines) do l.Visible=false end
    if not ESPToggles.skeleton or not s.character then return end
    for i,pair in ipairs(SKEL_LINES) do
        local fP=s.parts[pair[1]]; local tP=s.parts[pair[2]]; if not fP or not tP then continue end
        local f,onF=Camera:WorldToViewportPoint(fP.Position); local t2,onT=Camera:WorldToViewportPoint(tP.Position)
        if not onF or not onT then continue end
        local l=s.lines[i]; l.From=Vector2.new(f.X,f.Y); l.To=Vector2.new(t2.X,t2.Y)
        l.Color=ESPOptions.color; l.Thickness=ESPToggles.skeletonOutline and 2 or 1; l.Visible=true
    end
end
function ESP:drawBox(s,w,h,pos)
    s.squares[1].Visible=false; s.squares[2].Visible=false; if not ESPToggles.box then return end
    s.squares[2].Size=Vector2.new(w,h); s.squares[2].Position=pos-Vector2.new(w/2,0)
    s.squares[2].Color=ESPOptions.color; s.squares[2].Filled=ESPToggles.fill; s.squares[2].Visible=true
end
function ESP:drawText(s,w,h,pos)
    for _,t in ipairs(s.text) do t.Visible=false end
    local topPos=pos-Vector2.new(0,15); local botPos=pos+Vector2.new(0,h+2)
    if ESPToggles.name then s.text[1].Text=s.player.Name; s.text[1].Position=topPos; s.text[1].Color=ESPOptions.color; s.text[1].Visible=true end
    if ESPToggles.weapon then
        local item=s.character and (s.character:FindFirstChildOfClass('Tool') or s.character:FindFirstChild('EquippedItem'))
        s.text[2].Text=item and item.Name or 'None'; s.text[2].Position=botPos; s.text[2].Color=ESPOptions.color; s.text[2].Visible=true; botPos=botPos+Vector2.new(0,14)
    end
    if ESPToggles.distance and s.humanoidRootPart then
        local d=math.round((s.humanoidRootPart.Position-Camera.CFrame.Position).Magnitude)
        s.text[3].Text='['..d..'m]'; s.text[3].Position=botPos; s.text[3].Color=ESPOptions.color; s.text[3].Visible=true
    end
end
function ESP:drawHealthbar(s,w,h,pos)
    s.squares[3].Visible=false; s.squares[4].Visible=false; if not ESPToggles.healthbar or not s.humanoid then return end
    local ratio=math.clamp(s.humanoid.Health/s.humanoid.MaxHealth,0,1)
    local barH=h*ratio; local barPos=pos-Vector2.new(w/2+6,-h+barH); local bgPos=pos-Vector2.new(w/2+6,0)
    s.squares[4].Size=Vector2.new(3,h); s.squares[4].Position=bgPos; s.squares[4].Visible=true
    s.squares[3].Size=Vector2.new(3,barH); s.squares[3].Position=barPos
    s.squares[3].Color=Color3.fromRGB(255,0,0):Lerp(Color3.fromRGB(0,255,0),ratio); s.squares[3].Visible=true
end
function ESP:hideAll(s) for _,d in ipairs(s.drawings) do d.Visible=false end end
function ESP:update(player)
    local s=self.players[player]; if not s then return end
    if not ESPToggles.master then self:hideAll(s); return end
    local char=s.character
    if not char or not s.humanoidRootPart or not s.humanoid or s.humanoid.Health<=0 then self:hideAll(s); return end
    if player==LocalPlayer then self:hideAll(s); return end
    local w,h,pos=self:bounds(s); if not w then self:hideAll(s); return end
    self:drawSkeleton(s); self:drawBox(s,w,h,pos); self:drawText(s,w,h,pos); self:drawHealthbar(s,w,h,pos)
end
function ESP:start()
    local function onAdded(player)
        if Library.Unloaded then return end
        local s=self:createState(player); self.players[player]=s
        local function onChar(char) task.spawn(function() self:updateState(player,char) end) end
        table.insert(s.connections,player.CharacterAdded:Connect(onChar))
        table.insert(s.connections,player.CharacterRemoving:Connect(function() self:hideAll(s); s.character=nil end))
        if player.Character then onChar(player.Character) end
    end
    for _,p in ipairs(Players:GetPlayers()) do onAdded(p) end
    Players.PlayerAdded:Connect(onAdded)
    Players.PlayerRemoving:Connect(function(player)
        local s=self.players[player]; if not s then return end
        for _,c in ipairs(s.connections) do pcall(c.Disconnect,c) end
        for _,d in ipairs(s.drawings)    do pcall(d.Remove,d) end
        self.players[player]=nil
    end)
    RunService.RenderStepped:Connect(function()
        if Library.Unloaded then return end
        for p in pairs(self.players) do self:update(p) end
    end)
end
local ESPEngine = ESP.new(); ESPEngine:start()

-- ── Crosshair ─────────────────────────────────────────────────────
local CH = {Visible=false,SpinSpeed=0.005,CentralGap=8,TotalLength=112,LineThickness=2,OutlineThickness=4,ColorStart=Color3.fromRGB(180,180,180),ColorEnd=Color3.fromRGB(20,20,20),CircleVisible=true,CircleRadius=119,CircleTransparency=0.3,CircleColor=Color3.fromRGB(15,15,25),TrackingEnabled=false,TrackingRadius=150,TrackingSmoothness=0.2,TrackPart='Head',TeamCheck=true}
local SEG=2; local chLines,chOutlines,chCircle={},{},nil
local function clearCH()
    if chCircle then chCircle:Remove(); chCircle=nil end
    for arm=1,#chLines do if chLines[arm] then for seg=1,#chLines[arm] do
        if chLines[arm][seg] then chLines[arm][seg]:Remove() end
        if chOutlines[arm][seg] then chOutlines[arm][seg]:Remove() end
    end end end
    chLines,chOutlines={},{}
end
local function initCH()
    clearCH()
    chCircle=Drawing.new('Circle'); chCircle.Filled=true; chCircle.NumSides=64; chCircle.Radius=CH.CircleRadius
    chCircle.Color=CH.CircleColor; chCircle.Transparency=CH.CircleTransparency; chCircle.Visible=CH.Visible and CH.CircleVisible
    local segs=math.max(1,math.floor(CH.TotalLength/SEG))
    for arm=1,4 do
        chLines[arm],chOutlines[arm]={},{}
        for seg=1,segs do
            local p=(seg-0.5)/segs
            local ol=Drawing.new('Line'); ol.Thickness=CH.OutlineThickness; ol.Color=Color3.new(0,0,0); ol.Visible=CH.Visible
            local ml=Drawing.new('Line'); ml.Thickness=CH.LineThickness; ml.Color=CH.ColorStart:Lerp(CH.ColorEnd,p); ml.Visible=CH.Visible
            chOutlines[arm][seg]=ol; chLines[arm][seg]=ml
        end
    end
end
local function getCHTarget(center)
    local best,bestD=nil,CH.TrackingRadius
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LocalPlayer or not p.Character then continue end
        local part=p.Character:FindFirstChild(CH.TrackPart); local hum=p.Character:FindFirstChildOfClass('Humanoid')
        if not part or not hum or hum.Health<=0 then continue end
        if CH.TeamCheck and p.Team==LocalPlayer.Team then continue end
        local sp,on=Camera:WorldToViewportPoint(part.Position)
        if on then local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude; if d<bestD then bestD=d; best=Vector2.new(sp.X,sp.Y) end end
    end
    return best
end
local BASE={0,math.pi/2,math.pi,math.pi*1.5}; local chAngle=0
RunService.RenderStepped:Connect(function()
    if Library.Unloaded then return end
    local screenCenter=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    local targetPos=screenCenter
    if CH.TrackingEnabled then local t=getCHTarget(screenCenter); if t then targetPos=t end end
    currentCHPosition=currentCHPosition:Lerp(targetPos,CH.TrackingSmoothness)
    if chCircle then chCircle.Position=currentCHPosition; chCircle.Radius=CH.CircleRadius; chCircle.Color=CH.CircleColor; chCircle.Transparency=CH.CircleTransparency; chCircle.Visible=CH.Visible and CH.CircleVisible end
    chAngle=chAngle+CH.SpinSpeed
    local segs=math.max(1,math.floor(CH.TotalLength/SEG))
    for arm=1,4 do
        local angle=BASE[arm]+chAngle; local cos,sin=math.cos(angle),math.sin(angle)
        local AL,AO=chLines[arm],chOutlines[arm]; if not AL then continue end
        for seg=1,#AL do
            local ml,ol=AL[seg],AO[seg]; if not ml or not ol then continue end
            if CH.Visible then
                local s1=CH.CentralGap+(seg-1)*SEG; local s2=CH.CentralGap+seg*SEG
                local sP=currentCHPosition+Vector2.new(cos*s1,sin*s1); local eP=currentCHPosition+Vector2.new(cos*s2,sin*s2)
                ol.From=sP; ol.To=eP; ol.Thickness=CH.OutlineThickness; ol.Visible=true
                ml.From=sP; ml.To=eP; ml.Thickness=CH.LineThickness; ml.Color=CH.ColorStart:Lerp(CH.ColorEnd,(seg-0.5)/segs); ml.Visible=true
            else ml.Visible=false; ol.Visible=false end
        end
    end
end)
initCH()

-- ── Movement ──────────────────────────────────────────────────────
local speedEnabled=false; local walkSpeed=16; local jumpEnabled=false; local jumpPower=50; local flying=false; local flySpeed=50; local flyConn

local function applySpeed()
    local char=LocalPlayer.Character; if not char then return end
    local hum=char:FindFirstChildOfClass('Humanoid'); if not hum then return end
    hum.WalkSpeed=speedEnabled and walkSpeed or 16
end
local function applyJump()
    local char=LocalPlayer.Character; if not char then return end
    local hum=char:FindFirstChildOfClass('Humanoid'); if not hum then return end
    hum.UseJumpPower=true; hum.JumpPower=jumpEnabled and jumpPower or 50
end

-- FIX 2+3: AssemblyLinearVelocity + AssemblyAngularVelocity for fly
local function toggleFly(on)
    flying=on; local char=LocalPlayer.Character; if not char then return end
    local root=char:FindFirstChild('HumanoidRootPart'); if not root then return end
    if flying then
        flyConn=RunService.RenderStepped:Connect(function()
            local dir=Vector3.new(0,0,0); local cam=workspace.CurrentCamera
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir-Vector3.new(0,1,0) end
            root.AssemblyLinearVelocity=dir*flySpeed
            root.AssemblyAngularVelocity=Vector3.new(0,0,0)
        end)
    else
        if flyConn then flyConn:Disconnect() end
        root.AssemblyLinearVelocity=Vector3.new(0,0,0)
    end
end
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); if speedEnabled then applySpeed() end; if jumpEnabled then applyJump() end end)

-- ── Weather ───────────────────────────────────────────────────────
local weatherEnabled=false; local selectedWeather='Rain'; local weatherIntensity=31; local weatherColor=Color3.fromRGB(200,220,255)
local OriginalBrightness=Lighting.Brightness; local nextLightning=0; local brightnessPinned=false
local weatherFolder=workspace:FindFirstChild("CustomWeatherFolder") or Instance.new("Folder"); weatherFolder.Name="CustomWeatherFolder"; weatherFolder.Parent=workspace
local weatherParticles={}; local maxParticles=120
for i=1,maxParticles do
    local p=Instance.new("Part"); p.Name="WeatherParticle"; p.Material=Enum.Material.SmoothPlastic; p.Transparency=0.4
    p.CanCollide=false; p.Anchored=true; p.CastShadow=false; p.Parent=weatherFolder
    table.insert(weatherParticles,{Part=p,Active=false,Speed=0,Drift=0})
end
RunService.RenderStepped:Connect(function()
    if Library.Unloaded then return end
    if not weatherEnabled then
        for _,d in ipairs(weatherParticles) do if d.Active then d.Active=false; d.Part.CFrame=CFrame.new(0,-1000,0) end end
        if brightnessPinned then Lighting.Brightness=OriginalBrightness; brightnessPinned=false end; return
    end
    local char=LocalPlayer.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local activeLimit=math.clamp(math.floor((weatherIntensity/100)*maxParticles),5,maxParticles); local center=hrp.Position
    for i=1,maxParticles do
        local d=weatherParticles[i]
        if i<=activeLimit then
            if not d.Active or d.Part.Position.Y<(center.Y-10) then
                d.Part.CFrame=CFrame.new(center+Vector3.new(math.random(-60,60),math.random(20,50),math.random(-60,60))); d.Active=true
                if selectedWeather=='Snow' then d.Part.Size=Vector3.new(0.4,0.4,0.4); d.Part.Shape=Enum.PartType.Ball; d.Speed=math.random(10,25); d.Drift=math.random(-5,5)/10
                elseif selectedWeather=='Storm' then d.Part.Size=Vector3.new(0.09,3.2,0.09); d.Part.Shape=Enum.PartType.Block; d.Speed=math.random(150,220); d.Drift=0
                else d.Part.Size=Vector3.new(0.08,2.5,0.08); d.Part.Shape=Enum.PartType.Block; d.Speed=math.random(80,120); d.Drift=0 end
            else d.Part.CFrame=d.Part.CFrame-Vector3.new(d.Drift,d.Speed*(1/60),0); d.Part.Color=weatherColor end
        else if d.Active then d.Active=false; d.Part.CFrame=CFrame.new(0,-1000,0) end end
    end
    if selectedWeather=='Storm' and tick()>=nextLightning then
        nextLightning=tick()+math.random(40,180)/10; brightnessPinned=true
        task.spawn(function()
            for _=1,math.random(1,3) do Lighting.Brightness=OriginalBrightness+6; task.wait(0.06); if not weatherEnabled or selectedWeather~='Storm' then break end; Lighting.Brightness=OriginalBrightness; task.wait(math.random(4,12)/100) end
            Lighting.Brightness=OriginalBrightness
        end)
    end
end)

-- ── Self Chams & FOV ──────────────────────────────────────────────
local selfChamsEnabled=false; local selfChamsStyle='Highlight'; local selfChamsGradient=false; local selfGradientSpeed=5
local selfFillColor=Color3.fromRGB(255,255,255); local selfOutlineColor=Color3.fromRGB(255,255,255)
local selfFillTrans=0.5; local selfOutlineTrans=0; local fovEnabled=false; local customFov=90
local OriginalFOV=workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local selfHue=0; local savedState={}; local isChamsActive=false

local function saveCharacterState(char)
    savedState={Parts={},Clothing={},Textures={}}
    for _,item in ipairs(char:GetDescendants()) do
        if item:IsA("BasePart") then savedState.Parts[item]={Material=item.Material,Color=item.Color,Transparency=item.Transparency}
        elseif item:IsA("Clothing") or item:IsA("ShirtGraphic") then savedState.Clothing[item]=item.Parent
        elseif item:IsA("Decal") or item:IsA("Texture") then savedState.Textures[item]=item.Transparency end
    end
end
local function restoreCharacterState(char)
    if not isChamsActive then return end; isChamsActive=false
    local hl=char:FindFirstChild("SelfHighlight"); if hl then hl:Destroy() end
    for part,data in pairs(savedState.Parts or {}) do if part and part.Parent then part.Material=data.Material; part.Color=data.Color; part.Transparency=data.Transparency end end
    for item,parent in pairs(savedState.Clothing or {}) do if item then item.Parent=parent end end
    for decal,trans in pairs(savedState.Textures or {}) do if decal and decal.Parent then decal.Transparency=trans end end
    savedState={}
end
local function applySelfChams()
    local char=LocalPlayer.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    if not selfChamsEnabled then restoreCharacterState(char); return end
    if not isChamsActive then saveCharacterState(char); isChamsActive=true end
    local activeColor=selfChamsGradient and Color3.fromHSV(selfHue,1,1) or selfFillColor
    if selfChamsStyle=='Highlight' then
        for item,parent in pairs(savedState.Clothing) do if item then item.Parent=parent end end
        for decal,trans in pairs(savedState.Textures) do if decal then decal.Transparency=trans end end
        for part,data in pairs(savedState.Parts) do if part then part.Material=data.Material; part.Color=data.Color; part.Transparency=data.Transparency end end
        local hl=char:FindFirstChild("SelfHighlight") or Instance.new("Highlight"); hl.Name="SelfHighlight"; hl.Adornee=char; hl.Enabled=true
        hl.FillColor=activeColor; hl.OutlineColor=selfChamsGradient and activeColor or selfOutlineColor; hl.FillTransparency=selfFillTrans; hl.OutlineTransparency=selfOutlineTrans
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
    elseif selfChamsStyle=='ForceField' or selfChamsStyle=='Solid Color' then
        local hl2=char:FindFirstChild("SelfHighlight"); if hl2 then hl2:Destroy() end
        for item in pairs(savedState.Clothing) do if item then item.Parent=nil end end
        for decal in pairs(savedState.Textures) do if decal then decal.Transparency=1 end end
        local mat=(selfChamsStyle=='ForceField') and Enum.Material.ForceField or Enum.Material.SmoothPlastic
        for _,part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then part.Material=mat; part.Color=activeColor; part.Transparency=selfFillTrans
            elseif part:IsA("Accessory") then local h=part:FindFirstChild("Handle"); if h and h:IsA("BasePart") then h.Material=mat; h.Color=activeColor; h.Transparency=selfFillTrans end end
        end
    end
end
RunService.RenderStepped:Connect(function(dt)
    if Library.Unloaded then return end
    if selfChamsGradient then selfHue=(selfHue+(dt*selfGradientSpeed*0.2))%1 end
    applySelfChams(); if fovEnabled then workspace.CurrentCamera.FieldOfView=customFov end
end)
LocalPlayer.CharacterAdded:Connect(function() isChamsActive=false; savedState={} end)

-- ── ColorCorrection & Bloom ───────────────────────────────────────
local ccEffect=Lighting:FindFirstChild("CustomColorCorrection") or Instance.new("ColorCorrectionEffect"); ccEffect.Name="CustomColorCorrection"; ccEffect.Parent=Lighting
local bloomEffect=Lighting:FindFirstChild("CustomBloom") or Instance.new("BloomEffect"); bloomEffect.Name="CustomBloom"; bloomEffect.Parent=Lighting
local ccEnabled=false; local bloomEnabled=false
local function updateColorCorrection(brightness,contrast,saturation,tintColor)
    ccEffect.Enabled=ccEnabled; if ccEnabled then ccEffect.Brightness=brightness; ccEffect.Contrast=contrast; ccEffect.Saturation=saturation; ccEffect.TintColor=tintColor end
end
local function updateBloom(intensity,size,threshold)
    bloomEffect.Enabled=bloomEnabled; if bloomEnabled then bloomEffect.Intensity=intensity; bloomEffect.Size=size; bloomEffect.Threshold=threshold end
end

-- ── Custom Shiftlock ──────────────────────────────────────────────
local ShiftLockSystem={Enabled=false,CurrentID="6031075931",IconSize=32}
local ShiftPresets={["Clean White Dot"]="6031075931",["Red Dot"]="6830874135",["Crosshair Small"]="138380362",["Crosshair Large"]="254508119",["Circle Scope"]="3523723128",["Purple Crosshair"]="6031075931",["Target Scope"]="5820712980"}
local ShiftPresetNames={}; for name,_ in pairs(ShiftPresets) do table.insert(ShiftPresetNames,name) end
local CrosshairGui=Instance.new("ScreenGui"); CrosshairGui.Name="CustomShiftlockOverlay"; CrosshairGui.ResetOnSpawn=false
pcall(function() CrosshairGui.Parent=CoreGui end); if not CrosshairGui.Parent then CrosshairGui.Parent=PlayerGui end
local CrosshairImage=Instance.new("ImageLabel"); CrosshairImage.Name="CursorImage"; CrosshairImage.AnchorPoint=Vector2.new(0.5,0.5); CrosshairImage.BackgroundTransparency=1; CrosshairImage.Size=UDim2.new(0,32,0,32); CrosshairImage.Visible=false; CrosshairImage.Parent=CrosshairGui
local function hideDefaultShiftlock(hide)
    pcall(function()
        local robloxGui=CoreGui:FindFirstChild("RobloxGui") or LocalPlayer.PlayerGui
        for _,v in pairs(robloxGui:GetDescendants()) do if v:IsA("ImageLabel") and (v.Name=="ShiftLockCursor" or v.Name=="MouseIcon") then v.ImageTransparency=hide and 1 or 0 end end
    end)
end
RunService.RenderStepped:Connect(function()
    if Library.Unloaded then return end
    if not ShiftLockSystem.Enabled then CrosshairImage.Visible=false; hideDefaultShiftlock(false); return end
    if UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter then
        hideDefaultShiftlock(true); local vs=workspace.CurrentCamera.ViewportSize
        CrosshairImage.Position=UDim2.new(0,vs.X/2,0,vs.Y/2)
        CrosshairImage.Image="rbxassetid://"..tostring(ShiftLockSystem.CurrentID):gsub("%D","")
        CrosshairImage.Size=UDim2.new(0,ShiftLockSystem.IconSize,0,ShiftLockSystem.IconSize); CrosshairImage.Visible=true
    else CrosshairImage.Visible=false; hideDefaultShiftlock(false) end
end)

-- ── Time Control ──────────────────────────────────────────────────
local TimeSystem={CurrentTime=14,FreezeTime=false}
local function setGameTime(v) TimeSystem.CurrentTime=v; Lighting.ClockTime=v end
RunService.RenderStepped:Connect(function() if TimeSystem.FreezeTime then Lighting.ClockTime=TimeSystem.CurrentTime end end)

-- ── Santa Visuals ─────────────────────────────────────────────────
local function svCreate(className,props,parent)
    local inst=Instance.new(className); local propParent=nil
    for key,value in pairs(props) do if key=='Parent' then propParent=value else inst[key]=value end end
    inst.Parent=propParent or parent; return inst
end
local SV_Original={Exposure=Lighting.ExposureCompensation,FogStart=Lighting.FogStart,FogEnd=Lighting.FogEnd,FogColor=Lighting.FogColor,Fov=workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70}
local SV={Enabled=true,AtmoEnabled=true,Density=0.32,Offset=0.5,Haze=1.8,Glare=0.35,AtmoColor=Color3.fromRGB(199,199,199),AtmoDecay=Color3.fromRGB(106,112,125),CcEnabled=true,Brightness=0,Contrast=0.12,Saturation=0.12,Exposure=0.12,TintColor=Color3.fromRGB(255,244,230),FogEnabled=false,FogStart=150,FogEnd=1400,FogColor=Color3.fromRGB(190,200,215),VignetteEnabled=true,VignetteStrength=0.5}
local SV_Presets={Default={AtmoEnabled=false,CcEnabled=false,FogEnabled=false,VignetteEnabled=false,Exposure=0},Cinematic={AtmoEnabled=true,Density=0.32,Haze=1.8,Glare=0.35,AtmoColor=Color3.fromRGB(199,199,199),AtmoDecay=Color3.fromRGB(106,112,125),CcEnabled=true,Contrast=0.12,Saturation=0.12,TintColor=Color3.fromRGB(255,244,230),Exposure=0.12,VignetteEnabled=true,VignetteStrength=0.5,FogEnabled=false},Hazy={AtmoEnabled=true,Density=0.55,Haze=3.5,Glare=0.15,AtmoColor=Color3.fromRGB(220,220,225),AtmoDecay=Color3.fromRGB(140,145,160),CcEnabled=true,Contrast=0.05,Saturation=-0.08,TintColor=Color3.fromRGB(245,245,250),Exposure=0.08,FogEnabled=true,FogStart=80,FogEnd=900,FogColor=Color3.fromRGB(205,210,220),VignetteEnabled=true,VignetteStrength=0.35},Vibrant={AtmoEnabled=true,Density=0.25,Haze=1.2,Glare=0.45,AtmoColor=Color3.fromRGB(199,199,199),AtmoDecay=Color3.fromRGB(106,112,125),CcEnabled=true,Contrast=0.22,Saturation=0.4,TintColor=Color3.fromRGB(255,255,255),Exposure=0.1,VignetteEnabled=false,FogEnabled=false},Noir={AtmoEnabled=true,Density=0.4,Haze=2.2,Glare=0.1,AtmoColor=Color3.fromRGB(160,160,170),AtmoDecay=Color3.fromRGB(60,60,70),CcEnabled=true,Contrast=0.3,Saturation=-0.85,Brightness=-0.03,TintColor=Color3.fromRGB(235,235,240),Exposure=-0.05,VignetteEnabled=true,VignetteStrength=0.75,FogEnabled=true,FogStart=100,FogEnd=700,FogColor=Color3.fromRGB(40,40,48)},Night={AtmoEnabled=true,Density=0.45,Haze=2.5,Glare=0.05,AtmoColor=Color3.fromRGB(120,135,170),AtmoDecay=Color3.fromRGB(40,45,70),CcEnabled=true,Contrast=0.15,Saturation=-0.15,TintColor=Color3.fromRGB(200,215,255),Exposure=-0.1,VignetteEnabled=true,VignetteStrength=0.6,FogEnabled=true,FogStart=60,FogEnd=600,FogColor=Color3.fromRGB(25,30,50)}}
local SV_Atmosphere=svCreate('Atmosphere',{Name='SantaAtmosphere',Color=SV.AtmoColor,Decay=SV.AtmoDecay},nil)
local SV_CC=svCreate('ColorCorrectionEffect',{Name='SantaColorCorrection',Parent=Lighting})
local svVigGui=svCreate('ScreenGui',{Name='SantaVignette',IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=100,Enabled=false,Parent=PlayerGui})
local svGrads={}
local function svMakeEdge(name,size,pos,rot)
    local f=svCreate('Frame',{Name=name,Size=size,Position=pos,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0,BorderSizePixel=0,ZIndex=5},svVigGui)
    local g=svCreate('UIGradient',{Rotation=rot,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,1)})},f); table.insert(svGrads,g)
end
svMakeEdge('Top',UDim2.new(1,0,0.32,0),UDim2.new(0,0,0,0),90); svMakeEdge('Bottom',UDim2.new(1,0,0.32,0),UDim2.new(0,0,0.68,0),270)
svMakeEdge('Left',UDim2.new(0.32,0,1,0),UDim2.new(0,0,0,0),0); svMakeEdge('Right',UDim2.new(0.32,0,1,0),UDim2.new(0.68,0,0,0),180)
local sv_expActive=false; local sv_fogActive=false
local function svApplyVignette()
    svVigGui.Enabled=SV.Enabled and SV.VignetteEnabled; if not svVigGui.Enabled then return end
    local opaque=1-math.clamp(SV.VignetteStrength,0,1)
    for _,g in ipairs(svGrads) do g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,opaque),NumberSequenceKeypoint.new(1,1)}) end
end
local function svApply()
    local on=SV.Enabled
    if on and SV.AtmoEnabled then SV_Atmosphere.Parent=Lighting; SV_Atmosphere.Density=SV.Density; SV_Atmosphere.Offset=SV.Offset; SV_Atmosphere.Haze=SV.Haze; SV_Atmosphere.Glare=SV.Glare; SV_Atmosphere.Color=SV.AtmoColor; SV_Atmosphere.Decay=SV.AtmoDecay else SV_Atmosphere.Parent=nil end
    SV_CC.Enabled=on and SV.CcEnabled
    if SV_CC.Enabled then SV_CC.Brightness=SV.Brightness; SV_CC.Contrast=SV.Contrast; SV_CC.Saturation=SV.Saturation; SV_CC.TintColor=SV.TintColor end
    local wantExp=on and SV.CcEnabled
    if wantExp then Lighting.ExposureCompensation=SV.Exposure elseif sv_expActive then Lighting.ExposureCompensation=SV_Original.Exposure end; sv_expActive=wantExp
    local wantFog=on and SV.FogEnabled
    if wantFog then Lighting.FogStart=SV.FogStart; Lighting.FogEnd=SV.FogEnd; Lighting.FogColor=SV.FogColor elseif sv_fogActive then Lighting.FogStart=SV_Original.FogStart; Lighting.FogEnd=SV_Original.FogEnd; Lighting.FogColor=SV_Original.FogColor end; sv_fogActive=wantFog
    svApplyVignette()
end
local SV_Sync={}
local function svBindValue(idx,kind,key) table.insert(SV_Sync,{kind=kind,idx=idx,key=key}) end
local function svToggle(parent,idx,key,opts) opts.Callback=function(v) SV[key]=v; svApply() end; parent:AddToggle(idx,opts); svBindValue(idx,'toggle',key) end
local function svSlider(parent,idx,key,opts) opts.Callback=function(v) SV[key]=v; svApply() end; parent:AddSlider(idx,opts); svBindValue(idx,'slider',key) end
local function svColor(parent,label,idx,key,default) parent:AddLabel(label):AddColorPicker(idx,{Default=default,Callback=function(v) SV[key]=v; svApply() end}); svBindValue(idx,'color',key) end
local function svSyncUI()
    for _,e in ipairs(SV_Sync) do
        local cur=SV[e.key]
        if e.kind=='toggle' then if Toggles[e.idx] and Toggles[e.idx].Value~=cur then Toggles[e.idx]:SetValue(cur) end
        elseif e.kind=='slider' then if Options[e.idx] and Options[e.idx].Value~=cur then Options[e.idx]:SetValue(cur) end
        elseif e.kind=='color' then if Options[e.idx] and Options[e.idx].Value~=cur then Options[e.idx]:SetValueRGB(cur) end end
    end
end
local function svApplyPreset(name)
    local p=SV_Presets[name]; if not p then return end; for k,v in pairs(p) do SV[k]=v end; svSyncUI(); svApply()
end

-- FIX 7: Silent Aim — executor-safe hook
local silentAim={enabled=false,teamCheck=false,fov=200,hitpart='Head'}
local function getSilentTarget()
    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    local best,bestDist=nil,silentAim.fov
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LocalPlayer or not p.Character then continue end
        local hum=p.Character:FindFirstChildOfClass('Humanoid'); local part=p.Character:FindFirstChild(silentAim.hitpart) or p.Character:FindFirstChild('HumanoidRootPart')
        if not hum or hum.Health<=0 or not part then continue end
        if silentAim.teamCheck and p.Team==LocalPlayer.Team then continue end
        local sp,onScreen=Camera:WorldToViewportPoint(part.Position); if not onScreen then continue end
        local dist=(Vector2.new(sp.X,sp.Y)-center).Magnitude
        if dist<bestDist then bestDist=dist; best=part end
    end
    return best
end
local SA_hooked=false
pcall(function()
    local mt=getrawmetatable(game); local old_index=rawget(mt,'__index'); setreadonly(mt,false)
    rawset(mt,'__index',newcclosure(function(self,key)
        if silentAim.enabled and self==Mouse then
            if key=='Hit' then local t=getSilentTarget(); if t then return t.CFrame end
            elseif key=='Target' then local t=getSilentTarget(); if t then return t end end
        end
        return old_index(self,key)
    end)); setreadonly(mt,true); SA_hooked=true
end)
if not SA_hooked then
    pcall(function()
        local mt=getrawmetatable(game); local old_nc=rawget(mt,'__namecall'); setreadonly(mt,false)
        rawset(mt,'__namecall',newcclosure(function(self,...)
            local method=getnamecallmethod()
            if silentAim.enabled and self==Mouse then
                if method=='Hit' then local t=getSilentTarget(); if t then return t.CFrame end
                elseif method=='Target' then local t=getSilentTarget(); if t then return t end end
            end
            return old_nc(self,...)
        end)); setreadonly(mt,true)
    end)
end

-- ── GUI ───────────────────────────────────────────────────────────
print("[Santa] OK    LinoriaLib loaded, creating window")
local Window = Library:CreateWindow({Title='Santa V.1',Center=true,AutoShow=true,TabPadding=8,MenuFadeTime=0.2})
local Tabs = {Combat=Window:AddTab('Combat'),Visuals=Window:AddTab('Visuals'),Movement=Window:AddTab('Movement'),Crosshair=Window:AddTab('Crosshair'),Misc=Window:AddTab('Misc'),Settings=Window:AddTab('Settings')}

-- Combat
print("[Santa] OK    tab combat built")
local CL=Tabs.Combat:AddLeftGroupbox('Aimbot'); local CR=Tabs.Combat:AddRightGroupbox('Colors')
local AA=Tabs.Combat:AddRightGroupbox('Anti-Aim'); local TR=Tabs.Combat:AddRightGroupbox('Trigger')
CL:AddToggle('AimbotOn',  {Text='Aimbot',         Default=false,Callback=function(v) aimbotEnabled=v; fovCircle.Visible=v end})
CL:AddToggle('LinkFovCH', {Text='Link FOV',Default=false,Callback=function(v) linkFovToCrosshair=v end})
CL:AddSlider('Smooth',    {Text='Smoothing',       Default=5,  Min=0,  Max=100, Rounding=0,Callback=function(v) smoothing=1-(v/100) end})
CL:AddSlider('PredStr',   {Text='Prediction',      Default=65, Min=0,  Max=200, Rounding=0,Callback=function(v) predictionStr=v/1000 end})
CL:AddSlider('FovSize',   {Text='Radius',      Default=100,Min=0,  Max=1000,Rounding=0,Callback=function(v) aimFov=v; fovCircle.Radius=v end})
CL:AddToggle('WallChk',   {Text='Wall',      Default=true, Callback=function(v) wallCheck=v end})
CL:AddToggle('StickyOn',  {Text='Sticky',      Default=false,Callback=function(v) stickyAim=v end})
CL:AddToggle('TeamChk',   {Text='Team',      Default=false,Callback=function(v) teamCheck=v end})
CL:AddToggle('HealthChk', {Text='Health',    Default=false,Callback=function(v) healthCheck=v end})
CL:AddSlider('MinHp',     {Text='Min HP',      Default=0,  Min=0,  Max=100, Rounding=0,Callback=function(v) minHealth=v end})
CL:AddToggle('RainbowFov',{Text='Rainbow',     Default=false,Callback=function(v) rainbowFov=v end})
CR:AddLabel('FOV'):AddColorPicker('FovCol',{Default=circleColor,Callback=function(v) circleColor=v; if not rainbowFov then fovCircle.Color=v end end})
CR:AddLabel('Target'):AddColorPicker('TgtCol',{Default=targetedColor,Callback=function(v) targetedColor=v end})
CR:AddToggle('TargetHUD_Enable',{Text='Target HUD',Default=false,Callback=function(v) targetHudEnabled=v; if not v then TargetFrame.Visible=false end end})
AA:AddToggle('AA_Enable',      {Text='Anti-Aim',  Default=false,Callback=function(v) antiAim.enabled=v end})
AA:AddToggle('AA_VeloDesync',  {Text='Desync',  Default=false,Callback=function(v) antiAim.velocityDesync=v end})
AA:AddSlider('AA_VeloY',       {Text='Y Offset',  Default=1000,Min=-5000,Max=5000,Rounding=0,Callback=function(v) antiAim.veloY=v end})
AA:AddToggle('AA_Jitter',      {Text='Jitter',  Default=false,Callback=function(v) antiAim.jitter=v end})
AA:AddSlider('AA_JitterRange', {Text='Intensity', Default=5,Min=1,Max=25,Rounding=0,Callback=function(v) antiAim.jitterRange=v end})
AA:AddSlider('AA_Pitch',       {Text='Pitch',      Default=0,Min=-180,Max=180,Rounding=0,Callback=function(v) antiAim.pitch=v end})
AA:AddSlider('AA_Yaw',         {Text='Yaw',        Default=0,Min=-180,Max=180,Rounding=0,Callback=function(v) antiAim.yaw=v end})
AA:AddSlider('AA_Roll',        {Text='Roll',       Default=0,Min=-180,Max=180,Rounding=0,Callback=function(v) antiAim.roll=v end})
TR:AddToggle('TrigOn',   {Text='Enable',                  Default=false,Callback=function(v) trigger.enabled=v end})
TR:AddToggle('TrigTeam', {Text='Team',              Default=false,Callback=function(v) trigger.teamCheck=v end})
TR:AddToggle('TrigHold', {Text='Hold', Default=false,Callback=function(v) trigger.holdMode=v end})
TR:AddSlider('TrigDelay',{Text='Delay',Default=0,Min=0,Max=100,Rounding=0,Callback=function(v) trigger.delay=v/100 end})
TR:AddSlider('TrigCPS',  {Text='Interval',Default=5,Min=1,Max=50, Rounding=0,Callback=function(v) trigger.clickInterval=v/100 end})

-- Silent Aim box
local SAG=Tabs.Combat:AddLeftGroupbox('Silent')
SAG:AddToggle('SAOn',   {Text='Enable',    Default=false,Callback=function(v) silentAim.enabled=v end})
SAG:AddToggle('SATeam', {Text='Team',Default=false,Callback=function(v) silentAim.teamCheck=v end})
SAG:AddSlider('SAFov',  {Text='FOV',       Default=200,Min=0,Max=800,Rounding=0,Callback=function(v) silentAim.fov=v end})
SAG:AddDropdown('SAPart',{Text='Part', Default=1,Values={'Head','UpperTorso','HumanoidRootPart'},Callback=function(v) silentAim.hitpart=v end})

-- Visuals
print("[Santa] OK    tab visuals built")
local VL=Tabs.Visuals:AddLeftGroupbox('ESP'); local VR=Tabs.Visuals:AddRightGroupbox('World')
VL:AddToggle('ESPOn',   {Text='ESP',      Default=false,Callback=function(v) ESPToggles.master=v end})
VL:AddToggle('ESPBox',  {Text='Box',             Default=true, Callback=function(v) ESPToggles.box=v end})
VL:AddToggle('ESPFill', {Text='Fill',        Default=false,Callback=function(v) ESPToggles.fill=v end})
VL:AddToggle('ESPName', {Text='Name',            Default=true, Callback=function(v) ESPToggles.name=v end})
VL:AddToggle('ESPDist', {Text='Distance',        Default=true, Callback=function(v) ESPToggles.distance=v end})
VL:AddToggle('ESPWep',  {Text='Weapon',          Default=false,Callback=function(v) ESPToggles.weapon=v end})
VL:AddToggle('ESPHp',   {Text='Health',      Default=true, Callback=function(v) ESPToggles.healthbar=v end})
VL:AddToggle('ESPSkel', {Text='Skeleton',        Default=false,Callback=function(v) ESPToggles.skeleton=v end})
VL:AddToggle('ESPSkelO',{Text='Skel Outline',Default=false,Callback=function(v) ESPToggles.skeletonOutline=v end})
VR:AddDropdown('ESPType',{Text='Type',Default=1,Values={'static','dynamic'},Callback=function(v) ESPOptions.boundsType=v end})
VR:AddSlider('ESPScale', {Text='Scale',Default=100,Min=50,Max=200,Rounding=0,Callback=function(v) ESPOptions.boundsScale=v end})
VR:AddLabel('Color'):AddColorPicker('ESPCol',{Default=ESPOptions.color,Callback=function(v) ESPOptions.color=v end})
VR:AddDivider()
VR:AddToggle('Visuals_Enabled',      {Text='Highlight',   Default=false})
VR:AddToggle('Visuals_Gradient',     {Text='Rainbow',  Default=false})
VR:AddSlider('Visuals_GradientSpeed',{Text='Speed',      Default=5,Min=1,Max=20,Rounding=0})
VR:AddToggle('Visuals_Fill',         {Text='Fill',        Default=true})
VR:AddSlider('Visuals_FillTransparency',{Text='Transparency',Default=0.5,Min=0,Max=1,Rounding=2})
VR:AddLabel('Fill'):AddColorPicker('Visuals_FillColor',{Default=Color3.fromRGB(255,0,0)})
VR:AddToggle('Visuals_Outline',      {Text='Outline',     Default=true})
VR:AddSlider('Visuals_OutlineTransparency',{Text='Transparency',Default=0,Min=0,Max=1,Rounding=2})
VR:AddLabel('Outline'):AddColorPicker('Visuals_OutlineColor',{Default=Color3.fromRGB(255,255,255)})
VR:AddDivider()
VR:AddToggle('Ambient_Enabled',{Text='Ambient',Default=false})
VR:AddLabel('Ambient'):AddColorPicker('Ambient_Color',{Default=Color3.fromRGB(128,128,128)})
VR:AddLabel('Outdoor'):AddColorPicker('OutdoorAmbient_Color',{Default=Color3.fromRGB(128,128,128)})
VL:AddDivider()
VL:AddToggle('Skybox_Enabled',{Text='Skybox',Default=false})
VL:AddDropdown('Skybox_Preset',{Values={'Default','Purple Nebula','Night Sky','Pink Sky','Sunset'},Default=1,Text='Preset'})
VL:AddInput('Skybox_CustomID',{Default='',Numeric=true,Finished=true,Text='Skybox ID',Placeholder='Dont Use'})
VR:AddToggle('Weather_Enabled',  {Text='Weather',Default=false,Callback=function(v) weatherEnabled=v end})
VR:AddDropdown('Weather_Type',   {Values={'Rain','Snow','Storm'},Default=1,Multi=false,Text='Type',Callback=function(v) selectedWeather=v end})
VR:AddSlider('Weather_Intensity',{Text='Intensity',Default=31,Min=5,Max=100,Rounding=0,Callback=function(v) weatherIntensity=v end})
VR:AddLabel('Color'):AddColorPicker('Weather_Color',{Default=Color3.fromRGB(200,220,255),Callback=function(v) weatherColor=v end})
VR:AddDivider()
VR:AddToggle('SelfChams_Enabled', {Text='Self Chams',Default=false,Callback=function(v) selfChamsEnabled=v end})
VR:AddDropdown('SelfChams_Style', {Values={'Highlight','ForceField','Solid Color'},Default=1,Multi=false,Text='Style',Callback=function(v) selfChamsStyle=v end})
VR:AddToggle('SelfChams_Gradient',{Text='Rainbow',Default=false,Callback=function(v) selfChamsGradient=v end})
VR:AddSlider('SelfChams_GradSpeed',{Text='Rate',Default=5,Min=1,Max=20,Rounding=0,Callback=function(v) selfGradientSpeed=v end})
VR:AddSlider('SelfChams_FillTrans',{Text='Alpha',Default=0,Min=0,Max=100,Rounding=0,Callback=function(v) selfFillTrans=v/100 end})
VR:AddLabel('Fill'):AddColorPicker('SelfChams_Color',{Default=Color3.fromRGB(255,255,255),Callback=function(v) selfFillColor=v end})
VR:AddLabel('Outline'):AddColorPicker('SelfChams_OutlineColor',{Default=Color3.fromRGB(255,255,255),Callback=function(v) selfOutlineColor=v end})
VR:AddDivider()
VR:AddToggle('FOV_Enabled',{Text='FOV',Default=false,Callback=function(v) fovEnabled=v; if not v then workspace.CurrentCamera.FieldOfView=OriginalFOV end end})
VR:AddSlider('FOV_Value',  {Text='Field',Default=90,Min=30,Max=120,Rounding=0,Callback=function(v) customFov=v end})

local VL_BloomCC=Tabs.Visuals:AddLeftGroupbox('Bloom')
VL_BloomCC:AddToggle('CC_Enabled',  {Text='Color',Default=false,Callback=function(v) ccEnabled=v; updateColorCorrection(Options.CC_Brightness.Value/100,Options.CC_Contrast.Value/100,Options.CC_Saturation.Value/100,Options.CC_TintColor.Value) end})
VL_BloomCC:AddSlider('CC_Brightness',{Text='Brightness',Default=0,  Min=-100,Max=100,Rounding=0,Callback=function(v) updateColorCorrection(v/100,Options.CC_Contrast.Value/100,Options.CC_Saturation.Value/100,Options.CC_TintColor.Value) end})
VL_BloomCC:AddSlider('CC_Contrast',  {Text='Contrast',  Default=0,  Min=-100,Max=100,Rounding=0,Callback=function(v) updateColorCorrection(Options.CC_Brightness.Value/100,v/100,Options.CC_Saturation.Value/100,Options.CC_TintColor.Value) end})
VL_BloomCC:AddSlider('CC_Saturation',{Text='Saturation',Default=0,  Min=-100,Max=100,Rounding=0,Callback=function(v) updateColorCorrection(Options.CC_Brightness.Value/100,Options.CC_Contrast.Value/100,v/100,Options.CC_TintColor.Value) end})
VL_BloomCC:AddLabel('Tint'):AddColorPicker('CC_TintColor',{Default=Color3.fromRGB(255,255,255),Callback=function(v) updateColorCorrection(Options.CC_Brightness.Value/100,Options.CC_Contrast.Value/100,Options.CC_Saturation.Value/100,v) end})
VL_BloomCC:AddDivider()
VL_BloomCC:AddToggle('Bloom_Enabled',  {Text='Bloom',Default=false,Callback=function(v) bloomEnabled=v; updateBloom(Options.Bloom_Intensity.Value/5,Options.Bloom_Size.Value,Options.Bloom_Threshold.Value/100) end})
VL_BloomCC:AddSlider('Bloom_Intensity',{Text='Intensity',Default=15,Min=0,Max=50, Rounding=0,Callback=function(v) updateBloom(v/5,Options.Bloom_Size.Value,Options.Bloom_Threshold.Value/100) end})
VL_BloomCC:AddSlider('Bloom_Size',     {Text='Size',     Default=24,Min=1,Max=56, Rounding=0,Callback=function(v) updateBloom(Options.Bloom_Intensity.Value/5,v,Options.Bloom_Threshold.Value/100) end})
VL_BloomCC:AddSlider('Bloom_Threshold',{Text='Threshold',Default=0, Min=0,Max=100,Rounding=0,Callback=function(v) updateBloom(Options.Bloom_Intensity.Value/5,Options.Bloom_Size.Value,v/100) end})

local TimeGroup=Tabs.Visuals:AddRightGroupbox('Time')
TimeGroup:AddSlider('TimeSlider',    {Text='Time',Default=14,Min=0,Max=24,Rounding=1,Callback=function(v) setGameTime(v) end})
TimeGroup:AddToggle('FreezeTimeToggle',{Text='Lock Time',Default=false,Callback=function(v) TimeSystem.FreezeTime=v end})
TimeGroup:AddButton({Text='Day',   Func=function() Options.TimeSlider:SetValue(12) end})
TimeGroup:AddButton({Text='Night',  Func=function() Options.TimeSlider:SetValue(0)  end})
TimeGroup:AddButton({Text='Sunset',Func=function() Options.TimeSlider:SetValue(18) end})

local SV_PresetGrp=Tabs.Visuals:AddLeftGroupbox('Presets')
SV_PresetGrp:AddDropdown('SV_PresetSelect',{Values={'Default','Cinematic','Hazy','Vibrant','Noir','Night'},Default=1,Text='Preset'})
SV_PresetGrp:AddButton({Text='Apply Preset',Func=function() svApplyPreset(Options.SV_PresetSelect.Value) end})

local SV_AtmoGrp=Tabs.Visuals:AddLeftGroupbox('Atmosphere')
svToggle(SV_AtmoGrp,'SV_AtmoOn','AtmoEnabled',{Text='Atmosphere',Default=false})
local SV_AtmoBox=SV_AtmoGrp:AddDependencyBox()
svSlider(SV_AtmoBox,'SV_Density','Density',{Text='Density',Default=0.32,Min=0,Max=1, Rounding=2})
svSlider(SV_AtmoBox,'SV_Offset', 'Offset', {Text='Offset', Default=0.5, Min=0,Max=1, Rounding=2})
svSlider(SV_AtmoBox,'SV_Haze',   'Haze',   {Text='Haze',   Default=1.8, Min=0,Max=10,Rounding=1})
svSlider(SV_AtmoBox,'SV_Glare',  'Glare',  {Text='Glare',  Default=0.35,Min=0,Max=2, Rounding=2})
svColor(SV_AtmoBox,'Atmo', 'SV_AtmoColor','AtmoColor',Color3.fromRGB(199,199,199))
svColor(SV_AtmoBox,'Decay','SV_AtmoDecay','AtmoDecay',Color3.fromRGB(106,112,125))
SV_AtmoBox:SetupDependencies({{Toggles.SV_AtmoOn,true}})

local SV_FogGrp=Tabs.Visuals:AddRightGroupbox('Fog')
svToggle(SV_FogGrp,'SV_FogOn','FogEnabled',{Text='Fog',Default=false})
local SV_FogBox=SV_FogGrp:AddDependencyBox()
svSlider(SV_FogBox,'SV_FogStart','FogStart',{Text='Start',Default=150, Min=0,  Max=2000, Rounding=0})
svSlider(SV_FogBox,'SV_FogEnd',  'FogEnd',  {Text='End',  Default=1400,Min=100,Max=10000,Rounding=0})
svColor(SV_FogBox,'Color','SV_FogColor','FogColor',Color3.fromRGB(190,200,215))
SV_FogBox:SetupDependencies({{Toggles.SV_FogOn,true}})

local SV_VigGrp=Tabs.Visuals:AddRightGroupbox('Vignette')
svToggle(SV_VigGrp,'SV_VigOn','VignetteEnabled',{Text='Vignette',Default=true})
local SV_VigBox=SV_VigGrp:AddDependencyBox()
svSlider(SV_VigBox,'SV_VigStr','VignetteStrength',{Text='Strength',Default=0.5,Min=0,Max=1,Rounding=2})
SV_VigBox:SetupDependencies({{Toggles.SV_VigOn,true}})

RunService.RenderStepped:Connect(function() if Library.Unloaded then return end; svApply() end)
Options.SV_PresetSelect:OnChanged(function(v) svApplyPreset(v) end)
svApply()

-- Movement
print("[Santa] OK    tab movement built")
local ML=Tabs.Movement:AddLeftGroupbox('Player')
ML:AddToggle('SpeedOn',  {Text='Speed',Default=false,Callback=function(v) speedEnabled=v; applySpeed() end})
ML:AddSlider('WalkSpd',  {Text='Walk',   Default=16,Min=16,Max=500,Rounding=0,Callback=function(v) walkSpeed=v; if speedEnabled then applySpeed() end end})
ML:AddToggle('FlyOn',    {Text='Fly',          Default=false,Callback=function(v) toggleFly(v) end})
ML:AddSlider('FlySpd',   {Text='Speed',    Default=50,Min=10,Max=300,Rounding=0,Callback=function(v) flySpeed=v end})
ML:AddToggle('JumpOn',   {Text='Jump',Default=false,Callback=function(v) jumpEnabled=v; applyJump() end})
ML:AddSlider('JumpPwr',  {Text='Power',   Default=50,Min=50,Max=500,Rounding=0,Callback=function(v) jumpPower=v; if jumpEnabled then applyJump() end end})
ML:AddToggle('SpinBotOn',{Text='Spin',      Default=false,Callback=function(v) spinEnabled=v end})
ML:AddSlider('SpinSpeed',{Text='Speed',   Default=10,Min=1,Max=100,Rounding=0,Callback=function(v) spinSpeed=v end})
ML:AddDropdown('SpinMode',{Text='Mode',   Default=1,Values={'Linear','Jitter'},Callback=function(v) spinMode=v end})

-- Crosshair
print("[Santa] OK    tab crosshair built")
local CHL=Tabs.Crosshair:AddLeftGroupbox('Main'); local CHR=Tabs.Crosshair:AddRightGroupbox('Circle')
CHL:AddToggle('CHVis',    {Text='Crosshair',   Default=false,Callback=function(v) CH.Visible=v end})
CHL:AddSlider('CHSpin',   {Text='Speed',        Default=5,  Min=0, Max=50, Rounding=0,Callback=function(v) CH.SpinSpeed=v/1000 end})
CHL:AddSlider('CHGap',    {Text='Gap',  Default=8,  Min=0, Max=50, Rounding=0,Callback=function(v) CH.CentralGap=v end})
CHL:AddSlider('CHLen',    {Text='Length', Default=112,Min=10,Max=300,Rounding=0,Callback=function(v) CH.TotalLength=v; initCH() end})
CHL:AddSlider('CHThick',  {Text='Thickness',    Default=2,  Min=1, Max=10, Rounding=0,Callback=function(v) CH.LineThickness=v end})
CHL:AddSlider('CHOut',    {Text='Outline Size', Default=4,  Min=0, Max=15, Rounding=0,Callback=function(v) CH.OutlineThickness=v end})
CHL:AddToggle('CHTrack',  {Text='Tracking',   Default=false,Callback=function(v) CH.TrackingEnabled=v end})
CHL:AddSlider('CHTRad',   {Text='Radius',   Default=150,Min=10,Max=800,Rounding=0,Callback=function(v) CH.TrackingRadius=v end})
CHL:AddSlider('CHTSmooth',{Text='Smoothness',Default=20,Min=1,Max=100,Rounding=0,Callback=function(v) CH.TrackingSmoothness=v/100 end})
CHL:AddDropdown('CHTgt',  {Text='Part',       Default=1,Values={'Head','HumanoidRootPart'},Callback=function(v) CH.TrackPart=v end})
CHL:AddToggle('CHTChk',   {Text='Team',        Default=true,Callback=function(v) CH.TeamCheck=v end})
CHR:AddToggle('CHCirVis', {Text='Visible',    Default=true,Callback=function(v) CH.CircleVisible=v end})
CHR:AddSlider('CHCirR',   {Text='Radius',     Default=119,Min=10,Max=300,Rounding=0,Callback=function(v) CH.CircleRadius=v end})
CHR:AddSlider('CHCirT',   {Text='Transparency',      Default=30, Min=0, Max=100,Rounding=0,Callback=function(v) CH.CircleTransparency=v/100 end})
CHR:AddLabel('Start'):AddColorPicker('CHColS',{Default=Color3.fromRGB(180,180,180),Callback=function(v) CH.ColorStart=v end})
CHR:AddLabel('End'):AddColorPicker('CHColE',  {Default=Color3.fromRGB(20,20,20),   Callback=function(v) CH.ColorEnd=v end})
CHR:AddLabel('Color'):AddColorPicker('CHCirC',{Default=Color3.fromRGB(15,15,25), Callback=function(v) CH.CircleColor=v end})
local SG=Tabs.Crosshair:AddLeftGroupbox('Crosshair Icon')
SG:AddToggle('EnableShiftIcon',{Text='Custom Icon',Default=false,Callback=function(v) ShiftLockSystem.Enabled=v end})
SG:AddDropdown('PresetShiftDropdown',{Values=ShiftPresetNames,Default=1,Multi=false,Text='Preset',Callback=function(v) local id=ShiftPresets[v]; if id then ShiftLockSystem.CurrentID=id end end})
SG:AddInput('CustomShiftID_Input',{Default='',Numeric=true,Finished=true,Text='Asset ID',Placeholder='Custom ID eingeben...',Callback=function(v) if v and v~="" then ShiftLockSystem.CurrentID=v end end})
SG:AddSlider('ShiftIconSizeSlider',{Text='Size',Default=32,Min=10,Max=100,Rounding=0,Callback=function(v) ShiftLockSystem.IconSize=v end})

-- Misc
print("[Santa] OK    tab misc built")
local MiscGroup=Tabs.Misc:AddLeftGroupbox('Watermark')
MiscGroup:AddToggle('WM_Enabled',{Text='Watermark',Default=true,Callback=function(v) WM_Config.Enabled=v; Library:SetWatermarkVisibility(v) end})
MiscGroup:AddInput('WM_Text',    {Default='Santa V.1',Numeric=false,Finished=true,Text='Title',Placeholder='Text eingeben...',Callback=function(v) WM_Config.Text=v end})
MiscGroup:AddToggle('WM_ShowFPS', {Text='FPS', Default=true,Callback=function(v) WM_Config.ShowFPS=v end})
MiscGroup:AddToggle('WM_ShowPing',{Text='Ping',Default=true,Callback=function(v) WM_Config.ShowPing=v end})
MiscGroup:AddToggle('WM_ShowTime',{Text='Time',Default=true,Callback=function(v) WM_Config.ShowTime=v end})
local LocalPlayerGroup=Tabs.Misc:AddRightGroupbox('Local')
LocalPlayerGroup:AddToggle('Enable_ShiftLock',{Text='Shift Lock',Default=false,Tooltip='Allows mouse-lock camera control',Callback=function(v) pcall(function() LocalPlayer.DevEnableMouseLock=v end) end})

-- Settings
print("[Santa] OK    tab settings built")
local UL=Tabs.Settings:AddLeftGroupbox('Menu')
UL:AddButton({Text='Unload',Func=function() Library:Unload() end})
-- Menu key: own handler (reads Settings > Menu Keybind). Linoria's built-in
-- ToggleKeybind is disabled so the two can't cancel each other out.
-- The window is found by its title label and shown/hidden via its ScreenGui,
-- so it does not depend on any particular Library method existing.
Library.ToggleKeybind = nil -- handled below with the same toggleMenu as the button
do
    local UIS_menu = game:GetService("UserInputService")
    local menuGui
    local lastSearch = 0
    local WINDOW_TITLE = "Santa V.1"

    -- Search only when needed, and at most once per second when it fails,
    -- so pressing keys never triggers a full GUI scan every time.
    -- Finds the main window frame: the top-level Frame (child of its ScreenGui)
    -- that contains the title label. Hiding that frame closes the menu.
    local function findMenuRoot()
        if menuGui and menuGui.Parent then return menuGui end
        if tick() - lastSearch < 1 then return nil end
        lastSearch = tick()
        local ok, found = pcall(function()
            for _, root in ipairs({ game:GetService("CoreGui"), PlayerGui }) do
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text == WINDOW_TITLE then
                        local node = d
                        while node.Parent and not node.Parent:IsA("ScreenGui") do
                            node = node.Parent
                        end
                        if node:IsA("GuiObject") and node.Parent and node.Parent:IsA("ScreenGui") then
                            return node
                        end
                    end
                end
            end
            return nil
        end)
        if ok and found then menuGui = found; return found end
        return nil
    end

    local menuShown = true
    local reported = false
    local function toggleMenu()
        local ok, err = pcall(function()
            local win = findMenuRoot()
            if not win then
                warn("[Menu] could not find the menu window (title '" .. WINDOW_TITLE .. "')")
                return
            end
            menuShown = not menuShown
            win.Visible = menuShown
            if not reported then
                reported = true
                print("[Menu] window '" .. win.Name .. "' is now " .. (menuShown and "shown" or "hidden"))
            end
        end)
        if not ok then warn("[Menu] toggle error: " .. tostring(err)) end
    end

    -- Menu key: Right Shift (or the key set in Settings) calls the same toggleMenu as the button
    local UIS_menu = game:GetService("UserInputService")
    local menuKeyConn = UIS_menu.InputBegan:Connect(function(input, gameProcessed)
        if Library.Unloaded then return end
        local kb = Options.MenuKeybind
        local bound = kb and kb.Value
        local isMenuKey = input.KeyCode == Enum.KeyCode.RightShift
            or (type(bound) == "string" and input.KeyCode.Name == bound)
        -- TEMP: log every keyboard key, so we can tell whether this listener receives input at all
        if input.UserInputType == Enum.UserInputType.Keyboard then
            print("[Menu] any key: " .. input.KeyCode.Name)
        end
        if isMenuKey or input.KeyCode.Name:find("Shift") then
            print("[Menu] key " .. input.KeyCode.Name .. " pressed (gameProcessed=" .. tostring(gameProcessed)
                .. ", textbox focused=" .. tostring(UIS_menu:GetFocusedTextBox() ~= nil) .. ")")
        end
        if not isMenuKey then return end
        -- Right Shift always toggles; the bound key is ignored while a textbox has focus
        if UIS_menu:GetFocusedTextBox() and input.KeyCode ~= Enum.KeyCode.RightShift then return end
        toggleMenu()
    end)
    Library:OnUnload(function() menuKeyConn:Disconnect() end)
    print("[Santa] OK    menu key listener (RightShift + " .. tostring(Options.MenuKeybind and Options.MenuKeybind.Value) .. ")")

    -- keybind for the same action, shown on its own row
    UL:AddLabel('Menu'):AddKeyPicker('MenuKeybind',{Default='RightShift',NoUI=false,Text='Menu'})

end

-- Visuals logic (post UI init)
local OriginalAmbient=Lighting.Ambient; local OriginalOutdoorAmbient=Lighting.OutdoorAmbient
local SkyboxPresets={['Purple Nebula']='rbxassetid://159454299',['Night Sky']='rbxassetid://12064107',['Pink Sky']='rbxassetid://271042516',Sunset='rbxassetid://600832712'}
local function applyHighlight(player)
    if player==LocalPlayer then return end
    local function setupCharacter(character)
        if not character then return end
        local hl=character:FindFirstChild("CustomHighlight") or Instance.new("Highlight")
        hl.Name="CustomHighlight"; hl.Adornee=character
        hl.Enabled=Toggles.Visuals_Enabled.Value; hl.FillColor=Options.Visuals_FillColor.Value; hl.OutlineColor=Options.Visuals_OutlineColor.Value
        hl.FillTransparency=Toggles.Visuals_Fill.Value and Options.Visuals_FillTransparency.Value or 1
        hl.OutlineTransparency=Toggles.Visuals_Outline.Value and Options.Visuals_OutlineTransparency.Value or 1; hl.Parent=character
    end
    if player.Character then setupCharacter(player.Character) end
    player.CharacterAdded:Connect(setupCharacter)
end
for _,p in ipairs(Players:GetPlayers()) do applyHighlight(p) end
Players.PlayerAdded:Connect(applyHighlight)

local hGradient=0; local mainConnection
mainConnection=RunService.RenderStepped:Connect(function(deltaTime)
    if Library.Unloaded then if mainConnection then mainConnection:Disconnect() end; return end
    if Toggles.Visuals_Gradient.Value then hGradient=(hGradient+(deltaTime*Options.Visuals_GradientSpeed.Value*0.2))%1 end
    local gradColor=Color3.fromHSV(hGradient,1,1)
    for _,player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("CustomHighlight") then
            local hl=player.Character.CustomHighlight; hl.Enabled=Toggles.Visuals_Enabled.Value
            if Toggles.Visuals_Gradient.Value then hl.FillColor=gradColor; hl.OutlineColor=gradColor
            else hl.FillColor=Options.Visuals_FillColor.Value; hl.OutlineColor=Options.Visuals_OutlineColor.Value end
            hl.FillTransparency=Toggles.Visuals_Fill.Value and Options.Visuals_FillTransparency.Value or 1
            hl.OutlineTransparency=Toggles.Visuals_Outline.Value and Options.Visuals_OutlineTransparency.Value or 1
        end
    end
    if Toggles.Ambient_Enabled.Value then Lighting.Ambient=Options.Ambient_Color.Value; Lighting.OutdoorAmbient=Options.OutdoorAmbient_Color.Value
    else Lighting.Ambient=OriginalAmbient; Lighting.OutdoorAmbient=OriginalOutdoorAmbient end
end)

local function updateSkybox()
    local sky=Lighting:FindFirstChildOfClass("Sky")
    if not Toggles.Skybox_Enabled.Value then if sky and sky.Name=="SantaCustomSky" then sky:Destroy() end; return end
    if not sky or sky.Name~="SantaCustomSky" then sky=Instance.new("Sky"); sky.Name="SantaCustomSky"; sky.Parent=Lighting end
    local selectedPreset=Options.Skybox_Preset.Value; local customId=Options.Skybox_CustomID.Value; local textureUri=''
    if customId and customId~='' then textureUri='rbxassetid://'..customId elseif SkyboxPresets[selectedPreset] then textureUri=SkyboxPresets[selectedPreset] end
    if textureUri~='' then sky.SkyboxBk=textureUri; sky.SkyboxDn=textureUri; sky.SkyboxFt=textureUri; sky.SkyboxLf=textureUri; sky.SkyboxRt=textureUri; sky.SkyboxUp=textureUri end
end
Toggles.Skybox_Enabled:OnChanged(updateSkybox); Options.Skybox_Preset:OnChanged(updateSkybox); Options.Skybox_CustomID:OnChanged(updateSkybox)

local FrameCounter=0; local LastGetFps=tick(); local CurrentFPS=60
RunService.RenderStepped:Connect(function()
    if Library.Unloaded then return end
    FrameCounter=FrameCounter+1
    if (tick()-LastGetFps)>=1 then CurrentFPS=FrameCounter; FrameCounter=0; LastGetFps=tick() end
    if WM_Config.Enabled then
        local parts={}
        if WM_Config.Text~="" then table.insert(parts,WM_Config.Text) end
        if WM_Config.ShowFPS then table.insert(parts,string.format("%d fps",CurrentFPS)) end
        if WM_Config.ShowPing then local ok,ping=pcall(function() return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end); if ok then table.insert(parts,ping.."ms") end end
        if WM_Config.ShowTime then table.insert(parts,os.date("%X")) end
        Library:SetWatermark(table.concat(parts," | "))
    end
end)

Library:SetWatermarkVisibility(WM_Config.Enabled)
ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings(); SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('TeddyHub'); SaveManager:SetFolder('TeddyHub/Config')
SaveManager:BuildConfigSection(Tabs.Settings); ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
print("[Santa] OK    LinoriaLib + managers loaded")

-- ════════════════════════════════════════════════════════════════════
-- MUSIC PLAYER
-- Reads .mp3/.ogg/.flac files from: Santa_V1/Songs/
-- Supports: play/pause, next/prev, shuffle, repeat modes,
--           volume, pitch, bass boost, visualizer bar,
--           seek (timeposition), queue, favourites, search filter
-- ════════════════════════════════════════════════════════════════════
local MP = {}
local function __buildMusicPlayer()
    MP.FOLDER       = "Santa_V1/Songs"
    MP.EXTS         = {mp3=true, ogg=true, flac=true, wav=true}
    MP.songs        = {}       -- {name=string, path=string}
    MP.queue        = {}       -- indices into MP.songs
    MP.queueIndex   = 0
    MP.favourites   = {}       -- set of song names
    MP.playing      = false
    MP.paused       = false
    MP.volume       = 0.8
    MP.pitch        = 1.0
    MP.bassBoost    = 0
    MP.repeatMode   = "off"    -- "off" | "one" | "all"
    MP.shuffle      = false
    MP.showViz      = true
    MP.sound        = nil      -- Sound instance
    MP.eqEnabled    = false
    MP.eqBass       = 0        -- EqualizerSoundEffect Bass
    MP.eqMid        = 0
    MP.eqTreble     = 0
    MP.searchFilter = ""
    MP.vizConn      = nil
    MP.autoConn     = nil

    -- ensure folder exists
    pcall(function()
        if not isfolder("Santa_V1") then makefolder("Santa_V1") end
        if not isfolder(MP.FOLDER)  then makefolder(MP.FOLDER)  end
    end)

    -- scan folder for songs (logs every step so a failure is visible)
    local function scanSongs()
        MP.songs = {}
        if not listfiles then
            warn("[Music] executor has no listfiles()"); return
        end
        local okList, entries = pcall(listfiles, MP.FOLDER)
        if not okList then
            warn("[Music] listfiles failed for " .. MP.FOLDER .. ": " .. tostring(entries))
            return
        end
        print("[Music] listfiles returned " .. #entries .. " entr" .. (#entries == 1 and "y" or "ies"))
        for _, f in ipairs(entries) do
            print("[Music]   raw: " .. tostring(f))
            local name = tostring(f):match("([^/\\]+)$") or tostring(f)
            local ext  = name:match("%.(%w+)$")
            if ext and MP.EXTS[ext:lower()] then
                table.insert(MP.songs, {name=name, path=tostring(f)})
            end
        end
        table.sort(MP.songs, function(a,b) return a.name < b.name end)
    end

    -- rebuild queue from current songs (respecting filter)
    local function rebuildQueue()
        MP.queue = {}
        local filter = MP.searchFilter:lower()
        for i, s in ipairs(MP.songs) do
            if filter == "" or s.name:lower():find(filter, 1, true) then
                table.insert(MP.queue, i)
            end
        end
        if MP.shuffle then
            for i = #MP.queue, 2, -1 do
                local j = math.random(1, i)
                MP.queue[i], MP.queue[j] = MP.queue[j], MP.queue[i]
            end
        end
    end

    -- create/get sound in workspace
    local function getSound()
        if MP.sound and MP.sound.Parent then return MP.sound end
        local s = Instance.new("Sound")
        s.Name = "SantaMusicPlayer"
        s.Parent = game:GetService("SoundService")
        s.Volume = MP.volume
        s.PlaybackSpeed = MP.pitch
        -- EQ
        local eq = Instance.new("EqualizerSoundEffect"); eq.Name="MP_EQ"; eq.Parent=s
        -- Bass boost via PitchShift trick + EQ bass
        MP.sound = s
        return s
    end

    local function applyEffects()
        if not MP.sound then return end
        MP.sound.Volume = MP.volume
        MP.sound.PlaybackSpeed = MP.pitch
        local eq = MP.sound:FindFirstChild("MP_EQ")
        if eq then
            eq.Enabled  = MP.eqEnabled or MP.bassBoost ~= 0
            eq.LowGain  = MP.eqEnabled and MP.eqBass   or 0
            eq.MidGain  = MP.eqEnabled and MP.eqMid    or 0
            eq.HighGain = MP.eqEnabled and MP.eqTreble or 0
            -- bass boost adds on top of eq
            if MP.bassBoost ~= 0 then
                eq.Enabled = true
                eq.LowGain = math.clamp((eq.LowGain or 0) + MP.bassBoost, -80, 10)
            end
        end
    end

    local function stopSound()
        if MP.sound then
            pcall(function() MP.sound:Stop() end)
        end
        MP.playing = false; MP.paused = false
    end

    -- UI label refs are managed via MP._nowPlayingLabel (set after viz build)
    local vizBars = {}
    local vizFrame

    local function updateProgressUI()
        -- progress is handled via the MP_Seek slider in the heartbeat loop
    end

    -- visualizer is animated in its own RenderStepped loop (see below)
    local function updateViz() end

    local songListDropdown  -- will be set after UI is built

    local function refreshSongList()
        scanSongs(); rebuildQueue()
        print("[Music] found " .. #MP.songs .. " song(s) in " .. MP.FOLDER)
        if songListDropdown then
            local names = {}
            for _, i in ipairs(MP.queue) do table.insert(names, MP.songs[i].name) end
            if #names == 0 then names = {"(no songs found)"} end
            local ok, err = pcall(function() songListDropdown:SetValues(names) end)
            if not ok then warn("[Music] could not update song list: " .. tostring(err)) end
        end
    end

    local function getCurrentSongIdx()
        if MP.queueIndex < 1 or MP.queueIndex > #MP.queue then return nil end
        return MP.queue[MP.queueIndex]
    end

    local function playSong(qIdx)
        if not MP.songs[qIdx] then return end
        local song = MP.songs[qIdx]
        stopSound()
        local s = getSound()
        -- Custom files can only be played through getcustomasset (executor API).
        -- rbxasset:// only resolves Roblox's own content, not files in the workspace folder.
        if not getcustomasset then
            warn("[Music] getcustomasset is not supported by this executor")
            if MP._nowPlayingLabel then MP._nowPlayingLabel.Text = "Executor lacks getcustomasset" end
            return
        end
        local okAsset, assetId = pcall(getcustomasset, song.path)
        if not okAsset or not assetId then
            warn("[Music] getcustomasset failed for "..song.path..": "..tostring(assetId))
            if MP._nowPlayingLabel then MP._nowPlayingLabel.Text = "Load error: "..song.name end
            return
        end
        s.SoundId = assetId
        applyEffects()
        local okPlay, errPlay = pcall(function() s:Play() end)
        if not okPlay then warn("[Music] Play failed: "..tostring(errPlay)) end
        MP.playing = true; MP.paused = false
        MP.currentSongName = song.name
        -- update now-playing overlay label (set after UI build)
        if MP._nowPlayingLabel then
            local display = song.name:match("(.+)%..+$") or song.name
            MP._nowPlayingLabel.Text = (MP.favourites[song.name] and "* " or "") .. display
        end
    end

    local function playIndex(newQueueIdx)
        if #MP.queue == 0 then return end
        newQueueIdx = ((newQueueIdx - 1) % #MP.queue) + 1
        MP.queueIndex = newQueueIdx
        local songIdx = getCurrentSongIdx()
        if songIdx then playSong(songIdx) end
        -- update dropdown highlight
        if songListDropdown then
            pcall(function() songListDropdown:SetValue(MP.songs[songIdx].name) end)
        end
    end

    local function playNext()
        if #MP.queue == 0 then return end
        if MP.repeatMode == "one" then playIndex(MP.queueIndex); return end
        local next = MP.queueIndex + 1
        if next > #MP.queue then
            if MP.repeatMode == "all" then next = 1 else stopSound(); return end
        end
        playIndex(next)
    end

    local function playPrev()
        if #MP.queue == 0 then return end
        if MP.sound and MP.sound.TimePosition > 3 then
            -- restart current if >3s in
            playSong(getCurrentSongIdx()); return
        end
        playIndex(MP.queueIndex - 1)
    end

    -- auto-advance when song ends
    MP.autoConn = RunService.Heartbeat:Connect(function()
        if MP.sound and MP.playing and not MP.paused then
            pcall(function()
                if MP.sound.TimeLength > 0 and
                   MP.sound.TimePosition >= MP.sound.TimeLength - 0.1 and
                   not MP.sound.IsPlaying then
                    playNext()
                end
            end)
            updateProgressUI()
            updateViz()
        end
    end)

    -- ── Music Tab GUI ─────────────────────────────────────────────
    local timeLabel
    local tMusic   = Tabs.Misc
    local gNowPlay = tMusic:AddLeftGroupbox('Playing')
    local gControl = tMusic:AddRightGroupbox('Controls')
    local gQueue   = tMusic:AddLeftGroupbox('Songs')
    local gFX      = tMusic:AddRightGroupbox('Effects')
    local gViz     = tMusic:AddLeftGroupbox('Visualizer')
    local gFav     = tMusic:AddRightGroupbox('Favourites')

    -- Now Playing
    -- Now Playing label — LinoriaLib AddLabel returns an object, not a TextLabel directly
    gNowPlay:AddLabel('No song')
    -- We track the current song name via a separate label we update manually
    -- currentSongLabel is set below after UI elements exist

    -- progress row: time label (updated from heartbeat)
    timeLabel = gNowPlay:AddLabel('0:00 / 0:00')

    -- visual progress bar via drawing or frame — use LinoriaLib slider trick
    -- We'll add a read-only slider and drive it from the heartbeat
    local seekSlider = gNowPlay:AddSlider('MP_Seek', {
        Text='Position', Default=0, Min=0, Max=100, Rounding=0,
        Callback=function(v)
            if MP.sound and MP.sound.TimeLength > 0 then
                pcall(function() MP.sound.TimePosition = (v/100) * MP.sound.TimeLength end)
            end
        end
    })
    -- update seek slider from heartbeat
    RunService.Heartbeat:Connect(function()
        if Library.Unloaded then return end
        pcall(function()
            if MP.sound and MP.sound.TimeLength > 0 then
                local pct = math.clamp((MP.sound.TimePosition / MP.sound.TimeLength) * 100, 0, 100)
                -- only update if not being dragged (avoid fighting user input)
                if math.abs((Options.MP_Seek.Value or 0) - pct) > 1 then
                    Options.MP_Seek:SetValue(math.floor(pct))
                end
            end
        end)
    end)

    -- Controls
    gControl:AddButton({Text='Previous', Func=function() playPrev() end})
    gControl:AddButton({Text='Play/Pause', Func=function()
        if not MP.sound then
            refreshSongList()
            if #MP.queue > 0 then MP.queueIndex = 1; playIndex(1) end
            return
        end
        if MP.playing and not MP.paused then
            MP.sound:Pause(); MP.paused=true
        elseif MP.paused then
            MP.sound:Resume(); MP.paused=false
        else
            if #MP.queue > 0 then playIndex(MP.queueIndex > 0 and MP.queueIndex or 1) end
        end
    end})
    gControl:AddButton({Text='Next', Func=function() playNext() end})
    gControl:AddButton({Text='Stop', Func=function() stopSound() end})
    gControl:AddDivider()
    gControl:AddSlider('MP_Volume', {Text='Volume', Default=80, Min=0, Max=100, Rounding=0,
        Callback=function(v) MP.volume=v/100; if MP.sound then MP.sound.Volume=MP.volume end end})
    gControl:AddSlider('MP_Pitch', {Text='Pitch', Default=100, Min=25, Max=200, Rounding=0,
        Callback=function(v) MP.pitch=v/100; if MP.sound then MP.sound.PlaybackSpeed=MP.pitch end end})
    gControl:AddDivider()
    gControl:AddToggle('MP_Shuffle', {Text='Shuffle', Default=false,
        Callback=function(v) MP.shuffle=v; rebuildQueue() end})
    gControl:AddDropdown('MP_Repeat', {Text='Repeat', Default=1, Values={'off','one','all'},
        Callback=function(v) MP.repeatMode=v end})
    gControl:AddDivider()
    gControl:AddSlider('MP_Sleep', {Text='Sleep (min)', Default=0, Min=0, Max=120, Rounding=0,
        Callback=function(v) MP.sleepEnd = (v > 0) and (tick() + v * 60) or nil end})
    gControl:AddButton({Text='Reload', Func=function() refreshSongList() end})

    -- Song List
    gQueue:AddInput('MP_Search', {Text='Search', Default='', Placeholder='Filter songs...',
        Callback=function(v) MP.searchFilter=v; rebuildQueue()
            if songListDropdown then
                local names={}
                for _,i in ipairs(MP.queue) do table.insert(names, MP.songs[i].name) end
                if #names==0 then names={"(no results)"} end
                pcall(function() songListDropdown:SetValues(names) end)
            end
        end})

    do
        -- initial scan before creating dropdown
        scanSongs(); rebuildQueue()
        local initNames = {}
        for _,i in ipairs(MP.queue) do table.insert(initNames, MP.songs[i].name) end
        if #initNames == 0 then initNames = {"(no songs)"} end

        songListDropdown = gQueue:AddDropdown('MP_SongList', {
            Text='Songs', Default=1, Values=initNames,
            Callback=function(v)
                -- find song by name
                for qi, si in ipairs(MP.queue) do
                    if MP.songs[si] and MP.songs[si].name == v then
                        MP.queueIndex = qi
                        playSong(si)
                        return
                    end
                end
            end
        })
    end

    gQueue:AddButton({Text='Play', Func=function()
        local v = tostring(Options.MP_SongList.Value or "")
        -- always rescan: files added after startup are picked up here
        refreshSongList()
        for qi, si in ipairs(MP.queue) do
            if MP.songs[si] and MP.songs[si].name == v then
                MP.queueIndex = qi; playSong(si); return
            end
        end
        -- nothing matched: fall back to the first song so the button always does something
        if #MP.queue > 0 then
            warn("[Music] Selection '"..v.."' not found, playing first song instead")
            playIndex(1)
        else
            warn("[Music] No songs found in Santa_V1/Songs/")
            if MP._nowPlayingLabel then MP._nowPlayingLabel.Text = "No songs in Santa_V1/Songs" end
        end
    end})
    gQueue:AddButton({Text='Favourite', Func=function()
        local v = Options.MP_SongList.Value
        if MP.favourites[v] then MP.favourites[v] = nil
        else MP.favourites[v] = true end
        -- refresh fav list
    end})

    -- Effects & EQ
    gFX:AddSlider('MP_Bass', {Text='Bass Boost', Default=0, Min=-10, Max=10, Rounding=1,
        Callback=function(v) MP.bassBoost=v; applyEffects() end})
    gFX:AddDivider()
    gFX:AddToggle('MP_EQOn', {Text='EQ', Default=false,
        Callback=function(v) MP.eqEnabled=v; applyEffects() end})
    gFX:AddSlider('MP_EQBass',   {Text='EQ Bass',   Default=0,Min=-10,Max=10,Rounding=1,Callback=function(v) MP.eqBass=v;   applyEffects() end})
    gFX:AddSlider('MP_EQMid',    {Text='EQ Mid',    Default=0,Min=-10,Max=10,Rounding=1,Callback=function(v) MP.eqMid=v;    applyEffects() end})
    gFX:AddSlider('MP_EQTreble', {Text='EQ Treble', Default=0,Min=-10,Max=10,Rounding=1,Callback=function(v) MP.eqTreble=v; applyEffects() end})
    gFX:AddDivider()
    -- Reverb
    gFX:AddToggle('MP_Reverb', {Text='Reverb', Default=false, Callback=function(v)
        if not MP.sound then return end
        local r = MP.sound:FindFirstChild("MP_Reverb") or Instance.new("ReverbSoundEffect")
        r.Name = "MP_Reverb"; r.Parent = MP.sound; r.Enabled = v
    end})
    gFX:AddSlider('MP_ReverbLevel', {Text='Level', Default=20, Min=0, Max=100, Rounding=0, Callback=function(v)
        if not MP.sound then return end
        local r = MP.sound:FindFirstChild("MP_Reverb"); if r then r.DecayTime=v/20 end
    end})
    -- Distortion
    gFX:AddToggle('MP_Distortion', {Text='Distortion', Default=false, Callback=function(v)
        if not MP.sound then return end
        local d = MP.sound:FindFirstChild("MP_Dist") or Instance.new("DistortionSoundEffect")
        d.Name="MP_Dist"; d.Parent=MP.sound; d.Enabled=v
    end})
    gFX:AddSlider('MP_DistLevel', {Text='Level', Default=0, Min=0, Max=100, Rounding=0, Callback=function(v)
        if not MP.sound then return end
        local d = MP.sound:FindFirstChild("MP_Dist"); if d then d.Level=v/100 end
    end})
    -- Chorus
    gFX:AddToggle('MP_Chorus', {Text='Chorus', Default=false, Callback=function(v)
        if not MP.sound then return end
        local c = MP.sound:FindFirstChild("MP_Chorus") or Instance.new("ChorusSoundEffect")
        c.Name="MP_Chorus"; c.Parent=MP.sound; c.Enabled=v
    end})
    gFX:AddSlider('MP_ChorusDepth', {Text='Depth', Default=50, Min=0, Max=100, Rounding=0, Callback=function(v)
        if not MP.sound then return end
        local c = MP.sound:FindFirstChild("MP_Chorus"); if c then c.Depth=v/100 end
    end})
    -- Normalize
    gFX:AddToggle('MP_Normalize', {Text='Normalize', Default=false, Callback=function(v)
        if not MP.sound then return end
        local n = MP.sound:FindFirstChild("MP_Norm") or Instance.new("CompressorSoundEffect")
        n.Name="MP_Norm"; n.Parent=MP.sound; n.Enabled=v
    end})

    -- Visualizer
    gViz:AddToggle('MP_VizOn', {Text='Visualizer', Default=true, Callback=function(v) MP.showViz=v end})
    -- Visualizer — LinoriaLib look: dark panel, 1px outline, accent strip, Code font
    local vizGui = Instance.new("ScreenGui"); vizGui.Name="SantaMusicViz"; vizGui.ResetOnSpawn=false; vizGui.DisplayOrder=150; vizGui.IgnoreGuiInset=true
    pcall(function() vizGui.Parent=CoreGui end); if not vizGui.Parent then vizGui.Parent=PlayerGui end

    local vizHolder = Instance.new("Frame")
    vizHolder.Name="VizHolder"; vizHolder.Size=UDim2.new(0,260,0,64); vizHolder.Position=UDim2.new(0.5,-130,0.9,0)
    vizHolder.BackgroundColor3=Library.MainColor; vizHolder.BorderSizePixel=0; vizHolder.BackgroundTransparency=0.05
    vizHolder.Parent=vizGui
    local vizOutline=Instance.new("UIStroke"); vizOutline.Color=Library.OutlineColor; vizOutline.Thickness=1; vizOutline.Parent=vizHolder
    local vizStrip=Instance.new("Frame"); vizStrip.Name="Strip"; vizStrip.Size=UDim2.new(1,0,0,2)
    vizStrip.BorderSizePixel=0; vizStrip.BackgroundColor3=Library.AccentColor; vizStrip.ZIndex=5; vizStrip.Parent=vizHolder

    local vizTitle = Instance.new("TextLabel")
    vizTitle.Name="Title"; vizTitle.Size=UDim2.new(1,-12,0,16); vizTitle.Position=UDim2.new(0,6,0,5)
    vizTitle.BackgroundTransparency=1; vizTitle.Font=Enum.Font.Code; vizTitle.TextSize=13
    vizTitle.TextXAlignment=Enum.TextXAlignment.Left; vizTitle.TextColor3=Library.FontColor
    vizTitle.TextTruncate=Enum.TextTruncate.AtEnd; vizTitle.Text="No song"; vizTitle.Parent=vizHolder
    local vizTStroke=Instance.new("UIStroke"); vizTStroke.Color=Color3.new(0,0,0); vizTStroke.Thickness=1
    vizTStroke.LineJoinMode=Enum.LineJoinMode.Miter; vizTStroke.Parent=vizTitle
    MP._nowPlayingLabel = vizTitle
    vizTitle.Size = UDim2.new(0.6, 0, 0, 16)
    local vizTime = Instance.new("TextLabel")
    vizTime.Name="Time"; vizTime.Size=UDim2.new(0.4,-6,0,16); vizTime.Position=UDim2.new(0.6,0,0,5)
    vizTime.BackgroundTransparency=1; vizTime.Font=Enum.Font.Code; vizTime.TextSize=13
    vizTime.TextXAlignment=Enum.TextXAlignment.Right; vizTime.TextColor3=Library.FontColor
    vizTime.Text="0:00 / 0:00"; vizTime.Parent=vizHolder
    local function fmtTime(s)
        s = math.max(0, math.floor(s + 0.5))
        return string.format("%d:%02d", math.floor(s / 60), s % 60)
    end

    local barArea = Instance.new("Frame")
    barArea.Name="Bars"; barArea.Position=UDim2.new(0,6,0,24); barArea.Size=UDim2.new(1,-12,1,-30)
    barArea.BackgroundTransparency=1; barArea.Parent=vizHolder

    local VIZ_COUNT = 32
    local vizLevel = {}
    for i=1,VIZ_COUNT do
        local b=Instance.new("Frame"); b.Name="VizBar"..i
        b.Size=UDim2.new(1/VIZ_COUNT,-2,0,0)
        b.AnchorPoint=Vector2.new(0,1); b.Position=UDim2.new((i-1)/VIZ_COUNT,1,1,0)
        b.BackgroundColor3=Library.AccentColor; b.BorderSizePixel=0; b.Parent=barArea
        vizBars[i]=b; vizLevel[i]=0
    end

    -- drag the panel
    vizHolder.Active=true
    do
        local dragging=false; local dragStart=Vector2.zero; local startPos=UDim2.new()
        vizHolder.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=inp.Position; startPos=vizHolder.Position end
        end)
        vizHolder.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
                local d=inp.Position-dragStart
                vizHolder.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
            end
        end)
        vizHolder.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
        end)
    end

    -- animation: smoothed bars, driven by loudness, idle wave when paused/stopped
    RunService.RenderStepped:Connect(function()
        if Library.Unloaded then return end
        vizHolder.Visible = MP.showViz
        -- sleep timer + live song time (shown in the visualizer and the Now Playing row)
        if MP.sleepEnd and tick() >= MP.sleepEnd then
            MP.sleepEnd = nil; stopSound(); print("[Music] sleep timer stopped playback")
        end
        local pos, dur = 0, 0
        if MP.sound then pcall(function() pos = MP.sound.TimePosition; dur = MP.sound.TimeLength end) end
        local txt = fmtTime(pos) .. " / " .. fmtTime(dur)
        vizTime.Text = txt
        if timeLabel then pcall(function() timeLabel:SetText(txt) end) end
        if not MP.showViz then return end
        local active = MP.sound and MP.playing and not MP.paused
        local loud = 0
        if active then pcall(function() loud = MP.sound.PlaybackLoudness or 0 end) end
        local norm = math.clamp(loud / 150, 0, 1)
        local t = tick()
        local areaH = math.max(barArea.AbsoluteSize.Y, 20)
        local rainbow = Toggles.MP_VizRainbow and Toggles.MP_VizRainbow.Value
        for i, b in ipairs(vizBars) do
            local wave = 0.5 + 0.5 * math.sin(t * (2.2 + i * 0.09) + i * 0.6)
            local target
            if active then
                target = 0.08 + norm * (0.3 + 0.7 * wave) + math.random() * norm * 0.12
            else
                target = 0.05 + 0.04 * wave
            end
            target = math.clamp(target, 0, 1)
            vizLevel[i] = vizLevel[i] + (target - vizLevel[i]) * 0.3
            b.Size = UDim2.new(1/VIZ_COUNT, -2, 0, math.max(2, vizLevel[i] * areaH))
            if rainbow then
                b.BackgroundColor3 = Color3.fromHSV((i / VIZ_COUNT + t * 0.08) % 1, 0.8, 1)
            else
                b.BackgroundColor3 = Library.AccentColor:Lerp(Library.FontColor, vizLevel[i] * 0.6)
            end
        end
        vizStrip.BackgroundColor3 = Library.AccentColor
    end)

    gViz:AddSlider('MP_VizX', {Text='Viz X', Default=50, Min=0, Max=100, Rounding=0,
        Callback=function(v) vizHolder.Position=UDim2.new(v/100,-100,vizHolder.Position.Y.Scale,vizHolder.Position.Y.Offset) end})
    gViz:AddSlider('MP_VizY', {Text='Viz Y', Default=92, Min=0, Max=100, Rounding=0,
        Callback=function(v) vizHolder.Position=UDim2.new(vizHolder.Position.X.Scale,vizHolder.Position.X.Offset,v/100,0) end})
    gViz:AddSlider('MP_VizW', {Text='Width', Default=200, Min=80, Max=600, Rounding=0,
        Callback=function(v) vizHolder.Size=UDim2.new(0,v,0,vizHolder.AbsoluteSize.Y) end})
    gViz:AddSlider('MP_VizH', {Text='Height', Default=40, Min=20, Max=120, Rounding=0,
        Callback=function(v) vizHolder.Size=UDim2.new(0,vizHolder.AbsoluteSize.X,0,v) end})
    gViz:AddToggle('MP_VizRainbow', {Text='Rainbow', Default=true})
    gViz:AddLabel('Drag to move.')

    -- Favourites tab
    gFav:AddLabel('Use Favourite on a song.')
    gFav:AddButton({Text='Play Favs', Func=function()
        MP.queue={}
        for i,s in ipairs(MP.songs) do
            if MP.favourites[s.name] then table.insert(MP.queue,i) end
        end
        if #MP.queue==0 then return end
        MP.queueIndex=1; playIndex(1)
    end})
    gFav:AddButton({Text='Clear Favs', Func=function() MP.favourites={} end})
    gFav:AddDivider()
    gFav:AddLabel('Folder: Songs')
    gFav:AddLabel('mp3 ogg flac wav')
    gFav:AddButton({Text='Song Info', Func=function()
        -- print path to output
        print("[Music] Songs folder: "..MP.FOLDER)
        print("[Music] "..#MP.songs.." songs loaded")
        for _,s in ipairs(MP.songs) do print("  - "..s.name) end
    end})

    -- store cleanup refs
    MP._vizGui = vizGui
end
SantaStep("music player", __buildMusicPlayer)

-- ════════════════════════════════════════════════════════════════════
-- MISC EXTRAS — player tools, visuals and server tools (Misc tab)
-- ════════════════════════════════════════════════════════════════════
local MiscExtras = {}
local function __buildMiscExtras()
    local UIS = game:GetService("UserInputService")
    local RS = game:GetService("RunService")
    local Lit = game:GetService("Lighting")
    local TeleportService = game:GetService("TeleportService")
    local VirtualUser = game:GetService("VirtualUser")
    local LP = game:GetService("Players").LocalPlayer

    local conns = {}
    local function track(c) table.insert(conns, c); return c end

    local noclipOn, infJumpOn, clickTpOn, antiAfkOn, fullbrightOn = false, false, false, false, false

    local origLight = {
        Brightness = Lit.Brightness, Ambient = Lit.Ambient, OutdoorAmbient = Lit.OutdoorAmbient,
        GlobalShadows = Lit.GlobalShadows, FogEnd = Lit.FogEnd, ClockTime = Lit.ClockTime,
    }

    local function restoreCollide()
        local c = LP.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end

    -- Noclip: keep character parts non-colliding while enabled
    track(RS.Stepped:Connect(function()
        if not noclipOn then return end
        local c = LP.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = false
            end
        end
    end))

    -- Infinite jump
    track(UIS.JumpRequest:Connect(function()
        if not infJumpOn then return end
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))

    -- Ctrl + click teleport
    track(UIS.InputBegan:Connect(function(input, gp)
        if gp or not clickTpOn then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not UIS:IsKeyDown(Enum.KeyCode.LeftControl) then return end
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local hit = LP:GetMouse().Hit
        if root and hit then
            root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
        end
    end))

    -- Anti-AFK: answers the idle kick with a virtual click
    track(LP.Idled:Connect(function()
        if not antiAfkOn then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))

    local function setFullbright(on)
        if on then
            Lit.Brightness = 2
            Lit.ClockTime = 14
            Lit.GlobalShadows = false
            Lit.Ambient = Color3.new(1, 1, 1)
            Lit.OutdoorAmbient = Color3.new(1, 1, 1)
            Lit.FogEnd = 100000
        else
            for k, v in pairs(origLight) do pcall(function() Lit[k] = v end) end
        end
    end

    local function setFps(v)
        if not setfpscap then warn("[Misc] setfpscap is not supported by this executor"); return end
        local n = tonumber(v) or 0 -- "Unlimited" -> 0
        pcall(setfpscap, n)
    end

    local function resetCharacter()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end

    local function copyJobId()
        if setclipboard then
            setclipboard(game.JobId)
            print("[Misc] JobId copied to clipboard")
        else
            print("[Misc] JobId: " .. game.JobId)
        end
    end

    local function rejoin()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end)
    end

    local function serverInfo()
        local count = #game:GetService("Players"):GetPlayers()
        print("[Misc] PlaceId: " .. game.PlaceId)
        print("[Misc] JobId:   " .. game.JobId)
        print("[Misc] Players: " .. count .. "/" .. game:GetService("Players").MaxPlayers)
    end

    local gPlayer = Tabs.Misc:AddLeftGroupbox("Player")
    local gWorld  = Tabs.Misc:AddRightGroupbox("Server")

    gPlayer:AddToggle("MX_Noclip", { Text = "Noclip", Default = false, Callback = function(v)
        noclipOn = v
        if not v then restoreCollide() end
    end })
    gPlayer:AddToggle("MX_InfJump", { Text = "Infinite Jump", Default = false, Callback = function(v)
        infJumpOn = v
    end })
    gPlayer:AddToggle("MX_ClickTP", { Text = "Ctrl + Click Teleport", Default = false, Callback = function(v)
        clickTpOn = v
    end })
    gPlayer:AddToggle("MX_AntiAfk", { Text = "Anti-AFK", Default = false, Callback = function(v)
        antiAfkOn = v
    end })
    gPlayer:AddDivider()
    gPlayer:AddButton({ Text = "Reset Character", Func = resetCharacter })

    gWorld:AddToggle("MX_Fullbright", { Text = "Fullbright", Default = false, Callback = function(v)
        fullbrightOn = v
        setFullbright(v)
    end })
    gWorld:AddDropdown("MX_FPS", { Text = "FPS Cap", Values = { "60", "120", "144", "240", "Unlimited" },
        Default = "Unlimited", Callback = setFps })
    gWorld:AddDivider()
    gWorld:AddButton({ Text = "Copy JobId", Func = copyJobId })
    gWorld:AddButton({ Text = "Rejoin Server", Func = rejoin })
    gWorld:AddButton({ Text = "Print Server Info", Func = serverInfo })

    -- bookmarks, position copy, spawn teleport
    local bookmark
    local function rootOf() return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") end
    gPlayer:AddButton({Text="Set Mark", Func=function()
        local r = rootOf(); if r then bookmark = r.CFrame; print("[Misc] bookmark set") end
    end})
    gPlayer:AddButton({Text="Go Mark", Func=function()
        local r = rootOf()
        if r and bookmark then r.CFrame = bookmark else warn("[Misc] no bookmark set") end
    end})
    gPlayer:AddButton({Text="Go Spawn", Func=function()
        local sp = workspace:FindFirstChildOfClass("SpawnLocation"); local r = rootOf()
        if sp and r then r.CFrame = sp.CFrame + Vector3.new(0, 5, 0) else warn("[Misc] no SpawnLocation found") end
    end})
    gWorld:AddButton({Text="Copy Pos", Func=function()
        local r = rootOf(); if not r then return end
        local p = r.Position
        local s = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
        if setclipboard then setclipboard(s); print("[Misc] copied " .. s) else print("[Misc] " .. s) end
    end})

    MiscExtras.cleanup = function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        noclipOn, infJumpOn, clickTpOn, antiAfkOn = false, false, false, false
        if fullbrightOn then setFullbright(false) end
        fullbrightOn = false
        restoreCollide()
    end
end
SantaStep("misc tools", __buildMiscExtras)

-- ════════════════════════════════════════════════════════════════════
-- CUSTOM HUD — Linoria-styled info panel (FPS, ping, time, players, ...)
-- Fully configurable in Visuals > Custom HUD. Shows general info only.
-- ════════════════════════════════════════════════════════════════════
local CustomHUD = {}
local function __buildCustomHUD()
    local RS = game:GetService("RunService")
    local StatsS = game:GetService("Stats")
    local PlayersS = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local LP = PlayersS.LocalPlayer
    local PG = LP:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "SantaCustomHUD"; gui.ResetOnSpawn = false; gui.DisplayOrder = 300; gui.IgnoreGuiInset = true
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = PG end

    -- panel: dark body, 1px outline, accent strip on top (LinoriaLib look)
    local panel = Instance.new("Frame")
    panel.Name = "Panel"; panel.Size = UDim2.fromOffset(190, 0); panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.BackgroundColor3 = Library.MainColor; panel.BorderSizePixel = 0
    panel.Position = UDim2.fromScale(0.01, 0.01); panel.Parent = gui
    local scale = Instance.new("UIScale"); scale.Parent = panel
    local outline = Instance.new("UIStroke"); outline.Color = Library.OutlineColor; outline.Thickness = 1; outline.Parent = panel
    local list = Instance.new("UIListLayout"); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0, 2); list.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = panel

    local strip = Instance.new("Frame")
    strip.Name = "AccentStrip"; strip.Size = UDim2.new(1, 0, 0, 2); strip.Position = UDim2.new(0, 0, 0, 0)
    strip.BorderSizePixel = 0; strip.BackgroundColor3 = Library.AccentColor
    strip.ZIndex = 5; strip.Parent = panel

    local function makeLine(order)
        local l = Instance.new("TextLabel")
        l.LayoutOrder = order; l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, 16)
        l.Font = Enum.Font.Code; l.TextSize = 14; l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Library.FontColor; l.Text = ""; l.Parent = panel
        local s = Instance.new("UIStroke"); s.Color = Color3.new(0, 0, 0); s.Thickness = 1
        s.LineJoinMode = Enum.LineJoinMode.Miter; s.Parent = l
        return l
    end

    local title = makeLine(0)
    local rows = {
        { key = "HUD_ShowFPS",      order = 1 },
        { key = "HUD_ShowPing",     order = 2 },
        { key = "HUD_ShowTime",     order = 3 },
        { key = "HUD_ShowPlayers",  order = 4 },
        { key = "HUD_ShowGameTime", order = 5 },
        { key = "HUD_ShowHealth",   order = 6 },
        { key = "HUD_ShowPos",      order = 7 },
    }
    local labels = {}
    for _, r in ipairs(rows) do labels[r.key] = makeLine(r.order) end

    -- drag the panel with the mouse
    panel.Active = true
    do
        local dragging, dragStart, startPos = false, Vector2.zero, panel.Position
        panel.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; dragStart = inp.Position; startPos = panel.Position
            end
        end)
        UIS.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                local d = inp.Position - dragStart
                panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    local frames, lastFps, fps = 0, tick(), 60
    local function ping()
        local ok, v = pcall(function() return math.floor(StatsS.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        return ok and v or 0
    end
    local function hpInfo()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return "--" end
        return string.format("%d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))
    end
    local function posInfo()
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then return "--" end
        local p = root.Position
        return string.format("%d, %d, %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
    end

    local tAcc = 0
    local conn
    conn = RS.RenderStepped:Connect(function(dt)
        if Library.Unloaded then return end
        frames = frames + 1
        if tick() - lastFps >= 1 then fps = frames; frames = 0; lastFps = tick() end

        -- layout / style every frame (cheap)
        local accent = Options.HUD_Accent.Value
        local textCol = Options.HUD_TextColor.Value
        local size = Options.HUD_TextSize.Value
        scale.Scale = Options.HUD_Scale.Value / 100
        panel.Position = UDim2.fromScale(Options.HUD_X.Value / 100, Options.HUD_Y.Value / 100)
        panel.BackgroundTransparency = Options.HUD_BgTrans.Value / 100
        panel.Visible = Toggles.HUD_Enabled.Value
        strip.BackgroundColor3 = accent
        strip.Visible = Toggles.HUD_ShowTitle.Value

        -- text refresh ~5x/second
        tAcc = tAcc + dt
        if tAcc < 0.2 then return end
        tAcc = 0

        title.Visible = Toggles.HUD_ShowTitle.Value
        title.Text = Options.HUD_Title.Value
        title.TextColor3 = accent
        title.TextSize = size

        local values = {
            HUD_ShowFPS      = "FPS: " .. fps,
            HUD_ShowPing     = "Ping: " .. ping() .. " ms",
            HUD_ShowTime     = "Time: " .. os.date("%H:%M:%S"),
            HUD_ShowPlayers  = "Players: " .. #PlayersS:GetPlayers() .. " / " .. PlayersS.MaxPlayers,
            HUD_ShowGameTime = string.format("Game time: %02d:%02d", math.floor(game:GetService("Lighting").ClockTime), math.floor((game:GetService("Lighting").ClockTime % 1) * 60)),
            HUD_ShowHealth   = "HP: " .. hpInfo(),
            HUD_ShowPos      = "Pos: " .. posInfo(),
        }
        for _, r in ipairs(rows) do
            local l = labels[r.key]
            l.Visible = Toggles[r.key].Value
            l.Text = values[r.key]
            l.TextColor3 = textCol
            l.TextSize = size
        end
    end)

    CustomHUD.cleanup = function()
        if conn then conn:Disconnect() end
        pcall(function() gui:Destroy() end)
    end
end

-- ── GUI for the HUD (Visuals tab) ──
do
    local gHUD = Tabs.Visuals:AddRightGroupbox("Custom HUD")
    gHUD:AddToggle("HUD_Enabled", { Text = "Enable Custom HUD", Default = false })
    gHUD:AddToggle("HUD_ShowTitle", { Text = "Show Title", Default = true })
    gHUD:AddInput("HUD_Title", { Default = "Santa V.1", Text = "Title", Finished = true })
    gHUD:AddDivider()
    gHUD:AddToggle("HUD_ShowFPS", { Text = "FPS", Default = true })
    gHUD:AddToggle("HUD_ShowPing", { Text = "Ping", Default = true })
    gHUD:AddToggle("HUD_ShowTime", { Text = "Real Time", Default = true })
    gHUD:AddToggle("HUD_ShowPlayers", { Text = "Player Count", Default = true })
    gHUD:AddToggle("HUD_ShowGameTime", { Text = "Game Time", Default = false })
    gHUD:AddToggle("HUD_ShowHealth", { Text = "My Health", Default = false })
    gHUD:AddToggle("HUD_ShowPos", { Text = "My Position", Default = false })
    gHUD:AddDivider()
    gHUD:AddSlider("HUD_Scale", { Text = "Scale %", Default = 100, Min = 50, Max = 200, Rounding = 0 })
    gHUD:AddSlider("HUD_TextSize", { Text = "Text Size", Default = 14, Min = 10, Max = 24, Rounding = 0 })
    gHUD:AddSlider("HUD_BgTrans", { Text = "Background Transparency %", Default = 15, Min = 0, Max = 100, Rounding = 0 })
    gHUD:AddSlider("HUD_X", { Text = "Position X %", Default = 1, Min = 0, Max = 100, Rounding = 0 })
    gHUD:AddSlider("HUD_Y", { Text = "Position Y %", Default = 1, Min = 0, Max = 100, Rounding = 0 })
    gHUD:AddLabel("Accent"):AddColorPicker("HUD_Accent", { Default = Library.AccentColor })
    gHUD:AddLabel("Text"):AddColorPicker("HUD_TextColor", { Default = Library.FontColor })
    gHUD:AddDivider()
    gHUD:AddButton({ Text = "Reset Position", Func = function()
        Options.HUD_X:SetValue(1); Options.HUD_Y:SetValue(1)
    end })
end
SantaStep("custom HUD", __buildCustomHUD)

-- ════════════════════════════════════════════════════════════════════
-- KEYBINDS — every feature toggle gets its own key picker (Linoria KeyPicker)
-- Set the key in the toggle's row; Mode "Toggle" flips the feature on press.
-- ════════════════════════════════════════════════════════════════════
do
    local keybindToggles = {
        "AimbotOn", "WallChk", "StickyOn", "TrigOn", "SAOn", "AA_Enable",
        "ESPOn", "Visuals_Enabled", "Weather_Enabled", "SelfChams_Enabled",
        "FOV_Enabled", "CC_Enabled", "Bloom_Enabled", "CHVis",
        "SpeedOn", "JumpOn", "FlyOn", "SpinBotOn",
        "MX_Noclip", "MX_InfJump", "MX_ClickTP", "MX_AntiAfk", "MX_Fullbright",
        "HUD_Enabled", "MP_EQOn",
    }
    local added, failed = 0, 0
    for _, idx in ipairs(keybindToggles) do
        local ok, err = pcall(function()
            local t = Toggles[idx]
            if not t then error("toggle not found") end
            t:AddKeyPicker(idx .. "_Key", {
                Default = "None",
                Mode = "Toggle",
                SyncToggleState = true,
                Text = idx,
                NoUI = false,
            })
        end)
        if ok then added = added + 1 else failed = failed + 1; warn("[Keybind] " .. idx .. ": " .. tostring(err)) end
    end
    print("[Keybind] " .. added .. " feature keybind(s) added, " .. failed .. " failed")
end

-- ════════════════════════════════════════════════════════════════════
-- KEYBIND LIST — Linoria-styled panel, lists only keys that are bound.
-- Settings > Keybinds: enable, show inactive, position, scale, transparency.
-- ════════════════════════════════════════════════════════════════════
local KeyList = {}
do
    local kbGui = Instance.new("ScreenGui")
    kbGui.Name = "SantaKeybinds"; kbGui.ResetOnSpawn = false; kbGui.DisplayOrder = 250; kbGui.IgnoreGuiInset = true
    pcall(function() kbGui.Parent = game:GetService("CoreGui") end)
    if not kbGui.Parent then kbGui.Parent = PlayerGui end

    local panel = Instance.new("Frame")
    panel.Name = "Panel"; panel.Size = UDim2.fromOffset(170, 0); panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Position = UDim2.new(0, 8, 0.4, 0); panel.BackgroundColor3 = Library.MainColor; panel.BorderSizePixel = 0
    panel.Parent = kbGui
    local uiScale = Instance.new("UIScale"); uiScale.Parent = panel
    local stroke = Instance.new("UIStroke"); stroke.Color = Library.OutlineColor; stroke.Thickness = 1; stroke.Parent = panel
    local strip = Instance.new("Frame")
    strip.Name = "Strip"; strip.Size = UDim2.new(1, 0, 0, 2); strip.BorderSizePixel = 0
    strip.BackgroundColor3 = Library.AccentColor; strip.ZIndex = 5; strip.Parent = panel
    local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 2); layout.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 7); pad.PaddingBottom = UDim.new(0, 6); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = panel

    local function styleLabel(l)
        l.BackgroundTransparency = 1; l.Font = Enum.Font.Code; l.TextXAlignment = Enum.TextXAlignment.Left
        local s = Instance.new("UIStroke"); s.Color = Color3.new(0, 0, 0); s.Thickness = 1
        s.LineJoinMode = Enum.LineJoinMode.Miter; s.Parent = l
        return l
    end
    local header = styleLabel(Instance.new("TextLabel"))
    header.Name = "Header"; header.LayoutOrder = 0; header.Size = UDim2.new(1, 0, 0, 16)
    header.Text = "Keybinds"; header.Parent = panel

    local rows = {}
    local function rowAt(i)
        if not rows[i] then
            local l = styleLabel(Instance.new("TextLabel"))
            l.LayoutOrder = i; l.Size = UDim2.new(1, 0, 0, 16); l.Visible = false; l.Parent = panel
            rows[i] = l
        end
        return rows[i]
    end

    local function collect()
        local out = {}
        for k, o in pairs(Options) do
            if type(k) == "string" and (k == "MenuKeybind" or k:sub(-4) == "_Key") then
                local key = o.Value
                if type(key) == "string" and key ~= "" and key ~= "None" then
                    local name, on
                    if k == "MenuKeybind" then
                        name, on = "Menu", true
                    else
                        name = k:sub(1, -5)
                        local t = Toggles[name]
                        on = t and t.Value == true
                    end
                    table.insert(out, { name = name, key = key, on = on })
                end
            end
        end
        table.sort(out, function(a, b) return a.name < b.name end)
        return out
    end

    local acc = 0
    local hbConn = RunService.Heartbeat:Connect(function(dt)
        if Library.Unloaded then return end
        acc = acc + dt
        if acc < 0.15 then return end
        acc = 0
        local enabled = Toggles.KL_Enable.Value
        panel.Visible = enabled
        if not enabled then return end
        panel.Position = UDim2.fromScale(Options.KL_X.Value / 100, Options.KL_Y.Value / 100)
        uiScale.Scale = Options.KL_Scale.Value / 100
        panel.BackgroundTransparency = Options.KL_Trans.Value / 100
        strip.BackgroundColor3 = Library.AccentColor
        header.Visible = Toggles.KL_Title.Value
        header.TextSize = Options.KL_Size.Value
        header.TextColor3 = Library.AccentColor

        local list = collect()
        local shown = 0
        for _, e in ipairs(list) do
            if Toggles.KL_ShowOff.Value or e.on then
                shown = shown + 1
                local l = rowAt(shown + 1)
                l.Visible = true
                l.TextSize = Options.KL_Size.Value
                l.Text = e.name .. "  [" .. e.key .. "]"
                l.TextColor3 = e.on and Library.AccentColor or Library.FontColor
            end
        end
        for i = shown + 2, #rows do rows[i].Visible = false end
        panel.Visible = shown > 0
    end)

    KeyList.cleanup = function()
        if hbConn then hbConn:Disconnect() end
        pcall(function() kbGui:Destroy() end)
    end
end

-- Settings > Keybinds: options for the keybind list
do
    local gKL = Tabs.Settings:AddRightGroupbox("Keybinds")
    gKL:AddToggle("KL_Enable", { Text = "Enable", Default = true })
    gKL:AddToggle("KL_ShowOff", { Text = "Show Off", Default = true })
    gKL:AddToggle("KL_Title", { Text = "Title", Default = true })
    gKL:AddDivider()
    gKL:AddSlider("KL_X", { Text = "X", Default = 0, Min = 0, Max = 100, Rounding = 0 })
    gKL:AddSlider("KL_Y", { Text = "Y", Default = 40, Min = 0, Max = 100, Rounding = 0 })
    gKL:AddSlider("KL_Scale", { Text = "Scale", Default = 100, Min = 50, Max = 200, Rounding = 0 })
    gKL:AddSlider("KL_Trans", { Text = "Transparency", Default = 10, Min = 0, Max = 100, Rounding = 0 })
    gKL:AddSlider("KL_Size", { Text = "Text Size", Default = 13, Min = 10, Max = 20, Rounding = 0 })
end

Library:OnUnload(function()
    Library.Unloaded=true
    if KeyList.cleanup then pcall(KeyList.cleanup) end
    if CustomHUD.cleanup then pcall(CustomHUD.cleanup) end
    if MiscExtras.cleanup then pcall(MiscExtras.cleanup) end
    if mainConnection then mainConnection:Disconnect(); mainConnection=nil end
    if flyConn then flyConn:Disconnect(); flyConn=nil end
    -- music cleanup
    pcall(function()
        if MP.autoConn then MP.autoConn:Disconnect() end
        if MP.sound then MP.sound:Stop(); MP.sound:Destroy() end
        if MP._vizGui then MP._vizGui:Destroy() end
    end)
    aimbotEnabled=false; pcall(function() fovCircle:Remove() end)
    trigger.enabled=false; ESPToggles.master=false
    for _,s in pairs(ESPEngine.players) do for _,c in ipairs(s.connections) do pcall(c.Disconnect,c) end; for _,d in ipairs(s.drawings) do pcall(d.Remove,d) end end
    ESPEngine.players={}; CH.Visible=false; pcall(clearCH)
    spinEnabled=false; antiAim.enabled=false
    speedEnabled=false; applySpeed(); jumpEnabled=false; applyJump()
    if flying then toggleFly(false) end
    ShiftLockSystem.Enabled=false; CrosshairImage.Visible=false; pcall(hideDefaultShiftlock,false); pcall(function() CrosshairGui:Destroy() end)
    weatherEnabled=false; Lighting.Brightness=OriginalBrightness
    for _,d in ipairs(weatherParticles) do if d.Active then d.Active=false; d.Part.CFrame=CFrame.new(0,-1000,0) end end
    pcall(function() weatherFolder:Destroy() end)
    targetHudEnabled=false; pcall(function() ScreenGui:Destroy() end)
    selfChamsEnabled=false; if isChamsActive and LocalPlayer.Character then restoreCharacterState(LocalPlayer.Character) end
    fovEnabled=false; TimeSystem.FreezeTime=false; ccEnabled=false; bloomEnabled=false
    if ccEffect then ccEffect.Enabled=false end; if bloomEffect then bloomEffect.Enabled=false end
    Lighting.Ambient=OriginalAmbient; Lighting.OutdoorAmbient=OriginalOutdoorAmbient
    local sky=Lighting:FindFirstChild("SantaCustomSky"); if sky then sky:Destroy() end
    local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass('Humanoid'); if hum then hum.AutoRotate=true end
    SV_Atmosphere:Destroy(); SV_CC:Destroy(); svVigGui:Destroy()
    Lighting.ExposureCompensation=SV_Original.Exposure; Lighting.FogStart=SV_Original.FogStart; Lighting.FogEnd=SV_Original.FogEnd; Lighting.FogColor=SV_Original.FogColor
    local cam=workspace.CurrentCamera; if cam then cam.FieldOfView=SV_Original.Fov end
end)
end -- ScriptToRun

-- ════════════════════════════════════════════════════════════════════
-- KEY SYSTEM
-- ════════════════════════════════════════════════════════════════════
local LocalPlayer2 = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local PlayerGui2   = LocalPlayer2:WaitForChild("PlayerGui")

local FontColor=Color3.fromRGB(255,255,255); local MainColor=Color3.fromRGB(28,28,28)
local BackgroundColor=Color3.fromRGB(20,20,20); local AccentColor=Color3.fromRGB(0,85,255)
local OutlineColor=Color3.fromRGB(50,50,50); local RiskColor=Color3.fromRGB(255,50,50)
local Black=Color3.new(0,0,0); local FONT=Enum.Font.Code; local TEXTSIZE=16
local TAG="[KeySystem] "; local lastStage="none"
local function stage(name) lastStage=name; print(TAG.."built: "..name) end

local function FetchValidKeys()
    local success,response=pcall(function() return game:HttpGet(KeyURL) end)
    if not success or type(response)~="string" then return nil,"Could not reach the key server." end
    local keys={}
    for line in response:gmatch("[^\r\n]+") do
        local cleanKey=line:match("^%s*(.-)%s*$")
        if cleanKey and #cleanKey>0 and cleanKey:sub(1,1)~="#" then table.insert(keys,cleanKey) end
    end
    if #keys==0 then return nil,"The key list came back empty." end
    return keys
end
local function IsKeyValid(keyToCheck,validKeys) for _,key in ipairs(validKeys) do if keyToCheck==key then return true end end; return false end
local KEY_PATTERN="^[%a][%w]*%-[%w]+%-[%w]+$"

local function ApplyTextStroke(inst)
    inst.TextStrokeTransparency=1
    local stroke=Instance.new("UIStroke"); stroke.Color=Black; stroke.Thickness=1; stroke.LineJoinMode=Enum.LineJoinMode.Miter; stroke.Transparency=0; stroke.Parent=inst; return stroke
end
local function label(props)
    local inst=Instance.new("TextLabel"); inst.BackgroundTransparency=1; inst.Font=FONT; inst.TextColor3=FontColor; inst.TextSize=TEXTSIZE; ApplyTextStroke(inst)
    for k,v in pairs(props) do inst[k]=v end; return inst
end
local function box(class,props)
    local inst=Instance.new(class); inst.BorderSizePixel=1; inst.BorderColor3=OutlineColor
    for k,v in pairs(props) do inst[k]=v end; return inst
end
local function MakeDraggable(frame,cutoff)
    frame.Active=true; local dragging=false; local dragStart=Vector2.zero; local startPos=UDim2.new(); local endConnection=nil
    local function stopDragging() dragging=false; if endConnection then endConnection:Disconnect(); endConnection=nil end end
    frame.InputBegan:Connect(function(input)
        local kind=input.UserInputType
        if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
        dragging=true; dragStart=input.Position; startPos=frame.Position
        endConnection=input.Changed:Connect(function() if input.State==Enum.UserInputState.End then stopDragging() end end)
    end)
    frame.InputChanged:Connect(function(input)
        if not dragging then return end
        local kind=input.UserInputType
        if kind~=Enum.UserInputType.MouseMovement and kind~=Enum.UserInputType.Touch then return end
        local delta=input.Position-dragStart; local viewport=workspace.CurrentCamera.ViewportSize
        frame.Position=UDim2.new(startPos.X.Scale,math.clamp(startPos.X.Offset+delta.X,-cutoff,viewport.X-cutoff),startPos.Y.Scale,math.clamp(startPos.Y.Offset+delta.Y,-cutoff,viewport.Y-cutoff))
    end)
    frame.InputEnded:Connect(stopDragging)
end

task.spawn(function()
    if readfile and isfile and isfile(SaveFileName) then
        local savedKey=readfile(SaveFileName):match("^%s*(.-)%s*$")
        if savedKey and #savedKey>0 then
            print(TAG.."Checking Saved Key")
            local validKeys,err=FetchValidKeys()
            if not validKeys then print(TAG.."Saved Key check failed: "..tostring(err))
            elseif IsKeyValid(savedKey,validKeys) then print(TAG.."Saved Key has passed"); SantaStep("main script", ScriptToRun); return
            else print(TAG.."Saved Key has failed"); if delfile then delfile(SaveFileName) end end
        end
    end

    local function buildUI()
        local KeySystemUI=Instance.new("ScreenGui"); KeySystemUI.Name="KeySystemUI"; KeySystemUI.Parent=PlayerGui2
        KeySystemUI.ResetOnSpawn=false; KeySystemUI.IgnoreGuiInset=true; KeySystemUI.DisplayOrder=500; KeySystemUI.ZIndexBehavior=Enum.ZIndexBehavior.Global; stage("ScreenGui")
        local WIDTH,HEIGHT=420,300
        local Outer=box("Frame",{Name="Outer",BackgroundColor3=Black,Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(WIDTH,HEIGHT),ZIndex=1,Parent=KeySystemUI}); MakeDraggable(Outer,60); stage("Outer")
        local Inner=box("Frame",{Name="Inner",BackgroundColor3=MainColor,BorderColor3=AccentColor,BorderMode=Enum.BorderMode.Inset,Position=UDim2.fromOffset(1,1),Size=UDim2.new(1,-2,1,-2),ZIndex=2,Parent=Outer}); stage("Inner")
        local Title=label({Name="Title",Position=UDim2.fromOffset(7,0),Size=UDim2.new(1,-40,0,25),Text="Key System",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3,Parent=Inner}); stage("Title")
        local CloseButton=box("TextButton",{Name="Close",Font=FONT,TextColor3=FontColor,TextSize=TEXTSIZE,AutoButtonColor=false,Active=true,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,4),Size=UDim2.fromOffset(16,16),Text="X",ZIndex=4,Parent=Inner}); ApplyTextStroke(CloseButton); stage("CloseButton")
        local MainSectionOuter=box("Frame",{Name="MainSectionOuter",BackgroundColor3=BackgroundColor,BorderColor3=OutlineColor,Position=UDim2.fromOffset(8,25),Size=UDim2.new(1,-16,1,-33),ZIndex=3,Parent=Inner})
        local MainSectionInner=box("Frame",{Name="MainSectionInner",BackgroundColor3=BackgroundColor,BorderColor3=Black,BorderMode=Enum.BorderMode.Inset,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,1,0),ZIndex=4,Parent=MainSectionOuter}); stage("MainSection")
        local GroupboxOuter=box("Frame",{Name="GroupboxOuter",BackgroundColor3=MainColor,BorderColor3=OutlineColor,Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,1,-12),ZIndex=5,Parent=MainSectionInner})
        local GroupboxInner=box("Frame",{Name="GroupboxInner",BackgroundColor3=MainColor,BorderColor3=Black,BorderMode=Enum.BorderMode.Inset,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,1,0),ZIndex=6,Parent=GroupboxOuter}); stage("Groupbox")
        label({Name="GroupboxLabel",Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-16,0,18),Text="Authentication",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7,Parent=GroupboxInner}); stage("GroupboxLabel")
        local PAD=20
        label({Name="KeyLabel",Position=UDim2.fromOffset(PAD,30),Size=UDim2.new(1,-PAD*2,0,16),Text="Key",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7,Parent=GroupboxInner}); stage("KeyLabel")
        local KeyInputShell=box("Frame",{Name="KeyInputShell",BackgroundColor3=BackgroundColor,BorderColor3=OutlineColor,Position=UDim2.fromOffset(PAD,50),Size=UDim2.new(1,-PAD*2,0,26),ZIndex=7,Parent=GroupboxInner})
        local KeyInput=box("TextBox",{Name="KeyInput",BackgroundColor3=BackgroundColor,BackgroundTransparency=1,BorderSizePixel=0,Font=FONT,TextColor3=FontColor,TextSize=TEXTSIZE,Text="",PlaceholderText="SANTA-XXXX-XXXX",PlaceholderColor3=OutlineColor,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Size=UDim2.new(1,-10,1,0),Position=UDim2.fromOffset(4,0),ZIndex=8,Parent=KeyInputShell}); stage("KeyInput")
        local StatusLabel=label({Name="Status",Position=UDim2.fromOffset(PAD,84),Size=UDim2.new(1,-PAD*2,0,16),Text="",TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7,Parent=GroupboxInner}); stage("Status")
        local SubmitButton=box("TextButton",{Name="SubmitButton",BackgroundColor3=BackgroundColor,BorderColor3=OutlineColor,Position=UDim2.fromOffset(PAD,108),Size=UDim2.new(1,-PAD*2,0,28),Text="Check Key",TextColor3=FontColor,TextSize=TEXTSIZE,Font=FONT,AutoButtonColor=false,ZIndex=7,Parent=GroupboxInner}); ApplyTextStroke(SubmitButton); stage("SubmitButton")
        local busy=false
        local function setStatus(text,colour) StatusLabel.Text=text; StatusLabel.TextColor3=colour or FontColor end
        local function setInputBorder(colour) TweenService:Create(KeyInputShell,TweenInfo.new(0.15),{BorderColor3=colour}):Play() end
        local function setButton(colour,text) SubmitButton.Text=text; TweenService:Create(SubmitButton,TweenInfo.new(0.15),{BackgroundColor3=colour}):Play() end
        local function onSuccess(enteredKey)
            busy=true; setStatus("Key passed.",AccentColor); setInputBorder(AccentColor); setButton(AccentColor,"Welcome")
            if writefile then writefile(SaveFileName,enteredKey) end
            print(TAG.."Key has passed"); task.wait(1); KeySystemUI:Destroy(); SantaStep("main script", ScriptToRun)
        end
        local function onFailure(message)
            busy=true; setStatus(message,RiskColor); setInputBorder(RiskColor); setButton(RiskColor,"Wrong Key")
            task.wait(1.5); setInputBorder(OutlineColor); setButton(BackgroundColor,"Check Key"); busy=false
        end
        local function attempt()
            if busy then return end
            local enteredKey=KeyInput.Text:match("^%s*(.-)%s*$")
            if not enteredKey or #enteredKey==0 then onFailure("Enter a key first."); return end
            if not enteredKey:match(KEY_PATTERN) then onFailure("That is not a valid key format."); return end
            busy=true; SubmitButton.Text="Checking Key..."; setStatus("Verifying...",AccentColor); setInputBorder(AccentColor)
            local validKeys,err=FetchValidKeys()
            if not validKeys then onFailure(err or "Key check failed."); return end
            if IsKeyValid(enteredKey,validKeys) then onSuccess(enteredKey) else onFailure("Wrong key.") end
        end
        SubmitButton.MouseButton1Click:Connect(function() attempt() end)
        KeyInput.Focused:Connect(function() setInputBorder(AccentColor) end)
        KeyInput.FocusLost:Connect(function(enterPressed) setInputBorder(OutlineColor); if not busy and enterPressed then attempt() end end)
        SubmitButton.MouseEnter:Connect(function() if busy then return end; setButton(AccentColor,SubmitButton.Text) end)
        SubmitButton.MouseLeave:Connect(function() if busy then return end; setButton(BackgroundColor,SubmitButton.Text) end)
        CloseButton.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then KeySystemUI:Destroy() end end)
        local function fadeIn(root,time)
            local list={root}; for _,child in ipairs(root:GetDescendants()) do if child:IsA("GuiObject") then table.insert(list,child) end end
            for _,obj in ipairs(list) do
                local props={"BackgroundTransparency"}
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then table.insert(props,"TextTransparency") end
                for _,prop in ipairs(props) do local base=obj[prop]; obj[prop]=math.clamp(base+0.6,0,1); TweenService:Create(obj,TweenInfo.new(time),{[prop]=base}):Play() end
            end
        end
        task.spawn(function() task.wait(0.1); fadeIn(Outer,0.25) end)
    end

    local ok,err=pcall(buildUI)
    if ok then print(TAG.."UI build finished, last element: "..lastStage)
    else print(TAG.."UI BUILD FAILED after: "..lastStage); print(TAG.."error = "..tostring(err)) end
end)

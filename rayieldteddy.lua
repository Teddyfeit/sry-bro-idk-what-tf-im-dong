local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local triggerSettings = {
    enabled = false,
    teamCheck = false,
    delay = 0,
    holdMode = false,
    onHoldKey = Enum.UserInputType.MouseButton2, -- Rechtsklick halten zum Aktivieren
    clickInterval = 0.05
}

local isHolding = false
local lastClick = 0

-- Überprüfung der Maus-Ziele
local function getTarget()
    local target = Mouse.Target
    if target and target.Parent then
        local char = target.Parent
        if char:FindFirstChild("Humanoid") then
            local player = Players:GetPlayerFromCharacter(char)
            if player and player ~= LocalPlayer then
                if triggerSettings.teamCheck and player.Team == LocalPlayer.Team then
                    return nil
                end
                return player
            end
        end
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    if not triggerSettings.enabled then return end
    
    -- Check für Hold-Mode
    local canTrigger = true
    if triggerSettings.holdMode then
        canTrigger = game:GetService("UserInputService"):IsMouseButtonPressed(triggerSettings.onHoldKey)
    end

    if canTrigger then
        local target = getTarget()
        if target and (tick() - lastClick) >= (triggerSettings.delay + triggerSettings.clickInterval) then
            lastClick = tick()
            mouse1click() -- Simuliert den Klick
        end
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local espSettings = {
    enabled = false,
    boxes = false,
    tracers = false,
    headDots = false,
    names = false,
    distance = false,
    maxDistance = 500,
    boxColor = Color3.fromRGB(255, 255, 255),
    tracerColor = Color3.fromRGB(255, 255, 255),
    tracerOrigin = "Bottom" -- "Bottom" oder "Center"
}

local objects = {}

local function createEspObjects(player)
    objects[player] = {
        box = Drawing.new("Square"),
        tracer = Drawing.new("Line"),
        headDot = Drawing.new("Circle"),
        label = Drawing.new("Text")
    }
    local obj = objects[player]
    obj.box.Thickness = 1
    obj.box.Filled = false
    obj.tracer.Thickness = 1
    obj.headDot.Thickness = 1
    obj.headDot.Filled = true
    obj.label.Size = 14
    obj.label.Center = true
    obj.label.Outline = true
end

local function updateEsp()
    for player, obj in pairs(objects) do
        if espSettings.enabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") and player ~= LocalPlayer then
            local root = player.Character.HumanoidRootPart
            local head = player.Character.Head
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local dist = (Camera.CFrame.Position - root.Position).Magnitude

            if onScreen and dist <= espSettings.maxDistance then
                -- Box
                if espSettings.boxes then
                    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                    obj.box.Size = Vector2.new(2500 / pos.Z, headPos.Y - legPos.Y)
                    obj.box.Position = Vector2.new(pos.X - obj.box.Size.X / 2, pos.Y - obj.box.Size.Y / 2)
                    obj.box.Color = espSettings.boxColor
                    obj.box.Visible = true
                else obj.box.Visible = false end

                -- Tracers
                if espSettings.tracers then
                    obj.tracer.From = espSettings.tracerOrigin == "Bottom" and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    obj.tracer.To = Vector2.new(pos.X, pos.Y)
                    obj.tracer.Color = espSettings.tracerColor
                    obj.tracer.Visible = true
                else obj.tracer.Visible = false end

                -- Head Dots
                if espSettings.headDots then
                    local headVp = Camera:WorldToViewportPoint(head.Position)
                    obj.headDot.Position = Vector2.new(headVp.X, headVp.Y)
                    obj.headDot.Radius = 500 / pos.Z
                    obj.headDot.Color = espSettings.boxColor
                    obj.headDot.Visible = true
                else obj.headDot.Visible = false end

                -- Names & Distance
                if espSettings.names or espSettings.distance then
                    local text = ""
                    if espSettings.names then text = text .. player.Name end
                    if espSettings.distance then text = text .. " [" .. math.floor(dist) .. "m]" end
                    obj.label.Text = text
                    obj.label.Position = Vector2.new(pos.X, pos.Y + (obj.box.Size.Y / 2) + 5)
                    obj.label.Color = Color3.fromRGB(255, 255, 255)
                    obj.label.Visible = true
                else obj.label.Visible = false end
            else
                obj.box.Visible = false
                obj.tracer.Visible = false
                obj.headDot.Visible = false
                obj.label.Visible = false
            end
        else
            obj.box.Visible = false
            obj.tracer.Visible = false
            obj.headDot.Visible = false
            obj.label.Visible = false
        end
    end
end

Players.PlayerAdded:Connect(createEspObjects)
for _, p in pairs(Players:GetPlayers()) do createEspObjects(p) end
RunService.RenderStepped:Connect(updateEsp)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local aimlockEnabled = false
local aimlockPart = "Head"
local fovRadius = 100
local fovVisible = true

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Filled = false
fovCircle.Transparency = 1

local function getClosestPlayer()
    local target = nil
    local shortestDistance = math.huge

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild(aimlockPart) then
            local pos, onScreen = Camera:WorldToViewportPoint(v.Character[aimlockPart].Position)
            if onScreen then
                local distance = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                if distance < shortestDistance and distance <= fovRadius then
                    target = v
                    shortestDistance = distance
                end
            end
        end
    end
    return target
end

RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Radius = fovRadius
    fovCircle.Visible = fovVisible and aimlockEnabled

    if aimlockEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = getClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild(aimlockPart) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character[aimlockPart].Position)
        end
    end
end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local jumpEnabled = false
local jumpPowerValue = 50

local function updateJump()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    hum.UseJumpPower = true 

    if jumpEnabled then
        hum.JumpPower = jumpPowerValue
    else
        hum.JumpPower = 50
    end
end

LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    if jumpEnabled then
        updateJump()
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local flying = false
local flySpeed = 50
local camera = workspace.CurrentCamera
local connection

-- Die Flug-Logik
local function toggleFly(stat)
    flying = stat
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart

    if flying then
        -- Wir nutzen eine RenderStepped-Schleife für die Bewegung
        connection = RunService.RenderStepped:Connect(function()
            local direction = Vector3.new(0, 0, 0)
            
            -- Tastatur-Abfrage für Bewegung
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction = direction - Vector3.new(0, 1, 0) end

            root.Velocity = direction * flySpeed
            
            -- Verhindert, dass der Charakter umfällt
            root.RotVelocity = Vector3.new(0, 0, 0)
        end)
    else
        if connection then connection:Disconnect() end
        root.Velocity = Vector3.new(0, 0, 0)
    end
end


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local speedEnabled = false
local walkSpeedValue = 16 -- Standard Roblox Speed

-- Funktion zum Aktualisieren der Geschwindigkeit
local function updateSpeed()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    
    if speedEnabled then
        hum.WalkSpeed = walkSpeedValue
    else
        hum.WalkSpeed = 16
    end
end

-- Sicherstellen, dass der Speed nach dem Respawn erhalten bleibt
LocalPlayer.CharacterAdded:Connect(function(character)
    local hum = character:WaitForChild("Humanoid")
    task.wait(0.5) -- Kurz warten, bis das Spiel den Standard-Speed setzt
    if speedEnabled then
        hum.WalkSpeed = walkSpeedValue
    end
end)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Teddy Hub",
   Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
   LoadingTitle = "Welcome",
   LoadingSubtitle = "by Teddyfight",
   ShowText = "Rayfield", -- for mobile users to unhide Rayfield, change if you'd like
   Theme = "Default", -- Check https://docs.sirius.menu/rayfield/configuration/themes

   ToggleUIKeybind = "K", -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false, -- Prevents Rayfield from emitting warnings when the script has a version mismatch with the interface.

   -- ScriptID = "sid_xxxxxxxxxxxx", -- Your Script ID from developer.sirius.menu — enables analytics, managed keys, and script hosting

   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil, -- Create a custom folder for your hub/game
      FileName = "Big Hub"
   },

   Discord = {
      Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
      Invite = "https://discord.gg/Q7Suga4GnS", -- The Discord invite code, do not include Discord.gg/. E.g. Discord.gg/ABCD would be ABCD
      RememberJoins = true -- Set this to false to make them join the Discord every time they load it up
   },

   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "Key System",
      Subtitle = "ahmed have dih",
      Note = "key is selimthegoat", -- Use this to tell the user how to get a key
      FileName = "Key", -- It is recommended to use something unique, as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"selimthegoat"} 
   }
})

local Tab = Window:CreateTab("Combat", 4483362458)

Tab:CreateToggle({
   Name = "Enable Aimlock",
   CurrentValue = false,
   Flag = "AimlockToggle",
   Callback = function(Value)
      aimlockEnabled = Value
   end,
})

Tab:CreateDropdown({
   Name = "Aim Part",
   Options = {"Head", "HumanoidRootPart"},
   CurrentOption = {"Head"},
   Flag = "AimPartDropdown",
   Callback = function(Option)
      aimlockPart = Option[1]
   end,
})

Tab:CreateSlider({
   Name = "FOV Radius",
   Range = {10, 800},
   Increment = 10,
   Suffix = " Pixels",
   CurrentValue = 100,
   Flag = "FOVSlider",
   Callback = function(Value)
      fovRadius = Value
   end,
})

Tab:CreateToggle({
   Name = "Show FOV Circle",
   CurrentValue = true,
   Flag = "FOVVisible",
   Callback = function(Value)
      fovVisible = Value
   end,
})

Tab:CreateSection("Triggerbot Main")

Tab:CreateToggle({
   Name = "Enable Triggerbot",
   CurrentValue = false,
   Flag = "TriggerEnabled",
   Callback = function(Value) triggerSettings.enabled = Value end,
})

Tab:CreateToggle({
   Name = "Team Check",
   CurrentValue = false,
   Flag = "TriggerTeam",
   Callback = function(Value) triggerSettings.teamCheck = Value end,
})

Tab:CreateSection("Customization")

Tab:CreateSlider({
   Name = "Reaction Delay (Seconds)",
   Range = {0, 1},
   Increment = 0.01,
   Suffix = "s",
   CurrentValue = 0,
   Flag = "TriggerDelay",
   Callback = function(Value) triggerSettings.delay = Value end,
})

Tab:CreateSlider({
   Name = "Click Interval (CPS)",
   Range = {0.01, 0.5},
   Increment = 0.01,
   Suffix = "s",
   CurrentValue = 0.05,
   Flag = "TriggerInterval",
   Callback = function(Value) triggerSettings.clickInterval = Value end,
})

Tab:CreateSection("Activation")

Tab:CreateToggle({
   Name = "Hold Mode (Only on Right Click)",
   CurrentValue = false,
   Flag = "TriggerHold",
   Callback = function(Value) triggerSettings.holdMode = Value end,
})

local Tab = Window:CreateTab("Movement", 4483362458) 

Tab:CreateToggle({
   Name = "Enable Speed Modifier",
   CurrentValue = false,
   Flag = "SpeedToggle",
   Callback = function(Value)
      speedEnabled = Value
      updateSpeed()
   end,
})

Tab:CreateSlider({
   Name = "WalkSpeed",
   Range = {16, 500},
   Increment = 1,
   Suffix = " Speed",
   CurrentValue = 16,
   Flag = "SpeedSlider",
   Callback = function(Value)
      walkSpeedValue = Value
      if speedEnabled then
          updateSpeed()
      end
   end,
})

Tab:CreateToggle({
   Name = "Enable Fly",
   CurrentValue = false,
   Flag = "FlyToggle",
   Callback = function(Value)
      toggleFly(Value)
   end,
})

Tab:CreateSlider({
   Name = "Fly Speed",
   Range = {10, 300},
   Increment = 10,
   Suffix = " Speed",
   CurrentValue = 50,
   Flag = "FlySpeedSlider",
   Callback = function(Value)
      flySpeed = Value
   end,
})

Tab:CreateToggle({
   Name = "Enable Jump Modifier",
   CurrentValue = false,
   Flag = "JumpToggle",
   Callback = function(Value)
      jumpEnabled = Value
      updateJump()
   end,
})

Tab:CreateSlider({
   Name = "Jump Power",
   Range = {50, 500},
   Increment = 5,
   Suffix = " Power",
   CurrentValue = 50,
   Flag = "JumpSlider",
   Callback = function(Value)
      jumpPowerValue = Value
      if jumpEnabled then
          updateJump()
      end
   end,
})

local Tab = Window:CreateTab("Visuel", 4483362458)

Tab:CreateToggle({Name = "Master Switch", CurrentValue = false, Callback = function(v) espSettings.enabled = v end})

Tab:CreateSection("Features")
Tab:CreateToggle({Name = "Boxes", CurrentValue = false, Callback = function(v) espSettings.boxes = v end})
Tab:CreateToggle({Name = "Tracers", CurrentValue = false, Callback = function(v) espSettings.tracers = v end})
Tab:CreateToggle({Name = "Head Dots", CurrentValue = false, Callback = function(v) espSettings.headDots = v end})
Tab:CreateToggle({Name = "Show Names", CurrentValue = false, Callback = function(v) espSettings.names = v end})
Tab:CreateToggle({Name = "Show Distance", CurrentValue = false, Callback = function(v) espSettings.distance = v end})

Tab:CreateSection("Settings")
Tab:CreateSlider({Name = "Max Distance", Range = {100, 5000}, Increment = 100, CurrentValue = 500, Callback = function(v) espSettings.maxDistance = v end})
Tab:CreateDropdown({Name = "Tracer Origin", Options = {"Bottom", "Center"}, CurrentOption = {"Bottom"}, Callback = function(v) espSettings.tracerOrigin = v end})

Tab:CreateSection("Colors")
Tab:CreateColorPicker({Name = "Box/Head Color", Color = Color3.fromRGB(255, 255, 255), Callback = function(v) espSettings.boxColor = v end})
Tab:CreateColorPicker({Name = "Tracer Color", Color = Color3.fromRGB(255, 255, 255), Callback = function(v) espSettings.tracerColor = v end})



local Tab = Window:CreateTab("Scripts", 4483362458)

local Button = Tab:CreateButton({
   Name = "Bloxstrike NerverLose - Keyless",
   Callback = function()

     loadstring(game:HttpGet("https://raw.githubusercontent.com/Xranbfg132/NeverLose/refs/heads/main/main1.lua"))()

   end,
})

local Button = Tab:CreateButton({
   Name = "Dropkick Script - Keyless",
   Callback = function()

     loadstring(game:HttpGet("https://raw.githubusercontent.com/gsm231/Fe-DropKick/refs/heads/main/V0.1"))()

   end,
})

local Button = Tab:CreateButton({Name = "Infinity Yield - Keyless",
   Callback = function()
            
     loadstring(game:HttpGet("https://raw.githubusercontent.com/Teddyfeit/sry-bro-idk-what-tf-im-dong/refs/heads/main/not1.lua"))()
     loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Soluna Universal - Keyless",
   Callback = function()
     
     loadstring(game:HttpGet("https://raw.githubusercontent.com/EndOverdosing/Soluna-API/refs/heads/main/universal.lua",true))()

   end,
})

local Button = Tab:CreateButton({
   Name = "Fe Collection - Keyless",
   Callback = function()
            
     loadstring(game:HttpGet("https://raw.githubusercontent.com/Teddyfeit/sry-bro-idk-what-tf-im-dong/refs/heads/main/not2.lua"))()
     loadstring(game:HttpGet("https://raw.githubusercontent.com/sypcerr/FECollection/refs/heads/main/script.lua",true))()
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Kiciahook V2 Rivals - Key",
   Callback = function()

     loadstring(game:HttpGet("https://raw.githubusercontent.com/kiciahook/kiciahook/refs/heads/main/loader.luau"))()
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Bankroll Bloxstrike - Keyless",
   Callback = function()

     loadstring(game:HttpGet("https://raw.githubusercontent.com/Zylang104/bankroll/main/bankroll.lua"))()
   
   end,
})

local Tab = Window:CreateTab("Solix Hub", 4483362458)

local Label = Tab:CreateLabel("Not every game is Supported", 4483362458, Color3.fromRGB(255, 255, 255), false) -- Title, Icon, Color, IgnoreTheme

local Button = Tab:CreateButton({
   Name = "Run Solix Hub",
   Callback = function()

     loadstring(game:HttpGet("https://raw.githubusercontent.com/bao8jl/solixhub/main/loader"))()
   
   end,
})

local Tab = Window:CreateTab("Aether Hub", 4483362458)

local Label = Tab:CreateLabel("Not every game is Supported", 4483362458, Color3.fromRGB(255, 255, 255), false)

local Button = Tab:CreateButton({
   Name = "Run Aether",
   Callback = function()

     loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/2529a5f9dfddd5523ca4e22f21cceffa.lua"))()
   
   end,
})

local Tab = Window:CreateTab("Discord", 4483362458)

local Button = Tab:CreateButton({
   Name = "My Discord Server",
   Callback = function()

     setclipboard("https://discord.gg/Q7Suga4GnS")

     Rayfield:Notify({
     Title = "Copied",
     Content = "Discord Server Link Copied!",
     Duration = 2.5,
     Image = "rewind",
})
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Kiciahook",
   Callback = function()

     setclipboard("https://discord.gg/kicia")

     Rayfield:Notify({
     Title = "Copied",
     Content = "Discord Server Link Copied!",
     Duration = 2.5,
     Image = "rewind",
})
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Bankroll",
   Callback = function()

     setclipboard("")

     Rayfield:Notify({
     Title = "Oops...",
     Content = "Cant get the server Link",
     Duration = 2.5,
     Image = "rewind",
})
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Solix Hub",
   Callback = function()

     setclipboard("https://discord.gg/s4NPuBrxZG")

     Rayfield:Notify({
     Title = "Copied",
     Content = "Discord Server Link Copied!",
     Duration = 2.5,
     Image = "rewind",
})
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Aether Hub",
   Callback = function()

     setclipboard("https://discord.gg/pEx6UmDUKV")

     Rayfield:Notify({
     Title = "Copied",
     Content = "Discord Server Link Copied!",
     Duration = 2.5,
     Image = "rewind",
})
   
   end,
})

local Button = Tab:CreateButton({
   Name = "Soluna",
   Callback = function()

     setclipboard("https://discord.gg/Zw6zknetPH")

     Rayfield:Notify({
     Title = "Copied",
     Content = "Discord Server Link Copied!",
     Duration = 2.5,
     Image = "rewind",
})
   
   end,
})

loadstring(game:HttpGet("https://raw.githubusercontent.com/Teddyfeit/sry-bro-idk-what-tf-im-dong/refs/heads/main/v2not1"))()

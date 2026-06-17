local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Custom crosshair menu",
   LoadingTitle = "loading custom crosshair",
   LoadingSubtitle = "by Some random kid",
   Theme = "Default"
})

local MainTab = Window:CreateTab("Crosshair Settings", 4483362458)
local CircleTab = Window:CreateTab("Circle Settings", 4483362458)
local TrackingTab = Window:CreateTab("Crosshair Tracking", 4483362458)

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Crosshair = {
    Visible = true, SpinSpeed = 0.005, CentralGap = 8, TotalLength = 112,
    LineThickness = 2, OutlineThickness = 4, ColorStart = Color3.fromRGB(180, 180, 180),
    ColorEnd = Color3.fromRGB(20, 20, 20), CircleVisible = true, CircleRadius = 119,
    CircleTransparency = 0.3, CircleColor = Color3.fromRGB(15, 15, 25),
    TrackingEnabled = false, TrackingRadius = 150, TrackPart = "Head", TeamCheck = true
}

local FIXED_SEG_LEN = 2
local crosshairLines, crosshairOutlines, backgroundCircle, renderConnection = {}, {}, nil, nil

local function createDrawing(class, properties)
    local d = Drawing.new(class)
    for k, v in pairs(properties) do d[k] = v end
    return d
end

local function ClearCrosshair()
    if backgroundCircle then backgroundCircle:Remove() backgroundCircle = nil end
    for arm = 1, #crosshairLines do
        if crosshairLines[arm] then
            for seg = 1, #crosshairLines[arm] do
                if crosshairLines[arm][seg] then crosshairLines[arm][seg]:Remove() end
                if crosshairOutlines[arm][seg] then crosshairOutlines[arm][seg]:Remove() end
            end
        end
    end
    crosshairLines, crosshairOutlines = {}, {}
end

local function InitializeCrosshair()
    ClearCrosshair()
    backgroundCircle = createDrawing("Circle", {
        Filled = true, NumSides = 64, Radius = Crosshair.CircleRadius,
        Color = Crosshair.CircleColor, Transparency = Crosshair.CircleTransparency,
        Visible = Crosshair.Visible and Crosshair.CircleVisible
    })
    local segmentsNeeded = math.max(1, math.floor(Crosshair.TotalLength / FIXED_SEG_LEN))
    for arm = 1, 4 do
        crosshairLines[arm], crosshairOutlines[arm] = {}, {}
        for seg = 1, segmentsNeeded do
            local progress = (seg - 0.5) / segmentsNeeded
            crosshairOutlines[arm][seg] = createDrawing("Line", {Thickness = Crosshair.OutlineThickness, Color = Color3.fromRGB(0, 0, 0), Transparency = 1, Visible = Crosshair.Visible})
            crosshairLines[arm][seg] = createDrawing("Line", {Thickness = Crosshair.LineThickness, Color = Crosshair.ColorStart:Lerp(Crosshair.ColorEnd, progress), Transparency = 1, Visible = Crosshair.Visible})
        end
    end
end

local function GetClosestPlayer(centerPos)
    local closestPlayer, shortestDistance = nil, Crosshair.TrackingRadius
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(Crosshair.TrackPart) and player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            if Crosshair.TeamCheck and player.Team == LocalPlayer.Team then continue end
            local screenPos, onScreen = Camera:WorldToViewportPoint(player.Character[Crosshair.TrackPart].Position)
            if onScreen then
                local target2D = Vector2.new(screenPos.X, screenPos.Y)
                local distance = (target2D - centerPos).Magnitude
                if distance < shortestDistance then shortestDistance = distance closestPlayer = target2D end
            end
        end
    end
    return closestPlayer
end

local baseAngles = {0, math.pi / 2, math.pi, math.pi * 1.5}
local currentAngle = 0

if renderConnection then renderConnection:Disconnect() end
renderConnection = RunService.RenderStepped:Connect(function()
    local crosshairCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    if Crosshair.TrackingEnabled then
        local targetPos = GetClosestPlayer(crosshairCenter)
        if targetPos then crosshairCenter = targetPos end
    end
    if backgroundCircle then
        backgroundCircle.Position = crosshairCenter backgroundCircle.Radius = Crosshair.CircleRadius
        backgroundCircle.Color = Crosshair.CircleColor backgroundCircle.Transparency = Crosshair.CircleTransparency
        backgroundCircle.Visible = Crosshair.Visible and Crosshair.CircleVisible
    end
    currentAngle = currentAngle + Crosshair.SpinSpeed
    for arm = 1, 4 do
        local angle = baseAngles[arm] + currentAngle
        local cos, sin = math.cos(angle), math.sin(angle)
        local armLines, armOutlines = crosshairLines[arm], crosshairOutlines[arm]
        if armLines then
            for seg = 1, #armLines do
                local mainLine, outlineLine = armLines[seg], armOutlines[seg]
                if mainLine and outlineLine then
                    if Crosshair.Visible then
                        local startDist = Crosshair.CentralGap + ((seg - 1) * FIXED_SEG_LEN)
                        local endDist = Crosshair.CentralGap + (seg * FIXED_SEG_LEN)
                        local sPos = crosshairCenter + Vector2.new(cos * startDist, sin * startDist)
                        local ePos = crosshairCenter + Vector2.new(cos * endDist, sin * endDist)
                        outlineLine.From, outlineLine.To, outlineLine.Thickness, outlineLine.Visible = sPos, ePos, Crosshair.OutlineThickness, true
                        mainLine.From, mainLine.To, mainLine.Thickness = sPos, ePos, Crosshair.LineThickness
                        mainLine.Color = Crosshair.ColorStart:Lerp(Crosshair.ColorEnd, (seg - 0.5) / math.max(1, math.floor(Crosshair.TotalLength / FIXED_SEG_LEN)))
                        mainLine.Visible = true
                    else mainLine.Visible, outlineLine.Visible = false, false end
                end
            end
        end
    end
end)
InitializeCrosshair()

MainTab:CreateToggle({Name = "Crosshair Visible", CurrentValue = true, Callback = function(v) Crosshair.Visible = v end})
MainTab:CreateSlider({Name = "Spin Speed", Increment = 0.001, Suffix = " speed", CurrentValue = 0.005, Range = {0, 0.05}, Callback = function(v) Crosshair.SpinSpeed = v end})
MainTab:CreateSlider({Name = "Central Gap", Increment = 1, Suffix = " px", CurrentValue = 8, Range = {0, 50}, Callback = function(v) Crosshair.CentralGap = v end})
MainTab:CreateSlider({Name = "Total Length", Increment = 2, Suffix = " px", CurrentValue = 112, Range = {10, 300}, Callback = function(v) Crosshair.TotalLength = v InitializeCrosshair() end})
MainTab:CreateSlider({Name = "Line Thickness", Increment = 1, Suffix = " px", CurrentValue = 2, Range = {1, 10}, Callback = function(v) Crosshair.LineThickness = v end})
MainTab:CreateSlider({Name = "Outline Thickness", Increment = 1, Suffix = " px", CurrentValue = 4, Range = {0, 15}, Callback = function(v) Crosshair.OutlineThickness = v end})
MainTab:CreateColorPicker({Name = "Line Color (Start)", Color = Color3.fromRGB(180, 180, 180), Callback = function(v) Crosshair.ColorStart = v end})
MainTab:CreateColorPicker({Name = "Line Color (End)", Color = Color3.fromRGB(20, 20, 20), Callback = function(v) Crosshair.ColorEnd = v end})

CircleTab:CreateToggle({Name = "Circle Visible", CurrentValue = true, Callback = function(v) Crosshair.CircleVisible = v end})
CircleTab:CreateSlider({Name = "Circle Radius", Increment = 5, Suffix = " px", CurrentValue = 119, Range = {10, 300}, Callback = function(v) Crosshair.CircleRadius = v end})
CircleTab:CreateSlider({Name = "Circle Transparency", Increment = 0.05, Suffix = " alpha", CurrentValue = 0.3, Range = {0, 1}, Callback = function(v) Crosshair.CircleTransparency = v end})
CircleTab:CreateColorPicker({Name = "Circle Color", Color = Color3.fromRGB(15, 15, 25), Callback = function(v) Crosshair.CircleColor = v end})

TrackingTab:CreateToggle({Name = "Enable Tracking", CurrentValue = false, Callback = function(v) Crosshair.TrackingEnabled = v end})
TrackingTab:CreateSlider({Name = "Activation Radius (FOV)", Increment = 10, Suffix = " px", CurrentValue = 150, Range = {10, 800}, Callback = function(v) Crosshair.TrackingRadius = v end})
TrackingTab:CreateDropdown({Name = "Target Part", Options = {"Head", "HumanoidRootPart"}, CurrentOption = {"Head"}, MultipleOptions = false, Callback = function(v) Crosshair.TrackPart = v end})
TrackingTab:CreateToggle({Name = "Team Check", CurrentValue = true, Callback = function(v) Crosshair.TeamCheck = v end})

Rayfield:LoadConfiguration()

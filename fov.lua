local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local Crosshair = {
	Visible = true,
	SpinSpeed = 0.005,
	CentralGap = 8,
	TotalLength = 112,
	LineThickness = 2,
	OutlineThickness = 4,
	
	ColorStart = Color3.fromRGB(180, 180, 180),
	ColorEnd = Color3.fromRGB(20, 20, 20),
	
	CircleVisible = true,
	CircleRadius = 119,
	CircleTransparency = 0.3,
	CircleColor = Color3.fromRGB(15, 15, 25)
}

local FIXED_SEG_LEN = 2
local crosshairLines = {}
local crosshairOutlines = {}
local backgroundCircle = nil

local function createDrawing(class, properties)
	local d = Drawing.new(class)
	for k, v in pairs(properties) do d[k] = v end
	return d
end

local function InitializeCrosshair()
	backgroundCircle = createDrawing("Circle", {
		Filled = true,
		NumSides = 64,
		Radius = Crosshair.CircleRadius,
		Color = Crosshair.CircleColor,
		Transparency = Crosshair.CircleTransparency,
		Visible = Crosshair.Visible and Crosshair.CircleVisible
	})

	local segmentsNeeded = math.max(1, math.floor(Crosshair.TotalLength / FIXED_SEG_LEN))
	
	for arm = 1, 4 do
		crosshairLines[arm] = {}
		crosshairOutlines[arm] = {}
		
		for seg = 1, segmentsNeeded do
			local progress = (seg - 0.5) / segmentsNeeded

			crosshairOutlines[arm][seg] = createDrawing("Line", {
				Thickness = Crosshair.OutlineThickness,
				Color = Color3.fromRGB(0, 0, 0),
				Transparency = 1,
				Visible = Crosshair.Visible
			})
			
			crosshairLines[arm][seg] = createDrawing("Line", {
				Thickness = Crosshair.LineThickness,
				Color = Crosshair.ColorStart:Lerp(Crosshair.ColorEnd, progress),
				Transparency = 1,
				Visible = Crosshair.Visible
			})
		end
	end
end

local baseAngles = {0, math.pi / 2, math.pi, math.pi * 1.5}
local currentAngle = 0

RunService.RenderStepped:Connect(function()
	-- Berechnet das exakte Zentrum des Bildschirms für PC und Mobile
	local viewportSize = Camera.ViewportSize
	local centerPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	
	if backgroundCircle then
		backgroundCircle.Position = centerPos
		backgroundCircle.Visible = Crosshair.Visible and Crosshair.CircleVisible
	end
	
	currentAngle = currentAngle + Crosshair.SpinSpeed
	
	for arm = 1, 4 do
		local angle = baseAngles[arm] + currentAngle
		local cos = math.cos(angle)
		local sin = math.sin(angle)
		
		local armLines = crosshairLines[arm]
		local armOutlines = crosshairOutlines[arm]
		
		if armLines then
			for seg = 1, #armLines do
				local mainLine = armLines[seg]
				local outlineLine = armOutlines[seg]
				
				if mainLine and outlineLine then
					if Crosshair.Visible then
						-- Abstandskette ausgehend vom festen Mittelpunkt berechnen
						local startDist = Crosshair.CentralGap + ((seg - 1) * FIXED_SEG_LEN)
						local endDist = Crosshair.CentralGap + (seg * FIXED_SEG_LEN)
						
						local sPos = centerPos + Vector2.new(cos * startDist, sin * startDist)
						local ePos = centerPos + Vector2.new(cos * endDist, sin * endDist)
						
						-- Koordinaten setzen und Sichtbarkeit erzwingen
						outlineLine.From = sPos
						outlineLine.To = ePos
						outlineLine.Visible = true
						
						mainLine.From = sPos
						mainLine.To = ePos
						mainLine.Visible = true
					else
						mainLine.Visible = false
						outlineLine.Visible = false
					end
				end
			end
		end
	end
end)

InitializeCrosshair()

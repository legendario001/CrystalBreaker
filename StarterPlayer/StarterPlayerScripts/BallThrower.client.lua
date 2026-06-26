-- ============================================
-- BallThrower (LocalScript) - StarterPlayerScripts
-- Presiona 1 o click en boton para equipar/desequipar
-- Click izquierdo para lanzar (sin desequipar)
-- ============================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ballEquipped = false
local inputDebounce = false
local throwDebounce = false

-- ============================================
-- GUI MODERNA
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Barra inferior
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(0, 200, 0, 70)
bottomBar.Position = UDim2.new(0.5, -100, 1, -80)
bottomBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
bottomBar.BackgroundTransparency = 0.2
bottomBar.BorderSizePixel = 0
bottomBar.Parent = screenGui
Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 16)

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(100, 200, 255)
uiStroke.Thickness = 2
uiStroke.Transparency = 0.5
uiStroke.Parent = bottomBar

-- Boton de pelota
local ballButton = Instance.new("TextButton")
ballButton.Name = "BallButton"
ballButton.Size = UDim2.new(0, 60, 0, 60)
ballButton.Position = UDim2.new(0.5, -30, 0.5, -30)
ballButton.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
ballButton.BorderSizePixel = 0
ballButton.Text = ""
ballButton.Parent = bottomBar
Instance.new("UICorner", ballButton).CornerRadius = UDim.new(0, 12)

local btnStroke = Instance.new("UIStroke")
btnStroke.Name = "BtnStroke"
btnStroke.Color = Color3.fromRGB(100, 200, 255)
btnStroke.Thickness = 2
btnStroke.Transparency = 0.3
btnStroke.Parent = ballButton

-- Icono de pelota
local ballIcon = Instance.new("TextLabel")
ballIcon.Size = UDim2.new(0.6, 0, 0.6, 0)
ballIcon.Position = UDim2.new(0.2, 0, 0.1, 0)
ballIcon.BackgroundTransparency = 1
ballIcon.Text = "⚽"
ballIcon.TextScaled = true
ballIcon.Parent = ballButton

-- Tecla 1
local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(0.3, 0, 0.3, 0)
keyLabel.Position = UDim2.new(0.65, 0, 0.6, 0)
keyLabel.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
keyLabel.BorderSizePixel = 0
keyLabel.Text = "1"
keyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
keyLabel.TextScaled = true
keyLabel.Font = Enum.Font.GothamBold
keyLabel.Parent = ballButton
Instance.new("UICorner", keyLabel).CornerRadius = UDim.new(0, 4)

-- Nombre de la herramienta
local toolName = Instance.new("TextLabel")
toolName.Size = UDim2.new(0, 120, 0, 20)
toolName.Position = UDim2.new(0.5, -60, 0, -25)
toolName.BackgroundTransparency = 1
toolName.Text = "Crystal Ball"
toolName.TextColor3 = Color3.fromRGB(100, 200, 255)
toolName.TextScaled = true
toolName.Font = Enum.Font.GothamBold
toolName.TextTransparency = 0.5
toolName.Parent = bottomBar

-- Funcion para actualizar el boton visualmente
local function updateButton()
	if ballEquipped then
		ballButton.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
		ballIcon.TextColor3 = Color3.fromRGB(0, 0, 0)
		keyLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		keyLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		btnStroke.Color = Color3.fromRGB(150, 230, 255)
		toolName.TextTransparency = 0
	else
		ballButton.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		ballIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
		keyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
		keyLabel.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
		btnStroke.Color = Color3.fromRGB(100, 200, 255)
		toolName.TextTransparency = 0.5
	end
end

-- ============================================
-- SISTEMA DE PELOTA
-- ============================================

local function equipBall()
	if ballEquipped then return end
	local char = player.Character
	if not char then return end

	-- Eliminar pelota anterior si existe
	local old = char:FindFirstChild("CrystalBall")
	if old then old:Destroy() end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local oldBp = bp:FindFirstChild("CrystalBall")
		if oldBp then oldBp:Destroy() end
	end

	local tool = Instance.new("Tool")
	tool.Name = "CrystalBall"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.5, 1.5, 1.5)
	handle.Shape = Enum.PartType.Ball
	handle.Color = Color3.fromRGB(100, 200, 255)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool.Parent = char
	ballEquipped = true
	updateButton()
end

local function unequipBall()
	if not ballEquipped then return end
	local char = player.Character
	if char then
		local tool = char:FindFirstChild("CrystalBall")
		if tool then tool:Destroy() end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local tool = bp:FindFirstChild("CrystalBall")
		if tool then tool:Destroy() end
	end
	ballEquipped = false
	updateButton()
end

local function throwBall()
	if not ballEquipped then return end
	if throwDebounce then return end
	throwDebounce = true

	local char = player.Character
	if not char then
		throwDebounce = false
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		throwDebounce = false
		return
	end

	-- NO desequipar, solo lanzar una pelota fisica

	local ball = Instance.new("Part")
	ball.Name = "ThrownBall"
	ball.Size = Vector3.new(1.5, 1.5, 1.5)
	ball.Shape = Enum.PartType.Ball
	ball.Color = Color3.fromRGB(100, 200, 255)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = false
	ball.CanCollide = true
	ball.Massless = false
	ball.Position = root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 3, 0)
	ball.Parent = workspace

	-- Fisicas de rebote
	local bounceForce = Instance.new("VectorForce")
	bounceForce.RelativeTo = Enum.ActuatorRelativeTo.World

	local attachment = Instance.new("Attachment")
	attachment.Parent = ball
	bounceForce.Attachment0 = attachment
	bounceForce.Force = Vector3.new(0, 0, 0)
	bounceForce.Parent = ball

	-- Propiedades de rebote (elasticidad alta)
	ball.CustomPhysicalProperties = PhysicalProperties.new(
		0.5,   -- Density
		0.3,   -- Friction
		1.0,   -- Elasticity (alto = mucho rebote)
		0.3,   -- FrictionWeight
		1.0    -- ElasticityWeight
	)

	-- Lanzar con velocidad
	local direction = (mouse.Hit.Position - ball.Position).Unit
	local launchSpeed = 100
	ball.AssemblyLinearVelocity = direction * launchSpeed + Vector3.new(0, 20, 0)

	-- Eliminar despues de 5 segundos
	task.delay(5, function()
		if ball and ball.Parent then
			ball:Destroy()
		end
	end)

	task.wait(0.3)
	throwDebounce = false
end

-- ============================================
-- INPUTS
-- ============================================

-- Tecla 1 para equipar/desequipar
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.One then
		if inputDebounce then return end
		inputDebounce = true
		if ballEquipped then
			unequipBall()
		else
			equipBall()
		end
		task.wait(0.3)
		inputDebounce = false
	end
end)

-- Click izquierdo para lanzar
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if ballEquipped then
			throwBall()
		end
	end
end)

-- Click en el boton
ballButton.MouseButton1Click:Connect(function()
	if inputDebounce then return end
	inputDebounce = true
	if ballEquipped then
		unequipBall()
	else
		equipBall()
	end
	task.wait(0.3)
	inputDebounce = false
end)

-- Al respawnear, reiniciar
player.CharacterAdded:Connect(function()
	ballEquipped = false
	inputDebounce = false
	throwDebounce = false
	updateButton()
end)

updateButton()
print("BallThrower cargado!")

-- ============================================
-- BallThrower (LocalScript) - StarterPlayerScripts
-- 1 = equipar/desequipar pelota
-- Click = lanzar pelota
-- E = recoger cofre / colocar personaje en pedestal
-- G = soltar personaje
-- ============================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ballEquipped = false
local inputDebounce = false
local throwDebounce = false
local isCarrying = false

-- Eventos del servidor
local ThrowBallEvent = ReplicatedStorage:WaitForChild("ThrowBall", 15)
local PickupChestEvent = ReplicatedStorage:WaitForChild("PickupChest", 15)
local PlaceCharacterEvent = ReplicatedStorage:WaitForChild("PlaceCharacter", 15)
local DropCharacterEvent = ReplicatedStorage:WaitForChild("DropCharacter", 15)

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

-- ============================================
-- BOTON PELOTA
-- ============================================
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

local ballIcon = Instance.new("TextLabel")
ballIcon.Size = UDim2.new(0.6, 0, 0.6, 0)
ballIcon.Position = UDim2.new(0.2, 0, 0.1, 0)
ballIcon.BackgroundTransparency = 1
ballIcon.Text = "⚽"
ballIcon.TextScaled = true
ballIcon.Parent = ballButton

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

-- ============================================
-- PANEL DE PERSONAJE (solo al cargar)
-- ============================================
local carryPanel = Instance.new("Frame")
carryPanel.Name = "CarryPanel"
carryPanel.Size = UDim2.new(0, 220, 0, 70)
carryPanel.Position = UDim2.new(0.5, -110, 1, -80)
carryPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
carryPanel.BackgroundTransparency = 0.2
carryPanel.BorderSizePixel = 0
carryPanel.Visible = false
carryPanel.Parent = screenGui
Instance.new("UICorner", carryPanel).CornerRadius = UDim.new(0, 16)

local carryStroke = Instance.new("UIStroke")
carryStroke.Color = Color3.fromRGB(255, 200, 50)
carryStroke.Thickness = 2
carryStroke.Transparency = 0.3
carryStroke.Parent = carryPanel

-- Boton Colocar
local placeBtn = Instance.new("TextButton")
placeBtn.Name = "PlaceBtn"
placeBtn.Size = UDim2.new(0, 90, 0, 50)
placeBtn.Position = UDim2.new(0, 10, 0, 10)
placeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
placeBtn.BorderSizePixel = 0
placeBtn.Text = "Colocar"
placeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
placeBtn.TextScaled = true
placeBtn.Font = Enum.Font.GothamBold
placeBtn.Parent = carryPanel
Instance.new("UICorner", placeBtn).CornerRadius = UDim.new(0, 10)

local placeKey = Instance.new("TextLabel")
placeKey.Size = UDim2.new(0.3, 0, 0.3, 0)
placeKey.Position = UDim2.new(0.65, 0, 0.6, 0)
placeKey.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
placeKey.BorderSizePixel = 0
placeKey.Text = "E"
placeKey.TextColor3 = Color3.fromRGB(0, 120, 60)
placeKey.TextScaled = true
placeKey.Font = Enum.Font.GothamBold
placeKey.Parent = placeBtn
Instance.new("UICorner", placeKey).CornerRadius = UDim.new(0, 4)

-- Boton Soltar
local dropBtn = Instance.new("TextButton")
dropBtn.Name = "DropBtn"
dropBtn.Size = UDim2.new(0, 90, 0, 50)
dropBtn.Position = UDim2.new(0, 120, 0, 10)
dropBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
dropBtn.BorderSizePixel = 0
dropBtn.Text = "Soltar"
dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dropBtn.TextScaled = true
dropBtn.Font = Enum.Font.GothamBold
dropBtn.Parent = carryPanel
Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 10)

local dropKey = Instance.new("TextLabel")
dropKey.Size = UDim2.new(0.3, 0, 0.3, 0)
dropKey.Position = UDim2.new(0.65, 0, 0.6, 0)
dropKey.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dropKey.BorderSizePixel = 0
dropKey.Text = "G"
dropKey.TextColor3 = Color3.fromRGB(150, 30, 30)
dropKey.TextScaled = true
dropKey.Font = Enum.Font.GothamBold
dropKey.Parent = dropBtn
Instance.new("UICorner", dropKey).CornerRadius = UDim.new(0, 4)

-- ============================================
-- FUNCIONES DE ESTADO
-- ============================================
local function updateUI()
	if isCarrying then
		bottomBar.Visible = false
		carryPanel.Visible = true
	else
		bottomBar.Visible = true
		carryPanel.Visible = false
	end
end

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

-- Detectar si esta cargando un personaje
local function checkCarrying()
	local char = player.Character
	if char then
		local tool = char:FindFirstChild("Carrying")
		if tool then
			isCarrying = true
			updateUI()
			return
		end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local tool = bp:FindFirstChild("Carrying")
		if tool then
			isCarrying = true
			updateUI()
			return
		end
	end
	if isCarrying then
		isCarrying = false
		updateUI()
	end
end

-- Verificar periodicamente
task.spawn(function()
	while true do
		task.wait(0.5)
		checkCarrying()
	end
end)

-- ============================================
-- SISTEMA DE PELOTA
-- ============================================
local function equipBall()
	if ballEquipped then return end
	if isCarrying then return end
	local char = player.Character
	if not char then return end

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
	if isCarrying then return end
	if throwDebounce then return end
	throwDebounce = true

	local char = player.Character
	if not char then
		throwDebounce = false
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChild("Humanoid")
	if not root then
		throwDebounce = false
		return
	end

	-- Animacion de lanzar
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://90927250635352"
			local track = animator:LoadAnimation(anim)
			track:Play()
		end
	end

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

	local bounceForce = Instance.new("VectorForce")
	bounceForce.RelativeTo = Enum.ActuatorRelativeTo.World
	local attachment = Instance.new("Attachment")
	attachment.Parent = ball
	bounceForce.Attachment0 = attachment
	bounceForce.Force = Vector3.new(0, 0, 0)
	bounceForce.Parent = ball

	ball.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 1.0, 0.3, 1.0)

	local direction = (mouse.Hit.Position - ball.Position).Unit
	local launchSpeed = 100
	ball.AssemblyLinearVelocity = direction * launchSpeed + Vector3.new(0, 20, 0)

	-- Enviar posicion al servidor
	if ThrowBallEvent then
		ThrowBallEvent:FireServer(mouse.Hit.Position)
	end

	task.delay(5, function()
		if ball and ball.Parent then ball:Destroy() end
	end)

	task.wait(0.3)
	throwDebounce = false
end

-- ============================================
-- INPUTS
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.One then
		if isCarrying then return end
		if inputDebounce then return end
		inputDebounce = true
		if ballEquipped then
			unequipBall()
		else
			equipBall()
		end
		task.wait(0.3)
		inputDebounce = false

	elseif input.KeyCode == Enum.KeyCode.E then
		if isCarrying then
			-- Colocar personaje en pedestal
			if PlaceCharacterEvent then
				PlaceCharacterEvent:FireServer()
			end
		else
			-- Recoger cofre
			if PickupChestEvent then
				PickupChestEvent:FireServer()
			end
		end

	elseif input.KeyCode == Enum.KeyCode.G then
		if isCarrying then
			-- Soltar personaje
			if DropCharacterEvent then
				DropCharacterEvent:FireServer()
			end
		end
	end
end)

-- Click izquierdo para lanzar pelota
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if ballEquipped and not isCarrying then
			throwBall()
		end
	end
end)

-- Botones de la GUI
ballButton.MouseButton1Click:Connect(function()
	if isCarrying then return end
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

placeBtn.MouseButton1Click:Connect(function()
	if isCarrying and PlaceCharacterEvent then
		PlaceCharacterEvent:FireServer()
	end
end)

dropBtn.MouseButton1Click:Connect(function()
	if isCarrying and DropCharacterEvent then
		DropCharacterEvent:FireServer()
	end
end)

-- Al respawnear
player.CharacterAdded:Connect(function()
	ballEquipped = false
	inputDebounce = false
	throwDebounce = false
	isCarrying = false
	updateButton()
	updateUI()
end)

updateButton()
updateUI()
print("BallThrower cargado!")

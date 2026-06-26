-- ============================================
-- BallThrower (LocalScript) - StarterPlayerScripts
-- Presiona 1 para equipar/desequipar la pelota
-- Click izquierdo para lanzar
-- ============================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ballEquipped = false
local debounce = false
local throwDebounce = false

-- Crear la herramienta de pelota
local function createBall()
	local tool = Instance.new("Tool")
	tool.Name = "CrystalBall"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2, 2, 2)
	handle.Shape = Enum.PartType.Ball
	handle.Color = Color3.fromRGB(100, 200, 255)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

-- Equipar pelota
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

	local tool = createBall()
	tool.Parent = char
	ballEquipped = true
end

-- Desequipar pelota
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
end

-- Lanzar pelota
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

	-- Quitar la herramienta
	unequipBall()

	-- Crear pelota que vuela
	local ball = Instance.new("Part")
	ball.Name = "ThrownBall"
	ball.Size = Vector3.new(2, 2, 2)
	ball.Shape = Enum.PartType.Ball
	ball.Color = Color3.fromRGB(100, 200, 255)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.Position = root.Position + Vector3.new(0, 3, 0)
	ball.Parent = workspace

	-- Dirección del lanzamiento
	local direction = (mouse.Hit.Position - ball.Position).Unit
	local speed = 120
	local velocity = direction * speed

	-- Animar la pelota
	task.spawn(function()
		local startPos = ball.Position
		local distance = 0
		local maxDistance = 200

		while distance < maxDistance do
			local dt = task.wait(0.01)
			local move = velocity * dt
			ball.Position = ball.Position + move
			distance = distance + move.Magnitude

			-- Efecto de brillo al moverse
			ball.Transparency = 0.1 + (distance / maxDistance) * 0.5
		end

		-- Desaparecer al llegar al límite
		ball:Destroy()
	end)

	task.wait(0.3)
	throwDebounce = false
end

-- Tecla 1 para equipar/desequipar
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.One then
		if debounce then return end
		debounce = true
		if ballEquipped then
			unequipBall()
		else
			equipBall()
		end
		task.wait(0.3)
		debounce = false
	end
end)

-- Click para lanzar
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if ballEquipped then
			throwBall()
		end
	end
end)

-- Al respawnear, reiniciar
player.CharacterAdded:Connect(function()
	ballEquipped = false
	debounce = false
	throwDebounce = false
end)

print("BallThrower cargado!")

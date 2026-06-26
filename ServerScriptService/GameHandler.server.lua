-- ============================================
-- GameHandler (Script) - ServerScriptService
-- Script principal del servidor
-- ============================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CrystalSpawner = require(ServerStorage.ServerModules.CrystalSpawner)
local BaseManager = require(ServerStorage.ServerModules.BaseManager)
local CharacterManager = require(ServerStorage.ServerModules.CharacterManager)
local ModelManager = require(ServerStorage.ServerModules.ModelManager)
local Events = require(game:GetService("ReplicatedStorage").RemoteEvents)

local playerData = {}
local droppedChars = {}

-- ============================================
-- CREAR HERRAMIENTA DE CARGA
-- ============================================
local function createCarryTool(player, model)
	local char = player.Character
	if not char then return end

	-- Eliminar herramienta anterior
	local old = char:FindFirstChild("Carrying")
	if old then old:Destroy() end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local oldBp = bp:FindFirstChild("Carrying")
		if oldBp then oldBp:Destroy() end
	end

	local carryTool = Instance.new("Tool")
	carryTool.Name = "Carrying"
	carryTool.RequiresHandle = true
	carryTool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.Anchored = false
	handle.CanCollide = false
	handle.Parent = carryTool

	if model then
		local modelClone = model:Clone()
		modelClone.Parent = carryTool

		pcall(function() modelClone:ScaleTo(2) end)

		local primaryPart = modelClone.PrimaryPart
		if not primaryPart then
			for _, desc in ipairs(modelClone:GetDescendants()) do
				if desc:IsA("BasePart") then
					primaryPart = desc
					break
				end
			end
		end

		for _, desc in ipairs(modelClone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanCollide = false
				desc.Massless = true
			end
		end

		if primaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = primaryPart
			weld.Parent = handle
		end
	end

	carryTool.Parent = char
end

-- ============================================
-- LANZAR PELOTA AL CRISTAL
-- ============================================
Events.ThrowBall.OnServerEvent:Connect(function(player, targetPos)
	-- No lanzar si esta cargando personaje
	local data = playerData[player.UserId]
	if data and data.carrying then return end

	local map = Workspace:FindFirstChild("Map")
	if not map then return end
	local zone = map:FindFirstChild("CrystalZone")
	if not zone then return end

	local nearest = nil
	local nearDist = 15

	for _, c in ipairs(zone:GetChildren()) do
		if c.Name == "Crystal" then
			local d = (c.Position - targetPos).Magnitude
			if d < nearDist then
				nearDist = d
				nearest = c
			end
		end
	end

	if not nearest then return end

	local hp = nearest:FindFirstChild("Health")
	if not hp then return end
	hp.Value = hp.Value - 1

	if hp.Value <= 0 then
		local rt = nearest:FindFirstChild("Rarity")
		local rarity = rt and rt.Value or "Blanco"
		local crystalColor = nearest.Color
		local pos = nearest.Position

		local crystalType = {color = crystalColor, name = rarity}
		nearest:Destroy()
		CrystalSpawner.spawnChest(pos, crystalType, player)
	end
end)

-- ============================================
-- RECOGER COFRE (E) - Da personaje aleatorio
-- ============================================
Events.PickupChest.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local data = playerData[player.UserId]
	if not data then return end
	if data.carrying then return end

	local nearest = nil
	local nearDist = 15

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Chest" then
			local owner = obj:FindFirstChild("Owner")
			if owner and owner.Value == player then
				local d = (obj.Position - root.Position).Magnitude
				if d < nearDist then
					nearDist = d
					nearest = obj
				end
			end
		end
	end

	if not nearest then return end

	local rt = nearest:FindFirstChild("Rarity")
	local rarity = rt and rt.Value or "Blanco"

	local model, folder = CharacterManager.getRandomModel(rarity)
	local charName = model and model.Name or (rarity .. " Personaje")

	local charIndex = #data.characters + 1
	table.insert(data.characters, {
		name = charName,
		rarity = rarity,
		level = 1,
		model = model,
		folder = folder,
		pedestal = nil
	})

	data.carrying = charIndex
	createCarryTool(player, model)

	local pos = nearest.Position - Vector3.new(0, 3, 0)
	nearest:Destroy()
	CrystalSpawner.respawn(pos)

	print(player.Name .. " obtuvo " .. charName .. " [" .. rarity .. "]")
end)

-- ============================================
-- COLOCAR PERSONAJE EN PEDESTAL (E)
-- ============================================
Events.PlaceCharacter.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data or not data.carrying then return end

	local charData = data.characters[data.carrying]
	if not charData then return end

	-- Buscar base del jugador
	local base = BaseManager.getBase(player.UserId)
	if not base then return end

	-- Buscar pedestal libre
	local pedestals = base:FindFirstChild("Pedestals")
	if not pedestals then return end

	local freePed = nil
	for _, ped in ipairs(pedestals:GetChildren()) do
		if ped:FindFirstChild("Platform") then
			local occupied = false
			for _, c in ipairs(data.characters) do
				if c.pedestal == ped then
					occupied = true
					break
				end
			end
			if not occupied then
				freePed = ped
				break
			end
		end
	end

	if not freePed then return end

	-- Colocar modelo en pedestal
	if charData.model then
		ModelManager.placeOnPedestal(charData.model, freePed)
	end
	charData.pedestal = freePed
	ModelManager.createLabels(freePed, charData.name, charData.rarity)

	-- Quitar herramienta de carga
	local pchar = player.Character
	if pchar then
		local tool = pchar:FindFirstChild("Carrying")
		if tool then tool:Destroy() end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local tool = bp:FindFirstChild("Carrying")
		if tool then tool:Destroy() end
	end

	data.carrying = nil
	print(player.Name .. " coloco " .. charData.name .. " en pedestal")
end)

-- ============================================
-- SOLTAR PERSONAJE (G) - Se deja en el suelo con timer
-- ============================================
Events.DropCharacter.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data or not data.carrying then return end

	local charData = data.characters[data.carrying]
	if not charData then return end

	-- Quitar herramienta de carga
	local pchar = player.Character
	if pchar then
		local tool = pchar:FindFirstChild("Carrying")
		if tool then tool:Destroy() end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		local tool = bp:FindFirstChild("Carrying")
		if tool then tool:Destroy() end
	end

	-- Crear modelo en el suelo
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local dropPos = root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
	local charIndex = data.carrying

	if charData.model then
		local dm = charData.model:Clone()
		dm.Parent = workspace
		pcall(function() dm:ScaleTo(4) end)
		pcall(function() dm:PivotTo(CFrame.new(dropPos)) end)
		for _, p in ipairs(dm:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end

		-- Timer de 30 segundos
		local tp = Instance.new("Part")
		tp.Name = "DropTimer"
		tp.Size = Vector3.new(1, 1, 1)
		tp.Transparency = 1
		tp.Anchored = true
		tp.CanCollide = false
		tp.Position = dropPos + Vector3.new(0, 4, 0)
		tp.Parent = workspace

		Instance.new("ObjectValue", tp).Name = "Owner"
		tp.Owner.Value = player
		Instance.new("IntValue", tp).Name = "CharIndex"
		tp.CharIndex.Value = charIndex
		Instance.new("ObjectValue", tp).Name = "DropModel"
		tp.DropModel.Value = dm

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(4, 0, 1, 0)
		bb.StudsOffset = Vector3.new(0, 1, 0)
		bb.AlwaysOnTop = true
		bb.Parent = tp

		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		tl.BackgroundTransparency = 0.3
		tl.TextColor3 = Color3.fromRGB(255, 100, 100)
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBold
		tl.Text = "30s"
		tl.Parent = bb

		local key = player.UserId .. "_" .. charIndex
		droppedChars[key] = tp

		task.spawn(function()
			for i = 29, 0, -1 do
				task.wait(1)
				if not tp or not tp.Parent then return end
				tl.Text = i .. "s"
			end
			if tp and tp.Parent then
				local d = tp:FindFirstChild("DropModel")
				if d and d.Value and d.Value.Parent then d.Value:Destroy() end
				tp:Destroy()
			end
			-- Eliminar personaje de los datos
			if data.characters[charIndex] then
				table.remove(data.characters, charIndex)
			end
			droppedChars[key] = nil
		end)
	end

	data.carrying = nil
	print(player.Name .. " solto " .. charData.name)
end)

-- ============================================
-- JUGADOR ENTRA / SALE
-- ============================================
Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " se unio al juego")
	playerData[player.UserId] = {characters = {}, carrying = nil}

	task.delay(3, function()
		local base = BaseManager.assign(player)
		if not base then
			task.delay(5, function()
				BaseManager.assign(player)
			end)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	print(player.Name .. " salio del juego")
	playerData[player.UserId] = nil
	BaseManager.release(player.UserId)
end)

-- ============================================
-- INICIO
-- ============================================
task.delay(3, function()
	CrystalSpawner.spawnAll()
end)

print("=== GameHandler iniciado correctamente ===")

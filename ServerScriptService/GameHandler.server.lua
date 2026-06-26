-- ============================================
-- GameHandler (Script) - ServerScriptService
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
local PLACE_DISTANCE = 12

-- ============================================
-- CREAR HERRAMIENTA DE CARGA
-- ============================================
local function createCarryTool(player, model)
	local char = player.Character
	if not char then return end

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
	handle.Massless = true
	handle.Position = Vector3.new(0, 0, 0)
	handle.Parent = carryTool

	carryTool.Grip = CFrame.new(0, -1.5, 1.5)

	if model then
		local modelClone = model:Clone()

		for _, desc in ipairs(modelClone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanCollide = false
				desc.Massless = true
			end
		end

		modelClone.Parent = carryTool

		local parts = {}
		for _, desc in ipairs(modelClone:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(parts, desc)
			end
		end

		if #parts > 0 then
			local sumX, sumZ = 0, 0
			local lowestY = math.huge
			for _, part in ipairs(parts) do
				sumX = sumX + part.Position.X
				sumZ = sumZ + part.Position.Z
				local bottomY = part.Position.Y - part.Size.Y / 2
				if bottomY < lowestY then
					lowestY = bottomY
				end
			end
			local centerX = sumX / #parts
			local centerZ = sumZ / #parts

			local offsetX = 0 - centerX
			local offsetY = 0 - lowestY
			local offsetZ = 0 - centerZ

			for _, part in ipairs(parts) do
				part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
			end
		end

		for _, desc in ipairs(modelClone:GetDescendants()) do
			if desc:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = desc
				weld.Parent = handle
			end
		end
	end

	carryTool.Parent = char
end

-- ============================================
-- MOSTRAR E EN PEDESTALES VACIOS DE UNA BASE
-- ============================================
local function showEmptyLabels(base)
	local pedestals = base:FindFirstChild("Pedestals")
	if not pedestals then return end
	for _, ped in ipairs(pedestals:GetChildren()) do
		ModelManager.showEmptyLabel(ped)
	end
end

-- ============================================
-- LANZAR PELOTA AL CRISTAL (1 golpe = roto)
-- ============================================
Events.ThrowBall.OnServerEvent:Connect(function(player, targetPos)
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

	-- Cristal se rompe de un golpe
	local rt = nearest:FindFirstChild("Rarity")
	local rarity = rt and rt.Value or "Blanco"
	local crystalColor = nearest.Color
	local pos = nearest.Position
	local crystalType = {color = crystalColor, name = rarity}
	nearest:Destroy()
	CrystalSpawner.spawnChest(pos, crystalType, player)
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
-- RECOGER PERSONAJE SOLTADO DEL SUELO (E)
-- ============================================
Events.PickupDropped.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local data = playerData[player.UserId]
	if not data then return end
	if data.carrying then return end

	-- Buscar DropTimer mas cercano que pertenezca a este jugador
	local nearest = nil
	local nearDist = 15

	for key, tp in pairs(droppedChars) do
		if tp and tp.Parent then
			local owner = tp:FindFirstChild("Owner")
			if owner and owner.Value == player then
				local d = (tp.Position - root.Position).Magnitude
				if d < nearDist then
					nearDist = d
					nearest = tp
				end
			end
		end
	end

	if not nearest then return end

	-- Obtener datos del personaje soltado
	local charIndexObj = nearest:FindFirstChild("CharIndex")
	local dropModelObj = nearest:FindFirstChild("DropModel")

	if not charIndexObj or not dropModelObj then return end

	local charIndex = charIndexObj.Value
	local dropModel = dropModelObj.Value

	-- Verificar que el personaje aun existe en los datos del jugador
	local charData = data.characters[charIndex]
	if not charData then
		-- El personaje ya fue eliminado (se acabo el timer)
		if dropModel and dropModel.Parent then dropModel:Destroy() end
		if nearest.Parent then nearest:Destroy() end
		return
	end

	-- Recoger: equipar en la mano
	data.carrying = charIndex
	createCarryTool(player, charData.model)

	-- Destruir modelo del suelo y timer
	if dropModel and dropModel.Parent then dropModel:Destroy() end
	if nearest.Parent then nearest:Destroy() end

	-- Limpiar de droppedChars
	local key = player.UserId .. "_" .. charIndex
	droppedChars[key] = nil

	print(player.Name .. " recogio " .. charData.name .. " del suelo")
end)

-- ============================================
-- COLOCAR PERSONAJE EN PEDESTAL CERCANO (E o 2)
-- ============================================
Events.PlaceCharacter.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data or not data.carrying then return end

	local charData = data.characters[data.carrying]
	if not charData then return end

	local pchar = player.Character
	if not pchar then return end
	local root = pchar:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local base = BaseManager.getBase(player.UserId)
	if not base then return end

	local pedestals = base:FindFirstChild("Pedestals")
	if not pedestals then return end

	local nearestFree = nil
	local nearestDist = PLACE_DISTANCE

	for _, ped in ipairs(pedestals:GetChildren()) do
		local platform = ped:FindFirstChild("Platform")
		if platform then
			local occupied = false
			for _, c in ipairs(data.characters) do
				if c.pedestal == ped then
					occupied = true
					break
				end
			end
			if not occupied then
				local d = (platform.Position - root.Position).Magnitude
				if d < nearestDist then
					nearestDist = d
					nearestFree = ped
				end
			end
		end
	end

	if not nearestFree then return end

	if charData.model then
		ModelManager.placeOnPedestal(charData.model, nearestFree)
	end
	charData.pedestal = nearestFree
	ModelManager.createLabels(nearestFree, charData.name, charData.rarity)

	local char = player.Character
	if char then
		local tool = char:FindFirstChild("Carrying")
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
-- RECOGER PERSONAJE DE PEDESTAL (E)
-- ============================================
Events.RemoveFromPedestal.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data then return end
	if data.carrying then return end

	local pchar = player.Character
	if not pchar then return end
	local root = pchar:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local base = BaseManager.getBase(player.UserId)
	if not base then return end

	local pedestals = base:FindFirstChild("Pedestals")
	if not pedestals then return end

	local nearestPed = nil
	local nearDist = PLACE_DISTANCE
	local nearCharIdx = nil

	for _, ped in ipairs(pedestals:GetChildren()) do
		local platform = ped:FindFirstChild("Platform")
		if platform then
			local d = (platform.Position - root.Position).Magnitude
			if d < nearDist then
				for i, c in ipairs(data.characters) do
					if c.pedestal == ped then
						nearestPed = ped
						nearDist = d
						nearCharIdx = i
						break
					end
				end
			end
		end
	end

	if not nearestPed or not nearCharIdx then return end

	local charData = data.characters[nearCharIdx]

	ModelManager.clearPedestal(nearestPed)
	charData.pedestal = nil

	data.carrying = nearCharIdx
	createCarryTool(player, charData.model)

	print(player.Name .. " recogio " .. charData.name .. " del pedestal")
end)

-- ============================================
-- SOLTAR PERSONAJE (G)
-- ============================================
Events.DropCharacter.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data or not data.carrying then return end

	local charData = data.characters[data.carrying]
	if not charData then return end

	-- Quitar herramienta
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

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local dropPos = root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
	local charIndex = data.carrying

	if charData.model then
		local dm = charData.model:Clone()

		for _, p in ipairs(dm:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end

		dm.Parent = workspace
		ModelManager.moveModelTo(dm, dropPos)

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

		-- Etiqueta bonita del personaje soltado
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(4, 0, 1.5, 0)
		bb.StudsOffset = Vector3.new(0, 1, 0)
		bb.AlwaysOnTop = true
		bb.Parent = tp

		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		bg.BackgroundTransparency = 0.4
		bg.BorderSizePixel = 0
		bg.Parent = bb
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

		local bgStroke = Instance.new("UIStroke")
		bgStroke.Color = Color3.fromRGB(255, 100, 100)
		bgStroke.Thickness = 1.5
		bgStroke.Transparency = 0.3
		bgStroke.Parent = bg

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = charData.name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = bg

		local tl = Instance.new("TextLabel")
		tl.Name = "TimerLabel"
		tl.Size = UDim2.new(1, 0, 0.5, 0)
		tl.Position = UDim2.new(0, 0, 0.5, 0)
		tl.BackgroundTransparency = 1
		tl.Text = "30s"
		tl.TextColor3 = Color3.fromRGB(255, 100, 100)
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBold
		tl.Parent = bg

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
		if base then
			showEmptyLabels(base)
		else
			task.delay(5, function()
				base = BaseManager.assign(player)
				if base then showEmptyLabels(base) end
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

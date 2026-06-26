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

-- Color verde dolar
local MONEY_COLOR = Color3.fromRGB(76, 175, 80)

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
-- MOSTRAR E EN PEDESTALES VACIOS
-- ============================================
local function showEmptyLabels(base)
	local pedestals = base:FindFirstChild("Pedestals")
	if not pedestals then return end
	for _, ped in ipairs(pedestals:GetChildren()) do
		ModelManager.showEmptyLabel(ped)
	end
end

-- ============================================
-- DAR DINERO AL JUGADOR
-- ============================================
local function addMoney(player, amount)
	local data = playerData[player.UserId]
	if not data then return end

	data.money = (data.money or 0) + amount

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			coins.Value = data.money
		end
	end

	Events.MoneyUpdate:FireClient(player, data.money)
end

-- ============================================
-- Configurar eventos de un MoneyPile (Touched + Click mejorar)
-- Se llama solo cuando se crea el moneyPile, NO usa DescendantAdded
-- ============================================
local function setupMoneyPileEvents(pedestal, moneyPile, charIdx)
	if not moneyPile then return end

	-- Evento de mejora por click
	local upgradeEvent = moneyPile:WaitForChild("UpgradeEvent", 5)
	if upgradeEvent then
		upgradeEvent.Event:Connect(function(player)
			local data = playerData[player.UserId]
			if not data then return end

			local charData = data.characters[charIdx]
			if not charData then return end
			if charData.pedestal ~= pedestal then return end

			local currentLevel = charData.level or 1
			if currentLevel >= 100 then return end

			local cost = ModelManager.getUpgradeCost(currentLevel)
			if (data.money or 0) < cost then return end

			-- Pagar y subir nivel
			data.money = data.money - cost
			charData.level = currentLevel + 1

			-- Actualizar leaderstats
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local coins = leaderstats:FindFirstChild("Coins")
				if coins then coins.Value = data.money end
			end
			Events.MoneyUpdate:FireClient(player, data.money)

			-- Actualizar labels
			ModelManager.createLabels(pedestal, charData.name, charData.rarity, charData.level)
			ModelManager.updateMoneyPileUI(pedestal, charData.rarity, charData.level)

			print(player.Name .. " mejoro " .. charData.name .. " a Lv." .. charData.level .. " (-$" .. cost .. ")")
		end)
	end

	-- Evento de recoleccion por Touched
	local collectEvent = moneyPile:WaitForChild("CollectEvent", 5)
	if collectEvent then
		collectEvent.Event:Connect(function(player, amount)
			addMoney(player, amount)
			print(player.Name .. " recogio $" .. amount)
		end)
	end
end

-- ============================================
-- LANZAR PELOTA AL CRISTAL
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

	local rt = nearest:FindFirstChild("Rarity")
	local rarity = rt and rt.Value or "Blanco"
	local crystalColor = nearest.Color
	local pos = nearest.Position
	local crystalType = {color = crystalColor, name = rarity}
	nearest:Destroy()
	CrystalSpawner.spawnChest(pos, crystalType, player)
end)

-- ============================================
-- RECOGER COFRE
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
-- RECOGER PERSONAJE SOLTADO
-- ============================================
Events.PickupDropped.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local data = playerData[player.UserId]
	if not data then return end
	if data.carrying then return end

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

	local charIndexObj = nearest:FindFirstChild("CharIndex")
	local dropModelObj = nearest:FindFirstChild("DropModel")
	if not charIndexObj or not dropModelObj then return end

	local charIndex = charIndexObj.Value
	local dropModel = dropModelObj.Value

	local charData = data.characters[charIndex]
	if not charData then
		if dropModel and dropModel.Parent then dropModel:Destroy() end
		if nearest.Parent then nearest:Destroy() end
		return
	end

	data.carrying = charIndex
	createCarryTool(player, charData.model)

	if dropModel and dropModel.Parent then dropModel:Destroy() end
	if nearest.Parent then nearest:Destroy() end

	local key = player.UserId .. "_" .. charIndex
	droppedChars[key] = nil

	print(player.Name .. " recogio " .. charData.name .. " del suelo")
end)

-- ============================================
-- COLOCAR PERSONAJE EN PEDESTAL
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

	local charIdx = data.carrying

	if charData.model then
		ModelManager.placeOnPedestal(charData.model, nearestFree)
	end
	charData.pedestal = nearestFree
	ModelManager.createLabels(nearestFree, charData.name, charData.rarity, charData.level)

	-- Crear pila de dinero con eventos
	local moneyPile = ModelManager.createMoneyPile(nearestFree, charData.rarity, charData.level)
	setupMoneyPileEvents(nearestFree, moneyPile, charIdx)

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
	print(player.Name .. " coloco " .. charData.name .. " Lv." .. (charData.level or 1) .. " en pedestal")
end)

-- ============================================
-- RECOGER PERSONAJE DE PEDESTAL
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

	-- Recolectar dinero pendiente
	local moneyPile = nearestPed:FindFirstChild("MoneyPile")
	if moneyPile then
		local mv = moneyPile:FindFirstChild("MoneyValue")
		if mv and mv.Value > 0 then
			addMoney(player, mv.Value)
		end
	end

	ModelManager.clearPedestal(nearestPed)
	ModelManager.removeMoneyPile(nearestPed)
	charData.pedestal = nil

	data.carrying = nearCharIdx
	createCarryTool(player, charData.model)

	print(player.Name .. " recogio " .. charData.name .. " del pedestal")
end)

-- ============================================
-- MEJORAR PERSONAJE (evento alternativo desde servidor)
-- ============================================
Events.UpgradeCharacter.OnServerEvent:Connect(function(player)
	-- Este evento es backup en caso de que el ClickDetector no funcione
	-- Buscar pedestal mas cercano con MoneyPile
	local data = playerData[player.UserId]
	if not data then return end

	local pchar = player.Character
	if not pchar then return end
	local root = pchar:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local base = BaseManager.getBase(player.UserId)
	if not base then return end

	local pedestals = base:FindFirstChild("Pedestals")
	if not pedestals then return end

	-- Buscar pedestal con MoneyPile clickeable mas cercano
	for i, charData in ipairs(data.characters) do
		if charData.pedestal then
			local mp = charData.pedestal:FindFirstChild("MoneyPile")
			if mp then
				local platform = charData.pedestal:FindFirstChild("Platform")
				if platform then
					local d = (platform.Position - root.Position).Magnitude
					if d < 15 then
						local currentLevel = charData.level or 1
						if currentLevel >= 100 then return end

						local cost = ModelManager.getUpgradeCost(currentLevel)
						if (data.money or 0) < cost then return end

						data.money = data.money - cost
						charData.level = currentLevel + 1

						local leaderstats = player:FindFirstChild("leaderstats")
						if leaderstats then
							local coins = leaderstats:FindFirstChild("Coins")
							if coins then coins.Value = data.money end
						end
						Events.MoneyUpdate:FireClient(player, data.money)

						ModelManager.createLabels(charData.pedestal, charData.name, charData.rarity, charData.level)
						ModelManager.updateMoneyPileUI(charData.pedestal, charData.rarity, charData.level)

						print(player.Name .. " mejoro " .. charData.name .. " a Lv." .. charData.level .. " (-$" .. cost .. ")")
						return
					end
				end
			end
		end
	end
end)

-- ============================================
-- SOLTAR PERSONAJE (G)
-- ============================================
Events.DropCharacter.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data or not data.carrying then return end

	local charData = data.characters[data.carrying]
	if not charData then return end

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
		nameLabel.Text = charData.name .. " Lv." .. (charData.level or 1)
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
-- SISTEMA DE DINERO - Timer cada 2 segundos
-- ============================================
task.spawn(function()
	while true do
		task.wait(2)
		for userId, data in pairs(playerData) do
			if data.characters then
				for _, charData in ipairs(data.characters) do
					if charData.pedestal then
						local moneyPile = charData.pedestal:FindFirstChild("MoneyPile")
						if moneyPile and moneyPile.Parent then
							local mv = moneyPile:FindFirstChild("MoneyValue")
							local rarityTag = moneyPile:FindFirstChild("Rarity")
							local levelTag = moneyPile:FindFirstChild("CharLevel")
							if mv and rarityTag then
								local lvl = levelTag and levelTag.Value or 1
								local rate = ModelManager.getMoneyRate(rarityTag.Value, lvl)
								mv.Value = mv.Value + rate
								local bb = moneyPile:FindFirstChild("MoneyGui")
								if bb then
									local bg = bb:FindFirstChild("Frame")
									if bg then
										local lbl = bg:FindFirstChild("MoneyLabel")
										if lbl then
											lbl.Text = "$" .. mv.Value
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end)

-- ============================================
-- JUGADOR ENTRA / SALE
-- ============================================
Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " se unio al juego")
	playerData[player.UserId] = {characters = {}, carrying = nil, money = 0}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	task.delay(1, function()
		Events.MoneyUpdate:FireClient(player, 0)
	end)

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

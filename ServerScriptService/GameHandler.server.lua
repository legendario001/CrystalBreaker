-- ============================================
-- GameHandler (Script) - ServerScriptService
-- FIX: table.remove → nil assignment (evita corrupcion de indices)
-- FIX: PlayerRemoving limpia TODO (droppedChars, pedestales, carry tools)
-- FIX: pcall en todos los event handlers + verificacion de instancias destruidas
-- FIX: FireClient con verificacion de jugador conectado
-- ============================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local CrystalSpawner = require(ServerStorage.ServerModules.CrystalSpawner)
local BaseManager = require(ServerStorage.ServerModules.BaseManager)
local CharacterManager = require(ServerStorage.ServerModules.CharacterManager)
local ModelManager = require(ServerStorage.ServerModules.ModelManager)
local Events = require(game:GetService("ReplicatedStorage").RemoteEvents)

local playerData = {}
local droppedChars = {}
local PLACE_DISTANCE = 12

-- ============================================
-- Helper: verificar si una instancia es valida (no destruida)
-- ============================================
local function isValid(instance)
	return instance ~= nil and instance.Parent ~= nil
end

-- ============================================
-- Helper: verificar si un jugador sigue conectado
-- ============================================
local function isPlayerValid(player)
	return player ~= nil and player.Parent ~= nil
end

-- ============================================
-- Helper: encontrar siguiente indice disponible en tabla de personajes
-- (Evita sobreescribir indices existentes cuando hay huecos nil)
-- ============================================
local function getNextCharIndex(characters)
	local idx = 1
	while characters[idx] do
		idx = idx + 1
	end
	return idx
end

-- ============================================
-- Helper: iterar personajes saltando nil (sparse array)
-- ============================================
local function iterateCharacters(characters)
	local results = {}
	for i, c in pairs(characters) do
		if c then
			table.insert(results, {index = i, data = c})
		end
	end
	return results
end

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
			for _, part in ipairs(parts) do
				part.Position = part.Position + Vector3.new(0 - centerX, 0 - lowestY, 0 - centerZ)
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
-- FIX: Verificar que el jugador siga conectado antes de FireClient
-- ============================================
local function addMoney(player, amount)
	if not isPlayerValid(player) then return end
	local data = playerData[player.UserId]
	if not data then return end
	data.money = (data.money or 0) + amount

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then coins.Value = data.money end
	end

	if isPlayerValid(player) then
		Events.MoneyUpdate:FireClient(player, data.money)
	end
end

-- ============================================
-- Configurar eventos de MoneyPile (Touched)
-- ============================================
local function setupMoneyPileEvents(moneyPile)
	if not moneyPile then return end
	local collectEvent = moneyPile:WaitForChild("CollectEvent", 5)
	if collectEvent then
		collectEvent.Event:Connect(function(player, amount)
			addMoney(player, amount)
		end)
	end
end

-- ============================================
-- Configurar eventos de UpgradeButton (Click)
-- ============================================
local function setupUpgradeButtonEvents(pedestal, upgradeBtn, charIdx)
	if not upgradeBtn then return end
	local upgradeEvent = upgradeBtn:WaitForChild("UpgradeEvent", 5)
	if not upgradeEvent then return end

	upgradeEvent.Event:Connect(function(player)
		local ok, err = pcall(function()
			if not isPlayerValid(player) then return end
			local data = playerData[player.UserId]
			if not data then return end

			local charData = data.characters[charIdx]
			if not charData then return end

			-- Verificar que el pedestal sigue siendo valido
			if not isValid(charData.pedestal) then
				charData.pedestal = nil
				return
			end
			if charData.pedestal ~= pedestal then return end
			if not isValid(pedestal) then return end

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
			if isPlayerValid(player) then
				Events.MoneyUpdate:FireClient(player, data.money)
			end

			-- Actualizar labels y botones
			if isValid(pedestal) then
				ModelManager.createLabels(pedestal, charData.name, charData.rarity, charData.level)
				ModelManager.updateUpgradeButtonUI(pedestal, charData.rarity, charData.level)

				-- Actualizar nivel en MoneyPile para que la generacion suba
				local moneyPile = pedestal:FindFirstChild("MoneyPile")
				if moneyPile then
					local lt = moneyPile:FindFirstChild("CharLevel")
					if lt then lt.Value = charData.level end
				end
			end

			print(player.Name .. " mejoro " .. charData.name .. " a Lv." .. charData.level .. " (-$" .. cost .. ")")
		end)
		if not ok then
			warn("Error en upgrade: " .. tostring(err))
		end
	end)
end

-- ============================================
-- LANZAR PELOTA AL CRISTAL
-- ============================================
Events.ThrowBall.OnServerEvent:Connect(function(player, targetPos)
	local ok, err = pcall(function()
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
		local crystalType = {color = nearest.Color, name = rarity}
		local pos = nearest.Position
		nearest:Destroy()
		CrystalSpawner.spawnChest(pos, crystalType, player)
	end)
	if not ok then
		warn("Error en ThrowBall: " .. tostring(err))
	end
end)

-- ============================================
-- RECOGER COFRE
-- ============================================
Events.PickupChest.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
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

		-- FIX: Usar getNextCharIndex en vez de #data.characters + 1
		local charIndex = getNextCharIndex(data.characters)
		data.characters[charIndex] = {
			name = charName,
			rarity = rarity,
			level = 1,
			model = model,
			folder = folder,
			pedestal = nil
		}

		data.carrying = charIndex
		createCarryTool(player, model)

		local pos = nearest.Position - Vector3.new(0, 3, 0)
		nearest:Destroy()
		CrystalSpawner.respawn(pos)
		print(player.Name .. " obtuvo " .. charName .. " [" .. rarity .. "]")
	end)
	if not ok then
		warn("Error en PickupChest: " .. tostring(err))
	end
end)

-- ============================================
-- RECOGER PERSONAJE SOLTADO
-- FIX: Verificar que charIndex sigue siendo valido
-- ============================================
Events.PickupDropped.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
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

		-- FIX: Verificar que el character en ese indice sigue existiendo
		local charData = data.characters[charIndex]
		if not charData then
			if dropModel and dropModel.Parent then dropModel:Destroy() end
			if nearest.Parent then nearest:Destroy() end
			droppedChars[player.UserId .. "_" .. charIndex] = nil
			return
		end

		data.carrying = charIndex
		createCarryTool(player, charData.model)

		if dropModel and dropModel.Parent then dropModel:Destroy() end
		if nearest.Parent then nearest:Destroy() end
		droppedChars[player.UserId .. "_" .. charIndex] = nil
		print(player.Name .. " recogio " .. charData.name .. " del suelo")
	end)
	if not ok then
		warn("Error en PickupDropped: " .. tostring(err))
	end
end)

-- ============================================
-- COLOCAR PERSONAJE EN PEDESTAL
-- ============================================
Events.PlaceCharacter.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
		local data = playerData[player.UserId]
		if not data or not data.carrying then return end

		local charData = data.characters[data.carrying]
		if not charData then return end
		if charData.pedestal then return end

		-- QUITAR HERRAMIENTA INMEDIATAMENTE
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
				local hasModel = false
				for _, child in ipairs(ped:GetChildren()) do
					if child:IsA("Model") then
						hasModel = true
						break
					end
				end
				if hasModel then continue end

				local occupied = false
				for _, entry in ipairs(iterateCharacters(data.characters)) do
					if entry.data.pedestal == ped then
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

		local moneyPile = ModelManager.createMoneyPile(nearestFree, charData.rarity, charData.level)
		setupMoneyPileEvents(moneyPile)

		local upgradeBtn = ModelManager.createUpgradeButton(nearestFree, charData.rarity, charData.level)
		setupUpgradeButtonEvents(nearestFree, upgradeBtn, charIdx)

		data.carrying = nil
		print(player.Name .. " coloco " .. charData.name .. " Lv." .. (charData.level or 1))
	end)
	if not ok then
		warn("Error en PlaceCharacter: " .. tostring(err))
	end
end)

-- ============================================
-- RECOGER PERSONAJE DE PEDESTAL
-- FIX: Usar iterateCharacters en vez de ipairs (para sparse array)
-- ============================================
Events.RemoveFromPedestal.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
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

		for _, entry in ipairs(iterateCharacters(data.characters)) do
			local charData = entry.data
			if charData.pedestal and isValid(charData.pedestal) then
				local platform = charData.pedestal:FindFirstChild("Platform")
				if platform then
					local d = (platform.Position - root.Position).Magnitude
					if d < nearDist then
						nearestPed = charData.pedestal
						nearDist = d
						nearCharIdx = entry.index
					end
				end
			end
		end

		if not nearestPed or not nearCharIdx then return end
		local charData = data.characters[nearCharIdx]
		if not charData then return end

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
		ModelManager.removeUpgradeButton(nearestPed)
		charData.pedestal = nil

		data.carrying = nearCharIdx
		createCarryTool(player, charData.model)
		print(player.Name .. " recogio " .. charData.name .. " del pedestal")
	end)
	if not ok then
		warn("Error en RemoveFromPedestal: " .. tostring(err))
	end
end)

-- ============================================
-- MEJORAR PERSONAJE (tecla F)
-- FIX: Usar iterateCharacters + verificar instancias destruidas
-- ============================================
Events.UpgradeCharacter.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
		if not isPlayerValid(player) then return end
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

		for _, entry in ipairs(iterateCharacters(data.characters)) do
			local charData = entry.data
			if charData.pedestal then
				if not isValid(charData.pedestal) then
					charData.pedestal = nil
					continue
				end

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
						if isPlayerValid(player) then
							Events.MoneyUpdate:FireClient(player, data.money)
						end

						if isValid(charData.pedestal) then
							ModelManager.createLabels(charData.pedestal, charData.name, charData.rarity, charData.level)
							ModelManager.updateUpgradeButtonUI(charData.pedestal, charData.rarity, charData.level)

							local mp = charData.pedestal:FindFirstChild("MoneyPile")
							if mp then
								local lt = mp:FindFirstChild("CharLevel")
								if lt then lt.Value = charData.level end
							end
						end

						print(player.Name .. " mejoro " .. charData.name .. " a Lv." .. charData.level .. " (-$" .. cost .. ")")
						return
					end
				end
			end
		end
	end)
	if not ok then
		warn("Error en UpgradeCharacter: " .. tostring(err))
	end
end)

-- ============================================
-- SOLTAR PERSONAJE (G)
-- FIX: No usar table.remove → set nil en su lugar
-- FIX: Usar Debris para cleanup del DropTimer
-- ============================================
Events.DropCharacter.OnServerEvent:Connect(function(player)
	local ok, err = pcall(function()
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
		local userId = player.UserId

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
			-- Auto-destruir el modelo clonado tras 35s (seguridad)
			Debris:AddItem(dm, 35)

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

			local key = userId .. "_" .. charIndex
			droppedChars[key] = tp

			task.spawn(function()
				for i = 29, 0, -1 do
					task.wait(1)
					if not tp or not tp.Parent then return end
					-- FIX: Verificar que el jugador siga conectado
					local currentData = playerData[userId]
					if not currentData then
						-- Jugador se fue, limpiar todo
						if dm and dm.Parent then dm:Destroy() end
						if tp and tp.Parent then tp:Destroy() end
						droppedChars[key] = nil
						return
					end
					tl.Text = i .. "s"
				end
				if tp and tp.Parent then
					local d = tp:FindFirstChild("DropModel")
					if d and d.Value and d.Value.Parent then d.Value:Destroy() end
					tp:Destroy()
				end
				-- FIX: set nil en vez de table.remove (no corrompe indices)
				local currentData = playerData[userId]
				if currentData and currentData.characters then
					currentData.characters[charIndex] = nil
				end
				droppedChars[key] = nil
			end)
		end

		data.carrying = nil
		print(player.Name .. " solto " .. charData.name)
	end)
	if not ok then
		warn("Error en DropCharacter: " .. tostring(err))
	end
end)

-- ============================================
-- SISTEMA DE DINERO - Timer cada 2 segundos
-- FIX: pcall + verificacion de instancias destruidas
-- FIX: Verificar jugador conectado antes de actualizar UI
-- ============================================
task.spawn(function()
	while true do
		task.wait(2)
		local ok, err = pcall(function()
			for userId, data in pairs(playerData) do
				if data.characters then
					for _, entry in ipairs(iterateCharacters(data.characters)) do
						local charData = entry.data
						if charData.pedestal then
							if not isValid(charData.pedestal) then
								charData.pedestal = nil
								continue
							end

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
											if lbl then lbl.Text = "$" .. mv.Value end
										end
									end
								end
							end
						end
					end
				end
			end
		end)
		if not ok then
			warn("Error en money timer: " .. tostring(err))
		end
	end
end)

-- ============================================
-- JUGADOR ENTRA / SALE
-- FIX: PlayerRemoving limpia TODO (droppedChars, pedestales, carry tools)
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
		if isPlayerValid(player) then
			Events.MoneyUpdate:FireClient(player, 0)
		end
	end)

	task.delay(3, function()
		if not isPlayerValid(player) then return end
		local base = BaseManager.assign(player)
		if base then
			showEmptyLabels(base)
		else
			task.delay(5, function()
				if not isPlayerValid(player) then return end
				base = BaseManager.assign(player)
				if base then showEmptyLabels(base) end
			end)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	print(player.Name .. " salio del juego")
	local userId = player.UserId
	local data = playerData[userId]

	if data then
		-- Limpiar carry tool
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

		-- Limpiar todos los pedestales del jugador
		for _, entry in ipairs(iterateCharacters(data.characters)) do
			local charData = entry.data
			if charData.pedestal and isValid(charData.pedestal) then
				-- Recolectar dinero pendiente
				local moneyPile = charData.pedestal:FindFirstChild("MoneyPile")
				if moneyPile then
					local mv = moneyPile:FindFirstChild("MoneyValue")
					if mv and mv.Value > 0 then
						-- El dinero se pierde al salir, pero limpiamos la instancia
					end
				end
				ModelManager.clearPedestal(charData.pedestal)
				ModelManager.removeMoneyPile(charData.pedestal)
				ModelManager.removeUpgradeButton(charData.pedestal)
			end
		end

		-- Limpiar personajes soltados del jugador
		for key, tp in pairs(droppedChars) do
			if tp and tp.Parent then
				local owner = tp:FindFirstChild("Owner")
				if owner and owner.Value == player then
					local dropModelObj = tp:FindFirstChild("DropModel")
					if dropModelObj and dropModelObj.Value and dropModelObj.Value.Parent then
						dropModelObj.Value:Destroy()
					end
					tp:Destroy()
					droppedChars[key] = nil
				end
			else
				-- Entrada stale, limpiar
				droppedChars[key] = nil
			end
		end
	end

	playerData[userId] = nil
	BaseManager.release(userId)
end)

-- ============================================
-- INICIO
-- ============================================
task.delay(3, function()
	CrystalSpawner.spawnAll()
end)

print("=== GameHandler iniciado correctamente ===")

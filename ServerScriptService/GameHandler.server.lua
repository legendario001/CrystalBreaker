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
local Events = require(game:GetService("ReplicatedStorage").RemoteEvents)

-- Datos de los jugadores
local playerData = {}

-- ============================================
-- LANZAR PELOTA AL CRISTAL
-- ============================================
Events.ThrowBall.OnServerEvent:Connect(function(player, targetPos)
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

	-- Si el cristal se rompe
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

	-- No recoger si ya esta cargando un personaje
	local data = playerData[player.UserId]
	if data and data.carrying then return end

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

	-- Obtener modelo aleatorio de la carpeta correspondiente
	local model, folder = CharacterManager.getRandomModel(rarity)
	local charName = model and model.Name or (rarity .. " Personaje")

	-- Guardar personaje en los datos del jugador
	if not playerData[player.UserId] then
		playerData[player.UserId] = {characters = {}, carrying = nil}
	end

	local charIndex = #playerData[player.UserId].characters + 1
	table.insert(playerData[player.UserId].characters, {
		name = charName,
		rarity = rarity,
		level = 1,
		model = model,
		folder = folder,
		pedestal = nil
	})

	playerData[player.UserId].carrying = charIndex

	-- Cargar herramienta que lleva el modelo
	if model and char then
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

		carryTool.Parent = char
	end

	-- Destruir cofre y regenerar cristal
	local pos = nearest.Position - Vector3.new(0, 3, 0)
	nearest:Destroy()
	CrystalSpawner.respawn(pos)

	print(player.Name .. " obtuvo " .. charName .. " [" .. rarity .. "]")
end)

-- ============================================
-- JUGADOR ENTRA / SALE
-- ============================================
Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " se unio al juego")

	playerData[player.UserId] = {characters = {}, carrying = nil}

	-- Asignar base despues de un momento
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

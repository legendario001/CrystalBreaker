-- ============================================
-- SaveManager (ModuleScript) - ServerStorage/ServerModules
-- Maneja el guardado y carga de datos del jugador con DataStore
-- Guarda: money, baseLevel, characters, blockInventory, placedBlocks
-- ============================================

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local SaveManager = {}

-- DataStore principal (un solo store por jugador, clave = userId)
local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

-- Cache de datos cargados (para no leer del DataStore en cada save)
local loadedData = {} -- [userId] = data table

-- ============================================
-- Serializacion: convertir Instancias a datos guardables
-- ============================================

-- Serializar un personaje (charData) a formato guardable
local function serializeCharacter(charData)
	if not charData then return nil end
	local serialized = {
		name = charData.name,
		rarity = charData.rarity,
		level = charData.level or 1,
		fusionLevel = charData.fusionLevel or 0,
		pedestalName = nil,
		pedestalFloor = nil,
	}
	-- Guardar info del pedestal si el personaje esta colocado
	if charData.pedestal and charData.pedestal.Parent then
		serialized.pedestalName = charData.pedestal.Name
		-- Determinar el piso del pedestal
		local current = charData.pedestal.Parent
		local floor = 1
		while current do
			if string.sub(current.Name, 1, 5) == "Floor" then
				local numStr = string.sub(current.Name, 6)
				local num = tonumber(numStr)
				if num then floor = num break end
			end
			current = current.Parent
		end
		serialized.pedestalFloor = floor
	end
	return serialized
end

-- Serializar la lista de personajes
local function serializeCharacters(characters)
	local serialized = {}
	for idx, charData in pairs(characters) do
		if charData and charData.name then
			serialized[tostring(idx)] = serializeCharacter(charData)
		end
	end
	return serialized
end

-- Serializar bloques colocados (Part -> tabla con posicion y blockId)
local function serializePlacedBlocks(blocksFolder)
	if not blocksFolder then return {} end
	local serialized = {}
	for _, block in ipairs(blocksFolder:GetChildren()) do
		if block:IsA("BasePart") then
			local idTag = block:FindFirstChild("BlockId")
			if idTag then
				table.insert(serialized, {
					blockId = idTag.Value,
					px = block.Position.X,
					py = block.Position.Y,
					pz = block.Position.Z,
					rx = block.Orientation.X,
					ry = block.Orientation.Y,
					rz = block.Orientation.Z,
				})
			end
		end
	end
	return serialized
end

-- Serializar inventario de bloques
local function serializeBlockInventory(inventory)
	local serialized = {}
	for blockId, count in pairs(inventory) do
		if count > 0 then
			serialized[blockId] = count
		end
	end
	return serialized
end

-- ============================================
-- API: cargar y guardar
-- ============================================

-- Cargar datos del jugador desde DataStore
-- Devuelve: tabla de datos o nil si no hay datos guardados
function SaveManager.loadPlayerData(userId)
	if loadedData[userId] then
		return loadedData[userId]
	end

	local success, data = pcall(function()
		return playerStore:GetAsync("player_" .. userId)
	end)

	if not success then
		warn("[SaveManager] Error al cargar datos de userId " .. userId .. ": " .. tostring(data))
		return nil
	end

	if not data then
		-- No hay datos guardados (jugador nuevo)
		return nil
	end

	loadedData[userId] = data
	return data
end

-- Guardar datos del jugador en DataStore
-- Parametros:
--   userId, playerData (de GameHandler), baseLevel, blockInventory, blocksFolder
function SaveManager.savePlayerData(userId, playerData, baseLevel, blockInventory, blocksFolder)
	-- Construir la tabla de datos a guardar
	local dataToSave = {
		money = 0,
		baseLevel = baseLevel or 1,
		characters = {},
		blockInventory = {},
		placedBlocks = {},
		version = 1, -- version del formato de guardado
	}

	if playerData then
		dataToSave.money = playerData.money or 0
		if playerData.characters then
			dataToSave.characters = serializeCharacters(playerData.characters)
		end
	end

	if blockInventory then
		dataToSave.blockInventory = serializeBlockInventory(blockInventory)
	end

	if blocksFolder then
		dataToSave.placedBlocks = serializePlacedBlocks(blocksFolder)
	end

	-- Guardar en DataStore
	local success, err = pcall(function()
		playerStore:SetAsync("player_" .. userId, dataToSave)
	end)

	if not success then
		warn("[SaveManager] Error al guardar datos de userId " .. userId .. ": " .. tostring(err))
		return false
	end

	-- Actualizar cache
	loadedData[userId] = dataToSave
	return true
end

-- Limpiar cache al salir el jugador
function SaveManager.clearCache(userId)
	loadedData[userId] = nil
end

-- Guardar todos los jugadores activos (para auto-save)
-- Parametro: funcion que devuelve (playerData, baseLevel, blockInventory, blocksFolder) dado un player
function SaveManager.saveAllPlayers(getPlayerDataFunc)
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local playerData, baseLevel, blockInventory, blocksFolder = getPlayerDataFunc(player)
		if playerData then
			SaveManager.savePlayerData(player.UserId, playerData, baseLevel, blockInventory, blocksFolder)
			count = count + 1
		end
	end
	return count
end

return SaveManager

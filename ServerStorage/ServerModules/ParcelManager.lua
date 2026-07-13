-- ============================================
-- ParcelManager (ModuleScript) - ServerStorage/ServerModules
-- Asigna parcelas de construccion a jugadores segun su base
-- Base 1 -> Parcela 1, Base 2 -> Parcela 2, etc.
-- Libera parcela al salir
-- ============================================

local Workspace = game:GetService("Workspace")

local ParcelManager = {}

-- Mapa: nombre base -> nombre parcela correspondiente
local BASE_TO_PARCEL = {
	["Base1"] = "Parcela 1",
	["Base2"] = "Parcela 2",
	["Base3"] = "Parcela 3",
	["Base4"] = "Parcela 4",
	["Base5"] = "Parcela 5",
}

-- Estado interno
local assignedParcels = {} -- [parcelName] = userId
local playerParcels = {}   -- [userId] = parcel (Instance)

-- Tamaño de cada bloque (en studs) - para validacion de bounds
local BLOCK_SIZE = 4

-- Tamaño de la parcela (en studs) - para validacion de bounds
-- Las parcelas miden 36 (X) x 1 (Y) x 56 (Z)
-- Area de construccion: 9 bloques ancho x 14 largo x 9 alto
local PARCEL_SIZE_X = 36
local PARCEL_SIZE_Z = 56
local PARCEL_HEIGHT = 36 -- 9 bloques x 4 studs = 36 studs hacia arriba

-- Obtener la parcela como Instance por nombre
local function getParcelByName(parcelName)
	local parcelas = Workspace:FindFirstChild("Parcelas")
	if not parcelas then return nil end
	return parcelas:FindFirstChild(parcelName)
end

-- Obtener la parcela del jugador
function ParcelManager.getParcel(userId)
	return playerParcels[userId]
end

-- Asignar parcela segun el nombre de la base del jugador
function ParcelManager.assignByBaseName(player, baseName)
	if playerParcels[player.UserId] then
		return playerParcels[player.UserId]
	end

	local parcelName = BASE_TO_PARCEL[baseName]
	if not parcelName then
		warn("[ParcelManager] No hay parcela mapeada para base: " .. tostring(baseName))
		return nil
	end

	-- Verificar que la parcela no este asignada a otro jugador
	if assignedParcels[parcelName] and assignedParcels[parcelName] ~= player.UserId then
		warn("[ParcelManager] Parcela " .. parcelName .. " ya esta asignada a otro userId: " .. tostring(assignedParcels[parcelName]))
		return nil
	end

	local parcel = getParcelByName(parcelName)
	if not parcel then
		warn("[ParcelManager] No se encontro la parcela: " .. parcelName)
		return nil
	end

	assignedParcels[parcelName] = player.UserId
	playerParcels[player.UserId] = parcel

	-- Crear folder para los bloques colocados por el jugador en esta parcela
	local blocksFolder = Instance.new("Folder")
	blocksFolder.Name = "Blocks_" .. player.UserId
	blocksFolder.Parent = parcel

	print("[ParcelManager] Parcela asignada a " .. player.Name .. ": " .. parcelName)
	return parcel
end

-- Liberar parcela al salir el jugador
function ParcelManager.release(userId)
	local parcel = playerParcels[userId]
	if not parcel then return end

	-- Eliminar todos los bloques colocados por el jugador
	local blocksFolder = parcel:FindFirstChild("Blocks_" .. userId)
	if blocksFolder then
		blocksFolder:Destroy()
	end

	-- Limpiar asignacion
	local parcelName = parcel.Name
	assignedParcels[parcelName] = nil
	playerParcels[userId] = nil

	print("[ParcelManager] Parcela liberada: " .. parcelName)
end

-- Verificar que una parcela pertenece al jugador
function ParcelManager.isParcelOwnedByPlayer(parcel, player)
	if not parcel or not player then return false end
	local assigned = playerParcels[player.UserId]
	return assigned == parcel
end

-- Obtener los limites (bounds) del area de construccion de una parcela
-- Devuelve: minX, maxX, minY, maxY, minZ, maxZ (en world coords)
function ParcelManager.getParcelBounds(parcel)
	if not parcel then return nil end
	local pos = parcel.Position
	local halfX = PARCEL_SIZE_X / 2
	local halfZ = PARCEL_SIZE_Z / 2
	-- minY = top de la parcela (donde se construye encima)
	-- maxY = minY + 36 (9 bloques de alto)
	return {
		minX = pos.X - halfX,
		maxX = pos.X + halfX,
		minY = pos.Y,        -- top de la parcela
		maxY = pos.Y + PARCEL_HEIGHT,
		minZ = pos.Z - halfZ,
		maxZ = pos.Z + halfZ,
	}
end

-- Verificar que una posicion (centro del bloque) esta dentro de los bounds de la parcela
function ParcelManager.isPositionInParcel(parcel, position)
	local bounds = ParcelManager.getParcelBounds(parcel)
	if not bounds then return false end
	local halfBlock = BLOCK_SIZE / 2
	-- El bloque entero debe caber dentro de la parcela
	return  position.X - halfBlock >= bounds.minX and position.X + halfBlock <= bounds.maxX and
		position.Y - halfBlock >= bounds.minY and position.Y + halfBlock <= bounds.maxY and
		position.Z - halfBlock >= bounds.minZ and position.Z + halfBlock <= bounds.maxZ
end

-- Obtener el folder de bloques del jugador en su parcela
function ParcelManager.getBlocksFolder(userId)
	local parcel = playerParcels[userId]
	if not parcel then return nil end
	return parcel:FindFirstChild("Blocks_" .. userId)
end

-- Constantes exportadas para que BuildManager y el cliente las usen
ParcelManager.BLOCK_SIZE = BLOCK_SIZE
ParcelManager.PARCEL_SIZE_X = PARCEL_SIZE_X
ParcelManager.PARCEL_SIZE_Z = PARCEL_SIZE_Z
ParcelManager.PARCEL_HEIGHT = PARCEL_HEIGHT

return ParcelManager

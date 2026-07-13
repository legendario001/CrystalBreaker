-- ============================================
-- BuildManager (ModuleScript) - ServerStorage/ServerModules
-- Maneja colocacion y quita de bloques en parcelas
-- Validacion de parcela, dinero, bounds y dueño
-- ============================================

local ServerStorage = game:GetService("ServerStorage")
local ParcelManager = require(ServerStorage.ServerModules.ParcelManager)

local BuildManager = {}

-- ============================================
-- Lista de bloques disponibles (TEST PRECIOS BARATOS)
-- Para agregar mas bloques en el futuro, solo agregar entradas a esta tabla
-- ============================================
local BLOCK_TYPES = {
	{ id = "madera",    name = "Madera",    color = Color3.fromRGB(160, 100, 50),  material = Enum.Material.Wood,        cost = 1 },
	{ id = "tierra",    name = "Tierra",    color = Color3.fromRGB(130, 90, 60),   material = Enum.Material.Grass,      cost = 1 },
	{ id = "piedra",    name = "Piedra",    color = Color3.fromRGB(130, 130, 130), material = Enum.Material.Slate,      cost = 2 },
	{ id = "ladrillo",  name = "Ladrillo",  color = Color3.fromRGB(180, 80, 60),   material = Enum.Material.Brick,      cost = 5 },
	{ id = "marmol",    name = "Marmol",    color = Color3.fromRGB(240, 240, 240), material = Enum.Material.Marble,     cost = 10 },
	{ id = "oro",       name = "Oro",       color = Color3.fromRGB(255, 215, 0),   material = Enum.Material.Foil,       cost = 50 },
	{ id = "diamante",  name = "Diamante",  color = Color3.fromRGB(135, 230, 255), material = Enum.Material.Glass,      cost = 100 },
	{ id = "galaxia",   name = "Galaxia",   color = Color3.fromRGB(75, 0, 130),    material = Enum.Material.Neon,       cost = 500 },
}

-- Mapa rapido: id -> config del bloque
local BLOCK_MAP = {}
for _, b in ipairs(BLOCK_TYPES) do
	BLOCK_MAP[b.id] = b
end

-- Obtener la lista completa de bloques (para enviar al cliente)
function BuildManager.getBlocksList()
	return BLOCK_TYPES
end

-- Obtener la config de un bloque por id
function BuildManager.getBlockConfig(blockId)
	return BLOCK_MAP[blockId]
end

-- Colocar un bloque en la parcela del jugador
-- Devuelve: true si se coloco, false + mensaje de error si no
function BuildManager.placeBlock(player, blockId, position, rotation)
	if not player or not player.Parent then return false, "Jugador invalido" end

	local config = BLOCK_MAP[blockId]
	if not config then return false, "Bloque invalido: " .. tostring(blockId) end

	local parcel = ParcelManager.getParcel(player.UserId)
	if not parcel then return false, "No tienes parcela asignada" end

	-- Validar que la posicion este dentro de los bounds de la parcela
	if not ParcelManager.isPositionInParcel(parcel, position) then
		return false, "Posicion fuera de tu parcela"
	end

	-- Validar dinero suficiente (lo hace el servidor via RemoteEvent handler en GameHandler)
	-- Aqui solo verificamos que tenga el modulo de dinero disponible
	-- (la validacion real de dinero la hace GameHandler antes de llamar a placeBlock)

	-- Crear el bloque
	local block = Instance.new("Part")
	block.Name = "Block_" .. blockId
	block.Size = Vector3.new(ParcelManager.BLOCK_SIZE, ParcelManager.BLOCK_SIZE, ParcelManager.BLOCK_SIZE)
	block.Position = position
	if rotation then
		block.Orientation = rotation
	end
	block.Anchored = true
	block.CanCollide = true
	block.Material = config.material
	block.Color = config.color
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	block.CastShadow = true

	-- Tag con el id del bloque (para identificarlo al quitar)
	local idTag = Instance.new("StringValue")
	idTag.Name = "BlockId"
	idTag.Value = blockId
	idTag.Parent = block

	-- Tag con el dueño (por seguridad extra)
	local ownerTag = Instance.new("ObjectValue")
	ownerTag.Name = "Owner"
	ownerTag.Value = player
	ownerTag.Parent = block

	-- Parent al folder de bloques del jugador en la parcela
	local blocksFolder = ParcelManager.getBlocksFolder(player.UserId)
	if not blocksFolder then
		-- Si no existe el folder, crearlo (puede pasar si assignByBaseName no lo creo)
		blocksFolder = Instance.new("Folder")
		blocksFolder.Name = "Blocks_" .. player.UserId
		blocksFolder.Parent = parcel
	end
	block.Parent = blocksFolder

	return true, block
end

-- Quitar un bloque de la parcela del jugador
-- Devuelve: true si se quito, false + mensaje si no
function BuildManager.removeBlock(player, block)
	if not player or not player.Parent then return false, "Jugador invalido" end
	if not block or not block.Parent then return false, "Bloque invalido" end

	-- Verificar que el bloque tenga tag de Owner y sea del jugador
	local ownerTag = block:FindFirstChild("Owner")
	if not ownerTag or ownerTag.Value ~= player then
		return false, "No eres dueno de este bloque"
	end

	-- Verificar que el bloque este dentro de una parcela (subir padres hasta encontrarla)
	local current = block.Parent
	while current do
		if ParcelManager.isParcelOwnedByPlayer(current, player) then
			block:Destroy()
			return true
		end
		current = current.Parent
	end

	return false, "El bloque no esta en tu parcela"
end

-- Limpiar todos los bloques del jugador (al salir)
function BuildManager.cleanupPlayer(userId)
	-- ParcelManager.release ya destruye el folder Blocks_<userId>
	-- Esta funcion existe por si se necesita limpieza extra en el futuro
end

return BuildManager

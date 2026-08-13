-- ============================================
-- BuildManager (ModuleScript) - ServerStorage/ServerModules
-- Maneja compra, inventario y colocacion de bloques en parcelas
-- Flujo: BuyBlock (con dinero) -> inventario -> PlaceBlock (usa inventario, no dinero)
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
        { id = "cristal",   name = "Cristal",   color = Color3.fromRGB(200, 240, 255), material = Enum.Material.Glass,      cost = 1000000, transparency = 0.3 },
        { id = "puerta_madera", name = "Puerta Madera", color = Color3.fromRGB(140, 90, 45), material = Enum.Material.Wood, cost = 1000000, isDoor = true },
}

-- Mapa rapido: id -> config del bloque
local BLOCK_MAP = {}
for _, b in ipairs(BLOCK_TYPES) do
        BLOCK_MAP[b.id] = b
end

-- Inventario de bloques por jugador: [userId] = { [blockId] = count }
local playerInventories = {}

-- Obtener la lista completa de bloques (para enviar al cliente)
function BuildManager.getBlocksList()
        return BLOCK_TYPES
end

-- Obtener la config de un bloque por id
function BuildManager.getBlockConfig(blockId)
        return BLOCK_MAP[blockId]
end

-- Obtener el inventario de un jugador (copia para no mutar el original)
function BuildManager.getInventory(userId)
        local inv = playerInventories[userId]
        if not inv then return {} end
        -- Devolver copia con count > 0
        local result = {}
        for id, count in pairs(inv) do
                if count > 0 then
                        result[id] = count
                end
        end
        return result
end

-- Comprar un bloque (descuenta dinero, agrega al inventario)
-- Devuelve: true si se compro, false + mensaje de error si no
function BuildManager.buyBlock(player, blockId)
        if not player or not player.Parent then return false, "Jugador invalido" end

        local config = BLOCK_MAP[blockId]
        if not config then return false, "Bloque invalido: " .. tostring(blockId) end

        -- El dinero lo maneja GameHandler (valida y descuenta), aqui solo agregamos al inventario
        if not playerInventories[player.UserId] then
                playerInventories[player.UserId] = {}
        end
        playerInventories[player.UserId][blockId] = (playerInventories[player.UserId][blockId] or 0) + 1

        return true, config.cost
end

-- Colocar un bloque del inventario del jugador
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

        -- Validar que el jugador tenga el bloque en su inventario
        local inv = playerInventories[player.UserId]
        if not inv or not inv[blockId] or inv[blockId] <= 0 then
                return false, "No tienes este bloque en tu inventario"
        end

        -- Verificar overlap: si ya hay un bloque en esa posicion exacta, no colocar
        local blocksFolder = ParcelManager.getBlocksFolder(player.UserId)
        if blocksFolder then
                for _, b in ipairs(blocksFolder:GetChildren()) do
                        if b:IsA("BasePart") and (b.Position - position).Magnitude < 1 then
                                return false, "Ya hay un bloque en esa posicion"
                        end
                end
        end

        -- Crear el bloque
        -- FIX: Si es puerta, crear bloque base INVISIBLE (marcador) + modelo de puerta
        -- Si no es puerta, crear bloque normal visible
        local block = Instance.new("Part")
        block.Name = "Block_" .. blockId
        block.Size = Vector3.new(ParcelManager.BLOCK_SIZE, ParcelManager.BLOCK_SIZE, ParcelManager.BLOCK_SIZE)
        block.Position = position
        if rotation then
                block.Orientation = rotation
        end
        block.Anchored = true
        block.Material = config.material
        block.Color = config.color
        block.TopSurface = Enum.SurfaceType.Smooth
        block.BottomSurface = Enum.SurfaceType.Smooth
        block.CastShadow = true

        -- Si es puerta, el bloque base es invisible y no colisiona (solo sirve como marcador)
        if config.isDoor then
                block.Transparency = 1
                block.CanCollide = false
        else
                block.CanCollide = true
                -- Transparencia para bloques como cristal
                if config.transparency then
                        block.Transparency = config.transparency
                end
        end

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
        if not blocksFolder then
                blocksFolder = Instance.new("Folder")
                blocksFolder.Name = "Blocks_" .. player.UserId
                blocksFolder.Parent = parcel
        end
        block.Parent = blocksFolder

        -- FIX: Si es una puerta, clonar el modelo de ServerStorage y agregar logica de apertura
        if config.isDoor then
                local ServerStorage = game:GetService("ServerStorage")
                local puertaModel = ServerStorage:FindFirstChild("Puerta")
                if puertaModel then
                        local doorClone = puertaModel:Clone()

                        -- FIX CRITICO: Asegurar PrimaryPart ANTES de posicionar
                        if not doorClone.PrimaryPart then
                                local firstPart = doorClone:FindFirstChildWhichIsA("BasePart")
                                if firstPart then
                                        doorClone.PrimaryPart = firstPart
                                else
                                        warn("[BuildManager] El modelo Puerta no tiene BaseParts")
                                        doorClone:Destroy()
                                        return false, "Modelo de puerta invalido"
                                end
                        end

                        -- FIX: Preservar la rotacion original del modelo
                        -- Solo cambiar la posicion, mantener la orientacion del PrimaryPart
                        local originalCFrame = doorClone.PrimaryPart.CFrame
                        local originalRotation = originalCFrame - originalCFrame.Position

                        -- Calcular la posicion objetivo: la base del modelo debe quedar en position.Y
                        -- Buscar la Y minima del modelo para calcular el offset
                        local minY = math.huge
                        for _, p in ipairs(doorClone:GetDescendants()) do
                                if p:IsA("BasePart") then
                                        local partBottomY = p.Position.Y - p.Size.Y/2
                                        if partBottomY < minY then
                                                minY = partBottomY
                                        end
                                end
                        end

                        -- Posicion objetivo del PrimaryPart:
                        -- position.Y es la base del bloque, queremos que la base del modelo quede ahi
                        -- yOffset = position.Y - minY (cuanto mover el modelo en Y)
                        -- targetPos = originalPrimaryPart.Position + (0, yOffset, 0)
                        local yOffset = position.Y - minY
                        local targetPrimaryPos = originalCFrame.Position + Vector3.new(
                                position.X - originalCFrame.Position.X,
                                yOffset,
                                position.Z - originalCFrame.Position.Z
                        )

                        -- Posicionar preservando rotacion
                        doorClone:SetPrimaryPartCFrame(CFrame.new(targetPrimaryPos) * originalRotation)
                        doorClone.Parent = blocksFolder

                        -- Hacer todas las partes Anchored
                        local doorParts = {}
                        for _, p in ipairs(doorClone:GetDescendants()) do
                                if p:IsA("BasePart") then
                                        p.Anchored = true
                                        table.insert(doorParts, p)
                                end
                        end

                        -- Tag para identificarla como puerta (en el modelo, no en el bloque base)
                        local doorTag = Instance.new("StringValue")
                        doorTag.Name = "DoorPart"
                        doorTag.Value = "model"
                        doorTag.Parent = doorClone

                        -- Tag con el id del bloque en el modelo tambien (para eliminar)
                        local doorIdTag = Instance.new("StringValue")
                        doorIdTag.Name = "BlockId"
                        doorIdTag.Value = blockId
                        doorIdTag.Parent = doorClone

                        -- Tag con el dueño en el modelo (para poder eliminarlo)
                        local doorOwnerTag = Instance.new("ObjectValue")
                        doorOwnerTag.Name = "Owner"
                        doorOwnerTag.Value = player
                        doorOwnerTag.Parent = doorClone

                        -- Guardar transparencias originales
                        local originalTransparencies = {}
                        for _, p in ipairs(doorParts) do
                                originalTransparencies[p] = p.Transparency
                        end

                        -- Sonido de puerta (sound ID valido de Roblox)
                        local doorSound = Instance.new("Sound")
                        doorSound.SoundId = "rbxassetid://9046618260"
                        doorSound.Volume = 0.8
                        doorSound.Parent = doorClone

                        -- Estado de la puerta
                        local isOpen = false
                        local debounce = false

                        -- Loop para detectar jugadores cercanos y abrir/cerrar
                        task.spawn(function()
                                local Players = game:GetService("Players")
                                while doorClone and doorClone.Parent do
                                        task.wait(0.3)
                                        local someoneNear = false
                                        for _, p in ipairs(Players:GetPlayers()) do
                                                local char = p.Character
                                                if char and char:FindFirstChild("HumanoidRootPart") then
                                                        local hrp = char.HumanoidRootPart
                                                        local dist = (hrp.Position - position).Magnitude
                                                        if dist < (ParcelManager.BLOCK_SIZE + 4) then
                                                                someoneNear = true
                                                                break
                                                        end
                                                end
                                        end
                                        if someoneNear and not isOpen then
                                                isOpen = true
                                                for _, p in ipairs(doorParts) do
                                                        p.Transparency = 1
                                                        p.CanCollide = false
                                                end
                                                if not debounce then
                                                        debounce = true
                                                        pcall(function() doorSound:Play() end)
                                                        task.delay(1, function() debounce = false end)
                                                end
                                        elseif not someoneNear and isOpen then
                                                isOpen = false
                                                for _, p in ipairs(doorParts) do
                                                        p.Transparency = originalTransparencies[p] or 0
                                                        p.CanCollide = true
                                                end
                                                if not debounce then
                                                        debounce = true
                                                        pcall(function() doorSound:Play() end)
                                                        task.delay(1, function() debounce = false end)
                                                end
                                        end
                                end
                        end)
                else
                        warn("[BuildManager] No se encontro el modelo 'Puerta' en ServerStorage")
                end
        end

        -- Descontar 1 del inventario
        inv[blockId] = inv[blockId] - 1
        if inv[blockId] <= 0 then
                inv[blockId] = nil
        end

        return true, block
end

-- Quitar un bloque de la parcela del jugador
-- Devuelve: true si se quito, false + mensaje si no
-- Si returnToInventory es true, el bloque se devuelve al inventario del jugador
function BuildManager.removeBlock(player, block, returnToInventory)
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
                        -- Si returnToInventory, devolver al inventario antes de destruir
                        if returnToInventory then
                                local idTag = block:FindFirstChild("BlockId")
                                if idTag then
                                        local blockId = idTag.Value
                                        if not playerInventories[player.UserId] then
                                                playerInventories[player.UserId] = {}
                                        end
                                        playerInventories[player.UserId][blockId] = (playerInventories[player.UserId][blockId] or 0) + 1
                                end
                        end
                        -- FIX: Si es una puerta, eliminar tambien el modelo clonado
                        local blockIdTag = block:FindFirstChild("BlockId")
                        local blockId = blockIdTag and blockIdTag.Value
                        if blockId and BLOCK_MAP[blockId] and BLOCK_MAP[blockId].isDoor then
                                local blockPos = block.Position
                                local parent = block.Parent
                                if parent then
                                        for _, sibling in ipairs(parent:GetChildren()) do
                                                if sibling ~= block then
                                                        -- Eliminar modelo de puerta (DoorPart tag)
                                                        -- Buscar tanto en Models como en BaseParts
                                                        local doorTag = sibling:FindFirstChild("DoorPart")
                                                        if doorTag then
                                                                -- Es un modelo de puerta, verificar cercania
                                                                local siblingPos = nil
                                                                if sibling:IsA("Model") then
                                                                        if sibling.PrimaryPart then
                                                                                siblingPos = sibling.PrimaryPart.Position
                                                                        else
                                                                                local firstPart = sibling:FindFirstChildWhichIsA("BasePart")
                                                                                if firstPart then
                                                                                        siblingPos = firstPart.Position
                                                                                end
                                                                        end
                                                                elseif sibling:IsA("BasePart") then
                                                                        siblingPos = sibling.Position
                                                                end
                                                                if siblingPos then
                                                                        local dist = (siblingPos - blockPos).Magnitude
                                                                        if dist < ParcelManager.BLOCK_SIZE + 4 then
                                                                                sibling:Destroy()
                                                                        end
                                                                end
                                                        end
                                                end
                                        end
                                end
                        end
                        block:Destroy()
                        return true
                end
                current = current.Parent
        end

        return false, "El bloque no esta en tu parcela"
end

-- Limpiar inventario y bloques del jugador (al salir)
function BuildManager.cleanupPlayer(userId)
        -- ParcelManager.release ya destruye el folder Blocks_<userId>
        -- Aqui solo limpiamos el inventario en memoria
        playerInventories[userId] = nil
end

-- Establecer el inventario directamente (para cargar desde DataStore)
-- inventoryData = { [blockId] = count }
function BuildManager.setInventory(userId, inventoryData)
        if not inventoryData then return end
        playerInventories[userId] = {}
        for blockId, count in pairs(inventoryData) do
                if count > 0 then
                        playerInventories[userId][blockId] = count
                end
        end
end

-- Colocar un bloque sin descontar del inventario (para restaurar desde DataStore)
-- No valida dinero ni inventario, solo valida parcela y overlap
function BuildManager.placeBlockNoCost(player, blockId, position, rotation)
        if not player or not player.Parent then return false, "Jugador invalido" end

        local config = BLOCK_MAP[blockId]
        if not config then return false, "Bloque invalido: " .. tostring(blockId) end

        local parcel = ParcelManager.getParcel(player.UserId)
        if not parcel then return false, "No tienes parcela asignada" end

        -- Validar bounds
        if not ParcelManager.isPositionInParcel(parcel, position) then
                return false, "Posicion fuera de tu parcela"
        end

        -- Verificar overlap
        local blocksFolder = ParcelManager.getBlocksFolder(player.UserId)
        if blocksFolder then
                for _, b in ipairs(blocksFolder:GetChildren()) do
                        if b:IsA("BasePart") and (b.Position - position).Magnitude < 1 then
                                return false, "Ya hay un bloque en esa posicion"
                        end
                end
        end

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

        local idTag = Instance.new("StringValue")
        idTag.Name = "BlockId"
        idTag.Value = blockId
        idTag.Parent = block

        local ownerTag = Instance.new("ObjectValue")
        ownerTag.Name = "Owner"
        ownerTag.Value = player
        ownerTag.Parent = block

        if not blocksFolder then
                blocksFolder = Instance.new("Folder")
                blocksFolder.Name = "Blocks_" .. player.UserId
                blocksFolder.Parent = parcel
        end
        block.Parent = blocksFolder

        return true, block
end

return BuildManager

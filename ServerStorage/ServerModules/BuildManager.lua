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
        -- Transparencia para bloques como cristal
        if config.transparency then
                block.Transparency = config.transparency
        end
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
        if not blocksFolder then
                blocksFolder = Instance.new("Folder")
                blocksFolder.Name = "Blocks_" .. player.UserId
                blocksFolder.Parent = parcel
        end
        block.Parent = blocksFolder

        -- FIX: Si es una puerta, crear el segundo bloque arriba + logica de apertura automatica
        if config.isDoor then
                -- Crear bloque superior (2 bloques de altura como Minecraft)
                local upperBlock = Instance.new("Part")
                upperBlock.Name = "Block_" .. blockId .. "_Upper"
                upperBlock.Size = Vector3.new(ParcelManager.BLOCK_SIZE, ParcelManager.BLOCK_SIZE, ParcelManager.BLOCK_SIZE)
                upperBlock.Position = position + Vector3.new(0, ParcelManager.BLOCK_SIZE, 0)
                upperBlock.Anchored = true
                upperBlock.CanCollide = true
                upperBlock.Material = config.material
                upperBlock.Color = config.color
                upperBlock.TopSurface = Enum.SurfaceType.Smooth
                upperBlock.BottomSurface = Enum.SurfaceType.Smooth
                upperBlock.CastShadow = true
                upperBlock.Parent = blocksFolder

                -- Tags para identificarla como puerta
                local upperIdTag = Instance.new("StringValue")
                upperIdTag.Name = "BlockId"
                upperIdTag.Value = blockId
                upperIdTag.Parent = upperBlock

                local upperOwnerTag = Instance.new("ObjectValue")
                upperOwnerTag.Name = "Owner"
                upperOwnerTag.Value = player
                upperOwnerTag.Parent = upperBlock

                -- Tag DoorPart para identificarla en la logica de apertura
                local doorTag = Instance.new("StringValue")
                doorTag.Name = "DoorPart"
                doorTag.Value = "upper"
                doorTag.Parent = upperBlock
                local doorTagLower = Instance.new("StringValue")
                doorTagLower.Name = "DoorPart"
                doorTagLower.Value = "lower"
                doorTagLower.Parent = block

                -- Marca visual en la puerta (panel frontal)
                local billboard = Instance.new("BillboardGui")
                billboard.Size = UDim2.new(4, 0, 4, 0)
                billboard.StudsOffset = Vector3.new(0, 0, 0)
                billboard.AlwaysOnTop = false
                billboard.MaxDistance = 30
                billboard.Parent = block

                local doorLabel = Instance.new("TextLabel")
                doorLabel.Size = UDim2.new(1, 0, 0.3, 0)
                doorLabel.Position = UDim2.new(0, 0, 0.35, 0)
                doorLabel.BackgroundTransparency = 1
                doorLabel.Text = "🚪"
                doorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                doorLabel.TextScaled = true
                doorLabel.Font = Enum.Font.GothamBold
                doorLabel.Parent = billboard

                -- Logica de apertura automatica al pasar cerca
                local isOpen = false
                local debounce = false
                local proximity = Instance.new("Part")
                proximity.Name = "DoorProximity"
                proximity.Size = Vector3.new(ParcelManager.BLOCK_SIZE + 6, ParcelManager.BLOCK_SIZE * 2.5, ParcelManager.BLOCK_SIZE + 6)
                proximity.Position = position + Vector3.new(0, ParcelManager.BLOCK_SIZE / 2, 0)
                proximity.Anchored = true
                proximity.CanCollide = false
                proximity.Transparency = 1
                proximity.Parent = blocksFolder

                local proxIdTag = Instance.new("StringValue")
                proxIdTag.Name = "BlockId"
                proxIdTag.Value = blockId
                proxIdTag.Parent = proximity

                proximity.Touched:Connect(function(hit)
                        if debounce then return end
                        local character = hit.Parent
                        if not character then return end
                        local humanoid = character:FindFirstChildOfClass("Humanoid")
                        if not humanoid then return end
                        debounce = true
                        if not isOpen then
                                isOpen = true
                                block.CanCollide = false
                                upperBlock.CanCollide = false
                                block.Transparency = 0.7
                                upperBlock.Transparency = 0.7
                        end
                        task.wait(0.5)
                        debounce = false
                end)

                -- Loop para cerrar la puerta cuando no hay nadie cerca
                task.spawn(function()
                        local Players = game:GetService("Players")
                        while block and block.Parent do
                                task.wait(0.5)
                                if isOpen then
                                        local someoneNear = false
                                        for _, p in ipairs(Players:GetPlayers()) do
                                                local char = p.Character
                                                if char and char:FindFirstChild("HumanoidRootPart") then
                                                        local hrp = char.HumanoidRootPart
                                                        local dist = (hrp.Position - block.Position).Magnitude
                                                        if dist < (ParcelManager.BLOCK_SIZE + 4) then
                                                                someoneNear = true
                                                                break
                                                        end
                                                end
                                        end
                                        if not someoneNear then
                                                isOpen = false
                                                block.CanCollide = true
                                                upperBlock.CanCollide = true
                                                block.Transparency = 0
                                                upperBlock.Transparency = 0
                                        end
                                end
                        end
                end)
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
                        -- FIX: Si es una puerta, eliminar tambien el bloque superior y la proximity
                        local doorTag = block:FindFirstChild("DoorPart")
                        if doorTag then
                                -- Buscar el bloque superior o inferior segun corresponda
                                local blockPos = block.Position
                                local parent = block.Parent
                                if parent then
                                        for _, sibling in ipairs(parent:GetChildren()) do
                                                if sibling:IsA("BasePart") and sibling ~= block then
                                                        local siblingDoorTag = sibling:FindFirstChild("DoorPart")
                                                        local siblingIdTag = sibling:FindFirstChild("BlockId")
                                                        local isProximity = sibling.Name == "DoorProximity"
                                                        if siblingDoorTag or isProximity then
                                                                -- Si es proximity o la otra mitad de la puerta, eliminar
                                                                if isProximity then
                                                                        sibling:Destroy()
                                                                elseif doorTag.Value == "lower" and siblingDoorTag.Value == "upper" then
                                                                        -- Es la mitad superior de esta puerta, eliminar
                                                                        local dist = (sibling.Position - blockPos).Magnitude
                                                                        if dist < ParcelManager.BLOCK_SIZE + 1 then
                                                                                sibling:Destroy()
                                                                        end
                                                                elseif doorTag.Value == "upper" and siblingDoorTag.Value == "lower" then
                                                                        -- Es la mitad inferior de esta puerta, eliminar
                                                                        local dist = (sibling.Position - blockPos).Magnitude
                                                                        if dist < ParcelManager.BLOCK_SIZE + 1 then
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

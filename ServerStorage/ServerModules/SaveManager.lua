-- ============================================
-- SaveManager (ModuleScript) - ServerStorage/ServerModules
-- Maneja el guardado y carga de datos del jugador con DataStore
-- Guarda: money, baseLevel, characters, blockInventory, placedBlocks
-- ============================================

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local SaveManager = {}

-- DataStore principal (un solo store por jugador, clave = userId)
local playerStore = DataStoreService:GetDataStore("PlayerData_v2")

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
                modelName = charData.modelName or (charData.model and charData.model.Name) or charData.name,
                pedestalName = nil,
                pedestalFloor = nil,
                accumulatedMoney = 0, -- dinero acumulado en el MoneyPile (no recogido)
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

                -- Leer el dinero acumulado en el MoneyPile del pedestal
                local moneyPile = charData.pedestal:FindFirstChild("MoneyPile")
                if moneyPile then
                        local moneyValue = moneyPile:FindFirstChild("MoneyValue")
                        if moneyValue then
                                serialized.accumulatedMoney = moneyValue.Value or 0
                        end
                end
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

-- Serializar bloques colocados (Part -> tabla con posicion RELATIVA al centro de la parcela)
-- Esto permite que la construccion se mueva con el jugador si le asignan otra parcela
local function serializePlacedBlocks(blocksFolder, parcelCenter)
        if not blocksFolder then return {} end
        parcelCenter = parcelCenter or Vector3.new(0, 0, 0)
        local serialized = {}
        for _, block in ipairs(blocksFolder:GetChildren()) do
                if block:IsA("BasePart") then
                        local idTag = block:FindFirstChild("BlockId")
                        if idTag then
                                table.insert(serialized, {
                                        blockId = idTag.Value,
                                        -- Posicion relativa al centro de la parcela (offset)
                                        ox = block.Position.X - parcelCenter.X,
                                        oy = block.Position.Y - parcelCenter.Y,
                                        oz = block.Position.Z - parcelCenter.Z,
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
        -- FIX: La cache solo se usa si fue poblada por un loadPlayerData previo en la
        -- MISMA sesion del servidor. Si el jugador salio y volvio a entrar, clearCache
        -- la borro, asi que esta llamada va a leer del DataStore real.
        -- Esto es correcto: si la cache existia, son los mismos datos que ya cargamos.
        if loadedData[userId] then
                print("[SaveManager] Cache hit para userId " .. userId)
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
                print("[SaveManager] No hay datos guardados para userId " .. userId .. " (jugador nuevo)")
                return nil
        end

        -- LOGS DE DIAGNOSTICO: mostrar que se leyo del DataStore
        local charCount = 0
        if data.characters then
                for _ in pairs(data.characters) do charCount = charCount + 1 end
        end
        print("[SaveManager] Datos leidos del DataStore para userId " .. userId .. ":")
        print("[SaveManager]   money=" .. tostring(data.money) .. ", bankBalance=" .. tostring(data.bankBalance))
        print("[SaveManager]   characters=" .. charCount .. ", baseLevel=" .. tostring(data.baseLevel))
        print("[SaveManager]   lastSaveTimestamp=" .. tostring(data.lastSaveTimestamp) .. " (hace " .. (os.time() - (data.lastSaveTimestamp or 0)) .. "s)")

        loadedData[userId] = data
        return data
end

-- Guardar datos del jugador en DataStore
-- Parametros:
--   userId, playerData, baseLevel, blockInventory, blocksFolder, bankBalance, parcelCenter, unlockedBalls, boostLevel
function SaveManager.savePlayerData(userId, playerData, baseLevel, blockInventory, blocksFolder, bankBalance, parcelCenter, unlockedBalls, boostLevel, rebirthLevel)
        -- Construir la tabla de datos a guardar
        local dataToSave = {
                money = 0,
                baseLevel = baseLevel or 1,
                characters = {},
                blockInventory = {},
                placedBlocks = {},
                bankBalance = bankBalance or 0,
                unlockedBalls = unlockedBalls or {}, -- pelotas desbloqueadas
                boostLevel = boostLevel or 0, -- nivel de boost de ganancias (0-5)
                rebirthLevel = rebirthLevel or 0, -- nivel de renacimiento/evolucion (0-5)
                investors = playerData.investors or 0, -- inversionistas acumulados (Sell Lemons style)
                totalMoneyEarnedThisLife = playerData.totalMoneyEarnedThisLife or 0, -- dinero generado esta vida
                lastSaveTimestamp = os.time(), -- timestamp del ultimo guardado (para dinero offline)
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
                dataToSave.placedBlocks = serializePlacedBlocks(blocksFolder, parcelCenter)
        end

        -- LOG DE DIAGNOSTICO: que se va a guardar
        local charCount = 0
        for _ in pairs(dataToSave.characters) do charCount = charCount + 1 end
        print("[SaveManager] SetAsync para userId " .. userId .. ": money=" .. dataToSave.money .. ", bank=" .. dataToSave.bankBalance .. ", chars=" .. charCount)

        -- Guardar en DataStore
        local success, err = pcall(function()
                playerStore:SetAsync("player_" .. userId, dataToSave)
        end)

        if not success then
                warn("[SaveManager] Error al guardar datos de userId " .. userId .. ": " .. tostring(err))
                return false
        end

        print("[SaveManager] SetAsync OK para userId " .. userId)
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

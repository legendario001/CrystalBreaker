-- ============================================
-- CharacterManager (ModuleScript) - ServerStorage/ServerModules
-- Maneja los modelos de personajes por rareza
-- Al recoger un cofre da un personaje aleatorio de la carpeta correspondiente
-- ============================================

local ServerStorage = game:GetService("ServerStorage")

local CharacterManager = {}

-- Mapeo de rareza a carpeta
local folderMap = {
        Morado = "Morado",
        Rojo = "Rojo",
        Amarillo = "Amarillo",
        Azul = "Azul",
        Blanco = "Blanco"
}

-- Obtener un modelo aleatorio de la carpeta correspondiente a la rareza
-- avoidList: (opcional) tabla con nombres de modelos a evitar (para no dar repetidos)
-- Devuelve: model, folderName, modelName
function CharacterManager.getRandomModel(rarity, avoidList)
        local mf = ServerStorage:FindFirstChild("ModelosPj")
        if not mf then return nil, "", nil end
        local folderName = folderMap[rarity]
        if not folderName then return nil, "", nil end
        local folder = mf:FindFirstChild(folderName)
        if not folder then return nil, "", nil end
        local allModels = folder:GetChildren()
        if #allModels == 0 then return nil, "", nil end

        -- Filtrar modelos que estan en avoidList (para no dar repetidos)
        local availableModels = {}
        for _, m in ipairs(allModels) do
                local isAvoided = false
                if avoidList then
                        for _, avoidName in ipairs(avoidList) do
                                if m.Name == avoidName then
                                        isAvoided = true
                                        break
                                end
                        end
                end
                if not isAvoided then
                        table.insert(availableModels, m)
                end
        end

        -- Si todos estan en avoidList, usar todos (no hay opcion)
        if #availableModels == 0 then
                availableModels = allModels
        end

        local chosen = availableModels[math.random(#availableModels)]
        return chosen, folderName, chosen.Name
end

-- Obtener un modelo por nombre y rareza (para cargar desde DataStore)
-- Devuelve: model (Instance), folderName (string) o nil, "" si no se encuentra
function CharacterManager.getModelByName(rarity, modelName)
        if not rarity or not modelName then return nil, "" end
        local mf = ServerStorage:FindFirstChild("ModelosPj")
        if not mf then return nil, "" end
        local folderName = folderMap[rarity]
        if not folderName then return nil, "" end
        local folder = mf:FindFirstChild(folderName)
        if not folder then return nil, "" end
        local model = folder:FindFirstChild(modelName)
        if not model then return nil, "" end
        return model, folderName
end

return CharacterManager

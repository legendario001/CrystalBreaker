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
function CharacterManager.getRandomModel(rarity)
        local mf = ServerStorage:FindFirstChild("ModelosPj")
        if not mf then return nil, "" end
        local folderName = folderMap[rarity]
        if not folderName then return nil, "" end
        local folder = mf:FindFirstChild(folderName)
        if not folder then return nil, "" end
        local models = folder:GetChildren()
        if #models == 0 then return nil, "" end
        return models[math.random(#models)], folderName
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

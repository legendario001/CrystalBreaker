-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- Enfoque: part.Position + offset, lowestY, center XZ
-- NO usar PivotTo, NO destruir partes internas
-- ============================================

local ModelManager = {}

local rarityColors = {
        Morado = Color3.fromRGB(170, 85, 255),
        Rojo = Color3.fromRGB(255, 80, 80),
        Amarillo = Color3.fromRGB(255, 255, 100),
        Azul = Color3.fromRGB(85, 170, 255),
        Blanco = Color3.fromRGB(220, 220, 220)
}

-- ============================================
-- Obtener todas las BaseParts de un modelo
-- ============================================
local function getAllParts(modelOrClone)
        local parts = {}
        for _, desc in ipairs(modelOrClone:GetDescendants()) do
                if desc:IsA("BasePart") then
                        table.insert(parts, desc)
                end
        end
        return parts
end

-- ============================================
-- Calcular centro XZ y lowestY de un modelo
-- Retorna: centerX, centerZ, lowestY, firstPart
-- ============================================
local function getModelBounds(parts)
        if #parts == 0 then return 0, 0, 0, nil end

        local lowestY = math.huge
        local firstPart = parts[1]

        for _, part in ipairs(parts) do
                local bottomY = part.Position.Y - part.Size.Y / 2
                if bottomY < lowestY then
                        lowestY = bottomY
                end
        end

        -- Centro XZ basado en la primera BasePart encontrada
        local centerX = firstPart.Position.X
        local centerZ = firstPart.Position.Z

        return centerX, centerZ, lowestY, firstPart
end

-- ============================================
-- Mostrar E en pedestal vacio
-- ============================================
function ModelManager.showEmptyLabel(pedestal)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then return end
        local old = platform:FindFirstChild("EmptyGui")
        if old then old:Destroy() end

        local bb = Instance.new("BillboardGui")
        bb.Name = "EmptyGui"
        bb.Size = UDim2.new(2, 0, 2, 0)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = 30
        bb.Parent = platform

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "E"
        lbl.TextColor3 = Color3.fromRGB(160, 160, 160)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBlack
        lbl.Parent = bb
end

-- ============================================
-- Ocultar E en pedestal
-- ============================================
function ModelManager.hideEmptyLabel(pedestal)
        local platform = pedestal:FindFirstChild("Platform")
        if platform then
                local old = platform:FindFirstChild("EmptyGui")
                if old then old:Destroy() end
        end
end

-- ============================================
-- Colocar modelo en pedestal usando part.Position + offset
-- Metodo:
--   1. Clonar modelo (NO destruir nada)
--   2. Anchored=true, CanCollide=false en todas las partes
--   3. Calcular lowestY = min(part.Position.Y - part.Size.Y/2)
--   4. offsetY = pedestalTop.Y - lowestY
--   5. Mover todas las partes por (0, offsetY, 0)
--   6. Centrar X,Z usando la primera BasePart como referencia
--   7. Parentear al pedestal
-- ============================================
function ModelManager.placeOnPedestal(model, pedestal)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then return end

        local clone = model:Clone()

        -- Paso 1: Anclar todo y desactivar colisiones ANTES de mover
        for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                end
        end

        -- Parentear al pedestal PRIMERO para que las posiciones se preserven
        clone.Parent = pedestal

        -- Paso 2: Obtener todas las partes y calcular bounds
        local parts = getAllParts(clone)
        if #parts == 0 then return end

        local centerX, centerZ, lowestY, firstPart = getModelBounds(parts)

        -- Paso 3: Calcular posicion objetivo
        local pedestalTop = platform.Position.Y + platform.Size.Y / 2
        local offsetY = pedestalTop - lowestY

        -- Centro del pedestal en XZ
        local targetX = platform.Position.X
        local targetZ = platform.Position.Z

        -- Offset XZ desde el centro actual del modelo al centro del pedestal
        local offsetX = targetX - centerX
        local offsetZ = targetZ - centerZ

        -- Paso 4: Mover TODAS las partes usando CFrame (respeta rotacion)
        for _, part in ipairs(parts) do
                local currentCF = part.CFrame
                -- Aplicar offset en mundo (no en espacio local)
                part.CFrame = currentCF * CFrame.new(offsetX, offsetY, offsetZ)
        end

        ModelManager.hideEmptyLabel(pedestal)
end

-- ============================================
-- Mover modelo a una posicion usando part.Position + offset
-- Mismo enfoque que placeOnPedestal pero sin pedestal
-- ============================================
function ModelManager.moveModelTo(model, position)
        local parts = getAllParts(model)
        if #parts == 0 then return end

        local centerX, centerZ, lowestY, firstPart = getModelBounds(parts)

        -- Calcular offsets para mover el modelo a la posicion deseada
        local offsetX = position.X - centerX
        local offsetY = position.Y - lowestY
        local offsetZ = position.Z - centerZ

        for _, part in ipairs(parts) do
                local currentCF = part.CFrame
                part.CFrame = currentCF * CFrame.new(offsetX, offsetY, offsetZ)
        end
end

-- ============================================
-- Crear etiquetas de nombre y nivel en pedestal
-- ============================================
function ModelManager.createLabels(pedestal, charName, rarity)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then return end

        local nameGui = Instance.new("BillboardGui")
        nameGui.Name = "CharNameGui"
        nameGui.Size = UDim2.new(4, 0, 0.5, 0)
        nameGui.StudsOffset = Vector3.new(0, 5, 0)
        nameGui.AlwaysOnTop = false
        nameGui.Parent = platform

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = charName
        nameLabel.TextColor3 = rarityColors[rarity] or Color3.new(1, 1, 1)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = nameGui

        local levelGui = Instance.new("BillboardGui")
        levelGui.Name = "CharLevelGui"
        levelGui.Size = UDim2.new(2, 0, 0.5, 0)
        levelGui.StudsOffset = Vector3.new(0, 4, 0)
        levelGui.AlwaysOnTop = false
        levelGui.Parent = platform

        local levelLabel = Instance.new("TextLabel")
        levelLabel.Size = UDim2.new(1, 0, 1, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.Text = "Lv.1"
        levelLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.Parent = levelGui
end

-- ============================================
-- Limpiar pedestal y mostrar E de nuevo
-- ============================================
function ModelManager.clearPedestal(pedestal)
        for _, child in ipairs(pedestal:GetChildren()) do
                if child.Name ~= "Platform" and child.Name ~= "PedestalColumn" then
                        child:Destroy()
                end
        end
        ModelManager.showEmptyLabel(pedestal)
end

return ModelManager

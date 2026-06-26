-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- Metodo: part.Position + Vector3 offset (espacio MUNDIAL)
-- NO usar PivotTo, NO usar CFrame * CFrame.new para offsets
-- NO destruir partes internas (FakeRootPart, AnimationController, etc.)
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
-- Calcular centro XZ, lowestY y highestY de un modelo
-- Retorna: centerX, centerZ, lowestY, highestY
-- ============================================
local function getModelBounds(parts)
        if #parts == 0 then return 0, 0, 0, 0 end

        local lowestY = math.huge
        local highestY = -math.huge
        local sumX = 0
        local sumZ = 0

        for _, part in ipairs(parts) do
                local bottomY = part.Position.Y - part.Size.Y / 2
                local topY = part.Position.Y + part.Size.Y / 2
                if bottomY < lowestY then
                        lowestY = bottomY
                end
                if topY > highestY then
                        highestY = topY
                end
                sumX = sumX + part.Position.X
                sumZ = sumZ + part.Position.Z
        end

        -- Centro XZ promediado entre TODAS las partes
        local centerX = sumX / #parts
        local centerZ = sumZ / #parts

        return centerX, centerZ, lowestY, highestY
end

-- ============================================
-- Rotar modelo alrededor de su centro para que mire en una direccion
-- lookDirection: Vector3 unitario de la direccion deseada
-- El modelo se rota en Y para que su "frente" mire en esa direccion
-- ============================================
local function rotateModelToFace(parts, centerX, centerZ, lookDirection)
        -- El eje Y es arriba, solo rotamos en el plano XZ
        -- Calculamos el angulo deseado
        local desiredAngle = math.atan2(lookDirection.X, lookDirection.Z)

        for _, part in ipairs(parts) do
                -- Calcular offset del part al centro del modelo (solo XZ)
                local offsetX = part.Position.X - centerX
                local offsetZ = part.Position.Z - centerZ

                -- Rotar el offset alrededor del centro
                local cosA = math.cos(desiredAngle)
                local sinA = math.sin(desiredAngle)
                local newOffsetX = offsetX * cosA - offsetZ * sinA
                local newOffsetZ = offsetX * sinA + offsetZ * cosA

                -- Nueva posicion: centro + offset rotado, Y sin cambio
                local newY = part.Position.Y
                part.Position = Vector3.new(centerX + newOffsetX, newY, centerZ + newOffsetZ)

                -- Rotar tambien el CFrame de la parte (para que las partes individuales miren bien)
                local currentCF = part.CFrame
                local currentPos = currentCF.Position
                local currentRot = currentCF - currentPos
                -- Aplicar rotacion en Y al CFrame
                local rotCF = CFrame.fromMatrix(Vector3.new(0,0,0),
                        Vector3.new(cosA, 0, sinA),
                        Vector3.new(0, 1, 0),
                        Vector3.new(-sinA, 0, cosA)
                )
                part.CFrame = CFrame.new(part.Position) * rotCF * currentRot
        end
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
-- Colocar modelo en pedestal usando part.Position + Vector3
-- Ahora tambien rota el modelo para que mire de frente
-- segun su posicion en la base (izquierda mira derecha, derecha mira izquierda)
-- ============================================
function ModelManager.placeOnPedestal(model, pedestal)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then
                warn("placeOnPedestal: No se encontro Platform en pedestal")
                return nil
        end

        local clone = model:Clone()

        -- Paso 1: Anclar todo y desactivar colisiones ANTES de mover
        for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                end
        end

        -- Paso 2: Parentar al pedestal PRIMERO para que las posiciones sean validas en workspace
        clone.Parent = pedestal

        -- Paso 3: Obtener todas las partes y calcular bounds
        local parts = getAllParts(clone)
        if #parts == 0 then
                warn("placeOnPedestal: El modelo no tiene BaseParts")
                return nil
        end

        local centerX, centerZ, lowestY = getModelBounds(parts)

        -- Paso 4: Calcular posicion objetivo
        local pedestalTopY = platform.Position.Y + platform.Size.Y / 2
        local targetX = platform.Position.X
        local targetZ = platform.Position.Z

        -- Paso 5: Calcular offsets en espacio MUNDIAL
        local offsetY = pedestalTopY - lowestY
        local offsetX = targetX - centerX
        local offsetZ = targetZ - centerZ

        -- Paso 6: Mover TODAS las partes usando part.Position + Vector3 (ESPACIO MUNDIAL)
        for _, part in ipairs(parts) do
                part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
        end

        -- Paso 7: Rotar modelo para que mire de frente
        -- Calcular nueva posicion central despues del movimiento
        local newCenterX = targetX
        local newCenterZ = targetZ

        -- Determinar direccion: buscar la base para saber de que lado esta el pedestal
        -- Los pedestales 1-5 estan a la izquierda (pedX = baseX - 12) -> mirar hacia +X (derecha)
        -- Los pedestales 6-10 estan a la derecha (pedX = baseX + 12) -> mirar hacia -X (izquierda)
        -- Ambas filas se miran de frente entre si

        -- Buscar la base padre para obtener baseX
        local baseFolder = pedestal.Parent -- Pedestals folder
        local base = baseFolder and baseFolder.Parent -- Base folder

        local lookDir = Vector3.new(0, 0, -1) -- default: mirar al sur (hacia la zona de cristales)

        if base then
                -- Obtener baseX del BaseFloor
                local baseFloor = base:FindFirstChild("BaseFloor")
                if baseFloor then
                        local baseX = baseFloor.Position.X
                        -- Si el pedestal esta a la izquierda del centro de la base, mirar a la derecha (+X)
                        -- Si esta a la derecha, mirar a la izquierda (-X)
                        if targetX < baseX then
                                lookDir = Vector3.new(-1, 0, 0) -- fila izquierda mira hacia -X (al centro)
                        else
                                lookDir = Vector3.new(1, 0, 0) -- fila derecha mira hacia +X (al centro)
                        end
                end
        end

        -- Recalcular bounds despues del movimiento para rotar correctamente
        local afterCenterX, afterCenterZ = getModelBounds(parts)
        rotateModelToFace(parts, afterCenterX, afterCenterZ, lookDir)

        ModelManager.hideEmptyLabel(pedestal)
        print("[ModelManager] Modelo colocado y rotado para mirar de frente")
        return clone
end

-- ============================================
-- Mover modelo a una posicion usando part.Position + Vector3
-- ============================================
function ModelManager.moveModelTo(model, position)
        local parts = getAllParts(model)
        if #parts == 0 then return end

        local centerX, centerZ, lowestY = getModelBounds(parts)

        -- Calcular offsets en espacio MUNDIAL
        local offsetX = position.X - centerX
        local offsetY = position.Y - lowestY
        local offsetZ = position.Z - centerZ

        for _, part in ipairs(parts) do
                part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
        end
end

-- ============================================
-- Nombres de rareza bonitos para los labels
-- ============================================
local rarityDisplayNames = {
        Morado = "MITICO",
        Rojo = "EPICO",
        Amarillo = "RARO",
        Azul = "INCOMUN",
        Blanco = "COMUN"
}

-- ============================================
-- Crear etiquetas de nombre y rareza SOBRE la cabeza del personaje
-- Con estilo bonito: fondo oscuro, borde de rareza, texto brillante
-- ============================================
function ModelManager.createLabels(pedestal, charName, rarity)
        -- Buscar la parte mas alta del modelo (la cabeza)
        local highestPart = nil
        local highestY = -math.huge

        for _, child in ipairs(pedestal:GetChildren()) do
                if child:IsA("Model") then
                        for _, part in ipairs(child:GetDescendants()) do
                                if part:IsA("BasePart") then
                                        local topY = part.Position.Y + part.Size.Y / 2
                                        if topY > highestY then
                                                highestY = topY
                                                highestPart = part
                                        end
                                end
                        end
                end
        end

        local labelParent = highestPart
        local labelStudsOffset = Vector3.new(0, 2, 0)

        if not labelParent then
                local platform = pedestal:FindFirstChild("Platform")
                if platform then
                        labelParent = platform
                        labelStudsOffset = Vector3.new(0, 5, 0)
                else
                        return
                end
        end

        -- Limpiar labels anteriores en el padre
        local oldLabel = labelParent:FindFirstChild("CharInfoGui")
        if oldLabel then oldLabel:Destroy() end

        -- Tambien limpiar labels viejos de Platform si existen
        local platform = pedestal:FindFirstChild("Platform")
        if platform and platform ~= labelParent then
                local pOldName = platform:FindFirstChild("CharNameGui")
                if pOldName then pOldName:Destroy() end
                local pOldLevel = platform:FindFirstChild("CharLevelGui")
                if pOldLevel then pOldLevel:Destroy() end
                local pOldInfo = platform:FindFirstChild("CharInfoGui")
                if pOldInfo then pOldInfo:Destroy() end
        end

        local rarityColor = rarityColors[rarity] or Color3.new(1, 1, 1)
        local rarityDisplay = rarityDisplayNames[rarity] or string.upper(rarity)

        -- ============================================
        -- BILLBOARD GUI UNIFICADO (nombre + rareza + nivel)
        -- ============================================
        local infoGui = Instance.new("BillboardGui")
        infoGui.Name = "CharInfoGui"
        infoGui.Size = UDim2.new(5, 0, 2, 0)
        infoGui.StudsOffset = labelStudsOffset
        infoGui.AlwaysOnTop = false
        infoGui.MaxDistance = 50
        infoGui.Parent = labelParent

        -- Fondo oscuro con bordes redondeados
        local bg = Instance.new("Frame")
        bg.Name = "Bg"
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.45
        bg.BorderSizePixel = 0
        bg.Parent = infoGui
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        -- Borde del color de la rareza
        local bgStroke = Instance.new("UIStroke")
        bgStroke.Color = rarityColor
        bgStroke.Thickness = 2
        bgStroke.Transparency = 0.2
        bgStroke.Parent = bg

        -- Fila 1: Nombre del personaje
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = charName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = bg

        -- Fila 2: Rareza (con color)
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Name = "RarityLabel"
        rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
        rarityLabel.Position = UDim2.new(0, 0, 0.4, 0)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = rarityDisplay
        rarityLabel.TextColor3 = rarityColor
        rarityLabel.TextScaled = true
        rarityLabel.Font = Enum.Font.GothamBlack
        rarityLabel.Parent = bg

        -- Brillo sutil en el texto de rareza
        local rarityStroke = Instance.new("UIStroke")
        rarityStroke.Color = Color3.fromRGB(255, 255, 255)
        rarityStroke.Thickness = 0.8
        rarityStroke.Transparency = 0.75
        rarityStroke.Parent = rarityLabel

        -- Fila 3: Nivel
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Name = "LevelLabel"
        levelLabel.Size = UDim2.new(1, 0, 0.3, 0)
        levelLabel.Position = UDim2.new(0, 0, 0.7, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.Text = "Lv.1"
        levelLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.Parent = bg
end

-- ============================================
-- Limpiar pedestal y mostrar E de nuevo
-- AHORA tambien limpia los labels de la Platform
-- ============================================
function ModelManager.clearPedestal(pedestal)
        -- Primero limpiar labels de Platform (el bug: quedaban grabados)
        local platform = pedestal:FindFirstChild("Platform")
        if platform then
                local oldName = platform:FindFirstChild("CharNameGui")
                if oldName then oldName:Destroy() end
                local oldLevel = platform:FindFirstChild("CharLevelGui")
                if oldLevel then oldLevel:Destroy() end
                local oldInfo = platform:FindFirstChild("CharInfoGui")
                if oldInfo then oldInfo:Destroy() end
        end

        -- Limpiar todo lo demas (modelos, labels en partes del modelo, etc)
        -- excepto Platform y PedestalColumn
        for _, child in ipairs(pedestal:GetChildren()) do
                if child.Name ~= "Platform" and child.Name ~= "PedestalColumn" then
                        child:Destroy()
                end
        end

        ModelManager.showEmptyLabel(pedestal)
end

return ModelManager

-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- ============================================

local ModelManager = {}

local rarityColors = {
        Morado = Color3.fromRGB(170, 85, 255),
        Rojo = Color3.fromRGB(255, 80, 80),
        Amarillo = Color3.fromRGB(255, 255, 100),
        Azul = Color3.fromRGB(85, 170, 255),
        Blanco = Color3.fromRGB(220, 220, 220)
}

local rarityMoneyRate = {
        Morado = 10,
        Rojo = 7,
        Amarillo = 5,
        Azul = 3,
        Blanco = 1
}

local UPGRADE_BASE_COST = 5

local MONEY_GREEN = Color3.fromRGB(76, 175, 80)
local MONEY_GREEN_BRIGHT = Color3.fromRGB(129, 199, 132)

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
-- Calcular centro XZ y lowestY
-- ============================================
local function getModelBounds(parts)
        if #parts == 0 then return 0, 0, 0 end

        local lowestY = math.huge
        local sumX = 0
        local sumZ = 0

        for _, part in ipairs(parts) do
                local bottomY = part.Position.Y - part.Size.Y / 2
                if bottomY < lowestY then
                        lowestY = bottomY
                end
                sumX = sumX + part.Position.X
                sumZ = sumZ + part.Position.Z
        end

        return sumX / #parts, sumZ / #parts, lowestY
end

-- ============================================
-- Rotar modelo
-- ============================================
local function rotateModelToFace(parts, centerX, centerZ, lookDirection)
        local desiredAngle = math.atan2(lookDirection.X, lookDirection.Z)

        for _, part in ipairs(parts) do
                local offsetX = part.Position.X - centerX
                local offsetZ = part.Position.Z - centerZ
                local cosA = math.cos(desiredAngle)
                local sinA = math.sin(desiredAngle)
                local newOffsetX = offsetX * cosA - offsetZ * sinA
                local newOffsetZ = offsetX * sinA + offsetZ * cosA
                part.Position = Vector3.new(centerX + newOffsetX, part.Position.Y, centerZ + newOffsetZ)

                local currentCF = part.CFrame
                local currentRot = currentCF - currentCF.Position
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

function ModelManager.hideEmptyLabel(pedestal)
        local platform = pedestal:FindFirstChild("Platform")
        if platform then
                local old = platform:FindFirstChild("EmptyGui")
                if old then old:Destroy() end
        end
end

-- ============================================
-- Calcular posicion de elementos frente al pedestal
-- Retorna: x, z hacia el centro de la base
-- ============================================
local function getForwardPosition(pedestal, offsetStuds)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then return pedestal.Position.X, pedestal.Position.Z end

        local baseFolder = pedestal.Parent
        local base = baseFolder and baseFolder.Parent

        local pileX = platform.Position.X
        local pileZ = platform.Position.Z

        if base then
                local baseFloor = base:FindFirstChild("BaseFloor")
                if baseFloor then
                        local baseX = baseFloor.Position.X
                        if platform.Position.X < baseX then
                                pileX = platform.Position.X + offsetStuds
                        else
                                pileX = platform.Position.X - offsetStuds
                        end
                end
        end

        return pileX, pileZ
end

-- ============================================
-- Colocar modelo en pedestal
-- ============================================
function ModelManager.placeOnPedestal(model, pedestal)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then return nil end

        local clone = model:Clone()

        for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                end
        end

        clone.Parent = pedestal

        local parts = getAllParts(clone)
        if #parts == 0 then return nil end

        local centerX, centerZ, lowestY = getModelBounds(parts)

        local pedestalTopY = platform.Position.Y + platform.Size.Y / 2
        local targetX = platform.Position.X
        local targetZ = platform.Position.Z

        local offsetY = pedestalTopY - lowestY
        local offsetX = targetX - centerX
        local offsetZ = targetZ - centerZ

        for _, part in ipairs(parts) do
                part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
        end

        local baseFolder = pedestal.Parent
        local base = baseFolder and baseFolder.Parent
        local lookDir = Vector3.new(0, 0, -1)

        if base then
                local baseFloor = base:FindFirstChild("BaseFloor")
                if baseFloor then
                        local baseX = baseFloor.Position.X
                        if targetX < baseX then
                                lookDir = Vector3.new(-1, 0, 0)
                        else
                                lookDir = Vector3.new(1, 0, 0)
                        end
                end
        end

        local afterCenterX, afterCenterZ = getModelBounds(parts)
        rotateModelToFace(parts, afterCenterX, afterCenterZ, lookDir)

        ModelManager.hideEmptyLabel(pedestal)
        return clone
end

-- ============================================
-- Mover modelo a una posicion
-- ============================================
function ModelManager.moveModelTo(model, position)
        local parts = getAllParts(model)
        if #parts == 0 then return end
        local centerX, centerZ, lowestY = getModelBounds(parts)
        for _, part in ipairs(parts) do
                part.Position = part.Position + Vector3.new(position.X - centerX, position.Y - lowestY, position.Z - centerZ)
        end
end

-- ============================================
-- Nombres de rareza
-- ============================================
local rarityDisplayNames = {
        Morado = "MITICO",
        Rojo = "EPICO",
        Amarillo = "RARO",
        Azul = "INCOMUN",
        Blanco = "COMUN"
}

-- ============================================
-- Colores RichText (hex) para etiquetas
-- Solo el dinero es verde, lo demas usa otros colores
-- ============================================
local COLOR_LEVEL = "#FFD700"       -- Dorado para nivel
local COLOR_SEPARATOR = "#AAAAAA"   -- Gris para separador
local COLOR_MONEY = "#81C784"       -- Verde para dinero
local COLOR_LABEL = "#B0BEC5"       -- Gris azulado para etiquetas ("Siguiente:", "Costo:", "Nivel:")
local COLOR_MAX = "#FFD700"         -- Dorado para nivel maximo
local COLOR_UPGRADE = "#64FF64"     -- Verde para MEJORAR

-- ============================================
-- Crear etiquetas sobre la cabeza: nombre + rareza + nivel + produccion
-- Solo los numeros de dinero son verdes, lo demas usa otros colores
-- ============================================
function ModelManager.createLabels(pedestal, charName, rarity, level)
        level = level or 1
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

        if labelParent then
                local halfHeight = labelParent.Size.Y / 2
                labelStudsOffset = Vector3.new(0, halfHeight + 1, 0)
        else
                local platform = pedestal:FindFirstChild("Platform")
                if platform then
                        labelParent = platform
                        labelStudsOffset = Vector3.new(0, 5, 0)
                else
                        return
                end
        end

        -- Limpiar labels anteriores
        local oldLabel = labelParent:FindFirstChild("CharInfoGui")
        if oldLabel then oldLabel:Destroy() end
        local platform = pedestal:FindFirstChild("Platform")
        if platform and platform ~= labelParent then
                local pOld = platform:FindFirstChild("CharInfoGui")
                if pOld then pOld:Destroy() end
        end

        local rarityColor = rarityColors[rarity] or Color3.new(1, 1, 1)
        local rarityDisplay = rarityDisplayNames[rarity] or string.upper(rarity)
        local currentRate = ModelManager.getMoneyRate(rarity, level)

        local infoGui = Instance.new("BillboardGui")
        infoGui.Name = "CharInfoGui"
        infoGui.Size = UDim2.new(5, 0, 2.5, 0)
        infoGui.StudsOffset = labelStudsOffset
        infoGui.AlwaysOnTop = false
        infoGui.MaxDistance = 50
        infoGui.Parent = labelParent

        local bg = Instance.new("Frame")
        bg.Name = "Bg"
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.45
        bg.BorderSizePixel = 0
        bg.Parent = infoGui
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        local bgStroke = Instance.new("UIStroke")
        bgStroke.Color = rarityColor
        bgStroke.Thickness = 2
        bgStroke.Transparency = 0.2
        bgStroke.Parent = bg

        -- Fila 1: Nombre (blanco)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = charName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = bg

        -- Fila 2: Rareza (color de rareza)
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(1, 0, 0.2, 0)
        rarityLabel.Position = UDim2.new(0, 0, 0.3, 0)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = rarityDisplay
        rarityLabel.TextColor3 = rarityColor
        rarityLabel.TextScaled = true
        rarityLabel.Font = Enum.Font.GothamBlack
        rarityLabel.Parent = bg

        local rarityStroke = Instance.new("UIStroke")
        rarityStroke.Color = Color3.fromRGB(255, 255, 255)
        rarityStroke.Thickness = 0.8
        rarityStroke.Transparency = 0.75
        rarityStroke.Parent = rarityLabel

        -- Fila 3: Nivel (dorado) + Produccion (verde) usando RichText
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Name = "LevelLabel"
        levelLabel.Size = UDim2.new(1, 0, 0.2, 0)
        levelLabel.Position = UDim2.new(0, 0, 0.5, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.RichText = true
        levelLabel.Text = '<font color="' .. COLOR_LEVEL .. '">Lv.' .. level .. '</font><font color="' .. COLOR_SEPARATOR .. '">  |  </font><font color="' .. COLOR_MONEY .. '">+' .. currentRate .. '$/2s</font>'
        levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.Parent = bg

        -- Fila 4: Barra de progreso
        local levelBarBg = Instance.new("Frame")
        levelBarBg.Size = UDim2.new(0.9, 0, 0.08, 0)
        levelBarBg.Position = UDim2.new(0.05, 0, 0.73, 0)
        levelBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        levelBarBg.BorderSizePixel = 0
        levelBarBg.Parent = bg
        Instance.new("UICorner", levelBarBg).CornerRadius = UDim.new(0, 4)

        local levelBarFill = Instance.new("Frame")
        levelBarFill.Name = "LevelBarFill"
        levelBarFill.Size = UDim2.new(math.clamp(level / 100, 0.01, 1), 0, 1, 0)
        levelBarFill.BackgroundColor3 = rarityColor
        levelBarFill.BorderSizePixel = 0
        levelBarFill.Parent = levelBarBg
        Instance.new("UICorner", levelBarFill).CornerRadius = UDim.new(0, 4)

        -- Fila 5: Costo siguiente nivel (etiqueta gris + dinero verde)
        if level < 100 then
                local nextCost = ModelManager.getUpgradeCost(level)
                local nextLevelLabel = Instance.new("TextLabel")
                nextLevelLabel.Size = UDim2.new(1, 0, 0.17, 0)
                nextLevelLabel.Position = UDim2.new(0, 0, 0.83, 0)
                nextLevelLabel.BackgroundTransparency = 1
                nextLevelLabel.RichText = true
                nextLevelLabel.Text = '<font color="' .. COLOR_LABEL .. '">Siguiente: </font><font color="' .. COLOR_MONEY .. '">$' .. nextCost .. '</font>'
                nextLevelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nextLevelLabel.TextScaled = true
                nextLevelLabel.Font = Enum.Font.GothamBold
                nextLevelLabel.Parent = bg
        end
end

-- ============================================
-- Obtener la tasa de dinero
-- FIX: base * level garantiza incremento visible en cada nivel
-- Blanco: 1,2,3,4...  Azul: 3,6,9...  Morado: 10,20,30...
-- ============================================
function ModelManager.getMoneyRate(rarity, level)
        level = level or 1
        local base = rarityMoneyRate[rarity] or 1
        return base * level
end

-- ============================================
-- Calcular costo de mejora
-- ============================================
function ModelManager.getUpgradeCost(currentLevel)
        if currentLevel >= 100 then return math.huge end
        return math.floor(UPGRADE_BASE_COST * math.pow(currentLevel, 1.5))
end

-- ============================================
-- Crear PILA DE DINERO (solo dinero, separada del boton mejorar)
-- Moneda verde en el suelo, genera dinero, se recoge al caminar
-- ============================================
function ModelManager.createMoneyPile(pedestal, rarity, level)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then return nil end

        ModelManager.removeMoneyPile(pedestal)

        local pileX, pileZ = getForwardPosition(pedestal, 4)

        local rarityColor = rarityColors[rarity] or Color3.fromRGB(220, 220, 220)

        -- Moneda en el suelo
        local moneyPile = Instance.new("Part")
        moneyPile.Name = "MoneyPile"
        moneyPile.Size = Vector3.new(2.2, 0.3, 2.2)
        moneyPile.Shape = Enum.PartType.Cylinder
        moneyPile.Orientation = Vector3.new(0, 0, 90)
        moneyPile.Position = Vector3.new(pileX, 1.5, pileZ)
        moneyPile.Anchored = true
        moneyPile.CanCollide = false
        moneyPile.Material = Enum.Material.SmoothPlastic
        moneyPile.Color = MONEY_GREEN
        moneyPile.Transparency = 0.25
        moneyPile.Parent = pedestal

        local moneyValue = Instance.new("IntValue")
        moneyValue.Name = "MoneyValue"
        moneyValue.Value = 0
        moneyValue.Parent = moneyPile

        local rarityTag = Instance.new("StringValue")
        rarityTag.Name = "Rarity"
        rarityTag.Value = rarity
        rarityTag.Parent = moneyPile

        local levelTag = Instance.new("IntValue")
        levelTag.Name = "CharLevel"
        levelTag.Value = level or 1
        levelTag.Parent = moneyPile

        -- Crear CollectEvent ANTES del Touched para que setupMoneyPileEvents lo encuentre
        local collectEvent = Instance.new("BindableEvent")
        collectEvent.Name = "CollectEvent"
        collectEvent.Parent = moneyPile

        -- Billboard: Solo dinero (verde)
        local bb = Instance.new("BillboardGui")
        bb.Name = "MoneyGui"
        bb.Size = UDim2.new(3, 0, 0.8, 0)
        bb.StudsOffset = Vector3.new(0, 1.5, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = 40
        bb.Parent = moneyPile

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.4
        bg.BorderSizePixel = 0
        bg.Parent = bb
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

        local bgStroke = Instance.new("UIStroke")
        bgStroke.Color = MONEY_GREEN
        bgStroke.Thickness = 1.5
        bgStroke.Transparency = 0.3
        bgStroke.Parent = bg

        local moneyLabel = Instance.new("TextLabel")
        moneyLabel.Name = "MoneyLabel"
        moneyLabel.Size = UDim2.new(1, 0, 1, 0)
        moneyLabel.BackgroundTransparency = 1
        moneyLabel.Text = "$0"
        moneyLabel.TextColor3 = MONEY_GREEN_BRIGHT
        moneyLabel.TextScaled = true
        moneyLabel.Font = Enum.Font.GothamBlack
        moneyLabel.Parent = bg

        -- Recolectar al caminar sobre la moneda
        local touchDebounce = false
        moneyPile.Touched:Connect(function(hit)
                if touchDebounce then return end
                local character = hit.Parent
                if not character then return end
                local player = game:GetService("Players"):GetPlayerFromCharacter(character)
                if not player then return end

                local mv = moneyPile:FindFirstChild("MoneyValue")
                if not mv or mv.Value <= 0 then return end

                touchDebounce = true
                local amount = mv.Value
                mv.Value = 0

                local bbGui = moneyPile:FindFirstChild("MoneyGui")
                if bbGui then
                        local frame = bbGui:FindFirstChild("Frame")
                        if frame then
                                local ml = frame:FindFirstChild("MoneyLabel")
                                if ml then ml.Text = "$0" end
                        end
                end

                -- Disparar evento de recoleccion (ya existe, creado arriba)
                collectEvent:Fire(player, amount)

                task.wait(0.5)
                touchDebounce = false
        end)

        return moneyPile
end

-- ============================================
-- Crear BOTON MEJORAR (separado de la pila de dinero)
-- Click para subir nivel, muestra nivel y costo
-- Solo los numeros de dinero son verdes, lo demas usa otros colores
-- ============================================
function ModelManager.createUpgradeButton(pedestal, rarity, level)
        local platform = pedestal:FindFirstChild("Platform")
        if not platform then return nil end

        ModelManager.removeUpgradeButton(pedestal)

        local btnX, btnZ = getForwardPosition(pedestal, 7)
        local rarityColor = rarityColors[rarity] or Color3.fromRGB(220, 220, 220)
        local isMaxLevel = (level or 1) >= 100

        -- Boton visual
        local upgradeBtn = Instance.new("Part")
        upgradeBtn.Name = "UpgradeButton"
        upgradeBtn.Size = Vector3.new(1.8, 0.4, 1.8)
        upgradeBtn.Shape = Enum.PartType.Block
        upgradeBtn.Position = Vector3.new(btnX, 1.5, btnZ)
        upgradeBtn.Anchored = true
        upgradeBtn.CanCollide = false
        upgradeBtn.Material = Enum.Material.SmoothPlastic
        upgradeBtn.Color = rarityColor
        upgradeBtn.Transparency = 0.3
        upgradeBtn.Parent = pedestal

        -- Guardar datos
        local rarityTag = Instance.new("StringValue")
        rarityTag.Name = "Rarity"
        rarityTag.Value = rarity
        rarityTag.Parent = upgradeBtn

        local levelTag = Instance.new("IntValue")
        levelTag.Name = "CharLevel"
        levelTag.Value = level or 1
        levelTag.Parent = upgradeBtn

        -- ClickDetector
        if not isMaxLevel then
                local click = Instance.new("ClickDetector")
                click.Name = "UpgradeClick"
                click.MaxActivationDistance = 15
                click.Parent = upgradeBtn

                local upgradeEvent = Instance.new("BindableEvent")
                upgradeEvent.Name = "UpgradeEvent"
                upgradeEvent.Parent = upgradeBtn

                click.MouseClick:Connect(function(player)
                        upgradeEvent:Fire(player)
                end)
        end

        -- Billboard: Nivel + Costo + Click hint
        local bb = Instance.new("BillboardGui")
        bb.Name = "UpgradeGui"
        bb.Size = UDim2.new(3.5, 0, 1.5, 0)
        bb.StudsOffset = Vector3.new(0, 1.8, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = 40
        bb.Parent = upgradeBtn

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.4
        bg.BorderSizePixel = 0
        bg.Parent = bb
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

        local bgStroke = Instance.new("UIStroke")
        bgStroke.Color = Color3.fromRGB(100, 255, 100)
        bgStroke.Thickness = 1.5
        bgStroke.Transparency = 0.3
        bgStroke.Parent = bg

        -- Fila 1: Titulo MEJORAR (verde) o MAX (dorado)
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.Size = UDim2.new(1, 0, 0.35, 0)
        titleLabel.BackgroundTransparency = 1
        if isMaxLevel then
                titleLabel.Text = "MAX Lv.100"
                titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        else
                titleLabel.Text = "MEJORAR"
                titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.Parent = bg

        -- Fila 2: Nivel actual (amarillo/dorado para el numero, gris para etiqueta)
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Name = "LevelLabel"
        levelLabel.Size = UDim2.new(1, 0, 0.3, 0)
        levelLabel.Position = UDim2.new(0, 0, 0.35, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.RichText = true
        levelLabel.Text = '<font color="' .. COLOR_LABEL .. '">Nivel: </font><font color="' .. COLOR_LEVEL .. '">' .. (level or 1) .. '/100</font>'
        levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.Parent = bg

        -- Fila 3: Costo siguiente nivel (etiqueta gris, dinero verde)
        local costLabel = Instance.new("TextLabel")
        costLabel.Name = "CostLabel"
        costLabel.Size = UDim2.new(1, 0, 0.3, 0)
        costLabel.Position = UDim2.new(0, 0, 0.65, 0)
        costLabel.BackgroundTransparency = 1
        if isMaxLevel then
                costLabel.RichText = true
                costLabel.Text = '<font color="' .. COLOR_MAX .. '">Nivel maximo!</font>'
                costLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        else
                local cost = ModelManager.getUpgradeCost(level or 1)
                costLabel.RichText = true
                costLabel.Text = '<font color="' .. COLOR_LABEL .. '">Costo: </font><font color="' .. COLOR_MONEY .. '">$' .. cost .. '</font>'
                costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        costLabel.TextScaled = true
        costLabel.Font = Enum.Font.GothamBold
        costLabel.Parent = bg

        return upgradeBtn
end

-- ============================================
-- Actualizar UI del UpgradeButton despues de mejorar
-- Solo los numeros de dinero son verdes, lo demas usa otros colores
-- ============================================
function ModelManager.updateUpgradeButtonUI(pedestal, rarity, level)
        local btn = pedestal:FindFirstChild("UpgradeButton")
        if not btn then return end

        local isMaxLevel = level >= 100
        local cost = ModelManager.getUpgradeCost(level)

        local bb = btn:FindFirstChild("UpgradeGui")
        if not bb then return end
        local bg = bb:FindFirstChild("Frame")
        if not bg then return end

        local titleLabel = bg:FindFirstChild("TitleLabel")
        if titleLabel then
                if isMaxLevel then
                        titleLabel.Text = "MAX Lv.100"
                        titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                else
                        titleLabel.Text = "MEJORAR"
                        titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                end
        end

        local levelLabel = bg:FindFirstChild("LevelLabel")
        if levelLabel then
                levelLabel.RichText = true
                levelLabel.Text = '<font color="' .. COLOR_LABEL .. '">Nivel: </font><font color="' .. COLOR_LEVEL .. '">' .. level .. '/100</font>'
        end

        local costLabel = bg:FindFirstChild("CostLabel")
        if costLabel then
                if isMaxLevel then
                        costLabel.RichText = true
                        costLabel.Text = '<font color="' .. COLOR_MAX .. '">Nivel maximo!</font>'
                else
                        costLabel.RichText = true
                        costLabel.Text = '<font color="' .. COLOR_LABEL .. '">Costo: </font><font color="' .. COLOR_MONEY .. '">$' .. cost .. '</font>'
                end
        end

        -- Si llego a max, quitar ClickDetector
        if isMaxLevel then
                local click = btn:FindFirstChild("UpgradeClick")
                if click then click:Destroy() end
        end
end

-- ============================================
-- Eliminar pila de dinero
-- ============================================
function ModelManager.removeMoneyPile(pedestal)
        local old = pedestal:FindFirstChild("MoneyPile")
        if old then old:Destroy() end
end

-- ============================================
-- Eliminar boton mejorar
-- ============================================
function ModelManager.removeUpgradeButton(pedestal)
        local old = pedestal:FindFirstChild("UpgradeButton")
        if old then old:Destroy() end
end

-- ============================================
-- Limpiar pedestal
-- ============================================
function ModelManager.clearPedestal(pedestal)
        local platform = pedestal:FindFirstChild("Platform")
        if platform then
                local oldName = platform:FindFirstChild("CharNameGui")
                if oldName then oldName:Destroy() end
                local oldLevel = platform:FindFirstChild("CharLevelGui")
                if oldLevel then oldLevel:Destroy() end
                local oldInfo = platform:FindFirstChild("CharInfoGui")
                if oldInfo then oldInfo:Destroy() end
        end

        for _, child in ipairs(pedestal:GetChildren()) do
                if child.Name ~= "Platform" and child.Name ~= "PedestalColumn" then
                        child:Destroy()
                end
        end

        ModelManager.showEmptyLabel(pedestal)
end

return ModelManager

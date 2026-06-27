-- ============================================
-- BaseUpgradeManager (ModuleScript) - ServerStorage/ServerModules
-- Maneja la mejora de la base:
-- - Crea el boton "MEJORAR BASE" en el centro de la base
-- - Al activarse, muestra el segundo piso + escalera + pedestales
-- - Costo: 1M (ajustable via BaseManager.getUpgradeCost)
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseUpgradeManager = {}

local COLOR_GOLD = Color3.fromRGB(255, 215, 0)
local COLOR_GOLD_BRIGHT = Color3.fromRGB(255, 235, 100)
local COLOR_GREEN = Color3.fromRGB(76, 175, 80)
local COLOR_GREEN_BRIGHT = Color3.fromRGB(129, 199, 132)

-- Requiere ModelManager para formatMoney
local ServerStorage = game:GetService("ServerStorage")
local ModelManager = require(ServerStorage.ServerModules.ModelManager)
local BaseManager = require(ServerStorage.ServerModules.BaseManager)

-- ============================================
-- Crear el boton de mejorar base en el centro de la base
-- ============================================
function BaseUpgradeManager.createUpgradeButton(base, player)
        if not base then return nil end

        -- Limpiar boton anterior si existe
        BaseUpgradeManager.removeUpgradeButton(base)

        local baseLevel = BaseManager.getBaseLevel(player.UserId)
        local baseFloor = base:FindFirstChild("BaseFloor")
        if not baseFloor then return nil end

        local baseX = baseFloor.Position.X
        -- Boton en el centro de la base, sobre el suelo
        local btnPos = Vector3.new(baseX, 1.5, 95)

        local upgradeBtn = Instance.new("Part")
        upgradeBtn.Name = "BaseUpgradeButton"
        upgradeBtn.Size = Vector3.new(4, 0.5, 4)
        upgradeBtn.Position = btnPos
        upgradeBtn.Anchored = true
        upgradeBtn.CanCollide = false
        upgradeBtn.Material = Enum.Material.SmoothPlastic
        upgradeBtn.Color = COLOR_GOLD
        upgradeBtn.Transparency = 0.2
        upgradeBtn.Parent = base

        local levelTag = Instance.new("IntValue")
        levelTag.Name = "BaseLevel"
        levelTag.Value = baseLevel
        levelTag.Parent = upgradeBtn

        local ownerTag = Instance.new("ObjectValue")
        ownerTag.Name = "Owner"
        ownerTag.Value = player
        ownerTag.Parent = upgradeBtn

        local click = Instance.new("ClickDetector")
        click.Name = "UpgradeClick"
        click.MaxActivationDistance = 12
        click.Parent = upgradeBtn

        local upgradeEvent = Instance.new("BindableEvent")
        upgradeEvent.Name = "BaseUpgradeEvent"
        upgradeEvent.Parent = upgradeBtn

        click.MouseClick:Connect(function(clickingPlayer)
                if clickingPlayer == player then
                        upgradeEvent:Fire(clickingPlayer)
                end
        end)

        -- Billboard con info
        local bb = Instance.new("BillboardGui")
        bb.Name = "UpgradeGui"
        bb.Size = UDim2.new(5, 0, 2.5, 0)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = 60
        bb.Parent = upgradeBtn

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.4
        bg.BorderSizePixel = 0
        bg.Parent = bb
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Color = COLOR_GOLD
        stroke.Thickness = 2
        stroke.Transparency = 0.2
        stroke.Parent = bg

        -- Titulo
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.Size = UDim2.new(1, 0, 0.3, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "MEJORAR BASE"
        titleLabel.TextColor3 = COLOR_GOLD_BRIGHT
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.Parent = bg

        -- Nivel actual
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Name = "LevelLabel"
        levelLabel.Size = UDim2.new(1, 0, 0.25, 0)
        levelLabel.Position = UDim2.new(0, 0, 0.3, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.RichText = true
        levelLabel.Text = '<font color="#B0BEC5">Nivel: </font><font color="#FFD700">' .. baseLevel .. '/2</font>'
        levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.Parent = bg

        -- Costo
        local costLabel = Instance.new("TextLabel")
        costLabel.Name = "CostLabel"
        costLabel.Size = UDim2.new(1, 0, 0.25, 0)
        costLabel.Position = UDim2.new(0, 0, 0.55, 0)
        costLabel.BackgroundTransparency = 1
        costLabel.RichText = true
        local cost = BaseManager.getUpgradeCost(baseLevel)
        costLabel.Text = '<font color="#B0BEC5">Costo: </font><font color="#81C784">$' .. ModelManager.formatMoney(cost) .. '</font>'
        costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        costLabel.TextScaled = true
        costLabel.Font = Enum.Font.GothamBold
        costLabel.Parent = bg

        -- Hint de tecla
        local hintLabel = Instance.new("TextLabel")
        hintLabel.Name = "HintLabel"
        hintLabel.Size = UDim2.new(1, 0, 0.2, 0)
        hintLabel.Position = UDim2.new(0, 0, 0.8, 0)
        hintLabel.BackgroundTransparency = 1
        hintLabel.RichText = true
        hintLabel.Text = '<font color="#B0BEC5">Presiona </font><font color="#FFD700">H</font><font color="#B0BEC5"> cerca</font>'
        hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        hintLabel.TextScaled = true
        hintLabel.Font = Enum.Font.GothamBold
        hintLabel.Parent = bg

        return upgradeBtn
end

-- ============================================
-- Actualizar el UI del boton (despues de mejorar)
-- ============================================
function BaseUpgradeManager.updateButtonUI(base, baseLevel)
        local btn = base:FindFirstChild("BaseUpgradeButton")
        if not btn then return end

        local bb = btn:FindFirstChild("UpgradeGui")
        if not bb then return end
        local bg = bb:FindFirstChild("Frame")
        if not bg then return end

        local levelLabel = bg:FindFirstChild("LevelLabel")
        if levelLabel then
                if baseLevel >= 2 then
                        levelLabel.RichText = true
                        levelLabel.Text = '<font color="#FFD700">MAX NIVEL 2!</font>'
                else
                        levelLabel.RichText = true
                        levelLabel.Text = '<font color="#B0BEC5">Nivel: </font><font color="#FFD700">' .. baseLevel .. '/2</font>'
                end
        end

        local costLabel = bg:FindFirstChild("CostLabel")
        if costLabel then
                if baseLevel >= 2 then
                        costLabel.RichText = true
                        costLabel.Text = '<font color="#FFD700">Base mejorada!</font>'
                else
                        local cost = BaseManager.getUpgradeCost(baseLevel)
                        costLabel.RichText = true
                        costLabel.Text = '<font color="#B0BEC5">Costo: </font><font color="#81C784">$' .. ModelManager.formatMoney(cost) .. '</font>'
                end
        end

        -- Si llego a max, quitar ClickDetector
        if baseLevel >= 2 then
                local click = btn:FindFirstChild("UpgradeClick")
                if click then click:Destroy() end
        end
end

-- ============================================
-- Activar el segundo piso: hacer visibles todas las partes
-- ============================================
function BaseUpgradeManager.activateFloor2(base)
        local floor2 = base:FindFirstChild("Floor2")
        if not floor2 then return end

        for _, desc in ipairs(floor2:GetDescendants()) do
                if desc:IsA("BasePart") then
                        desc.Transparency = 0
                        desc.CanCollide = true
                        desc.CanQuery = true
                end
        end
end

-- ============================================
-- Eliminar el boton de mejora
-- ============================================
function BaseUpgradeManager.removeUpgradeButton(base)
        local old = base:FindFirstChild("BaseUpgradeButton")
        if old then old:Destroy() end
        -- Tambien limpiar boton de teletransporte
        BaseUpgradeManager.removeTeleportButton(base)
end

-- ============================================
-- Crear boton de TELETRANSPORTE (al lado del boton de mejorar)
-- Solo aparece cuando la base esta mejorada (nivel 2)
-- ============================================
function BaseUpgradeManager.createTeleportButton(base, player)
        if not base then return nil end

        BaseUpgradeManager.removeTeleportButton(base)

        local baseLevel = BaseManager.getBaseLevel(player.UserId)
        if baseLevel < 2 then return nil end -- Solo si ya mejoro

        local baseFloor = base:FindFirstChild("BaseFloor")
        if not baseFloor then return nil end

        local baseX = baseFloor.Position.X
        -- Boton al lado del de mejorar (5 studs a la derecha)
        local btnPos = Vector3.new(baseX + 6, 1.5, 95)

        local teleBtn = Instance.new("Part")
        teleBtn.Name = "TeleportButton"
        teleBtn.Size = Vector3.new(4, 0.5, 4)
        teleBtn.Position = btnPos
        teleBtn.Anchored = true
        teleBtn.CanCollide = false
        teleBtn.Material = Enum.Material.SmoothPlastic
        teleBtn.Color = Color3.fromRGB(100, 150, 255) -- Azul
        teleBtn.Transparency = 0.2
        teleBtn.Parent = base

        local ownerTag = Instance.new("ObjectValue")
        ownerTag.Name = "Owner"
        ownerTag.Value = player
        ownerTag.Parent = teleBtn

        local click = Instance.new("ClickDetector")
        click.Name = "TeleportClick"
        click.MaxActivationDistance = 12
        click.Parent = teleBtn

        local teleEvent = Instance.new("BindableEvent")
        teleEvent.Name = "TeleportEvent"
        teleEvent.Parent = teleBtn

        click.MouseClick:Connect(function(clickingPlayer)
                if clickingPlayer == player then
                        teleEvent:Fire(clickingPlayer)
                end
        end)

        -- Billboard con info
        local bb = Instance.new("BillboardGui")
        bb.Name = "TeleportGui"
        bb.Size = UDim2.new(4, 0, 2, 0)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = 60
        bb.Parent = teleBtn

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.4
        bg.BorderSizePixel = 0
        bg.Parent = bb
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(100, 150, 255)
        stroke.Thickness = 2
        stroke.Transparency = 0.2
        stroke.Parent = bg

        -- Titulo
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, 0, 0.35, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "TELETRANSPORTE"
        titleLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.Parent = bg

        -- Subtitulo
        local subLabel = Instance.new("TextLabel")
        subLabel.Size = UDim2.new(1, 0, 0.3, 0)
        subLabel.Position = UDim2.new(0, 0, 0.35, 0)
        subLabel.BackgroundTransparency = 1
        subLabel.RichText = true
        subLabel.Text = '<font color="#B0BEC5">Cambio de piso</font>'
        subLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        subLabel.TextScaled = true
        subLabel.Font = Enum.Font.GothamBold
        subLabel.Parent = bg

        -- Hint de tecla
        local hintLabel = Instance.new("TextLabel")
        hintLabel.Size = UDim2.new(1, 0, 0.35, 0)
        hintLabel.Position = UDim2.new(0, 0, 0.65, 0)
        hintLabel.BackgroundTransparency = 1
        hintLabel.RichText = true
        hintLabel.Text = '<font color="#B0BEC5">Presiona </font><font color="#64B5FF">J</font>'
        hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        hintLabel.TextScaled = true
        hintLabel.Font = Enum.Font.GothamBold
        hintLabel.Parent = bg

        return teleBtn
end

-- ============================================
-- Eliminar boton de teletransporte
-- ============================================
function BaseUpgradeManager.removeTeleportButton(base)
        local old = base:FindFirstChild("TeleportButton")
        if old then old:Destroy() end
end

return BaseUpgradeManager


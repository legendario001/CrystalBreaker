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
        bb.Size = UDim2.new(13.5, 0, 6.75, 0)
        bb.StudsOffset = Vector3.new(0, 7, 0)
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
        levelLabel.Size = UDim2.new(1, 0, 0.2, 0)
        levelLabel.Position = UDim2.new(0, 0, 0.25, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.RichText = true
        levelLabel.Text = '<font color="#B0BEC5">Nivel: </font><font color="#FFD700">' .. baseLevel .. '/5</font>'
        levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.Parent = bg

        -- Costo
        local costLabel = Instance.new("TextLabel")
        costLabel.Name = "CostLabel"
        costLabel.Size = UDim2.new(1, 0, 0.2, 0)
        costLabel.Position = UDim2.new(0, 0, 0.45, 0)
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
        hintLabel.Size = UDim2.new(1, 0, 0.25, 0)
        hintLabel.Position = UDim2.new(0, 0, 0.7, 0)
        hintLabel.BackgroundTransparency = 1
        hintLabel.RichText = true
        hintLabel.Text = '<font color="#FFFFFF">Presiona </font><font color="#00A2FF"><b>[ H ]</b></font><font color="#FFFFFF"> para mejorar</font>'
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
                if baseLevel >= 5 then
                        levelLabel.RichText = true
                        levelLabel.Text = '<font color="#FFD700">MAX NIVEL 5!</font>'
                else
                        levelLabel.RichText = true
                        levelLabel.Text = '<font color="#B0BEC5">Nivel: </font><font color="#FFD700">' .. baseLevel .. '/5</font>'
                end
        end

        local costLabel = bg:FindFirstChild("CostLabel")
        if costLabel then
                if baseLevel >= 5 then
                        costLabel.RichText = true
                        costLabel.Text = '<font color="#FFD700">Base mejorada!</font>'
                else
                        local cost = BaseManager.getUpgradeCost(baseLevel)
                        costLabel.RichText = true
                        costLabel.Text = '<font color="#B0BEC5">Costo: </font><font color="#81C784">$' .. ModelManager.formatMoney(cost) .. '</font>'
                end
        end

        -- Si llego a max, quitar ClickDetector
        if baseLevel >= 5 then
                local click = btn:FindFirstChild("UpgradeClick")
                if click then click:Destroy() end
        end
end

-- ============================================
-- Activar un piso (hacer visibles todas sus partes)
-- Funciona para Floor2, Floor3, etc.
-- Respeta la transparencia original de las decoraciones de nube
-- ============================================
function BaseUpgradeManager.activateFloor(base, floorNum)
        local floor = base:FindFirstChild("Floor" .. floorNum)
        if not floor then return end

        for _, desc in ipairs(floor:GetDescendants()) do
                if desc:IsA("BasePart") then
                        -- Restaurar transparencia: partes con nombre "CloudDecor" o suelos
                        -- tienen transparencia ligera para efecto nube
                        local name = desc.Name
                        if string.find(name, "CloudDecor") then
                                desc.Transparency = 0.15
                        elseif string.find(name, "Front") or string.find(name, "Back") then
                                -- Suelos del piso: ligera transparencia estilo nube
                                desc.Transparency = 0.05
                        else
                                -- Barandas, pedestales, escalera: opacos
                                desc.Transparency = 0
                        end
                        desc.CanCollide = true
                        desc.CanQuery = true
                end
        end
end

-- Activar segundo piso (compatibilidad)
function BaseUpgradeManager.activateFloor2(base)
        BaseUpgradeManager.activateFloor(base, 2)
end

-- Activar tercer piso
function BaseUpgradeManager.activateFloor3(base)
        BaseUpgradeManager.activateFloor(base, 3)
end

-- Activar cuarto piso
function BaseUpgradeManager.activateFloor4(base)
        BaseUpgradeManager.activateFloor(base, 4)
end

-- Activar quinto piso
function BaseUpgradeManager.activateFloor5(base)
        BaseUpgradeManager.activateFloor(base, 5)
end

-- ============================================
-- Eliminar el boton de mejora
-- ============================================
function BaseUpgradeManager.removeUpgradeButton(base)
        local old = base:FindFirstChild("BaseUpgradeButton")
        if old then old:Destroy() end
end

return BaseUpgradeManager







-- ============================================
-- InvestorSystem (LocalScript) - StarterPlayerScripts
-- UI del sistema de Inversionistas (estilo Sell Lemons)
-- Muestra: inversionistas actuales, ganaria al renacer, multiplicador, boton renacer
-- Tematica: hombre millonario (en lugar de alien)
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local InvestorRequest = ReplicatedStorage:WaitForChild("InvestorRequest", 15)
local InvestorUpdate = ReplicatedStorage:WaitForChild("InvestorUpdate", 15)

-- ============================================
-- ScreenGui principal
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InvestorSystemGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100 -- encima de otros paneles
screenGui.Parent = playerGui

-- ============================================
-- Panel principal (modal) - RESPONSIVE (igual que shop/rebirth)
-- ============================================
local panel = Instance.new("Frame")
panel.Name = "InvestorPanel"
panel.Size = UDim2.new(0.9, 0, 0.75, 0)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)

local sizeConstraint = Instance.new("UISizeConstraint", panel)
sizeConstraint.MaxSize = Vector2.new(500, 600)

local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(255, 215, 0)  -- dorado
panelStroke.Thickness = 4

-- ============================================
-- Titulo
-- ============================================
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 0, 50)
titleLabel.Position = UDim2.new(0, 20, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "💰 INVERSIONISTAS"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Parent = panel

-- ============================================
-- Boton cerrar (X) - SIEMPRE visible
-- ============================================
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -10, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 22
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 10
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.Active = true

-- ============================================
-- Subtitulo / descripcion
-- ============================================
local descLabel = Instance.new("TextLabel")
descLabel.Size = UDim2.new(1, -40, 0, 50)
descLabel.Position = UDim2.new(0, 20, 0, 70)
descLabel.BackgroundTransparency = 1
descLabel.Text = "Los inversionistas te dan +0.5% de ganancias permanentes por cada uno. Renace para obtener mas."
descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
descLabel.TextWrapped = true
descLabel.TextScaled = true
descLabel.Font = Enum.Font.GothamMedium
descLabel.Parent = panel

-- ============================================
-- Bloque 1: Bonus actual (verde)
-- ============================================
local bonusFrame = Instance.new("Frame")
bonusFrame.Name = "BonusFrame"
bonusFrame.Size = UDim2.new(1, -40, 0, 60)
bonusFrame.Position = UDim2.new(0, 20, 0, 130)
bonusFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
bonusFrame.BackgroundTransparency = 0.2
bonusFrame.BorderSizePixel = 0
bonusFrame.Parent = panel
Instance.new("UICorner", bonusFrame).CornerRadius = UDim.new(0, 10)

local bonusStroke = Instance.new("UIStroke", bonusFrame)
bonusStroke.Color = Color3.fromRGB(100, 255, 100)
bonusStroke.Thickness = 2

local bonusLabel = Instance.new("TextLabel")
bonusLabel.Name = "BonusLabel"
bonusLabel.Size = UDim2.new(1, -20, 1, 0)
bonusLabel.Position = UDim2.new(0, 10, 0, 0)
bonusLabel.BackgroundTransparency = 1
bonusLabel.Text = "Multiplicador actual: x1"
bonusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
bonusLabel.TextScaled = true
bonusLabel.Font = Enum.Font.GothamBold
bonusLabel.Parent = bonusFrame

-- ============================================
-- Bloque 2: Inversionistas actuales
-- ============================================
local currentFrame = Instance.new("Frame")
currentFrame.Name = "CurrentFrame"
currentFrame.Size = UDim2.new(1, -40, 0, 60)
currentFrame.Position = UDim2.new(0, 20, 0, 200)
currentFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
currentFrame.BackgroundTransparency = 0.2
currentFrame.BorderSizePixel = 0
currentFrame.Parent = panel
Instance.new("UICorner", currentFrame).CornerRadius = UDim.new(0, 10)

local currentStroke = Instance.new("UIStroke", currentFrame)
currentStroke.Color = Color3.fromRGB(255, 215, 0)
currentStroke.Thickness = 2

local currentLabel = Instance.new("TextLabel")
currentLabel.Name = "CurrentLabel"
currentLabel.Size = UDim2.new(1, -20, 1, 0)
currentLabel.Position = UDim2.new(0, 10, 0, 0)
currentLabel.BackgroundTransparency = 1
currentLabel.Text = "Inversionistas: 0"
currentLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
currentLabel.TextScaled = true
currentLabel.Font = Enum.Font.GothamBold
currentLabel.Parent = currentFrame

-- ============================================
-- Bloque 3: Ganarias al renacer (destacado)
-- ============================================
local gainFrame = Instance.new("Frame")
gainFrame.Name = "GainFrame"
gainFrame.Size = UDim2.new(1, -40, 0, 70)
gainFrame.Position = UDim2.new(0, 20, 0, 270)
gainFrame.BackgroundColor3 = Color3.fromRGB(40, 30, 15)
gainFrame.BackgroundTransparency = 0.1
gainFrame.BorderSizePixel = 0
gainFrame.Parent = panel
Instance.new("UICorner", gainFrame).CornerRadius = UDim.new(0, 10)

local gainStroke = Instance.new("UIStroke", gainFrame)
gainStroke.Color = Color3.fromRGB(255, 215, 0)
gainStroke.Thickness = 3

local gainLabel = Instance.new("TextLabel")
gainLabel.Name = "GainLabel"
gainLabel.Size = UDim2.new(1, -20, 1, 0)
gainLabel.Position = UDim2.new(0, 10, 0, 0)
gainLabel.BackgroundTransparency = 1
gainLabel.Text = "Renacer para obtener: 0 inversionistas"
gainLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
gainLabel.TextScaled = true
gainLabel.Font = Enum.Font.GothamBlack
gainLabel.Parent = gainFrame

-- ============================================
-- Bloque 4: Progreso actual (dinero generado esta vida)
-- ============================================
local progressFrame = Instance.new("Frame")
progressFrame.Name = "ProgressFrame"
progressFrame.Size = UDim2.new(1, -40, 0, 50)
progressFrame.Position = UDim2.new(0, 20, 0, 350)
progressFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
progressFrame.BackgroundTransparency = 0.3
progressFrame.BorderSizePixel = 0
progressFrame.Parent = panel
Instance.new("UICorner", progressFrame).CornerRadius = UDim.new(0, 10)

local progressStroke = Instance.new("UIStroke", progressFrame)
progressStroke.Color = Color3.fromRGB(150, 150, 150)
progressStroke.Thickness = 1.5

local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "ProgressLabel"
progressLabel.Size = UDim2.new(1, -20, 1, 0)
progressLabel.Position = UDim2.new(0, 10, 0, 0)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Dinero generado: $0"
progressLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
progressLabel.TextScaled = true
progressLabel.Font = Enum.Font.GothamMedium
progressLabel.Parent = progressFrame

-- ============================================
-- Boton RENACER (grande, dorado, anclado al fondo)
-- ============================================
local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Name = "RebirthBtn"
rebirthBtn.Size = UDim2.new(1, -40, 0, 55)
rebirthBtn.Position = UDim2.new(0, 20, 1, -65)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
rebirthBtn.BorderSizePixel = 0
rebirthBtn.Text = "NECESITAS MAS DINERO"
rebirthBtn.Font = Enum.Font.GothamBlack
rebirthBtn.TextSize = 22
rebirthBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
rebirthBtn.Parent = panel
Instance.new("UICorner", rebirthBtn).CornerRadius = UDim.new(0, 12)

local rebirthStroke = Instance.new("UIStroke", rebirthBtn)
rebirthStroke.Color = Color3.fromRGB(100, 100, 100)
rebirthStroke.Thickness = 2

-- ============================================
-- Formato de dinero (reutiliza el mismo formato del contador)
-- ============================================
local function formatMoney(amount)
        amount = amount or 0
        local suffixes = {
                {1e15, "Cuatrillones"},
                {1e12, "Trillones"},
                {1e9, "Billones"},
                {1e6, "Millones"},
                {1e3, "Mil"},
        }
        for _, tier in ipairs(suffixes) do
                if amount >= tier[1] then
                        local v = amount / tier[1]
                        if v >= 100 then
                                return string.format("%.1f %s", v, tier[2])
                        elseif v >= 10 then
                                return string.format("%.2f %s", v, tier[2])
                        else
                                return string.format("%.3f %s", v, tier[2])
                        end
                end
        end
        return tostring(math.floor(amount))
end

-- ============================================
-- Estado local
-- ============================================
local currentInfo = nil
local isProcessing = false

-- ============================================
-- Actualizar UI con la info del servidor
-- ============================================
local function updateUI(info)
        if not info then return end
        currentInfo = info

        -- Multiplicador actual
        local multStr = string.format("%.2f", info.currentMultiplier)
        bonusLabel.Text = "Multiplicador actual: x" .. multStr

        -- Inversionistas actuales
        currentLabel.Text = "Inversionistas: " .. tostring(info.currentInvestors)

        -- Ganarias al renacer
        if info.investorsGained > 0 then
                gainLabel.Text = "Renacer para obtener: +" .. tostring(info.investorsGained) .. " inversionistas"
                gainLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        else
                gainLabel.Text = "Genera mas dinero para obtener inversionistas"
                gainLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end

        -- Progreso (dinero generado esta vida)
        progressLabel.Text = "Dinero generado: $" .. formatMoney(info.totalMoneyEarnedThisLife)

        -- Boton renacer
        if info.canRebirth and info.investorsGained > 0 then
                rebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                rebirthBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
                rebirthBtn.Text = "🔄 RENACER (+x" .. string.format("%.2f", info.nextMultiplier) .. ")"
                rebirthStroke.Color = Color3.fromRGB(255, 240, 100)
                rebirthStroke.Thickness = 3
                rebirthBtn.Active = true
        else
                rebirthBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                rebirthBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
                rebirthBtn.Text = "NECESITAS MAS DINERO"
                rebirthStroke.Color = Color3.fromRGB(100, 100, 100)
                rebirthStroke.Thickness = 2
                rebirthBtn.Active = false
        end
end

-- ============================================
-- Escuchar actualizaciones del servidor
-- ============================================
if InvestorUpdate then
        InvestorUpdate.OnClientEvent:Connect(function(info)
                updateUI(info)
        end)
end

-- ============================================
-- Abrir / cerrar panel
-- ============================================
local function openPanel()
        panel.Visible = true
        panel.Size = UDim2.new(0, 0, 0, 0)
        local tween = TweenService:Create(panel,
                TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.9, 0, 0.75, 0)}
        )
        tween:Play()
        -- Pedir info actualizada al servidor
        if InvestorRequest then
                InvestorRequest:FireServer("getInfo")
        end
        -- Polling cada 2s mientras el panel este abierto
        task.spawn(function()
                while panel.Visible do
                        task.wait(2)
                        if panel.Visible and InvestorRequest then
                                InvestorRequest:FireServer("getInfo")
                        end
                end
        end)
end

local function closePanel()
        local tween = TweenService:Create(panel,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 0, 0, 0)}
        )
        tween:Play()
        tween.Completed:Connect(function()
                panel.Visible = false
        end)
end

closeBtn.MouseButton1Click:Connect(closePanel)

UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
                closePanel()
        end
end)

-- ============================================
-- Boton RENACER
-- ============================================
rebirthBtn.MouseButton1Click:Connect(function()
        if isProcessing then return end
        if not currentInfo or not currentInfo.canRebirth then return end

        isProcessing = true
        rebirthBtn.Text = "PROCESANDO..."

        if InvestorRequest then
                InvestorRequest:FireServer("rebirth")
        end

        task.delay(5, function()
                isProcessing = false
        end)
end)

-- ============================================
-- Polling inicial al entrar
-- ============================================
task.spawn(function()
        task.wait(3)
        if InvestorRequest then
                InvestorRequest:FireServer("sync")
        end
end)

print("[InvestorSystem] UI de Inversionistas cargada")

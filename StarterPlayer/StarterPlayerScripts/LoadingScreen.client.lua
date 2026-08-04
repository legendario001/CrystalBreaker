-- ============================================
-- LoadingScreen (LocalScript) - StarterPlayer/StarterPlayerScripts
-- Muestra un mensaje de carga mientras se restauran los brainrots del jugador
-- para evitar que coloque brainrots nuevos que se sobreescribirian con los guardados
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Esperar a que el RemoteEvent LoadingState exista
local loadingEvent
local maxWait = 10
local elapsed = 0
while not loadingEvent and elapsed < maxWait do
        loadingEvent = ReplicatedStorage:FindFirstChild("LoadingState")
        if not loadingEvent then
                task.wait(0.2)
                elapsed = elapsed + 0.2
        end
end

if not loadingEvent then
        warn("[LoadingScreen] No se encontro RemoteEvent LoadingState despues de " .. maxWait .. "s")
        return
end

-- ============================================
-- Crear UI de carga
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingBrainrotsGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 9999 -- siempre arriba de todo
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Fondo semi-transparente (no bloquea la vista pero indica carga)
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.new(0.45, 0, 0.16, 0)
bg.Position = UDim2.new(0.5, 0, 0.78, 0) -- abajo-centro (no tapar HUD principal)
bg.AnchorPoint = Vector2.new(0.5, 0.5)
bg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
bg.BackgroundTransparency = 0.15
bg.BorderSizePixel = 0
bg.Parent = screenGui

-- Borde dorado
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = bg

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 200, 60)
stroke.Thickness = 2.5
stroke.Transparency = 0.1
stroke.Parent = bg

-- Contenedor interno
local innerPadding = Instance.new("UIPadding")
innerPadding.PaddingLeft = UDim.new(0, 16)
innerPadding.PaddingRight = UDim.new(0, 16)
innerPadding.PaddingTop = UDim.new(0, 8)
innerPadding.PaddingBottom = UDim.new(0, 8)
innerPadding.Parent = bg

-- Spinner (3 puntos animados)
local spinnerFrame = Instance.new("Frame")
spinnerFrame.Name = "Spinner"
spinnerFrame.Size = UDim2.new(0, 24, 0, 24)
spinnerFrame.Position = UDim2.new(0, 0, 0.5, 0)
spinnerFrame.AnchorPoint = Vector2.new(0, 0.5)
spinnerFrame.BackgroundTransparency = 1
spinnerFrame.Parent = bg

local dots = {}
for i = 1, 3 do
        local dot = Instance.new("Frame")
        dot.Name = "Dot" .. i
        dot.Size = UDim2.new(0, 8, 0, 8)
        dot.Position = UDim2.new(0, (i - 1) * 9, 0.5, 0)
        dot.AnchorPoint = Vector2.new(0, 0.5)
        dot.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
        dot.BorderSizePixel = 0
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot
        dot.Parent = spinnerFrame
        dots[i] = dot
end

-- Texto de carga
local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "Message"
messageLabel.Size = UDim2.new(1, -32, 1, 0)
messageLabel.Position = UDim2.new(0, 32, 0, 0)
messageLabel.BackgroundTransparency = 1
messageLabel.Font = Enum.Font.GothamBold
messageLabel.TextSize = 16
messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.TextYAlignment = Enum.TextYAlignment.Center
messageLabel.Text = "Cargando tus brainrots..."
messageLabel.Parent = bg

-- Subtexto de ayuda
local subLabel = Instance.new("TextLabel")
subLabel.Name = "SubText"
subLabel.Size = UDim2.new(1, -32, 0, 14)
subLabel.Position = UDim2.new(0, 32, 1, -16)
subLabel.BackgroundTransparency = 1
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 11
subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
subLabel.TextTransparency = 0.3
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.TextYAlignment = Enum.TextYAlignment.Center
subLabel.Text = "No coloques brainrots nuevos aun"
subLabel.Parent = bg

-- ============================================
-- Animacion del spinner (3 puntos que parpadean)
-- ============================================
local spinnerRunning = false
local spinnerThread = nil

local function startSpinner()
        if spinnerRunning then return end
        spinnerRunning = true
        spinnerThread = task.spawn(function()
                while spinnerRunning do
                        for i = 1, 3 do
                                if not spinnerRunning then break end
                                dots[i].BackgroundColor3 = Color3.fromRGB(255, 230, 130)
                                task.wait(0.15)
                                dots[i].BackgroundColor3 = Color3.fromRGB(255, 200, 60)
                        end
                end
        end)
end

local function stopSpinner()
        spinnerRunning = false
        for i = 1, 3 do
                if dots[i] then
                        dots[i].BackgroundColor3 = Color3.fromRGB(255, 200, 60)
                end
        end
end

-- ============================================
-- Manejar eventos del servidor
-- ============================================
local fadeInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

loadingEvent.OnClientEvent:Connect(function(isLoading, message)
        if isLoading then
                messageLabel.Text = message or "Cargando tus brainrots..."
                screenGui.Enabled = true
                bg.BackgroundTransparency = 1
                bg.Size = UDim2.new(0.4, 0, 0.14, 0)
                -- Fade in
                TweenService:Create(bg, fadeInfo, {BackgroundTransparency = 0.15, Size = UDim2.new(0.45, 0, 0.16, 0)}):Play()
                startSpinner()
        else
                -- Fade out
                local tween = TweenService:Create(bg, fadeInfo, {BackgroundTransparency = 1, Size = UDim2.new(0.4, 0, 0.14, 0)})
                tween:Play()
                tween.Completed:Connect(function()
                        screenGui.Enabled = false
                        stopSpinner()
                end)
        end
end)

print("[LoadingScreen] Script cargado, esperando eventos del servidor")

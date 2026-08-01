-- ============================================
-- EventUI (LocalScript) - StarterPlayerScripts
-- Timer permanente + anuncios de eventos
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EventAnnouncement = ReplicatedStorage:WaitForChild("EventAnnouncement", 15)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EventUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ============================================
-- Timer permanente (arriba centro)
-- ============================================
local timerFrame = Instance.new("Frame")
timerFrame.Name = "TimerFrame"
timerFrame.Size = UDim2.new(0, 350, 0, 45)
timerFrame.Position = UDim2.new(0.5, -175, 0, 10)
timerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
timerFrame.BackgroundTransparency = 0.3
timerFrame.BorderSizePixel = 0
timerFrame.Parent = screenGui
Instance.new("UICorner", timerFrame).CornerRadius = UDim.new(0, 10)

local timerStroke = Instance.new("UIStroke", timerFrame)
timerStroke.Color = Color3.fromRGB(255, 100, 50)
timerStroke.Thickness = 3

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -10, 1, 0)
timerLabel.Position = UDim2.new(0, 5, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Cargando eventos..."
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Parent = timerFrame

local timerTextStroke = Instance.new("UIStroke", timerLabel)
timerTextStroke.Color = Color3.fromRGB(0, 0, 0)
timerTextStroke.Thickness = 2

-- ============================================
-- Formatear segundos a M:SS
-- ============================================
local function formatTime(seconds)
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%d:%02d", mins, secs)
end

-- ============================================
-- Anuncio grande (temporal)
-- ============================================
local announcementFrame = Instance.new("Frame")
announcementFrame.Name = "Announcement"
announcementFrame.Size = UDim2.new(0, 600, 0, 150)
announcementFrame.Position = UDim2.new(0.5, -300, 0.15, 0)
announcementFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
announcementFrame.BackgroundTransparency = 0.1
announcementFrame.BorderSizePixel = 0
announcementFrame.Visible = false
announcementFrame.ZIndex = 200
announcementFrame.Parent = screenGui
Instance.new("UICorner", announcementFrame).CornerRadius = UDim.new(0, 15)

local annStroke = Instance.new("UIStroke", announcementFrame)
annStroke.Color = Color3.fromRGB(255, 100, 50)
annStroke.Thickness = 5

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -20, 0, 60)
titleLabel.Position = UDim2.new(0, 10, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = ""
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.ZIndex = 201
titleLabel.Parent = announcementFrame

local titleStroke = Instance.new("UIStroke", titleLabel)
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 3

local msgLabel = Instance.new("TextLabel")
msgLabel.Size = UDim2.new(1, -20, 0, 70)
msgLabel.Position = UDim2.new(0, 10, 0, 70)
msgLabel.BackgroundTransparency = 1
msgLabel.Text = ""
msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
msgLabel.TextWrapped = true
msgLabel.TextScaled = true
msgLabel.Font = Enum.Font.GothamBold
msgLabel.ZIndex = 201
msgLabel.Parent = announcementFrame

local msgStroke = Instance.new("UIStroke", msgLabel)
msgStroke.Color = Color3.fromRGB(0, 0, 0)
msgStroke.Thickness = 2

-- ============================================
-- Escuchar eventos del servidor
-- ============================================
if EventAnnouncement then
        EventAnnouncement.OnClientEvent:Connect(function(data)
                if data.type == "timer" then
                        -- Actualizar timer permanente
                        if data.state == "waiting" then
                                timerLabel.Text = data.eventName .. " | Proximo en: " .. formatTime(data.timeLeft)
                                timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                                timerStroke.Color = Color3.fromRGB(255, 100, 50)
                        elseif data.state == "active" then
                                timerLabel.Text = "EVENTO ACTIVO | Termina en: " .. formatTime(data.timeLeft)
                                timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                                timerStroke.Color = Color3.fromRGB(100, 255, 100)
                        end
                elseif data.type == "announcement" then
                        -- Mostrar anuncio grande
                        titleLabel.Text = data.eventName or "EVENTO"
                        msgLabel.Text = data.message or ""
                        
                        announcementFrame.Visible = true
                        announcementFrame.Size = UDim2.new(0, 0, 0, 150)
                        
                        local tween = TweenService:Create(
                                announcementFrame,
                                TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                                {Size = UDim2.new(0, 600, 0, 150)}
                        )
                        tween:Play()
                        
                        task.delay(data.duration or 5, function()
                                local tweenOut = TweenService:Create(
                                        announcementFrame,
                                        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                        {Size = UDim2.new(0, 0, 0, 150)}
                                )
                                tweenOut:Play()
                                tweenOut.Completed:Connect(function()
                                        announcementFrame.Visible = false
                                end)
                        end)
                end
        end)
end

print("[EventUI] Timer de eventos + anuncios cargado")

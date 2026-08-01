-- ============================================
-- EventUI (LocalScript) - StarterPlayerScripts
-- Muestra anuncios de eventos en pantalla (centro, grande)
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EventAnnouncement = ReplicatedStorage:WaitForChild("EventAnnouncement", 15)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EventUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local announcementFrame = Instance.new("Frame")
announcementFrame.Name = "Announcement"
announcementFrame.Size = UDim2.new(0, 600, 0, 150)
announcementFrame.Position = UDim2.new(0.5, -300, 0.3, -75)
announcementFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
announcementFrame.BackgroundTransparency = 0.1
announcementFrame.BorderSizePixel = 0
announcementFrame.Visible = false
announcementFrame.ZIndex = 200
announcementFrame.Parent = screenGui
Instance.new("UICorner", announcementFrame).CornerRadius = UDim.new(0, 15)

local frameStroke = Instance.new("UIStroke", announcementFrame)
frameStroke.Color = Color3.fromRGB(255, 100, 50)
frameStroke.Thickness = 5

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

if EventAnnouncement then
        EventAnnouncement.OnClientEvent:Connect(function(data)
                titleLabel.Text = data.eventName or "EVENTO"
                msgLabel.Text = data.message or ""
                
                announcementFrame.Visible = true
                announcementFrame.Size = UDim2.new(0, 0, 0, 150)
                
                local tweenService = game:GetService("TweenService")
                local tween = tweenService:Create(
                        announcementFrame,
                        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        {Size = UDim2.new(0, 600, 0, 150)}
                )
                tween:Play()
                
                task.delay(data.duration or 5, function()
                        local tweenOut = tweenService:Create(
                                announcementFrame,
                                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                {Size = UDim2.new(0, 0, 0, 150)}
                        )
                        tweenOut:Play()
                        tweenOut.Completed:Connect(function()
                                announcementFrame.Visible = false
                        end)
                end)
        end)
end

print("[EventUI] Sistema de anuncios de eventos cargado")

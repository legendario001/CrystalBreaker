-- ============================================
-- InvestorInteract (LocalScript) - StarterPlayerScripts
-- Boton world-space en la posicion 34.297, 4.008, 3.4
-- Al acercarse el jugador, aparece el boton de abrir (icono E)
-- Al hacer click, abre el panel de Inversionistas (InvestorSystem)
-- ============================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INVESTOR_POSITION = Vector3.new(34.297, 4.008, 3.4)
local INTERACT_DISTANCE = 18

-- Crear Part invisible en la posicion del inversionista
local interactPart = Instance.new("Part")
interactPart.Name = "InvestorInteractPart"
interactPart.Anchored = true
interactPart.CanCollide = false
interactPart.CanQuery = false
interactPart.CanTouch = false
interactPart.Transparency = 1
interactPart.Size = Vector3.new(2, 2, 2)
interactPart.Position = INVESTOR_POSITION
interactPart.Parent = Workspace

-- ============================================
-- ScreenGui con boton clicable (funciona en PC y movil)
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InvestorInteractGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local clickBtn = Instance.new("TextButton")
clickBtn.Name = "InvestorClickBtn"
clickBtn.Size = UDim2.new(0, 100, 0, 100)
clickBtn.Position = UDim2.new(0.5, -50, 0.5, -50)
clickBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
clickBtn.BackgroundTransparency = 1
clickBtn.BorderSizePixel = 0
clickBtn.Text = ""
clickBtn.Visible = false
clickBtn.ZIndex = 100
clickBtn.Parent = screenGui

-- Icono E (mismo que mochila para consistencia)
local eImage = Instance.new("ImageLabel")
eImage.Size = UDim2.new(1, 0, 1, 0)
eImage.BackgroundTransparency = 1
eImage.Image = "rbxassetid://78972021775884"
eImage.ScaleType = Enum.ScaleType.Fit
eImage.Parent = clickBtn

-- ============================================
-- Funcion para abrir/cerrar el panel de inversionistas
-- ============================================
local function toggleInvestorPanel()
        local panel = playerGui:FindFirstChild("InvestorPanel", true)
        if panel then
                panel.Visible = not panel.Visible
                -- Si se abre el panel, pedir info al servidor
                if panel.Visible then
                        local InvestorRequest = game:GetService("ReplicatedStorage"):FindFirstChild("InvestorRequest")
                        if InvestorRequest then
                                InvestorRequest:FireServer("getInfo")
                        end
                end
        else
                warn("[InvestorInteract] No se encontro InvestorPanel en PlayerGui")
        end
end

clickBtn.MouseButton1Click:Connect(toggleInvestorPanel)

-- ============================================
-- Deteccion de cercania + posicionamiento del boton en pantalla
-- ============================================
RunService.Heartbeat:Connect(function()
        if not interactPart or not interactPart.Parent then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local dist = (root.Position - interactPart.Position).Magnitude
        local near = dist < INTERACT_DISTANCE

        if near then
                local panel = playerGui:FindFirstChild("InvestorPanel", true)
                local panelOpen = panel and panel.Visible

                if not panelOpen then
                        local cam = Workspace.CurrentCamera
                        if cam then
                                local screenPos, onScreen = cam:WorldToViewportPoint(interactPart.Position + Vector3.new(0, 3, 0))
                                if onScreen then
                                        clickBtn.Visible = true
                                        clickBtn.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y - 50)
                                else
                                        clickBtn.Visible = false
                                end
                        end
                else
                        clickBtn.Visible = false
                end
        else
                clickBtn.Visible = false
        end
end)

print("[InvestorInteract] Sistema de interaccion de inversionistas cargado en posicion " .. tostring(INVESTOR_POSITION))

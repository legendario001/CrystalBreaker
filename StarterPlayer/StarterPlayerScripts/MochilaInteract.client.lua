-- ============================================
-- MochilaInteract (LocalScript) - StarterPlayerScripts
-- Sistema simple de interaccion para la mochila/tienda de pelotas.
-- Usa ProximityPrompt (PC: tecla E) + ScreenGui button (movil: tap).
-- ============================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Posicion donde aparece el icono de interaccion
local MOCHILA_POSITION = Vector3.new(26.981, 3.368, -0.8)
local MOCHILA_INTERACT_DISTANCE = 18

-- Crear Part invisible en la posicion de la mochila
local mochilaPart = Instance.new("Part")
mochilaPart.Name = "MochilaInteractPart"
mochilaPart.Anchored = true
mochilaPart.CanCollide = false
mochilaPart.CanQuery = false
mochilaPart.CanTouch = false
mochilaPart.Transparency = 1
mochilaPart.Size = Vector3.new(2, 2, 2)
mochilaPart.Position = MOCHILA_POSITION
mochilaPart.Parent = Workspace

-- ============================================
-- ScreenGui con boton clicable (funciona en PC y movil)
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MochilaInteractGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local mochilaClickBtn = Instance.new("TextButton")
mochilaClickBtn.Name = "MochilaClickBtn"
mochilaClickBtn.Size = UDim2.new(0, 100, 0, 100)
mochilaClickBtn.Position = UDim2.new(0.5, -50, 0.5, -50)
mochilaClickBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mochilaClickBtn.BackgroundTransparency = 1
mochilaClickBtn.BorderSizePixel = 0
mochilaClickBtn.Text = ""
mochilaClickBtn.Visible = false
mochilaClickBtn.ZIndex = 100
mochilaClickBtn.Parent = screenGui

local eImage = Instance.new("ImageLabel")
eImage.Size = UDim2.new(1, 0, 1, 0)
eImage.BackgroundTransparency = 1
eImage.Image = "rbxassetid://78972021775884"
eImage.ScaleType = Enum.ScaleType.Fit
eImage.Parent = mochilaClickBtn

-- ============================================
-- Funcion para abrir/cerrar la mochila
-- ============================================
local function toggleMochila()
	local function findBackpackPanel(parent)
		for _, child in ipairs(parent:GetDescendants()) do
			if child:IsA("Frame") and child.Name == "BackpackPanel" then
				return child
			end
		end
		return nil
	end

	local backpackPanel = findBackpackPanel(playerGui)
	if backpackPanel then
		backpackPanel.Visible = not backpackPanel.Visible
	else
		warn("[MochilaInteract] No se encontro BackpackPanel en PlayerGui")
	end
end

-- Click en el boton ScreenGui (funciona en PC y movil con tap)
mochilaClickBtn.MouseButton1Click:Connect(toggleMochila)

-- ============================================
-- Deteccion de cercania + posicionamiento del boton en pantalla
-- (Mismo patron exacto que el banco)
-- ============================================
RunService.Heartbeat:Connect(function()
	if not mochilaPart or not mochilaPart.Parent then return end
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local dist = (root.Position - mochilaPart.Position).Magnitude
	local nearMochila = dist < MOCHILA_INTERACT_DISTANCE

	if nearMochila then
		-- Verificar que el BackpackPanel no este ya abierto
		local bp = playerGui:FindFirstChild("BackpackPanel", true)
		local panelOpen = bp and bp.Visible

		if not panelOpen then
			local cam = Workspace.CurrentCamera
			if cam then
				local screenPos, onScreen = cam:WorldToViewportPoint(mochilaPart.Position + Vector3.new(0, 3, 0))
				if onScreen then
					mochilaClickBtn.Visible = true
					mochilaClickBtn.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y - 50)
				else
					mochilaClickBtn.Visible = false
				end
			end
		else
			mochilaClickBtn.Visible = false
		end
	else
		mochilaClickBtn.Visible = false
	end
end)

print("[MochilaInteract] Sistema de interaccion de mochila cargado en posicion " .. tostring(MOCHILA_POSITION))

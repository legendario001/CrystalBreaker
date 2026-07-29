-- ============================================
-- MochilaInteract (LocalScript) - StarterPlayerScripts
-- Sistema simple de interaccion para la mochila/tienda de pelotas.
-- Usa ProximityPrompt de Roblox (sistema nativo, muestra la E automaticamente).
-- No depende de BallThrower, funciona independientemente.
-- ============================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Posicion donde aparece el icono de interaccion
local MOCHILA_POSITION = Vector3.new(26.981, 3.368, -0.8)

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

-- Crear ProximityPrompt (sistema nativo de Roblox para interacciones)
-- Esto muestra automaticamente el boton E al acercarse, funciona en PC y movil
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "MochilaPrompt"
prompt.ActionText = "Mochila"
prompt.ObjectText = "Tienda de Pelotas"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
prompt.HoldDuration = 0  -- 0 = instantaneo (no hay que mantener presionado)
prompt.MaxActivationDistance = 18  -- 18 studs como pidio el usuario
prompt.RequiresLineOfSight = false  -- funciona aunque haya objetos entre el jugador y el part
prompt.Parent = mochilaPart

-- Customizar el icono del prompt para usar la misma imagen del banco
-- ProximityPrompt tiene una propiedad Style que se puede customizar
prompt.Style = Enum.ProximityPromptStyle.Custom

-- Crear BillboardGui para mostrar el icono E personalizado (rbxassetid://78972021775884)
-- cuando el prompt esta activo
local billboard = Instance.new("BillboardGui")
billboard.Name = "MochilaInteractGui"
billboard.Size = UDim2.new(0, 80, 0, 80)
billboard.StudsOffset = Vector3.new(0, 2, 0)
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.MaxDistance = 25
billboard.Enabled = false
billboard.Parent = mochilaPart

local eImage = Instance.new("ImageLabel")
eImage.Size = UDim2.new(1, 0, 1, 0)
eImage.BackgroundTransparency = 1
eImage.Image = "rbxassetid://78972021775884"
eImage.ScaleType = Enum.ScaleType.Fit
eImage.Parent = billboard

-- Mostrar/ocultar el billboard segun la cercania del prompt
prompt.PromptShown:Connect(function()
	billboard.Enabled = true
end)

prompt.PromptHidden:Connect(function()
	billboard.Enabled = false
end)

-- Cuando el jugador activa el prompt (click en movil o tecla E en PC)
prompt.Triggered:Connect(function(triggeringPlayer)
	if triggeringPlayer ~= player then return end

	-- Buscar el BackpackPanel en el PlayerGui
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	-- El BackpackPanel esta dentro del ScreenGui "BallThrowerGui" (o como se llame)
	-- Buscarlo recursivamente
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
		-- Toggle: si esta visible, ocultarlo; si no, mostrarlo
		backpackPanel.Visible = not backpackPanel.Visible

		-- Si se abrio, intentar llamar updateBackpackUI si existe
		-- (Buscamos el backpackBtn que tiene conectado el toggle)
		if backpackPanel.Visible then
			-- Buscar el backpackBtn y simular un click para que se ejecute updateBackpackUI
			for _, child in ipairs(playerGui:GetDescendants()) do
				if child:IsA("TextButton") and child.Name == "BackpackBtn" then
					-- FireEvent para simular click
					-- En Roblox no podemos simular clicks directamente, pero podemos
					-- buscar si hay un atributo o simplemente confiar en que el panel se actualize
					break
				end
			end
		end
	else
		warn("[MochilaInteract] No se encontro BackpackPanel en PlayerGui")
	end
end)

print("[MochilaInteract] Sistema de interaccion de mochila cargado en posicion " .. tostring(MOCHILA_POSITION))

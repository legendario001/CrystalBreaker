-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- Coloca modelos en pedestales, crea etiquetas
-- ============================================

local ModelManager = {}

function ModelManager.placeOnPedestal(model, pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then return end

	local clone = model:Clone()
	clone.Parent = pedestal

	pcall(function()
		local _, size = clone:GetBoundingBox()
		local maxDim = math.max(size.X, size.Y, size.Z)
		if maxDim > 4 then
			clone:ScaleTo(4)
		end
	end)

	pcall(function()
		local topY = platform.Position.Y + platform.Size.Y / 2
		local cf = CFrame.new(platform.Position.X, topY + 2.5, platform.Position.Z)
		clone:PivotTo(cf)
	end)

	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
end

function ModelManager.createLabels(pedestal, charName, rarity)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then return end

	-- Color segun rareza
	local rarityColors = {
		Morado = Color3.fromRGB(170, 85, 255),
		Rojo = Color3.fromRGB(255, 80, 80),
		Amarillo = Color3.fromRGB(255, 255, 100),
		Azul = Color3.fromRGB(85, 170, 255),
		Blanco = Color3.fromRGB(220, 220, 220)
	}

	-- Nombre del personaje
	local nameGui = Instance.new("BillboardGui")
	nameGui.Name = "CharNameGui"
	nameGui.Size = UDim2.new(4, 0, 0.5, 0)
	nameGui.StudsOffset = Vector3.new(0, 5, 0)
	nameGui.AlwaysOnTop = false
	nameGui.Parent = platform

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = charName
	nameLabel.TextColor3 = rarityColors[rarity] or Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = nameGui

	-- Nivel
	local levelGui = Instance.new("BillboardGui")
	levelGui.Name = "CharLevelGui"
	levelGui.Size = UDim2.new(2, 0, 0.5, 0)
	levelGui.StudsOffset = Vector3.new(0, 4, 0)
	levelGui.AlwaysOnTop = false
	levelGui.Parent = platform

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(1, 0, 1, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Lv.1"
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = levelGui
end

function ModelManager.clearPedestal(pedestal)
	for _, child in ipairs(pedestal:GetChildren()) do
		if child.Name ~= "Platform" and child.Name ~= "PedestalColumn" then
			child:Destroy()
		end
	end
end

return ModelManager

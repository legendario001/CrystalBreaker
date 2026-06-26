-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- Coloca modelos en pedestales, crea etiquetas, muestra E en vacios
-- ============================================

local ModelManager = {}

local rarityColors = {
	Morado = Color3.fromRGB(170, 85, 255),
	Rojo = Color3.fromRGB(255, 80, 80),
	Amarillo = Color3.fromRGB(255, 255, 100),
	Azul = Color3.fromRGB(85, 170, 255),
	Blanco = Color3.fromRGB(220, 220, 220)
}

-- Weld todas las partes de un modelo entre si
local function weldAllParts(model, rootPart)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") and desc ~= rootPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rootPart
			weld.Part1 = desc
			weld.Parent = rootPart
		end
	end
end

-- Mostrar E en pedestal vacio
function ModelManager.showEmptyLabel(pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then return end

	local old = platform:FindFirstChild("EmptyGui")
	if old then old:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "EmptyGui"
	bb.Size = UDim2.new(2, 0, 2, 0)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 30
	bb.Parent = platform

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "E"
	lbl.TextColor3 = Color3.fromRGB(160, 160, 160)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = bb
end

-- Ocultar E en pedestal
function ModelManager.hideEmptyLabel(pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if platform then
		local old = platform:FindFirstChild("EmptyGui")
		if old then old:Destroy() end
	end
end

function ModelManager.placeOnPedestal(model, pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then return end

	local clone = model:Clone()

	-- Asegurar PrimaryPart
	if not clone.PrimaryPart then
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				clone.PrimaryPart = desc
				break
			end
		end
	end

	-- Weld todas las partes al PrimaryPart para que se muevan juntas
	if clone.PrimaryPart then
		weldAllParts(clone, clone.PrimaryPart)
	end

	-- Desanclar todo antes de mover
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	-- Parentear al workspace temporalmente
	clone.Parent = workspace

	-- Mover TODO el modelo junto con PivotTo
	pcall(function()
		local topY = platform.Position.Y + platform.Size.Y / 2
		local targetCF = CFrame.new(platform.Position.X, topY + 2, platform.Position.Z)
		clone:PivotTo(targetCF)
	end)

	-- Ahora anclar todo en su posicion correcta
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- Mover al pedestal
	clone.Parent = pedestal

	-- Ocultar la E
	ModelManager.hideEmptyLabel(pedestal)
end

function ModelManager.createLabels(pedestal, charName, rarity)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then return end

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
	ModelManager.showEmptyLabel(pedestal)
end

return ModelManager

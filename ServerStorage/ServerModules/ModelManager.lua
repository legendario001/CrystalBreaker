-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- Coloca modelos en pedestales
-- Limpia partes problematicas: FakeRootPart, AnimationController, AnimSaves
-- Mueve usando CFrame offset sobre partes visibles
-- ============================================

local ModelManager = {}

local rarityColors = {
	Morado = Color3.fromRGB(170, 85, 255),
	Rojo = Color3.fromRGB(255, 80, 80),
	Amarillo = Color3.fromRGB(255, 255, 100),
	Azul = Color3.fromRGB(85, 170, 255),
	Blanco = Color3.fromRGB(220, 220, 220)
}

-- Nombres de partes/objetos a eliminar del clon
local REMOVE_NAMES = {
	["FakeRootPart"] = true,
	["AnimationController"] = true,
	["AnimSaves"] = true,
}

-- Limpiar partes problematicas de un modelo clonado
local function cleanModel(model)
	for _, obj in ipairs(model:GetDescendants()) do
		if REMOVE_NAMES[obj.Name] then
			obj:Destroy()
		end
	end
	-- Tambien limpiar ParticleEmitters y otros efectos que causan problemas
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj:Destroy()
		end
	end
end

-- Obtener partes visibles (MeshPart y Part, no eliminadas)
local function getVisibleParts(model)
	local parts = {}
	for _, part in ipairs(model:GetDescendants()) do
		if (part:IsA("BasePart") or part:IsA("MeshPart")) and not part.Name:find("FakeRoot") then
			table.insert(parts, part)
		end
	end
	return parts
end

-- Calcular centro de partes visibles
local function getCenter(parts)
	if #parts == 0 then return Vector3.new(0, 5, 0) end
	local sum = Vector3.new(0, 0, 0)
	for _, part in ipairs(parts) do
		sum = sum + part.Position
	end
	return sum / #parts
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

	-- Limpiar partes problematicas
	cleanModel(clone)

	-- Desanclar todo
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end

	-- Parentear al pedestal
	clone.Parent = pedestal

	-- Calcular posicion objetivo
	local topY = platform.Position.Y + platform.Size.Y / 2 + 2
	local targetPos = Vector3.new(platform.Position.X, topY, platform.Position.Z)

	-- Mover modelo: calcular offset y aplicarlo a cada parte
	local parts = getVisibleParts(clone)
	if #parts > 0 then
		local center = getCenter(parts)
		local offset = targetPos - center
		for _, part in ipairs(parts) do
			part.CFrame = part.CFrame + offset
		end
	end

	-- Anclar todo
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	ModelManager.hideEmptyLabel(pedestal)
end

function ModelManager.moveModelTo(model, position)
	cleanModel(model)
	local parts = getVisibleParts(model)
	if #parts > 0 then
		local center = getCenter(parts)
		local offset = position - center
		for _, part in ipairs(parts) do
			part.CFrame = part.CFrame + offset
		end
	end
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

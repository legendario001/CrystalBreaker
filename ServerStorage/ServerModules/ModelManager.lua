-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- Metodo: part.Position + Vector3 offset (espacio MUNDIAL)
-- NO usar PivotTo, NO usar CFrame * CFrame.new para offsets
-- NO destruir partes internas (FakeRootPart, AnimationController, etc.)
-- ============================================

local ModelManager = {}

local rarityColors = {
	Morado = Color3.fromRGB(170, 85, 255),
	Rojo = Color3.fromRGB(255, 80, 80),
	Amarillo = Color3.fromRGB(255, 255, 100),
	Azul = Color3.fromRGB(85, 170, 255),
	Blanco = Color3.fromRGB(220, 220, 220)
}

-- ============================================
-- Obtener todas las BaseParts de un modelo
-- ============================================
local function getAllParts(modelOrClone)
	local parts = {}
	for _, desc in ipairs(modelOrClone:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end
	return parts
end

-- ============================================
-- Calcular centro XZ y lowestY de un modelo
-- Retorna: centerX, centerZ, lowestY
-- ============================================
local function getModelBounds(parts)
	if #parts == 0 then return 0, 0, 0 end

	local lowestY = math.huge
	local sumX = 0
	local sumZ = 0

	for _, part in ipairs(parts) do
		local bottomY = part.Position.Y - part.Size.Y / 2
		if bottomY < lowestY then
			lowestY = bottomY
		end
		sumX = sumX + part.Position.X
		sumZ = sumZ + part.Position.Z
	end

	-- Centro XZ promediado entre TODAS las partes
	local centerX = sumX / #parts
	local centerZ = sumZ / #parts

	return centerX, centerZ, lowestY
end

-- ============================================
-- Mostrar E en pedestal vacio
-- ============================================
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

-- ============================================
-- Ocultar E en pedestal
-- ============================================
function ModelManager.hideEmptyLabel(pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if platform then
		local old = platform:FindFirstChild("EmptyGui")
		if old then old:Destroy() end
	end
end

-- ============================================
-- Colocar modelo en pedestal usando part.Position + Vector3
-- Metodo correcto (espacio MUNDIAL):
--   1. Clonar modelo (NO destruir nada)
--   2. Anchored=true, CanCollide=false en todas las partes
--   3. Parentar al pedestal (workspace)
--   4. Calcular lowestY = min(part.Position.Y - part.Size.Y/2)
--   5. Calcular centro XZ promediado
--   6. offsetY = pedestalTop.Y - lowestY
--   7. offsetX = targetX - centerX
--   8. offsetZ = targetZ - centerZ
--   9. Mover: part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
-- ============================================
function ModelManager.placeOnPedestal(model, pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then
		warn("placeOnPedestal: No se encontro Platform en pedestal")
		return
	end

	local clone = model:Clone()

	-- Paso 1: Anclar todo y desactivar colisiones ANTES de mover
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- Paso 2: Parentar al pedestal PRIMERO para que las posiciones sean validas en workspace
	clone.Parent = pedestal

	-- Paso 3: Obtener todas las partes y calcular bounds
	local parts = getAllParts(clone)
	if #parts == 0 then
		warn("placeOnPedestal: El modelo no tiene BaseParts")
		return
	end

	local centerX, centerZ, lowestY = getModelBounds(parts)

	-- Paso 4: Calcular posicion objetivo
	local pedestalTopY = platform.Position.Y + platform.Size.Y / 2
	local targetX = platform.Position.X
	local targetZ = platform.Position.Z

	-- Paso 5: Calcular offsets en espacio MUNDIAL
	local offsetY = pedestalTopY - lowestY
	local offsetX = targetX - centerX
	local offsetZ = targetZ - centerZ

	print("[ModelManager] pedestalTop=" .. pedestalTopY .. " lowestY=" .. lowestY .. " offsetY=" .. offsetY)
	print("[ModelManager] targetX=" .. targetX .. " centerX=" .. centerX .. " offsetX=" .. offsetX)
	print("[ModelManager] targetZ=" .. targetZ .. " centerZ=" .. centerZ .. " offsetZ=" .. offsetZ)

	-- Paso 6: Mover TODAS las partes usando part.Position + Vector3 (ESPACIO MUNDIAL)
	-- ESTO ES LO CRITICO: NO usar CFrame * CFrame.new() porque aplica en espacio local
	for _, part in ipairs(parts) do
		part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
	end

	ModelManager.hideEmptyLabel(pedestal)
	print("[ModelManager] Modelo colocado correctamente en pedestal")
end

-- ============================================
-- Mover modelo a una posicion usando part.Position + Vector3
-- Mismo enfoque que placeOnPedestal pero para posicion arbitraria
-- ============================================
function ModelManager.moveModelTo(model, position)
	local parts = getAllParts(model)
	if #parts == 0 then return end

	local centerX, centerZ, lowestY = getModelBounds(parts)

	-- Calcular offsets en espacio MUNDIAL
	local offsetX = position.X - centerX
	local offsetY = position.Y - lowestY
	local offsetZ = position.Z - centerZ

	for _, part in ipairs(parts) do
		part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
	end
end

-- ============================================
-- Centrar modelo alrededor de un punto (para Tool handle)
-- Mueve todas las partes para que el centro del modelo este en 'targetPos'
-- ============================================
function ModelManager.centerModelOn(model, targetPos)
	local parts = getAllParts(model)
	if #parts == 0 then return end

	local centerX, centerZ, lowestY = getModelBounds(parts)
	local centerY = lowestY + 2 -- un poco arriba del punto mas bajo

	local offsetX = targetPos.X - centerX
	local offsetY = targetPos.Y - centerY
	local offsetZ = targetPos.Z - centerZ

	for _, part in ipairs(parts) do
		part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
	end
end

-- ============================================
-- Crear etiquetas de nombre y nivel en pedestal
-- ============================================
function ModelManager.createLabels(pedestal, charName, rarity)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then return end

	-- Limpiar labels anteriores
	local oldName = platform:FindFirstChild("CharNameGui")
	if oldName then oldName:Destroy() end
	local oldLevel = platform:FindFirstChild("CharLevelGui")
	if oldLevel then oldLevel:Destroy() end

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

-- ============================================
-- Limpiar pedestal y mostrar E de nuevo
-- ============================================
function ModelManager.clearPedestal(pedestal)
	for _, child in ipairs(pedestal:GetChildren()) do
		if child.Name ~= "Platform" and child.Name ~= "PedestalColumn" then
			child:Destroy()
		end
	end
	ModelManager.showEmptyLabel(pedestal)
end

return ModelManager

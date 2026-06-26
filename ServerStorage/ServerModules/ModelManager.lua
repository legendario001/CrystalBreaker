-- ============================================
-- ModelManager (ModuleScript) - ServerStorage/ServerModules
-- Metodo: part.Position + Vector3 offset (espacio MUNDIAL)
-- ============================================

local ModelManager = {}

local rarityColors = {
	Morado = Color3.fromRGB(170, 85, 255),
	Rojo = Color3.fromRGB(255, 80, 80),
	Amarillo = Color3.fromRGB(255, 255, 100),
	Azul = Color3.fromRGB(85, 170, 255),
	Blanco = Color3.fromRGB(220, 220, 220)
}

-- Dinero generado cada 2 segundos segun rareza (base, se multiplica por nivel)
local rarityMoneyRate = {
	Morado = 10,
	Rojo = 7,
	Amarillo = 5,
	Azul = 3,
	Blanco = 1
}

-- Costo base de mejora (se multiplica por el nivel actual)
local UPGRADE_BASE_COST = 5

-- Color verde dolar para el dinero
local MONEY_COLOR = Color3.fromRGB(76, 175, 80)
local MONEY_COLOR_BRIGHT = Color3.fromRGB(129, 199, 132)

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
-- Calcular centro XZ, lowestY y highestY de un modelo
-- ============================================
local function getModelBounds(parts)
	if #parts == 0 then return 0, 0, 0, 0 end

	local lowestY = math.huge
	local highestY = -math.huge
	local sumX = 0
	local sumZ = 0

	for _, part in ipairs(parts) do
		local bottomY = part.Position.Y - part.Size.Y / 2
		local topY = part.Position.Y + part.Size.Y / 2
		if bottomY < lowestY then
			lowestY = bottomY
		end
		if topY > highestY then
			highestY = topY
		end
		sumX = sumX + part.Position.X
		sumZ = sumZ + part.Size.Z
	end

	local centerX = sumX / #parts
	local centerZ = sumZ / #parts

	return centerX, centerZ, lowestY, highestY
end

-- ============================================
-- Rotar modelo alrededor de su centro
-- ============================================
local function rotateModelToFace(parts, centerX, centerZ, lookDirection)
	local desiredAngle = math.atan2(lookDirection.X, lookDirection.Z)

	for _, part in ipairs(parts) do
		local offsetX = part.Position.X - centerX
		local offsetZ = part.Position.Z - centerZ

		local cosA = math.cos(desiredAngle)
		local sinA = math.sin(desiredAngle)
		local newOffsetX = offsetX * cosA - offsetZ * sinA
		local newOffsetZ = offsetX * sinA + offsetZ * cosA

		local newY = part.Position.Y
		part.Position = Vector3.new(centerX + newOffsetX, newY, centerZ + newOffsetZ)

		local currentCF = part.CFrame
		local currentPos = currentCF.Position
		local currentRot = currentCF - currentPos
		local rotCF = CFrame.fromMatrix(Vector3.new(0,0,0),
			Vector3.new(cosA, 0, sinA),
			Vector3.new(0, 1, 0),
			Vector3.new(-sinA, 0, cosA)
		)
		part.CFrame = CFrame.new(part.Position) * rotCF * currentRot
	end
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
-- Colocar modelo en pedestal
-- ============================================
function ModelManager.placeOnPedestal(model, pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then
		warn("placeOnPedestal: No se encontro Platform")
		return nil
	end

	local clone = model:Clone()

	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	clone.Parent = pedestal

	local parts = getAllParts(clone)
	if #parts == 0 then return nil end

	local centerX, centerZ, lowestY = getModelBounds(parts)

	local pedestalTopY = platform.Position.Y + platform.Size.Y / 2
	local targetX = platform.Position.X
	local targetZ = platform.Position.Z

	local offsetY = pedestalTopY - lowestY
	local offsetX = targetX - centerX
	local offsetZ = targetZ - centerZ

	for _, part in ipairs(parts) do
		part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
	end

	local baseFolder = pedestal.Parent
	local base = baseFolder and baseFolder.Parent
	local lookDir = Vector3.new(0, 0, -1)

	if base then
		local baseFloor = base:FindFirstChild("BaseFloor")
		if baseFloor then
			local baseX = baseFloor.Position.X
			if targetX < baseX then
				lookDir = Vector3.new(-1, 0, 0)
			else
				lookDir = Vector3.new(1, 0, 0)
			end
		end
	end

	local afterCenterX, afterCenterZ = getModelBounds(parts)
	rotateModelToFace(parts, afterCenterX, afterCenterZ, lookDir)

	ModelManager.hideEmptyLabel(pedestal)
	return clone
end

-- ============================================
-- Mover modelo a una posicion
-- ============================================
function ModelManager.moveModelTo(model, position)
	local parts = getAllParts(model)
	if #parts == 0 then return end

	local centerX, centerZ, lowestY = getModelBounds(parts)
	local offsetX = position.X - centerX
	local offsetY = position.Y - lowestY
	local offsetZ = position.Z - centerZ

	for _, part in ipairs(parts) do
		part.Position = part.Position + Vector3.new(offsetX, offsetY, offsetZ)
	end
end

-- ============================================
-- Nombres de rareza bonitos
-- ============================================
local rarityDisplayNames = {
	Morado = "MITICO",
	Rojo = "EPICO",
	Amarillo = "RARO",
	Azul = "INCOMUN",
	Blanco = "COMUN"
}

-- ============================================
-- Crear etiquetas de nombre y rareza sobre cabeza
-- ============================================
function ModelManager.createLabels(pedestal, charName, rarity, level)
	level = level or 1
	local highestPart = nil
	local highestY = -math.huge

	for _, child in ipairs(pedestal:GetChildren()) do
		if child:IsA("Model") then
			for _, part in ipairs(child:GetDescendants()) do
				if part:IsA("BasePart") then
					local topY = part.Position.Y + part.Size.Y / 2
					if topY > highestY then
						highestY = topY
						highestPart = part
					end
				end
			end
		end
	end

	local labelParent = highestPart
	local labelStudsOffset = Vector3.new(0, 2, 0)

	if labelParent then
		local halfHeight = labelParent.Size.Y / 2
		labelStudsOffset = Vector3.new(0, halfHeight + 1, 0)
	else
		local platform = pedestal:FindFirstChild("Platform")
		if platform then
			labelParent = platform
			labelStudsOffset = Vector3.new(0, 5, 0)
		else
			return
		end
	end

	local oldLabel = labelParent:FindFirstChild("CharInfoGui")
	if oldLabel then oldLabel:Destroy() end

	local platform = pedestal:FindFirstChild("Platform")
	if platform and platform ~= labelParent then
		local pOldInfo = platform:FindFirstChild("CharInfoGui")
		if pOldInfo then pOldInfo:Destroy() end
	end

	local rarityColor = rarityColors[rarity] or Color3.new(1, 1, 1)
	local rarityDisplay = rarityDisplayNames[rarity] or string.upper(rarity)

	local infoGui = Instance.new("BillboardGui")
	infoGui.Name = "CharInfoGui"
	infoGui.Size = UDim2.new(5, 0, 2, 0)
	infoGui.StudsOffset = labelStudsOffset
	infoGui.AlwaysOnTop = false
	infoGui.MaxDistance = 50
	infoGui.Parent = labelParent

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.45
	bg.BorderSizePixel = 0
	bg.Parent = infoGui
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = rarityColor
	bgStroke.Thickness = 2
	bgStroke.Transparency = 0.2
	bgStroke.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.35, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = charName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = bg

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, 0, 0.25, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.35, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = rarityDisplay
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBlack
	rarityLabel.Parent = bg

	local rarityStroke = Instance.new("UIStroke")
	rarityStroke.Color = Color3.fromRGB(255, 255, 255)
	rarityStroke.Thickness = 0.8
	rarityStroke.Transparency = 0.75
	rarityStroke.Parent = rarityLabel

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, 0, 0.25, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.6, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Lv." .. level
	levelLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = bg

	-- Barra de progreso visual al fondo
	local levelBarBg = Instance.new("Frame")
	levelBarBg.Size = UDim2.new(0.9, 0, 0.1, 0)
	levelBarBg.Position = UDim2.new(0.05, 0, 0.88, 0)
	levelBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	levelBarBg.BorderSizePixel = 0
	levelBarBg.Parent = bg
	Instance.new("UICorner", levelBarBg).CornerRadius = UDim.new(0, 4)

	local levelBarFill = Instance.new("Frame")
	levelBarFill.Name = "LevelBarFill"
	levelBarFill.Size = UDim2.new(math.clamp(level / 100, 0.01, 1), 0, 1, 0)
	levelBarFill.BackgroundColor3 = rarityColor
	levelBarFill.BorderSizePixel = 0
	levelBarFill.Parent = levelBarBg
	Instance.new("UICorner", levelBarFill).CornerRadius = UDim.new(0, 4)
end

-- ============================================
-- Obtener la tasa de dinero segun rareza y nivel
-- ============================================
function ModelManager.getMoneyRate(rarity, level)
	level = level or 1
	local base = rarityMoneyRate[rarity] or 1
	-- Cada nivel suma 10% de la base (nivel 1 = 1x, nivel 10 = 2x, nivel 50 = 6x, nivel 100 = 11x)
	return math.floor(base * (1 + (level - 1) * 0.1))
end

-- ============================================
-- Calcular costo de mejora segun nivel actual
-- ============================================
function ModelManager.getUpgradeCost(currentLevel)
	if currentLevel >= 100 then return math.huge end
	-- Costo exponencial: base * nivel^1.5
	return math.floor(UPGRADE_BASE_COST * math.pow(currentLevel, 1.5))
end

-- ============================================
-- Crear pila de dinero frente al pedestal
-- Con boton MEJORAR y recoleccion al caminar sobre ella
-- ============================================
function ModelManager.createMoneyPile(pedestal, rarity, level, onUpgradeCallback)
	local platform = pedestal:FindFirstChild("Platform")
	if not platform then return nil end

	ModelManager.removeMoneyPile(pedestal)

	local baseFolder = pedestal.Parent
	local base = baseFolder and baseFolder.Parent

	local pileX = platform.Position.X
	local pileZ = platform.Position.Z
	local pileY = 1.5

	if base then
		local baseFloor = base:FindFirstChild("BaseFloor")
		if baseFloor then
			local baseX = baseFloor.Position.X
			if platform.Position.X < baseX then
				pileX = platform.Position.X + 5
			else
				pileX = platform.Position.X - 5
			end
		end
	end

	local rarityColor = rarityColors[rarity] or Color3.fromRGB(220, 220, 220)
	local upgradeCost = ModelManager.getUpgradeCost(level or 1)
	local isMaxLevel = (level or 1) >= 100

	-- Parte visual: moneda verde en el suelo
	local moneyPile = Instance.new("Part")
	moneyPile.Name = "MoneyPile"
	moneyPile.Size = Vector3.new(2.5, 0.3, 2.5)
	moneyPile.Shape = Enum.PartType.Cylinder
	moneyPile.Orientation = Vector3.new(0, 0, 90)
	moneyPile.Position = Vector3.new(pileX, pileY, pileZ)
	moneyPile.Anchored = true
	moneyPile.CanCollide = false
	moneyPile.Material = Enum.Material.SmoothPlastic
	moneyPile.Color = MONEY_COLOR
	moneyPile.Transparency = 0.2
	moneyPile.Parent = pedestal

	-- ClickDetector para boton MEJORAR
	if not isMaxLevel then
		local click = Instance.new("ClickDetector")
		click.Name = "UpgradeClick"
		click.MaxActivationDistance = 15
		click.CursorIcon = ""
		click.Parent = moneyPile

		-- Guardar callback para cuando hagan click
		local upgradeEvent = Instance.new("BindableEvent")
		upgradeEvent.Name = "UpgradeEvent"
		upgradeEvent.Parent = moneyPile

		click.MouseClick:Connect(function(player)
			upgradeEvent:Fire(player)
		end)
	end

	-- Valor acumulado
	local moneyValue = Instance.new("IntValue")
	moneyValue.Name = "MoneyValue"
	moneyValue.Value = 0
	moneyValue.Parent = moneyPile

	-- Rareza
	local rarityTag = Instance.new("StringValue")
	rarityTag.Name = "Rarity"
	rarityTag.Value = rarity
	rarityTag.Parent = moneyPile

	-- Nivel
	local levelTag = Instance.new("IntValue")
	levelTag.Name = "CharLevel"
	levelTag.Value = level or 1
	levelTag.Parent = moneyPile

	-- ============================================
	-- Billboard: Dinero + Boton Mejorar
	-- ============================================
	local bb = Instance.new("BillboardGui")
	bb.Name = "MoneyGui"
	bb.Size = UDim2.new(4, 0, 2.5, 0)
	bb.StudsOffset = Vector3.new(0, 1.8, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 40
	bb.Parent = moneyPile

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = MONEY_COLOR
	bgStroke.Thickness = 2
	bgStroke.Transparency = 0.2
	bgStroke.Parent = bg

	-- Fila 1: Dinero acumulado (verde)
	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "MoneyLabel"
	moneyLabel.Size = UDim2.new(1, 0, 0.35, 0)
	moneyLabel.Position = UDim2.new(0, 0, 0, 0)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Text = "$0"
	moneyLabel.TextColor3 = MONEY_COLOR_BRIGHT
	moneyLabel.TextScaled = true
	moneyLabel.Font = Enum.Font.GothamBlack
	moneyLabel.Parent = bg

	-- Fila 2: Tasa de generacion
	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Size = UDim2.new(1, 0, 0.25, 0)
	rateLabel.Position = UDim2.new(0, 0, 0.35, 0)
	rateLabel.BackgroundTransparency = 1
	local currentRate = ModelManager.getMoneyRate(rarity, level or 1)
	rateLabel.Text = "+" .. currentRate .. "/2s"
	rateLabel.TextColor3 = MONEY_COLOR
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.Parent = bg

	-- Fila 3: Boton mejorar o MAX
	local upgradeLabel = Instance.new("TextLabel")
	upgradeLabel.Name = "UpgradeLabel"
	upgradeLabel.Size = UDim2.new(1, 0, 0.3, 0)
	upgradeLabel.Position = UDim2.new(0, 0, 0.6, 0)
	upgradeLabel.BackgroundTransparency = 1
	if isMaxLevel then
		upgradeLabel.Text = "MAX LV.100"
		upgradeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	else
		upgradeLabel.Text = "MEJORAR $" .. upgradeCost
		upgradeLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
	upgradeLabel.TextScaled = true
	upgradeLabel.Font = Enum.Font.GothamBlack
	upgradeLabel.Parent = bg

	-- Fila 4: Hint click
	if not isMaxLevel then
		local hintLabel = Instance.new("TextLabel")
		hintLabel.Size = UDim2.new(1, 0, 0.15, 0)
		hintLabel.Position = UDim2.new(0, 0, 0.85, 0)
		hintLabel.BackgroundTransparency = 1
		hintLabel.Text = "[Click para mejorar]"
		hintLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		hintLabel.TextScaled = true
		hintLabel.Font = Enum.Font.GothamBold
		hintLabel.Parent = bg
	end

	-- Touched con debounce para recoger dinero
	local touchDebounce = false
	moneyPile.Touched:Connect(function(hit)
		if touchDebounce then return end
		local character = hit.Parent
		if not character then return end
		local player = game:GetService("Players"):GetPlayerFromCharacter(character)
		if not player then return end

		local mv = moneyPile:FindFirstChild("MoneyValue")
		if not mv or mv.Value <= 0 then return end

		touchDebounce = true
		local amount = mv.Value
		mv.Value = 0

		local bbGui = moneyPile:FindFirstChild("MoneyGui")
		if bbGui then
			local frame = bbGui:FindFirstChild("Frame")
			if frame then
				local ml = frame:FindFirstChild("MoneyLabel")
				if ml then ml.Text = "$0" end
			end
		end

		-- Notificar al servidor viaBindableEvent
		local collectEvent = moneyPile:FindFirstChild("CollectEvent")
		if not collectEvent then
			collectEvent = Instance.new("BindableEvent")
			collectEvent.Name = "CollectEvent"
			collectEvent.Parent = moneyPile
		end
		collectEvent:Fire(player, amount)

		task.wait(0.5)
		touchDebounce = false
	end)

	return moneyPile
end

-- ============================================
-- Actualizar la UI del MoneyPile (despues de mejora)
-- ============================================
function ModelManager.updateMoneyPileUI(pedestal, rarity, level)
	local moneyPile = pedestal:FindFirstChild("MoneyPile")
	if not moneyPile then return end

	local levelTag = moneyPile:FindFirstChild("CharLevel")
	if levelTag then levelTag.Value = level end

	local upgradeCost = ModelManager.getUpgradeCost(level)
	local isMaxLevel = level >= 100
	local currentRate = ModelManager.getMoneyRate(rarity, level)

	local bb = moneyPile:FindFirstChild("MoneyGui")
	if not bb then return end
	local bg = bb:FindFirstChild("Frame")
	if not bg then return end

	local rateLabel = bg:FindFirstChild("RateLabel")
	if rateLabel then
		rateLabel.Text = "+" .. currentRate .. "/2s"
	end

	local upgradeLabel = bg:FindFirstChild("UpgradeLabel")
	if upgradeLabel then
		if isMaxLevel then
			upgradeLabel.Text = "MAX LV.100"
			upgradeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		else
			upgradeLabel.Text = "MEJORAR $" .. upgradeCost
			upgradeLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end
end

-- ============================================
-- Eliminar pila de dinero de un pedestal
-- ============================================
function ModelManager.removeMoneyPile(pedestal)
	local old = pedestal:FindFirstChild("MoneyPile")
	if old then old:Destroy() end
end

-- ============================================
-- Limpiar pedestal y mostrar E de nuevo
-- ============================================
function ModelManager.clearPedestal(pedestal)
	local platform = pedestal:FindFirstChild("Platform")
	if platform then
		local oldName = platform:FindFirstChild("CharNameGui")
		if oldName then oldName:Destroy() end
		local oldLevel = platform:FindFirstChild("CharLevelGui")
		if oldLevel then oldLevel:Destroy() end
		local oldInfo = platform:FindFirstChild("CharInfoGui")
		if oldInfo then oldInfo:Destroy() end
	end

	for _, child in ipairs(pedestal:GetChildren()) do
		if child.Name ~= "Platform" and child.Name ~= "PedestalColumn" then
			child:Destroy()
		end
	end

	ModelManager.showEmptyLabel(pedestal)
end

return ModelManager

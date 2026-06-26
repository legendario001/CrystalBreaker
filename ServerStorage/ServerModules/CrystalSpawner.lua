-- ============================================
-- CrystalSpawner (ModuleScript) - ServerStorage/ServerModules
-- Genera 25 cristales en la zona de cristales
-- Rareza: Mitico (Morado) > Epico (Rojo) > Raro (Amarillo) > Incomun (Azul) > Comun (Blanco)
-- Cofres al romper cristal, regenera si no se recoge
-- ============================================

local Workspace = game:GetService("Workspace")

local CrystalSpawner = {}

-- Colores, rareza y nombres bonitos de cristales
local CRYSTAL_TYPES = {
	{color = Color3.fromRGB(170, 85, 255),  name = "Morado",   displayName = "MITICO",  weight = 3},
	{color = Color3.fromRGB(255, 80, 80),   name = "Rojo",     displayName = "EPICO",   weight = 6},
	{color = Color3.fromRGB(255, 255, 100), name = "Amarillo", displayName = "RARO",    weight = 12},
	{color = Color3.fromRGB(85, 170, 255),  name = "Azul",     displayName = "INCOMUN", weight = 25},
	{color = Color3.fromRGB(220, 220, 220), name = "Blanco",   displayName = "COMUN",   weight = 54}
}

local CHEST_TIMEOUT = 15 -- segundos antes de que el cofre desaparezca y regenere cristal

-- Elegir rareza aleatoria basada en pesos
local function pickRarity()
	local total = 0
	for _, t in ipairs(CRYSTAL_TYPES) do
		total = total + t.weight
	end
	local roll = math.random(total)
	local cum = 0
	for _, t in ipairs(CRYSTAL_TYPES) do
		cum = cum + t.weight
		if roll <= cum then
			return t
		end
	end
	return CRYSTAL_TYPES[#CRYSTAL_TYPES]
end

-- Crear un cristal en una posicion con etiqueta bonita
local function createCrystal(position, crystalType, parent)
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Size = Vector3.new(2.5, 5, 2.5)
	crystal.Material = Enum.Material.Ice
	crystal.Transparency = 0.15
	crystal.Anchored = true
	crystal.CanCollide = true
	crystal.CanQuery = true
	crystal.Position = position
	crystal.Color = crystalType.color
	crystal.Parent = parent

	local rarityTag = Instance.new("StringValue")
	rarityTag.Name = "Rarity"
	rarityTag.Value = crystalType.name
	rarityTag.Parent = crystal

	-- HP = 1 (se rompe de un golpe)
	local hp = Instance.new("IntValue")
	hp.Name = "Health"
	hp.Value = 1
	hp.Parent = crystal

	local mhp = Instance.new("IntValue")
	mhp.Name = "MaxHealth"
	mhp.Value = 1
	mhp.Parent = crystal

	-- ============================================
	-- ETIQUETA BONITA DE RAREZA sobre el cristal
	-- ============================================
	local bb = Instance.new("BillboardGui")
	bb.Name = "RarityLabel"
	bb.Size = UDim2.new(4, 0, 1.5, 0)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 60
	bb.Parent = crystal

	-- Fondo oscuro con bordes redondeados
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.5
	bg.BorderSizePixel = 0
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

	-- Borde del color de la rareza
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = crystalType.color
	bgStroke.Thickness = 2
	bgStroke.Transparency = 0.2
	bgStroke.Parent = bg

	-- Texto del nombre de rareza
	local lbl = Instance.new("TextLabel")
	lbl.Name = "RarityText"
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = crystalType.displayName
	lbl.TextColor3 = crystalType.color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = bg

	-- Brillo sutil en el texto (UIStroke)
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(255, 255, 255)
	textStroke.Thickness = 1
	textStroke.Transparency = 0.7
	textStroke.Parent = lbl

	return crystal
end

-- Crear un cofre cuando se rompe un cristal
function CrystalSpawner.spawnChest(position, crystalType, player)
	local chest = Instance.new("Part")
	chest.Name = "Chest"
	chest.Size = Vector3.new(2, 2, 2)
	chest.Material = Enum.Material.SmoothPlastic
	chest.Anchored = true
	chest.CanCollide = false
	chest.Position = position + Vector3.new(0, 3, 0)
	chest.Color = crystalType.color
	chest.Parent = workspace

	-- Rareza del cofre
	local rt = Instance.new("StringValue")
	rt.Name = "Rarity"
	rt.Value = crystalType.name
	rt.Parent = chest

	-- Dueno del cofre (quien lo rompio)
	local ot = Instance.new("ObjectValue")
	ot.Name = "Owner"
	ot.Value = player
	ot.Parent = chest

	-- Encontrar displayName
	local displayName = crystalType.name
	for _, ct in ipairs(CRYSTAL_TYPES) do
		if ct.name == crystalType.name then
			displayName = ct.displayName
			break
		end
	end

	-- Etiqueta del cofre con estilo
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(4, 0, 1.5, 0)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = chest

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = crystalType.color
	bgStroke.Thickness = 1.5
	bgStroke.Transparency = 0.3
	bgStroke.Parent = bg

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0.6, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = displayName
	lbl.TextColor3 = crystalType.color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = bg

	local timerLbl = Instance.new("TextLabel")
	timerLbl.Name = "TimerLabel"
	timerLbl.Size = UDim2.new(1, 0, 0.4, 0)
	timerLbl.Position = UDim2.new(0, 0, 0.6, 0)
	timerLbl.BackgroundTransparency = 1
	timerLbl.Text = CHEST_TIMEOUT .. "s"
	timerLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
	timerLbl.TextScaled = true
	timerLbl.Font = Enum.Font.GothamBold
	timerLbl.Parent = bg

	-- Timer: si no se recoge, regenerar cristal
	task.spawn(function()
		for i = CHEST_TIMEOUT, 1, -1 do
			task.wait(1)
			if not chest or not chest.Parent then return end
			local tl = chest:FindFirstChild("BillboardGui")
			if tl then
				local f = tl:FindFirstChild("Frame")
				if f then
					local t = f:FindFirstChild("TimerLabel")
					if t then t.Text = i .. "s" end
				end
			end
		end
		-- Tiempo agotado: regenerar cristal y borrar cofre
		if chest and chest.Parent then
			local pos = chest.Position - Vector3.new(0, 3, 0)
			chest:Destroy()
			CrystalSpawner.respawn(pos)
		end
	end)

	return chest
end

function CrystalSpawner.spawnAll()
	local map = Workspace:FindFirstChild("Map")
	if not map then return end
	local zone = map:FindFirstChild("CrystalZone")
	if not zone then return end

	-- Limpiar cristales anteriores
	for _, c in ipairs(zone:GetChildren()) do
		if c.Name == "Crystal" then c:Destroy() end
	end

	zone.CanQuery = false
	zone.CanCollide = false
	zone.Transparency = 1

	local zonePos = zone.Position
	local zoneSize = zone.Size
	local halfX = zoneSize.X / 2 - 4
	local halfZ = zoneSize.Z / 2 - 4
	local topY = zonePos.Y + zoneSize.Y / 2 + 2.5
	local MIN_DISTANCE = 8

	local usedPositions = {}

	local function findValidPosition()
		for attempt = 1, 50 do
			local x = zonePos.X + math.random() * halfX * 2 - halfX
			local z = zonePos.Z + math.random() * halfZ * 2 - halfZ
			local pos = Vector3.new(x, topY, z)

			local valid = true
			for _, usedPos in ipairs(usedPositions) do
				if (pos - usedPos).Magnitude < MIN_DISTANCE then
					valid = false
					break
				end
			end

			if valid then
				return pos
			end
		end
		local x = zonePos.X + math.random() * halfX * 2 - halfX
		local z = zonePos.Z + math.random() * halfZ * 2 - halfZ
		return Vector3.new(x, topY, z)
	end

	for i = 1, 25 do
		local crystalType = pickRarity()
		local pos = findValidPosition()
		table.insert(usedPositions, pos)
		createCrystal(pos, crystalType, zone)
	end

	print("=== 25 cristales generados ===")
end

-- Respawn un cristal en una posicion (con nueva rareza aleatoria)
function CrystalSpawner.respawn(oldPos)
	task.delay(5, function()
		local map = Workspace:FindFirstChild("Map")
		if not map then return end
		local zone = map:FindFirstChild("CrystalZone")
		if not zone then return end

		local crystalType = pickRarity()
		createCrystal(oldPos, crystalType, zone)
	end)
end

return CrystalSpawner

-- ============================================
-- RebirthManager (ModuleScript) - ServerStorage/ServerModules
-- Sistema de Renacimiento (Rebirth) por rareza.
-- El jugador debe llenar 5 pisos (50 brainrots) de una rareza especifica
-- para poder renacer y obtener +20% de ganancias permanentes.
-- ============================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RebirthManager = {}

-- Rareza requerida para cada nivel de renacimiento
-- IMPORTANTE: los nombres deben coincidir con los que usa CrystalSpawner.lua
-- El juego guarda rarity = "Blanco", "Azul", "Amarillo", "Rojo", "Morado"
-- (NO usa "Comun", "Incomun", etc.)
local REBIRTH_RARITIES = {
	[1] = "Blanco",     -- COMUN
	[2] = "Azul",       -- INCOMUN
	[3] = "Amarillo",   -- RARO
	[4] = "Rojo",       -- EPICO
	[5] = "Morado",     -- MITICO
}

-- Nombres para mostrar al jugador (mas amigables)
local REBIRTH_RARITY_DISPLAY = {
	[1] = "Comun (Blanco)",
	[2] = "Incomun (Azul)",
	[3] = "Raro (Amarillo)",
	[4] = "Epico (Rojo)",
	[5] = "Mitico (Morado)",
}

local MAX_REBIRTH = 5
local REBIRTH_BONUS_PER_LEVEL = 20  -- +20% por cada renacimiento

-- Colores para el aura visual
local AURA_COLORS = {
	[1] = Color3.fromRGB(255, 255, 255),  -- blanco
	[2] = Color3.fromRGB(100, 200, 255),  -- azul
	[3] = Color3.fromRGB(255, 215, 0),    -- dorado
	[4] = Color3.fromRGB(255, 80, 80),    -- rojo
	[5] = Color3.fromRGB(180, 80, 255),   -- morado
}

-- Titulos por nivel
local REBIRTH_TITLES = {
	[1] = "Renacido I",
	[2] = "Renacido II",
	[3] = "Renacido III",
	[4] = "Renacido IV",
	[5] = "Leyenda",
}

-- ============================================
-- FUNCIONES DE CONSULTA
-- ============================================

-- Devuelve el nombre para mostrar de la rareza
function RebirthManager.getRequiredRarityDisplay(rebirthLevel)
	local nextLevel = (rebirthLevel or 0) + 1
	return REBIRTH_RARITY_DISPLAY[nextLevel]
end

-- Devuelve la rareza requerida para el proximo renacimiento
function RebirthManager.getRequiredRarity(rebirthLevel)
	local nextLevel = (rebirthLevel or 0) + 1
	return REBIRTH_RARITIES[nextLevel]
end

-- Devuelve el bonus total (boost comprado + rebirth) en porcentaje
function RebirthManager.getTotalBonusPercent(boostLevel, rebirthLevel)
	local boost = (boostLevel or 0) * 20
	local rebirth = (rebirthLevel or 0) * REBIRTH_BONUS_PER_LEVEL
	return boost + rebirth
end

-- Devuelve el bonus que tendria si renace ahora
function RebirthManager.getNextBonusPercent(boostLevel, rebirthLevel)
	local current = RebirthManager.getTotalBonusPercent(boostLevel, rebirthLevel)
	if (rebirthLevel or 0) >= MAX_REBIRTH then
		return current  -- ya esta al maximo
	end
	return current + REBIRTH_BONUS_PER_LEVEL
end

-- Devuelve true si el jugador puede renacer (tiene 50 brainrots de la rareza correcta)
-- playerData: la tabla de datos del jugador
-- characters: la lista de personajes serializados o en memoria
function RebirthManager.canRebirth(rebirthLevel, characters)
	local level = rebirthLevel or 0
	if level >= MAX_REBIRTH then return false end

	local requiredRarity = RebirthManager.getRequiredRarity(level)
	if not requiredRarity then return false end

	-- Contar brainrots de la rareza requerida
	local count = 0
	if characters then
		for _, charData in pairs(characters) do
			if charData and charData.rarity == requiredRarity then
				count = count + 1
			end
		end
	end

	return count >= 50, count, requiredRarity
end

-- Devuelve cuantos brainrots de la rareza requerida tiene el jugador
function RebirthManager.countRequiredBrainrots(rebirthLevel, characters)
	local level = rebirthLevel or 0
	local requiredRarity = RebirthManager.getRequiredRarity(level)
	if not requiredRarity then return 0, nil end

	local count = 0
	if characters then
		for _, charData in pairs(characters) do
			if charData and charData.rarity == requiredRarity then
				count = count + 1
			end
		end
	end
	return count, requiredRarity
end

-- ============================================
-- APLICAR RECOMPENSAS VISUALES
-- ============================================

function RebirthManager.applyVisualRewards(player, rebirthLevel)
	local level = rebirthLevel or 0
	if level <= 0 then return end

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Limpiar auras anteriores
	for _, part in ipairs(char:GetDescendants()) do
		if part.Name == "RebirthAuraAttachment" or part.Name == "RebirthTitle" or part.Name == "RebirthLight" then
			part:Destroy()
		end
	end
	local oldAtt = hrp:FindFirstChild("RebirthAuraAttachment")
	if oldAtt then oldAtt:Destroy() end
	local oldTitle = char:FindFirstChild("RebirthTitle")
	if oldTitle then oldTitle:Destroy() end

	local auraColor = AURA_COLORS[level] or Color3.fromRGB(255, 255, 255)
	local isMaxLevel = level >= 5

	-- ============================================
	-- AURA ULTRA ESPECTACULAR (5 capas + luz)
	-- ============================================

	local attachment = Instance.new("Attachment")
	attachment.Name = "RebirthAuraAttachment"
	attachment.Parent = hrp

	-- 1. LLAMARADA PRINCIPAL (ki flame subiendo)
	local flameEmitter = Instance.new("ParticleEmitter")
	flameEmitter.Name = "RebirthFlame"
	flameEmitter.Texture = "rbxasset://textures/particles/fire_base.dds"
	flameEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, auraColor),
		ColorSequenceKeypoint.new(0.3, auraColor),
		ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	flameEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isMaxLevel and 4 or 3),
		NumberSequenceKeypoint.new(0.4, isMaxLevel and 5 or 3.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	flameEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	flameEmitter.Lifetime = NumberRange.new(0.3, 0.5)
	flameEmitter.Rate = isMaxLevel and 80 or 60
	flameEmitter.Speed = NumberRange.new(4, 7)
	flameEmitter.SpreadAngle = Vector2.new(10, 10)
	flameEmitter.Rotation = NumberRange.new(0, 360)
	flameEmitter.RotSpeed = NumberRange.new(-360, 360)
	flameEmitter.Acceleration = Vector3.new(0, 12, 0)
	flameEmitter.LightEmission = 1
	flameEmitter.LightInfluence = 0
	flameEmitter.Parent = attachment

	-- 2. RAYOS ELECTRICOS (chispas violentas en todas direcciones)
	local electricEmitter = Instance.new("ParticleEmitter")
	electricEmitter.Name = "RebirthElectric"
	electricEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	electricEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	electricEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	electricEmitter.Transparency = NumberSequence.new(0)
	electricEmitter.Lifetime = NumberRange.new(0.1, 0.2)
	electricEmitter.Rate = isMaxLevel and 60 or 40
	electricEmitter.Speed = NumberRange.new(8, 15)
	electricEmitter.SpreadAngle = Vector2.new(360, 360)
	electricEmitter.Acceleration = Vector3.new(0, 8, 0)
	electricEmitter.LightEmission = 1
	electricEmitter.LightInfluence = 0
	electricEmitter.Parent = attachment

	-- 3. ANILLO DE ENERGIA (particulas que orbitan)
	local ringEmitter = Instance.new("ParticleEmitter")
	ringEmitter.Name = "RebirthRing"
	ringEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ringEmitter.Color = ColorSequence.new(auraColor)
	ringEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isMaxLevel and 3 or 2),
		NumberSequenceKeypoint.new(1, 0),
	})
	ringEmitter.Transparency = NumberSequence.new(0.2)
	ringEmitter.Lifetime = NumberRange.new(0.8, 1.2)
	ringEmitter.Rate = isMaxLevel and 20 or 15
	ringEmitter.Speed = NumberRange.new(2, 4)
	ringEmitter.SpreadAngle = Vector2.new(180, 0)
	ringEmitter.Rotation = NumberRange.new(0, 360)
	ringEmitter.RotSpeed = NumberRange.new(180, 360)
	ringEmitter.LightEmission = 1
	ringEmitter.Parent = attachment

	-- 4. EXPLOSIONES DE DESTELLOS (estrellas grandes que aparecen y desaparecen)
	local starEmitter = Instance.new("ParticleEmitter")
	starEmitter.Name = "RebirthStars"
	starEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	starEmitter.Color = ColorSequence.new(auraColor)
	starEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, isMaxLevel and 4 or 3),
		NumberSequenceKeypoint.new(0.8, isMaxLevel and 3 or 2),
		NumberSequenceKeypoint.new(1, 0),
	})
	starEmitter.Transparency = NumberSequence.new(0)
	starEmitter.Lifetime = NumberRange.new(1, 1.5)
	starEmitter.Rate = isMaxLevel and 12 or 8
	starEmitter.Speed = NumberRange.new(0, 1)
	starEmitter.SpreadAngle = Vector2.new(360, 360)
	starEmitter.LightEmission = 1
	starEmitter.Parent = attachment

	-- 5. HUMO/NEBLINA DE ENERGIA (base del aura)
	local smokeEmitter = Instance.new("ParticleEmitter")
	smokeEmitter.Name = "RebirthSmoke"
	smokeEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smokeEmitter.Color = ColorSequence.new(auraColor)
	smokeEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 5),
	})
	smokeEmitter.Transparency = NumberSequence.new(0.6)
	smokeEmitter.Lifetime = NumberRange.new(1, 1.5)
	smokeEmitter.Rate = isMaxLevel and 15 or 10
	smokeEmitter.Speed = NumberRange.new(1, 2)
	smokeEmitter.SpreadAngle = Vector2.new(45, 45)
	smokeEmitter.Acceleration = Vector3.new(0, 3, 0)
	smokeEmitter.LightEmission = 0.5
	smokeEmitter.Parent = attachment

	-- 6. DOBLES LUCES (para mas efecto)
	local light1 = Instance.new("PointLight")
	light1.Name = "RebirthLight"
	light1.Color = auraColor
	light1.Range = isMaxLevel and 20 or 15
	light1.Brightness = isMaxLevel and 5 or 4
	light1.Parent = hrp

	local light2 = Instance.new("PointLight")
	light2.Name = "RebirthLight2"
	light2.Color = Color3.new(1, 1, 1)
	light2.Range = isMaxLevel and 10 or 8
	light2.Brightness = 3
	light2.Parent = hrp

	-- TITULO GIGANTE sobre la cabeza
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "RebirthTitle"
	titleGui.Size = UDim2.new(0, isMaxLevel and 350 or 280, 0, isMaxLevel and 70 or 55)
	titleGui.StudsOffset = Vector3.new(0, 4, 0)
	titleGui.AlwaysOnTop = true
	titleGui.Parent = char

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = REBIRTH_TITLES[level] or ""
	titleLabel.TextColor3 = auraColor
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	titleLabel.Parent = titleGui
end

-- ============================================
-- EJECUTAR RENACIMIENTO
-- ============================================
-- Esta funcion debe ser llamada desde el GameHandler que tiene acceso a
-- playerData, BankManager, SaveManager, etc.
-- Le pasamos callbacks para no acoplar el modulo.

function RebirthManager.performRebirth(player, callbacks)
	local userId = player.UserId

	-- callbacks debe tener:
	-- getRebirthLevel(userId) -> number
	-- getCharacters(userId) -> table de personajes
	-- resetProgress(userId) -> resetea money, bank, baseLevel, bloques, pelotas
	-- setRebirthLevel(userId, level)
	-- saveData(userId)
	-- notifyClient(player, newLevel, bonusPercent)

	local currentLevel = callbacks.getRebirthLevel(userId) or 0
	if currentLevel >= MAX_REBIRTH then
		warn("[Rebirth] " .. player.Name .. " ya esta en el nivel maximo")
		return false, "Ya estas en el nivel maximo de renacimiento"
	end

	local canRebirth, count, requiredRarity = RebirthManager.canRebirth(currentLevel, callbacks.getCharacters(userId))
	if not canRebirth then
		warn("[Rebirth] " .. player.Name .. " no cumple los requisitos (" .. count .. "/50 " .. requiredRarity .. ")")
		return false, "Necesitas 50 brainrots " .. requiredRarity .. " (tienes " .. count .. ")"
	end

	-- 1. Resetear todo el progreso (menos boostLevel y rebirthLevel)
	if callbacks.resetProgress then
		callbacks.resetProgress(userId)
	end

	-- 2. Incrementar rebirthLevel
	local newLevel = currentLevel + 1
	if callbacks.setRebirthLevel then
		callbacks.setRebirthLevel(userId, newLevel)
	end

	-- 3. Guardar
	if callbacks.saveData then
		callbacks.saveData(userId)
	end

	-- 4. Aplicar recompensas visuales
	RebirthManager.applyVisualRewards(player, newLevel)

	-- 5. Notificar al cliente
	local boostLevel = callbacks.getBoostLevel and callbacks.getBoostLevel(userId) or 0
	local bonusPercent = RebirthManager.getTotalBonusPercent(boostLevel, newLevel)
	if callbacks.notifyClient then
		callbacks.notifyClient(player, newLevel, bonusPercent)
	end

	-- 6. Respawnear al jugador (para que empiece limpio)
	player:LoadCharacter()

	print("[Rebirth] " .. player.Name .. " renacio al nivel " .. newLevel .. " (bonus total: +" .. bonusPercent .. "%)")
	return true, newLevel
end

-- Re-aplicar recompensas visuales al respawear (desde GameHandler.CharacterAdded)
function RebirthManager.onCharacterAdded(player, rebirthLevel)
	RebirthManager.applyVisualRewards(player, rebirthLevel)
end

return RebirthManager

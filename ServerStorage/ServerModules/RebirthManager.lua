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
local REBIRTH_RARITIES = {
	[1] = "Comun",      -- blanco
	[2] = "Incomun",    -- azul
	[3] = "Raro",       -- amarillo
	[4] = "Epico",      -- rojo
	[5] = "Mitico",     -- morado
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

	-- Eliminar aura anterior si existe
	local oldAura = hrp:FindFirstChild("RebirthAura")
	if oldAura then oldAura:Destroy() end

	local oldTitle = char:FindFirstChild("RebirthTitle")
	if oldTitle then oldTitle:Destroy() end

	-- Crear nueva aura
	local auraColor = AURA_COLORS[level] or Color3.fromRGB(255, 255, 255)
	local attachment = Instance.new("Attachment")
	attachment.Name = "RebirthAuraAttachment"
	attachment.Parent = hrp

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RebirthAura"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(auraColor)
	emitter.Size = NumberSequence.new(0.5, 1.2)
	emitter.Lifetime = NumberRange.new(0.5, 1.0)
	emitter.Rate = 15
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = attachment

	-- Crear titulo sobre la cabeza
	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "RebirthTitle"
	titleGui.Size = UDim2.new(0, 200, 0, 40)
	titleGui.StudsOffset = Vector3.new(0, 3, 0)
	titleGui.AlwaysOnTop = true
	titleGui.Parent = char

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = REBIRTH_TITLES[level] or ""
	titleLabel.TextColor3 = auraColor
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextStrokeTransparency = 0.3
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

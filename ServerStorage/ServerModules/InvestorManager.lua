-- ============================================
-- InvestorManager (ModuleScript) - ServerStorage/ServerModules
-- Sistema de Inversionistas (estilo Sell Lemons)
--
-- Trackea totalMoneyEarnedThisLife para calcular cuantos inversionistas
-- ganaria el jugador si renace. Los inversionistas dan +0.5% de bonus
-- permanente a todas las ganancias (acumulable, se multiplica con evolucion y boost).
-- ============================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local InvestorManager = {}

-- Configuracion
local INVESTOR_BONUS_PER_UNIT = 0.01  -- +1% por inversionista (0.01 = 1%)
local MONEY_DIVISOR = 1e6  -- 1 millon como base para calcular inversionistas
local EXPONENT = 0.6  -- curva decreciente (rendimiento marginal)

-- ============================================
-- CALCULO DE INVERSIONISTAS
-- ============================================

-- Calcular cuantos inversionistas ganaria el jugador al renacer
-- Basado en el dinero total generado esta vida
function InvestorManager.calculateInvestorsGained(totalMoneyEarnedThisLife)
        local money = totalMoneyEarnedThisLife or 0
        if money < MONEY_DIVISOR then return 0 end
        local investors = math.floor((money / MONEY_DIVISOR) ^ EXPONENT)
        return math.max(0, investors)
end

-- Multiplicador de bonus por inversionistas
-- 0 inversionistas = x1, 100 = x2, 1000 = x11, 10000 = x101, etc.
function InvestorManager.getInvestorMultiplier(totalInvestors)
        local count = totalInvestors or 0
        return 1 + (count * INVESTOR_BONUS_PER_UNIT)
end

-- ============================================
-- SISTEMA DE CARTEL DE INVERSIONISTAS (Opcion B)
-- ============================================
-- El cartel crece en altura y da un bonus de multiplicador global
-- basado en la cantidad de inversionistas acumulados.

-- Nivel del cartel: 1 nivel por cada 100 inversionistas (logaritmico)
-- 1 inv = nivel 1, 100 inv = nivel 1, 1000 inv = nivel 10, 10000 = nivel 100
function InvestorManager.getSignLevel(totalInvestors)
        local count = totalInvestors or 0
        if count <= 0 then return 1 end
        -- log base 100: 1=0, 100=1, 1000=2, 10000=3...
        -- Pero queremos que sea 1 nivel por cada 100 inv
        -- Nivel = floor(log10(count) * 2) aproximado, minimo 1
        local level = math.floor(math.log10(count) * 2)
        return math.max(1, level)
end

-- Altura del cartel en studs: 3 + log10(inversionistas) * 3
-- 1 inv = 3, 100 = 9, 1000 = 12, 10000 = 15, 100000 = 18, 1M = 21, 1B = 30
function InvestorManager.getSignHeight(totalInvestors)
        local count = totalInvestors or 0
        if count <= 0 then return 3 end
        local height = 3 + math.log10(count) * 3
        -- Limitar a maximo 35 studs para no romper el mapa
        return math.min(35, math.max(3, height))
end

-- Multiplicador global del cartel: 1 + nivel * 0.05 (5% por nivel)
-- Nivel 1 = x1.05, Nivel 10 = x1.5, Nivel 100 = x6, Nivel 1000 = x51
function InvestorManager.getSignMultiplier(totalInvestors)
        local level = InvestorManager.getSignLevel(totalInvestors)
        return 1 + (level * 0.05)
end

-- Color del cartel segun el nivel (escala de rareza)
function InvestorManager.getSignColor(totalInvestors)
        local level = InvestorManager.getSignLevel(totalInvestors)
        -- Escala de colores: verde -> azul -> amarillo -> rojo -> morado
        if level >= 1000 then return Color3.fromRGB(180, 80, 255) end   -- morado
        if level >= 100 then return Color3.fromRGB(255, 80, 80) end     -- rojo
        if level >= 10 then return Color3.fromRGB(255, 215, 0) end      -- amarillo
        if level >= 2 then return Color3.fromRGB(100, 200, 255) end     -- azul
        return Color3.fromRGB(100, 255, 100)                            -- verde
end

-- ============================================
-- TABLA DE PROGRESO (para mostrar en UI)
-- ============================================

-- Devuelve informacion completa del jugador para la UI
function InvestorManager.getPlayerInfo(playerData)
        if not playerData then return nil end
        local totalEarned = playerData.totalMoneyEarnedThisLife or 0
        local currentInvestors = playerData.investors or 0
        local investorsGained = InvestorManager.calculateInvestorsGained(totalEarned)
        local totalAfterRebirth = currentInvestors + investorsGained
        local currentMultiplier = InvestorManager.getInvestorMultiplier(currentInvestors)
        local nextMultiplier = InvestorManager.getInvestorMultiplier(totalAfterRebirth)

        return {
                currentInvestors = currentInvestors,
                investorsGained = investorsGained,
                totalAfterRebirth = totalAfterRebirth,
                currentMultiplier = currentMultiplier,
                nextMultiplier = nextMultiplier,
                totalMoneyEarnedThisLife = totalEarned,
                canRebirth = investorsGained > 0,
        }
end

-- ============================================
-- RENACER (REBIRTH DE INVERSIONISTAS)
-- ============================================

-- Ejecutar el renacimiento de inversionistas
-- callbacks debe tener:
--   get playerData, resetProgress(userId), setInvestors(userId, newTotal),
--   saveData(userId), notifyClient(player, info), respawnPlayer(player)
function InvestorManager.performRebirth(player, callbacks)
        if not player or not callbacks then return false, "Parametros invalidos" end

        local userId = player.UserId
        local playerData = callbacks.getPlayerData(userId)
        if not playerData then return false, "Sin playerData" end

        local totalEarned = playerData.totalMoneyEarnedThisLife or 0
        local currentInvestors = playerData.investors or 0
        local investorsGained = InvestorManager.calculateInvestorsGained(totalEarned)

        if investorsGained <= 0 then
                return false, "No tienes suficientes inversionistas para renacer"
        end

        local newTotal = currentInvestors + investorsGained

        -- 1. Resetear progreso temporal (dinero, brainrots, base, bloques, pelotas)
        if callbacks.resetProgress then
                callbacks.resetProgress(userId)
        end

        -- 2. Resetear totalMoneyEarnedThisLife a 0
        if callbacks.setTotalMoneyEarned then
                callbacks.setTotalMoneyEarned(userId, 0)
        end

        -- 3. Setear nuevo total de inversionistas
        if callbacks.setInvestors then
                callbacks.setInvestors(userId, newTotal)
        end

        -- 4. Guardar
        if callbacks.saveData then
                callbacks.saveData(userId)
        end

        -- 5. Notificar al cliente
        local info = {
                currentInvestors = newTotal,
                investorsGained = 0,  -- ya se sumaron
                totalAfterRebirth = newTotal,
                currentMultiplier = InvestorManager.getInvestorMultiplier(newTotal),
                nextMultiplier = InvestorManager.getInvestorMultiplier(newTotal),
                totalMoneyEarnedThisLife = 0,
                canRebirth = false,
        }
        if callbacks.notifyClient then
                callbacks.notifyClient(player, info)
        end

        -- 6. Respawnear al jugador
        if callbacks.respawnPlayer then
                callbacks.respawnPlayer(player)
        end

        print("[Investors] " .. player.Name .. " renacio. Inversionistas: " .. currentInvestors .. " -> " .. newTotal .. " (gano " .. investorsGained .. ")")
        return true, newTotal
end

-- Re-aplicar efectos visuales al respawnear (placeholder por si se quiere aura de millonario)
function InvestorManager.onCharacterAdded(player, investorCount)
        -- TODO: aura visual de millonario si se quiere
end

return InvestorManager

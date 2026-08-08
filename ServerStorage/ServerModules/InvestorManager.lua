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
local INVESTOR_BONUS_PER_UNIT = 0.005  -- +0.5% por inversionista (0.005 = 0.5%)
local MONEY_DIVISOR = 1e9  -- 1 billon como base para calcular inversionistas
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
-- 0 inversionistas = x1, 1000 = x6, 10000 = x51, etc.
function InvestorManager.getInvestorMultiplier(totalInvestors)
        local count = totalInvestors or 0
        return 1 + (count * INVESTOR_BONUS_PER_UNIT)
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

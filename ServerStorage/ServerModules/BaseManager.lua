-- ============================================
-- BaseManager (ModuleScript) - ServerStorage/ServerModules
-- Asigna bases a jugadores al entrar
-- Muestra nombre y cara en el cartel
-- Maneja el nivel de mejora de la base
-- Libera base al salir
-- ============================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local BaseManager = {}

local assignedBases = {}
local playerBases = {}
local baseLevels = {} -- [userId] = nivel (1=sin mejora, 2=segundo piso)

-- Costo de mejora (TEST - ajustable en el futuro)
local UPGRADE_COSTS = {
        [2] = 1000000,           -- Nivel 1 -> 2: 1M
        [3] = 100000000,         -- Nivel 2 -> 3: 100M
        [4] = 1000000000,        -- Nivel 3 -> 4: 1000M (1B)
        [5] = 100000000000,      -- Nivel 4 -> 5: 100B
}

function BaseManager.getBase(userId)
        return playerBases[userId]
end

function BaseManager.getBaseLevel(userId)
        return baseLevels[userId] or 1
end

function BaseManager.setBaseLevel(userId, level)
        baseLevels[userId] = level
end

function BaseManager.getUpgradeCost(currentLevel)
        return UPGRADE_COSTS[currentLevel + 1] or math.huge
end

function BaseManager.assign(player)
        -- Si ya tiene base, devolverla
        if playerBases[player.UserId] then
                return playerBases[player.UserId]
        end

        local map = Workspace:FindFirstChild("Map")
        if not map then return nil end
        local bases = map:FindFirstChild("Bases")
        if not bases then return nil end

        -- Buscar base libre
        for _, base in ipairs(bases:GetChildren()) do
                if not assignedBases[base.Name] then
                        assignedBases[base.Name] = player.UserId
                        playerBases[player.UserId] = base
                        baseLevels[player.UserId] = 1 -- Nivel 1 por defecto

                        -- Actualizar cartel
                        local sign = base:FindFirstChild("BaseSign")
                        if sign then
                                pcall(function()
                                        local sg = sign:FindFirstChild("SurfaceGui")
                                        if sg then
                                                -- Nombre del jugador
                                                local lbl = sg:FindFirstChild("PlayerName")
                                                if lbl then lbl.Text = player.Name end

                                                -- Cara del jugador
                                                local face = sg:FindFirstChild("PlayerFace")
                                                if face then
                                                        local thumbType = Enum.ThumbnailType.HeadShot
                                                        local thumbSize = Enum.ThumbnailSize.Size100x100
                                                        local content, isReady = Players:GetUserThumbnailAsync(player.UserId, thumbType, thumbSize)
                                                        if content then
                                                                face.Image = content
                                                        end
                                                end
                                        end
                                end)
                        end

                        print("Base asignada a " .. player.Name .. ": " .. base.Name)
                        return base
                end
        end

        print("No hay bases disponibles para " .. player.Name)
        return nil
end

function BaseManager.release(userId)
        local base = playerBases[userId]
        if not base then return end

        assignedBases[base.Name] = nil

        -- Limpiar cartel
        local sign = base:FindFirstChild("BaseSign")
        if sign then
                pcall(function()
                        local sg = sign:FindFirstChild("SurfaceGui")
                        if sg then
                                local lbl = sg:FindFirstChild("PlayerName")
                                if lbl then lbl.Text = "Libre" end

                                local face = sg:FindFirstChild("PlayerFace")
                                if face then face.Image = "" end
                        end
                end)
        end

        playerBases[userId] = nil
        baseLevels[userId] = nil
end

return BaseManager




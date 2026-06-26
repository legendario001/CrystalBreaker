-- ============================================
-- GameHandler (Script) - ServerScriptService
-- Script principal del servidor
-- ============================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CrystalSpawner = require(ServerStorage.ServerModules.CrystalSpawner)
local Events = require(game:GetService("ReplicatedStorage").RemoteEvents)

-- ============================================
-- LANZAR PELOTA AL CRISTAL
-- ============================================
Events.ThrowBall.OnServerEvent:Connect(function(player, targetPos)
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        local zone = map:FindFirstChild("CrystalZone")
        if not zone then return end

        -- Buscar cristal mas cercano a la posicion
        local nearest = nil
        local nearDist = 15

        for _, c in ipairs(zone:GetChildren()) do
                if c.Name == "Crystal" then
                        local d = (c.Position - targetPos).Magnitude
                        if d < nearDist then
                                nearDist = d
                                nearest = c
                        end
                end
        end

        if not nearest then return end

        -- Reducir vida del cristal
        local hp = nearest:FindFirstChild("Health")
        if not hp then return end
        hp.Value = hp.Value - 1

        -- Si el cristal se rompe
        if hp.Value <= 0 then
                local rt = nearest:FindFirstChild("Rarity")
                local rarity = rt and rt.Value or "Blanco"
                local crystalColor = nearest.Color
                local pos = nearest.Position

                -- Buscar tipo de cristal por nombre
                local crystalType = {color = crystalColor, name = rarity}

                nearest:Destroy()

                -- Generar cofre
                CrystalSpawner.spawnChest(pos, crystalType, player)
        end
end)

-- ============================================
-- RECOGER COFRE (E)
-- ============================================
Events.PickupChest.OnServerEvent:Connect(function(player)
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- Buscar cofre mas cercano del jugador
        local nearest = nil
        local nearDist = 15

        for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "Chest" then
                        local owner = obj:FindFirstChild("Owner")
                        if owner and owner.Value == player then
                                local d = (obj.Position - root.Position).Magnitude
                                if d < nearDist then
                                        nearDist = d
                                        nearest = obj
                                end
                        end
                end
        end

        if not nearest then return end

        local rt = nearest:FindFirstChild("Rarity")
        local rarity = rt and rt.Value or "Blanco"

        -- Por ahora solo destruir el cofre y regenerar cristal
        -- Mas adelante aqui se dara el personaje al jugador
        local pos = nearest.Position - Vector3.new(0, 3, 0)
        nearest:Destroy()
        CrystalSpawner.respawn(pos)

        print(player.Name .. " recogio cofre " .. rarity)
end)

-- ============================================
-- INICIO
-- ============================================
task.delay(3, function()
        CrystalSpawner.spawnAll()
end)

Players.PlayerAdded:Connect(function(player)
        print(player.Name .. " se unio al juego")
end)

Players.PlayerRemoving:Connect(function(player)
        print(player.Name .. " salio del juego")
end)

print("=== GameHandler iniciado correctamente ===")

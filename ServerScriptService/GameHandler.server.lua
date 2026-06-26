-- ============================================
-- GameHandler (Script) - ServerScriptService
-- Script principal del servidor
-- ============================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CrystalSpawner = require(ServerStorage.ServerModules.CrystalSpawner)

-- Generar cristales al iniciar
task.delay(3, function()
	CrystalSpawner.spawnAll()
end)

-- Jugador entra
Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " se unio al juego")
end)

-- Jugador sale
Players.PlayerRemoving:Connect(function(player)
	print(player.Name .. " salio del juego")
end)

print("=== GameHandler iniciado correctamente ===")

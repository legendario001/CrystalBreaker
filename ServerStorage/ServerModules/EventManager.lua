-- ============================================
-- EventManager (ModuleScript) - ServerStorage/ServerModules
-- Controla el "Evento del Magnate de la Podredumbre".
-- Lluvia de pelotas que destruye todos los cristales del mapa periódicamente.
-- Optimizado: no crea pelotas físicas, solo partículas visuales + ruptura directa.
-- ============================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EventManager = {}

-- Configuracion del evento
local EVENT_INTERVAL = 10800 -- 3 horas entre eventos (en segundos)
local EVENT_DURATION = 30    -- duracion total del evento (en segundos)
local WAVE_INTERVAL = 5      -- cada cuantos segundos se rompen todos los cristales (coincide con el respawn de 5s)

local isEventActive = false
local eventLoopConnection = nil

-- Referencias inyectadas
local CrystalSpawner = nil
local GameHandlerDeps = nil

-- ============================================
-- Inicializacion
-- ============================================
function EventManager.init(deps)
        CrystalSpawner = deps.CrystalSpawner
        GameHandlerDeps = deps
        print("[EventManager] Inicializado. Proximo evento en " .. (EVENT_INTERVAL / 3600) .. " horas")
        
        -- Iniciar loop principal de chequeo del evento
        task.spawn(function()
                while true do
                        task.wait(EVENT_INTERVAL)
                        EventManager.startEvent()
                end
        end)
end

-- ============================================
-- Obtener cristales y zona
-- ============================================
local function getCrystalZone()
        local map = Workspace:FindFirstChild("Map")
        if not map then return nil end
        return map:FindFirstChild("CrystalZone")
end

local function getAllCrystals()
        local zone = getCrystalZone()
        if not zone then return {} end
        
        local crystals = {}
        for _, child in ipairs(zone:GetChildren()) do
                if child.Name == "Crystal" and child:IsA("BasePart") then
                        table.insert(crystals, child)
                end
        end
        return crystals
end

-- ============================================
-- Romper todos los cristales (Oleada)
-- ============================================
local function breakWave()
        local crystals = getAllCrystals()
        local zone = getCrystalZone()
        
        if #crystals == 0 then return end
        
        -- Obtener un jugador valido para asignar el cofre (o nil si no hay)
        local players = Players:GetPlayers()
        local randomPlayer = #players > 0 and players[math.random(#players)] or nil
        
        for _, crystal in ipairs(crystals) do
                local rt = crystal:FindFirstChild("Rarity")
                local rarity = rt and rt.Value or "Blanco"
                local pos = crystal.Position
                local crystalColor = crystal.Color
                
                -- Destruir cristal
                crystal:Destroy()
                
                -- Spawnear cofre (como lo hace el GameHandler)
                if CrystalSpawner then
                        pcall(function()
                                CrystalSpawner.spawnChest(pos, {color=crystalColor, name=rarity}, randomPlayer)
                        end)
                end
        end
        
        print("[EventManager] Oleada completada: " .. #crystals .. " cristales rotos")
end

-- ============================================
-- Efectos visuales de la lluvia (Particulas)
-- ============================================
local function createRainEffect()
        local zone = getCrystalZone()
        if not zone then return nil end
        
        local zonePos = zone.Position
        local zoneSize = zone.Size
        
        -- Crear Part invisible arriba de la zona de cristales
        local rainPart = Instance.new("Part")
        rainPart.Name = "BallRainEffect"
        rainPart.Anchored = true
        rainPart.CanCollide = false
        rainPart.CanQuery = false
        rainPart.CanTouch = false
        rainPart.Transparency = 1
        rainPart.Size = Vector3.new(zoneSize.X, 1, zoneSize.Z)
        -- Posicionar arriba de la zona, alto en el cielo
        rainPart.Position = Vector3.new(zonePos.X, zonePos.Y + 80, zonePos.Z)
        rainPart.Parent = Workspace
        
        -- ParticleEmitter que simula pelotas cayendo
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "RainEmitter"
        -- Usar una textura de pelota/circulo
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 255)),
        })
        emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 2),
                NumberSequenceKeypoint.new(1, 3),
        })
        emitter.Transparency = NumberSequence.new(0.2)
        emitter.Lifetime = NumberRange.new(2, 3)
        emitter.Rate = 200 -- 200 particulas por segundo
        emitter.Speed = NumberRange.new(40, 60) -- caen rapido
        emitter.SpreadAngle = Vector2.new(15, 15)
        emitter.Acceleration = Vector3.new(0, -20, 0) -- gravedad
        emitter.LightEmission = 0.5
        emitter.Parent = rainPart
        
        return rainPart
end

-- ============================================
-- Notificar a clientes (para UI de anuncio)
-- ============================================
local function notifyClients(eventName, message, duration)
        local event = ReplicatedStorage:FindFirstChild("EventAnnouncement")
        if event then
                for _, player in ipairs(Players:GetPlayers()) do
                        pcall(function()
                                event:FireClient(player, {
                                        eventName = eventName,
                                        message = message,
                                        duration = duration or 5,
                                })
                        end)
                end
        end
end

-- ============================================
-- Iniciar el evento
-- ============================================
function EventManager.startEvent()
        if isEventActive then return end
        isEventActive = true
        
        print("[EventManager] === EVENTO DEL MAGNATE DE LA PODREDUMBRE INICIADO ===")
        
        -- 1. Anuncio inicial (10 segundos de countdown)
        notifyClients("⚠️ EVENTO INMINENTE ⚠️", "¡Lluvia de Pelotas en 10 segundos! Ve a la zona de cristales", 10)
        task.wait(10)
        
        -- 2. Anuncio de inicio
        notifyClients("🌧️ EVENTO ACTIVO 🌧️", "¡Los cristales estan siendo destruidos! Recoge los cofres", EVENT_DURATION)
        
        -- 3. Crear efecto visual de lluvia
        local rainEffect = createRainEffect()
        
        -- 4. Loop de oleadas (cada WAVE_INTERVAL segundos)
        local startTime = os.clock()
        local waveCount = 0
        
        while os.clock() - startTime < EVENT_DURATION do
                waveCount = waveCount + 1
                print("[EventManager] Iniciando oleada " .. waveCount)
                breakWave()
                task.wait(WAVE_INTERVAL)
        end
        
        -- 5. Fin del evento
        if rainEffect then
                rainEffect:Destroy()
        end
        
        isEventActive = false
        print("[EventManager] === EVENTO FINALIZADO === (" .. waveCount .. " oleadas completadas)")
        notifyClients("✅ EVENTO FINALIZADO", "El evento ha terminado. ¡Hasta la próxima!", 5)
end

-- Forzar inicio del evento (para testing desde Command Bar)
function EventManager.forceStart()
        task.spawn(function()
                EventManager.startEvent()
        end)
end

return EventManager

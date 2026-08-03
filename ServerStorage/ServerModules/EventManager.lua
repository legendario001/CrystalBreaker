-- ============================================
-- EventManager (ModuleScript) - ServerStorage/ServerModules
-- Controla el "Evento del Magnate de la Podredumbre".
-- ============================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EventManager = {}

-- TEMPORAL PARA TESTEAR: 60s evento, 60s cooldown
local EVENT_NAME = "Evento del Magnate de la Podredumbre"

-- Sistema progresivo de eventos (para servidores vacios o con pocos jugadores)
-- Escala: intervalo y duracion aumentan gradualmente hasta llegar al maximo
local PROGRESSIVE_SCALE = {
        { interval = 60,  duration = 30,  msg = "El proximo evento sera mas largo!" },
        { interval = 120, duration = 60,  msg = "El proximo evento sera mas largo!" },
        { interval = 180, duration = 90,  msg = "El proximo evento sera mas largo!" },
        { interval = 240, duration = 120, msg = "El proximo evento sera mas largo!" },
}
local FINAL_INTERVAL = 300   -- 5 minutos (intervalo final repetitivo)
local FINAL_DURATION = 180   -- 3 minutos (duracion final repetitiva)
local WAVE_INTERVAL = 5      -- cada 5s se rompen los cristales
local CRYSTAL_BREAK_TIME = 50 -- los cristales tardan hasta 50s en romperse todos

local eventCount = 0 -- contador de eventos (se reinicia si el server esta vacio)
local playerLeftTimer = 0    -- cuenta cuanto tiempo el server ha estado vacio

local isEventActive = false
local eventCooldown = 0  -- cooldown para evitar race condition al terminar evento
local timeUntilEvent = 60  -- primer evento en 1 minuto
local timeRemaining = 0

-- Musica del evento (2 temas que se alternan en cada evento)
local EVENT_MUSIC = {
        { name = "Magnate de la Podredumbre", soundId = "rbxassetid://130094886005121" },
        { name = "Brain Rot Tycoon (Mystic Mix)", soundId = "rbxassetid://100045289136245" },
        { name = "Harp Hero Tycoon (Retro Game)", soundId = "rbxassetid://86498434699930" },
        { name = "Mystic Retro", soundId = "rbxassetid://117592700598857" },
}
local eventMusicIndex = 1  -- alterna entre 1 y 2
local eventSound = nil  -- referencia al sonido activo del evento

-- Sonidos de cristal rompiendose (mismos que usa el GameHandler)
local CRYSTAL_BREAK_SOUNDS = {
        "rbxassetid://124054125419097",
        "rbxassetid://138817960173178",
        "rbxassetid://129395018150183",
        "rbxassetid://92650188901933"
}

-- Helper: reproducir sonido en una posicion (optimizado, se destruye solo)
local function playSoundAt(soundId, position)
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.5
        sound.Parent = Workspace
        -- Mover un Part temporal para posicionar el sonido 3D
        local anchor = Instance.new("Part")
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Position = position
        anchor.Parent = Workspace
        sound.Parent = anchor
        sound:Play()
        -- Limpiar despues de que termine (optimizacion de memoria)
        task.delay(3, function()
                if anchor and anchor.Parent then anchor:Destroy() end
        end)
end

local isEventActive = false
local eventCooldown = 0  -- cooldown para evitar race condition al terminar evento
local timeUntilEvent = 60  -- primer evento en 1 minuto
local timeRemaining = 0

local CrystalSpawner = nil

function EventManager.init(deps)
        CrystalSpawner = deps.CrystalSpawner
        print("[EventManager] Inicializado. Primer evento en 60s, luego progresivo hasta 5min")

        -- Loop principal: envia timer a clientes cada segundo
        task.spawn(function()
                while true do
                        task.wait(1)
                        
                        -- Detectar si el server esta vacio para reiniciar la progresion
                        if #Players:GetPlayers() == 0 then
                                playerLeftTimer = playerLeftTimer + 1
                                if playerLeftTimer >= 30 then
                                        -- Server vacio por 30s: reiniciar progresion
                                        eventCount = 0
                                        timeUntilEvent = 60
                                        playerLeftTimer = 0
                                end
                        else
                                playerLeftTimer = 0
                        end
                        
                        if not isEventActive then
                                if eventCooldown > 0 then
                                        eventCooldown = eventCooldown - 1
                                elseif timeUntilEvent <= 0 then
                                        task.spawn(function()
                                                EventManager.startEvent()
                                        end)
                                else
                                        timeUntilEvent = timeUntilEvent - 1
                                        EventManager.sendTimerUpdate("waiting", timeUntilEvent)
                                end
                        else
                                timeRemaining = timeRemaining - 1
                                EventManager.sendTimerUpdate("active", timeRemaining)
                        end
                end
        end)
end

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

local function breakWave()
        local crystals = getAllCrystals()
        if #crystals == 0 then return end
        local players = Players:GetPlayers()
        local randomPlayer = #players > 0 and players[math.random(#players)] or nil
        
        -- Romper cristales uno por uno con delay aleatorio (simula lluvia cayendo)
        -- Mezclar orden aleatorio
        for i = #crystals, 2, -1 do
                local j = math.random(i)
                crystals[i], crystals[j] = crystals[j], crystals[i]
        end
        
        local crystalCount = #crystals
        for i, crystal in ipairs(crystals) do
                task.spawn(function()
                        -- Delay aleatorio entre 0 y 10 segundos para simular lluvia golpeando al azar
                        -- Optimizado: si hay pocos cristales, el delay se reparte entre ellos
                        local maxDelay = math.min(CRYSTAL_BREAK_TIME, crystalCount * (CRYSTAL_BREAK_TIME / 25))
                        task.wait(math.random() * maxDelay)
                        
                        if not crystal or not crystal.Parent then return end
                        
                        local rt = crystal:FindFirstChild("Rarity")
                        local rarity = rt and rt.Value or "Blanco"
                        local pos = crystal.Position
                        local crystalColor = crystal.Color
                        
                        -- Sonido + efecto visual combinados en 1 solo Part (optimizado)
                        local snd = CRYSTAL_BREAK_SOUNDS[math.random(#CRYSTAL_BREAK_SOUNDS)]
                        
                        local impactPart = Instance.new("Part")
                        impactPart.Name = "RainImpact"
                        impactPart.Anchored = true
                        impactPart.CanCollide = false
                        impactPart.CanQuery = false
                        impactPart.CanTouch = false
                        impactPart.Material = Enum.Material.Neon
                        impactPart.Color = Color3.fromRGB(255, 255, 255)
                        impactPart.Size = Vector3.new(0.5, 50, 0.5)
                        impactPart.Position = Vector3.new(pos.X, pos.Y + 30, pos.Z)
                        impactPart.Transparency = 0.2
                        impactPart.Parent = Workspace
                        
                        -- Reproducir sonido directamente en el impactPart (1 solo objeto)
                        local sound = Instance.new("Sound")
                        sound.SoundId = snd
                        sound.Volume = 0.5
                        sound.Parent = impactPart
                        sound:Play()
                        
                        -- Desaparecer el rayo + sonido rapidamente
                        task.delay(0.3, function()
                                if impactPart and impactPart.Parent then
                                        impactPart:Destroy()
                                end
                        end)
                        
                        crystal:Destroy()
                        
                        if CrystalSpawner then
                                pcall(function()
                                        CrystalSpawner.spawnChest(pos, {color=crystalColor, name=rarity}, randomPlayer)
                                end)
                        end
                end)
        end
        print("[EventManager] Oleada: " .. #crystals .. " cristales programados para romperse")
end

local function createRainEffect()
        local zone = getCrystalZone()
        if not zone then return nil end
        local zonePos = zone.Position
        local zoneSize = zone.Size
        
        local rainPart = Instance.new("Part")
        rainPart.Name = "BallRainEffect"
        rainPart.Anchored = true
        rainPart.CanCollide = false
        rainPart.CanQuery = false
        rainPart.CanTouch = false
        rainPart.Transparency = 1
        rainPart.Size = Vector3.new(zoneSize.X, 1, zoneSize.Z)
        rainPart.Position = Vector3.new(zonePos.X, zonePos.Y + 80, zonePos.Z)
        rainPart.Parent = Workspace
        
        -- Lluvia de pelotas visuales (particulas grandes y brillantes)
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "RainEmitter"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 200, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 255)),
        })
        emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 3),
                NumberSequenceKeypoint.new(0.5, 4),
                NumberSequenceKeypoint.new(1, 2),
        })
        emitter.Transparency = NumberSequence.new(0)
        emitter.Lifetime = NumberRange.new(1.5, 2.5)
        emitter.Rate = 500 -- mas particulas
        emitter.Speed = NumberRange.new(50, 80)
        emitter.SpreadAngle = Vector2.new(25, 25)
        emitter.Acceleration = Vector3.new(0, -30, 0)
        emitter.LightEmission = 1
        emitter.LightInfluence = 0
        emitter.Parent = rainPart
        
        -- Segundo emitter para pelotas mas grandes (efecto de lluvia densa)
        local bigEmitter = Instance.new("ParticleEmitter")
        bigEmitter.Name = "BigRainEmitter"
        bigEmitter.Texture = "rbxasset://textures/particles/fire_base.dds"
        bigEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        bigEmitter.Size = NumberSequence.new(5, 2)
        bigEmitter.Transparency = NumberSequence.new(0.3)
        bigEmitter.Lifetime = NumberRange.new(1, 2)
        bigEmitter.Rate = 100
        bigEmitter.Speed = NumberRange.new(60, 90)
        bigEmitter.SpreadAngle = Vector2.new(20, 20)
        bigEmitter.Acceleration = Vector3.new(0, -35, 0)
        bigEmitter.LightEmission = 1
        bigEmitter.LightInfluence = 0
        bigEmitter.Parent = rainPart
        
        return rainPart
end

-- Enviar timer a todos los clientes
function EventManager.sendTimerUpdate(state, time)
        local event = ReplicatedStorage:FindFirstChild("EventAnnouncement")
        if event then
                for _, player in ipairs(Players:GetPlayers()) do
                        pcall(function()
                                event:FireClient(player, {
                                        type = "timer",
                                        state = state,
                                        timeLeft = time,
                                        eventName = EVENT_NAME,
                                        isEventActive = isEventActive,
                                })
                        end)
                end
        end
end

-- Enviar anuncio grande
local function sendAnnouncement(eventName, message, duration)
        local event = ReplicatedStorage:FindFirstChild("EventAnnouncement")
        if event then
                for _, player in ipairs(Players:GetPlayers()) do
                        pcall(function()
                                event:FireClient(player, {
                                        type = "announcement",
                                        eventName = eventName,
                                        message = message,
                                        duration = duration or 5,
                                })
                        end)
                end
        end
end

function EventManager.startEvent()
        if isEventActive then return end
        isEventActive = true
        eventCount = eventCount + 1
        
        -- Calcular duracion e intervalo segun el numero de evento
        local currentDuration, currentInterval, nextMsg
        if eventCount <= #PROGRESSIVE_SCALE then
                local scale = PROGRESSIVE_SCALE[eventCount]
                currentDuration = scale.duration
                currentInterval = scale.interval
                nextMsg = scale.msg
        else
                currentDuration = FINAL_DURATION
                currentInterval = FINAL_INTERVAL
                nextMsg = nil
        end
        
        timeRemaining = currentDuration
        -- timeUntilEvent se asignara AL FINAL del evento (no aqui)
        
        print("[EventManager] === " .. EVENT_NAME .. " INICIADO ===")
        
        -- Cambiar ambiente a morado con ColorCorrectionEffect (mas visible)
        local Lighting = game:GetService("Lighting")
        local colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Name = "EventAmbient"
        colorCorrection.TintColor = Color3.fromRGB(180, 100, 220)  -- tinte morado
        colorCorrection.Brightness = -0.1  -- un poco mas oscuro
        colorCorrection.Contrast = 0.2
        colorCorrection.Saturation = 0.3
        colorCorrection.Parent = Lighting
        
        -- Pausar musica del cliente (boton de musica) y reproducir musica del evento
        local pauseMusicEvent = ReplicatedStorage:FindFirstChild("PauseMusicForEvent")
        if pauseMusicEvent then
                for _, p in ipairs(Players:GetPlayers()) do
                        pcall(function() pauseMusicEvent:FireClient(p) end)
                end
        end
        
        -- Crear y reproducir musica del evento
        if eventSound then eventSound:Destroy() end
        local track = EVENT_MUSIC[eventMusicIndex]
        eventMusicIndex = eventMusicIndex + 1
        if eventMusicIndex > #EVENT_MUSIC then
                eventMusicIndex = 1
        end
        eventSound = Instance.new("Sound")
        eventSound.Name = "EventMusic"
        eventSound.SoundId = track.soundId
        eventSound.Volume = 0.6
        eventSound.Looped = true
        eventSound.Parent = Workspace
        eventSound:Play()
        print("[EventManager] Reproduciendo: " .. track.name)
        
        local announceMsg = "¡Los cristales estan siendo destruidos! Recoge los cofres"
        if nextMsg then
                announceMsg = announceMsg .. "\n" .. nextMsg
        end
        sendAnnouncement("⚠️ " .. EVENT_NAME .. " ⚠️", announceMsg, 5)
        
        local rainEffect = createRainEffect()
        
        local startTime = os.clock()
        local waveCount = 0
        
        while os.clock() - startTime < currentDuration do
                waveCount = waveCount + 1
                breakWave()
                task.wait(WAVE_INTERVAL)
        end
        
        if rainEffect then rainEffect:Destroy() end
        
        -- Detener musica del evento
        if eventSound then
                eventSound:Stop()
                eventSound:Destroy()
                eventSound = nil
        end
        
        -- Reanudar musica del cliente
        local resumeMusicEvent = ReplicatedStorage:FindFirstChild("ResumeMusicAfterEvent")
        if resumeMusicEvent then
                for _, p in ipairs(Players:GetPlayers()) do
                        pcall(function() resumeMusicEvent:FireClient(p) end)
                end
        end
        
        -- Restaurar ambiente original (eliminar ColorCorrectionEffect)
        local Lighting = game:GetService("Lighting")
        local cc = Lighting:FindFirstChild("EventAmbient")
        if cc then cc:Destroy() end
        
        isEventActive = false
        -- timeUntilEvent ya fue asignado en startEvent con currentInterval
        print("[EventManager] === EVENTO FINALIZADO === (" .. waveCount .. " oleadas)")
        -- Mostrar el intervalo del PROXIMO evento (eventCount ya fue incrementado en startEvent)
        -- Pero el proximo evento es eventCount + 1
        local nextEventNum = eventCount + 1
        local nextIntervalStr = ""
        if nextEventNum <= #PROGRESSIVE_SCALE then
                nextIntervalStr = "Proximo evento en " .. math.floor(PROGRESSIVE_SCALE[nextEventNum].interval / 60) .. " minuto(s)"
        else
                nextIntervalStr = "Proximo evento en 5 minutos"
        end
        sendAnnouncement("✅ EVENTO FINALIZADO", nextIntervalStr, 5)
end

function EventManager.forceStart()
        timeUntilEvent = 0
end

return EventManager

-- ============================================
-- EventManager (ModuleScript) - ServerStorage/ServerModules
-- Controla el "Evento del Magnate de la Podredumbre".
-- Diseño de un solo hilo para evitar race conditions.
-- ============================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EventManager = {}

local EVENT_NAME = "Evento del Magnate de la Podredumbre"
local WAVE_INTERVAL = 5
local CRYSTAL_BREAK_TIME = 50

-- Escala progresiva
local PROGRESSIVE_SCALE = {
        { interval = 60,  duration = 30,  msg = "El proximo evento sera mas largo!" },
        { interval = 120, duration = 60,  msg = "El proximo evento sera mas largo!" },
        { interval = 180, duration = 90,  msg = "El proximo evento sera mas largo!" },
        { interval = 240, duration = 120, msg = "El proximo evento sera mas largo!" },
}
local FINAL_INTERVAL = 300
local FINAL_DURATION = 180

-- Musica del evento
local EVENT_MUSIC = {
        { name = "Magnate de la Podredumbre", soundId = "rbxassetid://130094886005121" },
        { name = "Brain Rot Tycoon (Mystic Mix)", soundId = "rbxassetid://100045289136245" },
        { name = "Harp Hero Tycoon (Retro Game)", soundId = "rbxassetid://86498434699930" },
        { name = "Mystic Retro", soundId = "rbxassetid://117592700598857" },
}
local eventMusicIndex = 1
local eventSound = nil

local CRYSTAL_BREAK_SOUNDS = {
        "rbxassetid://124054125419097",
        "rbxassetid://138817960173178",
        "rbxassetid://129395018150183",
        "rbxassetid://92650188901933"
}

local isEventActive = false
local timeUntilEvent = 60
local timeRemaining = 0
local eventCount = 0
local playerLeftTimer = 0
local CrystalSpawner = nil

-- ============================================
-- Funciones auxiliares
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

local function breakWave()
        local crystals = getAllCrystals()
        if #crystals == 0 then return end
        local players = Players:GetPlayers()
        local randomPlayer = #players > 0 and players[math.random(#players)] or nil
        
        for i = #crystals, 2, -1 do
                local j = math.random(i)
                crystals[i], crystals[j] = crystals[j], crystals[i]
        end
        
        for i, crystal in ipairs(crystals) do
                task.spawn(function()
                        local maxDelay = math.min(CRYSTAL_BREAK_TIME, crystalCount * (CRYSTAL_BREAK_TIME / 25))
                        task.wait(math.random() * maxDelay)
                        
                        if not crystal or not crystal.Parent then return end
                        local rt = crystal:FindFirstChild("Rarity")
                        local rarity = rt and rt.Value or "Blanco"
                        local pos = crystal.Position
                        local crystalColor = crystal.Color
                        
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
                        
                        local sound = Instance.new("Sound")
                        sound.SoundId = snd
                        sound.Volume = 0.5
                        sound.Parent = impactPart
                        sound:Play()
                        
                        task.delay(0.3, function()
                                if impactPart and impactPart.Parent then impactPart:Destroy() end
                        end)
                        
                        crystal:Destroy()
                        if CrystalSpawner then
                                pcall(function()
                                        CrystalSpawner.spawnChest(pos, {color=crystalColor, name=rarity}, randomPlayer)
                                end)
                        end
                end)
        end
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
        
        local emitter = Instance.new("ParticleEmitter")
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 200, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 255)),
        })
        emitter.Size = NumberSequence.new(3, 2)
        emitter.Transparency = NumberSequence.new(0)
        emitter.Lifetime = NumberRange.new(1.5, 2.5)
        emitter.Rate = 500
        emitter.Speed = NumberRange.new(50, 80)
        emitter.SpreadAngle = Vector2.new(25, 25)
        emitter.Acceleration = Vector3.new(0, -30, 0)
        emitter.LightEmission = 1
        emitter.LightInfluence = 0
        emitter.Parent = rainPart
        
        local bigEmitter = Instance.new("ParticleEmitter")
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

local function sendTimerUpdate(state, time)
        local event = ReplicatedStorage:FindFirstChild("EventAnnouncement")
        if event then
                for _, player in ipairs(Players:GetPlayers()) do
                        pcall(function()
                                event:FireClient(player, {
                                        type = "timer",
                                        state = state,
                                        timeLeft = time,
                                        eventName = EVENT_NAME,
                                })
                        end)
                end
        end
end

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

-- ============================================
-- LOOP PRINCIPAL (un solo hilo, sin race conditions)
-- ============================================
function EventManager.init(deps)
        CrystalSpawner = deps.CrystalSpawner
        print("[EventManager] Inicializado. Primer evento en 60s")
        
        task.spawn(function()
                while true do
                        task.wait(1)
                        
                        -- Detectar server vacio
                        if #Players:GetPlayers() == 0 then
                                playerLeftTimer = playerLeftTimer + 1
                                if playerLeftTimer >= 30 then
                                        eventCount = 0
                                        timeUntilEvent = 60
                                        playerLeftTimer = 0
                                end
                        else
                                playerLeftTimer = 0
                        end
                        
                        if isEventActive then
                                -- Evento en curso: enviar countdown del evento
                                timeRemaining = timeRemaining - 1
                                if timeRemaining > 0 then
                                        sendTimerUpdate("active", timeRemaining)
                                end
                        else
                                -- Esperando: enviar countdown del proximo evento
                                timeUntilEvent = timeUntilEvent - 1
                                if timeUntilEvent <= 0 then
                                        -- ===== INICIAR EVENTO =====
                                        isEventActive = true
                                        eventCount = eventCount + 1
                                        
                                        local currentDuration, nextMsg
                                        if eventCount <= #PROGRESSIVE_SCALE then
                                                local scale = PROGRESSIVE_SCALE[eventCount]
                                                currentDuration = scale.duration
                                                nextMsg = scale.msg
                                        else
                                                currentDuration = FINAL_DURATION
                                                nextMsg = nil
                                        end
                                        timeRemaining = currentDuration
                                        
                                        print("[EventManager] === EVENTO " .. eventCount .. " INICIADO (" .. currentDuration .. "s) ===")
                                        
                                        -- Ambiente morado
                                        local Lighting = game:GetService("Lighting")
                                        local cc = Lighting:FindFirstChild("EventAmbient")
                                        if not cc then
                                                cc = Instance.new("ColorCorrectionEffect")
                                                cc.Name = "EventAmbient"
                                                cc.TintColor = Color3.fromRGB(180, 100, 220)
                                                cc.Brightness = -0.1
                                                cc.Contrast = 0.2
                                                cc.Saturation = 0.3
                                                cc.Parent = Lighting
                                        end
                                        
                                        -- Pausar musica del cliente
                                        local pauseEvent = ReplicatedStorage:FindFirstChild("PauseMusicForEvent")
                                        if pauseEvent then
                                                for _, p in ipairs(Players:GetPlayers()) do
                                                        pcall(function() pauseEvent:FireClient(p) end)
                                                end
                                        end
                                        
                                        -- Reproducir musica del evento
                                        if eventSound then eventSound:Destroy() end
                                        local track = EVENT_MUSIC[eventMusicIndex]
                                        eventMusicIndex = eventMusicIndex + 1
                                        if eventMusicIndex > #EVENT_MUSIC then eventMusicIndex = 1 end
                                        eventSound = Instance.new("Sound")
                                        eventSound.Name = "EventMusic"
                                        eventSound.SoundId = track.soundId
                                        eventSound.Volume = 0.6
                                        eventSound.Looped = true
                                        eventSound.Parent = Workspace
                                        eventSound:Play()
                                        
                                        -- Anuncio inicial
                                        local announceMsg = "Recoge los cofres!"
                                        if nextMsg then announceMsg = announceMsg .. "\n" .. nextMsg end
                                        sendAnnouncement("⚠️ " .. EVENT_NAME .. " ⚠️", announceMsg, 5)
                                        
                                        -- Lluvia visual
                                        local rainEffect = createRainEffect()
                                        
                                        -- Oleadas (en hilo separado para no bloquear el loop)
                                        task.spawn(function()
                                                local startTime = os.clock()
                                                local waveCount = 0
                                                while os.clock() - startTime < currentDuration do
                                                        waveCount = waveCount + 1
                                                        breakWave()
                                                        task.wait(WAVE_INTERVAL)
                                                end
                                                
                                                -- ===== TERMINAR EVENTO =====
                                                if rainEffect then rainEffect:Destroy() end
                                                
                                                -- Detener musica del evento
                                                if eventSound then
                                                        eventSound:Stop()
                                                        eventSound:Destroy()
                                                        eventSound = nil
                                                end
                                                
                                                -- Reanudar musica del cliente
                                                local resumeEvent = ReplicatedStorage:FindFirstChild("ResumeMusicAfterEvent")
                                                if resumeEvent then
                                                        for _, p in ipairs(Players:GetPlayers()) do
                                                                pcall(function() resumeEvent:FireClient(p) end)
                                                        end
                                                end
                                                
                                                -- Restaurar ambiente
                                                local Lighting = game:GetService("Lighting")
                                                local cc2 = Lighting:FindFirstChild("EventAmbient")
                                                if cc2 then cc2:Destroy() end
                                                
                                                -- Calcular proximo intervalo
                                                local nextEventNum = eventCount + 1
                                                if nextEventNum <= #PROGRESSIVE_SCALE then
                                                        timeUntilEvent = PROGRESSIVE_SCALE[nextEventNum].interval
                                                else
                                                        timeUntilEvent = FINAL_INTERVAL
                                                end
                                                
                                                -- Anuncio final
                                                local nextMinStr = "5 minutos"
                                                if nextEventNum <= #PROGRESSIVE_SCALE then
                                                        nextMinStr = math.floor(PROGRESSIVE_SCALE[nextEventNum].interval / 60) .. " minuto(s)"
                                                end
                                                sendAnnouncement("✅ EVENTO FINALIZADO", "Proximo evento en " .. nextMinStr, 5)
                                                
                                                -- IMPORTANTE: desactivar isEventActive al FINAL
                                                isEventActive = false
                                                
                                                print("[EventManager] === EVENTO FINALIZADO === Proximo en " .. timeUntilEvent .. "s")
                                        end)
                                else
                                        sendTimerUpdate("waiting", timeUntilEvent)
                                end
                        end
                end
        end)
end

function EventManager.forceStart()
        timeUntilEvent = 0
end

return EventManager

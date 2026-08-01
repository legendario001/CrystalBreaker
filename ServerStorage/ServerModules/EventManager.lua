-- ============================================
-- EventManager (ModuleScript) - ServerStorage/ServerModules
-- Controla el "Evento del Magnate de la Podredumbre".
-- ============================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EventManager = {}

-- TEMPORAL PARA TESTEAR: 60s evento, 60s cooldown
local EVENT_INTERVAL = 60    -- 1 minuto entre eventos (TEST)
local EVENT_DURATION = 60    -- 1 minuto de evento (TEST)
local WAVE_INTERVAL = 5      -- cada 5s se rompen los cristales
local EVENT_NAME = "Evento del Magnate de la Podredumbre"

local isEventActive = false
local timeUntilEvent = EVENT_INTERVAL
local timeRemaining = 0

local CrystalSpawner = nil

function EventManager.init(deps)
        CrystalSpawner = deps.CrystalSpawner
        print("[EventManager] Inicializado. Evento cada " .. EVENT_INTERVAL .. "s (TEST)")

        -- Loop principal: envia timer a clientes cada segundo
        task.spawn(function()
                while true do
                        task.wait(1)
                        if not isEventActive then
                                timeUntilEvent = timeUntilEvent - 1
                                if timeUntilEvent <= 0 then
                                        task.spawn(function()
                                                EventManager.startEvent()
                                        end)
                                else
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
        
        for i, crystal in ipairs(crystals) do
                task.spawn(function()
                        -- Delay aleatorio entre 0 y 3 segundos para simular impacto aleatorio
                        task.wait(math.random() * 3)
                        
                        if not crystal or not crystal.Parent then return end
                        
                        local rt = crystal:FindFirstChild("Rarity")
                        local rarity = rt and rt.Value or "Blanco"
                        local pos = crystal.Position
                        local crystalColor = crystal.Color
                        
                        -- Crear efecto visual de impacto (rayo de luz cayendo)
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
                        
                        -- Desaparecer el rayo rapidamente
                        task.delay(0.15, function()
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
        timeRemaining = EVENT_DURATION
        
        print("[EventManager] === " .. EVENT_NAME .. " INICIADO ===")
        
        sendAnnouncement("⚠️ " .. EVENT_NAME .. " ⚠️", "¡Los cristales estan siendo destruidos! Recoge los cofres", 5)
        
        local rainEffect = createRainEffect()
        
        local startTime = os.clock()
        local waveCount = 0
        
        while os.clock() - startTime < EVENT_DURATION do
                waveCount = waveCount + 1
                breakWave()
                task.wait(WAVE_INTERVAL)
        end
        
        if rainEffect then rainEffect:Destroy() end
        
        isEventActive = false
        timeUntilEvent = EVENT_INTERVAL
        print("[EventManager] === EVENTO FINALIZADO === (" .. waveCount .. " oleadas)")
        sendAnnouncement("✅ EVENTO FINALIZADO", "Proximo evento en " .. EVENT_INTERVAL .. " segundos", 5)
end

function EventManager.forceStart()
        timeUntilEvent = 0
end

return EventManager

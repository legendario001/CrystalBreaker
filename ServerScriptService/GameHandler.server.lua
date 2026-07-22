local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CrystalSpawner = require(ServerStorage.ServerModules.CrystalSpawner)
-- BaseManager con proteccion - si falla, el juego avisa pero no crashea
local BaseManager
local ok_bm, err_bm = pcall(function()
        BaseManager = require(ServerStorage.ServerModules.BaseManager)
end)
if not ok_bm or not BaseManager then
        warn("[CRITICAL] BaseManager no se pudo cargar: " .. tostring(err_bm))
        -- Crear un BaseManager vacio para evitar crashes
        BaseManager = {
                getBase = function() return nil end,
                assign = function() return nil end,
                release = function() end,
                getBaseLevel = function() return 1 end,
                setBaseLevel = function() end,
                getUpgradeCost = function() return math.huge end,
        }
else
        -- Verificar que tiene las funciones necesarias
        if type(BaseManager.assign) ~= "function" then
                warn("[CRITICAL] BaseManager.assign no es una funcion! Revisa BaseManager.lua")
        end
        if type(BaseManager.getBase) ~= "function" then
                warn("[CRITICAL] BaseManager.getBase no es una funcion! Revisa BaseManager.lua")
        end
        print("[OK] BaseManager cargado correctamente")
end
local CharacterManager = require(ServerStorage.ServerModules.CharacterManager)
local ModelManager = require(ServerStorage.ServerModules.ModelManager)
-- SaveManager para persistencia de datos (DataStore)
local SaveManager
local ok_sm, err_sm = pcall(function()
        SaveManager = require(ServerStorage.ServerModules.SaveManager)
end)
if not ok_sm or not SaveManager then
        warn("[CRITICAL] SaveManager no se pudo cargar: " .. tostring(err_sm))
        SaveManager = {
                loadPlayerData = function() return nil end,
                savePlayerData = function() return false end,
                clearCache = function() end,
                saveAllPlayers = function() return 0 end,
        }
else
        print("[OK] SaveManager cargado correctamente")
end
-- ParcelManager + BuildManager para sistema de construccion
local ParcelManager
local ok_pm, err_pm = pcall(function()
        ParcelManager = require(ServerStorage.ServerModules.ParcelManager)
end)
if not ok_pm or not ParcelManager then
        warn("[CRITICAL] ParcelManager no se pudo cargar: " .. tostring(err_pm))
        ParcelManager = {
                assignByBaseName = function() return nil end,
                getParcel = function() return nil end,
                release = function() end,
                isParcelOwnedByPlayer = function() return false end,
                isPositionInParcel = function() return false end,
        }
else
        print("[OK] ParcelManager cargado correctamente")
end

local BuildManager
local ok_bld, err_bld = pcall(function()
        BuildManager = require(ServerStorage.ServerModules.BuildManager)
end)
if not ok_bld or not BuildManager then
        warn("[CRITICAL] BuildManager no se pudo cargar: " .. tostring(err_bld))
        BuildManager = {
                getBlocksList = function() return {} end,
                getBlockConfig = function() return nil end,
                placeBlock = function() return false, "BuildManager no cargo" end,
                removeBlock = function() return false, "BuildManager no cargo" end,
        }
else
        print("[OK] BuildManager cargado correctamente")
end
-- BankManager para sistema de banco (depositar/retirar dinero)
local BankManager
local ok_bnk, err_bnk = pcall(function()
        BankManager = require(ServerStorage.ServerModules.BankManager)
end)
if not ok_bnk or not BankManager then
        warn("[CRITICAL] BankManager no se pudo cargar: " .. tostring(err_bnk))
        BankManager = {
                getBalance = function() return 0 end,
                setBalance = function() end,
                deposit = function() return false, "BankManager no cargo" end,
                withdraw = function() return false, "BankManager no cargo" end,
                cleanupPlayer = function() end,
        }
else
        print("[OK] BankManager cargado correctamente")
end
-- LeaderboardManager para tabla de lideres (top 30 + personajes bailando)
local LeaderboardManager
local ok_lb, err_lb = pcall(function()
        LeaderboardManager = require(ServerStorage.ServerModules.LeaderboardManager)
end)
if not ok_lb or not LeaderboardManager then
        warn("[CRITICAL] LeaderboardManager no se pudo cargar: " .. tostring(err_lb))
        LeaderboardManager = {
                loadAll = function() end,
                saveAll = function() end,
                updateBalance = function() end,
                recalculateTop = function() end,
                getTop30 = function() return {} end,
                updateTop3Characters = function() end,
        }
else
        print("[OK] LeaderboardManager cargado correctamente")
end
-- Conectar BankManager con LeaderboardManager: cuando cambia el saldo, actualizar leaderboard
if BankManager and LeaderboardManager then
        BankManager.onBalanceChanged = function(userId, newBalance)
                LeaderboardManager.updateBalance(userId, newBalance)
        end
        print("[OK] BankManager <-> LeaderboardManager conectados")
end
-- BaseUpgradeManager es opcional - si falla, el juego sigue sin mejora de base
local BaseUpgradeManager
local ok_bum, err_bum = pcall(function()
        BaseUpgradeManager = require(ServerStorage.ServerModules.BaseUpgradeManager)
end)
if not ok_bum then
        warn("BaseUpgradeManager no se pudo cargar: " .. tostring(err_bum))
        BaseUpgradeManager = nil
end
local Events = require(game:GetService("ReplicatedStorage").RemoteEvents)

local playerData = {}
local droppedChars = {}
local PLACE_DISTANCE = 12

-- Debounces
local upgradeCooldowns = {}
local upgradeButtonCooldowns = {}
local throwCooldowns = {}
local pickupCooldowns = {}

-- ============================================
-- SONIDOS DEL JUEGO
-- ============================================
local SOUND_COLLECT_MONEY = "rbxassetid://79392333090964"
local SOUND_UPGRADE       = "rbxassetid://203620899"
local SOUND_BUY_BLOCK     = "rbxassetid://13449037359" -- sonido al comprar bloques de construccion
local SOUND_CRYSTAL_BREAK = "rbxassetid://124054125419097"
-- Lista de sonidos al romper cristal (se reproduce 1 al azar cada vez)
local CRYSTAL_BREAK_SOUNDS = {
        "rbxassetid://124054125419097",
        "rbxassetid://138817960173178",
        "rbxassetid://129395018150183",
        "rbxassetid://92650188901933"
}
local SOUND_CHEST_OPEN    = "rbxassetid://116517233858315" -- 6.56s animacion apertura cofre
local SOUND_FUSION_NEAR   = "rbxassetid://86261914368076"  -- 5.2s sonido al acercarse a la maquina
local SOUND_FUSION_ACTIVATE = "rbxassetid://5509750509"   -- sonido al hacer click en fusionar

local function playSoundAt(soundId, position)
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.6
        -- Usar un Attachment en lugar de una Part para no ensuciar el Workspace
        local temp = Instance.new("Part")
        temp.Name = "SoundEmitter"
        temp.Size = Vector3.new(0.1, 0.1, 0.1)
        temp.Position = position
        temp.Anchored = true
        temp.CanCollide = false
        temp.Transparency = 1
        -- Poner bajo Map para no interferir con busquedas de Cofres/Cristales
        local map = Workspace:FindFirstChild("Map")
        if map then
                temp.Parent = map
        else
                temp.Parent = Workspace
        end
        sound.Parent = temp
        sound:Play()
        -- Auto-destruir despues de 3 segundos
        Debris:AddItem(temp, 3)
end

-- ============================================
-- EFECTO VISUAL: Cristal rompiendose en pedazos
-- Usa el modelo CrystalShardModel de ServerStorage (clona 10 veces)
-- Cada clon sale volando en direccion aleatoria con rotacion aleatoria
-- Usa Debris para auto-eliminar (sin lag, sin limpieza manual)
-- ============================================
local ServerStorage = game:GetService("ServerStorage")

local function createCrystalBreakEffect(position, color)
        -- Buscar el modelo de cristal roto en ServerStorage
        local shardTemplate = ServerStorage:FindFirstChild("CrystalShardModel")
        if not shardTemplate then
                warn("CrystalShardModel no encontrado en ServerStorage - efecto visual omitido")
                return
        end

        local NUM_SHARDS = 10 -- numero de fragmentos a clonar (ligero)
        for i = 1, NUM_SHARDS do
                local shard = shardTemplate:Clone()
                shard.Name = "CrystalShardEffect"

                -- EL CRISTAL MIDE 10 DE ALTO: position es el centro (5 studs arriba del suelo)
                -- Spawnear los fragmentos a la altura del cristal (de centro hacia arriba)
                -- y dejar que la gravedad los haga caer hacia el cofre
                local offsetX = math.random(-8, 8) / 10 -- -0.8 a 0.8 studs
                local offsetY = math.random(0, 50) / 10 -- 0 a 5 studs (de centro a cima del cristal)
                local offsetZ = math.random(-8, 8) / 10 -- -0.8 a 0.8 studs
                local spawnPos = position + Vector3.new(offsetX, offsetY, offsetZ)

                -- Mover todo el modelo clonado a la posicion del cristal
                -- Usar PivotTo para mover el modelo completo manteniendo su forma
                local templatePivot = shardTemplate:GetPivot()
                shard:PivotTo(CFrame.new(spawnPos) * (templatePivot - templatePivot.Position))

                -- Rotacion aleatoria para que cada fragmento se vea diferente
                shard:PivotTo(shard:GetPivot() * CFrame.Angles(
                        math.rad(math.random(0, 360)),
                        math.rad(math.random(0, 360)),
                        math.rad(math.random(0, 360))
                        ))

                -- Configurar todas las partes del modelo clonado
                for _, desc in ipairs(shard:GetDescendants()) do
                        if desc:IsA("BasePart") then
                                desc.Anchored = false
                                desc.CanCollide = false
                                desc.CanQuery = false
                                desc.Massless = true
                                desc.Color = color
                                desc.Material = Enum.Material.Ice
                                desc.Transparency = 0.1
                                -- ELIMINAR SurfaceAppearance para que el Color de la parte se vea
                                -- (SurfaceAppearance usa texturas que ignoran la propiedad Color)
                                local surfaceApp = desc:FindFirstChild("SurfaceAppearance")
                                if surfaceApp then
                                        surfaceApp:Destroy()
                                end
                        end
                end

                -- Si el propio template es una Part (no un Model)
                if shard:IsA("BasePart") then
                        shard.Position = spawnPos
                        shard.Anchored = false
                        shard.CanCollide = false
                        shard.CanQuery = false
                        shard.Massless = true
                        shard.Color = color
                        shard.Material = Enum.Material.Ice
                        shard.Transparency = 0.1
                        -- Eliminar SurfaceAppearance si existe
                        local surfaceApp = shard:FindFirstChild("SurfaceAppearance")
                        if surfaceApp then
                                surfaceApp:Destroy()
                        end
                end

                shard.Parent = Workspace

                -- Velocidad aleatoria para expulsar los fragmentos
                -- Reducida para que salgan del cristal, no vuelen muy lejos
                local mainPart = nil
                if shard:IsA("BasePart") then
                        mainPart = shard
                else
                        mainPart = shard.PrimaryPart or shard:FindFirstChildWhichIsA("BasePart")
                end

                if mainPart then
                        -- Velocidad: outward (horizontal) mas amplia para que se expandan
                        -- Salto bajo para que caigan desde la altura del cristal hacia el cofre
                        local velocity = Vector3.new(
                                math.random(-25, 25), -- mas expansion horizontal
                                math.random(2, 8), -- salto muy bajo, casi solo caen
                                math.random(-25, 25) -- mas expansion horizontal
                        )
                        mainPart.AssemblyLinearVelocity = velocity

                        -- Velocidad angular para que giren
                        mainPart.AssemblyAngularVelocity = Vector3.new(
                                math.random(-10, 10),
                                math.random(-10, 10),
                                math.random(-10, 10)
                        )
                end

                -- Auto-eliminar despues de 2 segundos (sin lag)
                Debris:AddItem(shard, 2)
        end
end

local function playSoundForPlayer(soundId, player, duration)
        if not player or not player.Parent then return end
        local char = player.Character
        if not char then return end
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.5
        sound.Parent = char
        sound:Play()
        -- Duracion: usar la pasada como parametro, o 3s por defecto
        local waitTime = duration or 3
        task.delay(waitTime, function()
                if sound and sound.Parent then sound:Destroy() end
        end)
end

local function isValid(instance)
        return instance ~= nil and instance.Parent ~= nil
end

-- ============================================
-- Helper: Obtener TODOS los pedestales de una base (piso 1, 2, 3, 4, 5)
-- Retorna una lista plana de todos los folders de pedestal
-- ============================================
local function getAllPedestals(base)
        local allPedestals = {}
        if not base then return allPedestals end

        -- Piso 1: base.Pedestals
        local floor1Peds = base:FindFirstChild("Pedestals")
        if floor1Peds then
                for _, ped in ipairs(floor1Peds:GetChildren()) do
                        table.insert(allPedestals, ped)
                end
        end

        -- Pisos 2-5: base.FloorN.PedestalsN
        for floorNum = 2, 5 do
                local floor = base:FindFirstChild("Floor" .. floorNum)
                if floor then
                        local peds = floor:FindFirstChild("Pedestals" .. floorNum)
                        if peds then
                                for _, ped in ipairs(peds:GetChildren()) do
                                        table.insert(allPedestals, ped)
                                end
                        end
                end
        end

        return allPedestals
end

-- Buscar un pedestal por nombre y numero de piso en la base del jugador
-- Para restaurar personajes colocados desde DataStore
local function findPedestalByNameAndFloor(base, pedestalName, floorNum)
        if not base or not pedestalName then return nil end
        floorNum = floorNum or 1
        if floorNum == 1 then
                local floor1Peds = base:FindFirstChild("Pedestals")
                if floor1Peds then
                        return floor1Peds:FindFirstChild(pedestalName)
                end
        else
                local floor = base:FindFirstChild("Floor" .. floorNum)
                if floor then
                        local peds = floor:FindFirstChild("Pedestals" .. floorNum)
                        if peds then
                                return peds:FindFirstChild(pedestalName)
                        end
                end
        end
        return nil
end

local function isPlayerValid(player)
        return player ~= nil and player.Parent ~= nil
end

-- Verificar que un pedestal pertenece a la base del jugador
local function isPedestalOwnedByPlayer(pedestal, player)
        local base = BaseManager.getBase(player.UserId)
        if not base then return false end
        -- Verificar que el pedestal es descendiente de la base del jugador
        local current = pedestal.Parent
        while current do
                if current == base then return true end
                current = current.Parent
        end
        return false
end

local function getNextCharIndex(characters)
        local idx = 1
        while characters[idx] do idx = idx + 1 end
        return idx
end

local function iterateCharacters(characters)
        local results = {}
        for i, c in pairs(characters) do
                if c then table.insert(results, {index=i, data=c}) end
        end
        return results
end

local function addMoney(player, amount)
        if not isPlayerValid(player) then return end
        local data = playerData[player.UserId]
        if not data then return end
        data.money = (data.money or 0) + amount
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
                local coins = leaderstats:FindFirstChild("Coins")
                if coins then coins.Value = data.money end
        end
        Events.MoneyUpdate:FireClient(player, data.money)
end

local function createCarryTool(player, model)
        local char = player.Character
        if not char then return end

        local function removeOld(parent)
                local old = parent and parent:FindFirstChild("Carrying")
                if old then old:Destroy() end
        end
        removeOld(char)
        removeOld(player:FindFirstChild("Backpack"))

        local carryTool = Instance.new("Tool")
        carryTool.Name = "Carrying"
        carryTool.RequiresHandle = true
        carryTool.CanBeDropped = false

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(0.5, 0.5, 0.5)
        handle.Transparency = 1
        handle.Anchored = false
        handle.CanCollide = false
        handle.Massless = true
        handle.Parent = carryTool
        carryTool.Grip = CFrame.new(0, -1.5, 1.5)

        if model then
                local modelClone = model:Clone()
                local parts = {}
                for _, desc in ipairs(modelClone:GetDescendants()) do
                        if desc:IsA("BasePart") then
                                desc.Anchored = false
                                desc.CanCollide = false
                                desc.Massless = true
                                table.insert(parts, desc)
                        end
                end
                modelClone.Parent = carryTool

                if #parts > 0 then
                        local sumX, sumZ, lowestY = 0, 0, math.huge
                        for _, part in ipairs(parts) do
                                sumX = sumX + part.Position.X
                                sumZ = sumZ + part.Position.Z
                                local bottomY = part.Position.Y - part.Size.Y/2
                                if bottomY < lowestY then lowestY = bottomY end
                        end
                        local cx = sumX/#parts
                        local cz = sumZ/#parts
                        for _, part in ipairs(parts) do
                                part.Position = part.Position + Vector3.new(-cx, -lowestY, -cz)
                        end
                        for _, part in ipairs(parts) do
                                local weld = Instance.new("WeldConstraint")
                                weld.Part0 = handle
                                weld.Part1 = part
                                weld.Parent = handle
                        end
                end
        end
        carryTool.Parent = char
end

local function showEmptyLabels(base)
        local pedestals = base:FindFirstChild("Pedestals")
        if not pedestals then return end
        for _, ped in ipairs(pedestals:GetChildren()) do
                ModelManager.showEmptyLabel(ped)
        end
end

local function setupMoneyPileEvents(pedestal, moneyPile)
        if not moneyPile then return end
        local collectEvent = moneyPile:WaitForChild("CollectEvent", 5)
        if collectEvent then
                collectEvent.Event:Connect(function(player, amount)
                        -- Solo el dueño de la base puede recoger el dinero
                        if not isPedestalOwnedByPlayer(pedestal, player) then return end
                        addMoney(player, amount)
                        -- Sonido de recoger dinero
                        playSoundForPlayer(SOUND_COLLECT_MONEY, player)
                        -- Efecto visual de billete (solo visible para el dueño)
                        local char = player.Character
                        if char and char:FindFirstChild("HumanoidRootPart") then
                                local pilePos = moneyPile.Position
                                local playerPos = char.HumanoidRootPart.Position
                                -- Mezclar 50/50: aparece entre la pila y el jugador
                                local midPos = (pilePos + playerPos) * 0.5
                                pcall(function()
                                        Events.ShowBillEffect:FireClient(player, midPos, amount)
                                end)
                        end
                end)
        end
end

local function setupUpgradeButtonEvents(pedestal, upgradeBtn, charIdx)
        if not upgradeBtn then return end
        local upgradeEvent = upgradeBtn:WaitForChild("UpgradeEvent", 5)
        if not upgradeEvent then return end

        upgradeEvent.Event:Connect(function(player)
                local btnKey = player.UserId .. "_" .. charIdx
                if upgradeButtonCooldowns[btnKey] then return end
                upgradeButtonCooldowns[btnKey] = true
                task.delay(0.3, function() upgradeButtonCooldowns[btnKey] = nil end)

                local ok, err = pcall(function()
                        if not isPlayerValid(player) then return end
                        local data = playerData[player.UserId]
                        if not data then return end
                        local charData = data.characters[charIdx]
                        if not charData then return end
                        if not isValid(charData.pedestal) then charData.pedestal=nil return end
                        if charData.pedestal ~= pedestal then return end
                        -- Solo mejorar si el pedestal es de la base del jugador
                        if not isPedestalOwnedByPlayer(pedestal, player) then return end

                        local currentLevel = charData.level or 1
                        if currentLevel >= 100 then return end
                        local cost = ModelManager.getUpgradeCost(currentLevel, charData.rarity)
                        if (data.money or 0) < cost then return end

                        data.money = data.money - cost
                        charData.level = currentLevel + 1

                        local leaderstats = player:FindFirstChild("leaderstats")
                        if leaderstats then
                                local coins = leaderstats:FindFirstChild("Coins")
                                if coins then coins.Value = data.money end
                        end
                        Events.MoneyUpdate:FireClient(player, data.money)

                        if isValid(pedestal) then
                                ModelManager.createLabels(pedestal, charData.name, charData.rarity, charData.level, charData.fusionLevel or 0)
                                ModelManager.updateUpgradeButtonUI(pedestal, charData.rarity, charData.level)
                                local mp = pedestal:FindFirstChild("MoneyPile")
                                if mp then
                                        local lt = mp:FindFirstChild("CharLevel")
                                        if lt then lt.Value = charData.level end
                                        local flt = mp:FindFirstChild("FusionLevel")
                                        if flt then flt.Value = charData.fusionLevel or 0 end
                                end
                        end
                        print(player.Name.." mejoro "..charData.name.." a Lv."..charData.level.." (-$"..cost..")")
                        -- Sonido de mejora
                        playSoundForPlayer(SOUND_UPGRADE, player)
                        -- Efecto visual de upgrade (solo visible para el dueño)
                        if isValid(upgradeBtn) then
                                pcall(function()
                                        Events.ShowUpgradeEffect:FireClient(player, upgradeBtn.Position)
                                end)
                        end
                end)
                if not ok then warn("Error en upgrade btn: "..tostring(err)) end
        end)
end

-- THROW BALL
Events.ThrowBall.OnServerEvent:Connect(function(player, startPos, launchVel, ballType)
        if throwCooldowns[player.UserId] then return end
        throwCooldowns[player.UserId] = true
        task.delay(0.3, function() throwCooldowns[player.UserId] = nil end)

        local ok, err = pcall(function()
                local data = playerData[player.UserId]
                if data and data.carrying then return end

                -- Configuracion de pelotas
                local SERVER_BALL_CONFIG = {
                        basic = { color = Color3.fromRGB(100, 200, 255), material = Enum.Material.SmoothPlastic, gravity = 1.0, bounce = true, damage = 1, modelName = nil },
                        fire = { color = Color3.fromRGB(255, 100, 30), material = Enum.Material.Neon, gravity = 0.3, bounce = false, damage = 10, modelName = "FireBallModel" },
            earth = { color = Color3.fromRGB(140, 90, 50), material = Enum.Material.Slate, gravity = 1.0, bounce = true, damage = 100, modelName = "EarthBallModel" },
            air = { color = Color3.fromRGB(240, 250, 255), material = Enum.Material.Glass, gravity = 0.2, bounce = true, damage = 10000, modelName = "AirBallModel" },
            water = { color = Color3.fromRGB(80, 150, 220), material = Enum.Material.Glass, gravity = 1.0, bounce = true, damage = 1000, modelName = "WaterBallModel" }
                }
                local ballCfg = SERVER_BALL_CONFIG[ballType] or SERVER_BALL_CONFIG.basic

                -- CREAR pelota en el servidor (visible para TODOS)
                local ball, mainPart
                local template = nil
                if ballCfg.modelName then
                        template = ReplicatedStorage:FindFirstChild(ballCfg.modelName)
                end

                if template then
                        ball = template:Clone()
                        ball.Name = "ThrownBall"
                        mainPart = ball.PrimaryPart or ball:FindFirstChild("Handle") or ball:FindFirstChildWhichIsA("BasePart")
                        if not mainPart then
                                ball:Destroy()
                                template = nil
                        end
                end

                if not template then
                        ball = Instance.new("Part")
                        ball.Name = "ThrownBall"
                        ball.Size = Vector3.new(1.5, 1.5, 1.5)
                        ball.Shape = Enum.PartType.Ball
                        ball.Color = ballCfg.color
                        ball.Material = ballCfg.material
                        mainPart = ball
                end

                -- Configurar partes del modelo
                for _, desc in ipairs(ball:GetDescendants()) do
                        if desc:IsA("BasePart") and desc ~= mainPart then
                                desc.Anchored = false
                                desc.CanCollide = false
                                desc.CanQuery = false
                                desc.Massless = true
                                local w = Instance.new("WeldConstraint")
                                w.Part0 = mainPart
                                w.Part1 = desc
                                w.Parent = desc
                        end
                end

                -- Configurar fisicas
                mainPart.Anchored = false
                mainPart.CanCollide = ballCfg.bounce and true or false
                mainPart.CanQuery = true
                mainPart.Massless = false
                local gravity = ballCfg.gravity or 1.0
                local bounceVal = ballCfg.bounce and 0.8 or 0.0
                mainPart.CustomPhysicalProperties = PhysicalProperties.new(ballCfg.gravity or 0.5, 0.3, bounceVal, 0.5, 0.5)

                -- Posicionar y dar velocidad (antes de parentear)
                mainPart.Position = startPos
                mainPart.AssemblyLinearVelocity = launchVel
                ball.Parent = Workspace
                mainPart.AssemblyLinearVelocity = launchVel

                -- DETECCION DE CRISTAL: cuando la pelota toca un cristal, dañarlo
                local ballHitSent = false
                local ballTouchedConn
                ballTouchedConn = mainPart.Touched:Connect(function(hit)
                        if ballHitSent then return end
                        if hit.Name == "Crystal" then
                                ballHitSent = true

                                local rt = hit:FindFirstChild("Rarity")
                                local rarity = rt and rt.Value or "Blanco"
                                local pos = hit.Position
                                local crystalColor = hit.Color
                                local hpObj = hit:FindFirstChild("Health")
                                local mhpObj = hit:FindFirstChild("MaxHealth")

                                if not hpObj or not mhpObj then
                                        local snd = CRYSTAL_BREAK_SOUNDS[math.random(#CRYSTAL_BREAK_SOUNDS)]
                                        playSoundAt(snd, pos)
                                        createCrystalBreakEffect(pos, crystalColor)
                                        hit:Destroy()
                                        CrystalSpawner.spawnChest(pos, {color=crystalColor, name=rarity}, player)
                                else
                                        local DAMAGE = ballCfg.damage
                                        hpObj.Value = hpObj.Value - DAMAGE
                                        CrystalSpawner.updateCrystalHealthUI(hit, hpObj.Value, mhpObj.Value)
                                        local hitSound = CRYSTAL_BREAK_SOUNDS[math.random(#CRYSTAL_BREAK_SOUNDS)]
                                        playSoundAt(hitSound, pos)

                                        if hpObj.Value <= 0 then
                                                local breakSound = CRYSTAL_BREAK_SOUNDS[math.random(#CRYSTAL_BREAK_SOUNDS)]
                                                playSoundAt(breakSound, pos)
                                                createCrystalBreakEffect(pos, crystalColor)
                                                hit:Destroy()
                                                CrystalSpawner.spawnChest(pos, {color=crystalColor, name=rarity}, player)
                                        end
                                end

                                if ballTouchedConn then
                                        ballTouchedConn:Disconnect()
                                        ballTouchedConn = nil
                                end
                        end
                end)

                -- Si la pelota no rebota (ej: fuego), destruirla al tocar cualquier cosa
                if not ballCfg.bounce then
                        local destroyConn
                        destroyConn = mainPart.Touched:Connect(function(hit)
                                if ball and ball.Parent then
                                        ball:Destroy()
                                end
                                if destroyConn then
                                        destroyConn:Disconnect()
                                end
                        end)
                end

                -- Auto-eliminar despues de 6 segundos
                Debris:AddItem(ball, 8)
        end)
        if not ok then warn("Error ThrowBall: "..tostring(err)) end
end)

-- PICKUP CHEST
Events.PickupChest.OnServerEvent:Connect(function(player)
        if pickupCooldowns[player.UserId] then return end
        pickupCooldowns[player.UserId] = true
        task.delay(8, function() pickupCooldowns[player.UserId] = nil end) -- 8s cooldown (animacion + margen)

        local ok, err = pcall(function()
                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local data = playerData[player.UserId]
                if not data or data.carrying then return end

                -- Buscar cofre cercano (que no este abriendo ya)
                local nearest, nearDist = nil, 15
                for _, obj in ipairs(workspace:GetChildren()) do
                        if obj.Name == "Chest" then
                                -- Ignorar cofres que ya se estan abriendo
                                local opening = obj:FindFirstChild("Opening")
                                if opening and opening.Value then continue end
                                local owner = obj:FindFirstChild("Owner")
                                if owner and owner.Value == player then
                                        local d = (obj.Position - root.Position).Magnitude
                                        if d < nearDist then nearDist=d nearest=obj end
                                end
                        end
                end
                if not nearest then return end

                local rt = nearest:FindFirstChild("Rarity")
                local rarity = rt and rt.Value or "Blanco"

                -- Marcar el cofre como "abriendo" para que no se pueda recoger otra vez
                local openingTag = Instance.new("BoolValue")
                openingTag.Name = "Opening"
                openingTag.Value = true
                openingTag.Parent = nearest

                -- Encontrar displayName de la rareza
                local displayName = rarity
                local rarityColor = Color3.fromRGB(220, 220, 220)
                local rarityDisplayNames = {
                        Morado = "MITICO", Rojo = "EPICO", Amarillo = "RARO",
                        Azul = "INCOMUN", Blanco = "COMUN"
                }
                local rarityColors = {
                        Morado = Color3.fromRGB(170, 85, 255), Rojo = Color3.fromRGB(255, 80, 80),
                        Amarillo = Color3.fromRGB(255, 255, 100), Azul = Color3.fromRGB(85, 170, 255),
                        Blanco = Color3.fromRGB(220, 220, 220)
                }
                displayName = rarityDisplayNames[rarity] or string.upper(rarity)
                rarityColor = rarityColors[rarity] or Color3.fromRGB(220, 220, 220)

                -- Obtener el personaje ganado AHORA (para mostrarlo al final de la animacion)
                local model, folder, modelName = CharacterManager.getRandomModel(rarity)
                local charName = model and model.Name or (rarity.." Personaje")

                -- Guardar posicion del cofre ANTES de destruirlo (para respawn del cristal)
                local chestPos = nearest.Position + Vector3.new(0, 1, 0)

                -- DESTRUIR EL COFRE INMEDIATAMENTE al recogerlo (no esperar a que termine el spin)
                nearest:Destroy()
                CrystalSpawner.respawn(chestPos)

                -- Enviar evento al cliente para que inicie la animacion de apertura
                Events.ChestOpen:FireClient(player, displayName, rarityColor, charName)

                -- Reproducir sonido de apertura (7s para que suene completo, el audio dura 6.56s)
                playSoundForPlayer(SOUND_CHEST_OPEN, player, 7)

                -- Esperar a que termine la animacion (6.56 segundos)
                task.wait(6.6)

                -- Verificar que el jugador sigue conectado
                if not isPlayerValid(player) then return end

                -- Dar el personaje al jugador
                local currentData = playerData[player.UserId]
                if not currentData or currentData.carrying then return end

                local charIndex = getNextCharIndex(currentData.characters)
                currentData.characters[charIndex] = {
                        name=charName, rarity=rarity, level=1,
                        model=model, folder=folder, pedestal=nil,
                        modelName=modelName or (model and model.Name) or charName
                }
                currentData.carrying = charIndex
                createCarryTool(player, model)

                print(player.Name.." obtuvo "..charName.." ["..rarity.."]")
        end)
        if not ok then warn("Error PickupChest: "..tostring(err)) end
end)

-- PICKUP DROPPED
Events.PickupDropped.OnServerEvent:Connect(function(player)
        local ok, err = pcall(function()
                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local data = playerData[player.UserId]
                if not data or data.carrying then return end

                local nearest, nearDist = nil, 15
                local staleKeys = {}
                for key, tp in pairs(droppedChars) do
                        if not tp or not tp.Parent then
                                table.insert(staleKeys, key)
                        else
                                local owner = tp:FindFirstChild("Owner")
                                if owner and owner.Value == player then
                                        local d = (tp.Position - root.Position).Magnitude
                                        if d < nearDist then nearDist=d nearest=tp end
                                end
                        end
                end
                for _, key in ipairs(staleKeys) do droppedChars[key]=nil end
                if not nearest then return end

                local charIndexObj = nearest:FindFirstChild("CharIndex")
                local dropModelObj = nearest:FindFirstChild("DropModel")
                if not charIndexObj or not dropModelObj then return end

                local charIndex = charIndexObj.Value
                local dropModel = dropModelObj.Value
                local charData = data.characters[charIndex]

                if not charData then
                        if dropModel and dropModel.Parent then dropModel:Destroy() end
                        if nearest.Parent then nearest:Destroy() end
                        droppedChars[player.UserId.."_"..charIndex] = nil
                        return
                end

                data.carrying = charIndex
                createCarryTool(player, charData.model)
                if dropModel and dropModel.Parent then dropModel:Destroy() end
                if nearest.Parent then nearest:Destroy() end
                droppedChars[player.UserId.."_"..charIndex] = nil
                print(player.Name.." recogio "..charData.name.." del suelo")
        end)
        if not ok then warn("Error PickupDropped: "..tostring(err)) end
end)

-- PLACE CHARACTER
Events.PlaceCharacter.OnServerEvent:Connect(function(player)
        local ok, err = pcall(function()
                local data = playerData[player.UserId]
                if not data or not data.carrying then return end
                local charData = data.characters[data.carrying]
                if not charData or charData.pedestal then return end

                local pchar = player.Character
                if not pchar then return end
                local root = pchar:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local base = BaseManager.getBase(player.UserId)
                if not base then return end
                -- FIX: Buscar en TODOS los pisos (1, 2, 3, 4, 5)
                local allPedestals = getAllPedestals(base)
                if #allPedestals == 0 then return end

                local nearestFree, nearestDist = nil, PLACE_DISTANCE
                for _, ped in ipairs(allPedestals) do
                        local platform = ped:FindFirstChild("Platform")
                        if not platform then continue end
                        local hasModel = false
                        for _, child in ipairs(ped:GetChildren()) do
                                if child:IsA("Model") then hasModel=true break end
                        end
                        if hasModel then continue end
                        local occupied = false
                        for _, entry in ipairs(iterateCharacters(data.characters)) do
                                if entry.data.pedestal == ped then occupied=true break end
                        end
                        if not occupied then
                                local d = (platform.Position - root.Position).Magnitude
                                if d < nearestDist then nearestDist=d nearestFree=ped end
                        end
                end
                -- Si no hay pedestal libre cerca, NO destruir la herramienta
                if not nearestFree then return end

                -- SOLO ahora destruir la herramienta (ya tenemos pedestal seguro)
                local char = player.Character
                if char then
                        local t = char:FindFirstChild("Carrying") if t then t:Destroy() end
                end
                local bp = player:FindFirstChild("Backpack")
                if bp then
                        local t = bp:FindFirstChild("Carrying") if t then t:Destroy() end
                end

                local charIdx = data.carrying
                if charData.model then ModelManager.placeOnPedestal(charData.model, nearestFree) end
                charData.pedestal = nearestFree
                ModelManager.createLabels(nearestFree, charData.name, charData.rarity, charData.level, charData.fusionLevel or 0)

                local moneyPile = ModelManager.createMoneyPile(nearestFree, charData.rarity, charData.level, charData.fusionLevel or 0, player)
                setupMoneyPileEvents(nearestFree, moneyPile)
                local upgradeBtn = ModelManager.createUpgradeButton(nearestFree, charData.rarity, charData.level, charData.fusionLevel or 0)
                setupUpgradeButtonEvents(nearestFree, upgradeBtn, charIdx)

                data.carrying = nil
                print(player.Name.." coloco "..charData.name.." Lv."..(charData.level or 1))
        end)
        if not ok then warn("Error PlaceCharacter: "..tostring(err)) end
end)

-- REMOVE FROM PEDESTAL
Events.RemoveFromPedestal.OnServerEvent:Connect(function(player)
        local ok, err = pcall(function()
                local data = playerData[player.UserId]
                if not data or data.carrying then return end
                local pchar = player.Character
                if not pchar then return end
                local root = pchar:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local nearestPed, nearDist, nearCharIdx = nil, PLACE_DISTANCE, nil
                for _, entry in ipairs(iterateCharacters(data.characters)) do
                        local charData = entry.data
                        if charData.pedestal then
                                if not isValid(charData.pedestal) then charData.pedestal=nil continue end
                                -- Solo pedestales de la base del jugador
                                if not isPedestalOwnedByPlayer(charData.pedestal, player) then continue end
                                local platform = charData.pedestal:FindFirstChild("Platform")
                                if platform then
                                        local d = (platform.Position - root.Position).Magnitude
                                        if d < nearDist then
                                                nearestPed=charData.pedestal nearDist=d nearCharIdx=entry.index
                                        end
                                end
                        end
                end
                if not nearestPed or not nearCharIdx then return end

                local charData = data.characters[nearCharIdx]
                if not charData then return end

                local moneyPile = nearestPed:FindFirstChild("MoneyPile")
                if moneyPile then
                        local mv = moneyPile:FindFirstChild("MoneyValue")
                        if mv and mv.Value > 0 then addMoney(player, mv.Value) end
                end

                ModelManager.clearPedestal(nearestPed)
                ModelManager.removeMoneyPile(nearestPed)
                ModelManager.removeUpgradeButton(nearestPed)
                charData.pedestal = nil
                data.carrying = nearCharIdx
                createCarryTool(player, charData.model)
                print(player.Name.." recogio "..charData.name.." del pedestal")
        end)
        if not ok then warn("Error RemoveFromPedestal: "..tostring(err)) end
end)

-- UPGRADE CHARACTER (tecla F)
Events.UpgradeCharacter.OnServerEvent:Connect(function(player)
        if upgradeCooldowns[player.UserId] then return end
        upgradeCooldowns[player.UserId] = true
        task.delay(0.3, function() upgradeCooldowns[player.UserId] = nil end)

        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                local data = playerData[player.UserId]
                if not data then return end
                local pchar = player.Character
                if not pchar then return end
                local root = pchar:FindFirstChild("HumanoidRootPart")
                if not root then return end

                -- Buscar el UpgradeButton MAS CERCANO al jugador
                local closestDist = math.huge
                local closestEntry = nil
                local closestPedestal = nil

                for _, entry in ipairs(iterateCharacters(data.characters)) do
                        local charData = entry.data
                        if not charData.pedestal then continue end
                        if not isValid(charData.pedestal) then charData.pedestal=nil continue end
                        -- Solo pedestales de la base del jugador
                        if not isPedestalOwnedByPlayer(charData.pedestal, player) then continue end

                        -- Usar la posicion del UpgradeButton (no del pedestal)
                        local upgradeBtn = charData.pedestal:FindFirstChild("UpgradeButton")
                        if not upgradeBtn then continue end

                        local dist = (upgradeBtn.Position - root.Position).Magnitude
                        if dist < closestDist then
                                closestDist = dist
                                closestEntry = entry
                                closestPedestal = charData.pedestal
                        end
                end

                -- Verificar que esta suficientemente cerca del boton (8 studs)
                if not closestEntry or closestDist >= 8 then return end

                local charData = closestEntry.data
                local currentLevel = charData.level or 1
                if currentLevel >= 100 then return end
                local cost = ModelManager.getUpgradeCost(currentLevel, charData.rarity)
                if (data.money or 0) < cost then return end

                data.money = data.money - cost
                charData.level = currentLevel + 1

                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins")
                        if coins then coins.Value = data.money end
                end
                Events.MoneyUpdate:FireClient(player, data.money)

                if isValid(closestPedestal) then
                        ModelManager.createLabels(closestPedestal, charData.name, charData.rarity, charData.level, charData.fusionLevel or 0)
                        ModelManager.updateUpgradeButtonUI(closestPedestal, charData.rarity, charData.level)
                        local mp = closestPedestal:FindFirstChild("MoneyPile")
                        if mp then
                                local lt = mp:FindFirstChild("CharLevel")
                                if lt then lt.Value = charData.level end
                        end
                end
                print(player.Name.." mejoro "..charData.name.." a Lv."..charData.level.." (-$"..cost..")")
                -- Sonido de mejora
                playSoundForPlayer(SOUND_UPGRADE, player)
                -- Efecto visual de upgrade (solo visible para el dueño)
                local upgradeBtn = closestPedestal:FindFirstChild("UpgradeButton")
                if isValid(upgradeBtn) then
                        pcall(function()
                                Events.ShowUpgradeEffect:FireClient(player, upgradeBtn.Position)
                        end)
                end
        end)
        if not ok then warn("Error UpgradeCharacter: "..tostring(err)) end
end)

-- DROP CHARACTER
Events.DropCharacter.OnServerEvent:Connect(function(player)
        local ok, err = pcall(function()
                local data = playerData[player.UserId]
                if not data or not data.carrying then return end
                local charData = data.characters[data.carrying]
                if not charData then return end

                local function cleanTool(parent)
                        if not parent then return end
                        local t = parent:FindFirstChild("Carrying")
                        if t then t:Destroy() end
                end
                cleanTool(player.Character)
                cleanTool(player:FindFirstChild("Backpack"))

                local character = player.Character
                if not character then return end
                local root = character:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local dropPos = root.Position + root.CFrame.LookVector*3 + Vector3.new(0,2,0)
                local charIndex = data.carrying
                local userId = player.UserId

                if charData.model then
                        local dm = charData.model:Clone()
                        for _, p in ipairs(dm:GetDescendants()) do
                                if p:IsA("BasePart") then
                                        p.Anchored = true
                                        p.CanCollide = false
                                end
                        end
                        dm.Parent = workspace
                        ModelManager.moveModelTo(dm, dropPos)
                        Debris:AddItem(dm, 35)

                        local tp = Instance.new("Part")
                        tp.Name = "DropTimer"
                        tp.Size = Vector3.new(1,1,1)
                        tp.Transparency = 1
                        tp.Anchored = true
                        tp.CanCollide = false
                        tp.Position = dropPos + Vector3.new(0,4,0)
                        tp.Parent = workspace

                        local ownerVal = Instance.new("ObjectValue")
                        ownerVal.Name = "Owner" ownerVal.Value = player ownerVal.Parent = tp
                        local idxVal = Instance.new("IntValue")
                        idxVal.Name = "CharIndex" idxVal.Value = charIndex idxVal.Parent = tp
                        local dmVal = Instance.new("ObjectValue")
                        dmVal.Name = "DropModel" dmVal.Value = dm dmVal.Parent = tp

                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(4,0,1.5,0)
                        bb.StudsOffset = Vector3.new(0,1,0)
                        bb.AlwaysOnTop = true
                        bb.Parent = tp

                        local bg = Instance.new("Frame")
                        bg.Size = UDim2.new(1,0,1,0)
                        bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
                        bg.BackgroundTransparency = 0.4
                        bg.BorderSizePixel = 0
                        bg.Parent = bb
                        Instance.new("UICorner", bg).CornerRadius = UDim.new(0,6)

                        local bgStroke = Instance.new("UIStroke")
                        bgStroke.Color = Color3.fromRGB(255,100,100)
                        bgStroke.Thickness = 1.5
                        bgStroke.Transparency = 0.3
                        bgStroke.Parent = bg

                        local nameLabel = Instance.new("TextLabel")
                        nameLabel.Size = UDim2.new(1,0,0.5,0)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.Text = charData.name.." Lv."..(charData.level or 1)
                        nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
                        nameLabel.TextScaled = true
                        nameLabel.Font = Enum.Font.GothamBold
                        nameLabel.Parent = bg

                        local tl = Instance.new("TextLabel")
                        tl.Name = "TimerLabel"
                        tl.Size = UDim2.new(1,0,0.5,0)
                        tl.Position = UDim2.new(0,0,0.5,0)
                        tl.BackgroundTransparency = 1
                        tl.Text = "30s"
                        tl.TextColor3 = Color3.fromRGB(255,100,100)
                        tl.TextScaled = true
                        tl.Font = Enum.Font.GothamBold
                        tl.Parent = bg

                        local key = userId.."_"..charIndex
                        droppedChars[key] = tp

                        task.spawn(function()
                                for i = 29, 0, -1 do
                                        task.wait(1)
                                        if not tp or not tp.Parent then return end
                                        if not playerData[userId] then
                                                if dm and dm.Parent then dm:Destroy() end
                                                if tp and tp.Parent then tp:Destroy() end
                                                droppedChars[key] = nil
                                                return
                                        end
                                        tl.Text = i.."s"
                                end
                                if tp and tp.Parent then
                                        local d = tp:FindFirstChild("DropModel")
                                        if d and d.Value and d.Value.Parent then d.Value:Destroy() end
                                        tp:Destroy()
                                end
                                local currentData = playerData[userId]
                                if currentData and currentData.characters then
                                        currentData.characters[charIndex] = nil
                                end
                                droppedChars[key] = nil
                        end)
                end

                data.carrying = nil
                print(player.Name.." solto "..charData.name)
        end)
        if not ok then warn("Error DropCharacter: "..tostring(err)) end
end)

-- MONEY TIMER - OPTIMIZADO
-- Solo acumula en el servidor, NO actualiza UI desde aqui
-- El cliente recoge el dinero cuando lo necesita
task.spawn(function()
        while true do
                task.wait(2)
                local activePlayers = {}
                for userId, data in pairs(playerData) do
                        table.insert(activePlayers, {userId=userId, data=data})
                end

                for _, playerEntry in ipairs(activePlayers) do
                        local data = playerEntry.data
                        if not data or not data.characters then continue end

                        local charList = iterateCharacters(data.characters)
                        for _, entry in ipairs(charList) do
                                local ok, err = pcall(function()
                                        local charData = entry.data
                                        if not charData or not charData.pedestal then return end
                                        if not isValid(charData.pedestal) then
                                                charData.pedestal = nil return
                                        end

                                        local moneyPile = charData.pedestal:FindFirstChild("MoneyPile")
                                        if not moneyPile or not moneyPile.Parent then return end

                                        local mv = moneyPile:FindFirstChild("MoneyValue")
                                        local rarityTag = moneyPile:FindFirstChild("Rarity")
                                        if not mv or not rarityTag then return end

                                        local levelTag = moneyPile:FindFirstChild("CharLevel")
                                        local fusionLevelTag = moneyPile:FindFirstChild("FusionLevel")
                                        local lvl = (levelTag and levelTag.Value) or 1
                                        local fLvl = (fusionLevelTag and fusionLevelTag.Value) or 0
                                        local rate = ModelManager.getMoneyRate(rarityTag.Value, lvl, fLvl)
                                        mv.Value = mv.Value + rate

                                        -- Actualizar UI del MoneyPile para que se vea el dinero acumulado
                                        local bb = moneyPile:FindFirstChild("MoneyGui")
                                        if bb and bb.Parent then
                                                local bg = bb:FindFirstChild("Frame")
                                                if bg and bg.Parent then
                                                        local lbl = bg:FindFirstChild("MoneyLabel")
                                                        if lbl and lbl.Parent then
                                                                lbl.Text = "$" .. ModelManager.formatMoney(mv.Value)
                                                        end
                                                end
                                        end
                                end)
                                if not ok then warn("[MoneyTimer] "..tostring(err)) end
                        end
                end
        end
end)

-- ============================================
-- SISTEMA DE GUARDADO (DataStore via SaveManager)
-- ============================================

-- Forward declaration (sendInventoryUpdate se define mas abajo en el archivo)
local sendInventoryUpdate

-- Guardar el progreso del jugador
local function savePlayerProgress(player)
        if not isPlayerValid(player) then return end
        local data = playerData[player.UserId]
        if not data then return end

        local baseLevel = BaseManager.getBaseLevel(player.UserId)
        local blockInventory = BuildManager.getInventory(player.UserId)
        local parcel = ParcelManager.getParcel(player.UserId)
        local blocksFolder = ParcelManager.getBlocksFolder(player.UserId)
        local bankBalance = BankManager.getBalance(player.UserId)
        -- Centro de la parcela para guardar posiciones relativas de bloques
        local parcelCenter = nil
        if parcel then
                parcelCenter = parcel.Position
        end

        print("[Save] Guardando " .. player.Name .. ": money=" .. (data.money or 0) .. ", bankBalance=" .. bankBalance .. ", blocksFolder=" .. (blocksFolder and "si" or "no"))

        local success = SaveManager.savePlayerData(player.UserId, data, baseLevel, blockInventory, blocksFolder, bankBalance, parcelCenter, data.unlockedBalls)
        if success then
                print("[Save] Datos guardados para " .. player.Name)
        else
                warn("[Save] Error al guardar datos de " .. player.Name)
        end
end

-- Restaurar el progreso del jugador desde datos guardados
local function restorePlayerProgress(player, savedData, base)
        if not savedData then return end
        local data = playerData[player.UserId]
        if not data then return end

        -- Evitar que se restaure 2 veces (si se llama desde task.delay 3 y task.delay 5)
        if data._restored then
                return
        end
        data._restored = true

        -- Restaurar dinero
        if savedData.money then
                data.money = savedData.money
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins")
                        if coins then coins.Value = data.money end
                end
                task.delay(0.5, function()
                        if isPlayerValid(player) then
                                Events.MoneyUpdate:FireClient(player, data.money)
                        end
                end)
        end

        -- Restaurar nivel de base
        if savedData.baseLevel and savedData.baseLevel > 1 then
                BaseManager.setBaseLevel(player.UserId, savedData.baseLevel)
                -- Activar pisos comprados
                if BaseUpgradeManager and base then
                        for floorNum = 2, savedData.baseLevel do
                                if floorNum == 2 then BaseUpgradeManager.activateFloor2(base)
                                elseif floorNum == 3 then BaseUpgradeManager.activateFloor3(base)
                                elseif floorNum == 4 then BaseUpgradeManager.activateFloor4(base)
                                elseif floorNum == 5 then BaseUpgradeManager.activateFloor5(base)
                                end
                        end
                        BaseUpgradeManager.updateButtonUI(base, savedData.baseLevel)
                end
        end

        -- Restaurar personajes
        if savedData.characters and base then
                for idxStr, charSaved in pairs(savedData.characters) do
                        local idx = tonumber(idxStr)
                        if idx and charSaved and charSaved.name and charSaved.rarity then
                                -- Buscar el modelo por modelName (nombre real del modelo, no el nombre mostrado)
                                -- Esto es CRITICO para personajes fusionados cuyo "name" es "X Fusion" pero el modelo real es "X"
                                local modelNameToFind = charSaved.modelName or charSaved.name
                                local model, folder = CharacterManager.getModelByName(charSaved.rarity, modelNameToFind)
                                if model then
                                        local charData = {
                                                name = charSaved.name,
                                                rarity = charSaved.rarity,
                                                level = charSaved.level or 1,
                                                model = model,
                                                folder = folder,
                                                pedestal = nil,
                                                fusionLevel = charSaved.fusionLevel or 0,
                                                modelName = modelNameToFind,
                                        }
                                        data.characters[idx] = charData

                                        -- Si tenia pedestal, colocarlo ahi
                                        if charSaved.pedestalName and charSaved.pedestalFloor then
                                                local pedestal = findPedestalByNameAndFloor(base, charSaved.pedestalName, charSaved.pedestalFloor)
                                                if pedestal and not pedestal:FindFirstChild("CharacterModel") then
                                                        -- Verificar que el pedestal este activo (visible)
                                                        local platform = pedestal:FindFirstChild("Platform")
                                                        local isVisible = true
                                                        if platform and platform.Transparency == 1 then
                                                                isVisible = false
                                                        end
                                                        if isVisible then
                                                                ModelManager.placeOnPedestal(model, pedestal)
                                                                charData.pedestal = pedestal
                                                                ModelManager.createLabels(pedestal, charData.name, charData.rarity, charData.level, charData.fusionLevel or 0)
                                                                local moneyPile = ModelManager.createMoneyPile(pedestal, charData.rarity, charData.level, charData.fusionLevel or 0, player)
                                                                local upgradeBtn = ModelManager.createUpgradeButton(pedestal, charData.rarity, charData.level, charData.fusionLevel or 0)
                                                                if upgradeBtn then
                                                                        setupUpgradeButtonEvents(pedestal, upgradeBtn, idx)
                                                                end
                                                                if moneyPile then
                                                                        setupMoneyPileEvents(pedestal, moneyPile)
                                                                        -- Restaurar dinero acumulado guardado
                                                                        local savedMoney = charSaved.accumulatedMoney or 0
                                                                        if savedMoney > 0 then
                                                                                local mv = moneyPile:FindFirstChild("MoneyValue")
                                                                                if mv then
                                                                                        mv.Value = savedMoney
                                                                                end
                                                                                -- Actualizar el label del MoneyPile
                                                                                local bbGui = moneyPile:FindFirstChild("MoneyGui")
                                                                                if bbGui then
                                                                                        local frame = bbGui:FindFirstChild("Frame")
                                                                                        if frame then
                                                                                                local ml = frame:FindFirstChild("MoneyLabel")
                                                                                                if ml then
                                                                                                        ml.Text = "$" .. tostring(savedMoney)
                                                                                                end
                                                                                        end
                                                                                end
                                                                        end
                                                                end
                                                        end
                                                end
                                        end
                                else
                                        warn("[Save] No se encontro modelo '" .. charSaved.name .. "' en rareza '" .. charSaved.rarity .. "' para " .. player.Name)
                                end
                        end
                end
        end

        -- Restaurar inventario de bloques (se carga via BuildManager.setInventory)
        if savedData.blockInventory and BuildManager.setInventory then
                BuildManager.setInventory(player.UserId, savedData.blockInventory)
                -- Enviar inventario al cliente para que actualice la UI
                task.delay(1, function()
                        if isPlayerValid(player) then
                                sendInventoryUpdate(player)
                        end
                end)
        end

        -- Restaurar bloques colocados (se hace despues de que la parcela este asignada)
        -- Las posiciones se guardan RELATIVAS al centro de la parcela, asi que sumamos
        -- el offset al centro de la parcela actual (que puede ser diferente a la original)
        if savedData.placedBlocks and #savedData.placedBlocks > 0 then
                task.delay(2, function()
                        if not isPlayerValid(player) then return end
                        local parcel = ParcelManager.getParcel(player.UserId)
                        if not parcel then return end
                        local parcelCenter = parcel.Position
                        local restoredCount = 0
                        for _, blockSaved in ipairs(savedData.placedBlocks) do
                                -- Posicion absoluta = centro de parcela actual + offset guardado
                                local position
                                if blockSaved.ox ~= nil then
                                        -- Formato nuevo: posiciones relativas (ox, oy, oz)
                                        position = Vector3.new(
                                                parcelCenter.X + blockSaved.ox,
                                                parcelCenter.Y + blockSaved.oy,
                                                parcelCenter.Z + blockSaved.oz
                                        )
                                else
                                        -- Formato antiguo: posiciones absolutas (px, py, pz) - compatibilidad
                                        position = Vector3.new(blockSaved.px, blockSaved.py, blockSaved.pz)
                                end
                                local rotation = Vector3.new(blockSaved.rx or 0, blockSaved.ry or 0, blockSaved.rz or 0)
                                -- Colocar bloque sin descontar del inventario (ya esta colocado)
                                local success = BuildManager.placeBlockNoCost(player, blockSaved.blockId, position, rotation)
                                if success then
                                        restoredCount = restoredCount + 1
                                end
                        end
                        print("[Save] " .. restoredCount .. "/" .. #savedData.placedBlocks .. " bloques restaurados para " .. player.Name)
                end)
        end

        -- Restaurar saldo del banco (siempre setear, incluso si es 0)
        local savedBankBalance = savedData.bankBalance or 0
        BankManager.setBalance(player.UserId, savedBankBalance)
        print("[Save] Banco restaurado para " .. player.Name .. " (saldo=" .. savedBankBalance .. ")")
        -- Enviar BankUIUpdate al cliente para que su UI muestre el saldo correcto desde el inicio
        task.delay(2, function()
                if isPlayerValid(player) then
                        local data = playerData[player.UserId]
                        local playerMoney = (data and data.money) or 0
                        pcall(function()
                                Events.BankUIUpdate:FireClient(player, savedBankBalance, playerMoney)
                        end)
                end
        end)

        -- Restaurar pelotas desbloqueadas (ya se envio al cliente en PlayerAdded, aqui solo aseguramos data)
        if savedData.unlockedBalls then
                local data = playerData[player.UserId]
                if data then
                        data.unlockedBalls = savedData.unlockedBalls
                        data.unlockedBalls["basic"] = true
                        print("[Save] Pelotas desbloqueadas restauradas para " .. player.Name)
                end
        end

        -- ============================================
        -- DINERO OFFLINE: calcular dinero generado mientras el jugador estuvo fuera
        -- ============================================
        if savedData.lastSaveTimestamp and savedData.lastSaveTimestamp > 0 then
                local currentTime = os.time()
                local elapsedSeconds = currentTime - savedData.lastSaveTimestamp

                -- Limitar a maximo 24 horas (86400 segundos) para no dar dinero infinito
                if elapsedSeconds > 86400 then
                        elapsedSeconds = 86400
                end

                -- Solo calcular si paso mas de 60 segundos (evitar calculos inutiles)
                if elapsedSeconds > 60 then
                        -- Calcular el rate total de todos los personajes en pedestales
                        local totalRatePerSecond = 0
                        if data.characters then
                                for _, charData in pairs(data.characters) do
                                        if charData and charData.pedestal then
                                                local rate = ModelManager.getMoneyRate(
                                                        charData.rarity,
                                                        charData.level or 1,
                                                        charData.fusionLevel or 0
                                                )
                                                -- El rate es por 2 segundos, asi que dividir entre 2 para obtener por segundo
                                                totalRatePerSecond = totalRatePerSecond + (rate / 2)
                                        end
                                end
                        end

                        if totalRatePerSecond > 0 then
                                local offlineEarnings = math.floor(totalRatePerSecond * elapsedSeconds)

                                -- Dar el dinero al jugador
                                data.money = (data.money or 0) + offlineEarnings
                                local leaderstats = player:FindFirstChild("leaderstats")
                                if leaderstats then
                                        local coins = leaderstats:FindFirstChild("Coins")
                                        if coins then coins.Value = data.money end
                                end

                                -- Enviar dinero actualizado al cliente
                                task.delay(3, function()
                                        if isPlayerValid(player) then
                                                Events.MoneyUpdate:FireClient(player, data.money)
                                        end
                                end)

                                -- Calcular tiempo legible para el mensaje
                                local hours = math.floor(elapsedSeconds / 3600)
                                local minutes = math.floor((elapsedSeconds % 3600) / 60)
                                local timeStr = ""
                                if hours > 0 then
                                        timeStr = hours .. "h " .. minutes .. "m"
                                else
                                        timeStr = minutes .. "m"
                                end

                                print("[Save] Dinero offline para " .. player.Name .. ": $" .. offlineEarnings .. " (" .. timeStr .. " fuera, rate/sec: " .. totalRatePerSecond .. ")")

                                                                -- Enviar notificacion visual al cliente
                                                                task.delay(4, function()
                                                                        if isPlayerValid(player) then
                                                                                pcall(function()
                                                                                        Events.OfflineEarnings:FireClient(player, offlineEarnings, timeStr)
                                                                                end)
                                                                        end
                                                                end)
                        end
                end
        end

        print("[Save] Progreso restaurado para " .. player.Name .. " (money=" .. (savedData.money or 0) .. ")")
end

-- PLAYERS
Players.PlayerAdded:Connect(function(player)
        print(player.Name.." se unio")
        playerData[player.UserId] = {characters={}, carrying=nil, money=0, unlockedBalls={["basic"]=true}}

        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player

        local coins = Instance.new("IntValue")
        coins.Name = "Coins" coins.Value = 0 coins.Parent = leaderstats

        -- Cargar datos guardados desde DataStore (antes de asignar la base)
        local savedData = SaveManager.loadPlayerData(player.UserId)
        if savedData then
                print("[Save] Datos encontrados para " .. player.Name)
        else
                print("[Save] Sin datos guardados para " .. player.Name .. " (jugador nuevo)")
        end

        -- Restaurar pelotas desbloqueadas INMEDIATAMENTE (sin esperar a que se asigne la base)
        -- Esto evita que el jugador vea las pelotas como "no compradas" al abrir la mochila
        if savedData and savedData.unlockedBalls then
                local data = playerData[player.UserId]
                if data then
                        data.unlockedBalls = savedData.unlockedBalls
                        data.unlockedBalls["basic"] = true
                        -- Enviar al cliente con un delay corto (1s) para que el BallThrower ya este cargado
                        task.delay(1, function()
                                if isPlayerValid(player) then
                                        pcall(function()
                                                Events.BallsRestored:FireClient(player, data.unlockedBalls)
                                        end)
                                        print("[Save] Pelotas desbloqueadas enviadas a " .. player.Name)
                                end
                        end)
                end
        end

        task.delay(1, function()
                if isPlayerValid(player) then
                        Events.MoneyUpdate:FireClient(player, savedData and savedData.money or 0)
                end
        end)

        task.delay(3, function()
                if not isPlayerValid(player) then return end
                local base = BaseManager.assign(player)
                if base then
                        showEmptyLabels(base)
                        -- Crear boton de mejorar base (solo si BaseUpgradeManager cargo)
                        if BaseUpgradeManager then
                                BaseUpgradeManager.createUpgradeButton(base, player)
                        end
                        -- Asignar parcela de construccion segun la base (Base1 -> Parcela 1, etc.)
                        if ParcelManager then
                                ParcelManager.assignByBaseName(player, base.Name)
                        end
                        -- Restaurar progreso DESPUES de que la base y parcela esten asignadas
                        if savedData then
                                restorePlayerProgress(player, savedData, base)
                        end
                else
                        task.delay(5, function()
                                if not isPlayerValid(player) then return end
                                base = BaseManager.assign(player)
                                if base then
                                        showEmptyLabels(base)
                                        if BaseUpgradeManager then
                                                BaseUpgradeManager.createUpgradeButton(base, player)
                                        end
                                        -- Asignar parcela tambien en el reintento
                                        if ParcelManager then
                                                ParcelManager.assignByBaseName(player, base.Name)
                                        end
                                        -- Restaurar progreso en el reintento tambien
                                        if savedData then
                                                restorePlayerProgress(player, savedData, base)
                                        end
                                end
                        end)
                end
        end)
end)

Players.PlayerRemoving:Connect(function(player)
        print(player.Name.." salio del juego")
        local userId = player.UserId
        local data = playerData[userId]

        if data then
                local function cleanTool(parent)
                        if not parent then return end
                        local t = parent:FindFirstChild("Carrying")
                        if t then t:Destroy() end
                end
                cleanTool(player.Character)
                cleanTool(player:FindFirstChild("Backpack"))

                for _, entry in ipairs(iterateCharacters(data.characters)) do
                        local charData = entry.data
                        if charData.pedestal and isValid(charData.pedestal) then
                                ModelManager.clearPedestal(charData.pedestal)
                                ModelManager.removeMoneyPile(charData.pedestal)
                                ModelManager.removeUpgradeButton(charData.pedestal)
                        end
                end

                for key, tp in pairs(droppedChars) do
                        if tp and tp.Parent then
                                local owner = tp:FindFirstChild("Owner")
                                if owner and owner.Value == player then
                                        local dmObj = tp:FindFirstChild("DropModel")
                                        if dmObj and dmObj.Value and dmObj.Value.Parent then dmObj.Value:Destroy() end
                                        tp:Destroy()
                                        droppedChars[key] = nil
                                end
                        else
                                droppedChars[key] = nil
                        end
                end
        end

        playerData[userId] = nil
        upgradeCooldowns[userId] = nil
        throwCooldowns[userId] = nil
        pickupCooldowns[userId] = nil
        for key in pairs(upgradeButtonCooldowns) do
                if string.find(key, tostring(userId)) then
                        upgradeButtonCooldowns[key] = nil
                end
        end

        -- Limpiar boton de mejora de base (solo si BaseUpgradeManager cargo)
        if BaseUpgradeManager then
                local base = BaseManager.getBase(userId)
                if base then
                        BaseUpgradeManager.removeUpgradeButton(base)
                        -- OCULTAR todos los pisos comprados (Floor2-5) al salir
                        for floorNum = 2, 5 do
                                local floor = base:FindFirstChild("Floor" .. floorNum)
                                if floor then
                                        for _, desc in ipairs(floor:GetDescendants()) do
                                                if desc:IsA("BasePart") then
                                                        desc.Transparency = 1
                                                        desc.CanCollide = false
                                                        desc.CanQuery = false
                                                end
                                        end
                                end
                        end
                end
        end

        -- GUARDAR PROGRESO antes de limpiar (la parcela y bloques aun existen)
        savePlayerProgress(player)

        BaseManager.release(userId)
        -- Liberar parcela de construccion del jugador
        if ParcelManager then
                ParcelManager.release(userId)
        end
        -- Limpiar inventario de bloques del jugador
        if BuildManager then
                BuildManager.cleanupPlayer(userId)
        end
        -- Limpiar saldo del banco del jugador (los datos ya estan guardados en DataStore)
        if BankManager then
                BankManager.cleanupPlayer(userId)
        end
        -- Limpiar cache de SaveManager
        SaveManager.clearCache(userId)
end)

-- ============================================
-- MEJORAR BASE (tecla H o click en boton)
-- ============================================
local baseUpgradeCooldowns = {}
Events.UpgradeBase.OnServerEvent:Connect(function(player)
        if not BaseUpgradeManager then return end -- Si no cargo, ignorar
        if baseUpgradeCooldowns[player.UserId] then return end
        baseUpgradeCooldowns[player.UserId] = true
        task.delay(0.5, function() baseUpgradeCooldowns[player.UserId] = nil end)

        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                local data = playerData[player.UserId]
                if not data then return end

                local base = BaseManager.getBase(player.UserId)
                if not base then return end

                local currentLevel = BaseManager.getBaseLevel(player.UserId)
                if currentLevel >= 5 then return end -- Max level (5 pisos)

                local cost = BaseManager.getUpgradeCost(currentLevel)
                if (data.money or 0) < cost then return end

                -- Pagar y subir nivel
                data.money = data.money - cost
                BaseManager.setBaseLevel(player.UserId, currentLevel + 1)
                local newLevel = BaseManager.getBaseLevel(player.UserId)

                -- Actualizar leaderstats
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins")
                        if coins then coins.Value = data.money end
                end
                Events.MoneyUpdate:FireClient(player, data.money)

                -- Activar el piso correspondiente al nuevo nivel
                if newLevel == 2 then
                        BaseUpgradeManager.activateFloor2(base)
                elseif newLevel == 3 then
                        BaseUpgradeManager.activateFloor3(base)
                elseif newLevel == 4 then
                        BaseUpgradeManager.activateFloor4(base)
                elseif newLevel == 5 then
                        BaseUpgradeManager.activateFloor5(base)
                end
                BaseUpgradeManager.updateButtonUI(base, newLevel)

                -- Sonido de mejora (usamos el de upgrade)
                playSoundForPlayer(SOUND_UPGRADE, player)

                print(player.Name.." mejoro su base a Nivel " .. newLevel .. " (-$" .. ModelManager.formatMoney(cost) .. ")")
        end)
        if not ok then warn("Error UpgradeBase: "..tostring(err)) end
end)

-- ============================================
-- SISTEMA DE FUSION DE PERSONAJES
-- MECANICA: el jugador carga un personaje, se acerca a la maquina,
-- presiona E para depositarlo en Slot A o B. Cuando ambos slots estan llenos
-- con personajes identicos, puede presionar FUSIONAR.
-- ============================================
local FUSION_MACHINE_CENTER = Vector3.new(-142.3, 10.8, 11.0)
local FUSION_PROXIMITY = 20 -- studs

-- Slots de fusion por jugador: fusionSlots[userId] = { slotA = charIdx or nil, slotB = charIdx or nil }
local fusionSlots = {}
-- Trackear jugadores que ya escucharon el sonido de proximidad (para que suene 1 vez por visita)
local fusionSoundPlayed = {}

-- Helper: obtener info de un personaje para enviar al cliente
local function getCharInfo(charData, index)
        return {
                index = index,
                name = charData.name,
                rarity = charData.rarity,
                level = charData.level or 1,
                fusionLevel = charData.fusionLevel or 0
        }
end

-- Proximity detection: enviar estado de fusion al cliente cuando esta cerca
task.spawn(function()
        while true do
                task.wait(0.5)
                for userId, data in pairs(playerData) do
                        local player = Players:GetPlayerByUserId(userId)
                        if player and player.Character then
                                local root = player.Character:FindFirstChild("HumanoidRootPart")
                                if root then
                                        local dist = (root.Position - FUSION_MACHINE_CENTER).Magnitude
                                        if dist < FUSION_PROXIMITY then
                                                -- SONIDO DE PROXIMIDAD: suena 1 vez cuando el jugador se acerca
                                                if not fusionSoundPlayed[userId] then
                                                        fusionSoundPlayed[userId] = true
                                                        playSoundForPlayer(SOUND_FUSION_NEAR, player, 6)
                                                end
                                                -- Esta cerca: enviar estado de fusion
                                                local slots = fusionSlots[userId] or { slotA = nil, slotB = nil }
                                                local slotAInfo = nil
                                                local slotBInfo = nil
                                                if slots.slotA and data.characters[slots.slotA] then
                                                        slotAInfo = getCharInfo(data.characters[slots.slotA], slots.slotA)
                                                end
                                                if slots.slotB and data.characters[slots.slotB] then
                                                        slotBInfo = getCharInfo(data.characters[slots.slotB], slots.slotB)
                                                end
                                                -- Info del personaje que lleva en la mano (si hay)
                                                local carryingInfo = nil
                                                if data.carrying and data.characters[data.carrying] then
                                                        carryingInfo = getCharInfo(data.characters[data.carrying], data.carrying)
                                                end
                                                Events.FusionUIUpdate:FireClient(player, {
                                                        slotA = slotAInfo,
                                                        slotB = slotBInfo,
                                                        carrying = carryingInfo
                                                })
                                        else
                                                -- Se alejo: resetear flag del sonido para que suene otra vez al volver
                                                fusionSoundPlayed[userId] = nil
                                        end
                                end
                        end
                end
        end
end)

-- Manejar deposito de personaje en slot de fusion
Events.DepositCharacter.OnServerEvent:Connect(function(player)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                local data = playerData[player.UserId]
                if not data then return end
                if not data.carrying then return end -- debe estar cargando algo

                -- Verificar cercania a la maquina
                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local dist = (root.Position - FUSION_MACHINE_CENTER).Magnitude
                if dist > FUSION_PROXIMITY then return end

                -- BLOQUEAR personajes fusionados (no se pueden volver a fusionar)
                local charData = data.characters[data.carrying]
                if not charData then return end
                if (charData.fusionLevel or 0) > 0 then
                        print(player.Name .. " intento depositar personaje fusionado (bloqueado)")
                        return
                end

                -- Inicializar slots si no existen
                if not fusionSlots[player.UserId] then
                        fusionSlots[player.UserId] = { slotA = nil, slotB = nil }
                end
                local slots = fusionSlots[player.UserId]

                -- Si el personaje ya esta en un slot, no hacer nada
                if slots.slotA == data.carrying or slots.slotB == data.carrying then return end

                -- Depositar en el primer slot vacio
                if not slots.slotA then
                        slots.slotA = data.carrying
                elseif not slots.slotB then
                        slots.slotB = data.carrying
                else
                        return -- ambos slots llenos
                end

                -- Quitar de la mano del jugador (destruir carry tool)
                if char then
                        local tool = char:FindFirstChild("Carrying")
                        if tool then tool:Destroy() end
                end
                local bp = player:FindFirstChild("Backpack")
                if bp then
                        local tool = bp:FindFirstChild("Carrying")
                        if tool then tool:Destroy() end
                end

                data.carrying = nil
                print(player.Name .. " deposito personaje en maquina de fusion")
        end)
        if not ok then warn("Error DepositCharacter: "..tostring(err)) end
end)

-- Manejar remocion de personaje de slot de fusion (click izquierdo en slot)
Events.RemoveFromFusionSlot.OnServerEvent:Connect(function(player, slotName)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                local data = playerData[player.UserId]
                if not data then return end
                if data.carrying then return end -- no debe estar cargando nada

                local slots = fusionSlots[player.UserId]
                if not slots then return end

                -- slotName debe ser "A" o "B"
                local slotKey = nil
                if slotName == "A" then
                        slotKey = "slotA"
                elseif slotName == "B" then
                        slotKey = "slotB"
                else
                        return
                end

                local charIdx = slots[slotKey]
                if not charIdx then return end -- slot vacio

                local charData = data.characters[charIdx]
                if not charData then
                        slots[slotKey] = nil
                        return
                end

                -- Devolver el personaje a la mano del jugador
                data.carrying = charIdx
                createCarryTool(player, charData.model)

                -- Limpiar el slot
                slots[slotKey] = nil

                print(player.Name .. " quito personaje del slot " .. slotName .. " de la maquina de fusion")
        end)
        if not ok then warn("Error RemoveFromFusionSlot: "..tostring(err)) end
end)

-- Manejar fusion de personajes (usa los slots almacenados)
Events.FuseCharacters.OnServerEvent:Connect(function(player)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                local data = playerData[player.UserId]
                if not data then return end
                if data.carrying then return end -- no debe estar cargando nada

                local slots = fusionSlots[player.UserId]
                if not slots or not slots.slotA or not slots.slotB then return end

                local charA = data.characters[slots.slotA]
                local charB = data.characters[slots.slotB]
                if not charA or not charB then return end

                -- Validar: mismo nombre, misma rareza, mismo fusionLevel
                if charA.name ~= charB.name then return end
                if charA.rarity ~= charB.rarity then return end
                if (charA.fusionLevel or 0) ~= (charB.fusionLevel or 0) then return end

                -- Crear personaje fusionado
                local newFusionLevel = (charA.fusionLevel or 0) + 1
                local fusedName = charA.name
                if newFusionLevel == 1 then
                        fusedName = charA.name .. " Fusion"
                else
                        local roman = {"", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"}
                        fusedName = charA.name .. " Fusion " .. (roman[newFusionLevel] or tostring(newFusionLevel))
                end

                -- Eliminar los 2 originales
                data.characters[slots.slotA] = nil
                data.characters[slots.slotB] = nil

                -- Limpiar slots
                fusionSlots[player.UserId] = { slotA = nil, slotB = nil }

                -- Crear el personaje fusionado
                local newIdx = getNextCharIndex(data.characters)
                data.characters[newIdx] = {
                        name = fusedName,
                        rarity = charA.rarity,
                        level = charA.level,
                        model = charA.model,
                        folder = charA.folder,
                        pedestal = nil,
                        fusionLevel = newFusionLevel,
                        modelName = charA.modelName or (charA.model and charA.model.Name) or charA.name
                }

                -- Dar al jugador como carrying (sale por el output de la maquina)
                data.carrying = newIdx
                createCarryTool(player, charA.model)

                -- Sonido de activacion de fusion (al hacer click en FUSIONAR)
                playSoundForPlayer(SOUND_FUSION_ACTIVATE, player, 5)
                -- Sonido de mejora adicional
                playSoundForPlayer(SOUND_UPGRADE, player)

                print(player.Name .. " fuciono " .. charA.name .. " + " .. charB.name .. " = " .. fusedName .. " (x" .. math.pow(3, newFusionLevel) .. ")")
        end)
        if not ok then warn("Error FuseCharacters: "..tostring(err)) end
end)

-- Limpiar slots de fusion cuando el jugador sale
-- (agregar al PlayerRemoving existente)
local originalPlayerRemoving = nil
-- El PlayerRemoving ya esta conectado, agregamos limpieza de slots al final
task.spawn(function()
        while true do
                task.wait(5)
                -- Limpiar slots de jugadores que ya no estan
                for userId, _ in pairs(fusionSlots) do
                        local player = Players:GetPlayerByUserId(userId)
                        if not player then
                                fusionSlots[userId] = nil
                        end
                end
        end
end)

-- ============================================
-- SISTEMA DE PELOTAS (servidor)
-- Crea/elimina la pelota en el personaje del jugador para que TODOS la vean
-- ============================================
-- ReplicatedStorage ya declarado al inicio del script

-- Configuracion de pelotas en el servidor
local SERVER_BALL_TYPES = {
        basic = {
                color = Color3.fromRGB(100, 200, 255),
                material = Enum.Material.SmoothPlastic,
                transparency = 0
        },
        fire = {
                color = Color3.fromRGB(255, 100, 30),
                material = Enum.Material.Neon,
                transparency = 0,
                modelName = "FireBallModel"
        },
        earth = {
                color = Color3.fromRGB(140, 90, 50),
                material = Enum.Material.Slate,
                transparency = 0,
                modelName = "EarthBallModel"
        },
        air = {
                color = Color3.fromRGB(240, 250, 255),
                material = Enum.Material.Glass,
                transparency = 0.5,
                modelName = "AirBallModel"
        },
        water = {
                color = Color3.fromRGB(80, 150, 220),
                material = Enum.Material.Glass,
                transparency = 0.3,
                modelName = "WaterBallModel"
        }
}

Events.EquipBall.OnServerEvent:Connect(function(player, ballType, equip)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                local char = player.Character
                if not char then return end

                -- Limpiar pelota anterior si existe
                local oldBall = char:FindFirstChild("CrystalBall")
                if oldBall then oldBall:Destroy() end

                if not equip then return end -- si equip=false, solo eliminar

                local ballConfig = SERVER_BALL_TYPES[ballType] or SERVER_BALL_TYPES.basic

                -- Buscar la mano derecha
                local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
                if not rightHand then return end

                -- Crear la pelota (modelo 3D o Part simple)
                local ball, mainPart
                local template = nil
                if ballConfig.modelName then
                        template = ReplicatedStorage:FindFirstChild(ballConfig.modelName)
                end

                if template then
                        ball = template:Clone()
                        ball.Name = "CrystalBall"
                        mainPart = ball.PrimaryPart or ball:FindFirstChild("Handle") or ball:FindFirstChildWhichIsA("BasePart")
                        if not mainPart then
                                ball:Destroy()
                                template = nil
                        end
                end

                if not template then
                        ball = Instance.new("Part")
                        ball.Name = "CrystalBall"
                        ball.Size = Vector3.new(1.5, 1.5, 1.5)
                        ball.Shape = Enum.PartType.Ball
                        ball.Color = ballConfig.color
                        ball.Material = ballConfig.material
                        ball.Transparency = ballConfig.transparency
                        mainPart = ball
                end

                -- Configurar partes
                for _, desc in ipairs(ball:GetDescendants()) do
                        if desc:IsA("BasePart") then
                                desc.Anchored = false
                                desc.CanCollide = false
                                desc.CanQuery = false
                                desc.Massless = true
                        end
                end
                if ball:IsA("BasePart") then
                        ball.Anchored = false
                        ball.CanCollide = false
                        ball.CanQuery = false
                        ball.Massless = true
                end

                -- Posicionar y weld
                mainPart.Position = rightHand.Position + Vector3.new(0, 0, -1.0)
                ball.Parent = char

                local weld = Instance.new("Weld")
                weld.Name = "BallWeld"
                weld.Part0 = rightHand
                weld.Part1 = mainPart
                weld.C0 = CFrame.new(0, 0, -1.0)
                weld.Parent = ball
        end)
        if not ok then warn("Error EquipBall: "..tostring(err)) end
end)

task.delay(3, function()
        CrystalSpawner.spawnAll()
end)

-- ============================================
-- SISTEMA DE CONSTRUCCION (BuyBlock / PlaceBlock / RemoveBlock)
-- Flujo: BuyBlock (con dinero) -> inventario -> PlaceBlock (usa inventario, no dinero)
-- Al quitar un bloque, se devuelve al inventario del jugador
-- ============================================

-- Cooldowns para evitar spam de bloques (0.05s = 20 bloques/seg max)
local placeBlockCooldowns = {}
local removeBlockCooldowns = {}
local buyBlockCooldowns = {}

-- Helper: enviar inventario actualizado al cliente
function sendInventoryUpdate(player)
        if not isPlayerValid(player) then return end
        local inv = BuildManager.getInventory(player.UserId)
        -- Convertir a tabla serializable (id -> count)
        local data = {}
        for id, count in pairs(inv) do
                data[id] = count
        end
        pcall(function()
                Events.UpdateInventory:FireClient(player, data)
        end)
end

-- BUY BLOCK: compra un bloque con dinero, lo agrega al inventario
Events.BuyBlock.OnServerEvent:Connect(function(player, blockId)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                -- Cooldown
                if buyBlockCooldowns[player.UserId] then return end
                buyBlockCooldowns[player.UserId] = true
                task.delay(0.1, function() buyBlockCooldowns[player.UserId] = nil end)

                local data = playerData[player.UserId]
                if not data then return end

                -- Validar bloque
                local config = BuildManager.getBlockConfig(blockId)
                if not config then
                        warn("[Build] Bloque invalido: " .. tostring(blockId))
                        return
                end

                -- Validar dinero
                if (data.money or 0) < config.cost then
                        warn("[Build] " .. player.Name .. " no tiene dinero para " .. config.name .. " ($" .. config.cost .. ")")
                        return
                end

                -- Comprar bloque (agrega al inventario)
                local success, result = BuildManager.buyBlock(player, blockId)
                if not success then
                        warn("[Build] No se pudo comprar bloque: " .. tostring(result))
                        return
                end

                -- Descontar dinero
                data.money = data.money - config.cost
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins")
                        if coins then coins.Value = data.money end
                end
                Events.MoneyUpdate:FireClient(player, data.money)

                -- Enviar inventario actualizado al cliente
                sendInventoryUpdate(player)

                -- Sonido de compra
                playSoundForPlayer(SOUND_BUY_BLOCK, player)
        end)
        if not ok then warn("Error BuyBlock: "..tostring(err)) end
end)

-- PLACE BLOCK: coloca un bloque del inventario (no gasta dinero)
Events.PlaceBlock.OnServerEvent:Connect(function(player, blockId, position, rotation)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                -- Cooldown
                if placeBlockCooldowns[player.UserId] then return end
                placeBlockCooldowns[player.UserId] = true
                task.delay(0.05, function() placeBlockCooldowns[player.UserId] = nil end)

                -- Colocar bloque (validacion de inventario dentro de BuildManager)
                local success, result = BuildManager.placeBlock(player, blockId, position, rotation)
                if not success then
                        warn("[Build] No se pudo colocar bloque: " .. tostring(result))
                        return
                end

                -- Enviar inventario actualizado al cliente (count bajo)
                sendInventoryUpdate(player)
        end)
        if not ok then warn("Error PlaceBlock: "..tostring(err)) end
end)

-- REMOVE BLOCK: quita un bloque y lo devuelve al inventario
Events.RemoveBlock.OnServerEvent:Connect(function(player, block)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                -- Cooldown
                if removeBlockCooldowns[player.UserId] then return end
                removeBlockCooldowns[player.UserId] = true
                task.delay(0.05, function() removeBlockCooldowns[player.UserId] = nil end)

                -- Quitar bloque y devolverlo al inventario (returnToInventory = true)
                local success, msg = BuildManager.removeBlock(player, block, true)
                if not success then
                        warn("[Build] No se pudo quitar bloque: " .. tostring(msg))
                        return
                end

                -- Enviar inventario actualizado al cliente (count subio)
                sendInventoryUpdate(player)
        end)
        if not ok then warn("Error RemoveBlock: "..tostring(err)) end
end)

-- ============================================
-- RemoteFunction: GetPlayerParcel
-- Cliente pide su parcela asignada, servidor responde con la Instance
-- Usado por el Beam guia para apuntar a la parcela correcta (no la mas cercana)
-- ============================================
Events.GetPlayerParcel.OnServerInvoke = function(player)
        if not isPlayerValid(player) then return nil end
        if not ParcelManager then return nil end
        local parcel = ParcelManager.getParcel(player.UserId)
        return parcel
end

-- ============================================
-- SISTEMA DE BANCO (DepositMoney / WithdrawMoney)
-- ============================================

-- ============================================
-- COMPRA DE PELOTAS (BuyBall)
-- ============================================
-- Costos de las pelotas (deben coincidir con BALL_TYPES del cliente)
local BALL_COSTS = {
        basic = 0,
        fire = 100000,        -- 100K
        earth = 5000000,      -- 5M
        water = 100000000,    -- 100M
        air = 5000000000,     -- 5B
}

Events.BuyBall.OnServerEvent:Connect(function(player, ballKey)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                local data = playerData[player.UserId]
                if not data then return end

                -- Validar ballKey
                local cost = BALL_COSTS[ballKey]
                if not cost then
                        warn("[BuyBall] Pelota invalida: " .. tostring(ballKey))
                        Events.BallPurchased:FireClient(player, false, ballKey, "Pelota invalida")
                        return
                end

                -- Validar que no este ya desbloqueada
                if data.unlockedBalls and data.unlockedBalls[ballKey] then
                        warn("[BuyBall] " .. player.Name .. " ya tiene " .. ballKey .. " desbloqueada")
                        Events.BallPurchased:FireClient(player, false, ballKey, "Ya tienes esta pelota")
                        return
                end

                -- Validar dinero
                if (data.money or 0) < cost then
                        warn("[BuyBall] " .. player.Name .. " no tiene dinero para " .. ballKey .. " ($" .. cost .. ")")
                        Events.BallPurchased:FireClient(player, false, ballKey, "Dinero insuficiente! Necesitas $" .. cost)
                        return
                end

                -- Descontar dinero
                data.money = data.money - cost
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins")
                        if coins then coins.Value = data.money end
                end
                Events.MoneyUpdate:FireClient(player, data.money)

                -- Marcar como desbloqueada
                if not data.unlockedBalls then data.unlockedBalls = {} end
                data.unlockedBalls[ballKey] = true

                -- Confirmar compra al cliente
                Events.BallPurchased:FireClient(player, true, ballKey, "Compra exitosa")
                print("[BuyBall] " .. player.Name .. " compro " .. ballKey .. " por $" .. cost)
        end)
        if not ok then warn("Error BuyBall: "..tostring(err)) end
end)

-- Cooldowns para deposito/retiro
local depositCooldowns = {}
local withdrawCooldowns = {}

-- Helper: enviar actualizacion de UI del banco al cliente
local function sendBankUpdate(player)
        if not isPlayerValid(player) then return end
        local balance = BankManager.getBalance(player.UserId)
        local data = playerData[player.UserId]
        local playerMoney = (data and data.money) or 0
        pcall(function()
                Events.BankUIUpdate:FireClient(player, balance, playerMoney)
        end)
end

-- DEPOSIT MONEY: jugador deposita dinero en el banco
Events.DepositMoney.OnServerEvent:Connect(function(player, amount)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                -- Cooldown
                if depositCooldowns[player.UserId] then return end
                depositCooldowns[player.UserId] = true
                task.delay(0.3, function() depositCooldowns[player.UserId] = nil end)

                local data = playerData[player.UserId]
                if not data then return end

                -- Validar cantidad
                amount = math.floor(tonumber(amount) or 0)
                if amount <= 0 then
                        warn("[Bank] Cantidad invalida de deposito: " .. tostring(amount))
                        return
                end

                -- Validar que el jugador tenga ese dinero
                if (data.money or 0) < amount then
                        warn("[Bank] " .. player.Name .. " no tiene $" .. amount .. " para depositar (tiene $" .. (data.money or 0) .. ")")
                        return
                end

                -- Quitar dinero del jugador y depositar en banco
                data.money = data.money - amount
                BankManager.deposit(player.UserId, amount)

                -- Actualizar leaderstats
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins")
                        if coins then coins.Value = data.money end
                end
                Events.MoneyUpdate:FireClient(player, data.money)

                -- Enviar actualizacion de UI del banco
                sendBankUpdate(player)

                print("[Bank] " .. player.Name .. " deposito $" .. amount .. " (saldo banco: $" .. BankManager.getBalance(player.UserId) .. ")")
        end)
        if not ok then warn("Error DepositMoney: "..tostring(err)) end
end)

-- WITHDRAW MONEY: jugador retira dinero del banco
Events.WithdrawMoney.OnServerEvent:Connect(function(player, amount)
        local ok, err = pcall(function()
                if not isPlayerValid(player) then return end
                -- Cooldown
                if withdrawCooldowns[player.UserId] then return end
                withdrawCooldowns[player.UserId] = true
                task.delay(0.3, function() withdrawCooldowns[player.UserId] = nil end)

                local data = playerData[player.UserId]
                if not data then return end

                -- Validar cantidad
                amount = math.floor(tonumber(amount) or 0)
                if amount <= 0 then
                        warn("[Bank] Cantidad invalida de retiro: " .. tostring(amount))
                        return
                end

                -- Retirar del banco (valida saldo suficiente)
                local success, result = BankManager.withdraw(player.UserId, amount)
                if not success then
                        warn("[Bank] No se pudo retirar: " .. tostring(result))
                        return
                end

                -- Dar dinero al jugador
                data.money = (data.money or 0) + amount

                -- Actualizar leaderstats
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats then
                        local coins = leaderstats:FindFirstChild("Coins")
                        if coins then coins.Value = data.money end
                end
                Events.MoneyUpdate:FireClient(player, data.money)

                -- Enviar actualizacion de UI del banco
                sendBankUpdate(player)

                print("[Bank] " .. player.Name .. " retiro $" .. amount .. " (saldo banco: $" .. BankManager.getBalance(player.UserId) .. ")")
        end)
        if not ok then warn("Error WithdrawMoney: "..tostring(err)) end
end)

print("=== GameHandler iniciado ===")

-- ============================================
-- SISTEMA DE LEADERBOARD (tabla de lideres)
-- ============================================

-- Helper: obtener nombre de jugador por userId (con cache)
local playerNameCache = {}
local function getPlayerName(userId)
        if playerNameCache[userId] then return playerNameCache[userId] end
        local success, name = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
        end)
        if success and name then
                playerNameCache[userId] = name
                return name
        end
        return "Jugador"
end

-- Helper: enviar leaderboard a todos los clientes
local function sendLeaderboardToAll()
        local top = LeaderboardManager.getTop30()
        -- Construir tabla serializable con nombre y balance
        local data = {}
        for i, entry in ipairs(top) do
                table.insert(data, {
                        rank = i,
                        userId = entry.userId,
                        name = getPlayerName(entry.userId),
                        balance = entry.balance,
                })
        end
        -- Enviar a todos los jugadores
        for _, player in ipairs(Players:GetPlayers()) do
                pcall(function()
                        Events.LeaderboardUpdate:FireClient(player, data)
                end)
        end
end

-- Cargar leaderboard al iniciar el servidor
task.spawn(function()
        -- Esperar un poco a que el DataStore este listo
        task.wait(3)
        LeaderboardManager.loadAll()
        sendLeaderboardToAll()
        LeaderboardManager.updateTop3Characters()
        print("[Leaderboard] Sistema iniciado")
end)

-- Auto-update del leaderboard cada 60 segundos
task.spawn(function()
        while true do
                task.wait(60)
                -- Actualizar balances de jugadores online en el cache del leaderboard
                for _, player in ipairs(Players:GetPlayers()) do
                        local balance = BankManager.getBalance(player.UserId)
                        LeaderboardManager.updateBalance(player.UserId, balance)
                end
                -- Recalcular top
                LeaderboardManager.recalculateTop()
                -- Guardar en DataStore
                LeaderboardManager.saveAll()
                -- Enviar a clientes
                sendLeaderboardToAll()
                -- Actualizar personajes del Top 3
                LeaderboardManager.updateTop3Characters()
        end
end)

-- ============================================
-- AUTO-SAVE: guardar todos los jugadores cada 60 segundos
-- ============================================
task.spawn(function()
        while true do
                task.wait(60)
                for _, player in ipairs(Players:GetPlayers()) do
                        if isPlayerValid(player) then
                                local ok = pcall(function()
                                        savePlayerProgress(player)
                                end)
                                if not ok then
                                        warn("[Save] Error en auto-save de " .. player.Name)
                                end
                        end
                end
        end
end)

-- Guardar todos los jugadores cuando el servidor se cierra
game:BindToClose(function()
        print("[Save] Servidor cerrandose - guardando todos los jugadores...")
        for _, player in ipairs(Players:GetPlayers()) do
                if isPlayerValid(player) then
                        pcall(function()
                                savePlayerProgress(player)
                        end)
                end
        end
        task.wait(3) -- esperar a que terminen los saves
        print("[Save] Todos los jugadores guardados.")
end)
















































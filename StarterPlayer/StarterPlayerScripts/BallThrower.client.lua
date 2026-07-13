local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ballEquipped = false
local inputDebounce = false
local throwDebounce = false
local isCarrying = false
local activeBalls = 0
local MAX_ACTIVE_BALLS = 5
local upgradeDebounce = false
local nearFusionMachine = false
local fusionSlotA = nil
local fusionSlotB = nil
local fusionCarrying = nil
local nearUpgradeButton = false

local ThrowBallEvent = ReplicatedStorage:WaitForChild("ThrowBall", 15)
local PickupChestEvent = ReplicatedStorage:WaitForChild("PickupChest", 15)
local PlaceCharacterEvent = ReplicatedStorage:WaitForChild("PlaceCharacter", 15)
local DropCharacterEvent = ReplicatedStorage:WaitForChild("DropCharacter", 15)
local RemoveFromPedestalEvent = ReplicatedStorage:WaitForChild("RemoveFromPedestal", 15)
local PickupDroppedEvent = ReplicatedStorage:WaitForChild("PickupDropped", 15)
local MoneyUpdateEvent = ReplicatedStorage:WaitForChild("MoneyUpdate", 15)
local UpgradeCharacterEvent = ReplicatedStorage:WaitForChild("UpgradeCharacter", 15)
local UpgradeBaseEvent = ReplicatedStorage:WaitForChild("UpgradeBase", 15)
local ChestOpenEvent = ReplicatedStorage:WaitForChild("ChestOpen", 15)
local FusionUIUpdateEvent = ReplicatedStorage:WaitForChild("FusionUIUpdate", 15)
local FuseCharactersEvent = ReplicatedStorage:WaitForChild("FuseCharacters", 15)
local DepositCharacterEvent = ReplicatedStorage:WaitForChild("DepositCharacter", 15)
local RemoveFromFusionSlotEvent = ReplicatedStorage:WaitForChild("RemoveFromFusionSlot", 15)
local EquipBallEvent = ReplicatedStorage:WaitForChild("EquipBall", 15)
local ShowBillEffectEvent = ReplicatedStorage:WaitForChild("ShowBillEffect", 15)
local ShowUpgradeEffectEvent = ReplicatedStorage:WaitForChild("ShowUpgradeEffect", 15)
local PlaceBlockEvent = ReplicatedStorage:WaitForChild("PlaceBlock", 15)
local RemoveBlockEvent = ReplicatedStorage:WaitForChild("RemoveBlock", 15)

-- ============================================
-- EFECTO DE BILLETE (solo visible para el dueño)
-- ============================================
-- Cuando el servidor dispara ShowBillEffect, el cliente clona el modelo BillModel
-- de ReplicatedStorage y crea una pequeña lluvia de billetes en world-space.
-- Como el billete se crea en el cliente (no en el servidor), los demas jugadores
-- nunca lo reciben por red -> solo el dueño lo ve.
local function spawnBillEffect(position, amount)
        local billTemplate = ReplicatedStorage:FindFirstChild("BillModel")
        if not billTemplate then
                warn("[BillEffect] No se encontro BillModel en ReplicatedStorage. Sube el modelo y nombralo 'BillModel'.")
                return
        end

        -- Cantidad de billetes segun el monto (3-8 billetes, nunca pasarse de 8)
        local count = math.clamp(math.floor(amount / 5) + 3, 3, 8)

        for i = 1, count do
                task.spawn(function()
                        local bill = billTemplate:Clone()
                        bill.Parent = workspace

                        -- Posicion inicial con pequena dispersion aleatoria
                        local offset = Vector3.new(
                                (math.random() - 0.5) * 4,
                                0,
                                (math.random() - 0.5) * 4
                        )
                        -- Si el modelo tiene PrimaryPart usarlo, sino buscar primera BasePart
                        local part = bill.PrimaryPart or bill:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                                bill:PivotTo(CFrame.new(position + offset + Vector3.new(0, 2, 0)))
                        end

                        -- Animacion: arco hacia arriba + rotacion + fade out
                        local startTime = tick()
                        local duration = 1.4
                        local initialPos = position + offset + Vector3.new(0, 2, 0)
                        local direction = Vector3.new(
                                (math.random() - 0.5) * 6,
                                8 + math.random() * 4, -- sube entre 8 y 12 studs
                                (math.random() - 0.5) * 6
                        )
                        local spinSpeed = Vector3.new(
                                math.random() * 6,
                                math.random() * 6,
                                math.random() * 6
                        )

                        -- Recolectar todas las partes del modelo para animar
                        local parts = {}
                        for _, p in ipairs(bill:GetDescendants()) do
                                if p:IsA("BasePart") then
                                        table.insert(parts, p)
                                end
                        end
                        if part and #parts == 0 then table.insert(parts, part) end

                        -- Guardar CFrames iniciales
                        local initialCFrames = {}
                        for _, p in ipairs(parts) do
                                initialCFrames[p] = p.CFrame
                        end

                        while tick() - startTime < duration do
                                local dt = task.wait()
                                local elapsed = tick() - startTime
                                local t = elapsed / duration
                                -- Movimiento parabolico (sube y cae ligeramente)
                                local yOffset = direction.Y * t - 12 * t * t
                                local xOffset = direction.X * t
                                local zOffset = direction.Z * t
                                local basePos = initialPos + Vector3.new(xOffset, yOffset, zOffset)

                                -- Aplicar a cada parte relativa a su CFrame inicial
                                for _, p in ipairs(parts) do
                                        if p and p.Parent then
                                                local initCF = initialCFrames[p]
                                                local spinCF = CFrame.Angles(spinSpeed.X * elapsed, spinSpeed.Y * elapsed, spinSpeed.Z * elapsed)
                                                p.CFrame = CFrame.new(basePos) * spinCF * (initCF - initCF.Position)
                                        end
                                end

                                -- Fade out en el ultimo 40%
                                if t > 0.6 then
                                        local fadeT = (t - 0.6) / 0.4
                                        for _, p in ipairs(parts) do
                                                if p and p.Parent then
                                                        p.Transparency = fadeT
                                                end
                                        end
                                end
                        end

                        -- Limpiar
                        if bill and bill.Parent then
                                bill:Destroy()
                        end
                end)
        end
end

ShowBillEffectEvent.OnClientEvent:Connect(function(position, amount)
        pcall(spawnBillEffect, position, amount)
end)

-- ============================================
-- EFECTO DE UPGRADE (solo visible para el dueño)
-- ============================================
-- Cuando el servidor dispara ShowUpgradeEffect, el cliente crea UNA sola imagen
-- de upgrade en world-space sobre el boton de mejora, con animacion de escala +
-- ascenso + fade-out. Una sola imagen, no varias.
local function spawnUpgradeEffect(position)
        local UPGRADE_IMAGE = "rbxassetid://97532714186492"

        -- Part invisible anclado para sostener el BillboardGui
        local anchor = Instance.new("Part")
        anchor.Name = "UpgradeEffectAnchor"
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Position = position + Vector3.new(0, 2, 0)
        anchor.Parent = workspace

        -- BillboardGui para que la imagen siempre mire a la camara
        local bb = Instance.new("BillboardGui")
        bb.Name = "UpgradeEffectGui"
        bb.Size = UDim2.new(0, 120, 0, 120)
        bb.StudsOffset = Vector3.new(0, 0, 0)
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.MaxDistance = 100 -- solo visible de cerca
        bb.Parent = anchor

        local img = Instance.new("ImageLabel")
        img.Name = "UpgradeImage"
        img.Size = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.Image = UPGRADE_IMAGE
        img.ScaleType = Enum.ScaleType.Fit
        img.ImageTransparency = 0
        img.Parent = bb

        -- Animacion: escalar de grande + subir + fade out (1.2s)
        task.spawn(function()
                local startTime = tick()
                local duration = 1.2
                local initialSize = 80
                local maxSize = 240
                local riseHeight = 4 -- studs que sube
                while tick() - startTime < duration do
                        local dt = task.wait()
                        local elapsed = tick() - startTime
                        local t = elapsed / duration
                        -- Escala: ease out (crece rapido al inicio y se frena)
                        local easedT = 1 - (1 - t) * (1 - t)
                        local size = initialSize + (maxSize - initialSize) * easedT
                        bb.Size = UDim2.new(0, size, 0, size)
                        -- Sube gradualmente
                        anchor.CFrame = CFrame.new(position + Vector3.new(0, 2 + riseHeight * t, 0))
                        -- Fade out en el ultimo 50%
                        if t > 0.5 then
                                local fadeT = (t - 0.5) / 0.5
                                img.ImageTransparency = fadeT
                        end
                end
                if anchor and anchor.Parent then
                        anchor:Destroy()
                end
        end)
end

ShowUpgradeEffectEvent.OnClientEvent:Connect(function(position)
        pcall(spawnUpgradeEffect, position)
end)

-- ============================================
-- CONFIGURACION DE PELOTAS
-- ============================================
local BALL_TYPES = {
        basic = {
                name = "Basica",
                icon = "⚽",
                color = Color3.fromRGB(100, 200, 255),
                material = Enum.Material.SmoothPlastic,
                damage = 1,
                speed = 100,
                gravity = 1.0, -- gravedad normal
                bounce = true,
                transparency = 0,
                unlocked = true,
                cost = 0,
                description = "Pelota balanceada"
        },
        fire = {
                name = "Fuego",
                icon = "🔥",
                iconImage = "rbxassetid://14373611462",
                color = Color3.fromRGB(255, 100, 30),
                material = Enum.Material.Neon,
                damage = 2,
                speed = 100,
                gravity = 0.3, -- gravedad baja (vuela mas recto)
                bounce = false, -- no rebota, se extingue
                transparency = 0,
                unlocked = false,
                cost = 10000,
                description = "Mas rapida y dano x2",
                soundEquip = "rbxassetid://129504465599355", -- sonido al equipar
                soundThrow = "rbxassetid://130422645188028", -- sonido al lanzar
                modelName = "FireBallModel" -- modelo 3D personalizado en ReplicatedStorage
        },
        earth = {
                name = "Tierra",
                icon = "🟤",
                iconImage = "rbxassetid://104704077581701",
                color = Color3.fromRGB(140, 90, 50),
                material = Enum.Material.Slate,
                damage = 3,
                speed = 100,
                gravity = 1.0,
                bounce = true,
                transparency = 0,
                unlocked = false,
                cost = 50000,
                description = "Dano x3, modelo de tierra",
                soundEquip = "rbxassetid://9085909202",
                soundThrow = "rbxassetid://78919029033811",
                modelName = "EarthBallModel"
        },
        air = {
                name = "Aire",
                icon = "💨",
                iconImage = "rbxassetid://129908338697871",
                color = Color3.fromRGB(240, 250, 255),
                material = Enum.Material.Glass,
                damage = 1,
                speed = 150,
                gravity = 0.2, -- gravedad muy baja (vuela recto)
                bounce = true, -- rebota mucho
                transparency = 0.5,
                unlocked = false,
                cost = 100000,
                description = "Muy rapida, alcance largo",
                soundEquip = "rbxassetid://92952421540994",
                soundThrow = "rbxassetid://139638115866253",
                modelName = "AirBallModel"
        },
        water = {
                name = "Agua",
                icon = "💧",
                iconImage = "rbxassetid://111743315105905",
                color = Color3.fromRGB(80, 150, 220),
                material = Enum.Material.Glass,
                damage = 2,
                speed = 90,
                gravity = 1.0,
                bounce = true,
                transparency = 0.3,
                unlocked = false,
                cost = 500000,
                description = "Rebota mucho, dano x2",
                soundEquip = "rbxassetid://107317726222506",
                soundThrow = "rbxassetid://9117822127",
                modelName = "WaterBallModel"
        }
}

-- Pelota seleccionada actualmente
local selectedBallType = "basic"

-- Animacion cacheada
local cachedThrowAnim = Instance.new("Animation")
cachedThrowAnim.AnimationId = "rbxassetid://90927250635352"
local cachedTrack = nil

-- Funcion helper para reproducir sonidos en el cliente
local function playClientSound(soundId, volume)
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume or 0.5
        sound.Parent = player:WaitForChild("PlayerGui")
        sound:Play()
        -- Auto-destruir despues de 5 segundos
        Debris:AddItem(sound, 5)
end

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local MONEY_GREEN = Color3.fromRGB(76,175,80)
local MONEY_GREEN_BRIGHT = Color3.fromRGB(129,199,132)

-- Bottom bar
local bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.new(0,80,0,70)
bottomBar.Position = UDim2.new(0.7,-40,1,-80)
bottomBar.BackgroundColor3 = Color3.fromRGB(20,20,30)
bottomBar.BackgroundTransparency = 0.2
bottomBar.BorderSizePixel = 0
bottomBar.Parent = screenGui
Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0,16)
local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(100,200,255)
uiStroke.Thickness = 2 uiStroke.Transparency = 0.5 uiStroke.Parent = bottomBar

local ballButton = Instance.new("TextButton")
ballButton.Size = UDim2.new(0,60,0,60)
ballButton.Position = UDim2.new(0.5,-30,0.5,-30)
ballButton.BackgroundColor3 = Color3.fromRGB(40,40,60)
ballButton.BorderSizePixel = 0 ballButton.Text = ""
ballButton.Parent = bottomBar
Instance.new("UICorner", ballButton).CornerRadius = UDim.new(0,12)
local btnStroke = Instance.new("UIStroke")
btnStroke.Name = "BtnStroke"
btnStroke.Color = Color3.fromRGB(100,200,255)
btnStroke.Thickness = 2 btnStroke.Transparency = 0.3 btnStroke.Parent = ballButton

local ballIcon = Instance.new("TextLabel")
ballIcon.Size = UDim2.new(0.6,0,0.6,0)
ballIcon.Position = UDim2.new(0.2,0,0.1,0)
ballIcon.BackgroundTransparency = 1 ballIcon.Text = "⚽"
ballIcon.TextScaled = true ballIcon.Parent = ballButton

-- ImageLabel para iconos de pelota con imagen (se alterna con ballIcon)
local ballIconImg = Instance.new("ImageLabel")
ballIconImg.Name = "BallIconImg"
ballIconImg.Size = UDim2.new(0.7, 0, 0.7, 0)
ballIconImg.Position = UDim2.new(0.15, 0, 0.05, 0)
ballIconImg.BackgroundTransparency = 1
ballIconImg.ScaleType = Enum.ScaleType.Fit
ballIconImg.Visible = false
ballIconImg.ZIndex = 2
ballIconImg.Parent = ballButton

-- Funcion para actualizar el icono de la pelota equipada (imagen o emoji)
local function updateBallIcon()
        local config = BALL_TYPES[selectedBallType]
        if not config then return end
        if config.iconImage then
                ballIconImg.Image = config.iconImage
                ballIconImg.Visible = true
                ballIcon.Visible = false
        else
                ballIcon.Text = config.icon or "?"
                ballIcon.Visible = true
                ballIconImg.Visible = false
        end
end

local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(0.3,0,0.3,0)
keyLabel.Position = UDim2.new(0.65,0,0.6,0)
keyLabel.BackgroundColor3 = Color3.fromRGB(100,200,255)
keyLabel.BorderSizePixel = 0 keyLabel.Text = "1"
keyLabel.TextColor3 = Color3.fromRGB(0,0,0)
keyLabel.TextScaled = true keyLabel.Font = Enum.Font.GothamBold
keyLabel.Parent = ballButton
Instance.new("UICorner", keyLabel).CornerRadius = UDim.new(0,4)

-- Carry panel
local carryPanel = Instance.new("Frame")
carryPanel.Size = UDim2.new(0,220,0,70)
carryPanel.Position = UDim2.new(1,-240,1,-80)
carryPanel.BackgroundColor3 = Color3.fromRGB(20,20,30)
carryPanel.BackgroundTransparency = 0.2
carryPanel.BorderSizePixel = 0 carryPanel.Visible = false
carryPanel.Parent = screenGui
Instance.new("UICorner", carryPanel).CornerRadius = UDim.new(0,16)
local carryStroke = Instance.new("UIStroke")
carryStroke.Color = Color3.fromRGB(255,200,50)
carryStroke.Thickness = 2 carryStroke.Transparency = 0.3 carryStroke.Parent = carryPanel

local placeBtn = Instance.new("TextButton")
placeBtn.Size = UDim2.new(0,90,0,50)
placeBtn.Position = UDim2.new(0,10,0,10)
placeBtn.BackgroundColor3 = Color3.fromRGB(0,120,60)
placeBtn.BorderSizePixel = 0 placeBtn.Text = "Colocar"
placeBtn.TextColor3 = Color3.fromRGB(255,255,255)
placeBtn.TextScaled = true placeBtn.Font = Enum.Font.GothamBold
placeBtn.Parent = carryPanel
Instance.new("UICorner", placeBtn).CornerRadius = UDim.new(0,10)
local placeKey = Instance.new("TextLabel")
placeKey.Size = UDim2.new(0.3,0,0.3,0)
placeKey.Position = UDim2.new(0.65,0,0.6,0)
placeKey.BackgroundColor3 = Color3.fromRGB(255,255,255)
placeKey.BorderSizePixel = 0 placeKey.Text = "E"
placeKey.TextColor3 = Color3.fromRGB(0,120,60)
placeKey.TextScaled = true placeKey.Font = Enum.Font.GothamBold
placeKey.Parent = placeBtn
Instance.new("UICorner", placeKey).CornerRadius = UDim.new(0,4)

local dropBtn = Instance.new("TextButton")
dropBtn.Size = UDim2.new(0,90,0,50)
dropBtn.Position = UDim2.new(0,120,0,10)
dropBtn.BackgroundColor3 = Color3.fromRGB(150,30,30)
dropBtn.BorderSizePixel = 0 dropBtn.Text = "Soltar"
dropBtn.TextColor3 = Color3.fromRGB(255,255,255)
dropBtn.TextScaled = true dropBtn.Font = Enum.Font.GothamBold
dropBtn.Parent = carryPanel
Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0,10)
local dropKey = Instance.new("TextLabel")
dropKey.Size = UDim2.new(0.3,0,0.3,0)
dropKey.Position = UDim2.new(0.65,0,0.6,0)
dropKey.BackgroundColor3 = Color3.fromRGB(255,255,255)
dropKey.BorderSizePixel = 0 dropKey.Text = "G"
dropKey.TextColor3 = Color3.fromRGB(150,30,30)
dropKey.TextScaled = true dropKey.Font = Enum.Font.GothamBold
dropKey.Parent = dropBtn
Instance.new("UICorner", dropKey).CornerRadius = UDim.new(0,4)

-- Money panel
local moneyPanel = Instance.new("Frame")
moneyPanel.Size = UDim2.new(0,180,0,55)
moneyPanel.Position = UDim2.new(1,-200,0,15)
moneyPanel.BackgroundColor3 = Color3.fromRGB(20,20,30)
moneyPanel.BackgroundTransparency = 0.2
moneyPanel.BorderSizePixel = 0 moneyPanel.Parent = screenGui
Instance.new("UICorner", moneyPanel).CornerRadius = UDim.new(0,16)
local moneyStroke = Instance.new("UIStroke")
moneyStroke.Color = MONEY_GREEN
moneyStroke.Thickness = 2 moneyStroke.Transparency = 0.3 moneyStroke.Parent = moneyPanel

local moneyIcon = Instance.new("ImageLabel")
moneyIcon.Name = "MoneyIcon"
moneyIcon.Size = UDim2.new(0.28, 0, 0.85, 0)
moneyIcon.Position = UDim2.new(0.03, 0, 0.075, 0)
moneyIcon.BackgroundTransparency = 1
moneyIcon.Image = "rbxassetid://128422594736289"
moneyIcon.ScaleType = Enum.ScaleType.Fit
moneyIcon.Parent = moneyPanel

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.Size = UDim2.new(0.62, 0, 0.6, 0)
moneyLabel.Position = UDim2.new(0.35, 0, 0.2, 0)
moneyLabel.BackgroundTransparency = 1 moneyLabel.Text = "0"
moneyLabel.TextColor3 = MONEY_GREEN_BRIGHT
moneyLabel.TextScaled = true moneyLabel.Font = Enum.Font.GothamBlack
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Parent = moneyPanel

-- ============================================
-- Formato de dinero en cliente (K, M, B, T, Q)
-- ============================================
local function formatMoneyClient(amount)
        amount = amount or 0
        if amount >= 1000000000000 then
                local t = amount / 1000000000000
                if t == math.floor(t) then
                        return tostring(math.floor(t)) .. "T"
                else
                        return string.format("%.1fT", t)
                end
        elseif amount >= 1000000000 then
                local b = amount / 1000000000
                if b == math.floor(b) then
                        return tostring(math.floor(b)) .. "B"
                else
                        return string.format("%.1fB", b)
                end
        elseif amount >= 1000000 then
                local m = amount / 1000000
                if m == math.floor(m) then
                        return tostring(math.floor(m)) .. "M"
                else
                        return string.format("%.1fM", m)
                end
        elseif amount >= 10000 then
                local k = amount / 1000
                if k == math.floor(k) then
                        return tostring(math.floor(k)) .. "K"
                else
                        return string.format("%.1fK", k)
                end
        else
                return tostring(amount)
        end
end

-- Upgrade hint
local upgradeHint = Instance.new("Frame")
upgradeHint.Size = UDim2.new(0,250,0,55)
upgradeHint.Position = UDim2.new(0.5,-125,0.7,0)
upgradeHint.BackgroundColor3 = Color3.fromRGB(20,20,30)
upgradeHint.BackgroundTransparency = 0.15
upgradeHint.BorderSizePixel = 0 upgradeHint.Visible = false
upgradeHint.Parent = screenGui
Instance.new("UICorner", upgradeHint).CornerRadius = UDim.new(0,16)
local hintStroke = Instance.new("UIStroke")
hintStroke.Color = Color3.fromRGB(255,215,0)
hintStroke.Thickness = 2 hintStroke.Transparency = 0.2 hintStroke.Parent = upgradeHint

local hintKeyBg = Instance.new("Frame")
hintKeyBg.Size = UDim2.new(0,40,0,40)
hintKeyBg.Position = UDim2.new(0,10,0,7.5)
hintKeyBg.BackgroundColor3 = Color3.fromRGB(255,215,0)
hintKeyBg.BorderSizePixel = 0 hintKeyBg.Parent = upgradeHint
Instance.new("UICorner", hintKeyBg).CornerRadius = UDim.new(0,8)

local hintKeyText = Instance.new("TextLabel")
hintKeyText.Size = UDim2.new(1,0,1,0)
hintKeyText.BackgroundTransparency = 1 hintKeyText.Text = "F"
hintKeyText.TextColor3 = Color3.fromRGB(0,0,0)
hintKeyText.TextScaled = true hintKeyText.Font = Enum.Font.GothamBlack
hintKeyText.Parent = hintKeyBg

local hintText = Instance.new("TextLabel")
hintText.Size = UDim2.new(0,185,0,40)
hintText.Position = UDim2.new(0,58,0,7.5)
hintText.BackgroundTransparency = 1 hintText.Text = "Mejorar personaje"
hintText.TextColor3 = Color3.fromRGB(255,215,0)
hintText.TextScaled = true hintText.Font = Enum.Font.GothamBold
hintText.TextXAlignment = Enum.TextXAlignment.Left
hintText.Parent = upgradeHint

-- FUNCIONES
local function updateUI()
        bottomBar.Visible = not isCarrying
        carryPanel.Visible = isCarrying
end

local function updateButton()
        if ballEquipped then
                ballButton.BackgroundColor3 = Color3.fromRGB(100,200,255)
                ballIcon.TextColor3 = Color3.fromRGB(0,0,0)
                keyLabel.TextColor3 = Color3.fromRGB(100,200,255)
                keyLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
                btnStroke.Color = Color3.fromRGB(150,230,255)
        else
                ballButton.BackgroundColor3 = Color3.fromRGB(40,40,60)
                ballIcon.TextColor3 = Color3.fromRGB(255,255,255)
                keyLabel.TextColor3 = Color3.fromRGB(0,0,0)
                keyLabel.BackgroundColor3 = Color3.fromRGB(100,200,255)
                btnStroke.Color = Color3.fromRGB(100,200,255)
        end
end

-- OPTIMIZADO: Un solo loop con RunService en lugar de dos task.spawn separados
local checkTimer = 0
local upgradeCheckTimer = 0
RunService.Heartbeat:Connect(function(dt)
        checkTimer = checkTimer + dt
        upgradeCheckTimer = upgradeCheckTimer + dt

        -- Check carrying cada 0.5s
        if checkTimer >= 0.5 then
                checkTimer = 0
                local char = player.Character
                local newCarrying = false
                if char and char:FindFirstChild("Carrying") then
                        newCarrying = true
                elseif player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Carrying") then
                        newCarrying = true
                end
                if newCarrying ~= isCarrying then
                        isCarrying = newCarrying
                        updateUI()
                end
        end

        -- Check upgrade button cada 0.3s
        if upgradeCheckTimer >= 0.3 then
                upgradeCheckTimer = 0
                if isCarrying then
                        if nearUpgradeButton then
                                nearUpgradeButton = false
                                upgradeHint.Visible = false
                        end
                        return
                end

                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local found = false
                local map = workspace:FindFirstChild("Map")
                if map then
                        local bases = map:FindFirstChild("Bases")
                        if bases then
                                for _, base in ipairs(bases:GetChildren()) do
                                        if found then break end
                                        -- Buscar en TODOS los pisos (1, 2, 3, 4, 5)
                                        local allPedestalFolders = {}
                                        local p1 = base:FindFirstChild("Pedestals")
                                        if p1 then table.insert(allPedestalFolders, p1) end
                                        for floorNum = 2, 5 do
                                                local floor = base:FindFirstChild("Floor" .. floorNum)
                                                if floor then
                                                        local peds = floor:FindFirstChild("Pedestals" .. floorNum)
                                                        if peds then table.insert(allPedestalFolders, peds) end
                                                end
                                        end
                                        -- Buscar UpgradeButtons en todos los pedestales
                                        for _, pedFolder in ipairs(allPedestalFolders) do
                                                if found then break end
                                                for _, ped in ipairs(pedFolder:GetChildren()) do
                                                        local btn = ped:FindFirstChild("UpgradeButton")
                                                        if btn and (btn.Position - root.Position).Magnitude < 8 then
                                                                found = true break
                                                        end
                                                end
                                        end
                                end
                        end
                end

                if found ~= nearUpgradeButton then
                        nearUpgradeButton = found
                        upgradeHint.Visible = found
                end
        end
end)

-- ============================================
-- HELPER: Crear pelota desde modelo 3D o Part simple
-- Si la pelota tiene modelName, busca el modelo en ReplicatedStorage
-- Retorna: (objeto, mainPart) donde objeto puede ser Model o Part
-- ============================================
local function createBallObject(ballConfig)
        local template = nil
        if ballConfig.modelName then
                template = ReplicatedStorage:FindFirstChild(ballConfig.modelName)
        end

        if template then
                -- Clonar el modelo 3D personalizado
                local obj = template:Clone()
                obj.Name = "CrystalBall"

                -- Encontrar la parte principal (PrimaryPart, Handle, o primera BasePart)
                local mainPart = obj.PrimaryPart or obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                if not mainPart then
                        obj:Destroy()
                        template = nil -- fallback a Part simple
                else
                        -- Configurar todas las partes del modelo
                        for _, desc in ipairs(obj:GetDescendants()) do
                                if desc:IsA("BasePart") then
                                        desc.Anchored = false
                                        desc.CanCollide = false
                                        desc.CanQuery = false
                                        desc.Massless = true
                                end
                        end
                        -- Si el propio objeto es una Part (no un Model)
                        if obj:IsA("BasePart") then
                                obj.Anchored = false
                                obj.CanCollide = false
                                obj.CanQuery = false
                                obj.Massless = true
                                mainPart = obj
                        end
                        return obj, mainPart
                end
        end

        -- Fallback: crear Part simple
        local ball = Instance.new("Part")
        ball.Name = "CrystalBall"
        ball.Size = Vector3.new(1.5, 1.5, 1.5)
        ball.Shape = Enum.PartType.Ball
        ball.Color = ballConfig.color
        ball.Material = ballConfig.material
        ball.Anchored = false
        ball.CanCollide = false
        ball.Massless = true
        ball.Transparency = ballConfig.transparency
        return ball, ball
end

-- BALL SYSTEM
-- La pelota se crea en el SERVIDOR para que todos los jugadores la vean
-- El cliente solo envia el tipo de pelota a equipar
local function equipBall()
        if ballEquipped or isCarrying then return end
        local char = player.Character
        if not char then return end

        -- Enviar evento al servidor para crear la pelota (visible para todos)
        if EquipBallEvent then
                EquipBallEvent:FireServer(selectedBallType, true)
        end

        ballEquipped = true
        updateButton()
        updateUI()

        -- Sonido al equipar (si la pelota tiene sonido)
        local ballConfig = BALL_TYPES[selectedBallType] or BALL_TYPES.basic
        if ballConfig.soundEquip then
                playClientSound(ballConfig.soundEquip, 0.6)
        end
end

local function unequipBall()
        if not ballEquipped then return end
        -- Enviar evento al servidor para quitar la pelota
        if EquipBallEvent then
                EquipBallEvent:FireServer(selectedBallType, false)
        end
        ballEquipped = false
        updateButton()
        updateUI()
end

-- Re-equipar la pelota en la mano (despues de lanzar)
-- El servidor la crea automaticamente, solo reproducir sonido si aplica
local function reEquipBall()
        if EquipBallEvent then
                EquipBallEvent:FireServer(selectedBallType, true)
        end
end

local function throwBall(targetPosition)
        if not ballEquipped or isCarrying then return end
        if throwDebounce or activeBalls >= MAX_ACTIVE_BALLS then return end
        throwDebounce = true

        local char = player.Character
        if not char then throwDebounce=false return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not root then throwDebounce=false return end

        -- Quitar la pelota de la mano durante el lanzamiento (pedir al servidor)
        if EquipBallEvent then
                EquipBallEvent:FireServer(selectedBallType, false)
        end

        -- Animacion de lanzar
        if humanoid then
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if animator then
                        if not cachedTrack then
                                cachedTrack = animator:LoadAnimation(cachedThrowAnim)
                        end
                        if cachedTrack and not cachedTrack.IsPlaying then
                                cachedTrack:Play(0.1)
                        end
                end
        end

        -- Obtener configuracion de la pelota seleccionada
        local ballConfig = BALL_TYPES[selectedBallType] or BALL_TYPES.basic

        -- Sonido al lanzar (si la pelota tiene sonido)
        if ballConfig.soundThrow then
                playClientSound(ballConfig.soundThrow, 0.6)
        end

        -- Calcular direccion: usar targetPosition (toque movil) o mouse.Hit (PC)
        local aimPos = targetPosition
        if not aimPos then
                local mouseHit = mouse.Hit
                if mouseHit then aimPos = mouseHit.Position end
        end

        -- ============================================
        -- LANZAMIENTO HIBRIDO: pelota local + servidor
        -- ============================================
        -- 1. Crear pelota LOCAL inmediatamente (cero lag, 100% fluido)
        --    Esta pelota es solo visual, no daña cristales
        local localBall, localMainPart = createBallObject(ballConfig)
        localBall.Name = "ThrownBallLocal"
        local startPos = root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 3, 0)
        localMainPart.Position = startPos
        localMainPart.Anchored = false
        -- CanCollide depende de si rebota o no
        -- Si rebota (basic): CanCollide = true para que choque con el suelo y rebote
        -- Si no rebota (fire): CanCollide = false para que no choque, solo se destruye
        localMainPart.CanCollide = ballConfig.bounce and true or false
        localMainPart.CanQuery = false
        localMainPart.Massless = true
        local gravity = ballConfig.gravity or 1.0
        local bounceVal = ballConfig.bounce and 0.8 or 0.0
        localMainPart.CustomPhysicalProperties = PhysicalProperties.new(gravity, 0.3, bounceVal, 0.5, 0.5)
        -- Weld partes secundarias
        for _, desc in ipairs(localBall:GetDescendants()) do
                if desc:IsA("BasePart") and desc ~= localMainPart then
                        desc.Anchored = false
                        desc.CanCollide = false
                        desc.CanQuery = false
                        desc.Massless = true
                        local w = Instance.new("WeldConstraint")
                        w.Part0 = localMainPart
                        w.Part1 = desc
                        w.Parent = desc
                end
        end
        localBall.Parent = workspace

        -- Aplicar velocidad INMEDIATAMENTE (antes de parentear ya esta lista)
        if aimPos then
                local direction = (aimPos - startPos).Unit
                local upImpulse = 20 * (ballConfig.gravity or 1.0)
                localMainPart.AssemblyLinearVelocity = direction * ballConfig.speed + Vector3.new(0, upImpulse, 0)
        end

        -- Auto-eliminar la pelota local despues de 4s
        Debris:AddItem(localBall, 4)

        -- Si la pelota local toca un cristal, enviar evento al servidor
        local localHitSent = false
        local localTouchedConn
        localTouchedConn = localMainPart.Touched:Connect(function(hit)
                if localHitSent then return end
                if hit.Name == "Crystal" then
                        localHitSent = true
                        if ThrowBallEvent then
                                ThrowBallEvent:FireServer(hit.Position, selectedBallType)
                        end
                        if localTouchedConn then
                                localTouchedConn:Disconnect()
                                localTouchedConn = nil
                        end
                end
        end)

        -- Si la pelota no rebota (ej: fuego), destruirla al tocar el suelo
        if not ballConfig.bounce then
                local destroyConn
                destroyConn = localMainPart.Touched:Connect(function(hit)
                        if localBall and localBall.Parent then
                                localBall:Destroy()
                        end
                        if destroyConn then
                                destroyConn:Disconnect()
                        end
                end)
        end

        -- 2. ENVIAR al servidor para crear pelota visible para TODOS
        -- El servidor crea una pelota que todos ven (incluido el que lanza)
        -- Despues de 0.15s, destruir la pelota local para evitar duplicado
        -- (la pelota del servidor ya estara visible para entonces)
        local launchVel = Vector3.new(0, 0, 0)
        if aimPos then
                local direction = (aimPos - startPos).Unit
                local upImpulse = 20 * (ballConfig.gravity or 1.0)
                launchVel = direction * ballConfig.speed + Vector3.new(0, upImpulse, 0)
        end

        if ThrowBallEvent then
                ThrowBallEvent:FireServer(startPos, launchVel, selectedBallType)
        end

        -- Destruir pelota local despues de 0.15s (cuando la del servidor aparece)
        task.delay(0.15, function()
                if localBall and localBall.Parent then
                        localBall:Destroy()
                end
        end)

        activeBalls = activeBalls + 1
        task.delay(4.5, function() activeBalls = math.max(0, activeBalls-1) end)

        -- Despues del lanzamiento, volver a poner la pelota en la mano
        task.delay(0.5, function()
                if ballEquipped and not isCarrying then
                        reEquipBall()
                end
        end)

        task.wait(0.5)
        throwDebounce = false
end

-- INPUTS
UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.One then
                if isCarrying or inputDebounce then return end
                inputDebounce = true
                if ballEquipped then unequipBall() else equipBall() end
                task.wait(0.3)
                inputDebounce = false

        elseif input.KeyCode == Enum.KeyCode.E then
                if inputDebounce then return end
                inputDebounce = true
                if isCarrying then
                        -- Si esta cerca de la maquina de fusion, depositar ahi
                        if nearFusionMachine and DepositCharacterEvent then
                                DepositCharacterEvent:FireServer()
                        elseif PlaceCharacterEvent then
                                PlaceCharacterEvent:FireServer()
                        end
                else
                        -- Solo dispara UN evento, el servidor decide qué hacer
                        if PickupChestEvent then PickupChestEvent:FireServer() end
                        task.wait(0.15)
                        if not isCarrying then
                                if RemoveFromPedestalEvent then RemoveFromPedestalEvent:FireServer() end
                        end
                        task.wait(0.15)
                        if not isCarrying then
                                if PickupDroppedEvent then PickupDroppedEvent:FireServer() end
                        end
                end
                task.wait(0.3)
                inputDebounce = false

        elseif input.KeyCode == Enum.KeyCode.G then
                if isCarrying and DropCharacterEvent then
                        DropCharacterEvent:FireServer()
                end

        elseif input.KeyCode == Enum.KeyCode.F then
                if not isCarrying and nearUpgradeButton and not upgradeDebounce then
                        upgradeDebounce = true
                        if UpgradeCharacterEvent then UpgradeCharacterEvent:FireServer() end
                        task.delay(0.3, function() upgradeDebounce = false end)
                end

        elseif input.KeyCode == Enum.KeyCode.H then
                -- Mejorar base (solo si no esta cargando nada)
                if not isCarrying and UpgradeBaseEvent then
                        UpgradeBaseEvent:FireServer()
                end
        end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if ballEquipped and not isCarrying then throwBall() end
        end
end)

ballButton.MouseButton1Click:Connect(function()
        if isCarrying or inputDebounce then return end
        inputDebounce = true
        if ballEquipped then unequipBall() else equipBall() end
        task.wait(0.3)
        inputDebounce = false
end)

-- ============================================
-- SISTEMA DE LANZAR PARA MOVIL (toque en pantalla)
-- Detecta toques en cualquier parte de la pantalla
-- y lanza la pelota en esa direccion
-- ============================================
local touchDebounce = false

-- Funcion para obtener la posicion 3D del toque en pantalla
local function getTouchWorldPosition(touchPosition)
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        -- Crear un rayo desde la camara hacia la posicion del toque
        local unitRay = camera:ScreenPointToRay(touchPosition.X, touchPosition.Y)
        -- Calcular un punto a 100 studs de distancia (donde "apunta" el toque)
        return camera.CFrame.Position + unitRay.Direction * 100
end

-- Detectar toques en la pantalla (movil)
-- Usar TouchStart en vez de TouchTap para que NO pause el movimiento del jugador
-- TouchTap se dispara al levantar el dedo (pausa el personaje), TouchStart es instantaneo
UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- Solo procesar toques en pantalla (movil)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        if not ballEquipped or isCarrying then return end
        if touchDebounce or throwDebounce then return end

        touchDebounce = true
        -- Obtener la posicion 3D donde se toco
        local touchPos = input.Position
        local targetPos = getTouchWorldPosition(touchPos)
        throwBall(targetPos)
        task.delay(0.5, function()
                touchDebounce = false
        end)
end)

-- Para PC: el click del mouse ya funciona con el handler de InputBegan existente
-- Para movil: TouchTap cubre todos los toques en pantalla

-- ============================================
-- BOTONES DE INTERACCION PARA MOVIL (solo movil)
-- Aparecen semitransparentes con borde negro cuando hay algo con que interactuar
-- Boton 1: 👆 colocar/recoger (cerca del pedestal)
-- Boton 2: ⬆️ mejorar personaje (cerca del boton de mejora)
-- ============================================

-- Solo crear botones si es dispositivo movil (tacto)
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- ============================================
-- CONFIGURACION DE CAMARA PARA MOVIL
-- Bloquear el pinch-to-zoom que se queda activado y bloquea el giro de camara
-- ============================================
if isMobile then
        local camera = workspace.CurrentCamera

        -- Forzar el modo de camara Classic
        player.CameraMode = Enum.CameraMode.Classic

        -- Restaurar distancias normales de camara (no forzar 0.5)
        player.CameraMinZoomDistance = 0.5
        player.CameraMaxZoomDistance = 128

        -- INTERCEPTAR el pinch: cuando se detecta 2 dedos (pinch), 
        -- simular que NO hay pinch reseteando el FOV inmediatamente
        -- y forzando la distancia de camara a su valor actual
        local lastZoom = 12.5 -- distancia normal de camara

        UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state)
                if state == Enum.UserInputState.Begin then
                        -- Guardar la distancia actual de la camara
                        local playerZoom = (player.CameraMaxZoomDistance + player.CameraMinZoomDistance) / 2
                        lastZoom = playerZoom
                end
                if state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change then
                        -- Resetear FOV inmediatamente
                        if camera then
                                camera.FieldOfView = 70
                        end
                end
                if state == Enum.UserInputState.End then
                        -- Al terminar el pinch, restaurar la distancia de camara
                        player.CameraMinZoomDistance = 0.5
                        player.CameraMaxZoomDistance = 128
                        if camera then
                                camera.FieldOfView = 70
                        end
                end
        end)

        -- Monitoreo continuo: si el FOV cambia por pinch, resetearlo
        task.spawn(function()
                while true do
                        task.wait(0.05)
                        if camera and camera.FieldOfView ~= 70 then
                                camera.FieldOfView = 70
                        end
                end
        end)
end

-- Funcion helper para crear un boton de interaccion con estilo: solo borde negro, sin relleno
-- Soporta texto (emoji) o imagen (rbxassetid://)
local function createMobileButton(name, icon, size)
        size = size or 60 -- tamaño por defecto 60x60
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, size, 0, size)
        btn.Position = UDim2.new(0.5, -size/2, 0.7, 0)
        btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        btn.BackgroundTransparency = 0.85 -- casi transparente
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.Visible = false
        btn.ZIndex = 100
        btn.Parent = screenGui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

        -- Borde negro bien marcado
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 3
        stroke.Transparency = 0.1
        stroke.Parent = btn

        -- Si es imagen, crear ImageLabel; si es texto, crear TextLabel
        if string.sub(icon, 1, 13) == "rbxassetid://" then
                local img = Instance.new("ImageLabel")
                img.Size = UDim2.new(0.7, 0, 0.7, 0)
                img.Position = UDim2.new(0.15, 0, 0.15, 0)
                img.BackgroundTransparency = 1
                img.Image = icon
                img.ScaleType = Enum.ScaleType.Fit
                img.ZIndex = 101
                img.Parent = btn
        else
                btn.Text = icon
                btn.TextColor3 = Color3.fromRGB(0, 0, 0)
                btn.TextTransparency = 0
                btn.TextScaled = true
                btn.Font = Enum.Font.GothamBlack
        end

        return btn
end

-- Boton de interaccion principal (colocar/recoger/cofre/fusion)
local interactBtn = nil
-- Boton de mejora de personaje (F)
local upgradeMobBtn = nil
-- Boton de mejora de base (H)
local baseUpgradeMobBtn = nil

if isMobile then
        interactBtn = createMobileButton("MobInteractBtn", "rbxassetid://18985225104", 120) -- doble tamaño
        upgradeMobBtn = createMobileButton("MobUpgradeBtn", "rbxassetid://90725732857650", 120) -- doble tamaño
        baseUpgradeMobBtn = createMobileButton("MobBaseUpgradeBtn", "rbxassetid://90725732857650") -- misma imagen que mejorar personaje, tamaño normal
end

local interactDebounce = false
local upgradeMobDebounce = false
local baseUpgradeMobDebounce = false

-- Accion del boton de interaccion (mismo que presionar E)
if interactBtn then
        interactBtn.MouseButton1Click:Connect(function()
                if interactDebounce then return end
                interactDebounce = true
                if isCarrying then
                        -- Colocar personaje en pedestal o depositar en fusion
                        if nearFusionMachine and DepositCharacterEvent then
                                DepositCharacterEvent:FireServer()
                        elseif PlaceCharacterEvent then
                                PlaceCharacterEvent:FireServer()
                        end
                else
                        -- Recoger (cofre, pedestal, o suelo)
                        if PickupChestEvent then PickupChestEvent:FireServer() end
                        task.wait(0.15)
                        if not isCarrying then
                                if RemoveFromPedestalEvent then RemoveFromPedestalEvent:FireServer() end
                        end
                        task.wait(0.15)
                        if not isCarrying then
                                if PickupDroppedEvent then PickupDroppedEvent:FireServer() end
                        end
                end
                task.wait(0.5)
                interactDebounce = false
        end)
end

-- Accion del boton de mejorar personaje (mismo que presionar F)
if upgradeMobBtn then
        upgradeMobBtn.MouseButton1Click:Connect(function()
                if upgradeMobDebounce then return end
                upgradeMobDebounce = true
                if UpgradeCharacterEvent then
                        UpgradeCharacterEvent:FireServer()
                end
                task.wait(0.5)
                upgradeMobDebounce = false
        end)
end

-- Accion del boton de mejorar base (mismo que presionar H)
if baseUpgradeMobBtn then
        baseUpgradeMobBtn.MouseButton1Click:Connect(function()
                if baseUpgradeMobDebounce then return end
                baseUpgradeMobDebounce = true
                if UpgradeBaseEvent then
                        UpgradeBaseEvent:FireServer()
                end
                task.wait(0.5)
                baseUpgradeMobDebounce = false
        end)
end

-- ============================================
-- DETECCION DE PROXIMIDAD para mostrar los botones en movil
-- Posiciona los botones cerca del objeto 3D usando WorldToViewportPoint
-- ============================================
if isMobile then
        task.spawn(function()
                while true do
                        task.wait(0.2)
                        local char = player.Character
                        if not char then
                                if interactBtn then interactBtn.Visible = false end
                                if upgradeMobBtn then upgradeMobBtn.Visible = false end
                                if baseUpgradeMobBtn then baseUpgradeMobBtn.Visible = false end
                                continue
                        end
                        local root = char:FindFirstChild("HumanoidRootPart")
                        if not root then
                                if interactBtn then interactBtn.Visible = false end
                                if upgradeMobBtn then upgradeMobBtn.Visible = false end
                                if baseUpgradeMobBtn then baseUpgradeMobBtn.Visible = false end
                                continue
                        end

                        local playerPos = root.Position
                        local camera = workspace.CurrentCamera
                        local showInteract = false
                        local showUpgrade = false
                        local showBaseUpgrade = false
                        local interactScreenPos = nil
                        local upgradeScreenPos = nil
                        local baseUpgradeScreenPos = nil

                        -- 1. Verificar cofres cerca (solo si no esta cargando)
                        if not isCarrying then
                                for _, obj in ipairs(workspace:GetChildren()) do
                                        if obj.Name == "Chest" then
                                                local owner = obj:FindFirstChild("Owner")
                                                if owner and owner.Value == player then
                                                        local d = (obj.Position - playerPos).Magnitude
                                                        if d < 15 then
                                                                showInteract = true
                                                                interactScreenPos = camera:WorldToViewportPoint(obj.Position)
                                                                break
                                                        end
                                                end
                                        end
                                end
                        end

                        -- 2. Verificar personajes soltados cerca (DropTimer)
                        if not showInteract and not isCarrying then
                                for _, obj in ipairs(workspace:GetChildren()) do
                                        if obj.Name == "DropTimer" then
                                                local owner = obj:FindFirstChild("Owner")
                                                if owner and owner.Value == player then
                                                        local d = (obj.Position - playerPos).Magnitude
                                                        if d < 15 then
                                                                showInteract = true
                                                                interactScreenPos = camera:WorldToViewportPoint(obj.Position)
                                                                break
                                                        end
                                                end
                                        end
                                end
                        end

                        -- 3. Verificar pedestales (colocar/recoger + mejorar)
                        if not showInteract or not showUpgrade then
                                local map = workspace:FindFirstChild("Map")
                                if map then
                                        local bases = map:FindFirstChild("Bases")
                                        if bases then
                                                for _, base in ipairs(bases:GetChildren()) do
                                                        if showInteract and showUpgrade then break end
                                                        -- Buscar en todos los pisos
                                                        local allPeds = {}
                                                        local p1 = base:FindFirstChild("Pedestals")
                                                        if p1 then table.insert(allPeds, p1) end
                                                        for floorNum = 2, 5 do
                                                                local floor = base:FindFirstChild("Floor" .. floorNum)
                                                                if floor then
                                                                        local peds = floor:FindFirstChild("Pedestals" .. floorNum)
                                                                        if peds then table.insert(allPeds, peds) end
                                                                end
                                                        end

                                                        for _, pedFolder in ipairs(allPeds) do
                                                                if showInteract and showUpgrade then break end
                                                                for _, ped in ipairs(pedFolder:GetChildren()) do
                                                                        local platform = ped:FindFirstChild("Platform")
                                                                        if platform then
                                                                                local d = (platform.Position - playerPos).Magnitude
                                                                                if d < 14 then
                                                                                        -- Boton de interaccion (colocar/recoger)
                                                                                        if not showInteract then
                                                                                                if isCarrying then
                                                                                                        -- Verificar pedestal vacio
                                                                                                        local hasModel = false
                                                                                                        for _, child in ipairs(ped:GetChildren()) do
                                                                                                                if child:IsA("Model") then hasModel = true break end
                                                                                                        end
                                                                                                        if not hasModel then
                                                                                                                showInteract = true
                                                                                                                interactScreenPos = camera:WorldToViewportPoint(platform.Position)
                                                                                                        end
                                                                                                else
                                                                                                        -- Verificar pedestal con personaje
                                                                                                        local hasModel = false
                                                                                                        for _, child in ipairs(ped:GetChildren()) do
                                                                                                                if child:IsA("Model") then hasModel = true break end
                                                                                                        end
                                                                                                        if hasModel then
                                                                                                                showInteract = true
                                                                                                                interactScreenPos = camera:WorldToViewportPoint(platform.Position)
                                                                                                        end
                                                                                                end
                                                                                        end

                                                                                        -- Boton de mejora (cerca del UpgradeButton)
                                                                                        if not showUpgrade and not isCarrying then
                                                                                                local upgradeBtn3D = ped:FindFirstChild("UpgradeButton")
                                                                                                if upgradeBtn3D then
                                                                                                        local ud = (upgradeBtn3D.Position - playerPos).Magnitude
                                                                                                        if ud < 10 then
                                                                                                                showUpgrade = true
                                                                                                                upgradeScreenPos = camera:WorldToViewportPoint(upgradeBtn3D.Position)
                                                                                                        end
                                                                                                end
                                                                                        end
                                                                                end
                                                                        end
                                                                end
                                                        end
                                                end
                                        end
                                end
                        end

                        -- 4. Verificar maquina de fusion (siempre que este cerca, cargando o no)
                        if not showInteract then
                                local FUSION_MACHINE_CENTER = Vector3.new(-142.3, 10.8, 11.0)
                                local dist = (playerPos - FUSION_MACHINE_CENTER).Magnitude
                                if dist < 20 then
                                        -- Solo mostrar el boton de interaccion si esta cargando (para depositar)
                                        -- Si no esta cargando, el panel de fusion ya muestra la info
                                        if isCarrying then
                                                showInteract = true
                                                interactScreenPos = camera:WorldToViewportPoint(FUSION_MACHINE_CENTER)
                                        end
                                end
                        end

                        -- 5. Verificar boton de mejora de base (BaseUpgradeButton)
                        if not showBaseUpgrade then
                                local map = workspace:FindFirstChild("Map")
                                if map then
                                        local bases = map:FindFirstChild("Bases")
                                        if bases then
                                                for _, base in ipairs(bases:GetChildren()) do
                                                        if showBaseUpgrade then break end
                                                        local baseUpgradeBtn3D = base:FindFirstChild("BaseUpgradeButton")
                                                        if baseUpgradeBtn3D then
                                                                local d = (baseUpgradeBtn3D.Position - playerPos).Magnitude
                                                                if d < 12 then
                                                                        showBaseUpgrade = true
                                                                        baseUpgradeScreenPos = camera:WorldToViewportPoint(baseUpgradeBtn3D.Position)
                                                                end
                                                        end
                                                end
                                        end
                                end
                        end

                        -- Actualizar visibilidad y posicion de los botones
                        if interactBtn then
                                if showInteract and interactScreenPos and interactScreenPos.Z > 0 then
                                        interactBtn.Visible = true
                                        interactBtn.Position = UDim2.new(0, interactScreenPos.X - 60, 0, interactScreenPos.Y - 60) -- centrado para 120x120
                                else
                                        interactBtn.Visible = false
                                end
                        end

                        if upgradeMobBtn then
                                if showUpgrade and upgradeScreenPos and upgradeScreenPos.Z > 0 then
                                        upgradeMobBtn.Visible = true
                                        upgradeMobBtn.Position = UDim2.new(0, upgradeScreenPos.X - 60, 0, upgradeScreenPos.Y - 60) -- centrado para 120x120
                                else
                                        upgradeMobBtn.Visible = false
                                end
                        end

                        if baseUpgradeMobBtn then
                                if showBaseUpgrade and baseUpgradeScreenPos and baseUpgradeScreenPos.Z > 0 then
                                        baseUpgradeMobBtn.Visible = true
                                        baseUpgradeMobBtn.Position = UDim2.new(0, baseUpgradeScreenPos.X - 30, 0, baseUpgradeScreenPos.Y - 30)
                                else
                                        baseUpgradeMobBtn.Visible = false
                                end
                        end
                end
        end)
end

placeBtn.MouseButton1Click:Connect(function()
        if isCarrying and PlaceCharacterEvent then PlaceCharacterEvent:FireServer() end
end)

dropBtn.MouseButton1Click:Connect(function()
        if isCarrying and DropCharacterEvent then DropCharacterEvent:FireServer() end
end)

player.CharacterAdded:Connect(function()
        ballEquipped = false
        inputDebounce = false
        throwDebounce = false
        isCarrying = false
        activeBalls = 0
        cachedTrack = nil
        updateButton()
        updateUI()
end)

MoneyUpdateEvent.OnClientEvent:Connect(function(amount)
        moneyLabel.Text = formatMoneyClient(amount)
end)

-- ============================================
-- ANIMACION DE APERTURA DE COFRE
-- Aparece un cuadro con signo de interrogacion que gira
-- Al final revela el personaje ganado
-- ============================================
local TweenService = game:GetService("TweenService")
local isChestAnimating = false

ChestOpenEvent.OnClientEvent:Connect(function(rarityName, rarityColor, charName)
        if isChestAnimating then return end
        isChestAnimating = true

        -- Fondo oscuro que cubre toda la pantalla
        local backdrop = Instance.new("Frame")
        backdrop.Name = "ChestBackdrop"
        backdrop.Size = UDim2.new(1, 0, 1, 0)
        backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        backdrop.BackgroundTransparency = 0.5
        backdrop.BorderSizePixel = 0
        backdrop.ZIndex = 100
        backdrop.Parent = screenGui

        -- Contenedor central
        local container = Instance.new("Frame")
        container.Name = "ChestContainer"
        container.Size = UDim2.new(0, 300, 0, 400)
        container.Position = UDim2.new(0.5, -150, 0.5, -200)
        container.BackgroundTransparency = 1
        container.ZIndex = 101
        container.Parent = backdrop

        -- Cuadro del cofre (gira)
        local box = Instance.new("Frame")
        box.Name = "ChestBox"
        box.Size = UDim2.new(0, 200, 0, 200)
        box.Position = UDim2.new(0.5, -100, 0, 50)
        box.BackgroundColor3 = rarityColor
        box.BorderSizePixel = 0
        box.ZIndex = 102
        box.Parent = container
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 20)

        -- Borde brillante
        local boxStroke = Instance.new("UIStroke")
        boxStroke.Color = Color3.fromRGB(255, 255, 255)
        boxStroke.Thickness = 4
        boxStroke.Transparency = 0.2
        boxStroke.Parent = box

        -- Signo de interrogacion
        local questionMark = Instance.new("TextLabel")
        questionMark.Name = "QuestionMark"
        questionMark.Size = UDim2.new(1, 0, 1, 0)
        questionMark.BackgroundTransparency = 1
        questionMark.Text = "?"
        questionMark.TextColor3 = Color3.fromRGB(255, 255, 255)
        questionMark.TextScaled = true
        questionMark.Font = Enum.Font.GothamBlack
        questionMark.ZIndex = 103
        questionMark.Parent = box

        -- Texto superior "ABRIENDO COFRE"
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.Size = UDim2.new(1, 0, 0, 40)
        titleLabel.Position = UDim2.new(0, 0, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "ABRIENDO COFRE..."
        titleLabel.TextColor3 = rarityColor
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.ZIndex = 102
        titleLabel.Parent = container

        -- Texto de rareza (debajo del cuadro)
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Name = "RarityLabel"
        rarityLabel.Size = UDim2.new(1, 0, 0, 35)
        rarityLabel.Position = UDim2.new(0, 0, 0, 270)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = rarityName
        rarityLabel.TextColor3 = rarityColor
        rarityLabel.TextScaled = true
        rarityLabel.Font = Enum.Font.GothamBold
        rarityLabel.ZIndex = 102
        rarityLabel.Parent = container

        -- Texto del personaje ganado (oculto al inicio)
        local resultLabel = Instance.new("TextLabel")
        resultLabel.Name = "ResultLabel"
        resultLabel.Size = UDim2.new(1, 0, 0, 40)
        resultLabel.Position = UDim2.new(0, 0, 0, 320)
        resultLabel.BackgroundTransparency = 1
        resultLabel.Text = ""
        resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        resultLabel.TextScaled = true
        resultLabel.Font = Enum.Font.GothamBold
        resultLabel.ZIndex = 102
        resultLabel.Parent = container

        -- Animacion: girar el cuadro por 6 segundos
        -- Velocidad variable: empieza lento, acelera, frena al final
        local totalDuration = 6.5
        local startTime = tick()

        -- Tween de rotacion continua (gira multiples veces)
        local rotationTween = TweenService:Create(
                box,
                TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0),
                {Rotation = 360}
        )
        rotationTween:Play()

        -- Efecto de pulso (escala)
        local pulseTween = TweenService:Create(
                box,
                TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0),
                {Size = UDim2.new(0, 220, 0, 220)}
        )
        pulseTween:Play()

        -- Esperar casi hasta el final (5.5s) para mostrar el resultado
        task.delay(5.5, function()
                if not box or not box.Parent then return end
                -- Detener animaciones
                rotationTween:Cancel()
                pulseTween:Cancel()

                -- Resetear rotacion y tamano
                box.Rotation = 0
                box.Size = UDim2.new(0, 200, 0, 200)

                -- Cambiar el signo de interrogacion por una estrella/check
                questionMark.Text = "★"
                questionMark.TextColor3 = Color3.fromRGB(255, 215, 0)

                -- Efecto de aparicion del resultado
                titleLabel.Text = "¡FELICIDADES!"
                titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                resultLabel.Text = charName

                -- Flash de brillo
                local flashTween = TweenService:Create(
                        box,
                        TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
                        {BackgroundColor3 = Color3.fromRGB(255, 215, 0)}
                )
                flashTween:Play()

                -- Expandir el resultado
                resultLabel.TextTransparency = 1
                local revealTween = TweenService:Create(
                        resultLabel,
                        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {TextTransparency = 0}
                )
                revealTween:Play()
        end)

        -- Al final (6.5s) eliminar todo
        task.delay(totalDuration, function()
                if backdrop and backdrop.Parent then
                        local fadeOut = TweenService:Create(
                                backdrop,
                                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                {BackgroundTransparency = 1}
                        )
                        fadeOut:Play()
                        fadeOut.Completed:Wait()
                        backdrop:Destroy()
                end
                isChestAnimating = false
        end)
end)

-- ============================================
-- SISTEMA DE FUSION - UI
-- Aparece cuando el jugador esta cerca de la maquina de fusion
-- ============================================
local fusionPanel = Instance.new("Frame")
fusionPanel.Name = "FusionPanel"
fusionPanel.Size = UDim2.new(0, 640, 0, 400)
fusionPanel.Position = UDim2.new(0.5, -320, 0.5, -200)
fusionPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
fusionPanel.BackgroundTransparency = 0.1
fusionPanel.BorderSizePixel = 0
fusionPanel.Visible = false
fusionPanel.ZIndex = 50
fusionPanel.Parent = screenGui
Instance.new("UICorner", fusionPanel).CornerRadius = UDim.new(0, 16)

local fusionStroke = Instance.new("UIStroke")
fusionStroke.Color = Color3.fromRGB(255, 215, 0)
fusionStroke.Thickness = 3
fusionStroke.Transparency = 0.2
fusionStroke.Parent = fusionPanel

-- Titulo
local fusionTitle = Instance.new("TextLabel")
fusionTitle.Size = UDim2.new(1, 0, 0, 40)
fusionTitle.BackgroundTransparency = 1
fusionTitle.Text = "MAQUINA DE FUSION"
fusionTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
fusionTitle.TextScaled = true
fusionTitle.Font = Enum.Font.GothamBlack
fusionTitle.ZIndex = 51
fusionTitle.Parent = fusionPanel

-- Slot A (clickeable para quitar personaje)
local slotABg = Instance.new("TextButton")
slotABg.Size = UDim2.new(0, 140, 0, 160)
slotABg.Position = UDim2.new(0, 20, 0, 50)
slotABg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
slotABg.BorderSizePixel = 0
slotABg.Text = ""
slotABg.ZIndex = 51
slotABg.Parent = fusionPanel
Instance.new("UICorner", slotABg).CornerRadius = UDim.new(0, 10)

local slotAStroke = Instance.new("UIStroke")
slotAStroke.Color = Color3.fromRGB(100, 200, 255)
slotAStroke.Thickness = 2
slotAStroke.Parent = slotABg

local slotATitle = Instance.new("TextLabel")
slotATitle.Size = UDim2.new(1, 0, 0, 25)
slotATitle.BackgroundTransparency = 1
slotATitle.Text = "BLOCK A"
slotATitle.TextColor3 = Color3.fromRGB(100, 200, 255)
slotATitle.TextScaled = true
slotATitle.Font = Enum.Font.GothamBold
slotATitle.ZIndex = 52
slotATitle.Parent = slotABg

local slotAContent = Instance.new("TextLabel")
slotAContent.Size = UDim2.new(1, 0, 1, -25)
slotAContent.Position = UDim2.new(0, 0, 0, 25)
slotAContent.BackgroundTransparency = 1
slotAContent.Text = "Vacio"
slotAContent.TextColor3 = Color3.fromRGB(120, 120, 120)
slotAContent.TextScaled = true
slotAContent.Font = Enum.Font.GothamBold
slotAContent.ZIndex = 52
slotAContent.Parent = slotABg

-- Slot B (clickeable para quitar personaje)
local slotBBg = Instance.new("TextButton")
slotBBg.Size = UDim2.new(0, 140, 0, 160)
slotBBg.Position = UDim2.new(0, 180, 0, 50)
slotBBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
slotBBg.BorderSizePixel = 0
slotBBg.Text = ""
slotBBg.ZIndex = 51
slotBBg.Parent = fusionPanel
Instance.new("UICorner", slotBBg).CornerRadius = UDim.new(0, 10)

local slotBStroke = Instance.new("UIStroke")
slotBStroke.Color = Color3.fromRGB(255, 150, 50)
slotBStroke.Thickness = 2
slotBStroke.Parent = slotBBg

local slotBTitle = Instance.new("TextLabel")
slotBTitle.Size = UDim2.new(1, 0, 0, 25)
slotBTitle.BackgroundTransparency = 1
slotBTitle.Text = "BLOCK B"
slotBTitle.TextColor3 = Color3.fromRGB(255, 150, 50)
slotBTitle.TextScaled = true
slotBTitle.Font = Enum.Font.GothamBold
slotBTitle.ZIndex = 52
slotBTitle.Parent = slotBBg

local slotBContent = Instance.new("TextLabel")
slotBContent.Size = UDim2.new(1, 0, 1, -25)
slotBContent.Position = UDim2.new(0, 0, 0, 25)
slotBContent.BackgroundTransparency = 1
slotBContent.Text = "Vacio"
slotBContent.TextColor3 = Color3.fromRGB(120, 120, 120)
slotBContent.TextScaled = true
slotBContent.Font = Enum.Font.GothamBold
slotBContent.ZIndex = 52
slotBContent.Parent = slotBBg

-- Output slot
local outputBg = Instance.new("Frame")
outputBg.Size = UDim2.new(0, 140, 0, 160)
outputBg.Position = UDim2.new(0, 340, 0, 50)
outputBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
outputBg.BorderSizePixel = 0
outputBg.ZIndex = 51
outputBg.Parent = fusionPanel
Instance.new("UICorner", outputBg).CornerRadius = UDim.new(0, 10)

local outputStroke = Instance.new("UIStroke")
outputStroke.Color = Color3.fromRGB(255, 215, 0)
outputStroke.Thickness = 2
outputStroke.Parent = outputBg

local outputTitle = Instance.new("TextLabel")
outputTitle.Size = UDim2.new(1, 0, 0, 25)
outputTitle.BackgroundTransparency = 1
outputTitle.Text = "RESULTADO"
outputTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
outputTitle.TextScaled = true
outputTitle.Font = Enum.Font.GothamBold
outputTitle.ZIndex = 52
outputTitle.Parent = outputBg

local outputContent = Instance.new("TextLabel")
outputContent.Size = UDim2.new(1, 0, 1, -25)
outputContent.Position = UDim2.new(0, 0, 0, 25)
outputContent.BackgroundTransparency = 1
outputContent.Text = "Esperando..."
outputContent.TextColor3 = Color3.fromRGB(120, 120, 120)
outputContent.TextScaled = true
outputContent.Font = Enum.Font.GothamBold
outputContent.ZIndex = 52
outputContent.Parent = outputBg

-- Boton FUSIONAR (a la derecha de los slots)
local fuseBtn = Instance.new("TextButton")
fuseBtn.Size = UDim2.new(0, 100, 0, 160)
fuseBtn.Position = UDim2.new(0, 500, 0, 50)
fuseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
fuseBtn.BorderSizePixel = 0
fuseBtn.Text = "FUSIONAR"
fuseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
fuseBtn.TextScaled = true
fuseBtn.Font = Enum.Font.GothamBlack
fuseBtn.ZIndex = 51
fuseBtn.Active = false
fuseBtn.Parent = fusionPanel
Instance.new("UICorner", fuseBtn).CornerRadius = UDim.new(0, 10)

-- Boton cerrar
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 51
closeBtn.Parent = fusionPanel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Colores de rareza para el UI
local rarityColorsClient = {
        Morado = Color3.fromRGB(170, 85, 255),
        Rojo = Color3.fromRGB(255, 80, 80),
        Amarillo = Color3.fromRGB(255, 255, 100),
        Azul = Color3.fromRGB(85, 170, 255),
        Blanco = Color3.fromRGB(220, 220, 220)
}

local rarityDisplayClient = {
        Morado = "MITICO", Rojo = "EPICO", Amarillo = "RARO",
        Azul = "INCOMUN", Blanco = "COMUN"
}

-- Texto de ayuda (instrucciones) - abajo de los slots
local helpLabel = Instance.new("TextLabel")
helpLabel.Size = UDim2.new(1, 0, 0, 50)
helpLabel.Position = UDim2.new(0, 0, 0, 225)
helpLabel.BackgroundTransparency = 1
helpLabel.Text = "Lleva un personaje en la mano y presiona E para depositarlo\nClick izquierdo en un slot para quitarlo"
helpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
helpLabel.TextScaled = true
helpLabel.Font = Enum.Font.GothamBold
helpLabel.ZIndex = 51
helpLabel.Parent = fusionPanel

-- Estado actual de la mano (lo que lleva el jugador)
local carryingLabel = Instance.new("TextLabel")
carryingLabel.Size = UDim2.new(1, 0, 0, 30)
carryingLabel.Position = UDim2.new(0, 0, 0, 285)
carryingLabel.BackgroundTransparency = 1
carryingLabel.Text = "En mano: nada"
carryingLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
carryingLabel.TextScaled = true
carryingLabel.Font = Enum.Font.GothamBold
carryingLabel.ZIndex = 51
carryingLabel.Parent = fusionPanel

-- Boton DEPOSITAR (E)
local depositHint = Instance.new("TextLabel")
depositHint.Size = UDim2.new(1, 0, 0, 25)
depositHint.Position = UDim2.new(0, 0, 0, 320)
depositHint.BackgroundTransparency = 1
depositHint.Text = "Presiona E para depositar"
depositHint.TextColor3 = Color3.fromRGB(100, 200, 255)
depositHint.TextScaled = true
depositHint.Font = Enum.Font.GothamBold
depositHint.ZIndex = 51
depositHint.Parent = fusionPanel

-- Actualizar el UI de fusion con el nuevo formato
local function updateFusionUI(state)
        fusionSlotA = state.slotA
        fusionSlotB = state.slotB
        fusionCarrying = state.carrying

        -- Actualizar Slot A
        if state.slotA then
                local name = state.slotA.name
                if state.slotA.fusionLevel > 0 then
                        name = name .. " Fusion"
                end
                slotAContent.Text = name .. "\nLv." .. state.slotA.level
                slotAContent.TextColor3 = rarityColorsClient[state.slotA.rarity] or Color3.fromRGB(255, 255, 255)
        else
                slotAContent.Text = "Vacio"
                slotAContent.TextColor3 = Color3.fromRGB(120, 120, 120)
        end

        -- Actualizar Slot B
        if state.slotB then
                local name = state.slotB.name
                if state.slotB.fusionLevel > 0 then
                        name = name .. " Fusion"
                end
                slotBContent.Text = name .. "\nLv." .. state.slotB.level
                slotBContent.TextColor3 = rarityColorsClient[state.slotB.rarity] or Color3.fromRGB(255, 255, 255)
        else
                slotBContent.Text = "Vacio"
                slotBContent.TextColor3 = Color3.fromRGB(120, 120, 120)
        end

        -- Actualizar "En mano"
        if state.carrying then
                local name = state.carrying.name
                if state.carrying.fusionLevel > 0 then
                        name = name .. " Fusion"
                end
                carryingLabel.Text = "En mano: " .. name .. " Lv." .. state.carrying.level
                carryingLabel.TextColor3 = rarityColorsClient[state.carrying.rarity] or Color3.fromRGB(255, 255, 255)
        else
                carryingLabel.Text = "En mano: nada"
                carryingLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end

        -- Verificar si se puede fusionar
        local canFuse = false
        if state.slotA and state.slotB then
                if state.slotA.name == state.slotB.name
                        and state.slotA.rarity == state.slotB.rarity
                        and state.slotA.fusionLevel == state.slotB.fusionLevel then
                        canFuse = true
                        local mult = math.pow(3, state.slotA.fusionLevel + 1)
                        local fusedName = state.slotA.name
                        if state.slotA.fusionLevel == 0 then
                                fusedName = state.slotA.name .. " Fusion"
                        else
                                fusedName = state.slotA.name .. " Fusion+"
                        end
                        outputContent.Text = fusedName .. "\nx" .. mult .. " produccion"
                        outputContent.TextColor3 = Color3.fromRGB(255, 215, 0)
                else
                        outputContent.Text = "No compatible"
                        outputContent.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
        else
                outputContent.Text = "Esperando..."
                outputContent.TextColor3 = Color3.fromRGB(120, 120, 120)
        end

        -- Actualizar boton
        if canFuse then
                fuseBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
                fuseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                fuseBtn.Active = true
        else
                fuseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                fuseBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
                fuseBtn.Active = false
        end
end

-- Recibir actualizaciones del servidor
FusionUIUpdateEvent.OnClientEvent:Connect(function(state)
        nearFusionMachine = true
        fusionPanel.Visible = true
        updateFusionUI(state)
end)

-- Loop para ocultar el panel si el jugador se aleja de la maquina
task.spawn(function()
        local FUSION_MACHINE_CENTER = Vector3.new(-142.3, 10.8, 11.0)
        local FUSION_PROXIMITY = 20
        while true do
                task.wait(0.5)
                local char = player.Character
                if char then
                        local root = char:FindFirstChild("HumanoidRootPart")
                        if root then
                                local dist = (root.Position - FUSION_MACHINE_CENTER).Magnitude
                                if dist > FUSION_PROXIMITY then
                                        -- Se alejo: ocultar panel
                                        nearFusionMachine = false
                                        fusionPanel.Visible = false
                                end
                        end
                end
        end
end)

-- Boton FUSIONAR (sin argumentos, el servidor usa los slots almacenados)
fuseBtn.MouseButton1Click:Connect(function()
        if not fuseBtn.Active then return end
        if FuseCharactersEvent then
                FuseCharactersEvent:FireServer()
        end
end)

-- Click en Slot A para quitar personaje
slotABg.MouseButton1Click:Connect(function()
        if fusionSlotA and RemoveFromFusionSlotEvent then
                RemoveFromFusionSlotEvent:FireServer("A")
        end
end)

-- Click en Slot B para quitar personaje
slotBBg.MouseButton1Click:Connect(function()
        if fusionSlotB and RemoveFromFusionSlotEvent then
                RemoveFromFusionSlotEvent:FireServer("B")
        end
end)

-- Boton cerrar (ocultar manualmente)
closeBtn.MouseButton1Click:Connect(function()
        fusionPanel.Visible = false
end)

-- ============================================
-- MOCHILA / INVENTARIO DE PELOTAS
-- ============================================
-- Boton de mochila (izquierda, abajo)
local backpackBtn = Instance.new("TextButton")
backpackBtn.Name = "BackpackBtn"
backpackBtn.Size = UDim2.new(0, 60, 0, 60)
backpackBtn.Position = UDim2.new(0, 20, 1, -200)
backpackBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
backpackBtn.BorderSizePixel = 0
backpackBtn.Text = ""
backpackBtn.Parent = screenGui
Instance.new("UICorner", backpackBtn).CornerRadius = UDim.new(0, 12)

-- Icono de mochila personalizado
local backpackIcon = Instance.new("ImageLabel")
backpackIcon.Name = "BackpackIcon"
backpackIcon.Size = UDim2.new(1.6, 0, 1.6, 0)
backpackIcon.Position = UDim2.new(-0.3, 0, -0.3, 0)
backpackIcon.BackgroundTransparency = 1
backpackIcon.Image = "rbxassetid://113160993563399"
backpackIcon.ScaleType = Enum.ScaleType.Fit
backpackIcon.Parent = backpackBtn

local backpackStroke = Instance.new("UIStroke")
backpackStroke.Color = Color3.fromRGB(255, 215, 0)
backpackStroke.Thickness = 2
backpackStroke.Transparency = 0.3
backpackStroke.Parent = backpackBtn

-- Panel de mochila (se abre/cierra) - centrado abajo, abre hacia arriba
local backpackPanel = Instance.new("Frame")
backpackPanel.Name = "BackpackPanel"
backpackPanel.Size = UDim2.new(0, 400, 0, 350)
-- Centrado horizontalmente (0.5 - mitad del ancho), abajo de la pantalla
backpackPanel.Position = UDim2.new(0.5, -200, 1, -370)
backpackPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
backpackPanel.BackgroundTransparency = 0.05
backpackPanel.BorderSizePixel = 0
backpackPanel.Visible = false
backpackPanel.ZIndex = 50
backpackPanel.Parent = screenGui
Instance.new("UICorner", backpackPanel).CornerRadius = UDim.new(0, 16)

-- Boton X para cerrar (esquina superior derecha del panel)
local bpCloseBtn = Instance.new("TextButton")
bpCloseBtn.Name = "BpCloseBtn"
bpCloseBtn.Size = UDim2.new(0, 30, 0, 30)
bpCloseBtn.Position = UDim2.new(1, -35, 0, 5)
bpCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
bpCloseBtn.BorderSizePixel = 0
bpCloseBtn.Text = "X"
bpCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bpCloseBtn.TextScaled = true
bpCloseBtn.Font = Enum.Font.GothamBold
bpCloseBtn.ZIndex = 52
bpCloseBtn.Parent = backpackPanel
Instance.new("UICorner", bpCloseBtn).CornerRadius = UDim.new(0, 8)

local bpStroke = Instance.new("UIStroke")
bpStroke.Color = Color3.fromRGB(255, 215, 0)
bpStroke.Thickness = 2
bpStroke.Transparency = 0.2
bpStroke.Parent = backpackPanel

-- Titulo
local bpTitle = Instance.new("TextLabel")
bpTitle.Size = UDim2.new(1, 0, 0, 35)
bpTitle.BackgroundTransparency = 1
bpTitle.Text = "PELOTAS"
bpTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
bpTitle.TextScaled = true
bpTitle.Font = Enum.Font.GothamBlack
bpTitle.ZIndex = 51
bpTitle.Parent = backpackPanel

-- Contenedor de pelotas (scrollable)
local bpScroll = Instance.new("ScrollingFrame")
bpScroll.Size = UDim2.new(1, -20, 1, -45)
bpScroll.Position = UDim2.new(0, 10, 0, 40)
bpScroll.BackgroundTransparency = 1
bpScroll.ScrollBarThickness = 6
bpScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
bpScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
bpScroll.ZIndex = 51
bpScroll.Parent = backpackPanel

local bpListLayout = Instance.new("UIListLayout")
bpListLayout.Padding = UDim.new(0, 8)
bpListLayout.Parent = bpScroll

-- Funcion para actualizar la mochila
local function updateBackpackUI()
        -- Limpiar lista anterior
        for _, child in ipairs(bpScroll:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
        end

        -- Crear card por cada pelota
        for ballKey, ballConfig in pairs(BALL_TYPES) do
                local card = Instance.new("Frame")
                card.Name = "Card_" .. ballKey
                card.Size = UDim2.new(1, -10, 0, 70)
                card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                card.BorderSizePixel = 0
                card.ZIndex = 52
                card.Parent = bpScroll
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

                -- Color del borde segun si esta seleccionada o no
                local cardStroke = Instance.new("UIStroke")
                if selectedBallType == ballKey then
                        cardStroke.Color = Color3.fromRGB(80, 220, 80) -- verde = seleccionada
                        cardStroke.Thickness = 3
                else
                        cardStroke.Color = ballConfig.color
                        cardStroke.Thickness = 2
                end
                cardStroke.Transparency = 0.2
                cardStroke.Parent = card

                -- Icono de la pelota (ImageLabel si tiene iconImage, sino TextLabel con emoji)
                if ballConfig.iconImage then
                        local iconImg = Instance.new("ImageLabel")
                        iconImg.Size = UDim2.new(0, 50, 1, -10)
                        iconImg.Position = UDim2.new(0, 5, 0, 5)
                        iconImg.BackgroundTransparency = 1
                        iconImg.Image = ballConfig.iconImage
                        iconImg.ScaleType = Enum.ScaleType.Fit
                        iconImg.ZIndex = 53
                        iconImg.Parent = card
                else
                        local iconLabel = Instance.new("TextLabel")
                        iconLabel.Size = UDim2.new(0, 50, 1, -10)
                        iconLabel.Position = UDim2.new(0, 5, 0, 5)
                        iconLabel.BackgroundTransparency = 1
                        iconLabel.Text = ballConfig.icon
                        iconLabel.TextScaled = true
                        iconLabel.ZIndex = 53
                        iconLabel.Parent = card
                end

                -- Info de la pelota
                local infoLabel = Instance.new("TextLabel")
                infoLabel.Size = UDim2.new(1, -120, 1, -10)
                infoLabel.Position = UDim2.new(0, 60, 0, 5)
                infoLabel.BackgroundTransparency = 1
                infoLabel.Text = ""
                infoLabel.RichText = true
                infoLabel.TextXAlignment = Enum.TextXAlignment.Left
                infoLabel.TextYAlignment = Enum.TextYAlignment.Center
                infoLabel.ZIndex = 53
                infoLabel.Parent = card

                -- Estado: desbloqueada o bloqueada
                if ballConfig.unlocked then
                        infoLabel.Text = '<font color="#FFFFFF">' .. ballConfig.name .. '</font>\n<font color="#81C784">Dano: ' .. ballConfig.damage .. '</font>  <font color="#B0BEC5">' .. ballConfig.description .. '</font>'
                else
                        infoLabel.Text = '<font color="#999999">' .. ballConfig.name .. '</font> 🔒\n<font color="#FFD700">$' .. ballConfig.cost .. '</font>  <font color="#666666">' .. ballConfig.description .. '</font>'
                end
                infoLabel.TextScaled = true
                infoLabel.Font = Enum.Font.GothamBold

                -- Boton para seleccionar / comprar
                local actionBtn = Instance.new("TextButton")
                actionBtn.Size = UDim2.new(0, 60, 0, 30)
                actionBtn.Position = UDim2.new(1, -65, 0.5, -15)
                actionBtn.BorderSizePixel = 0
                actionBtn.Text = ""
                actionBtn.ZIndex = 53
                actionBtn.Parent = card
                Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)

                if ballConfig.unlocked then
                        -- Ya desbloqueada: boton para seleccionar
                        if selectedBallType == ballKey then
                                actionBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
                                actionBtn.Text = "✓"
                                actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                        else
                                actionBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
                                actionBtn.Text = "Usar"
                                actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                        end
                        actionBtn.Font = Enum.Font.GothamBold
                        actionBtn.TextScaled = true

                        actionBtn.MouseButton1Click:Connect(function()
                                selectedBallType = ballKey
                                -- Si la pelota esta equipada, re-equipar con el nuevo tipo
                                if ballEquipped then
                                        reEquipBall()
                                end
                                -- Reproducir sonido de equipar al cambiar de pelota en la mochila
                                if ballConfig.soundEquip then
                                        playClientSound(ballConfig.soundEquip, 0.6)
                                end
                                updateBallIcon()
                                updateBackpackUI()
                        end)
                else
                        -- Bloqueada: boton para comprar
                        actionBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
                        actionBtn.Text = "Comprar"
                        actionBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                        actionBtn.Font = Enum.Font.GothamBold
                        actionBtn.TextScaled = true

                        actionBtn.MouseButton1Click:Connect(function()
                                -- Por ahora, desbloquear gratis para testear
                                -- En el futuro se validara el dinero del servidor
                                BALL_TYPES[ballKey].unlocked = true
                                selectedBallType = ballKey
                                if ballEquipped then
                                        reEquipBall()
                                end
                                -- Reproducir sonido de equipar al comprar/seleccionar
                                if ballConfig.soundEquip then
                                        playClientSound(ballConfig.soundEquip, 0.6)
                                end
                                updateBallIcon()
                                updateBackpackUI()
                                print("Pelota de " .. ballConfig.name .. " desbloqueada y seleccionada")
                        end)
                end
        end
end

-- Toggle mochila
backpackBtn.MouseButton1Click:Connect(function()
        backpackPanel.Visible = not backpackPanel.Visible
        if backpackPanel.Visible then
                updateBackpackUI()
        end
end)

-- Boton X para cerrar mochila (funciona con mouse y movil)
bpCloseBtn.MouseButton1Click:Connect(function()
        backpackPanel.Visible = false
end)

updateButton()
updateBallIcon()
updateUI()
print("BallThrower cargado!")

-- ============================================
-- SISTEMA DE MUSICA (boton + panel como la mochila)
-- ============================================
-- Lista de musicas disponibles. Para agregar mas en el futuro,
-- solo agregar una entrada a esta tabla: { name = "...", soundId = "rbxassetid://..." }
local MUSIC_LIST = {
        { name = "Naturaleza",          soundId = "rbxassetid://96749515704166" },
        { name = "Mystical Harp",       soundId = "rbxassetid://110289082772686" },
        { name = "Tibetanos",           soundId = "rbxassetid://94670025666551" },
        { name = "Relaxing Game Loop",  soundId = "rbxassetid://84498576072067" },
}

local MUSIC_ICON = "rbxassetid://980810848"

-- Estado de musica
local musicSound = Instance.new("Sound")
musicSound.Name = "BackgroundMusic"
musicSound.SoundId = MUSIC_LIST[1].soundId
musicSound.Looped = true
musicSound.Volume = 0.4
musicSound.Parent = game:GetService("SoundService")

local currentMusicIdx = 1
local musicMuted = false

-- Reproducir musica al entrar (con pequeno delay para asegurar carga)
task.delay(1, function()
        pcall(function()
                musicSound:Play()
        end)
end)

-- Boton de musica (arriba del boton de mochila)
local musicBtn = Instance.new("TextButton")
musicBtn.Name = "MusicBtn"
musicBtn.Size = UDim2.new(0, 60, 0, 60)
musicBtn.Position = UDim2.new(0, 20, 1, -270) -- 70px arriba del boton mochila (-200 - 70)
musicBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
musicBtn.BorderSizePixel = 0
musicBtn.Text = ""
musicBtn.Parent = screenGui
Instance.new("UICorner", musicBtn).CornerRadius = UDim.new(0, 12)

-- Icono de musica (ImageLabel como el de la mochila)
local musicIcon = Instance.new("ImageLabel")
musicIcon.Name = "MusicIcon"
musicIcon.Size = UDim2.new(0.8, 0, 0.8, 0)
musicIcon.Position = UDim2.new(0.1, 0, 0.1, 0)
musicIcon.BackgroundTransparency = 1
musicIcon.Image = MUSIC_ICON
musicIcon.ScaleType = Enum.ScaleType.Fit
musicIcon.Parent = musicBtn

local musicStroke = Instance.new("UIStroke")
musicStroke.Color = Color3.fromRGB(80, 180, 255) -- azul para diferenciar de la mochila
musicStroke.Thickness = 2
musicStroke.Transparency = 0.3
musicStroke.Parent = musicBtn

-- Indicador visual de muteado (X roja encima del icono cuando esta muteado)
local mutedIndicator = Instance.new("TextLabel")
mutedIndicator.Name = "MutedIndicator"
mutedIndicator.Size = UDim2.new(0.6, 0, 0.6, 0)
mutedIndicator.Position = UDim2.new(0.2, 0, 0.2, 0)
mutedIndicator.BackgroundTransparency = 1
mutedIndicator.Text = "X"
mutedIndicator.TextColor3 = Color3.fromRGB(255, 80, 80)
mutedIndicator.TextScaled = true
mutedIndicator.Font = Enum.Font.GothamBlack
mutedIndicator.Visible = false
mutedIndicator.ZIndex = 2
mutedIndicator.Parent = musicBtn

-- Panel de musica (mismo formato y posicion que la mochila)
local musicPanel = Instance.new("Frame")
musicPanel.Name = "MusicPanel"
musicPanel.Size = UDim2.new(0, 400, 0, 350)
musicPanel.Position = UDim2.new(0.5, -200, 1, -370) -- misma posicion que la mochila
musicPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
musicPanel.BackgroundTransparency = 0.05
musicPanel.BorderSizePixel = 0
musicPanel.Visible = false
musicPanel.ZIndex = 50
musicPanel.Parent = screenGui
Instance.new("UICorner", musicPanel).CornerRadius = UDim.new(0, 16)

-- Boton X para cerrar panel de musica
local mpCloseBtn = Instance.new("TextButton")
mpCloseBtn.Name = "MpCloseBtn"
mpCloseBtn.Size = UDim2.new(0, 30, 0, 30)
mpCloseBtn.Position = UDim2.new(1, -35, 0, 5)
mpCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
mpCloseBtn.BorderSizePixel = 0
mpCloseBtn.Text = "X"
mpCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mpCloseBtn.TextScaled = true
mpCloseBtn.Font = Enum.Font.GothamBold
mpCloseBtn.ZIndex = 52
mpCloseBtn.Parent = musicPanel
Instance.new("UICorner", mpCloseBtn).CornerRadius = UDim.new(0, 8)

local mpStroke = Instance.new("UIStroke")
mpStroke.Color = Color3.fromRGB(80, 180, 255)
mpStroke.Thickness = 2
mpStroke.Transparency = 0.2
mpStroke.Parent = musicPanel

-- Titulo del panel
local mpTitle = Instance.new("TextLabel")
mpTitle.Size = UDim2.new(1, 0, 0, 35)
mpTitle.BackgroundTransparency = 1
mpTitle.Text = "MUSICA"
mpTitle.TextColor3 = Color3.fromRGB(80, 180, 255)
mpTitle.TextScaled = true
mpTitle.Font = Enum.Font.GothamBlack
mpTitle.ZIndex = 51
mpTitle.Parent = musicPanel

-- Boton grande de MUTE/UNMUTE (arriba del scroll)
local muteBtn = Instance.new("TextButton")
muteBtn.Name = "MuteBtn"
muteBtn.Size = UDim2.new(1, -20, 0, 50)
muteBtn.Position = UDim2.new(0, 10, 0, 40)
muteBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
muteBtn.BorderSizePixel = 0
muteBtn.Text = "Silenciar"
muteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
muteBtn.TextScaled = true
muteBtn.Font = Enum.Font.GothamBold
muteBtn.ZIndex = 51
muteBtn.Parent = musicPanel
Instance.new("UICorner", muteBtn).CornerRadius = UDim.new(0, 10)

local muteStroke = Instance.new("UIStroke")
muteStroke.Color = Color3.fromRGB(255, 100, 100)
muteStroke.Thickness = 2
muteStroke.Transparency = 0.3
muteStroke.Parent = muteBtn

-- Contenedor de canciones (scrollable)
local mpScroll = Instance.new("ScrollingFrame")
mpScroll.Size = UDim2.new(1, -20, 1, -105)
mpScroll.Position = UDim2.new(0, 10, 0, 100)
mpScroll.BackgroundTransparency = 1
mpScroll.ScrollBarThickness = 6
mpScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mpScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mpScroll.ZIndex = 51
mpScroll.Parent = musicPanel

local mpListLayout = Instance.new("UIListLayout")
mpListLayout.Padding = UDim.new(0, 8)
mpListLayout.Parent = mpScroll

-- Funcion para actualizar el panel de musica
local function updateMusicUI()
        -- Limpiar lista anterior
        for _, child in ipairs(mpScroll:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
        end

        -- Crear card por cada cancion
        for idx, song in ipairs(MUSIC_LIST) do
                local card = Instance.new("Frame")
                card.Name = "SongCard_" .. idx
                card.Size = UDim2.new(1, -10, 0, 60)
                card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                card.BorderSizePixel = 0
                card.ZIndex = 52
                card.Parent = mpScroll
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

                -- Borde: verde si es la cancion actual, azul si no
                local cardStroke = Instance.new("UIStroke")
                if idx == currentMusicIdx then
                        cardStroke.Color = Color3.fromRGB(80, 220, 80) -- verde = sonando
                        cardStroke.Thickness = 3
                else
                        cardStroke.Color = Color3.fromRGB(80, 180, 255) -- azul
                        cardStroke.Thickness = 2
                end
                cardStroke.Transparency = 0.2
                cardStroke.Parent = card

                -- Nombre de la cancion
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(0.7, 0, 1, 0)
                nameLabel.Position = UDim2.new(0, 10, 0, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = song.name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextScaled = true
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.ZIndex = 53
                nameLabel.Parent = card

                -- Indicador "SONANDO" si es la actual
                if idx == currentMusicIdx then
                        local playingLabel = Instance.new("TextLabel")
                        playingLabel.Size = UDim2.new(0.3, -5, 0.5, 0)
                        playingLabel.Position = UDim2.new(0.7, 5, 0.25, 0)
                        playingLabel.BackgroundTransparency = 1
                        playingLabel.Text = "SONANDO"
                        playingLabel.TextColor3 = Color3.fromRGB(80, 220, 80)
                        playingLabel.TextScaled = true
                        playingLabel.Font = Enum.Font.GothamBold
                        playingLabel.ZIndex = 53
                        playingLabel.Parent = card
                else
                        -- Boton "Reproducir" si no es la actual
                        local playBtn = Instance.new("TextButton")
                        playBtn.Size = UDim2.new(0.3, -5, 0.6, 0)
                        playBtn.Position = UDim2.new(0.7, 5, 0.2, 0)
                        playBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
                        playBtn.BorderSizePixel = 0
                        playBtn.Text = ">"
                        playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                        playBtn.TextScaled = true
                        playBtn.Font = Enum.Font.GothamBold
                        playBtn.ZIndex = 53
                        playBtn.Parent = card
                        Instance.new("UICorner", playBtn).CornerRadius = UDim.new(0, 6)

                        playBtn.MouseButton1Click:Connect(function()
                                currentMusicIdx = idx
                                musicSound:Stop()
                                musicSound.SoundId = song.soundId
                                musicSound:Play()
                                -- Si estaba muteado, desmutear al cambiar de cancion
                                if musicMuted then
                                        musicMuted = false
                                        mutedIndicator.Visible = false
                                        muteBtn.Text = "Silenciar"
                                        muteBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                                end
                                updateMusicUI()
                        end)
                end
        end
end

-- Toggle panel de musica
musicBtn.MouseButton1Click:Connect(function()
        musicPanel.Visible = not musicPanel.Visible
        if musicPanel.Visible then
                -- Si se abre el panel de musica, cerrar la mochila para que no se solapen
                backpackPanel.Visible = false
                updateMusicUI()
        end
end)

-- Boton X para cerrar panel de musica
mpCloseBtn.MouseButton1Click:Connect(function()
        musicPanel.Visible = false
end)

-- Cuando se abre la mochila, cerrar panel de musica (no se solapen)
backpackBtn.MouseButton1Click:Connect(function()
        if backpackPanel.Visible then
                musicPanel.Visible = false
        end
end)

-- Accion del boton MUTE
muteBtn.MouseButton1Click:Connect(function()
        musicMuted = not musicMuted
        if musicMuted then
                musicSound:Pause()
                mutedIndicator.Visible = true
                muteBtn.Text = "Activar Sonido"
                muteBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        else
                musicSound:Resume()
                mutedIndicator.Visible = false
                muteBtn.Text = "Silenciar"
                muteBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        end
end)

print("Sistema de musica cargado!")

-- ============================================
-- SISTEMA DE CONSTRUCCION (modo build)
-- ============================================
-- Boton "Construir" + tecla B para activar modo construccion
-- Click izquierdo: coloca bloque seleccionado
-- Click derecho: quita bloque apuntado
-- Grid visual cuando el modo esta activo
-- Bloque fantasma (preview) sigue al mouse

-- Lista local de bloques (debe coincidir con BuildManager.lua del servidor)
local BLOCK_TYPES_BUILD = {
        { id = "madera",    name = "Madera",    color = Color3.fromRGB(160, 100, 50),  material = Enum.Material.Wood,        cost = 1 },
        { id = "tierra",    name = "Tierra",    color = Color3.fromRGB(130, 90, 60),   material = Enum.Material.Grass,      cost = 1 },
        { id = "piedra",    name = "Piedra",    color = Color3.fromRGB(130, 130, 130), material = Enum.Material.Slate,      cost = 2 },
        { id = "ladrillo",  name = "Ladrillo",  color = Color3.fromRGB(180, 80, 60),   material = Enum.Material.Brick,      cost = 5 },
        { id = "marmol",    name = "Marmol",    color = Color3.fromRGB(240, 240, 240), material = Enum.Material.Marble,     cost = 10 },
        { id = "oro",       name = "Oro",       color = Color3.fromRGB(255, 215, 0),   material = Enum.Material.Foil,       cost = 50 },
        { id = "diamante",  name = "Diamante",  color = Color3.fromRGB(135, 230, 255), material = Enum.Material.Glass,      cost = 100 },
        { id = "galaxia",   name = "Galaxia",   color = Color3.fromRGB(75, 0, 130),    material = Enum.Material.Neon,       cost = 500 },
}

local BLOCK_SIZE_BUILD = 4 -- debe coincidir con ParcelManager.BLOCK_SIZE
local PARCEL_HEIGHT_BUILD = 36 -- debe coincidir con ParcelManager.PARCEL_HEIGHT
local PARCEL_SIZE_X_BUILD = 36
local PARCEL_SIZE_Z_BUILD = 56

-- Estado del modo construccion
local buildMode = false
local selectedBlockIdx = 1 -- bloque seleccionado del inventario
local ghostBlock = nil -- Part preview que sigue al mouse
local gridVisual = nil -- Folder con las lineas del grid

-- Funcion para obtener la parcela del jugador (busca en Workspace/Parcelas)
local function findPlayerParcel()
        local parcelas = Workspace:FindFirstChild("Parcelas")
        if not parcelas then return nil end
        -- El cliente no sabe cual es "su" parcela, pero el servidor si.
        -- Para el grid y el ghost, mostramos solo en la parcela que esta cerca del jugador.
        local char = player.Character
        if not char then return nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        local closest = nil
        local closestDist = math.huge
        for _, p in ipairs(parcelas:GetChildren()) do
                if p:IsA("BasePart") then
                        local dist = (p.Position - root.Position).Magnitude
                        if dist < closestDist then
                                closestDist = dist
                                closest = p
                        end
                end
        end
        -- Solo devolver si esta suficientemente cerca (50 studs)
        if closestDist < 50 then return closest end
        return nil
end

-- Snap de posicion a la cuadricula de 4 studs
local function snapToGrid(position, parcelCenter)
        -- Calcula offset desde el centro de la parcela, hace snap, y vuelve a world coords
        local offsetX = position.X - parcelCenter.X
        local offsetZ = position.Z - parcelCenter.Z
        -- Snap: redondear al multiplo de BLOCK_SIZE mas cercano
        local snappedX = math.round(offsetX / BLOCK_SIZE_BUILD) * BLOCK_SIZE_BUILD
        local snappedZ = math.round(offsetZ / BLOCK_SIZE_BUILD) * BLOCK_SIZE_BUILD
        return Vector3.new(
                parcelCenter.X + snappedX,
                position.Y,
                parcelCenter.Z + snappedZ
        )
end

-- Crear/actualizar el bloque fantasma (preview)
local function updateGhostBlock()
        if not buildMode then
                if ghostBlock then
                        ghostBlock:Destroy()
                        ghostBlock = nil
                end
                return
        end

        local parcel = findPlayerParcel()
        if not parcel then
                if ghostBlock then ghostBlock.LocalTransparencyModifier = 1 end -- ocultar (Part no tiene Visible)
                return
        end

        -- Raycast desde la camara hacia el mouse
        local mousePos = mouse.Hit.Position
        -- El bloque se coloca encima de la superficie apuntada
        local placeY = mousePos.Y + BLOCK_SIZE_BUILD / 2

        -- Para colocar al ras del suelo de la parcela:
        -- Si la Y del bloque seria menor que la Y de la parcela + BLOCK_SIZE/2, ajustar
        local parcelTopY = parcel.Position.Y
        if placeY < parcelTopY + BLOCK_SIZE_BUILD / 2 then
                placeY = parcelTopY + BLOCK_SIZE_BUILD / 2
        end

        local snappedPos = snapToGrid(Vector3.new(mousePos.X, placeY, mousePos.Z), parcel.Position)

        -- Calcular bounds de la parcela para verificar que el ghost este dentro
        local halfX = PARCEL_SIZE_X_BUILD / 2
        local halfZ = PARCEL_SIZE_Z_BUILD / 2
        local maxY = parcelTopY + PARCEL_HEIGHT_BUILD

        local inBounds =  snappedPos.X - BLOCK_SIZE_BUILD/2 >= parcel.Position.X - halfX and
                snappedPos.X + BLOCK_SIZE_BUILD/2 <= parcel.Position.X + halfX and
                snappedPos.Z - BLOCK_SIZE_BUILD/2 >= parcel.Position.Z - halfZ and
                snappedPos.Z + BLOCK_SIZE_BUILD/2 <= parcel.Position.Z + halfZ and
                snappedPos.Y + BLOCK_SIZE_BUILD/2 <= maxY

        if not ghostBlock then
                ghostBlock = Instance.new("Part")
                ghostBlock.Name = "GhostBlock"
                ghostBlock.Size = Vector3.new(BLOCK_SIZE_BUILD, BLOCK_SIZE_BUILD, BLOCK_SIZE_BUILD)
                ghostBlock.Anchored = true
                ghostBlock.CanCollide = false
                ghostBlock.CanQuery = false
                ghostBlock.CanTouch = false
                ghostBlock.Material = Enum.Material.ForceField
                ghostBlock.Transparency = 0.5
                ghostBlock.LocalTransparencyModifier = 1 -- oculto por defecto (hasta que se actualice la posicion)
                ghostBlock.Parent = Workspace
        end

        local config = BLOCK_TYPES_BUILD[selectedBlockIdx]
        ghostBlock.Position = snappedPos
        ghostBlock.LocalTransparencyModifier = 0.5 -- semi-transparente (Visible no existe en Part)
        -- Color del bloque si esta en bounds, rojo si no
        if inBounds then
                ghostBlock.Color = config.color
        else
                ghostBlock.Color = Color3.fromRGB(255, 80, 80)
        end
end

-- Crear el grid visual (lineas que muestran la cuadricula de la parcela)
local function createGridVisual(parcel)
        if gridVisual then
                gridVisual:Destroy()
                gridVisual = nil
        end
        if not parcel then return end

        gridVisual = Instance.new("Folder")
        gridVisual.Name = "GridVisual"
        gridVisual.Parent = Workspace

        local halfX = PARCEL_SIZE_X_BUILD / 2
        local halfZ = PARCEL_SIZE_Z_BUILD / 2
        local center = parcel.Position
        local topY = center.Y + 0.1 -- ligeramente encima de la parcela para evitar z-fighting

        -- Lineas horizontales (a lo largo de Z, desplazadas en X)
        for i = -halfX, halfX, BLOCK_SIZE_BUILD do
                local line = Instance.new("Part")
                line.Name = "GridLine_H_" .. i
                line.Size = Vector3.new(0.1, 0.05, PARCEL_SIZE_Z_BUILD)
                line.Position = Vector3.new(center.X + i, topY, center.Z)
                line.Anchored = true
                line.CanCollide = false
                line.CanQuery = false
                line.CanTouch = false
                line.Material = Enum.Material.Neon
                line.Color = Color3.fromRGB(100, 200, 255)
                line.Transparency = 0.7
                line.Parent = gridVisual
        end
        -- Lineas verticales (a lo largo de X, desplazadas en Z)
        for i = -halfZ, halfZ, BLOCK_SIZE_BUILD do
                local line = Instance.new("Part")
                line.Name = "GridLine_V_" .. i
                line.Size = Vector3.new(PARCEL_SIZE_X_BUILD, 0.05, 0.1)
                line.Position = Vector3.new(center.X, topY, center.Z + i)
                line.Anchored = true
                line.CanCollide = false
                line.CanQuery = false
                line.CanTouch = false
                line.Material = Enum.Material.Neon
                line.Color = Color3.fromRGB(100, 200, 255)
                line.Transparency = 0.7
                line.Parent = gridVisual
        end
end

local function removeGridVisual()
        if gridVisual then
                gridVisual:Destroy()
                gridVisual = nil
        end
end

-- Boton "Construir" (arriba del boton de musica)
local buildBtn = Instance.new("TextButton")
buildBtn.Name = "BuildBtn"
buildBtn.Size = UDim2.new(0, 60, 0, 60)
buildBtn.Position = UDim2.new(0, 20, 1, -340) -- 70px arriba del boton de musica (-270 - 70)
buildBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
buildBtn.BorderSizePixel = 0
buildBtn.Text = ""
buildBtn.Parent = screenGui
Instance.new("UICorner", buildBtn).CornerRadius = UDim.new(0, 12)

-- Icono del boton construir (emoji temporal - se puede reemplazar por imagen)
local buildIcon = Instance.new("TextLabel")
buildIcon.Size = UDim2.new(0.8, 0, 0.8, 0)
buildIcon.Position = UDim2.new(0.1, 0, 0.1, 0)
buildIcon.BackgroundTransparency = 1
buildIcon.Text = "🔨"
buildIcon.TextScaled = true
buildIcon.Parent = buildBtn

local buildStroke = Instance.new("UIStroke")
buildStroke.Color = Color3.fromRGB(255, 180, 80) -- naranja para diferenciar
buildStroke.Thickness = 2
buildStroke.Transparency = 0.3
buildStroke.Parent = buildBtn

-- Tooltip del boton (texto B)
local buildKeyLabel = Instance.new("TextLabel")
buildKeyLabel.Size = UDim2.new(0.3, 0, 0.3, 0)
buildKeyLabel.Position = UDim2.new(0.65, 0, 0.6, 0)
buildKeyLabel.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
buildKeyLabel.BorderSizePixel = 0
buildKeyLabel.Text = "B"
buildKeyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
buildKeyLabel.TextScaled = true
buildKeyLabel.Font = Enum.Font.GothamBold
buildKeyLabel.ZIndex = 2
buildKeyLabel.Parent = buildBtn
Instance.new("UICorner", buildKeyLabel).CornerRadius = UDim.new(0, 4)

-- Panel de bloques (mismo formato que mochila y musica)
local buildPanel = Instance.new("Frame")
buildPanel.Name = "BuildPanel"
buildPanel.Size = UDim2.new(0, 400, 0, 350)
buildPanel.Position = UDim2.new(0.5, -200, 1, -370)
buildPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
buildPanel.BackgroundTransparency = 0.05
buildPanel.BorderSizePixel = 0
buildPanel.Visible = false
buildPanel.ZIndex = 50
buildPanel.Parent = screenGui
Instance.new("UICorner", buildPanel).CornerRadius = UDim.new(0, 16)

local bpBuildCloseBtn = Instance.new("TextButton")
bpBuildCloseBtn.Name = "BpBuildCloseBtn"
bpBuildCloseBtn.Size = UDim2.new(0, 30, 0, 30)
bpBuildCloseBtn.Position = UDim2.new(1, -35, 0, 5)
bpBuildCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
bpBuildCloseBtn.BorderSizePixel = 0
bpBuildCloseBtn.Text = "X"
bpBuildCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bpBuildCloseBtn.TextScaled = true
bpBuildCloseBtn.Font = Enum.Font.GothamBold
bpBuildCloseBtn.ZIndex = 52
bpBuildCloseBtn.Parent = buildPanel
Instance.new("UICorner", bpBuildCloseBtn).CornerRadius = UDim.new(0, 8)

local bpBuildStroke = Instance.new("UIStroke")
bpBuildStroke.Color = Color3.fromRGB(255, 180, 80)
bpBuildStroke.Thickness = 2
bpBuildStroke.Transparency = 0.2
bpBuildStroke.Parent = buildPanel

local bpBuildTitle = Instance.new("TextLabel")
bpBuildTitle.Size = UDim2.new(1, 0, 0, 35)
bpBuildTitle.BackgroundTransparency = 1
bpBuildTitle.Text = "BLOQUES"
bpBuildTitle.TextColor3 = Color3.fromRGB(255, 180, 80)
bpBuildTitle.TextScaled = true
bpBuildTitle.Font = Enum.Font.GothamBlack
bpBuildTitle.ZIndex = 51
bpBuildTitle.Parent = buildPanel

-- Scroll con los bloques
local bpBuildScroll = Instance.new("ScrollingFrame")
bpBuildScroll.Size = UDim2.new(1, -20, 1, -45)
bpBuildScroll.Position = UDim2.new(0, 10, 0, 40)
bpBuildScroll.BackgroundTransparency = 1
bpBuildScroll.ScrollBarThickness = 6
bpBuildScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
bpBuildScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
bpBuildScroll.ZIndex = 51
bpBuildScroll.Parent = buildPanel

local bpBuildListLayout = Instance.new("UIListLayout")
bpBuildListLayout.Padding = UDim.new(0, 8)
bpBuildListLayout.Parent = bpBuildScroll

-- Funcion para actualizar el panel de bloques
local function updateBuildUI()
        -- Limpiar
        for _, child in ipairs(bpBuildScroll:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
        end
        -- Crear card por bloque
        for idx, block in ipairs(BLOCK_TYPES_BUILD) do
                local card = Instance.new("Frame")
                card.Name = "BlockCard_" .. idx
                card.Size = UDim2.new(1, -10, 0, 60)
                card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                card.BorderSizePixel = 0
                card.ZIndex = 52
                card.Parent = bpBuildScroll
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

                local cardStroke = Instance.new("UIStroke")
                if idx == selectedBlockIdx then
                        cardStroke.Color = Color3.fromRGB(80, 220, 80)
                        cardStroke.Thickness = 3
                else
                        cardStroke.Color = Color3.fromRGB(255, 180, 80)
                        cardStroke.Thickness = 2
                end
                cardStroke.Transparency = 0.2
                cardStroke.Parent = card

                -- Preview del bloque (Part color como indicador)
                local preview = Instance.new("Frame")
                preview.Size = UDim2.new(0, 50, 1, -10)
                preview.Position = UDim2.new(0, 5, 0, 5)
                preview.BackgroundColor3 = block.color
                preview.BorderSizePixel = 0
                preview.ZIndex = 53
                preview.Parent = card
                Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 6)

                -- Info del bloque
                local infoLabel = Instance.new("TextLabel")
                infoLabel.Size = UDim2.new(0.55, 0, 1, -10)
                infoLabel.Position = UDim2.new(0, 60, 0, 5)
                infoLabel.BackgroundTransparency = 1
                infoLabel.Text = '<font color="#FFFFFF">' .. block.name .. '</font>\n<font color="#80C8FF">$' .. block.cost .. '</font>'
                infoLabel.RichText = true
                infoLabel.TextXAlignment = Enum.TextXAlignment.Left
                infoLabel.TextYAlignment = Enum.TextYAlignment.Center
                infoLabel.TextScaled = true
                infoLabel.Font = Enum.Font.GothamBold
                infoLabel.ZIndex = 53
                infoLabel.Parent = card

                -- Boton Seleccionar
                local selBtn = Instance.new("TextButton")
                selBtn.Size = UDim2.new(0.3, -5, 0.6, 0)
                selBtn.Position = UDim2.new(0.7, 5, 0.2, 0)
                selBtn.BackgroundColor3 = (idx == selectedBlockIdx) and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(255, 180, 80)
                selBtn.BorderSizePixel = 0
                selBtn.Text = (idx == selectedBlockIdx) and "✓" or "Sel"
                selBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                selBtn.TextScaled = true
                selBtn.Font = Enum.Font.GothamBold
                selBtn.ZIndex = 53
                selBtn.Parent = card
                Instance.new("UICorner", selBtn).CornerRadius = UDim.new(0, 6)

                selBtn.MouseButton1Click:Connect(function()
                        selectedBlockIdx = idx
                        updateBuildUI()
                        print("[Build] Bloque seleccionado: " .. block.name .. " ($" .. block.cost .. ")")
                end)
        end
end

-- Forward declaration para que las closures puedan referenciarla
local toggleBuildMode

-- Toggle panel de bloques
buildBtn.MouseButton1Click:Connect(function()
        toggleBuildMode()
end)

bpBuildCloseBtn.MouseButton1Click:Connect(function()
        if buildMode then toggleBuildMode() end
end)

-- Cuando se abre mochila o musica, cerrar panel de bloques (no se solapen)
backpackBtn.MouseButton1Click:Connect(function()
        if backpackPanel.Visible and buildMode then
                toggleBuildMode()
        end
end)
musicBtn.MouseButton1Click:Connect(function()
        if musicPanel.Visible and buildMode then
                toggleBuildMode()
        end
end)

-- Tecla B para abrir/cerrar modo construccion
UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.B then
                toggleBuildMode()
        end
end)

-- Click izquierdo: colocar bloque / Click derecho: quitar bloque (solo en modo build)
UserInputService.InputBegan:Connect(function(input, processed)
        if not buildMode then return end
        if processed then return end
        -- Solo procesar si no es UI
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                -- Click izquierdo: colocar bloque
                -- (Part no tiene Visible, usamos LocalTransparencyModifier para saber si esta visible)
                if ghostBlock and ghostBlock.LocalTransparencyModifier < 1 then
                        local config = BLOCK_TYPES_BUILD[selectedBlockIdx]
                        PlaceBlockEvent:FireServer(config.id, ghostBlock.Position, nil)
                end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                -- Click derecho: quitar bloque apuntado
                -- Raycast desde la camara para encontrar el bloque
                local mouseTarget = mouse.Target
                if mouseTarget and mouseTarget.Name and string.sub(mouseTarget.Name, 1, 6) == "Block_" then
                        -- Verificar que tenga tag Owner (el servidor validara que sea del jugador)
                        RemoveBlockEvent:FireServer(mouseTarget)
                end
        end
end)

-- Touch para mobile (tocar = colocar, mantener + tocar = quitar)
UserInputService.InputBegan:Connect(function(input, processed)
        if not buildMode then return end
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Touch then
                -- En mobile, un toque = colocar bloque
                if ghostBlock and ghostBlock.LocalTransparencyModifier < 1 then
                        local config = BLOCK_TYPES_BUILD[selectedBlockIdx]
                        PlaceBlockEvent:FireServer(config.id, ghostBlock.Position, nil)
                end
        end
end)

-- Loop para actualizar el ghost block en cada frame
RunService.RenderStepped:Connect(function()
        if buildMode then
                updateGhostBlock()
        end
end)

-- Definicion real de toggleBuildMode (al final para que vea todas las variables locales)
function toggleBuildMode()
        buildMode = not buildMode
        if buildMode then
                -- Activar
                local parcel = findPlayerParcel()
                createGridVisual(parcel)
                -- Desactivar pelota si esta equipada (para no conflictos)
                if ballEquipped then
                        unequipBall()
                end
                -- Cerrar mochila y panel de musica si estan abiertos
                backpackPanel.Visible = false
                musicPanel.Visible = false
                -- Mostrar panel de bloques
                buildPanel.Visible = true
                updateBuildUI()
                -- Cambiar color del boton para indicar que esta activo
                buildBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
                print("[Build] Modo construccion ACTIVADO")
        else
                -- Desactivar
                removeGridVisual()
                if ghostBlock then
                        ghostBlock:Destroy()
                        ghostBlock = nil
                end
                buildPanel.Visible = false
                buildBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                print("[Build] Modo construccion DESACTIVADO")
        end
end

print("Sistema de construccion cargado!")
























































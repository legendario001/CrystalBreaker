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

-- Animacion cacheada
local cachedThrowAnim = Instance.new("Animation")
cachedThrowAnim.AnimationId = "rbxassetid://90927250635352"
local cachedTrack = nil

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
bottomBar.Position = UDim2.new(0,20,1,-80)
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

local moneyIcon = Instance.new("TextLabel")
moneyIcon.Size = UDim2.new(0.3,0,0.6,0)
moneyIcon.Position = UDim2.new(0.05,0,0.2,0)
moneyIcon.BackgroundTransparency = 1 moneyIcon.Text = "$"
moneyIcon.TextColor3 = MONEY_GREEN_BRIGHT
moneyIcon.TextScaled = true moneyIcon.Font = Enum.Font.GothamBlack
moneyIcon.Parent = moneyPanel

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.Size = UDim2.new(0.6,0,0.6,0)
moneyLabel.Position = UDim2.new(0.35,0,0.2,0)
moneyLabel.BackgroundTransparency = 1 moneyLabel.Text = "0"
moneyLabel.TextColor3 = MONEY_GREEN_BRIGHT
moneyLabel.TextScaled = true moneyLabel.Font = Enum.Font.GothamBlack
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Parent = moneyPanel

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

-- BALL SYSTEM
local function equipBall()
    if ballEquipped or isCarrying then return end
    local char = player.Character
    if not char then return end

    local function removeOld(parent)
        if not parent then return end
        local old = parent:FindFirstChild("CrystalBall")
        if old then old:Destroy() end
    end
    removeOld(char)
    removeOld(player:FindFirstChild("Backpack"))

    local tool = Instance.new("Tool")
    tool.Name = "CrystalBall"
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1.5,1.5,1.5)
    handle.Shape = Enum.PartType.Ball
    handle.Color = Color3.fromRGB(100,200,255)
    handle.Material = Enum.Material.SmoothPlastic
    handle.Anchored = false handle.CanCollide = false handle.Massless = true
    handle.Parent = tool
    tool.Parent = char
    ballEquipped = true
    updateButton()
end

local function unequipBall()
    if not ballEquipped then return end
    local function removeOld(parent)
        if not parent then return end
        local old = parent:FindFirstChild("CrystalBall")
        if old then old:Destroy() end
    end
    removeOld(player.Character)
    removeOld(player:FindFirstChild("Backpack"))
    ballEquipped = false
    updateButton()
end

local function throwBall()
    if not ballEquipped or isCarrying then return end
    if throwDebounce or activeBalls >= MAX_ACTIVE_BALLS then return end
    throwDebounce = true

    local char = player.Character
    if not char then throwDebounce=false return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not root then throwDebounce=false return end

    -- OPTIMIZADO: reusar track cacheado
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            if not cachedTrack then
                cachedTrack = animator:LoadAnimation(cachedThrowAnim)
            end
            if cachedTrack and not cachedTrack.IsPlaying then
                cachedTrack:Play()
            end
        end
    end

    local ball = Instance.new("Part")
    ball.Name = "ThrownBall"
    ball.Size = Vector3.new(1.5,1.5,1.5)
    ball.Shape = Enum.PartType.Ball
    ball.Color = Color3.fromRGB(100,200,255)
    ball.Material = Enum.Material.SmoothPlastic
    ball.Anchored = false ball.CanCollide = true ball.Massless = false
    ball.Position = root.Position + root.CFrame.LookVector*3 + Vector3.new(0,3,0)
    ball.CustomPhysicalProperties = PhysicalProperties.new(0.5,0.3,1.0,0.3,1.0)
    ball.Parent = workspace

    local mouseHit = mouse.Hit
    if mouseHit then
        local direction = (mouseHit.Position - ball.Position).Unit
        ball.AssemblyLinearVelocity = direction*100 + Vector3.new(0,20,0)
    end

    if ThrowBallEvent then
        ThrowBallEvent:FireServer(mouseHit and mouseHit.Position or root.Position + root.CFrame.LookVector*20)
    end

    activeBalls = activeBalls + 1
    Debris:AddItem(ball, 4)
    task.delay(4.5, function() activeBalls = math.max(0, activeBalls-1) end)
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
            if PlaceCharacterEvent then PlaceCharacterEvent:FireServer() end
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
    moneyLabel.Text = tostring(amount)
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

updateButton()
updateUI()
print("BallThrower cargado!")







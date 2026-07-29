-- ============================================
-- ShopSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Boton "SHOP" en esquina inferior derecha con UIStroke grosor 10.
-- Abre un panel con el Boost de Ganancias 20% (GamePass 99 R$ o 1 trillon dinero).
-- ============================================

local ShopSystem = {}

function ShopSystem.init(deps)
        local player = deps.player
        local screenGui = deps.screenGui
        local Workspace = deps.Workspace
        local ReplicatedStorage = deps.ReplicatedStorage
        local MarketplaceService = game:GetService("MarketplaceService")
        local UserInputService = game:GetService("UserInputService")

        -- ============================================
        -- Configuracion
        -- ============================================
        local BOOST_GAMEPASS_ID = 3612156466  -- GamePass: da nivel 1 permanente
        local BOOST_DEVPRODUCT_ID = 3612156466  -- Developer Product: Mejora Boost 20% (99 R$)
        local BOOST_COST_MONEY = 1000000000000  -- 1 trillon (1T = 1e12)
        local MAX_BOOST_LEVEL = 5

        local BuyBoostWithMoneyEvent = ReplicatedStorage:WaitForChild("BuyBoostWithMoney", 15)

        -- ============================================
        -- Boton "SHOP" (esquina inferior izquierda, arriba del martillo de construccion)
        -- El buildBtn esta en Position(0, 20, 1, -340) con size 60x60.
        -- Ponemos el shop justo arriba: Position(0, 20, 1, -410) con size 60x60.
        -- ============================================
        local shopButton = Instance.new("TextButton")
        shopButton.Name = "ShopButton"
        shopButton.Size = UDim2.new(0, 60, 0, 60)
        shopButton.Position = UDim2.new(0, 20, 1, -410)  -- arriba del martillo
        shopButton.BackgroundColor3 = Color3.fromRGB(255, 100, 50)  -- naranja/rojo
        shopButton.BorderSizePixel = 0
        shopButton.Text = ""
        shopButton.Parent = screenGui
        Instance.new("UICorner", shopButton).CornerRadius = UDim.new(0, 12)

        -- Icono de tienda (carrito de compras) usando ImageLabel
        local shopIcon = Instance.new("ImageLabel")
        shopIcon.Name = "ShopIcon"
        shopIcon.Size = UDim2.new(0.7, 0, 0.7, 0)
        shopIcon.Position = UDim2.new(0.15, 0, 0.15, 0)
        shopIcon.BackgroundTransparency = 1
        shopIcon.Image = "rbxassetid://8143125530"  -- icono de shop personalizado
        shopIcon.ScaleType = Enum.ScaleType.Fit
        shopIcon.Parent = shopButton

        -- UIStroke GRUESO (grosor 10 como pidio el usuario)
        local shopStroke = Instance.new("UIStroke", shopButton)
        shopStroke.Name = "ShopButtonStroke"
        shopStroke.Color = Color3.fromRGB(0, 0, 0)  -- negro
        shopStroke.Thickness = 10  -- grueso
        shopStroke.Transparency = 0
        shopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        -- ============================================
        -- Panel de la Shop (modal)
        -- ============================================
        local shopPanel = Instance.new("Frame")
        shopPanel.Name = "ShopPanel"
        shopPanel.Size = UDim2.new(0, 450, 0, 550)
        shopPanel.Position = UDim2.new(0.5, -225, 0.5, -275)
        shopPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        shopPanel.BackgroundTransparency = 0.05
        shopPanel.BorderSizePixel = 0
        shopPanel.Visible = false
        shopPanel.Parent = screenGui
        Instance.new("UICorner", shopPanel).CornerRadius = UDim.new(0, 15)

        local panelStroke = Instance.new("UIStroke", shopPanel)
        panelStroke.Color = Color3.fromRGB(255, 100, 50)
        panelStroke.Thickness = 4

        -- Titulo
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -40, 0, 70)
        titleLabel.Position = UDim2.new(0, 20, 0, 15)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "🛒 TIENDA"
        titleLabel.TextColor3 = Color3.fromRGB(255, 100, 50)
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.Parent = shopPanel

        -- Boton cerrar (X)
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 45, 0, 45)
        closeBtn.Position = UDim2.new(1, -55, 0, 10)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 22
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.BorderSizePixel = 0
        closeBtn.Parent = shopPanel
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

        -- ============================================
        -- Item: Boost de Ganancias 20%
        -- ============================================
        local boostItem = Instance.new("Frame")
        boostItem.Name = "BoostItem"
        boostItem.Size = UDim2.new(1, -40, 0, 200)
        boostItem.Position = UDim2.new(0, 20, 0, 100)
        boostItem.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        boostItem.BackgroundTransparency = 0.2
        boostItem.BorderSizePixel = 0
        boostItem.Parent = shopPanel
        Instance.new("UICorner", boostItem).CornerRadius = UDim.new(0, 12)

        local itemStroke = Instance.new("UIStroke", boostItem)
        itemStroke.Color = Color3.fromRGB(255, 215, 0)  -- dorado
        itemStroke.Thickness = 3

        -- Titulo del item
        local itemTitle = Instance.new("TextLabel")
        itemTitle.Size = UDim2.new(1, -20, 0, 50)
        itemTitle.Position = UDim2.new(0, 10, 0, 10)
        itemTitle.BackgroundTransparency = 1
        itemTitle.Text = "🚀 BOOST GANANCIAS +20%"
        itemTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
        itemTitle.TextScaled = true
        itemTitle.Font = Enum.Font.GothamBold
        itemTitle.TextXAlignment = Enum.TextXAlignment.Left
        itemTitle.Parent = boostItem

        -- Descripcion
        local itemDesc = Instance.new("TextLabel")
        itemDesc.Size = UDim2.new(1, -20, 0, 60)
        itemDesc.Position = UDim2.new(0, 10, 0, 60)
        itemDesc.BackgroundTransparency = 1
        itemDesc.Text = "Cada nivel da +20% de ganancias en todos tus personajes. Maximo 5 niveles (hasta +100%)."
        itemDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
        itemDesc.TextWrapped = true
        itemDesc.TextScaled = true
        itemDesc.Font = Enum.Font.GothamMedium
        itemDesc.TextXAlignment = Enum.TextXAlignment.Left
        itemDesc.Parent = boostItem

        -- Nivel actual
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Name = "LevelLabel"
        levelLabel.Size = UDim2.new(1, -20, 0, 30)
        levelLabel.Position = UDim2.new(0, 10, 0, 125)
        levelLabel.BackgroundTransparency = 1
        levelLevel = levelLabel  -- referencia
        levelLabel.Text = "Nivel actual: 0/5 (+0%)"
        levelLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.TextXAlignment = Enum.TextXAlignment.Left
        levelLabel.Parent = boostItem

        -- Boton comprar con Robux (GamePass)
        local buyRobuxBtn = Instance.new("TextButton")
        buyRobuxBtn.Name = "BuyWithRobux"
        buyRobuxBtn.Size = UDim2.new(0.48, -5, 0, 45)
        buyRobuxBtn.Position = UDim2.new(0, 10, 1, -55)
        buyRobuxBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
        buyRobuxBtn.Text = "Comprar con Robux (99 R$)"
        buyRobuxBtn.Font = Enum.Font.GothamBold
        buyRobuxBtn.TextSize = 14
        buyRobuxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyRobuxBtn.BorderSizePixel = 0
        buyRobuxBtn.Parent = boostItem
        Instance.new("UICorner", buyRobuxBtn).CornerRadius = UDim.new(0, 8)

        -- Boton comprar con dinero del juego
        local buyMoneyBtn = Instance.new("TextButton")
        buyMoneyBtn.Name = "BuyWithMoney"
        buyMoneyBtn.Size = UDim2.new(0.48, -5, 0, 45)
        buyMoneyBtn.Position = UDim2.new(0.52, 0, 1, -55)
        buyMoneyBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
        buyMoneyBtn.Text = "Comprar con $1T"
        buyMoneyBtn.Font = Enum.Font.GothamBold
        buyMoneyBtn.TextSize = 14
        buyMoneyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyMoneyBtn.BorderSizePixel = 0
        buyMoneyBtn.Parent = boostItem
        Instance.new("UICorner", buyMoneyBtn).CornerRadius = UDim.new(0, 8)

        -- ============================================
        -- Logica
        -- ============================================
        local function openShop()
                shopPanel.Visible = true
        end

        local function closeShop()
                shopPanel.Visible = false
        end

        shopButton.MouseButton1Click:Connect(openShop)
        closeBtn.MouseButton1Click:Connect(closeShop)

        UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == Enum.KeyCode.Escape and shopPanel.Visible then
                        closeShop()
                end
        end)

        -- Comprar con Robux (Developer Product - se puede comprar multiples veces)
        buyRobuxBtn.MouseButton1Click:Connect(function()
                if BOOST_DEVPRODUCT_ID > 0 then
                        pcall(function()
                                MarketplaceService:PromptProductPurchase(player, BOOST_DEVPRODUCT_ID)
                        end)
                else
                        warn("[Shop] BOOST_DEVPRODUCT_ID no configurado (es 0). Crea un Developer Product de 99 R$.")
                end
        end)

        -- Comprar con dinero del juego
        buyMoneyBtn.MouseButton1Click:Connect(function()
                if BuyBoostWithMoneyEvent then
                        BuyBoostWithMoneyEvent:FireServer()
                end
        end)

        -- Escuchar actualizaciones de boost del servidor
        local BoostUpdateEvent = ReplicatedStorage:WaitForChild("BoostUpdate", 10)
        if BoostUpdateEvent then
                BoostUpdateEvent.OnClientEvent:Connect(function(boostLevel)
                        if levelLabel then
                                levelLabel.Text = "Nivel actual: " .. boostLevel .. "/5 (+" .. (boostLevel * 20) .. "%)"
                        end
                        -- Desactivar botones si ya tiene el nivel maximo
                        if boostLevel >= 5 then
                                buyRobuxBtn.Visible = false
                                buyMoneyBtn.Visible = false
                                levelLabel.Text = "Nivel MAXIMO: 5/5 (+100%) 🎉"
                        end
                end)
        end

        print("[ShopSystem] Boton SHOP cargado (UIStroke grosor 10)")
end

return ShopSystem

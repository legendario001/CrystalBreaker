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
        local BOOST_GAMEPASS_ID = 3612156466  -- Boost 20% Ganancias (99 R$)
        local BOOST_COST_MONEY = 1000000000000000  -- 1 trillon (1e15)
        local MAX_BOOST_LEVEL = 5

        local BuyBoostWithMoneyEvent = ReplicatedStorage:WaitForChild("BuyBoostWithMoney", 15)

        -- ============================================
        -- Boton "SHOP" (esquina inferior derecha)
        -- ============================================
        local shopButton = Instance.new("TextButton")
        shopButton.Name = "ShopButton"
        shopButton.Size = UDim2.new(0, 140, 0, 60)
        shopButton.Position = UDim2.new(1, -160, 1, -80)  -- esquina inferior derecha
        shopButton.BackgroundColor3 = Color3.fromRGB(255, 100, 50)  -- naranja/rojo
        shopButton.BorderSizePixel = 0
        shopButton.Text = "🛒 SHOP"
        shopButton.Font = Enum.Font.GothamBlack
        shopButton.TextSize = 22
        shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        shopButton.Parent = screenGui
        Instance.new("UICorner", shopButton).CornerRadius = UDim.new(0, 12)

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

        -- Comprar con Robux (GamePass)
        buyRobuxBtn.MouseButton1Click:Connect(function()
                if BOOST_GAMEPASS_ID > 0 then
                        pcall(function()
                                MarketplaceService:PromptGamePassPurchase(player, BOOST_GAMEPASS_ID)
                        end)
                else
                        warn("[Shop] BOOST_GAMEPASS_ID no configurado (es 0)")
                end
        end)

        -- Comprar con dinero del juego
        buyMoneyBtn.MouseButton1Click:Connect(function()
                if BuyBoostWithMoneyEvent then
                        BuyBoostWithMoneyEvent:FireServer()
                end
        end)

        print("[ShopSystem] Boton SHOP cargado (UIStroke grosor 10)")
end

return ShopSystem

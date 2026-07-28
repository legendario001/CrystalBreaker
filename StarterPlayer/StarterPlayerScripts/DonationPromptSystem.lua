-- ============================================
-- DonationPromptSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Detecta cuando el jugador se acerca al TablaDonadores y muestra un boton "DONAR".
-- Al hacer click, pide al servidor los productos de donacion disponibles y abre un panel.
--
-- RemoteEvents usados:
--   - RequestDonationProducts (cliente -> servidor): pedir lista de productos
--   - DonationProductsResponse (servidor -> cliente): respuesta con la lista
-- ============================================

local DonationPromptSystem = {}

function DonationPromptSystem.init(deps)
        local player = deps.player
        local screenGui = deps.screenGui
        local Workspace = deps.Workspace
        local ReplicatedStorage = deps.ReplicatedStorage
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")

        local RequestDonationProducts = ReplicatedStorage:WaitForChild("RequestDonationProducts", 15)
        local DonationProductsResponse = ReplicatedStorage:WaitForChild("DonationProductsResponse", 15)

        local PROMPT_DISTANCE = 25  -- distancia maxima para mostrar el boton "Donar"
        local checkInterval = 0.5  -- verificar cada 0.5s (no cada frame para optimizar)
        local lastCheck = 0

        -- ============================================
        -- Boton "DONAR" (flotante, aparece al acercarse)
        -- ============================================
        local donateButton = Instance.new("TextButton")
        donateButton.Name = "DonateButton"
        donateButton.Size = UDim2.new(0, 200, 0, 70)
        donateButton.Position = UDim2.new(0.5, -100, 0.7, 0)  -- abajo al centro
        donateButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)  -- dorado
        donateButton.BorderSizePixel = 0
        donateButton.Text = "💖 DONAR"
        donateButton.Font = Enum.Font.GothamBlack
        donateButton.TextSize = 24
        donateButton.TextColor3 = Color3.fromRGB(20, 20, 30)
        donateButton.Visible = false
        donateButton.Parent = screenGui
        Instance.new("UICorner", donateButton).CornerRadius = UDim.new(0, 12)

        -- UIStroke GRUESO alrededor del boton (grosor 8 como pidio el usuario)
        local btnStroke = Instance.new("UIStroke", donateButton)
        btnStroke.Name = "DonationButtonStroke"
        btnStroke.Color = Color3.fromRGB(0, 0, 0)  -- negro
        btnStroke.Thickness = 8  -- grueso
        btnStroke.Transparency = 0
        btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        -- ============================================
        -- Panel de productos de donacion (modal)
        -- ============================================
        local donationPanel = Instance.new("Frame")
        donationPanel.Name = "DonationPanel"
        donationPanel.Size = UDim2.new(0, 400, 0, 500)
        donationPanel.Position = UDim2.new(0.5, -200, 0.5, -250)
        donationPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        donationPanel.BackgroundTransparency = 0.05
        donationPanel.BorderSizePixel = 0
        donationPanel.Visible = false
        donationPanel.Parent = screenGui
        Instance.new("UICorner", donationPanel).CornerRadius = UDim.new(0, 15)

        local panelStroke = Instance.new("UIStroke", donationPanel)
        panelStroke.Color = Color3.fromRGB(255, 215, 0)
        panelStroke.Thickness = 4

        -- Titulo
        local panelTitle = Instance.new("TextLabel")
        panelTitle.Size = UDim2.new(1, -40, 0, 60)
        panelTitle.Position = UDim2.new(0, 20, 0, 15)
        panelTitle.BackgroundTransparency = 1
        panelTitle.Text = "💖 DONAR ROBUX"
        panelTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
        panelTitle.TextScaled = true
        panelTitle.Font = Enum.Font.GothamBlack
        panelTitle.Parent = donationPanel

        -- Boton cerrar (X)
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 40, 0, 40)
        closeBtn.Position = UDim2.new(1, -50, 0, 10)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 20
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.BorderSizePixel = 0
        closeBtn.Parent = donationPanel
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

        -- Contenedor de productos (con scroll)
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -30, 1, -120)
        scrollFrame.Position = UDim2.new(0, 15, 0, 90)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.BorderSizePixel = 0
        scrollFrame.ScrollBarThickness = 6
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollFrame.Parent = donationPanel

        local listLayout = Instance.new("UIListLayout", scrollFrame)
        listLayout.Padding = UDim.new(0, 10)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- Texto de carga
        local loadingLabel = Instance.new("TextLabel")
        loadingLabel.Size = UDim2.new(1, 0, 0, 50)
        loadingLabel.BackgroundTransparency = 1
        loadingLabel.Text = "Cargando productos..."
        loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loadingLabel.TextScaled = true
        loadingLabel.Font = Enum.Font.GothamMedium
        loadingLabel.Parent = scrollFrame

        -- ============================================
        -- Logica de deteccion de cercania
        -- ============================================
        local function getTablaDonadoresPosition()
                local tablaModel = Workspace:FindFirstChild("TablaDonadores")
                if not tablaModel then return nil end
                local screen = tablaModel:FindFirstChild("LeaderboardScreen")
                if screen then return screen.Position end
                -- Fallback: usar posicion conocida
                return Vector3.new(146.169, 10, 100.85)
        end

        RunService.RenderStepped:Connect(function()
                local now = os.clock()
                if now - lastCheck < checkInterval then return end
                lastCheck = now

                if donationPanel.Visible then return end  -- no mostrar boton si el panel esta abierto

                local character = player.Character
                if not character then return end
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local tablaPos = getTablaDonadoresPosition()
                if not tablaPos then return end

                local dist = (hrp.Position - tablaPos).Magnitude
                if dist <= PROMPT_DISTANCE then
                        donateButton.Visible = true
                else
                        donateButton.Visible = false
                end
        end)

        -- ============================================
        -- Abrir panel y pedir productos
        -- ============================================
        local function openDonationPanel()
                donationPanel.Visible = true
                donateButton.Visible = false
                -- Limpiar productos anteriores
                for _, child in ipairs(scrollFrame:GetChildren()) do
                        if child:IsA("TextButton") then child:Destroy() end
                end
                loadingLabel.Visible = true
                loadingLabel.Text = "Cargando productos..."
                -- Pedir productos al servidor
                if RequestDonationProducts then
                        RequestDonationProducts:FireServer()
                end
        end

        local function closeDonationPanel()
                donationPanel.Visible = false
        end

        donateButton.MouseButton1Click:Connect(openDonationPanel)
        closeBtn.MouseButton1Click:Connect(closeDonationPanel)

        -- Tecla Escape para cerrar
        UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == Enum.KeyCode.Escape and donationPanel.Visible then
                        closeDonationPanel()
                end
        end)

        -- ============================================
        -- Recibir lista de productos del servidor
        -- ============================================
        if DonationProductsResponse then
                DonationProductsResponse.OnClientEvent:Connect(function(products)
                        loadingLabel.Visible = false
                        -- Limpiar
                        for _, child in ipairs(scrollFrame:GetChildren()) do
                                if child:IsA("TextButton") then child:Destroy() end
                        end

                        if not products or #products == 0 then
                                loadingLabel.Visible = true
                                loadingLabel.Text = "No hay productos de donacion disponibles."
                                return
                        end

                        for i, product in ipairs(products) do
                                local productBtn = Instance.new("TextButton")
                                productBtn.Size = UDim2.new(1, -10, 0, 80)
                                productBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                                productBtn.BorderSizePixel = 0
                                productBtn.Text = ""
                                productBtn.LayoutOrder = i
                                productBtn.Parent = scrollFrame
                                Instance.new("UICorner", productBtn).CornerRadius = UDim.new(0, 10)

                                local pStroke = Instance.new("UIStroke", productBtn)
                                pStroke.Color = Color3.fromRGB(255, 215, 0)
                                pStroke.Thickness = 2
                                pStroke.Transparency = 0.5

                                -- Nombre del producto
                                local nameLabel = Instance.new("TextLabel")
                                nameLabel.Size = UDim2.new(1, -20, 0, 40)
                                nameLabel.Position = UDim2.new(0, 10, 0, 5)
                                nameLabel.BackgroundTransparency = 1
                                nameLabel.Text = product.name or ("Donacion " .. product.robux .. " R$")
                                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                                nameLabel.TextScaled = true
                                nameLabel.Font = Enum.Font.GothamBold
                                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                                nameLabel.Parent = productBtn

                                -- Precio
                                local priceLabel = Instance.new("TextLabel")
                                priceLabel.Size = UDim2.new(1, -20, 0, 30)
                                priceLabel.Position = UDim2.new(0, 10, 0, 45)
                                priceLabel.BackgroundTransparency = 1
                                priceLabel.Text = product.robux .. " Robux"
                                priceLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
                                priceLabel.TextScaled = true
                                priceLabel.Font = Enum.Font.GothamMedium
                                priceLabel.TextXAlignment = Enum.TextXAlignment.Left
                                priceLabel.Parent = productBtn

                                -- Al hacer click, abrir el prompt de compra de Roblox
                                productBtn.MouseButton1Click:Connect(function()
                                        local MarketplaceService = game:GetService("MarketplaceService")
                                        pcall(function()
                                                MarketplaceService:PromptProductPurchase(player, product.productId)
                                        end)
                                end)
                        end
                end)
        end

        print("[DonationPromptSystem] Sistema de prompt de donacion cargado")
end

return DonationPromptSystem

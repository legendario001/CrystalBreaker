-- ============================================
-- BankSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Sistema de banco: detecta proximidad, muestra imagen E, abre panel
-- Permite depositar y retirar dinero
-- ============================================

local BankSystem = {}

function BankSystem.init(deps)
        local player = deps.player
        local screenGui = deps.screenGui
        local UserInputService = deps.UserInputService
        local RunService = deps.RunService
        local Workspace = deps.Workspace
        local ReplicatedStorage = deps.ReplicatedStorage
        local backpackPanel = deps.backpackPanel
        local musicPanel = deps.musicPanel

        -- Eventos
        local DepositMoneyEvent = ReplicatedStorage:WaitForChild("DepositMoney", 15)
        local WithdrawMoneyEvent = ReplicatedStorage:WaitForChild("WithdrawMoney", 15)
        local BankUIUpdateEvent = ReplicatedStorage:WaitForChild("BankUIUpdate", 15)

        -- Posicion del banco (donde aparece la imagen E y donde el jugador debe acercarse)
        local BANK_POSITION = Vector3.new(126, 4.5, 3)
        local BANK_INTERACT_DISTANCE = 30 -- studs para mostrar la E (aparece desde 30 studs)

        -- Estado
        local bankBalance = 0
        local playerMoney = 0
        local bankPanelOpen = false
        local nearBank = false

        -- Forward declarations (funciones definidas mas abajo)
        local openBankPanel
        local closeBankPanel
        local updateBankUI
        local formatMoney

        -- ============================================
        -- BillboardGui con la imagen E sobre el banco
        -- ============================================
        -- En vez de buscar un Part existente, creamos un Part invisible temporal
        -- en la posicion del banco. Esto garantiza que siempre funcione sin importar
        -- si el usuario creo un Part o no.
        local bankPart = Instance.new("Part")
        bankPart.Name = "BankAnchor"
        bankPart.Anchored = true
        bankPart.CanCollide = false
        bankPart.CanQuery = false
        bankPart.CanTouch = false
        bankPart.Transparency = 1
        bankPart.Size = Vector3.new(0.1, 0.1, 0.1)
        bankPart.Position = BANK_POSITION
        bankPart.Parent = Workspace

        local bankBillboard = Instance.new("BillboardGui")
        bankBillboard.Name = "BankInteractGui"
        bankBillboard.Size = UDim2.new(0, 80, 0, 80)
        bankBillboard.StudsOffset = Vector3.new(0, -3, 0) -- 3 studs abajo del banco
        bankBillboard.AlwaysOnTop = true
        bankBillboard.LightInfluence = 0
        bankBillboard.MaxDistance = 40 -- visible desde lejos (porque ahora aparece a 30 studs)
        bankBillboard.Enabled = false -- oculto por defecto
        bankBillboard.Parent = bankPart

        -- Imagen E (unica imagen del billboard)
        local eImage = Instance.new("ImageLabel")
        eImage.Size = UDim2.new(1, 0, 1, 0)
        eImage.BackgroundTransparency = 1
        eImage.Image = "rbxassetid://78972021775884"
        eImage.ScaleType = Enum.ScaleType.Fit
        eImage.Parent = bankBillboard

        -- ============================================
        -- Boton clickable en ScreenGui (sigue al banco en pantalla)
        -- BillboardGui no recibe touch en movil de forma confiable, por eso usamos ScreenGui
        -- ============================================
        local camera = Workspace.CurrentCamera
        local bankClickBtn = Instance.new("TextButton")
        bankClickBtn.Name = "BankClickBtn"
        bankClickBtn.Size = UDim2.new(0, 100, 0, 100)
        bankClickBtn.Position = UDim2.new(0.5, -50, 0.5, -50) -- se actualiza en el loop
        bankClickBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bankClickBtn.BackgroundTransparency = 1 -- totalmente transparente
        bankClickBtn.BorderSizePixel = 0
        bankClickBtn.Text = ""
        bankClickBtn.Visible = false
        bankClickBtn.ZIndex = 100
        bankClickBtn.Parent = screenGui

        -- Imagen E dentro del boton ScreenGui (se ve igual que el billboard)
        local screenEImage = Instance.new("ImageLabel")
        screenEImage.Size = UDim2.new(1, 0, 1, 0)
        screenEImage.BackgroundTransparency = 1
        screenEImage.Image = "rbxassetid://78972021775884"
        screenEImage.ScaleType = Enum.ScaleType.Fit
        screenEImage.Parent = bankClickBtn

        bankClickBtn.MouseButton1Click:Connect(function()
                if nearBank then
                        if bankPanelOpen then
                                closeBankPanel()
                        else
                                openBankPanel()
                        end
                end
        end)

        print("[BankSystem] Part ancla del banco creado en " .. tostring(BANK_POSITION))

        -- ============================================
        -- Panel de banco
        -- ============================================
        local bankPanel = Instance.new("Frame")
        bankPanel.Name = "BankPanel"
        bankPanel.Size = UDim2.new(0, 400, 0, 380)
        bankPanel.Position = UDim2.new(0.5, -200, 1, -400)
        bankPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        bankPanel.BackgroundTransparency = 0.05
        bankPanel.BorderSizePixel = 0
        bankPanel.Visible = false
        bankPanel.ZIndex = 50
        bankPanel.Parent = screenGui
        Instance.new("UICorner", bankPanel).CornerRadius = UDim.new(0, 16)

        local bankStroke = Instance.new("UIStroke")
        bankStroke.Color = Color3.fromRGB(100, 220, 100) -- verde (dinero)
        bankStroke.Thickness = 2
        bankStroke.Transparency = 0.2
        bankStroke.Parent = bankPanel

        -- Boton X para cerrar
        local bankCloseBtn = Instance.new("TextButton")
        bankCloseBtn.Name = "BankCloseBtn"
        bankCloseBtn.Size = UDim2.new(0, 30, 0, 30)
        bankCloseBtn.Position = UDim2.new(1, -35, 0, 5)
        bankCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        bankCloseBtn.BorderSizePixel = 0
        bankCloseBtn.Text = "X"
        bankCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        bankCloseBtn.TextScaled = true
        bankCloseBtn.Font = Enum.Font.GothamBold
        bankCloseBtn.ZIndex = 52
        bankCloseBtn.Parent = bankPanel
        Instance.new("UICorner", bankCloseBtn).CornerRadius = UDim.new(0, 8)

        -- Titulo
        local bankTitle = Instance.new("TextLabel")
        bankTitle.Size = UDim2.new(1, 0, 0, 40)
        bankTitle.BackgroundTransparency = 1
        bankTitle.Text = "🏦 BANCO"
        bankTitle.TextColor3 = Color3.fromRGB(100, 220, 100)
        bankTitle.TextScaled = true
        bankTitle.Font = Enum.Font.GothamBlack
        bankTitle.ZIndex = 51
        bankTitle.Parent = bankPanel

        -- Saldo del banco
        local balanceLabel = Instance.new("TextLabel")
        balanceLabel.Size = UDim2.new(1, -20, 0, 40)
        balanceLabel.Position = UDim2.new(0, 10, 0, 50)
        balanceLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        balanceLabel.BorderSizePixel = 0
        balanceLabel.Text = "Saldo en banco: $0"
        balanceLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
        balanceLabel.TextScaled = true
        balanceLabel.Font = Enum.Font.GothamBold
        balanceLabel.ZIndex = 51
        balanceLabel.Parent = bankPanel
        Instance.new("UICorner", balanceLabel).CornerRadius = UDim.new(0, 8)

        -- Dinero del jugador
        local moneyLabel = Instance.new("TextLabel")
        moneyLabel.Size = UDim2.new(1, -20, 0, 40)
        moneyLabel.Position = UDim2.new(0, 10, 0, 100)
        moneyLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        moneyLabel.BorderSizePixel = 0
        moneyLabel.Text = "Dinero contigo: $0"
        moneyLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        moneyLabel.TextScaled = true
        moneyLabel.Font = Enum.Font.GothamBold
        moneyLabel.ZIndex = 51
        moneyLabel.Parent = bankPanel
        Instance.new("UICorner", moneyLabel).CornerRadius = UDim.new(0, 8)

        -- Input de cantidad
        local amountInput = Instance.new("TextBox")
        amountInput.Name = "AmountInput"
        amountInput.Size = UDim2.new(1, -20, 0, 50)
        amountInput.Position = UDim2.new(0, 10, 0, 160)
        amountInput.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        amountInput.BorderSizePixel = 0
        amountInput.Text = ""
        amountInput.PlaceholderText = "Ingresa la cantidad..."
        amountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        amountInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
        amountInput.TextScaled = true
        amountInput.Font = Enum.Font.GothamBold
        amountInput.ClearTextOnFocus = false
        amountInput.ZIndex = 51
        amountInput.Parent = bankPanel
        Instance.new("UICorner", amountInput).CornerRadius = UDim.new(0, 8)

        -- Solo permitir numeros en el input
        amountInput:GetPropertyChangedSignal("Text"):Connect(function()
                local text = amountInput.Text
                -- Filtrar solo digitos
                local cleaned = string.gsub(text, "[^0-9]", "")
                if cleaned ~= text then
                        amountInput.Text = cleaned
                end
        end)

        -- Boton Depositar
        local depositBtn = Instance.new("TextButton")
        depositBtn.Size = UDim2.new(0.48, -5, 0, 50)
        depositBtn.Position = UDim2.new(0, 10, 0, 230)
        depositBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
        depositBtn.BorderSizePixel = 0
        depositBtn.Text = "Depositar"
        depositBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        depositBtn.TextScaled = true
        depositBtn.Font = Enum.Font.GothamBold
        depositBtn.ZIndex = 51
        depositBtn.Parent = bankPanel
        Instance.new("UICorner", depositBtn).CornerRadius = UDim.new(0, 8)

        -- Boton Retirar
        local withdrawBtn = Instance.new("TextButton")
        withdrawBtn.Size = UDim2.new(0.48, -5, 0, 50)
        withdrawBtn.Position = UDim2.new(0.52, 5, 0, 230)
        withdrawBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 80)
        withdrawBtn.BorderSizePixel = 0
        withdrawBtn.Text = "Retirar"
        withdrawBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        withdrawBtn.TextScaled = true
        withdrawBtn.Font = Enum.Font.GothamBold
        withdrawBtn.ZIndex = 51
        withdrawBtn.Parent = bankPanel
        Instance.new("UICorner", withdrawBtn).CornerRadius = UDim.new(0, 8)

        -- Boton Depositar Todo
        local depositAllBtn = Instance.new("TextButton")
        depositAllBtn.Size = UDim2.new(0.48, -5, 0, 40)
        depositAllBtn.Position = UDim2.new(0, 10, 0, 295)
        depositAllBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 80)
        depositAllBtn.BorderSizePixel = 0
        depositAllBtn.Text = "Depositar Todo"
        depositAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        depositAllBtn.TextScaled = true
        depositAllBtn.Font = Enum.Font.GothamBold
        depositAllBtn.ZIndex = 51
        depositAllBtn.Parent = bankPanel
        Instance.new("UICorner", depositAllBtn).CornerRadius = UDim.new(0, 8)

        -- Boton Retirar Todo
        local withdrawAllBtn = Instance.new("TextButton")
        withdrawAllBtn.Size = UDim2.new(0.48, -5, 0, 40)
        withdrawAllBtn.Position = UDim2.new(0.52, 5, 0, 295)
        withdrawAllBtn.BackgroundColor3 = Color3.fromRGB(130, 70, 60)
        withdrawAllBtn.BorderSizePixel = 0
        withdrawAllBtn.Text = "Retirar Todo"
        withdrawAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        withdrawAllBtn.TextScaled = true
        withdrawAllBtn.Font = Enum.Font.GothamBold
        withdrawAllBtn.ZIndex = 51
        withdrawAllBtn.Parent = bankPanel
        Instance.new("UICorner", withdrawAllBtn).CornerRadius = UDim.new(0, 8)

        -- Boton Cerrar (abajo)
        local closeBottomBtn = Instance.new("TextButton")
        closeBottomBtn.Size = UDim2.new(1, -20, 0, 40)
        closeBottomBtn.Position = UDim2.new(0, 10, 0, 340)
        closeBottomBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
        closeBottomBtn.BorderSizePixel = 0
        closeBottomBtn.Text = "Cerrar"
        closeBottomBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBottomBtn.TextScaled = true
        closeBottomBtn.Font = Enum.Font.GothamBold
        closeBottomBtn.ZIndex = 51
        closeBottomBtn.Parent = bankPanel
        Instance.new("UICorner", closeBottomBtn).CornerRadius = UDim.new(0, 8)

        -- ============================================
        -- Funciones
        -- ============================================

function openBankPanel()
                bankPanelOpen = true
                bankPanel.Visible = true
                -- Cerrar otros paneles
                if backpackPanel then backpackPanel.Visible = false end
                if musicPanel then musicPanel.Visible = false end
                -- buildPanel se maneja dentro de BuildSystem, no lo cerramos aqui
                -- Pedir actualizacion de saldo al servidor
                -- (el servidor enviara BankUIUpdate con balance y money actuales)
                -- Por ahora usamos los valores que tenemos
                updateBankUI()
        end

function closeBankPanel()
                bankPanelOpen = false
                bankPanel.Visible = false
                amountInput.Text = ""
        end

function updateBankUI()
                balanceLabel.Text = "Saldo en banco: $" .. formatMoney(bankBalance)
                moneyLabel.Text = "Dinero contigo: $" .. formatMoney(playerMoney)
        end

        -- Formato de dinero (K, M, B, T)
function formatMoney(amount)
                amount = amount or 0
                if amount >= 1000000000000 then
                        return string.format("%.1fT", amount / 1000000000000)
                elseif amount >= 1000000000 then
                        return string.format("%.1fB", amount / 1000000000)
                elseif amount >= 1000000 then
                        return string.format("%.1fM", amount / 1000000)
                elseif amount >= 10000 then
                        return string.format("%.1fK", amount / 1000)
                else
                        return tostring(amount)
                end
        end

        -- Obtener cantidad del input
        local function getAmount()
                local text = amountInput.Text
                local amount = tonumber(text)
                if not amount or amount <= 0 then
                        return nil
                end
                return math.floor(amount)
        end

        -- ============================================
        -- Handlers de botones
        -- ============================================

        depositBtn.MouseButton1Click:Connect(function()
                local amount = getAmount()
                if not amount then
                        amountInput.Text = ""
                        return
                end
                DepositMoneyEvent:FireServer(amount)
                amountInput.Text = ""
        end)

        withdrawBtn.MouseButton1Click:Connect(function()
                local amount = getAmount()
                if not amount then
                        amountInput.Text = ""
                        return
                end
                WithdrawMoneyEvent:FireServer(amount)
                amountInput.Text = ""
        end)

        depositAllBtn.MouseButton1Click:Connect(function()
                if playerMoney > 0 then
                        DepositMoneyEvent:FireServer(playerMoney)
                        amountInput.Text = ""
                end
        end)

        withdrawAllBtn.MouseButton1Click:Connect(function()
                if bankBalance > 0 then
                        WithdrawMoneyEvent:FireServer(bankBalance)
                        amountInput.Text = ""
                end
        end)

        bankCloseBtn.MouseButton1Click:Connect(function()
                closeBankPanel()
        end)

        closeBottomBtn.MouseButton1Click:Connect(function()
                closeBankPanel()
        end)

        -- ============================================
        -- Recepcion de eventos del servidor
        -- ============================================

        BankUIUpdateEvent.OnClientEvent:Connect(function(balance, money)
                bankBalance = balance or 0
                playerMoney = money or 0
                updateBankUI()
        end)

        -- Tambien actualizar cuando llega MoneyUpdate (dinero del jugador cambia)
        local MoneyUpdateEvent = ReplicatedStorage:WaitForChild("MoneyUpdate", 15)
        MoneyUpdateEvent.OnClientEvent:Connect(function(amount)
                playerMoney = amount or 0
                if bankPanelOpen then
                        updateBankUI()
                end
        end)

        -- Detectar si es movil
        local isMobileBank = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

        -- ============================================
        -- Deteccion de proximidad + input E
        -- ============================================

        -- Loop para detectar proximidad al banco
        RunService.Heartbeat:Connect(function()
                if not bankPart or not bankPart.Parent then return end
                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local dist = (root.Position - bankPart.Position).Magnitude
                nearBank = dist < BANK_INTERACT_DISTANCE

                -- Ocultar billboard original (usamos el boton ScreenGui en su lugar)
                if bankBillboard then
                        bankBillboard.Enabled = false
                end

                -- Posicionar y mostrar/ocultar el boton ScreenGui
                if nearBank and not bankPanelOpen then
                        -- Convertir posicion del banco a coordenadas de pantalla
                        local screenPos, onScreen = camera:WorldToViewportPoint(bankPart.Position + Vector3.new(0, 3, 0))
                        if onScreen then
                                bankClickBtn.Visible = true
                                -- Centrar el boton en la posicion del banco en pantalla
                                bankClickBtn.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y - 50)
                        else
                                bankClickBtn.Visible = false
                        end
                else
                        bankClickBtn.Visible = false
                end
        end)

        -- Input E para abrir banco (PC)
        UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == Enum.KeyCode.E then
                        if nearBank then
                                if bankPanelOpen then
                                        closeBankPanel()
                                else
                                        openBankPanel()
                                end
                        end
                end
        end)

        print("[BankSystem] Sistema de banco cargado!")
end

return BankSystem

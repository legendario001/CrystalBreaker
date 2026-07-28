-- ============================================
-- DonationLeaderboardSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Crea un SurfaceGui en el TablaDonadores.LeaderboardScreen con el TOP 3 DONADORES
-- Muestra nombre y robux donado
--
-- Modelo esperado en Workspace: "TablaDonadores"
--   - Part "LeaderboardScreen" (size 10.9, 14.8, 0.1; pos 146.169, 10, 100.85; orient 0, 90, 0)
-- ============================================

local DonationLeaderboardSystem = {}

function DonationLeaderboardSystem.init(deps)
        local player = deps.player
        local screenGui = deps.screenGui
        local Workspace = deps.Workspace
        local ReplicatedStorage = deps.ReplicatedStorage

        -- Evento del servidor
        local DonationLeaderboardUpdateEvent = ReplicatedStorage:WaitForChild("DonationLeaderboardUpdate", 15)

        -- ============================================
        -- Encontrar el TablaDonadores.LeaderboardScreen
        -- ============================================
        local function findDonationScreen()
                local tablaModel = Workspace:FindFirstChild("TablaDonadores")
                if not tablaModel then return nil end
                return tablaModel:FindFirstChild("LeaderboardScreen")
        end

        local function ensureDonationScreen()
                local screen = findDonationScreen()
                if screen then return screen end

                -- Crear Part invisible en la posicion definida (fallback)
                screen = Instance.new("Part")
                screen.Name = "LeaderboardScreen"
                screen.Size = Vector3.new(10.9, 14.8, 0.1)
                screen.Position = Vector3.new(146.169, 10, 100.85)
                screen.Orientation = Vector3.new(0, 90, 0)
                screen.Anchored = true
                screen.CanCollide = false
                screen.Transparency = 1
                screen.Parent = Workspace

                local tablaModel = Workspace:FindFirstChild("TablaDonadores")
                if tablaModel then
                        screen.Parent = tablaModel
                end
                return screen
        end

        -- ============================================
        -- Formato de robux (K, M)
        -- ============================================
        local function formatRobux(amount)
                amount = amount or 0
                if amount >= 1000000 then
                        return string.format("%.1fM", amount / 1000000)
                elseif amount >= 1000 then
                        return string.format("%.1fK", amount / 1000)
                else
                        return tostring(amount)
                end
        end

        -- ============================================
        -- Crear SurfaceGui
        -- ============================================
        local screen = ensureDonationScreen()

        local surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Name = "DonationLeaderboardGui"
        -- El Part tiene orientacion (0, 90, 0). Probamos Front primero; si se ve al reves, cambiar a Back.
        surfaceGui.Face = Enum.NormalId.Front
        surfaceGui.CanvasSize = Vector2.new(800, 1000)
        surfaceGui.LightInfluence = 0
        surfaceGui.MaxDistance = 200
        surfaceGui.Parent = screen

        -- Fondo principal
        local background = Instance.new("Frame")
        background.Name = "Background"
        background.Size = UDim2.new(1, 0, 1, 0)
        background.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        background.BackgroundTransparency = 0.1
        background.BorderSizePixel = 0
        background.Parent = surfaceGui
        Instance.new("UICorner", background).CornerRadius = UDim.new(0, 20)

        -- Borde dorado
        local borderStroke = Instance.new("UIStroke")
        borderStroke.Color = Color3.fromRGB(255, 215, 0)
        borderStroke.Thickness = 6
        borderStroke.Transparency = 0.1
        borderStroke.Parent = background

        -- Titulo
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -40, 0, 100)
        titleLabel.Position = UDim2.new(0, 20, 0, 20)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "💖 TOP 3 DONADORES 💖"
        titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.Parent = background

        local titleStroke = Instance.new("UIStroke", titleLabel)
        titleStroke.Color = Color3.fromRGB(0, 0, 0)
        titleStroke.Thickness = 3
        titleStroke.Transparency = 0.3

        -- Contenedor de entradas
        local entriesContainer = Instance.new("Frame")
        entriesContainer.Name = "Entries"
        entriesContainer.Size = UDim2.new(1, -40, 1, -140)
        entriesContainer.Position = UDim2.new(0, 20, 0, 120)
        entriesContainer.BackgroundTransparency = 1
        entriesContainer.Parent = background

        local listLayout = Instance.new("UIListLayout", entriesContainer)
        listLayout.Padding = UDim.new(0, 15)
        listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- ============================================
        -- Crear/actualizar entradas
        -- ============================================
        local function updateEntries(top3)
                -- Limpiar
                for _, child in ipairs(entriesContainer:GetChildren()) do
                        if child:IsA("Frame") then child:Destroy() end
                end

                if not top3 or #top3 == 0 then
                        local empty = Instance.new("TextLabel")
                        empty.Size = UDim2.new(1, 0, 0, 80)
                        empty.BackgroundTransparency = 1
                        empty.Text = "Sé el primero en donar!"
                        empty.TextColor3 = Color3.fromRGB(180, 180, 180)
                        empty.TextScaled = true
                        empty.Font = Enum.Font.GothamMedium
                        empty.Parent = entriesContainer
                        return
                end

                for i, entry in ipairs(top3) do
                        local entryFrame = Instance.new("Frame")
                        entryFrame.Name = "Entry_" .. i
                        entryFrame.Size = UDim2.new(1, 0, 0, 120)
                        entryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                        entryFrame.BackgroundTransparency = 0.2
                        entryFrame.BorderSizePixel = 0
                        entryFrame.LayoutOrder = i
                        entryFrame.Parent = entriesContainer
                        Instance.new("UICorner", entryFrame).CornerRadius = UDim.new(0, 15)

                        -- Borde de color segun rango
                        local entryStroke = Instance.new("UIStroke", entryFrame)
                        if i == 1 then
                                entryStroke.Color = Color3.fromRGB(255, 215, 0)  -- oro
                        elseif i == 2 then
                                entryStroke.Color = Color3.fromRGB(192, 192, 192)  -- plata
                        else
                                entryStroke.Color = Color3.fromRGB(205, 127, 50)  -- bronce
                        end
                        entryStroke.Thickness = 4

                        -- Rango
                        local rankLabel = Instance.new("TextLabel")
                        rankLabel.Size = UDim2.new(0, 100, 1, 0)
                        rankLabel.Position = UDim2.new(0, 10, 0, 0)
                        rankLabel.BackgroundTransparency = 1
                        rankLabel.Text = "#" .. i
                        rankLabel.TextColor3 = entryStroke.Color
                        rankLabel.TextScaled = true
                        rankLabel.Font = Enum.Font.GothamBlack
                        rankLabel.Parent = entryFrame

                        -- Nombre
                        local nameLabel = Instance.new("TextLabel")
                        nameLabel.Size = UDim2.new(1, -250, 0.5, 0)
                        nameLabel.Position = UDim2.new(0, 120, 0, 10)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.Text = entry.name or "Donador"
                        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                        nameLabel.TextScaled = true
                        nameLabel.Font = Enum.Font.GothamBold
                        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                        nameLabel.Parent = entryFrame

                        -- Cantidad donada
                        local amountLabel = Instance.new("TextLabel")
                        amountLabel.Size = UDim2.new(1, -250, 0.5, 0)
                        amountLabel.Position = UDim2.new(0, 120, 0.5, 0)
                        amountLabel.BackgroundTransparency = 1
                        amountLabel.Text = formatRobux(entry.amount) .. " R$"
                        amountLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
                        amountLabel.TextScaled = true
                        amountLabel.Font = Enum.Font.GothamBold
                        amountLabel.TextXAlignment = Enum.TextXAlignment.Left
                        amountLabel.Parent = entryFrame
                end
        end

        -- Recibir actualizaciones del servidor
        if DonationLeaderboardUpdateEvent then
                DonationLeaderboardUpdateEvent.OnClientEvent:Connect(function(top3)
                        updateEntries(top3)
                end)
        end

        print("[DonationLeaderboardSystem] SurfaceGui del top 3 donadores creado")
end

return DonationLeaderboardSystem

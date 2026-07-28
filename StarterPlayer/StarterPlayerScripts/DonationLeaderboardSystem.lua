-- ============================================
-- DonationLeaderboardSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Crea un SurfaceGui en el TablaDonadores.LeaderboardScreen con el TOP 20 DONADORES
-- Muestra: numero, cara (headshot), nombre y robux donado
-- 2 paginas de 10 jugadores cada una
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
        local Players = game:GetService("Players")

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
                if tablaModel then screen.Parent = tablaModel end
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
        surfaceGui.Face = Enum.NormalId.Front
        surfaceGui.CanvasSize = Vector2.new(1200, 1500)
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

        local borderStroke = Instance.new("UIStroke", background)
        borderStroke.Color = Color3.fromRGB(255, 215, 0)
        borderStroke.Thickness = 6
        borderStroke.Transparency = 0.1

        -- Titulo
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -40, 0, 100)
        titleLabel.Position = UDim2.new(0, 20, 0, 20)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "💖 TOP 20 DONADORES 💖"
        titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.Parent = background

        local titleStroke = Instance.new("UIStroke", titleLabel)
        titleStroke.Color = Color3.fromRGB(0, 0, 0)
        titleStroke.Thickness = 3
        titleStroke.Transparency = 0.3

        -- Contenedor de entradas (10 por pagina)
        local entriesContainer = Instance.new("Frame")
        entriesContainer.Name = "Entries"
        entriesContainer.Size = UDim2.new(1, -40, 1, -260)
        entriesContainer.Position = UDim2.new(0, 20, 0, 130)
        entriesContainer.BackgroundTransparency = 1
        entriesContainer.Parent = background

        local listLayout = Instance.new("UIListLayout", entriesContainer)
        listLayout.Padding = UDim.new(0, 5)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- Botones de pagina (1 y 2)
        local pageBtnContainer = Instance.new("Frame")
        pageBtnContainer.Name = "PageButtons"
        pageBtnContainer.Size = UDim2.new(0, 300, 0, 80)
        pageBtnContainer.Position = UDim2.new(0.5, -150, 1, -100)
        pageBtnContainer.BackgroundTransparency = 1
        pageBtnContainer.Parent = background

        local page1Btn = Instance.new("TextButton")
        page1Btn.Size = UDim2.new(0, 130, 0, 70)
        page1Btn.Position = UDim2.new(0, 0, 0, 5)
        page1Btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        page1Btn.Text = "Pag 1"
        page1Btn.Font = Enum.Font.GothamBold
        page1Btn.TextSize = 24
        page1Btn.TextColor3 = Color3.fromRGB(20, 20, 30)
        page1Btn.BorderSizePixel = 0
        page1Btn.Parent = pageBtnContainer
        Instance.new("UICorner", page1Btn).CornerRadius = UDim.new(0, 10)

        local page2Btn = Instance.new("TextButton")
        page2Btn.Size = UDim2.new(0, 130, 0, 70)
        page2Btn.Position = UDim2.new(1, -130, 0, 5)
        page2Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        page2Btn.Text = "Pag 2"
        page2Btn.Font = Enum.Font.GothamBold
        page2Btn.TextSize = 24
        page2Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        page2Btn.BorderSizePixel = 0
        page2Btn.Parent = pageBtnContainer
        Instance.new("UICorner", page2Btn).CornerRadius = UDim.new(0, 10)

        -- ============================================
        -- Estado
        -- ============================================
        local leaderboardData = {}
        local currentPage = 1

        -- ============================================
        -- Crear una entrada de la lista
        -- ============================================
        local function createEntry(index, entry, startIndex)
                local rank = startIndex + index - 1
                local entryFrame = Instance.new("Frame")
                entryFrame.Name = "Entry_" .. rank
                entryFrame.Size = UDim2.new(1, 0, 0, 100)
                entryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                entryFrame.BackgroundTransparency = 0.2
                entryFrame.BorderSizePixel = 0
                entryFrame.LayoutOrder = index
                entryFrame.Parent = entriesContainer
                Instance.new("UICorner", entryFrame).CornerRadius = UDim.new(0, 10)

                -- Borde de color segun rango (top 3: oro/plata/bronce)
                local entryStroke = Instance.new("UIStroke", entryFrame)
                if rank == 1 then
                        entryStroke.Color = Color3.fromRGB(255, 215, 0)
                        entryStroke.Thickness = 4
                elseif rank == 2 then
                        entryStroke.Color = Color3.fromRGB(192, 192, 192)
                        entryStroke.Thickness = 4
                elseif rank == 3 then
                        entryStroke.Color = Color3.fromRGB(205, 127, 50)
                        entryStroke.Thickness = 4
                else
                        entryStroke.Color = Color3.fromRGB(60, 60, 70)
                        entryStroke.Thickness = 2
                        entryStroke.Transparency = 0.5
                end

                -- Numero de rango
                local rankLabel = Instance.new("TextLabel")
                rankLabel.Size = UDim2.new(0, 80, 1, 0)
                rankLabel.Position = UDim2.new(0, 10, 0, 0)
                rankLabel.BackgroundTransparency = 1
                rankLabel.Text = "#" .. rank
                rankLabel.TextColor3 = entryStroke.Color
                rankLabel.TextScaled = true
                rankLabel.Font = Enum.Font.GothamBlack
                rankLabel.Parent = entryFrame

                -- Cara del jugador (headshot via ImageLabel)
                local faceLabel = Instance.new("ImageLabel")
                faceLabel.Size = UDim2.new(0, 80, 0, 80)
                faceLabel.Position = UDim2.new(0, 100, 0.5, -40)
                faceLabel.BackgroundTransparency = 1
                faceLabel.BorderSizePixel = 0
                faceLabel.Image = ""  -- se setea abajo
                faceLabel.Parent = entryFrame

                local faceCorner = Instance.new("UICorner", faceLabel)
                faceCorner.CornerRadius = UDim.new(1, 0)  -- circular

                -- Cargar headshot del jugador
                if entry.userId then
                        pcall(function()
                                -- Usar Players:GetUserThumbnailAsync para el headshot
                                local thumbType = Enum.ThumbnailType.HeadShot
                                local thumbSize = Enum.ThumbnailSize.Size420x420
                                local ok, thumb = pcall(function()
                                        return Players:GetUserThumbnailAsync(entry.userId, thumbType, thumbSize)
                                end)
                                if ok and thumb then
                                        faceLabel.Image = thumb
                                end
                        end)
                end

                -- Nombre del jugador
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(0, 450, 1, 0)
                nameLabel.Position = UDim2.new(0, 200, 0, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = entry.name or "Donador"
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextScaled = true
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = entryFrame

                -- Cantidad donada
                local amountLabel = Instance.new("TextLabel")
                amountLabel.Size = UDim2.new(0, 350, 1, 0)
                amountLabel.Position = UDim2.new(1, -360, 0, 0)
                amountLabel.BackgroundTransparency = 1
                amountLabel.Text = formatRobux(entry.amount) .. " R$"
                amountLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
                amountLabel.TextScaled = true
                amountLabel.Font = Enum.Font.GothamBold
                amountLabel.TextXAlignment = Enum.TextXAlignment.Right
                amountLabel.Parent = entryFrame
        end

        -- ============================================
        -- Mostrar pagina actual (10 entradas)
        -- ============================================
        local function showPage(pageNum)
                -- Limpiar entradas anteriores (TODOS los hijos excepto UIListLayout)
                -- Antes solo se eliminaban Frames, pero el TextLabel "No hay mas donadores"
                -- de la pagina 2 vacia se quedaba ahi y tapaba las entradas al volver a pag 1.
                for _, child in ipairs(entriesContainer:GetChildren()) do
                        if child ~= listLayout then
                                child:Destroy()
                        end
                end

                local startIndex = (pageNum - 1) * 10 + 1
                local endIndex = math.min(startIndex + 9, #leaderboardData)

                if startIndex > #leaderboardData then
                        -- Pagina vacia
                        local empty = Instance.new("TextLabel")
                        empty.Size = UDim2.new(1, 0, 1, 0)
                        empty.BackgroundTransparency = 1
                        empty.Text = "No hay mas donadores"
                        empty.TextColor3 = Color3.fromRGB(150, 150, 150)
                        empty.TextScaled = true
                        empty.Font = Enum.Font.GothamMedium
                        empty.Parent = entriesContainer
                        return
                end

                local count = 0
                for i = startIndex, endIndex do
                        count = count + 1
                        createEntry(count, leaderboardData[i], startIndex)
                end
        end

        -- ============================================
        -- Botones de pagina
        -- ============================================
        local function updatePageButtons()
                if currentPage == 1 then
                        page1Btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                        page1Btn.TextColor3 = Color3.fromRGB(20, 20, 30)
                        page2Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                        page2Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
                else
                        page1Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                        page1Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
                        page2Btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                        page2Btn.TextColor3 = Color3.fromRGB(20, 20, 30)
                end
        end

        page1Btn.MouseButton1Click:Connect(function()
                currentPage = 1
                updatePageButtons()
                showPage(currentPage)
        end)

        page2Btn.MouseButton1Click:Connect(function()
                currentPage = 2
                updatePageButtons()
                showPage(currentPage)
        end)

        -- ============================================
        -- Recibir actualizaciones del servidor
        -- ============================================
        if DonationLeaderboardUpdateEvent then
                DonationLeaderboardUpdateEvent.OnClientEvent:Connect(function(top20)
                        leaderboardData = top20 or {}
                        showPage(currentPage)
                        updatePageButtons()
                end)
        end

        print("[DonationLeaderboardSystem] SurfaceGui del top 20 donadores creado (2 paginas)")
end

return DonationLeaderboardSystem

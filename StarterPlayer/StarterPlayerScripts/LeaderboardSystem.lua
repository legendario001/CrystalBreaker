-- ============================================
-- LeaderboardSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Crea un SurfaceGui en el LeaderboardScreen con el top 30 de jugadores
-- Muestra cara, nombre y dinero (bankBalance)
-- 2 paginas de 15 jugadores cada una
-- ============================================

local LeaderboardSystem = {}

function LeaderboardSystem.init(deps)
	local player = deps.player
	local screenGui = deps.screenGui
	local Workspace = deps.Workspace
	local ReplicatedStorage = deps.ReplicatedStorage
	local Players = game:GetService("Players")

	-- Evento del servidor
	local LeaderboardUpdateEvent = ReplicatedStorage:WaitForChild("LeaderboardUpdate", 15)

	-- Posicion y tamaño del LeaderboardScreen
	local SCREEN_POSITION = Vector3.new(148.035, 10.4, 29.65)
	local SCREEN_SIZE = Vector3.new(12.5, 15.6, 0.1)

	-- Estado
	local leaderboardData = {} -- top 30 entries
	local currentPage = 1 -- 1 o 2

	-- ============================================
	-- Encontrar el LeaderboardScreen (Part frontal del pizarron)
	-- ============================================
	local function findLeaderboardScreen()
		local leaderboardModel = Workspace:FindFirstChild("LeaderBoard")
		if not leaderboardModel then return nil end
		-- Buscar por nombre
		local screen = leaderboardModel:FindFirstChild("LeaderboardScreen")
		if screen then return screen end
		-- Fallback: buscar por posicion cercana
		for _, obj in ipairs(leaderboardModel:GetDescendants()) do
			if obj:IsA("BasePart") then
				local dist = (obj.Position - SCREEN_POSITION).Magnitude
				if dist < 5 then
					return obj
				end
			end
		end
		return nil
	end

	-- Si no existe el Part, crearlo automaticamente
	local function ensureLeaderboardScreen()
		local screen = findLeaderboardScreen()
		if screen then return screen end

		-- Crear Part invisible en la posicion definida
		screen = Instance.new("Part")
		screen.Name = "LeaderboardScreen"
		screen.Size = SCREEN_SIZE
		screen.Position = SCREEN_POSITION
		screen.Orientation = Vector3.new(0, -90, 0)
		screen.Anchored = true
		screen.CanCollide = false
		screen.Transparency = 1
		screen.Parent = Workspace

		-- Si existe el modelo LeaderBoard, meterlo ahi
		local leaderboardModel = Workspace:FindFirstChild("LeaderBoard")
		if leaderboardModel then
			screen.Parent = leaderboardModel
		end

		print("[LeaderboardSystem] LeaderboardScreen creado automaticamente en " .. tostring(SCREEN_POSITION))
		return screen
	end

	-- ============================================
	-- Formato de dinero (K, M, B, T)
	-- ============================================
	local function formatMoney(amount)
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

	-- ============================================
	-- Crear SurfaceGui en el LeaderboardScreen
	-- ============================================
	local screen = ensureLeaderboardScreen()

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "LeaderboardGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(1200, 1500) -- resolucion del canvas
	surfaceGui.LightInfluence = 0
	surfaceGui.MaxDistance = 200 -- visible desde lejos
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
	titleLabel.Text = "🏆 TOP 30 RICOS 🏆"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = background

	-- Stroke del titulo
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 3
	titleStroke.Parent = titleLabel

	-- Contenedor de la lista (ScrollingFrame para 15 entradas)
	local listFrame = Instance.new("Frame")
	listFrame.Size = UDim2.new(1, -40, 1, -240)
	listFrame.Position = UDim2.new(0, 20, 0, 130)
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = background

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = listFrame

	-- Botones de pagina
	local page1Btn = Instance.new("TextButton")
	page1Btn.Size = UDim2.new(0.45, 0, 0, 70)
	page1Btn.Position = UDim2.new(0.05, 0, 1, -90)
	page1Btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	page1Btn.BorderSizePixel = 0
	page1Btn.Text = "Pagina 1"
	page1Btn.TextColor3 = Color3.fromRGB(0, 0, 0)
	page1Btn.TextScaled = true
	page1Btn.Font = Enum.Font.GothamBold
	page1Btn.Parent = background
	Instance.new("UICorner", page1Btn).CornerRadius = UDim.new(0, 10)

	local page2Btn = Instance.new("TextButton")
	page2Btn.Size = UDim2.new(0.45, 0, 0, 70)
	page2Btn.Position = UDim2.new(0.5, 0, 1, -90)
	page2Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	page2Btn.BorderSizePixel = 0
	page2Btn.Text = "Pagina 2"
	page2Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	page2Btn.TextScaled = true
	page2Btn.Font = Enum.Font.GothamBold
	page2Btn.Parent = background
	Instance.new("UICorner", page2Btn).CornerRadius = UDim.new(0, 10)

	-- ============================================
	-- Actualizar la lista visual
	-- ============================================
	local function updateList()
		-- Limpiar lista anterior
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		-- Determinar rango de jugadores a mostrar (15 por pagina)
		local startIdx = (currentPage - 1) * 15 + 1
		local endIdx = math.min(startIdx + 14, #leaderboardData)

		-- Crear entrada para cada jugador
		for i = startIdx, endIdx do
			local entry = leaderboardData[i]
			if not entry then break end

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 80)
			row.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			row.BorderSizePixel = 0
			row.Parent = listFrame
			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

			-- Color del borde segun el rango (oro, plata, bronce para top 3)
			local rowStroke = Instance.new("UIStroke")
			if i == 1 then
				rowStroke.Color = Color3.fromRGB(255, 215, 0) -- oro
				rowStroke.Thickness = 3
			elseif i == 2 then
				rowStroke.Color = Color3.fromRGB(192, 192, 192) -- plata
				rowStroke.Thickness = 3
			elseif i == 3 then
				rowStroke.Color = Color3.fromRGB(205, 127, 50) -- bronce
				rowStroke.Thickness = 3
			else
				rowStroke.Color = Color3.fromRGB(60, 60, 70)
				rowStroke.Thickness = 1
			end
			rowStroke.Parent = row

			-- Numero de rango
			local rankLabel = Instance.new("TextLabel")
			rankLabel.Size = UDim2.new(0, 80, 1, 0)
			rankLabel.BackgroundTransparency = 1
			rankLabel.Text = "#" .. i
			rankLabel.TextColor3 = (i <= 3) and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(200, 200, 200)
			rankLabel.TextScaled = true
			rankLabel.Font = Enum.Font.GothamBlack
			rankLabel.Parent = row

			-- Cara del jugador (ImageLabel)
			local faceImage = Instance.new("ImageLabel")
			faceImage.Size = UDim2.new(0, 70, 0, 70)
			faceImage.Position = UDim2.new(0, 90, 0.5, -35)
			faceImage.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			faceImage.BorderSizePixel = 0
			faceImage.Image = ""
			faceImage.Parent = row
			Instance.new("UICorner", faceImage).CornerRadius = UDim.new(1, 0) -- circular

			-- Cargar cara del jugador asincronamente
			task.spawn(function()
				local thumbType = Enum.ThumbnailType.HeadShot
				local thumbSize = Enum.ThumbnailSize.Size150x150
				local content, isReady = Players:GetUserThumbnailAsync(entry.userId, thumbType, thumbSize)
				if content and faceImage and faceImage.Parent then
					faceImage.Image = content
				end
			end)

			-- Nombre del jugador
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0, 500, 1, 0)
			nameLabel.Position = UDim2.new(0, 180, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = entry.name or "Jugador"
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = row

			-- Dinero (bankBalance)
			local moneyLabel = Instance.new("TextLabel")
			moneyLabel.Size = UDim2.new(0, 350, 1, 0)
			moneyLabel.Position = UDim2.new(1, -370, 0, 0)
			moneyLabel.BackgroundTransparency = 1
			moneyLabel.Text = "$" .. formatMoney(entry.balance)
			moneyLabel.TextColor3 = Color3.fromRGB(100, 220, 100) -- verde
			moneyLabel.TextScaled = true
			moneyLabel.Font = Enum.Font.GothamBlack
			moneyLabel.TextXAlignment = Enum.TextXAlignment.Right
			moneyLabel.Parent = row
		end

		-- Actualizar colores de botones de pagina
		if currentPage == 1 then
			page1Btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			page1Btn.TextColor3 = Color3.fromRGB(0, 0, 0)
			page2Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			page2Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			page1Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			page1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			page2Btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			page2Btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		end
	end

	-- ============================================
	-- Handlers de botones de pagina
	-- ============================================
	page1Btn.MouseButton1Click:Connect(function()
		currentPage = 1
		updateList()
	end)

	page2Btn.MouseButton1Click:Connect(function()
		currentPage = 2
		updateList()
	end)

	-- ============================================
	-- Recibir datos del leaderboard desde el servidor
	-- ============================================
	LeaderboardUpdateEvent.OnClientEvent:Connect(function(data)
		leaderboardData = data or {}
		updateList()
		print("[LeaderboardSystem] Datos recibidos: " .. #leaderboardData .. " jugadores")
	end)

	print("[LeaderboardSystem] Sistema de leaderboard cargado!")
end

return LeaderboardSystem

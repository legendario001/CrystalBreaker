-- ============================================
-- RebirthSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Boton "Renacer" al lado de la mochila + interfaz con requisitos y conteo.
-- Muestra el bonus total del jugador en pantalla.
-- ============================================

local RebirthSystem = {}

function RebirthSystem.init(deps)
	local player = deps.player
	local screenGui = deps.screenGui
	local ReplicatedStorage = deps.ReplicatedStorage
	local UserInputService = game:GetService("UserInputService")

	local RebirthRequest = ReplicatedStorage:WaitForChild("RebirthRequest", 15)
	local RebirthUpdate = ReplicatedStorage:WaitForChild("RebirthUpdate", 15)

	-- Estado local
	local myRebirthLevel = 0
	local myBoostLevel = 0
	local brainrotCount = 0
	local requiredRarity = "Comun"
	local isProcessing = false

	-- ============================================
	-- Etiqueta de bonus en pantalla (esquina inferior derecha)
	-- ============================================
	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Name = "RebirthBonusLabel"
	bonusLabel.Size = UDim2.new(0, 200, 0, 40)
	bonusLabel.Position = UDim2.new(1, -220, 0, 20)  -- esquina superior derecha
	bonusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	bonusLabel.BackgroundTransparency = 0.3
	bonusLabel.BorderSizePixel = 0
	bonusLabel.Text = "Bonus: +0%"
	bonusLabel.Font = Enum.Font.GothamBold
	bonusLabel.TextSize = 18
	bonusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	bonusLabel.Parent = screenGui
	Instance.new("UICorner", bonusLabel).CornerRadius = UDim.new(0, 8)

	local bonusStroke = Instance.new("UIStroke", bonusLabel)
	bonusStroke.Color = Color3.fromRGB(0, 0, 0)
	bonusStroke.Thickness = 3

	-- ============================================
	-- Boton "Renacer" (al lado derecho de la mochila)
	-- Mochila esta en Position(0, 20, 1, -200), Size 60x60
	-- Ponemos renacer a la derecha: Position(0, 90, 1, -200)
	-- ============================================
	local rebirthBtn = Instance.new("TextButton")
	rebirthBtn.Name = "RebirthBtn"
	rebirthBtn.Size = UDim2.new(0, 60, 0, 60)
	rebirthBtn.Position = UDim2.new(0, 90, 1, -200)  -- a la derecha de la mochila
	rebirthBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 120)  -- morado oscuro
	rebirthBtn.BorderSizePixel = 0
	rebirthBtn.Text = ""
	rebirthBtn.Parent = screenGui
	Instance.new("UICorner", rebirthBtn).CornerRadius = UDim.new(0, 12)

	local rebirthStroke = Instance.new("UIStroke", rebirthBtn)
	rebirthStroke.Color = Color3.fromRGB(180, 80, 255)
	rebirthStroke.Thickness = 3

	-- Icono del boton renacer
	local rebirthIcon = Instance.new("ImageLabel")
	rebirthIcon.Size = UDim2.new(0.7, 0, 0.7, 0)
	rebirthIcon.Position = UDim2.new(0.15, 0, 0.15, 0)
	rebirthIcon.BackgroundTransparency = 1
	rebirthIcon.Image = "rbxassetid://99418679601643"
	rebirthIcon.ScaleType = Enum.ScaleType.Fit
	rebirthIcon.Parent = rebirthBtn

	-- ============================================
	-- Panel de Renacimiento (modal)
	-- ============================================
	local rebirthPanel = Instance.new("Frame")
	rebirthPanel.Name = "RebirthPanel"
	rebirthPanel.Size = UDim2.new(0, 500, 0, 600)
	rebirthPanel.Position = UDim2.new(0.5, -250, 0.5, -300)
	rebirthPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	rebirthPanel.BackgroundTransparency = 0.05
	rebirthPanel.BorderSizePixel = 0
	rebirthPanel.Visible = false
	rebirthPanel.Parent = screenGui
	Instance.new("UICorner", rebirthPanel).CornerRadius = UDim.new(0, 15)

	local panelStroke = Instance.new("UIStroke", rebirthPanel)
	panelStroke.Color = Color3.fromRGB(180, 80, 255)
	panelStroke.Thickness = 4

	-- Titulo
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -40, 0, 60)
	titleLabel.Position = UDim2.new(0, 20, 0, 15)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🔄 RENACIMIENTO"
	titleLabel.TextColor3 = Color3.fromRGB(180, 80, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = rebirthPanel

	-- Boton cerrar
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = rebirthPanel
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

	-- ============================================
	-- Instrucciones / Requisitos
	-- ============================================
	local instructionsLabel = Instance.new("TextLabel")
	instructionsLabel.Name = "Instructions"
	instructionsLabel.Size = UDim2.new(1, -40, 0, 120)
	instructionsLabel.Position = UDim2.new(0, 20, 0, 85)
	instructionsLabel.BackgroundTransparency = 1
	instructionsLabel.Text = "Para renacer, debes llenar los 5 pisos de tu base con 50 brainrots de la rareza indicada.\n\nCada renacimiento te da +20% de ganancias permanentes y se acumula con tus mejoras compradas."
	instructionsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	instructionsLabel.TextWrapped = true
	instructionsLabel.TextScaled = true
	instructionsLabel.Font = Enum.Font.GothamMedium
	instructionsLabel.TextYAlignment = Enum.TextYAlignment.Top
	instructionsLabel.Parent = rebirthPanel

	-- ============================================
	-- Tabla de niveles de renacimiento
	-- ============================================
	local levelsFrame = Instance.new("Frame")
	levelsFrame.Name = "LevelsTable"
	levelsFrame.Size = UDim2.new(1, -40, 0, 200)
	levelsFrame.Position = UDim2.new(0, 20, 0, 215)
	levelsFrame.BackgroundTransparency = 1
	levelsFrame.Parent = rebirthPanel

	local levelsLayout = Instance.new("UIListLayout", levelsFrame)
	levelsLayout.Padding = UDim.new(0, 5)

	local levelInfo = {
		{rarity = "Comun", color = Color3.fromRGB(220, 220, 220)},
		{rarity = "Incomun", color = Color3.fromRGB(100, 200, 255)},
		{rarity = "Raro", color = Color3.fromRGB(255, 215, 0)},
		{rarity = "Epico", color = Color3.fromRGB(255, 80, 80)},
		{rarity = "Mitico", color = Color3.fromRGB(180, 80, 255)},
	}

	for i, info in ipairs(levelInfo) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Parent = levelsFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local stroke = Instance.new("UIStroke", row)
		stroke.Color = info.color
		stroke.Thickness = 2
		stroke.Transparency = 0.5

		local levelText = Instance.new("TextLabel")
		levelText.Size = UDim2.new(1, -10, 1, 0)
		levelText.Position = UDim2.new(0, 10, 0, 0)
		levelText.BackgroundTransparency = 1
		levelText.Text = "Renacimiento " .. i .. ": 50x " .. info.rarity .. "  →  +" .. (i * 20) .. "% total"
		levelText.TextColor3 = info.color
		levelText.TextScaled = true
		levelText.Font = Enum.Font.GothamBold
		levelText.TextXAlignment = Enum.TextXAlignment.Left
		levelText.Parent = row
	end

	-- ============================================
	-- Conteo en tiempo real
	-- ============================================
	local countFrame = Instance.new("Frame")
	countFrame.Name = "CountFrame"
	countFrame.Size = UDim2.new(1, -40, 0, 60)
	countFrame.Position = UDim2.new(0, 20, 0, 425)
	countFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	countFrame.BackgroundTransparency = 0.2
	countFrame.BorderSizePixel = 0
	countFrame.Parent = rebirthPanel
	Instance.new("UICorner", countFrame).CornerRadius = UDim.new(0, 10)

	local countStroke = Instance.new("UIStroke", countFrame)
	countStroke.Color = Color3.fromRGB(180, 80, 255)
	countStroke.Thickness = 3

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, -20, 1, 0)
	countLabel.Position = UDim2.new(0, 10, 0, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "0 / 50 brainrots requeridos"
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextScaled = true
	countLabel.Font = Enum.Font.GothamBold
	countLabel.Parent = countFrame

	-- ============================================
	-- Boton RENACER (dentro del panel)
	-- ============================================
	local doRebirthBtn = Instance.new("TextButton")
	doRebirthBtn.Name = "DoRebirthBtn"
	doRebirthBtn.Size = UDim2.new(0, 300, 0, 60)
	doRebirthBtn.Position = UDim2.new(0.5, -150, 1, -80)
	doRebirthBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 120)
	doRebirthBtn.BorderSizePixel = 0
	doRebirthBtn.Text = "RENACER"
	doRebirthBtn.Font = Enum.Font.GothamBlack
	doRebirthBtn.TextSize = 24
	doRebirthBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	doRebirthBtn.Parent = rebirthPanel
	Instance.new("UICorner", doRebirthBtn).CornerRadius = UDim.new(0, 12)

	local doRebirthStroke = Instance.new("UIStroke", doRebirthBtn)
	doRebirthStroke.Color = Color3.fromRGB(180, 80, 255)
	doRebirthStroke.Thickness = 3

	-- ============================================
	-- Funciones de UI
	-- ============================================
	local function updateCountDisplay()
		local count = brainrotCount
		local max = 50
		local rarity = requiredRarity or "?"

		-- Color del contador: rojo si < 50, verde si >= 50
		if count >= max then
			countLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			countLabel.Text = "✅ " .. count .. " / " .. max .. " brainrots " .. rarity .. " - LISTO PARA RENACER"
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
			doRebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			doRebirthBtn.Text = "🔄 RENACER AHORA"
		else
			countLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
			countLabel.Text = count .. " / " .. max .. " brainrots " .. rarity .. " requeridos"
			doRebirthBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
			doRebirthBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
			doRebirthBtn.Text = "NECESITAS 50 BRAINROTS"
		end
	end

	local function updateBonusLabel(boostLevel, rebirthLevel)
		local total = (boostLevel or 0) * 20 + (rebirthLevel or 0) * 20
		bonusLabel.Text = "Bonus: +" .. total .. "%"
		if total > 0 then
			bonusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
		end
	end

	-- ============================================
	-- Abrir/cerrar panel
	-- ============================================
	local function openPanel()
		rebirthPanel.Visible = true
		-- Pedir conteo actual al servidor
		if RebirthRequest then
			RebirthRequest:FireServer("getCount")
		end
	end

	local function closePanel()
		rebirthPanel.Visible = false
	end

	rebirthBtn.MouseButton1Click:Connect(openPanel)
	closeBtn.MouseButton1Click:Connect(closePanel)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Escape and rebirthPanel.Visible then
			closePanel()
		end
	end)

	-- ============================================
	-- Boton RENACER
	-- ============================================
	doRebirthBtn.MouseButton1Click:Connect(function()
		if isProcessing then return end
		if brainrotCount < 50 then return end  -- doble verificacion

		isProcessing = true
		doRebirthBtn.Text = "PROCESANDO..."

		if RebirthRequest then
			RebirthRequest:FireServer("rebirth")
		end

		-- El servidor respondera via RebirthUpdate o cerrara el panel
		task.delay(5, function()
			isProcessing = false
			doRebirthBtn.Text = "RENACER AHORA"
		end)
	end)

	-- ============================================
	-- Escuchar actualizaciones del servidor
	-- ============================================
	if RebirthUpdate then
		RebirthUpdate.OnClientEvent:Connect(function(data)
			if data.type == "count" then
				brainrotCount = data.count or 0
				requiredRarity = data.requiredRarity or "Comun"
				myRebirthLevel = data.rebirthLevel or 0
				myBoostLevel = data.boostLevel or 0
				updateCountDisplay()
				updateBonusLabel(myBoostLevel, myRebirthLevel)
			elseif data.type == "rebirthComplete" then
				myRebirthLevel = data.rebirthLevel or 0
				myBoostLevel = data.boostLevel or 0
				updateBonusLabel(myBoostLevel, myRebirthLevel)
				closePanel()
				isProcessing = false
			elseif data.type == "sync" then
				myRebirthLevel = data.rebirthLevel or 0
				myBoostLevel = data.boostLevel or 0
				brainrotCount = data.count or 0
				requiredRarity = data.requiredRarity or "Comun"
				updateBonusLabel(myBoostLevel, myRebirthLevel)
				updateCountDisplay()
			end
		end)
	end

	-- Pedir sincronizacion al entrar
	task.spawn(function()
		task.wait(3)
		if RebirthRequest then
			RebirthRequest:FireServer("sync")
		end
	end)

	print("[RebirthSystem] Sistema de renacimiento cargado")
end

return RebirthSystem

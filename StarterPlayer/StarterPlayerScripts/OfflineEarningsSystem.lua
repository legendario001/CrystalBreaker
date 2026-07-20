-- ============================================
-- OfflineEarningsSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Muestra notificacion visual de dinero offline al entrar
-- ============================================

local OfflineEarningsSystem = {}

function OfflineEarningsSystem.init(deps)
	local player = deps.player
	local screenGui = deps.screenGui
	local ReplicatedStorage = deps.ReplicatedStorage

	local OfflineEarningsEvent = ReplicatedStorage:WaitForChild("OfflineEarnings", 15)

	-- Formato de dinero (K, M, B, T)
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

	OfflineEarningsEvent.OnClientEvent:Connect(function(amount, timeStr)
		if not amount or amount <= 0 then return end

		-- Crear frame principal centrado
		local notifyFrame = Instance.new("Frame")
		notifyFrame.Name = "OfflineEarningsNotify"
		notifyFrame.Size = UDim2.new(0, 500, 0, 200)
		notifyFrame.Position = UDim2.new(0.5, -250, 0.3, 0)
		notifyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		notifyFrame.BackgroundTransparency = 0.05
		notifyFrame.BorderSizePixel = 0
		notifyFrame.ZIndex = 300
		notifyFrame.Parent = screenGui
		Instance.new("UICorner", notifyFrame).CornerRadius = UDim.new(0, 20)

		-- Borde dorado
		local borderStroke = Instance.new("UIStroke")
		borderStroke.Color = Color3.fromRGB(255, 215, 0)
		borderStroke.Thickness = 5
		borderStroke.Transparency = 0.1
		borderStroke.Parent = notifyFrame

		-- Padding
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 15)
		padding.PaddingBottom = UDim.new(0, 15)
		padding.PaddingLeft = UDim.new(0, 20)
		padding.PaddingRight = UDim.new(0, 20)
		padding.Parent = notifyFrame

		-- Layout vertical
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 10)
		layout.Parent = notifyFrame

		-- Titulo
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, 0, 0, 50)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = "BIENVENIDO DE VUELTA!"
		titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		titleLabel.TextScaled = true
		titleLabel.Font = Enum.Font.GothamBlack
		titleLabel.Parent = notifyFrame

		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Color3.fromRGB(0, 0, 0)
		titleStroke.Thickness = 4
		titleStroke.Transparency = 0
		titleStroke.Parent = titleLabel

		-- Descripcion
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, 0, 0, 35)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = "Tus personajes generaron dinero mientras estabas ausente (" .. (timeStr or "") .. ")"
		descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		descLabel.TextScaled = true
		descLabel.Font = Enum.Font.GothamBold
		descLabel.Parent = notifyFrame

		local descStroke = Instance.new("UIStroke")
		descStroke.Color = Color3.fromRGB(0, 0, 0)
		descStroke.Thickness = 3
		descStroke.Transparency = 0.2
		descStroke.Parent = descLabel

		-- Cantidad de dinero
		local moneyLabel = Instance.new("TextLabel")
		moneyLabel.Size = UDim2.new(1, 0, 0, 60)
		moneyLabel.BackgroundTransparency = 1
		moneyLabel.Text = "+ $" .. formatMoney(amount)
		moneyLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
		moneyLabel.TextScaled = true
		moneyLabel.Font = Enum.Font.GothamBlack
		moneyLabel.Parent = notifyFrame

		local moneyStroke = Instance.new("UIStroke")
		moneyStroke.Color = Color3.fromRGB(0, 0, 0)
		moneyStroke.Thickness = 5
		moneyStroke.Transparency = 0
		moneyStroke.Parent = moneyLabel

		-- Animacion: fade in, esperar 5s, fade out
		task.spawn(function()
			notifyFrame.BackgroundTransparency = 1
			borderStroke.Transparency = 1
			titleLabel.TextTransparency = 1
			titleStroke.Transparency = 1
			descLabel.TextTransparency = 1
			descStroke.Transparency = 1
			moneyLabel.TextTransparency = 1
			moneyStroke.Transparency = 1

			-- Fade in
			for i = 1, 10 do
				local t = i / 10
				notifyFrame.BackgroundTransparency = 1 - (t * 0.95)
				borderStroke.Transparency = 1 - (t * 0.9)
				titleLabel.TextTransparency = 1 - t
				titleStroke.Transparency = 1 - t
				descLabel.TextTransparency = 1 - (t * 0.9)
				descStroke.Transparency = 1 - (t * 0.8)
				moneyLabel.TextTransparency = 1 - t
				moneyStroke.Transparency = 1 - t
				task.wait(0.05)
			end

			-- Mostrar completo
			notifyFrame.BackgroundTransparency = 0.05
			borderStroke.Transparency = 0.1
			titleLabel.TextTransparency = 0
			titleStroke.Transparency = 0
			descLabel.TextTransparency = 0.1
			descStroke.Transparency = 0.2
			moneyLabel.TextTransparency = 0
			moneyStroke.Transparency = 0

			-- Esperar 5 segundos
			task.wait(5)

			-- Fade out
			for i = 1, 10 do
				local t = i / 10
				notifyFrame.BackgroundTransparency = 0.05 + (t * 0.95)
				borderStroke.Transparency = 0.1 + (t * 0.9)
				titleLabel.TextTransparency = t
				titleStroke.Transparency = t
				descLabel.TextTransparency = 0.1 + (t * 0.9)
				descStroke.Transparency = 0.2 + (t * 0.8)
				moneyLabel.TextTransparency = t
				moneyStroke.Transparency = t
				task.wait(0.05)
			end

			if notifyFrame and notifyFrame.Parent then
				notifyFrame:Destroy()
			end
		end)
	end)

	print("[OfflineEarningsSystem] Sistema cargado!")
end

return OfflineEarningsSystem

-- ============================================
-- TutorialSystem (LocalScript) - StarterPlayerScripts
-- Tutorial paginado que aparece siempre al entrar.
-- 8 páginas con íconos emoji + descripción.
-- UIStroke grueso estilo moderno, responsivo para todos los dispositivos.
-- ============================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================
-- ScreenGui principal
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TutorialSystemGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 200 -- encima de todo (incluido InvestorSystem)
screenGui.Parent = playerGui

-- ============================================
-- Panel principal (modal) - TOTALMENTE RESPONSIVE
-- Usa Scale para todo (tamaño del panel y alturas de elementos)
-- asi se adapta a cualquier pantalla: movil, tablet horizontal, PC
-- UIScale ajusta todo proporcionalmente segun el tamaño real del panel
-- ============================================
local panel = Instance.new("Frame")
panel.Name = "TutorialPanel"
-- Size en Scale: 88% ancho, 80% alto de la pantalla
panel.Size = UDim2.new(0.88, 0, 0.8, 0)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)

-- Sin UISizeConstraint: el panel SIEMPRE ocupa 88%x80% de la pantalla
-- (en tablet horizontal se adapta, en PC grande tambien)

local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(100, 200, 255)  -- azul tutorial
panelStroke.Thickness = 5

-- UIAspectConstraint para mantener proporciones razonables en pantallas muy anchas
-- (limita el aspect ratio del panel a max 1.2, evita que se vea demasiado ancho)
local aspectConstraint = Instance.new("UIAspectRatioConstraint", panel)
aspectConstraint.AspectRatio = 0.85  -- mas alto que ancho (0.85:1)
aspectConstraint.AspectType = Enum.AspectType.ScaleWithParentSize
aspectConstraint.DominantAxis = Enum.DominantAxis.Height

-- ============================================
-- UIScale: escala todo el contenido proporcionalmente
-- Se actualiza dinamicamente segun el tamaño real del panel
-- ============================================
local uiScale = Instance.new("UIScale", panel)
uiScale.Scale = 1

-- ============================================
-- Boton cerrar (X) - SIEMPRE visible, altura en Scale
-- ============================================
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.08, 0, 0.07, 0)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -0.02, 0, 0.02)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 10
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.Active = true

local closeStroke = Instance.new("UIStroke", closeBtn)
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Thickness = 3

-- ============================================
-- Indicador de página (arriba centro) - altura en Scale
-- ============================================
local pageIndicator = Instance.new("TextLabel")
pageIndicator.Size = UDim2.new(0.8, 0, 0.06, 0)
pageIndicator.Position = UDim2.new(0.1, 0, 0.02, 0)
pageIndicator.BackgroundTransparency = 1
pageIndicator.Text = "1 / 8"
pageIndicator.TextColor3 = Color3.fromRGB(180, 180, 200)
pageIndicator.TextScaled = true
pageIndicator.Font = Enum.Font.GothamBold
pageIndicator.Parent = panel

local pageIndicatorStroke = Instance.new("UIStroke", pageIndicator)
pageIndicatorStroke.Color = Color3.fromRGB(0, 0, 0)
pageIndicatorStroke.Thickness = 3

-- ============================================
-- Contenido de la página - TODO en Scale
-- ============================================
-- Icono grande (emoji) - 22% de la altura del panel
local iconLabel = Instance.new("TextLabel")
iconLabel.Size = UDim2.new(0.9, 0, 0.22, 0)
iconLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
iconLabel.BackgroundTransparency = 1
iconLabel.Text = "🎯"
iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
iconLabel.TextScaled = true
iconLabel.Font = Enum.Font.GothamBlack
iconLabel.Parent = panel

-- Título de la página - 10% de la altura
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.9, 0, 0.1, 0)
titleLabel.Position = UDim2.new(0.05, 0, 0.34, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Bienvenida"
titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Parent = panel

local titleStroke = Instance.new("UIStroke", titleLabel)
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 5

-- Descripción - 40% de la altura (texto largo)
local descLabel = Instance.new("TextLabel")
descLabel.Size = UDim2.new(0.9, 0, 0.4, 0)
descLabel.Position = UDim2.new(0.05, 0, 0.46, 0)
descLabel.BackgroundTransparency = 1
descLabel.Text = ""
descLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
descLabel.TextWrapped = true
descLabel.TextScaled = true
descLabel.TextYAlignment = Enum.TextYAlignment.Top
descLabel.Font = Enum.Font.GothamMedium
descLabel.Parent = panel

local descStroke = Instance.new("UIStroke", descLabel)
descStroke.Color = Color3.fromRGB(0, 0, 0)
descStroke.Thickness = 2

-- ============================================
-- Botones de navegación (abajo) - altura en Scale
-- ============================================
-- Botón Anterior (izquierda)
local prevBtn = Instance.new("TextButton")
prevBtn.Name = "PrevBtn"
prevBtn.Size = UDim2.new(0.3, 0, 0.08, 0)
prevBtn.Position = UDim2.new(0.04, 0, 0.9, 0)
prevBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
prevBtn.Text = "← Anterior"
prevBtn.Font = Enum.Font.GothamBold
prevBtn.TextScaled = true
prevBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
prevBtn.BorderSizePixel = 0
prevBtn.Parent = panel
Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 10)

local prevStroke = Instance.new("UIStroke", prevBtn)
prevStroke.Color = Color3.fromRGB(100, 200, 255)
prevStroke.Thickness = 3

-- Botón Saltar (centro)
local skipBtn = Instance.new("TextButton")
skipBtn.Name = "SkipBtn"
skipBtn.Size = UDim2.new(0.25, 0, 0.08, 0)
skipBtn.Position = UDim2.new(0.375, 0, 0.9, 0)
skipBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
skipBtn.Text = "Saltar"
skipBtn.Font = Enum.Font.GothamBold
skipBtn.TextScaled = true
skipBtn.TextColor3 = Color3.fromRGB(220, 180, 180)
skipBtn.BorderSizePixel = 0
skipBtn.Parent = panel
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 10)

local skipStroke = Instance.new("UIStroke", skipBtn)
skipStroke.Color = Color3.fromRGB(200, 80, 80)
skipStroke.Thickness = 2

-- Botón Siguiente / Entendido (derecha)
local nextBtn = Instance.new("TextButton")
nextBtn.Name = "NextBtn"
nextBtn.Size = UDim2.new(0.3, 0, 0.08, 0)
nextBtn.Position = UDim2.new(0.66, 0, 0.9, 0)
nextBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
nextBtn.Text = "Siguiente →"
nextBtn.Font = Enum.Font.GothamBold
nextBtn.TextScaled = true
nextBtn.TextColor3 = Color3.fromRGB(15, 15, 25)
nextBtn.BorderSizePixel = 0
nextBtn.Parent = panel
Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 10)

local nextStroke = Instance.new("UIStroke", nextBtn)
nextStroke.Color = Color3.fromRGB(0, 0, 0)
nextStroke.Thickness = 3

-- ============================================
-- Actualizar UIScale dinamicamente segun el tamaño del panel
-- Esto hace que en pantallas chicas todo se achique proporcionalmente
-- ============================================
local RunService = game:GetService("RunService")
local lastScale = 1
RunService.RenderStepped:Connect(function()
        if not panel.Visible then return end
        local absHeight = panel.AbsoluteSize.Y
        -- Calcular escala: si la altura es menor a 500px, achicar proporcionalmente
        -- 500px = escala 1, 300px = escala 0.6, 200px = escala 0.4
        local newScale = math.min(1, absHeight / 500)
        newScale = math.max(0.4, newScale) -- minimo 0.4 para que se siga viendo
        if math.abs(newScale - lastScale) > 0.01 then
                uiScale.Scale = newScale
                lastScale = newScale
        end
end)

-- ============================================
-- Contenido del tutorial (8 páginas)
-- ============================================
local pages = {
        {
                icon = "🎯",
                title = "¡Bienvenido a CrystalBreaker!",
                desc = "Tu objetivo es romper cristales, coleccionar brainrots y construir la base mas rica del servidor. Mientras mas brainrots tengas, mas dinero generaras. ¡Conviertete en el mas rico!",
        },
        {
                icon = "💎",
                title = "Romper Cristales",
                desc = "Ve a la zona de cristales y lanzales pelotas para romperlos. Al romper un cristal, te aparece un cofre. Recoge el cofre para obtener un brainrot aleatorio de distintas rarezas: Blanco, Azul, Amarillo, Rojo o Morado.",
        },
        {
                icon = "🧠",
                title = "Colocar Brainrots",
                desc = "Los brainrots que obtengas van a tu mochila. Llevalos a tu base y colocalos en los pedestales. Cada brainrot en un pedestal genera dinero pasivo automaticamente. ¡Mientras mas brainrots, mas dinero!",
        },
        {
                icon = "⬆️",
                title = "Mejorar Brainrots",
                desc = "Acercate a un brainrot colocado y veras un boton de mejora. Cada mejora sube el nivel del brainrot y aumenta su produccion de dinero. Llega a nivel 100 para multiplicar x5 su produccion. Tambien puedes fusionar 2 brainrots iguales para x3 produccion.",
        },
        {
                icon = "🏗️",
                title = "Mejorar tu Base",
                desc = "Tu base tiene 5 pisos. Mejora tu base para desbloquear mas pisos con mas pedestales. Mas pedestales = mas brainrots = mas dinero. La mejora de base se compra con el boton que aparece en tu base.",
        },
        {
                icon = "🔄",
                title = "Evolucion (Renacer por Rareza)",
                desc = "Cuando llenes los 5 pisos con 50 brainrots de una rareza especifica, puedes EVOLUCIONAR. Al evolucionar pierdes todo tu progreso temporal pero ganas un MULTIPLICADOR permanente: x1, x3, x6, x10 o x15. ¡Cada evolucion te hace mas fuerte!",
        },
        {
                icon = "💰",
                title = "Inversionistas (Renacer por Dinero)",
                desc = "Frente a tu base esta el cartel de Inversionistas. Mientras generas dinero, acumulas inversionistas potenciales. Al renacer pierdes todo pero ganas inversionistas. Cada inversionista da +1% permanente a todas tus ganancias. ¡El multiplicador puede llegar a cientos o miles!",
        },
        {
                icon = "📊",
                title = "Cartel de Inversionistas",
                desc = "El cartel frente a tu base crece en altura segun cuantos inversionistas tengas. Entre mas inversionistas, mas alto el cartel y mas ostentoso se ve. Otros jugadores veran tu progreso. ¡Haz el cartel mas alto del servidor!",
        },
}

local currentPage = 1

-- ============================================
-- Función para actualizar la página mostrada
-- ============================================
local function showPage(pageNum)
        if pageNum < 1 then pageNum = 1 end
        if pageNum > #pages then pageNum = #pages end
        currentPage = pageNum

        local page = pages[currentPage]
        iconLabel.Text = page.icon
        titleLabel.Text = page.title
        descLabel.Text = page.desc
        pageIndicator.Text = currentPage .. " / " .. #pages

        -- Actualizar botones
        if currentPage == 1 then
                prevBtn.Visible = false
        else
                prevBtn.Visible = true
        end

        if currentPage == #pages then
                nextBtn.Text = "¡Entendido! ✓"
                skipBtn.Visible = false
        else
                nextBtn.Text = "Siguiente →"
                skipBtn.Visible = true
        end
end

-- ============================================
-- Abrir / cerrar panel
-- ============================================
local function openPanel()
        panel.Visible = true
        showPage(1)
end

local function closePanel()
        panel.Visible = false
end

closeBtn.MouseButton1Click:Connect(closePanel)
skipBtn.MouseButton1Click:Connect(closePanel)

UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
                closePanel()
        end
end)

-- Navegación
prevBtn.MouseButton1Click:Connect(function()
        showPage(currentPage - 1)
end)

nextBtn.MouseButton1Click:Connect(function()
        if currentPage == #pages then
                closePanel()
        else
                showPage(currentPage + 1)
    end
end)

-- ============================================
-- Mostrar automáticamente al entrar (siempre)
-- ============================================
task.delay(2, function()
        openPanel()
end)

-- ============================================
-- API pública para abrir desde MenuToggle (slot 6)
-- ============================================
-- Exponer función global para que MenuToggle pueda abrir el tutorial
_G.OpenTutorial = openPanel

print("[TutorialSystem] Sistema de tutorial cargado (8 páginas, auto-muestra al entrar)")

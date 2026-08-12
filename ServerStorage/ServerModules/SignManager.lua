-- ============================================
-- SignManager (ModuleScript) - ServerStorage/ServerModules
-- Crea y actualiza los carteles de inversionistas frente a cada base.
-- El cartel crece en altura y cambia de color segun la cantidad de inversionistas.
-- Incluye SurfaceGui con UIStroke grueso para estilo moderno.
-- ============================================

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local SignManager = {}

-- Configuracion visual
local SIGN_WIDTH = 12
local SIGN_DEPTH = 0.5
local SIGN_OFFSET_Z = -10  -- 10 studs adelante del BaseSign (Z=29 -> Z=19)
local SIGN_BASE_Y = 0.5  -- base del cartel a media altura del suelo
local PIXELS_PER_STUD = 100  -- resolucion: 100 pixels por stud (consistente)

-- Cache de carteles: [userId] = {signPart, surfaceGui, investorsLabel, levelLabel, playerLabel}
local signs = {}

-- ============================================
-- Crear el cartel para un jugador en su base
-- ============================================
function SignManager.createSign(player, base, investorCount)
        if not player or not base then return nil end
        local userId = player.UserId

        -- Si ya existe, eliminar primero
        SignManager.removeSign(userId)

        -- Buscar BaseSign para obtener la posicion
        local baseSign = base:FindFirstChild("BaseSign")
        if not baseSign then
                warn("[SignManager] No se encontro BaseSign en " .. base.Name)
                return nil
        end
        local signPos = baseSign.Position

        -- Folder para el cartel
        local signFolder = Instance.new("Folder")
        signFolder.Name = "InvestorSign"
        signFolder.Parent = base

        -- Poste del cartel (soporte vertical)
        local post = Instance.new("Part")
        post.Name = "SignPost"
        post.Size = Vector3.new(0.5, 3, 0.5)
        post.Position = Vector3.new(signPos.X, 1.5, signPos.Z + SIGN_OFFSET_Z)
        post.Anchored = true
        post.Material = Enum.Material.Metal
        post.Color = Color3.fromRGB(40, 40, 50)
        post.Parent = signFolder

        -- Cartel principal (Part que crece en altura)
        local signPart = Instance.new("Part")
        signPart.Name = "SignBoard"
        -- Altura inicial segun inversionistas (usar InvestorManager para consistencia)
        local InvestorManager = require(script.Parent.InvestorManager)
        local initialHeight = InvestorManager.getSignHeight(investorCount or 0)
        signPart.Size = Vector3.new(SIGN_WIDTH, initialHeight, SIGN_DEPTH)
        -- Posicionar de modo que la base del cartel este a Y=3 (encima del poste)
        signPart.Position = Vector3.new(signPos.X, 3 + initialHeight/2, signPos.Z + SIGN_OFFSET_Z)
        signPart.Anchored = true
        signPart.Material = Enum.Material.Neon
        -- Color inicial segun inversionistas
        signPart.Color = InvestorManager.getSignColor(investorCount or 0)
        signPart.Parent = signFolder

        -- PointLight para efecto neón
        local light = Instance.new("PointLight")
        light.Name = "SignLight"
        light.Range = 20
        light.Brightness = 2
        light.Color = signPart.Color
        light.Parent = signPart

        -- SurfaceGui con el texto (NO rota, esta fijo en la cara Front del cartel)
        -- CanvasSize DINAMICO: X fijo (12 studs * 100px = 1200px), Y = altura * 100px
        -- Esto mantiene 100 pixels por stud SIEMPRE, asi el texto NO se estira
        -- cuando el cartel crece. El fixedContainer tiene tamaño fijo en pixels
        -- = tamaño fisico fijo en studs.
        local surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Name = "SignGui"
        surfaceGui.Face = Enum.NormalId.Front
        surfaceGui.CanvasSize = Vector2.new(SIGN_WIDTH * PIXELS_PER_STUD, initialHeight * PIXELS_PER_STUD)
        surfaceGui.LightInfluence = 0
        surfaceGui.MaxDistance = 250
        surfaceGui.Parent = signPart

        -- Fondo del SurfaceGui (transparente para que se vea el neón del Part)
        local bg = Instance.new("Frame")
        bg.Name = "Background"
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
        bg.BackgroundTransparency = 0.2
        bg.BorderSizePixel = 0
        bg.Parent = surfaceGui
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)

        -- UIStroke grueso del fondo (estilo moderno)
        local bgStroke = Instance.new("UIStroke", bg)
        bgStroke.Color = Color3.fromRGB(255, 255, 255)
        bgStroke.Thickness = 8
        bgStroke.Transparency = 0.2

        -- fixedContainer: anclado al fondo del cartel, tamaño FIJO en pixels
        -- 350px = 3.5 studs fisicos (siempre, sin importar la altura del cartel)
        -- cabe en el minimo de 5 studs de altura
        local fixedContainer = Instance.new("Frame")
        fixedContainer.Name = "FixedContainer"
        fixedContainer.AnchorPoint = Vector2.new(0.5, 1)  -- anclado al centro-abajo
        fixedContainer.Size = UDim2.new(1, -60, 0, 350)  -- ancho completo - padding, alto fijo 350px
        fixedContainer.Position = UDim2.new(0.5, 0, 1, -15)  -- al fondo del SurfaceGui
        fixedContainer.BackgroundTransparency = 1
        fixedContainer.BorderSizePixel = 0
        fixedContainer.Parent = bg

        -- Titulo "INVERSIONISTAS" (arriba del contenedor)
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.Size = UDim2.new(1, 0, 0, 50)
        titleLabel.Position = UDim2.new(0, 0, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "INVERSIONISTAS"
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextScaled = true
        titleLabel.Font = Enum.Font.GothamBlack
        titleLabel.Parent = fixedContainer

        -- UIStroke grueso del titulo
        local titleStroke = Instance.new("UIStroke", titleLabel)
        titleStroke.Color = Color3.fromRGB(0, 0, 0)
        titleStroke.Thickness = 6
        titleStroke.Transparency = 0

        -- Numero de inversionistas (grande, debajo del titulo)
        local investorsLabel = Instance.new("TextLabel")
        investorsLabel.Name = "InvestorsLabel"
        investorsLabel.Size = UDim2.new(1, 0, 0, 120)
        investorsLabel.Position = UDim2.new(0, 0, 0, 55)
        investorsLabel.BackgroundTransparency = 1
        investorsLabel.Text = tostring(investorCount or 0)
        investorsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        investorsLabel.TextScaled = true
        investorsLabel.Font = Enum.Font.GothamBlack
        investorsLabel.Parent = fixedContainer

        -- UIStroke grueso del numero
        local investorsStroke = Instance.new("UIStroke", investorsLabel)
        investorsStroke.Color = Color3.fromRGB(0, 0, 0)
        investorsStroke.Thickness = 8
        investorsStroke.Transparency = 0

        -- Nivel del cartel
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Name = "LevelLabel"
        levelLabel.Size = UDim2.new(1, 0, 0, 40)
        levelLabel.Position = UDim2.new(0, 0, 0, 185)
        levelLabel.BackgroundTransparency = 1
        local level = InvestorManager.getSignLevel(investorCount or 0)
        levelLabel.Text = "Nivel " .. level
        levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        levelLabel.TextScaled = true
        levelLabel.Font = Enum.Font.GothamBold
        levelLabel.Parent = fixedContainer

        -- UIStroke del nivel
        local levelStroke = Instance.new("UIStroke", levelLabel)
        levelStroke.Color = Color3.fromRGB(0, 0, 0)
        levelStroke.Thickness = 4
        levelStroke.Transparency = 0

        -- Multiplicador del cartel
        local multLabel = Instance.new("TextLabel")
        multLabel.Name = "MultLabel"
        multLabel.Size = UDim2.new(1, 0, 0, 40)
        multLabel.Position = UDim2.new(0, 0, 0, 230)
        multLabel.BackgroundTransparency = 1
        local mult = InvestorManager.getSignMultiplier(investorCount or 0)
        multLabel.Text = "Multiplicador x" .. string.format("%.2f", mult)
        multLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        multLabel.TextScaled = true
        multLabel.Font = Enum.Font.GothamBold
        multLabel.Parent = fixedContainer

        -- UIStroke del multiplicador
        local multStroke = Instance.new("UIStroke", multLabel)
        multStroke.Color = Color3.fromRGB(0, 0, 0)
        multStroke.Thickness = 4
        multStroke.Transparency = 0

        -- Nombre del jugador (abajo del todo)
        local playerLabel = Instance.new("TextLabel")
        playerLabel.Name = "PlayerLabel"
        playerLabel.Size = UDim2.new(1, 0, 0, 40)
        playerLabel.Position = UDim2.new(0, 0, 1, -40)
        playerLabel.BackgroundTransparency = 1
        playerLabel.Text = player.Name
        playerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        playerLabel.TextScaled = true
        playerLabel.Font = Enum.Font.GothamBold
        playerLabel.Parent = fixedContainer

        -- UIStroke del nombre
        local playerStroke = Instance.new("UIStroke", playerLabel)
        playerStroke.Color = Color3.fromRGB(0, 0, 0)
        playerStroke.Thickness = 4
        playerStroke.Transparency = 0

        -- Guardar en cache
        signs[userId] = {
                folder = signFolder,
                signPart = signPart,
                surfaceGui = surfaceGui,
                investorsLabel = investorsLabel,
                levelLabel = levelLabel,
                multLabel = multLabel,
                light = light,
        }

        print("[SignManager] Cartel creado para " .. player.Name .. " (inversionistas: " .. (investorCount or 0) .. ", altura: " .. initialHeight .. ")")
        return signs[userId]
end

-- ============================================
-- Actualizar el cartel cuando cambian los inversionistas
-- ============================================
function SignManager.updateSign(userId, investorCount)
        local sign = signs[userId]
        if not sign then return end

        local InvestorManager = require(script.Parent.InvestorManager)
        local newHeight = InvestorManager.getSignHeight(investorCount)
        local newColor = InvestorManager.getSignColor(investorCount)
        local newLevel = InvestorManager.getSignLevel(investorCount)
        local newMult = InvestorManager.getSignMultiplier(investorCount)

        -- Tween de altura (animacion suave)
        local currentSize = sign.signPart.Size
        local newSize = Vector3.new(SIGN_WIDTH, newHeight, SIGN_DEPTH)
        -- Recalcular posicion Y para que crezca hacia arriba (base fija en Y=3)
        local newPos = Vector3.new(sign.signPart.Position.X, 3 + newHeight/2, sign.signPart.Position.Z)

        local tween = TweenService:Create(sign.signPart,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = newSize, Position = newPos, Color = newColor}
        )
        tween:Play()

        -- Actualizar luz
        sign.light.Color = newColor

        -- FIX CRITICO: Actualizar CanvasSize Y del SurfaceGui para que mantenga
        -- 100 pixels por stud. Sin esto, el texto se estira verticalmente cuando
        -- el cartel crece (porque el canvas fijo se mapea a un Part mas grande).
        if sign.surfaceGui then
                sign.surfaceGui.CanvasSize = Vector2.new(SIGN_WIDTH * PIXELS_PER_STUD, newHeight * PIXELS_PER_STUD)
        end

        -- Actualizar textos (el fixedContainer con AnchorPoint al fondo se ajusta solo)
        sign.investorsLabel.Text = tostring(investorCount)
        sign.levelLabel.Text = "Nivel " .. newLevel
        sign.multLabel.Text = "Multiplicador x" .. string.format("%.2f", newMult)
end

-- ============================================
-- Eliminar el cartel de un jugador
-- ============================================
function SignManager.removeSign(userId)
        local sign = signs[userId]
        if sign and sign.folder then
                sign.folder:Destroy()
        end
        signs[userId] = nil
end

-- ============================================
-- Obtener el multiplicador del cartel de un jugador
-- (llamado desde el Money Timer)
-- ============================================
function SignManager.getSignMultiplier(userId)
        -- Este metodo no se usa directamente; el GameHandler llama a InvestorManager.getSignMultiplier
        -- con la cantidad de inversionistas del jugador.
        return 1
end

return SignManager

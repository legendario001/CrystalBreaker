-- ============================================
-- BUILD FUSION MACHINE - Ejecutar en Command Bar
-- Crea una maquina de fusion visual en el centro del mapa
-- 3 camaras (2 entrada + 1 salida) + tubos + paneles
-- ============================================

local Workspace = game:GetService("Workspace")

-- Eliminar maquina anterior si existe
local oldMachine = Workspace:FindFirstChild("FusionMachine")
if oldMachine then oldMachine:Destroy() end

-- Crear modelo principal
local machine = Instance.new("Model")
machine.Name = "FusionMachine"
machine.Parent = Workspace

-- Posicion central del mapa (cerca del spawn)
local centerX = 0
local centerY = 0.5
local centerZ = 15

-- ============================================
-- PLATAFORMA BASE (madera clara)
-- ============================================
local platform = Instance.new("Part")
platform.Name = "Platform"
platform.Size = Vector3.new(40, 1, 16)
platform.Position = Vector3.new(centerX, centerY, centerZ)
platform.Anchored = true
platform.Material = Enum.Material.Wood
platform.Color = Color3.fromRGB(180, 140, 90)
platform.Parent = machine

-- ============================================
-- FUNCION HELPER: Crear camara
-- ============================================
local function createChamber(name, position, baseColor, frameColor)
	local chamber = Instance.new("Model")
	chamber.Name = name
	chamber.Parent = machine

	-- Base de la camara (color principal)
	local base = Instance.new("Part")
	base.Name = "ChamberBase"
	base.Size = Vector3.new(6, 0.5, 6)
	base.Position = position + Vector3.new(0, 0.25, 0)
	base.Anchored = true
	base.Material = Enum.Material.SmoothPlastic
	base.Color = baseColor
	base.Parent = chamber

	-- Marco (4 esquinas + 4 barras verticales)
	local frameColor2 = frameColor
	-- Esquina frontal izquierda
	local corner1 = Instance.new("Part")
	corner1.Name = "Corner1"
	corner1.Size = Vector3.new(0.5, 8, 0.5)
	corner1.Position = position + Vector3.new(-3, 4.25, -3)
	corner1.Anchored = true
	corner1.Material = Enum.Material.SmoothPlastic
	corner1.Color = frameColor2
	corner1.Parent = chamber

	-- Esquina frontal derecha
	local corner2 = Instance.new("Part")
	corner2.Name = "Corner2"
	corner2.Size = Vector3.new(0.5, 8, 0.5)
	corner2.Position = position + Vector3.new(3, 4.25, -3)
	corner2.Anchored = true
	corner2.Material = Enum.Material.SmoothPlastic
	corner2.Color = frameColor2
	corner2.Parent = chamber

	-- Esquina trasera izquierda
	local corner3 = Instance.new("Part")
	corner3.Name = "Corner3"
	corner3.Size = Vector3.new(0.5, 8, 0.5)
	corner3.Position = position + Vector3.new(-3, 4.25, 3)
	corner3.Anchored = true
	corner3.Material = Enum.Material.SmoothPlastic
	corner3.Color = frameColor2
	corner3.Parent = chamber

	-- Esquina trasera derecha
	local corner4 = Instance.new("Part")
	corner4.Name = "Corner4"
	corner4.Size = Vector3.new(0.5, 8, 0.5)
	corner4.Position = position + Vector3.new(3, 4.25, 3)
	corner4.Anchored = true
	corner4.Material = Enum.Material.SmoothPlastic
	corner4.Color = frameColor2
	corner4.Parent = chamber

	-- Techo
	local top = Instance.new("Part")
	top.Name = "ChamberTop"
	top.Size = Vector3.new(6, 0.5, 6)
	top.Position = position + Vector3.new(0, 8.5, 0)
	top.Anchored = true
	top.Material = Enum.Material.SmoothPlastic
	top.Color = frameColor2
	top.Parent = chamber

	-- Panel frontal transparente (cristal)
	local frontPanel = Instance.new("Part")
	frontPanel.Name = "FrontPanel"
	frontPanel.Size = Vector3.new(5.5, 7, 0.2)
	frontPanel.Position = position + Vector3.new(0, 4.25, -3.1)
	frontPanel.Anchored = true
	frontPanel.Material = Enum.Material.Glass
	frontPanel.Transparency = 0.6
	frontPanel.Color = Color3.fromRGB(150, 200, 255)
	frontPanel.Parent = chamber

	-- Panel trasero transparente
	local backPanel = Instance.new("Part")
	backPanel.Name = "BackPanel"
	backPanel.Size = Vector3.new(5.5, 7, 0.2)
	backPanel.Position = position + Vector3.new(0, 4.25, 3.1)
	backPanel.Anchored = true
	backPanel.Material = Enum.Material.Glass
	backPanel.Transparency = 0.6
	backPanel.Color = Color3.fromRGB(150, 200, 255)
	backPanel.Parent = chamber

	-- Panel izquierdo transparente
	local leftPanel = Instance.new("Part")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = Vector3.new(0.2, 7, 5.5)
	leftPanel.Position = position + Vector3.new(-3.1, 4.25, 0)
	leftPanel.Anchored = true
	leftPanel.Material = Enum.Material.Glass
	leftPanel.Transparency = 0.6
	leftPanel.Color = Color3.fromRGB(150, 200, 255)
	leftPanel.Parent = chamber

	-- Panel derecho transparente
	local rightPanel = Instance.new("Part")
	rightPanel.Name = "RightPanel"
	rightPanel.Size = Vector3.new(0.2, 7, 5.5)
	rightPanel.Position = position + Vector3.new(3.1, 4.25, 0)
	rightPanel.Anchored = true
	rightPanel.Material = Enum.Material.Glass
	rightPanel.Transparency = 0.6
	rightPanel.Color = Color3.fromRGB(150, 200, 255)
	rightPanel.Parent = chamber

	-- Etiqueta (cartel con el nombre)
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Size = Vector3.new(5, 1.5, 0.3)
	sign.Position = position + Vector3.new(0, 9.5, 0)
	sign.Anchored = true
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(255, 255, 255)
	sign.Parent = chamber

	-- Texto del cartel
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.Text = name
	signText.TextColor3 = Color3.fromRGB(40, 40, 40)
	signText.TextScaled = true
	signText.Font = Enum.Font.GothamBlack
	signText.Parent = sg

	-- Engranajes decorativos en la base (2 pequeños)
	local gear1 = Instance.new("Part")
	gear1.Name = "Gear1"
	gear1.Shape = Enum.PartType.Cylinder
	gear1.Size = Vector3.new(1, 1, 1)
	gear1.Orientation = Vector3.new(0, 0, 90)
	gear1.Position = position + Vector3.new(-2, 0.8, -2.5)
	gear1.Anchored = true
	gear1.Material = Enum.Material.Metal
	gear1.Color = Color3.fromRGB(150, 150, 150)
	gear1.Parent = chamber

	local gear2 = Instance.new("Part")
	gear2.Name = "Gear2"
	gear2.Shape = Enum.PartType.Cylinder
	gear2.Size = Vector3.new(1, 1, 1)
	gear2.Orientation = Vector3.new(0, 0, 90)
	gear2.Position = position + Vector3.new(2, 0.8, -2.5)
	gear2.Anchored = true
	gear2.Material = Enum.Material.Metal
	gear2.Color = Color3.fromRGB(150, 150, 150)
	gear2.Parent = chamber

	return chamber
end

-- ============================================
-- CREAR LAS 3 CAMARAS
-- ============================================

-- Camara A (izquierda) - rosa con marco azul
local chamberA = createChamber(
	"Block A",
	Vector3.new(centerX - 13, centerY, centerZ),
	Color3.fromRGB(255, 130, 180),  -- rosa
	Color3.fromRGB(80, 150, 230)    -- azul
)

-- Camara B (centro) - verde con marco naranja
local chamberB = createChamber(
	"Block B",
	Vector3.new(centerX, centerY, centerZ),
	Color3.fromRGB(120, 200, 100),  -- verde
	Color3.fromRGB(255, 150, 50)    -- naranja
)

-- Camara C (derecha) - amarilla con marco rosa, con puerta abierta
local chamberC = createChamber(
	"Fused Item",
	Vector3.new(centerX + 13, centerY, centerZ),
	Color3.fromRGB(255, 220, 80),   -- amarillo
	Color3.fromRGB(255, 130, 180)   -- rosa
)

-- ============================================
-- TUBOS CONECTORES (transparentes con brillo cyan)
-- ============================================
local function createTube(name, startPos, endPos)
	local tube = Instance.new("Part")
	tube.Name = name

	local distance = (endPos - startPos).Magnitude
	tube.Size = Vector3.new(1.2, 1.2, distance)
	tube.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance/2)
	tube.Anchored = true
	tube.Material = Enum.Material.ForceField
	tube.Transparency = 0.3
	tube.Color = Color3.fromRGB(100, 200, 255)
	tube.Parent = machine

	return tube
end

-- Tubo: Camara A -> Camara B (arco por arriba)
local tubeAB1 = Instance.new("Part")
tubeAB1.Name = "TubeAB_Up"
tubeAB1.Size = Vector3.new(1.2, 4, 1.2)
tubeAB1.Position = Vector3.new(centerX - 8, centerY + 11, centerZ)
tubeAB1.Anchored = true
tubeAB1.Material = Enum.Material.ForceField
tubeAB1.Transparency = 0.3
tubeAB1.Color = Color3.fromRGB(100, 200, 255)
tubeAB1.Parent = machine

local tubeAB2 = Instance.new("Part")
tubeAB2.Name = "TubeAB_Horizontal"
tubeAB2.Size = Vector3.new(8, 1.2, 1.2)
tubeAB2.Position = Vector3.new(centerX - 6.5, centerY + 13, centerZ)
tubeAB2.Anchored = true
tubeAB2.Material = Enum.Material.ForceField
tubeAB2.Transparency = 0.3
tubeAB2.Color = Color3.fromRGB(100, 200, 255)
tubeAB2.Parent = machine

local tubeAB3 = Instance.new("Part")
tubeAB3.Name = "TubeAB_Down"
tubeAB3.Size = Vector3.new(1.2, 5, 1.2)
tubeAB3.Position = Vector3.new(centerX - 5, centerY + 11, centerZ)
tubeAB3.Anchored = true
tubeAB3.Material = Enum.Material.ForceField
tubeAB3.Transparency = 0.3
tubeAB3.Color = Color3.fromRGB(100, 200, 255)
tubeAB3.Parent = machine

-- Tubo: Camara B -> Camara C (arco por arriba)
local tubeBC1 = Instance.new("Part")
tubeBC1.Name = "TubeBC_Up"
tubeBC1.Size = Vector3.new(1.2, 4, 1.2)
tubeBC1.Position = Vector3.new(centerX + 5, centerY + 11, centerZ)
tubeBC1.Anchored = true
tubeBC1.Material = Enum.Material.ForceField
tubeBC1.Transparency = 0.3
tubeBC1.Color = Color3.fromRGB(100, 200, 255)
tubeBC1.Parent = machine

local tubeBC2 = Instance.new("Part")
tubeBC2.Name = "TubeBC_Horizontal"
tubeBC2.Size = Vector3.new(8, 1.2, 1.2)
tubeBC2.Position = Vector3.new(centerX + 6.5, centerY + 13, centerZ)
tubeBC2.Anchored = true
tubeBC2.Material = Enum.Material.ForceField
tubeBC2.Transparency = 0.3
tubeBC2.Color = Color3.fromRGB(100, 200, 255)
tubeBC2.Parent = machine

local tubeBC3 = Instance.new("Part")
tubeBC3.Name = "TubeBC_Down"
tubeBC3.Size = Vector3.new(1.2, 5, 1.2)
tubeBC3.Position = Vector3.new(centerX + 8, centerY + 11, centerZ)
tubeBC3.Anchored = true
tubeBC3.Material = Enum.Material.ForceField
tubeBC3.Transparency = 0.3
tubeBC3.Color = Color3.fromRGB(100, 200, 255)
tubeBC3.Parent = machine

-- ============================================
-- PANELES DE CONTROL
-- ============================================

-- Panel izquierdo (Power Levels)
local leftPanel = Instance.new("Part")
leftPanel.Name = "PowerPanel"
leftPanel.Size = Vector3.new(4, 3, 0.5)
leftPanel.Position = Vector3.new(centerX - 6.5, centerY + 5, centerZ + 4)
leftPanel.Anchored = true
leftPanel.Material = Enum.Material.SmoothPlastic
leftPanel.Color = Color3.fromRGB(230, 220, 190)
leftPanel.Parent = machine

local lsg = Instance.new("SurfaceGui")
lsg.Face = Enum.NormalId.Front
lsg.Parent = leftPanel

local powerTitle = Instance.new("TextLabel")
powerTitle.Size = UDim2.new(1, 0, 0.3, 0)
powerTitle.BackgroundTransparency = 1
powerTitle.Text = "POWER LEVELS"
powerTitle.TextColor3 = Color3.fromRGB(40, 40, 40)
powerTitle.TextScaled = true
powerTitle.Font = Enum.Font.GothamBold
powerTitle.Parent = lsg

-- Barra de progreso
local powerBarBg = Instance.new("Frame")
powerBarBg.Size = UDim2.new(0.8, 0, 0.15, 0)
powerBarBg.Position = UDim2.new(0.1, 0, 0.4, 0)
powerBarBg.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
powerBarBg.BorderSizePixel = 0
powerBarBg.Parent = lsg
Instance.new("UICorner", powerBarBg).CornerRadius = UDim.new(0, 4)

local powerBarFill = Instance.new("Frame")
powerBarFill.Size = UDim2.new(0.85, 0, 1, 0)
powerBarFill.BackgroundColor3 = Color3.fromRGB(80, 230, 80)
powerBarFill.BorderSizePixel = 0
powerBarFill.Parent = powerBarBg
Instance.new("UICorner", powerBarFill).CornerRadius = UDim.new(0, 4)

local powerText = Instance.new("TextLabel")
powerText.Size = UDim2.new(1, 0, 0.2, 0)
powerText.Position = UDim2.new(0, 0, 0.6, 0)
powerText.BackgroundTransparency = 1
powerText.Text = "850/1000"
powerText.TextColor3 = Color3.fromRGB(40, 40, 40)
powerText.TextScaled = true
powerText.Font = Enum.Font.GothamBold
powerText.Parent = lsg

-- Botones (rojo y verde) decorativos
local redButton = Instance.new("TextLabel")
redButton.Size = UDim2.new(0.3, 0, 0.2, 0)
redButton.Position = UDim2.new(0.1, 0, 0.8, 0)
redButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
redButton.Text = ""
redButton.Parent = lsg
Instance.new("UICorner", redButton).CornerRadius = UDim.new(1, 0)

local greenButton = Instance.new("TextLabel")
greenButton.Size = UDim2.new(0.3, 0, 0.2, 0)
greenButton.Position = UDim2.new(0.6, 0, 0.8, 0)
greenButton.BackgroundColor3 = Color3.fromRGB(60, 220, 80)
greenButton.Text = ""
greenButton.Parent = lsg
Instance.new("UICorner", greenButton).CornerRadius = UDim.new(1, 0)

-- Panel derecho (Activate Fusion)
local rightPanel = Instance.new("Part")
rightPanel.Name = "ActivatePanel"
rightPanel.Size = Vector3.new(4, 3, 0.5)
rightPanel.Position = Vector3.new(centerX + 6.5, centerY + 5, centerZ + 4)
rightPanel.Anchored = true
rightPanel.Material = Enum.Material.SmoothPlastic
rightPanel.Color = Color3.fromRGB(230, 220, 190)
rightPanel.Parent = machine

local rsg = Instance.new("SurfaceGui")
rsg.Face = Enum.NormalId.Front
rsg.Parent = rightPanel

local activateTitle = Instance.new("TextLabel")
activateTitle.Size = UDim2.new(1, 0, 0.4, 0)
activateTitle.BackgroundTransparency = 1
activateTitle.Text = "ACTIVATE"
activateTitle.TextColor3 = Color3.fromRGB(40, 40, 40)
activateTitle.TextScaled = true
activateTitle.Font = Enum.Font.GothamBold
activateTitle.Parent = rsg

local activateTitle2 = Instance.new("TextLabel")
activateTitle2.Size = UDim2.new(1, 0, 0.4, 0)
activateTitle2.Position = UDim2.new(0, 0, 0.35, 0)
activateTitle2.BackgroundTransparency = 1
activateTitle2.Text = "FUSION"
activateTitle2.TextColor3 = Color3.fromRGB(40, 40, 40)
activateTitle2.TextScaled = true
activateTitle2.Font = Enum.Font.GothamBold
activateTitle2.Parent = rsg

-- Botón grande verde
local activateButton = Instance.new("TextLabel")
activateButton.Size = UDim2.new(0.7, 0, 0.2, 0)
activateButton.Position = UDim2.new(0.15, 0, 0.8, 0)
activateButton.BackgroundColor3 = Color3.fromRGB(60, 220, 80)
activateButton.Text = ""
activateButton.Parent = rsg
Instance.new("UICorner", activateButton).CornerRadius = UDim.new(0, 8)

-- ============================================
-- PUERTA ABIERTA EN CAMARA C (salida)
-- ============================================
-- Eliminar el panel frontal de la camara C y poner una puerta abierta
local chamberCFrontPanel = chamberC:FindFirstChild("FrontPanel")
if chamberCFrontPanel then chamberCFrontPanel:Destroy() end

-- Puerta abierta (rotada)
local door = Instance.new("Part")
door.Name = "OpenDoor"
door.Size = Vector3.new(5.5, 7, 0.2)
door.Position = Vector3.new(centerX + 13 + 3.5, centerY + 4.25, centerZ - 3)
door.Orientation = Vector3.new(0, -60, 0)
door.Anchored = true
door.Material = Enum.Material.Glass
door.Transparency = 0.5
door.Color = Color3.fromRGB(150, 200, 255)
door.Parent = chamberC

-- ============================================
-- ITEMS DE EJEMPLO DENTRO DE LAS CAMARAS
-- (decorativos, como en la imagen original)
-- ============================================

-- Camara A: cubos rojos y azules
local itemA1 = Instance.new("Part")
itemA1.Name = "DemoItemA1"
itemA1.Size = Vector3.new(1.5, 1.5, 1.5)
itemA1.Position = Vector3.new(centerX - 13 - 1, centerY + 1.5, centerZ - 1)
itemA1.Anchored = true
itemA1.Material = Enum.Material.SmoothPlastic
itemA1.Color = Color3.fromRGB(220, 60, 60)
itemA1.Parent = machine

local itemA2 = Instance.new("Part")
itemA2.Name = "DemoItemA2"
itemA2.Size = Vector3.new(1.2, 1.2, 1.2)
itemA2.Position = Vector3.new(centerX - 13 + 1.5, centerY + 1.2, centerZ + 1)
itemA2.Anchored = true
itemA2.Material = Enum.Material.Neon
itemA2.Color = Color3.fromRGB(80, 150, 255)
itemA2.Parent = machine

-- Camara B: piramides verdes y amarillas
local itemB1 = Instance.new("Part")
itemB1.Name = "DemoItemB1"
itemB1.Shape = Enum.PartType.Ball
itemB1.Size = Vector3.new(1.5, 1.5, 1.5)
itemB1.Position = Vector3.new(centerX - 1, centerY + 1.5, centerZ - 1)
itemB1.Anchored = true
itemB1.Material = Enum.Material.SmoothPlastic
itemB1.Color = Color3.fromRGB(80, 200, 80)
itemB1.Parent = machine

local itemB2 = Instance.new("Part")
itemB2.Name = "DemoItemB2"
itemB2.Shape = Enum.PartType.Ball
itemB2.Size = Vector3.new(1.3, 1.3, 1.3)
itemB2.Position = Vector3.new(centerX + 1.5, centerY + 1.3, centerZ + 1)
itemB2.Anchored = true
itemB2.Material = Enum.Material.Neon
itemB2.Color = Color3.fromRGB(255, 220, 80)
itemB2.Parent = machine

-- Camara C: items arcoiris (estrellas representadas como bolas)
local itemC1 = Instance.new("Part")
itemC1.Name = "DemoItemC1"
itemC1.Shape = Enum.PartType.Ball
itemC1.Size = Vector3.new(1.5, 1.5, 1.5)
itemC1.Position = Vector3.new(centerX + 13 - 1, centerY + 1.5, centerZ - 1)
itemC1.Anchored = true
itemC1.Material = Enum.Material.Neon
itemC1.Color = Color3.fromRGB(255, 100, 100)
itemC1.Parent = machine

local itemC2 = Instance.new("Part")
itemC2.Name = "DemoItemC2"
itemC2.Shape = Enum.PartType.Ball
itemC2.Size = Vector3.new(1.5, 1.5, 1.5)
itemC2.Position = Vector3.new(centerX + 13 + 1.5, centerY + 1.5, centerZ + 1)
itemC2.Anchored = true
itemC2.Material = Enum.Material.Neon
itemC2.Color = Color3.fromRGB(100, 255, 100)
itemC2.Parent = machine

local itemC3 = Instance.new("Part")
itemC3.Name = "DemoItemC3"
itemC3.Shape = Enum.PartType.Ball
itemC3.Size = Vector3.new(1.5, 1.5, 1.5)
itemC3.Position = Vector3.new(centerX + 13, centerY + 1.5, centerZ)
itemC3.Anchored = true
itemC3.Material = Enum.Material.Neon
itemC3.Color = Color3.fromRGB(100, 150, 255)
itemC3.Parent = machine

print("=== MAQUINA DE FUSION CREADA EN EL CENTRO DEL MAPA ===")
print("Ubicacion: X=0, Z=15 (cerca del spawn)")
print("Muevela manualmente a donde quieras")

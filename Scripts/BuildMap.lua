-- ============================================
-- BUILD MAP - Ejecutar en Command Bar (una sola vez)
-- Crea el mapa con 5 bases, pedestales, zona de cristales y paredes
-- ============================================

local Workspace = game:GetService("Workspace")

-- Eliminar mapa anterior si existe
local oldMap = Workspace:FindFirstChild("Map")
if oldMap then oldMap:Destroy() end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = Workspace

-- ============================================
-- SUELO
-- ============================================
local ground = Instance.new("Part")
ground.Name = "Floor"
ground.Size = Vector3.new(300, 1, 500)
ground.Position = Vector3.new(0, -0.5, 60)
ground.Anchored = true
ground.Material = Enum.Material.Grass
ground.Color = Color3.fromRGB(120, 180, 100)
ground.Parent = map

-- ============================================
-- PAREDES
-- ============================================
local wallColor = Color3.fromRGB(80, 90, 110)
local wallMat = Enum.Material.SmoothPlastic

-- Pared Norte
local wallN = Instance.new("Part")
wallN.Name = "WallNorth"
wallN.Size = Vector3.new(300, 10, 2)
wallN.Position = Vector3.new(0, 5, -110)
wallN.Anchored = true
wallN.Material = wallMat
wallN.Color = wallColor
wallN.Parent = map

-- Pared Sur
local wallS = Instance.new("Part")
wallS.Name = "WallSouth"
wallS.Size = Vector3.new(300, 10, 2)
wallS.Position = Vector3.new(0, 5, 230)
wallS.Anchored = true
wallS.Material = wallMat
wallS.Color = wallColor
wallS.Parent = map

-- Pared Este
local wallE = Instance.new("Part")
wallE.Name = "WallEast"
wallE.Size = Vector3.new(2, 10, 342)
wallE.Position = Vector3.new(151, 5, 60)
wallE.Anchored = true
wallE.Material = wallMat
wallE.Color = wallColor
wallE.Parent = map

-- Pared Oeste
local wallW = Instance.new("Part")
wallW.Name = "WallWest"
wallW.Size = Vector3.new(2, 10, 342)
wallW.Position = Vector3.new(-151, 5, 60)
wallW.Anchored = true
wallW.Material = wallMat
wallW.Color = wallColor
wallW.Parent = map

-- Techos decorativos
local topColor = Color3.fromRGB(60, 70, 90)

local wallNTop = Instance.new("Part")
wallNTop.Name = "WallNorthTop"
wallNTop.Size = Vector3.new(304, 1, 4)
wallNTop.Position = Vector3.new(0, 10.5, -110)
wallNTop.Anchored = true
wallNTop.Material = wallMat
wallNTop.Color = topColor
wallNTop.Parent = map

local wallSTop = Instance.new("Part")
wallSTop.Name = "WallSouthTop"
wallSTop.Size = Vector3.new(304, 1, 4)
wallSTop.Position = Vector3.new(0, 10.5, 230)
wallSTop.Anchored = true
wallSTop.Material = wallMat
wallSTop.Color = topColor
wallSTop.Parent = map

local wallETop = Instance.new("Part")
wallETop.Name = "WallEastTop"
wallETop.Size = Vector3.new(4, 1, 346)
wallETop.Position = Vector3.new(151, 10.5, 60)
wallETop.Anchored = true
wallETop.Material = wallMat
wallETop.Color = topColor
wallETop.Parent = map

local wallWTop = Instance.new("Part")
wallWTop.Name = "WallWestTop"
wallWTop.Size = Vector3.new(4, 1, 346)
wallWTop.Position = Vector3.new(-151, 10.5, 60)
wallWTop.Anchored = true
wallWTop.Material = wallMat
wallWTop.Color = topColor
wallWTop.Parent = map

-- ============================================
-- ZONA DE CRISTALES
-- ============================================
local crystalFloor = Instance.new("Part")
crystalFloor.Name = "CrystalZone"
crystalFloor.Size = Vector3.new(280, 1, 80)
crystalFloor.Position = Vector3.new(0, 0.5, -55)
crystalFloor.Anchored = true
crystalFloor.Material = Enum.Material.Ice
crystalFloor.Color = Color3.fromRGB(180, 210, 255)
crystalFloor.Transparency = 0.5
crystalFloor.CanQuery = false
crystalFloor.CanCollide = false
crystalFloor.Parent = map

local crystalBorder = Instance.new("Part")
crystalBorder.Name = "CrystalBorder"
crystalBorder.Size = Vector3.new(284, 2, 84)
crystalBorder.Position = Vector3.new(0, 0.5, -55)
crystalBorder.Anchored = true
crystalBorder.Material = Enum.Material.SmoothPlastic
crystalBorder.Color = Color3.fromRGB(150, 190, 230)
crystalBorder.Transparency = 0.8
crystalBorder.Parent = map

-- Spawn del jugador
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "PlayerSpawn"
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.Position = Vector3.new(0, 0.5, -10)
spawnLocation.Anchored = true
spawnLocation.Parent = map

-- ============================================
-- 5 BASES CON 10 PEDESTALES CADA UNA (13 studs de separacion)
-- ============================================
local basesFolder = Instance.new("Folder")
basesFolder.Name = "Bases"
basesFolder.Parent = map

for baseNum = 1, 5 do
	local base = Instance.new("Folder")
	base.Name = "Base" .. baseNum
	base.Parent = basesFolder

	local baseX = (baseNum - 3) * 50

	-- Suelo de la base
	local baseFloor = Instance.new("Part")
	baseFloor.Name = "BaseFloor"
	baseFloor.Size = Vector3.new(40, 1, 85)
	baseFloor.Position = Vector3.new(baseX, 0.5, 72)
	baseFloor.Anchored = true
	baseFloor.Material = Enum.Material.SmoothPlastic
	baseFloor.Color = Color3.fromRGB(100, 100, 120)
	baseFloor.Parent = base

	-- Poste del letrero
	local signPost = Instance.new("Part")
	signPost.Name = "BaseSignPost"
	signPost.Size = Vector3.new(0.5, 4, 0.5)
	signPost.Position = Vector3.new(baseX, 2.5, 29)
	signPost.Anchored = true
	signPost.Material = Enum.Material.SmoothPlastic
	signPost.Color = Color3.fromRGB(60, 60, 80)
	signPost.Parent = base

	-- Letrero de la base
	local sign = Instance.new("Part")
	sign.Name = "BaseSign"
	sign.Size = Vector3.new(8, 3, 0.3)
	sign.Position = Vector3.new(baseX, 4.5, 29)
	sign.Anchored = true
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(50, 50, 70)
	sign.Parent = base

	-- SurfaceGui del letrero (avatar + nombre)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = sign

	-- Avatar del jugador (mitad superior)
	local playerFaceLabel = Instance.new("ImageLabel")
	playerFaceLabel.Name = "PlayerFace"
	playerFaceLabel.Size = UDim2.new(0.5, 0, 0.5, 0)
	playerFaceLabel.Position = UDim2.new(0.25, 0, 0, 0)
	playerFaceLabel.BackgroundTransparency = 1
	playerFaceLabel.Image = ""
	playerFaceLabel.ScaleType = Enum.ScaleType.Fit
	playerFaceLabel.Parent = sg

	-- Nombre del jugador (mitad inferior)
	local playerNameLabel = Instance.new("TextLabel")
	playerNameLabel.Name = "PlayerName"
	playerNameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	playerNameLabel.Position = UDim2.new(0, 0, 0.5, 0)
	playerNameLabel.BackgroundTransparency = 1
	playerNameLabel.Text = "Libre"
	playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	playerNameLabel.TextScaled = true
	playerNameLabel.Font = Enum.Font.GothamBold
	playerNameLabel.Parent = sg

	-- Pedestales de la base (10 total: 5 izquierda, 5 derecha)
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = base

	for i = 1, 10 do
		local ped = Instance.new("Folder")
		ped.Name = "Pedestal" .. i
		ped.Parent = pedestals

		local pedX
		local pedZ
		if i <= 5 then
			pedX = baseX - 12
			pedZ = 35 + (i - 1) * 13
		else
			pedX = baseX + 12
			pedZ = 35 + (i - 6) * 13
		end

		-- Columna del pedestal
		local pedCol = Instance.new("Part")
		pedCol.Name = "PedestalColumn"
		pedCol.Size = Vector3.new(3, 2, 3)
		pedCol.Position = Vector3.new(pedX, 1, pedZ)
		pedCol.Anchored = true
		pedCol.Material = Enum.Material.SmoothPlastic
		pedCol.Color = Color3.fromRGB(70, 70, 90)
		pedCol.Parent = ped

		-- Plataforma del pedestal
		local platform = Instance.new("Part")
		platform.Name = "Platform"
		platform.Size = Vector3.new(4, 0.5, 4)
		platform.Position = Vector3.new(pedX, 2.25, pedZ)
		platform.Anchored = true
		platform.Material = Enum.Material.SmoothPlastic
		platform.Color = Color3.fromRGB(90, 90, 110)
		platform.Parent = ped
	end
end

print("=== MAPA CREADO EXITOSAMENTE ===")

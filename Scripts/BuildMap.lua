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

        -- Pedestales de la base (10 total: 5 izquierda, 5 derecha) - PISO 1
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

        -- ============================================
        -- FUNCION REUTILIZABLE PARA CREAR PISOS ADICIONALES
        -- Crea un piso completo (suelo con agujero, barandas, escalera, pedestales)
        -- ============================================
        local FLOOR_HEIGHT = 17 -- distancia vertical entre pisos
        local FLOOR2_Y = 18     -- piso 2 a esta altura

        local function createFloor(floorNum, floorY, ladderStartY)
                local floor = Instance.new("Folder")
                floor.Name = "Floor" .. floorNum
                floor.Parent = base

                -- COLORES ESTILO NUBE (blancos suaves, sin texturas complejas)
                local cloudFloorColor = Color3.fromRGB(245, 248, 252)  -- Blanco azulado muy claro
                local cloudBarColor = Color3.fromRGB(255, 255, 255)    -- Blanco puro
                local cloudPedColor = Color3.fromRGB(235, 240, 248)    -- Blanco grisaceo muy claro

                -- Suelo CON AGUJERO EN LA PARTE DE ATRAS (estilo nube: blanco, ligera transparencia)
                local floorFront = Instance.new("Part")
                floorFront.Name = "Floor" .. floorNum .. "Front"
                floorFront.Size = Vector3.new(40, 1, 70)
                floorFront.Position = Vector3.new(baseX, floorY, 65)
                floorFront.Anchored = true
                floorFront.Material = Enum.Material.SmoothPlastic
                floorFront.Color = cloudFloorColor
                floorFront.Transparency = 0.05 -- Casi opaco, ligero efecto etereo
                floorFront.CastShadow = false
                floorFront.Parent = floor

                local floorBack = Instance.new("Part")
                floorBack.Name = "Floor" .. floorNum .. "Back"
                floorBack.Size = Vector3.new(40, 1, 6)
                floorBack.Position = Vector3.new(baseX, floorY, 111)
                floorBack.Anchored = true
                floorBack.Material = Enum.Material.SmoothPlastic
                floorBack.Color = cloudFloorColor
                floorBack.Transparency = 0.05
                floorBack.CastShadow = false
                floorBack.Parent = floor

                -- DECORACION: pequeñas "nubes" en las esquinas del piso (partes blancas redondeadas)
                -- Solo 4 partes extra por piso, muy ligero
                local cloudDecorColor = Color3.fromRGB(255, 255, 255)
                local corners = {
                        {x = baseX - 18, z = 35},
                        {x = baseX + 18, z = 35},
                        {x = baseX - 18, z = 109},
                        {x = baseX + 18, z = 109},
                }
                for i, corner in ipairs(corners) do
                        local cloudDecor = Instance.new("Part")
                        cloudDecor.Name = "CloudDecor" .. floorNum .. "_" .. i
                        cloudDecor.Size = Vector3.new(6, 0.8, 6)
                        cloudDecor.Position = Vector3.new(corner.x, floorY - 0.3, corner.z)
                        cloudDecor.Anchored = true
                        cloudDecor.Material = Enum.Material.SmoothPlastic
                        cloudDecor.Color = cloudDecorColor
                        cloudDecor.Transparency = 0.15
                        cloudDecor.CastShadow = false
                        cloudDecor.Parent = floor
                end

                -- Barandas estilo nube (blanco Neon, brillo suave)
                local barL = Instance.new("Part")
                barL.Name = "BarandL" .. floorNum
                barL.Size = Vector3.new(0.5, 2, 85)
                barL.Position = Vector3.new(baseX - 20, floorY + 1, 72)
                barL.Anchored = true
                barL.Material = Enum.Material.Neon
                barL.Color = cloudBarColor
                barL.CastShadow = false
                barL.Parent = floor

                local barR = Instance.new("Part")
                barR.Name = "BarandR" .. floorNum
                barR.Size = Vector3.new(0.5, 2, 85)
                barR.Position = Vector3.new(baseX + 20, floorY + 1, 72)
                barR.Anchored = true
                barR.Material = Enum.Material.Neon
                barR.Color = cloudBarColor
                barR.CastShadow = false
                barR.Parent = floor

                local barBack = Instance.new("Part")
                barBack.Name = "BarandBack" .. floorNum
                barBack.Size = Vector3.new(40, 2, 0.5)
                barBack.Position = Vector3.new(baseX, floorY + 1, 114)
                barBack.Anchored = true
                barBack.Material = Enum.Material.Neon
                barBack.Color = cloudBarColor
                barBack.CastShadow = false
                barBack.Parent = floor

                local barFront = Instance.new("Part")
                barFront.Name = "BarandFront" .. floorNum
                barFront.Size = Vector3.new(40, 2, 0.5)
                barFront.Position = Vector3.new(baseX, floorY + 1, 30)
                barFront.Anchored = true
                barFront.Material = Enum.Material.Neon
                barFront.Color = cloudBarColor
                barFront.CastShadow = false
                barFront.Parent = floor

                -- ESCALERA VERTICAL continua desde el piso anterior hasta este piso
                local ladderHeight = floorY - ladderStartY
                local ladder = Instance.new("TrussPart")
                ladder.Name = "Ladder" .. floorNum
                ladder.Size = Vector3.new(2, ladderHeight, 2)
                ladder.Position = Vector3.new(baseX, ladderStartY + ladderHeight/2, 104)
                ladder.Anchored = true
                ladder.Material = Enum.Material.Metal
                ladder.Color = Color3.fromRGB(120, 120, 130)
                ladder.CastShadow = false
                ladder.Parent = floor

                -- Pedestales del piso (mismas posiciones relativas que piso 1)
                local pedestalsN = Instance.new("Folder")
                pedestalsN.Name = "Pedestals" .. floorNum
                pedestalsN.Parent = floor

                for i = 1, 10 do
                        local ped = Instance.new("Folder")
                        ped.Name = "Pedestal" .. floorNum .. "_" .. i
                        ped.Parent = pedestalsN

                        local pedX
                        local pedZ
                        if i <= 5 then
                                pedX = baseX - 12
                                pedZ = 35 + (i - 1) * 13
                        else
                                pedX = baseX + 12
                                pedZ = 35 + (i - 6) * 13
                        end

                        local pedCol = Instance.new("Part")
                        pedCol.Name = "PedestalColumn"
                        pedCol.Size = Vector3.new(3, 2, 3)
                        pedCol.Position = Vector3.new(pedX, floorY + 1, pedZ)
                        pedCol.Anchored = true
                        pedCol.Material = Enum.Material.SmoothPlastic
                        pedCol.Color = cloudPedColor
                        pedCol.CastShadow = false
                        pedCol.Parent = ped

                        local platform = Instance.new("Part")
                        platform.Name = "Platform"
                        platform.Size = Vector3.new(4, 0.5, 4)
                        platform.Position = Vector3.new(pedX, floorY + 2.25, pedZ)
                        platform.Anchored = true
                        platform.Material = Enum.Material.SmoothPlastic
                        platform.Color = cloudPedColor
                        platform.CastShadow = false
                        platform.Parent = ped
                end

                -- OCULTAR el piso por defecto
                for _, desc in ipairs(floor:GetDescendants()) do
                        if desc:IsA("BasePart") then
                                desc.Transparency = 1
                                desc.CanCollide = false
                                desc.CanQuery = false
                        end
                end

                return floor
        end

        -- Crear PISO 2 (escalera sube desde Y=1 del piso 1)
        local floor2 = createFloor(2, FLOOR2_Y, 1)

        -- Crear PISO 3 (escalera sube desde Y=FLOOR2_Y del piso 2, escalera continua)
        local FLOOR3_Y = FLOOR2_Y + FLOOR_HEIGHT
        local floor3 = createFloor(3, FLOOR3_Y, FLOOR2_Y)

        -- Crear PISO 4 (escalera sube desde Y=FLOOR3_Y del piso 3, escalera continua)
        local FLOOR4_Y = FLOOR3_Y + FLOOR_HEIGHT
        local floor4 = createFloor(4, FLOOR4_Y, FLOOR3_Y)

        -- Crear PISO 5 (escalera sube desde Y=FLOOR4_Y del piso 4, escalera continua)
        local FLOOR5_Y = FLOOR4_Y + FLOOR_HEIGHT
        local floor5 = createFloor(5, FLOOR5_Y, FLOOR4_Y)
end

print("=== MAPA CREADO EXITOSAMENTE ===")









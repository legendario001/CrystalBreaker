-- ============================================
-- BuildSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Sistema de construccion extraido a ModuleScript para evitar
-- superar el limite de 200 local registers del chunk principal.
-- ============================================

local BuildSystem = {}

-- Dependencias que se pasan desde BallThrower.client.lua via init()
local deps

function BuildSystem.init(dependencies)
        deps = dependencies

        -- Desempaquetar dependencias para uso local
        local player = deps.player
        local screenGui = deps.screenGui
        local mouse = deps.mouse
        local UserInputService = deps.UserInputService
        local RunService = deps.RunService
        local Workspace = deps.Workspace
        local ReplicatedStorage = deps.ReplicatedStorage

        -- Eventos
        local PlaceBlockEvent = deps.PlaceBlockEvent
        local RemoveBlockEvent = deps.RemoveBlockEvent
        local BuyBlockEvent = deps.BuyBlockEvent
        local UpdateInventoryEvent = deps.UpdateInventoryEvent

        -- UI externa (para cerrar al activar build)
        local backpackPanel = deps.backpackPanel
        local musicPanel = deps.musicPanel
        local backpackBtn = deps.backpackBtn
        local musicBtn = deps.musicBtn

        -- Estado externo (pelota)
        local ballEquippedRef = deps.ballEquippedRef
        local unequipBall = deps.unequipBall

-- Flujo:
-- 1. Click en boton hammer (o tecla B) -> abre panel con 3 pestañas
-- 2. Pestaña Materiales: comprar bloques con dinero (van al inventario)
-- 3. Pestaña Inventario: ver bloques comprados, equipar uno
-- 4. Pestaña Modo Construccion: cierra el panel y muestra hotbar inferior
--    con el bloque equipado. Click izquierdo coloca, click derecho quita.
-- El panel se puede reabrir con B o click en hammer.

-- Lista local de bloques (debe coincidir con BuildManager.lua del servidor)
local BLOCK_TYPES_BUILD = {
        { id = "madera",    name = "Madera",    color = Color3.fromRGB(160, 100, 50),  material = Enum.Material.Wood,        cost = 1 },
        { id = "tierra",    name = "Tierra",    color = Color3.fromRGB(130, 90, 60),   material = Enum.Material.Grass,      cost = 1 },
        { id = "piedra",    name = "Piedra",    color = Color3.fromRGB(130, 130, 130), material = Enum.Material.Slate,      cost = 2 },
        { id = "ladrillo",  name = "Ladrillo",  color = Color3.fromRGB(180, 80, 60),   material = Enum.Material.Brick,      cost = 5 },
        { id = "marmol",    name = "Marmol",    color = Color3.fromRGB(240, 240, 240), material = Enum.Material.Marble,     cost = 10 },
        { id = "oro",       name = "Oro",       color = Color3.fromRGB(255, 215, 0),   material = Enum.Material.Foil,       cost = 50 },
        { id = "diamante",  name = "Diamante",  color = Color3.fromRGB(135, 230, 255), material = Enum.Material.Glass,      cost = 100 },
        { id = "galaxia",   name = "Galaxia",   color = Color3.fromRGB(75, 0, 130),    material = Enum.Material.Neon,       cost = 500 },
}

-- Mapa rapido: id -> config
local BLOCK_MAP_BUILD = {}
for _, b in ipairs(BLOCK_TYPES_BUILD) do
        BLOCK_MAP_BUILD[b.id] = b
end

local BLOCK_SIZE_BUILD = 4 -- debe coincidir con ParcelManager.BLOCK_SIZE
local PARCEL_HEIGHT_BUILD = 36 -- debe coincidir con ParcelManager.PARCEL_HEIGHT
local PARCEL_SIZE_X_BUILD = 36
local PARCEL_SIZE_Z_BUILD = 56

-- Estado del modo construccion
local buildMode = false          -- true si el modo construccion esta activo (panel abierto o hotbar visible)
local buildPanelOpen = false     -- true si el panel de pestañas esta abierto
local buildModeActive = false    -- true si el modo construccion esta activo (hotbar visible, panel cerrado)
local equippedBlockId = nil      -- id del bloque equipado para colocar (del inventario)
local blockInventory = {}        -- { [blockId] = count } - espejo del inventario del servidor
local ghostBlock = nil           -- Part preview que sigue al mouse
local gridVisual = nil           -- Folder con las lineas del grid
local canPlace = false           -- true si se puede colocar en la posicion actual del ghost
local currentTab = 1             -- 1=Materiales, 2=Inventario, 3=Modo Construccion

-- Funcion para obtener la parcela del jugador (busca en Workspace/Parcelas)
local function findPlayerParcel()
        local parcelas = Workspace:FindFirstChild("Parcelas")
        if not parcelas then return nil end
        local char = player.Character
        if not char then return nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        local closest = nil
        local closestDist = math.huge
        for _, p in ipairs(parcelas:GetChildren()) do
                if p:IsA("BasePart") then
                        local dist = (p.Position - root.Position).Magnitude
                        if dist < closestDist then
                                closestDist = dist
                                closest = p
                        end
                end
        end
        if closestDist < 50 then return closest end
        return nil
end

-- Snap de posicion a la cuadricula de 4 studs
local function snapToGrid(position, parcelCenter)
        local offsetX = position.X - parcelCenter.X
        local offsetZ = position.Z - parcelCenter.Z
        local snappedX = math.round(offsetX / BLOCK_SIZE_BUILD) * BLOCK_SIZE_BUILD
        local snappedZ = math.round(offsetZ / BLOCK_SIZE_BUILD) * BLOCK_SIZE_BUILD
        return Vector3.new(
                parcelCenter.X + snappedX,
                position.Y,
                parcelCenter.Z + snappedZ
        )
end

-- Forward declarations para variables que se usan antes de definirse (UI creada mas abajo)
local hotbarSlot
local hotbarPreview
local hotbarNameLabel
local hotbarCountLabel
local invBtn

-- Actualizar el hotbar inferior (slot con el bloque equipado + count)
local function updateHotbar()
        if not buildModeActive then
                if hotbarSlot then hotbarSlot.Visible = false end
                if invBtn then invBtn.Visible = false end
                return
        end
        -- Mostrar siempre el boton inventario cuando el modo esta activo
        if invBtn then invBtn.Visible = true end
        -- Siempre mostrar el slot cuando el modo esta activo (aunque este vacio)
        if not equippedBlockId or not blockInventory[equippedBlockId] or blockInventory[equippedBlockId] <= 0 then
                -- Slot vacio: gris, sin bloque equipado
                if hotbarPreview then
                        hotbarPreview.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                end
                if hotbarNameLabel then
                        hotbarNameLabel.Text = "Sin bloque"
                end
                if hotbarCountLabel then
                        hotbarCountLabel.Text = "x0"
                        hotbarCountLabel.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
                end
                if hotbarSlot then hotbarSlot.Visible = true end
                return
        end
        local config = BLOCK_MAP_BUILD[equippedBlockId]
        if not config then
                if hotbarSlot then hotbarSlot.Visible = false end
                return
        end
        hotbarPreview.BackgroundColor3 = config.color
        hotbarNameLabel.Text = config.name
        hotbarCountLabel.Text = "x" .. tostring(blockInventory[equippedBlockId])
        hotbarCountLabel.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
        hotbarSlot.Visible = true
end

-- Crear/actualizar el bloque fantasma (preview)
local function updateGhostBlock()
        if not buildModeActive then
                if ghostBlock then
                        ghostBlock:Destroy()
                        ghostBlock = nil
                end
                canPlace = false
                return
        end

        -- Si no hay bloque equipado o count 0, no mostrar ghost
        if not equippedBlockId or not blockInventory[equippedBlockId] or blockInventory[equippedBlockId] <= 0 then
                if ghostBlock then ghostBlock.LocalTransparencyModifier = 1 end
                canPlace = false
                return
        end

        local parcel = findPlayerParcel()
        if not parcel then
                if ghostBlock then ghostBlock.LocalTransparencyModifier = 1 end
                canPlace = false
                return
        end

        local parcelSizeY = parcel.Size and parcel.Size.Y or 1
        local parcelTopY = parcel.Position.Y + (parcelSizeY / 2)

        local mouseTarget = mouse.Target
        local mousePos = mouse.Hit.Position
        local targetSurface = mouse.TargetSurface
        local normalVec = Vector3.new(0, 0, 0)
        if targetSurface == Enum.NormalId.Top then normalVec = Vector3.new(0, 1, 0)
        elseif targetSurface == Enum.NormalId.Bottom then normalVec = Vector3.new(0, -1, 0)
        elseif targetSurface == Enum.NormalId.Front then normalVec = Vector3.new(0, 0, -1)
        elseif targetSurface == Enum.NormalId.Back then normalVec = Vector3.new(0, 0, 1)
        elseif targetSurface == Enum.NormalId.Left then normalVec = Vector3.new(-1, 0, 0)
        elseif targetSurface == Enum.NormalId.Right then normalVec = Vector3.new(1, 0, 0)
        end

        local snappedPos
        if mouseTarget and string.sub(mouseTarget.Name, 1, 6) == "Block_" then
                local targetPos = mouseTarget.Position
                local adjacentPos = targetPos + normalVec * BLOCK_SIZE_BUILD
                snappedPos = snapToGrid(adjacentPos, parcel.Position)
        else
                snappedPos = snapToGrid(Vector3.new(mousePos.X, parcelTopY + BLOCK_SIZE_BUILD/2, mousePos.Z), parcel.Position)
        end

        local halfX = PARCEL_SIZE_X_BUILD / 2
        local halfZ = PARCEL_SIZE_Z_BUILD / 2
        local maxY = parcelTopY + PARCEL_HEIGHT_BUILD

        local inBounds =  snappedPos.X - BLOCK_SIZE_BUILD/2 >= parcel.Position.X - halfX - 0.01 and
                snappedPos.X + BLOCK_SIZE_BUILD/2 <= parcel.Position.X + halfX + 0.01 and
                snappedPos.Z - BLOCK_SIZE_BUILD/2 >= parcel.Position.Z - halfZ - 0.01 and
                snappedPos.Z + BLOCK_SIZE_BUILD/2 <= parcel.Position.Z + halfZ + 0.01 and
                snappedPos.Y + BLOCK_SIZE_BUILD/2 <= maxY + 0.01 and
                snappedPos.Y - BLOCK_SIZE_BUILD/2 >= parcelTopY - 0.01

        local occupied = false
        local blocksFolder = parcel:FindFirstChild("Blocks_" .. player.UserId)
        if blocksFolder then
                for _, b in ipairs(blocksFolder:GetChildren()) do
                        if b:IsA("BasePart") and (b.Position - snappedPos).Magnitude < 1 then
                                occupied = true
                                break
                        end
                end
        end

        canPlace = inBounds and not occupied

        if not ghostBlock then
                ghostBlock = Instance.new("Part")
                ghostBlock.Name = "GhostBlock"
                ghostBlock.Size = Vector3.new(BLOCK_SIZE_BUILD, BLOCK_SIZE_BUILD, BLOCK_SIZE_BUILD)
                ghostBlock.Anchored = true
                ghostBlock.CanCollide = false
                ghostBlock.CanQuery = false
                ghostBlock.CanTouch = false
                ghostBlock.Material = Enum.Material.ForceField
                ghostBlock.Transparency = 0.3
                ghostBlock.LocalTransparencyModifier = 1
                ghostBlock.Parent = Workspace
        end

        local config = BLOCK_MAP_BUILD[equippedBlockId]
        ghostBlock.Position = snappedPos
        ghostBlock.LocalTransparencyModifier = 0.3 -- mas visible (antes 0.5)
        if canPlace then
                ghostBlock.Color = config.color
        else
                ghostBlock.Color = Color3.fromRGB(255, 80, 80)
        end
end

-- Crear el grid visual
local function createGridVisual(parcel)
        if gridVisual then
                gridVisual:Destroy()
                gridVisual = nil
        end
        if not parcel then return end

        gridVisual = Instance.new("Folder")
        gridVisual.Name = "GridVisual"
        gridVisual.Parent = Workspace

        local halfX = PARCEL_SIZE_X_BUILD / 2
        local halfZ = PARCEL_SIZE_Z_BUILD / 2
        local center = parcel.Position
        local topY = center.Y + 0.1

        for i = -halfX, halfX, BLOCK_SIZE_BUILD do
                local line = Instance.new("Part")
                line.Name = "GridLine_H_" .. i
                line.Size = Vector3.new(0.1, 0.05, PARCEL_SIZE_Z_BUILD)
                line.Position = Vector3.new(center.X + i, topY, center.Z)
                line.Anchored = true
                line.CanCollide = false
                line.CanQuery = false
                line.CanTouch = false
                line.Material = Enum.Material.Neon
                line.Color = Color3.fromRGB(100, 200, 255)
                line.Transparency = 0.7
                line.Parent = gridVisual
        end
        for i = -halfZ, halfZ, BLOCK_SIZE_BUILD do
                local line = Instance.new("Part")
                line.Name = "GridLine_V_" .. i
                line.Size = Vector3.new(PARCEL_SIZE_X_BUILD, 0.05, 0.1)
                line.Position = Vector3.new(center.X, topY, center.Z + i)
                line.Anchored = true
                line.CanCollide = false
                line.CanQuery = false
                line.CanTouch = false
                line.Material = Enum.Material.Neon
                line.Color = Color3.fromRGB(100, 200, 255)
                line.Transparency = 0.7
                line.Parent = gridVisual
        end
end

local function removeGridVisual()
        if gridVisual then
                gridVisual:Destroy()
                gridVisual = nil
        end
end

-- ============================================
-- UI: Boton hammer (abre/cierra panel)
-- ============================================
local buildBtn = Instance.new("TextButton")
buildBtn.Name = "BuildBtn"
buildBtn.Size = UDim2.new(0, 60, 0, 60)
buildBtn.Position = UDim2.new(0, 20, 1, -340)
buildBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
buildBtn.BorderSizePixel = 0
buildBtn.Text = ""
buildBtn.Parent = screenGui
Instance.new("UICorner", buildBtn).CornerRadius = UDim.new(0, 12)

local buildIcon = Instance.new("TextLabel")
buildIcon.Size = UDim2.new(0.8, 0, 0.8, 0)
buildIcon.Position = UDim2.new(0.1, 0, 0.1, 0)
buildIcon.BackgroundTransparency = 1
buildIcon.Text = "🔨"
buildIcon.TextScaled = true
buildIcon.Parent = buildBtn

local buildStroke = Instance.new("UIStroke")
buildStroke.Color = Color3.fromRGB(255, 180, 80)
buildStroke.Thickness = 2
buildStroke.Transparency = 0.3
buildStroke.Parent = buildBtn

local buildKeyLabel = Instance.new("TextLabel")
buildKeyLabel.Size = UDim2.new(0.3, 0, 0.3, 0)
buildKeyLabel.Position = UDim2.new(0.65, 0, 0.6, 0)
buildKeyLabel.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
buildKeyLabel.BorderSizePixel = 0
buildKeyLabel.Text = "B"
buildKeyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
buildKeyLabel.TextScaled = true
buildKeyLabel.Font = Enum.Font.GothamBold
buildKeyLabel.ZIndex = 2
buildKeyLabel.Parent = buildBtn
Instance.new("UICorner", buildKeyLabel).CornerRadius = UDim.new(0, 4)

-- ============================================
-- UI: Panel con 3 pestañas
-- ============================================
local buildPanel = Instance.new("Frame")
buildPanel.Name = "BuildPanel"
buildPanel.Size = UDim2.new(0, 400, 0, 380)
buildPanel.Position = UDim2.new(0.5, -200, 1, -400)
buildPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
buildPanel.BackgroundTransparency = 0.05
buildPanel.BorderSizePixel = 0
buildPanel.Visible = false
buildPanel.ZIndex = 50
buildPanel.Parent = screenGui
Instance.new("UICorner", buildPanel).CornerRadius = UDim.new(0, 16)

local bpBuildStroke = Instance.new("UIStroke")
bpBuildStroke.Color = Color3.fromRGB(255, 180, 80)
bpBuildStroke.Thickness = 2
bpBuildStroke.Transparency = 0.2
bpBuildStroke.Parent = buildPanel

-- Boton X para cerrar
local bpBuildCloseBtn = Instance.new("TextButton")
bpBuildCloseBtn.Name = "BpBuildCloseBtn"
bpBuildCloseBtn.Size = UDim2.new(0, 30, 0, 30)
bpBuildCloseBtn.Position = UDim2.new(1, -35, 0, 5)
bpBuildCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
bpBuildCloseBtn.BorderSizePixel = 0
bpBuildCloseBtn.Text = "X"
bpBuildCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bpBuildCloseBtn.TextScaled = true
bpBuildCloseBtn.Font = Enum.Font.GothamBold
bpBuildCloseBtn.ZIndex = 52
bpBuildCloseBtn.Parent = buildPanel
Instance.new("UICorner", bpBuildCloseBtn).CornerRadius = UDim.new(0, 8)

-- ============================================
-- Pestañas (3 botones arriba del panel)
-- ============================================
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, -20, 0, 35)
tabContainer.Position = UDim2.new(0, 10, 0, 5)
tabContainer.BackgroundTransparency = 1
tabContainer.ZIndex = 51
tabContainer.Parent = buildPanel

local tabButtons = {}
local tabLabels = { "Materiales", "Inventario", "Modo Construccion" }
-- Colores por tab para que se distingan visualmente
local TAB_COLORS = {
        { bg = Color3.fromRGB(180, 120, 60), text = Color3.fromRGB(255, 255, 255) }, -- Materiales (naranja)
        { bg = Color3.fromRGB(80, 160, 220), text = Color3.fromRGB(255, 255, 255) }, -- Inventario (azul)
        { bg = Color3.fromRGB(80, 200, 100), text = Color3.fromRGB(0, 0, 0) },       -- Modo Construccion (verde)
}
for i, label in ipairs(tabLabels) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab" .. i
        tabBtn.Size = UDim2.new(0.33, -3, 1, 0)
        tabBtn.Position = UDim2.new((i-1) * 0.33, 0, 0, 0)
        -- Color base mas oscuro (inactivo), se reemplaza por selectTab
        tabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = label
        tabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        tabBtn.TextScaled = true
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.ZIndex = 51
        tabBtn.Parent = tabContainer
        Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)
        -- Borde para que se note mas que es boton
        local tabStroke = Instance.new("UIStroke")
        tabStroke.Color = TAB_COLORS[i].bg
        tabStroke.Thickness = 2
        tabStroke.Transparency = 0.4
        tabStroke.Parent = tabBtn
        -- AutoButtonColor para feedback al hover
        tabBtn.AutoButtonColor = true
        tabButtons[i] = tabBtn
end

-- ============================================
-- Contenido de las pestañas (3 frames, solo 1 visible a la vez)
-- ============================================
-- Tab 1: Materiales (comprar)
local tabMateriales = Instance.new("ScrollingFrame")
tabMateriales.Name = "TabMateriales"
tabMateriales.Size = UDim2.new(1, -20, 1, -50)
tabMateriales.Position = UDim2.new(0, 10, 0, 45)
tabMateriales.BackgroundTransparency = 1
tabMateriales.ScrollBarThickness = 6
tabMateriales.CanvasSize = UDim2.new(0, 0, 0, 0)
tabMateriales.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabMateriales.ZIndex = 51
tabMateriales.Visible = true
tabMateriales.Parent = buildPanel
local tabMatLayout = Instance.new("UIListLayout")
tabMatLayout.Padding = UDim.new(0, 8)
tabMatLayout.Parent = tabMateriales

-- Tab 2: Inventario (equipar)
local tabInventario = Instance.new("ScrollingFrame")
tabInventario.Name = "TabInventario"
tabInventario.Size = UDim2.new(1, -20, 1, -50)
tabInventario.Position = UDim2.new(0, 10, 0, 45)
tabInventario.BackgroundTransparency = 1
tabInventario.ScrollBarThickness = 6
tabInventario.CanvasSize = UDim2.new(0, 0, 0, 0)
tabInventario.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabInventario.ZIndex = 51
tabInventario.Visible = false
tabInventario.Parent = buildPanel
local tabInvLayout = Instance.new("UIListLayout")
tabInvLayout.Padding = UDim.new(0, 8)
tabInvLayout.Parent = tabInventario

-- Tab 3: Modo Construccion (boton grande que activa el modo y cierra el panel)
local tabModoConstruccion = Instance.new("Frame")
tabModoConstruccion.Name = "TabModoConstruccion"
tabModoConstruccion.Size = UDim2.new(1, -20, 1, -50)
tabModoConstruccion.Position = UDim2.new(0, 10, 0, 45)
tabModoConstruccion.BackgroundTransparency = 1
tabModoConstruccion.ZIndex = 51
tabModoConstruccion.Visible = false
tabModoConstruccion.Parent = buildPanel

local modoConstrucionInfo = Instance.new("TextLabel")
modoConstrucionInfo.Size = UDim2.new(1, 0, 0, 80)
modoConstrucionInfo.Position = UDim2.new(0, 0, 0, 20)
modoConstrucionInfo.BackgroundTransparency = 1
modoConstrucionInfo.Text = "Al activar el modo construccion, se cerrara este panel y aparecerá un hotbar abajo con el bloque equipado.\n\nClick izquierdo: colocar bloque\nClick derecho: quitar bloque"
modoConstrucionInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
modoConstrucionInfo.TextScaled = true
modoConstrucionInfo.Font = Enum.Font.Gotham
modoConstrucionInfo.TextWrapped = true
modoConstrucionInfo.ZIndex = 52
modoConstrucionInfo.Parent = tabModoConstruccion

local activarModoBtn = Instance.new("TextButton")
activarModoBtn.Name = "ActivarModoBtn"
activarModoBtn.Size = UDim2.new(1, 0, 0, 60)
activarModoBtn.Position = UDim2.new(0, 0, 0, 130)
activarModoBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
activarModoBtn.BorderSizePixel = 0
activarModoBtn.Text = "ACTIVAR MODO CONSTRUCCION"
activarModoBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
activarModoBtn.TextScaled = true
activarModoBtn.Font = Enum.Font.GothamBold
activarModoBtn.ZIndex = 52
activarModoBtn.Parent = tabModoConstruccion
Instance.new("UICorner", activarModoBtn).CornerRadius = UDim.new(0, 10)

-- Advertencia si no hay bloque equipado
local noEquipWarning = Instance.new("TextLabel")
noEquipWarning.Size = UDim2.new(1, 0, 0, 40)
noEquipWarning.Position = UDim2.new(0, 0, 0, 210)
noEquipWarning.BackgroundTransparency = 1
noEquipWarning.Text = "⚠ No tienes bloque equipado. Ve a Inventario y equipa uno."
noEquipWarning.TextColor3 = Color3.fromRGB(255, 180, 80)
noEquipWarning.TextScaled = true
noEquipWarning.Font = Enum.Font.GothamBold
noEquipWarning.Visible = false
noEquipWarning.ZIndex = 52
noEquipWarning.Parent = tabModoConstruccion

-- ============================================
-- Hotbar inferior (slot con bloque equipado)
-- ============================================
hotbarSlot = Instance.new("Frame")
hotbarSlot.Name = "HotbarSlot"
hotbarSlot.Size = UDim2.new(0, 100, 0, 100)
hotbarSlot.Position = UDim2.new(0.5, -50, 1, -120)
hotbarSlot.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
hotbarSlot.BackgroundTransparency = 0.1
hotbarSlot.BorderSizePixel = 0
hotbarSlot.Visible = false
hotbarSlot.ZIndex = 50
hotbarSlot.Parent = screenGui
Instance.new("UICorner", hotbarSlot).CornerRadius = UDim.new(0, 12)

-- ============================================
-- Boton Inventario (al lado izquierdo del hotbar, visible solo en modo construccion)
-- ============================================
invBtn = Instance.new("TextButton")
invBtn.Name = "InvBtn"
invBtn.Size = UDim2.new(0, 100, 0, 100)
invBtn.Position = UDim2.new(0.5, -160, 1, -120) -- 110px a la izquierda del hotbar (50 + 100 + 10)
invBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
invBtn.BackgroundTransparency = 0.1
invBtn.BorderSizePixel = 0
invBtn.Text = ""
invBtn.Visible = false
invBtn.ZIndex = 50
invBtn.Parent = screenGui
Instance.new("UICorner", invBtn).CornerRadius = UDim.new(0, 12)

local invBtnStroke = Instance.new("UIStroke")
invBtnStroke.Color = Color3.fromRGB(80, 160, 220) -- azul (mismo color que tab Inventario)
invBtnStroke.Thickness = 2
invBtnStroke.Transparency = 0.2
invBtnStroke.Parent = invBtn

-- Icono del boton inventario (mochila emoji temporal)
local invBtnIcon = Instance.new("TextLabel")
invBtnIcon.Size = UDim2.new(0.6, 0, 0.5, 0)
invBtnIcon.Position = UDim2.new(0.2, 0, 0.1, 0)
invBtnIcon.BackgroundTransparency = 1
invBtnIcon.Text = "🎒"
invBtnIcon.TextScaled = true
invBtnIcon.ZIndex = 51
invBtnIcon.Parent = invBtn

-- Texto "Inventario" debajo del icono
local invBtnLabel = Instance.new("TextLabel")
invBtnLabel.Size = UDim2.new(1, 0, 0.25, 0)
invBtnLabel.Position = UDim2.new(0, 0, 0.65, 0)
invBtnLabel.BackgroundTransparency = 1
invBtnLabel.Text = "Inventario"
invBtnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
invBtnLabel.TextScaled = true
invBtnLabel.Font = Enum.Font.GothamBold
invBtnLabel.ZIndex = 51
invBtnLabel.Parent = invBtn

local hotbarStroke = Instance.new("UIStroke")
hotbarStroke.Color = Color3.fromRGB(255, 180, 80)
hotbarStroke.Thickness = 2
hotbarStroke.Transparency = 0.2
hotbarStroke.Parent = hotbarSlot

-- Preview del bloque (cuadro de color)
hotbarPreview = Instance.new("Frame")
hotbarPreview.Name = "Preview"
hotbarPreview.Size = UDim2.new(0.7, 0, 0.5, 0)
hotbarPreview.Position = UDim2.new(0.15, 0, 0.1, 0)
hotbarPreview.BackgroundColor3 = Color3.fromRGB(160, 100, 50)
hotbarPreview.BorderSizePixel = 0
hotbarPreview.ZIndex = 51
hotbarPreview.Parent = hotbarSlot
Instance.new("UICorner", hotbarPreview).CornerRadius = UDim.new(0, 6)

-- Nombre del bloque
hotbarNameLabel = Instance.new("TextLabel")
hotbarNameLabel.Size = UDim2.new(1, 0, 0.2, 0)
hotbarNameLabel.Position = UDim2.new(0, 0, 0.65, 0)
hotbarNameLabel.BackgroundTransparency = 1
hotbarNameLabel.Text = "Madera"
hotbarNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hotbarNameLabel.TextScaled = true
hotbarNameLabel.Font = Enum.Font.GothamBold
hotbarNameLabel.ZIndex = 51
hotbarNameLabel.Parent = hotbarSlot

-- Count
hotbarCountLabel = Instance.new("TextLabel")
hotbarCountLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
hotbarCountLabel.Position = UDim2.new(0.55, 0, 0.05, 0)
hotbarCountLabel.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
hotbarCountLabel.BorderSizePixel = 0
hotbarCountLabel.Text = "x1"
hotbarCountLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
hotbarCountLabel.TextScaled = true
hotbarCountLabel.Font = Enum.Font.GothamBold
hotbarCountLabel.ZIndex = 52
hotbarCountLabel.Parent = hotbarSlot
Instance.new("UICorner", hotbarCountLabel).CornerRadius = UDim.new(0, 6)

-- ============================================
-- Funciones de UI
-- ============================================

-- Actualizar la tab seleccionada visualmente
local function selectTab(idx)
        currentTab = idx
        for i, btn in ipairs(tabButtons) do
                local stroke = btn:FindFirstChildWhichIsA("UIStroke")
                if i == idx then
                        -- Tab activa: fondo con su color vibrante, texto blanco/negro segun el color
                        btn.BackgroundColor3 = TAB_COLORS[i].bg
                        btn.TextColor3 = TAB_COLORS[i].text
                        btn.AutoButtonColor = false
                        if stroke then
                                stroke.Thickness = 3
                                stroke.Transparency = 0
                        end
                else
                        -- Tab inactiva: fondo oscuro, texto gris, borde de su color
                        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
                        btn.AutoButtonColor = true
                        if stroke then
                                stroke.Thickness = 2
                                stroke.Transparency = 0.4
                        end
                end
        end
        tabMateriales.Visible = (idx == 1)
        tabInventario.Visible = (idx == 2)
        tabModoConstruccion.Visible = (idx == 3)
end

-- Llenar la tab de Materiales (comprar)
local function updateMaterialesTab()
        for _, child in ipairs(tabMateriales:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
        end
        for _, block in ipairs(BLOCK_TYPES_BUILD) do
                local card = Instance.new("Frame")
                card.Name = "BuyCard_" .. block.id
                card.Size = UDim2.new(1, -10, 0, 60)
                card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                card.BorderSizePixel = 0
                card.ZIndex = 52
                card.Parent = tabMateriales
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

                local cardStroke = Instance.new("UIStroke")
                cardStroke.Color = Color3.fromRGB(255, 180, 80)
                cardStroke.Thickness = 2
                cardStroke.Transparency = 0.2
                cardStroke.Parent = card

                -- Preview del bloque (color)
                local preview = Instance.new("Frame")
                preview.Size = UDim2.new(0, 50, 1, -10)
                preview.Position = UDim2.new(0, 5, 0, 5)
                preview.BackgroundColor3 = block.color
                preview.BorderSizePixel = 0
                preview.ZIndex = 53
                preview.Parent = card
                Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 6)

                -- Info (nombre + precio)
                local infoLabel = Instance.new("TextLabel")
                infoLabel.Size = UDim2.new(0.55, 0, 1, -10)
                infoLabel.Position = UDim2.new(0, 60, 0, 5)
                infoLabel.BackgroundTransparency = 1
                infoLabel.Text = '<font color="#FFFFFF">' .. block.name .. '</font>\n<font color="#80C8FF">$' .. block.cost .. '</font>'
                infoLabel.RichText = true
                infoLabel.TextXAlignment = Enum.TextXAlignment.Left
                infoLabel.TextYAlignment = Enum.TextYAlignment.Center
                infoLabel.TextScaled = true
                infoLabel.Font = Enum.Font.GothamBold
                infoLabel.ZIndex = 53
                infoLabel.Parent = card

                -- Boton Comprar
                local buyBtn = Instance.new("TextButton")
                buyBtn.Size = UDim2.new(0.3, -5, 0.6, 0)
                buyBtn.Position = UDim2.new(0.7, 5, 0.2, 0)
                buyBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
                buyBtn.BorderSizePixel = 0
                buyBtn.Text = "Comprar"
                buyBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                buyBtn.TextScaled = true
                buyBtn.Font = Enum.Font.GothamBold
                buyBtn.ZIndex = 53
                buyBtn.Parent = card
                Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

                buyBtn.MouseButton1Click:Connect(function()
                        BuyBlockEvent:FireServer(block.id)
                end)
        end
end

-- Llenar la tab de Inventario (equipar)
local function updateInventarioTab()
        for _, child in ipairs(tabInventario:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
        end
        local hasAny = false
        for _, block in ipairs(BLOCK_TYPES_BUILD) do
                local count = blockInventory[block.id] or 0
                if count > 0 then
                        hasAny = true
                        local card = Instance.new("Frame")
                        card.Name = "InvCard_" .. block.id
                        card.Size = UDim2.new(1, -10, 0, 60)
                        card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                        card.BorderSizePixel = 0
                        card.ZIndex = 52
                        card.Parent = tabInventario
                        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

                        local cardStroke = Instance.new("UIStroke")
                        if equippedBlockId == block.id then
                                cardStroke.Color = Color3.fromRGB(80, 220, 80)
                                cardStroke.Thickness = 3
                        else
                                cardStroke.Color = Color3.fromRGB(255, 180, 80)
                                cardStroke.Thickness = 2
                        end
                        cardStroke.Transparency = 0.2
                        cardStroke.Parent = card

                        local preview = Instance.new("Frame")
                        preview.Size = UDim2.new(0, 50, 1, -10)
                        preview.Position = UDim2.new(0, 5, 0, 5)
                        preview.BackgroundColor3 = block.color
                        preview.BorderSizePixel = 0
                        preview.ZIndex = 53
                        preview.Parent = card
                        Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 6)

                        local infoLabel = Instance.new("TextLabel")
                        infoLabel.Size = UDim2.new(0.55, 0, 1, -10)
                        infoLabel.Position = UDim2.new(0, 60, 0, 5)
                        infoLabel.BackgroundTransparency = 1
                        infoLabel.Text = '<font color="#FFFFFF">' .. block.name .. '</font>\n<font color="#80C8FF">x' .. count .. '</font>'
                        infoLabel.RichText = true
                        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
                        infoLabel.TextYAlignment = Enum.TextYAlignment.Center
                        infoLabel.TextScaled = true
                        infoLabel.Font = Enum.Font.GothamBold
                        infoLabel.ZIndex = 53
                        infoLabel.Parent = card

                        local equipBtn = Instance.new("TextButton")
                        equipBtn.Size = UDim2.new(0.3, -5, 0.6, 0)
                        equipBtn.Position = UDim2.new(0.7, 5, 0.2, 0)
                        if equippedBlockId == block.id then
                                equipBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
                                equipBtn.Text = "✓ Equipado"
                        else
                                equipBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
                                equipBtn.Text = "Equipar"
                        end
                        equipBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                        equipBtn.TextScaled = true
                        equipBtn.Font = Enum.Font.GothamBold
                        equipBtn.ZIndex = 53
                        equipBtn.Parent = card
                        Instance.new("UICorner", equipBtn).CornerRadius = UDim.new(0, 6)

                        equipBtn.MouseButton1Click:Connect(function()
                                equippedBlockId = block.id
                                updateInventarioTab()
                                updateHotbar()
                                selectTab(3) -- saltar a la tab de modo construccion
                                print("[Build] Bloque equipado: " .. block.name)
                        end)
                end
        end
        if not hasAny then
                local empty = Instance.new("TextLabel")
                empty.Size = UDim2.new(1, -10, 0, 60)
                empty.BackgroundTransparency = 1
                empty.Text = "No tienes bloques. Ve a Materiales y compra algunos."
                empty.TextColor3 = Color3.fromRGB(180, 180, 180)
                empty.TextScaled = true
                empty.Font = Enum.Font.Gotham
                empty.ZIndex = 52
                empty.Parent = tabInventario
        end
end

-- Activar modo construccion (cierra panel, muestra hotbar y grid)
local function activateBuildMode()
        -- Permitir activar modo construccion aunque no haya bloques equipados.
        -- Si no hay bloque equipado, el hotbar aparecera vacio y al intentar colocar
        -- se le avisara al jugador que compre/equipe bloques.
        buildPanelOpen = false
        buildPanel.Visible = false
        buildModeActive = true
        buildBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
        -- Crear grid
        local parcel = findPlayerParcel()
        createGridVisual(parcel)
        -- Desactivar pelota si esta equipada
        if ballEquippedRef() then
                unequipBall()
        end
        -- Cerrar mochila y musica
        backpackPanel.Visible = false
        musicPanel.Visible = false
        updateHotbar()
        print("[Build] Modo construccion ACTIVADO (con hotbar)")
end

-- Desactivar modo construccion (cierra hotbar y grid)
local function deactivateBuildMode()
        buildModeActive = false
        buildPanelOpen = false
        buildPanel.Visible = false
        removeGridVisual()
        if ghostBlock then
                ghostBlock:Destroy()
                ghostBlock = nil
        end
        buildBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        updateHotbar()
        print("[Build] Modo construccion DESACTIVADO")
end

-- Abrir panel de construccion
local function openBuildPanel()
        if buildModeActive then
                -- Si el modo construccion esta activo, desactivarlo primero
                deactivateBuildMode()
        end
        buildPanelOpen = true
        buildPanel.Visible = true
        buildBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
        selectTab(1) -- abrir siempre en Materiales
        updateMaterialesTab()
        updateInventarioTab()
        -- Desactivar pelota si esta equipada
        if ballEquippedRef() then
                unequipBall()
        end
        -- Cerrar mochila y musica
        backpackPanel.Visible = false
        musicPanel.Visible = false
end

-- Cerrar panel de construccion
local function closeBuildPanel()
        buildPanelOpen = false
        buildPanel.Visible = false
        -- El color del boton hammer depende de si el modo construccion sigue activo
        if buildModeActive then
                buildBtn.BackgroundColor3 = Color3.fromRGB(80, 220, 100) -- verde (modo activo)
        else
                buildBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40) -- oscuro (nada activo)
        end
end

-- Toggle: si panel abierto -> cerrar. Si modo activo -> desactivar. Si nada -> abrir panel.
local function toggleBuild()
        if buildPanelOpen then
                closeBuildPanel()
        elseif buildModeActive then
                deactivateBuildMode()
        else
                openBuildPanel()
        end
end

-- ============================================
-- Conexiones de UI
-- ============================================

-- Boton hammer
buildBtn.MouseButton1Click:Connect(function()
        toggleBuild()
end)

-- Boton X del panel
bpBuildCloseBtn.MouseButton1Click:Connect(function()
        closeBuildPanel()
end)

-- Pestañas
for i, btn in ipairs(tabButtons) do
        btn.MouseButton1Click:Connect(function()
                selectTab(i)
                if i == 1 then updateMaterialesTab()
                elseif i == 2 then updateInventarioTab() end
        end)
end

-- Boton ACTIVAR MODO CONSTRUCCION (tab 3)
activarModoBtn.MouseButton1Click:Connect(function()
        activateBuildMode()
end)

-- Boton INVENTARIO (al lado del hotbar, en modo construccion activo)
-- Abre la pestaña Inventario del panel SIN desactivar el modo construccion.
-- El jugador puede equipar bloques y volver a colocar cerrando el panel.
invBtn.MouseButton1Click:Connect(function()
        if not buildModeActive then return end
        -- Mostrar panel y seleccionar tab Inventario
        buildPanelOpen = true
        buildPanel.Visible = true
        selectTab(2) -- tab Inventario
        updateInventarioTab()
end)

-- Cuando se abre mochila o musica, cerrar todo de build
backpackBtn.MouseButton1Click:Connect(function()
        if backpackPanel.Visible then
                if buildPanelOpen then closeBuildPanel() end
                if buildModeActive then deactivateBuildMode() end
        end
end)
musicBtn.MouseButton1Click:Connect(function()
        if musicPanel.Visible then
                if buildPanelOpen then closeBuildPanel() end
                if buildModeActive then deactivateBuildMode() end
        end
end)

-- Tecla B para toggle
UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.B then
                toggleBuild()
        end
end)

-- Aviso flotante (notificacion temporal en pantalla)
local function showBuildNotice(text, color)
        color = color or Color3.fromRGB(255, 180, 80)
        local notice = Instance.new("TextLabel")
        notice.Name = "BuildNotice"
        notice.Size = UDim2.new(0, 400, 0, 50)
        notice.Position = UDim2.new(0.5, -200, 0.3, 0)
        notice.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        notice.BackgroundTransparency = 0.1
        notice.BorderSizePixel = 0
        notice.Text = text
        notice.TextColor3 = color
        notice.TextScaled = true
        notice.Font = Enum.Font.GothamBold
        notice.ZIndex = 200
        notice.Parent = screenGui
        Instance.new("UICorner", notice).CornerRadius = UDim.new(0, 12)
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = 2
        stroke.Transparency = 0.2
        stroke.Parent = notice
        -- Animar: aparece, espera 2s, desaparece con fade
        task.spawn(function()
                notice.TextTransparency = 1
                notice.BackgroundTransparency = 1
                stroke.Transparency = 1
                -- Fade in
                for i = 1, 10 do
                        notice.TextTransparency = 1 - (i * 0.1)
                        notice.BackgroundTransparency = 1 - (i * 0.1) * 0.9
                        stroke.Transparency = 1 - (i * 0.1) * 0.8
                        task.wait(0.02)
                end
                task.wait(2)
                -- Fade out
                for i = 1, 10 do
                        notice.TextTransparency = i * 0.1
                        notice.BackgroundTransparency = 1 - (1 - i * 0.1) * 0.9
                        stroke.Transparency = 1 - (1 - i * 0.1) * 0.8
                        task.wait(0.02)
                end
                if notice and notice.Parent then
                        notice:Destroy()
                end
        end)
end

-- Click izquierdo: colocar / Click derecho: quitar (solo en modo construccion activo)
UserInputService.InputBegan:Connect(function(input, processed)
        if not buildModeActive then return end
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                -- Verificar si hay bloque equipado
                if not equippedBlockId or not blockInventory[equippedBlockId] or blockInventory[equippedBlockId] <= 0 then
                        showBuildNotice("⚠ No tienes bloques equipados. Compra en Materiales y equipa en Inventario.", Color3.fromRGB(255, 100, 100))
                        return
                end
                if ghostBlock and ghostBlock.LocalTransparencyModifier < 1 and canPlace then
                        PlaceBlockEvent:FireServer(equippedBlockId, ghostBlock.Position, nil)
                elseif ghostBlock and ghostBlock.LocalTransparencyModifier < 1 and not canPlace then
                        showBuildNotice("⚠ No puedes colocar aqui (fuera de parcela o posicion ocupada)", Color3.fromRGB(255, 100, 100))
                end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                local mouseTarget = mouse.Target
                if mouseTarget and string.sub(mouseTarget.Name, 1, 6) == "Block_" then
                        RemoveBlockEvent:FireServer(mouseTarget)
                end
        end
end)

-- Touch para mobile
UserInputService.InputBegan:Connect(function(input, processed)
        if not buildModeActive then return end
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Touch then
                -- Verificar si hay bloque equipado
                if not equippedBlockId or not blockInventory[equippedBlockId] or blockInventory[equippedBlockId] <= 0 then
                        showBuildNotice("⚠ No tienes bloques equipados. Compra en Materiales y equipa en Inventario.", Color3.fromRGB(255, 100, 100))
                        return
                end
                if ghostBlock and ghostBlock.LocalTransparencyModifier < 1 and canPlace then
                        PlaceBlockEvent:FireServer(equippedBlockId, ghostBlock.Position, nil)
                end
        end
end)

-- Loop para actualizar ghost block
RunService.RenderStepped:Connect(function()
        if buildModeActive then
                updateGhostBlock()
        end
end)

-- Recibir inventario actualizado del servidor
UpdateInventoryEvent.OnClientEvent:Connect(function(inventoryData)
        blockInventory = inventoryData or {}
        updateInventarioTab()
        updateHotbar()
        -- Si el bloque equipado se acabo, NO desactivar el modo construccion.
        -- El jugador puede seguir en modo construccion; el hotbar mostrara "Sin bloque"
        -- y al intentar colocar se le avisara que compre/equipe bloques.
        -- Solo actualizamos el hotbar para que refleje el count actualizado.
end)


end

return BuildSystem

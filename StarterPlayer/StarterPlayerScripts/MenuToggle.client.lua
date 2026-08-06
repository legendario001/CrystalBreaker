-- ============================================
-- MenuToggle (LocalScript) - StarterPlayerScripts
-- Boton flecha en el borde izquierdo-centro que despliega/oculta
-- un panel 3x3 al centro de la pantalla con todos los botones del juego.
-- ============================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================
-- ScreenGui principal del menu
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MenuToggleGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 50 -- encima de la mayoria de GUIs pero debajo de popups
screenGui.Parent = playerGui

-- ============================================
-- Boton flecha (borde izquierdo-centro)
-- ============================================
local arrowBtn = Instance.new("TextButton")
arrowBtn.Name = "MenuArrow"
arrowBtn.Size = UDim2.new(0, 50, 0, 80)
arrowBtn.Position = UDim2.new(0, 8, 0.5, -40) -- borde izquierdo, centro vertical
arrowBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
arrowBtn.BackgroundTransparency = 0.15
arrowBtn.BorderSizePixel = 0
arrowBtn.Text = ">"
arrowBtn.TextColor3 = Color3.fromRGB(255, 215, 60)
arrowBtn.TextScaled = true
arrowBtn.Font = Enum.Font.GothamBlack
arrowBtn.AutoButtonColor = true
arrowBtn.Parent = screenGui
Instance.new("UICorner", arrowBtn).CornerRadius = UDim.new(0, 12)

local arrowStroke = Instance.new("UIStroke", arrowBtn)
arrowStroke.Color = Color3.fromRGB(255, 215, 60)
arrowStroke.Thickness = 2
arrowStroke.Transparency = 0.2

local arrowTextStroke = Instance.new("UIStroke", arrowBtn)
arrowTextStroke.Color = Color3.fromRGB(0, 0, 0)
arrowTextStroke.Thickness = 3
arrowTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- ============================================
-- Panel 3x3 al centro de la pantalla
-- Panel 380x380, padding 15, cells 100, gaps 15
-- 3*100 + 2*15 = 330, disponible = 380-30 = 350 (margen 20px)
-- ============================================
local PANEL_W = 380
local PANEL_H = 380
local CELL = 100 -- tamaño de cada slot
local GAP = 15 -- separacion entre slots

local panel = Instance.new("Frame")
panel.Name = "MenuPanel"
panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position = UDim2.new(0.5, -PANEL_W/2, 0.5, -PANEL_H/2)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)

local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(255, 215, 60)
panelStroke.Thickness = 2.5
panelStroke.Transparency = 0.15

-- Padding interno (15px para que los 9 slots quepan con margen)
local panelPadding = Instance.new("UIPadding", panel)
panelPadding.PaddingLeft = UDim.new(0, 15)
panelPadding.PaddingRight = UDim.new(0, 15)
panelPadding.PaddingTop = UDim.new(0, 15)
panelPadding.PaddingBottom = UDim.new(0, 15)

-- GridLayout 3x3
local grid = Instance.new("UIGridLayout", panel)
grid.CellSize = UDim2.new(0, CELL, 0, CELL)
grid.CellPadding = UDim2.new(0, GAP, 0, GAP)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.FillDirection = Enum.FillDirection.Horizontal
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.VerticalAlignment = Enum.VerticalAlignment.Center

-- ============================================
-- Slots 3x3 (9 slots totales)
-- ============================================
local slots = {}
local slotOrder = 1

-- Botones conocidos a mover (en orden de slot 1-5)
local buttonNames = {
        "ShopButton",   -- slot 1
        "BuildBtn",     -- slot 2 (martillo)
        "MusicBtn",     -- slot 3 (musica)
        "BackpackBtn",  -- slot 4 (mochila)
        "RebirthBtn",   -- slot 5 (renacer)
}

-- Crear los 9 slots (5 para botones conocidos, 4 vacios como placeholders)
for i = 1, 9 do
        local slot = Instance.new("Frame")
        slot.Name = "Slot" .. i
        slot.LayoutOrder = i
        slot.Size = UDim2.new(0, CELL, 0, CELL)
        slot.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        slot.BackgroundTransparency = 0.5
        slot.BorderSizePixel = 0
        slot.Parent = panel
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 12)

        local slotStroke = Instance.new("UIStroke", slot)
        slotStroke.Color = Color3.fromRGB(80, 80, 100)
        slotStroke.Thickness = 1.5
        slotStroke.Transparency = 0.5

        -- Label "Vacio" para slots que no tienen boton (se oculta cuando se mueve un boton ahi)
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Name = "EmptyLabel"
        emptyLabel.Size = UDim2.new(1, 0, 1, 0)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = (i <= #buttonNames) and "" or "Vacio"
        emptyLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
        emptyLabel.TextScaled = true
        emptyLabel.Font = Enum.Font.GothamBold
        emptyLabel.TextTransparency = 0.4
        emptyLabel.Parent = slot

        slots[i] = {frame = slot, emptyLabel = emptyLabel, occupied = false}
end

-- ============================================
-- Mover botones existentes a los slots
-- ============================================
-- Forward declaration para que moveButtonToSlot pueda cerrar el panel al click
local closePanel

local function moveButtonToSlot(button, slotIdx)
        if not button or not button.Parent then return false end
        local slot = slots[slotIdx]
        if not slot then return false end

        -- Guardar informacion para poder restaurar si es necesario
        button:SetAttribute("OriginalParent", button.Parent.Name)
        button:SetAttribute("OriginalSize", tostring(button.Size))
        button:SetAttribute("OriginalPosition", tostring(button.Position))

        -- Mover el boton al slot
        button.Parent = slot.frame
        button.Size = UDim2.new(1, 0, 1, 0)
        button.Position = UDim2.new(0, 0, 0, 0)
        button.LayoutOrder = 0 -- para que se dibuje encima del slot

        -- Ocultar el label "Vacio"
        slot.emptyLabel.Visible = false
        slot.occupied = true

        -- FIX: Conectar click para cerrar el menu al hacer click en cualquier boton
        -- Esto permite que el sub-panel (mochila, shop, etc.) se vea encima de todo
        button.MouseButton1Click:Connect(function()
                task.wait(0.05) -- pequeno delay para que el click del boton se procese primero
                if closePanel then closePanel() end
        end)

        print("[MenuToggle] Boton " .. button.Name .. " movido al slot " .. slotIdx)
        return true
end

-- Buscar y mover cada boton (con timeout, esperando a que los otros scripts los creen)
local function findButtonByName(name)
        -- Buscar en todos los ScreenGuis del PlayerGui
        for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                        local btn = gui:FindFirstChild(name, true)
                        if btn and btn:IsA("TextButton") then
                                return btn
                        end
                end
        end
        return nil
end

-- Esperar a que todos los botones esten creados y moverlos
-- Los otros scripts pueden tardar hasta 15s en cargar (esperan RemoteEvents)
task.spawn(function()
        -- Esperar minimo inicial para que los scripts comiencen a cargar
        task.wait(3)

        -- Reintentar hasta 30s para encontrar cada boton
        local maxAttempts = 30
        for i, btnName in ipairs(buttonNames) do
                local btn = nil
                local attempts = 0
                while not btn and attempts < maxAttempts do
                        btn = findButtonByName(btnName)
                        if not btn then
                                task.wait(1)
                                attempts = attempts + 1
                        end
                end
                if btn then
                        moveButtonToSlot(btn, i)
                else
                        warn("[MenuToggle] No se encontro boton '" .. btnName .. "' despues de " .. maxAttempts .. "s para slot " .. i)
                end
        end
end)

-- ============================================
-- Toggle del panel (flecha)
-- ============================================
local isPanelOpen = false

local function closePanelImpl()
        if not isPanelOpen then return end
        isPanelOpen = false
        arrowBtn.Text = ">"
        local tween = TweenService:Create(panel,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 0, 0, 0)}
        )
        tween:Play()
        tween.Completed:Connect(function()
                panel.Visible = false
        end)
        print("[MenuToggle] Panel cerrado")
end

-- Asignar a la forward declaration
closePanel = closePanelImpl

local function openPanel()
        if isPanelOpen then return end
        isPanelOpen = true
        arrowBtn.Text = "<"
        panel.Visible = true
        panel.Size = UDim2.new(0, 0, 0, 0)
        local tween = TweenService:Create(panel,
                TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, PANEL_W, 0, PANEL_H)}
        )
        tween:Play()
        print("[MenuToggle] Panel abierto")
end

local function togglePanel()
        if isPanelOpen then
                closePanel()
        else
                openPanel()
        end
end

arrowBtn.MouseButton1Click:Connect(togglePanel)

print("[MenuToggle] Sistema de menu 3x3 cargado")

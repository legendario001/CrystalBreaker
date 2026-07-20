-- ============================================
-- ShopSystem (ModuleScript) - StarterPlayer/StarterPlayerScripts
-- Sistema de tienda: detecta proximidad, muestra boton E, abre la mochila
-- Funciona igual que BankSystem pero abre el panel de pelotas (backpackPanel)
-- ============================================

local ShopSystem = {}

function ShopSystem.init(deps)
        local player = deps.player
        local screenGui = deps.screenGui
        local UserInputService = deps.UserInputService
        local RunService = deps.RunService
        local Workspace = deps.Workspace
        local ReplicatedStorage = deps.ReplicatedStorage
        local backpackPanel = deps.backpackPanel
        local openBackpack = deps.openBackpack -- funcion que abre la mochila (setVisible + updateBackpackUI)

        -- Posicion de la tienda (donde aparece el boton E)
        local SHOP_POSITION = Vector3.new(26.981, 3.368, -0.8)
        local SHOP_INTERACT_DISTANCE = 18 -- studs para mostrar la E

        -- Estado
        local nearShop = false
        local shopPanelOpen = false -- trackea si la mochila esta abierta por la tienda

        -- ============================================
        -- Crear Part ancla en la posicion de la tienda
        -- ============================================
        local shopPart = Instance.new("Part")
        shopPart.Name = "ShopAnchor"
        shopPart.Anchored = true
        shopPart.CanCollide = false
        shopPart.CanQuery = false
        shopPart.CanTouch = false
        shopPart.Transparency = 1
        shopPart.Size = Vector3.new(0.1, 0.1, 0.1)
        shopPart.Position = SHOP_POSITION
        shopPart.Parent = Workspace

        -- BillboardGui con la imagen E (no se ve, solo referencia visual)
        local shopBillboard = Instance.new("BillboardGui")
        shopBillboard.Name = "ShopInteractGui"
        shopBillboard.Size = UDim2.new(0, 80, 0, 80)
        shopBillboard.StudsOffset = Vector3.new(0, -3, 0) -- 3 studs abajo
        shopBillboard.AlwaysOnTop = true
        shopBillboard.LightInfluence = 0
        shopBillboard.MaxDistance = 40
        shopBillboard.Enabled = false
        shopBillboard.Parent = shopPart

        local eImage = Instance.new("ImageLabel")
        eImage.Size = UDim2.new(1, 0, 1, 0)
        eImage.BackgroundTransparency = 1
        eImage.Image = "rbxassetid://78972021775884"
        eImage.ScaleType = Enum.ScaleType.Fit
        eImage.Parent = shopBillboard

        -- ============================================
        -- Boton clickable en ScreenGui (sigue a la tienda en pantalla)
        -- BillboardGui no recibe touch en movil, por eso usamos ScreenGui
        -- ============================================
        local camera = Workspace.CurrentCamera
        local shopClickBtn = Instance.new("TextButton")
        shopClickBtn.Name = "ShopClickBtn"
        shopClickBtn.Size = UDim2.new(0, 100, 0, 100)
        shopClickBtn.Position = UDim2.new(0.5, -50, 0.5, -50)
        shopClickBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        shopClickBtn.BackgroundTransparency = 1
        shopClickBtn.BorderSizePixel = 0
        shopClickBtn.Text = ""
        shopClickBtn.Visible = false
        shopClickBtn.ZIndex = 100
        shopClickBtn.Parent = screenGui

        local screenEImage = Instance.new("ImageLabel")
        screenEImage.Size = UDim2.new(1, 0, 1, 0)
        screenEImage.BackgroundTransparency = 1
        screenEImage.Image = "rbxassetid://78972021775884"
        screenEImage.ScaleType = Enum.ScaleType.Fit
        screenEImage.Parent = shopClickBtn

        -- Funcion para abrir la mochila desde la tienda
        local function openShopPanel()
                if openBackpack then
                        openBackpack()
                elseif backpackPanel then
                        backpackPanel.Visible = true
                end
                shopPanelOpen = true
        end

        shopClickBtn.MouseButton1Click:Connect(function()
                if nearShop then
                        if backpackPanel and backpackPanel.Visible then
                                -- Si ya esta abierta, cerrarla
                                backpackPanel.Visible = false
                                shopPanelOpen = false
                        else
                                openShopPanel()
                        end
                end
        end)

        print("[ShopSystem] Part ancla de tienda creado en " .. tostring(SHOP_POSITION))

        -- ============================================
        -- Deteccion de proximidad + input E
        -- ============================================

        RunService.Heartbeat:Connect(function()
                if not shopPart or not shopPart.Parent then return end
                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local dist = (root.Position - shopPart.Position).Magnitude
                nearShop = dist < SHOP_INTERACT_DISTANCE

                -- Ocultar billboard (usamos el boton ScreenGui)
                if shopBillboard then
                        shopBillboard.Enabled = false
                end

                -- Posicionar y mostrar/ocultar el boton ScreenGui
                if nearShop and not (backpackPanel and backpackPanel.Visible) then
                        local screenPos, onScreen = camera:WorldToViewportPoint(shopPart.Position + Vector3.new(0, 3, 0))
                        if onScreen then
                                shopClickBtn.Visible = true
                                shopClickBtn.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y - 50)
                        else
                                shopClickBtn.Visible = false
                        end
                else
                        shopClickBtn.Visible = false
                end
        end)

        -- Input E para abrir tienda (PC)
        UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == Enum.KeyCode.E then
                        if nearShop then
                                if backpackPanel and backpackPanel.Visible then
                                        backpackPanel.Visible = false
                                        shopPanelOpen = false
                                else
                                        openShopPanel()
                                end
                        end
                end
        end)

        print("[ShopSystem] Sistema de tienda cargado!")
end

return ShopSystem

-- ============================================
-- CrystalSpawner (Script) - ServerScriptService
-- Genera 25 cristales en la zona de cristales
-- Rareza: Morado (raro) > Rojo > Amarillo > Azul > Blanco (comun)
-- ============================================

local Workspace = game:GetService("Workspace")

local CrystalSpawner = {}

-- Colores y rareza de cristales
local CRYSTAL_TYPES = {
        {color = Color3.fromRGB(170, 85, 255), name = "Morado", weight = 3},   -- Mas raro
        {color = Color3.fromRGB(255, 80, 80),  name = "Rojo",    weight = 6},
        {color = Color3.fromRGB(255, 255, 100), name = "Amarillo", weight = 12},
        {color = Color3.fromRGB(85, 170, 255),  name = "Azul",    weight = 25},
        {color = Color3.fromRGB(220, 220, 220), name = "Blanco",  weight = 54}  -- Menos raro
}

-- Elegir rareza aleatoria basada en pesos
local function pickRarity()
        local total = 0
        for _, t in ipairs(CRYSTAL_TYPES) do
                total = total + t.weight
        end
        local roll = math.random(total)
        local cum = 0
        for _, t in ipairs(CRYSTAL_TYPES) do
                cum = cum + t.weight
                if roll <= cum then
                        return t
                end
        end
        return CRYSTAL_TYPES[#CRYSTAL_TYPES]
end

function CrystalSpawner.spawnAll()
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        local zone = map:FindFirstChild("CrystalZone")
        if not zone then return end

        -- Limpiar cristales anteriores
        for _, c in ipairs(zone:GetChildren()) do
                if c.Name == "Crystal" then c:Destroy() end
        end

        -- Zona invisible (solo para referencia)
        zone.CanQuery = false
        zone.CanCollide = false
        zone.Transparency = 1

        local zonePos = zone.Position
        local zoneSize = zone.Size
        local halfX = zoneSize.X / 2 - 4
        local halfZ = zoneSize.Z / 2 - 4
        local topY = zonePos.Y + zoneSize.Y / 2 + 2.5
        local MIN_DISTANCE = 8

        -- Guardar posiciones ya usadas para evitar cristales pegados
        local usedPositions = {}

        -- Funcion para encontrar posicion valida
        local function findValidPosition()
                for attempt = 1, 50 do
                        local x = zonePos.X + math.random() * halfX * 2 - halfX
                        local z = zonePos.Z + math.random() * halfZ * 2 - halfZ
                        local pos = Vector3.new(x, topY, z)

                        local valid = true
                        for _, usedPos in ipairs(usedPositions) do
                                if (pos - usedPos).Magnitude < MIN_DISTANCE then
                                        valid = false
                                        break
                                end
                        end

                        if valid then
                                return pos
                        end
                end
                -- Si no encuentra posicion valida despues de 50 intentos, usar la ultima
                local x = zonePos.X + math.random() * halfX * 2 - halfX
                local z = zonePos.Z + math.random() * halfZ * 2 - halfZ
                return Vector3.new(x, topY, z)
        end

        -- Generar 25 cristales
        for i = 1, 25 do
                local crystalType = pickRarity()

                local crystal = Instance.new("Part")
                crystal.Name = "Crystal"
                crystal.Size = Vector3.new(2.5, 5, 2.5)
                crystal.Material = Enum.Material.Ice
                crystal.Transparency = 0.15
                crystal.Anchored = true
                crystal.CanCollide = true
                crystal.CanQuery = true

                local pos = findValidPosition()
                table.insert(usedPositions, pos)
                crystal.Position = pos
                crystal.Color = crystalType.color
                crystal.Parent = zone

                -- Tag de rareza
                local rarityTag = Instance.new("StringValue")
                rarityTag.Name = "Rarity"
                rarityTag.Value = crystalType.name
                rarityTag.Parent = crystal

                -- Etiqueta de rareza sobre el cristal
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(3, 0, 1, 0)
                bb.StudsOffset = Vector3.new(0, 3.5, 0)
                bb.AlwaysOnTop = false
                bb.Parent = crystal

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = crystalType.name
                lbl.TextColor3 = crystalType.color
                lbl.TextScaled = true
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = bb

                -- Vida del cristal
                local hp = Instance.new("IntValue")
                hp.Name = "Health"
                hp.Value = 10
                hp.Parent = crystal

                local mhp = Instance.new("IntValue")
                mhp.Name = "MaxHealth"
                mhp.Value = 10
                mhp.Parent = crystal
        end

        print("=== 25 cristales generados ===")
end

-- Respawn un cristal en una posicion
function CrystalSpawner.respawn(oldPos)
        task.delay(5, function()
                local map = Workspace:FindFirstChild("Map")
                if not map then return end
                local zone = map:FindFirstChild("CrystalZone")
                if not zone then return end

                local crystalType = pickRarity()

                local crystal = Instance.new("Part")
                crystal.Name = "Crystal"
                crystal.Size = Vector3.new(2.5, 5, 2.5)
                crystal.Material = Enum.Material.Ice
                crystal.Transparency = 0.15
                crystal.Anchored = true
                crystal.CanCollide = true
                crystal.Position = oldPos
                crystal.Color = crystalType.color
                crystal.Parent = zone

                local rarityTag = Instance.new("StringValue")
                rarityTag.Name = "Rarity"
                rarityTag.Value = crystalType.name
                rarityTag.Parent = crystal

                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(3, 0, 1, 0)
                bb.StudsOffset = Vector3.new(0, 3.5, 0)
                bb.AlwaysOnTop = false
                bb.Parent = crystal

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = crystalType.name
                lbl.TextColor3 = crystalType.color
                lbl.TextScaled = true
                lbl.Font = Enum.Font.GothamBold
                lbl.Parent = bb

                local hp = Instance.new("IntValue")
                hp.Name = "Health"
                hp.Value = 10
                hp.Parent = crystal

                local mhp = Instance.new("IntValue")
                mhp.Name = "MaxHealth"
                mhp.Value = 10
                mhp.Parent = crystal
        end)
end

return CrystalSpawner

-- ============================================
-- DonationManager (ModuleScript) - ServerStorage/ServerModules
-- Mantiene un leaderboard global de los TOP DONADORES (por robux donado)
-- Usa un DataStore global con todas las donaciones
-- Spawnea los personajes del Top 3 en pedestales con animacion de baile
--
-- Modelo esperado en Workspace: "TablaDonadores"
--   - Part "LeaderboardScreen" (pizarron)
--   - Folder "Pedestals" con Top1Pedestal, Top2Pedestal, Top3Pedestal
--   - Part "Top1Spawn", "Top2Spawn", "Top3Spawn" (donde aparece el personaje)
--   - Folder "TopCharacters" (vacio, donde se ponen los personajes spawneados)
-- ============================================

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DonationManager = {}

-- DataStore global con todas las donaciones: { [userId] = totalRobuxDonated }
local donationStore = DataStoreService:GetDataStore("DonationLeaderboard_v1")

-- Cache en memoria: { [userId] = robuxDonated }
local allDonations = {}

-- Top 3 cacheado (lista ordenada de mayor a menor)
local top3 = {}

-- Configuracion de pedestales (posiciones de los Top#Spawn dentro de TablaDonadores)
local PEDESTAL_SPAWN_NAMES = {
        [1] = "Top1Spawn",  -- position 146, 6.1, 73.4
        [2] = "Top2Spawn",  -- position 146, 5.1, 79.4
        [3] = "Top3Spawn",  -- position 146, 4.1, 85.4
}
local DANCE_ANIMATION_ID = "rbxassetid://127874881693302"

-- Personajes actualmente spawneados (para limpiar al actualizar)
local spawnedCharacters = {}

-- Folder donde se ponen los personajes del Top 3
local topCharactersFolder = nil

-- ============================================
-- Cargar y guardar el DataStore global
-- ============================================

function DonationManager.loadAll()
        local success, data = pcall(function()
                return donationStore:GetAsync("all_donations")
        end)
        if success and data then
                allDonations = data
                local count = 0
                for _ in pairs(data) do count = count + 1 end
                print("[DonationManager] Cargadas " .. count .. " donaciones desde DataStore")
        else
                print("[DonationManager] No habia datos previos, iniciando vacio")
                allDonations = {}
        end
        DonationManager.recalculateTop()
end

function DonationManager.saveAll()
        local success, err = pcall(function()
                donationStore:SetAsync("all_donations", allDonations)
        end)
        if not success then
                warn("[DonationManager] Error al guardar: " .. tostring(err))
        end
end

-- Agregar robux donado a un jugador
function DonationManager.addDonation(userId, robuxAmount)
        if not userId or not robuxAmount or robuxAmount <= 0 then return end
        local current = allDonations[userId] or 0
        allDonations[userId] = current + robuxAmount
        print("[DonationManager] +" .. robuxAmount .. " R$ para userId " .. userId .. " (total: " .. allDonations[userId] .. ")")
end

function DonationManager.recalculateTop()
        local sorted = {}
        for userId, amount in pairs(allDonations) do
                table.insert(sorted, { userId = userId, amount = amount })
        end
        table.sort(sorted, function(a, b) return a.amount > b.amount end)

        top3 = {}
        for i = 1, math.min(3, #sorted) do
                table.insert(top3, sorted[i])
        end
end

function DonationManager.getTop3()
        return top3
end

-- ============================================
-- Manejo de personajes del Top 3 (bailando en pedestales)
-- ============================================

local function clearSpawnedCharacters()
        for _, model in ipairs(spawnedCharacters) do
                if model and model.Parent then
                        model:Destroy()
                end
        end
        spawnedCharacters = {}
end

local function ensureTopCharactersFolder()
        local tablaModel = Workspace:FindFirstChild("TablaDonadores")
        if not tablaModel then return nil end
        topCharactersFolder = tablaModel:FindFirstChild("TopCharacters")
        if not topCharactersFolder then
                topCharactersFolder = Instance.new("Folder")
                topCharactersFolder.Name = "TopCharacters"
                topCharactersFolder.Parent = tablaModel
        end
        return topCharactersFolder
end

-- Spawnear un personaje del Top 3 en su pedestal
local function spawnTopCharacter(rank, userId)
        if not userId then return nil end

        local tablaModel = Workspace:FindFirstChild("TablaDonadores")
        if not tablaModel then return nil end

        -- Buscar el Part Top#Spawn dentro del modelo
        local spawnPart = tablaModel:FindFirstChild(PEDESTAL_SPAWN_NAMES[rank], true)
        if not spawnPart then
                warn("[DonationManager] No se encontro " .. PEDESTAL_SPAWN_NAMES[rank] .. " en TablaDonadores")
                return nil
        end
        local position = spawnPart.Position

        -- Crear modelo del avatar del jugador
        local success, model = pcall(function()
                return Players:CreateHumanoidModelFromUserId(userId)
        end)
        if not success or not model then
                warn("[DonationManager] No se pudo crear modelo para userId " .. userId)
                return nil
        end

        -- Asegurar PrimaryPart
        if not model.PrimaryPart then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hrp then
                        model.PrimaryPart = hrp
                else
                        for _, p in ipairs(model:GetDescendants()) do
                                if p:IsA("BasePart") then
                                        model.PrimaryPart = p
                                        break
                                end
                        end
                end
        end

        -- Hacer partes no colisionables
        for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.CanQuery = false
                        part.CanTouch = false
                end
        end

        -- Posicionar: sumar offset en Y para que se pare encima del pedestal
        local spawnPosition = position + Vector3.new(0, 5, 0)
        local spawnCFrame = CFrame.new(spawnPosition) * CFrame.Angles(0, math.rad(90), 0)
        model:PivotTo(spawnCFrame)

        -- Parent al folder
        local folder = ensureTopCharactersFolder()
        if folder then
                model.Parent = folder
        else
                model.Parent = Workspace
        end

        -- Configurar Humanoid
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
                humanoid.JumpHeight = 0
                humanoid.AutoRotate = false
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
                humanoid.BreakJointsOnDeath = false
                humanoid.PlatformStand = true

                -- Animacion de baile
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if not animator then
                        animator = Instance.new("Animator")
                        animator.Parent = humanoid
                end
                local animation = Instance.new("Animation")
                animation.AnimationId = DANCE_ANIMATION_ID
                local track = animator:LoadAnimation(animation)
                track.Looped = true
                track.Priority = Enum.AnimationPriority.Action
                track:Play()
        end

        -- Fijar posicion con BodyPosition + BodyGyro
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then
                local bodyPos = Instance.new("BodyPosition")
                bodyPos.Name = "LockPosition"
                bodyPos.Position = spawnPosition
                bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyPos.P = 10000
                bodyPos.D = 500
                bodyPos.Parent = hrp

                local bodyGyro = Instance.new("BodyGyro")
                bodyGyro.Name = "LockRotation"
                bodyGyro.CFrame = spawnCFrame
                bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bodyGyro.P = 10000
                bodyGyro.D = 500
                bodyGyro.Parent = hrp
        end

        -- Etiqueta con nombre y rango
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "RankLabel"
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "#" .. rank .. " " .. (Players:GetNameFromUserIdAsync(userId) or "Donador")
        label.TextColor3 = (rank == 1 and Color3.fromRGB(255, 215, 0)) or
                           (rank == 2 and Color3.fromRGB(192, 192, 192)) or
                           Color3.fromRGB(205, 127, 50)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBlack
        label.TextStrokeTransparency = 0.5
        label.Parent = billboard

        return model
end

-- Actualizar los personajes del Top 3
function DonationManager.updateTop3Characters()
        clearSpawnedCharacters()
        for rank = 1, 3 do
                if top3[rank] then
                        local model = spawnTopCharacter(rank, top3[rank].userId)
                        if model then
                                table.insert(spawnedCharacters, model)
                        end
                end
        end
        print("[DonationManager] Top 3 personajes actualizados")
end

return DonationManager

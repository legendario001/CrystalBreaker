-- ============================================
-- LeaderboardManager (ModuleScript) - ServerStorage/ServerModules
-- Mantiene un leaderboard global de los jugadores mas ricos (por bankBalance)
-- Usa un DataStore global con todos los saldos
-- Spawnea los personajes del Top 3 en pedestales con animacion de baile
-- ============================================

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LeaderboardManager = {}

-- DataStore global con todos los saldos: { [userId] = bankBalance }
local leaderboardStore = DataStoreService:GetDataStore("LeaderboardBankBalances_v2")

-- Cache en memoria: { [userId] = balance }
local allBalances = {}

-- Top 30 cacheado (lista ordenada de mayor a menor)
local top30 = {}

-- Configuracion de pedestales y animacion
local PEDESTAL_POSITIONS = {
        [1] = Vector3.new(146, 2, 48),    -- Top 1
        [2] = Vector3.new(146, 1.5, 54),  -- Top 2
        [3] = Vector3.new(146, 1, 60),    -- Top 3
}
local DANCE_ANIMATION_ID = "rbxassetid://127874881693302"

-- Personajes actualmente spawneados (para limpiar al actualizar)
local spawnedCharacters = {}

-- Folder donde se ponen los personajes del Top 3
local topCharactersFolder = nil

-- ============================================
-- Cargar y guardar el DataStore global
-- ============================================

-- Cargar todos los saldos desde el DataStore al iniciar el servidor
function LeaderboardManager.loadAll()
        local success, data = pcall(function()
                return leaderboardStore:GetAsync("all_balances")
        end)
        if success and data then
                allBalances = data
                -- Contar cuantos saldos hay
                local count = 0
                for _ in pairs(data) do count = count + 1 end
                print("[Leaderboard] " .. count .. " saldos cargados desde DataStore")
        else
                print("[Leaderboard] No habia datos guardados (empezando vacio)")
                allBalances = {}
        end
        LeaderboardManager.recalculateTop()
end

-- Guardar todos los saldos en el DataStore
function LeaderboardManager.saveAll()
        local success, err = pcall(function()
                leaderboardStore:SetAsync("all_balances", allBalances)
        end)
        if not success then
                warn("[Leaderboard] Error al guardar saldos: " .. tostring(err))
        else
                print("[Leaderboard] Saldos guardados en DataStore")
        end
end

-- Actualizar el saldo de un jugador en el cache
function LeaderboardManager.updateBalance(userId, balance)
        allBalances[tostring(userId)] = balance
end

-- Recalcular el top 30
function LeaderboardManager.recalculateTop()
        local sorted = {}
        for userIdStr, balance in pairs(allBalances) do
                if balance > 0 then
                        table.insert(sorted, {
                                userId = tonumber(userIdStr),
                                userIdStr = userIdStr,
                                balance = balance,
                        })
                end
        end
        table.sort(sorted, function(a, b)
                return a.balance > b.balance
        end)

        top30 = {}
        for i = 1, math.min(30, #sorted) do
                table.insert(top30, sorted[i])
        end

        print("[Leaderboard] Top recalculado: " .. #top30 .. " jugadores en el ranking")
end

-- Obtener el top 30
function LeaderboardManager.getTop30()
        return top30
end

-- ============================================
-- Spawnear personajes del Top 3 con animacion de baile
-- ============================================

-- Limpiar personajes spawneados anteriormente
local function clearSpawnedCharacters()
        for _, char in ipairs(spawnedCharacters) do
                if char and char.Parent then
                        char:Destroy()
                end
        end
        spawnedCharacters = {}
end

-- Crear el folder para los personajes si no existe
local function ensureTopCharactersFolder()
        local leaderboardModel = Workspace:FindFirstChild("LeaderBoard")
        if not leaderboardModel then return nil end
        topCharactersFolder = leaderboardModel:FindFirstChild("TopCharacters")
        if not topCharactersFolder then
                topCharactersFolder = Instance.new("Folder")
                topCharactersFolder.Name = "TopCharacters"
                topCharactersFolder.Parent = leaderboardModel
        end
        return topCharactersFolder
end

-- Spawnear un personaje del Top 3 en su pedestal
local function spawnTopCharacter(rank, userId)
        if not userId then return nil end

        local position = PEDESTAL_POSITIONS[rank]
        if not position then return nil end

        -- Crear modelo del avatar del jugador
        local success, model = pcall(function()
                return Players:CreateHumanoidModelFromUserId(userId)
        end)
        if not success or not model then
                warn("[Leaderboard] No se pudo crear modelo para userId " .. userId)
                return nil
        end

        -- Asegurar que el modelo tenga PrimaryPart (necesario para PivotTo)
        if not model.PrimaryPart then
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hrp then
                        model.PrimaryPart = hrp
                else
                        -- Buscar cualquier BasePart
                        for _, p in ipairs(model:GetDescendants()) do
                                if p:IsA("BasePart") then
                                        model.PrimaryPart = p
                                        break
                                end
                        end
                end
        end

        -- Hacer todas las partes no colisionables (para que no estorben)
        -- NO poner Anchored = true porque rompe las animaciones
        for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.CanQuery = false
                        part.CanTouch = false
                end
        end

        -- Posicionar el modelo: sumar offset en Y para que se pare encima del pedestal
        -- El HumanoidRootPart esta en el centro del cuerpo, asi que subimos ~5 studs
        -- Rotar +90 grados en Y (90 grados a la izquierda del jugador)
        local spawnPosition = position + Vector3.new(0, 5, 0)
        local spawnCFrame = CFrame.new(spawnPosition) * CFrame.Angles(0, math.rad(90), 0)
        model:PivotTo(spawnCFrame)

        -- Parent al folder ANTES de reproducir animacion (necesario para el Animator)
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
                -- Desactivar salud (no puede morir)
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
                humanoid.BreakJointsOnDeath = false
                -- Plataforma para que no se caiga
                humanoid.PlatformStand = true

                -- Cargar y reproducir animacion de baile
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

        -- Fijar el personaje en su posicion para que no se mueva al tocarlo
        -- Usamos BodyPosition + BodyGyro en el HumanoidRootPart (no rompe animaciones)
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then
                -- BodyPosition: fija la posicion (con fuerza alta para que no se mueva)
                local bodyPos = Instance.new("BodyPosition")
                bodyPos.Name = "LockPosition"
                bodyPos.Position = spawnPosition
                bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyPos.P = 10000 -- fuerza
                bodyPos.D = 500 -- amortiguacion
                bodyPos.Parent = hrp

                -- BodyGyro: fija la rotacion
                local bodyGyro = Instance.new("BodyGyro")
                bodyGyro.Name = "LockRotation"
                bodyGyro.CFrame = spawnCFrame
                bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bodyGyro.P = 10000
                bodyGyro.D = 500
                bodyGyro.Parent = hrp
        end

        -- Etiqueta con el nombre y rango
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "RankLabel"
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "#" .. rank .. " " .. (Players:GetNameFromUserIdAsync(userId) or "Jugador")
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
function LeaderboardManager.updateTop3Characters()
        clearSpawnedCharacters()

        for rank = 1, 3 do
                if top30[rank] then
                        local model = spawnTopCharacter(rank, top30[rank].userId)
                        if model then
                                table.insert(spawnedCharacters, model)
                        end
                end
        end

        print("[Leaderboard] Top 3 personajes actualizados")
end

return LeaderboardManager

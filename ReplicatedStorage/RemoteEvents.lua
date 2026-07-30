-- ============================================
-- RemoteEvents (ModuleScript) - ReplicatedStorage
-- Crea los RemoteEvents necesarios para el juego
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events = {}

local eventNames = {
        "ThrowBall",
        "PickupChest",
        "PlaceCharacter",
        "DropCharacter",
        "RemoveFromPedestal",
        "PickupDropped",
        "MoneyUpdate",
        "UpgradeCharacter",
        "UpgradeBase",
        "ChestOpen",
        "FusionUIUpdate",
        "DepositCharacter",
        "RemoveFromFusionSlot",
        "FuseCharacters",
        "EquipBall",
        "ShowBillEffect",
        "ShowUpgradeEffect",
        "PlaceBlock",
        "RemoveBlock",
        "OpenBuildMenu",
        "BuyBlock",
        "UpdateInventory",
        "DepositMoney",
        "WithdrawMoney",
        "BankUIUpdate",
        "LeaderboardUpdate",
        "BuyBall",
        "BallPurchased",
        "BallsRestored",
        "OfflineEarnings",
        "DonationLeaderboardUpdate",  -- Servidor -> Cliente: top 3 donadores
        "RequestDonationProducts",    -- Cliente -> Servidor: pedir lista de productos
        "DonationProductsResponse",   -- Servidor -> Cliente: respuesta con productos
        "BoostUpdate",                  -- Servidor -> Cliente: nivel de boost actualizado
        "RebirthRequest",              -- Cliente -> Servidor: pedir conteo o renacer
        "RebirthUpdate",                -- Servidor -> Cliente: actualizar conteo/bonus
}

for _, name in ipairs(eventNames) do
        local existing = ReplicatedStorage:FindFirstChild(name)
        if existing then
                events[name] = existing
        else
                local re = Instance.new("RemoteEvent")
                re.Name = name
                re.Parent = ReplicatedStorage
                events[name] = re
        end
end

-- RemoteFunctions (para consultas cliente -> servidor que necesitan respuesta)
local functionNames = {
        "GetPlayerParcel", -- cliente pide su parcela asignada, servidor responde con la Instance
}

for _, name in ipairs(functionNames) do
        local existing = ReplicatedStorage:FindFirstChild(name)
        if existing then
                events[name] = existing
        else
                local rf = Instance.new("RemoteFunction")
                rf.Name = name
                rf.Parent = ReplicatedStorage
                events[name] = rf
        end
end

return events









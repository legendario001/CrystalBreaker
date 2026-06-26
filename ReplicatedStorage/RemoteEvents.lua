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
	"PickupDropped"
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

return events

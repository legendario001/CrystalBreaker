-- ============================================
-- BankManager (ModuleScript) - ServerStorage/ServerModules
-- Maneja el saldo del banco de cada jugador
-- Permite depositar y retirar dinero
-- ============================================

local BankManager = {}

-- Saldos en memoria: [userId] = balance
local bankBalances = {}

-- Obtener el saldo del banco de un jugador
function BankManager.getBalance(userId)
	return bankBalances[userId] or 0
end

-- Establecer el saldo directamente (para cargar desde DataStore)
function BankManager.setBalance(userId, balance)
	bankBalances[userId] = balance or 0
end

-- Depositar dinero (devuelve nuevo saldo)
function BankManager.deposit(userId, amount)
	if not amount or amount <= 0 then return false, "Cantidad invalida" end
	if not bankBalances[userId] then bankBalances[userId] = 0 end
	bankBalances[userId] = bankBalances[userId] + amount
	return true, bankBalances[userId]
end

-- Retirar dinero (devuelve true + nuevo saldo, o false + error)
function BankManager.withdraw(userId, amount)
	if not amount or amount <= 0 then return false, "Cantidad invalida" end
	if not bankBalances[userId] then bankBalances[userId] = 0 end
	if bankBalances[userId] < amount then
		return false, "Saldo insuficiente en el banco"
	end
	bankBalances[userId] = bankBalances[userId] - amount
	return true, bankBalances[userId]
end

-- Limpiar saldo al salir el jugador (los datos ya estan guardados en DataStore)
function BankManager.cleanupPlayer(userId)
	bankBalances[userId] = nil
end

return BankManager

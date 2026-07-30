# 🔄 Sistema de Renacimiento (Rebirth) por Rareza

Sistema de prestigio/endgame para CrystalBreaker. El jugador que ya completó el juego (tiene todas las pelotas, rompe todos los cristales) puede "renacer" para obtener bonus permanentes y recompensas visuales exclusivas.

---

## 🎯 Concepto principal

El jugador debe llenar los **5 pisos de su base con 50 brainrots de una rareza específica** para poder renacer. Cada renacimiento exige una rareza mayor, creando una curva de dificultad natural sin necesidad de aumentar la cantidad de brainrots.

**Por qué por rareza y no por cantidad:**
- Si fuera "60 brainrots, 70, 80..." el jugador podría comprar pelotas caras y romper cristales rápido, saltándose el progreso
- Al exigir rarezas específicas, el dinero NO sirve de nada → el jugador DEBE dominar el sistema de fusión y todos los sistemas del juego para conseguir los brainrots de esa rareza

---

## 📊 Tabla de renacimientos

| Rebirth | Rareza de los 50 brainrots | Color | Bonus acumulado | Título | Aura |
|---|---|---|---|---|---|
| 0 (inicio) | — | — | +0% | Sin título | Sin aura |
| 1 | Común | Blanco | +20% | "Renacido I" | Aura blanca |
| 2 | Incomún | Azul | +40% | "Renacido II" | Aura azul |
| 3 | Raro | Amarillo | +60% | "Renacido III" | Aura dorada |
| 4 | Épico | Rojo | +80% | "Renacido IV" | Aura roja |
| 5 (max) | Mítico | Morado | +100% | "Leyenda" | Aura morada legendaria |

### Tiempo estimado por renacimiento
| Rebirth | Dificultad | Tiempo estimado |
|---|---|---|
| 1 (Común) | Fácil | 1-2 horas |
| 2 (Incomún) | Fácil-Medio | 3-5 horas |
| 3 (Raro) | Medio | 1-2 días |
| 4 (Épico) | Difícil | 3-5 días |
| 5 (Mítico) | Muy difícil | 1-2 semanas |

---

## 🔄 Qué se pierde al renacer

- ❌ Todo el dinero (mano + banco)
- ❌ Todos los brainrots (los 50 se consumen)
- ❌ Nivel de la base (baseLevel = 1)
- ❌ Inventario de bloques de construcción
- ❌ Pelotas desbloqueadas (vuelve a básica)

## ✅ Qué NO se pierde (permanentemente)

- ✅ Boosts comprados con Robux (GamePass/DevProduct)
- ✅ Boosts comprados con dinero del juego
- ✅ Nivel de renacimiento (rebirthLevel)
- ✅ El bonus acumulado de renacimientos (+20% por cada uno)
- ✅ Estadísticas históricas (si las hay)

**Razón:** los jugadores que pagaron Robux por mejoras NO pierden su inversión → genera confianza en las compras. Si perdieran los boosts al renacer, nadie compraría mejoras con Robux.

---

## 🧮 Cálculo del bonus total

El bonus de ganancias se calcula así:

```
bonusTotal = boostLevel_comprado + rebirthLevel
gananciaFinal = gananciaBase × (1 + (bonusTotal × 0.20))
```

### Ejemplo
- Jugador con boost nivel 3 (comprado con Robux/dinero) = +60%
- Jugador con rebirth nivel 2 = +40%
- **Total: +100%** (las ganancias se duplican)

### Ejemplo máximo
- Boost nivel 5 (máximo comprable) = +100%
- Rebirth nivel 5 (mítico completado) = +100%
- **Total: +200%** (las ganancias se triplican)

---

## 🎮 Mecánica de renacimiento

### Condición para renacer
1. El jugador debe tener **exactamente 50 brainrots** de la rareza correspondiente a su próximo renacimiento
2. Los 50 brainrots deben estar colocados en los pedestales (5 pisos × 10 brainrots)
3. No importa el nivel ni la fusión de los brainrots, **solo la rareza**
4. Si tiene 49 brainrots de la rareza correcta y 1 de otra → NO puede renacer

### Proceso
1. El jugador presiona el botón "Renacer" en la UI
2. Aparece confirmación: "¿Estás seguro? Perderás todo tu dinero, brainrots y progreso. Tu bonus será +X%"
3. Al confirmar:
   - Se consumen los 50 brainrots
   - Se reinicia: money=0, bankBalance=0, baseLevel=1, blockInventory={}, placedBlocks={}, unlockedBalls={basic=true}
   - Se incrementa `rebirthLevel` en +1
   - Se actualiza el bonus total
   - Se aplica el aura visual y título
   - Se guarda en DataStore

### Botón de renacimiento
- Visible en la UI principal del jugador
- Solo se habilita (cambia a dorado/brillante) cuando se cumple la condición de 50 brainrots de la rareza correcta
- Si no se cumple, muestra en gris con texto: "Necesitas 50 brainrots [rareza] para renacer"
- Muestra el bonus actual y el bonus que tendría al renacer

---

## 🎨 Recompensas visuales

### Aura de partículas
Cada nivel de renacimiento aplica un `ParticleEmitter` al personaje del jugador:
- Rebirth 1: partículas blancas suaves
- Rebirth 2: partículas azules
- Rebirth 3: partículas doradas brillantes
- Rebirth 4: partículas rojas intensas
- Rebirth 5: partículas moradas legendarias con efecto de rayos

### Título sobre la cabeza
`BillboardGui` sobre el personaje con el título:
- "Renacido I" (blanco)
- "Renacido II" (azul)
- "Renacido III" (dorado)
- "Renacido IV" (rojo)
- "Leyenda" (morado, más grande, con efecto de brillo)

**Propósito:** los demás jugadores ven que renaciste → genera envidia y motivación para renacer.

---

## 💾 Persistencia (DataStore)

### Campo nuevo en PlayerData_v2
```lua
playerData = {
    -- ... campos existentes ...
    rebirthLevel = 0,          -- 0 a 5
    rebirthBonus = 0,          -- 0 a 100 (porcentaje acumulado de renacimientos)
    -- boostLevel ya existe (compras con Robux/dinero)
}
```

### Fórmula del bonus total
```lua
local totalBonusPercent = (playerData.boostLevel or 0) * 20 + (playerData.rebirthLevel or 0) * 20
-- Ejemplo: boostLevel=3, rebirthLevel=2 → 60 + 40 = 100% bonus
local multiplier = 1 + (totalBonusPercent / 100)
-- rate = baseRate * multiplier
```

---

## 🛡️ Reglas adicionales

### 1. No se puede renacer antes de tiempo
- El botón solo se habilita cuando los 50 brainrots son de la rareza correcta
- No hay forma de "renacer parcial"

### 2. Máximo 5 renacimientos
- Después del rebirth 5 (mítico), no se puede renacer más
- El jugador ya es "Leyenda" con +100% bonus de renacimiento
- Puede seguir jugando normalmente, acumulando dinero, compitiendo en leaderboard

### 3. Los brainrots se consumen
- Los 50 brainrots se eliminan al renacer (se "sacrifican")
- No se recuperan ni se convierten en nada

### 4. El boost comprado NUNCA se pierde
- Si un jugador compró boost nivel 3 con Robux y renace 2 veces:
  - Boost comprado: +60% (se conserva)
  - Rebirth: +40% (se acumula)
  - Total: +100%
- Si renace de nuevo (rebirth 3): boost +60%, rebirth +60% = +120%

---

## 🏗️ Implementación técnica (sin romper código)

### Archivos nuevos
- `ServerStorage/ServerModules/RebirthManager.lua` — lógica del servidor
- `StarterPlayer/StarterPlayerScripts/RebirthSystem.lua` — UI del cliente

### Cambios mínimos en código existente
- `SaveManager.lua`: agregar `rebirthLevel` y `rebirthBonus` al dataToSave
- `GameHandler.server.lua`: 
  - Cargar `rebirthLevel` desde savedData al entrar
  - Aplicar multiplicador en el Money Timer (junto con boostLevel)
  - Crear RemoteEvent `RebirthRequest` (cliente → servidor)
  - Crear RemoteEvent `RebirthUpdate` (servidor → cliente, para sync UI)

### Money Timer (cambio mínimo)
```lua
-- Antes:
local rate = ModelManager.getMoneyRate(rarityTag.Value, lvl, fLvl)
if pData.boostLevel > 0 then
    rate = rate * (1 + pData.boostLevel * 0.20)
end

-- Después:
local rate = ModelManager.getMoneyRate(rarityTag.Value, lvl, fLvl)
local boostPercent = (pData.boostLevel or 0) * 20 + (pData.rebirthLevel or 0) * 20
if boostPercent > 0 then
    rate = rate * (1 + boostPercent / 100)
end
```

### RebirthManager.lua (lógica del servidor)
```lua
-- Funciones principales:
- canRebirth(userId) → verifica si tiene 50 brainrots de la rareza correcta
- getRequiredRarity(rebirthLevel) → devuelve la rareza necesaria
- performRebirth(player) → ejecuta el renacimiento (consume brainrots, resetea, incrementa)
- applyVisualRewards(player) → aplica aura + título
- getTotalBonus(userId) → devuelve el % total (boost + rebirth)
```

### Rarezas mapeadas
```lua
local REBIRTH_RARITIES = {
    [1] = "Comun",      -- blanco
    [2] = "Incomun",    -- azul
    [3] = "Raro",       -- amarillo
    [4] = "Epico",      -- rojo
    [5] = "Mitico",     -- morado
}
```

---

## 📊 Impacto esperado

| Métrica | Impacto |
|---|---|
| Retención a largo plazo | 🔥🔥🔥 (semanas de gameplay extra) |
| Satisfacción del jugador | 🔥🔥🔥 (progreso visible y permanente) |
| Ingresos por Robux | 🔥🔥 (más jugadores compran boosts sabiendo que no se pierden) |
| Social/competencia | 🔥🔥🔥 (auras y títulos generan envidia) |
| Esfuerzo de implementación | Medio (2 archivos nuevos + cambios mínimos en 3 existentes) |
| Riesgo de romper código | Bajo (sistema aislado, solo agrega campos) |

---

## 📋 Checklist de implementación

- [ ] Crear `RebirthManager.lua` (ServerModule)
- [ ] Crear `RebirthSystem.lua` (ClientModule con botón + UI de confirmación)
- [ ] Agregar `rebirthLevel` y `rebirthBonus` al SaveManager
- [ ] Agregar `RebirthRequest` y `RebirthUpdate` RemoteEvents
- [ ] Modificar Money Timer para incluir rebirthLevel en el multiplicador
- [ ] Implementar `canRebirth()` que verifica los 50 brainrots de la rareza correcta
- [ ] Implementar `performRebirth()` que resetea todo excepto boosts y rebirthLevel
- [ ] Implementar auras visuales (ParticleEmitter por nivel)
- [ ] Implementar títulos (BillboardGui sobre la cabeza)
- [ ] Cargar rebirthLevel desde DataStore al entrar
- [ ] Sincronizar UI al entrar (RemoteFunction `RequestRebirthLevel`)
- [ ] Mostrar bonus total en la UI del jugador
- [ ] Deshabilitar botón si no cumple la condición
- [ ] Confirmación de seguridad antes de renacer

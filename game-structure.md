# 🎮 CrystalBreaker - Memoria Arquitectónica Permanente

> **⚠️ DOCUMENTO OBLIGATORIO**: Este archivo es la fuente de verdad del proyecto.
> Antes de crear, modificar o eliminar cualquier sistema, CONSULTA este documento.
> Si detectas información desactualizada, ACTUALÍZALA inmediatamente.

---

## 1. Información General

| Campo | Valor |
|-------|-------|
| **Nombre del proyecto** | CrystalBreaker |
| **Versión actual** | 1.8.0 |
| **Última actualización** | 2026-07-09 |
| **Repositorio GitHub** | `legendario001/CrystalBreaker` |
| **Plataforma** | Roblox (Luau) |
| **Tipo de juego** | Tycoon / Colección de personajes |
| **Descripción** | Los jugadores rompen cristales para obtener cofres que contienen personajes de diferentes rarezas. Colocan personajes en pedestales para generar dinero pasivo, mejoran los personajes para aumentar la producción, y mejoran su base para desbloquear pisos adicionales con más pedestales. |
| **Objetivo** | Coleccionar todos los personajes, maxearlos a nivel 100 y construir la base definitiva de 5 pisos. |

---

## 2. Árbol Completo del Proyecto

```
CrystalBreaker/
├── ReplicatedStorage/
│   ├── FireBallModel/                      (Model - modelo 3D de pelota de fuego con partículas)
│   └── RemoteEvents.lua                    (ModuleScript - crea todos los RemoteEvents)
│
├── ServerScriptService/
│   └── GameHandler.server.lua              (Script - lógica principal del servidor)
│
├── ServerStorage/
│   ├── CofreModel/                         (Part+Mesh - modelo 3D de cofre)
│   ├── CrystalShardModel/                  (Part+Mesh - modelo 3D de fragmento de cristal)
│   ├── ServerModules/
│   │   ├── BaseManager.lua                 (ModuleScript - asignación de bases)
│   │   ├── BaseUpgradeManager.lua          (ModuleScript - mejora de bases/pisos)
│   │   ├── CharacterManager.lua            (ModuleScript - modelos de personajes por rareza)
│   │   ├── CrystalSpawner.lua              (ModuleScript - generación de cristales)
│   │   └── ModelManager.lua                (ModuleScript - colocación, labels, dinero, mejoras)
│   └── ModelosPj/                          (Folder - modelos de personajes organizados por rareza)
│       ├── Morado/
│       ├── Rojo/
│       ├── Amarillo/
│       ├── Azul/
│       └── Blanco/
│
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       └── BallThrower.client.lua          (LocalScript - UI, inputs del cliente)
│
├── StarterGui/
│   └── .gitkeep
│
├── Lighting/
│   └── .gitkeep
│
├── Scripts/
│   └── BuildMap.lua                        (Script de Command Bar - crea el mapa completo)
│
└── Workspace/
    ├── Map/                                (Folder - generado por BuildMap.lua)
    └── Maquina/                            (Folder - modelo de fusión del usuario)
        └── FusionMachine/                  (Model - máquina de fusión visual)
            ├── TextBlockA/                 (Part - etiqueta "Block A Fusion Chamber")
            ├── TextBlockB/                 (Part - etiqueta "Block B Fusion Chamber")
            └── TexFusedItem/               (Part - etiqueta "Fused Item Collection")
        ├── Floor                           (suelo principal)
        ├── WallNorth/South/East/West       (paredes del mapa)
        ├── CrystalZone                     (zona de cristales)
        ├── PlayerSpawn                     (spawn de jugadores)
        └── Bases/                          (5 bases)
            ├── Base1/
            │   ├── BaseFloor               (suelo piso 1)
            │   ├── BaseSign/Post            (cartel con avatar del dueño)
            │   ├── Pedestals/              (10 pedestales piso 1)
            │   │   ├── Pedestal1/ ... Pedestal10/
            │   │   │   ├── PedestalColumn
            │   │   │   └── Platform
            │   ├── Floor2/                 (PISO 2 - oculto hasta mejorar)
            │   │   ├── Floor2Front/Back    (suelo con agujero para escalera)
            │   │   ├── BarandL/R/Back/Front (barandas)
            │   │   ├── CloudDecor1-4       (decoraciones de nube)
            │   │   ├── Ladder2             (TrussPart - escalera vertical)
            │   │   └── Pedestals2/         (10 pedestales piso 2)
            │   ├── Floor3/                 (PISO 3 - oculto hasta mejorar)
            │   ├── Floor4/                 (PISO 4 - oculto hasta mejorar)
            │   └── Floor5/                 (PISO 5 - oculto hasta mejorar)
            ├── Base2/ ... Base5/           (misma estructura)
```

---

## 3. Lista de Sistemas

### 🟢 Sistema de Cristales
- **Estado**: Activo
- **Responsabilidad**: Genera 25 cristales en la CrystalZone con rarezas aleatorias. Al golpearlos con una pelota, se rompen y generan un cofre.
- **Scripts**: `CrystalSpawner.lua`
- **Depende de**: `ModelManager` (no directamente)
- **Servicios**: `Workspace`

### 🟢 Sistema de Cofres
- **Estado**: Activo
- **Responsabilidad**: Cuando se rompe un cristal, genera un cofre del mismo color. El cofre tiene timer de 15s. Si se recoge, da un personaje aleatorio. Si no, regenera el cristal.
- **Scripts**: `CrystalSpawner.lua` (`spawnChest`, `respawn`)
- **Depende de**: `CharacterManager`

### 🟢 Sistema de Personajes
- **Estado**: Activo
- **Responsabilidad**: Maneja los modelos de personajes organizados por rareza en `ServerStorage/ModelosPj/`. Devuelve un modelo aleatorio según la rareza del cofre.
- **Scripts**: `CharacterManager.lua`
- **Carpetas requeridas**: `ServerStorage/ModelosPj/{Morado,Rojo,Amarillo,Azul,Blanco}/`

### 🟢 Sistema de Pedestales
- **Estado**: Activo
- **Responsabilidad**: Coloca personajes en pedestales, crea labels con info (nombre, rareza, nivel, producción), crea pila de dinero y botón de mejora frente al pedestal.
- **Scripts**: `ModelManager.lua` (`placeOnPedestal`, `createLabels`, `createMoneyPile`, `createUpgradeButton`)
- **Funciona en**: TODOS los pisos (1-5) gracias a `getAllPedestals()`

### 🟢 Sistema de Economía
- **Estado**: Activo
- **Responsabilidad**: Genera dinero pasivo cada 2 segundos. Formato K/M/B para números grandes.
- **Fórmulas**:
  - `getMoneyRate(rarity, level) = base * level²` con bonus x2 en niveles 25, 50, 75 y x5 en nivel 100
  - `getUpgradeCost(level) = 100 * level³`
  - `formatMoney(amount)`: convierte a K (≥10K), M (≥1M), B (≥1B)
- **Rates por rareza**: Morado=150, Rojo=50, Amarillo=20, Azul=8, Blanco=2
- **Scripts**: `ModelManager.lua` (`getMoneyRate`, `getUpgradeCost`, `formatMoney`)
- **Timer**: En `GameHandler.server.lua` (cada 2s, con pcall individual por personaje)

### 🟢 Sistema de Mejora de Personajes
- **Estado**: Activo
- **Responsabilidad**: Sube el nivel del personaje (max 100). Cada nivel aumenta la producción cuadráticamente. Costo sube cúbicamente.
- **Tecla**: F (cuando estás cerca del botón de mejora, 8 studs)
- **Click**: También funciona clickeando el botón de mejora
- **Scripts**: `ModelManager.lua`, `GameHandler.server.lua` (`UpgradeCharacter` event, `setupUpgradeButtonEvents`)
- **Debounce**: 0.3s servidor, 0.3s cliente

### 🟢 Sistema de Mejora de Base
- **Estado**: Activo
- **Responsabilidad**: Sube el nivel de la base (max 5). Cada nivel desbloquea un piso nuevo con 10 pedestales.
- **Tecla**: H (o click en botón dorado)
- **Costos (TEST)**: L1→2=$10, L2→3=$25, L3→4=$50, L4→5=$100
- **Scripts**: `BaseManager.lua`, `BaseUpgradeManager.lua`, `GameHandler.server.lua` (`UpgradeBase` event)
- **Funciones**: `activateFloor(base, floorNum)` hace visibles todas las partes del piso

### 🟢 Sistema de Bases
- **Estado**: Activo
- **Responsabilidad**: Asigna bases libres a jugadores al entrar. Muestra nombre y avatar en el cartel. Libera la base al salir.
- **Scripts**: `BaseManager.lua` (`assign`, `release`, `getBase`, `getBaseLevel`, `setBaseLevel`)
- **Número de bases**: 5

### 🟢 Sistema de Carry Tool
- **Estado**: Activo
- **Responsabilidad**: Crea una herramienta invisible que el jugador sostiene al cargar un personaje. El modelo del personaje se adjunta al handle.
- **Scripts**: `GameHandler.server.lua` (`createCarryTool`)

### 🟢 Sistema de UI (Cliente)
- **Estado**: Activo
- **Responsabilidad**: Muestra panel de dinero, panel de cargar (Colocar/Soltar), botón de pelota, hint de mejora (F), hint de mejora de base (H)
- **Scripts**: `BallThrower.client.lua`
- **Controles**: 1 (pelota), E (recoger/colocar), G (soltar), F (mejorar personaje), H (mejorar base), Click (lanzar pelota)

### 🟢 Sistema de Sonidos
- **Estado**: Activo
- **Responsabilidad**: Reproduce efectos de sonido en eventos clave.
- **Sonidos**:
  - Recoger dinero: `rbxassetid://79392333090964` (solo el jugador)
  - Mejorar personaje: `rbxassetid://203620899` (solo el jugador)
  - Romper cristal: `rbxassetid://124054125419097` (posicional, todos lo escuchan)
- **Scripts**: `GameHandler.server.lua` (`playSoundForPlayer`, `playSoundAt`)

---

## 4. Servicios

| Servicio | Ubicación | Responsabilidad | Utilizado por |
|----------|-----------|-----------------|---------------|
| **GameHandler** | `ServerScriptService/GameHandler.server.lua` | Lógica principal del servidor: eventos, timers, coordinación | Todos los sistemas |
| **BaseManager** | `ServerStorage/ServerModules/BaseManager.lua` | Asignación y liberación de bases, niveles de mejora | GameHandler, BaseUpgradeManager |
| **BaseUpgradeManager** | `ServerStorage/ServerModules/BaseUpgradeManager.lua` | Crear botón de mejora de base, activar pisos | GameHandler |
| **CharacterManager** | `ServerStorage/ServerModules/CharacterManager.lua` | Devolver modelos de personajes por rareza | GameHandler |
| **CrystalSpawner** | `ServerStorage/ServerModules/CrystalSpawner.lua` | Generar cristales y cofres | GameHandler |
| **ModelManager** | `ServerStorage/ServerModules/ModelManager.lua` | Colocación en pedestales, labels, dinero, mejoras, formato K/M/B | GameHandler, BaseUpgradeManager |

---

## 5. Managers

### BaseManager
- **Responsabilidad**: Asigna bases a jugadores, rastrea el nivel de mejora de cada base (1-5), libera bases al salir.
- **Tablas internas**: `assignedBases`, `playerBases`, `baseLevels`
- **Costos de mejora**: `UPGRADE_COSTS = {[2]=10, [3]=25, [4]=50, [5]=100}` (TEST)

### BaseUpgradeManager
- **Responsabilidad**: Crea el botón dorado "MEJORAR BASE" en el centro de cada base. Al activarse, hace visibles todas las partes del piso correspondiente.
- **Funciones clave**: `createUpgradeButton`, `updateButtonUI`, `activateFloor(base, floorNum)`, `activateFloor2/3/4/5`

### ModelManager
- **Responsabilidad**: Maneja todo lo visual de los personajes en pedestales. Coloca modelos, crea labels con RichText, crea pilas de dinero, crea botones de mejora, calcula economía.
- **Funciones clave**: `placeOnPedestal`, `createLabels`, `createMoneyPile`, `createUpgradeButton`, `getMoneyRate`, `getUpgradeCost`, `formatMoney`

---

## 6. ModuleScripts

| Nombre | Ubicación | Responsabilidad | Dependencias | Utilizado por |
|--------|-----------|-----------------|--------------|---------------|
| **RemoteEvents** | `ReplicatedStorage/RemoteEvents.lua` | Crea todos los RemoteEvents al inicio | - | GameHandler, BallThrower |
| **BaseManager** | `ServerStorage/ServerModules/` | Gestión de bases y niveles | - | GameHandler, BaseUpgradeManager |
| **BaseUpgradeManager** | `ServerStorage/ServerModules/` | Botones de mejora de base y activación de pisos | BaseManager, ModelManager | GameHandler |
| **CharacterManager** | `ServerStorage/ServerModules/` | Modelos de personajes por rareza | ServerStorage/ModelosPj | GameHandler |
| **CrystalSpawner** | `ServerStorage/ServerModules/` | Generación de cristales y cofres | Workspace | GameHandler |
| **ModelManager** | `ServerStorage/ServerModules/` | Colocación, labels, dinero, mejoras, formato K/M/B | - | GameHandler, BaseUpgradeManager |

---

## 7. RemoteEvents y RemoteFunctions

| Nombre | Tipo | Ubicación | Usado por | Responsabilidad |
|--------|------|-----------|-----------|-----------------|
| **ThrowBall** | RemoteEvent | `ReplicatedStorage` | BallThrower (client) → GameHandler (server) | Cliente avisa dónde lanzó la pelota para romper cristal |
| **PickupChest** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Recoger cofre y obtener personaje |
| **PlaceCharacter** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Colocar personaje cargado en pedestal libre |
| **DropCharacter** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Soltar personaje al suelo (DropTimer 30s) |
| **RemoveFromPedestal** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Recoger personaje del pedestal |
| **PickupDropped** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Recoger personaje soltado del suelo |
| **MoneyUpdate** | RemoteEvent | `ReplicatedStorage` | GameHandler → BallThrower | Servidor envía dinero actualizado al cliente |
| **UpgradeCharacter** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Mejorar personaje (tecla F o click) |
| **UpgradeBase** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Mejorar base (tecla H o click) |
| **ChestOpen** | RemoteEvent | `ReplicatedStorage` | GameHandler → BallThrower | Servidor avisa al cliente para animación de apertura de cofre |
| **FusionUIUpdate** | RemoteEvent | `ReplicatedStorage` | GameHandler → BallThrower | Servidor envía estado de slots de fusión al cliente |
| **DepositCharacter** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Depositar personaje en slot de fusión (tecla E) |
| **RemoveFromFusionSlot** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Quitar personaje de slot de fusión (click en slot) |
| **FuseCharacters** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Fusionar 2 personajes idénticos |
| **EquipBall** | RemoteEvent | `ReplicatedStorage` | BallThrower → GameHandler | Equipar/desequipar pelota (servidor crea pelota visible para todos) |

---

## 8. Flujo Completo del Proyecto

### Flujo principal del juego:
```
Jugador entra
    ↓
BaseManager.assign() → le asigna una base libre
    ↓
BaseUpgradeManager.createUpgradeButton() → crea botón dorado
    ↓
Jugador va a CrystalZone
    ↓
Presiona 1 → equipa pelota (BallThrower)
    ↓
Click → lanza pelota (ThrowBall event → servidor)
    ↓
Servidor detecta cristal cercano → lo destruye → CrystalSpawner.spawnChest()
    ↓
Jugador camina sobre cofre → presiona E (PickupChest event)
    ↓
CharacterManager.getRandomModel(rarity) → devuelve modelo
    ↓
createCarryTool() → jugador carga el personaje
    ↓
Jugador camina a su base → presiona E (PlaceCharacter event)
    ↓
getAllPedestals() → busca pedestal libre más cercano en TODOS los pisos
    ↓
ModelManager.placeOnPedestal() → coloca modelo
ModelManager.createLabels() → crea etiquetas con info
ModelManager.createMoneyPile() → crea pila de dinero
ModelManager.createUpgradeButton() → crea botón de mejora
    ↓
Timer cada 2s → ModelManager.getMoneyRate() → suma dinero a MoneyValue
    ↓
Jugador camina sobre MoneyPile → recoge dinero (CollectEvent → addMoney)
    ↓
Jugador presiona F cerca de UpgradeButton → UpgradeCharacter event
    ↓
Servidor valida → resta dinero → sube nivel → actualiza UI
    ↓
Jugador presiona H cerca de botón dorado → UpgradeBase event
    ↓
Servidor valida → resta dinero → sube nivel base → activateFloor(N)
    ↓
Piso N se hace visible → jugador sube por escalera → coloca más personajes
```

---

## 9. Dependencias

```
GameHandler (servidor principal)
    ├── BaseManager
    ├── BaseUpgradeManager
    │   ├── BaseManager
    │   └── ModelManager
    ├── CharacterManager
    ├── CrystalSpawner
    ├── ModelManager
    └── RemoteEvents (ReplicatedStorage)

BallThrower (cliente)
    └── RemoteEvents (ReplicatedStorage)

BuildMap (Command Bar, una sola vez)
    └── Workspace
```

---

## 10. Convenciones del Proyecto

### Controles:
- **1** = Equipar/desequipar pelota
- **Click / Toque pantalla** = Lanzar pelota (PC y móvil)
- **E** = Recoger/colocar personaje, recoger cofre
- **G** = Soltar personaje
- **F** = Mejorar personaje (cerca del botón de mejora)
- **H** = Mejorar base (cerca del botón dorado)
- **Mochila** = Click para abrir/cerrar panel de pelotas
- **Móvil**: Botones táctiles 👆 ⬆️ 🏰 aparecen automáticamente

### Reglas permanentes:

1. **Todos los módulos del servidor** viven en `ServerStorage/ServerModules/`
2. **Todos los RemoteEvents** se crean en `ReplicatedStorage/RemoteEvents.lua`
3. **El script principal del servidor** vive en `ServerScriptService/GameHandler.server.lua`
4. **El script principal del cliente** vive en `StarterPlayer/StarterPlayerScripts/BallThrower.client.lua`
5. **El mapa se genera** con `Scripts/BuildMap.lua` ejecutado en Command Bar
6. **Nunca duplicar lógica** — si una función ya existe en un módulo, reutilizarla
7. **Usar pcall** en todos los event handlers del servidor para evitar crashes
8. **Usar debounce** en todos los eventos que pueden ser spameados (0.3s mínimo)
9. **Verificar `isValid(instance)`** antes de acceder a instancias que pueden estar destruidas
10. **Verificar `isPlayerValid(player)`** antes de `FireClient`
11. **Verificar `isPedestalOwnedByPlayer`** antes de cualquier interacción con pedestal
12. **Usar `getAllPedestals(base)`** para buscar pedestales en todos los pisos
13. **Solo los números de dinero son verdes** — el resto de textos usan otros colores
14. **RichText** para labels con múltiples colores
15. **`CastShadow = false`** en todas las partes de pisos superiores (2-5)
16. **Nombres consistentes**: Pedestals (piso 1), Pedestals2 (piso 2), etc.
17. **formatMoney()** para TODOS los números de dinero mostrados al jugador

---

## 11. Recursos del Juego

### Sonidos
| Sonido | ID | Evento |
|--------|----|----|
| Recoger dinero | `rbxassetid://79392333090964` | Al caminar sobre MoneyPile |
| Mejorar personaje | `rbxassetid://203620899` | Al subir nivel de personaje |
| Romper cristal (4 aleatorios) | `rbxassetid://124054125419097`, `138817960173178`, `129395018150183`, `92650188901933` | Al golpear cristal con pelota |
| Abrir cofre | `rbxassetid://116517233858315` | Animación de apertura de cofre (6.56s) |
| Cerca de máquina de fusión | `rbxassetid://86261914368076` | Al acercarse a la máquina de fusión |
| Activar fusión | `rbxassetid://5509750509` | Al hacer click en botón FUSIONAR |
| Equipar pelota de fuego | `rbxassetid://129504465599355` | Al equipar/cambiar a pelota de fuego |
| Lanzar pelota de fuego | `rbxassetid://130422645188028` | Al lanzar pelota de fuego |

### Animaciones
| Animación | ID | Uso |
|-----------|----|----|
| Lanzar pelota | `rbxassetid://90927250635352` | Al lanzar pelota (cliente) |

### Modelos
- **Personajes**: En `ServerStorage/ModelosPj/{Morado,Rojo,Amarillo,Azul,Blanco}/`
- **Cristales**: Generados dinámicamente por CrystalSpawner
- **Cofres**: Generados dinámicamente por CrystalSpawner

### Colores de Rareza
| Rareza | Display | Color RGB | Rate base |
|--------|---------|-----------|-----------|
| Morado | MITICO | (170, 85, 255) | 150 |
| Rojo | EPICO | (255, 80, 80) | 50 |
| Amarillo | RARO | (255, 255, 100) | 20 |
| Azul | INCOMUN | (85, 170, 255) | 8 |
| Blanco | COMUN | (220, 220, 220) | 2 |

### Pesos de rareza (al generar cristal)
- Morado: 3, Rojo: 6, Amarillo: 12, Azul: 25, Blanco: 54

---

## 12. Sistemas Pendientes

### No implementados aún:
- [ ] Sistema de guardado (DataStore) — actualmente los datos se pierden al salir
- [ ] Sistema de mascotas
- [ ] Sistema de gremios
- [ ] Sistema de comercio entre jugadores
- [ ] Sistema de logros
- [ ] Sistema de clima
- [ ] Sistema de ranking global
- [ ] Sistema de codes/redención
- [ ] Sistema de anti-cheat robusto
- [ ] Música de fondo
- [ ] Sistema de recompensas diarias
- [ ] Tienda para comprar con dinero del juego
- [ ] Pelotas de Tierra, Aire y Agua (solo Básica y Fuego implementadas)
- [ ] Modelos 3D personalizados para cada pelota
- [ ] Costos reales de pelotas (actualmente gratis para testear)

### En desarrollo:
- [ ] Ajustar costos reales de mejora de base (actualmente TEST: $10, $25, $50, $100)

---

## 13. Historial de Cambios

### Versión 1.5.0 (2026-06-29)
- ✅ Agregados pisos 4 y 5 con estilo nube
- ✅ FIX: PlaceCharacter ahora funciona en todos los pisos (`getAllPedestals`)
- ✅ FIX: MoneyPile y UpgradeButton aparecen a la altura correcta en cada piso
- ✅ FIX: Hint de F funciona en todos los pisos
- ✅ Reducido brillo de pisos (Neon → SmoothPlastic, blanco → gris claro)
- ✅ Estilo nube: colores grises, decoraciones en esquinas

### Versión 1.4.0 (2026-06-28)
- ✅ Agregado piso 3 con escalera continua
- ✅ Eliminado sistema de teletransporte (tecla J)
- ✅ Agujero en parte trasera de pisos con escalera vertical (TrussPart)
- ✅ Eliminadas luces (pisos sin sombras en su lugar)

### Versión 1.3.0 (2026-06-28)
- ✅ Sistema de mejora de base (5 niveles)
- ✅ BaseUpgradeManager creado
- ✅ Botón dorado "MEJORAR BASE" con tecla H
- ✅ Piso 2 y 3 con estilo nube

### Versión 1.2.0 (2026-06-27)
- ✅ Nueva economía adictiva: level² income, level³ cost, formato K/M/B
- ✅ Bonus de milestone: x2 en niveles 25, 50, 75; x5 en nivel 100
- ✅ Sistema de respaldo en rama `respaldo-confirmado`

### Versión 1.1.0 (2026-06-27)
- ✅ Efectos de sonido: recoger dinero, mejorar, romper cristal
- ✅ Debounce en todos los eventos del servidor
- ✅ Fix: cristales dejan de funcionar (nearest.Color después de Destroy)
- ✅ Fix: base ownership check en todas las interacciones
- ✅ Fix: carry tool solo se destruye después de confirmar pedestal

### Versión 1.8.0 (2026-07-09)
- ✅ Pelota visible para todos los jugadores (creada en servidor via EquipBallEvent)
- ✅ Lanzamiento híbrido: pelota local (cero lag) + servidor (visible para todos)
- ✅ Pelota de fuego con modelo 3D personalizado (FireBallModel en ReplicatedStorage)
- ✅ Sistema de vida de cristales con barra visual (Blanco=2, Azul=4, Amarillo=6, Rojo=8, Morado=10)
- ✅ Botones táctiles para móvil (👆 interactuar, ⬆️ mejorar personaje, 🏰 mejorar base)
- ✅ Lanzar pelota en móvil tocando pantalla (sin pausar movimiento)
- ✅ Detección física de cristales (la pelota toca para dañar)
- ✅ Bloqueo de pinch-zoom en móvil (FOV forzado a 70)
- ✅ Mochila con icono personalizado (rbxassetid://113160993563399)
- ✅ Soporte móvil completo

### Versión 1.7.0 (2026-07-08)
- ✅ Soporte móvil completo: toque en pantalla para lanzar pelota
- ✅ Detección física de cristales (la pelota toca el cristal para dañarlo)
- ✅ Mochila de pelotas con UI (básica + fuego)
- ✅ Pelota de fuego (daño x2, velocidad 120, no rebota, Neon, gravedad baja)
- ✅ Sonidos de equipar y lanzar para pelota de fuego
- ✅ Soporte móvil: lanzar sin pausar movimiento (InputBegan + Touch)

### Versión 1.6.0 (2026-07-05)
- ✅ Sistema de vida de cristales (Blanco=2, Azul=4, Amarillo=6, Rojo=8, Morado=10)
- ✅ Barra de vida visual con colores dinámicos (verde→amarillo→rojo)
- ✅ 4 sonidos aleatorios al romper cristales
- ✅ Efecto visual de cristal rompiéndose (CrystalShardModel 3D)
- ✅ Fragmentos con color del cristal roto (SurfaceAppearance eliminado)
- ✅ Cofres 3D personalizados (CofreModel) que aparecen en el suelo
- ✅ Animación de apertura de cofre (spin + signo de interrogación + sonido 6.56s)
- ✅ Cofre desaparece instantáneamente al recoger

### Versión 1.5.1 (2026-07-02)
- ✅ Sistema de fusión completo (máquina con slots A/B, carry+deposit)
- ✅ Efecto visual dorado en personajes fusionados (UIStroke + borde dorado)
- ✅ Multiplicador x3 por nivel de fusión (Fusion=x3, Fusion II=x9, etc.)
- ✅ Sonidos de fusión (proximidad + activación)
- ✅ Pelota visible en la mano (Weld en punta de los dedos, brazo natural)
- ✅ Re-equipar automático después de lanzar
- ✅ Block de personajes fusionados (no se pueden volver a fusionar)
- ✅ Click en slot para quitar personaje de la máquina de fusión

### Versión 1.0.0 (2026-06-26)
- ✅ Sistema de cristales y cofres
- ✅ Sistema de personajes con 5 rarezas
- ✅ Sistema de pedestales con labels RichText
- ✅ Sistema de dinero con MoneyPile
- ✅ Sistema de mejora de personajes (tecla F)
- ✅ Controles: 1, E, G, F, Click
- ✅ UI moderna con paneles de dinero y carry

---

## 14. Acciones Manuales para Roblox Studio

### ⚠️ IMPORTANTE: Después de cada cambio, verificar esta sección.

### Al recrear el mapa:
1. Workspace → eliminar folder `Map` (o ejecutar BuildMap.lua que lo hace automático)
2. View → Command Bar → pegar contenido de `BuildMap.lua` → Enter

### Al agregar nuevo ModuleScript:
1. ServerStorage → ServerModules → clic derecho → Insert Object → ModuleScript
2. Nombrar exactamente como está en este documento (sin extensión .lua)
3. Pegar contenido desde GitHub

### Al agregar nuevo RemoteEvent:
1. Actualizar `ReplicatedStorage/RemoteEvents.lua` con el nuevo nombre en `eventNames`
2. El RemoteEvent se crea automáticamente al ejecutar el juego

### Al actualizar archivos existentes:
1. Abrir el archivo en Roblox Studio
2. Ctrl+A → Delete (borrar todo)
3. Copiar contenido nuevo desde GitHub
4. Pegar en Roblox Studio
5. Verificar que termina correctamente (return Module para módulos)

### Estado actual de acciones manuales:
**No se requieren cambios manuales adicionales** si todos los archivos están actualizados a la versión 1.5.0.

---

## 15. Estado Actual del Proyecto

### Sistemas existentes (todos activos):
- ✅ Cristales y cofres
- ✅ Personajes (5 rarezas)
- ✅ Pedestales (funcionan en 5 pisos)
- ✅ Economía (level² income, level³ cost, K/M/B format)
- ✅ Mejora de personajes (nivel 1-100, tecla F)
- ✅ Mejora de base (nivel 1-5, tecla H)
- ✅ Carry tool
- ✅ UI completa
- ✅ Sonidos (3 efectos)
- ✅ 5 pisos con estilo nube y escaleras verticales

### Sistemas faltantes (prioritarios):
- ❌ Sistema de guardado (DataStore) — CRÍTICO
- ❌ Ajustar costos reales de mejora de base
- ❌ Sistema anti-cheat

### Arquitectura actual:
- **Cliente-Servidor** con RemoteEvents
- **1 script servidor** principal (GameHandler)
- **1 script cliente** principal (BallThrower)
- **6 ModuleScripts** en ServerStorage/ServerModules + ReplicatedStorage
- **1 script Command Bar** para generar mapa (BuildMap)
- **Sin DataStore** todavía (datos en memoria)

---

## Reglas Permanentes

> Este documento representa la **memoria del proyecto**.
> 
> - Debe mantenerse **siempre actualizado**.
> - **Nunca eliminar información útil**.
> - **Nunca cambiar la arquitectura** sin actualizar este documento.
> - Cada vez que se cree un nuevo Script/ModuleScript/RemoteEvent/Folder/Asset, **registrar el cambio aquí**.
> - Antes de implementar cualquier nueva característica, **consultar este documento**.
> - Si detectas arquitectura inconsistente, **reorganizar antes de continuar**.
> 
> La prioridad no es solo generar código, sino mantener una **arquitectura limpia, consistente, escalable y bien documentada**.



# 🎮 Ideas de Sistemas de Juego Alternativos (Mini-juegos)

El jugador se aburre cuando ya tiene todas las pelotas y rompe todos los cristales. Estos sistemas ofrecen **formas divertidas y diferentes de conseguir brainrots** para los pedestales, sin romper el código existente. Todos son módulos independientes.

---

## 🎯 Mini-juegos activos (el jugador juega directamente)

### 1. Casino de Cristales (Máquina Tragamonedas)
```
Sistema: CrystalCasino (ServerModule + ClientModule)
Dependencias: Solo lee playerData.money, agrega personajes via ModelManager
```
- **Concepto:** Máquina tragamonedas con símbolos de brainrots
- **Costo:** 100M por tirada (o 25 R$)
- **Mecánica:**
  - 3 rodillos que giran con símbolos de brainrots (blanco, azul, amarillo, rojo, morado)
  - Si salen 3 iguales → ganas ese brainrot
  - Si salen 2 iguales → ganas dinero
  - Si salen 3 morados → JACKPOT (brainrot legendario + efecto especial)
- **Ubicación:** Una zona nueva del mapa con máquinas físicas
- **Por qué funciona:** gambling psychology, cada tirada es emocionante
- **No rompe código:** Solo cobra dinero y entrega personajes via eventos existentes

### 2. Torre de Cristales (Tower Climb)
```
Sistema: TowerClimb (ServerModule + ClientModule)
Dependencias: Zona separada del mapa, no toca cristales existentes
```
- **Concepto:** Torre de 50 pisos con cristales especiales
- **Mecánica:**
  - Cada piso tiene cristales más duros
  - Tienes 60 segundos por piso para romper todos los cristales
  - Si los rompes todos → subes al siguiente piso
  - Si se acaba el tiempo → vuelves al piso 1
  - Cada 10 pisos: recompensa garantizada (brainrot amarillo+)
  - Piso 50: brainrot morado garantizado
- **Entrada:** Portal en el mapa principal que te teleporta a la torre
- **Por qué funciona:** desafío creciente, sensación de progreso
- **No rompe código:** Zona aislada con su propia lógica

### 3. Arena de Olas (Survival)
```
Sistema: WaveArena (ServerModule + ClientModule)
Dependencias: Zona separada, usa el sistema de pelotas existente
```
- **Concepto:** Oleadas de cristales que vienen hacia ti
- **Mecánica:**
  - Estás en una arena cerrada
  - Oleadas de cristales spawnean y se mueven hacia ti
  - Tienes que romperlos con pelotas antes de que te toquen
  - Si te tocan 3 veces → game over
  - Cada 5 oleadas: boss cristal (muy duro, recompensa grande)
  - Recompensa según oleadas sobrevividas
- **Entrada:** Portal en el mapa principal
- **Por qué funciona:** acción intensa, adrenalina
- **No rompe código:** Reutiliza el BallThrower existente en zona aislada

### 4. Pesca de Brainrots
```
Sistema: FishingSystem (ServerModule + ClientModule)
Dependencias: Solo agrega a playerData, no toca nada
```
- **Concepto:** Pesca estilo Animal Crossing pero con brainrots
- **Mecánica:**
  - Lanzas el anzuelo en un lago/rio
  - Esperas a que muerda (1-10 segundos aleatorio)
  - Minijuego de timing: mantener el cursor en la zona verde
  - Si lo logras → atrapas un brainrot aleatorio
  - Mejor timing = mejor rareza
  - Peces raros aparecen a ciertas horas del día
- **Ubicación:** Lago en el mapa
- **Por qué funciona:** relajante pero gratificante, variedad de gameplay
- **No rompe código:** Sistema 100% independiente

---

## 🤖 Sistemas pasivos (el jugador configura y espera)

### 5. Granja de Cristales (Idle/Passive)
```
Sistema: CrystalFarm (ServerModule + ClientModule)
Dependencias: Solo agrega farmData a playerData
```
- **Concepto:** Plantas cristales que crecen solos
- **Mecánica:**
  - Compras "semillas de cristal" (blanco, azul, etc.)
  - Las plantas en tu parcela de granja
  - Crecen en tiempo real (30min - 24h según rareza)
  - Al cosechar → obtienes brainrots o dinero
  - Puedes acelerar crecimiento con Robux o fertilizante (comprable con dinero)
- **Ubicación:** Zona de granja en el mapa
- **Por qué funciona:** los jugadores vuelven para cosechar (retención)
- **No rompe código:** Solo lee/escribe playerData.farmData

### 6. Mercado Negro (Trading System)
```
Sistema: BlackMarket (ServerModule + ClientModule)
Dependencias: Solo lee playerData.characters
```
- **Concepto:** NPC que ofrece intercambios especiales
- **Mecánica:**
  - Cada 6 horas, el NPC ofrece 3 intercambios:
    - "Dame 5 brainrots blancos → te doy 1 azul"
    - "Dame 3 brainrots azules → te doy 1 amarillo"
    - "Dame 1 brainrot rojo + 1B → te doy 1 morado"
  - Los intercambios son aleatorios y cambian cada 6h
  - A veces ofrece intercambios exclusivos (raros)
- **Ubicación:** NPC en una zona oscura del mapa
- **Por qué funciona:** los jugadores entran para ver qué ofrece hoy
- **No rompe código:** Solo lee/remueve/agrega personajes de playerData

### 7. Galaxia de Cristales (Space Mining)
```
Sistema: SpaceMine (ServerModule + ClientModule)
Dependencias: Zona separada del mapa
```
- **Concepto:** Viajas a planetas diferentes para minar cristales exóticos
- **Mecánica:**
  - 5 planetas diferentes, cada uno con cristales únicos
  - Viajar cuesta combustible (se compra con dinero o Robux)
  - Cada planeta tiene cristales con mecánicas especiales:
    - Planeta Hielo: cristales que se deslizan
    - Planeta Fuego: cristales que explotan si no los rompes rápido
    - Planeta Gravedad: cristales que flotan
  - Recompensas exclusivas de cada planeta
- **Entrada:** Nave/portal en el mapa principal
- **Por qué funciona:** variedad, exploración, mecánicas nuevas
- **No rompe código:** Zona completamente aislada

---

## 🏆 Sistemas competitivos (jugador vs jugador)

### 8. Arena PvP de Pelotas
```
Sistema: BallArena (ServerModule + ClientModule)
Dependencias: Zona separada, usa BallThrower existente
```
- **Concepto:** Duelos de pelotas entre jugadores
- **Mecánica:**
  - 2-4 jugadores entran a una arena
  - Cada uno tiene su pelota equipada
  - Tienen que romper cristales en el centro de la arena
  - Pueden interceptar las pelotas de los demás
  - El que rompa más cristales en 2 minutos gana
  - Recompensa: brainrots + dinero según posición
- **Entrada:** Cola de matchmaking (queue) en el mapa
- **Por qué funciona:** competencia directa, replayabilidad
- **No rompe código:** Arena aislada, reutiliza BallThrower

### 9. Carrera de Cristales (Speedrun)
```
Sistema: CrystalRace (ServerModule + ClientModule)
Dependencias: Pista separada del mapa
```
- **Concepto:** Carrera donde rompes cristales para avanzar
- **Mecánica:**
  - 4 jugadores compiten en una pista lineal
  - Cada cristal roto te da un boost de velocidad
  - Obstáculos entre cristales (paredes, rampas)
  - Primero en llegar a la meta gana
  - Recompensa según posición
- **Por qué funciona:** velocidad, competencia, espectáculo
- **No rompe código:** Pista aislada con su propia lógica

---

## 📊 Tabla comparativa

| # | Sistema | Esfuerzo | Retención | Ingresos | Diversión |
|---|---------|----------|-----------|----------|-----------|
| 1 | Casino Tragamonedas | Medio | 🔥🔥🔥 | 🔥🔥🔥 | 🔥🔥🔥 |
| 2 | Torre de Cristales | Alto | 🔥🔥🔥 | 🔥🔥 | 🔥🔥🔥 |
| 3 | Arena de Olas | Alto | 🔥🔥 | 🔥 | 🔥🔥🔥 |
| 4 | Pesca de Brainrots | Medio | 🔥🔥 | 🔥 | 🔥🔥 |
| 5 | Granja de Cristales | Medio | 🔥🔥🔥 | 🔥🔥 | 🔥 |
| 6 | Mercado Negro | Bajo | 🔥🔥🔥 | 🔥 | 🔥🔥 |
| 7 | Galaxia de Cristales | Muy alto | 🔥🔥 | 🔥🔥 | 🔥🔥🔥 |
| 8 | Arena PvP | Alto | 🔥🔥🔥 | 🔥 | 🔥🔥🔥 |
| 9 | Carrera de Cristales | Alto | 🔥🔥 | 🔥 | 🔥🔥🔥 |

---

## 🎯 Mi top 3 recomendado

1. **Casino de Cristales** — fácil de implementar, genera Robux, muy adictivo
2. **Mercado Negro** — muy fácil, hace que los jugadores entren cada 6h
3. **Pesca de Brainrots** — variedad de gameplay, relajante, fácil de hacer

**Orden sugerido de implementación:**
1. Mercado Negro (más fácil, retención inmediata)
2. Casino (genera ingresos, muy adictivo)
3. Pesca (variedad, relajante)

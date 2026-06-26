# CrystalBreaker

Estructura del proyecto Roblox.

## Estructura

```
CrystalBreaker/
├── ServerScriptService/       ← Scripts del servidor (Script)
├── ServerStorage/             ← Almacenamiento del servidor
│   └── ServerModules/         ← ModuleScripts del servidor
├── ReplicatedStorage/         ← Compartido entre cliente y servidor
├── StarterPlayer/             ← Scripts del jugador
│   └── StarterPlayerScripts/  ← LocalScripts del jugador
├── StarterGui/                ← GUIs del jugador
├── Workspace/                 ← Mundo del juego
│   └── Map/                   ← Mapa del juego
│       ├── Bases/             ← Bases de jugadores
│       ├── CrystalZone/       ← Zona de cristales
│       └── Walls/             ← Paredes del mapa
├── Lighting/                  ← Iluminación
└── Scripts/                   ← Scripts de Command Bar
```

## Convención de nombres

- `.server.lua` = Script (servidor)
- `.client.lua` = LocalScript (cliente)
- `.lua` = ModuleScript (módulo)

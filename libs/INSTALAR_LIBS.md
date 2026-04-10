# Instalación de librerías Ace3

El addon necesita las siguientes librerías dentro de la carpeta `libs/`.
Descárgalas desde sus repositorios oficiales y extrae cada una en su subcarpeta.

## Librerías necesarias y sus URLs de descarga

| Librería | Descarga | Carpeta destino |
|---|---|---|
| LibStub | https://www.wowace.com/projects/libstub/files | `libs/LibStub/` |
| CallbackHandler-1.0 | https://www.wowace.com/projects/callbackhandler/files | `libs/CallbackHandler-1.0/` |
| AceAddon-3.0 | https://www.wowace.com/projects/ace3/files | `libs/AceAddon-3.0/` |
| AceEvent-3.0 | (incluido en Ace3) | `libs/AceEvent-3.0/` |
| AceConsole-3.0 | (incluido en Ace3) | `libs/AceConsole-3.0/` |
| AceGUI-3.0 | (incluido en Ace3) | `libs/AceGUI-3.0/` |
| AceDB-3.0 | (incluido en Ace3) | `libs/AceDB-3.0/` |

## Método más fácil: descargar Ace3 completo

Ace3 incluye todas las librerías necesarias en un solo ZIP:

1. Ve a https://www.wowace.com/projects/ace3/files
2. Descarga la última versión (elige el ZIP de release)
3. Extrae el ZIP
4. Copia las carpetas `AceAddon-3.0`, `AceEvent-3.0`, `AceConsole-3.0`,
   `AceGUI-3.0` y `AceDB-3.0` dentro de `libs/`

Para `LibStub` y `CallbackHandler-1.0`:
- Suelen estar incluidas dentro del ZIP de Ace3
- Si no, descárgalas individualmente desde sus páginas de WowAce

## Estructura final esperada

```
BuildViewer/
└── libs/
    ├── LibStub/
    │   └── LibStub.lua
    ├── CallbackHandler-1.0/
    │   └── CallbackHandler-1.0.lua
    ├── AceAddon-3.0/
    │   └── AceAddon-3.0.lua
    ├── AceEvent-3.0/
    │   └── AceEvent-3.0.lua
    ├── AceConsole-3.0/
    │   └── AceConsole-3.0.lua
    ├── AceGUI-3.0/
    │   ├── AceGUI-3.0.lua
    │   └── widgets/
    │       └── ... (archivos de widgets)
    └── AceDB-3.0/
        └── AceDB-3.0.lua
```

## Alternativa: usar CurseForge App

Si tienes instalado el cliente de CurseForge, las librerías Ace3 se instalan
automáticamente como dependencias de otros addons. En ese caso, WoW las carga
desde sus propias carpetas en `Interface/AddOns/` y no necesitas incluirlas
en `libs/`. Para ello, elimina las líneas de `libs\` del archivo `BuildViewer.toc`.

> **Nota para desarrollo:** Durante el desarrollo es más sencillo incluir las
> libs embebidas en el addon (como está configurado ahora) para no depender
> de que el usuario tenga instalado otro addon.

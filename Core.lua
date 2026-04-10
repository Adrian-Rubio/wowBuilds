-- BuildViewer - Core.lua
-- Inicialización del addon, slash commands y gestión de base de datos.

local addonName, addonTable = ...

-- Crear el addon con los módulos Ace3 necesarios
local BuildViewer = LibStub("AceAddon-3.0"):NewAddon(
    "BuildViewer",
    "AceConsole-3.0",
    "AceEvent-3.0"
)

-- Esquema por defecto de la base de datos (valores guardados por personaje)
local DB_DEFAULTS = {
    char = {
        lastClass   = nil,   -- última clase seleccionada
        lastSpec    = nil,   -- última spec seleccionada
        lastContext = "Overall", -- último contexto (Overall, Raid, Mythic+)
        windowX     = nil,   -- posición X de la ventana
        windowY     = nil,   -- posición Y de la ventana
    }
}

-- Se llama una vez cuando el addon se carga por primera vez
function BuildViewer:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BuildViewerDB", DB_DEFAULTS, true)
    self:RegisterChatCommand("bv",          "SlashCommand")
    self:RegisterChatCommand("buildviewer", "SlashCommand")
    self:Print("|cff00ccffBuildViewer|r cargado. Escribe |cffffcc00/bv|r para abrir.")
end

-- Se llama cuando el jugador entra en el mundo (login / reload)
function BuildViewer:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
end

function BuildViewer:OnPlayerLogin()
    -- Aquí puedes poner lógica que dependa de que el jugador ya esté en el mundo.
    -- Por ahora no hacemos nada especial al login.
end

-- Manejo del slash command /bv [clase] [spec]
-- Ejemplos:
--   /bv                        → abre/cierra la ventana
--   /bv Warrior Arms           → abre la ventana directo en Warrior > Arms
function BuildViewer:SlashCommand(input)
    local args = {}
    for word in string.gmatch(input or "", "%S+") do
        table.insert(args, word)
    end

    if #args == 0 then
        -- Sin argumentos: toggle de la ventana
        if BuildViewer_UI and BuildViewer_UI:IsWindowOpen() then
            BuildViewer_UI:CloseWindow()
        else
            BuildViewer_UI:OpenWindow()
        end
        return
    end

    -- Argumentos: intentar abrir en la clase/spec indicada
    -- Reconstruir clase y spec desde los argumentos (pueden tener espacios)
    -- Ej: /bv Death Knight Blood → args = {"Death", "Knight", "Blood"}
    -- Estrategia: buscar la primera clase que empiece con los args dados
    local className, specName = BuildViewer:ParseClassSpecArgs(args)
    if className then
        BuildViewer_UI:OpenWindow(className, specName)
    else
        self:Print("Uso: |cffffcc00/bv|r  o  |cffffcc00/bv <Clase> [Spec]|r")
        self:Print("Clases disponibles:")
        for cls, _ in pairs(BuildViewerData) do
            self:Print("  |cff80ff80" .. cls .. "|r")
        end
    end
end

-- Intenta mapear los argumentos de texto a una clase y spec válidas.
-- Devuelve className, specName (specName puede ser nil si no se especificó)
function BuildViewer:ParseClassSpecArgs(args)
    if not args or #args == 0 then return nil, nil end

    -- Intentar todas las longitudes posibles para el nombre de clase (1, 2, 3 palabras)
    for classWords = #args, 1, -1 do
        local candidateClass = table.concat(args, " ", 1, classWords)
        -- Búsqueda insensible a mayúsculas
        local matchedClass = BuildViewer:FindCaseInsensitive(BuildViewerData, candidateClass)
        if matchedClass then
            -- El resto de argumentos es la spec
            if #args > classWords then
                local candidateSpec = table.concat(args, " ", classWords + 1, #args)
                local matchedSpec = BuildViewer:FindCaseInsensitive(BuildViewerData[matchedClass], candidateSpec)
                return matchedClass, matchedSpec
            end
            return matchedClass, nil
        end
    end
    return nil, nil
end

-- Busca una clave en una tabla de forma insensible a mayúsculas.
-- Devuelve la clave real si hay coincidencia, nil en caso contrario.
function BuildViewer:FindCaseInsensitive(tbl, query)
    if not tbl or not query then return nil end
    local lowerQuery = query:lower()
    for key, _ in pairs(tbl) do
        if key:lower() == lowerQuery then
            return key
        end
    end
    return nil
end

-- Guarda la última clase/spec vista (llamado desde UI.lua)
function BuildViewer:SaveLastSelection(className, specName, contextName)
    self.db.char.lastClass = className
    self.db.char.lastSpec  = specName
    if contextName then
        self.db.char.lastContext = contextName
    end
end

-- Devuelve la última clase/spec/contexto guardada
function BuildViewer:GetLastSelection()
    return self.db.char.lastClass, self.db.char.lastSpec, self.db.char.lastContext
end

-- Guarda la posición de la ventana (llamado desde UI.lua)
function BuildViewer:SaveWindowPosition(x, y)
    self.db.char.windowX = x
    self.db.char.windowY = y
end

-- Devuelve la posición guardada de la ventana
function BuildViewer:GetWindowPosition()
    return self.db.char.windowX, self.db.char.windowY
end

-- Referencia global al addon para que UI.lua pueda acceder a él
_G["BuildViewer"] = BuildViewer

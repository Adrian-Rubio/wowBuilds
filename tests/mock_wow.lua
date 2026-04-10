-- =============================================================
-- mock_wow.lua
-- Simula las APIs de WoW y las librerías Ace3 necesarias para
-- poder cargar y probar el addon fuera del cliente de WoW.
-- Usar con Lua 5.1 o LuaJIT.
-- =============================================================

-- ── Globals de WoW ───────────────────────────────────────────
_G = _G or {}

UIParent = { GetPoint = function() return "CENTER", UIParent, "CENTER", 0, 0 end }

C_Clipboard = {
    SetText = function(text)
        print("  [C_Clipboard.SetText] → " .. tostring(text))
    end
}

-- WoW override de print con colores (los códigos |c se ignoran en consola)
local _orig_print = print
function print(...)
    local args = {...}
    local cleaned = {}
    for i, v in ipairs(args) do
        local s = tostring(v)
        -- Eliminar códigos de color WoW (|cRRGGBBAA y |r)
        s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
        s = s:gsub("|r", "")
        cleaned[i] = s
    end
    _orig_print(table.unpack and table.unpack(cleaned) or unpack(cleaned))
end

-- Compatibilidad Lua 5.1 / 5.2+
local unpack = table.unpack or unpack

-- ── LibStub mock ─────────────────────────────────────────────
local _libs = {}

LibStub = setmetatable({}, {
    __call = function(self, name, silent)
        if _libs[name] then return _libs[name] end
        if not silent then
            error("LibStub: librería no encontrada: " .. tostring(name), 2)
        end
        return nil
    end
})

function LibStub:NewLibrary(name, version)
    local lib = {}
    _libs[name] = lib
    return lib, true
end

-- ── AceAddon-3.0 mock ────────────────────────────────────────
local AceAddon = {}
_libs["AceAddon-3.0"] = AceAddon

function AceAddon:NewAddon(name, ...)
    local mixins = {...}
    local addon = {
        _name   = name,
        _mixins = mixins,
        -- AceConsole-3.0 methods
        Print = function(self, ...)
            _orig_print("[" .. name .. "]", ...)
        end,
        RegisterChatCommand = function(self, cmd, handler)
            -- Guardar referencia para poder simular el slash command en tests
            self._commands = self._commands or {}
            self._commands[cmd] = handler
        end,
        -- AceEvent-3.0 methods
        RegisterEvent = function(self, event, handler)
            self._events = self._events or {}
            self._events[event] = handler
        end,
        UnregisterEvent = function(self, event)
            if self._events then self._events[event] = nil end
        end,
        -- AceAddon lifecycle (llamados manualmente en los tests)
        OnInitialize = function(self) end,
        OnEnable     = function(self) end,
        OnDisable    = function(self) end,
    }
    -- Autorun del ciclo de vida
    _G[name] = addon
    return addon
end

-- ── AceDB-3.0 mock ───────────────────────────────────────────
local AceDB = {}
_libs["AceDB-3.0"] = AceDB

function AceDB:New(svName, defaults, shared)
    -- Simular la variable SavedVariable (comienza vacía como en primera ejecución)
    local db = { char = {}, global = {}, profile = {} }
    if defaults then
        if defaults.char then
            for k, v in pairs(defaults.char) do db.char[k] = v end
        end
        if defaults.global then
            for k, v in pairs(defaults.global) do db.global[k] = v end
        end
    end
    return db
end

-- ── AceGUI-3.0 mock ──────────────────────────────────────────
-- UI.lua usa AceGUI; como no podemos renderizar UI en CLI,
-- mockeamos los widgets con objetos simples que registran sus llamadas.
local AceGUI = {}
_libs["AceGUI-3.0"] = AceGUI

local function makeWidget(widgetType)
    local w = {
        _type       = widgetType,
        _children   = {},
        _callbacks  = {},
        _value      = nil,
        _disabled   = false,
        _text       = "",
        _list       = {},
    }
    -- Métodos comunes
    function w:SetTitle(t)       self._title = t end
    function w:SetStatusText(t)  self._status = t end
    function w:SetWidth(n)       self._width = n end
    function w:SetHeight(n)      self._height = n end
    function w:SetLayout(l)      self._layout = l end
    function w:SetFullWidth(b)   self._fullwidth = b end
    function w:SetLabel(l)       self._label = l end
    function w:SetText(t)        self._text = t end
    function w:SetList(l)        self._list = l end
    function w:SetValue(v)       self._value = v end
    function w:GetValue()        return self._value end
    function w:SetDisabled(b)    self._disabled = b end
    function w:SetPoint(...)     end
    function w:FixScroll()       end
    function w:SetCallback(event, fn) self._callbacks[event] = fn end
    function w:AddChild(child)   table.insert(self._children, child) end
    -- Frame interno (para acceso .frame en UI.lua)
    w.frame = {
        Show         = function() end,
        Hide         = function() end,
        Raise        = function() end,
        ClearAllPoints = function() end,
        SetPoint     = function() end,
        SetScript    = function() end,
        StopMovingOrSizing = function() end,
        GetPoint     = function() return "CENTER", nil, "CENTER", 0, 0 end,
    }
    -- Simular selección de un valor (para tests)
    function w:SimulateSelect(value)
        self._value = value
        if self._callbacks["OnValueChanged"] then
            self._callbacks["OnValueChanged"](self, "OnValueChanged", value)
        end
    end
    return w
end

function AceGUI:Create(widgetType)
    return makeWidget(widgetType)
end

function AceGUI:Release(widget)
    -- Llamar al callback OnClose si existe
    if widget and widget._callbacks and widget._callbacks["OnClose"] then
        widget._callbacks["OnClose"](widget)
    end
end

-- ── Helpers de test ──────────────────────────────────────────
-- Función global para simular un slash command
function SimulateSlashCommand(addon, cmd, args)
    if addon._commands and addon._commands[cmd] then
        local handler = addon._commands[cmd]
        if type(handler) == "string" then
            addon[handler](addon, args or "")
        else
            handler(addon, args or "")
        end
    else
        error("Slash command '/" .. cmd .. "' no registrado en el addon")
    end
end

-- Función global para simular un evento WoW
function SimulateEvent(addon, event, ...)
    if addon._events and addon._events[event] then
        local handler = addon._events[event]
        if type(handler) == "string" then
            addon[handler](addon, event, ...)
        else
            handler(addon, event, ...)
        end
    end
end

print("[mock_wow] APIs de WoW y Ace3 cargadas correctamente.")

-- =============================================================
-- test_logic.lua
-- Suite de tests para la lógica Lua del addon BuildViewer.
-- Ejecutar con:  lua tests/test_logic.lua  (desde la raíz del proyecto)
-- =============================================================

-- Ajustar el path para que Lua encuentre los archivos del proyecto
-- (se ejecuta desde la raíz del proyecto)
local function projectFile(path)
    return path  -- rutas relativas desde la raíz
end

-- ── Framework de tests minimalista ───────────────────────────
local passed = 0
local failed = 0
local errors = {}

local function describe(suiteName, fn)
    print("\n┌─ " .. suiteName)
    fn()
    print("└─────────────────────────────────────────")
end

local function it(testName, fn)
    local ok, err = pcall(fn)
    if ok then
        print("│  ✓  " .. testName)
        passed = passed + 1
    else
        print("│  ✗  " .. testName)
        print("│     ERROR: " .. tostring(err))
        failed = failed + 1
        table.insert(errors, { test = testName, err = err })
    end
end

local function assertEqual(a, b, msg)
    if a ~= b then
        error(
            (msg or "assertEqual falló") ..
            "\n│       esperado: " .. tostring(b) ..
            "\n│       obtenido: " .. tostring(a),
            2
        )
    end
end

local function assertNotNil(v, msg)
    if v == nil then
        error((msg or "assertNotNil falló: el valor es nil"), 2)
    end
end

local function assertNil(v, msg)
    if v ~= nil then
        error((msg or "assertNil falló: se esperaba nil, obtenido: " .. tostring(v)), 2)
    end
end

local function assertTrue(v, msg)
    if not v then
        error((msg or "assertTrue falló"), 2)
    end
end

local function assertFalse(v, msg)
    if v then
        error((msg or "assertFalse falló"), 2)
    end
end

local function assertTableLength(tbl, n, msg)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    if count ~= n then
        error(
            (msg or "assertTableLength falló") ..
            "\n│       esperado: " .. n ..
            "\n│       obtenido: " .. count,
            2
        )
    end
end

-- ── Cargar el entorno de mocks ────────────────────────────────
print("=============================================================")
print("  BuildViewer — Test Suite")
print("=============================================================")
print("\n[1/3] Cargando mocks de WoW y Ace3...")
dofile("tests/mock_wow.lua")

-- ── Cargar los datos ─────────────────────────────────────────
print("\n[2/3] Cargando datos y lógica del addon...")
dofile("data/Builds.lua")

-- Simular que Core.lua se carga como addon (el vararg ... no existe con dofile)
-- Parchamos la primera línea del comportamiento: definir addonName globalmente
addonName   = "BuildViewer"
addonTable  = {}

dofile("Core.lua")

-- Inicializar el addon manualmente (simula lo que hace WoW al cargar)
local addon = _G["BuildViewer"]
assertNotNil(addon, "El addon 'BuildViewer' debe estar en _G después de cargar Core.lua")
addon:OnInitialize()
addon:OnEnable()

print("\n[3/3] Ejecutando tests...\n")

-- =============================================================
--  SUITE 1: Estructura de datos (Builds.lua)
-- =============================================================
describe("data/Builds.lua — Estructura de datos", function()

    it("BuildViewerData existe y es una tabla", function()
        assertNotNil(BuildViewerData, "BuildViewerData no existe")
        assertEqual(type(BuildViewerData), "table")
    end)

    it("Contiene todas las clases esperadas", function()
        local expectedClasses = {
            "Death Knight", "Demon Hunter", "Druid", "Evoker",
            "Hunter", "Mage", "Monk", "Paladin", "Priest",
            "Rogue", "Shaman", "Warlock", "Warrior"
        }
        for _, cls in ipairs(expectedClasses) do
            assertNotNil(BuildViewerData[cls], "Falta la clase: " .. cls)
        end
    end)

    it("Warrior tiene las tres specs (Arms, Fury, Protection)", function()
        local warrior = BuildViewerData["Warrior"]
        assertNotNil(warrior, "Warrior no existe")
        assertNotNil(warrior["Arms"],       "Falta Warrior > Arms")
        assertNotNil(warrior["Fury"],       "Falta Warrior > Fury")
        assertNotNil(warrior["Protection"], "Falta Warrior > Protection")
    end)

    it("Druid tiene las cuatro specs", function()
        local druid = BuildViewerData["Druid"]
        assertNotNil(druid["Balance"],     "Falta Druid > Balance")
        assertNotNil(druid["Feral"],       "Falta Druid > Feral")
        assertNotNil(druid["Guardian"],    "Falta Druid > Guardian")
        assertNotNil(druid["Restoration"], "Falta Druid > Restoration")
    end)

    it("Evoker tiene las tres specs (incluyendo Augmentation)", function()
        local evoker = BuildViewerData["Evoker"]
        assertNotNil(evoker["Devastation"],  "Falta Evoker > Devastation")
        assertNotNil(evoker["Preservation"], "Falta Evoker > Preservation")
        assertNotNil(evoker["Augmentation"], "Falta Evoker > Augmentation")
    end)

    it("Cada build tiene los campos obligatorios", function()
        for className, specs in pairs(BuildViewerData) do
            for specName, build in pairs(specs) do
                local ctx = className .. " > " .. specName
                assertNotNil(build.summary,  ctx .. ": falta 'summary'")
                assertNotNil(build.stats,    ctx .. ": falta 'stats'")
                assertNotNil(build.url,      ctx .. ": falta 'url'")
                assertEqual(type(build.summary), "string", ctx .. ": 'summary' debe ser string")
                assertEqual(type(build.stats),   "table",  ctx .. ": 'stats' debe ser tabla")
                assertEqual(type(build.url),     "string", ctx .. ": 'url' debe ser string")
            end
        end
    end)

    it("Las stats de cada build no están vacías", function()
        for className, specs in pairs(BuildViewerData) do
            for specName, build in pairs(specs) do
                local ctx = className .. " > " .. specName
                assertTrue(#build.stats > 0, ctx .. ": stats está vacío")
            end
        end
    end)

    it("Todas las URLs apuntan a icy-veins.com", function()
        for className, specs in pairs(BuildViewerData) do
            for specName, build in pairs(specs) do
                local ctx = className .. " > " .. specName
                assertTrue(
                    build.url:find("icy-veins.com") ~= nil,
                    ctx .. ": URL no apunta a icy-veins.com: " .. build.url
                )
            end
        end
    end)

end)

-- =============================================================
--  SUITE 2: Lógica pura de Core.lua
-- =============================================================
describe("Core.lua — FindCaseInsensitive()", function()

    it("Encuentra una clave con la misma capitalización", function()
        local result = addon:FindCaseInsensitive(BuildViewerData, "Warrior")
        assertEqual(result, "Warrior")
    end)

    it("Encuentra una clave en minúsculas", function()
        local result = addon:FindCaseInsensitive(BuildViewerData, "warrior")
        assertEqual(result, "Warrior")
    end)

    it("Encuentra una clave en mayúsculas", function()
        local result = addon:FindCaseInsensitive(BuildViewerData, "MAGE")
        assertEqual(result, "Mage")
    end)

    it("Encuentra clases con espacios (Death Knight)", function()
        local result = addon:FindCaseInsensitive(BuildViewerData, "death knight")
        assertEqual(result, "Death Knight")
    end)

    it("Devuelve nil para una clave inexistente", function()
        local result = addon:FindCaseInsensitive(BuildViewerData, "Palomino")
        assertNil(result)
    end)

    it("Devuelve nil si la tabla es nil", function()
        local result = addon:FindCaseInsensitive(nil, "Warrior")
        assertNil(result)
    end)

    it("Devuelve nil si el query es nil", function()
        local result = addon:FindCaseInsensitive(BuildViewerData, nil)
        assertNil(result)
    end)

end)

describe("Core.lua — ParseClassSpecArgs()", function()

    it("Parsea una clase de una sola palabra", function()
        local cls, spec = addon:ParseClassSpecArgs({"Warrior"})
        assertEqual(cls, "Warrior")
        assertNil(spec)
    end)

    it("Parsea clase + spec de una sola palabra", function()
        local cls, spec = addon:ParseClassSpecArgs({"Warrior", "Arms"})
        assertEqual(cls, "Warrior")
        assertEqual(spec, "Arms")
    end)

    it("Parsea clase de dos palabras (Death Knight)", function()
        local cls, spec = addon:ParseClassSpecArgs({"Death", "Knight"})
        assertEqual(cls, "Death Knight")
        assertNil(spec)
    end)

    it("Parsea clase de dos palabras + spec", function()
        local cls, spec = addon:ParseClassSpecArgs({"Death", "Knight", "Blood"})
        assertEqual(cls, "Death Knight")
        assertEqual(spec, "Blood")
    end)

    it("Parsea clase de dos palabras + spec de dos palabras (Beast Mastery)", function()
        local cls, spec = addon:ParseClassSpecArgs({"Hunter", "Beast", "Mastery"})
        assertEqual(cls, "Hunter")
        assertEqual(spec, "Beast Mastery")
    end)

    it("Es insensible a mayúsculas para la clase", function()
        local cls, spec = addon:ParseClassSpecArgs({"warrior", "arms"})
        assertEqual(cls, "Warrior")
        assertEqual(spec, "Arms")
    end)

    it("Devuelve nil para input vacío", function()
        local cls, spec = addon:ParseClassSpecArgs({})
        assertNil(cls)
        assertNil(spec)
    end)

    it("Devuelve nil para clase inexistente", function()
        local cls, spec = addon:ParseClassSpecArgs({"Gnome"})
        assertNil(cls)
    end)

    it("Devuelve clase válida aunque la spec sea inexistente", function()
        local cls, spec = addon:ParseClassSpecArgs({"Warrior", "Banana"})
        assertEqual(cls, "Warrior")
        assertNil(spec)  -- spec inexistente → nil
    end)

end)

describe("Core.lua — SaveLastSelection / GetLastSelection()", function()

    it("Guarda y recupera clase + spec", function()
        addon:SaveLastSelection("Mage", "Fire")
        local cls, spec = addon:GetLastSelection()
        assertEqual(cls,  "Mage")
        assertEqual(spec, "Fire")
    end)

    it("Sobreescribe la selección anterior", function()
        addon:SaveLastSelection("Paladin", "Holy")
        local cls, spec = addon:GetLastSelection()
        assertEqual(cls,  "Paladin")
        assertEqual(spec, "Holy")
    end)

    it("Permite guardar nil para resetear", function()
        addon:SaveLastSelection(nil, nil)
        local cls, spec = addon:GetLastSelection()
        assertNil(cls)
        assertNil(spec)
    end)

end)

describe("Core.lua — SaveWindowPosition / GetWindowPosition()", function()

    it("Guarda y recupera coordenadas", function()
        addon:SaveWindowPosition(100, -200)
        local x, y = addon:GetWindowPosition()
        assertEqual(x, 100)
        assertEqual(y, -200)
    end)

    it("Acepta coordenadas negativas", function()
        addon:SaveWindowPosition(-50, -300)
        local x, y = addon:GetWindowPosition()
        assertEqual(x, -50)
        assertEqual(y, -300)
    end)

end)

describe("Core.lua — Slash commands registrados", function()

    it("El comando /bv está registrado", function()
        assertNotNil(addon._commands, "No hay comandos registrados")
        assertNotNil(addon._commands["bv"], "Falta el comando 'bv'")
    end)

    it("El comando /buildviewer está registrado", function()
        assertNotNil(addon._commands["buildviewer"], "Falta el comando 'buildviewer'")
    end)

end)

describe("Core.lua — Evento PLAYER_LOGIN registrado", function()

    it("El evento PLAYER_LOGIN está registrado", function()
        assertNotNil(addon._events, "No hay eventos registrados")
        assertNotNil(addon._events["PLAYER_LOGIN"], "Falta PLAYER_LOGIN")
    end)

    it("El evento PLAYER_LOGIN se puede disparar sin errores", function()
        SimulateEvent(addon, "PLAYER_LOGIN")
        -- Si no lanza error, el test pasa
    end)

end)

-- =============================================================
--  RESUMEN
-- =============================================================
print("\n=============================================================")
print(string.format("  RESULTADO: %d pasados  |  %d fallados  |  %d total",
    passed, failed, passed + failed))
print("=============================================================")

if failed > 0 then
    print("\nTests fallados:")
    for _, e in ipairs(errors) do
        print("  ✗ " .. e.test)
    end
    os.exit(1)
else
    print("\n¡Todos los tests pasaron! ✓")
    os.exit(0)
end

-- BuildViewer - UI.lua
-- Ventana principal del addon construida con AceGUI.
-- Expone BuildViewer_UI con métodos OpenWindow() y CloseWindow().

local AceGUI = LibStub("AceGUI-3.0")

-- Tabla que contiene el estado y los métodos de la UI
BuildViewer_UI = {}

-- Referencia al frame principal (nil cuando está cerrado)
local mainFrame = nil

-- Colores para el texto
local COLOR_TITLE    = "|cff00ccff"   -- azul claro
local COLOR_HEADER   = "|cffffcc00"   -- amarillo
local COLOR_VALUE    = "|cffffffff"   -- blanco
local COLOR_LINK     = "|cff4488ff"   -- azul link
local COLOR_RESET    = "|r"

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

-- Devuelve una lista ordenada de las claves de una tabla
local function sortedKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

-- Formatea la lista de stats como texto con colores
local function formatStats(stats)
    if not stats or #stats == 0 then return "N/A" end
    local parts = {}
    for i, stat in ipairs(stats) do
        parts[i] = COLOR_VALUE .. stat .. COLOR_RESET
    end
    return table.concat(parts, " > ")
end

-- Construye el texto completo de un build para mostrarlo en el ScrollFrame
local function buildText(className, specName)
    local data = BuildViewerData[className] and BuildViewerData[className][specName]
    if not data then
        return "No hay datos disponibles para " .. (className or "?") .. " - " .. (specName or "?")
    end

    local lines = {}

    -- Cabecera
    table.insert(lines, COLOR_TITLE .. "═══ " .. className .. " — " .. specName .. " ═══" .. COLOR_RESET)
    table.insert(lines, "")

    -- Resumen
    table.insert(lines, COLOR_HEADER .. "Resumen:" .. COLOR_RESET)
    -- Partir el resumen en líneas de ~80 caracteres para que no se salga
    local summary = data.summary or "Sin resumen."
    table.insert(lines, summary)
    table.insert(lines, "")

    -- Prioridad de stats
    table.insert(lines, COLOR_HEADER .. "Prioridad de stats:" .. COLOR_RESET)
    table.insert(lines, formatStats(data.stats))
    table.insert(lines, "")

    -- Gemas
    if data.gems and data.gems ~= "" then
        table.insert(lines, COLOR_HEADER .. "Gemas:" .. COLOR_RESET)
        table.insert(lines, COLOR_VALUE .. (data.gems or "N/A") .. COLOR_RESET)
        table.insert(lines, "")
    end

    -- Encantamientos
    if data.enchants and data.enchants ~= "" then
        table.insert(lines, COLOR_HEADER .. "Encantamientos:" .. COLOR_RESET)
        table.insert(lines, COLOR_VALUE .. (data.enchants or "N/A") .. COLOR_RESET)
        table.insert(lines, "")
    end

    -- Talent string
    if data.talents and data.talents ~= "" then
        table.insert(lines, COLOR_HEADER .. "Talent string (importar en el árbol de talentos):" .. COLOR_RESET)
        table.insert(lines, COLOR_VALUE .. (data.talents or "N/A") .. COLOR_RESET)
        table.insert(lines, "")
    end

    -- Fuente
    table.insert(lines, COLOR_HEADER .. "Fuente:" .. COLOR_RESET)
    table.insert(lines, COLOR_LINK .. (data.url or "N/A") .. COLOR_RESET)

    return table.concat(lines, "\n")
end

-- ─────────────────────────────────────────────
--  CONSTRUCCIÓN DE LA VENTANA
-- ─────────────────────────────────────────────

local function createWindow()
    -- Frame contenedor principal
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(COLOR_TITLE .. "BuildViewer" .. COLOR_RESET .. " — Builds de Icy Veins")
    frame:SetStatusText("WoW Midnight · Datos de icy-veins.com")
    frame:SetWidth(620)
    frame:SetHeight(520)
    frame:SetLayout("Flow")

    -- Restaurar posición guardada
    local savedX, savedY = BuildViewer:GetWindowPosition()
    if savedX and savedY then
        frame.frame:ClearAllPoints()
        frame.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedX, savedY)
    else
        frame:SetPoint("CENTER")
    end

    -- Guardar posición al mover
    frame.frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        BuildViewer:SaveWindowPosition(x, y)
    end)

    -- Al cerrar la ventana con la X
    frame:SetCallback("OnClose", function()
        BuildViewer_UI:CloseWindow()
    end)

    -- ── Fila de selección de clase y spec ──────────────
    local classDropdown = AceGUI:Create("Dropdown")
    classDropdown:SetLabel(COLOR_HEADER .. "Clase" .. COLOR_RESET)
    classDropdown:SetWidth(200)

    local specDropdown = AceGUI:Create("Dropdown")
    specDropdown:SetLabel(COLOR_HEADER .. "Especialización" .. COLOR_RESET)
    specDropdown:SetWidth(200)

    -- ── Botones de acción ───────────────────────────────
    local copyButton = AceGUI:Create("Button")
    copyButton:SetText("Copiar Talent String")
    copyButton:SetWidth(180)
    copyButton:SetDisabled(true)

    -- ── Contenido de texto (scroll) ─────────────────────
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(360)
    scrollContainer:SetLayout("Fill")

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("Flow")
    scrollContainer:AddChild(scrollFrame)

    local contentLabel = AceGUI:Create("Label")
    contentLabel:SetFullWidth(true)
    contentLabel:SetText(
        COLOR_TITLE .. "Bienvenido a BuildViewer" .. COLOR_RESET .. "\n\n" ..
        "Selecciona una |cffffcc00clase|r y una |cffffcc00especialización|r para ver el build recomendado de Icy Veins.\n\n" ..
        "También puedes usar el slash command:\n" ..
        "  |cffffcc00/bv Warrior Arms|r\n" ..
        "  |cffffcc00/bv Mage Fire|r"
    )
    scrollFrame:AddChild(contentLabel)

    -- ── Lógica de los dropdowns ─────────────────────────

    -- Variable local para el talent string actual (para el botón de copiar)
    local currentTalentString = nil

    -- Actualiza el contenido del scroll al seleccionar clase/spec
    local function updateContent(className, specName)
        if not className or not specName then return end
        local text = buildText(className, specName)
        contentLabel:SetText(text)
        scrollFrame:FixScroll()

        -- Actualizar el botón de copiar
        local buildData = BuildViewerData[className] and BuildViewerData[className][specName]
        if buildData and buildData.talents and buildData.talents ~= "" then
            currentTalentString = buildData.talents
            copyButton:SetDisabled(false)
        else
            currentTalentString = nil
            copyButton:SetDisabled(true)
        end

        BuildViewer:SaveLastSelection(className, specName)
    end

    -- Popula el dropdown de specs según la clase seleccionada
    local function populateSpecDropdown(className)
        if not className or not BuildViewerData[className] then return end
        local specs = sortedKeys(BuildViewerData[className])
        local specList = {}
        for _, spec in ipairs(specs) do
            specList[spec] = spec
        end
        specDropdown:SetList(specList)
        specDropdown:SetValue(nil)
        specDropdown:SetText("Selecciona spec...")
        copyButton:SetDisabled(true)
        currentTalentString = nil
    end

    -- Callback del dropdown de clase
    classDropdown:SetCallback("OnValueChanged", function(widget, event, className)
        populateSpecDropdown(className)
        -- Intentar restaurar la spec si es la misma clase
        local lastClass, lastSpec = BuildViewer:GetLastSelection()
        if lastClass == className and lastSpec and BuildViewerData[className][lastSpec] then
            specDropdown:SetValue(lastSpec)
            updateContent(className, lastSpec)
        end
    end)

    -- Callback del dropdown de spec
    specDropdown:SetCallback("OnValueChanged", function(widget, event, specName)
        local className = classDropdown:GetValue()
        if className and specName then
            updateContent(className, specName)
        end
    end)

    -- Callback del botón de copiar
    copyButton:SetCallback("OnClick", function()
        if currentTalentString then
            -- Copiar al clipboard usando la función nativa de WoW
            if C_Clipboard and C_Clipboard.SetText then
                C_Clipboard.SetText(currentTalentString)
                BuildViewer:Print("|cff00ff00Talent string copiado al portapapeles.|r")
            else
                -- Fallback: mostrar en el chat para que el usuario lo copie manualmente
                BuildViewer:Print("Talent string: |cffffcc00" .. currentTalentString .. "|r")
                BuildViewer:Print("(Selecciona el texto de arriba y cópialo manualmente)")
            end
        end
    end)

    -- ── Poblar dropdown de clases ───────────────────────
    local classes = sortedKeys(BuildViewerData)
    local classList = {}
    for _, cls in ipairs(classes) do
        classList[cls] = cls
    end
    classDropdown:SetList(classList)
    classDropdown:SetText("Selecciona clase...")

    -- ── Añadir widgets al frame ─────────────────────────
    frame:AddChild(classDropdown)
    frame:AddChild(specDropdown)
    frame:AddChild(copyButton)
    frame:AddChild(scrollContainer)

    -- ── Separador visual ────────────────────────────────
    -- (AceGUI no tiene separator nativo, usamos un Label vacío como espacio)
    local spacer = AceGUI:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText(" ")
    frame:AddChild(spacer)

    return frame, classDropdown, specDropdown, updateContent
end

-- ─────────────────────────────────────────────
--  API PÚBLICA
-- ─────────────────────────────────────────────

-- Abre la ventana. Opcionalmente acepta clase y spec para ir directamente a un build.
function BuildViewer_UI:OpenWindow(className, specName)
    if mainFrame then
        -- Ya está abierta: mostrar y traer al frente
        mainFrame.frame:Show()
        mainFrame.frame:Raise()
        if className then
            mainFrame._classDropdown:SetValue(className)
            mainFrame._populateSpec(className)
            if specName then
                mainFrame._specDropdown:SetValue(specName)
                mainFrame._updateContent(className, specName)
            end
        end
        return
    end

    -- Crear la ventana
    local frame, classDropdown, specDropdown, updateContent = createWindow()

    -- Guardar referencias para poder acceder desde fuera
    frame._classDropdown  = classDropdown
    frame._specDropdown   = specDropdown
    frame._updateContent  = updateContent
    frame._populateSpec   = function(cls)
        if not cls or not BuildViewerData[cls] then return end
        local specs = sortedKeys(BuildViewerData[cls])
        local specList = {}
        for _, spec in ipairs(specs) do specList[spec] = spec end
        specDropdown:SetList(specList)
        specDropdown:SetText("Selecciona spec...")
    end

    mainFrame = frame

    -- Restaurar selección anterior si existe
    local lastClass, lastSpec = BuildViewer:GetLastSelection()
    local targetClass = className or lastClass
    local targetSpec  = specName  or lastSpec

    if targetClass and BuildViewerData[targetClass] then
        classDropdown:SetValue(targetClass)
        frame._populateSpec(targetClass)
        if targetSpec and BuildViewerData[targetClass][targetSpec] then
            specDropdown:SetValue(targetSpec)
            updateContent(targetClass, targetSpec)
        end
    end

    -- Si se pasó clase/spec explícitamente y no había ventana abierta, navegar directo
    if className and specName then
        updateContent(className, specName)
    end
end

-- Cierra y destruye la ventana
function BuildViewer_UI:CloseWindow()
    if mainFrame then
        AceGUI:Release(mainFrame)
        mainFrame = nil
    end
end

-- Devuelve true si la ventana está abierta
function BuildViewer_UI:IsWindowOpen()
    return mainFrame ~= nil
end

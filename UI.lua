-- BuildViewer - UI.lua
-- Ventana principal v2.0 con soporte multicontexto (Raid, M+, Overall).

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

local function sortedKeys(tbl)
    local keys = {}
    if not tbl then return keys end
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

local function formatStats(stats)
    if not stats or #stats == 0 then return "N/A" end
    local parts = {}
    for i, stat in ipairs(stats) do
        parts[i] = COLOR_VALUE .. stat .. COLOR_RESET
    end
    return table.concat(parts, " > ")
end

-- Construye el texto completo de un build para mostrarlo en el ScrollFrame
local function buildText(className, specName, contextName)
    local specData = BuildViewerData[className] and BuildViewerData[className][specName]
    if not specData then
        return "No hay datos disponibles para " .. (className or "?") .. " - " .. (specName or "?")
    end

    local contextData = specData.builds and specData.builds[contextName]
    if not contextData then
        return "No hay datos para el contexto: " .. (contextName or "?")
    end

    local lines = {}

    -- Cabecera
    table.insert(lines, COLOR_TITLE .. "══ " .. className .. " (" .. specName .. ") - " .. contextName .. " ══" .. COLOR_RESET)
    table.insert(lines, "")

    -- Resumen
    table.insert(lines, COLOR_HEADER .. "Resumen:" .. COLOR_RESET)
    table.insert(lines, specData.summary or "Sin resumen.")
    table.insert(lines, "")

    -- Prioridad de stats
    table.insert(lines, COLOR_HEADER .. "Prioridad de stats:" .. COLOR_RESET)
    table.insert(lines, formatStats(specData.stats))
    table.insert(lines, "")

    -- Gear (BiS)
    table.insert(lines, COLOR_HEADER .. "Equipamiento Best in Slot (BIS):" .. COLOR_RESET)
    if contextData.gear and contextData.gear ~= "" then
        table.insert(lines, COLOR_VALUE .. contextData.gear .. COLOR_RESET)
    else
        table.insert(lines, "No hay datos de equipo para este contexto.")
    end
    table.insert(lines, "")

    -- Talent string
    if contextData.talents and contextData.talents ~= "" then
        table.insert(lines, COLOR_HEADER .. "Talent string (Importar):" .. COLOR_RESET)
        table.insert(lines, COLOR_VALUE .. contextData.talents .. COLOR_RESET)
        table.insert(lines, "")
    end

    -- Fuente
    table.insert(lines, COLOR_HEADER .. "Fuente:" .. COLOR_RESET)
    table.insert(lines, COLOR_LINK .. (specData.url or "N/A") .. COLOR_RESET)

    return table.concat(lines, "\n")
end

-- ─────────────────────────────────────────────
--  CONSTRUCCIÓN DE LA VENTANA
-- ─────────────────────────────────────────────

local function createWindow()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(COLOR_TITLE .. "BuildViewer v2.0" .. COLOR_RESET)
    frame:SetStatusText("Datos: Icy Veins | Contextos: Overall, Raid, M+")
    frame:SetWidth(650)
    frame:SetHeight(550)
    frame:SetLayout("Flow")

    -- Posición
    local savedX, savedY = BuildViewer:GetWindowPosition()
    if savedX and savedY then
        frame.frame:ClearAllPoints()
        frame.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedX, savedY)
    else
        frame:SetPoint("CENTER")
    end
    frame.frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        BuildViewer:SaveWindowPosition(x, y)
    end)

    frame:SetCallback("OnClose", function() BuildViewer_UI:CloseWindow() end)

    -- ── Selectores ───────────────────────────────
    local classDropdown = AceGUI:Create("Dropdown")
    classDropdown:SetLabel("Clase")
    classDropdown:SetWidth(180)

    local specDropdown = AceGUI:Create("Dropdown")
    specDropdown:SetLabel("Especialización")
    specDropdown:SetWidth(180)

    local contextDropdown = AceGUI:Create("Dropdown")
    contextDropdown:SetLabel("Contexto/Modo")
    contextDropdown:SetWidth(180)
    contextDropdown:SetList({["Overall"]="Overall", ["Raid"]="Raid", ["Mythic+"]="Mythic+"})

    -- ── Botones ──────────────────────────────────
    local copyButton = AceGUI:Create("Button")
    copyButton:SetText("Copiar Talentos")
    copyButton:SetWidth(180)
    copyButton:SetDisabled(true)

    -- ── Contenido ────────────────────────────────
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(360)
    scrollContainer:SetLayout("Fill")

    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("Flow")
    scrollContainer:AddChild(scrollFrame)

    local contentLabel = AceGUI:Create("Label")
    contentLabel:SetFullWidth(true)
    contentLabel:SetText("Selecciona Clase, Spec y el Modo (Raid/M+).")
    scrollFrame:AddChild(contentLabel)

    local currentTalentString = nil

    local function updateContent()
        local className = classDropdown:GetValue()
        local specName = specDropdown:GetValue()
        local contextName = contextDropdown:GetValue()

        if not className or not specName or not contextName then return end

        local text = buildText(className, specName, contextName)
        contentLabel:SetText(text)
        scrollFrame:FixScroll()

        local specData = BuildViewerData[className] and BuildViewerData[className][specName]
        local ctxData = specData and specData.builds and specData.builds[contextName]
        
        if ctxData and ctxData.talents and ctxData.talents ~= "" then
            currentTalentString = ctxData.talents
            copyButton:SetDisabled(false)
        else
            currentTalentString = nil
            copyButton:SetDisabled(true)
        end

        BuildViewer:SaveLastSelection(className, specName, contextName)
    end

    classDropdown:SetCallback("OnValueChanged", function(w, e, val)
        local specs = sortedKeys(BuildViewerData[val])
        local list = {}
        for _, s in ipairs(specs) do list[s] = s end
        specDropdown:SetList(list)
        specDropdown:SetValue(nil)
        updateContent()
    end)

    specDropdown:SetCallback("OnValueChanged", updateContent)
    contextDropdown:SetCallback("OnValueChanged", updateContent)

    copyButton:SetCallback("OnClick", function()
        if currentTalentString then
            if C_Clipboard and C_Clipboard.SetText then
                C_Clipboard.SetText(currentTalentString)
                BuildViewer:Print("|cff00ff00Talentos copiados al portapapeles.|r")
            else
                BuildViewer:Print("Talentos: |cffffcc00" .. currentTalentString .. "|r")
            end
        end
    end)

    -- Población inicial
    local classes = sortedKeys(BuildViewerData)
    local cList = {}
    for _, c in ipairs(classes) do cList[c] = c end
    classDropdown:SetList(cList)

    frame:AddChild(classDropdown)
    frame:AddChild(specDropdown)
    frame:AddChild(contextDropdown)
    frame:AddChild(copyButton)
    frame:AddChild(scrollContainer)

    return frame, classDropdown, specDropdown, contextDropdown, updateContent
end

-- ── API ───────────────────────────────────────

function BuildViewer_UI:OpenWindow()
    if mainFrame then 
        mainFrame.frame:Show()
        return 
    end

    local frame, classDropdown, specDropdown, contextDropdown, updateContent = createWindow()
    mainFrame = frame

    local lastClass, lastSpec, lastContext = BuildViewer:GetLastSelection()
    if lastClass and BuildViewerData[lastClass] then
        classDropdown:SetValue(lastClass)
        local specs = sortedKeys(BuildViewerData[lastClass])
        local list = {}
        for _, s in ipairs(specs) do list[s] = s end
        specDropdown:SetList(list)
        
        if lastSpec and BuildViewerData[lastClass][lastSpec] then
            specDropdown:SetValue(lastSpec)
        end
    end
    contextDropdown:SetValue(lastContext or "Overall")
    updateContent()
end

function BuildViewer_UI:CloseWindow()
    if mainFrame then AceGUI:Release(mainFrame); mainFrame = nil end
end

function BuildViewer_UI:IsWindowOpen() return mainFrame ~= nil end

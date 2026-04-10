-- BuildViewer - UI.lua
-- Interfaz Estilo PaperDoll (Panel de Personaje) v3.0

local AceGUI = LibStub("AceGUI-3.0")

-- Tabla global de la UI
BuildViewer_UI = {}

local mainFrame = nil
local slotButtons = {} -- Contenedor de botones de equipo
local alternativeIndices = {} -- Guarda qué índice de alternativa tiene cada slot seleccionado

-- Configuración de colores
local COLOR_TITLE  = "|cff00ccff"
local COLOR_HEADER = "|cffffcc00"
local COLOR_RESET  = "|r"

-- Mapeo de slots y posiciones relativas (x, y)
-- Basado en una cuadrícula central
local SLOT_CONFIG = {
    -- Izquierda
    { slot = "Head",     x = -240, y = 140 },
    { slot = "Neck",     x = -240, y = 90  },
    { slot = "Shoulder", x = -240, y = 40  },
    { slot = "Back",     x = -240, y = -10 },
    { slot = "Chest",    x = -240, y = -60 },
    { slot = "Wrist",    x = -240, y = -110},
    -- Derecha
    { slot = "Hands",    x = 240,  y = 140 },
    { slot = "Waist",    x = 240,  y = 90  },
    { slot = "Legs",     x = 240,  y = 40  },
    { slot = "Feet",     x = 240,  y = -10 },
    { slot = "Finger1",  x = 240,  y = -60 },
    { slot = "Finger2",  x = 240,  y = -110},
    -- Trinkets (abajo derecha o junto a dedos)
    { slot = "Trinket1", x = 240,  y = -160},
    { slot = "Trinket2", x = 240,  y = -210},
    -- Armas (abajo)
    { slot = "MainHand", x = -80,  y = -210},
    { slot = "OffHand",  x = 80,   y = -210},
}

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

local function GetItemData(className, specName, contextName, slotName)
    local spec = BuildViewerData[className] and BuildViewerData[className][specName]
    local ctx = spec and spec.builds and spec.builds[contextName]
    if ctx and ctx.gear and ctx.gear[slotName] then
        return ctx.gear[slotName]
    end
    return nil
end

-- Actualiza el aspecto de un botón de slot
local function UpdateSlotButton(btn, className, specName, contextName)
    local items = GetItemData(className, specName, contextName, btn.slotName)
    
    if not items or #items == 0 then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
        btn.border:SetVertexColor(0.4, 0.4, 0.4, 1)
        btn.hasAlt:Hide()
        btn.itemID = nil
        return
    end

    -- Obtener el índice actual (por defecto 1)
    local idxKey = btn.slotName
    local idx = alternativeIndices[idxKey] or 1
    if idx > #items then idx = 1; alternativeIndices[idxKey] = 1 end

    local itemData = items[idx]
    btn.itemID = itemData.id
    
    -- Carga de icono y rareza desde el juego
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(itemData.id)
    
    if texture then
        btn.icon:SetTexture(texture)
    else
        -- Si no está en caché, usamos uno genérico temporal
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Color del borde según calidad
    if quality then
        local r, g, b = GetItemQualityColor(quality)
        btn.border:SetVertexColor(r, g, b, 1)
    else
        btn.border:SetVertexColor(1, 1, 1, 0.5)
    end

    -- Mostrar indicador si hay alternativas
    if #items > 1 then
        btn.hasAlt:Show()
    else
        btn.hasAlt:Hide()
    end
end

-- ─────────────────────────────────────────────
--  CONSTRUCCIÓN DE SLOTS
-- ─────────────────────────────────────────────

local function CreateItemSlot(parent, config)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(46, 46)
    btn:SetPoint("CENTER", parent, "CENTER", config.x, config.y)
    btn.slotName = config.slot

    -- Textura de fondo (Slot vacío)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
    bg:SetAlpha(0.2)

    -- Icono del objeto
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    -- Borde de calidad
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(68, 68)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    btn.border = border

    -- Indicador de alternativas (Flecha pequeña)
    local hasAlt = btn:CreateTexture(nil, "OVERLAY")
    hasAlt:SetSize(16, 16)
    hasAlt:SetPoint("TOPRIGHT", -2, -2)
    hasAlt:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up")
    hasAlt:Hide()
    btn.hasAlt = hasAlt

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Rotación de alternativas al hacer clic
    btn:SetScript("OnClick", function(self)
        local className = BuildViewer_UI.currentClass
        local specName = BuildViewer_UI.currentSpec
        local contextName = BuildViewer_UI.currentContext

        local items = GetItemData(className, specName, contextName, self.slotName)
        if items and #items > 1 then
            local idx = (alternativeIndices[self.slotName] or 1) + 1
            if idx > #items then idx = 1 end
            alternativeIndices[self.slotName] = idx
            UpdateSlotButton(self, className, specName, contextName)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)

    return btn
end

-- ─────────────────────────────────────────────
--  VENTANA PRINCIPAL
-- ─────────────────────────────────────────────

local function createWindow()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(COLOR_TITLE .. "BuildViewer v3.0 - BiS PaperDoll" .. COLOR_RESET)
    frame:SetWidth(800)
    frame:SetHeight(650)
    frame:SetLayout("Flow")

    -- Callbacks de posición
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

    -- Contenedor de Selectores Superior
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetFullWidth(true)
    headerGroup:SetLayout("Flow")
    frame:AddChild(headerGroup)

    local classDropdown = AceGUI:Create("Dropdown")
    classDropdown:SetLabel("Clase")
    classDropdown:SetWidth(150)
    headerGroup:AddChild(classDropdown)

    local specDropdown = AceGUI:Create("Dropdown")
    specDropdown:SetLabel("Especialización")
    specDropdown:SetWidth(150)
    headerGroup:AddChild(specDropdown)

    local contextDropdown = AceGUI:Create("Dropdown")
    contextDropdown:SetLabel("Modo")
    contextDropdown:SetWidth(150)
    contextDropdown:SetList({["Overall"]="General", ["Raid"]="Banda", ["Mythic+"]="Míticas+"})
    headerGroup:AddChild(contextDropdown)

    local talentButton = AceGUI:Create("Button")
    talentButton:SetText("Copiar Talentos")
    talentButton:SetWidth(150)
    headerGroup:AddChild(talentButton)

    -- Área Central (Simulación PaperDoll)
    local dollFrame = CreateFrame("Frame", nil, frame.content)
    dollFrame:SetSize(600, 450)
    dollFrame:SetPoint("TOP", frame.content, "TOP", 0, -20)
    
    -- Fondo (Opcional: Símbolo de clase o silueta)
    local bg = dollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(300, 400)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\PaperdollInfoFrame\\UI-Character-CharacterStats-Background")
    bg:SetAlpha(0.15)

    -- Crear los huecos
    slotButtons = {}
    for _, config in ipairs(SLOT_CONFIG) do
        local btn = CreateItemSlot(dollFrame, config)
        table.insert(slotButtons, btn)
    end

    -- Resumen inferior
    local summaryText = AceGUI:Create("Label")
    summaryText:SetFullWidth(true)
    summaryText:SetFontObject(GameFontNormalSmall)
    summaryText:SetText("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n") -- Espaciado para el paperdoll
    frame:AddChild(summaryText)

    local function updateAll()
        local c = classDropdown:GetValue()
        local s = specDropdown:GetValue()
        local ctx = contextDropdown:GetValue()
        
        BuildViewer_UI.currentClass = c
        BuildViewer_UI.currentSpec = s
        BuildViewer_UI.currentContext = ctx

        if not c or not s or not ctx then return end

        local data = BuildViewerData[c] and BuildViewerData[c][s]
        if not data then return end

        -- Actualizar cada botón
        for _, btn in ipairs(slotButtons) do
            UpdateSlotButton(btn, c, s, ctx)
        end

        summaryText:SetText(string.format("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n%sStats: %s|r\n%s", COLOR_HEADER, table.concat(data.stats or {}, " > "), data.summary or ""))

        -- Botón de talentos
        local bData = data.builds and data.builds[ctx]
        if bData and bData.talents and bData.talents ~= "" then
            talentButton:SetDisabled(false)
            talentButton.talentString = bData.talents
        else
            talentButton:SetDisabled(true)
            talentButton.talentString = nil
        end
        
        BuildViewer:SaveLastSelection(c, s, ctx)
    end

    classDropdown:SetCallback("OnValueChanged", function(_, _, val)
        local specs = {}
        for k in pairs(BuildViewerData[val]) do specs[k] = k end
        specDropdown:SetList(specs)
        specDropdown:SetValue(nil)
        updateAll()
    end)

    specDropdown:SetCallback("OnValueChanged", updateAll)
    contextDropdown:SetCallback("OnValueChanged", updateAll)
    
    talentButton:SetCallback("OnClick", function(self)
        if self.talentString then
            if C_Clipboard then C_Clipboard.SetText(self.talentString) end
            BuildViewer:Print("Talento copiado.")
        end
    end)

    -- Inicialización
    local classes = {}
    for k in pairs(BuildViewerData) do classes[k] = k end
    classDropdown:SetList(classes)

    return frame, classDropdown, specDropdown, contextDropdown, updateAll
end

-- ── API ───────────────────────────────────────

function BuildViewer_UI:OpenWindow()
    if mainFrame then mainFrame:Show(); return end
    
    local frame, classDropdown, specDropdown, contextDropdown, updateAll = createWindow()
    mainFrame = frame

    local lastC, lastS, lastCtx = BuildViewer:GetLastSelection()
    if lastC and BuildViewerData[lastC] then
        classDropdown:SetValue(lastC)
        local specs = {}
        for k in pairs(BuildViewerData[lastC]) do specs[k] = k end
        specDropdown:SetList(specs)
        if lastS and BuildViewerData[lastC][lastS] then
            specDropdown:SetValue(lastS)
        end
    end
    contextDropdown:SetValue(lastCtx or "Overall")
    updateAll()
end

function BuildViewer_UI:CloseWindow()
    if mainFrame then AceGUI:Release(mainFrame); mainFrame = nil end
end

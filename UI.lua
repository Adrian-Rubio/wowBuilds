-- BuildViewer - UI.lua
-- Interfaz Estilo PaperDoll (Panel de Personaje) v3.1

local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then 
    print("|cffff0000BuildViewer ERROR: AceGUI-3.0 no encontrado.|r")
    return 
end

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
local SLOT_CONFIG = {
    { slot = "Head",     x = -240, y = 140 },
    { slot = "Neck",     x = -240, y = 90  },
    { slot = "Shoulder", x = -240, y = 40  },
    { slot = "Back",     x = -240, y = -10 },
    { slot = "Chest",    x = -240, y = -60 },
    { slot = "Wrist",    x = -240, y = -110},
    { slot = "Hands",    x = 240,  y = 140 },
    { slot = "Waist",    x = 240,  y = 90  },
    { slot = "Legs",     x = 240,  y = 40  },
    { slot = "Feet",     x = 240,  y = -10 },
    { slot = "Finger1",  x = 240,  y = -60 },
    { slot = "Finger2",  x = 240,  y = -110},
    { slot = "Trinket1", x = 240,  y = -160},
    { slot = "Trinket2", x = 240,  y = -210},
    { slot = "MainHand", x = -80,  y = -210},
    { slot = "OffHand",  x = 80,   y = -210},
}

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

local function GetItemData(className, specName, contextName, slotName)
    if not BuildViewerData then return nil end
    local spec = BuildViewerData[className] and BuildViewerData[className][specName]
    local ctx = spec and spec.builds and spec.builds[contextName]
    if ctx and ctx.gear and ctx.gear[slotName] then
        return ctx.gear[slotName]
    end
    return nil
end

local function UpdateSlotButton(btn, className, specName, contextName)
    local items = GetItemData(className, specName, contextName, btn.slotName)
    
    if not items or #items == 0 then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
        btn.border:SetVertexColor(0.4, 0.4, 0.4, 1)
        btn.hasAlt:Hide()
        btn.itemID = nil
        return
    end

    local idx = alternativeIndices[btn.slotName] or 1
    if idx > #items then idx = 1; alternativeIndices[btn.slotName] = 1 end

    local itemData = items[idx]
    btn.itemID = itemData.id
    
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(itemData.id)
    
    if texture then
        btn.icon:SetTexture(texture)
    else
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    if quality then
        local r, g, b = GetItemQualityColor(quality)
        btn.border:SetVertexColor(r, g, b, 1)
    else
        btn.border:SetVertexColor(1, 1, 1, 0.5)
    end

    if #items > 1 then btn.hasAlt:Show() else btn.hasAlt:Hide() end
end

-- ─────────────────────────────────────────────
--  CONSTRUCCIÓN DE SLOTS
-- ─────────────────────────────────────────────

local function CreateItemSlot(parent, config)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(46, 46)
    btn:SetPoint("CENTER", parent, "CENTER", config.x, config.y)
    btn.slotName = config.slot

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
    bg:SetAlpha(0.2)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(68, 68)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    btn.border = border

    local hasAlt = btn:CreateTexture(nil, "OVERLAY")
    hasAlt:SetSize(16, 16)
    hasAlt:SetPoint("TOPRIGHT", -2, -2)
    hasAlt:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up")
    hasAlt:Hide()
    btn.hasAlt = hasAlt

    btn:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self)
        local c = BuildViewer_UI.currentClass
        local s = BuildViewer_UI.currentSpec
        local ctx = BuildViewer_UI.currentContext
        local items = GetItemData(c, s, ctx, self.slotName)
        if items and #items > 1 then
            local idx = (alternativeIndices[self.slotName] or 1) + 1
            if idx > #items then idx = 1 end
            alternativeIndices[self.slotName] = idx
            UpdateSlotButton(self, c, s, ctx)
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
    frame:SetTitle(COLOR_TITLE .. "BuildViewer v3.1" .. COLOR_RESET)
    frame:SetLayout("Flow")

    local savedX, savedY = BuildViewer:GetWindowPosition()
    local savedW, savedH = BuildViewer:GetWindowSize()
    
    if savedW and savedH then
        frame:SetWidth(math.max(600, savedW))
        frame:SetHeight(math.max(500, savedH))
    else
        frame:SetWidth(800)
        frame:SetHeight(650)
    end

    if savedX and savedY then
        frame.frame:ClearAllPoints()
        frame.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedX, savedY)
    else
        frame:SetPoint("CENTER")
    end

    frame.frame:SetResizable(true)
    frame.frame:SetMinResize(600, 500)
    frame.frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        BuildViewer:SaveWindowPosition(x, y)
    end)
    frame.frame:SetScript("OnSizeChanged", function(self, width, height)
        BuildViewer:SaveWindowSize(width, height)
    end)
    frame:SetCallback("OnClose", function() BuildViewer_UI:CloseWindow() end)

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

    local dollFrame = CreateFrame("Frame", nil, frame.content)
    dollFrame:SetSize(600, 450)
    dollFrame:SetPoint("TOP", frame.content, "TOP", 0, -20)
    
    local bg = dollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(300, 400)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\PaperdollInfoFrame\\UI-Character-CharacterStats-Background")
    bg:SetAlpha(0.15)

    slotButtons = {}
    for _, config in ipairs(SLOT_CONFIG) do
        local btn = CreateItemSlot(dollFrame, config)
        table.insert(slotButtons, btn)
    end

    local summaryText = AceGUI:Create("Label")
    summaryText:SetFullWidth(true)
    summaryText:SetFontObject(GameFontNormalSmall)
    summaryText:SetText("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n") 
    frame:AddChild(summaryText)

    local function updateAll()
        local c = classDropdown:GetValue()
        local s = specDropdown:GetValue()
        local ctx = contextDropdown:GetValue()
        BuildViewer_UI.currentClass, BuildViewer_UI.currentSpec, BuildViewer_UI.currentContext = c, s, ctx
        if not c or not s or not ctx or not BuildViewerData then return end
        local data = BuildViewerData[c] and BuildViewerData[c][s]
        if not data then return end
        for _, btn in ipairs(slotButtons) do UpdateSlotButton(btn, c, s, ctx) end
        summaryText:SetText(string.format("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n%sStats: %s|r\n%s", COLOR_HEADER, table.concat(data.stats or {}, " > "), data.summary or ""))
        local bData = data.builds and data.builds[ctx]
        talentButton:SetDisabled(not (bData and bData.talents and bData.talents ~= ""))
        talentButton.talentString = bData and bData.talents
        BuildViewer:SaveLastSelection(c, s, ctx)
    end

    classDropdown:SetCallback("OnValueChanged", function(_, _, val)
        local specs = {}
        if BuildViewerData and BuildViewerData[val] then
            for k in pairs(BuildViewerData[val]) do specs[k] = k end
        end
        specDropdown:SetList(specs); specDropdown:SetValue(nil); updateAll()
    end)
    specDropdown:SetCallback("OnValueChanged", updateAll)
    contextDropdown:SetCallback("OnValueChanged", updateAll)
    talentButton:SetCallback("OnClick", function(self)
        if self.talentString and C_Clipboard then C_Clipboard.SetText(self.talentString); BuildViewer:Print("Talento copiado.") end
    end)

    if BuildViewerData then
        local classes = {}
        for k in pairs(BuildViewerData) do classes[k] = k end
        classDropdown:SetList(classes)
    end

    return frame, classDropdown, specDropdown, contextDropdown, updateAll
end

-- ── API ───────────────────────────────────────

function BuildViewer_UI:OpenWindow(cls, spec)
    if not BuildViewerData then 
        print("|cffff0000BuildViewer ERROR: No se cargaron los datos (Builds.lua).|r")
        return 
    end
    if mainFrame then 
        if cls then BuildViewer_UI:SetSelection(cls, spec) end
        mainFrame:Show(); return 
    end
    local frame, cd, sd, ctd, updateAll = createWindow()
    mainFrame, BuildViewer_UI.classDropdown, BuildViewer_UI.specDropdown, BuildViewer_UI.contextDropdown, BuildViewer_UI.updateAll = frame, cd, sd, ctd, updateAll
    local lastC, lastS, lastCtx = BuildViewer:GetLastSelection()
    local c, s = cls or lastC, spec or lastS
    if c and BuildViewerData[c] then
        cd:SetValue(c)
        local specs = {}
        for k in pairs(BuildViewerData[c]) do specs[k] = k end
        sd:SetList(specs)
        if s and BuildViewerData[c][s] then sd:SetValue(s) end
    end
    ctd:SetValue(lastCtx or "Overall"); updateAll()
end

function BuildViewer_UI:SetSelection(cls, spec)
    if not mainFrame or not cls then return end
    self.classDropdown:SetValue(cls)
    local specs = {}
    if BuildViewerData[cls] then for k in pairs(BuildViewerData[cls]) do specs[k] = k end end
    self.specDropdown:SetList(specs)
    self.specDropdown:SetValue(spec); self.updateAll()
end

function BuildViewer_UI:IsWindowOpen() return mainFrame ~= nil and mainFrame:IsShown() end
function BuildViewer_UI:CloseWindow() if mainFrame then AceGUI:Release(mainFrame); mainFrame = nil end end

-- BuildViewer - UI.lua
-- Interfaz Estilo PaperDoll (Panel de Personaje) v4.0 (Rediseño Sidebar)

local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then return end

BuildViewer_UI = {}
local mainFrame = nil
local slotButtons = {}
local alternativeIndices = {}

local COLOR_TITLE  = "|cff00ccff"
local COLOR_HEADER = "|cffffcc00"
local COLOR_RESET  = "|r"

local SLOT_CONFIG = {
    { slot = "Head",     x = -180, y = 140 }, { slot = "Hands",    x = 180, y = 140 },
    { slot = "Neck",     x = -180, y = 90  }, { slot = "Waist",    x = 180, y = 90  },
    { slot = "Shoulder", x = -180, y = 40  }, { slot = "Legs",     x = 180, y = 40  },
    { slot = "Back",     x = -180, y = -10 }, { slot = "Feet",     x = 180, y = -10 },
    { slot = "Chest",    x = -180, y = -60 }, { slot = "Finger1",  x = 180, y = -60 },
    { slot = "Wrist",    x = -180, y = -110}, { slot = "Finger2",  x = 180, y = -110},
    -- Extras
    { slot = "Trinket1", x = 180,  y = -160}, { slot = "Trinket2", x = 180,  y = -210},
    { slot = "MainHand", x = -60,  y = -210}, { slot = "OffHand",  x = 60,   y = -210},
}

local function UpdateSlotButton(btn, className, specName, contextName)
    if not BuildViewerData then return end
    local items = nil
    if className and specName and contextName then
        local spec = BuildViewerData[className] and BuildViewerData[className][specName]
        local build = spec and spec.builds and spec.builds[contextName]
        items = build and build.gear and build.gear[btn.slotName]
    end
    
    if not items or #items == 0 then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
        btn.border:Hide(); btn.hasAlt:Hide(); btn.itemID = nil; return
    end

    local idx = alternativeIndices[btn.slotName] or 1
    if idx > #items then idx = 1 end
    local itemData = items[idx]
    btn.itemID = itemData.id
    
    local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemData.id)
    btn.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if quality then
        local r, g, b = GetItemQualityColor(quality)
        btn.border:SetVertexColor(r, g, b, 1); btn.border:Show()
    else
        btn.border:Hide()
    end
    if #items > 1 then btn.hasAlt:Show() else btn.hasAlt:Hide() end
end

local function CreateItemSlot(parent, config)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(42, 42); btn:SetPoint("CENTER", parent, "CENTER", config.x, config.y)
    btn.slotName = config.slot

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-White"); bg:SetAlpha(0.2)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(60, 60); border:SetPoint("CENTER")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); border:SetBlendMode("ADD"); btn.border = border

    local hasAlt = btn:CreateTexture(nil, "OVERLAY")
    hasAlt:SetSize(14, 14); hasAlt:SetPoint("TOPRIGHT", -1, -1)
    hasAlt:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up"); btn.hasAlt = hasAlt

    btn:SetScript("OnEnter", function(self) if self.itemID then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.itemID); GameTooltip:Show() end end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        if not (BuildViewer_UI.c and BuildViewer_UI.s and BuildViewer_UI.ctx) then return end
        local build = BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s].builds[BuildViewer_UI.ctx]
        local items = build and build.gear and build.gear[self.slotName]
        if items and #items > 1 then
            alternativeIndices[self.slotName] = ((alternativeIndices[self.slotName] or 1) % #items) + 1
            UpdateSlotButton(self, BuildViewer_UI.c, BuildViewer_UI.s, BuildViewer_UI.ctx)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    return btn
end

local function createWindow()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(COLOR_TITLE .. "BuildViewer v4.0 - Base de Datos" .. COLOR_RESET)
    frame:SetLayout("Fill") -- Usamos Fill para que el TreeGroup ocupe todo
    
    local w, h = BuildViewer:GetWindowSize()
    frame:SetWidth(w or 850); frame:SetHeight(h or 650)
    local x, y = BuildViewer:GetWindowPosition()
    if x and y then 
        frame.frame:ClearAllPoints(); frame.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) 
    else 
        frame:SetPoint("CENTER") 
    end

    frame.frame:SetResizable(true); frame.frame:SetMinResize(700, 500)
    frame.frame:HookScript("OnDragStop", function(self) local _, _, _, ox, oy = self:GetPoint(); BuildViewer:SaveWindowPosition(ox, oy) end)
    frame.frame:HookScript("OnSizeChanged", function(self, nw, nh) BuildViewer:SaveWindowSize(nw, nh) end)
    frame:SetCallback("OnClose", function() BuildViewer_UI:CloseWindow() end)

    -- Navegación Lateral (Abandono de Dropdowns rotos)
    local treeGroup = AceGUI:Create("TreeGroup")
    treeGroup:SetTreeWidth(200, false)
    treeGroup:SetLayout("Flow")
    frame:AddChild(treeGroup)

    -- Botón Superior (Right Panel)
    local tb = AceGUI:Create("Button")
    tb:SetText("Copiar Talentos")
    tb:SetWidth(200)
    tb:SetDisabled(true)
    treeGroup:AddChild(tb)

    -- Espaciador para PaperDoll
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ") 
    spacer:SetFullWidth(true)
    spacer:SetHeight(400)
    treeGroup:AddChild(spacer)

    local dollFrame = CreateFrame("Frame", nil, spacer.frame)
    dollFrame:SetAllPoints()
    
    local bg = dollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(280, 360); bg:SetPoint("CENTER", 0, 10)
    bg:SetTexture("Interface\\PaperdollInfoFrame\\UI-Character-CharacterStats-Background")
    bg:SetAlpha(0.2)

    slotButtons = {}
    for _, cfg in ipairs(SLOT_CONFIG) do table.insert(slotButtons, CreateItemSlot(dollFrame, cfg)) end

    local summaryText = AceGUI:Create("Label")
    summaryText:SetFullWidth(true)
    summaryText:SetFontObject(GameFontNormalSmall)
    summaryText:SetText("\n\n\n\n Selecciona una clase a la izquierda.")
    treeGroup:AddChild(summaryText)

    local function update(c, s, ctx)
        if not c or not s or not ctx or not BuildViewerData then return end
        local data = BuildViewerData[c] and BuildViewerData[c][s]
        if not data then return end
        
        for _, b in ipairs(slotButtons) do UpdateSlotButton(b, c, s, ctx) end
        
        summaryText:SetText(string.format("\n%sStats: %s|r\n%s", COLOR_HEADER, table.concat(data.stats or {}, " > "), data.summary or ""))
        
        local b = data.builds and data.builds[ctx]
        tb:SetDisabled(not (b and b.talents and b.talents ~= ""))
        tb.t = b and b.talents
        BuildViewer:SaveLastSelection(c, s, ctx)
    end

    tb:SetCallback("OnClick", function(self) if self.t and C_Clipboard then C_Clipboard.SetText(self.t); BuildViewer:Print("Talento copiado.") end end)

    -- Rellenar el Árbol
    if BuildViewerData then
        local tData = {}
        local classes = {}
        for c in pairs(BuildViewerData) do table.insert(classes, c) end
        table.sort(classes)

        for _, c in ipairs(classes) do
            local specNodes = {}
            local specs = {}
            for s in pairs(BuildViewerData[c]) do table.insert(specs, s) end
            table.sort(specs)
            
            for _, s in ipairs(specs) do
                local ctxNodes = {
                    { value = "Overall", text = "General" },
                    { value = "Raid", text = "Banda" },
                    { value = "Mythic+", text = "Míticas+" }
                }
                table.insert(specNodes, { value = s, text = s, children = ctxNodes })
            end
            table.insert(tData, { value = c, text = "|cff80ff80"..c.."|r", children = specNodes })
        end
        treeGroup:SetTree(tData)
    end

    treeGroup:SetCallback("OnGroupSelected", function(self, event, group)
        local c, s, ctx = string.split("\001", group)
        BuildViewer_UI.c = c
        BuildViewer_UI.s = s
        BuildViewer_UI.ctx = ctx
        
        if c and s and ctx then
            update(c, s, ctx)
        else
            for _, b in ipairs(slotButtons) do UpdateSlotButton(b, nil, nil, nil) end
            summaryText:SetText("\nSelecciona un modo (General, Banda, Míticas+) a la izquierda.")
            tb:SetDisabled(true)
        end
    end)

    return frame, treeGroup, update
end

function BuildViewer_UI:OpenWindow(cls, spec)
    if not BuildViewerData then print("|cffff0000BuildViewer: Error cargando Builds.lua|r"); return end
    if mainFrame then 
        if cls then BuildViewer_UI:SetSelection(cls, spec) end
        mainFrame:Show()
        return 
    end
    
    local f, tg, u = createWindow()
    mainFrame, BuildViewer_UI.treeGroup, BuildViewer_UI.u = f, tg, u
    
    local lc, ls, lctx = BuildViewer:GetLastSelection()
    local c = cls or lc
    local s = spec or ls
    local ctx = lctx or "Overall"
    
    if c and s and ctx and BuildViewerData[c] and BuildViewerData[c][s] then
        tg:SelectByPath(c, s, ctx)
    end
end

function BuildViewer_UI:SetSelection(c, s)
    if not mainFrame then return end
    if c and s and BuildViewerData[c] and BuildViewerData[c][s] then
        local ctx = BuildViewer_UI.ctx or "Overall"
        BuildViewer_UI.treeGroup:SelectByPath(c, s, ctx)
    end
end

function BuildViewer_UI:IsWindowOpen() return mainFrame ~= nil and mainFrame:IsShown() end
function BuildViewer_UI:CloseWindow() if mainFrame then AceGUI:Release(mainFrame); mainFrame = nil end end

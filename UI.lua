-- BuildViewer - UI.lua
-- Interfaz Estilo PaperDoll (Panel de Personaje) v3.2

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
    local items = (BuildViewerData[className] and BuildViewerData[className][specName] and 
                   BuildViewerData[className][specName].builds[contextName] and 
                   BuildViewerData[className][specName].builds[contextName].gear[btn.slotName])
    
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
        local items = BuildViewerData[BuildViewer_UI.c] and BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s] and BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s].builds[BuildViewer_UI.ctx].gear[self.slotName]
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
    frame:SetTitle(COLOR_TITLE .. "BuildViewer v3.2" .. COLOR_RESET)
    frame:SetLayout("Flow")
    
    local w, h = BuildViewer:GetWindowSize()
    frame:SetWidth(w or 800); frame:SetHeight(h or 650)
    local x, y = BuildViewer:GetWindowPosition()
    if x and y then frame.frame:ClearAllPoints(); frame.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) else frame:SetPoint("CENTER") end

    frame.frame:SetResizable(true); frame.frame:SetMinResize(600, 500)
    frame.frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); local _, _, _, ox, oy = self:GetPoint(); BuildViewer:SaveWindowPosition(ox, oy) end)
    frame.frame:SetScript("OnSizeChanged", function(self, nw, nh) BuildViewer:SaveWindowSize(nw, nh) end)
    frame:SetCallback("OnClose", function() BuildViewer_UI:CloseWindow() end)

    -- Contenedores
    local hGroup = AceGUI:Create("SimpleGroup")
    hGroup:SetFullWidth(true); hGroup:SetLayout("Flow"); frame:AddChild(hGroup)

    local cd = AceGUI:Create("Dropdown"); cd:SetLabel("Clase"); cd:SetWidth(140); hGroup:AddChild(cd)
    local sd = AceGUI:Create("Dropdown"); sd:SetLabel("Especialización"); sd:SetWidth(140); hGroup:AddChild(sd)
    local ctd = AceGUI:Create("Dropdown"); ctd:SetLabel("Modo"); ctd:SetWidth(140); ctd:SetList({Overall="General", Raid="Banda", ["Mythic+"]="Míticas+"}); hGroup:AddChild(ctd)
    local tb = AceGUI:Create("Button"); tb:SetText("Copiar Talentos"); tb:SetWidth(140); hGroup:AddChild(tb)

    -- El PaperDoll (como grupo MANUAL para posicionar nativos)
    local dollArea = AceGUI:Create("SimpleGroup")
    dollArea:SetFullWidth(true); dollArea:SetHeight(400); dollArea:SetLayout("Manual"); frame:AddChild(dollArea)

    local dollFrame = CreateFrame("Frame", nil, dollArea.content)
    dollFrame:SetAllPoints(dollArea.content)
    
    local bg = dollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(280, 360); bg:SetPoint("CENTER"); bg:SetTexture("Interface\\PaperdollInfoFrame\\UI-Character-CharacterStats-Background"); bg:SetAlpha(0.2)

    slotButtons = {}
    for _, cfg in ipairs(SLOT_CONFIG) do table.insert(slotButtons, CreateItemSlot(dollFrame, cfg)) end

    local summary = AceGUI:Create("Label"); summary:SetFullWidth(true); summary:SetFontObject(GameFontNormalSmall); frame:AddChild(summary)

    local function update()
        local c, s, ctx = cd:GetValue(), sd:GetValue(), ctd:GetValue()
        BuildViewer_UI.c, BuildViewer_UI.s, BuildViewer_UI.ctx = c, s, ctx
        if not c or not s or not ctx or not BuildViewerData then return end
        local data = BuildViewerData[c] and BuildViewerData[c][s]
        if not data then return end
        for _, b in ipairs(slotButtons) do UpdateSlotButton(b, c, s, ctx) end
        summary:SetText(string.format("\n%sStats: %s|r\n%s", COLOR_HEADER, table.concat(data.stats or {}, " > "), data.summary or ""))
        local b = data.builds[ctx]; tb:SetDisabled(not (b and b.talents and b.talents ~= "")); tb.t = b and b.talents
        BuildViewer:SaveLastSelection(c, s, ctx)
    end

    cd:SetCallback("OnValueChanged", function(_, _, v)
        local list = {}; if BuildViewerData[v] then for k in pairs(BuildViewerData[v]) do list[k] = k end end
        sd:SetList(list); sd:SetValue(nil); update()
    end)
    sd:SetCallback("OnValueChanged", update); ctd:SetCallback("OnValueChanged", update)
    tb:SetCallback("OnClick", function(self) if self.t and C_Clipboard then C_Clipboard.SetText(self.t); BuildViewer:Print("Talento copiado.") end end)

    if BuildViewerData then
        local list = {}; for k in pairs(BuildViewerData) do list[k] = k end
        cd:SetList(list)
    end

    return frame, cd, sd, ctd, update
end

function BuildViewer_UI:OpenWindow(cls, spec)
    if not BuildViewerData then print("|cffff0000BuildViewer: Error cargando Builds.lua|r"); return end
    if mainFrame then if cls then BuildViewer_UI:SetSelection(cls, spec) end; mainFrame:Show(); return end
    local f, cd, sd, ctd, u = createWindow()
    mainFrame, BuildViewer_UI.cd, BuildViewer_UI.sd, BuildViewer_UI.u = f, cd, sd, u
    local lc, ls, lctx = BuildViewer:GetLastSelection()
    local c, s = cls or lc, spec or ls
    if c and BuildViewerData[c] then
        cd:SetValue(c); local l = {}; for k in pairs(BuildViewerData[c]) do l[k] = k end; sd:SetList(l)
        if s and BuildViewerData[c][s] then sd:SetValue(s) end
    end
    ctd:SetValue(lctx or "Overall"); u()
end

function BuildViewer_UI:SetSelection(c, s)
    if not mainFrame then return end
    self.cd:SetValue(c); local l = {}; if BuildViewerData[c] then for k in pairs(BuildViewerData[c]) do l[k] = k end end
    self.sd:SetList(l); self.sd:SetValue(s); self.u()
end
function BuildViewer_UI:IsWindowOpen() return mainFrame ~= nil and mainFrame:IsShown() end
function BuildViewer_UI:CloseWindow() if mainFrame then AceGUI:Release(mainFrame); mainFrame = nil end end

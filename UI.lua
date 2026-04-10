-- BuildViewer - UI.lua
-- Native WoW 12.0 (Midnight) Compatible Interface v5.2
-- 100% Native API (No Ace3 visuals)

BuildViewer_UI = {}
local mainFrame = nil
local slotButtons = {}
local alternativeIndices = {}

-- UI State
BuildViewer_UI.c = nil   
BuildViewer_UI.s = nil   
BuildViewer_UI.ctx = "Overall" 

local COLOR_TITLE  = "|cff00ccff"
local COLOR_HEADER = "|cffffcc00"
local COLOR_RESET  = "|r"

local SLOT_CONFIG = {
    { slot = "Head",     x = -170, y = 140 }, { slot = "Hands",    x = 170, y = 140 },
    { slot = "Neck",     x = -170, y = 95  }, { slot = "Waist",    x = 170, y = 95  },
    { slot = "Shoulder", x = -170, y = 50  }, { slot = "Legs",     x = 170, y = 50  },
    { slot = "Back",     x = -170, y = 5   }, { slot = "Feet",     x = 170, y = 5   },
    { slot = "Chest",    x = -170, y = -40 }, { slot = "Finger1",  x = 170, y = -40 },
    { slot = "Wrist",    x = -170, y = -85 }, { slot = "Finger2",  x = 170, y = -85 },
    { slot = "Trinket1", x = 170,  y = -130}, { slot = "Trinket2", x = 170,  y = -175},
    { slot = "MainHand", x = -50,  y = -175}, { slot = "OffHand",  x = 50,   y = -175},
}

-- Update function
local function UpdateSlotButton(btn)
    if not BuildViewerData or not BuildViewer_UI.c or not BuildViewer_UI.s or not BuildViewer_UI.ctx then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
        btn.border:Hide(); btn.hasAlt:Hide(); btn.itemID = nil; return
    end
    local dat = BuildViewerData[BuildViewer_UI.c] and BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s]
    local build = dat and dat.builds and dat.builds[BuildViewer_UI.ctx]
    local items = build and build.gear and build.gear[btn.slotName]
    if not items or #items == 0 then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
        btn.border:Hide(); btn.hasAlt:Hide(); btn.itemID = nil; return
    end
    local idx = alternativeIndices[btn.slotName] or 1
    if idx > #items then idx = 1 end
    local itemData = items[idx]
    btn.itemID = itemData.id
    local n, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemData.id)
    btn.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if quality then
        local r, g, b = GetItemQualityColor(quality)
        btn.border:SetVertexColor(r, g, b, 1); btn.border:Show()
    else
        btn.border:Hide()
    end
    if #items > 1 then btn.hasAlt:Show() else btn.hasAlt:Hide() end
end

-- Refresh UI
local function RefreshUI()
    if not mainFrame then return end
    local c, s, ctx = BuildViewer_UI.c, BuildViewer_UI.s, BuildViewer_UI.ctx
    if not c or not s or not ctx or not BuildViewerData then 
        for _, b in ipairs(slotButtons) do UpdateSlotButton(b) end
        mainFrame.sumText:SetText("Selecciona una Clase/Spec a la izquierda.")
        return 
    end
    local data = BuildViewerData[c] and BuildViewerData[c][s]
    if not data then return end
    for _, b in ipairs(slotButtons) do UpdateSlotButton(b) end
    mainFrame.statsText:SetText(string.format("%sStats: %s%s", COLOR_HEADER, table.concat(data.stats or {}, " > "), COLOR_RESET))
    mainFrame.sumText:SetText(data.summary or "")
    local b = data.builds and data.builds[ctx]
    if b and b.talents and b.talents ~= "" then
        mainFrame.talBtn:Enable(); mainFrame.talBtn.t = b.talents
    else
        mainFrame.talBtn:Disable()
    end
    -- Highlight Sidebar
    if BuildViewer_UI.btns then
        for k, b in pairs(BuildViewer_UI.btns) do
            if k == (c .. s) then b.t:SetTextColor(0, 1, 0) else b.t:SetTextColor(1, 1, 1) end
        end
    end
    if BuildViewer then BuildViewer:SaveLastSelection(c, s, ctx) end
end

-- Init UI
local function InitWindow()
    if mainFrame then return end
    mainFrame = CreateFrame("Frame", "BV_Window", UIParent, "BackdropTemplate")
    mainFrame:SetSize(850, 650); mainFrame:SetPoint("CENTER"); mainFrame:SetMovable(true); mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton"); mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); local _,_,_,x,y = s:GetPoint(); if BuildViewer then BuildViewer:SaveWindowPosition(x,y) end end)
    
    mainFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    mainFrame:SetBackdropColor(0, 0, 0, 0.95); mainFrame:SetFrameStrata("HIGH")

    local t = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    t:SetPoint("TOP", 0, -15); t:SetText(COLOR_TITLE .. "BuildViewer v5.2" .. COLOR_RESET)

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5); close:SetScript("OnClick", function() mainFrame:Hide() end)

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetSize(220, 560); sidebar:SetPoint("TOPLEFT", 15, -60); sidebar:SetPoint("BOTTOMLEFT", 15, 15)
    sidebar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    sidebar:SetBackdropColor(0, 0, 0, 0.6)

    local sf = CreateFrame("ScrollFrame", "BV_SidebarScroll", sidebar, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -8); sf:SetPoint("BOTTOMRIGHT", -25, 8)
    local cont = CreateFrame("Frame", nil, sf)
    cont:SetSize(180, 1000); sf:SetScrollChild(cont)

    BuildViewer_UI.btns = {}
    local y = -5
    local sorted = {}
    if BuildViewerData then for c in pairs(BuildViewerData) do table.insert(sorted, c) end end
    table.sort(sorted)

    for _, c in ipairs(sorted) do
        local h = cont:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 5, y); h:SetText("|cffffcc00" .. c .. "|r"); y = y - 22
        local specs = {}
        for s in pairs(BuildViewerData[c]) do table.insert(specs, s) end
        table.sort(specs)
        for _, s in ipairs(specs) do
            local b = CreateFrame("Button", nil, cont)
            b:SetSize(160, 22); b:SetPoint("TOPLEFT", 15, y)
            local bt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            bt:SetPoint("LEFT", 5, 0); bt:SetText(s); b.t = bt
            b:SetScript("OnClick", function() BuildViewer_UI.c=c; BuildViewer_UI.s=s; RefreshUI() end)
            BuildViewer_UI.btns[c .. s] = b; y = y - 24
        end
        y = y - 10
    end
    cont:SetHeight(math.abs(y) + 20)

    -- Modes
    local modes = {"Overall", "Raid", "Mythic+"}
    local labels = {Overall="General", Raid="Banda", ["Mythic+"]="Míticas+"}
    mainFrame.modeBtns = {}
    for i, m in ipairs(modes) do
        local b = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        b:SetSize(90, 26); b:SetPoint("TOPLEFT", 250 + (i-1)*95, -60); b:SetText(labels[m])
        b:SetScript("OnClick", function() BuildViewer_UI.ctx = m; RefreshUI() end); mainFrame.modeBtns[m] = b
    end

    -- Copy Talents
    local tb = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    tb:SetSize(140, 26); tb:SetPoint("TOPRIGHT", -25, -60); tb:SetText("Copiar Talentos")
    tb:SetScript("OnClick", function(s) if s.t and C_Clipboard then C_Clipboard.SetText(s.t); print("Talentos copiados.") end end); mainFrame.talBtn = tb

    -- Items
    local dollArea = CreateFrame("Frame", nil, mainFrame)
    dollArea:SetSize(580, 520); dollArea:SetPoint("TOPLEFT", 245, -100); dollArea:SetPoint("BOTTOMRIGHT", -20, 20)
    local dollBG = dollArea:CreateTexture(nil, "BACKGROUND")
    dollBG:SetSize(320, 420); dollBG:SetPoint("CENTER", 0, 30); dollBG:SetTexture("Interface\\PaperdollInfoFrame\\UI-Character-CharacterStats-Background"); dollBG:SetAlpha(0.2)
    
    slotButtons = {}
    for _, cfg in ipairs(SLOT_CONFIG) do
        local b = CreateFrame("Button", nil, dollArea)
        b:SetSize(42, 42); b:SetPoint("CENTER", dollArea, "CENTER", cfg.x, cfg.y); b.slotName = cfg.slot
        local icon = b:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); b.icon = icon
        local bor = b:CreateTexture(nil, "OVERLAY"); bor:SetSize(60, 60); bor:SetPoint("CENTER"); bor:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.border = bor
        local alt = b:CreateTexture(nil, "OVERLAY"); alt:SetSize(14, 14); alt:SetPoint("TOPRIGHT", -1, -1); alt:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up"); b.hasAlt = alt
        b:SetScript("OnEnter", function(s) if s.itemID then GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(s.itemID); GameTooltip:Show() end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(s)
            local dat = BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s]
            local items = dat and dat.builds[BuildViewer_UI.ctx].gear[s.slotName]
            if items and #items > 1 then
                alternativeIndices[s.slotName] = ((alternativeIndices[s.slotName] or 1) % #items) + 1; UpdateSlotButton(s)
            end
        end)
        table.insert(slotButtons, b)
    end

    mainFrame.statsText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal"); mainFrame.statsText:SetPoint("BOTTOMLEFT", 260, 60)
    mainFrame.sumText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); mainFrame.sumText:SetPoint("BOTTOMLEFT", 260, 30); mainFrame.sumText:SetWidth(550)
end

function BuildViewer_UI:OpenWindow(cls, spec)
    InitWindow()
    mainFrame:Show()
    if BuildViewer then
        local lc, ls, lctx = BuildViewer:GetLastSelection()
        BuildViewer_UI.c = cls or lc or BuildViewer_UI.c
        BuildViewer_UI.s = spec or ls or BuildViewer_UI.s
        BuildViewer_UI.ctx = lctx or "Overall"
    end
    RefreshUI()
end

function BuildViewer_UI:CloseWindow() if mainFrame then mainFrame:Hide() end end
function BuildViewer_UI:IsWindowOpen() return mainFrame and mainFrame:IsShown() end

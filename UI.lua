-- BuildViewer - UI.lua
-- Native WoW 12.0 (Midnight) Compatible Interface v7.5
-- Final "Midnight" Fix - Robust Matching & Perfect Layout

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

-- Symmetrical Coordinates (Centered inside the Right Panel)
local SLOT_CONFIG = {
    -- Left Column (x = -150)
    { slot = "Head",     x = -155, y = 170 },
    { slot = "Neck",     x = -155, y = 125 },
    { slot = "Shoulder", x = -155, y = 80  },
    { slot = "Back",     x = -155, y = 35  },
    { slot = "Chest",    x = -155, y = -10 },
    { slot = "Wrist",    x = -155, y = -55 },
    -- Right Column (x = 155)
    { slot = "Hands",    x = 155, y = 170  },
    { slot = "Waist",    x = 155, y = 125  },
    { slot = "Legs",     x = 155, y = 80   },
    { slot = "Feet",     x = 155, y = 35   },
    { slot = "Finger1",  x = 155, y = -10  },
    { slot = "Finger2",  x = 155, y = -55  },
    { slot = "Trinket1", x = 155, y = -100 },
    { slot = "Trinket2", x = 155, y = -145 },
    -- Bottom Row (Weapon Space)
    { slot = "MainHand", x = -55, y = -190 },
    { slot = "OffHand",  x = 55,  y = -190 },
}

-- Intelligent Item Link System (Cross-ID & Name fallback)
local function RequestItemInfo(btn, itemID, itemName)
    if not itemID then return end
    
    local i = Item:CreateFromItemID(itemID)
    i:ContinueOnItemDataReady(function()
        local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)
        
        -- Si el ID falla (típico de Midnight Custom), buscamos por NOMBRE
        if not texture and itemName then
            local newName, _, newQuality, _, _, _, _, _, _, newTexture = GetItemInfo(itemName)
            if newTexture then
                texture, quality = newTexture, newQuality
                -- Buscamos el ID real que tiene el cliente para este objeto
                local _, link = GetItemInfo(itemName)
                if link then
                    local foundID = tonumber(link:match("item:(%d+)"))
                    if foundID then btn.itemID = foundID end
                end
            end
        end
        
        if texture then
            btn.icon:SetTexture(texture)
            if quality then
                local r, g, b = GetItemQualityColor(quality)
                btn.border:SetVertexColor(r, g, b, 1); btn.border:Show()
            else btn.border:Hide() end
        else
            btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            btn.border:Hide()
        end
    end)
end

local function UpdateSlotButton(btn)
    if not BuildViewerData or not BuildViewer_UI.c or not BuildViewer_UI.s or not BuildViewer_UI.ctx then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot"); btn.border:Hide(); btn.hasAlt:Hide(); return
    end
    
    local spec = BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s]
    local build = spec.builds[BuildViewer_UI.ctx]
    local items = build.gear and build.gear[btn.slotName]
    
    if not items or #items == 0 then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot"); btn.border:Hide(); btn.hasAlt:Hide(); return
    end

    local idx = alternativeIndices[btn.slotName] or 1
    if idx > #items then idx = 1 end
    local itm = items[idx]
    
    btn.itemID = itm.id
    btn.itemName = itm.name
    
    RequestItemInfo(btn, itm.id, itm.name)
    if #items > 1 then btn.hasAlt:Show() else btn.hasAlt:Hide() end
end

local function RefreshUI()
    if not mainFrame then return end
    local c, s, ctx = BuildViewer_UI.c, BuildViewer_UI.s, BuildViewer_UI.ctx
    
    if not c or not s or not ctx or not BuildViewerData then 
        for _, b in ipairs(slotButtons) do UpdateSlotButton(b) end
        mainFrame.sumText:SetText("Selecciona Clase y Spec."); mainFrame.statsText:SetText(""); return 
    end
    
    local data = BuildViewerData[c] and BuildViewerData[c][s]
    if not data then return end
    
    for _, b in ipairs(slotButtons) do UpdateSlotButton(b) end
    
    mainFrame.statsText:SetText(string.format("%sStats: %s%s", COLOR_HEADER, table.concat(data.stats or {}, " > "), COLOR_RESET))
    mainFrame.sumText:SetText(data.summary or "")
    
    local b = data.builds and data.builds[ctx]
    if b and b.talents and b.talents ~= "" then
        mainFrame.talBtn:Enable(); mainFrame.talBtn.t = b.talents
    else mainFrame.talBtn:Disable() end
    
    if BuildViewer_UI.sbBtns then
        for k, btn in pairs(BuildViewer_UI.sbBtns) do
            if k == (c .. s) then btn.t:SetTextColor(0, 1, 0); btn.bg:SetAlpha(0.3) else btn.t:SetTextColor(1, 1, 1); btn.bg:SetAlpha(0) end
        end
    end
    mainFrame.titleText:SetText(string.format("%s %s - %s", c, s, ctx))
    if BuildViewer then BuildViewer:SaveLastSelection(c, s, ctx) end
end

local function InitWindow()
    if mainFrame then return end
    
    mainFrame = CreateFrame("Frame", "BV_Window", UIParent, "BackdropTemplate")
    mainFrame:SetSize(880, 620); mainFrame:SetPoint("CENTER"); mainFrame:SetMovable(true); mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton"); mainFrame:SetScript("OnDragStart", mainFrame.StartMoving); mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    
    mainFrame:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    mainFrame:SetBackdropColor(0, 0, 0, 0.95); mainFrame:SetFrameStrata("HIGH")

    local header = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 4, -4); header:SetPoint("TOPRIGHT", -4, -4); header:SetHeight(40)
    header:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" }); header:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

    mainFrame.titleText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); mainFrame.titleText:SetPoint("CENTER", 0, 0)
    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton"); close:SetPoint("RIGHT", -5, 0); close:SetScript("OnClick", function() mainFrame:Hide() end)

    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetSize(190, 568); sidebar:SetPoint("TOPLEFT", 4, -44); sidebar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" }); sidebar:SetBackdropColor(0, 0, 0, 0.8)

    local sf = CreateFrame("ScrollFrame", "BV_SBScroll", sidebar, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -8); sf:SetPoint("BOTTOMRIGHT", -25, 8)
    local cont = CreateFrame("Frame", nil, sf); cont:SetSize(160, 1000); sf:SetScrollChild(cont)

    BuildViewer_UI.sbBtns = {}
    local y = -5
    local sorted = {}
    if BuildViewerData then for c in pairs(BuildViewerData) do table.insert(sorted, c) end end
    table.sort(sorted)

    for _, c_val in ipairs(sorted) do
        local h = cont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); h:SetPoint("TOPLEFT", 5, y); h:SetText(c_val); y = y - 18
        local specs = {}
        for s_val in pairs(BuildViewerData[c_val]) do table.insert(specs, s_val) end
        table.sort(specs)
        for _, s_val in ipairs(specs) do
            local current_c, current_s = c_val, s_val
            local b = CreateFrame("Button", nil, cont); b:SetSize(150, 18); b:SetPoint("TOPLEFT", 10, y)
            local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.1); bg:SetAlpha(0); b.bg = bg
            local bt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bt:SetPoint("LEFT", 5, 0); bt:SetText(current_s); b.t = bt
            b:SetScript("OnClick", function() BuildViewer_UI.c=current_c; BuildViewer_UI.s=current_s; RefreshUI(); PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end)
            BuildViewer_UI.sbBtns[current_c .. current_s] = b; y = y - 18
        end
        y = y - 10
    end
    cont:SetHeight(math.abs(y) + 20)

    local centerArea = CreateFrame("Frame", nil, mainFrame)
    centerArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0); centerArea:SetPoint("BOTTOMRIGHT", -4, 4)

    local model = CreateFrame("PlayerModel", nil, centerArea)
    model:SetSize(450, 550); model:SetPoint("CENTER", 0, 15); model:SetUnit("player"); model:SetRotation(0); mainFrame.model = model

    local modes = {"Overall", "Raid", "Mythic+"}; local l = {Overall="General", Raid="Banda", ["Mythic+"]="Míticas+"}
    mainFrame.modeBtns = {}
    for i, m in ipairs(modes) do
        local b = CreateFrame("Button", nil, centerArea, "UIPanelButtonTemplate")
        b:SetSize(95, 26); b:SetPoint("TOPLEFT", 50 + (i-1)*100, -10); b:SetText(l[m])
        b:SetScript("OnClick", function() BuildViewer_UI.ctx = m; RefreshUI() end); mainFrame.modeBtns[m] = b
    end

    local talBtn = CreateFrame("Button", nil, centerArea, "UIPanelButtonTemplate")
    talBtn:SetSize(140, 26); talBtn:SetPoint("TOPRIGHT", -50, -10); talBtn:SetText("Copiar Talentos")
    talBtn:SetScript("OnClick", function(btn) if btn.t and C_Clipboard then C_Clipboard.SetText(btn.t); print("Talentos copiados.") end end); mainFrame.talBtn = talBtn

    slotButtons = {}
    for _, cfg in ipairs(SLOT_CONFIG) do
        local b = CreateFrame("Button", nil, centerArea)
        b:SetSize(46, 46); b:SetPoint("CENTER", centerArea, "CENTER", cfg.x, cfg.y); b.slotName = cfg.slot
        local icon = b:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); b.icon = icon
        local bor = b:CreateTexture(nil, "OVERLAY"); bor:SetSize(66, 66); bor:SetPoint("CENTER"); bor:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.border = bor
        local alt = b:CreateTexture(nil, "OVERLAY"); alt:SetSize(14, 14); alt:SetPoint("TOPRIGHT", -1, -1); alt:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up"); b.hasAlt = alt
        b:SetScript("OnEnter", function(obj) if obj.itemID then GameTooltip:SetOwner(obj, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(obj.itemID); GameTooltip:Show() end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(obj)
            if not BuildViewer_UI.c then return end
            local items = BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s].builds[BuildViewer_UI.ctx].gear[obj.slotName]
            if items and #items > 1 then alternativeIndices[obj.slotName] = ((alternativeIndices[obj.slotName] or 1) % #items) + 1; UpdateSlotButton(obj) end
        end)
        table.insert(slotButtons, b)
    end

    mainFrame.statsText = centerArea:CreateFontString(nil, "OVERLAY", "GameFontNormal"); mainFrame.statsText:SetPoint("BOTTOMRIGHT", -40, 70)
    mainFrame.sumText = centerArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); mainFrame.sumText:SetPoint("BOTTOM", 0, 30); mainFrame.sumText:SetWidth(450)
end

function BuildViewer_UI:OpenWindow(cls, spec)
    InitWindow()
    mainFrame:Show()
    mainFrame.model:SetUnit("player")
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

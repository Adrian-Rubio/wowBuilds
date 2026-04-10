-- BuildViewer - UI.lua
-- Native WoW 12.0 (Midnight) Compatible Interface v7.0
-- "The Perfect PaperDoll" - Centered character, fixed async items & cross-ID matching

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

-- Revised Symmetrical Coordinates (Centered on the WHOLE window)
-- Character at 0, 0
local SLOT_CONFIG = {
    -- Left Column (x = -130)
    { slot = "Head",     x = -130, y = 160 },
    { slot = "Neck",     x = -130, y = 115 },
    { slot = "Shoulder", x = -130, y = 70  },
    { slot = "Back",     x = -130, y = 25  },
    { slot = "Chest",    x = -130, y = -20 },
    { slot = "Wrist",    x = -130, y = -65 },
    -- Right Column (x = 130)
    { slot = "Hands",    x = 130, y = 160  },
    { slot = "Waist",    x = 130, y = 115  },
    { slot = "Legs",     x = 130, y = 70   },
    { slot = "Feet",     x = 130, y = 25   },
    { slot = "Finger1",  x = 130, y = -20  },
    { slot = "Finger2",  x = 130, y = -65  },
    { slot = "Trinket1", x = 130, y = -110 },
    { slot = "Trinket2", x = 130, y = -155 },
    -- Bottom Row
    { slot = "MainHand", x = -45, y = -190 },
    { slot = "OffHand",  x = 45,  y = -190 },
}

-- Intelligent Item Updater
local function SetItemToButton(btn, itemID, itemName)
    if not itemID then return end
    
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemDataReady(function()
        local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)
        
        -- fallback to Name if ID info is missing
        if not texture and itemName then
            _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemName)
        end
        
        if texture then
            btn.icon:SetTexture(texture)
            if quality then
                local r, g, b = GetItemQualityColor(quality)
                btn.border:SetVertexColor(r, g, b, 1); btn.border:Show()
            end
        else
            btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            btn.border:Hide()
        end
    end)
end

-- Update function
local function UpdateSlotButton(btn)
    if not BuildViewerData or not BuildViewer_UI.c or not BuildViewer_UI.s or not BuildViewer_UI.ctx then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
        btn.border:Hide(); btn.hasAlt:Hide(); btn.itemID = nil; return
    end
    
    local spec = BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s]
    local build = spec.builds[BuildViewer_UI.ctx]
    local items = build.gear and build.gear[btn.slotName]
    
    if not items or #items == 0 then
        btn.icon:SetTexture("Interface\\Paperdoll\\UI-Backpack-EmptySlot")
        btn.border:Hide(); btn.hasAlt:Hide(); btn.itemID = nil; return
    end

    local idx = alternativeIndices[btn.slotName] or 1
    if idx > #items then idx = 1 end
    local itemData = items[idx]
    btn.itemID = itemData.id
    btn.itemName = itemData.name
    
    SetItemToButton(btn, itemData.id, itemData.name)
    if #items > 1 then btn.hasAlt:Show() else btn.hasAlt:Hide() end
end

-- Refresh UI
local function RefreshUI()
    if not mainFrame then return end
    local c, s, ctx = BuildViewer_UI.c, BuildViewer_UI.s, BuildViewer_UI.ctx
    
    if not c or not s or not ctx or not BuildViewerData then 
        for _, b in ipairs(slotButtons) do UpdateSlotButton(b) end
        mainFrame.sumText:SetText("Selecciona Clase y Especialización.")
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
    
    -- Sidebar Selection
    if BuildViewer_UI.sidebarButtons then
        for key, btn in pairs(BuildViewer_UI.sidebarButtons) do
            if key == (c .. s) then 
                btn.t:SetTextColor(0, 1, 0); btn.bg:SetAlpha(0.3)
            else 
                btn.t:SetTextColor(1, 1, 1); btn.bg:SetAlpha(0)
            end
        end
    end

    mainFrame.titleText:SetText(string.format("%s %s - %s", c, s, ctx))
end

-- Init UI
local function InitWindow()
    if mainFrame then return end
    
    -- BASE WINDOW
    mainFrame = CreateFrame("Frame", "BV_Window", UIParent, "BackdropTemplate")
    mainFrame:SetSize(850, 600)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    
    mainFrame:SetBackdrop({ 
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground", 
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", 
        tile = true, tileSize = 32, edgeSize = 16, 
        insets = { left = 4, right = 4, top = 4, bottom = 4 } 
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.95)
    mainFrame:SetFrameStrata("HIGH")

    -- HEADER
    local header = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 4, -4); header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(40)
    header:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("CENTER", 0, 0)
    mainFrame.titleText = title

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -5, 0); close:SetScript("OnClick", function() mainFrame:Hide() end)

    -- SIDEBAR (Slim and clean)
    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetSize(180, 552)
    sidebar:SetPoint("TOPLEFT", 4, -44)
    sidebar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    sidebar:SetBackdropColor(0, 0, 0, 0.7)

    local sf = CreateFrame("ScrollFrame", "BV_SidebarScroll", sidebar, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 5, -5); sf:SetPoint("BOTTOMRIGHT", -25, 5)
    local cont = CreateFrame("Frame", nil, sf)
    cont:SetSize(150, 1000); sf:SetScrollChild(cont)

    BuildViewer_UI.sidebarButtons = {}
    local y = -5
    local sorted = {}
    if BuildViewerData then for c in pairs(BuildViewerData) do table.insert(sorted, c) end end
    table.sort(sorted)

    for _, c in ipairs(sorted) do
        local h = cont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", 5, y); h:SetText(c); y = y - 18
        local specs = {}
        for s in pairs(BuildViewerData[c]) do table.insert(specs, s) end
        table.sort(specs)
        for _, s in ipairs(specs) do
            local b = CreateFrame("Button", nil, cont)
            b:SetSize(140, 18); b:SetPoint("TOPLEFT", 10, y)
            local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.1); bg:SetAlpha(0); b.bg = bg
            local bt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bt:SetPoint("LEFT", 5, 0); bt:SetText(s); b.t = bt
            b:SetScript("OnClick", function() BuildViewer_UI.c=c; BuildViewer_UI.s=s; RefreshUI(); PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end)
            BuildViewer_UI.sidebarButtons[c .. s] = b; y = y - 18
        end
        y = y - 8
    end
    cont:SetHeight(math.abs(y) + 20)

    -- CENTRAL CONTENT AREA
    local centerArea = CreateFrame("Frame", nil, mainFrame)
    centerArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    centerArea:SetPoint("BOTTOMRIGHT", -4, 4)

    -- The Model (Perfectly Centered in centerArea)
    local model = CreateFrame("PlayerModel", nil, centerArea)
    model:SetSize(400, 500)
    model:SetPoint("CENTER", 0, 20)
    model:SetUnit("player")
    model:SetRotation(0)
    mainFrame.model = model

    -- Mode Buttons
    local modes = {"Overall", "Raid", "Mythic+"}
    local labels = {Overall="General", Raid="Banda", ["Mythic+"]="Míticas+"}
    mainFrame.modeBtns = {}
    for i, m in ipairs(modes) do
        local b = CreateFrame("Button", nil, centerArea, "UIPanelButtonTemplate")
        b:SetSize(90, 26); b:SetPoint("TOPLEFT", 40 + (i-1)*95, -10); b:SetText(labels[m])
        b:SetScript("OnClick", function() BuildViewer_UI.ctx = m; RefreshUI() end)
        mainFrame.modeBtns[m] = b
    end

    -- Talent Button
    local talBtn = CreateFrame("Button", nil, centerArea, "UIPanelButtonTemplate")
    talBtn:SetSize(130, 26); talBtn:SetPoint("TOPRIGHT", -40, -10); talBtn:SetText("Copiar Talentos")
    talBtn:SetScript("OnClick", function(btn) if btn.t and C_Clipboard then C_Clipboard.SetText(btn.t); print("Talentos copiados.") end end)
    mainFrame.talBtn = talBtn

    -- Slot Buttons (Relative to centerArea:CENTER)
    slotButtons = {}
    for _, cfg in ipairs(SLOT_CONFIG) do
        local b = CreateFrame("Button", nil, centerArea)
        b:SetSize(44, 44); b:SetPoint("CENTER", centerArea, "CENTER", cfg.x, cfg.y); b.slotName = cfg.slot
        local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-White"); bg:SetAlpha(0.2)
        local icon = b:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); b.icon = icon
        local bor = b:CreateTexture(nil, "OVERLAY"); bor:SetSize(62, 62); bor:SetPoint("CENTER"); bor:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.border = bor
        local alt = b:CreateTexture(nil, "OVERLAY"); alt:SetSize(14, 14); alt:SetPoint("TOPRIGHT", -1, -1); alt:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up"); b.hasAlt = alt
        b:SetScript("OnEnter", function(obj) if obj.itemID then GameTooltip:SetOwner(obj, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(obj.itemID); GameTooltip:Show() end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(obj)
            if not BuildViewer_UI.c then return end
            local dat = BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s]
            local items = dat.builds[BuildViewer_UI.ctx].gear[obj.slotName]
            if items and #items > 1 then
                alternativeIndices[obj.slotName] = ((alternativeIndices[obj.slotName] or 1) % #items) + 1; UpdateSlotButton(obj)
            end
        end)
        table.insert(slotButtons, b)
    end

    local stats = centerArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stats:SetPoint("BOTTOMRIGHT", -30, 60); stats:SetJustifyH("RIGHT")
    mainFrame.statsText = stats

    local sum = centerArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sum:SetPoint("BOTTOM", 0, 30); sum:SetWidth(400); sum:SetJustifyH("CENTER")
    mainFrame.sumText = sum
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

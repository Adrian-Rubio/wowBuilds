-- BuildViewer - UI.lua
-- Native WoW 12.0 (Midnight) Compatible Interface v6.0
-- "The PaperDoll Experience" - Clean Character Sheet Layout

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

-- Official PaperDoll Layout Coords (Relative to center of right panel)
local SLOT_CONFIG = {
    -- Left Column
    { slot = "Head",     x = -115, y = 160 },
    { slot = "Neck",     x = -115, y = 115 },
    { slot = "Shoulder", x = -115, y = 70  },
    { slot = "Back",     x = -115, y = 25  },
    { slot = "Chest",    x = -115, y = -20 },
    { slot = "Wrist",    x = -115, y = -65 },
    -- Right Column
    { slot = "Hands",    x = 115, y = 160 },
    { slot = "Waist",    x = 115, y = 115 },
    { slot = "Legs",     x = 115, y = 70  },
    { slot = "Feet",     x = 115, y = 25  },
    { slot = "Finger1",  x = 115, y = -20 },
    { slot = "Finger2",  x = 115, y = -65 },
    { slot = "Trinket1", x = 115, y = -110},
    { slot = "Trinket2", x = 115, y = -155},
    -- Bottom
    { slot = "MainHand", x = -40, y = -190 },
    { slot = "OffHand",  x = 40,  y = -190 },
}

-- Async Item Info Handler
local itemInfoReceivedFrame = CreateFrame("Frame")
itemInfoReceivedFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoReceivedFrame:SetScript("OnEvent", function()
    if BuildViewer_UI:IsWindowOpen() then
        for _, b in ipairs(slotButtons) do
            if b.itemID and (not b.icon:GetTexture() or b.icon:GetTexture() == 134400) then -- Question mark
                local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(b.itemID)
                if texture then
                    b.icon:SetTexture(texture)
                    if quality then
                        local r, g, b_col = GetItemQualityColor(quality)
                        b.border:SetVertexColor(r, g, b_col, 1); b.border:Show()
                    end
                end
            end
        end
    end
end)

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
    
    local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemData.id)
    btn.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if quality then
        local r, g, b_col = GetItemQualityColor(quality)
        btn.border:SetVertexColor(r, g, b_col, 1); btn.border:Show()
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
        mainFrame.statsText:SetText("")
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
        for k, btn in pairs(BuildViewer_UI.btns) do
            if k == (c .. s) then 
                btn.t:SetTextColor(0, 1, 0)
                btn.bg:SetAlpha(0.2)
            else 
                btn.t:SetTextColor(1, 1, 1)
                btn.bg:SetAlpha(0)
            end
        end
    end

    -- Update Window Title
    mainFrame.title:SetText(string.format("%s - %s (%s)", c, s, ctx))

    if BuildViewer then BuildViewer:SaveLastSelection(c, s, ctx) end
end

-- Init UI
local function InitWindow()
    if mainFrame then return end
    
    -- MAIN FRAME
    mainFrame = CreateFrame("Frame", "BV_Window", UIParent, "BackdropTemplate")
    mainFrame:SetSize(850, 600)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(sf) 
        sf:StopMovingOrSizing() 
        local _,_,_,x,y = sf:GetPoint()
        if BuildViewer then BuildViewer:SaveWindowPosition(x,y) end 
    end)
    
    mainFrame:SetBackdrop({ 
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground", 
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", 
        tile = true, tileSize = 32, edgeSize = 16, 
        insets = { left = 4, right = 4, top = 4, bottom = 4 } 
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.9)
    mainFrame:SetFrameStrata("HIGH")

    -- HEADER
    local header = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 4, -4); header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(40)
    header:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 15, 0); title:SetText("BuildViewer")
    mainFrame.title = title

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -5, 0); close:SetScript("OnClick", function() mainFrame:Hide() end)

    -- SIDEBAR (Selection Drawer)
    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetSize(200, 552)
    sidebar:SetPoint("TOPLEFT", 4, -44)
    sidebar:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
    sidebar:SetBackdropColor(0.05, 0.05, 0.05, 0.9)

    local sf = CreateFrame("ScrollFrame", "BV_SidebarScroll", sidebar, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 5, -5); sf:SetPoint("BOTTOMRIGHT", -25, 5)
    local cont = CreateFrame("Frame", nil, sf)
    cont:SetSize(170, 1000); sf:SetScrollChild(cont)

    BuildViewer_UI.btns = {}
    local y = -5
    local sorted = {}
    if BuildViewerData then for c in pairs(BuildViewerData) do table.insert(sorted, c) end end
    table.sort(sorted)

    for _, c in ipairs(sorted) do
        local h = cont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", 5, y); h:SetText("|cffffcc00" .. c .. "|r"); y = y - 18
        local specs = {}
        for s in pairs(BuildViewerData[c]) do table.insert(specs, s) end
        table.sort(specs)
        for _, s in ipairs(specs) do
            local b = CreateFrame("Button", nil, cont)
            b:SetSize(155, 18); b:SetPoint("TOPLEFT", 10, y)
            
            local bg = b:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.1); bg:SetAlpha(0); b.bg = bg

            local bt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            bt:SetPoint("LEFT", 5, 0); bt:SetText(s); b.t = bt
            
            b:SetScript("OnEnter", function(obj) obj.bg:SetAlpha(0.2) end)
            b:SetScript("OnLeave", function(obj) if not (BuildViewer_UI.c == c and BuildViewer_UI.s == s) then obj.bg:SetAlpha(0) end end)
            b:SetScript("OnClick", function() BuildViewer_UI.c=c; BuildViewer_UI.s=s; RefreshUI(); PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end)
            
            BuildViewer_UI.btns[c .. s] = b; y = y - 18
        end
        y = y - 8
    end
    cont:SetHeight(math.abs(y) + 20)

    -- RIGHT PANEL (The PaperDoll)
    local paperdoll = CreateFrame("Frame", nil, mainFrame)
    paperdoll:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    paperdoll:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Model View (The character in the middle)
    local model = CreateFrame("PlayerModel", nil, paperdoll)
    model:SetSize(300, 450)
    model:SetPoint("CENTER", 0, 20)
    model:SetUnit("player")
    model:SetPortraitZoom(0)
    model:SetPosition(0, 0, 0)
    model:SetRotation(0)
    mainFrame.model = model

    -- Mode Toggles (Tabs Style at Top)
    local modes = {"Overall", "Raid", "Mythic+"}
    local labels = {Overall="General", Raid="Banda", ["Mythic+"]="Míticas+"}
    mainFrame.modeBtns = {}
    for i, m in ipairs(modes) do
        local b = CreateFrame("Button", nil, paperdoll, "UIPanelButtonTemplate")
        b:SetSize(100, 26); b:SetPoint("TOPLEFT", 40 + (i-1)*105, -10); b:SetText(labels[m])
        b:SetScript("OnClick", function() BuildViewer_UI.ctx = m; RefreshUI(); PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end)
        mainFrame.modeBtns[m] = b
    end

    -- Copy Talents
    local talBtn = CreateFrame("Button", nil, paperdoll, "UIPanelButtonTemplate")
    talBtn:SetSize(130, 26); talBtn:SetPoint("TOPRIGHT", -40, -10); talBtn:SetText("Copiar Talentos")
    talBtn:SetScript("OnClick", function(btn) if btn.t and C_Clipboard then C_Clipboard.SetText(btn.t); print("|cff00ff00BuildViewer: Talentos copiados.|r") end end)
    mainFrame.talBtn = talBtn

    -- Gear Slots
    slotButtons = {}
    for _, cfg in ipairs(SLOT_CONFIG) do
        local b = CreateFrame("Button", nil, paperdoll)
        b:SetSize(44, 44); b:SetPoint("CENTER", paperdoll, "CENTER", cfg.x, cfg.y); b.slotName = cfg.slot
        
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\UI-EmptySlot-White"); bg:SetAlpha(0.15)

        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); b.icon = icon
        
        local bor = b:CreateTexture(nil, "OVERLAY")
        bor:SetSize(62, 62); bor:SetPoint("CENTER"); bor:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.border = bor
        
        local alt = b:CreateTexture(nil, "OVERLAY")
        alt:SetSize(14, 14); alt:SetPoint("TOPRIGHT", -1, -1); alt:SetTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up"); b.hasAlt = alt
        
        b:SetScript("OnEnter", function(obj) if obj.itemID then GameTooltip:SetOwner(obj, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(obj.itemID); GameTooltip:Show() end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(obj)
            if not (BuildViewer_UI.c and BuildViewer_UI.s) then return end
            local dat = BuildViewerData[BuildViewer_UI.c][BuildViewer_UI.s]
            local items = dat and dat.builds[BuildViewer_UI.ctx].gear[obj.slotName]
            if items and #items > 1 then
                alternativeIndices[obj.slotName] = ((alternativeIndices[obj.slotName] or 1) % #items) + 1; UpdateSlotButton(obj)
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            end
        end)
        table.insert(slotButtons, b)
    end

    -- Stats Display (Bottom Right of Character)
    local stats = paperdoll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stats:SetPoint("BOTTOMRIGHT", -40, 60); stats:SetJustifyH("RIGHT")
    mainFrame.statsText = stats

    local sum = paperdoll:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sum:SetPoint("BOTTOMLEFT", 40, 20); sum:SetPoint("BOTTOMRIGHT", -40, 20)
    sum:SetHeight(40); sum:SetJustifyH("CENTER"); sum:SetJustifyV("BOTTOM")
    mainFrame.sumText = sum
end

function BuildViewer_UI:OpenWindow(cls, spec)
    InitWindow()
    mainFrame:Show()
    mainFrame.model:SetUnit("player") -- Refresh model
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

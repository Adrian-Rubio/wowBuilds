-- Rediseño UI para probar el anclaje seguro
local AceGUI = LibStub("AceGUI-3.0")

local frame = AceGUI:Create("Frame")
frame:SetTitle("Test")
frame:SetWidth(800)
frame:SetHeight(600)
frame:SetLayout("Flow")

local cd = AceGUI:Create("Dropdown")
cd:SetList({A="A"})
frame:AddChild(cd)

local spacer = AceGUI:Create("Label")
spacer:SetText(" ")    -- Esto evita que el layout ignore el label
spacer:SetFullWidth(true) -- Ocupa toda la fila
spacer:SetHeight(400)  -- Reserva 400 pixels de alto
frame:AddChild(spacer)

local r = CreateFrame("Frame", nil, spacer.frame)
r:SetAllPoints()

local bg = r:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(1,0,0,0.5) -- Fondo rojo de prueba

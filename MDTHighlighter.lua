-- MDTHighlighter.lua
-- Core de l'addon : namespace, couleurs, SavedVariables, bootstrap.

MDTHighlighter = {}

MDTHighlighter.ADDON_NAME = "MDTHighlighter"
MDTHighlighter.VERSION    = "@project-version@"

-- Couleurs par categorie de highlight
MDTHighlighter.COLORS = {
    CURRENT = { r=1.0, g=0.4, b=0.0, a=0.9 }, -- orange  : pull actuel (tank aggro)
    NEXT    = { r=1.0, g=0.9, b=0.0, a=0.8 }, -- jaune   : prochain pull
    SKIP    = { r=0.4, g=0.4, b=1.0, a=0.5 }, -- bleu    : mob skippe
}

-- SavedVariables
MDTHighlighterDB = MDTHighlighterDB or {}

local function InitDefaults()
    local def = {
        enabled     = true,
        showCurrent = true,
        showNext    = true,
        showSkip    = true,
        borderSize  = 3,
    }
    for k,v in pairs(def) do
        if MDTHighlighterDB[k] == nil then MDTHighlighterDB[k] = v end
    end
end

function MDTHighlighter:OnInitialize()
    InitDefaults()
    MDTHighlighter.db = MDTHighlighterDB
    MDTHighlighter.Config:Initialize()
    MDTHighlighter.MDTBridge:Initialize()
    MDTHighlighter.NameplateManager:Initialize()
    MDTHighlighter:Print("Charge. Tape |cff00ff00/mdth|r pour les options.")
end

function MDTHighlighter:Print(msg)
    print("|cffff9900[MDTHighlighter]|r " .. tostring(msg))
end

-- Bootstrap
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == MDTHighlighter.ADDON_NAME then
        MDTHighlighter:OnInitialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
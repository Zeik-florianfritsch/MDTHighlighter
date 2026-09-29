-- MDTHighlighter.lua
-- Entry point and core of the addon.

---@class MDTHighlighter
MDTHighlighter = {}
MDTHighlighter.__index = MDTHighlighter

MDTHighlighter.ADDON_NAME = "MDTHighlighter"
MDTHighlighter.VERSION     = "@project-version@"

-- Color definitions for the three highlight states
MDTHighlighter.COLORS = {
    CURRENT = { r = 1.0, g = 0.4, b = 0.0, a = 1.0 },  -- orange: aggro maintenant
    NEXT    = { r = 1.0, g = 0.9, b = 0.0, a = 1.0 },  -- jaune: prochain pull
    SKIP    = { r = 0.4, g = 0.4, b = 1.0, a = 0.7 },  -- bleu: skipped
}

-- SavedVariables
MDTHighlighterDB = MDTHighlighterDB or {}

local eventFrame = CreateFrame("Frame")
MDTHighlighter.eventFrame = eventFrame

local function InitDefaults()
    local defaults = {
        enabled          = true,
        showCurrent      = true,
        showNext         = true,
        showSkip         = true,
        glowLines        = 8,
        glowFrequency    = 0.25,
        glowThickness    = 2,
        -- M0 / test : aucune restriction de difficulte par defaut
        restrictToMythicPlus = false,
    }
    for k, v in pairs(defaults) do
        if MDTHighlighterDB[k] == nil then
            MDTHighlighterDB[k] = v
        end
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

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == MDTHighlighter.ADDON_NAME then
        MDTHighlighter:OnInitialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
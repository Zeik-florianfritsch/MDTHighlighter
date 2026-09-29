-- Modules/Config.lua
-- Commandes slash /mdth et /mdthighlighter.
-- Inclut /mdth test pour forcer un rafraichissement (utile en M0 ou hors donjon).

---@class ConfigModule
MDTHighlighter.Config = {}
local Config = MDTHighlighter.Config

local function BoolText(v)
    return v and "|cff00ff00ON|r" or "|cffff0000OFF|r"
end

local function PrintStatus()
    local db  = MDTHighlighter.db
    local br  = MDTHighlighter.MDTBridge
    local currentIdx = br:GetCurrentPullIndex()
    local totalPulls = br:GetTotalPulls()

    -- Detecte la difficulte actuelle pour info
    local diffID   = select(3, GetInstanceInfo())
    local diffName = GetDifficultyInfo(diffID) or "?"

    MDTHighlighter:Print("=== MDTHighlighter " .. MDTHighlighter.VERSION .. " ===")
    MDTHighlighter:Print("Statut          : " .. BoolText(db.enabled))
    MDTHighlighter:Print("Difficulte      : " .. tostring(diffName) .. " (ID " .. tostring(diffID) .. ")")
    MDTHighlighter:Print("MDT pret        : " .. BoolText(br:IsReady()))
    if br:IsReady() then
        MDTHighlighter:Print("Pull actuel     : " .. tostring(currentIdx) .. " / " .. tostring(totalPulls))
        local c = #(function() local t={} for _ in pairs(br.currentPullNPCs) do t[#t+1]=_ end return t end())
        local n = #(function() local t={} for _ in pairs(br.nextPullNPCs) do t[#t+1]=_ end return t end())
        local s = #(function() local t={} for _ in pairs(br.skipNPCs) do t[#t+1]=_ end return t end())
        MDTHighlighter:Print("  NPC courant   : " .. c .. " | Prochain : " .. n .. " | Skips : " .. s)
    end
    MDTHighlighter:Print("Current (orange): " .. BoolText(db.showCurrent))
    MDTHighlighter:Print("Next (jaune)     : " .. BoolText(db.showNext))
    MDTHighlighter:Print("Skip (bleu)      : " .. BoolText(db.showSkip))
    MDTHighlighter:Print("Tip: /mdth test  pour forcer un refresh (M0 / test)")
end

local function HandleSlash(input)
    if not input or input == "" then
        PrintStatus()
        return
    end

    local args = {}
    for arg in input:gmatch("%S+") do
        tinsert(args, arg:lower())
    end

    local cmd = args[1]
    local db  = MDTHighlighter.db

    if cmd == "on" then
        db.enabled = true
        MDTHighlighter:Print("Active.")
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "off" then
        db.enabled = false
        MDTHighlighter:Print("Desactive.")
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "current" then
        if args[2] == "on" then db.showCurrent = true
        elseif args[2] == "off" then db.showCurrent = false end
        MDTHighlighter:Print("Current pull : " .. BoolText(db.showCurrent))
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "next" then
        if args[2] == "on" then db.showNext = true
        elseif args[2] == "off" then db.showNext = false end
        MDTHighlighter:Print("Next pull : " .. BoolText(db.showNext))
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "skip" then
        if args[2] == "on" then db.showSkip = true
        elseif args[2] == "off" then db.showSkip = false end
        MDTHighlighter:Print("Skip : " .. BoolText(db.showSkip))
        MDTHighlighter.NameplateManager:RefreshAll()

    -- /mdth test  → force un rafraichissement immediat sans attendre le ticker
    -- Tres utile en M0 ou quand on vient d importer une route dans MDT
    elseif cmd == "test" or cmd == "force" or cmd == "refresh" then
        if not MDTHighlighter.MDTBridge:IsReady() then
            MDTHighlighter:Print("|cffff0000MDT n est pas pret.|r Verifie que MDT est charge et qu une route est importee.")
            MDTHighlighter:Print("Tip: Dans MDT, importe une route via /mdt puis clique sur un pull.")
            return
        end
        MDTHighlighter.MDTBridge:ForceRefresh()
        MDTHighlighter.NameplateManager:RefreshAll()
        local idx   = MDTHighlighter.MDTBridge:GetCurrentPullIndex()
        local total = MDTHighlighter.MDTBridge:GetTotalPulls()
        MDTHighlighter:Print("Refresh force ! Pull " .. tostring(idx) .. "/" .. tostring(total))

    -- /mdth color current|next|skip R G B
    elseif cmd == "color" then
        local target = args[2]
        local r = tonumber(args[3])
        local g = tonumber(args[4])
        local b = tonumber(args[5])
        if not (target and r and g and b) then
            MDTHighlighter:Print("Usage: /mdth color current|next|skip <R> <G> <B>  (valeurs 0-1)")
            return
        end
        local key = target:upper()
        if not MDTHighlighter.COLORS[key] then
            MDTHighlighter:Print("Categorie inconnue. Utilise: current, next, skip")
            return
        end
        r = math.max(0, math.min(1, r))
        g = math.max(0, math.min(1, g))
        b = math.max(0, math.min(1, b))
        MDTHighlighter.COLORS[key].r = r
        MDTHighlighter.COLORS[key].g = g
        MDTHighlighter.COLORS[key].b = b
        db["color_" .. key] = { r=r, g=g, b=b }
        MDTHighlighter:Print(string.format("Couleur %s : (%.2f, %.2f, %.2f)", key, r, g, b))
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "reset" then
        MDTHighlighterDB = nil
        MDTHighlighter:Print("Parametres reinitialises au prochain /reload.")

    else
        MDTHighlighter:Print("Commandes disponibles:")
        MDTHighlighter:Print("  /mdth                    - statut")
        MDTHighlighter:Print("  /mdth on|off             - activer/desactiver")
        MDTHighlighter:Print("  /mdth current|next|skip on|off")
        MDTHighlighter:Print("  /mdth test               - forcer refresh (M0/test)")
        MDTHighlighter:Print("  /mdth color current|next|skip R G B")
        MDTHighlighter:Print("  /mdth reset              - reinitialiser")
    end
end

function Config:Initialize()
    SLASH_MDTHIGHLIGHTER1 = "/mdth"
    SLASH_MDTHIGHLIGHTER2 = "/mdthighlighter"
    SlashCmdList["MDTHIGHLIGHTER"] = HandleSlash

    -- Restaure les couleurs personnalisees depuis les SavedVariables
    local db = MDTHighlighter.db
    for _, key in ipairs({ "CURRENT", "NEXT", "SKIP" }) do
        local saved = db["color_" .. key]
        if saved then
            MDTHighlighter.COLORS[key].r = saved.r
            MDTHighlighter.COLORS[key].g = saved.g
            MDTHighlighter.COLORS[key].b = saved.b
        end
    end
end
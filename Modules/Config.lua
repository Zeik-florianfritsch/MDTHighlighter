-- Modules/Config.lua
-- Commandes slash /mdth et /mdthighlighter.

MDTHighlighter.Config = {}
local Config = MDTHighlighter.Config

local function Bool(v) return v and "|cff00ff00ON|r" or "|cffff0000OFF|r" end

local function PrintStatus()
    local db  = MDTHighlighter.db
    local br  = MDTHighlighter.MDTBridge
    local diffID   = select(3, GetInstanceInfo())
    local diffName = GetDifficultyInfo(diffID) or "?"
    MDTHighlighter:Print("=== MDTHighlighter ===")
    MDTHighlighter:Print("Actif           : " .. Bool(db.enabled))
    MDTHighlighter:Print("Difficulte      : " .. tostring(diffName))
    MDTHighlighter:Print("MDT pret        : " .. Bool(br:IsReady()))
    if br:IsReady() then
        local cur   = br:GetCurrentPullIndex() or "?"
        local total = br:GetTotalPulls()
        MDTHighlighter:Print("Pull actuel     : " .. cur .. "/" .. total)
        local c,n,s = 0,0,0
        for _ in pairs(br.currentPullNPCs) do c=c+1 end
        for _ in pairs(br.nextPullNPCs)    do n=n+1 end
        for _ in pairs(br.skipNPCs)        do s=s+1 end
        MDTHighlighter:Print("  NPCs current=" .. c .. "  next=" .. n .. "  skip=" .. s)
    end
    MDTHighlighter:Print("Current (orange): " .. Bool(db.showCurrent))
    MDTHighlighter:Print("Next (jaune)     : " .. Bool(db.showNext))
    MDTHighlighter:Print("Skip (bleu)      : " .. Bool(db.showSkip))
    if not br:IsReady() then
        MDTHighlighter:Print("|cffffff00>> /mdth debug pour diagnostiquer MDT|r")
    end
end

local function HandleSlash(input)
    if not input or input == "" then PrintStatus(); return end
    local args = {}
    for a in input:gmatch("%S+") do tinsert(args, a:lower()) end
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
        if args[2] == "on" then db.showCurrent = true elseif args[2] == "off" then db.showCurrent = false end
        MDTHighlighter:Print("Current : " .. Bool(db.showCurrent))
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "next" then
        if args[2] == "on" then db.showNext = true elseif args[2] == "off" then db.showNext = false end
        MDTHighlighter:Print("Next : " .. Bool(db.showNext))
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "skip" then
        if args[2] == "on" then db.showSkip = true elseif args[2] == "off" then db.showSkip = false end
        MDTHighlighter:Print("Skip : " .. Bool(db.showSkip))
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "test" or cmd == "force" or cmd == "refresh" then
        MDTHighlighter:Print("Refresh force...")
        if not MDTHighlighter.MDTBridge:IsReady() then
            MDTHighlighter:Print("|cffff0000MDT non pret.|r Tape /mdth debug pour diagnostiquer.")
        else
            MDTHighlighter.MDTBridge:ForceRefresh()
            MDTHighlighter.NameplateManager:RefreshAll()
            local idx   = MDTHighlighter.MDTBridge:GetCurrentPullIndex()
            local total = MDTHighlighter.MDTBridge:GetTotalPulls()
            MDTHighlighter:Print("OK. Pull " .. tostring(idx) .. "/" .. tostring(total))
        end

    -- NOUVEAU : diagnostic complet de la structure MDT    elseif cmd == "testglow" then
        -- Force un glow orange sur TOUTES les nameplates pour tester le rendu
        local NM = MDTHighlighter.NameplateManager
        local count = 0
        -- Test direct sur les plates connues
        for unitToken, data in pairs(NM._plates) do
            if data.indicator then
                local color = MDTHighlighter.COLORS["CURRENT"]
                data.indicator:SetBackdropColor(color.r, color.g, color.b, color.a)
                data.indicator:SetBackdropBorderColor(1, 0.5, 0, 1)
                data.indicator:Show()
                count = count + 1
            end
        end
        -- Test direct sur C_NamePlate
        local allPlates = C_NamePlate.GetNamePlates()
        for _, np in ipairs(allPlates) do
            -- Creer un frame test directement sur le nameplate
            local tf = CreateFrame("Frame", nil, np, "BackdropTemplate")
            tf:SetFrameStrata("TOOLTIP")
            tf:SetSize(60, 8)
            tf:SetPoint("TOP", np, "BOTTOM", 0, -3)
            tf:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeSize = 1 })
            tf:SetBackdropColor(1, 0.2, 0, 0.9)
            tf:SetBackdropBorderColor(1, 1, 0, 1)
            tf:Show()
        end
        MDTHighlighter:Print("testglow: " .. count .. " NM._plates | " .. #allPlates .. " plates directes")

    elseif cmd == "debug" then
        MDTHighlighter.MDTBridge:DebugDump()

    elseif cmd == "color" then
        local target = args[2]
        local r,g,b  = tonumber(args[3]), tonumber(args[4]), tonumber(args[5])
        if not (target and r and g and b) then
            MDTHighlighter:Print("Usage: /mdth color current|next|skip R G B  (0-1)")
            return
        end
        local key = target:upper()
        if not MDTHighlighter.COLORS[key] then
            MDTHighlighter:Print("Categorie inconnue : current, next, skip")
            return
        end
        r = math.max(0, math.min(1,r))
        g = math.max(0, math.min(1,g))
        b = math.max(0, math.min(1,b))
        MDTHighlighter.COLORS[key].r = r
        MDTHighlighter.COLORS[key].g = g
        MDTHighlighter.COLORS[key].b = b
        db["color_"..key] = {r=r,g=g,b=b}
        MDTHighlighter:Print(string.format("Couleur %s = (%.2f,%.2f,%.2f)", key,r,g,b))
        MDTHighlighter.NameplateManager:RefreshAll()

    elseif cmd == "reset" then
        MDTHighlighterDB = nil
        MDTHighlighter:Print("Reset au prochain /reload.")

    else
        MDTHighlighter:Print("/mdth [on|off]  |  current|next|skip [on|off]  |  test  |  debug  |  color C R G B  |  reset")
    end
end

function Config:Initialize()
    SLASH_MDTHIGHLIGHTER1 = "/mdth"
    SLASH_MDTHIGHLIGHTER2 = "/mdthighlighter"
    SlashCmdList["MDTHIGHLIGHTER"] = HandleSlash
    local db = MDTHighlighter.db
    for _, key in ipairs({"CURRENT","NEXT","SKIP"}) do
        local s = db["color_"..key]
        if s then MDTHighlighter.COLORS[key].r=s.r; MDTHighlighter.COLORS[key].g=s.g; MDTHighlighter.COLORS[key].b=s.b end
    end
end
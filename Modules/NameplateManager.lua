-- Modules/NameplateManager.lua
-- Gere les nameplates visibles et applique les glows LibCustomGlow.
-- Fonctionne en toute difficulte (M0, M+, Heroic, Normal).

---@class NameplateManagerModule
MDTHighlighter.NameplateManager = {}
local NM = MDTHighlighter.NameplateManager

NM._plates  = {}  -- unitToken -> { frame, glowFrame, npcID }
local GLOW_KEY = "MDTHighlighter"

-- ─────────────────────────────────────────────────────────────
-- Utilitaires
-- ─────────────────────────────────────────────────────────────

-- Extrait le NPC ID numerique depuis un GUID Creature/Vehicle
-- Format GUID : "Creature-0-XXXX-XXXX-XXXX-NPCID-XXXX"
local function GUIDToNPCID(guid)
    if not guid then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

-- Retourne le frame cible pour le glow (UnitFrame du nameplate)
local function GetGlowFrame(nameplate)
    if nameplate and nameplate.UnitFrame then
        return nameplate.UnitFrame
    end
    return nameplate
end

-- ─────────────────────────────────────────────────────────────
-- Application du glow
-- ─────────────────────────────────────────────────────────────

local function ApplyGlow(frame, colorKey)
    local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
    if not LCG then return end
    local c  = MDTHighlighter.COLORS[colorKey]
    local db = MDTHighlighter.db
    LCG.PixelGlow_Stop(frame, GLOW_KEY)
    LCG.PixelGlow_Start(
        frame,
        { c.r, c.g, c.b, c.a },
        db.glowLines      or 8,
        db.glowFrequency  or 0.25,
        db.glowThickness  or 2,
        0, 0, false,
        GLOW_KEY
    )
end

local function RemoveGlow(frame)
    local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
    if LCG then LCG.PixelGlow_Stop(frame, GLOW_KEY) end
end

-- ─────────────────────────────────────────────────────────────
-- Mise a jour d un nameplate individuel
-- ─────────────────────────────────────────────────────────────

local function UpdatePlate(unitToken)
    local entry = NM._plates[unitToken]
    if not entry then return end
    local db = MDTHighlighter.db
    if not db or not db.enabled then
        RemoveGlow(entry.glowFrame)
        return
    end
    local highlight = MDTHighlighter.MDTBridge:GetHighlightForNPC(entry.npcID)
    if not highlight
        or (highlight == "CURRENT" and not db.showCurrent)
        or (highlight == "NEXT"    and not db.showNext)
        or (highlight == "SKIP"    and not db.showSkip)
    then
        RemoveGlow(entry.glowFrame)
        return
    end
    ApplyGlow(entry.glowFrame, highlight)
end

-- ─────────────────────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────────────────────

-- Appele par MDTBridge quand les pulls changent
function NM:OnRouteChanged()
    for unitToken in pairs(NM._plates) do
        UpdatePlate(unitToken)
    end
end

-- Appele par Config apres un toggle
function NM:RefreshAll()
    NM:OnRouteChanged()
end

function NM:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, unitToken)

        if event == "NAME_PLATE_UNIT_ADDED" then
            local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken)
            if not nameplate then return end
            local guid  = UnitGUID(unitToken)
            local npcID = GUIDToNPCID(guid)
            if not npcID then return end
            NM._plates[unitToken] = {
                frame     = nameplate,
                glowFrame = GetGlowFrame(nameplate),
                npcID     = npcID,
            }
            UpdatePlate(unitToken)

        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local entry = NM._plates[unitToken]
            if entry then
                RemoveGlow(entry.glowFrame)
                NM._plates[unitToken] = nil
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Nettoie les entrees perimees lors d un changement de zone
            -- (fonctionne pour passage M0->M+, M+->M0, changement de donjon, etc.)
            NM._plates = {}
        end
    end)
end
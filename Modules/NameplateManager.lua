-- Modules/NameplateManager.lua
-- Midnight M+: GUIDs secrets → matching par npcID impossible directement.
-- Solution: cache npcID→nom (construit hors M+) + indicateur DIALOG strata.

MDTHighlighter.NameplateManager = {}
local NM = MDTHighlighter.NameplateManager
NM._plates    = {}
NM._addCount  = 0

local issecret = _G.issecretvalue or function() return false end

local function GUIDToNPCID(guid)
    if not guid then return nil end
    local ok, r = pcall(issecret, guid)
    if ok and r then return nil end
    local ok2, unitType, _, _, _, _, npcID = pcall(strsplit, "-", guid)
    if ok2 and (unitType == "Creature" or unitType == "Vehicle") then
        return tonumber(npcID)
    end
    return nil
end

local function GetLocaleCache()
    if not MDTHighlighter.db then return {} end
    if not MDTHighlighter.db.nameCache then
        MDTHighlighter.db.nameCache = {}
    end
    return MDTHighlighter.db.nameCache
end

-- Indicateur colore sous la nameplate
local function CreateIndicator(nameplate)
    local f = CreateFrame("Frame", nil, nameplate, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(128)
    f:SetSize(60, 6)
    f:SetPoint("TOP", nameplate, "BOTTOM", 0, -3)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(0, 0, 0, 0)
    f:Hide()
    return f
end

function NM:ApplyGlow(unitToken, highlightType)
    local data = NM._plates[unitToken]
    if not data or not data.indicator then return end

    if highlightType and MDTHighlighter.db and MDTHighlighter.db.enabled then
        local color = MDTHighlighter.COLORS[highlightType]
        if color then
            data.indicator:SetBackdropColor(color.r, color.g, color.b, color.a)
            data.indicator:SetBackdropBorderColor(
                math.min(1, color.r + 0.3),
                math.min(1, color.g + 0.3),
                math.min(1, color.b + 0.3), 1)
            data.indicator:Show()
            return
        end
    end
    data.indicator:Hide()
end

function NM:UpdateNameplate(unitToken)
    local data = NM._plates[unitToken]
    if not data then return end

    -- Ignorer les allies
    if UnitIsFriend("player", unitToken) then
        NM:ApplyGlow(unitToken, nil)
        return
    end

    local bridge = MDTHighlighter.MDTBridge
    local highlight = nil

    -- 1) Essai direct par NPC ID (fonctionne hors M+)
    if data.npcID then
        highlight = bridge:GetHighlightForNPC(data.npcID)
    end

    -- 2) Cache locale: chercher le npcID pour ce nom localise
    if not highlight and data.name then
        local cache = GetLocaleCache()
        local cachedNpcID = cache[data.name]
        if cachedNpcID then
            highlight = bridge:GetHighlightForNPC(cachedNpcID)
        end
    end

    -- 3) Fallback par nom anglais (si par hasard MDT est en anglais aussi)
    if not highlight and data.name then
        highlight = bridge:GetHighlightForName(data.name)
    end

    NM:ApplyGlow(unitToken, highlight)
end

function NM:RefreshAll()
    for unitToken in pairs(NM._plates) do
        NM:UpdateNameplate(unitToken)
    end
end

function NM:OnRouteChanged()
    NM:RefreshAll()
end

function NM:OnNamePlateAdded(unitToken)
    NM._addCount = NM._addCount + 1
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitToken)
    if not nameplate then return end

    local guid  = UnitGUID(unitToken)
    local npcID = GUIDToNPCID(guid)
    local name  = UnitName(unitToken)

    -- Construire le cache localise quand le GUID n'est pas secret (M0, monde)
    if npcID and name then
        local cache = GetLocaleCache()
        if not cache[name] then
            cache[name] = npcID
        end
    end

    local indicator = CreateIndicator(nameplate)

    NM._plates[unitToken] = {
        indicator = indicator,
        npcID     = npcID,
        name      = name,
    }

    NM:UpdateNameplate(unitToken)
end

function NM:OnNamePlateRemoved(unitToken)
    local data = NM._plates[unitToken]
    if data then
        if data.indicator then
            data.indicator:Hide()
            data.indicator:SetParent(nil)
        end
        NM._plates[unitToken] = nil
    end
end

function NM:ForceGlowAll(highlightType)
    -- Pour tester le rendu (testglow)
    for unitToken, data in pairs(NM._plates) do
        NM:ApplyGlow(unitToken, highlightType)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:SetScript("OnEvent", function(_, event, unitToken)
    if event == "NAME_PLATE_UNIT_ADDED" then
        NM:OnNamePlateAdded(unitToken)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        NM:OnNamePlateRemoved(unitToken)
    end
end)

function NM:Initialize()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = nameplate.namePlateUnitToken
        if unit then NM:OnNamePlateAdded(unit) end
    end
end
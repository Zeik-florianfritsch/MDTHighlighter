-- Modules/MDTBridge.lua

MDTHighlighter.MDTBridge = {}
local Bridge = MDTHighlighter.MDTBridge

Bridge.currentPullNPCs   = {}
Bridge.currentPullNames  = {}
Bridge.nextPullNPCs      = {}
Bridge.nextPullNames     = {}
Bridge.skipNPCs          = {}
Bridge.skipNames         = {}
Bridge._lastPullIndex    = nil
Bridge._ticker           = nil
Bridge.TICK_INTERVAL     = 0.5

local function GetMDTDB()
    local api = _G.MythicDungeonToolsAPI
    if api and type(api.GetDB) == "function" then
        local ok, db = pcall(function() return api:GetDB() end)
        if ok and db then return db end
    end
    local sv = _G["MythicDungeonToolsDB"]
    if sv and sv.global then return sv.global end
    return nil
end

local function GetCurrentDungeonIdx()
    local db = GetMDTDB()
    return db and db.currentDungeonIdx or nil
end

local function GetCurrentPreset()
    local db = GetMDTDB()
    local didx = GetCurrentDungeonIdx()
    if not db or not didx then return nil end
    if not db.presets or not db.presets[didx] then return nil end
    local pidx = (db.currentPreset and db.currentPreset[didx]) or 1
    return db.presets[didx][pidx]
end

local function GetCurrentPullIndex()
    local preset = GetCurrentPreset()
    if not preset or not preset.value then return nil end
    local sel = preset.value.selection
    if sel and #sel > 0 then return sel[#sel] end
    if preset.value.currentPull and preset.value.currentPull > 0 then
        return preset.value.currentPull
    end
    return nil
end

local function GetTotalPullsCount()
    local preset = GetCurrentPreset()
    if preset and preset.value and preset.value.pulls then
        return #preset.value.pulls
    end
    return 0
end

local function GetDungeonEnemies()
    local api = _G.MythicDungeonToolsAPI
    if api and type(api.dungeonEnemies) == "table" then
        return api.dungeonEnemies
    end
    return nil
end

local function ExtractPullDataFromDB(pullIndex)
    local ids, names = {}, {}
    local preset = GetCurrentPreset()
    if not preset or not preset.value or not preset.value.pulls then return ids, names end
    local pull = preset.value.pulls[pullIndex]
    if not pull then return ids, names end

    local dungeonIdx = GetCurrentDungeonIdx()
    local de = GetDungeonEnemies()
    if not de or not dungeonIdx or not de[dungeonIdx] then return ids, names end
    local dungeon = de[dungeonIdx]

    for enemyIdxStr, clones in pairs(pull) do
        local enemyIdx = tonumber(enemyIdxStr)
        if enemyIdx then
            local enemy = dungeon[enemyIdx]
            if enemy and type(clones) == "table" then
                local hasClone = false
                for _, cloneIdx in pairs(clones) do
                    if enemy.clones and enemy.clones[cloneIdx] then
                        hasClone = true; break
                    end
                end
                if hasClone then
                    if enemy.id   then ids[enemy.id]     = true end
                    if enemy.name then names[enemy.name] = true end
                end
            end
        end
    end
    return ids, names
end

local function ExtractPullDataFromUI(pullIndex)
    local ids, names = {}, {}
    local sidePanel = _G.MDTFrame and _G.MDTFrame.sidePanel
    if not sidePanel or not sidePanel.newPullButtons then return ids, names end
    local btn = sidePanel.newPullButtons[pullIndex]
    if not btn or not btn.enemyPortraits then return ids, names end
    for i = 1, 7 do
        local portrait = btn.enemyPortraits[i]
        if portrait and portrait.enemyData then
            local d = portrait.enemyData
            if d.npcId then ids[d.npcId] = true end
            if d.name  then names[d.name] = true end
        end
    end
    return ids, names
end

local function ExtractPullData(pullIndex)
    local de = GetDungeonEnemies()
    local didx = GetCurrentDungeonIdx()
    if de and didx and de[didx] then
        return ExtractPullDataFromDB(pullIndex)
    end
    return ExtractPullDataFromUI(pullIndex)
end

function Bridge:IsReady()
    return GetTotalPullsCount() > 0
end

function Bridge:GetCurrentPullIndex()
    return GetCurrentPullIndex()
end

function Bridge:GetTotalPulls()
    return GetTotalPullsCount()
end

function Bridge:GetHighlightForNPC(npcID)
    if Bridge.currentPullNPCs[npcID] then return "CURRENT" end
    if Bridge.nextPullNPCs[npcID]    then return "NEXT"    end
    if Bridge.skipNPCs[npcID]        then return "SKIP"    end
    return nil
end

function Bridge:GetHighlightForName(name)
    if not name then return nil end
    if Bridge.currentPullNames[name] then return "CURRENT" end
    if Bridge.nextPullNames[name]    then return "NEXT"    end
    if Bridge.skipNames[name]        then return "SKIP"    end
    return nil
end

local function DoRefresh()
    if not MDTHighlighter.db or not MDTHighlighter.db.enabled then return end
    if not Bridge:IsReady() then
        Bridge.currentPullNPCs, Bridge.currentPullNames = {}, {}
        Bridge.nextPullNPCs, Bridge.nextPullNames = {}, {}
        Bridge.skipNPCs, Bridge.skipNames = {}, {}
        MDTHighlighter.NameplateManager:OnRouteChanged()
        return
    end

    local currentIndex = Bridge:GetCurrentPullIndex()
    if currentIndex == Bridge._lastPullIndex then return end
    Bridge._lastPullIndex = currentIndex

    local totalPulls = Bridge:GetTotalPulls()
    local allNPCs, allNames = {}, {}

    Bridge.currentPullNPCs, Bridge.currentPullNames = {}, {}
    if currentIndex and MDTHighlighter.db.showCurrent then
        Bridge.currentPullNPCs, Bridge.currentPullNames = ExtractPullData(currentIndex)
        for id in pairs(Bridge.currentPullNPCs)  do allNPCs[id]  = true end
        for nm in pairs(Bridge.currentPullNames) do allNames[nm] = true end
    end

    Bridge.nextPullNPCs, Bridge.nextPullNames = {}, {}
    if currentIndex and currentIndex < totalPulls and MDTHighlighter.db.showNext then
        Bridge.nextPullNPCs, Bridge.nextPullNames = ExtractPullData(currentIndex + 1)
        for id in pairs(Bridge.nextPullNPCs)  do allNPCs[id]  = true end
        for nm in pairs(Bridge.nextPullNames) do allNames[nm] = true end
    end

    Bridge.skipNPCs, Bridge.skipNames = {}, {}
    if MDTHighlighter.db.showSkip then
        for i = 1, totalPulls do
            if i ~= currentIndex and (not currentIndex or i ~= currentIndex + 1) then
                local ids, names = ExtractPullData(i)
                for id in pairs(ids)   do if not allNPCs[id]  then Bridge.skipNPCs[id]  = true end end
                for nm in pairs(names) do if not allNames[nm] then Bridge.skipNames[nm] = true end end
            end
        end
    end

    MDTHighlighter.NameplateManager:OnRouteChanged()
end

function Bridge:Refresh()
    DoRefresh()
end

function Bridge:ForceRefresh()
    Bridge._lastPullIndex = nil
    DoRefresh()
end

function Bridge:DebugDump()
    MDTHighlighter:Print("=== MDTBridge Debug ===")
    local db = GetMDTDB()
    MDTHighlighter:Print("MDT DB: " .. (db and "|cff00ff00OK|r" or "|cffff0000nil|r"))
    local didx = GetCurrentDungeonIdx()
    MDTHighlighter:Print("Dungeon idx: " .. tostring(didx))

    local preset = GetCurrentPreset()
    if preset and preset.value then
        local pulls = preset.value.pulls
        local sel = preset.value.selection
        MDTHighlighter:Print("Pulls: #" .. (pulls and #pulls or 0) ..
            " selection=" .. (sel and table.concat(sel, ",") or "nil"))
    else
        MDTHighlighter:Print("|cffff0000Preset: nil|r")
    end

    local de = GetDungeonEnemies()
    local hasDE = de and didx and de[didx]
    local hasUI = _G.MDTFrame and _G.MDTFrame.sidePanel and _G.MDTFrame.sidePanel.newPullButtons
    MDTHighlighter:Print("dungeonEnemies: " .. (hasDE and "|cff00ff00OK|r" or "|cffff0000nil|r") ..
        "  UI Buttons: " .. (hasUI and "|cff00ff00Yes|r" or "|cffff0000No|r"))

    local cidx = GetCurrentPullIndex()
    MDTHighlighter:Print("Current pull idx: " .. tostring(cidx))
    if cidx then
        local ids, names = ExtractPullData(cidx)
        local idList, nameList = {}, {}
        for id in pairs(ids)   do idList[#idList+1]     = id end
        for nm in pairs(names) do nameList[#nameList+1] = nm end
        MDTHighlighter:Print("Pull " .. cidx .. ": " .. #idList .. " NPCs IDs, noms=(" ..
            table.concat(nameList, ", ") .. ")")
    end

    -- Diagnostic nameplates
    local NM = MDTHighlighter.NameplateManager
    MDTHighlighter:Print("--- Nameplates ---")
    MDTHighlighter:Print("NM._plates: " .. (function() local n=0; for _ in pairs(NM._plates) do n=n+1 end; return n end)() ..
        "  events: " .. tostring(NM._addCount or 0))

    -- Compter les plates via GetNamePlates (pairs, pas ipairs)
    local plateCount = 0
    local allPlates = C_NamePlate.GetNamePlates()
    for _ in pairs(allPlates) do plateCount = plateCount + 1 end
    MDTHighlighter:Print("C_NamePlate.GetNamePlates(): " .. plateCount .. " plates")

    local issecret = _G.issecretvalue or function() return false end
    local shown = 0
    for _, np in pairs(allPlates) do
        local token = np.namePlateUnitToken
        if token then
            shown = shown + 1
            local name = UnitName(token) or "?"
            local guid  = UnitGUID(token)
            local sec = false
            if guid then local ok, r = pcall(issecret, guid); sec = ok and r end
            local npcID = nil
            if guid and not sec then
                local ok, _, _, _, _, _, nid = pcall(strsplit, "-", guid)
                if ok then npcID = tonumber(nid) end
            end
            MDTHighlighter:Print(string.format("  [%d] %s | npcID=%s | secret=%s | friend=%s",
                shown, name, tostring(npcID), tostring(sec),
                tostring(UnitIsFriend("player", token))))
            if shown >= 4 then MDTHighlighter:Print("  ..."); break end
        end
    end
    if shown == 0 then
        MDTHighlighter:Print("  (0 nameplates avec token valide)")
    end

    -- Cibler une plate directement via target
    if UnitExists("target") and not UnitIsFriend("player", "target") then
        local guid = UnitGUID("target")
        local sec = false
        if guid then local ok, r = pcall(issecret, guid); sec = ok and r end
        local npcID = nil
        if guid and not sec then
            local ok, _, _, _, _, _, nid = pcall(strsplit, "-", guid)
            if ok then npcID = tonumber(nid) end
        end
        MDTHighlighter:Print("TARGET: " .. (UnitName("target") or "?") ..
            " npcID=" .. tostring(npcID) ..
            " secret=" .. tostring(sec) ..
            " highlight=" .. tostring(Bridge:GetHighlightForNPC(npcID or 0)))
    end
end

function Bridge:Initialize()
    -- Charger MythicDungeonTools_UI silencieusement (sans ouvrir la fenetre)
    -- Cela peuple dungeonEnemies qui est necessaire pour matcher les NPCs
    C_Timer.After(0.5, function()
        if C_AddOns.IsAddOnLoaded("MythicDungeonTools") and
           not C_AddOns.IsAddOnLoaded("MythicDungeonTools_UI") then
            C_AddOns.LoadAddOn("MythicDungeonTools_UI")
        end
    end)

    C_Timer.After(1.5, function()
        Bridge:ForceRefresh()
    end)

    Bridge._ticker = C_Timer.NewTicker(Bridge.TICK_INTERVAL, function()
        Bridge:Refresh()
    end)
end
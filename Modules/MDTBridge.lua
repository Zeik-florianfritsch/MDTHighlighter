-- Modules/MDTBridge.lua
-- Interface avec MythicDungeonTools pour extraire les pulls.
-- Fonctionne en Mythic+, Mythic 0 (MM0), Heroic, Normal.
-- Aucune restriction de difficulte : utile pour tester hors cle.

---@class MDTBridgeModule
MDTHighlighter.MDTBridge = {}
local Bridge = MDTHighlighter.MDTBridge

-- ─────────────────────────────────────────────────────────────
-- Etat interne
-- ─────────────────────────────────────────────────────────────

Bridge.currentPullNPCs = {}
Bridge.nextPullNPCs    = {}
Bridge.skipNPCs        = {}

Bridge._lastPullIndex  = nil
Bridge._ticker         = nil
Bridge.TICK_INTERVAL   = 1.0

-- ─────────────────────────────────────────────────────────────
-- Verification de disponibilite MDT
-- ─────────────────────────────────────────────────────────────

function Bridge:IsReady()
    return MDT ~= nil
        and MDT.db ~= nil
        and MDT.db.profile ~= nil
        and MDT.db.profile.pulls ~= nil
end

-- Retourne l index du pull actif (1-based) ou nil
function Bridge:GetCurrentPullIndex()
    if not Bridge:IsReady() then return nil end
    local pullIndex = MDT.db.profile.pull
    if type(pullIndex) == "number" and pullIndex >= 1 then
        return pullIndex
    end
    return nil
end

-- Retourne le nombre total de pulls dans la route chargee
function Bridge:GetTotalPulls()
    if not Bridge:IsReady() then return 0 end
    local pulls = MDT.db.profile.pulls
    if type(pulls) ~= "table" then return 0 end
    return #pulls
end

-- Collecte les NPC IDs d un pull donne. Renvoie { [npcID] = true }
-- Fonctionne peu importe la difficulte du donjon (M0, M+, Heroic...)
function Bridge:GetNPCsInPull(pullIndex)
    local set = {}
    if not Bridge:IsReady() then return set end
    if type(pullIndex) ~= "number" or pullIndex < 1 then return set end

    local pulls        = MDT.db.profile.pulls
    local dungeonIndex = MDT:GetCurrentDungeonIdx()
    if not pulls or not dungeonIndex then return set end

    local pull = pulls[pullIndex]
    if not pull then return set end

    -- MDT stocke les enemies du donjon dans MDT.dungeonEnemies[dungeonIndex]
    -- La cle dungeonIndex dans le pull correspond aux clones (positions) de chaque enemy
    local dungeonEnemies = MDT.dungeonEnemies and MDT.dungeonEnemies[dungeonIndex]
    if not dungeonEnemies then return set end

    local dungeonPull = pull[dungeonIndex]
    if not dungeonPull then return set end

    for cloneIndex, count in pairs(dungeonPull) do
        if type(count) == "number" and count > 0 then
            local enemy = dungeonEnemies[cloneIndex]
            if enemy and enemy.id then
                set[enemy.id] = true
            end
        end
    end
    return set
end

-- Collecte les NPCs presents dans les donnees du donjon mais absents de tous les pulls
function Bridge:GetSkippedNPCs(allPullNPCs)
    local set = {}
    if not Bridge:IsReady() then return set end

    local dungeonIndex   = MDT:GetCurrentDungeonIdx()
    local dungeonEnemies = dungeonIndex and MDT.dungeonEnemies and MDT.dungeonEnemies[dungeonIndex]
    if not dungeonEnemies then return set end

    for _, enemy in ipairs(dungeonEnemies) do
        -- Ne inclure que les enemies qui comptent vraiment (pas les bosses en dehors de la route, etc.)
        if enemy and enemy.id and not allPullNPCs[enemy.id] then
            -- Exclure les enemies marques comme non-comptables si MDT le precise
            local isSub = (enemy.sublevel ~= nil) -- toujours inclure meme les enemies de sous-niveau
            set[enemy.id] = true
        end
    end
    return set
end

-- Rafraichissement principal : recalcule les 3 sets et notifie NameplateManager
function Bridge:Refresh()
    if not MDTHighlighter.db or not MDTHighlighter.db.enabled then return end

    if not Bridge:IsReady() then
        if next(Bridge.currentPullNPCs) or next(Bridge.nextPullNPCs) or next(Bridge.skipNPCs) then
            Bridge.currentPullNPCs = {}
            Bridge.nextPullNPCs    = {}
            Bridge.skipNPCs        = {}
            MDTHighlighter.NameplateManager:OnRouteChanged()
        end
        return
    end

    local currentIndex = Bridge:GetCurrentPullIndex()
    if currentIndex == Bridge._lastPullIndex then return end
    Bridge._lastPullIndex = currentIndex

    local allPulled = {}
    local totalPulls = Bridge:GetTotalPulls()

    -- Pull actuel
    Bridge.currentPullNPCs = {}
    if currentIndex and MDTHighlighter.db.showCurrent then
        Bridge.currentPullNPCs = Bridge:GetNPCsInPull(currentIndex)
        for id in pairs(Bridge.currentPullNPCs) do allPulled[id] = true end
    end

    -- Pull suivant
    Bridge.nextPullNPCs = {}
    if currentIndex and currentIndex < totalPulls and MDTHighlighter.db.showNext then
        Bridge.nextPullNPCs = Bridge:GetNPCsInPull(currentIndex + 1)
        for id in pairs(Bridge.nextPullNPCs) do allPulled[id] = true end
    end

    -- Tous les pulls pour calculer les skips
    for i = 1, totalPulls do
        local npcs = Bridge:GetNPCsInPull(i)
        for id in pairs(npcs) do allPulled[id] = true end
    end

    -- Mobs skipped
    Bridge.skipNPCs = {}
    if MDTHighlighter.db.showSkip then
        Bridge.skipNPCs = Bridge:GetSkippedNPCs(allPulled)
    end

    MDTHighlighter.NameplateManager:OnRouteChanged()
end

-- Retourne la categorie de highlight pour un NPC ID, ou nil
-- Priorite : CURRENT > NEXT > SKIP
function Bridge:GetHighlightForNPC(npcID)
    if Bridge.currentPullNPCs[npcID] then return "CURRENT" end
    if Bridge.nextPullNPCs[npcID]    then return "NEXT"    end
    if Bridge.skipNPCs[npcID]        then return "SKIP"    end
    return nil
end

-- Force un rafraichissement immediat (utile apres /mdth test ou /mdth force)
function Bridge:ForceRefresh()
    Bridge._lastPullIndex = nil  -- invalide le cache pour forcer le recalcul
    Bridge:Refresh()
end

function Bridge:Initialize()
    -- Ticker de 1s : suffisant pour detecter les changements de pull dans MDT
    -- Fonctionne en toute difficulte (M0, M+, Heroic, Normal)
    Bridge._ticker = C_Timer.NewTicker(Bridge.TICK_INTERVAL, function()
        Bridge:Refresh()
    end)

    -- Hook sur MDT quand il est disponible pour detecter les changements de route importee
    if MDT then
        -- On hook la fonction d importation de route de MDT
        -- afin de forcer un rafraichissement immediat sans attendre le ticker
        if MDT.ImportStringToTable then
            hooksecurefunc(MDT, "ImportStringToTable", function()
                C_Timer.After(0.5, function() Bridge:ForceRefresh() end)
            end)
        end
        -- Hook sur le changement de pull actif dans l UI de MDT
        if MDT.UpdatePull then
            hooksecurefunc(MDT, "UpdatePull", function()
                Bridge:ForceRefresh()
            end)
        end
    end
end
------------------------------------------------------------------------
-- Pro Shop - Professions
-- Profession detection, recipe scanning, cooldown tracking
------------------------------------------------------------------------
local _, PS = ...
local C = PS.C

------------------------------------------------------------------------
-- Known profession names (for spellbook tab detection)
------------------------------------------------------------------------
local PRIMARY_PROFESSIONS = {
    ["Alchemy"] = true,
    ["Blacksmithing"] = true,
    ["Enchanting"] = true,
    ["Engineering"] = true,
    ["Jewelcrafting"] = true,
    ["Leatherworking"] = true,
    ["Tailoring"] = true,
    ["Mining"] = true,
    ["Herbalism"] = true,
    ["Skinning"] = true,
}

local SECONDARY_PROFESSIONS = {
    ["Cooking"] = true,
    ["First Aid"] = true,
    ["Fishing"] = true,
    ["Lockpicking"] = true,
}

-- Class-based services (not real professions, detected by player class)
local CLASS_SERVICES = {
    ["MAGE"]    = "Portals",
    ["WARLOCK"] = "Summons",
    ["ROGUE"]   = "Lockpicking",
}

local ALL_PROFESSIONS = {}
for k, v in pairs(PRIMARY_PROFESSIONS) do ALL_PROFESSIONS[k] = v end
for k, v in pairs(SECONDARY_PROFESSIONS) do ALL_PROFESSIONS[k] = v end

------------------------------------------------------------------------
-- Scan for professions using the Skills panel API (reliable in TBC Classic)
------------------------------------------------------------------------
function PS:ScanProfessions()
    -- Preserve existing recipe counts before resetting
    local existingCounts = {}
    for name, data in pairs(self.professions) do
        if data.numRecipes and data.numRecipes > 0 then
            existingCounts[name] = data.numRecipes
        end
    end

    self.professions = {}

    -- Method 1: Skill lines (Character -> Skills window) - most reliable in TBC
    local numSkillLines = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, numSkillLines do
        local name, isHeader, isExpanded, rank, numTempPoints, modifier, maxRank = GetSkillLineInfo(i)
        if name and not isHeader and ALL_PROFESSIONS[name] then
            self.professions[name] = {
                skill = rank,
                maxSkill = maxRank,
                numRecipes = 0,
                isPrimary = PRIMARY_PROFESSIONS[name] or false,
            }
        end
    end

    -- Method 2: Fallback to spellbook tabs if Skills API returned nothing
    if not next(self.professions) then
        local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
        for i = 1, numTabs do
            local name, texture, offset, numEntries = GetSpellTabInfo(i)
            if name and ALL_PROFESSIONS[name] then
                self.professions[name] = {
                    tabIndex = i,
                    texture = texture,
                    offset = offset,
                    numSpells = numEntries,
                    numRecipes = 0,
                    isPrimary = PRIMARY_PROFESSIONS[name] or false,
                }
            end
        end
    end

    -- Restore recipe counts from previous scan or saved cache
    for name, data in pairs(self.professions) do
        if data.numRecipes == 0 and existingCounts[name] then
            data.numRecipes = existingCounts[name]
        end
    end
    if self.db and self.db.knownRecipes then
        local profCounts = {}
        for _, prof in pairs(self.db.knownRecipes) do
            profCounts[prof] = (profCounts[prof] or 0) + 1
        end
        for profName, cnt in pairs(profCounts) do
            if self.professions[profName] and self.professions[profName].numRecipes == 0 then
                self.professions[profName].numRecipes = cnt
            end
        end
    end

    -- Count detected professions for status display
    local count = 0
    local names = {}
    for name, _ in pairs(self.professions) do
        count = count + 1
        table.insert(names, name)
    end

    if count > 0 then
        self:Print(C.GREEN .. count .. C.R .. " professions detected: " .. C.CYAN .. table.concat(names, ", ") .. C.R)
    else
        self:Debug("No professions detected yet. Try opening your Skills (K) window.")
    end

    -- Detect class-based services (Mage Portals, Warlock Summons, Rogue Lockpicking)
    local _, playerClass = UnitClass("player")
    if playerClass and CLASS_SERVICES[playerClass] then
        local serviceName = CLASS_SERVICES[playerClass]
        if not self.professions[serviceName] then
            local level = UnitLevel("player") or 1
            -- For Lockpicking, try to get actual skill level from skill lines
            local serviceSkill = level
            if serviceName == "Lockpicking" then
                for i = 1, (GetNumSkillLines and GetNumSkillLines() or 0) do
                    local sName, sHeader, _, sRank = GetSkillLineInfo(i)
                    if sName == "Lockpicking" and not sHeader then
                        serviceSkill = sRank or level
                        break
                    end
                end
            end
            self.professions[serviceName] = {
                skill = serviceSkill,
                maxSkill = serviceSkill,
                numRecipes = 0,
                isPrimary = false,
                isClassService = true,
            }
            self:Print(C.GREEN .. "Class service detected: " .. C.CYAN .. serviceName .. " (" .. serviceSkill .. ")" .. C.R)
        end
    end

    -- Register for trade skill events to scan recipes when windows open
    self:RegisterEvent("TRADE_SKILL_SHOW")
    self:RegisterEvent("TRADE_SKILL_UPDATE")
    self:RegisterEvent("TRADE_SKILL_CLOSE")

    -- Also re-scan on skill updates
    self:RegisterEvent("SKILL_LINES_CHANGED")
end

-- Re-scan when skills change (learning new profession, leveling up)
function PS:SKILL_LINES_CHANGED()
    if not self.initialized then return end

    -- Preserve class services (Portals, Summons, Lockpicking) before rebuilding
    local classServices = {}
    for name, data in pairs(self.professions) do
        if data.isClassService then
            classServices[name] = data
        end
    end

    -- Re-run skill scan
    local found = {}
    local numSkillLines = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, numSkillLines do
        local name, isHeader, isExpanded, rank, numTempPoints, modifier, maxRank = GetSkillLineInfo(i)
        if name and not isHeader and ALL_PROFESSIONS[name] then
            found[name] = {
                skill = rank,
                maxSkill = maxRank,
                numRecipes = self.professions[name] and self.professions[name].numRecipes or 0,
                isPrimary = PRIMARY_PROFESSIONS[name] or false,
            }
        end
    end
    if next(found) then
        self.professions = found
    end

    -- Restore class services
    for name, data in pairs(classServices) do
        if not self.professions[name] then
            self.professions[name] = data
        end
    end
end

------------------------------------------------------------------------
-- Scan recipes when trade skill window is opened
------------------------------------------------------------------------
function PS:TRADE_SKILL_SHOW()
    C_Timer.After(0.5, function()
        PS:ScanTradeSkill()
    end)
end

function PS:TRADE_SKILL_UPDATE()
    PS:ScanTradeSkill()
end

function PS:TRADE_SKILL_CLOSE()
    -- Nothing needed, recipes are cached
end

function PS:ScanTradeSkill()
    local skillName, currentLevel, maxLevel = GetTradeSkillLine()
    if not skillName or skillName == "UNKNOWN" then return end

    local numSkills = GetNumTradeSkills()
    if not numSkills or numSkills == 0 then return end

    local count = 0

    -- Expand all headers first for a full scan
    for i = numSkills, 1, -1 do
        local name, skillType = GetTradeSkillInfo(i)
        if skillType == "header" then
            ExpandTradeSkillSubClass(i)
        end
    end

    -- Re-read count after expansion
    numSkills = GetNumTradeSkills()

    for i = 1, numSkills do
        local recipeName, skillType = GetTradeSkillInfo(i)
        if recipeName and skillType ~= "header" then
            local lowerName = recipeName:lower()
            self.knownRecipes[lowerName] = {
                name = recipeName,
                profession = skillName,
                index = i,
            }
            -- Persist to saved variables
            self.db.knownRecipes[lowerName] = skillName
            count = count + 1
        end
    end

    -- Update profession info
    if self.professions[skillName] then
        self.professions[skillName].numRecipes = count
        self.professions[skillName].skill = currentLevel
        self.professions[skillName].maxSkill = maxLevel
    else
        -- Profession wasn't detected from spellbook tabs, add it now
        self.professions[skillName] = {
            numRecipes = count,
            skill = currentLevel,
            maxSkill = maxLevel,
            isPrimary = PRIMARY_PROFESSIONS[skillName] or false,
        }
    end

    self:Print(C.CYAN .. skillName .. C.R .. ": scanned " .. C.GREEN .. count .. C.R .. " recipes.")
end

------------------------------------------------------------------------
-- Deep Scan: User-guided recipe scanning
-- Recipes are automatically scanned when you open each profession window.
-- This function just tells you which professions still need scanning.
------------------------------------------------------------------------
local SCANNABLE_PROFESSIONS = {
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
    ["Enchanting"] = true, ["Engineering"] = true, ["First Aid"] = true,
    ["Jewelcrafting"] = true, ["Leatherworking"] = true, ["Tailoring"] = true,
}

function PS:DeepScanProfessions()
    -- List which professions need scanning
    local needScan = {}
    for name, data in pairs(self.professions) do
        if SCANNABLE_PROFESSIONS[name] and (data.numRecipes or 0) == 0 then
            table.insert(needScan, name)
        end
    end

    if #needScan == 0 then
        local total = 0
        for _, data in pairs(self.professions) do
            total = total + (data.numRecipes or 0)
        end
        self:Print(C.GREEN .. "All professions scanned! " .. C.R .. C.WHITE .. total .. " total recipes cached." .. C.R)
    else
        self:Print(C.CYAN .. "Open each profession window to scan recipes:" .. C.R)
        for _, name in ipairs(needScan) do
            self:Print("  " .. C.YELLOW .. name .. C.R .. " — not yet scanned")
        end
    end
end

------------------------------------------------------------------------
-- Check if player has a specific profession
------------------------------------------------------------------------
function PS:HasProfession(profName)
    return self.professions[profName] ~= nil
end

-- Check if a matched profession/item is something the player can do
function PS:CanFulfill(matchInfo)
    if not matchInfo or not matchInfo.profession then return false end

    -- Check if we have the profession
    if not self:HasProfession(matchInfo.profession) then
        return false
    end

    -- Lockpicking skill level check
    if matchInfo.profession == "Lockpicking" then
        local profData = self.professions["Lockpicking"]
        local playerSkill = profData and profData.skill or 0
        -- If the matched item has a required skill, check against it
        local requiredSkill = matchInfo.requiredSkill or 0
        if requiredSkill > 0 and playerSkill < requiredSkill then
            self:Debug("Lockpicking too low (" .. playerSkill .. "/" .. requiredSkill .. ") for " .. (matchInfo.item or "unknown"))
            return false
        end
        -- For generic "LF lockpicking" requests, still allow if we have the skill
    end

    -- Portals and Summons are class services - no recipe check needed
    if matchInfo.profession == "Portals" or matchInfo.profession == "Summons" then
        return true
    end

    -- If a specific item was matched, check if we actually know the recipe
    if matchInfo.item and (matchInfo.matchType == "keyword" or matchInfo.matchType == "recipe") then
        local lowerItem = matchInfo.item:lower()

        -- Check if we have any scanned recipes for this profession
        local haveRecipesForProf = false
        for _, data in pairs(self.knownRecipes) do
            if data.profession == matchInfo.profession then
                haveRecipesForProf = true
                break
            end
        end

        if haveRecipesForProf then
            -- We have recipe data for this profession: only match if we know the recipe
            for recipeName, data in pairs(self.knownRecipes) do
                if data.profession == matchInfo.profession then
                    -- Exact match
                    if recipeName == lowerItem then
                        return true
                    end
                    -- For recipe-type matches (from in-game scanning), allow the scanned
                    -- recipe name to contain the search term, but NOT the other way around.
                    -- This prevents "flying machine" from matching "turbo-charged flying machine".
                    if matchInfo.matchType == "recipe" then
                        if recipeName:find(lowerItem, 1, true) then
                            return true
                        end
                    end
                end
            end
            -- We have scanned this profession and don't know this recipe
            return false
        end

        -- No recipe data scanned yet for this profession: assume we can do it
        return true
    end

    -- Generic profession match (no specific item) - we have the profession so yes
    return true
end

------------------------------------------------------------------------
-- Cooldown Tracking
------------------------------------------------------------------------
function PS:CheckCooldowns()
    local cooldowns = {}

    for profession, cdList in pairs(PS.PROFESSION_COOLDOWNS) do
        if self:HasProfession(profession) then
            for _, cd in ipairs(cdList) do
                -- Try to find the spell in the spellbook
                local spellName = cd.spellName
                local start, duration, enabled = GetSpellCooldown(spellName)
                if start and start > 0 then
                    local remaining = (start + duration) - GetTime()
                    if remaining > 0 then
                        table.insert(cooldowns, {
                            name = cd.name,
                            profession = profession,
                            remaining = remaining,
                            ready = false,
                        })
                    else
                        table.insert(cooldowns, {
                            name = cd.name,
                            profession = profession,
                            remaining = 0,
                            ready = true,
                        })
                    end
                else
                    -- No cooldown data = ready or not learned
                    table.insert(cooldowns, {
                        name = cd.name,
                        profession = profession,
                        remaining = 0,
                        ready = true,
                    })
                end
            end
        end
    end

    return cooldowns
end

function PS:PrintCooldowns()
    local cooldowns = self:CheckCooldowns()

    if #cooldowns == 0 then
        self:Print(C.GRAY .. "No tracked cooldowns (need Tailoring, Alchemy, or Leatherworking)." .. C.R)
        return
    end

    self:Print(C.GOLD .. "=== Profession Cooldowns ===" .. C.R)
    for _, cd in ipairs(cooldowns) do
        local status
        if cd.ready then
            status = C.GREEN .. "READY" .. C.R
        else
            status = C.RED .. self:FormatTime(cd.remaining) .. C.R
        end
        self:Print("  " .. C.CYAN .. cd.profession .. C.R .. " - " .. cd.name .. ": " .. status)
    end
end

------------------------------------------------------------------------
-- Get a summary of professions for ad generation
------------------------------------------------------------------------
function PS:GetProfessionSummary()
    local summary = {}
    for name, data in pairs(self.professions) do
        if data.isPrimary or name == "Cooking" or name == "Lockpicking" or name == "Portals" or name == "Summons" then
            table.insert(summary, {
                name = name,
                skill = data.skill or "?",
                maxSkill = data.maxSkill or "?",
                numRecipes = data.numRecipes or 0,
            })
        end
    end
    table.sort(summary, function(a, b) return a.name < b.name end)
    return summary
end

------------------------------------------------------------------------
-- Portal Management: Track active portals and provide cast helpers
------------------------------------------------------------------------
-- All portal spells a mage can cast (spell name = item name from Database)
PS.PORTAL_SPELLS = {
    ["Portal: Shattrath"]     = true,
    ["Portal: Stormwind"]     = true,
    ["Portal: Ironforge"]     = true,
    ["Portal: Darnassus"]     = true,
    ["Portal: Exodar"]        = true,
    ["Portal: Orgrimmar"]     = true,
    ["Portal: Undercity"]     = true,
    ["Portal: Thunder Bluff"] = true,
    ["Portal: Silvermoon"]    = true,
    ["Portal: Stonard"]       = true,
    ["Portal: Theramore"]     = true,
}

-- Active portal state: portalSpell -> castTimestamp
PS.activePortals = {}

-- Portal duration (60s in TBC) minus safety buffer (30s) = 30s active window
PS.PORTAL_DURATION   = 60
PS.PORTAL_BUFFER     = 30
PS.PORTAL_ACTIVE_WIN = PS.PORTAL_DURATION - PS.PORTAL_BUFFER  -- 30 seconds

--- Check if a specific portal is still active (within the safe window)
function PS:IsPortalActive(portalSpell)
    local castTime = self.activePortals[portalSpell]
    if not castTime then return false end
    return (GetTime() - castTime) < self.PORTAL_ACTIVE_WIN
end

--- How many seconds remain in the safe active window
function PS:GetPortalTimeRemaining(portalSpell)
    local castTime = self.activePortals[portalSpell]
    if not castTime then return 0 end
    local remaining = self.PORTAL_ACTIVE_WIN - (GetTime() - castTime)
    return math.max(0, remaining)
end

--- Called by UNIT_SPELLCAST_SUCCEEDED to record portal casts
function PS:OnPortalCast(portalSpell)
    self.activePortals[portalSpell] = GetTime()
    self:Print(C.PURPLE .. "Portal cast: " .. C.CYAN .. portalSpell .. C.R ..
        " \226\128\148 active for " .. self.PORTAL_ACTIVE_WIN .. "s")

    -- Auto-invite any queued customers waiting for this portal
    for _, customer in ipairs(self.queue) do
        if customer.portalSpell == portalSpell
        and customer.state ~= "INVITED"
        and customer.state ~= "IN_PROGRESS"
        and customer.state ~= "COMPLETED" then
            self:InvitePlayer(customer.name)
            customer.state = "INVITED"
            self:Print(C.GREEN .. customer.name .. C.R .. " auto-invited (portal is up)")
        end
    end

    self:RefreshEngagementPanel()

    -- Refresh mage portal bars in dashboard
    self:RefreshMagePortalBars()

    -- Auto-refresh when portal expires so UI updates (Cast button reappears)
    C_Timer.After(self.PORTAL_ACTIVE_WIN + 1, function()
        PS:RefreshEngagementPanel()
    end)
end

--- Event handler for UNIT_SPELLCAST_SUCCEEDED
function PS:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    if unit ~= "player" then return end
    local spellName = GetSpellInfo(spellID)
    if spellName and self.PORTAL_SPELLS[spellName] then
        self:OnPortalCast(spellName)
    end
end

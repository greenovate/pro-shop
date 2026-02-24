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

    -- Detect class-based services (Mage Portals, Warlock Summons)
    local _, playerClass = UnitClass("player")
    if playerClass and CLASS_SERVICES[playerClass] then
        local serviceName = CLASS_SERVICES[playerClass]
        if not self.professions[serviceName] then
            local level = UnitLevel("player") or 1
            self.professions[serviceName] = {
                skill = level,
                maxSkill = level,
                numRecipes = 0,
                isPrimary = false,
                isClassService = true,
            }
            self:Print(C.GREEN .. "Class service detected: " .. C.CYAN .. serviceName .. C.R)
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
    local oldCount = 0
    for _ in pairs(self.professions) do oldCount = oldCount + 1 end

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
-- Deep Scan: Automatically open each profession window to scan recipes
-- Sequences through each detected craft/trade skill window
------------------------------------------------------------------------
PS.deepScanQueue = {}
PS.deepScanActive = false
PS.deepScanAutoClose = false

-- Professions that use CastSpellByName to open their trade skill window
local CASTABLE_PROFESSIONS = {
    ["Alchemy"] = "Alchemy",
    ["Blacksmithing"] = "Blacksmithing",
    ["Cooking"] = "Cooking",
    ["Enchanting"] = "Enchanting",
    ["Engineering"] = "Engineering",
    ["First Aid"] = "First Aid",
    ["Jewelcrafting"] = "Jewelcrafting",
    ["Leatherworking"] = "Leatherworking",
    ["Tailoring"] = "Tailoring",
}

function PS:DeepScanProfessions()
    if self.deepScanActive then
        self:Print(C.ORANGE .. "Deep scan already in progress..." .. C.R)
        return
    end

    if InCombatLockdown() then
        self:Print(C.RED .. "Can't scan professions while in combat." .. C.R)
        return
    end

    -- Build list of professions to scan
    self.deepScanQueue = {}
    for name, _ in pairs(self.professions) do
        if CASTABLE_PROFESSIONS[name] then
            table.insert(self.deepScanQueue, name)
        end
    end

    if #self.deepScanQueue == 0 then
        self:Print(C.RED .. "No scannable professions found." .. C.R)
        return
    end

    self.deepScanActive = true
    self:Print(C.CYAN .. "Deep scanning " .. #self.deepScanQueue .. " professions..." .. C.R)
    self:DeepScanNext()
end

function PS:DeepScanNext()
    if #self.deepScanQueue == 0 then
        -- Done scanning all professions
        self.deepScanActive = false
        -- Close the window if we opened it
        if self.deepScanAutoClose then
            CloseTradeSkill()
            self.deepScanAutoClose = false
        end

        -- Count total recipes
        local total = 0
        for _, data in pairs(self.professions) do
            total = total + (data.numRecipes or 0)
        end
        self:Print(C.GREEN .. "Deep scan complete! " .. C.R .. C.WHITE .. total .. " total recipes cached." .. C.R)
        return
    end

    local profName = table.remove(self.deepScanQueue, 1)
    local spellName = CASTABLE_PROFESSIONS[profName]

    self:Debug("Deep scanning: " .. profName)

    -- Close any currently open trade skill window first
    CloseTradeSkill()

    -- Wait a moment then open the profession
    C_Timer.After(0.3, function()
        if InCombatLockdown() then
            PS:Print(C.RED .. "Combat detected, aborting scan." .. C.R)
            PS.deepScanActive = false
            PS.deepScanQueue = {}
            return
        end

        PS.deepScanAutoClose = true
        CastSpellByName(spellName)

        -- Wait for TRADE_SKILL_SHOW to fire and scan, then continue
        C_Timer.After(1.0, function()
            -- ScanTradeSkill should have already fired via TRADE_SKILL_SHOW
            -- Now move to the next profession
            CloseTradeSkill()
            C_Timer.After(0.3, function()
                PS:DeepScanNext()
            end)
        end)
    end)
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



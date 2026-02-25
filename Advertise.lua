------------------------------------------------------------------------
-- Pro Shop - Advertise
-- Advertising system - profession link based advertising
-- Ads center around your clickable [Profession] link so buyers can
-- inspect your full recipe list themselves.
------------------------------------------------------------------------
local _, PS = ...
local C = PS.C

------------------------------------------------------------------------
-- Static templates for non-recipe services (Portals, Summons)
-- Lockpicking is dynamic based on actual skill level.
------------------------------------------------------------------------
PS.STATIC_AD_TEMPLATES = {
    ["Portals"] = {
        "[Pro Shop] Mage portals available! Shattrath, all capital cities. Tips appreciated! PST with destination!",
        "[Pro Shop] Portals open! Shatt, SW, IF, Org, UC & more. Fast service, tips welcome! PST!",
        "[Pro Shop] Need a portal? Mage LFW! All TBC destinations available. PST your city!",
    },
    ["Summons"] = {
        "[Pro Shop] Warlock available for summons! Need 2 clickers at destination. Tips appreciated! PST!",
        "[Pro Shop] Summon service! Get where you need to be fast. Need 2 helpers at location. PST!",
        "[Pro Shop] Need a summon? Warlock LFW! 2 people needed at destination. Tips welcome! PST!",
    },
}

------------------------------------------------------------------------
-- Lockbox tiers ordered by required skill (highest first for ad display)
------------------------------------------------------------------------
local LOCKBOX_TIERS = {
    { name = "Khorium",    skill = 325 },
    { name = "Felsteel",   skill = 300 },
    { name = "Adamantite", skill = 275 },
    { name = "Eternium",   skill = 225 },
    { name = "Thorium",    skill = 225 },
    { name = "Mithril",    skill = 175 },
}

------------------------------------------------------------------------
-- Build a lockpicking ad based on actual skill level
------------------------------------------------------------------------
function PS:BuildLockpickingAd()
    local profData = self.professions["Lockpicking"]
    if not profData then return nil end

    local skill = profData.skill or 0

    -- Collect lockboxes we can actually open
    local canOpen = {}
    for _, tier in ipairs(LOCKBOX_TIERS) do
        if skill >= tier.skill then
            table.insert(canOpen, tier.name)
        end
    end

    if #canOpen == 0 then
        return "[Pro Shop] Rogue lockpicking (" .. skill .. ") LFW! Tips welcome! PST!"
    end

    -- Build a list of the top boxes we can open (up to 4 for brevity)
    local displayBoxes = {}
    for i = 1, math.min(4, #canOpen) do
        table.insert(displayBoxes, canOpen[i])
    end

    local boxList = table.concat(displayBoxes, ", ")
    local suffix = #canOpen > #displayBoxes and " & more" or ""

    return "[Pro Shop] Rogue lockpicking (" .. skill .. ") LFW! " .. boxList .. suffix .. " lockboxes. Tips welcome! PST!"
end

------------------------------------------------------------------------
-- Build a default text ad for a profession
-- User can override with custom ads that include their own shift-clicked links.
------------------------------------------------------------------------
function PS:BuildProfessionAd(profession)
    local profData = self.professions[profession]
    if not profData then return nil end

    local skillLevel = profData.skill or "?"
    local recipeCount = profData.numRecipes or 0

    if recipeCount > 0 then
        return "[Pro Shop] " .. profession .. " (" .. skillLevel .. ") LFW! " .. recipeCount .. " recipes, your mats. Tips welcome! PST!"
    else
        return "[Pro Shop] " .. profession .. " (" .. skillLevel .. ") LFW! PST with what you need!"
    end
end

------------------------------------------------------------------------
-- Generate the DEFAULT ad for a profession (ignoring custom messages)
-- Used by the UI to show what you'd get without a custom override.
------------------------------------------------------------------------
function PS:GenerateDefaultAd(profession)
    if not self.professions[profession] then return nil end

    if profession == "Lockpicking" then
        return self:BuildLockpickingAd()
    elseif self.STATIC_AD_TEMPLATES[profession] then
        return self.STATIC_AD_TEMPLATES[profession][1]
    else
        return self:BuildProfessionAd(profession)
    end
end

------------------------------------------------------------------------
-- Generate an ad message for a specific profession
------------------------------------------------------------------------
function PS:GenerateAdForProfession(profession)
    if not self.professions[profession] then return nil end

    local msg

    -- Custom message takes priority
    if self.db.advertise.messages[profession] and self.db.advertise.messages[profession] ~= "" then
        msg = self.db.advertise.messages[profession]
    elseif profession == "Lockpicking" then
        -- Dynamic lockpicking ad based on actual skill level
        msg = self:BuildLockpickingAd()
    elseif self.STATIC_AD_TEMPLATES[profession] then
        -- Static templates for non-recipe services
        local templates = self.STATIC_AD_TEMPLATES[profession]
        if not self.db.advertise.profAdIndex then
            self.db.advertise.profAdIndex = {}
        end
        if self.db.advertise.rotateMessages then
            self.db.advertise.profAdIndex[profession] = (self.db.advertise.profAdIndex[profession] or 0) + 1
            if self.db.advertise.profAdIndex[profession] > #templates then
                self.db.advertise.profAdIndex[profession] = 1
            end
            msg = templates[self.db.advertise.profAdIndex[profession]]
        else
            msg = templates[math.random(#templates)]
        end
    else
        -- Link-based ad - profession link IS the ad
        msg = self:BuildProfessionAd(profession)
    end

    if not msg then return nil end

    return msg
end

-- Legacy single-message generator (used by Preview)
function PS:GenerateAdMessage()
    -- Find the first active profession and generate for it
    for profession, _ in pairs(self.professions) do
        if self:IsProfessionAdActive(profession) then
            local msg = self:GenerateAdForProfession(profession)
            if msg then return msg end
        end
    end
    return nil
end

-- Default exclusion list for non-service professions
local EXCLUDED_PROFESSIONS = { ["Mining"] = true, ["Herbalism"] = true, ["Skinning"] = true, ["Fishing"] = true, ["First Aid"] = true }

-- Check if a profession is enabled GLOBALLY (monitoring, auto-invite, whispers)
-- Controlled from the General tab
function PS:IsProfessionActive(profession)
    if self.db.activeProfessions and next(self.db.activeProfessions) then
        local val = self.db.activeProfessions[profession]
        if val ~= nil then return val end
        -- Not in the saved table yet: default to active for non-excluded profs
    end
    -- Default: all detected non-gathering profs are active
    if EXCLUDED_PROFESSIONS[profession] then return false end
    return self.professions[profession] ~= nil
end

-- Check if a profession is enabled for ADVERTISING (broadcast buttons)
-- Controlled from the Advertise tab. Must also be globally active.
function PS:IsProfessionAdActive(profession)
    -- Must be globally active first
    if not self:IsProfessionActive(profession) then return false end
    -- Then check ad-specific toggle
    if self.db.advertise.activeProfessions and next(self.db.advertise.activeProfessions) then
        local val = self.db.advertise.activeProfessions[profession]
        if val ~= nil then return val end
        -- Not in the saved table: follow global active state
    end
    -- Default: all globally-active professions also advertise
    return true
end

-- Get list of active professions for advertising
function PS:GetActiveAdProfessions()
    local active = {}
    for profession, _ in pairs(self.professions) do
        if self:IsProfessionAdActive(profession) then
            table.insert(active, profession)
        end
    end
    table.sort(active)
    return active
end

------------------------------------------------------------------------
-- Broadcast ad - sends one profession ad per click, rotating
------------------------------------------------------------------------
function PS:BroadcastAd()
    if not self.db.enabled then
        self:Print(C.RED .. "Addon is disabled." .. C.R)
        return
    end

    -- Find the trade channel
    local channelNum = self:GetTradeChannelNum()
    if not channelNum then
        self:Print(C.RED .. "Trade channel not found! Are you in a city?" .. C.R)
        return
    end

    local activeProfessions = self:GetActiveAdProfessions()
    if #activeProfessions == 0 then
        self:Print(C.RED .. "No active professions for advertising. Check your Advertise tab settings!" .. C.R)
        return
    end

    -- Rotate to the next profession
    self.db.advertise.lastBroadcastIndex = (self.db.advertise.lastBroadcastIndex or 0) + 1
    if self.db.advertise.lastBroadcastIndex > #activeProfessions then
        self.db.advertise.lastBroadcastIndex = 1
    end

    local profession = activeProfessions[self.db.advertise.lastBroadcastIndex]
    local msg = self:GenerateAdForProfession(profession)

    if msg then
        SendChatMessage(msg, "CHANNEL", nil, channelNum)
        self:Print(C.GREEN .. "Ad sent for " .. C.CYAN .. profession .. C.R .. C.GREEN .. "!" .. C.R)
        self:Debug("Ad [" .. profession .. "]: " .. msg)
    else
        self:Print(C.RED .. "No ad message available for " .. profession .. "." .. C.R)
    end
end

-- Helper to find trade channel number
function PS:GetTradeChannelNum()
    local channelName = self.db.advertise.channel or "Trade"
    local channelNum = GetChannelName(channelName)

    if not channelNum or channelNum == 0 then
        local tryNames = { "Trade", "Trade - City", "2" }
        for _, name in ipairs(tryNames) do
            channelNum = GetChannelName(name)
            if channelNum and channelNum > 0 then
                return channelNum
            end
        end
        return nil
    end

    return channelNum
end

------------------------------------------------------------------------
-- Broadcast all active profession ads at once (called from button)
------------------------------------------------------------------------
function PS:BroadcastAllAds()
    if not self.db.enabled then
        self:Print(C.RED .. "Addon is disabled." .. C.R)
        return
    end

    local channelNum = self:GetTradeChannelNum()
    if not channelNum then
        self:Print(C.RED .. "Trade channel not found! Are you in a city?" .. C.R)
        return
    end

    local activeProfessions = self:GetActiveAdProfessions()
    if #activeProfessions == 0 then
        self:Print(C.RED .. "No active professions for advertising." .. C.R)
        return
    end

    local sent = 0
    for _, profession in ipairs(activeProfessions) do
        local msg = self:GenerateAdForProfession(profession)
        if msg then
            SendChatMessage(msg, "CHANNEL", nil, channelNum)
            sent = sent + 1
            self:Debug("Ad [" .. profession .. "]: " .. msg)
        end
    end

    if sent > 0 then
        self:Print(C.GREEN .. "Sent " .. sent .. " ad(s) to trade chat!" .. C.R)
    else
        self:Print(C.RED .. "No ad messages available." .. C.R)
    end
end

------------------------------------------------------------------------
-- Broadcast a single profession ad  (called from quick ad bar)
------------------------------------------------------------------------
function PS:BroadcastSingleAd(profession)
    if not self.db.enabled then
        self:Print(C.RED .. "Addon is disabled." .. C.R)
        return
    end

    local channelNum = self:GetTradeChannelNum()
    if not channelNum then
        self:Print(C.RED .. "Trade channel not found! Are you in a city?" .. C.R)
        return
    end

    local msg = self:GenerateAdForProfession(profession)
    if msg then
        SendChatMessage(msg, "CHANNEL", nil, channelNum)
        self:Print(C.GREEN .. "Ad sent for " .. C.CYAN .. profession .. C.R .. C.GREEN .. "!" .. C.R)
    else
        self:Print(C.RED .. "No ad message for " .. profession .. "." .. C.R)
    end
end

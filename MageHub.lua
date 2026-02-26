------------------------------------------------------------------------
-- Pro Shop - Mage Hub (collapsible sections inside dashboard)
-- Portals, Food, Water buttons + active portal bars + reagent count
-- Uses SecureActionButtonTemplate for protected spell casting
------------------------------------------------------------------------
local _, PS = ...
local C = PS.C

------------------------------------------------------------------------
-- Data: Portal spells, Food ranks, Water ranks (TBC Classic)
------------------------------------------------------------------------
local ALLIANCE_PORTALS = {
    { spellID = 10059, label = "SW",    dest = "Stormwind" },
    { spellID = 11416, label = "IF",    dest = "Ironforge" },
    { spellID = 11419, label = "Darn",  dest = "Darnassus" },
    { spellID = 32266, label = "Exo",   dest = "Exodar" },
    { spellID = 49360, label = "Thera", dest = "Theramore" },
    { spellID = 33691, label = "Shatt", dest = "Shattrath" },
}

local HORDE_PORTALS = {
    { spellID = 11417, label = "Org",   dest = "Orgrimmar" },
    { spellID = 11418, label = "UC",    dest = "Undercity" },
    { spellID = 11420, label = "TB",    dest = "Thunder Bluff" },
    { spellID = 32267, label = "SM",    dest = "Silvermoon" },
    { spellID = 49361, label = "Ston",  dest = "Stonard" },
    { spellID = 35717, label = "Shatt", dest = "Shattrath" },
}

local CONJURE_FOOD = {
    { rank = 1, trainLevel = 1,  label = "L1",  useLevel = 1,  item = "Conjured Muffins" },
    { rank = 2, trainLevel = 6,  label = "L5",  useLevel = 5,  item = "Conjured Bread" },
    { rank = 3, trainLevel = 14, label = "L15", useLevel = 15, item = "Conjured Rye" },
    { rank = 4, trainLevel = 22, label = "L25", useLevel = 25, item = "Conjured Pumpernickel" },
    { rank = 5, trainLevel = 30, label = "L35", useLevel = 35, item = "Conjured Sourdough" },
    { rank = 6, trainLevel = 38, label = "L45", useLevel = 45, item = "Conjured Sweet Roll" },
    { rank = 7, trainLevel = 46, label = "L55", useLevel = 55, item = "Conjured Cinnamon Roll" },
    { rank = 8, trainLevel = 56, label = "L65", useLevel = 65, item = "Conjured Croissant" },
}

local CONJURE_WATER = {
    { rank = 1, trainLevel = 1,  label = "L1",  useLevel = 1,  item = "Conjured Water" },
    { rank = 2, trainLevel = 6,  label = "L5",  useLevel = 5,  item = "Conjured Fresh Water" },
    { rank = 3, trainLevel = 14, label = "L15", useLevel = 15, item = "Conjured Purified Water" },
    { rank = 4, trainLevel = 22, label = "L25", useLevel = 25, item = "Conjured Spring Water" },
    { rank = 5, trainLevel = 30, label = "L35", useLevel = 35, item = "Conjured Mineral Water" },
    { rank = 6, trainLevel = 38, label = "L45", useLevel = 45, item = "Conjured Sparkling Water" },
    { rank = 7, trainLevel = 46, label = "L55", useLevel = 55, item = "Conjured Crystal Water" },
    { rank = 8, trainLevel = 54, label = "L60", useLevel = 60, item = "Conjured Mountain Spring Water" },
    { rank = 9, trainLevel = 62, label = "L65", useLevel = 65, item = "Conjured Glacier Water" },
}

------------------------------------------------------------------------
-- Scan spellbook to build a map of spellID -> castable "Name(Rank N)"
------------------------------------------------------------------------
local function BuildSpellbookMap()
    local byID = {}
    local byName = {}  -- maps "SpellName" -> { [rank] = castName }
    local i = 1
    while true do
        local spellName, spellRank = GetSpellBookItemName(i, "spell")
        if not spellName then break end

        local _, spellID = GetSpellBookItemInfo(i, "spell")
        local castName
        if spellRank and spellRank ~= "" then
            castName = spellName .. "(" .. spellRank .. ")"
        else
            castName = spellName
        end

        if spellID then
            byID[spellID] = castName
        end

        -- Also index by name+rank for fallback matching
        if not byName[spellName] then byName[spellName] = {} end
        local rankNum = spellRank and tonumber(spellRank:match("(%d+)"))
        if rankNum then
            byName[spellName][rankNum] = castName
        elseif not byName[spellName][0] then
            byName[spellName][0] = castName
        end

        i = i + 1
    end
    return byID, byName
end

-- Spell name bases for fallback matching
local CONJURE_FOOD_NAME  = "Conjure Food"
local CONJURE_WATER_NAME = "Conjure Water"
local PORTAL_NAMES = {
    [10059] = "Portal: Stormwind",   [11416] = "Portal: Ironforge",
    [11419] = "Portal: Darnassus",   [32266] = "Portal: Exodar",
    [49360] = "Portal: Theramore",   [33691] = "Portal: Shattrath",
    [11417] = "Portal: Orgrimmar",   [11418] = "Portal: Undercity",
    [11420] = "Portal: Thunder Bluff", [32267] = "Portal: Silvermoon",
    [49361] = "Portal: Stonard",     [35717] = "Portal: Shattrath",
}

------------------------------------------------------------------------
-- Section layout constants
------------------------------------------------------------------------
local SEC_BTN_H     = 20
local SEC_BTN_PAD   = 2
local SEC_HEADER_H  = 18
local SEC_PAD       = 4
local PER_ROW       = 4
local PORTAL_BAR_H  = 14
local MAX_BARS      = 6
local RUNE_TELEPORT = 17031
local RUNE_PORTAL   = 17032

------------------------------------------------------------------------
-- Create collapsible mage sections inside the dashboard
------------------------------------------------------------------------
function PS:CreateMageSections()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "MAGE" then return end
    if self.mageSections then return end

    local f  = self.toggleFrame
    local df = f and f.dashFrame
    if not f or not df then return end

    local COL_W   = f.COL_W or 280
    local contentW = COL_W - 20
    local hubPane  = df.hubPane
    if not hubPane then return end

    -- Ensure db defaults
    if not self.db.mageCollapsed then
        self.db.mageCollapsed = {}
    end

    -- Determine faction portals
    local faction    = UnitFactionGroup("player")
    local portalList = (faction == "Alliance") and ALLIANCE_PORTALS or HORDE_PORTALS

    -- Scan spellbook for exact ranked spell names
    local spellMap, spellByName = BuildSpellbookMap()

    local knownPortals = {}
    for _, p in ipairs(portalList) do
        local castName = spellMap[p.spellID]
        -- Fallback: try matching portal by name
        if not castName and PORTAL_NAMES[p.spellID] then
            local portalName = PORTAL_NAMES[p.spellID]
            if spellByName[portalName] then
                -- Portal spells have no rank, use rank 0
                castName = spellByName[portalName][0]
            end
        end
        if castName then
            table.insert(knownPortals, { castName = castName, label = p.label, dest = p.dest })
        end
    end

    -- Build food/water lists directly from rank numbers (spellbook only shows
    -- the highest rank in Anniversary Classic, so we construct cast names ourselves)
    local playerLevel = UnitLevel("player") or 70

    local knownFood = {}
    for _, fd in ipairs(CONJURE_FOOD) do
        if playerLevel >= fd.trainLevel then
            local castName = "Conjure Food(Rank " .. fd.rank .. ")"
            table.insert(knownFood, { castName = castName, label = fd.label, useLevel = fd.useLevel, item = fd.item })
        end
    end

    local knownWater = {}
    for _, w in ipairs(CONJURE_WATER) do
        if playerLevel >= w.trainLevel then
            local castName = "Conjure Water(Rank " .. w.rank .. ")"
            table.insert(knownWater, { castName = castName, label = w.label, useLevel = w.useLevel, item = w.item })
        end
    end

    ---------------------------------------------------------------------------
    -- Helper: create secure spell buttons inside a container
    ---------------------------------------------------------------------------
    local btnCounter = 0
    local function CreateSpellButtons(parent, spells, startY)
        local btnW = math.floor((contentW - (PER_ROW - 1) * SEC_BTN_PAD) / PER_ROW)
        for idx, info in ipairs(spells) do
            btnCounter = btnCounter + 1
            local col = (idx - 1) % PER_ROW
            local row = math.floor((idx - 1) / PER_ROW)

            local btn = CreateFrame("Button", "PSMage" .. btnCounter, parent, "SecureActionButtonTemplate")
            btn:SetSize(btnW, SEC_BTN_H)
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", col * (btnW + SEC_BTN_PAD), startY - row * (SEC_BTN_H + SEC_BTN_PAD))
            btn:RegisterForClicks("AnyUp", "AnyDown")

            btn:SetNormalFontObject(GameFontNormalSmall)
            btn:SetHighlightFontObject(GameFontHighlightSmall)
            btn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
            btn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
            btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
            btn:GetNormalTexture():SetTexCoord(0, 0.625, 0, 0.6875)
            btn:GetPushedTexture():SetTexCoord(0, 0.625, 0, 0.6875)

            btn:SetText(info.label)

            -- Food/water: left-click casts, right-click adds 2 stacks, middle-click adds 3
            if info.item then
                btn:SetAttribute("type1", "macro")
                btn:SetAttribute("macrotext1", "/cast " .. info.castName)
                -- Clear right/middle from secure handler so PostClick can handle them
                btn:SetAttribute("type2", "")
                btn:SetAttribute("type3", "")

                btn:SetScript("PostClick", function(self, mouseButton, isDown)
                    if isDown then return end
                    local maxStacks
                    if mouseButton == "RightButton" then
                        maxStacks = 2
                    elseif mouseButton == "MiddleButton" then
                        maxStacks = 3
                    else
                        return
                    end
                    if not TradeFrame or not TradeFrame:IsShown() then
                        PS:Print(PS.C.YELLOW .. "Open a trade window first!" .. PS.C.R)
                        return
                    end
                    ClearCursor()
                    local itemName = info.item
                    local matchStr = "[" .. itemName .. "]"

                    -- Collect all bag slots containing this exact item
                    local stacks = {}
                    for bag = 0, 4 do
                        local numSlots = C_Container.GetContainerNumSlots(bag)
                        for slot = 1, numSlots do
                            local cInfo = C_Container.GetContainerItemInfo(bag, slot)
                            if cInfo and cInfo.hyperlink and cInfo.hyperlink:find(matchStr, 1, true) then
                                table.insert(stacks, { bag = bag, slot = slot })
                            end
                        end
                    end

                    if #stacks == 0 then
                        PS:Print(PS.C.RED .. "No " .. itemName .. " found in bags." .. PS.C.R)
                        return
                    end

                    -- Place up to maxStacks into the next available trade slots
                    local placed = 0
                    local stackIdx = 1
                    for ti = 1, 6 do
                        if placed >= maxStacks or stackIdx > #stacks then break end
                        local link = GetTradePlayerItemLink(ti)
                        if not link then
                            local s = stacks[stackIdx]
                            ClearCursor()
                            C_Container.PickupContainerItem(s.bag, s.slot)
                            ClickTradeButton(ti)
                            placed = placed + 1
                            stackIdx = stackIdx + 1
                        end
                    end

                    if placed > 0 then
                        PS:Print(PS.C.GREEN .. "Added " .. placed .. "x " .. itemName .. " to trade." .. PS.C.R)
                    else
                        PS:Print(PS.C.RED .. "All trade slots full!" .. PS.C.R)
                    end
                end)
            else
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/cast " .. info.castName)
            end

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local tip = info.castName
                if info.item then
                    -- Count all matching stacks across all bags (exact match via [ItemName])
                    local count = 0
                    local matchStr = "[" .. info.item .. "]"
                    for bag = 0, 4 do
                        local numSlots = C_Container.GetContainerNumSlots(bag)
                        for slot = 1, numSlots do
                            local cInfo = C_Container.GetContainerItemInfo(bag, slot)
                            if cInfo and cInfo.hyperlink and cInfo.hyperlink:find(matchStr, 1, true) then
                                count = count + (cInfo.stackCount or 1)
                            end
                        end
                    end
                    local clr = count > 0 and "|cff00ff00" or "|cffff4444"
                    tip = tip .. "\n|cffffffff" .. info.item .. "|r  " .. clr .. count .. " in bags|r"
                    tip = tip .. "\n|cff00ff00Right-click: add 2 stacks to trade|r"
                    tip = tip .. "\n|cff00bbffMiddle-click: add 3 stacks to trade|r"
                end
                if info.useLevel then
                    tip = tip .. "\n|cff888888Usable at level " .. info.useLevel .. "+|r"
                elseif info.dest then
                    tip = tip .. "\n|cff888888" .. info.dest .. "|r"
                end
                GameTooltip:SetText(tip)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        local rows = math.ceil(#spells / PER_ROW)
        return rows * (SEC_BTN_H + SEC_BTN_PAD)
    end

    ---------------------------------------------------------------------------
    -- Helper: find the best food/water item name for a given player level
    ---------------------------------------------------------------------------
    local function GetBestFoodForLevel(level)
        local best = nil
        for _, fd in ipairs(CONJURE_FOOD) do
            if fd.useLevel <= level then best = fd.item end
        end
        return best
    end

    local function GetBestWaterForLevel(level)
        local best = nil
        for _, w in ipairs(CONJURE_WATER) do
            if w.useLevel <= level then best = w.item end
        end
        return best
    end

    ---------------------------------------------------------------------------
    -- Helper: add N stacks of an item to the next available trade slots
    ---------------------------------------------------------------------------
    local function AddItemToTrade(itemName, count)
        if not TradeFrame or not TradeFrame:IsShown() then
            PS:Print(PS.C.YELLOW .. "Open a trade window first!" .. PS.C.R)
            return 0
        end
        ClearCursor()
        local matchStr = "[" .. itemName .. "]"

        -- Collect all bag slots with this item
        local stacks = {}
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local cInfo = C_Container.GetContainerItemInfo(bag, slot)
                if cInfo and cInfo.hyperlink and cInfo.hyperlink:find(matchStr, 1, true) then
                    table.insert(stacks, { bag = bag, slot = slot })
                end
            end
        end

        local placed = 0
        local stackIdx = 1
        for ti = 1, 6 do
            if placed >= count or stackIdx > #stacks then break end
            local link = GetTradePlayerItemLink(ti)
            if not link then
                local s = stacks[stackIdx]
                ClearCursor()
                C_Container.PickupContainerItem(s.bag, s.slot)
                ClickTradeButton(ti)
                placed = placed + 1
                stackIdx = stackIdx + 1
            end
        end
        return placed
    end

    ---------------------------------------------------------------------------
    -- Helper: get the trade partner's level (from queue data or UnitLevel)
    ---------------------------------------------------------------------------
    local function GetTradePartnerLevel()
        local partnerName = UnitName("NPC")
        local level = UnitLevel("NPC")
        -- If UnitLevel fails or returns 0, try queue data
        if (not level or level <= 0) and partnerName then
            local customer = PS:GetQueuedCustomer(partnerName)
            if customer and customer.level and customer.level > 0 then
                level = customer.level
            end
        end
        return level, partnerName
    end

    ---------------------------------------------------------------------------
    -- Trade Food / Trade Water buttons at the top of the hub
    ---------------------------------------------------------------------------
    local TRADE_BTN_W = math.floor((contentW - 4) / 2)
    local TRADE_BTN_H = 24

    local tradeFoodBtn = CreateFrame("Button", nil, hubPane, "UIPanelButtonTemplate")
    tradeFoodBtn:SetSize(TRADE_BTN_W, TRADE_BTN_H)
    tradeFoodBtn:SetPoint("TOPLEFT", hubPane, "TOPLEFT", 10, 0)
    tradeFoodBtn:SetText("Trade Food")
    tradeFoodBtn:SetNormalFontObject(GameFontNormalSmall)
    tradeFoodBtn:SetHighlightFontObject(GameFontHighlightSmall)
    tradeFoodBtn:SetScript("OnClick", function()
        local level, name = GetTradePartnerLevel()
        if not level or level <= 0 then
            PS:Print(PS.C.RED .. "Can't determine trade partner's level. Open trade first!" .. PS.C.R)
            return
        end
        local itemName = GetBestFoodForLevel(level)
        if not itemName then
            PS:Print(PS.C.RED .. "No suitable food for level " .. level .. "." .. PS.C.R)
            return
        end
        local placed = AddItemToTrade(itemName, 3)
        if placed > 0 then
            PS:Print(PS.C.GREEN .. "Added " .. placed .. "x " .. itemName .. " for " .. (name or "partner") .. " (L" .. level .. ")." .. PS.C.R)
        else
            PS:Print(PS.C.RED .. "No " .. itemName .. " in bags!" .. PS.C.R)
        end
    end)
    tradeFoodBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        local level, name = GetTradePartnerLevel()
        local tip = "|cffffffffTrade Food|r\nAdds 3 stacks of the best food\nfor the trade partner's level."
        if level and level > 0 then
            local itemName = GetBestFoodForLevel(level)
            tip = tip .. "\n\n|cff00ff00" .. (name or "Partner") .. " (L" .. level .. ")|r"
            if itemName then tip = tip .. "\n|cffffffff" .. itemName .. "|r" end
        else
            tip = tip .. "\n\n|cffff4444Open trade to see partner level|r"
        end
        GameTooltip:SetText(tip)
        GameTooltip:Show()
    end)
    tradeFoodBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local tradeWaterBtn = CreateFrame("Button", nil, hubPane, "UIPanelButtonTemplate")
    tradeWaterBtn:SetSize(TRADE_BTN_W, TRADE_BTN_H)
    tradeWaterBtn:SetPoint("TOPLEFT", tradeFoodBtn, "TOPRIGHT", 4, 0)
    tradeWaterBtn:SetText("Trade Water")
    tradeWaterBtn:SetNormalFontObject(GameFontNormalSmall)
    tradeWaterBtn:SetHighlightFontObject(GameFontHighlightSmall)
    tradeWaterBtn:SetScript("OnClick", function()
        local level, name = GetTradePartnerLevel()
        if not level or level <= 0 then
            PS:Print(PS.C.RED .. "Can't determine trade partner's level. Open trade first!" .. PS.C.R)
            return
        end
        local itemName = GetBestWaterForLevel(level)
        if not itemName then
            PS:Print(PS.C.RED .. "No suitable water for level " .. level .. "." .. PS.C.R)
            return
        end
        local placed = AddItemToTrade(itemName, 3)
        if placed > 0 then
            PS:Print(PS.C.GREEN .. "Added " .. placed .. "x " .. itemName .. " for " .. (name or "partner") .. " (L" .. level .. ")." .. PS.C.R)
        else
            PS:Print(PS.C.RED .. "No " .. itemName .. " in bags!" .. PS.C.R)
        end
    end)
    tradeWaterBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        local level, name = GetTradePartnerLevel()
        local tip = "|cffffffffTrade Water|r\nAdds 3 stacks of the best water\nfor the trade partner's level."
        if level and level > 0 then
            local itemName = GetBestWaterForLevel(level)
            tip = tip .. "\n\n|cff00ff00" .. (name or "Partner") .. " (L" .. level .. ")|r"
            if itemName then tip = tip .. "\n|cffffffff" .. itemName .. "|r" end
        else
            tip = tip .. "\n\n|cffff4444Open trade to see partner level|r"
        end
        GameTooltip:SetText(tip)
        GameTooltip:Show()
    end)
    tradeWaterBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Store reference for layout offset
    self._tradeBtnsH = TRADE_BTN_H + 4

    ---------------------------------------------------------------------------
    -- Build sections table
    ---------------------------------------------------------------------------
    local sections = {}

    --------------- PORTALS SECTION ---------------
    if #knownPortals > 0 then
        local sec = { key = "portals", title = "PORTALS" }

        local cont = CreateFrame("Frame", nil, hubPane)
        sec.content = cont
        local btnH = CreateSpellButtons(cont, knownPortals, 0)

        -- Active portal bars
        local barsTop = -btnH - 2

        local noText = cont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noText:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, barsTop)
        noText:SetText("|cff666666No active portals|r")
        sec.noActiveText = noText

        sec.portalBars = {}
        for idx = 1, MAX_BARS do
            local bar = CreateFrame("StatusBar", nil, cont)
            bar:SetSize(contentW, PORTAL_BAR_H)
            bar:SetPoint("TOPLEFT", cont, "TOPLEFT", 0, barsTop - (idx - 1) * (PORTAL_BAR_H + 2))
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetStatusBarColor(0.5, 0.2, 0.9, 0.8)
            bar:SetMinMaxValues(0, PS.PORTAL_DURATION)

            local bg = bar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

            local lbl = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", 4, 0)
            lbl:SetJustifyH("LEFT")
            bar.label = lbl

            local tt = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tt:SetPoint("RIGHT", -4, 0)
            tt:SetJustifyH("RIGHT")
            bar.timeText = tt

            bar:Hide()
            sec.portalBars[idx] = bar
        end

        -- Reagent count line
        local reagentText = cont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        reagentText:SetWidth(contentW)
        reagentText:SetJustifyH("LEFT")
        sec.reagentText = reagentText

        -- Store btnH for dynamic layout calculations
        sec._btnH = btnH
        sec._barsTop = barsTop

        -- Calculate base content height (buttons + "None" + reagent + padding)
        sec.contentH = btnH + 2 + 16 + 2 + 14 + 2

        -- UpdatePortalBars: repositions bars and recalculates content height
        function sec:UpdatePortalBars()
            local now = GetTime()
            local barIdx = 0

            for portalSpell, castTime in pairs(PS.activePortals) do
                local elapsed = now - castTime
                local remaining = PS.PORTAL_DURATION - elapsed
                if remaining > 0 then
                    barIdx = barIdx + 1
                    if barIdx > MAX_BARS then break end

                    local bar = self.portalBars[barIdx]
                    bar:SetValue(remaining)

                    if remaining > 30 then
                        bar:SetStatusBarColor(0.2, 0.8, 0.2, 0.8)
                    elseif remaining > 10 then
                        bar:SetStatusBarColor(0.9, 0.7, 0.1, 0.8)
                    else
                        bar:SetStatusBarColor(0.9, 0.2, 0.2, 0.8)
                    end

                    local dest = portalSpell:gsub("Portal: ", "")
                    bar.label:SetText("|cffffffff" .. dest .. "|r")
                    bar.timeText:SetText("|cffffffff" .. math.floor(remaining) .. "s|r")
                    bar:Show()
                end
            end

            for j = barIdx + 1, MAX_BARS do
                self.portalBars[j]:Hide()
            end

            self.noActiveText:SetShown(barIdx == 0)

            -- Reposition reagent text
            local barsH = barIdx > 0 and (barIdx * (PORTAL_BAR_H + 2)) or 16
            self.reagentText:ClearAllPoints()
            self.reagentText:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, self._barsTop - barsH - 2)

            -- Recalculate content height
            local newH = self._btnH + 2 + barsH + 2 + 14 + 2
            if newH ~= self.contentH then
                self.contentH = newH
                PS:RefreshMageLayout()
            end
        end

        function sec:UpdateReagents()
            local teleCount = GetItemCount(RUNE_TELEPORT) or 0
            local portCount = GetItemCount(RUNE_PORTAL) or 0
            local tc = teleCount > 5 and "|cff00ff00" or (teleCount > 0 and "|cffffff00" or "|cffff4444")
            local pc = portCount > 5 and "|cff00ff00" or (portCount > 0 and "|cffffff00" or "|cffff4444")
            self.reagentText:SetText(
                pc .. "Portals: " .. portCount .. "|r  " ..
                tc .. "Teleport: " .. teleCount .. "|r"
            )
        end

        sec:UpdateReagents()
        table.insert(sections, sec)
    end

    --------------- FOOD SECTION ---------------
    if #knownFood > 0 then
        local sec = { key = "food", title = "FOOD" }
        local cont = CreateFrame("Frame", nil, hubPane)
        sec.content = cont

        local btnH = CreateSpellButtons(cont, knownFood, 0)
        sec.contentH = btnH
        table.insert(sections, sec)
    end

    --------------- WATER SECTION ---------------
    if #knownWater > 0 then
        local sec = { key = "water", title = "WATER" }
        local cont = CreateFrame("Frame", nil, hubPane)
        sec.content = cont

        local btnH = CreateSpellButtons(cont, knownWater, 0)
        sec.contentH = btnH
        table.insert(sections, sec)
    end

    ---------------------------------------------------------------------------
    -- Create section headers (clickable toggle buttons)
    ---------------------------------------------------------------------------
    for _, sec in ipairs(sections) do
        local hdr = CreateFrame("Button", nil, hubPane)
        hdr:SetSize(contentW, SEC_HEADER_H)
        hdr:EnableMouse(true)
        hdr:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        local arrow = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("LEFT", 2, 0)
        hdr.arrow = arrow

        local label = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", 14, 0)
        label:SetText("|cffd4a017" .. sec.title .. "|r")
        hdr.label = label

        local line = hdr:CreateTexture(nil, "OVERLAY")
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", 0, 0)
        line:SetColorTexture(0.4, 0.3, 0.7, 0.4)

        hdr:SetScript("OnClick", function()
            if InCombatLockdown() then
                PS:Print(C.RED .. "Can't toggle sections in combat." .. C.R)
                return
            end
            PS.db.mageCollapsed[sec.key] = not PS.db.mageCollapsed[sec.key]
            PS:RefreshMageLayout()
        end)

        sec.header = hdr
    end

    ---------------------------------------------------------------------------
    -- Store reference & register events
    ---------------------------------------------------------------------------
    self.mageSections = sections

    -- BAG_UPDATE for reagent count
    if not self._mageEventFrame then
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("BAG_UPDATE")
        ef:SetScript("OnEvent", function()
            if PS.mageSections then
                for _, sec in ipairs(PS.mageSections) do
                    if sec.UpdateReagents then sec:UpdateReagents() end
                end
            end
        end)
        self._mageEventFrame = ef
    end

    -- OnUpdate ticker for portal bars (hooked onto the dashFrame)
    local portalElapsed = 0
    if not df._mageOnUpdate then
        df:HookScript("OnUpdate", function(_, dt)
            portalElapsed = portalElapsed + dt
            if portalElapsed < 0.2 then return end
            portalElapsed = 0
            if PS.mageSections then
                for _, sec in ipairs(PS.mageSections) do
                    if sec.UpdatePortalBars and not PS.db.mageCollapsed[sec.key] then
                        sec:UpdatePortalBars()
                    end
                end
            end
        end)
        df._mageOnUpdate = true
    end

    -- Initial layout
    self:RefreshMageLayout()
end

------------------------------------------------------------------------
-- Reposition all mage sections & recalculate hub pane height
------------------------------------------------------------------------
function PS:RefreshMageLayout()
    if not self.mageSections then return end

    local f  = self.toggleFrame
    local df = f and f.dashFrame
    if not f or not df then return end
    local hubPane = df.hubPane
    if not hubPane then return end

    local COL_W   = f.COL_W or 280
    local y = -(self._tradeBtnsH or 0)

    for _, sec in ipairs(self.mageSections) do
        local collapsed = self.db.mageCollapsed[sec.key]

        -- Position header
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT", hubPane, "TOPLEFT", 10, y)
        sec.header.arrow:SetText(collapsed and "|cffaaaaaa>|r" or "|cffaaaaaav|r")

        y = y - SEC_HEADER_H

        -- Show or hide content
        if not collapsed then
            sec.content:ClearAllPoints()
            sec.content:SetPoint("TOPLEFT", hubPane, "TOPLEFT", 10, y)
            sec.content:SetSize(COL_W - 20, sec.contentH)
            sec.content:Show()
            y = y - sec.contentH
        else
            sec.content:Hide()
        end

        y = y - SEC_PAD
    end

    -- Store hub pane height for window sizing
    local hubH = math.abs(y) + 4
    self._hubPaneH = hubH

    -- Resize window to fit tallest column
    PS:ResizeWindow()
end

------------------------------------------------------------------------
-- Called from Professions.lua when a portal is cast
------------------------------------------------------------------------
function PS:RefreshMagePortalBars()
    if not self.mageSections then return end
    for _, sec in ipairs(self.mageSections) do
        if sec.UpdatePortalBars then
            sec:UpdatePortalBars()
        end
        if sec.UpdateReagents then
            sec:UpdateReagents()
        end
    end
end

------------------------------------------------------------------------
-- Pro Shop - Queue
-- Customer queue management, whisper response handling, tip tracking
------------------------------------------------------------------------
local _, PS = ...
local C = PS.C

------------------------------------------------------------------------
-- Queue State Constants
------------------------------------------------------------------------
PS.STATE = {
    DETECTED       = "DETECTED",
    INVITED        = "INVITED",
    WHISPERED      = "WHISPERED",
    WAITING_MATS   = "WAITING_MATS",
    HAS_MATS       = "HAS_MATS",
    NEEDS_MATS     = "NEEDS_MATS",
    IN_PROGRESS    = "IN_PROGRESS",
    COMPLETED      = "COMPLETED",
    BUSY_NOTIFIED  = "BUSY_NOTIFIED",
    LEFT_GROUP     = "LEFT_GROUP",
}

------------------------------------------------------------------------
-- Queue Lookup Helpers
------------------------------------------------------------------------
function PS:GetQueuedCustomer(playerName)
    local clean = Ambiguate(playerName, "short")
    for _, customer in ipairs(self.queue) do
        if customer.name == clean then
            return customer
        end
    end
    return nil
end

function PS:GetQueuePosition(playerName)
    local clean = Ambiguate(playerName, "short")
    for i, customer in ipairs(self.queue) do
        if customer.name == clean then
            return i
        end
    end
    return nil
end

function PS:IsInQueue(playerName)
    return self:GetQueuedCustomer(playerName) ~= nil
end

function PS:GetCurrentCustomer()
    for _, customer in ipairs(self.queue) do
        if customer.state == PS.STATE.IN_PROGRESS then
            return customer
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Queue Management
------------------------------------------------------------------------
function PS:RemoveFromQueue(playerName)
    local clean = Ambiguate(playerName, "short")
    for i, customer in ipairs(self.queue) do
        if customer.name == clean then
            table.remove(self.queue, i)
            self:RefreshEngagementPanel()
            return true
        end
    end
    return false
end

function PS:ClearQueue()
    self.queue = {}
    self:RefreshEngagementPanel()
end

function PS:ServeNextCustomer()
    -- Find the first non-completed, non-in-progress customer
    local current = self:GetCurrentCustomer()
    if current then
        self:Print(C.ORANGE .. "Already serving " .. C.WHITE .. current.name .. C.R ..
            ". Use " .. C.GREEN .. "/ps done" .. C.R .. " to finish.")
        return
    end

    for _, customer in ipairs(self.queue) do
        if customer.state ~= PS.STATE.COMPLETED and customer.state ~= PS.STATE.IN_PROGRESS then
            customer.state = PS.STATE.IN_PROGRESS
            customer.lastActivity = GetTime()
            self:Print(C.GREEN .. "Now serving: " .. C.WHITE .. customer.name .. C.R ..
                " - " .. C.CYAN .. customer.item .. C.R)

            -- Invite them to the group first
            self:InvitePlayer(customer.name)

            -- Then whisper after a short delay so the invite lands first
            local custName = customer.name
            C_Timer.After(1.5, function()
                SendChatMessage("Hey! I'm ready for your " .. (customer.item or "order") .. ". Accepting the group invite and open trade when you're here!",
                    "WHISPER", nil, custName)
            end)

            self:RefreshEngagementPanel()
            return
        end
    end

    self:Print(C.GRAY .. "No customers in queue." .. C.R)
end

function PS:CompleteCurrentCustomer()
    local current = self:GetCurrentCustomer()
    if not current then
        self:Print(C.GRAY .. "No customer currently being served." .. C.R)
        return
    end

    current.state = PS.STATE.COMPLETED
    self.customersServed = (self.customersServed or 0) + 1
    local name = current.name

    -- Auto-thank
    if self.db.queue.autoThank then
        self:WhisperCustomer(name, "thanks", { item = current.item })
    end

    -- Remove from queue
    self:RemoveFromQueue(name)

    self:Print(C.GREEN .. "Completed service for " .. C.WHITE .. name .. C.R .. "!")

    -- Auto-serve next if available
    if #self.queue > 0 then
        self:Print(C.GRAY .. #self.queue .. " more in queue. " .. C.GREEN .. "/ps next" .. C.R .. " to serve next.")
    end
end

------------------------------------------------------------------------
-- Queue Cleanup (remove stale entries)
------------------------------------------------------------------------
function PS:CleanupQueue()
    local now = GetTime()
    local timeout = self.db.queue.timeout or 600
    local removed = {}

    for i = #self.queue, 1, -1 do
        local customer = self.queue[i]
        if customer.state == PS.STATE.COMPLETED then
            table.insert(removed, customer.name)
            table.remove(self.queue, i)
        elseif customer.state == PS.STATE.LEFT_GROUP then
            -- Don't auto-remove bailed customers — keep for blacklisting
            -- Only remove if they've been sitting there for 10+ minutes
            if (now - customer.lastActivity) > 600 then
                table.insert(removed, customer.name .. " (bailed, expired)")
                table.remove(self.queue, i)
            end
        elseif (now - customer.lastActivity) > timeout and customer.state ~= PS.STATE.IN_PROGRESS then
            table.insert(removed, customer.name .. " (timeout)")
            table.remove(self.queue, i)
        end
    end

    if #removed > 0 then
        self:Debug("Queue cleanup: removed " .. table.concat(removed, ", "))
    end
end

------------------------------------------------------------------------
-- Print Queue
------------------------------------------------------------------------
function PS:PrintQueue()
    if #self.queue == 0 then
        self:Print(C.GRAY .. "Queue is empty." .. C.R)
        return
    end

    self:Print(C.GOLD .. "=== Customer Queue (" .. #self.queue .. "/" .. self.db.queue.maxSize .. ") ===" .. C.R)
    for i, customer in ipairs(self.queue) do
        local stateColor = C.GRAY
        local stateText = customer.state
        if customer.state == PS.STATE.IN_PROGRESS then
            stateColor = C.GREEN
            stateText = "SERVING"
        elseif customer.state == PS.STATE.WHISPERED or customer.state == PS.STATE.INVITED then
            stateColor = C.YELLOW
            stateText = "WAITING"
        elseif customer.state == PS.STATE.HAS_MATS then
            stateColor = C.GREEN
            stateText = "HAS MATS"
        elseif customer.state == PS.STATE.NEEDS_MATS then
            stateColor = C.ORANGE
            stateText = "NEEDS MATS"
        elseif customer.state == PS.STATE.BUSY_NOTIFIED then
            stateColor = C.RED
            stateText = "NOTIFIED"
        end

        local matInfo = ""
        if customer.hasMats == true then
            matInfo = C.GREEN .. " [Has Mats]" .. C.R
        elseif customer.hasMats == false then
            matInfo = C.ORANGE .. " [Needs Mats]" .. C.R
        end

        local elapsed = self:FormatTime(GetTime() - customer.addedTime)

        self:Print(string.format("  %s#%d%s %s%s%s - %s%s%s %s(%s)%s%s",
            C.GRAY, i, C.R,
            C.WHITE, customer.name, C.R,
            C.CYAN, customer.item, C.R,
            stateColor, stateText, C.R,
            matInfo))
    end
end

------------------------------------------------------------------------
-- Whisper Response Handler
-- Listens for whispers from queued customers to determine mat status
------------------------------------------------------------------------
PS:RegisterEvent("CHAT_MSG_WHISPER")

function PS:CHAT_MSG_WHISPER(text, senderName, ...)
    if not self.db or not self.db.enabled then return end

    local cleanSender = Ambiguate(senderName, "short")
    local customer = self:GetQueuedCustomer(cleanSender)

    if not customer then return end -- Not from a queued customer

    -- Skip processing if customer already traded/completed/left
    if customer.tradedGold or customer.state == PS.STATE.COMPLETED or customer.state == PS.STATE.LEFT_GROUP then
        return
    end

    customer.lastActivity = GetTime()
    local lower = text:lower()

    self:Debug("Whisper from queued customer " .. cleanSender .. ": " .. text)

    -- Determine mat status from response
    if customer.state == PS.STATE.WHISPERED or customer.state == PS.STATE.WAITING_MATS then
        -- Check for "has mats" responses
        local hasMatsPatterns = {
            "have mat", "got mat", "have the mat", "got the mat",
            "have em", "got em", "have everything", "got everything",
            "have all", "got all", "yes", "yep", "yeah", "ya",
            "i have", "i got", "i do", "ready", "have them",
            "got them", "all good", "good to go", "yea", "ye",
        }

        local needsMatsPatterns = {
            "need mat", "no mat", "don't have", "dont have",
            "can you provide", "can u provide", "need them",
            "no i don't", "no i dont", "nope", "nah",
            "don't got", "dont got", "can you get",
            "hook me up", "provide mat", "sell mat",
            "buy mat", "purchase", "how much for mat",
            "what will it cost", "no mats",
        }

        local hasMats = false
        local needsMats = false

        for _, pattern in ipairs(hasMatsPatterns) do
            if lower:find(pattern, 1, true) then
                hasMats = true
                break
            end
        end

        if not hasMats then
            for _, pattern in ipairs(needsMatsPatterns) do
                if lower:find(pattern, 1, true) then
                    needsMats = true
                    break
                end
            end
        end

        if hasMats then
            customer.hasMats = true
            customer.state = PS.STATE.HAS_MATS
            self:Print(C.GREEN .. customer.name .. C.R .. " has mats for " .. C.CYAN .. customer.item .. C.R)

            if self.db.busyMode then
                local pos = self:GetQueuePosition(cleanSender)
                self:WhisperCustomer(cleanSender, "queued", { item = customer.item, position = tostring(pos or 1) })
            else
                SendChatMessage("Great! I'll get to you shortly. Open trade when you're in my group!",
                    "WHISPER", nil, cleanSender)
                -- If no current customer being served, auto-serve
                if not self:GetCurrentCustomer() then
                    customer.state = PS.STATE.IN_PROGRESS
                    self:Print(C.GREEN .. "Now serving: " .. C.WHITE .. customer.name .. C.R)
                    SendChatMessage("I'm ready! Open trade whenever you are.",
                        "WHISPER", nil, cleanSender)
                end
            end

        elseif needsMats then
            customer.hasMats = false
            customer.state = PS.STATE.NEEDS_MATS
            self:Print(C.ORANGE .. customer.name .. C.R .. " needs mats for " .. C.CYAN .. customer.item .. C.R)

            SendChatMessage("No worries! I can provide the mats for a fee. Want me to check what's needed?",
                "WHISPER", nil, cleanSender)
        else
            -- Ambiguous response - ask again or just acknowledge
            self:Debug("Ambiguous mat response from " .. cleanSender .. ": " .. text)
            customer.state = PS.STATE.WAITING_MATS
        end
    end

    -- Portal destination update: scan whispers from portal customers for destination keywords
    if customer.profession == "Portals" and not customer.portalSpell then
        local dest = PS:MatchDestinationKeyword(lower)
        if dest then
            customer.portalSpell = dest
            customer.item = dest
            self:Print(C.CYAN .. customer.name .. C.R .. " wants " .. C.GREEN .. dest .. C.R)
            self:RefreshEngagementPanel()
        end
    end
end

------------------------------------------------------------------------
-- Destination keyword matching for portal customers
-- Used to update portal destination from whisper/party chat after
-- initial detection (e.g. customer says "shatt" after generic "port" request)
------------------------------------------------------------------------
PS.DESTINATION_KEYWORDS = {
    -- Shattrath
    ["shattrath"]   = "Portal: Shattrath",
    ["shatt"]       = "Portal: Shattrath",
    ["shat"]        = "Portal: Shattrath",
    -- Stormwind
    ["stormwind"]   = "Portal: Stormwind",
    ["sw"]          = "Portal: Stormwind",
    ["storm"]       = "Portal: Stormwind",
    -- Ironforge
    ["ironforge"]   = "Portal: Ironforge",
    ["if"]          = "Portal: Ironforge",
    ["iron"]        = "Portal: Ironforge",
    -- Darnassus
    ["darnassus"]   = "Portal: Darnassus",
    ["darn"]        = "Portal: Darnassus",
    -- Exodar
    ["exodar"]      = "Portal: Exodar",
    ["exo"]         = "Portal: Exodar",
    -- Orgrimmar
    ["orgrimmar"]   = "Portal: Orgrimmar",
    ["org"]         = "Portal: Orgrimmar",
    -- Undercity
    ["undercity"]   = "Portal: Undercity",
    ["uc"]          = "Portal: Undercity",
    -- Thunder Bluff
    ["thunder bluff"] = "Portal: Thunder Bluff",
    ["tb"]          = "Portal: Thunder Bluff",
    -- Silvermoon
    ["silvermoon"]  = "Portal: Silvermoon",
    ["smc"]         = "Portal: Silvermoon",
    ["sm"]          = "Portal: Silvermoon",
    -- Stonard
    ["stonard"]     = "Portal: Stonard",
    ["ston"]        = "Portal: Stonard",
    ["stone"]       = "Portal: Stonard",
    ["blasted"]     = "Portal: Stonard",
    ["outland"]     = "Portal: Stonard",
    ["outlands"]    = "Portal: Stonard",
    -- Theramore
    ["theramore"]   = "Portal: Theramore",
    ["thera"]       = "Portal: Theramore",
}

function PS:MatchDestinationKeyword(text)
    local lower = text:lower()
    -- Try longest matches first
    local sorted = {}
    for kw, _ in pairs(self.DESTINATION_KEYWORDS) do
        table.insert(sorted, kw)
    end
    table.sort(sorted, function(a, b) return #a > #b end)

    for _, kw in ipairs(sorted) do
        local s, e = lower:find(kw, 1, true)
        if s then
            -- Word boundary check
            local before = s > 1 and lower:sub(s - 1, s - 1) or " "
            local after = e < #lower and lower:sub(e + 1, e + 1) or " "
            if not before:match("%a") and not after:match("%a") then
                return self.DESTINATION_KEYWORDS[kw]
            end
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Party Chat Handler: scan for portal destination updates
------------------------------------------------------------------------
PS:RegisterEvent("CHAT_MSG_PARTY")
PS:RegisterEvent("CHAT_MSG_PARTY_LEADER")

function PS:CHAT_MSG_PARTY(text, senderName, ...)
    PS:HandlePartyChatDestination(text, senderName)
end

function PS:CHAT_MSG_PARTY_LEADER(text, senderName, ...)
    PS:HandlePartyChatDestination(text, senderName)
end

function PS:HandlePartyChatDestination(text, senderName)
    if not self.db or not self.db.enabled then return end

    local cleanSender = Ambiguate(senderName, "short")
    local customer = self:GetQueuedCustomer(cleanSender)
    if not customer then return end
    if customer.profession ~= "Portals" then return end

    customer.lastActivity = GetTime()
    local lower = text:lower()

    -- Update destination even if they already have one (they might change their mind)
    local dest = self:MatchDestinationKeyword(lower)
    if dest then
        if customer.portalSpell ~= dest then
            customer.portalSpell = dest
            customer.item = dest
            self:Print(C.CYAN .. customer.name .. C.R .. " updated destination to " .. C.GREEN .. dest .. C.R)
            self:RefreshEngagementPanel()
        end
    end
end
------------------------------------------------------------------------
PS.tradeGoldBefore = nil
PS.tradePartner = nil

PS:RegisterEvent("TRADE_SHOW")
PS:RegisterEvent("TRADE_ACCEPT_UPDATE")
PS:RegisterEvent("TRADE_REQUEST_CANCEL")
PS:RegisterEvent("TRADE_CLOSED")
PS:RegisterEvent("UI_INFO_MESSAGE")

function PS:TRADE_SHOW()
    -- Record gold before trade
    self.tradeGoldBefore = GetMoney()
    -- Try to get trade partner name
    self.tradePartner = UnitName("NPC") or TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText() or nil
    self:Debug("Trade opened. Gold: " .. (self.tradeGoldBefore or 0) .. ", Partner: " .. (self.tradePartner or "unknown"))

    -- Also grab class/level from trade partner as backup source
    if self.tradePartner then
        local customer = self:GetQueuedCustomer(self.tradePartner)
        if customer then
            local _, classFile = UnitClass("NPC")
            local level = UnitLevel("NPC")
            if classFile then customer.classFile = classFile end
            if level and level > 0 then customer.level = level end
            self:RefreshEngagementPanel()
        end
    end
end

function PS:TRADE_REQUEST_CANCEL()
    self.tradeGoldBefore = nil
    self.tradePartner = nil
end

function PS:TRADE_CLOSED()
    -- Check for tip
    if self.tradeGoldBefore then
        C_Timer.After(0.5, function()
            PS:CheckForTip()
        end)
    end
end

function PS:TRADE_ACCEPT_UPDATE(playerAccepted, targetAccepted)
    -- Both accepted trade
    if playerAccepted == 1 and targetAccepted == 1 then
        self:Debug("Both parties accepted trade.")
    end
end

function PS:UI_INFO_MESSAGE(errorType, message)
    -- "Trade complete" message
    if message and message:find("Trade complete") then
        C_Timer.After(0.5, function()
            PS:CheckForTip()
        end)
    end
end

function PS:CheckForTip()
    if not self.tradeGoldBefore then return end

    local goldAfter = GetMoney()
    local diff = goldAfter - self.tradeGoldBefore

    if diff > 0 then
        local goldAmount = math.floor(diff / 10000)
        if goldAmount > 0 then
            -- Check if trade partner is a customer
            local customer = nil
            if self.tradePartner then
                customer = self:GetQueuedCustomer(self.tradePartner)
            end

            -- Record the tip
            self.db.tips.session = (self.db.tips.session or 0) + goldAmount
            self.db.tips.total = (self.db.tips.total or 0) + goldAmount

            table.insert(self.db.tips.history, {
                name = self.tradePartner or "Unknown",
                amount = goldAmount,
                timestamp = time(),
            })

            -- Trim history to last 100 entries
            while #self.db.tips.history > 100 do
                table.remove(self.db.tips.history, 1)
            end

            self:Print(C.GOLD .. "Tip received: " .. goldAmount .. "g" .. C.R ..
                " from " .. C.WHITE .. (self.tradePartner or "Unknown") .. C.R ..
                " | Session total: " .. C.GOLD .. self.db.tips.session .. "g" .. C.R)

            -- Mark customer as having traded gold
            if customer then
                customer.tradedGold = true
                customer.lastActivity = GetTime()
                self.customersServed = (self.customersServed or 0) + 1
                self:RefreshEngagementPanel()
            end

            -- Auto-whisper thanks for the tip
            if self.tradePartner and self.db.queue.autoThank then
                local partnerName = self.tradePartner
                C_Timer.After(1, function()
                    SendChatMessage("Thanks for the tip! Appreciate it. Enjoy!", "WHISPER", nil, partnerName)
                end)
            end
        end
    end

    self.tradeGoldBefore = nil
    self.tradePartner = nil
end

------------------------------------------------------------------------
-- Party/Group Event Handling
------------------------------------------------------------------------
PS:RegisterEvent("GROUP_ROSTER_UPDATE")
PS:RegisterEvent("PARTY_INVITE_REQUEST")
PS:RegisterEvent("CHAT_MSG_SYSTEM")

function PS:GROUP_ROSTER_UPDATE()
    -- When group composition changes, check if any queued customers joined or left
    if not self.db or not self.db.enabled then return end

    for _, customer in ipairs(self.queue) do
        if customer.state == PS.STATE.INVITED then
            -- Check if they're now in our group
            if self:IsPlayerInGroup(customer.name) then
                customer.state = PS.STATE.WHISPERED
                customer.lastActivity = GetTime()
                self:Debug(customer.name .. " joined the group.")

                -- Portal customers: whisper after they join the group
                if customer.profession == "Portals" then
                    local custName = customer.name
                    if customer.portalSpell then
                        -- They specified a destination — just say we're ready
                        C_Timer.After(PS.WHISPER_DELAY, function()
                            local c = PS:GetQueuedCustomer(custName)
                            if c and not c.tradedGold and c.state ~= PS.STATE.COMPLETED then
                                PS:WhisperCustomer(custName, "portalReady")
                            end
                        end)
                    else
                        -- Generic "port" request — ask where they want to go
                        C_Timer.After(PS.WHISPER_DELAY, function()
                            local c = PS:GetQueuedCustomer(custName)
                            if c and not c.tradedGold and c.state ~= PS.STATE.COMPLETED then
                                PS:WhisperCustomer(custName, "portalAskDest")
                            end
                        end)
                    end
                end
            end
        elseif customer.state ~= PS.STATE.COMPLETED and customer.state ~= PS.STATE.DETECTED
                and customer.state ~= PS.STATE.LEFT_GROUP then
            -- Customer was in our group flow - check if they left
            if customer.wasInGroup and not self:IsPlayerInGroup(customer.name) then
                if customer.tradedGold then
                    -- They paid and left — auto-complete, green row, auto-remove in 5s
                    customer.wasInGroup = false
                    customer.state = PS.STATE.COMPLETED
                    self:Print(C.GREEN .. customer.name .. C.R .. " traded and left. Auto-completed.")
                    -- Auto-remove after 5 seconds
                    local custName = customer.name
                    C_Timer.After(5, function()
                        PS:RemoveFromQueue(custName)
                    end)
                else
                    -- They left WITHOUT trading gold — mark red for review
                    customer.wasInGroup = false
                    self:Print(C.RED .. ">> " .. customer.name .. " LEFT without trading!" .. C.R)
                    customer.state = PS.STATE.LEFT_GROUP
                    customer.lastActivity = GetTime()
                    if self.db.monitor.soundAlert then PlaySound(8959) end
                end
                self:RefreshEngagementPanel()
            end
        end
    end

    -- Track who is currently in the group + grab class/level from roster
    for _, customer in ipairs(self.queue) do
        local unit = self:GetGroupUnit(customer.name)
        if unit then
            customer.wasInGroup = true
            -- Pull class + level directly from the group roster (always re-check)
            local _, classFile = UnitClass(unit)
            local level = UnitLevel(unit)
            if classFile then customer.classFile = classFile end
            if level and level > 0 then customer.level = level end
            self:Debug("Roster info for " .. customer.name .. ": class=" .. (classFile or "nil") .. " level=" .. (level or "nil"))
        end
    end
end

function PS:PARTY_INVITE_REQUEST(name)
    -- Auto-accept invites from customers in queue? Optional behavior.
    -- For now, just log it.
    if self:IsInQueue(name) then
        self:Debug("Invite request from queued customer: " .. name)
    end
end

------------------------------------------------------------------------
-- System Message Handler
-- Catches "already in a group", "declines your group", "not found" etc.
------------------------------------------------------------------------
function PS:CHAT_MSG_SYSTEM(message)
    if not self.db or not self.db.enabled then return end

    -- "Player is already in a group."
    -- "Player declines your group invitation."
    -- "Player not found."
    -- These follow the pattern: "Playername is already in a group."
    local name

    -- TBC Classic system messages
    name = message:match("^(%S+) is already in a group")
    if name then
        local customer = self:GetQueuedCustomer(name)
        if customer then
            self:Print(C.ORANGE .. name .. C.R .. " is already in a group — removed from queue.")
            self:RemoveFromQueue(name)
        end
        return
    end

    name = message:match("^(%S+) declines your group")
    if name then
        local customer = self:GetQueuedCustomer(name)
        if customer then
            self:Print(C.ORANGE .. name .. C.R .. " declined the invite — removed from queue.")
            self:RemoveFromQueue(name)
        end
        return
    end

    name = message:match("^(%S+) is not online")
    if not name then
        name = message:match("^No player named '(%S+)' is currently playing")
    end
    if name then
        local customer = self:GetQueuedCustomer(name)
        if customer then
            self:Print(C.ORANGE .. name .. C.R .. " is offline — removed from queue.")
            self:RemoveFromQueue(name)
        end
        return
    end
end

------------------------------------------------------------------------
-- Invite Timeout: auto-remove if customer doesn't join within N seconds
------------------------------------------------------------------------
PS.INVITE_TIMEOUT = 5  -- seconds

function PS:StartInviteTimer(playerName)
    C_Timer.After(self.INVITE_TIMEOUT, function()
        local customer = self:GetQueuedCustomer(playerName)
        if customer and customer.state == PS.STATE.INVITED then
            -- Still INVITED after timeout = never joined
            if not self:IsPlayerInGroup(playerName) then
                self:Print(C.ORANGE .. playerName .. C.R .. " didn't join within " .. self.INVITE_TIMEOUT .. "s — removed from queue.")
                self:RemoveFromQueue(playerName)
            end
        end
    end)
end

function PS:IsPlayerInGroup(playerName)
    return self:GetGroupUnit(playerName) ~= nil
end

function PS:GetGroupUnit(playerName)
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return nil end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name and name == playerName then
            return unit
        end
    end
    return nil
end

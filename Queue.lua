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
            return true
        end
    end
    return false
end

function PS:ClearQueue()
    self.queue = {}
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
end

------------------------------------------------------------------------
-- Trade Window Tracking (for tip detection)
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
            end
        elseif customer.state ~= PS.STATE.COMPLETED and customer.state ~= PS.STATE.DETECTED then
            -- Customer was in our group flow - check if they left
            if customer.wasInGroup and not self:IsPlayerInGroup(customer.name) then
                -- They left the group - send thank you / exit message
                customer.wasInGroup = false
                self:WhisperCustomer(customer.name, "thanks", { item = customer.item or "" })
                self:Print(C.GRAY .. customer.name .. " left the group. Thank-you whispered." .. C.R)
                customer.state = PS.STATE.COMPLETED
                -- Remove from queue after a short delay
                C_Timer.After(3, function()
                    PS:RemoveFromQueue(customer.name)
                end)
            end
        end
    end

    -- Track who is currently in the group
    for _, customer in ipairs(self.queue) do
        if self:IsPlayerInGroup(customer.name) then
            customer.wasInGroup = true
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

function PS:IsPlayerInGroup(playerName)
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return false end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name and name == playerName then
            return true
        end
    end
    return false
end

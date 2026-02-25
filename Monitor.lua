------------------------------------------------------------------------
-- Pro Shop - Monitor
-- Trade chat monitoring, keyword matching, customer detection
------------------------------------------------------------------------
local _, PS = ...
local C = PS.C

------------------------------------------------------------------------
-- Pending invite queue: invites waiting for /who zone verification
------------------------------------------------------------------------
PS.pendingInvites = {}  -- playerName -> { customer, timestamp }

------------------------------------------------------------------------
-- Start / Stop Monitoring
------------------------------------------------------------------------
function PS:StartMonitoring()
    if self.monitoringActive then return end

    self:RegisterEvent("CHAT_MSG_CHANNEL")
    self:RegisterEvent("CHAT_MSG_SAY")      -- optional: nearby chat
    self:RegisterEvent("CHAT_MSG_YELL")     -- optional: yell
    self:RegisterEvent("WHO_LIST_UPDATE")

    self.monitoringActive = true
    self:Debug("Chat monitoring started.")
end

function PS:StopMonitoring()
    if not self.monitoringActive then return end

    self:UnregisterEvent("CHAT_MSG_CHANNEL")
    self:UnregisterEvent("CHAT_MSG_SAY")
    self:UnregisterEvent("CHAT_MSG_YELL")
    self:UnregisterEvent("WHO_LIST_UPDATE")

    self.monitoringActive = false
    self:Debug("Chat monitoring stopped.")
end

------------------------------------------------------------------------
-- Channel Detection Helpers
------------------------------------------------------------------------
local function IsTradeChannel(channelName)
    if not channelName then return false end
    local lower = channelName:lower()
    return lower:find("trade") ~= nil
end

local function IsGeneralChannel(channelName)
    if not channelName then return false end
    local lower = channelName:lower()
    return lower:find("general") ~= nil
end

local function IsLFGChannel(channelName)
    if not channelName then return false end
    local lower = channelName:lower()
    return lower:find("lookingforgroup") ~= nil or lower:find("lfg") ~= nil
end

------------------------------------------------------------------------
-- Chat Event Handlers
------------------------------------------------------------------------
function PS:CHAT_MSG_CHANNEL(text, playerName, languageName, channelName, ...)
    if not self.db or not self.db.enabled then return end
    if not self.db.monitor.enabled then return end

    -- Determine if this channel should be monitored
    local shouldMonitor = false

    if self.db.monitor.tradeChat and IsTradeChannel(channelName) then
        shouldMonitor = true
        self:ProcessChatMessage(text, playerName, "trade")
    elseif self.db.monitor.generalChat and IsGeneralChannel(channelName) then
        shouldMonitor = true
        self:ProcessChatMessage(text, playerName, "general")
    elseif self.db.monitor.lfgChat and IsLFGChannel(channelName) then
        shouldMonitor = true
        self:ProcessChatMessage(text, playerName, "lfg")
    end
end

function PS:CHAT_MSG_SAY(text, playerName, ...)
    if not self.db or not self.db.enabled then return end
    if not self.db.monitor.enabled then return end
    self:ProcessChatMessage(text, playerName, "say")
end

function PS:CHAT_MSG_YELL(text, playerName, ...)
    if not self.db or not self.db.enabled then return end
    if not self.db.monitor.enabled then return end
    self:ProcessChatMessage(text, playerName, "yell")
end

------------------------------------------------------------------------
-- Core Message Processing
------------------------------------------------------------------------
function PS:ProcessChatMessage(text, senderName, source)
    -- Don't process our own messages
    local cleanSender = Ambiguate(senderName, "short")
    if cleanSender == self.playerName then return end

    -- Check blacklist
    if self:IsBlacklisted(cleanSender) then
        self:Debug("Ignoring blacklisted player: " .. cleanSender)
        return
    end

    -- Check if recently contacted (anti-spam)
    if self:IsRecentlyContacted(cleanSender) then
        self:Debug("Recently contacted, skipping: " .. cleanSender)
        return
    end

    -- Check if already in queue
    if self:IsInQueue(cleanSender) then
        self:Debug("Already in queue, skipping: " .. cleanSender)
        return
    end

    -- Check queue capacity
    if #self.queue >= self.db.queue.maxSize then
        self:Debug("Queue full, skipping: " .. cleanSender)
        return
    end

    -- Strip item links for plain text matching, but keep original for display
    local plainText = self:StripLinks(text)

    -- Step 0: Ignore WTS / selling messages immediately
    if self:ShouldIgnoreMessage(plainText) then
        self:Debug("Ignored (selling/WTS): " .. plainText:sub(1, 60))
        return
    end

    -- Step 1: Check if message contains a request pattern
    local hasRequest = self:HasRequestPattern(plainText)

    if not hasRequest then
        -- Even without a request prefix, check for very specific item keywords
        -- (someone might just say "mongoose?" in trade)
        local quickMatch = self:MatchItemKeyword(plainText)
        if not quickMatch then
            return
        end
    end

    -- Step 2: Analyze the message to find what they're looking for
    local matchInfo = self:AnalyzeMessage(text) -- pass original with links
    if not matchInfo then
        matchInfo = self:AnalyzeMessage(plainText) -- try plain text too
    end

    if not matchInfo then
        self:Debug("No match found in message: " .. plainText:sub(1, 60))
        return
    end

    -- Step 3: Check if this profession is active (user may have disabled it in General tab)
    if not self:IsProfessionActive(matchInfo.profession) then
        self:Debug("Profession disabled, skipping: " .. matchInfo.profession)
        return
    end

    -- Step 4: Check if we can fulfill this request
    if not self:CanFulfill(matchInfo) then
        self:Debug("Can't fulfill: " .. (matchInfo.item or matchInfo.profession) .. " (missing profession)")
        return
    end

    -- Step 5: We have a match! Process the customer
    self:Debug(C.GREEN .. "MATCH!" .. C.R .. " " .. cleanSender .. " wants: " ..
        (matchInfo.item or matchInfo.profession) .. " [" .. matchInfo.matchType .. "]")

    self:HandleNewCustomer(cleanSender, matchInfo, text, source)
end

------------------------------------------------------------------------
-- Handle New Customer Detection
------------------------------------------------------------------------
function PS:HandleNewCustomer(playerName, matchInfo, originalMessage, source)
    -- Mark as contacted to prevent spam
    self:MarkContacted(playerName)

    -- Build display name for the item/service
    local displayItem = matchInfo.item or matchInfo.profession
    local profession = matchInfo.profession
    local isGeneric = matchInfo.matchType == "profession"

    -- Alert the player
    local alertMsg = C.GOLD .. ">> " .. C.GREEN .. playerName .. C.R ..
        " is looking for " .. C.CYAN .. displayItem .. C.R ..
        " (" .. C.PURPLE .. profession .. C.R .. ")"
    self:Print(alertMsg)

    -- Play sound alert
    if self.db.monitor.soundAlert then
        PlaySound(8959) -- RAID_WARNING sound
    end

    -- Add to queue
    local customer = {
        name = playerName,
        item = displayItem,
        profession = profession,
        originalMessage = originalMessage,
        matchInfo = matchInfo,
        state = "DETECTED",
        hasMats = nil,
        addedTime = GetTime(),
        lastActivity = GetTime(),
    }
    table.insert(self.queue, customer)

    -- Update customer history
    self:UpdateCustomerHistory(playerName)

    -- Determine invite eligibility
    -- Say/Yell = proximity (always same zone), LFG = cross-zone (never auto-invite)
    -- Trade/General = could be cross-zone in TBC, needs /who verification
    local proximitySource = (source == "say" or source == "yell")
    local canAutoInvite = self.db.monitor.autoInvite and (source ~= "lfg")

    -- Some services don't need mats (skip askMats whisper for these)
    local noMatsProfession = (profession == "Lockpicking" or profession == "Portals" or profession == "Summons")

    if self.db.busyMode then
        self:WhisperCustomer(playerName, "busy", { item = displayItem })
        customer.state = "BUSY_NOTIFIED"
    else
        -- Whisper greeting (always, regardless of zone)
        if isGeneric then
            C_Timer.After(PS.WHISPER_DELAY, function()
                PS:WhisperCustomer(playerName, "greeting", { item = profession })
                local cust = PS:GetQueuedCustomer(playerName)
                if cust then
                    cust.state = "WHISPERED"
                    cust.lastActivity = GetTime()
                end
            end)
        else
            if self.db.monitor.autoWhisper then
                C_Timer.After(PS.WHISPER_DELAY, function()
                    PS:WhisperCustomer(playerName, "greeting", { item = displayItem })
                    if not noMatsProfession then
                        C_Timer.After(2, function()
                            PS:WhisperCustomer(playerName, "askMats", { item = displayItem })
                            local cust = PS:GetQueuedCustomer(playerName)
                            if cust then
                                cust.state = "WHISPERED"
                                cust.lastActivity = GetTime()
                            end
                        end)
                    else
                        local cust = PS:GetQueuedCustomer(playerName)
                        if cust then
                            cust.state = "WHISPERED"
                            cust.lastActivity = GetTime()
                        end
                    end
                end)
            end
        end

        -- Auto-invite: lockpicking/portals/summons always invite immediately, others do zone check
        if canAutoInvite then
            if proximitySource or noMatsProfession then
                -- Proximity or no-mats services: invite immediately
                self:InvitePlayer(playerName)
                customer.state = "INVITED"
                self:Debug("Invited " .. playerName .. " (" .. (noMatsProfession and "no-mats service" or "proximity") .. ")")
            else
                -- Trade/General chat: verify same zone via /who before inviting
                self:ZoneCheckAndInvite(playerName)
            end
        end
    end
end

------------------------------------------------------------------------
-- Zone Check via /who before inviting
------------------------------------------------------------------------
function PS:ZoneCheckAndInvite(playerName)
    -- Store pending invite
    self.pendingInvites[playerName] = {
        timestamp = GetTime(),
    }

    -- Suppress the /who results from showing in chat
    if SetWhoToUI then
        SetWhoToUI(true)
    end

    -- Send /who query for this specific player
    SendWho("n-\"" .. playerName .. "\"")
    self:Debug("Sent /who for zone check: " .. playerName)

    -- Timeout: if we don't get a response in 5 seconds, skip the invite
    C_Timer.After(5, function()
        if PS.pendingInvites[playerName] then
            PS.pendingInvites[playerName] = nil
            PS:Debug("Zone check timed out for " .. playerName .. ", skipping invite.")
        end
    end)
end

function PS:WHO_LIST_UPDATE()
    if not next(self.pendingInvites) then return end

    local myZone = GetRealZoneText()
    local numResults = C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults()
        or (GetNumWhoResults and GetNumWhoResults())
        or 0

    for i = 1, numResults do
        local info
        if C_FriendList and C_FriendList.GetWhoInfo then
            info = C_FriendList.GetWhoInfo(i)
        elseif GetWhoInfo then
            local name, guild, level, race, class, zone = GetWhoInfo(i)
            info = { fullName = name, area = zone }
        end

        if info then
            local whoName = info.fullName or ""
            -- Strip realm name if present
            local shortName = Ambiguate(whoName, "short")

            if self.pendingInvites[shortName] then
                local whoZone = info.area or ""
                self.pendingInvites[shortName] = nil

                if whoZone == myZone then
                    -- Same zone - invite!
                    self:InvitePlayer(shortName)
                    local cust = self:GetQueuedCustomer(shortName)
                    if cust then
                        cust.state = "INVITED"
                    end
                    self:Debug("Zone check PASSED for " .. shortName .. " (both in " .. myZone .. ") - invited!")
                else
                    self:Debug("Zone check FAILED for " .. shortName .. " (they're in " .. whoZone .. ", we're in " .. myZone .. ") - skipping invite.")
                    self:Print(C.GRAY .. shortName .. " is in " .. whoZone .. " (you're in " .. myZone .. ") - whispered only, no invite." .. C.R)
                end
            end
        end
    end

    -- Restore normal /who behavior
    if SetWhoToUI then
        SetWhoToUI(false)
    end
end

------------------------------------------------------------------------
-- Whisper Helpers
------------------------------------------------------------------------
function PS:SendGreeting(playerName, displayItem)
    -- Legacy helper - used by manual interactions
    self:WhisperCustomer(playerName, "greeting", { item = displayItem })
end

function PS:WhisperCustomer(playerName, templateKey, replacements)
    local template = self.db.whispers[templateKey]
    if not template then return end

    -- Replace placeholders
    local msg = template
    if replacements then
        for key, value in pairs(replacements) do
            msg = msg:gsub("{" .. key .. "}", value)
        end
    end

    -- Always replace {player} with our character name
    msg = msg:gsub("{player}", self.playerName or UnitName("player"))

    -- Replace queue position if needed
    local pos = self:GetQueuePosition(playerName)
    if pos then
        msg = msg:gsub("{position}", tostring(pos))
    end

    SendChatMessage(msg, "WHISPER", nil, playerName)
    self:Debug("Whispered " .. playerName .. ": " .. msg)
end

------------------------------------------------------------------------
-- Customer History Tracking
------------------------------------------------------------------------
function PS:UpdateCustomerHistory(playerName)
    if not self.db.customerHistory[playerName] then
        self.db.customerHistory[playerName] = {
            visits = 0,
            lastVisit = 0,
        }
    end
    local hist = self.db.customerHistory[playerName]
    hist.visits = hist.visits + 1
    hist.lastVisit = time()

    -- Repeat customer notification
    if hist.visits > 1 then
        self:Print(C.GOLD .. "Repeat customer! " .. C.WHITE .. playerName .. C.R ..
            " has used your services " .. C.GREEN .. hist.visits .. C.R .. " times!")
    end
end

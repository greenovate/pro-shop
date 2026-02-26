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
    self:RegisterEvent("CHAT_MSG_WHISPER")  -- direct whisper requests
    self:RegisterEvent("WHO_LIST_UPDATE")

    self.monitoringActive = true
    self:Debug("Chat monitoring started.")
end

function PS:StopMonitoring()
    if not self.monitoringActive then return end

    self:UnregisterEvent("CHAT_MSG_CHANNEL")
    self:UnregisterEvent("CHAT_MSG_SAY")
    self:UnregisterEvent("CHAT_MSG_YELL")
    self:UnregisterEvent("CHAT_MSG_WHISPER")
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
    if not self.db then return end
    if not self.db.enabled then
        self:Debug("CHAT_MSG_CHANNEL blocked: addon is CLOSED (db.enabled=false)")
        return
    end
    if self.paused then
        self:Debug("CHAT_MSG_CHANNEL blocked: shop is PAUSED")
        return
    end
    if not self.db.monitor.enabled then
        self:Debug("CHAT_MSG_CHANNEL blocked: monitoring is disabled")
        return
    end

    -- Determine if this channel should be monitored
    if self.db.monitor.tradeChat and IsTradeChannel(channelName) then
        self:Debug("Trade msg from " .. tostring(playerName) .. ": " .. tostring(text):sub(1, 50))
        self:ProcessChatMessage(text, playerName, "trade")
    elseif self.db.monitor.generalChat and IsGeneralChannel(channelName) then
        self:Debug("General msg from " .. tostring(playerName) .. ": " .. tostring(text):sub(1, 50))
        self:ProcessChatMessage(text, playerName, "general")
    elseif self.db.monitor.lfgChat and IsLFGChannel(channelName) then
        self:Debug("LFG msg from " .. tostring(playerName) .. ": " .. tostring(text):sub(1, 50))
        self:ProcessChatMessage(text, playerName, "lfg")
    end
end

function PS:CHAT_MSG_SAY(text, playerName, ...)
    if not self.db or not self.db.enabled then return end
    if not self.db.monitor.enabled then return end
    if self.paused then return end
    self:ProcessChatMessage(text, playerName, "say")
end

function PS:CHAT_MSG_YELL(text, playerName, ...)
    if not self.db or not self.db.enabled then return end
    if not self.db.monitor.enabled then return end
    if self.paused then return end
    self:ProcessChatMessage(text, playerName, "yell")
end

function PS:CHAT_MSG_WHISPER(text, playerName, ...)
    if not self.db or not self.db.enabled then return end
    if not self.db.monitor.enabled then return end
    if self.paused then return end

    local cleanSender = Ambiguate(playerName, "short")
    if cleanSender == self.playerName then return end

    self:Debug("Whisper from " .. tostring(cleanSender) .. ": " .. tostring(text):sub(1, 50))

    -- Handle "inv" / "invite" / "invite me" whispers: always invite (direct request)
    local lower = text:lower():trim()
    if lower == "inv" or lower == "invite" or lower == "invite me" or lower == "inv me"
        or lower == "invite pls" or lower == "inv pls" or lower == "inv plz" then
        if self:IsBlacklisted(cleanSender) then return end
        -- If already in queue, just re-invite
        local existing = self:GetQueuedCustomer(cleanSender)
        if existing then
            self:InvitePlayer(cleanSender)
            existing.state = "INVITED"
            self:StartInviteTimer(cleanSender)
            self:Print(C.GREEN .. cleanSender .. C.R .. " whispered inv — re-invited.")
            self:RefreshEngagementPanel()
            return
        end
        -- New: invite immediately, queue them too
        self:InvitePlayer(cleanSender)
        self:MarkContacted(cleanSender)
        if #self.queue < self.db.queue.maxSize then
            local customer = {
                name = cleanSender,
                item = "Invite Request",
                profession = "Unknown",
                originalMessage = text,
                matchInfo = { profession = "Unknown", item = "Invite Request", matchType = "whisper" },
                state = "INVITED",
                hasMats = nil,
                addedTime = GetTime(),
                lastActivity = GetTime(),
                level = nil,
                class = nil,
                classFile = nil,
            }
            table.insert(self.queue, customer)
            self:LookupPlayerInfo(cleanSender)
            self:StartInviteTimer(cleanSender)
            self:RefreshEngagementPanel()
        end
        self:Print(C.GREEN .. cleanSender .. C.R .. " whispered inv — invited.")
        if self.db.monitor.soundAlert then PlaySound(8959) end
        return
    end

    self:ProcessChatMessage(text, playerName, "whisper")
end

------------------------------------------------------------------------
-- Turbo keywords: dirt-cheap string.find patterns for instant invite
-- These fire BEFORE any heavy analysis to beat competing addons
------------------------------------------------------------------------
local TURBO_KEYWORDS = {
    -- Portal keywords
    { pattern = "port",    profession = "Portals" },
    { pattern = "portal",  profession = "Portals" },
    { pattern = "tele",    profession = "Portals" },
    { pattern = "shatt",   profession = "Portals" },
    { pattern = "shat ",   profession = "Portals" },
    { pattern = "stormw",  profession = "Portals" },
    { pattern = "ironf",   profession = "Portals" },
    { pattern = "darn",    profession = "Portals" },
    { pattern = "exodar",  profession = "Portals" },
    { pattern = "thera",   profession = "Portals" },
    { pattern = "orgr",    profession = "Portals" },
    { pattern = "undercity",profession = "Portals" },
    { pattern = "thunder", profession = "Portals" },
    { pattern = "silverm", profession = "Portals" },
    { pattern = "stonard", profession = "Portals" },
    -- Summon keywords
    { pattern = "summon",  profession = "Summons" },
    { pattern = "summ",    profession = "Summons" },
    -- Lockpicking
    { pattern = "lockpi",  profession = "Lockpicking" },
    { pattern = "lockbo",  profession = "Lockpicking" },
    { pattern = "unlock",  profession = "Lockpicking" },
    { pattern = "open box",profession = "Lockpicking" },
    { pattern = "open lock",profession = "Lockpicking" },
}

-- Quick WTS/selling filter (2 cheap checks to avoid inviting sellers) 
local TURBO_IGNORE = { "wts", "selling", "offering", "will tip", "my mats" }

------------------------------------------------------------------------
-- Core Message Processing
------------------------------------------------------------------------
function PS:ProcessChatMessage(text, senderName, source)
    debugprofilestart()
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

    --------------------------------------------------------------------------
    -- TURBO FAST-PATH: fire invite for no-mats professions BEFORE any heavy
    -- analysis. This runs in <0.1ms and beats competing addons.
    --------------------------------------------------------------------------
    local turboInvited = false
    local turboProfession = nil
    if not self.db.busyMode and source ~= "lfg" then
        local lowerText = text:lower()
        -- Quick WTS filter (don't turbo-invite sellers)
        local isSeller = false
        for _, ig in ipairs(TURBO_IGNORE) do
            if lowerText:find(ig, 1, true) then isSeller = true; break end
        end
        if not isSeller then
            for _, tk in ipairs(TURBO_KEYWORDS) do
                if lowerText:find(tk.pattern, 1, true) then
                    -- Verify this profession is active and auto-invite enabled
                    if self:IsProfessionActive(tk.profession)
                       and self:IsProfessionAutoInvite(tk.profession) then
                        turboProfession = tk.profession
                        self:InvitePlayer(cleanSender)
                        turboInvited = true
                        local turboMs = debugprofilestop()
                        self:Debug("TURBO invite " .. cleanSender .. " for " .. tk.profession .. " in " .. format("%.1f", turboMs) .. "ms")
                    end
                    break
                end
            end
        end
    end

    -- Strip item links for plain text matching, but keep original for display
    local plainText = self:StripLinks(text)

    -- Step 0: Ignore WTS / selling messages immediately (skip for whispers — direct requests)
    if source ~= "whisper" and self:ShouldIgnoreMessage(plainText) then
        self:Debug("Ignored (selling/WTS): " .. plainText:sub(1, 60))
        return
    end

    -- Step 1: Check if message contains a request pattern
    -- Whispers are always treated as direct requests (no prefix needed)
    local hasRequest = (source == "whisper") or self:HasRequestPattern(plainText)

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

    -- ULTRA-FAST INVITE: Fire invite the instant we have a confirmed match
    -- This happens BEFORE HandleNewCustomer to shave off every millisecond
    -- (may already be done by turbo path above)
    local profession = matchInfo.profession
    local proximitySource = (source == "say" or source == "yell" or source == "whisper")
    local canAutoInvite = self:IsProfessionAutoInvite(profession) and (source ~= "lfg")
    local noMatsProfession = (profession == "Lockpicking" or profession == "Portals" or profession == "Summons")
    local ultraInvited = turboInvited

    if not ultraInvited and not self.db.busyMode then
        if profession == "Portals" then
            self:InvitePlayer(cleanSender)
            ultraInvited = true
        elseif canAutoInvite and (proximitySource or noMatsProfession) then
            self:InvitePlayer(cleanSender)
            ultraInvited = true
        end
    end

    local totalMs = debugprofilestop()

    -- Step 5: We have a match! Process the customer
    self:Debug(C.GREEN .. "MATCH!" .. C.R .. " " .. cleanSender .. " wants: " ..
        (matchInfo.item or matchInfo.profession) .. " [" .. matchInfo.matchType .. "]")

    self:HandleNewCustomer(cleanSender, matchInfo, text, source, ultraInvited, totalMs)
end

------------------------------------------------------------------------
-- Handle New Customer Detection
------------------------------------------------------------------------
function PS:HandleNewCustomer(playerName, matchInfo, originalMessage, source, ultraInvited, processingMs)
    -- Mark as contacted to prevent spam
    self:MarkContacted(playerName)

    -- Build display name for the item/service
    local displayItem = matchInfo.item or matchInfo.profession
    local profession = matchInfo.profession
    local isGeneric = matchInfo.matchType == "profession"

    -- Determine invite eligibility EARLY so we can fire invite ASAP
    local proximitySource = (source == "say" or source == "yell" or source == "whisper")
    local canAutoInvite = self:IsProfessionAutoInvite(profession) and (source ~= "lfg")
    local noMatsProfession = (profession == "Lockpicking" or profession == "Portals" or profession == "Summons")

    -- earlyInvited = already invited in ProcessChatMessage ultra-fast path
    local earlyInvited = ultraInvited or false

    -- Fallback invite for paths not covered by ultra-fast (e.g. trade/general auto-invite)
    if not earlyInvited and not self.db.busyMode and canAutoInvite then
        if proximitySource or noMatsProfession then
            self:InvitePlayer(playerName)
            earlyInvited = true
        end
    end

    -- Alert the player
    local timingStr = ""
    if processingMs then
        timingStr = "  |cff888888[" .. format("%.1f", processingMs) .. "ms]|r"
    end
    local alertMsg = C.GOLD .. ">> " .. C.GREEN .. playerName .. C.R ..
        " is looking for " .. C.CYAN .. displayItem .. C.R ..
        " (" .. C.PURPLE .. profession .. C.R .. ")" .. timingStr
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
        level = nil,
        class = nil,
        classFile = nil,
    }

    -- For portal customers, store the requested portal spell
    if profession == "Portals" and matchInfo.item then
        customer.portalSpell = matchInfo.item  -- e.g. "Portal: Orgrimmar"
    end

    table.insert(self.queue, customer)

    -- Fire a /who to get class + level for the queue display
    self:LookupPlayerInfo(playerName)

    -- Update customer history
    self:UpdateCustomerHistory(playerName)

    -- Determine invite eligibility
    -- Say/Yell/Whisper = proximity (always same zone or direct request)
    -- LFG = cross-zone (never auto-invite)
    -- Trade/General = could be cross-zone in TBC, needs /who verification
    local proximitySource = (source == "say" or source == "yell" or source == "whisper")
    local canAutoInvite = self:IsProfessionAutoInvite(profession) and (source ~= "lfg")

    -- Some services don't need mats (skip askMats whisper for these)
    local noMatsProfession = (profession == "Lockpicking" or profession == "Portals" or profession == "Summons")

    if self.db.busyMode then
        self:WhisperCustomer(playerName, "busy", { item = displayItem })
        customer.state = "BUSY_NOTIFIED"
    elseif profession == "Portals" then
        -- Portal flow: already invited above, whisper deferred until group join
        customer.state = "INVITED"
        self:StartInviteTimer(playerName)
        self:Debug("Portal customer " .. playerName .. " invited (whisper deferred until group join)")
    else
        -- Whisper greeting (always, regardless of zone)
        if isGeneric then
            C_Timer.After(PS.WHISPER_DELAY, function()
                local cust = PS:GetQueuedCustomer(playerName)
                if not cust or cust.tradedGold or cust.state == "COMPLETED" then return end
                PS:WhisperCustomer(playerName, "greeting", { item = profession })
                cust.state = "WHISPERED"
                cust.lastActivity = GetTime()
            end)
        else
            if self.db.monitor.autoWhisper then
                C_Timer.After(PS.WHISPER_DELAY, function()
                    local cust = PS:GetQueuedCustomer(playerName)
                    if not cust or cust.tradedGold or cust.state == "COMPLETED" then return end
                    PS:WhisperCustomer(playerName, "greeting", { item = displayItem })
                    if not noMatsProfession then
                        C_Timer.After(2, function()
                            local cust2 = PS:GetQueuedCustomer(playerName)
                            if not cust2 or cust2.tradedGold or cust2.state == "COMPLETED" then return end
                            PS:WhisperCustomer(playerName, "askMats", { item = displayItem })
                            cust2.state = "WHISPERED"
                            cust2.lastActivity = GetTime()
                        end)
                    else
                        cust.state = "WHISPERED"
                        cust.lastActivity = GetTime()
                    end
                end)
            end
        end

        -- Auto-invite logic (non-portal) — skip if already invited in fast path
        if not earlyInvited and canAutoInvite then
            if proximitySource or noMatsProfession then
                self:InvitePlayer(playerName)
                customer.state = "INVITED"
                self:StartInviteTimer(playerName)
                self:Debug("Invited " .. playerName .. " (" .. (noMatsProfession and "no-mats service" or "proximity") .. ")")
            else
                -- Trade/General chat: verify same zone via /who before inviting
                self:ZoneCheckAndInvite(playerName)
            end
        elseif earlyInvited then
            customer.state = "INVITED"
            self:StartInviteTimer(playerName)
        end
    end

    -- Refresh the engagement panel
    self:RefreshEngagementPanel()
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
        pcall(SetWhoToUI, true)
    end

    -- Send /who query for this specific player (protected in Anniversary Classic)
    local query = "n-\"" .. playerName .. "\""
    local ok = false
    if C_FriendList and C_FriendList.SendWho then
        ok = pcall(C_FriendList.SendWho, query)
    end
    if not ok and SendWho then
        ok = pcall(SendWho, query)
    end
    if not ok then
        -- /who blocked, skip zone check and just invite directly
        self.pendingInvites[playerName] = nil
        self:InvitePlayer(playerName)
        self:Debug("SendWho blocked, inviting " .. playerName .. " without zone check")
        return
    end
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
    local hasPending = next(self.pendingInvites)
    local hasLookups = self._pendingLookups and next(self._pendingLookups)
    if not hasPending and not hasLookups then return end

    local myZone = GetRealZoneText()
    local numResults = C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults()
        or (GetNumWhoResults and GetNumWhoResults())
        or 0

    for i = 1, numResults do
        local info
        if C_FriendList and C_FriendList.GetWhoInfo then
            info = C_FriendList.GetWhoInfo(i)
        elseif GetWhoInfo then
            local name, guild, level, race, class, zone, classFile = GetWhoInfo(i)
            info = { fullName = name, area = zone, level = level, classStr = class, filename = classFile }
        end

        if info then
            local whoName = info.fullName or ""
            -- Strip realm name if present
            local shortName = Ambiguate(whoName, "short")

            -- Always store class/level on any queued customer we see in /who
            local cust = self:GetQueuedCustomer(shortName)
            if cust then
                if info.level and info.level > 0 then cust.level = info.level end
                if info.filename then cust.classFile = info.filename end
                if info.classStr then cust.class = info.classStr end
            end

            -- Clear lookup flag for this player
            if self._pendingLookups then
                self._pendingLookups[shortName] = nil
            end

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

------------------------------------------------------------------------
-- Lookup player class + level via /who
------------------------------------------------------------------------
function PS:LookupPlayerInfo(playerName)
    -- Try to get class/level via /who — optional, group roster is primary source
    -- SendWho is protected in Anniversary Classic; pcall to avoid ADDON_ACTION_BLOCKED
    if not self._pendingLookups then self._pendingLookups = {} end
    self._pendingLookups[playerName] = true
    if SetWhoToUI then pcall(SetWhoToUI, true) end
    local query = 'n-"' .. playerName .. '"'
    local ok = false
    if C_FriendList and C_FriendList.SendWho then
        ok = pcall(C_FriendList.SendWho, query)
    end
    if not ok and SendWho then
        ok = pcall(SendWho, query)
    end
    if not ok then
        self:Debug("SendWho blocked (protected) for " .. playerName)
    end
    C_Timer.After(5, function()
        if PS._pendingLookups then PS._pendingLookups[playerName] = nil end
    end)
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

    -- Replace {zone} with current zone name
    local zoneName = GetRealZoneText and GetRealZoneText() or GetZoneText and GetZoneText() or "unknown"
    msg = msg:gsub("{zone}", zoneName)

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

------------------------------------------------------------------------
-- Pro Shop - Core
-- Initialization, event handling, utilities, saved variables, slash commands
------------------------------------------------------------------------
local ADDON_NAME, PS = ...
ProShop = PS -- Global reference

-- Addon Info
PS.VERSION = "1.0.0"
PS.NAME = "Pro Shop"
PS.PREFIX = "|cff00ccff[Pro Shop]|r "

-- Runtime State
PS.initialized = false
PS.professions = {}       -- detected professions: name -> { skill, maxSkill, numRecipes }
PS.knownRecipes = {}      -- recipe name (lower) -> { name, profession, link }
PS.queue = {}             -- customer queue entries
PS.recentContacts = {}    -- anti-spam: lowercase name -> timestamp
PS.monitoringActive = false

-- Tuning
PS.CONTACT_COOLDOWN = 120   -- seconds before re-contacting someone
PS.WHISPER_DELAY = 1.5      -- delay between invite and first whisper
PS.QUEUE_CLEANUP_INTERVAL = 30

------------------------------------------------------------------------
-- Invite Helper (API varies by client version)
------------------------------------------------------------------------
function PS:InvitePlayer(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(name)
        self:Debug("InvitePlayer via C_PartyInfo.InviteUnit: " .. name)
    elseif InviteUnit then
        InviteUnit(name)
        self:Debug("InvitePlayer via InviteUnit: " .. name)
    elseif InviteByName then
        InviteByName(name)
        self:Debug("InvitePlayer via InviteByName: " .. name)
    else
        self:Print("|cffff0000No invite API available! Cannot invite " .. name .. "|r")
    end
end

------------------------------------------------------------------------
-- Color Helpers
------------------------------------------------------------------------
local C = {
    GOLD    = "|cffffd700",
    GREEN   = "|cff00ff00",
    RED     = "|cffff0000",
    BLUE    = "|cff3399ff",
    CYAN    = "|cff00ccff",
    ORANGE  = "|cffff8800",
    WHITE   = "|cffffffff",
    GRAY    = "|cff888888",
    PURPLE  = "|cffcc66ff",
    YELLOW  = "|cffffff00",
    R       = "|r",
}
PS.C = C

------------------------------------------------------------------------
-- Default Saved Variables
------------------------------------------------------------------------
PS.DEFAULTS = {
    enabled = true,
    debug = false,
    activeProfessions = {},  -- profession -> true/false for monitoring/invites (General tab)

    advertise = {
        channel = "Trade",    -- channel name to advertise in
        messages = {},        -- custom per-profession messages (profession -> msg)
        activeProfessions = {}, -- profession -> true/false for which to advertise
        rotateMessages = true,
        lastBroadcastIndex = 0,
    },

    monitor = {
        enabled = true,
        tradeChat = true,
        generalChat = false,
        lfgChat = true,
        autoInvite = true,
        autoWhisper = true,
        soundAlert = true,
        contactCooldown = 120,   -- seconds before re-contacting same person
    },

    queue = {
        maxSize = 10,
        timeout = 600,       -- seconds before auto-removing inactive customer
        autoThank = true,
    },

    whispers = {
        greeting   = "Hey! I saw you're looking for {item}. I can help with that!",
        askMats    = "Do you have the mats, or do you need me to provide them?",
        thanks     = "Thank you for choosing {player}'s Pro-Shop! Have a great day!",
        busy       = "Hey! I can do that but I'm a bit busy right now. I'll get to you shortly!",
        queued     = "You're #{position} in my queue. Sit tight!",
    },

    busyMode = false,
    blacklist = {},      -- name (capitalized) -> true

    tips = {
        session = 0,
        total = 0,
        history = {},     -- { name, amount, timestamp }
    },

    knownRecipes = {},    -- persisted recipe cache: lower name -> profession

    customerHistory = {}, -- name -> { visits, lastVisit }

    minimap = {
        show = true,
        position = 195,   -- degrees around minimap
    },

    toggleFrame = {
        show = true,
        point = "TOP",
        x = 0,
        y = -15,
    },

    framePosition = nil,  -- { point, relativeTo, relPoint, x, y }
}

------------------------------------------------------------------------
-- Utility Functions
------------------------------------------------------------------------
function PS:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. tostring(msg))
end

function PS:Debug(msg)
    if self.db and self.db.debug then
        DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. C.GRAY .. "[Debug] " .. tostring(msg) .. C.R)
    end
end

function PS:ColorText(text, color)
    return (color or C.WHITE) .. tostring(text) .. C.R
end

function PS:FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    if gold > 0 then
        return C.GOLD .. gold .. "g" .. C.R .. " " .. C.GRAY .. silver .. "s" .. C.R
    elseif silver > 0 then
        return C.GRAY .. silver .. "s" .. C.R
    else
        return C.ORANGE .. copper .. "c" .. C.R
    end
end

function PS:FormatTime(seconds)
    seconds = math.floor(seconds)
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m " .. (seconds % 60) .. "s"
    else
        return math.floor(seconds / 3600) .. "h " .. math.floor((seconds % 3600) / 60) .. "m"
    end
end

function PS:DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = self:DeepCopy(v)
    end
    return copy
end

function PS:MergeDefaults(saved, defaults)
    if type(saved) ~= "table" then
        return self:DeepCopy(defaults)
    end
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            saved[k] = self:DeepCopy(v)
        elseif type(v) == "table" and type(saved[k]) == "table" then
            self:MergeDefaults(saved[k], v)
        end
    end
    return saved
end

function PS:IsBlacklisted(name)
    return self.db.blacklist[name] ~= nil
end

function PS:IsRecentlyContacted(playerName)
    local t = self.recentContacts[playerName:lower()]
    local cooldown = (self.db and self.db.monitor and self.db.monitor.contactCooldown) or self.CONTACT_COOLDOWN
    return t and (GetTime() - t) < cooldown
end

function PS:MarkContacted(playerName)
    self.recentContacts[playerName:lower()] = GetTime()
end

-- Strip color codes and item links to get plain text
function PS:StripLinks(msg)
    -- Extract item/spell names from links  |cff...|Hitem:...|h[Name]|h|r  ->  Name
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x|H[^|]+|h%[([^%]]+)%]|h|r", "%1")
    -- Remove remaining color codes
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", "")
    msg = msg:gsub("|r", "")
    return msg
end

-- Extract item names from links in message
function PS:ExtractLinkedItems(msg)
    local items = {}
    for name in msg:gmatch("|c%x%x%x%x%x%x%x%x|H[^|]+|h%[([^%]]+)%]|h|r") do
        table.insert(items, name)
    end
    return items
end

------------------------------------------------------------------------
-- Event Handling
------------------------------------------------------------------------
PS.EventFrame = CreateFrame("Frame", "ProShopEventFrame", UIParent)
PS.EventFrame:RegisterEvent("ADDON_LOADED")
PS.EventFrame:RegisterEvent("PLAYER_LOGIN")

PS.EventFrame:SetScript("OnEvent", function(self, event, ...)
    if PS[event] then
        PS[event](PS, ...)
    end
end)

function PS:RegisterEvent(event)
    self.EventFrame:RegisterEvent(event)
end

function PS:UnregisterEvent(event)
    self.EventFrame:UnregisterEvent(event)
end

function PS:ADDON_LOADED(addon)
    if addon ~= ADDON_NAME then return end

    ProShopDB = self:MergeDefaults(ProShopDB or {}, self.DEFAULTS)
    self.db = ProShopDB
    self.db.tips.session = 0

    -- Migrate old thanks whisper that was missing {player}
    if self.db.whispers.thanks and not self.db.whispers.thanks:find("{player}") then
        -- Insert {player}'s before Pro-Shop / Pro Shop in whatever custom text they have
        self.db.whispers.thanks = self.db.whispers.thanks:gsub("Pro%-Shop", "{player}'s Pro-Shop"):gsub("Pro Shop", "{player}'s Pro-Shop")
        -- If still no {player} (completely custom text), just use the new default
        if not self.db.whispers.thanks:find("{player}") then
            self.db.whispers.thanks = self.DEFAULTS.whispers.thanks
        end
    end

    -- Create minimap button early so collectors (ElvUI, MBB, etc.) can find it
    self:CreateMinimapButton()
    self:CreateToggleFrame()
    self:CreateEngagementPanel()

    self:UnregisterEvent("ADDON_LOADED")
end

function PS:PLAYER_LOGIN()
    C_Timer.After(3, function()
        if not PS.initialized then
            PS:Initialize()
        end
    end)
end

function PS:Initialize()
    self.playerName = UnitName("player")
    self.playerRealm = GetRealmName()

    -- Scan professions from skill lines
    self:ScanProfessions()

    -- Restore persisted recipe cache
    if self.db.knownRecipes then
        for recipeName, prof in pairs(self.db.knownRecipes) do
            if not self.knownRecipes[recipeName] then
                self.knownRecipes[recipeName] = { name = recipeName, profession = prof }
            end
        end
        -- Update recipe counts from cache
        local profCounts = {}
        for _, prof in pairs(self.db.knownRecipes) do
            profCounts[prof] = (profCounts[prof] or 0) + 1
        end
        for profName, count in pairs(profCounts) do
            if self.professions[profName] and self.professions[profName].numRecipes == 0 then
                self.professions[profName].numRecipes = count
            end
        end
    end

    -- Start systems (only if addon is enabled AND monitoring is enabled)
    if self.db.enabled and self.db.monitor.enabled then
        self:StartMonitoring()
    elseif not self.db.enabled then
        self:Print(C.RED .. "Pro Shop is CLOSED." .. C.R .. " Right-click the toggle frame or type " .. C.GREEN .. "/ps on" .. C.R .. " to open.")
    end
    -- Advertising is manual (button click) to comply with protected function restrictions

    -- Queue cleanup timer
    C_Timer.NewTicker(self.QUEUE_CLEANUP_INTERVAL, function()
        PS:CleanupQueue()
    end)

    self.initialized = true
    self:Print(C.GOLD .. "v" .. self.VERSION .. C.R .. " loaded! Type " .. C.GREEN .. "/ps" .. C.R .. " for commands.")

    -- Auto deep-scan if we have no cached recipes yet
    if not next(self.knownRecipes) then
        C_Timer.After(2, function()
            if not InCombatLockdown() then
                PS:Print(C.CYAN .. "First run - auto-scanning recipes..." .. C.R)
                PS:DeepScanProfessions()
            end
        end)
    end
end

------------------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------------------
SLASH_PROSHOP1 = "/proshop"
SLASH_PROSHOP2 = "/ps"

SlashCmdList["PROSHOP"] = function(msg)
    local cmd, args = strsplit(" ", msg or "", 2)
    cmd = (cmd or ""):lower():trim()
    args = (args or ""):trim()

    if cmd == "" or cmd == "config" or cmd == "options" or cmd == "ui" then
        PS:ToggleUI()
    elseif cmd == "toggle" then
        PS.db.enabled = not PS.db.enabled
        if PS.db.enabled then
            if PS.db.monitor.enabled and not PS.monitoringActive then
                PS:StartMonitoring()
            end
        else
            if PS.monitoringActive then
                PS:StopMonitoring()
            end
        end
        PS:UpdateToggleFrame()
        PS:Print("Pro Shop is now " .. (PS.db.enabled and C.GREEN .. "OPEN" or C.RED .. "CLOSED") .. C.R)
    elseif cmd == "on" then
        PS.db.enabled = true
        if PS.db.monitor.enabled and not PS.monitoringActive then
            PS:StartMonitoring()
        end
        PS:UpdateToggleFrame()
        PS:Print("Pro Shop is now " .. C.GREEN .. "OPEN" .. C.R)
    elseif cmd == "off" then
        PS.db.enabled = false
        if PS.monitoringActive then
            PS:StopMonitoring()
        end
        PS:UpdateToggleFrame()
        PS:Print("Pro Shop is now " .. C.RED .. "CLOSED" .. C.R)
    elseif cmd == "scan" then
        PS:ScanProfessions()
        PS:DeepScanProfessions()
    elseif cmd == "ad" or cmd == "advertise" or cmd == "broadcast" then
        PS:Print(C.YELLOW .. "Use the Broadcast button in the Advertise tab (needs a click for protected function)." .. C.R)
    elseif cmd == "busy" then
        PS.db.busyMode = not PS.db.busyMode
        PS:Print("Busy mode: " .. (PS.db.busyMode and C.RED .. "ON" or C.GREEN .. "OFF") .. C.R)
    elseif cmd == "queue" or cmd == "q" then
        PS:PrintQueue()
    elseif cmd == "next" then
        PS:ServeNextCustomer()
    elseif cmd == "done" then
        PS:CompleteCurrentCustomer()
    elseif cmd == "clear" then
        PS:ClearQueue()
        PS:Print("Queue cleared.")
    elseif cmd == "blacklist" or cmd == "bl" then
        if args ~= "" then
            PS:ToggleBlacklist(args)
        else
            PS:PrintBlacklist()
        end
    elseif cmd == "tips" then
        PS:PrintTips()
    elseif cmd == "cooldowns" or cmd == "cd" then
        PS:PrintCooldowns()
    elseif cmd == "status" then
        PS:PrintStatus()
    elseif cmd == "diag" then
        PS:PrintDiag()
    elseif cmd == "monitor" then
        PS.db.monitor.enabled = not PS.db.monitor.enabled
        if PS.db.monitor.enabled then
            PS:StartMonitoring()
        else
            PS:StopMonitoring()
        end
        PS:Print("Monitoring: " .. (PS.db.monitor.enabled and C.GREEN .. "Active" or C.RED .. "Inactive") .. C.R)
    elseif cmd == "debug" then
        PS.db.debug = not PS.db.debug
        PS:Print("Debug: " .. (PS.db.debug and C.GREEN .. "ON" or C.RED .. "OFF") .. C.R)
    elseif cmd == "help" or cmd == "?" then
        PS:PrintHelp()
    else
        PS:PrintHelp()
    end
end

function PS:PrintHelp()
    self:Print(C.GOLD .. "=== Pro Shop Commands ===" .. C.R)
    local cmds = {
        { "/ps",              "Open settings panel" },
        { "/ps toggle",       "Enable / disable addon" },
        { "/ps scan",         "Rescan professions" },
        { "/ps ad",           "Open Advertise tab (use Broadcast button)" },
        { "/ps busy",         "Toggle busy mode" },
        { "/ps queue",        "Show customer queue" },
        { "/ps next",         "Serve next customer in queue" },
        { "/ps done",         "Mark current customer complete" },
        { "/ps clear",        "Clear customer queue" },
        { "/ps bl [name]",    "Toggle player on blacklist" },
        { "/ps tips",         "Show tip statistics" },
        { "/ps cd",           "Show profession cooldowns" },
        { "/ps status",       "Show current status" },
        { "/ps diag",         "Dump diagnostics (professions, flags)" },
        { "/ps monitor",      "Toggle chat monitoring" },
        { "/ps debug",        "Toggle debug output" },
    }
    for _, v in ipairs(cmds) do
        self:Print("  " .. C.GREEN .. v[1] .. C.R .. " - " .. v[2])
    end
end

function PS:PrintStatus()
    self:Print(C.GOLD .. "=== Status ===" .. C.R)
    self:Print("  Addon: " .. (self.db.enabled and C.GREEN .. "Enabled" or C.RED .. "Disabled") .. C.R)
    self:Print("  Busy: " .. (self.db.busyMode and C.RED .. "Yes" or C.GREEN .. "No") .. C.R)
    self:Print("  Monitor: " .. (self.monitoringActive and C.GREEN .. "Active" or C.RED .. "Off") .. C.R)
    self:Print("  Advertise: " .. C.CYAN .. "Manual (button click)" .. C.R)
    self:Print("  Queue: " .. #self.queue .. "/" .. self.db.queue.maxSize)
    self:Print("  Tips (session): " .. C.GOLD .. (self.db.tips.session or 0) .. "g" .. C.R)

    local profNames = {}
    for name, data in pairs(self.professions) do
        local count = data.numRecipes or 0
        table.insert(profNames, C.CYAN .. name .. C.R .. " (" .. count .. ")")
    end
    if #profNames > 0 then
        self:Print("  Professions: " .. table.concat(profNames, ", "))
    else
        self:Print("  Professions: " .. C.GRAY .. "None detected" .. C.R)
    end
end

function PS:PrintDiag()
    self:Print(C.GOLD .. "=== Diagnostics ===" .. C.R)
    self:Print("  enabled (OPEN/CLOSED): " .. (self.db.enabled and C.GREEN .. "OPEN" or C.RED .. "CLOSED") .. C.R ..
        " (raw: " .. tostring(self.db.enabled) .. ")")
    self:Print("  monitor.enabled: " .. tostring(self.db.monitor.enabled))
    self:Print("  monitoringActive: " .. tostring(self.monitoringActive))
    self:Print("  initialized: " .. tostring(self.initialized))
    self:Print("  tradeChat: " .. tostring(self.db.monitor.tradeChat))
    self:Print("  generalChat: " .. tostring(self.db.monitor.generalChat))
    self:Print("  lfgChat: " .. tostring(self.db.monitor.lfgChat))
    self:Print("  autoInvite: " .. tostring(self.db.monitor.autoInvite))
    self:Print("  autoWhisper: " .. tostring(self.db.monitor.autoWhisper))

    -- Check if events are actually registered
    local eventsOk = self.EventFrame:IsEventRegistered("CHAT_MSG_CHANNEL")
    self:Print("  CHAT_MSG_CHANNEL registered: " .. (eventsOk and C.GREEN .. "YES" or C.RED .. "NO") .. C.R)

    -- Summary verdict
    if not self.db.enabled then
        self:Print(C.RED .. "  >> PROBLEM: Addon is CLOSED! Messages will be ignored." .. C.R)
        self:Print(C.YELLOW .. "     Fix: /ps on  OR  right-click the toggle frame" .. C.R)
    elseif not self.db.monitor.enabled then
        self:Print(C.RED .. "  >> PROBLEM: Monitoring is disabled!" .. C.R)
    elseif not self.monitoringActive then
        self:Print(C.RED .. "  >> PROBLEM: Monitoring not started! Try /reload" .. C.R)
    elseif not eventsOk then
        self:Print(C.RED .. "  >> PROBLEM: Chat events not registered! Try /reload" .. C.R)
    else
        self:Print(C.GREEN .. "  >> Monitor is running normally." .. C.R)
    end

    -- Detected professions
    self:Print(C.GOLD .. "  -- Detected Professions --" .. C.R)
    if next(self.professions) then
        for name, data in pairs(self.professions) do
            local skill = data.skill or "?"
            local active = self:IsProfessionActive(name)
            self:Print("    " .. C.CYAN .. name .. C.R ..
                " skill=" .. tostring(skill) ..
                " active=" .. (active and C.GREEN .. "YES" or C.RED .. "NO") .. C.R)
        end
    else
        self:Print("    " .. C.RED .. "NONE - run /ps scan" .. C.R)
    end

    -- Active professions saved state
    if self.db.activeProfessions and next(self.db.activeProfessions) then
        self:Print(C.GOLD .. "  -- activeProfessions (saved) --" .. C.R)
        for name, val in pairs(self.db.activeProfessions) do
            self:Print("    " .. name .. " = " .. tostring(val))
        end
    end

    -- Queue
    self:Print("  Queue: " .. #self.queue .. "/" .. self.db.queue.maxSize)
end
function PS:ToggleBlacklist(name)
    name = name:sub(1,1):upper() .. name:sub(2):lower()
    if self.db.blacklist[name] then
        self.db.blacklist[name] = nil
        self:Print(C.GREEN .. name .. C.R .. " removed from blacklist.")
    else
        self.db.blacklist[name] = true
        self:Print(C.RED .. name .. C.R .. " added to blacklist.")
    end
end

function PS:PrintBlacklist()
    self:Print(C.GOLD .. "=== Blacklist ===" .. C.R)
    local count = 0
    for name, _ in pairs(self.db.blacklist) do
        self:Print("  " .. C.RED .. name .. C.R)
        count = count + 1
    end
    if count == 0 then
        self:Print("  " .. C.GRAY .. "(empty)" .. C.R)
    end
end

function PS:PrintTips()
    self:Print(C.GOLD .. "=== Tip Statistics ===" .. C.R)
    self:Print("  Session: " .. C.GOLD .. (self.db.tips.session or 0) .. "g" .. C.R)
    self:Print("  Lifetime: " .. C.GOLD .. (self.db.tips.total or 0) .. "g" .. C.R)
    if self.db.tips.history and #self.db.tips.history > 0 then
        self:Print("  " .. C.GRAY .. "Recent:" .. C.R)
        local startIdx = math.max(1, #self.db.tips.history - 4)
        for i = #self.db.tips.history, startIdx, -1 do
            local entry = self.db.tips.history[i]
            self:Print("    " .. C.WHITE .. entry.name .. C.R .. " - " .. C.GOLD .. entry.amount .. "g" .. C.R)
        end
    end
end

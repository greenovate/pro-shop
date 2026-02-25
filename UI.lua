------------------------------------------------------------------------
-- Pro Shop - UI
-- Configuration panel, minimap button, visual interface
------------------------------------------------------------------------
local _, PS = ...
local C = PS.C

------------------------------------------------------------------------
-- Open / Closed Toggle Frame  (always-visible shop sign)
------------------------------------------------------------------------
function PS:CreateToggleFrame()
    if self.toggleFrame then return end

    local f = CreateFrame("Frame", "ProShopToggleFrame", UIParent, "BackdropTemplate")
    f:SetSize(130, 36)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Backdrop
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Title label: "PRO SHOP"
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", f, "TOP", 0, -5)
    title:SetText("|cff00ccffPRO|r |cffffffffSHOP|r")
    title:SetFont(title:GetFont(), 9, "OUTLINE")
    f.title = title

    -- Status label: "OPEN" or "CLOSED"
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("BOTTOM", f, "BOTTOM", 0, 5)
    f.status = status

    -- Indicator dot
    local dot = f:CreateTexture(nil, "OVERLAY")
    dot:SetSize(10, 10)
    dot:SetPoint("RIGHT", status, "LEFT", -3, 0)
    dot:SetTexture("Interface\\COMMON\\Indicator-Green")
    f.dot = dot

    ----------------------------------------------------------------
    -- DASHBOARD elements (visible when shop is OPEN)
    ----------------------------------------------------------------
    local COMPACT_W, COMPACT_H = 130, 36
    local DASH_W = 240

    local dashFrame = CreateFrame("Frame", nil, f)
    dashFrame:SetAllPoints()
    dashFrame:Hide()
    f.dashFrame = dashFrame

    -- Dashboard title
    local dTitle = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    dTitle:SetText("|cff00ccffPRO|r |cffffffffSHOP|r")
    dTitle:SetFont(dTitle:GetFont(), 11, "OUTLINE")

    local dStatusText = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dStatusText:SetPoint("TOPRIGHT", f, "TOPLEFT", DASH_W - 10, -10)
    dStatusText:SetText("|cff00ff00OPEN|r")

    local dDot = dashFrame:CreateTexture(nil, "OVERLAY")
    dDot:SetSize(8, 8)
    dDot:SetTexture("Interface\\COMMON\\Indicator-Green")
    dDot:SetPoint("RIGHT", dStatusText, "LEFT", -3, 0)

    -- Separator 1
    local dSep1 = dashFrame:CreateTexture(nil, "OVERLAY")
    dSep1:SetSize(DASH_W - 12, 1)
    dSep1:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -24)
    dSep1:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    -- Session label + duration
    local dSessLabel = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dSessLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
    dSessLabel:SetText("|cffffff00SESSION|r")

    dashFrame.sessionTime = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dashFrame.sessionTime:SetPoint("TOPRIGHT", f, "TOPLEFT", DASH_W - 10, -28)
    dashFrame.sessionTime:SetText("|cffffffff00:00:00|r")

    -- Stat cards (2x2 grid)
    local CARD_W, CARD_H = 105, 32

    local function MakeStatCard(labelText, xOff, yOff)
        local card = CreateFrame("Frame", nil, dashFrame, "BackdropTemplate")
        card:SetSize(CARD_W, CARD_H)
        card:SetPoint("TOPLEFT", f, "TOPLEFT", xOff, yOff)
        card:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        card:SetBackdropColor(0.1, 0.1, 0.13, 0.9)
        card:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.5)
        card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.value:SetPoint("TOP", 0, -3)
        card.label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        card.label:SetPoint("BOTTOM", 0, 3)
        card.label:SetText("|cff888888" .. labelText .. "|r")
        return card
    end

    dashFrame.cardEarned = MakeStatCard("Earned",   10, -42)
    dashFrame.cardGoldHr = MakeStatCard("Per Hour", 121, -42)
    dashFrame.cardServed = MakeStatCard("Served",   10, -78)
    dashFrame.cardQueue  = MakeStatCard("In Queue", 121, -78)

    -- Separator 2
    local dSep2 = dashFrame:CreateTexture(nil, "OVERLAY")
    dSep2:SetSize(DASH_W - 12, 1)
    dSep2:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -114)
    dSep2:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    -- Top Tippers section
    local dTipHdr = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dTipHdr:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -119)
    dTipHdr:SetText("|cffffff00TOP TIPPERS|r")

    dashFrame.tipperLines = {}
    for i = 1, 3 do
        local tl = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -132 - (i - 1) * 13)
        tl:SetWidth(DASH_W - 28)
        tl:SetJustifyH("LEFT")
        dashFrame.tipperLines[i] = tl
    end

    -- Separator 3
    local dSep3 = dashFrame:CreateTexture(nil, "OVERLAY")
    dSep3:SetSize(DASH_W - 12, 1)
    dSep3:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -172)
    dSep3:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    -- Ad button container
    dashFrame.adContainer = CreateFrame("Frame", nil, dashFrame)
    dashFrame.adContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -177)
    dashFrame.adContainer:SetSize(DASH_W - 16, 20)
    dashFrame.adButtons = {}

    -- Busy mode toggle
    local halfW = math.floor((DASH_W - 24) / 2)
    dashFrame.busyBtn = CreateFrame("Button", nil, dashFrame, "UIPanelButtonTemplate")
    dashFrame.busyBtn:SetSize(halfW, 20)
    dashFrame.busyBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -201)
    dashFrame.busyBtn:GetFontString():SetFont(GameFontNormalSmall:GetFont())
    dashFrame.busyBtn:SetScript("OnClick", function()
        PS.db.busyMode = not PS.db.busyMode
        PS:RefreshDashboard()
        PS:Print("Busy mode: " .. (PS.db.busyMode and C.RED .. "ON" or C.GREEN .. "OFF") .. C.R)
    end)

    -- Take a Break (pause) button
    dashFrame.pauseBtn = CreateFrame("Button", nil, dashFrame, "UIPanelButtonTemplate")
    dashFrame.pauseBtn:SetSize(halfW, 20)
    dashFrame.pauseBtn:SetPoint("LEFT", dashFrame.busyBtn, "RIGHT", 4, 0)
    dashFrame.pauseBtn:GetFontString():SetFont(GameFontNormalSmall:GetFont())
    dashFrame.pauseBtn:SetScript("OnClick", function()
        if PS.paused then
            -- Resume
            PS.totalPausedTime = PS.totalPausedTime + (GetTime() - PS.pausedAt)
            PS.paused = false
            PS.pausedAt = 0
            if PS.db.enabled and PS.db.monitor.enabled and not PS.monitoringActive then
                PS:StartMonitoring()
            end
            PS:Print(C.GREEN .. "Break over — shop resumed!" .. C.R)
        else
            -- Pause
            PS.paused = true
            PS.pausedAt = GetTime()
            if PS.monitoringActive then
                PS:StopMonitoring()
            end
            PS:Print(C.YELLOW .. "Taking a break — monitoring paused. Session stats preserved." .. C.R)
        end
        PS:RefreshDashboard()
    end)

    -- Engagement section (integrated right panel)
    local ENG_W = 290
    f.DASH_W = DASH_W
    f.ENG_W = ENG_W

    -- Vertical separator between dashboard and engagements
    dashFrame.vertSep = dashFrame:CreateTexture(nil, "OVERLAY")
    dashFrame.vertSep:SetWidth(1)
    dashFrame.vertSep:SetPoint("TOPLEFT", f, "TOPLEFT", DASH_W, -4)
    dashFrame.vertSep:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", DASH_W, 4)
    dashFrame.vertSep:SetColorTexture(0.3, 0.3, 0.35, 0.6)
    dashFrame.vertSep:Hide()

    -- Engagement header
    dashFrame.engHeader = dashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dashFrame.engHeader:SetPoint("TOPLEFT", f, "TOPLEFT", DASH_W + 10, -8)
    dashFrame.engHeader:SetText("|cffffff00ENGAGEMENTS|r")
    dashFrame.engHeader:Hide()

    -- Clear button (engagement section)
    dashFrame.engClear = CreateFrame("Button", nil, dashFrame, "UIPanelButtonTemplate")
    dashFrame.engClear:SetSize(42, 16)
    dashFrame.engClear:SetPoint("TOPLEFT", f, "TOPLEFT", DASH_W + ENG_W - 96, -5)
    dashFrame.engClear:SetText("Clear")
    dashFrame.engClear:GetFontString():SetFont(GameFontNormalSmall:GetFont())
    dashFrame.engClear:SetScript("OnClick", function()
        PS:ClearQueue()
        PS:Print(C.GOLD .. "Engagements cleared." .. C.R)
    end)
    dashFrame.engClear:Hide()

    -- Hide engagement button
    dashFrame.engHide = CreateFrame("Button", nil, dashFrame, "UIPanelButtonTemplate")
    dashFrame.engHide:SetSize(42, 16)
    dashFrame.engHide:SetPoint("TOPLEFT", f, "TOPLEFT", DASH_W + ENG_W - 50, -5)
    dashFrame.engHide:SetText("Hide")
    dashFrame.engHide:GetFontString():SetFont(GameFontNormalSmall:GetFont())
    dashFrame.engHide:SetScript("OnClick", function()
        PS.db.toggleFrame.showEngagements = false
        PS:RefreshEngagementPanel()
    end)
    dashFrame.engHide:Hide()

    -- Engagement rows container
    dashFrame.engRows = {}

    -- Invisible Button overlay on the In Queue card for reliable click
    local queueBtn = CreateFrame("Button", nil, dashFrame)
    queueBtn:SetAllPoints(dashFrame.cardQueue)
    queueBtn:SetFrameLevel(dashFrame.cardQueue:GetFrameLevel() + 5)
    queueBtn:RegisterForClicks("LeftButtonUp")
    queueBtn:SetScript("OnClick", function()
        PS.db.toggleFrame.showEngagements = not (PS.db.toggleFrame.showEngagements ~= false)
        PS:RefreshEngagementPanel()
    end)
    queueBtn:SetScript("OnEnter", function(self)
        dashFrame.cardQueue:SetBackdropBorderColor(0.4, 0.6, 0.9, 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to show/hide engagements")
        GameTooltip:Show()
    end)
    queueBtn:SetScript("OnLeave", function(self)
        dashFrame.cardQueue:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.5)
        GameTooltip:Hide()
    end)

    -- "Show Engagements" tab (floats on the right edge of the dashboard frame)
    dashFrame.engShowBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    dashFrame.engShowBtn:SetSize(22, 80)
    dashFrame.engShowBtn:SetPoint("TOPLEFT", f, "TOPRIGHT", -1, -30)
    dashFrame.engShowBtn:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dashFrame.engShowBtn:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    dashFrame.engShowBtn:SetBackdropBorderColor(0.4, 0.6, 0.9, 0.8)
    dashFrame.engShowBtn:EnableMouse(true)
    local engTabLabel = dashFrame.engShowBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    engTabLabel:SetPoint("CENTER", 0, 0)
    engTabLabel:SetText("|cffffff00Q\nU\nE\nU\nE|r")
    dashFrame.engShowBtn.label = engTabLabel
    dashFrame.engShowBtn:SetScript("OnMouseUp", function()
        PS.db.toggleFrame.showEngagements = true
        PS:RefreshEngagementPanel()
    end)
    dashFrame.engShowBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.8, 1.0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show engagements")
        GameTooltip:Show()
    end)
    dashFrame.engShowBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.6, 0.9, 0.8)
        GameTooltip:Hide()
    end)
    dashFrame.engShowBtn:Hide()

    f.dashHeight = 227

    ----------------------------------------------------------------
    -- Update visual state  (compact <-> dashboard switch)
    ----------------------------------------------------------------
    local function UpdateState()
        if PS.db.enabled then
            title:Hide(); status:Hide(); dot:Hide()
            dashFrame:Show()
            f:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
            if PS.adBar then PS.adBar:Hide() end
            PS:RefreshDashboard()  -- cascades to RefreshEngagementPanel
        else
            -- CLOSED: compact mode
            f:SetSize(COMPACT_W, COMPACT_H)
            dashFrame:Hide()
            title:Show(); status:Show(); dot:Show()
            status:SetText("|cffff3333CLOSED|r")
            dot:SetTexture("Interface\\COMMON\\Indicator-Red")
            f:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
            f:SetBackdropBorderColor(0.8, 0.0, 0.0, 1)
        end
    end
    f.UpdateState = UpdateState

    -- Dragging
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PS.db.toggleFrame.point = point
        PS.db.toggleFrame.x = x
        PS.db.toggleFrame.y = y
    end)

    -- Click to toggle
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
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
            UpdateState()
            PS:RefreshEngagementPanel()
            PS:RefreshAdBar()
            PS:Print("Pro Shop is now " .. (PS.db.enabled and C.GREEN .. "OPEN" or C.RED .. "CLOSED") .. C.R)
        end
    end)

    -- Tooltip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cff00ccffPro Shop|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Status", PS.db.enabled and "|cff00ff00Open|r" or "|cffff3333Closed|r")
        GameTooltip:AddDoubleLine("Queue", "|cffffff00" .. #PS.queue .. "/" .. PS.db.queue.maxSize .. "|r")
        GameTooltip:AddDoubleLine("Tips (session)", "|cffffd700" .. (PS.db.tips.session or 0) .. "g|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Right-Click to toggle Open/Closed|r")
        GameTooltip:AddLine("|cff888888Drag to move|r")
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Restore saved position
    local saved = self.db.toggleFrame
    f:ClearAllPoints()
    f:SetPoint(saved.point or "TOP", UIParent, saved.point or "TOP", saved.x or 0, saved.y or -15)

    UpdateState()

    if not self.db.toggleFrame.show then
        f:Hide()
    end

    self.toggleFrame = f

    -- Auto-refresh dashboard stats every second
    C_Timer.NewTicker(1, function()
        if PS.toggleFrame and PS.toggleFrame.dashFrame and PS.toggleFrame.dashFrame:IsShown() then
            PS:RefreshDashboard()
        end
    end)
end

-- Update the toggle frame state externally (e.g., from slash command toggle)
function PS:UpdateToggleFrame()
    if self.toggleFrame and self.toggleFrame.UpdateState then
        self.toggleFrame:UpdateState()
    end
    self:RefreshEngagementPanel()
    self:RefreshAdBar()
end

------------------------------------------------------------------------
-- Dashboard Stats Refresh
------------------------------------------------------------------------
function PS:RefreshDashboard()
    if not self.toggleFrame or not self.toggleFrame.dashFrame then return end
    local df = self.toggleFrame.dashFrame
    if not df:IsShown() then return end

    -- Session duration (subtract paused time for accurate stats)
    local totalPaused = self.totalPausedTime or 0
    if self.paused and self.pausedAt > 0 then
        totalPaused = totalPaused + (GetTime() - self.pausedAt)
    end
    local elapsed = (GetTime() - (self.sessionStartTime or GetTime())) - totalPaused
    if elapsed < 0 then elapsed = 0 end
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local s = math.floor(elapsed % 60)
    local timeColor = self.paused and "|cffffff00" or "|cffffffff"
    df.sessionTime:SetText(timeColor .. string.format("%02d:%02d:%02d", h, m, s) .. (self.paused and " PAUSED" or "") .. "|r")

    -- Gold earned
    local gold = self.db.tips.session or 0
    df.cardEarned.value:SetText("|cffffd700" .. gold .. "g|r")

    -- Gold per hour
    local hrs = elapsed / 3600
    local gph = hrs > 0.01 and math.floor(gold / hrs) or 0
    df.cardGoldHr.value:SetText("|cffffd700" .. gph .. "g|r")

    -- Customers served
    df.cardServed.value:SetText("|cff00ff00" .. (self.customersServed or 0) .. "|r")

    -- Queue count
    df.cardQueue.value:SetText("|cffffff00" .. #self.queue .. "|r")

    -- Top tippers (session only)
    local tippers = {}
    local epoch = self.sessionStartEpoch or 0
    for _, entry in ipairs(self.db.tips.history or {}) do
        if entry.timestamp and entry.timestamp >= epoch then
            tippers[entry.name] = (tippers[entry.name] or 0) + entry.amount
        end
    end
    local sorted = {}
    for name, amount in pairs(tippers) do
        table.insert(sorted, { name = name, amount = amount })
    end
    table.sort(sorted, function(a, b) return a.amount > b.amount end)

    local medals = { "|cffffff00", "|cffaaaaaa", "|cffcd7f32" }
    for i = 1, 3 do
        local line = df.tipperLines[i]
        if sorted[i] then
            line:SetText(medals[i] .. i .. ".|r |cffffffff" .. sorted[i].name .. "|r  |cffffd700" .. sorted[i].amount .. "g|r")
            line:Show()
        elseif i == 1 then
            line:SetText("|cff555555No tips yet|r")
            line:Show()
        else
            line:SetText("")
            line:Hide()
        end
    end

    -- Busy button text
    if self.db.busyMode then
        df.busyBtn:SetText("Busy |cffff3333ON|r")
    else
        df.busyBtn:SetText("Busy |cff00ff00OFF|r")
    end

    -- Pause button text
    if self.paused then
        df.pauseBtn:SetText("|cff00ff00Resume|r")
    else
        df.pauseBtn:SetText("|cffffff00Break|r")
    end

    -- Refresh dashboard ad buttons
    self:RefreshDashboardAds()

    -- Refresh integrated engagement panel (handles sizing + border color)
    self:RefreshEngagementPanel()
end

------------------------------------------------------------------------
-- Dashboard Ad Buttons
------------------------------------------------------------------------
function PS:RefreshDashboardAds()
    if not self.toggleFrame or not self.toggleFrame.dashFrame then return end
    local df = self.toggleFrame.dashFrame
    if not df.adContainer then return end

    for _, btn in ipairs(df.adButtons) do btn:Hide() end

    if not self.db.enabled then
        df.adContainer:Hide()
        return
    end

    local profs = self:GetActiveAdProfessions()
    if #profs == 0 then
        df.adContainer:Hide()
        return
    end

    local SHORT = {
        ["Enchanting"]="Ench", ["Alchemy"]="Alch", ["Jewelcrafting"]="JC",
        ["Tailoring"]="Tail", ["Leatherworking"]="LW", ["Blacksmithing"]="BS",
        ["Engineering"]="Eng", ["Cooking"]="Cook", ["First Aid"]="FA",
        ["Lockpicking"]="Locks", ["Portals"]="Ports", ["Summons"]="Summ",
    }

    local x = 0
    for i, prof in ipairs(profs) do
        local btn = df.adButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, df.adContainer, "UIPanelButtonTemplate")
            btn:SetHeight(18)
            btn:GetFontString():SetFont(GameFontNormalSmall:GetFont())
            df.adButtons[i] = btn
        end
        local lbl = SHORT[prof] or prof:sub(1, 5)
        btn:SetText(lbl)
        btn:SetWidth(btn:GetFontString():GetStringWidth() + 16)
        btn:SetPoint("LEFT", df.adContainer, "LEFT", x, 0)
        btn:Show()
        btn:SetScript("OnClick", function() PS:BroadcastSingleAd(prof) end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Broadcast " .. prof .. " ad")
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        x = x + btn:GetWidth() + 2
    end
    df.adContainer:Show()
end

------------------------------------------------------------------------
-- Quick Ad Bar  (floating profession ad buttons below toggle frame)
------------------------------------------------------------------------
function PS:CreateAdBar()
    if self.adBar then return end
    if not self.toggleFrame then return end

    local f = CreateFrame("Frame", "ProShopAdBar", UIParent, "BackdropTemplate")
    f:SetSize(130, 24)
    f:SetPoint("TOP", self.toggleFrame, "BOTTOM", 0, -1)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
    f:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.8)

    f.buttons = {}
    f:Hide()
    self.adBar = f
end

function PS:RefreshAdBar()
    -- Dashboard has its own ad buttons; hide standalone bar when dashboard visible
    if self.toggleFrame and self.toggleFrame.dashFrame and self.toggleFrame.dashFrame:IsShown() then
        if self.adBar then self.adBar:Hide() end
        return
    end

    if not self.adBar then
        self:CreateAdBar()
    end
    if not self.adBar then return end

    local bar = self.adBar

    -- Hide existing buttons
    for _, btn in ipairs(bar.buttons) do
        btn:Hide()
    end

    if not self.db.enabled then
        bar:Hide()
        return
    end

    -- Gather active ad professions
    local profs = self:GetActiveAdProfessions()
    if #profs == 0 then
        bar:Hide()
        return
    end

    -- Short labels for profession buttons
    local SHORT_NAMES = {
        ["Enchanting"] = "Ench",
        ["Alchemy"] = "Alch",
        ["Jewelcrafting"] = "JC",
        ["Tailoring"] = "Tail",
        ["Leatherworking"] = "LW",
        ["Blacksmithing"] = "BS",
        ["Engineering"] = "Eng",
        ["Cooking"] = "Cook",
        ["First Aid"] = "FA",
        ["Lockpicking"] = "Locks",
        ["Portals"] = "Ports",
        ["Summons"] = "Summ",
    }

    local BTN_HEIGHT = 18
    local BTN_PAD = 2
    local x = 4
    local maxWidth = 0

    for i, profName in ipairs(profs) do
        local btn = bar.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
            btn:SetHeight(BTN_HEIGHT)
            btn:GetFontString():SetFont(GameFontNormalSmall:GetFont())
            bar.buttons[i] = btn
        end

        local label = SHORT_NAMES[profName] or profName:sub(1, 5)
        btn:SetText(label)
        btn:SetWidth(btn:GetFontString():GetStringWidth() + 16)
        btn:SetPoint("LEFT", bar, "LEFT", x, 0)
        btn:Show()

        btn:SetScript("OnClick", function()
            PS:BroadcastSingleAd(profName)
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Broadcast " .. profName .. " ad to trade chat")
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        x = x + btn:GetWidth() + BTN_PAD
    end

    maxWidth = x + 2
    bar:SetSize(math.max(maxWidth, 60), BTN_HEIGHT + 8)
    bar:Show()
end

------------------------------------------------------------------------
-- Engagement Panel  (integrated into dashboard right side)
------------------------------------------------------------------------
function PS:CreateEngagementPanel()
    -- Engagement panel is now integrated into the dashboard
    -- This function is kept as a no-op for backward compatibility
end

function PS:RefreshEngagementPanel()
    if not self.toggleFrame or not self.toggleFrame.dashFrame then return end
    local df = self.toggleFrame.dashFrame
    local f  = self.toggleFrame
    if not df:IsShown() then
        -- Dashboard not visible — just set border for CLOSED state
        return
    end

    -- Hide all existing engagement rows
    for _, row in ipairs(df.engRows) do row:Hide() end

    local DASH_W  = f.DASH_W or 240
    local ENG_W   = f.ENG_W  or 290
    local showEng = self.db.toggleFrame.showEngagements ~= false and #self.queue > 0

    if showEng then
        -- ── Show engagement section ──────────────────────────────
        df.vertSep:Show()
        df.engHeader:Show()
        df.engClear:Show()
        df.engHide:Show()

        local ROW_H       = 44
        local engContentW  = ENG_W - 16
        local MAX_MSG_LEN  = 38
        local y = -24

        for i, customer in ipairs(self.queue) do
            local row = df.engRows[i]
            if not row then
                row = CreateFrame("Frame", nil, df)
                row:SetSize(engContentW, ROW_H)

                -- State dot
                local dot = row:CreateTexture(nil, "OVERLAY")
                dot:SetSize(8, 8)
                dot:SetPoint("TOPLEFT", 4, -6)
                dot:SetTexture("Interface\\COMMON\\Indicator-Green")
                row.dot = dot

                -- Name + item
                local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameText:SetPoint("TOPLEFT", 16, -4)
                nameText:SetPoint("RIGHT", row, "RIGHT", -54, 0)
                nameText:SetJustifyH("LEFT")
                row.nameText = nameText

                -- Original message
                local msgText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                msgText:SetPoint("TOPLEFT", 16, -17)
                msgText:SetWidth(engContentW - 20)
                msgText:SetJustifyH("LEFT")
                row.msgText = msgText

                -- Invite button
                local invBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                invBtn:SetSize(44, 16)
                invBtn:SetPoint("TOPRIGHT", -2, -3)
                invBtn:SetText("Invite")
                invBtn:GetFontString():SetFont(GameFontNormalSmall:GetFont())
                invBtn:SetScript("OnClick", function()
                    local c = row.customer
                    if c and c.name then
                        PS:InvitePlayer(c.name)
                        c.state = "INVITED"
                        PS:RefreshEngagementPanel()
                    end
                end)
                row.invBtn = invBtn

                -- Ignore button
                local ignBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                ignBtn:SetSize(44, 14)
                ignBtn:SetPoint("BOTTOMRIGHT", -50, 2)
                ignBtn:SetText("Ignore")
                ignBtn:GetFontString():SetFont(GameFontNormalSmall:GetFont())
                ignBtn:SetScript("OnClick", function()
                    local c = row.customer
                    if c and c.name then
                        local IGNORE_DURATION = 3600
                        local cooldown = (PS.db and PS.db.monitor and PS.db.monitor.contactCooldown) or 120
                        PS.recentContacts[c.name:lower()] = GetTime() + (IGNORE_DURATION - cooldown)
                        PS:RemoveFromQueue(c.name)
                        PS:Print(PS.C.GOLD .. c.name .. PS.C.R .. " ignored for 1 hour.")
                    end
                end)
                row.ignBtn = ignBtn

                -- Blacklist button
                local blBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                blBtn:SetSize(50, 14)
                blBtn:SetPoint("BOTTOMRIGHT", -2, 2)
                blBtn:SetText("Blacklist")
                blBtn:GetFontString():SetFont(GameFontNormalSmall:GetFont())
                blBtn:SetScript("OnClick", function()
                    local c = row.customer
                    if c and c.name then
                        PS:RemoveFromQueue(c.name)
                        PS.db.blacklist[c.name] = true
                        PS:Print(PS.C.RED .. c.name .. PS.C.R .. " blacklisted.")
                    end
                end)
                row.blBtn = blBtn

                -- Separator
                local sep = row:CreateTexture(nil, "OVERLAY")
                sep:SetHeight(1)
                sep:SetPoint("BOTTOMLEFT", 4, 0)
                sep:SetPoint("BOTTOMRIGHT", -4, 0)
                sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
                row.sep = sep

                df.engRows[i] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", DASH_W + 6, y)

            -- State indicator
            local stateIcon
            if customer.state == "IN_PROGRESS" then
                stateIcon = "Interface\\COMMON\\Indicator-Yellow"
            elseif customer.state == "COMPLETED" then
                stateIcon = "Interface\\COMMON\\Indicator-Gray"
            else
                stateIcon = "Interface\\COMMON\\Indicator-Green"
            end
            row.dot:SetTexture(stateIcon)

            -- State tag
            local stateTag = ""
            if customer.state == "IN_PROGRESS" then
                stateTag = " |cffffff00[serving]|r"
            elseif customer.state == "INVITED" then
                stateTag = " |cff888888[invited]|r"
            elseif customer.state == "BUSY_NOTIFIED" then
                stateTag = " |cffff8800[busy]|r"
            end

            row.nameText:SetText(
                "|cff00ff00" .. customer.name .. "|r" ..
                " - |cff00ccff" .. (customer.item or customer.profession or "?") .. "|r" ..
                stateTag
            )

            row.customer = customer
            if customer.state == "INVITED" or customer.state == "IN_PROGRESS" or customer.state == "COMPLETED" then
                row.invBtn:Hide()
            else
                row.invBtn:Show()
            end

            -- Original message (truncated)
            local origMsg = customer.originalMessage or ""
            origMsg = origMsg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]+|h", ""):gsub("|h", "")
            if #origMsg > MAX_MSG_LEN then
                origMsg = origMsg:sub(1, MAX_MSG_LEN) .. "..."
            end
            row.msgText:SetText("|cff999999\"" .. origMsg .. "\"|r")

            row:Show()
            y = y - ROW_H
        end

        -- Calculate frame size
        local engH   = 24 + (#self.queue * ROW_H) + 6
        local frameH = math.max(f.dashHeight, engH)
        f:SetSize(DASH_W + ENG_W, frameH)

        -- Update queue card label with collapse indicator
        df.cardQueue.label:SetText("|cff888888In Queue \226\151\128|r")
        df.engShowBtn:Hide()
    else
        -- ── Hide engagement section ──────────────────────────────
        df.vertSep:Hide()
        df.engHeader:Hide()
        df.engClear:Hide()
        df.engHide:Hide()
        f:SetSize(DASH_W, f.dashHeight)

        -- Update queue card label with expand indicator (only if queue has items)
        if #self.queue > 0 then
            df.cardQueue.label:SetText("|cff888888In Queue \226\150\182|r")
            df.engShowBtn:Show()
        else
            df.cardQueue.label:SetText("|cff888888In Queue|r")
            df.engShowBtn:Hide()
        end
    end

    -- Border color (paused = yellow, running = green)
    if self.paused then
        f:SetBackdropBorderColor(0.8, 0.7, 0.0, 1)
    elseif self.db.enabled then
        f:SetBackdropBorderColor(0.0, 0.7, 0.0, 1)
    end
end

------------------------------------------------------------------------
-- Minimap Button (standard conventions for minimap collectors)
------------------------------------------------------------------------
function PS:CreateMinimapButton()
    if self.minimapButton then return end

    -- Use a standard naming pattern that minimap collectors recognize
    local btn = CreateFrame("Button", "LibDBIcon10_ProShop", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:EnableMouse(true)

    -- Standard minimap button textures (same pattern as LibDBIcon)
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", 0, 0)

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetAllPoints()

    -- Glow overlay for queue notifications
    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetSize(36, 36)
    glow:SetPoint("CENTER", 0, 0)
    glow:Hide()
    btn.glow = glow

    -- Queue count badge
    local badge = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    badge:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
    badge:Hide()
    btn.badge = badge

    -- Position around minimap
    local function UpdatePosition()
        local angle = math.rad(PS.db.minimap.position or 195)
        local x = 80 * math.cos(angle)
        local y = 80 * math.sin(angle)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- Dragging
    local isDragging = false
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        isDragging = true
    end)
    btn:SetScript("OnDragStop", function(self)
        isDragging = false
    end)
    btn:SetScript("OnUpdate", function(self)
        if not isDragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        PS.db.minimap.position = angle
        UpdatePosition()
    end)

    -- Click handlers
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() then
                PS:BroadcastAd()
            elseif IsControlKeyDown() then
                PS.db.busyMode = not PS.db.busyMode
                PS:Print("Busy mode: " .. (PS.db.busyMode and C.RED .. "ON" or C.GREEN .. "OFF") .. C.R)
            else
                PS:ToggleUI()
            end
        elseif button == "RightButton" then
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
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(C.CYAN .. "Pro Shop" .. C.R .. " v" .. PS.VERSION)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(C.WHITE .. "Status: " .. (PS.db.enabled and C.GREEN .. "Enabled" or C.RED .. "Disabled") .. C.R)
        GameTooltip:AddLine(C.WHITE .. "Busy: " .. (PS.db.busyMode and C.RED .. "Yes" or C.GREEN .. "No") .. C.R)
        GameTooltip:AddLine(C.WHITE .. "Queue: " .. C.YELLOW .. #PS.queue .. "/" .. PS.db.queue.maxSize .. C.R)
        GameTooltip:AddLine(C.WHITE .. "Tips: " .. C.GOLD .. (PS.db.tips.session or 0) .. "g (session)" .. C.R)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(C.GREEN .. "Left-Click", C.GRAY .. "Open config")
        GameTooltip:AddDoubleLine(C.GREEN .. "Shift-Click", C.GRAY .. "Broadcast ad")
        GameTooltip:AddDoubleLine(C.GREEN .. "Ctrl-Click", C.GRAY .. "Toggle busy")
        GameTooltip:AddDoubleLine(C.GREEN .. "Right-Click", C.GRAY .. "Enable/Disable")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    UpdatePosition()

    -- Show/hide based on saved setting
    if not self.db.minimap.show then
        btn:Hide()
    end

    self.minimapButton = btn

    -- Periodic update for glow badge
    C_Timer.NewTicker(3, function()
        PS:UpdateMinimapGlow()
    end)
end

-- Update minimap glow/badge when queue changes
function PS:UpdateMinimapGlow()
    local btn = self.minimapButton
    if not btn then return end
    local count = #self.queue
    if count > 0 then
        btn.glow:Show()
        btn.badge:SetText(C.GREEN .. count .. C.R)
        btn.badge:Show()
    else
        btn.glow:Hide()
        btn.badge:Hide()
    end
end

-- Toggle minimap button visibility
function PS:SetMinimapButtonShown(show)
    self.db.minimap.show = show
    if show then
        if not self.minimapButton then
            self:CreateMinimapButton()
        else
            self.minimapButton:Show()
        end
    else
        if self.minimapButton then
            self.minimapButton:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Main Config UI
------------------------------------------------------------------------
local MainFrame = nil

-- Helper: create a section header
local function CreateHeader(parent, text, x, y)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText(C.GOLD .. text .. C.R)
    return header
end

-- Helper: create a label
local function CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

-- Helper: create a checkbox
local function CreateCheckbox(parent, label, x, y, dbPath, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(26, 26)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    -- Set initial state
    local keys = { strsplit(".", dbPath) }
    local function GetValue()
        local t = PS.db
        for i, k in ipairs(keys) do
            if i < #keys then t = t[k] else return t[k] end
        end
    end
    local function SetValue(val)
        local t = PS.db
        for i, k in ipairs(keys) do
            if i < #keys then t = t[k] else t[k] = val end
        end
    end

    cb:SetChecked(GetValue())
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        SetValue(checked)
        PlaySound(checked and 856 or 857)

        -- Special handling for key toggles
        if dbPath == "enabled" then
            -- Master toggle: start/stop monitoring and update toggle frame
            if checked then
                if PS.db.monitor.enabled and not PS.monitoringActive then
                    PS:StartMonitoring()
                end
            else
                if PS.monitoringActive then
                    PS:StopMonitoring()
                end
            end
            PS:UpdateToggleFrame()
            PS:RefreshEngagementPanel()
            PS:Print("Pro Shop is now " .. (checked and PS.C.GREEN .. "OPEN" or PS.C.RED .. "CLOSED") .. PS.C.R)
        elseif dbPath == "monitor.enabled" then
            if checked and PS.db.enabled then
                PS:StartMonitoring()
            else
                PS:StopMonitoring()
            end
        end
    end)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    cb.Refresh = function()
        cb:SetChecked(GetValue())
    end

    return cb
end

-- Helper: create a slider
local sliderCounter = 0
local function CreateSlider(parent, label, x, y, min, max, step, dbPath, formatFunc)
    sliderCounter = sliderCounter + 1
    local sliderName = "ProShopSlider" .. sliderCounter

    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    container:SetSize(300, 64)

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, 0)

    local slider = CreateFrame("Slider", sliderName, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 5, -20)
    slider:SetSize(260, 17)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    -- Add a visible background track behind the slider
    local bg = slider:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    bg:SetSize(262, 8)
    bg:SetPoint("CENTER", 0, -1)
    bg:SetVertexColor(0.15, 0.15, 0.15, 1.0)

    -- Use template's built-in Low / High / Text font strings
    local lowText = _G[sliderName .. "Low"]
    local highText = _G[sliderName .. "High"]
    local titleText = _G[sliderName .. "Text"]

    -- Hide the template's center title (we use our own above the slider)
    if titleText then titleText:SetText("") titleText:Hide() end

    -- Set initial value
    local keys = { strsplit(".", dbPath) }
    local function GetValue()
        local t = PS.db
        for i, k in ipairs(keys) do
            if i < #keys then t = t[k] else return t[k] end
        end
    end
    local function SetValue(val)
        local t = PS.db
        for i, k in ipairs(keys) do
            if i < #keys then t = t[k] else t[k] = val end
        end
    end

    local val = GetValue() or min
    slider:SetValue(val)
    local displayFunc = formatFunc or function(v) return tostring(math.floor(v)) end
    title:SetText(label .. ": " .. C.WHITE .. displayFunc(val) .. C.R)

    -- Set the Low/High labels from the template
    if lowText then
        lowText:ClearAllPoints()
        lowText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 2, -3)
        lowText:SetText(C.GRAY .. "Low: " .. displayFunc(min) .. C.R)
        lowText:Show()
    end
    if highText then
        highText:ClearAllPoints()
        highText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -2, -3)
        highText:SetText(C.GRAY .. "High: " .. displayFunc(max) .. C.R)
        highText:Show()
    end

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step) * step
        SetValue(value)
        title:SetText(label .. ": " .. C.WHITE .. displayFunc(value) .. C.R)
    end)

    return container
end

-- Helper: create an editable text box
local function CreateEditBox(parent, label, x, y, width, dbPath)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    container:SetSize(width + 10, 45)

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local eb = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", 5, -16)
    eb:SetSize(width, 22)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(250)

    local keys = { strsplit(".", dbPath) }
    local function GetValue()
        local t = PS.db
        for i, k in ipairs(keys) do
            if i < #keys then t = t[k] else return t[k] end
        end
    end
    local function SetValue(val)
        local t = PS.db
        for i, k in ipairs(keys) do
            if i < #keys then t = t[k] else t[k] = val end
        end
    end

    eb:SetText(GetValue() or "")
    eb:SetScript("OnEnterPressed", function(self)
        SetValue(self:GetText())
        self:ClearFocus()
        PS:Print(C.GREEN .. "Saved: " .. C.R .. label)
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(GetValue() or "")
        self:ClearFocus()
    end)

    return container, eb
end

-- Helper: create a button
local function CreateButton(parent, text, x, y, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetSize(width, height)
    btn:SetText(text)
    btn:SetScript("OnClick", function()
        PlaySound(856)
        onClick()
    end)
    return btn
end

------------------------------------------------------------------------
-- Build the Main Frame
------------------------------------------------------------------------
function PS:CreateMainFrame()
    if MainFrame then return MainFrame end

    -- Main frame
    local f = CreateFrame("Frame", "ProShopMainFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(520, 620)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, relativeTo, relPoint, xOfs, yOfs = self:GetPoint()
        PS.db.framePosition = { point, nil, relPoint, xOfs, yOfs }
    end)
    f:SetClampedToScreen(true)

    -- Restore saved position
    if PS.db.framePosition then
        local pos = PS.db.framePosition
        f:ClearAllPoints()
        f:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
    end
    f:SetFrameStrata("DIALOG")

    -- Title
    f.TitleText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.TitleText:SetPoint("TOP", 0, -5)
    f.TitleText:SetText(C.CYAN .. "Pro Shop" .. C.R .. " " .. C.GRAY .. "v" .. PS.VERSION .. C.R)

    -- Tab buttons
    local tabs = { "General", "Monitor", "Advertise", "Whispers", "Queue", "Credits" }
    f.tabs = {}
    f.tabFrames = {}

    for i, tabName in ipairs(tabs) do
        local tab = CreateFrame("Button", "ProShopMainFrameTab" .. i, f, "CharacterFrameTabButtonTemplate")
        tab:SetText(tabName)
        tab:SetID(i)
        if i == 1 then
            tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 5, 2)
        else
            tab:SetPoint("LEFT", f.tabs[i-1], "RIGHT", -14, 0)
        end
        PanelTemplates_SetNumTabs(f, #tabs)
        tab:SetScript("OnClick", function()
            PanelTemplates_SetTab(f, i)
            PS:ShowTab(i)
        end)
        f.tabs[i] = tab

        -- Tab content frame
        local tf = CreateFrame("Frame", nil, f)
        tf:SetPoint("TOPLEFT", f.InsetBg or f, "TOPLEFT", 10, -30)
        tf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
        tf:Hide()
        f.tabFrames[i] = tf
    end

    PanelTemplates_SetTab(f, 1)

    -- Build each tab's content
    self:BuildGeneralTab(f.tabFrames[1])
    self:BuildMonitorTab(f.tabFrames[2])
    self:BuildAdvertiseTab(f.tabFrames[3])
    self:BuildWhispersTab(f.tabFrames[4])
    self:BuildQueueTab(f.tabFrames[5])
    self:BuildCreditsTab(f.tabFrames[6])

    -- Show first tab
    f.tabFrames[1]:Show()

    f:Hide() -- Start hidden
    MainFrame = f
    return f
end

function PS:ShowTab(index)
    if not MainFrame then return end
    for i, tf in ipairs(MainFrame.tabFrames) do
        if i == index then
            tf:Show()
        else
            tf:Hide()
        end
    end
    -- Refresh dynamic tabs when shown
    if index == 3 then
        self:RefreshAdvertiseTab()
    elseif index == 5 then
        self:RefreshQueueTab()
    end
end

------------------------------------------------------------------------
-- Tab 1: General
------------------------------------------------------------------------
function PS:BuildGeneralTab(parent)
    local y = -5

    CreateHeader(parent, "General Settings", 5, y)
    y = y - 30

    CreateCheckbox(parent, "Enable Pro Shop", 10, y, "enabled",
        "Master toggle for the entire addon.")
    y = y - 30

    CreateCheckbox(parent, "Busy Mode", 10, y, "busyMode",
        "When enabled, new customers get a 'busy' message instead of an invite.")
    y = y - 30

    CreateCheckbox(parent, "Debug Mode", 10, y, "debug",
        "Show debug messages in chat for troubleshooting.")
    y = y - 30

    -- Minimap button checkbox
    local mmCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    mmCb:SetPoint("TOPLEFT", 10, y)
    mmCb:SetSize(26, 26)
    local mmText = mmCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmText:SetPoint("LEFT", mmCb, "RIGHT", 4, 0)
    mmText:SetText("Show Minimap Button")
    mmCb:SetChecked(PS.db.minimap.show)
    mmCb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PS:SetMinimapButtonShown(checked)
        PlaySound(checked and 856 or 857)
    end)
    mmCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show or hide the Pro Shop minimap button.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    mmCb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 40

    -- Active Professions - controls monitoring, auto-invite, whispers
    CreateHeader(parent, "Active Professions", 5, y)
    y = y - 20

    local activeInfo = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    activeInfo:SetPoint("TOPLEFT", 15, y)
    activeInfo:SetWidth(460)
    activeInfo:SetText(C.GRAY .. "Checked professions will respond to requests (monitor, auto-invite, whisper). Advertising has its own toggles in the Advertise tab." .. C.R)
    y = y - 28

    local sorted = {}
    for name, _ in pairs(PS.professions) do
        table.insert(sorted, name)
    end
    table.sort(sorted)

    for _, profName in ipairs(sorted) do
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 10, y)
        cb:SetSize(24, 24)

        local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0)

        local profData = PS.professions[profName]
        local skillLevel = profData and profData.skill or "?"
        local maxSkill = profData and profData.maxSkill or "?"
        local recipeCount = profData and profData.numRecipes or 0
        cbText:SetText(C.CYAN .. profName .. C.R .. " " .. C.GRAY .. "(" .. skillLevel .. "/" .. maxSkill .. ") " .. recipeCount .. " recipes" .. C.R)

        local isActive = PS:IsProfessionActive(profName)
        cb:SetChecked(isActive)

        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            if not PS.db.activeProfessions then
                PS.db.activeProfessions = {}
            end
            if not next(PS.db.activeProfessions) then
                for _, pName in ipairs(sorted) do
                    PS.db.activeProfessions[pName] = PS:IsProfessionActive(pName)
                end
            end
            PS.db.activeProfessions[profName] = checked
            PlaySound(checked and 856 or 857)
            -- Refresh ad bar to reflect new active professions
            PS:RefreshAdBar()
        end)

        -- Auto-Invite toggle per profession
        local aiCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        aiCb:SetPoint("LEFT", cbText, "RIGHT", 8, 0)
        aiCb:SetSize(20, 20)

        local aiLabel = aiCb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        aiLabel:SetPoint("LEFT", aiCb, "RIGHT", 0, 0)
        aiLabel:SetText(C.GRAY .. "Auto-Inv" .. C.R)

        local aiActive = PS:IsProfessionAutoInvite(profName)
        aiCb:SetChecked(aiActive)

        aiCb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            if not PS.db.autoInviteByProfession then
                PS.db.autoInviteByProfession = {}
            end
            PS.db.autoInviteByProfession[profName] = checked
            PlaySound(checked and 856 or 857)
        end)
        aiCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Auto-Invite for " .. profName)
            GameTooltip:AddLine("When ON: customers are automatically invited (with zone check).\nWhen OFF: customers are queued only — you decide to invite from the engagement panel.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        aiCb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        y = y - 26
    end

    if #sorted == 0 then
        local noProf = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noProf:SetPoint("TOPLEFT", 15, y)
        noProf:SetText(C.GRAY .. "No professions detected yet. Try /ps scan" .. C.R)
        y = y - 20
    end

    y = y - 10

    local function RefreshProfessions() end  -- placeholder for button below

    CreateButton(parent, "Rescan Professions", 10, y, 160, 25, function()
        PS:ScanProfessions()
        RefreshProfessions()
        PS:Print("Professions rescanned!")
    end)

    CreateButton(parent, "Deep Scan Recipes", 180, y, 160, 25, function()
        PS:DeepScanProfessions()
    end)

    y = y - 40

    -- Stats summary
    CreateHeader(parent, "Session Stats", 5, y)
    y = y - 25

    local statsText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", 15, y)
    statsText:SetWidth(460)
    statsText:SetJustifyH("LEFT")
    statsText:SetText(
        C.WHITE .. "Tips (session): " .. C.GOLD .. (PS.db.tips.session or 0) .. "g" .. C.R .. "\n" ..
        C.WHITE .. "Tips (lifetime): " .. C.GOLD .. (PS.db.tips.total or 0) .. "g" .. C.R .. "\n" ..
        C.WHITE .. "Customers served: " .. C.GREEN .. "0" .. C.R
    )

    y = y - 50

    -- Cooldowns section
    CreateHeader(parent, "Profession Cooldowns", 5, y)
    y = y - 25

    local cdText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdText:SetPoint("TOPLEFT", 15, y)
    cdText:SetWidth(460)
    cdText:SetJustifyH("LEFT")

    local function RefreshCooldowns()
        local cds = PS:CheckCooldowns()
        if #cds == 0 then
            cdText:SetText(C.GRAY .. "No tracked cooldowns." .. C.R)
        else
            local lines = {}
            for _, cd in ipairs(cds) do
                local status = cd.ready and (C.GREEN .. "READY" .. C.R) or
                    (C.RED .. PS:FormatTime(cd.remaining) .. C.R)
                table.insert(lines, C.CYAN .. cd.profession .. C.R .. " - " .. cd.name .. ": " .. status)
            end
            cdText:SetText(table.concat(lines, "\n"))
        end
    end
    RefreshCooldowns()

    CreateButton(parent, "Refresh", 10, y - 50, 100, 22, function()
        RefreshProfessions()
        RefreshCooldowns()
        statsText:SetText(
            C.WHITE .. "Tips (session): " .. C.GOLD .. (PS.db.tips.session or 0) .. "g" .. C.R .. "\n" ..
            C.WHITE .. "Tips (lifetime): " .. C.GOLD .. (PS.db.tips.total or 0) .. "g" .. C.R .. "\n" ..
            C.WHITE .. "Queue: " .. C.GREEN .. #PS.queue .. C.R
        )
    end)
end

------------------------------------------------------------------------
-- Tab 2: Monitor Settings
------------------------------------------------------------------------
function PS:BuildMonitorTab(parent)
    local y = -5

    CreateHeader(parent, "Chat Monitoring", 5, y)
    y = y - 30

    CreateCheckbox(parent, "Enable Monitoring", 10, y, "monitor.enabled",
        "Monitor chat channels for crafting requests.")
    y = y - 30

    CreateCheckbox(parent, "Monitor Trade Chat", 10, y, "monitor.tradeChat",
        "Watch trade chat for people looking for profession services.")
    y = y - 30

    CreateCheckbox(parent, "Monitor General Chat", 10, y, "monitor.generalChat",
        "Also watch general chat (may produce more false positives).")
    y = y - 30

    CreateCheckbox(parent, "Monitor LFG Channel", 10, y, "monitor.lfgChat",
        "Watch the Looking For Group channel for profession requests.")
    y = y - 40

    CreateHeader(parent, "Auto-Actions", 5, y)
    y = y - 30

    CreateCheckbox(parent, "Auto-Invite Customers", 10, y, "monitor.autoInvite",
        "Automatically send a group invite when a matching request is found.")
    y = y - 30

    CreateCheckbox(parent, "Auto-Whisper Greeting", 10, y, "monitor.autoWhisper",
        "Automatically whisper customers with a greeting and ask about mats.")
    y = y - 30

    CreateCheckbox(parent, "Sound Alert", 10, y, "monitor.soundAlert",
        "Play a sound when a new customer is detected.")
    y = y - 35

    CreateSlider(parent, "Contact Cooldown", 10, y, 30, 600, 15, "monitor.contactCooldown",
        function(v)
            local mins = math.floor(v / 60)
            local secs = v % 60
            if mins > 0 then return mins .. "m " .. secs .. "s" end
            return secs .. "s"
        end)
    y = y - 70

    CreateHeader(parent, "Blacklist", 5, y)
    y = y - 25

    local blText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blText:SetPoint("TOPLEFT", 15, y)
    blText:SetWidth(460)
    blText:SetJustifyH("LEFT")

    local function RefreshBlacklist()
        local names = {}
        for name, _ in pairs(PS.db.blacklist) do
            table.insert(names, C.RED .. name .. C.R)
        end
        if #names == 0 then
            blText:SetText(C.GRAY .. "No blacklisted players. Use /ps bl <name> to add." .. C.R)
        else
            blText:SetText(table.concat(names, ", "))
        end
    end
    RefreshBlacklist()

    y = y - 30

    -- Standalone edit box for blacklist (not bound to a db path)
    local blContainer = CreateFrame("Frame", nil, parent)
    blContainer:SetPoint("TOPLEFT", 10, y)
    blContainer:SetSize(210, 45)
    local blTitle = blContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blTitle:SetPoint("TOPLEFT", 0, 0)
    blTitle:SetText("Add to Blacklist:")
    local blInput = CreateFrame("EditBox", nil, blContainer, "InputBoxTemplate")
    blInput:SetPoint("TOPLEFT", 5, -16)
    blInput:SetSize(200, 22)
    blInput:SetAutoFocus(false)
    blInput:SetMaxLetters(50)
    blInput:SetScript("OnEnterPressed", function(self)
        local name = self:GetText():trim()
        if name ~= "" then
            PS:ToggleBlacklist(name)
            self:SetText("")
            self:ClearFocus()
            RefreshBlacklist()
        end
    end)
    blInput:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    y = y - 50

    CreateButton(parent, "Add", 220, y + 50 + 16, 80, 22, function()
        local name = blInput:GetText():trim()
        if name ~= "" then
            PS:ToggleBlacklist(name)
            blInput:SetText("")
            blInput:ClearFocus()
            RefreshBlacklist()
        end
    end)

    CreateButton(parent, "Clear Blacklist", 310, y + 50 + 16, 120, 22, function()
        PS.db.blacklist = {}
        PS:Print("Blacklist cleared.")
        RefreshBlacklist()
    end)
end

------------------------------------------------------------------------
-- Tab 3: Advertise Settings
------------------------------------------------------------------------
function PS:BuildAdvertiseTab(parent)
    local y = -5

    CreateHeader(parent, "Advertising", 5, y)
    y = y - 20

    local infoText1 = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText1:SetPoint("TOPLEFT", 15, y)
    infoText1:SetWidth(460)
    infoText1:SetText(C.GRAY .. "Write your own ad per profession. Leave blank for auto-generated default. Press Enter to save." .. C.R)
    y = y - 30

    -- Ad-specific profession toggles
    CreateHeader(parent, "Professions to Advertise", 5, y)
    y = y - 5

    local infoText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 15, y)
    infoText:SetWidth(460)
    infoText:SetText(C.GRAY .. "Controls which professions appear in broadcast ads. Professions must also be enabled in the General tab. Write custom ads or leave blank for auto-generated defaults." .. C.R)
    y = y - 28

    -- Scrollable container for profession entries
    local scrollFrame = CreateFrame("ScrollFrame", "ProShopAdScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, y)
    scrollFrame:SetSize(465, 260)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(445, 800)
    scrollFrame:SetScrollChild(content)

    -- Store reference for refresh
    self.adScrollContent = content
    self:PopulateAdProfessions(content)

    y = y - 270

    CreateHeader(parent, "Broadcast", 5, y)
    y = y - 30

    CreateButton(parent, "Broadcast Next", 10, y, 150, 28, function()
        PS:BroadcastAd()
    end)

    CreateButton(parent, "Broadcast All", 170, y, 150, 28, function()
        PS:BroadcastAllAds()
    end)

    local broadcastInfo = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    broadcastInfo:SetPoint("TOPLEFT", 330, y - 5)
    broadcastInfo:SetWidth(160)
    broadcastInfo:SetText(C.GRAY .. "\"Next\" rotates one profession per click." .. C.R)
end

------------------------------------------------------------------------
-- Advertise Tab: Populate profession list (reusable for refresh)
------------------------------------------------------------------------
function PS:PopulateAdProfessions(content)
    -- Clear existing children
    local kids = { content:GetChildren() }
    for _, child in ipairs(kids) do child:Hide(); child:SetParent(nil) end
    local regions = { content:GetRegions() }
    for _, region in ipairs(regions) do region:Hide(); region:SetParent(nil) end

    local sorted = {}
    for name, _ in pairs(PS.professions) do
        table.insert(sorted, name)
    end
    table.sort(sorted)

    local cy = 0
    for _, profName in ipairs(sorted) do
        local globallyActive = PS:IsProfessionActive(profName)

        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 0, cy)
        cb:SetSize(24, 24)

        local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0)

        local profData = PS.professions[profName]
        local skillLevel = profData and profData.skill or "?"

        if globallyActive then
            cbText:SetText(C.CYAN .. profName .. C.R .. " " .. C.GRAY .. "(" .. skillLevel .. ")" .. C.R)
        else
            cbText:SetText(C.GRAY .. profName .. " (" .. skillLevel .. ") [disabled in General]" .. C.R)
        end

        local isAdActive = PS:IsProfessionAdActive(profName)
        cb:SetChecked(isAdActive)
        cb:SetEnabled(globallyActive)

        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            if not PS.db.advertise.activeProfessions then
                PS.db.advertise.activeProfessions = {}
            end
            if not next(PS.db.advertise.activeProfessions) then
                for _, pName in ipairs(sorted) do
                    PS.db.advertise.activeProfessions[pName] = PS:IsProfessionAdActive(pName)
                end
            end
            PS.db.advertise.activeProfessions[profName] = checked
            PlaySound(checked and 856 or 857)
            -- Refresh ad bar to reflect change
            PS:RefreshAdBar()
        end)

        cy = cy - 24

        if globallyActive then
            local ebLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ebLabel:SetPoint("TOPLEFT", 28, cy)
            ebLabel:SetText(C.GRAY .. "Custom ad (leave blank for default):" .. C.R)
            cy = cy - 14

            local eb = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
            eb:SetPoint("TOPLEFT", 28, cy)
            eb:SetSize(410, 22)
            eb:SetAutoFocus(false)
            eb:SetMaxLetters(255)

            local currentMsg = PS.db.advertise.messages[profName] or ""
            eb:SetText(currentMsg)

            eb:SetScript("OnEnterPressed", function(self)
                local val = self:GetText():trim()
                if val == "" then
                    PS.db.advertise.messages[profName] = nil
                    PS:Print(C.GREEN .. profName .. C.R .. " ad reset to default.")
                else
                    PS.db.advertise.messages[profName] = val
                    PS:Print(C.GREEN .. "Saved custom ad for " .. C.CYAN .. profName .. C.R)
                end
                self:ClearFocus()
            end)
            eb:SetScript("OnEscapePressed", function(self)
                self:SetText(PS.db.advertise.messages[profName] or "")
                self:ClearFocus()
            end)

            cy = cy - 28

            local defaultAd = PS:GenerateDefaultAd(profName)
            if defaultAd then
                local defLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                defLabel:SetPoint("TOPLEFT", 28, cy)
                defLabel:SetWidth(410)
                defLabel:SetJustifyH("LEFT")
                defLabel:SetText(C.GRAY .. "Default: " .. defaultAd .. C.R)
                cy = cy - 28
            end
        end

        cy = cy - 8
    end

    if #sorted == 0 then
        local noProf = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noProf:SetPoint("TOPLEFT", 5, 0)
        noProf:SetText(C.GRAY .. "No professions detected yet." .. C.R)
    end

    content:SetSize(445, math.abs(cy) + 20)
end

function PS:RefreshAdvertiseTab()
    if self.adScrollContent then
        self:PopulateAdProfessions(self.adScrollContent)
    end
end

------------------------------------------------------------------------
-- Tab 4: Whisper Templates
------------------------------------------------------------------------
function PS:BuildWhispersTab(parent)
    local y = -5

    CreateHeader(parent, "Whisper Templates", 5, y)
    y = y - 10

    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", 15, y)
    info:SetWidth(460)
    info:SetText(C.GRAY .. "Use {item} for the item name, {position} for queue position. Press Enter to save." .. C.R)
    y = y - 25

    local templates = {
        { label = "Greeting",       key = "whispers.greeting" },
        { label = "Ask About Mats", key = "whispers.askMats" },
        { label = "Thank You",      key = "whispers.thanks" },
        { label = "Busy Message",   key = "whispers.busy" },
        { label = "Queue Position", key = "whispers.queued" },
    }

    for _, tmpl in ipairs(templates) do
        CreateEditBox(parent, tmpl.label .. ":", 10, y, 460, tmpl.key)
        y = y - 50
    end

    y = y - 10

    CreateButton(parent, "Reset to Defaults", 10, y, 160, 25, function()
        for _, tmpl in ipairs(templates) do
            local keys = { strsplit(".", tmpl.key) }
            local defaultVal = PS.DEFAULTS
            for _, k in ipairs(keys) do
                defaultVal = defaultVal[k]
            end
            local t = PS.db
            for i, k in ipairs(keys) do
                if i < #keys then t = t[k] else t[k] = defaultVal end
            end
        end
        PS:Print("Whisper templates reset to defaults. Reopen the panel to see changes.")
    end)
end

------------------------------------------------------------------------
-- Tab 5: Queue Display
------------------------------------------------------------------------
function PS:BuildQueueTab(parent)
    local y = -5

    CreateHeader(parent, "Customer Queue", 5, y)
    y = y - 25

    -- Queue settings
    CreateSlider(parent, "Max Queue Size", 10, y, 1, 20, 1, "queue.maxSize")
    y = y - 70

    CreateSlider(parent, "Auto-Timeout", 10, y, 60, 1800, 60, "queue.timeout",
        function(v) return PS:FormatTime(v) end)
    y = y - 70

    CreateCheckbox(parent, "Auto-Thank After Service", 10, y, "queue.autoThank",
        "Automatically whisper a thank you when a customer is marked complete.")
    y = y - 35

    -- Queue buttons
    CreateButton(parent, "Serve Next", 10, y, 110, 25, function()
        PS:ServeNextCustomer()
    end)

    CreateButton(parent, "Mark Done", 130, y, 110, 25, function()
        PS:CompleteCurrentCustomer()
    end)

    CreateButton(parent, "Clear Queue", 250, y, 110, 25, function()
        PS:ClearQueue()
        PS:Print("Queue cleared.")
        PS:RefreshQueueTab()
    end)

    y = y - 35

    -- Queue display
    CreateHeader(parent, "Current Queue", 5, y)
    y = y - 25

    -- Scrolling queue list
    local scrollFrame = CreateFrame("ScrollFrame", "ProShopQueueScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, y)
    scrollFrame:SetSize(460, 200)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(440, 1)
    scrollFrame:SetScrollChild(content)

    parent.queueContent = content
    parent.queueY = -5
end

function PS:RefreshQueueTab()
    if not MainFrame or not MainFrame.tabFrames[5] then return end

    local parent = MainFrame.tabFrames[5]
    local content = parent.queueContent
    if not content then return end

    -- Clear existing children (font strings)
    for _, child in ipairs({ content:GetRegions() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local y = -5

    if #self.queue == 0 then
        local empty = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("TOPLEFT", 5, y)
        empty:SetText(C.GRAY .. "No customers in queue." .. C.R)
        content:SetHeight(30)
        return
    end

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
            stateText = "BUSY"
        end

        local entry = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        entry:SetPoint("TOPLEFT", 5, y)
        entry:SetWidth(430)
        entry:SetJustifyH("LEFT")

        local elapsed = PS:FormatTime(GetTime() - customer.addedTime)
        local matStatus = ""
        if customer.hasMats == true then
            matStatus = C.GREEN .. " [Has Mats]" .. C.R
        elseif customer.hasMats == false then
            matStatus = C.ORANGE .. " [Needs Mats]" .. C.R
        end

        entry:SetText(string.format("%s#%d%s  %s%s%s  -  %s%s%s  %s[%s]%s%s  %s(%s)%s",
            C.GRAY, i, C.R,
            C.WHITE, customer.name, C.R,
            C.CYAN, customer.item, C.R,
            stateColor, stateText, C.R,
            matStatus,
            C.GRAY, elapsed, C.R))

        y = y - 20
    end

    content:SetHeight(math.abs(y) + 10)
end

------------------------------------------------------------------------
-- Toggle UI
------------------------------------------------------------------------
function PS:ToggleUI()
    if not MainFrame then
        self:CreateMainFrame()
    end
    if MainFrame:IsShown() then
        MainFrame:Hide()
    else
        -- Refresh data
        self:RefreshQueueTab()
        MainFrame:Show()
    end
end

------------------------------------------------------------------------
-- Register with ESC key
------------------------------------------------------------------------
table.insert(UISpecialFrames, "ProShopMainFrame")

------------------------------------------------------------------------
-- Tab 6: Credits & Changelog
------------------------------------------------------------------------
function PS:BuildCreditsTab(parent)
    local y = -5

    CreateHeader(parent, "About", 5, y)
    y = y - 30

    -- Title
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, y)
    title:SetText(C.CYAN .. "Pro Shop" .. C.R)

    local ver = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
    ver:SetText(C.GRAY .. "v" .. PS.VERSION .. C.R)

    y = y - 25

    local author = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    author:SetPoint("TOPLEFT", 15, y)
    author:SetWidth(460)
    author:SetJustifyH("LEFT")
    author:SetText(
        C.WHITE .. "Created by " .. C.GOLD .. "Evild" .. C.R ..
        C.WHITE .. " aka " .. C.GREEN .. "\"Iowke\"" .. C.R ..
        C.WHITE .. " on " .. C.CYAN .. "Dreamscythe" .. C.R
    )

    y = y - 25

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", 15, y)
    desc:SetWidth(460)
    desc:SetJustifyH("LEFT")
    desc:SetText(C.GRAY .. "A profession services addon for WoW Anniversary Classic.\nAutomate advertising, monitor chat for customers, manage a queue, and track tips." .. C.R)

    y = y - 50

    CreateHeader(parent, "Changelog", 5, y)
    y = y - 25

    local changelog = {
        {
            version = "1.0.0",
            date = "2026-02-24",
            changes = {
                "Initial release",
                "Profession detection and recipe scanning",
                "Trade/General/LFG/Say/Yell chat monitoring",
                "Auto-whisper and zone-verified auto-invite",
                "Per-profession ad broadcasting (manual, TBC-safe)",
                "Customer queue with tip tracking and auto-thank",
                "Open/Closed toggle frame (always visible)",
                "WTS/selling and raid recruitment message filtering",
                "Busy mode and blacklist support",
                "ElvUI auto-skinning",
                "Minimap button with drag positioning",
                "Notable recipes database for ad generation",
                "Lockpicking support with skill-gated lockbox tiers",
            },
        },
    }

    for _, entry in ipairs(changelog) do
        local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", 15, y)
        header:SetText(C.GOLD .. "v" .. entry.version .. C.R .. "  " .. C.GRAY .. entry.date .. C.R)
        y = y - 18

        for _, change in ipairs(entry.changes) do
            local line = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line:SetPoint("TOPLEFT", 25, y)
            line:SetWidth(440)
            line:SetJustifyH("LEFT")
            line:SetText(C.WHITE .. "- " .. change .. C.R)
            y = y - 15
        end
        y = y - 10
    end
end

------------------------------------------------------------------------
-- ElvUI Skinning Support
-- Automatically skin Pro Shop frames if ElvUI is loaded
------------------------------------------------------------------------
function PS:SkinForElvUI()
    if not ElvUI then return end

    local E = unpack(ElvUI)
    if not E then return end

    local S = E:GetModule("Skins", true)
    if not S then return end

    local f = MainFrame
    if not f then return end

    -- Skin the main frame
    if f.StripTextures then f:StripTextures() end
    if f.CreateBackdrop then f:CreateBackdrop("Transparent") end

    -- Skin close button
    if S.HandleCloseButton and f.CloseButton then
        S:HandleCloseButton(f.CloseButton)
    end

    -- Skin tabs
    if S.HandleTab then
        for _, tab in ipairs(f.tabs or {}) do
            S:HandleTab(tab)
        end
    end

    -- Skin all child frames recursively
    local function SkinChildren(frame)
        if not frame then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            local objType = child:GetObjectType()

            -- Skin checkboxes
            if objType == "CheckButton" and S.HandleCheckBox then
                S:HandleCheckBox(child)
            end

            -- Skin sliders
            if objType == "Slider" and S.HandleSliderFrame then
                S:HandleSliderFrame(child)
            end

            -- Skin buttons
            if objType == "Button" then
                local name = child:GetName()
                -- Don't re-skin the close button or tabs
                if name and name:find("Tab") then
                    -- skip
                elseif child == f.CloseButton then
                    -- skip
                elseif S.HandleButton then
                    S:HandleButton(child)
                end
            end

            -- Skin edit boxes
            if objType == "EditBox" and S.HandleEditBox then
                S:HandleEditBox(child)
            end

            -- Skin scroll frames
            if objType == "ScrollFrame" and S.HandleScrollBar then
                local scrollBar = child.ScrollBar or _G[child:GetName() and (child:GetName() .. "ScrollBar")]
                if scrollBar then
                    S:HandleScrollBar(scrollBar)
                end
            end

            -- Recurse into child frames
            SkinChildren(child)
        end
    end

    for _, tf in ipairs(f.tabFrames or {}) do
        SkinChildren(tf)
    end

    self:Debug("ElvUI skinning applied.")
end

-- Hook into CreateMainFrame to auto-skin after building
local origCreateMainFrame = PS.CreateMainFrame
function PS:CreateMainFrame(...)
    local result = origCreateMainFrame(self, ...)
    -- Skin after a short delay so ElvUI has time to load
    C_Timer.After(0.1, function()
        PS:SkinForElvUI()
    end)
    return result
end

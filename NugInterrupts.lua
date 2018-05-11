local addonName, addon = ...

NugInterrupts = CreateFrame("Frame",nil,UIParent)

local NugInterrupts = _G.NugInterrupts
local NugInterruptsDB

local LSM = LibStub("LibSharedMedia-3.0")

LSM:Register("statusbar", "Aluminium", [[Interface\AddOns\NugInterrupts\statusbar.tga]])
LSM:Register("font", "ClearFont", [[Interface\AddOns\NugInterrupts\Calibri.ttf]], GetLocale() ~= "enUS" and 15)


local alltimers = {}
local inactive = {}
local active = {}

local anchor
local ghost_duration = 30
local showSolo = false
local showGroup = true
local showRaid = false

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local COMBATLOG_OBJECT_AFFILIATION_MASK = COMBATLOG_OBJECT_AFFILIATION_MASK
local AFFILIATION_PARTY_OR_RAID = COMBATLOG_OBJECT_AFFILIATION_RAID + COMBATLOG_OBJECT_AFFILIATION_PARTY
local AFFILIATION_PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY

spells = {
    [47528]  = { cooldown = 15, class = "DEATHKNIGHT" }, --Mind Freeze
    [106839] = { cooldown = 15, class = "DRUID" }, --Skull Bash
    [78675]  = { cooldown = 60, class = "DRUID" }, --Solar Beam
    [183752] = { cooldown = 15, class = "DEMONHUNTER" }, --Consume Magic
    [147362] = { cooldown = 24, class = "HUNTER" }, --Counter Shot
    [187707] = { cooldown = 15, class = "HUNTER" }, --Muzzle
    [2139]   = { cooldown = 24, class = "MAGE" }, --Counter Spell
    [116705] = { cooldown = 15, class = "MONK" }, --Spear Hand Strike
    [96231]  = { cooldown = 15, class = "PALADIN" }, --Rebuke
    [15487]  = { cooldown = 45, class = "PRIEST" }, --Silence
    [1766]   = { cooldown = 15, class = "ROGUE" }, --Kick
    [57994] = { cooldown = 12, class = "SHAMAN" }, --Wind Shear
    [6552]  = { cooldown = 15, class = "WARRIOR" }, --Pummel
    [171140] = { cooldown = 24, class = "WARLOCK" }, --Shadow Lock
    [171138] = { cooldown = 24, class = "WARLOCK" }, --Shadow Lock if used from pet bar    
}

local defaults = {
    anchor = {
        point = "CENTER",
        parent = "UIParent",
        to = "CENTER",
        x = -50,
        y = -137,
    },
    width = 150,
    height = 20,
    barTexture = "Aluminium",
    spellFont = "ClearFont",
    spellFontSize = 12,
    timeFont = "ClearFont",
    timeFontSize = 10,
    ghostDuration = 30,
    textColor = {1,1,1,0.7},
    showSolo = false,
    showGroup = true,
    showRaid = false,
}

local function SetupDefaults(t, defaults)
    if not defaults then return end
    for k,v in pairs(defaults) do
        if type(v) == "table" then
            if t[k] == nil then
                t[k] = CopyTable(v)
            elseif t[k] == false then
                t[k] = false --pass
            else
                SetupDefaults(t[k], v)
            end
        else
            if t[k] == nil then t[k] = v end
        end
    end
end
local function RemoveDefaults(t, defaults)
    if not defaults then return end
    for k, v in pairs(defaults) do
        if type(t[k]) == 'table' and type(v) == 'table' then
            RemoveDefaults(t[k], v)
            if next(t[k]) == nil then
                t[k] = nil
            end
        elseif t[k] == v then
            t[k] = nil
        end
    end
    return t
end


NugInterrupts:RegisterEvent("PLAYER_LOGIN")
NugInterrupts:RegisterEvent("PLAYER_LOGOUT")
NugInterrupts:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

function NugInterrupts:PLAYER_LOGIN()
    _G.NugInterruptsDB = _G.NugInterruptsDB or {}
    NugInterruptsDB = _G.NugInterruptsDB
    SetupDefaults(NugInterruptsDB, defaults)

    anchor = self:CreateAnchor(NugInterruptsDB.anchor)
    self:SetSize(5,5)
    self:SetPoint("TOPLEFT", anchor, "BOTTOMRIGHT",0,0)
    -- self:Arrange()

    ghost_duration = NugInterruptsDB.ghostDuration
    showSolo = NugInterruptsDB.showSolo
    showGroup = NugInterruptsDB.showGroup
    showRaid = NugInterruptsDB.showRaid

    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    -- self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:GROUP_ROSTER_UPDATE()

    SLASH_NUGINTERRUPTS1= "/nuginterrupts"
    SLASH_NUGINTERRUPTS2= "/nint"
    SlashCmdList["NUGINTERRUPTS"] = NugInterrupts.SlashCmd

    local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
    f:SetScript('OnShow', function(self)
        self:SetScript('OnShow', nil)

        if not NugInterrupts.optionsPanel then
            NugInterrupts.optionsPanel = NugInterrupts:CreateGUI()
        end
    end)
end

function NugInterrupts:PLAYER_LOGOUT()
    RemoveDefaults(NugInterruptsDB, defaults)
end

local function FindTimer(srcGUID, spellID)
    for timer in pairs(active) do
        if timer.srcGUID == srcGUID and timer.spellID == spellID then return timer end
    end
    return next(inactive)
end


function NugInterrupts:GROUP_ROSTER_UPDATE()
    if showRaid and IsInRaid() then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    elseif showGroup and IsInGroup() then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    elseif showSolo and not IsInGroup() then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end


local bit_band = bit.band
function NugInterrupts.COMBAT_LOG_EVENT_UNFILTERED( self, event, timestamp, eventType, hideCaster,
    srcGUID, srcName, srcFlags, srcFlags2,
    dstGUID, dstName, dstFlags, dstFlags2,
    spellID, spellName, spellSchool, auraType, amount)

    
    if eventType == "SPELL_CAST_SUCCESS" then 
        if bit_band(srcFlags, COMBATLOG_OBJECT_AFFILIATION_MASK) <= AFFILIATION_PARTY and spells[spellID] then
            local timer = FindTimer(srcGUID, spellID) or self:CreateTimer()
            timer:Start(spellID, srcGUID, spells[spellID] )
        end
    end
end

function NugInterrupts:FindUnitByGUID(srcGUID)
    if UnitGUID("player") == srcGUID then return "player" end
    for i=1, 4 do
        local unit = "party"..i
        if UnitGUID(unit) == srcGUID then return unit end
    end
    -- for i=1, 39 do
    --     local unit = "raid"..i
    --     if UnitGUID(unit) == srcGUID then return unit end
    -- end
end

local function TimerOnUpdate(self, elapsed)
    local v = self.elapsed + elapsed
    local beforeEnd = self.endTime - (v+self.startTime)
    self.elapsed = v

    local val
    if self.inverted then val = self.startTime + beforeEnd
    else val = self.endTime - beforeEnd end
    self.bar:SetValue(val)
    self.timeText:SetFormattedText("%.1f",beforeEnd)
    if beforeEnd <= 0 then
        self:Expire()
    end
end

local function TimerStart(self, spellID, srcGUID, opts)

    local duration = opts.cooldown
    local class = opts.class
    local unit = NugInterrupts:FindUnitByGUID(srcGUID)
    
    self:SetScript("OnUpdate", TimerOnUpdate)
    self.expiredGhost = nil
    self.isGhost = nil

    self.spellID = spellID
    self.srcGUID = srcGUID

    local now = GetTime()
    self.startTime = now
    self.endTime = now + duration

    self.bar:SetMinMaxValues(self.startTime, self.endTime)
    self.elapsed = GetTime() - self.startTime

    local spellName,_, texture = GetSpellInfo(spellID)
    local name = unit and UnitName(unit) or ""
    self.icon:SetTexture(texture)
    self.spellText:SetText(name)

    local color = RAID_CLASS_COLORS[class]
    self.bar:SetColor(color.r, color.g, color.b)
    self:Show()

    active[self] = true
    inactive[self] = nil

    NugInterrupts:Arrange()
end


local function TimerGhostOnUpdate(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed > ghost_duration then
        self:GhostExpire()
    end
end

local ResizeFunc = function(self, width, height)
    local texture = LSM:Fetch("statusbar", NugInterruptsDB.barTexture)
    self.bar:SetStatusBarTexture(texture)
    self.bar.bg:SetTexture(texture)

    self:SetWidth(width)
    self:SetHeight(height)
    self.bar:SetWidth(width - height - 1)
    self.bar:SetHeight(height)
    self.spellText:SetWidth(width/4*3 -12)
    self.spellText:SetHeight(height/2+1)
    local ic = self.icon:GetParent()
    ic:SetWidth(height)
    ic:SetHeight(height)
end

local ResizeTextFunc = function(self)
    self.timeText:SetFont(LSM:Fetch("font", NugInterruptsDB.timeFont), NugInterruptsDB.timeFontSize)
    self.timeText:SetTextColor(unpack(NugInterruptsDB.textColor))

    self.spellText:SetFont(LSM:Fetch("font", NugInterruptsDB.spellFont), NugInterruptsDB.spellFontSize)
    self.spellText:SetTextColor(unpack(NugInterruptsDB.textColor))
end


local function ChangeToGhost(self)
    -- self:SetColor(0.5,0,0)
    -- self.spellText:SetText("Ready")
    self.timeText:SetText("")
    -- self.bar:SetValue(0)
end

local function TimerBecomeGhost(self)
    self.expiredGhost = nil
    self.isGhost = true

    ChangeToGhost(self)
    local opts = self.opts
    
    self.elapsed = 0
    self:SetScript("OnUpdate", TimerGhostOnUpdate)
end

local function TimerExpire(self)
    if not self.isGhost then return self:BecomeGhost() end
    if self.isGhost and not self.expiredGhost then
        return
    end
    inactive[self] = true
    active[self] = nil
    self:Hide()
end


local function TimerGhostExpire(self)
    self:SetScript("OnUpdate", TimerOnUpdate)
    self.expiredGhost = true
    
    self:Expire()
    self.isGhost = nil
end

function NugInterrupts.CreateTimer(self)
    local f = CreateFrame("Frame",nil, self)

    local width = NugInterruptsDB.width
    local height = NugInterruptsDB.height
    
    f:SetWidth(width)
    f:SetHeight(height)

    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }

    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0, 0, 0, 1)

    local ic = CreateFrame("Frame",nil,f)
    ic:SetPoint("TOPLEFT",f,"TOPLEFT", 0, 0)
    ic:SetWidth(height)
    ic:SetHeight(height)
    local ict = ic:CreateTexture(nil,"ARTWORK",nil,0)
    ict:SetTexCoord(.07, .93, .07, .93)
    ict:SetAllPoints(ic)
    f.icon = ict

    local texture = LSM:Fetch("statusbar", NugInterruptsDB.barTexture)

    f.bar = CreateFrame("StatusBar",nil,f)
    f.bar:SetFrameStrata("MEDIUM")
    f.bar:SetStatusBarTexture(texture)
    f.bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    f.bar:SetHeight(height)
    f.bar:SetWidth(width - height - 1)
    f.bar:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)

    f.Resize = ResizeFunc
    f.ResizeText = ResizeTextFunc
    f.Start = TimerStart
    f.Expire = TimerExpire
    f.BecomeGhost = TimerBecomeGhost
    f.GhostExpire = TimerGhostExpire


    local m = 0.35
    f.bar.SetColor = function(self, r,g,b)
        self:SetStatusBarColor(r,g,b)
        self.bg:SetVertexColor(r*m,g*m,b*m)
    end

    f.bar.bg = f.bar:CreateTexture(nil, "BORDER")
    f.bar.bg:SetAllPoints(f.bar)
    f.bar.bg:SetTexture(texture)

    f.timeText = f.bar:CreateFontString();
    f.timeText:SetFont(LSM:Fetch("font", NugInterruptsDB.timeFont), NugInterruptsDB.timeFontSize)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetVertexColor(1,1,1)
    f.timeText:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",-6,0)
    f.timeText:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT",0,0)
    f.timeText:SetTextColor(unpack(NugInterruptsDB.textColor))

    local spellFontSize = NugInterruptsDB.spellFontSize

    f.spellText = f.bar:CreateFontString();
    f.spellText:SetFont(LSM:Fetch("font", NugInterruptsDB.spellFont), spellFontSize)
    f.spellText:SetWidth(width/4*3 -12)
    f.spellText:SetHeight(height/2+1)
    f.spellText:SetJustifyH("CENTER")
    f.spellText:SetTextColor(unpack(NugInterruptsDB.textColor))
    f.spellText:SetPoint("LEFT", f.bar, "LEFT",6,0)
    -- f.spellText:SetAlpha(0.5)


    f:SetScript("OnUpdate",TimerOnUpdate)

    f:Hide()

    inactive[f] = true
    table.insert(alltimers, f)

    return f
end





local ordered_bars = {}
local function bar_sort_func(a,b)
    -- local ap = a.isTarget
    -- local bp = b.isTarget
    -- if ap == bp then
        return a.endTime < b.endTime
    -- else
        -- return ap > bp
    -- end
end
function NugInterrupts.Arrange(self)
    table.wipe(ordered_bars)
    for timer in pairs(active) do
        table.insert(ordered_bars, timer)
    end

    table.sort(ordered_bars, bar_sort_func)     
    local prev
    local gap = 0
    -- local xgap = 0
    -- local firstTimer = ordered_bars[1]
    -- local gotTarget = true
    -- if firstTimer and firstTimer.isTarget == 0 then
    --     gap = -5-firstTimer:GetHeight()
    --     gotTarget = false
    -- end
    for i, timer in ipairs(ordered_bars) do
        -- timer:ClearAllPoints()
        timer:SetPoint("TOPLEFT", prev or self, prev and "BOTTOMLEFT" or "TOPLEFT", 0, gap)
        gap = -5
        prev = timer
    end
end









function NugInterrupts:CreateAnchor(db_tbl)
    local f = CreateFrame("Frame",nil,UIParent)
    f:SetHeight(20)
    f:SetWidth(20)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:Hide()

    local t = f:CreateTexture(nil,"BACKGROUND")
    t:SetTexture("Interface\\Buttons\\UI-RadioButton")
    t:SetTexCoord(0,0.25,0,1)
    t:SetAllPoints(f)

    t = f:CreateTexture(nil,"BACKGROUND")
    t:SetTexture("Interface\\Buttons\\UI-RadioButton")
    t:SetTexCoord(0.25,0.49,0,1)
    t:SetVertexColor(1, 0, 0)
    t:SetAllPoints(f)

    f.db_tbl = db_tbl

    f:SetScript("OnMouseDown",function(self)
        self:StartMoving()
    end)
    f:SetScript("OnMouseUp",function(self)
            local opts = self.db_tbl
            self:StopMovingOrSizing();
            local point,_,to,x,y = self:GetPoint(1)
            opts.point = point
            opts.parent = "UIParent"
            opts.to = to
            opts.x = x
            opts.y = y
    end)

    local pos = f.db_tbl
    f:SetPoint(pos.point, pos.parent, pos.to, pos.x, pos.y)
    return f
end



local ParseOpts = function(str)
    local t = {}
    local capture = function(k,v)
        t[k:lower()] = tonumber(v) or v
        return ""
    end
    str:gsub("(%w+)%s*=%s*%[%[(.-)%]%]", capture):gsub("(%w+)%s*=%s*(%S+)", capture)
    return t
end
NugInterrupts.Commands = {
    ["unlock"] = function()
        anchor:Show()
    end,
    ["lock"] = function()
        anchor:Hide()
    end,

    -- ["set"] = function(v)
    --     local p = ParseOpts(v)
    --     local unit = p["unit"]
    --     if unit then
    --         if p.width then NugInterruptsDB[unit].width = p.width end
    --         if p.height then NugInterruptsDB[unit].height = p.height end

    --         if unit == "player" then
    --             NugInterruptsPlayer:Resize(NugInterruptsDB.player.width, NugInterruptsDB.player.height)
    --         elseif unit == "target" then
    --             NugInterruptsTarget:Resize(NugInterruptsDB.target.width, NugInterruptsDB.target.height)
    --         elseif unit == "nameplates" then
    --             for i, timer in ipairs(npCastbars) do
    --                 timer:Resize(NugInterruptsDB.nameplates.width, NugInterruptsDB.nameplates.height)
    --             end
    --         end
    --     end
    -- end,
}

function NugInterrupts.SlashCmd(msg)
    local k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then print([[Usage:
      |cff00ff00/spg lock|r
      |cff00ff00/spg unlock|r
    ]]
    )end
    if NugInterrupts.Commands[k] then
        NugInterrupts.Commands[k](v)
    end

end




function NugInterrupts:Resize()
    for _, timer in ipairs(alltimers) do
        timer:Resize(NugInterruptsDB.width, NugInterruptsDB.height)
    end
end
function NugInterrupts:ResizeText()
    for _, timer in ipairs(alltimers) do
        timer:ResizeText()
    end
end


function NugInterrupts:CreateGUI()
    local opt = {
        type = 'group',
        name = "NugInterrupts Settings",
        order = 1,
        args = {
            unlock = {
                name = "Unlock",
                type = "execute",
                desc = "Unlock anchor for dragging",
                func = function() NugInterrupts.Commands.unlock() end,
                order = 1,
            },
            lock = {
                name = "Lock",
                type = "execute",
                desc = "Lock anchor",
                func = function() NugInterrupts.Commands.lock() end,
                order = 2,
            },
            resetToDefault = {
                name = "Restore Defaults",
                type = 'execute',
                func = function()
                    _G.NugInterruptsDB = {}
                    SetupDefaults(_G.NugInterruptsDB, defaults)
                    NugInterruptsDB = _G.NugInterruptsDB
                    NugInterrupts:Resize()
                    NugInterrupts:ResizeText()
                end,
                order = 3,
            },
            toggleGroup = {
                        
                type = "group",
                guiInline = true,
                name = " ",
                order = 4,
                args = {
                    showSolo = {
                        name = "Show Solo",
                        type = "toggle",
                        order = 1,
                        get = function(info) return NugInterruptsDB.showSolo end,
                        set = function(info, v)
                            NugInterruptsDB.showSolo = not NugInterruptsDB.showSolo
                            showSolo = NugInterruptsDB.showSolo
                            NugInterrupts:GROUP_ROSTER_UPDATE()
                        end
                    },
                    showGroup = {
                        name = "Show Group",
                        type = "toggle",
                        order = 2,
                        get = function(info) return NugInterruptsDB.showGroup end,
                        set = function(info, v)
                            NugInterruptsDB.showGroup = not NugInterruptsDB.showGroup
                            showGroup = NugInterruptsDB.showGroup
                            NugInterrupts:GROUP_ROSTER_UPDATE()
                        end
                    },
                    showRaid = {
                        name = "Show Raid",
                        type = "toggle",
                        order = 3,
                        get = function(info) return NugInterruptsDB.showRaid end,
                        set = function(info, v)
                            NugInterruptsDB.showRaid = not NugInterruptsDB.showRaid
                            showRaid = NugInterruptsDB.showRaid
                            NugInterrupts:GROUP_ROSTER_UPDATE()
                        end
                    },
                },
            },
            anchors = {
                type = "group",
                name = " ",
                guiInline = true,
                order = 6,
                args = {
                    colorGroup = {
                        type = "group",
                        name = "",
                        order = 1,
                        args = {
                            textColor = {
                                name = "Text Color & Alpha",
                                type = 'color',
                                hasAlpha = true,
                                order = 6,
                                get = function(info)
                                    local r,g,b,a = unpack(NugInterruptsDB.textColor)
                                    return r,g,b,a
                                end,
                                set = function(info, r, g, b, a)
                                    NugInterruptsDB.textColor = {r,g,b, a}
                                    NugInterrupts:ResizeText()
                                end,
                            },
                            texture = {
                                type = "select",
                                name = "Texture",
                                order = 5,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugInterruptsDB.barTexture end,
                                set = function(info, value)
                                    NugInterruptsDB.barTexture = value
                                    NugInterrupts:Resize()
                                end,
                                values = LSM:HashTable("statusbar"),
                                dialogControl = "LSM30_Statusbar",
                            },
                            ghostDuration = {
                                name = "Ghost Duration",
                                type = "range",
                                get = function(info) return NugInterruptsDB.ghostDuration end,
                                set = function(info, v)
                                    NugInterruptsDB.ghostDuration = tonumber(v)
                                    ghost_duration = NugInterruptsDB.ghostDuration
                                end,
                                min = 3,
                                max = 120,
                                step = 1,
                                order = 3,
                            },
                        },
                    },
                    barGroup = {
                        type = "group",
                        name = " ",
                        order = 2,
                        args = {
                            
                            playerWidth = {
                                name = "Bar Width",
                                type = "range",
                                get = function(info) return NugInterruptsDB.width end,
                                set = function(info, v)
                                    NugInterruptsDB.width = tonumber(v)
                                    NugInterrupts:Resize()
                                end,
                                min = 30,
                                max = 300,
                                step = 1,
                                order = 1,
                            },
                            playerHeight = {
                                name = "Bar Height",
                                type = "range",
                                get = function(info) return NugInterruptsDB.height end,
                                set = function(info, v)
                                    NugInterruptsDB.height = tonumber(v)
                                    NugInterrupts:Resize()
                                end,
                                min = 10,
                                max = 60,
                                step = 1,
                                order = 2,
                            },
                            playerFontSize = {
                                name = "Font Size",
                                type = "range",
                                order = 3,
                                get = function(info) return NugInterruptsDB.spellFontSize end,
                                set = function(info, v)
                                    NugInterruptsDB.spellFontSize = tonumber(v)
                                    NugInterrupts:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },

                           
                        },
                    },

                    textGroup = {
                        
                        type = "group",
                        name = " ",
                        order = 3,
                        args = {

                            font1 = {
                                type = "select",
                                name = "Spell Font",
                                order = 1,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugInterruptsDB.spellFont end,
                                set = function(info, value)
                                    NugInterruptsDB.spellFont = value
                                    NugInterrupts:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            
                            font2 = {
                                type = "select",
                                name = "Time Font",
                                order = 3,
                                desc = "Set the statusbar texture.",
                                get = function(info) return NugInterruptsDB.timeFont end,
                                set = function(info, value)
                                    NugInterruptsDB.timeFont = value
                                    NugInterrupts:ResizeText()
                                end,
                                values = LSM:HashTable("font"),
                                dialogControl = "LSM30_Font",
                            },
                            font2Size = {
                                name = "Time Font Size",
                                type = "range",
                                order = 4,
                                get = function(info) return NugInterruptsDB.timeFontSize end,
                                set = function(info, v)
                                    NugInterruptsDB.timeFontSize = tonumber(v)
                                    NugInterrupts:ResizeText()
                                end,
                                min = 5,
                                max = 50,
                                step = 1,
                            },
                        },
                    },
                    
                },
            }, --
        },
    }

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:RegisterOptionsTable("NugInterruptsOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame = AceConfigDialog:AddToBlizOptions("NugInterruptsOptions", "NugInterrupts")

    return panelFrame
end
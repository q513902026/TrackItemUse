----------------------------------------------------
---------------------- CORE ------------------------
----------------------------------------------------
local frame = CreateFrame("frame")
frame.trackSpell = {}
frame.events = {}
frame.eventHandler = {}

----------------------------------------------------
-------------------- SETTINGS ----------------------
----------------------------------------------------
-- 追蹤的物品ID列表
frame.trackItem = {
    [6948] = true, --炉石  TESTITEM
    --[141605] = true, --飞行管理员的哨子
    [152638] = true, --敏捷精煉藥劑
    [152639] = true, --智力精煉藥劑
    [152640] = true, --耐力精煉藥劑
    [152641] = true, --力量精煉藥劑
    [156525] = true, --海帆盛宴
    [162519] = true, --秘法药锅
    [156525] = true, --船长盛宴佳肴
    -- 機器人通報列表
    [132514] = true, -- 自動鐵錘
    [141333] = true, -- 宁神圣典
    [153646] = true, -- 静心圣典
}

-- 在事件中被忽略的UID
frame.blackUIDList = {
    ["target"] = true,
    ["focus"] = true,
    ["mouseover"] = true,
    ["player"] = false,
}

-- 触发的人名称职业染色(在使用聊天频道时无法染色) (当不能获取时为白色)
frame.useClassColor = true

-- 使用物品链接 而不是物品名字。 (注意并非当前使用的物品链接 而是同id的物品链接)
frame.useItemLink = false

-- 设置聊天频道 不启用时请输入nil或者删除  如果有多个参数 请直接使用table
frame.useChatMessage = nil

----------------------------------------------------
-------------------- FUNCTIONS ---------------------
----------------------------------------------------
frame:SetScript("OnEvent", function(self, event, ...)
    if self.eventHandler[event] then
        self.eventHandler[event](self, event, ...)
    end
end)

function frame:HandlerEvent(event, handler)
    if type(handler) == "function" then
        if type(event) == "table" then
            for _, v in pairs(event) do
                self.eventHandler[v] = handler
                if not self.events[v] then
                    self:RegisterEvent(v)
                    self.events[v] = true
                end
            end
        elseif type(event) == "string" then
            self.eventHandler[event] = handler
            if not self.events[event] then
                self:RegisterEvent(event)
                self.events[event] = true
            end
        end
    end
end

function frame:UnhandlerEvent(event)
    if type(event) == "table" then
        for _, v in pairs(event) do
            self.eventHandler[v] = nil
            if self.events[v] then
                self:UnregisterEvent(v)
                self.events[v] = false
            end
        end
    elseif type(event) == "string" then
        self.eventHandler[event] = nil
        if self.events[event] then
            self:UnregisterEvent(event)
            self.events[event] = false
        end
    end

end

--[[
把追蹤列表中的物品id轉換成對應的法術id
API name,spellid = GetItemSpell(itemID or itemLink)
]]
function frame:updateSpell()
    for i, v in pairs(self.trackItem) do
        if v then
            local _, spell = GetItemSpell(i)
            if spell then
                self.trackSpell[spell] = i
                local item = GetItemInfo(i)
            end
        end
    end
end

--[[
獲取頻道參數信息
直接使用useChatMessage字段
]]
function frame.GetChatMessagePars()
    if self.useChatMessage == "nil" then return false end
    if type(self.useChatMessage) == "table" then
        return unpack(self.useChatMessage)
    else
        return self.useChatMessage
    end
    return false
end

--[[
通過物品法術釋放事件來獲取要發送的信息
]]
function frame:GetSendMessage(event, uid, spellid, showServer)
    if not showServer then showServer = true end
    local name = GetUnitName(uid, showServer)
    local itemName, link = GetItemInfo(self.trackSpell[spellid])
    if name and self.useClassColor and (not self.useChatMessage) then
        local _, classEn = UnitClass(uid)
        if classEn then
            name = RAID_CLASS_COLORS[classEn]:WrapTextInColorCode(name)
        end
    end
    
    if itemName and self.useItemLink then
        itemName = link
    end
    
    local medials = "使用了"
    if event:match("_START") then
        medials = "正在使用"
    end
    return name .. medials .. itemName .. "!"
end

----------------------------------------------------
-------------------- EVENTS ------------------------
----------------------------------------------------
--[[
追蹤物品法術釋放事件
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_CHANNEL_START
UNIT_SPELLCAST_START
]]
function frame.trackItemUseFunc(self, event, ...)
    local uid, _, spellid = ...
    if (not self.blackUIDList[uid]) and self.trackSpell[spellid] then
        local msg = self:GetSendMessage(event, uid, spellid, true)
        if self.useChatMessage and self.GetChatMessagePars() then
            SendChatMessage(msg, self.GetChatMessagePars())
        else
            DEFAULT_CHAT_FRAME:AddMessage(msg, 0.6, 1, 1)
        end
    end
end
--[[
更新事件忽略UID列表
GROUP_ROSTER_UPDATE
]]
function frame.updateMode(self)
    local bool = false
    if IsInRaid() then
        bool = true
    end
    self.blackUIDList["player"] = bool
    for i = 1, 4, 1 do
        self.blackUIDList["party" .. i] = bool
    end
end

_G["TrackItemUse"] = frame

----------------------------------------------------
-------------------- LOADING -----------------------
----------------------------------------------------
local function onLogin()
    TrackItemUse:HandlerEvent({"UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_START"}, TrackItemUse.trackItemUseFunc)
    TrackItemUse:HandlerEvent("GROUP_ROSTER_UPDATE", TrackItemUse.updateMode)
    TrackItemUse:updateSpell()
end

local booter = CreateFrame("Frame")
booter:RegisterEvent("PLAYER_ENTERING_WORLD")
booter.onLogin = onLogin
booter:SetScript("OnEvent", function(self)
    self.onLogin()
    self:UnregisterAllEvents()
end)

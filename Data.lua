-------------------------------------------------------------------------------
-- TidyBags - Saved bags of every character
--
-- TidyBagsDB.chars[character] = {
--     name, realm, class, money,
--     bags = { [bagID] = { size, link (the bag item),
--              items = { [slot] = { id, link, count, icon, quality } } } },
-- }
-- The bags of the character in play are saved after every change, so the
-- other characters can see them, and the tooltips can count them.
-------------------------------------------------------------------------------

local _, ns = ...

-- Per character: [itemID] = count in its bags (built when needed)
local counts = {}

local function AllBags()
    local list = {}
    for _, bag in ipairs(ns.BAGS) do list[#list + 1] = bag end
    list[#list + 1] = ns.REAGENT_BAG
    return list
end
ns.AllBags = AllBags

-- The keyring shows only the rows of 4 its keys need (the game's size)
function ns.BagSize(bag)
    if bag == ns.KEYRING then return GetKeyRingSize() end
    return C_Container.GetContainerNumSlots(bag)
end

local function SaveBag(bags, bag)
    local saved = { size = ns.BagSize(bag), items = {} }
    if bag ~= 0 and bag ~= ns.KEYRING then
        saved.link = GetInventoryItemLink("player", C_Container.ContainerIDToInventoryID(bag))
    end
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            saved.items[slot] = { id = info.itemID, link = info.hyperlink, count = info.stackCount,
                icon = info.iconFileID, quality = info.quality }
        end
    end
    bags[bag] = saved
end

local charList

local function Save()
    local me = ns.db.chars[ns.charKey]
    if not me then
        me = {}
        ns.db.chars[ns.charKey] = me
        charList = nil
    end
    me.name = ns.CharName()
    me.realm = GetRealmName()
    me.class = select(2, UnitClass("player"))
    me.money = GetMoney()
    me.bags = {}
    for _, bag in ipairs(AllBags()) do SaveBag(me.bags, bag) end
    if ns.KeyringOn() then SaveBag(me.bags, ns.KEYRING) end
    counts[ns.charKey] = nil
end

-- The bags changed since the last save: saved when the data is read (the
-- tooltips) or at logout, so play does no work for it
local dirty = {}

local function Flush()
    if not next(dirty) then return end
    local me = ns.db.chars[ns.charKey]
    for bag in pairs(dirty) do
        if bag == ns.KEYRING and not ns.KeyringOn() then
            me.bags[bag] = nil
        elseif bag == ns.KEYRING or bag == ns.REAGENT_BAG or (bag >= 0 and bag <= 4) then
            SaveBag(me.bags, bag)
        end
    end
    wipe(dirty)
    counts[ns.charKey] = nil
end

local function MarkAll()
    for _, bag in ipairs(AllBags()) do dirty[bag] = true end
    dirty[ns.KEYRING] = true
end

local function SaveMoney()
    local me = ns.db.chars[ns.charKey]
    if me then me.money = GetMoney() end
end

-- Characters in name order, the one in play first (kept until the list
-- changes; read only)
function ns.Characters()
    if charList then return charList end
    local list = {}
    for key in pairs(ns.db.chars) do
        if key ~= ns.charKey then list[#list + 1] = key end
    end
    table.sort(list)
    table.insert(list, 1, ns.charKey)
    charList = list
    return list
end

function ns.CharData(key)
    if key == ns.charKey then Flush() end
    return ns.db.chars[key]
end

function ns.ForgetCharacter(key)
    if key == ns.charKey then return end
    ns.db.chars[key] = nil
    counts[key] = nil
    charList = nil
end

-- How many of an item a character has in its bags
function ns.CountOf(key, itemID)
    if key == ns.charKey then Flush() end
    local c = counts[key]
    if not c then
        c = {}
        local data = ns.db.chars[key]
        for _, bag in pairs(data and data.bags or {}) do
            for _, item in pairs(bag.items) do
                if item.id then c[item.id] = (c[item.id] or 0) + (item.count or 1) end
            end
        end
        counts[key] = c
    end
    return c[itemID] or 0
end

ns.Module(function()
    Save()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE")
    ev:RegisterEvent("BAG_CONTAINER_UPDATE")
    ev:RegisterEvent("PLAYER_MONEY")
    ev:RegisterEvent("PLAYER_LOGOUT")
    ev:SetScript("OnEvent", function(_, event, bag)
        if event == "BAG_UPDATE" then
            if bag then dirty[bag] = true end
        elseif event == "BAG_CONTAINER_UPDATE" then
            MarkAll()
        elseif event == "PLAYER_MONEY" then
            SaveMoney()
        else
            Flush()
        end
    end)
end)

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

local function SaveBag(bags, bag)
    local size = C_Container.GetContainerNumSlots(bag)
    local saved = { size = size, items = {} }
    if bag ~= 0 then
        saved.link = GetInventoryItemLink("player", C_Container.ContainerIDToInventoryID(bag))
    end
    for slot = 1, size do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            saved.items[slot] = { id = info.itemID, link = info.hyperlink, count = info.stackCount,
                icon = info.iconFileID, quality = info.quality }
        end
    end
    bags[bag] = saved
end

local function Save()
    local me = ns.db.chars[ns.charKey] or {}
    ns.db.chars[ns.charKey] = me
    me.name = ns.CharName()
    me.realm = GetRealmName()
    me.class = select(2, UnitClass("player"))
    me.money = GetMoney()
    me.bags = {}
    for _, bag in ipairs(AllBags()) do SaveBag(me.bags, bag) end
    counts[ns.charKey] = nil
end

local function SaveMoney()
    local me = ns.db.chars[ns.charKey]
    if me then me.money = GetMoney() end
end

-- Characters in name order, the one in play first
function ns.Characters()
    local list = {}
    for key in pairs(ns.db.chars) do
        if key ~= ns.charKey then list[#list + 1] = key end
    end
    table.sort(list)
    table.insert(list, 1, ns.charKey)
    return list
end

function ns.CharData(key)
    return ns.db.chars[key]
end

function ns.ForgetCharacter(key)
    if key == ns.charKey then return end
    ns.db.chars[key] = nil
    counts[key] = nil
end

-- How many of an item a character has in its bags
function ns.CountOf(key, itemID)
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
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_MONEY")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_MONEY" then SaveMoney() else Save() end
    end)
end)

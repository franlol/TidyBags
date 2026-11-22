-------------------------------------------------------------------------------
-- TidyBags - Item buttons
--
-- Live buttons (the character in play) are Blizzard's own container item
-- buttons, so using, selling, splitting, dragging and their tooltips are the
-- game's. Each button's bag comes from its parent frame's ID, as in
-- Blizzard's bags. Saved buttons (other characters) only show the item:
-- tooltip on hover and modified clicks (link, dress up).
-- Every button keeps Blizzard's size (37 px) and is scaled to the chosen
-- size, so Blizzard's glows and overlays scale with it.
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

ns.BUTTON = 37
local FLAT = "Interface\\Buttons\\WHITE8X8"

local bagFrames, live, saved = {}, {}, {}

-------------------------------------------------------------------------------
-- Look: Blizzard's art, or flat (cropped icon, 1 px border, dark slot)
-------------------------------------------------------------------------------
local function Flat(b)
    if b.tbEdge then return end
    b.tbEdge = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    b.tbEdge:SetAllPoints()
    b.tbEdge:SetTexture(FLAT)
    b.tbFill = b:CreateTexture(nil, "BACKGROUND", nil, -6)
    b.tbFill:SetPoint("TOPLEFT", 1, -1)
    b.tbFill:SetPoint("BOTTOMRIGHT", -1, 1)
    b.tbFill:SetTexture(FLAT)
end

local function QualityColor(quality)
    local c = quality and ColorManager and ColorManager.GetColorDataForBagItemQuality(quality)
    if c then return c.r, c.g, c.b end
    c = quality and ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
end

-- The style's art on a button. quality: the item's (nil when empty);
-- edge: a color for the flat border instead of the quality's (bag slots)
local function Paint(b, hasItem, quality, edge)
    local P = ns.P
    local flat = P.style == "flaty"
    local normal = b:GetNormalTexture()
    local pushed = b:GetPushedTexture()
    if flat then
        Flat(b)
        b.tbEdge:Show()
        b.tbFill:Show()
        b.tbFill:SetVertexColor(0.09, 0.09, 0.1, 1)
        local r, g, bl = 0, 0, 0
        if edge then
            r, g, bl = edge[1], edge[2], edge[3]
        elseif hasItem and P.quality and quality and quality >= Enum.ItemQuality.Uncommon then
            r, g, bl = QualityColor(quality)
        end
        b.tbEdge:SetVertexColor(r or 0, g or 0, bl or 0, 1)
        if b.tbIcon ~= "flaty" then
            b.tbIcon = "flaty"
            b.icon:ClearAllPoints()
            b.icon:SetPoint("TOPLEFT", 1, -1)
            b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        end
        -- the game's empty slot art resets the coords
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon:SetAlpha(hasItem and 1 or 0)
        b.IconBorder:SetAlpha(0)
        if normal then normal:SetAlpha(0) end
        if pushed then pushed:SetAlpha(0) end
    else
        if b.tbEdge then
            b.tbEdge:Hide()
            b.tbFill:Hide()
        end
        if b.tbIcon ~= "blizzard" then
            b.tbIcon = "blizzard"
            b.icon:ClearAllPoints()
            b.icon:SetAllPoints()
        end
        b.icon:SetTexCoord(0, 1, 0, 1)
        b.icon:SetAlpha(1)
        b.IconBorder:SetAlpha(P.quality and 1 or 0)
        if normal then normal:SetAlpha(1) end
        if pushed then pushed:SetAlpha(1) end
    end
    ns.StyleTexts(b)
end
ns.Paint = Paint

-------------------------------------------------------------------------------
-- Texts on the items: stack count (Blizzard's) and item level (ours)
-------------------------------------------------------------------------------
local function LevelText(b)
    if not b.tbLevel then
        b.tbLevel = b:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
    end
    return b.tbLevel
end

-- Buttons are scaled (size / 37): sizes and offsets are divided by the
-- scale so they read in px on screen
local function StyleText(b, fs, cfg)
    local s = ns.P.size / ns.BUTTON
    Flaty.SetFontFile(fs, cfg.font, cfg.size / s, cfg.outline)
    fs:ClearAllPoints()
    fs:SetPoint(cfg.point, b, cfg.point, cfg.x / s, cfg.y / s)
    fs:SetJustifyH(cfg.point:find("LEFT") and "LEFT" or cfg.point:find("RIGHT") and "RIGHT" or "CENTER")
end

-- The text settings on a button, once per change (ns.textsVersion)
function ns.StyleTexts(b)
    if b.tbTexts == ns.textsVersion then return end
    b.tbTexts = ns.textsVersion
    StyleText(b, b.Count, ns.P.texts.count)
    StyleText(b, LevelText(b), ns.P.texts.ilvl)
end

-- The game's search dimming on an item. It covers the item's marks; its
-- cooldown is a frame above the dimming, so it fades to the same shade
-- (the dimming is black at 80%)
function ns.SetMatches(b, matches)
    b:SetMatchesSearch(matches)
    if b.Cooldown then b.Cooldown:SetAlpha(matches and 1 or 0.2) end
end

-- every change of the settings styles the texts again
ns.textsVersion = 0
ns.Module(function() end, function() ns.textsVersion = ns.textsVersion + 1 end)

local function IsGear(id)
    if not id then return false end
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(id)
    return (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor)
        and equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

local function ShowLevel(b, id, level, quality)
    local text = LevelText(b)
    if ns.P.ilvl and level and level > 1 and IsGear(id) then
        text:SetText(level)
        local r, g, bl = QualityColor(quality)
        text:SetTextColor(r or 1, g or 1, bl or 1)
        text:Show()
    else
        text:Hide()
    end
end

-------------------------------------------------------------------------------
-- Live buttons
-------------------------------------------------------------------------------
-- The frame that holds a bag's buttons: its ID is the bag ID
function ns.BagFrame(bag, parent)
    local f = bagFrames[bag]
    if not f then
        f = CreateFrame("Frame", "TidyBagsBag" .. bag, parent)
        f:SetID(bag)
        f:SetAllPoints()
        bagFrames[bag] = f
    end
    return f
end

function ns.LiveButton(bag, slot, parent)
    live[bag] = live[bag] or {}
    local b = live[bag][slot]
    if not b then
        b = CreateFrame("ItemButton", "TidyBagsItem" .. bag .. "_" .. slot, ns.BagFrame(bag, parent),
            "ContainerFrameItemButtonTemplate")
        b:SetID(slot)
        live[bag][slot] = b
    end
    return b
end

function ns.LiveButtons()
    return live
end

function ns.HideLive()
    for _, f in pairs(bagFrames) do f:Hide() end
end

function ns.ShowLive()
    for _, f in pairs(bagFrames) do f:Show() end
end

-- Special bags: their empty slots show what the bag holds, in the game's
-- own empty slot icon (Blizzard's combined bags show the bag icon there)
local MARKS = {
    [Enum.ItemClass.Quiver] = {
        [Enum.ItemQuiverSubclass.Quiver] = 132381,       -- inv_ammo_arrow_01
        [Enum.ItemQuiverSubclass.Ammopouch] = 132383,    -- inv_ammo_bullet_01
    },
    [Enum.ItemClass.Container] = {
        [Enum.ItemContainerSubclass.Soul] = 134075,      -- inv_misc_gem_amethyst_02
        [Enum.ItemContainerSubclass.Herb] = 136246,      -- trade_herbalism
        [Enum.ItemContainerSubclass.Enchanting] = 136244, -- trade_engraving
        [Enum.ItemContainerSubclass.Engineering] = 136243, -- trade_engineering
        [Enum.ItemContainerSubclass.Mining] = 136248,    -- trade_mining
        [Enum.ItemContainerSubclass.Leatherworking] = 136247, -- trade_leatherworking
        [Enum.ItemContainerSubclass.Tacklebox] = 136245, -- trade_fishing
        [Enum.ItemContainerSubclass.Cooking] = 133971,   -- inv_misc_food_15
    },
}

local bagMarks = {}

-- The icon for a bag's type (nil: a normal bag), kept per equipped bag item
local function BagMark(bag)
    if bag < 1 or bag > NUM_BAG_SLOTS then return end
    local id = GetInventoryItemID("player", C_Container.ContainerIDToInventoryID(bag))
    local m = bagMarks[bag]
    if not m or m.id ~= id then
        local icon
        if id then
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
            icon = MARKS[classID] and MARKS[classID][subClassID]
        end
        m = { id = id, icon = icon }
        bagMarks[bag] = m
    end
    return m.icon
end

local function ShowMark(b, hasItem)
    local mark = b.EmptyBagIcon
    if not mark then return end
    local icon = not hasItem and BagMark(b:GetBagID())
    if not icon then
        mark:Hide()
        return
    end
    mark:ClearAllPoints()
    if ns.P.style == "flaty" then
        mark:SetPoint("TOPLEFT", 1, -1)
        mark:SetPoint("BOTTOMRIGHT", -1, 1)
        mark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        mark:SetAllPoints()
        mark:SetTexCoord(0, 1, 0, 1)
    end
    mark:SetTexture(icon)
    if EMPTY_BAG_SLOT_EFFECT_COLOR then
        mark:SetVertexColor(EMPTY_BAG_SLOT_EFFECT_COLOR:GetRGBA())
    end
    mark:SetDesaturation(1)
    mark:SetAlpha(0.15)
    mark:Show()
end

-- Blizzard's own update of a bag item button, then the style on top
function ns.UpdateLive(b, owner)
    local bag, slot = b:GetBagID(), b:GetID()
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local texture = info and info.iconFileID
    local quality = info and info.quality
    local link = info and info.hyperlink
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)

    ClearItemButtonOverlay(b)
    b:SetHasItem(texture)
    b:SetItemButtonTexture(texture)
    b:SyncAppearanceWithHasItem()
    SetItemButtonQuality(b, quality, link, false, info and info.isBound)
    SetItemButtonCount(b, info and info.stackCount)
    b:UpdateExtended()
    b:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
    b:UpdateNewItem(quality)
    b:UpdateJunkItem(quality, info and info.hasNoValue)
    b:UpdateItemContextMatching()
    b:UpdateCooldown(texture)
    b:SetReadable(info and info.isReadable)
    b:CheckUpdateTooltip(owner)
    b.tbMatches = not (info and info.isFiltered)
    ns.SetMatches(b, b.tbMatches)

    ns.UpdateLock(b, info)
    Paint(b, texture ~= nil, quality)
    ShowMark(b, texture ~= nil)
    local level
    if info and ns.P.ilvl and IsGear(info.itemID) then
        level = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot))
    end
    ShowLevel(b, info and info.itemID, level, quality)
end

-- Locked (moving) items and junk are grey
function ns.UpdateLock(b, info)
    info = info or C_Container.GetContainerItemInfo(b:GetBagID(), b:GetID())
    local junk = ns.P.junk and info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue
    SetItemButtonDesaturated(b, (info and info.isLocked) or junk)
end

-------------------------------------------------------------------------------
-- Saved buttons (other characters)
-------------------------------------------------------------------------------
local function SavedEnter(self)
    if not self.item or not self.item.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.item.link)
    GameTooltip:Show()
end

local function SavedClick(self)
    if self.item and self.item.link then HandleModifiedItemClick(self.item.link) end
end

function ns.SavedButton(i, parent)
    local b = saved[i]
    if not b then
        b = CreateFrame("ItemButton", "TidyBagsSaved" .. i, parent)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", SavedEnter)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", SavedClick)
        saved[i] = b
    end
    return b
end

function ns.HideSaved(from)
    for i = from or 1, #saved do saved[i]:Hide() end
end

local function ItemName(item)
    return item.link and item.link:match("%[(.-)%]")
end

function ns.UpdateSaved(b, item, search)
    b.item = item
    local id = item and item.id
    SetItemButtonTexture(b, item and item.icon)
    SetItemButtonCount(b, item and item.count)
    SetItemButtonQuality(b, item and item.quality, item and item.link)
    SetItemButtonDesaturated(b, ns.P.junk and item and item.quality == Enum.ItemQuality.Poor)
    local match = true
    if search and search ~= "" then
        local name = item and ItemName(item)
        match = name ~= nil and name:lower():find(search:lower(), 1, true) ~= nil
    end
    ns.SetMatches(b, match)
    Paint(b, item ~= nil, item and item.quality)
    local level = item and item.link and ns.P.ilvl and IsGear(id) and C_Item.GetDetailedItemLevelInfo(item.link)
    ShowLevel(b, id, level, item and item.quality)
end

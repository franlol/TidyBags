-------------------------------------------------------------------------------
-- TidyBags - The bags window
--
--   header : title (the character shown), search, characters, bag slots,
--            sort, close
--   bags   : the equipped bags (optional row)
--   items  : backpack and bags 1-4 in one grid, then the slots the backpack
--            gets with an authenticator (locked until then); the reagent bag
--            as its own section, inside the grid, or hidden
--   footer : free slots, authenticator button, tracked currencies, money
-- Two looks: Flaty (flat, LibFlatyUI theme) and Blizzard (the game's
-- frame and buttons). Another character's bags are shown from what was saved
-- the last time it played (read only).
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local UI = LibStub("LibFlatyUI-1.0"):New({ accent = ns.ACCENT })
local T = UI.theme
local BUTTON = ns.BUTTON

local W = CreateFrame("Frame", "TidyBagsFrame", UIParent)
W:Hide()
W:SetFrameStrata("MEDIUM")
W:SetToplevel(true)
W:SetMovable(true)
W:SetClampedToScreen(true)
ns.window = W

-- the character shown (ns.charKey: the one in play, live)
local viewing
local search = ""
local function IsLive() return viewing == nil or viewing == ns.charKey end

local function Close() CloseAllBags() end

-------------------------------------------------------------------------------
-- Dragging (from the frame's background)
-------------------------------------------------------------------------------
local function DragStart()
    if not ns.P.locked then W:StartMoving() end
end
local function DragStop()
    W:StopMovingOrSizing()
    local point, _, _, x, y = W:GetPoint()
    ns.P.pos = { point = point, x = x, y = y }
end
local function Draggable(f)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", DragStart)
    f:SetScript("OnDragStop", DragStop)
end

-------------------------------------------------------------------------------
-- Frame: the two looks
-------------------------------------------------------------------------------
local flat = CreateFrame("Frame", nil, W, "BackdropTemplate")
flat:SetAllPoints()
Draggable(flat)
flat.title = UI.Text(flat, "", T.titleFont)
flat.title:SetPoint("TOPLEFT", 10, -12)
flat.close = UI.IconButton(flat, "close", 20, Close)
flat.close:SetPoint("TOPRIGHT", -8, -8)

local blizz = CreateFrame("Frame", nil, W, "PortraitFrameFlatTemplate")
blizz:SetAllPoints()
Draggable(blizz)
blizz:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_08")
blizz.CloseButton:SetScript("OnClick", Close)

local content = CreateFrame("Frame", nil, W)
content:SetAllPoints()
content:SetFrameLevel(blizz:GetFrameLevel() + 5)

-------------------------------------------------------------------------------
-- Header tools: one button per action, drawn flat or bare (Blizzard)
-------------------------------------------------------------------------------
local tools = {}
local function Tool(icon, tip, onClick)
    local b = CreateFrame("Button", nil, content, "BackdropTemplate")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.SetIcon = function(self, tex)
        if C_Texture.GetAtlasInfo(tex) then self.icon:SetAtlas(tex) else self.icon:SetTexture(tex) end
    end
    b:SetIcon(icon)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b.icon)
    b.hl:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        if self.flat then self:SetBackdropBorderColor(unpack(T.accent)) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(type(tip) == "function" and tip() or tip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        if self.flat then self:SetBackdropBorderColor(unpack(T.border)) end
        GameTooltip:Hide()
    end)
    tools[#tools + 1] = b
    return b
end

local function StyleTool(b, isFlat)
    b.flat = isFlat
    b.icon:ClearAllPoints()
    if isFlat then
        b:SetSize(20, 20)
        UI.Backdrop(b, T.button)
        b.icon:SetPoint("TOPLEFT", 3, -3)
        b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    else
        b:SetSize(24, 24)
        b:ClearBackdrop()
        b.icon:SetAllPoints()
    end
end

-- Sort: Blizzard's sorting; right click: the backpack's cleanup options
local sortTool = Tool("bags-button-autosort-up", BAG_CLEANUP_BAGS, function(self, button)
    if button == "RightButton" then
        MenuUtil.CreateContextMenu(self, function(_, root)
            ContainerFrame_AddButtons_BagCleanup(root, Enum.BagIndex.Backpack)
        end)
    else
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
        C_Container.SortBags()
    end
end)

local bagsTool = Tool("Interface\\Icons\\INV_Misc_Bag_08", function() return L["Bag slots"] end, function()
    ns.P.bagBar = not ns.P.bagBar
    ns.ApplyAll()
end)

-- Characters: pick whose bags to see
local charTool
local function ShowCharacter(key)
    viewing = key
    -- the game's search only covers the character in play
    C_Container.SetItemSearch(IsLive() and search or "")
    ns.Refresh()
end
ns.ShowCharacter = ShowCharacter
local function CharLabel(key)
    local data = ns.CharData(key)
    local c = data and RAID_CLASS_COLORS[data.class]
    local name = data and data.name or key
    return c and c:WrapTextInColorCode(name) or name
end
charTool = Tool("classicon-warrior", function() return L["Characters"] end, function(self)
    local current = viewing or ns.charKey
    if ns.P.style == "flaty" then
        local items = {}
        for _, key in ipairs(ns.Characters()) do items[#items + 1] = { key, CharLabel(key) } end
        UI.Menu(self, items, ShowCharacter)
    else
        MenuUtil.CreateContextMenu(self, function(_, root)
            for _, key in ipairs(ns.Characters()) do
                root:CreateRadio(CharLabel(key), function() return key == current end, ShowCharacter, key)
            end
        end)
    end
end)

-------------------------------------------------------------------------------
-- Search: the game's item search (it also greys items in Blizzard's frames)
-------------------------------------------------------------------------------
local function OnSearch(text)
    search = text or ""
    if IsLive() then
        C_Container.SetItemSearch(search)
    else
        ns.UpdateItems()
    end
end

local flatSearch = UI.SearchBox(content, SEARCH, OnSearch)
local blizzSearch = CreateFrame("EditBox", "TidyBagsSearchBox", content, "BagSearchBoxTemplate")
blizzSearch:SetHeight(20)
blizzSearch:HookScript("OnTextChanged", function(self) OnSearch(self:GetText()) end)

-------------------------------------------------------------------------------
-- Items
-------------------------------------------------------------------------------
local grid = CreateFrame("Frame", nil, content)
-- the sections apart from the grid (reagent bag, keyring): their name and
-- free slots
local sectionTexts = {}
local function SectionTexts(i)
    local t = sectionTexts[i]
    if not t then
        t = { title = UI.Text(content, "", "GameFontNormalSmall"), free = UI.Text(content, "", "GameFontHighlightSmall") }
        sectionTexts[i] = t
    end
    return t
end
-- the sections of the last layout: { bag, mode, texts (when apart) }
local layoutSections = {}

-- the equipped bags
local bagBar = CreateFrame("Frame", nil, content)
local bagButtons = {}

local function InvSlot(bag)
    return C_Container.ContainerIDToInventoryID(bag)
end

-- Free slots of a bag: live, or saved (data)
local function FreeSlots(bag, data)
    if data then
        local saved = data.bags and data.bags[bag]
        if not saved then return 0 end
        local n = saved.size
        for slot in pairs(saved.items) do
            if slot <= saved.size then n = n - 1 end
        end
        return n
    end
    if bag == ns.KEYRING then
        if not ns.KeyringOn() then return 0 end
        local size = ns.BagSize(bag)
        local n = size
        for slot = 1, size do
            if C_Container.GetContainerItemInfo(bag, slot) then n = n - 1 end
        end
        return n
    end
    return C_Container.GetContainerNumFreeSlots(bag)
end

local function BagEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local bag = self.bag
    if bag == ns.KEYRING then
        GameTooltip:SetText(KEYRING, 1, 1, 1)
    elseif not IsLive() then
        if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetText(EQUIP_CONTAINER, 1, 1, 1) end
    elseif bag == Enum.BagIndex.Backpack then
        GameTooltip:SetText(BACKPACK_TOOLTIP, 1, 1, 1)
    elseif not GameTooltip:SetInventoryItem("player", InvSlot(bag)) then
        GameTooltip:SetText(bag == ns.REAGENT_BAG and EQUIP_CONTAINER_REAGENT or EQUIP_CONTAINER, 1, 1, 1)
    end
    GameTooltip:Show()
    -- its items stand out
    ns.FocusBag(bag)
end

local function BagLeave()
    GameTooltip:Hide()
    ns.FocusBag(nil)
end

-- Click: shows or hides the bag's slots. With an item on the cursor it goes
-- into the bag (a key into the keyring); right click: the game's bag options
local function BagClick(self, button)
    local bag = self.bag
    if IsLive() then
        if CursorHasItem() then
            if bag == ns.KEYRING then PutKeyInKeyRing()
            elseif bag == Enum.BagIndex.Backpack then PutItemInBackpack()
            else PutItemInBag(InvSlot(bag)) end
            return
        elseif button == "RightButton" then
            if bag ~= ns.KEYRING then
                MenuUtil.CreateContextMenu(self, function(_, root)
                    ContainerFrame_AddButtons_BagFilters(root, bag)
                    ContainerFrame_AddButtons_BagCleanup(root, bag)
                end)
            end
            return
        end
    end
    if button == "LeftButton" then
        ns.P.hiddenBags[bag] = ns.BagShown(bag) or nil
        ns.ApplyAll()
    end
end

local function BagDrag(self)
    if IsLive() and self.bag ~= Enum.BagIndex.Backpack and self.bag ~= ns.KEYRING then
        PickupBagFromSlot(InvSlot(self.bag))
    end
end

local BAR_BAGS = ns.AllBags()
BAR_BAGS[#BAR_BAGS + 1] = ns.KEYRING
for i, bag in ipairs(BAR_BAGS) do
    local b = CreateFrame("ItemButton", "TidyBagsBagSlot" .. bag, bagBar)
    b.bag = bag
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnEnter", BagEnter)
    b:SetScript("OnLeave", BagLeave)
    b:SetScript("OnClick", BagClick)
    b:SetScript("OnDragStart", BagDrag)
    b:SetScript("OnReceiveDrag", BagClick)
    bagButtons[i] = b
end

local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local BACKPACK = "Interface\\Buttons\\Button-Backpack-Up"
local KEY = "Interface\\Icons\\INV_Misc_Key_03"

-- The keyring's slot shows when the character has a keyring
local function HasKeyring(data)
    if data then return data.bags and data.bags[ns.KEYRING] ~= nil end
    return ns.KeyringOn()
end

local function UpdateBagBar()
    local data = not IsLive() and ns.CharData(viewing)
    for _, b in ipairs(bagButtons) do
        local bag, icon, free = b.bag, nil, nil
        if bag == ns.KEYRING then
            icon = KEY
            if HasKeyring(data) then free = FreeSlots(bag, data) end
        elseif data then
            local saved = data.bags and data.bags[bag]
            b.link = saved and saved.link
            icon = bag == Enum.BagIndex.Backpack and BACKPACK
                or (b.link and C_Item.GetItemIconByID(b.link)) or EMPTY_BAG
        else
            icon = bag == Enum.BagIndex.Backpack and BACKPACK
                or GetInventoryItemTexture("player", InvSlot(bag)) or EMPTY_BAG
            if C_Container.GetContainerNumSlots(bag) > 0 then
                free = C_Container.GetContainerNumFreeSlots(bag)
            end
        end
        SetItemButtonTexture(b, icon)
        SetItemButtonCount(b, free)
        if free then b.Count:SetText(free) b.Count:Show() end
        ns.PaintBag(b)
        -- unchecked: its slots are hidden
        local on = ns.BagShown(bag)
        b.icon:SetDesaturated(not on)
        b:SetAlpha(on and 1 or 0.4)
    end
end

-------------------------------------------------------------------------------
-- Footer
-------------------------------------------------------------------------------
local freeText = UI.Text(content, "", "GameFontHighlightSmall")

local money = CreateFrame("Frame", nil, content)
money:SetSize(120, 16)
money.text = UI.Text(money, "", "GameFontHighlightSmall")
money.text:SetPoint("RIGHT")
money.text:SetJustifyH("RIGHT")
money:EnableMouse(true)
money:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(MONEY, 1, 1, 1)
    local total = 0
    for _, key in ipairs(ns.Characters()) do
        local data = ns.CharData(key)
        if data and data.money then
            local c = RAID_CLASS_COLORS[data.class]
            GameTooltip:AddDoubleLine(data.name, GetMoneyString(data.money, true),
                c and c.r or 1, c and c.g or 1, c and c.b or 1, 1, 1, 1)
            total = total + data.money
        end
    end
    GameTooltip:AddDoubleLine(L["Total"], GetMoneyString(total, true), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end)
money:SetScript("OnLeave", GameTooltip_Hide)

-- the backpack's extra slots, unlocked with an authenticator
local auth = CreateFrame("Button", nil, content)
auth:SetSize(18, 18)
auth.icon = auth:CreateTexture(nil, "ARTWORK")
auth.icon:SetAllPoints()
auth.icon:SetAtlas("bags-icon-addauthenticator")
auth:SetHighlightAtlas("bags-icon-addauthenticator", "ADD")
auth:SetScript("OnClick", function() StaticPopup_Show("BACKPACK_INCREASE_SIZE") end)
auth:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(BACKPACK_AUTHENTICATOR_INCREASE_SIZE, 1, 1, 1)
    GameTooltip:Show()
end)
auth:SetScript("OnLeave", GameTooltip_Hide)

-- the currencies tracked in the backpack
local currencies = {}
local function Currency(i)
    local c = currencies[i]
    if not c then
        c = CreateFrame("Frame", nil, content)
        c:SetSize(40, 16)
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(14, 14)
        c.icon:SetPoint("RIGHT")
        c.text = UI.Text(c, "", "GameFontHighlightSmall")
        c.text:SetPoint("RIGHT", c.icon, "LEFT", -2, 0)
        c:EnableMouse(true)
        c:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetCurrencyByID(self.id)
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", GameTooltip_Hide)
        currencies[i] = c
    end
    return c
end

local function UpdateFooter()
    local data = not IsLive() and ns.CharData(viewing)
    money.text:SetText(GetMoneyString((data and data.money) or (not data and GetMoney()) or 0, true))

    -- the free slots of the bags shown in the grid; a section apart shows
    -- its own
    local free = 0
    for _, bag in ipairs(ns.BAGS) do
        if ns.BagShown(bag) then free = free + FreeSlots(bag, data) end
    end
    for _, sec in ipairs(layoutSections) do
        local n = FreeSlots(sec.bag, data)
        if sec.mode == "together" and ns.BagShown(sec.bag) then free = free + n end
        if sec.texts then sec.texts.free:SetFormattedText(L["%d free"], n) end
    end
    freeText:SetFormattedText(L["%d free"], free)

    auth:SetShown(not data and not IsAccountSecured())

    -- currencies, right to left before the money
    local anchor, n = money, 0
    if not data then
        for i = 1, 10 do
            local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
            if not info then break end
            n = i
            local c = Currency(i)
            c.id = info.currencyTypesID
            c.icon:SetTexture(info.iconFileID)
            c.text:SetText(BreakUpLargeNumbers(info.quantity))
            c:SetWidth(c.text:GetStringWidth() + 18)
            c:ClearAllPoints()
            c:SetPoint("RIGHT", anchor, anchor == money and "RIGHT" or "LEFT", anchor == money and -money.text:GetStringWidth() - 10 or -8, 0)
            c:Show()
            anchor = c
        end
    end
    for i = n + 1, #currencies do currencies[i]:Hide() end
end

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------
local PAD = 10
local shown = {}       -- the live buttons in the grid, in order
local focusBag

function ns.FocusBag(bag)
    focusBag = bag
    if not IsLive() then return end
    for _, b in ipairs(shown) do
        b:SetAlpha((bag == nil or b:GetBagID() == bag) and 1 or 0.25)
    end
end

-- The style's look on a bag slot button
function ns.PaintBag(b)
    if ns.P.style == "flaty" then
        b:GetNormalTexture():SetAlpha(0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if not b.tbEdge then
            b.tbEdge = b:CreateTexture(nil, "BACKGROUND", nil, -7)
            b.tbEdge:SetPoint("TOPLEFT", -1, 1)
            b.tbEdge:SetPoint("BOTTOMRIGHT", 1, -1)
            b.tbEdge:SetColorTexture(0, 0, 0, 1)
        end
        b.tbEdge:Show()
    else
        b:GetNormalTexture():SetAlpha(1)
        b.icon:SetTexCoord(0, 1, 0, 1)
        if b.tbEdge then b.tbEdge:Hide() end
    end
    ns.StyleTexts(b)
end

-- Places a button in the grid: index i of a block starting at y (px)
local function Place(b, i, y, cols, step, s)
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    b:SetScale(s)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", grid, "TOPLEFT", col * step / s, -(y + row * step) / s)
    b:Show()
end

local function Rows(n, cols) return math.ceil(n / cols) end

-- The live buttons of the bags shown, plus the backpack's locked slots apart
local function LiveList()
    local main, extra, reagent, keys = {}, {}, {}, {}
    for _, bag in ipairs(ns.BAGS) do
        if ns.BagShown(bag) then
            local max, size = C_Container.GetContainerNumSlots(bag), C_Container.GetContainerNumSlots(bag)
            if bag == Enum.BagIndex.Backpack then max, size = ContainerFrame_GetContainerNumSlots(bag) end
            for slot = 1, max do
                local b = ns.LiveButton(bag, slot, grid)
                if slot > size then extra[#extra + 1] = b else main[#main + 1] = b end
            end
        end
    end
    for _, b in ipairs(extra) do main[#main + 1] = b end
    if ns.BagShown(ns.REAGENT_BAG) then
        for slot = 1, C_Container.GetContainerNumSlots(ns.REAGENT_BAG) do
            reagent[#reagent + 1] = ns.LiveButton(ns.REAGENT_BAG, slot, grid)
        end
    end
    if ns.KeyringOn() and ns.BagShown(ns.KEYRING) then
        for slot = 1, ns.BagSize(ns.KEYRING) do keys[#keys + 1] = ns.LiveButton(ns.KEYRING, slot, grid) end
    end
    return main, reagent, keys
end

-- Saved items of a character, as { item or false } lists
local function SavedList(data)
    local main, reagent, keys = {}, {}, {}
    local function Add(list, bag)
        if not ns.BagShown(bag) then return end
        local saved = data.bags and data.bags[bag]
        for slot = 1, saved and saved.size or 0 do list[#list + 1] = saved.items[slot] or false end
    end
    for _, bag in ipairs(ns.BAGS) do Add(main, bag) end
    Add(reagent, ns.REAGENT_BAG)
    Add(keys, ns.KEYRING)
    return main, reagent, keys
end

function ns.Layout()
    local P = ns.P
    local isFlat = P.style == "flaty"
    local cols, size, gap = P.columns, P.size, P.spacing
    local step, s = size + gap, size / BUTTON
    local live = IsLive()

    -- header
    local top = isFlat and 36 or 62
    local left = isFlat and PAD or PAD
    local data = not live and ns.CharData(viewing)
    if P.bagBar then
        bagBar:Show()
        bagBar:ClearAllPoints()
        bagBar:SetPoint("TOPLEFT", W, "TOPLEFT", left, -top)
        local n = 0
        for _, b in ipairs(bagButtons) do
            local on = b.bag ~= ns.KEYRING or HasKeyring(data)
            b:SetShown(on)
            if on then
                b:SetScale(s)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", bagBar, "TOPLEFT", n * step / s, 0)
                n = n + 1
            end
        end
        bagBar:SetSize(n * step, size)
        top = top + size + 8
    else
        bagBar:Hide()
    end

    -- items: the grid, then the reagent bag and the keyring (each apart,
    -- in the grid, or hidden)
    local main, reagent, keys
    if live then
        ns.ShowLive()
        ns.HideSaved()
        main, reagent, keys = LiveList()
    else
        ns.HideLive()
        main, reagent, keys = SavedList(data or {})
    end
    wipe(layoutSections)
    layoutSections[1] = { bag = ns.REAGENT_BAG, mode = P.reagents, list = reagent, title = L["Reagents"] }
    layoutSections[2] = { bag = ns.KEYRING, mode = P.keyring, list = keys, title = L["Keyring"] }

    local all = {}
    for _, x in ipairs(main) do all[#all + 1] = x end
    for _, sec in ipairs(layoutSections) do
        if sec.mode == "together" then
            for _, x in ipairs(sec.list) do all[#all + 1] = x end
        end
    end

    if live then
        -- hide only the buttons that left (a hidden button loses its tooltip)
        local used = {}
        for _, b in ipairs(all) do used[b] = true end
        for _, sec in ipairs(layoutSections) do
            if sec.mode == "separate" then
                for _, b in ipairs(sec.list) do used[b] = true end
            end
        end
        for _, slots in pairs(ns.LiveButtons()) do
            for _, b in pairs(slots) do
                if not used[b] then b:Hide() end
            end
        end
    end

    wipe(shown)
    local savedIndex = 0
    local function Put(x, i, y)
        local b = x
        if not live then
            savedIndex = savedIndex + 1
            b = ns.SavedButton(savedIndex, grid)
            b.savedItem = x or nil
        end
        Place(b, i, y, cols, step, s)
        shown[#shown + 1] = b
    end

    for i, x in ipairs(all) do Put(x, i, 0) end
    local height = Rows(#all, cols) * step - gap

    for i, sec in ipairs(layoutSections) do
        local texts = SectionTexts(i)
        local apart = sec.mode == "separate" and #sec.list > 0
        texts.title:SetShown(apart)
        texts.free:SetShown(apart)
        if apart then
            sec.texts = texts
            local y = height + 12
            texts.title:ClearAllPoints()
            texts.title:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -y)
            texts.title:SetText(sec.title)
            texts.free:ClearAllPoints()
            texts.free:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, -y)
            y = y + 16
            for k, x in ipairs(sec.list) do Put(x, k, y) end
            height = y + Rows(#sec.list, cols) * step - gap
        end
    end
    if not live then ns.HideSaved(savedIndex + 1) end

    local gridW = cols * step - gap
    local width = math.max(gridW, isFlat and 300 or 320) + 2 * PAD
    grid:ClearAllPoints()
    grid:SetPoint("TOPLEFT", W, "TOPLEFT", left, -top)
    grid:SetSize(gridW, math.max(height, 1))

    -- footer
    local bottom = top + height + 10
    freeText:ClearAllPoints()
    freeText:SetPoint("TOPLEFT", W, "TOPLEFT", left, -bottom - 2)
    auth:ClearAllPoints()
    auth:SetPoint("LEFT", freeText, "RIGHT", 6, 0)
    money:ClearAllPoints()
    money:SetPoint("TOPRIGHT", W, "TOPRIGHT", -PAD, -bottom)

    W:SetSize(width, bottom + 16 + PAD)
    W:SetScale(P.scale / 100)
    W:ClearAllPoints()
    W:SetPoint(P.pos.point, UIParent, P.pos.point, P.pos.x, P.pos.y)

    -- header contents
    local name = data and data.name or ns.CharName()
    local class = data and data.class or select(2, UnitClass("player"))
    charTool:SetIcon("classicon-" .. (class or "warrior"):lower())
    flat:SetShown(isFlat)
    blizz:SetShown(not isFlat)
    flatSearch:SetShown(isFlat)
    blizzSearch:SetShown(not isFlat)
    for _, b in ipairs(tools) do StyleTool(b, isFlat) end
    sortTool:SetEnabled(live)
    sortTool:SetAlpha(live and 1 or 0.4)

    local list = { charTool, bagsTool, sortTool }
    local box = isFlat and flatSearch or blizzSearch
    if isFlat then
        UI.Backdrop(flat, T.window, T.windowBorder)
        flat.title:SetText(name)
        local c = RAID_CLASS_COLORS[class]
        flat.title:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
        local x = -32
        for _, b in ipairs(list) do
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", W, "TOPRIGHT", x, -8)
            x = x - 24
        end
        box:ClearAllPoints()
        box:SetPoint("TOPRIGHT", W, "TOPRIGHT", x - 4, -8)
        box:SetSize(120, 20)
    else
        blizz:SetTitle(name)
        local x = -10
        for _, b in ipairs(list) do
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", W, "TOPRIGHT", x, -30)
            x = x - 28
        end
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", W, "TOPLEFT", 64, -32)
        box:SetPoint("RIGHT", list[#list], "LEFT", -8, 0)
    end
    for _, texts in ipairs(sectionTexts) do
        texts.title:SetFontObject(isFlat and "GameFontNormalSmall" or "GameFontNormal")
        if isFlat then texts.title:SetTextColor(unpack(T.accent)) else texts.title:SetTextColor(1, 0.82, 0) end
    end

    UpdateBagBar()
    UpdateFooter()
end

-------------------------------------------------------------------------------
-- Items: live ones wait for their data, as Blizzard's bags do
-------------------------------------------------------------------------------
local function UpdateShown()
    if IsLive() then
        for _, b in ipairs(shown) do ns.UpdateLive(b) end
    else
        for _, b in ipairs(shown) do ns.UpdateSaved(b, b.savedItem, search) end
    end
    if focusBag then ns.FocusBag(focusBag) end
end

function ns.UpdateItems()
    if W.refresh then
        W.refresh:Cancel()
        W.refresh = nil
    end
    if not IsLive() then return UpdateShown() end
    local refresh = ContinuableContainer:Create()
    for _, b in ipairs(shown) do
        local item = Item:CreateFromBagAndSlot(b:GetBagID(), b:GetID())
        if not item:IsItemEmpty() then refresh:AddContinuable(item) end
    end
    W.refresh = refresh
    refresh:ContinueOnLoad(function()
        W.refresh = nil
        UpdateShown()
    end)
end

function ns.Refresh()
    if not W:IsShown() then return end
    ns.Layout()
    ns.UpdateItems()
end

-------------------------------------------------------------------------------
-- Opening and closing follow Blizzard's bags (Blizzard.lua)
-------------------------------------------------------------------------------
function ns.SetOpen(open)
    if open == W:IsShown() then return end
    if open then
        viewing = nil
        W:Show()
    else
        W:Hide()
    end
end

W:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    ns.Refresh()
end)
W:SetScript("OnHide", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
    -- the items that were in sight stop being new once the bags close
    -- (Blizzard does it when its own bag frames hide, which never show now);
    -- the ones in unchecked bags stay new
    if IsLive() then
        for _, b in ipairs(shown) do C_NewItems.RemoveNewItem(b:GetBagID(), b:GetID()) end
    end
    flatSearch.edit:SetText("")
    flatSearch.edit:ClearFocus()
    viewing = nil
end)

local events = {
    BAG_UPDATE_DELAYED = "all", BAG_CONTAINER_UPDATE = "all", PLAYER_ACCOUNT_SECURED = "all",
    INVENTORY_SEARCH_UPDATE = "items", QUEST_ACCEPTED = "items", UNIT_QUEST_LOG_CHANGED = "items",
    BAG_NEW_ITEMS_UPDATED = "items", MERCHANT_SHOW = "items", MERCHANT_CLOSED = "items",
    ITEM_LOCK_CHANGED = "lock", BAG_UPDATE_COOLDOWN = "cooldown",
    PLAYER_MONEY = "footer", CURRENCY_DISPLAY_UPDATE = "footer",
}

local function OnEvent(_, event, a, b)
    if not W:IsShown() or not IsLive() then return end
    local what = events[event]
    if what == "all" then
        ns.Refresh()
    elseif what == "items" then
        if event ~= "UNIT_QUEST_LOG_CHANGED" or a == "player" then ns.UpdateItems() end
    elseif what == "lock" then
        local slots = a and b and ns.LiveButtons()[a]
        local button = slots and slots[b]
        if button and button:IsShown() then ns.UpdateLock(button) end
        UpdateBagBar()
    elseif what == "cooldown" then
        for _, button in ipairs(shown) do button:UpdateCooldown(button:HasItem()) end
    else
        UpdateFooter()
    end
end

ns.Module(function()
    for event in pairs(events) do
        if C_EventUtils.IsEventValid(event) then W:RegisterEvent(event) end
    end
    W:SetScript("OnEvent", OnEvent)
end, function()
    if W:IsShown() then ns.Refresh() end
end)

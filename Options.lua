-------------------------------------------------------------------------------
-- TidyBags - Options window (LibFlatyUI-1.0)
--
--   Look       : style, columns, item size, spacing, scale, window
--   Items      : item level, quality border, junk, the reagent bag, sorting
--   Characters : tooltip counts, saved characters
--   Profiles   : profile in use, new, copy, reset, delete
-- "Bags" (header) opens the bags, to see every change at once.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local UI = LibStub("LibFlatyUI-1.0"):New({ accent = ns.ACCENT })
UI.OnChange = function() UI.RefreshAll() end
local STRINGS = { confirm = "Click again to confirm", search = "Search...", accept = "Accept",
    cancel = "Cancel", reset = "Reset", none = "None" }
UI.strings = setmetatable({}, { __index = function(_, key) return L[STRINGS[key]] end })

local win

-- getter / setter of a profile setting; every change is applied
local function Bind(key)
    return function() return ns.P[key] end,
        function(v)
            ns.P[key] = v
            ns.ApplyAll()
        end
end
local function Count(v) return ("%d"):format(v) end
local function Pct(v) return ("%d%%"):format(v) end

local function Rebuild()
    -- the window is built again in the new language, same page and place
    local current = win.current
    local point, _, relPoint, x, y = win:GetPoint(1)
    win:Hide()
    win = nil
    wipe(UI.widgets)
    wipe(UI.pages)
    ns.ToggleOptions()
    win:ClearAllPoints()
    win:SetPoint(point, UIParent, relPoint, x, y)
    win:Select(current)
    ns.ApplyAll()
end

-------------------------------------------------------------------------------
-- Look
-------------------------------------------------------------------------------
local function BuildLook(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["Style"]))
    local g, s = Bind("style")
    card:Add(UI.Segmented(card, nil, { { "flaty", "Flaty" }, { "blizzard", "Blizzard" } }, g, s))

    card = page:Add(1, UI.Card(page.content, L["Size"]))
    g, s = Bind("columns")
    card:Add(UI.Slider(card, L["Columns"], 6, 36, 1, g, s, { format = Count }))
    g, s = Bind("size")
    card:Add(UI.Slider(card, L["Item size"], 24, 56, 1, g, s, { format = UI.px }))
    g, s = Bind("spacing")
    card:Add(UI.Slider(card, L["Spacing"], 0, 12, 1, g, s, { format = UI.px }))
    g, s = Bind("scale")
    card:Add(UI.Slider(card, L["Scale"], 50, 150, 5, g, s, { format = Pct }))

    card = page:Add(2, UI.Card(page.content, L["Window"]))
    g, s = Bind("bagBar")
    card:Add(UI.Check(card, L["Bag slots"], g, s))
    g, s = Bind("locked")
    card:Add(UI.Check(card, L["Lock position"], g, s))
    card:Add(UI.Buttons(card, {
        { L["Reset position"], function()
            ns.P.pos = ns.Copy(ns.defaults.pos)
            ns.ApplyAll()
        end, "danger", confirm = true },
    }))

    card = page:Add(2, UI.Card(page.content, "TidyBags"))
    card:Add(UI.Segmented(card, L["Language"], { { "enUS", "English" }, { "esES", "Español" } },
        function() return ns.db.language or "enUS" end, function(v)
            ns.SetLanguagePref(v)
            Rebuild()
        end))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Items
-------------------------------------------------------------------------------
local function BuildItems(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["Items"]))
    local g, s = Bind("ilvl")
    card:Add(UI.Check(card, L["Item level"], g, s))
    g, s = Bind("quality")
    card:Add(UI.Check(card, L["Quality border"], g, s))
    g, s = Bind("junk")
    card:Add(UI.Check(card, L["Grey out junk"], g, s))

    card = page:Add(1, UI.Card(page.content, L["Reagent bag"]))
    g, s = Bind("reagents")
    card:Add(UI.Segmented(card, nil, {
        { "separate", L["Separate"] }, { "together", L["With the rest"] }, { "hidden", L["Hidden"] },
    }, g, s))

    -- the game's own settings (every character)
    card = page:Add(2, UI.Card(page.content, L["Sorting"], L["Game settings, for every character."]))
    card:Add(UI.Check(card, L["Sort from right to left"],
        function() return C_Container.GetSortBagsRightToLeft() end,
        function(v) C_Container.SetSortBagsRightToLeft(v) end))
    card:Add(UI.Check(card, L["Loot into the leftmost bag"],
        function() return C_Container.GetInsertItemsLeftToRight() end,
        function(v) C_Container.SetInsertItemsLeftToRight(v) end))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Characters
-------------------------------------------------------------------------------
local function BuildCharacters(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["Tooltips"]))
    local g, s = Bind("tooltip")
    card:Add(UI.Check(card, L["Item counts of every character"], g, s))

    card = page:Add(2, UI.Card(page.content, L["Characters"], L["Saved when they log in."]))
    card:Add(UI.List(card, {
        rows = 10,
        items = ns.Characters,
        label = function(key)
            local data = ns.CharData(key)
            return data and data.name or key
        end,
        lead = "dot",
        color = function(key)
            local data = ns.CharData(key)
            local c = data and RAID_CLASS_COLORS[data.class]
            return c and { c.r, c.g, c.b } or { 1, 1, 1 }
        end,
        secondary = function(key)
            local data = ns.CharData(key)
            return data and data.money and GetMoneyString(data.money, true) or ""
        end,
        canRemove = function(key) return key ~= ns.charKey end,
        onRemove = function(_, key)
            ns.ForgetCharacter(key)
            UI.RefreshAll()
        end,
    }))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------
local function ProfileList(othersOnly)
    local out = {}
    for _, name in ipairs(ns.ProfileNames()) do
        if not othersOnly or name ~= ns.profileName then out[#out + 1] = { name, name } end
    end
    return out
end

local function BuildProfiles(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["This character"],
        L["Several characters can share a profile."]))
    card:Add(UI.Dropdown(card, L["Profile in use"], function() return ProfileList(false) end,
        function() return ns.profileName end, function(v) ns.UseProfile(v) UI.RefreshAll() end))
    local newName = ""
    card:Add(UI.Input(card, L["New profile"], function() return newName end, function(v)
        v = strtrim(v or "")
        if v == "" then return end
        ns.UseProfile(v)
        newName = ""
        UI.RefreshAll()
    end))

    card = page:Add(2, UI.Card(page.content, L["Manage"]))
    local hasOthers = function() return #ProfileList(true) > 0 end
    card:Add(UI.Buttons(card, {
        { L["Copy from"] .. "...", function(self)
            UI.Menu(self, ProfileList(true), function(name)
                UI.Dialog(L["This replaces every setting of the profile in use. Continue?"], L["Copy"], function()
                    ns.CopyProfile(name)
                    UI.RefreshAll()
                end)
            end)
        end },
    }, { enableIf = hasOthers }))
    card:Add(UI.Buttons(card, {
        { L["Reset this profile"], function() ns.ResetProfile() UI.RefreshAll() end, "danger", confirm = true },
    }))
    card:Add(UI.Buttons(card, {
        { L["Delete profile"] .. "...", function(self)
            UI.Menu(self, ProfileList(true), function(name)
                UI.Dialog(L["Delete the profile \"%s\"?"]:format(name), L["Delete"], function()
                    ns.DeleteProfile(name)
                    UI.RefreshAll()
                end)
            end)
        end, "danger" },
    }, { enableIf = hasOthers }))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function Build()
    win = UI.Window({ name = "TidyBagsOptions", title = "TidyBags", version = ns.version,
        logo = "Interface\\Icons\\INV_Misc_Bag_08", width = 600, height = 440, navWidth = 110 })
    win:AddNav("look", L["Look"], BuildLook)
    win:AddNav("items", L["Items"], BuildItems)
    win:AddNav("characters", L["Characters"], BuildCharacters)
    win:AddNav("profiles", L["Profiles"], BuildProfiles)
    UI.OnRefresh = function()
        win:SetSubtitle(L["Profile: %s"]:format(ns.profileName or ""))
    end
    win:AddHeaderButton(L["Bags"], function() ToggleAllBags() end,
        function() return ns.window:IsShown() end)
    win:Select("look")
end

-- the bags opening or closing light the header button
local function BagsToggled()
    if win and win:IsShown() then UI.RefreshAll() end
end
ns.window:HookScript("OnShow", BagsToggled)
ns.window:HookScript("OnHide", BagsToggled)

function ns.ToggleOptions()
    if not win then
        Build()
        win:Show()
        return
    end
    win:Toggle()
end

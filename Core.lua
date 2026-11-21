-------------------------------------------------------------------------------
-- TidyBags - Settings, profiles, slash command
--
-- TidyBagsDB = {
--     language  = "enUS" | "esES",
--     chars     = { [character] = saved bags },   (Data.lua)
--     profiles  = { [name] = settings },
--     profileOf = { [character] = name },
--     icon      = LibDBIcon's saved state (account-wide),
-- }
-- ns.P is the profile in use. Every change applies at once.
-------------------------------------------------------------------------------

local ADDON, ns = ...

ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
if ns.version:find("^@") then ns.version = "dev" end

ns.ACCENT = { 0.96, 0.72, 0.32 }

-- Bag IDs: the backpack and the four bag slots, then the reagent bag
ns.BAGS = { 0, 1, 2, 3, 4 }
ns.REAGENT_BAG = Enum.BagIndex.ReagentBag
ns.KEYRING = Enum.BagIndex.Keyring

-- The keyring exists when the game has it on and shows once the character
-- has had a key (the game's own rule for its keyring button)
function ns.KeyringOn()
    return C_ActionBar.ShouldShowKeyring() and GetCVarBool("showKeyring")
end

-- the texts' font: Flaty's Oswald (the game's Arial Narrow without it)
local Flaty = LibStub("LibFlatyUI-1.0")
local FONT = Flaty.Media and Flaty.Media("font", "Flaty: Oswald") or "Fonts\\ARIALN.TTF"

ns.defaults = {
    enabled = true,         -- off: the game's own bags
    style = "flaty",        -- "flaty" or "blizzard"
    columns = 12,
    size = 36,              -- item size (px)
    spacing = 4,            -- space between items (px)
    scale = 100,            -- window scale (%)
    reagents = "separate",  -- the reagent bag: "separate" or "together" (in the grid)
    keyring = "separate",   -- the keyring: the same choices
    hiddenBags = {},        -- [bagID] = true: its slots are not shown (bag slots row)
    bagBar = true,          -- the equipped bags above the items
    locked = false,         -- the window can't be dragged
    pos = { point = "BOTTOMRIGHT", x = -60, y = 110 },
    ilvl = true,            -- item level on equipment
    quality = true,         -- border in the item's quality color
    junk = true,            -- grey poor quality items
    tooltip = true,         -- counts of other characters in item tooltips
    -- the texts on the items: font, size (px on screen), outline, and the
    -- point of the item they sit at, with an offset (px)
    texts = {
        count = { font = FONT, size = 12, outline = "THICKOUTLINE", point = "BOTTOMRIGHT", x = -2, y = 2 },
        ilvl = { font = FONT, size = 12, outline = "OUTLINE", point = "TOPLEFT", x = 3, y = -4 },
    },
}

local function Copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = Copy(v) end
    return c
end
ns.Copy = Copy

-- Missing keys of t from def (the rest is kept)
local function Fill(t, def)
    for k, v in pairs(def) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            Fill(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
end

-------------------------------------------------------------------------------
-- Modules: start() once at login, apply() after every change
-------------------------------------------------------------------------------
ns.modules = {}
function ns.Module(start, apply)
    ns.modules[#ns.modules + 1] = { start = start, apply = apply }
end

function ns.ApplyAll()
    for _, m in ipairs(ns.modules) do
        if m.apply then m.apply() end
    end
end

-------------------------------------------------------------------------------
-- Characters: Forever characters have a surname, so it is part of the key
-------------------------------------------------------------------------------
function ns.CharName()
    local name, surname = UnitName("player")
    if surname and surname ~= "" then name = name .. " " .. surname end
    return name or "?"
end

local function CharKey()
    return ns.CharName() .. " - " .. (GetRealmName() or "?")
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------
local DEFAULT = "Default"

-- Older settings in the current form
local function Migrate(p)
    -- "hidden" reagent bag or keyring: now an unchecked bag in the bag slots row
    for key, bag in pairs({ reagents = ns.REAGENT_BAG, keyring = ns.KEYRING }) do
        if p[key] == "hidden" then
            p.hiddenBags = p.hiddenBags or {}
            p.hiddenBags[bag] = true
            p[key] = "separate"
        end
    end
end

local function FillProfile(p)
    Migrate(p)
    Fill(p, ns.defaults)
end

local function SetProfile(name)
    local db = ns.db
    db.profiles[name] = db.profiles[name] or {}
    db.profileOf[ns.charKey] = name
    ns.profileName = name
    ns.P = db.profiles[name]
    FillProfile(ns.P)
end

-- Whether a bag's slots are shown (the bag slots row)
function ns.BagShown(bag)
    return not ns.P.hiddenBags[bag]
end

function ns.UseProfile(name)
    SetProfile(name)
    ns.ApplyAll()
end

function ns.CopyProfile(from)
    local src = ns.db.profiles[from]
    if not src or from == ns.profileName then return end
    wipe(ns.P)
    for k, v in pairs(Copy(src)) do ns.P[k] = v end
    FillProfile(ns.P)
    ns.ApplyAll()
end

function ns.ResetProfile()
    wipe(ns.P)
    Fill(ns.P, ns.defaults)
    ns.ApplyAll()
end

function ns.DeleteProfile(name)
    if name == ns.profileName then return end
    ns.db.profiles[name] = nil
    for char, p in pairs(ns.db.profileOf) do
        if p == name then ns.db.profileOf[char] = nil end
    end
end

function ns.ProfileNames()
    local list = {}
    for name in pairs(ns.db.profiles) do list[#list + 1] = name end
    table.sort(list)
    return list
end

function ns.SetLanguagePref(lang)
    ns.db.language = lang
    ns.SetLanguage(lang)
end

-------------------------------------------------------------------------------
-- Loading
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        TidyBagsDB = TidyBagsDB or {}
        ns.db = TidyBagsDB
        ns.db.chars = ns.db.chars or {}
        ns.db.profiles = ns.db.profiles or {}
        ns.db.profileOf = ns.db.profileOf or {}
        ns.db.icon = ns.db.icon or {}
        ns.SetLanguage(ns.db.language or "enUS")
    else
        ns.charKey = CharKey()
        SetProfile(ns.db.profileOf[ns.charKey] or DEFAULT)
        for _, m in ipairs(ns.modules) do m.start() end
        ns.ApplyAll()
    end
end)

-------------------------------------------------------------------------------
-- /tidybags (or /tb): the options
-------------------------------------------------------------------------------
SLASH_TIDYBAGS1 = "/tidybags"
SLASH_TIDYBAGS2 = "/tb"
SlashCmdList.TIDYBAGS = function() ns.ToggleOptions() end

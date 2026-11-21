-------------------------------------------------------------------------------
-- TidyBags - Minimap button (LibDBIcon) and addon menu entry
-- Click: the options
-------------------------------------------------------------------------------

local ADDON, ns = ...
local L = ns.L

local DBIcon = LibStub("LibDBIcon-1.0", true)
local LDB = LibStub("LibDataBroker-1.1", true)

local COLOR = ("|cff%02x%02x%02x"):format(ns.ACCENT[1] * 255, ns.ACCENT[2] * 255, ns.ACCENT[3] * 255)

local function Start()
    if not (DBIcon and LDB) then return end
    local obj = LDB:NewDataObject(ADDON, {
        type = "launcher",
        text = "TidyBags",
        icon = "Interface\\Icons\\INV_Misc_Bag_08",
        OnClick = function()
            ns.ToggleOptions()
        end,
        OnTooltipShow = function(tip)
            tip:AddLine(COLOR .. "TidyBags|r")
            tip:AddLine(L["Profile"] .. ": |cffffffff" .. (ns.profileName or "") .. "|r")
            tip:AddLine(" ")
            tip:AddDoubleLine(L["Click"], L["Open the options"], 0.7, 0.7, 0.7, 1, 1, 1)
        end,
    })
    -- the addon menu entry follows LibDBIcon's own saved showInCompartment
    DBIcon:Register(ADDON, obj, ns.db.icon)
end

function ns.SetMinimapIcon(show)
    ns.db.icon.hide = not show
    if not DBIcon then return end
    if show then DBIcon:Show(ADDON) else DBIcon:Hide(ADDON) end
end

ns.Module(Start)

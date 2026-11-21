-------------------------------------------------------------------------------
-- TidyBags - Blizzard's bags
--
-- Blizzard keeps deciding when the bags are open: the bag key, the bag
-- buttons, Escape, and opening at a vendor, mailbox or bank all go through
-- its own functions. Its bag frames live under a hidden parent (they still
-- open and close, unseen), and TidyBags' window shows while any of them is
-- open. Closing the window closes Blizzard's bags.
-------------------------------------------------------------------------------

local _, ns = ...

local hidden = CreateFrame("Frame")
hidden:Hide()

local function BagFrames()
    local list = { ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES do
        list[#list + 1] = _G["ContainerFrame" .. i]
    end
    return list
end

local function HideBlizzard()
    for _, f in ipairs(BagFrames()) do f:SetParent(hidden) end
end

-- One check per frame, after Blizzard has finished opening or closing
local pending = false
local function Sync()
    pending = false
    ns.SetOpen(IsAnyBagOpen())
end
local function Queue()
    if pending then return end
    pending = true
    RunNextFrame(Sync)
end

ns.Module(function()
    HideBlizzard()
    -- a full screen panel moves Blizzard's bag frames under it
    hooksecurefunc("ContainerFrame_SetFullScreenFrame", HideBlizzard)
    hooksecurefunc("ContainerFrame_ClearFullScreenFrame", HideBlizzard)

    for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "OpenBackpack", "CloseBackpack",
        "ToggleBackpack", "OpenBag", "CloseBag", "ToggleBag" }) do
        hooksecurefunc(name, Queue)
    end
    for _, f in ipairs(BagFrames()) do
        hooksecurefunc(f, "Show", Queue)
        hooksecurefunc(f, "Hide", Queue)
        hooksecurefunc(f, "SetShown", Queue)
    end
    Queue()
end)

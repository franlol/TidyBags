-------------------------------------------------------------------------------
-- TidyBags - Blizzard's bags
--
-- Blizzard keeps deciding when the bags are open: the bag key, the bag
-- buttons, Escape, and opening at a vendor, mailbox or bank all go through
-- its own functions. While TidyBags is on, its bag frames live under a hidden
-- parent (they still open and close, unseen), and TidyBags' window shows
-- while any of them is open. Closing the window closes Blizzard's bags.
-- Off, Blizzard's frames are back under UIParent and nothing else changes.
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

local function Reparent()
    local parent = ns.P.enabled and hidden or UIParent
    for _, f in ipairs(BagFrames()) do
        if f:GetParent() ~= parent then FrameUtil.SetParentMaintainRenderLayering(f, parent) end
    end
end

-- One check per frame, after Blizzard has finished opening or closing
local pending = false
local function Sync()
    pending = false
    ns.SetOpen(ns.P.enabled and IsAnyBagOpen())
end
local function Queue()
    if pending then return end
    pending = true
    RunNextFrame(Sync)
end

local wasEnabled
ns.Module(function()
    -- a full screen panel moves Blizzard's bag frames under it
    hooksecurefunc("ContainerFrame_SetFullScreenFrame", function() if ns.P.enabled then Reparent() end end)
    hooksecurefunc("ContainerFrame_ClearFullScreenFrame", function() if ns.P.enabled then Reparent() end end)

    for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "OpenBackpack", "CloseBackpack",
        "ToggleBackpack", "OpenBag", "CloseBag", "ToggleBag" }) do
        hooksecurefunc(name, Queue)
    end
    for _, f in ipairs(BagFrames()) do
        hooksecurefunc(f, "Show", Queue)
        hooksecurefunc(f, "Hide", Queue)
        hooksecurefunc(f, "SetShown", Queue)
    end
end, function()
    -- turned on or off: the bags close, and open again in the other look
    if wasEnabled ~= nil and wasEnabled ~= ns.P.enabled then CloseAllBags() end
    wasEnabled = ns.P.enabled
    Reparent()
    Queue()
end)

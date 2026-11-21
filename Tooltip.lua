-------------------------------------------------------------------------------
-- TidyBags - Item tooltips: how many each character has in its bags
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS[class]
    return c and c.r or 1, c and c.g or 1, c and c.b or 1
end

local function AddCounts(tooltip, data)
    if not ns.P or not ns.P.tooltip then return end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local id = data and data.id
    if type(id) ~= "number" then return end

    local lines, total = {}, 0
    for _, key in ipairs(ns.Characters()) do
        local n = ns.CountOf(key, id)
        if n > 0 then
            lines[#lines + 1] = { key, n }
            total = total + n
        end
    end
    if #lines == 0 then return end

    tooltip:AddLine(" ")
    for _, line in ipairs(lines) do
        local char = ns.CharData(line[1])
        local r, g, b = ClassColor(char.class)
        tooltip:AddDoubleLine(char.name, line[2], r, g, b, 1, 1, 1)
    end
    if #lines > 1 then
        tooltip:AddDoubleLine(L["Total"], total, 1, 0.82, 0, 1, 1, 1)
    end
end

ns.Module(function()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddCounts)
end)

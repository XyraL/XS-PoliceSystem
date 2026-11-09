Points = {}

Points.Kinds = {
    station = {
        { key = 'duty', icon = 'clock' },
        { key = 'locker', icon = 'shirt' },
        { key = 'armory', icon = 'gun' },
        { key = 'garage', icon = 'car', spawn = true },
        { key = 'helipad', icon = 'helicopter', spawn = true },
        { key = 'evidence', icon = 'box' },
        { key = 'lab', icon = 'gear' },
        { key = 'booking', icon = 'id' },
        { key = 'boss', icon = 'star' },
        { key = 'camroom', icon = 'camera' },
    },
    jail = {
        { key = 'cell', icon = 'door' },
        { key = 'canteen', icon = 'food' },
        { key = 'workout', icon = 'dumbbell', exercise = true },
        { key = 'release', icon = 'exit', single = true },
        { key = 'solitary', icon = 'door' },
        { key = 'guard', icon = 'shield', npc = true },
        { key = 'clerk', icon = 'cash', npc = true },
        { key = 'trader', icon = 'user', npc = true },
        { key = 'craft', icon = 'gear' },
        { key = 'hide', icon = 'lock', named = true },
        { key = 'tunnel', icon = 'door', exit = true },
        { key = 'fence', icon = 'barrier', exit = true },
    },
    impound = {
        { key = 'desk', icon = 'id' },
        { key = 'lot', icon = 'car', vehicle = true },
    },
    blip = {},
    service = {
        { key = 'task', icon = 'broom' },
    },
}

function Points.Allowed(placeKind, pointKind)
    for _, def in ipairs(Points.Kinds[placeKind] or {}) do
        if def.key == pointKind then return def end
    end
    return nil
end

Points.SpotMargin = 15.0

function Points.Reach(place, center, radius)
    radius = tonumber(radius) or 150.0
    if type(center) ~= 'table' or not center.x then return radius end
    local cx, cy, cz = center.x + 0.0, center.y + 0.0, (center.z or 0.0) + 0.0
    local function fit(p)
        if type(p) ~= 'table' or not p.x or not p.y then return end
        local d = math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2 + ((p.z or cz) - cz) ^ 2)
        radius = math.max(radius, d + Points.SpotMargin)
    end
    for kind, list in pairs(place.points or {}) do
        if kind ~= 'release' and type(list) == 'table' then
            for _, p in ipairs(list) do fit(p) end
        end
    end
    for _, work in ipairs(place.work or {}) do
        for _, spot in ipairs(work.spots or {}) do fit(spot) end
    end
    return radius
end

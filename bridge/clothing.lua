Clothing = { name = nil }

if IsDuplicityVersion() or not Config then return end

local SUPPORTED = { 'XS-Appearance', 'illenium-appearance', 'qb-clothing' }

local function detect()
    local forced = Config.Bridges and Config.Bridges.clothing or 'auto'
    if forced == 'none' then return nil end
    if forced ~= 'auto' then return forced end
    for _, resource in ipairs(SUPPORTED) do
        if GetResourceState(resource) == 'started' then return resource end
    end
    return nil
end

function Clothing.OpenOutfits()
    Clothing.name = detect()
    if Clothing.name == 'XS-Appearance' then
        local ok = pcall(function() exports['XS-Appearance']:OpenWardrobe() end)
        if ok then return true end
    end
    if Clothing.name == 'illenium-appearance' then
        TriggerEvent('illenium-appearance:client:openOutfitMenu')
        return true
    end
    if Clothing.name == 'qb-clothing' then
        TriggerEvent('qb-clothing:client:openOutfitMenu')
        return true
    end
    return false
end

local COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS = { 0, 1, 2, 6, 7 }

function Clothing.Snapshot(ped)
    local look = { c = {}, p = {} }
    for _, id in ipairs(COMPONENTS) do
        look.c[tostring(id)] = { GetPedDrawableVariation(ped, id), GetPedTextureVariation(ped, id) }
    end
    for _, id in ipairs(PROPS) do
        look.p[tostring(id)] = { GetPedPropIndex(ped, id), GetPedPropTextureIndex(ped, id) }
    end
    return look
end

function Clothing.Restore(ped, look)
    if type(look) ~= 'table' then return end
    for id, v in pairs(look.c or {}) do
        SetPedComponentVariation(ped, tonumber(id), tonumber(v[1]) or 0, tonumber(v[2]) or 0, 0)
    end
    for id, v in pairs(look.p or {}) do
        local prop = tonumber(id)
        if (tonumber(v[1]) or -1) < 0 then
            ClearPedProp(ped, prop)
        else
            SetPedPropIndex(ped, prop, tonumber(v[1]), tonumber(v[2]) or 0, true)
        end
    end
end

function Clothing.ReloadSaved()
    local name = detect()
    if name == 'XS-Appearance' then
        TriggerEvent('XS-Appearance:client:reload')
        return true
    end
    if name == 'illenium-appearance' then
        TriggerEvent('illenium-appearance:client:reloadSkin', true)
        return true
    end
    if name == 'qb-clothing' then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
        return true
    end
    return false
end

function Clothing.Wears(ped, outfit)
    if type(outfit) ~= 'table' then return false end
    local checked = false
    for _, id in ipairs({ 11, 4 }) do
        local v = outfit[id] or outfit[tostring(id)]
        if type(v) == 'table' then
            checked = true
            if GetPedDrawableVariation(ped, id) ~= (tonumber(v[1]) or 0) then return false end
        end
    end
    return checked
end

function Clothing.Wear(ped, outfit)
    if type(outfit) ~= 'table' then return end
    for id, v in pairs(outfit) do
        SetPedComponentVariation(ped, tonumber(id), tonumber(v[1]) or 0, tonumber(v[2]) or 0, 0)
    end
    for _, prop in ipairs(PROPS) do ClearPedProp(ped, prop) end
end

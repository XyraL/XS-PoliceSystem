Evidence = { name = nil }

local KNOWN = { 'evidences' }
local FORENSIC_ACTIONS = { fingerprint = true, dustPrints = true }

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

function Evidence.Detect()
    local forced = (Config.Bridges or {}).evidence or 'auto'
    if forced == 'auto' then
        for _, name in ipairs(KNOWN) do
            if running(name) then return name end
        end
        return 'builtin'
    end
    if forced == 'XS-PoliceSystem' or forced == 'builtin' then return 'builtin' end
    return forced
end

function Evidence.Name()
    Evidence.name = Evidence.Detect()
    return Evidence.name
end

function Evidence.Ours()
    return Evidence.Name() == 'builtin'
end

function Evidence.Hides(action)
    return FORENSIC_ACTIONS[action] == true and not Evidence.Ours()
end

if not IsDuplicityVersion() then return end

local function coords(at)
    if type(at) ~= 'table' and type(at) ~= 'vector3' then return nil end
    local x, y, z = tonumber(at.x), tonumber(at.y), tonumber(at.z)
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

function Evidence.Forward(kind, src, at)
    local name = Evidence.Name()
    if name ~= 'evidences' then return false end
    local ped = GetPlayerPed(src)
    local c = coords(at) or (ped ~= 0 and GetEntityCoords(ped) or nil)
    if not c then return false end
    local ok = pcall(function() exports.evidences:syncEvidence(kind, src, 'atCoords', c) end)
    return ok
end

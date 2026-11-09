Status = { list = {} }

Status.Known = {
    fight = true, widepupils = true, redeyes = true, weedsmell = true, gunpowder = true, chemicals = true, heavybreath = true,
    sweat = true, handbleed = true, confused = true, alcohol = true, heavyalcohol = true, agitated = true,
}

function Status.Set(src, id, seconds)
    id = tostring(id or '')
    if not Status.Known[id] then return false end
    local cid = Framework.GetCitizenId(src)
    if not cid then return false end
    seconds = Util.Clamp(math.floor(tonumber(seconds) or 0), 0, 3600)
    Status.list[cid] = Status.list[cid] or {}
    Status.list[cid][id] = seconds > 0 and os.time() + seconds or nil
    return true
end

function Status.Active(src)
    local cid = Framework.GetCitizenId(src)
    local out, now = {}, os.time()
    for id, untilAt in pairs(cid and Status.list[cid] or {}) do
        if untilAt > now then out[id] = true else Status.list[cid][id] = nil end
    end
    local shot = cid and Field.gsr[cid]
    if shot and now - shot <= (Config.Gsr.minutes or 20) * 60 then out.gunpowder = true end
    return out
end

function Status.Texts(src)
    local out = {}
    for id in pairs(Status.Active(src)) do out[#out + 1] = Text('status_' .. id) end
    table.sort(out)
    return out
end

function Status.Breath(src)
    local active = Status.Active(src)
    if active.heavyalcohol then return Util.Round(0.13 + math.random() * 0.11, 3) end
    if active.alcohol then return Util.Round(0.05 + math.random() * 0.05, 3) end
    return 0.0
end

function Status.Drugs(src)
    local active = Status.Active(src)
    local out = {}
    for key, ids in pairs((Config.Tests or {}).drugs or {}) do
        local hit = false
        for _, id in ipairs(ids) do if active[id] then hit = true end end
        out[key] = hit
    end
    return out
end

RegisterNetEvent('XS-PoliceSystem:server:status', function(id, seconds)
    Status.Set(source, id, seconds)
end)

exports('SetStatus', function(src, id, seconds) return Status.Set(tonumber(src), id, seconds) end)
exports('GetStatus', function(src) return Status.Active(tonumber(src)) end)

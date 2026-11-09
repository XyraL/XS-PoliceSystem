Links = {}

function Links.Warrants(cid)
    if not cid or GetResourceState('XS-MDT') ~= 'started' then return 0 end
    local ok, count = pcall(function() return exports['XS-MDT']:GetActiveWarrants(cid) end)
    return ok and tonumber(count) or 0
end

exports('GetPlateFlag', function(plate)
    local f = Plates.Get(plate)
    if not f then return nil end
    return { plate = Plates.Norm(plate), reason = f.reason, officer = f.officer, expires = f.expires }
end)

exports('GetProfile', function(cid)
    cid = tostring(cid or '')
    if cid == '' then return nil end
    local online = Framework.GetPlayerByCitizenId(cid)
    local meta = online and online.PlayerData.metadata
    if not meta then
        local row = MySQL.single.await('SELECT `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
        meta = row and Db.Decode(row.metadata, {}) or {}
    end
    local out = { tracker = meta.tracker == true, lab = {} }
    local svc = MySQL.single.await('SELECT `tasks`, `reason`, `officer` FROM `xs_police_service` WHERE `citizenid` = ?', { cid })
    if svc and (tonumber(svc.tasks) or 0) > 0 then out.service = { tasks = tonumber(svc.tasks), reason = svc.reason, officer = svc.officer } end
    for _, r in ipairs(MySQL.query.await('SELECT `place_id`, `kind`, `subject`, `result`, `officer`, `created_at` FROM `xs_police_lab` WHERE `match_cid` = ? ORDER BY `id` DESC LIMIT 10', { cid }) or {}) do
        local place = Places.Get(tonumber(r.place_id))
        out.lab[#out.lab + 1] = { kind = r.kind, subject = r.subject, result = r.result, officer = r.officer, at = tonumber(r.created_at) or 0, station = place and place.name or '' }
    end
    local mug = MySQL.single.await('SELECT `officer`, `taken_at` FROM `xs_police_mugshots` WHERE `citizenid` = ?', { cid })
    if mug then out.mugshot = { officer = mug.officer, at = tonumber(mug.taken_at) or 0 } end
    return out
end)

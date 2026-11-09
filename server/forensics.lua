Forensics = { drops = {}, nextId = 0, shotAt = {}, bleedAt = {}, printAt = {}, serials = {}, cars = {}, touchAt = {}, cleanAt = {} }

local MAX_DROPS = 500

local function cfg()
    return Config.Forensics or {}
end

local function code(prefix, cid)
    local h = Util.Hash(prefix .. tostring(cid))
    return ('%04X-%04X'):format(math.floor(h / 65536) % 65536, h % 65536)
end

function Forensics.Print(src)
    local fp = Framework.GetMetaData(src, 'fingerprint')
    if type(fp) == 'string' and fp ~= '' then return fp end
    local cid = Framework.GetCitizenId(src)
    return cid and code('xsp-print-', cid) or nil
end

function Forensics.DnaOf(cid)
    return code('xsp-dna-', cid)
end

function Forensics.Dna(src)
    local cid = Framework.GetCitizenId(src)
    return cid and code('xsp-dna-', cid) or nil
end

function Forensics.BloodType(src)
    local blood = Framework.GetMetaData(src, 'bloodtype')
    return type(blood) == 'string' and blood ~= '' and blood or nil
end

local function view(d)
    return {
        id = d.id, kind = d.kind, x = d.x, y = d.y, z = d.z, count = d.count, calibre = d.calibre, group = d.group,
        age = os.time() - (d.first or d.at or os.time()), marked = d.print ~= nil and d.kind == 'casing', quality = d.quality,
    }
end

local function toCops(action, data)
    for _, cop in ipairs(Framework.Cops(true)) do
        TriggerClientEvent('XS-PoliceSystem:client:evidence', cop, action, data)
    end
end

local function point(src, at)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if type(at) == 'table' or type(at) == 'vector3' then
        local x, y, z = tonumber(at.x), tonumber(at.y), tonumber(at.z)
        if x and y and z and #(vector3(x, y, z) - c) <= 8.0 then return x, y, z end
    end
    return c.x, c.y, c.z - 0.95
end

local function nearby(kind, x, y, z, radius, seconds, match)
    local now = os.time()
    for _, d in pairs(Forensics.drops) do
        if d.kind == kind and now - d.at <= seconds and math.abs(d.z - z) < 2.5
            and (d.x - x) ^ 2 + (d.y - y) ^ 2 <= radius * radius and match(d) then
            return d
        end
    end
    return nil
end

local function trim()
    local count, oldest = 0, nil
    for _, d in pairs(Forensics.drops) do
        count = count + 1
        if not oldest or d.at < oldest.at then oldest = d end
    end
    if count >= MAX_DROPS and oldest then
        Forensics.drops[oldest.id] = nil
        toCops('remove', { oldest.id })
    end
end

local function add(d)
    trim()
    Forensics.nextId = Forensics.nextId + 1
    d.id = Forensics.nextId
    d.at = os.time()
    d.first = d.at
    d.count = d.count or 1
    Forensics.drops[d.id] = d
    toCops('add', view(d))
    return d
end

local function bump(d, n)
    d.count = math.min(99, d.count + (n or 1))
    d.at = os.time()
    toCops('add', view(d))
    return d
end

local function serialOf(src, weapon)
    local hash = Util.U32(weapon)
    local cached = Forensics.serials[src]
    if cached and cached.hash == hash and os.time() - cached.at < 30 then return cached.serial end
    local serial
    for _, item in ipairs(Inventory.Snapshot(src)) do
        local name = tostring(item.name or '')
        if name:sub(1, 7):lower() == 'weapon_' and Util.Hash(name) == hash then
            local meta = type(item.metadata) == 'table' and item.metadata or {}
            serial = meta.serie or meta.serial
            if serial then break end
        end
    end
    Forensics.serials[src] = { hash = hash, serial = serial and tostring(serial) or nil, at = os.time() }
    return Forensics.serials[src].serial
end

function Forensics.Casing(src, weapon, group, at, shots, bare)
    local c = cfg()
    if not c.enabled or not c.casings or not Evidence.Ours() then return nil end
    local calibre = (c.calibres or {})[tostring(group or '')]
    local cid = Framework.GetCitizenId(src)
    if not calibre or not cid then return nil end
    local now = GetGameTimer()
    if Forensics.shotAt[src] and now - Forensics.shotAt[src] < 250 then return nil end
    Forensics.shotAt[src] = now
    local x, y, z = point(src, at)
    if not x then return nil end
    shots = Util.Clamp(math.floor(tonumber(shots) or 1), 1, 30)
    local serial = serialOf(src, weapon)
    local print = bare == true and math.random(100) <= (c.printOnCasing or 35) and Forensics.Print(src) or nil
    local found = nearby('casing', x, y, z, 3.0, 180, function(d) return d.cid == cid and d.calibre == calibre and d.serial == serial end)
    if found then
        found.print = found.print or print
        return bump(found, shots)
    end
    return add({ kind = 'casing', x = x, y = y, z = z, cid = cid, calibre = calibre, group = tostring(group or ''), serial = serial, count = shots, print = print })
end

function Forensics.Blood(src, at)
    local c = cfg()
    if not c.enabled or not c.blood or not Evidence.Ours() then return nil end
    local cid = Framework.GetCitizenId(src)
    if not cid then return nil end
    local now = GetGameTimer()
    if Forensics.bleedAt[src] and now - Forensics.bleedAt[src] < 2500 then return nil end
    Forensics.bleedAt[src] = now
    local x, y, z = point(src, at)
    if not x then return nil end
    local found = nearby('blood', x, y, z, 1.8, 300, function(d) return d.cid == cid end)
    if found then return bump(found) end
    return add({ kind = 'blood', x = x, y = y, z = z, cid = cid, dna = Forensics.Dna(src), bloodtype = Forensics.BloodType(src) })
end

function Forensics.Fingerprint(src, at)
    if not cfg().enabled or not Evidence.Ours() then return nil end
    local cid = Framework.GetCitizenId(src)
    if not cid then return nil end
    local now = GetGameTimer()
    if Forensics.printAt[src] and now - Forensics.printAt[src] < 3000 then return nil end
    Forensics.printAt[src] = now
    local x, y, z = point(src, at)
    if not x then return nil end
    local found = nearby('print', x, y, z, 1.0, 600, function(d) return d.cid == cid end)
    if found then
        found.at = os.time()
        return found
    end
    return add({ kind = 'print', x = x, y = y, z = z, cid = cid, print = Forensics.Print(src), quality = math.random(45, 98) })
end

function Forensics.Clear(src, kind, radius)
    local c = Places.Coords(src)
    if not c then return 0 end
    local gone = {}
    for id, d in pairs(Forensics.drops) do
        if (not kind or d.kind == kind) and (d.x - c.x) ^ 2 + (d.y - c.y) ^ 2 <= radius * radius and math.abs(d.z - c.z) < 4.0 then
            Forensics.drops[id] = nil
            gone[#gone + 1] = id
        end
    end
    if #gone > 0 then toCops('remove', gone) end
    return #gone
end

local function what(d)
    if d.kind == 'casing' then
        return d.count > 1 and Text('evidence_casings', { count = d.count }) or Text('evidence_casing')
    end
    return Text(d.kind == 'blood' and 'evidence_blood' or 'evidence_print')
end

function Forensics.Metadata(d, street, officer)
    local when = os.date('%d/%m %H:%M')
    street = street ~= '' and street or Text('evidence_unknown')
    local info = { street = street, collected = when, officer = officer }
    if d.kind == 'casing' then
        info.type, info.label = 'casing', Text('evidence_label_casing')
        info.ammolabel, info.ammotype, info.count = d.calibre, d.calibre, d.count
        info.serie = d.serial or Text('evidence_no_serial')
        info.fingerprint = d.print
        info.description = Text('evidence_desc_casing', { count = d.count, calibre = d.calibre, serial = info.serie, street = street, time = when, officer = officer })
    elseif d.kind == 'blood' then
        info.type, info.label = 'blood', Text('evidence_label_blood')
        info.dnalabel, info.bloodtype = d.dna, d.bloodtype or Text('evidence_unknown')
        info.description = Text('evidence_desc_blood', { bloodtype = info.bloodtype, dna = d.dna, street = street, time = when, officer = officer })
    else
        info.type, info.label = 'fingerprint', Text('evidence_label_print')
        info.fingerprint = d.print
        info.quality = d.quality
        info.description = Text('evidence_desc_print', { print = d.print, street = street, time = when, officer = officer })
    end
    return info
end

function Forensics.Matches(src, print, dna)
    local out = {}
    local filled = cfg().filled or 'filled_evidence_bag'
    for _, item in ipairs(Inventory.Snapshot(src)) do
        local m = item.name == filled and type(item.metadata) == 'table' and item.metadata or nil
        local listed = false
        for _, p in ipairs(m and type(m.prints) == 'table' and m.prints or {}) do if p == print then listed = true end end
        if m and #out < 8 and ((print and (m.fingerprint == print or listed)) or (dna and m.dnalabel == dna)) then
            out[#out + 1] = { kind = m.type, label = m.label, street = m.street, collected = m.collected }
        end
    end
    return out
end

lib.callback.register('XS-PoliceSystem:server:forensics', function(src)
    if not cfg().enabled or not Evidence.Ours() or not Framework.IsCopSource(src) then return {} end
    local out = {}
    for _, d in pairs(Forensics.drops) do out[#out + 1] = view(d) end
    return out
end)

lib.callback.register('XS-PoliceSystem:server:forensicsCollect', function(src, id, street)
    local c = cfg()
    if not c.enabled then return false, Text('err_failed') end
    if not Framework.IsCopSource(src) then return false, Text('err_police_only') end
    if Field.IsCuffed(src) or Field.IsDown(src) then return false, Text('err_cannot_now') end
    local d = Forensics.drops[tonumber(id) or -1]
    if not d then return false, Text('err_evidence_gone') end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false, Text('err_failed') end
    local p = GetEntityCoords(ped)
    if (p.x - d.x) ^ 2 + (p.y - d.y) ^ 2 > 3.5 * 3.5 or math.abs(p.z - d.z) > 3.0 then return false, Text('err_too_far') end
    local bag = c.bag
    if bag == '' then bag = nil end
    if bag and not Inventory.Has(src, bag, 1) then return false, Text('err_need_item', { item = Inventory.Label(bag) }) end
    local filled = c.filled or 'filled_evidence_bag'
    if not Inventory.CanCarry(src, filled, 1) then return false, Text('err_cannot_carry') end
    Forensics.drops[d.id] = nil
    local officer = Framework.GetName(src) or ''
    local meta = Forensics.Metadata(d, Util.Text(street, 60), officer)
    if not Inventory.Add(src, filled, 1, meta) then
        Forensics.drops[d.id] = d
        return false, Text('err_cannot_carry')
    end
    if bag then Inventory.Remove(src, bag, 1) end
    toCops('remove', { d.id })
    Db.Log('evidence', { citizenid = d.cid or '', name = '' }, d.count, meta.label .. ' · ' .. meta.street,
        { citizenid = Framework.GetCitizenId(src), name = officer, job = (Framework.GetJob(src) or {}).name })
    return true, Text('evidence_bagged', { what = what(d) })
end)

RegisterNetEvent('XS-PoliceSystem:server:casing', function(weapon, group, at, shots, bare)
    Forensics.Casing(source, weapon, group, at, shots, bare)
end)

local function carPrints(plate)
    local keep = ((Config.Forensics or {}).carPrintHours or 6) * 3600
    local now, out = os.time(), {}
    for _, e in ipairs(Forensics.cars[plate] or {}) do
        if now - e.at <= keep then out[#out + 1] = e end
    end
    Forensics.cars[plate] = out
    return out
end

function Forensics.Touch(src, vehicle)
    if not cfg().enabled then return false end
    local cid = Framework.GetCitizenId(src)
    if not cid or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local me = Places.Coords(src)
    if not me or #(me - GetEntityCoords(vehicle)) > 6.0 then return false end
    local plate = Plates.Norm(GetVehicleNumberPlateText(vehicle))
    if plate == '' then return false end
    local key = src .. ':' .. plate
    local now = os.time()
    if Forensics.touchAt[key] and now - Forensics.touchAt[key] < 30 then return false end
    Forensics.touchAt[key] = now
    local list = carPrints(plate)
    for i, e in ipairs(list) do
        if e.cid == cid then table.remove(list, i) break end
    end
    table.insert(list, 1, { cid = cid, print = Forensics.Print(src), at = now })
    while #list > 6 do table.remove(list) end
    return true
end

RegisterNetEvent('XS-PoliceSystem:server:touched', function(netId)
    Forensics.Touch(source, NetworkGetEntityFromNetworkId(tonumber(netId) or 0))
end)

lib.callback.register('XS-PoliceSystem:server:dustPrints', function(src, netId)
    local c = cfg()
    if not c.enabled or not Evidence.Ours() then return false, Text('err_other_evidence') end
    if not Framework.IsCopSource(src) then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, 'dustPrints') then return false, Text('err_not_allowed') end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
    local me = Places.Coords(src)
    if not me or #(me - GetEntityCoords(vehicle)) > 5.0 then return false, Text('err_too_far') end
    local plate = Plates.Norm(GetVehicleNumberPlateText(vehicle))
    local list = carPrints(plate)
    if #list == 0 then return false, Text('dust_none') end
    local bag = c.bag ~= '' and c.bag or nil
    if bag and not Inventory.Has(src, bag, 1) then return false, Text('err_need_item', { item = Inventory.Label(bag) }) end
    local prints = {}
    for _, e in ipairs(list) do prints[#prints + 1] = e.print end
    local officer = Framework.GetName(src) or ''
    local when = os.date('%d/%m %H:%M')
    local meta = {
        type = 'fingerprint', label = Text('evidence_label_carprints', { plate = plate }), fingerprint = prints[1], prints = prints, count = #prints,
        street = plate, collected = when, officer = officer,
        description = Text('evidence_desc_carprints', { count = #prints, plate = plate, prints = table.concat(prints, ', '), time = when, officer = officer }),
    }
    if not Inventory.Add(src, c.filled or 'filled_evidence_bag', 1, meta) then return false, Text('err_cannot_carry') end
    if bag then Inventory.Remove(src, bag, 1) end
    Forensics.cars[plate] = nil
    return true, Text('dust_bagged', { count = #prints })
end)

lib.callback.register('XS-PoliceSystem:server:bleach', function(src)
    local item = (Config.Forensics or {}).bleach
    if not item or item == '' then return false, Text('err_failed') end
    local now = os.time()
    if Forensics.cleanAt[src] and now - Forensics.cleanAt[src] < 5 then return false, Text('err_slow_down') end
    if not Inventory.Has(src, item, 1) then return false, Text('err_need_item', { item = Inventory.Label(item) }) end
    Forensics.cleanAt[src] = now
    Inventory.Remove(src, item, 1)
    local n = Forensics.Clear(src, nil, (Config.Forensics or {}).bleachRadius or 5.0)
    return true, Text('bleach_done', { count = n })
end)

RegisterNetEvent('XS-PoliceSystem:server:bleed', function(at)
    Forensics.Blood(source, at)
end)

exports('AddEvidence', function(kind, src, coords)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    if not Evidence.Ours() then return Evidence.Forward((kind == 'print') and 'fingerprint' or kind, src, coords) end
    if kind == 'blood' then return Forensics.Blood(src, coords) ~= nil end
    if kind == 'fingerprint' or kind == 'print' then return Forensics.Fingerprint(src, coords) ~= nil end
    return false
end)

CreateThread(function()
    while true do
        Wait(30000)
        local limit = (cfg().minutes or 45) * 60
        local now, gone = os.time(), {}
        for id, d in pairs(Forensics.drops) do
            if now - d.at > limit then
                Forensics.drops[id] = nil
                gone[#gone + 1] = id
            end
        end
        if #gone > 0 then toCops('remove', gone) end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Forensics.shotAt[src], Forensics.bleedAt[src], Forensics.printAt[src], Forensics.serials[src], Forensics.cleanAt[src] = nil, nil, nil, nil, nil
end)

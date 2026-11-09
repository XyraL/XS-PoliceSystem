Lab = { busy = {}, started = {} }

local function at(src, placeId, pointId)
    local place = Places.Get(placeId)
    if not place or place.kind ~= 'station' then return nil end
    local p = Places.Point(place, 'lab', pointId)
    if not p or not Places.Near(src, p, 3.0) then return nil end
    return place
end

local function keyOf(m)
    return table.concat({ m.type or '', m.fingerprint or m.dnalabel or m.serie or '', m.collected or '', m.street or '' }, '|')
end

local function bags(src)
    local out = {}
    local filled = (Config.Forensics or {}).filled or 'filled_evidence_bag'
    for _, item in ipairs(Inventory.Snapshot(src)) do
        local m = item.name == filled and type(item.metadata) == 'table' and item.metadata or nil
        if m and m.type then
            out[#out + 1] = {
                key = keyOf(m), type = m.type, label = m.label or '', street = m.street or '', collected = m.collected or '',
                detail = m.fingerprint or m.dnalabel or m.serie or '', meta = m,
            }
        end
    end
    return out
end

local function nameOf(charinfo)
    return Framework.FullName(type(charinfo) == 'table' and charinfo or Db.Decode(charinfo, {}))
end

function Lab.ByDna(dna)
    for _, src in ipairs(Framework.Players()) do
        if Forensics.Dna(src) == dna then return Framework.GetName(src), Framework.GetCitizenId(src) end
    end
    for _, row in ipairs(MySQL.query.await('SELECT `citizenid`, `charinfo` FROM `players`') or {}) do
        if Forensics.DnaOf(row.citizenid) == dna then return nameOf(row.charinfo), row.citizenid end
    end
    return nil
end

function Lab.ByPrint(print)
    for _, src in ipairs(Framework.Players()) do
        if Forensics.Print(src) == print then return Framework.GetName(src), Framework.GetCitizenId(src) end
    end
    local ok, row = pcall(MySQL.single.await, "SELECT `citizenid`, `charinfo` FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(`metadata`, '$.fingerprint')) = ? LIMIT 1", { print })
    if ok and row then return nameOf(row.charinfo), row.citizenid end
    return nil
end

local function gunWithSerial(items, serial)
    for _, item in pairs(type(items) == 'table' and items or {}) do
        local name = type(item) == 'table' and tostring(item.name or ''):lower() or ''
        local m = type(item) == 'table' and (item.metadata or item.info) or nil
        if name:sub(1, 7) == 'weapon_' and type(m) == 'table' and tostring(m.serie or m.serial or '') == serial then return true end
    end
    return false
end

function Lab.BySerial(serial)
    for _, src in ipairs(Framework.Players()) do
        if gunWithSerial(Inventory.Snapshot(src), serial) then return Framework.GetName(src), Framework.GetCitizenId(src) end
    end
    local ok, rows = pcall(MySQL.query.await, 'SELECT `citizenid`, `charinfo`, `inventory` FROM `players` WHERE `inventory` LIKE ? LIMIT 25', { '%' .. serial .. '%' })
    for _, row in ipairs(ok and rows or {}) do
        if gunWithSerial(Db.Decode(row.inventory, {}), serial) then return nameOf(row.charinfo), row.citizenid end
    end
    return nil
end

function Lab.Analyse(m)
    local t = m.type
    if t == 'blood' or t == 'dna' then
        local name, cid
        if m.dnalabel then name, cid = Lab.ByDna(m.dnalabel) end
        return name and Text('lab_dna_match', { name = name }) or Text('lab_dna_none'), name, cid
    end
    if t == 'fingerprint' then
        local list = type(m.prints) == 'table' and m.prints or { m.fingerprint }
        local names, cids = {}, {}
        for _, print in ipairs(list) do
            local name, cid
            if print then name, cid = Lab.ByPrint(print) end
            if name then names[#names + 1], cids[#cids + 1] = name, cid end
        end
        if #names == 0 then return Text('lab_print_none'), nil end
        return Text('lab_print_match', { name = table.concat(names, ', ') }), names[1], cids[1]
    end
    if t == 'casing' then
        local serial = m.serie
        if not serial or serial == Text('evidence_no_serial') then return Text('lab_serial_unreadable'), nil end
        local name, cid = Lab.BySerial(serial)
        local out = name and Text('lab_serial_match', { serial = serial, name = name }) or Text('lab_serial_none', { serial = serial })
        if m.fingerprint then
            local printName, printCid = Lab.ByPrint(m.fingerprint)
            if printName then
                out = out .. ' ' .. Text('lab_casing_print', { name = printName })
                cid = cid or printCid
            end
        end
        return out, name, cid
    end
    return Text('lab_nothing'), nil
end

local function benchOf(kind)
    if kind == 'casing' then return 'microscope' end
    if kind == 'blood' or kind == 'dna' then return 'sequencer' end
    return 'overlay'
end

local function details(m, name)
    local lines, ref = {}, ''
    local function line(key, value)
        if value ~= nil and value ~= '' then lines[#lines + 1] = { label = Text(key), value = tostring(value) } end
    end
    local who = name or Text('lab_unknown')
    if m.type == 'casing' then
        local serial = m.serie ~= Text('evidence_no_serial') and m.serie or nil
        line('lab_line_calibre', m.ammolabel)
        line('lab_line_count', m.count)
        line('lab_line_serial', serial or Text('lab_unreadable'))
        line('lab_line_holder', serial and who or nil)
        line('lab_line_casing_print', m.fingerprint)
        ref = serial or ''
    elseif m.type == 'blood' or m.type == 'dna' then
        line('lab_line_bloodtype', m.bloodtype)
        line('lab_line_dna', m.dnalabel)
        line('lab_line_match', who)
        ref = m.dnalabel or ''
    elseif m.type == 'fingerprint' then
        line('lab_line_print', m.fingerprint)
        line('lab_line_prints', type(m.prints) == 'table' and #m.prints > 1 and #m.prints or nil)
        line('lab_line_quality', m.quality and (tostring(m.quality) .. '%') or nil)
        line('lab_line_match', who)
        ref = m.fingerprint or ''
    end
    line('lab_line_scene', m.street)
    line('lab_line_collected', table.concat({ m.collected or '', m.officer or '' }, ' · '):gsub('^ · ', ''):gsub(' · $', ''))
    return lines, Util.Text(ref, 64)
end

local function links(ref)
    if ref == '' then return {} end
    local out = {}
    local ok, rows = pcall(MySQL.query.await, 'SELECT `subject`, `created_at` FROM `xs_police_lab` WHERE `ref` = ? ORDER BY `id` DESC LIMIT 4', { ref })
    for _, r in ipairs(ok and type(rows) == 'table' and rows or {}) do out[#out + 1] = { subject = r.subject, at = tonumber(r.created_at) or 0 } end
    return out
end

local function reports(placeId)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT `id`, `kind`, `subject`, `result`, `officer`, `created_at` FROM `xs_police_lab` WHERE `place_id` = ? ORDER BY `id` DESC LIMIT 15', { placeId }) or {}) do
        out[#out + 1] = { id = r.id, kind = r.kind, subject = r.subject, result = r.result, officer = r.officer, at = tonumber(r.created_at) or 0 }
    end
    return out
end

lib.callback.register('XS-PoliceSystem:server:labOpen', function(src, placeId, pointId)
    local place = at(src, placeId, pointId)
    if not place then return false, Text('err_too_far') end
    if not Framework.IsCopSource(src) then return false, Text('err_police_only') end
    local list = {}
    for _, b in ipairs(bags(src)) do
        list[#list + 1] = { key = b.key, type = b.type, label = b.label, street = b.street, collected = b.collected, detail = b.detail }
    end
    return true, { station = place.name, bags = list, reports = reports(place.id), seconds = (Config.Lab or {}).seconds or 8 }
end)

lib.callback.register('XS-PoliceSystem:server:labStart', function(src, placeId, pointId, key)
    local place = at(src, placeId, pointId)
    if not place then return false, Text('err_too_far') end
    if not Framework.IsCopSource(src) then return false, Text('err_police_only') end
    local bag
    for _, b in ipairs(bags(src)) do
        if b.key == key then bag = b break end
    end
    if not bag then return false, Text('err_lab_no_bag') end
    Lab.started[src] = { key = key, at = os.time() }
    return true, { bench = benchOf(bag.type), seconds = (Config.Lab or {}).seconds or 8, code = bag.detail }
end)

lib.callback.register('XS-PoliceSystem:server:labAnalyse', function(src, placeId, pointId, key)
    local place = at(src, placeId, pointId)
    if not place then return false, Text('err_too_far') end
    if not Framework.IsCopSource(src) then return false, Text('err_police_only') end
    if Lab.busy[src] then return false, Text('err_slow_down') end
    local bag
    for _, b in ipairs(bags(src)) do
        if b.key == key then bag = b break end
    end
    if not bag then return false, Text('err_lab_no_bag') end
    Lab.busy[src] = true
    local seconds = (Config.Lab or {}).seconds or 8
    local started = Lab.started[src]
    Lab.started[src] = nil
    local waitFor = seconds
    if started and started.key == key then waitFor = math.max(0, started.at + seconds - os.time()) end
    if waitFor > 0 then Wait(waitFor * 1000) end
    Lab.busy[src] = nil
    if not at(src, placeId, pointId) then return false, Text('err_too_far') end
    local result, name, matchCid = Lab.Analyse(bag.meta)
    local officer = Units.Label(src)
    local subject = ('%s · %s'):format(bag.label, bag.street ~= '' and bag.street or bag.detail)
    local lines, ref = details(bag.meta, name)
    local earlier = links(ref)
    MySQL.insert.await('INSERT INTO `xs_police_lab` (`place_id`, `kind`, `subject`, `result`, `officer`, `match_cid`, `ref`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { place.id, bag.type, Util.Text(subject, 160), Util.Text(result, 255), officer, matchCid or '', ref, os.time() })
    return true, { result = result, report = { kind = bag.type, label = bag.label, match = name ~= nil, lines = lines, links = earlier }, reports = reports(place.id) }
end)

AddEventHandler('playerDropped', function()
    Lab.busy[source], Lab.started[source] = nil, nil
end)

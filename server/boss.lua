local function at(src, placeId, pointId)
    local place = Places.Get(placeId)
    if not place or place.kind ~= 'station' then return nil end
    local p = Places.Point(place, 'boss', pointId)
    if not p or not Places.Near(src, p, 3.0) then return nil end
    return place
end

local function manager(src, placeId, pointId)
    local place = at(src, placeId, pointId)
    if not place then return nil, Text('err_too_far') end
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job, true) or not Places.ServesJob(place, job) then return nil, Text('err_police_only') end
    if not job.isBoss and (job.grade or 0) < ((Config.Grades or {}).manage or 4) then return nil, Text('err_grade') end
    return job, place
end

local function officerOf(src, job)
    return { citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', job = job.name }
end

local function nameOf(cid)
    local online = Framework.GetPlayerByCitizenId(cid)
    if online then return Framework.FullName(online.PlayerData.charinfo) end
    local row = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { cid })
    return row and Framework.FullName(Db.Decode(row.charinfo, {})) or cid
end

local function gradeLabel(jobName, grade)
    for _, g in ipairs(Framework.Grades(jobName)) do
        if g.level == grade then return g.label end
    end
    return tostring(grade)
end

local function callsignOf(cid, metadata)
    local online = Framework.GetPlayerByCitizenId(cid)
    local meta = online and online.PlayerData.metadata or Db.Decode(metadata, {})
    local value = type(meta) == 'table' and meta.callsign or nil
    if type(value) ~= 'string' or value == '' or value == 'NO CALLSIGN' then return '' end
    return value
end

local function employees(jobName)
    local out = {}
    local ok = pcall(function()
        if Framework.name ~= 'qbox' then error('players table') end
        local rows = MySQL.query.await("SELECT pg.`citizenid`, pg.`grade`, p.`charinfo`, p.`metadata` FROM `player_groups` pg LEFT JOIN `players` p ON p.`citizenid` = pg.`citizenid` WHERE pg.`group` = ? AND pg.`type` = 'job'", { jobName }) or {}
        for _, r in ipairs(rows) do
            out[#out + 1] = { cid = r.citizenid, grade = tonumber(r.grade) or 0, name = Framework.FullName(Db.Decode(r.charinfo, {})), callsign = callsignOf(r.citizenid, r.metadata) }
        end
    end)
    if not ok then
        local rows = MySQL.query.await("SELECT `citizenid`, `charinfo`, `job`, `metadata` FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(`job`, '$.name')) = ?", { jobName }) or {}
        for _, r in ipairs(rows) do
            local j = Db.Decode(r.job, {})
            local grade = type(j.grade) == 'table' and (tonumber(j.grade.level) or 0) or (tonumber(j.grade) or 0)
            out[#out + 1] = { cid = r.citizenid, grade = grade, name = Framework.FullName(Db.Decode(r.charinfo, {})), callsign = callsignOf(r.citizenid, r.metadata) }
        end
    end
    return out
end

local function member(jobName, cid)
    local online = Framework.GetPlayerByCitizenId(cid)
    if online then
        local j = Framework.JobOf(online.PlayerData)
        if j and j.name == jobName then return { grade = j.grade, src = online.PlayerData.source, active = true } end
    end
    for _, e in ipairs(employees(jobName)) do
        if e.cid == cid then return { grade = e.grade, src = online and online.PlayerData.source or nil, active = false } end
    end
    return nil
end

local function maxGrant(job)
    return job.isBoss and 50 or math.max(0, (job.grade or 0) - 1)
end

local function setOffline(cid, jobName, grade)
    if Framework.name == 'qbox' then
        local ok = pcall(function()
            if grade then exports.qbx_core:AddPlayerToJob(cid, jobName, grade) else exports.qbx_core:RemovePlayerFromJob(cid, jobName) end
        end)
        if ok then return true end
    end
    local row = MySQL.single.await('SELECT `job` FROM `players` WHERE `citizenid` = ?', { cid })
    if not row then return false end
    local current = Db.Decode(row.job, {})
    if current.name ~= jobName then return false end
    if grade then
        local label = ''
        for _, g in ipairs(Framework.Grades(jobName)) do if g.level == grade then label = g.label end end
        current.grade = { level = grade, name = label }
    else
        current = { name = 'unemployed', label = 'Civilian', payment = 10, onduty = false, isboss = false, grade = { name = 'Freelancer', level = 0 } }
    end
    MySQL.update.await('UPDATE `players` SET `job` = ? WHERE `citizenid` = ?', { json.encode(current), cid })
    return true
end

lib.callback.register('XS-PoliceSystem:server:boss', function(src, placeId, pointId)
    local job, place = manager(src, placeId, pointId)
    if not job then return false, place end
    local onlineCids, online = {}, {}
    for _, other in ipairs(Framework.Players()) do
        local j = Framework.GetJob(other)
        if j and j.name == job.name then
            local cid = Framework.GetCitizenId(other)
            onlineCids[cid or ''] = true
            online[#online + 1] = { src = other, cid = cid, name = Framework.GetName(other) or '', grade = j.grade, onDuty = j.onDuty }
        end
    end
    local staff, cids = {}, {}
    for _, e in ipairs(employees(job.name)) do
        e.online = onlineCids[e.cid] == true
        staff[#staff + 1] = e
        cids[#cids + 1] = e.cid
    end
    local hours = DutyClock.Hours(cids)
    for _, e in ipairs(staff) do
        local h = hours[e.cid]
        e.week, e.total = h and h.week or 0, h and h.total or 0
    end
    table.sort(staff, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    local grades, label = Framework.Grades(job.name)
    local nearby = {}
    local me = Places.Coords(src)
    for _, other in ipairs(Framework.Players()) do
        if other ~= src and me then
            local ped = GetPlayerPed(other)
            if ped ~= 0 and #(GetEntityCoords(ped) - me) < 5.0 then
                local j = Framework.GetJob(other)
                if not j or j.name ~= job.name then
                    nearby[#nearby + 1] = { src = other, name = Framework.GetName(other) or ('#' .. other) }
                end
            end
        end
    end
    local onDutyCids = {}
    for _, o in ipairs(online) do if o.onDuty then onDutyCids[o.cid or ''] = true end end
    local records = Office.Records(job.name)
    for _, e in ipairs(staff) do
        e.onDuty = onDutyCids[e.cid] == true
        e.record = records[e.cid] or { note = 0, warning = 0, commend = 0 }
    end
    return true, {
        department = label, job = job.name, myGrade = job.isBoss and 99 or maxGrant(job), isBoss = job.isBoss,
        staff = staff, onDuty = #online, grades = grades, nearby = nearby,
        balance = Banking.name and Banking.Balance(Stations.Society(job)) or nil,
        me = { cid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', grade = job.grade or 0, rank = gradeLabel(job.name, job.grade or 0) },
        station = { id = place.id, name = place.name, armory = place.armory or {}, vehicles = place.vehicles or {}, helicopters = place.helicopters or {} },
        pools = Office.Pools(place), week = Office.Week(job.name), recent = Office.Log(job.name, { limit = 12 }),
        banking = Banking.name ~= nil, maxPrice = (Config.Boss or {}).maxPrice or 100000,
    }
end)

lib.callback.register('XS-PoliceSystem:server:bossHire', function(src, placeId, pointId, target, grade)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    target = tonumber(target)
    if not target or not GetPlayerName(target) or target == src then return false, Text('err_no_player') end
    local me, them = Places.Coords(src), Places.Coords(target)
    if not me or not them or #(me - them) > 5.0 then return false, Text('err_too_far') end
    grade = Util.Clamp(math.floor(tonumber(grade) or 0), 0, maxGrant(job))
    if Framework.name == 'qbox' then
        pcall(function() exports.qbx_core:AddPlayerToJob(Framework.GetCitizenId(target), job.name, grade) end)
    end
    Framework.SetJob(target, job.name, grade)
    Framework.Notify(target, Text('hired', { job = job.label }), 'success')
    Db.Log('hire', { citizenid = Framework.GetCitizenId(target), name = Framework.GetName(target) or '' }, grade, gradeLabel(job.name, grade), officerOf(src, job))
    return true
end)

lib.callback.register('XS-PoliceSystem:server:bossGrade', function(src, placeId, pointId, cid, grade)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    cid = Util.Text(cid, 64)
    if cid == Framework.GetCitizenId(src) then return false, Text('err_not_self') end
    local who = member(job.name, cid)
    if not who then return false, Text('err_not_staff') end
    if not job.isBoss and who.grade >= (job.grade or 0) then return false, Text('err_grade') end
    grade = Util.Clamp(math.floor(tonumber(grade) or 0), 0, maxGrant(job))
    if grade == who.grade then return true end
    local ok = true
    if who.src then
        if Framework.name == 'qbox' then pcall(function() exports.qbx_core:AddPlayerToJob(cid, job.name, grade) end) end
        if who.active then Framework.SetJob(who.src, job.name, grade) end
        Framework.Notify(who.src, Text(grade > who.grade and 'promoted_you' or 'demoted_you', { rank = gradeLabel(job.name, grade) }), grade > who.grade and 'success' or 'inform')
    else
        ok = setOffline(cid, job.name, grade)
    end
    if ok then Db.Log(grade > who.grade and 'promote' or 'demote', { citizenid = cid, name = nameOf(cid) }, grade, gradeLabel(job.name, grade), officerOf(src, job)) end
    return ok
end)

lib.callback.register('XS-PoliceSystem:server:bossFire', function(src, placeId, pointId, cid)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    cid = Util.Text(cid, 64)
    if cid == Framework.GetCitizenId(src) then return false, Text('err_not_self') end
    local who = member(job.name, cid)
    if not who then return false, Text('err_not_staff') end
    if not job.isBoss and who.grade >= (job.grade or 0) then return false, Text('err_grade') end
    local name = nameOf(cid)
    local ok = true
    if who.src then
        if Framework.name == 'qbox' then pcall(function() exports.qbx_core:RemovePlayerFromJob(cid, job.name) end) end
        if who.active then Framework.SetJob(who.src, 'unemployed', 0) end
        Framework.Notify(who.src, Text('fired', { job = job.label }), 'error')
    else
        ok = setOffline(cid, job.name, nil)
    end
    if ok then Db.Log('fire', { citizenid = cid, name = name }, 0, gradeLabel(job.name, who.grade), officerOf(src, job)) end
    return ok
end)

lib.callback.register('XS-PoliceSystem:server:bossCallsign', function(src, placeId, pointId, cid, value)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    cid = Util.Text(cid, 64)
    local who = member(job.name, cid)
    if not who then return false, Text('err_not_staff') end
    local callsign = Units.CleanCallsign(value)
    if not callsign then return false, Text('err_callsign', { max = (Config.Callsign or {}).max or 10 }) end
    local online = Framework.GetPlayerByCitizenId(cid)
    if online then
        Framework.SetMetaData(online.PlayerData.source, 'callsign', callsign)
        Framework.Notify(online.PlayerData.source, Text('callsign_set', { callsign = callsign }), 'inform')
    else
        MySQL.update.await("UPDATE `players` SET `metadata` = JSON_SET(COALESCE(`metadata`, '{}'), '$.callsign', ?) WHERE `citizenid` = ?", { callsign, cid })
    end
    Db.Log('callsign', { citizenid = cid, name = nameOf(cid) }, 0, callsign, officerOf(src, job))
    return true, callsign
end)

lib.callback.register('XS-PoliceSystem:server:bossMoney', function(src, placeId, pointId, direction, amount)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    if not Banking.name then return false, Text('err_no_banking') end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, Text('err_amount') end
    local society = Stations.Society(job)
    if direction == 'deposit' then
        if not Framework.Charge(src, amount, 'cash', 'Police account deposit') then return false, Text('err_no_money') end
        if not Banking.Deposit(society, amount, 'Deposit by ' .. (Framework.GetName(src) or src)) then
            Framework.AddMoney(src, 'cash', amount, 'Police account deposit refund')
            return false, Text('err_failed')
        end
    else
        if not Banking.Withdraw(society, amount, 'Withdrawal by ' .. (Framework.GetName(src) or src)) then return false, Text('err_no_money') end
        Framework.AddMoney(src, 'cash', amount, 'Police account withdrawal')
    end
    Db.Log(direction == 'deposit' and 'deposit' or 'withdraw', nil, amount, '', officerOf(src, job))
    return true, Banking.Balance(society)
end)

Office = {}

local NOTE_KINDS = { note = true, warning = true, commend = true }
local GROUPS = {
    money = { 'fine', 'seize', 'impound_release', 'speeding', 'deposit', 'withdraw' },
    arrests = { 'jail', 'service', 'solitary', 'fine' },
    impounds = { 'impound', 'impound_release', 'impound_clear', 'impound_waive' },
    evidence = { 'evidence', 'prints', 'vsearch', 'k9', 'flag' },
    staff = { 'hire', 'fire', 'promote', 'demote', 'callsign', 'note', 'warning', 'commend', 'unitcam' },
    gear = { 'armory', 'armory_edit', 'fleet_edit' },
}

local function slug(value, max)
    return (tostring(value or ''):lower():gsub('[^%w_%-]', '')):sub(1, max or 64)
end

function Office.Records(jobName)
    local out = {}
    local ok, rows = pcall(MySQL.query.await, 'SELECT `citizenid`, `kind`, COUNT(*) AS `n` FROM `xs_police_staff_notes` WHERE `job` = ? GROUP BY `citizenid`, `kind`', { jobName })
    for _, r in ipairs(ok and type(rows) == 'table' and rows or {}) do
        out[r.citizenid] = out[r.citizenid] or { note = 0, warning = 0, commend = 0 }
        out[r.citizenid][r.kind] = tonumber(r.n) or 0
    end
    return out
end

function Office.Week(jobName)
    local out = {}
    local ok, rows = pcall(MySQL.query.await, 'SELECT `kind`, COUNT(*) AS `n`, COALESCE(SUM(`amount`), 0) AS `total` FROM `xs_police_log` WHERE `job` = ? AND `created_at` >= NOW() - INTERVAL 7 DAY GROUP BY `kind`', { jobName })
    for _, r in ipairs(ok and type(rows) == 'table' and rows or {}) do
        out[r.kind] = { n = tonumber(r.n) or 0, total = tonumber(r.total) or 0 }
    end
    return out
end

function Office.Log(jobName, filter)
    filter = type(filter) == 'table' and filter or {}
    local where, args = { '`job` = ?' }, { jobName }
    local kind = slug(filter.kind, 20)
    if GROUPS[kind] then
        local marks = {}
        for _, k in ipairs(GROUPS[kind]) do
            marks[#marks + 1] = '?'
            args[#args + 1] = k
        end
        where[#where + 1] = '`kind` IN (' .. table.concat(marks, ', ') .. ')'
    elseif kind ~= '' and kind ~= 'all' then
        where[#where + 1] = '`kind` = ?'
        args[#args + 1] = kind
    end
    local search = Util.Text(filter.search, 40):gsub('[%%_]', '')
    if search ~= '' then
        where[#where + 1] = '(`name` LIKE ? OR `officer_name` LIKE ? OR `detail` LIKE ?)'
        local like = '%' .. search .. '%'
        args[#args + 1], args[#args + 2], args[#args + 3] = like, like, like
    end
    local limit = Util.Clamp(math.floor(tonumber(filter.limit) or 50), 1, 100)
    local offset = Util.Clamp(math.floor(tonumber(filter.offset) or 0), 0, 1000000)
    local sql = ('SELECT `id`, `kind`, `name`, `amount`, `detail`, `officer_name`, UNIX_TIMESTAMP(`created_at`) AS `at` FROM `xs_police_log` WHERE %s ORDER BY `id` DESC LIMIT %d OFFSET %d'):format(table.concat(where, ' AND '), limit, offset)
    local ok, rows = pcall(MySQL.query.await, sql, args)
    local out = {}
    for _, r in ipairs(ok and type(rows) == 'table' and rows or {}) do
        out[#out + 1] = { id = r.id, kind = r.kind, name = r.name or '', amount = tonumber(r.amount) or 0, detail = r.detail or '', officer = r.officer_name or '', at = tonumber(r.at) or 0 }
    end
    return out
end

function Office.Pools(place)
    local B = Config.Boss or {}
    local items, wanted = {}, {}
    for _, name in ipairs(B.armoryPool or {}) do wanted[name] = true end
    for _, e in ipairs(place.armory or {}) do wanted[e.item] = true end
    for _, it in ipairs(Inventory.Items()) do
        if wanted[it.name] then items[#items + 1] = it end
    end
    local labels = {}
    for _, v in ipairs(Framework.Vehicles() or {}) do labels[v.model] = v.label end
    local vehicles, seen = {}, {}
    local function add(model, heli)
        if type(model) == 'string' and model ~= '' and not seen[model] then
            seen[model] = true
            vehicles[#vehicles + 1] = { model = model, label = labels[model] or model, heli = heli }
        end
    end
    for _, model in ipairs(B.vehiclePool or {}) do add(model, false) end
    for _, v in ipairs(place.vehicles or {}) do add(v.model, false) end
    for _, model in ipairs(B.helicopterPool or {}) do add(model, true) end
    for _, v in ipairs(place.helicopters or {}) do add(v.model, true) end
    return { items = items, vehicles = vehicles }
end

local function allowedSet(list, key, current)
    local set = {}
    for _, v in ipairs(list or {}) do set[v] = true end
    for _, e in ipairs(current or {}) do set[e[key]] = true end
    return set
end

lib.callback.register('XS-PoliceSystem:server:bossNotes', function(src, placeId, pointId, cid)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    cid = Util.Text(cid, 64)
    if not member(job.name, cid) then return false, Text('err_not_staff') end
    local rows = MySQL.query.await('SELECT `id`, `kind`, `text`, `author`, `created_at` FROM `xs_police_staff_notes` WHERE `job` = ? AND `citizenid` = ? ORDER BY `id` DESC LIMIT 50', { job.name, cid }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { id = r.id, kind = r.kind, text = r.text, author = r.author, at = tonumber(r.created_at) or 0 } end
    return true, out
end)

lib.callback.register('XS-PoliceSystem:server:bossNote', function(src, placeId, pointId, cid, kind, text)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    if (Config.Boss or {}).notes == false then return false, Text('err_failed') end
    cid = Util.Text(cid, 64)
    if cid == Framework.GetCitizenId(src) then return false, Text('err_not_self') end
    if not member(job.name, cid) then return false, Text('err_not_staff') end
    kind = NOTE_KINDS[kind] and kind or 'note'
    text = Util.Text(text, 255)
    if text == '' then return false, Text('err_need_reason') end
    MySQL.insert.await('INSERT INTO `xs_police_staff_notes` (`job`, `citizenid`, `kind`, `text`, `author`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)', { job.name, cid, kind, text, Framework.GetName(src) or '', os.time() })
    if kind ~= 'note' then
        local online = Framework.GetPlayerByCitizenId(cid)
        if online then Framework.Notify(online.PlayerData.source, Text(kind == 'warning' and 'staff_warned_you' or 'staff_commended_you', { text = text }), kind == 'warning' and 'error' or 'success') end
    end
    Db.Log(kind, { citizenid = cid, name = nameOf(cid) }, 0, text, officerOf(src, job))
    return true
end)

lib.callback.register('XS-PoliceSystem:server:bossNoteDelete', function(src, placeId, pointId, id)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    if not job.isBoss then return false, Text('err_boss_only') end
    MySQL.query.await('DELETE FROM `xs_police_staff_notes` WHERE `id` = ? AND `job` = ?', { tonumber(id) or 0, job.name })
    return true
end)

lib.callback.register('XS-PoliceSystem:server:bossArmory', function(src, placeId, pointId, list)
    local job, place = manager(src, placeId, pointId)
    if not job then return false, place end
    local B = Config.Boss or {}
    local allowed = allowedSet(B.armoryPool, 'item', place.armory)
    local maxPrice = tonumber(B.maxPrice) or 100000
    local clean = {}
    for _, e in ipairs(type(list) == 'table' and list or {}) do
        local item = type(e) == 'table' and slug(e.item) or ''
        if allowed[item] then
            clean[#clean + 1] = {
                item = item, grade = Util.Clamp(math.floor(tonumber(e.grade) or 0), 0, 50),
                price = Util.Clamp(math.floor(tonumber(e.price) or 0), 0, maxPrice), amount = Util.Clamp(math.floor(tonumber(e.amount) or 1), 1, 250),
            }
        end
    end
    local raw = Util.Copy(place)
    raw.armory = clean
    local saved = Places.Save(Places.Sanitize(raw))
    if not saved then return false, Text('err_db') end
    Db.Log('armory_edit', nil, #saved.armory, place.name, officerOf(src, job))
    return true, saved.armory
end)

lib.callback.register('XS-PoliceSystem:server:bossFleet', function(src, placeId, pointId, vehicles, helicopters)
    local job, place = manager(src, placeId, pointId)
    if not job then return false, place end
    local B = Config.Boss or {}
    local cars = allowedSet(B.vehiclePool, 'model', place.vehicles)
    local helis = allowedSet(B.helicopterPool, 'model', place.helicopters)
    local function keep(list, allowed)
        local out = {}
        for _, v in ipairs(type(list) == 'table' and list or {}) do
            if type(v) == 'table' and allowed[slug(v.model, 48)] then out[#out + 1] = v end
        end
        return out
    end
    local raw = Util.Copy(place)
    raw.vehicles = keep(vehicles, cars)
    raw.helicopters = keep(helicopters, helis)
    local saved = Places.Save(Places.Sanitize(raw))
    if not saved then return false, Text('err_db') end
    Db.Log('fleet_edit', nil, #saved.vehicles + #saved.helicopters, place.name, officerOf(src, job))
    return true, { vehicles = saved.vehicles, helicopters = saved.helicopters }
end)

lib.callback.register('XS-PoliceSystem:server:bossLog', function(src, placeId, pointId, filter)
    local job, err = manager(src, placeId, pointId)
    if not job then return false, err end
    return true, { rows = Office.Log(job.name, filter), week = Office.Week(job.name) }
end)

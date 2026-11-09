Jail = { inmates = {}, canteenAt = {}, jobStart = {}, spotAt = {}, workoutStart = {}, locks = {} }

local FALLBACK_RELEASE = { x = 1740.88, y = 2476.57, z = 44.85, w = 299.49 }
local ESCAPE_CHECKS = 3
local ARRIVE_GRACE = 20
local ARRIVE_MAX = 120

local function secondsPerMonth()
    return math.max(1, math.floor((tonumber(Config.Jail.minutesPerMonth) or 1) * 60))
end

local function monthsLeft(seconds)
    return math.max(0, math.ceil((tonumber(seconds) or 0) / secondsPerMonth()))
end

local function center(place)
    if place.center then return place.center end
    return (place.points.cell or {})[1]
end

Jail.Center = center

local function pickJail(near)
    local best, bestDist
    for _, place in ipairs(Places.List('jail')) do
        if #(place.points.cell or {}) > 0 then
            local c = center(place)
            local d = near and c and #(near - vector3(c.x, c.y, c.z)) or 0
            if not best or d < bestDist then best, bestDist = place, d end
        end
    end
    return best
end

local function pickCell(place)
    local cells = place and place.points.cell or {}
    if #cells == 0 then return nil end
    return cells[math.random(1, #cells)]
end

Jail.PickCell = pickCell

local function reach(place)
    return Points.Reach(place, center(place), place.radius or Config.Jail.escapeRadius or 150.0)
end

Jail.Reach = reach

local function inside(src, place)
    local c = place and center(place)
    local at = Places.Coords(src)
    if not c or not at then return true end
    return #(at - vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)) <= reach(place)
end

local function lock(cid)
    if not cid or Jail.locks[cid] then return false end
    Jail.locks[cid] = true
    return true
end

local function unlock(cid)
    if cid then Jail.locks[cid] = nil end
end

local function keepSet()
    local set = {}
    for _, name in ipairs(Config.Jail.keepItems or {}) do set[name] = true end
    return set
end

local function write(inmate)
    return MySQL.query.await([[
        INSERT INTO `xs_police_inmates` (`citizenid`, `name`, `jail_id`, `months`, `seconds_left`, `reason`, `officer_name`, `items`, `look`, `escaped`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `jail_id` = VALUES(`jail_id`), `months` = VALUES(`months`),
            `seconds_left` = VALUES(`seconds_left`), `reason` = VALUES(`reason`), `officer_name` = VALUES(`officer_name`),
            `items` = VALUES(`items`), `look` = VALUES(`look`), `escaped` = VALUES(`escaped`)
    ]], {
        inmate.cid, inmate.name, inmate.jailId, inmate.months, math.max(0, math.floor(inmate.left)), inmate.reason, inmate.officer,
        Db.Json(inmate.items or {}), inmate.look and Db.Json(inmate.look) or nil, inmate.escaped and 1 or 0,
    })
end

local function persist(src, wait)
    local inmate = Jail.inmates[src]
    if not inmate then return end
    local args = { math.max(0, math.floor(inmate.left)), inmate.escaped and 1 or 0, inmate.cid }
    local sql = 'UPDATE `xs_police_inmates` SET `seconds_left` = ?, `escaped` = ? WHERE `citizenid` = ?'
    if wait then MySQL.update.await(sql, args) else MySQL.update(sql, args) end
    Framework.SetMetaData(src, 'injail', inmate.escaped and 0 or monthsLeft(inmate.left))
end

local function publicState(inmate)
    local place = Places.Get(inmate.jailId)
    return {
        jailId = inmate.jailId, name = place and place.name or '', left = math.max(0, math.floor(inmate.left)), months = inmate.months,
        reason = inmate.reason, escaped = inmate.escaped == true, number = inmate.number, look = inmate.look ~= nil,
        credit = math.floor(tonumber(inmate.credit) or 0),
    }
end

function Jail.Count(jailId)
    local n = 0
    for _, inmate in pairs(Jail.inmates) do
        if inmate.jailId == jailId then n = n + 1 end
    end
    local row = MySQL.scalar.await('SELECT COUNT(*) FROM `xs_police_inmates` WHERE `jail_id` = ? AND `seconds_left` > 0', { jailId })
    return math.max(n, tonumber(row) or 0)
end

function Jail.IsInmate(src)
    local inmate = Jail.inmates[tonumber(src) or -1]
    return inmate ~= nil and not inmate.escaped
end

function Jail.Place(src)
    local inmate = Jail.inmates[src]
    if not inmate or inmate.escaped then return end
    local place = Places.Get(inmate.jailId) or pickJail(nil)
    if not place then return end
    inmate.jailId = place.id
    inmate.arriving = { since = os.time(), readyAt = nil }
    inmate.outside = 0
    TriggerClientEvent('XS-PoliceSystem:client:jailed', src, publicState(inmate), pickCell(place))
end

local function offDuty(src)
    local job = Framework.GetJob(src)
    if job and Util.IsCopJob(job) and job.onDuty then
        Framework.SetDuty(src, false)
        Duty.Changed(src, false)
    end
end

function Jail.Send(target, months, reason, officer)
    if not Config.Jail.enabled then return false, Text('err_jail_off') end
    months = math.floor(tonumber(months) or 0)
    if months < 1 or months > (Config.Jail.maxMonths or 300) then return false, Text('err_months', { max = Config.Jail.maxMonths or 300 }) end
    local cid = Framework.GetCitizenId(target)
    if not cid then return false, Text('err_no_player') end
    if Jail.IsInmate(target) then return false, Text('err_already_jailed') end
    local place = pickJail(officer and officer.src and Places.Coords(officer.src))
    if not place then return false, Text('err_no_jail') end
    if not lock(cid) then return false, Text('err_slow_down') end
    reason = Util.Text(reason, 200)
    if reason == '' then reason = Text('no_reason') end

    local ok, result = pcall(function()
        local old = MySQL.single.await('SELECT `items`, `look` FROM `xs_police_inmates` WHERE `citizenid` = ?', { cid })
        local items = old and Db.Decode(old.items, {}) or {}
        local keep, keepList = keepSet(), {}
        for name in pairs(keep) do keepList[#keepList + 1] = name end
        if Config.Jail.confiscate then
            for _, entry in ipairs(Inventory.Snapshot(target)) do
                if not keep[entry.name] then items[#items + 1] = entry end
            end
        end
        local inmate = {
            src = target, cid = cid, name = Framework.GetName(target) or '', jailId = place.id, months = months,
            left = months * secondsPerMonth(), reason = reason, officer = officer and officer.name or '',
            items = items, look = old and Db.Decode(old.look, nil) or nil, escaped = false, outside = 0,
            number = ('%04d'):format(math.random(1000, 9999)), credit = 0, breakout = {},
        }
        write(inmate)
        Inmate.Save(inmate)
        if Config.Jail.confiscate then Inventory.Clear(target, keepList) end
        return inmate
    end)
    if not ok then
        unlock(cid)
        print(('^1[XS-PoliceSystem]^0 could not jail %s: %s'):format(cid, tostring(result)))
        return false, Text('err_db')
    end

    local inmate = result
    if Field.escorts[target] then Field.StopEscort(target) end
    if Field.IsCuffed(target) then Field.SetCuffed(target, false) end
    offDuty(target)
    Jail.inmates[target] = inmate
    Framework.SetMetaData(target, 'injail', months)
    Framework.SetMetaData(target, 'criminalrecord', { hasRecord = true, date = os.date('*t') })
    unlock(cid)
    Jail.Place(target)
    Framework.Notify(target, Text('you_are_jailed', { months = months }), 'error')
    Db.Log('jail', { citizenid = cid, name = inmate.name }, months, reason, officer)
    TriggerEvent('XS-PoliceSystem:server:jailed', target, months, reason, officer and officer.src)
    print(('^3[XS-PoliceSystem]^0 %s jailed %s for %d month(s): %s'):format(officer and officer.name or 'Server', inmate.name, months, reason))
    return true, Text('jailed', { name = inmate.name, months = months })
end

local function giveBack(src, items)
    local left = {}
    for _, entry in ipairs(items or {}) do
        if not (Inventory.CanCarry(src, entry.name, entry.count) and Inventory.Add(src, entry.name, entry.count, entry.metadata)) then
            left[#left + 1] = entry
        end
    end
    return left
end

local function prisonItems()
    local J, set = Config.Jail, {}
    local function add(name) if type(name) == 'string' and name ~= '' then set[name] = true end end
    local C, B, T = J.contraband or {}, J.breakout or {}, J.trader or {}
    for _, name in ipairs(C.items or {}) do add(name) end
    for _, f in ipairs(C.finds or {}) do add(type(f) == 'table' and f.item) end
    for _, r in ipairs(J.recipes or {}) do
        add(type(r) == 'table' and r.item)
        for name in pairs(type(r) == 'table' and r.needs or {}) do add(name) end
    end
    for _, e in ipairs(T.sells or {}) do add(type(e) == 'table' and e.item) end
    add(J.currency)
    add(B.tunnelItem)
    add(B.fenceItem)
    return set
end

local function strip(src)
    if Config.Jail.releaseClear == false then return end
    local keep = keepSet()
    if Config.Jail.confiscate then
        local list = {}
        for name in pairs(keep) do list[#list + 1] = name end
        Inventory.Clear(src, list)
        return
    end
    for name in pairs(prisonItems()) do
        local n = Inventory.Count(src, name)
        if n > 0 then Inventory.Remove(src, name, n) end
    end
end

function Jail.Release(src, reason)
    local inmate = Jail.inmates[src]
    if not inmate or not lock(inmate.cid) then return false end
    Jail.inmates[src] = nil
    pcall(strip, src)
    Inmate.OnRelease(src, inmate)
    local ok, left = pcall(function()
        local remaining = Config.Jail.confiscate and giveBack(src, inmate.items) or {}
        if #remaining > 0 then
            MySQL.update.await('UPDATE `xs_police_inmates` SET `seconds_left` = 0, `months` = 0, `items` = ?, `escaped` = 0, `look` = NULL WHERE `citizenid` = ?', { Db.Json(remaining), inmate.cid })
        else
            MySQL.query.await('DELETE FROM `xs_police_inmates` WHERE `citizenid` = ?', { inmate.cid })
        end
        return remaining
    end)
    unlock(inmate.cid)
    if not ok then
        print(('^1[XS-PoliceSystem]^0 release of %s failed: %s'):format(inmate.cid, tostring(left)))
        left = {}
    end
    Framework.SetMetaData(src, 'injail', 0)
    local place = Places.Get(inmate.jailId)
    local spot = place and (place.points.release or {})[1] or FALLBACK_RELEASE
    TriggerClientEvent('XS-PoliceSystem:client:released', src, spot, inmate.look, #left > 0, reason)
    TriggerEvent('XS-PoliceSystem:server:released', src, reason)
    return true
end

function Jail.Load(src)
    if Jail.inmates[src] then return Jail.inmates[src] end
    local cid = Framework.GetCitizenId(src)
    if not cid then return nil end
    local row = MySQL.single.await('SELECT * FROM `xs_police_inmates` WHERE `citizenid` = ?', { cid })
    if not row or (tonumber(row.seconds_left) or 0) <= 0 then
        if row then TriggerClientEvent('XS-PoliceSystem:client:pendingBelongings', src) end
        return nil
    end
    local place = Places.Get(row.jail_id) or pickJail(nil)
    if not place then return nil end
    local inmate = {
        src = src, cid = cid, name = row.name, jailId = place.id, months = tonumber(row.months) or 0, left = tonumber(row.seconds_left) or 0,
        reason = row.reason or '', officer = row.officer_name or '', items = Db.Decode(row.items, {}), look = Db.Decode(row.look, nil),
        escaped = Util.Truthy(row.escaped), outside = 0, number = ('%04d'):format(math.random(1000, 9999)),
        credit = math.max(0, math.floor(tonumber(row.credit) or 0)), breakout = Db.Decode(row.breakout, {}),
    }
    Jail.inmates[src] = inmate
    Framework.SetMetaData(src, 'injail', inmate.escaped and 0 or monthsLeft(inmate.left))
    if inmate.escaped then
        TriggerClientEvent('XS-PoliceSystem:client:escapedState', src, publicState(inmate))
    else
        offDuty(src)
        Jail.Place(src)
    end
    return inmate
end

Framework.OnLoaded(function(src)
    SetTimeout(1500, function()
        if GetPlayerName(src) then Jail.Load(src) end
    end)
end)

lib.callback.register('XS-PoliceSystem:server:jailState', function(src)
    local inmate = Jail.inmates[src]
    return inmate and publicState(inmate) or nil
end)

RegisterNetEvent('XS-PoliceSystem:server:jailReady', function()
    local inmate = Jail.inmates[source]
    if inmate and inmate.arriving then inmate.arriving.readyAt = inmate.arriving.readyAt or os.time() end
end)

local syncAt = {}

RegisterNetEvent('XS-PoliceSystem:server:jailSync', function()
    local src = source
    local now = os.time()
    if syncAt[src] and now - syncAt[src] < 10 then return end
    syncAt[src] = now
    if Jail.inmates[src] then
        if not Jail.inmates[src].escaped then Jail.Place(src) end
    else
        Jail.Load(src)
    end
end)

RegisterNetEvent('XS-PoliceSystem:server:jailReturn', function()
    local src = source
    local inmate = Jail.inmates[src]
    if inmate and not inmate.escaped then return Jail.Place(src) end
    if inmate or Jail.Load(src) then return end
    local months = tonumber(Framework.GetMetaData(src, 'injail')) or 0
    if months > 0 then Jail.Send(src, months, Text('mdt_sentence'), nil) end
end)

lib.callback.register('XS-PoliceSystem:server:jailLook', function(src, look)
    local inmate = Jail.inmates[src]
    if not inmate or inmate.look or type(look) ~= 'table' then return false end
    inmate.look = look
    MySQL.update.await('UPDATE `xs_police_inmates` SET `look` = ? WHERE `citizenid` = ?', { Db.Json(look), inmate.cid })
    return true
end)

local function workSpot(place, workId, spotId)
    for _, work in ipairs(place and place.work or {}) do
        if work.id == workId then
            for _, spot in ipairs(work.spots or {}) do
                if spot.id == spotId then return work, spot end
            end
            return nil
        end
    end
    return nil
end

local function inmateAt(src)
    local inmate = Jail.inmates[src]
    if not inmate or inmate.escaped or inmate.arriving then return nil end
    if inmate.solitary and inmate.solitary > os.time() then return nil end
    return inmate, Places.Get(inmate.jailId)
end

Jail.At = inmateAt
Jail.Persist = persist
Jail.SecondsPerMonth = secondsPerMonth

lib.callback.register('XS-PoliceSystem:server:jailJobStart', function(src, workId, spotId)
    local inmate, place = inmateAt(src)
    if not inmate then return false end
    local work, spot = workSpot(place, workId, spotId)
    if not spot or not Places.Near(src, spot, 3.0) then return false, Text('err_too_far') end
    local now = os.time()
    local last = (Jail.spotAt[src] or {})[spot.id]
    if last and now - last < (Config.Jail.spotCooldown or 90) then return false, Text('job_spot_done') end
    Jail.jobStart[src] = { work = work.id, spot = spot.id, at = now }
    return true, work.seconds
end)

lib.callback.register('XS-PoliceSystem:server:jailJob', function(src, workId, spotId)
    local inmate, place = inmateAt(src)
    if not inmate then return false end
    local work, spot = workSpot(place, workId, spotId)
    if not spot or not Places.Near(src, spot, 3.0) then return false, Text('err_too_far') end
    local started = Jail.jobStart[src]
    Jail.jobStart[src] = nil
    local now = os.time()
    if not started or started.work ~= work.id or started.spot ~= spot.id or now - started.at < work.seconds - 1 then
        return false, Text('err_slow_down')
    end
    Jail.spotAt[src] = Jail.spotAt[src] or {}
    Jail.spotAt[src][spot.id] = now
    inmate.left = math.max(1, inmate.left - work.credit)
    local extra = Inmate.JobDone(src, inmate, work)
    return true, { left = math.floor(inmate.left), credit = work.credit, pay = extra.pay, wallet = extra.wallet, found = extra.found }
end)

lib.callback.register('XS-PoliceSystem:server:workoutStart', function(src, pointId)
    local inmate, place = inmateAt(src)
    if not inmate then return false end
    local p = Places.Point(place, 'workout', pointId)
    if not p or not Places.Near(src, p, 3.0) then return false, Text('err_too_far') end
    Jail.workoutStart[src] = { point = p.id, at = os.time() }
    return true, (Config.Jail.workout or {}).seconds or 20
end)

lib.callback.register('XS-PoliceSystem:server:workout', function(src, pointId)
    local inmate, place = inmateAt(src)
    if not inmate then return false end
    local p = Places.Point(place, 'workout', pointId)
    if not p or not Places.Near(src, p, 3.0) then return false, Text('err_too_far') end
    local W = Config.Jail.workout or {}
    local started = Jail.workoutStart[src]
    Jail.workoutStart[src] = nil
    if not started or started.point ~= p.id or os.time() - started.at < (W.seconds or 20) - 1 then return false, Text('err_slow_down') end
    if (W.stress or 0) > 0 then Framework.SetStress(src, -W.stress) end
    local credit = math.max(0, math.floor(tonumber(W.credit) or 0))
    if credit > 0 then inmate.left = math.max(1, inmate.left - credit) end
    return true, { left = math.floor(inmate.left), credit = credit }
end)

local function canteenAt(src, pointId)
    local inmate = Jail.inmates[src]
    if not inmate or inmate.escaped then return nil end
    if inmate.solitary and inmate.solitary > os.time() then return nil, Text('err_in_solitary') end
    local place = Places.Get(inmate.jailId)
    local p = Places.Point(place, 'canteen', pointId)
    if not p or not Places.Near(src, p, 3.0) then return nil, Text('err_too_far') end
    return place
end

local function mealWait(src, place)
    local last = Jail.canteenAt[Framework.GetCitizenId(src) or src]
    if not last then return 0 end
    return math.max(0, (place.mealMinutes or 5) * 60 - (os.time() - last))
end

lib.callback.register('XS-PoliceSystem:server:canteenMenu', function(src, pointId)
    local place, err = canteenAt(src, pointId)
    if not place then return false, err end
    local meals = {}
    for _, meal in ipairs(place.meals or {}) do
        local items = {}
        for _, e in ipairs(meal.items) do
            items[#items + 1] = { item = e.item, amount = e.amount, label = Inventory.Label(e.item), image = Inventory.Image(e.item) }
        end
        meals[#meals + 1] = { id = meal.id, label = meal.label, items = items }
    end
    return true, { jail = place.name, meals = meals, wait = mealWait(src, place) }
end)

lib.callback.register('XS-PoliceSystem:server:canteen', function(src, pointId, mealId)
    local place, err = canteenAt(src, pointId)
    if not place then return false, err end
    local meal
    for _, m in ipairs(place.meals or {}) do
        if m.id == mealId then meal = m break end
    end
    if not meal then return false, Text('err_failed') end
    local wait = mealWait(src, place)
    if wait > 0 then return false, Text('canteen_wait_for', { time = Util.Span(wait) }) end
    Jail.canteenAt[Framework.GetCitizenId(src) or src] = os.time()
    for _, e in ipairs(meal.items) do Inventory.Add(src, e.item, e.amount) end
    return true, Text('canteen_served_meal', { meal = meal.label })
end)

lib.callback.register('XS-PoliceSystem:server:collect', function(src)
    if Jail.inmates[src] then return false, Text('err_nothing_to_collect') end
    local cid = Framework.GetCitizenId(src)
    if not lock(cid) then return false, Text('err_slow_down') end
    local ok, a, b = pcall(function()
        local row = MySQL.single.await('SELECT `items`, `seconds_left` FROM `xs_police_inmates` WHERE `citizenid` = ?', { cid })
        if not row or (tonumber(row.seconds_left) or 0) > 0 then return false, Text('err_nothing_to_collect') end
        local gone = MySQL.update.await('DELETE FROM `xs_police_inmates` WHERE `citizenid` = ? AND `seconds_left` <= 0', { cid })
        if (tonumber(gone) or 0) < 1 then return false, Text('err_nothing_to_collect') end
        local left = giveBack(src, Db.Decode(row.items, {}))
        if #left > 0 then
            MySQL.query.await('INSERT INTO `xs_police_inmates` (`citizenid`, `name`, `seconds_left`, `items`) VALUES (?, ?, 0, ?)', { cid, Framework.GetName(src) or '', Db.Json(left) })
            return false, Text('collect_partial')
        end
        return true, Text('collect_done')
    end)
    unlock(cid)
    if not ok then return false, Text('err_failed') end
    return a, b
end)

local function escape(src, inmate, place, quiet)
    inmate.escaped = true
    inmate.arriving = nil
    persist(src)
    TriggerClientEvent('XS-PoliceSystem:client:escaped', src)
    if quiet then return end
    if place and Config.Jail.alarm ~= false then Prison.Alarm(place.id) end
    if not Config.Jail.escapeAlert then return end
    local c = Places.Coords(src) or vector3(0.0, 0.0, 0.0)
    local text = Text('escape_alert', { name = inmate.name, jail = place and place.name or '' })
    for _, cop in ipairs(Framework.Cops(true)) do
        Framework.Notify(cop, text, 'error')
        TriggerClientEvent('XS-PoliceSystem:client:alertBlip', cop, { x = c.x, y = c.y, z = c.z }, Text('escape_blip'), 'escape')
    end
    Dispatch.Forward({ type = 'custom', code = '10-98', title = Text('escape_blip'), description = text, coords = c, sprite = 188 })
end

function Jail.Escape(src, quiet)
    local inmate = Jail.inmates[src]
    if not inmate or inmate.escaped then return false end
    escape(src, inmate, Places.Get(inmate.jailId), quiet)
    return true
end

local function enforce(src, inmate, place)
    local cell = pickCell(place)
    local ped = GetPlayerPed(src)
    if cell and ped ~= 0 then SetEntityCoords(ped, cell.x + 0.0, cell.y + 0.0, cell.z + 0.0, false, false, false, false) end
    inmate.arriving = { since = os.time(), readyAt = os.time() }
    TriggerClientEvent('XS-PoliceSystem:client:jailed', src, publicState(inmate), cell)
end

local function step(src, inmate, tick, later)
    if not GetPlayerName(src) then
        Jail.inmates[src] = nil
        return
    end
    if inmate.escaped then return end
    local place = Places.Get(inmate.jailId)
    if not place then return end
    local now = os.time()
    if inmate.arriving then
        if inside(src, place) then
            inmate.arriving = nil
            inmate.outside = 0
        else
            local a = inmate.arriving
            if (a.readyAt and now - a.readyAt > ARRIVE_GRACE) or now - a.since > ARRIVE_MAX then
                later[#later + 1] = function() enforce(src, inmate, place) end
            end
        end
        return
    end
    if not inside(src, place) then
        inmate.outside = (inmate.outside or 0) + 1
        if inmate.outside >= ESCAPE_CHECKS then later[#later + 1] = function() escape(src, inmate, place) end end
        return
    end
    inmate.outside = 0
    Prison.Tick(src, inmate, place)
    inmate.left = inmate.left - 10
    if inmate.left <= 0 then
        later[#later + 1] = function() Jail.Release(src, 'served') end
        return
    end
    if tick % 6 == 0 then persist(src) end
    TriggerClientEvent('XS-PoliceSystem:client:jailTime', src, math.floor(inmate.left))
end

CreateThread(function()
    local tick = 0
    while true do
        Wait(10000)
        tick = tick + 1
        local list = {}
        for src, inmate in pairs(Jail.inmates) do list[#list + 1] = { src = src, inmate = inmate } end
        local later = {}
        for _, entry in ipairs(list) do
            if Jail.inmates[entry.src] == entry.inmate then
                local ok, err = pcall(step, entry.src, entry.inmate, tick, later)
                if not ok then print(('^1[XS-PoliceSystem]^0 jail tick failed for %s: %s'):format(entry.src, tostring(err))) end
            end
        end
        for _, fn in ipairs(later) do
            CreateThread(function()
                local ok, err = pcall(fn)
                if not ok then print(('^1[XS-PoliceSystem]^0 jail action failed: %s'):format(tostring(err))) end
            end)
        end
    end
end)

Framework.OnUnloaded(function(src)
    if Jail.inmates[src] then persist(src, true) end
    Jail.inmates[src] = nil
    Jail.jobStart[src], Jail.spotAt[src], Jail.workoutStart[src] = nil, nil, nil
end)

function Jail.LoadOnline()
    for _, src in ipairs(Framework.Players()) do
        local ok, err = pcall(Jail.Load, src)
        if not ok then print(('^1[XS-PoliceSystem]^0 could not load jail state for %s: %s'):format(src, tostring(err))) end
    end
end

exports('SendToJail', function(target, months, reason) return Jail.Send(tonumber(target), months, reason, nil) end)
exports('ReleaseFromJail', function(target) return Jail.Release(tonumber(target), 'released') end)
exports('IsInJail', function(target) return Jail.IsInmate(target) end)
exports('JailTimeLeft', function(target)
    local inmate = Jail.inmates[tonumber(target) or -1]
    return inmate and math.max(0, math.floor(inmate.left)) or 0
end)

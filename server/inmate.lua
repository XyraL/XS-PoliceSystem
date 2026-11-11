Inmate = { crafting = {}, digging = {}, searchAt = {}, callAt = {} }

local function J()
    return Config.Jail or {}
end

local function at(src, kind, pointId)
    local inmate, place = Jail.At(src)
    if not inmate then return nil, nil, Text('err_not_now_inmate') end
    local p = Places.Point(place, kind, pointId)
    if not p or not Places.Near(src, p, 3.0) then return nil, nil, Text('err_too_far') end
    return inmate, place, p
end

local function credited(src, inmate)
    Inmate.Save(inmate)
    TriggerClientEvent('XS-PoliceSystem:client:jailCredit', src, math.floor(inmate.credit or 0))
end

function Inmate.Save(inmate)
    if not inmate or not inmate.cid then return end
    MySQL.update('UPDATE `xs_police_inmates` SET `credit` = ?, `breakout` = ? WHERE `citizenid` = ?', { math.floor(tonumber(inmate.credit) or 0), Db.Json(inmate.breakout or {}), inmate.cid })
end

function Inmate.JobDone(src, inmate, work)
    local pay = math.max(0, math.floor(tonumber(work.pay) or 0))
    if pay > 0 then inmate.credit = math.floor(tonumber(inmate.credit) or 0) + pay end
    local found
    for _, f in ipairs((J().contraband or {}).finds or {}) do
        if not found and type(f) == 'table' and f.item and math.random(100) <= (tonumber(f.chance) or 0)
            and Inventory.CanCarry(src, f.item, 1) and Inventory.Add(src, f.item, 1) then
            found = Inventory.Label(f.item)
        end
    end
    if pay > 0 then credited(src, inmate) end
    return { pay = pay, wallet = math.floor(tonumber(inmate.credit) or 0), found = found }
end

function Inmate.OnRelease(src, inmate)
    Inmate.crafting[src], Inmate.digging[src] = nil, nil
    local credit = math.floor(tonumber(inmate.credit) or 0)
    local cash = math.floor(credit * (tonumber(J().creditPayout) or 0))
    if cash > 0 then
        Framework.AddMoney(src, 'cash', cash, 'Prison commissary credit')
        Framework.Notify(src, Text('credit_paid', { amount = cash }), 'success')
    end
    inmate.credit, inmate.breakout = 0, {}
    MySQL.update('UPDATE `xs_police_inmates` SET `credit` = 0, `breakout` = NULL WHERE `citizenid` = ?', { inmate.cid })
end

local function itemView(item, price, extra)
    local out = { item = item, price = math.max(0, math.floor(tonumber(price) or 0)), label = Inventory.Label(item), image = Inventory.Image(item) }
    for k, v in pairs(extra or {}) do out[k] = v end
    return out
end

lib.callback.register('XS-PoliceSystem:server:commissary', function(src, pointId)
    local inmate, place, err = at(src, 'clerk', pointId)
    if not inmate then return false, err end
    local items = {}
    for i, e in ipairs(J().commissary or {}) do
        if type(e) == 'table' and e.call then
            items[#items + 1] = { id = i, call = true, price = math.floor(tonumber(e.price) or 0), label = Text('commissary_call') }
        elseif type(e) == 'table' and e.item then
            items[#items + 1] = itemView(e.item, e.price, { id = i, amount = math.max(1, math.floor(tonumber(e.amount) or 1)) })
        end
    end
    return true, { mode = 'commissary', jail = place.name, credit = math.floor(inmate.credit or 0), items = items }
end)

lib.callback.register('XS-PoliceSystem:server:commissaryBuy', function(src, pointId, id, qty)
    local inmate, _, err = at(src, 'clerk', pointId)
    if not inmate then return false, err end
    local e = (J().commissary or {})[tonumber(id) or 0]
    if type(e) ~= 'table' or not e.item then return false, Text('err_failed') end
    qty = Util.Clamp(math.floor(tonumber(qty) or 1), 1, 10)
    local cost = math.max(0, math.floor(tonumber(e.price) or 0)) * qty
    local count = math.max(1, math.floor(tonumber(e.amount) or 1)) * qty
    if (inmate.credit or 0) < cost then return false, Text('err_no_credit') end
    if not Inventory.CanCarry(src, e.item, count) then return false, Text('err_cannot_carry') end
    inmate.credit = inmate.credit - cost
    if not Inventory.Add(src, e.item, count) then
        inmate.credit = inmate.credit + cost
        return false, Text('err_cannot_carry')
    end
    credited(src, inmate)
    return true, { credit = inmate.credit, message = Text('commissary_bought', { count = count, item = Inventory.Label(e.item) }) }
end)

lib.callback.register('XS-PoliceSystem:server:commissaryPeople', function(src, pointId, query)
    local inmate, _, err = at(src, 'clerk', pointId)
    if not inmate then return false, err end
    query = Util.Text(query, 40):lower()
    if #query < 3 then return true, {} end
    local out = {}
    for _, other in ipairs(Framework.Players()) do
        local name = Framework.GetName(other) or ''
        if other ~= src and name:lower():find(query, 1, true) and #out < 6 then out[#out + 1] = { src = other, name = name } end
    end
    return true, out
end)

lib.callback.register('XS-PoliceSystem:server:commissaryCall', function(src, pointId, id, target, message)
    local inmate, place, err = at(src, 'clerk', pointId)
    if not inmate then return false, err end
    local e = (J().commissary or {})[tonumber(id) or 0]
    if type(e) ~= 'table' or not e.call then return false, Text('err_failed') end
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return false, Text('err_no_player') end
    message = Util.Text(message, 160)
    if message == '' then return false, Text('err_need_message') end
    local now = os.time()
    if Inmate.callAt[src] and now - Inmate.callAt[src] < 60 then return false, Text('err_slow_down') end
    local cost = math.max(0, math.floor(tonumber(e.price) or 0))
    if (inmate.credit or 0) < cost then return false, Text('err_no_credit') end
    Inmate.callAt[src] = now
    inmate.credit = inmate.credit - cost
    credited(src, inmate)
    Framework.Notify(target, Text('prison_call_from', { jail = place.name, name = inmate.name, message = message }), 'inform')
    return true, { credit = inmate.credit, message = Text('prison_call_sent', { name = Framework.GetName(target) or '' }) }
end)

local function currency()
    local c = J().currency
    return (type(c) == 'string' and c ~= '') and c or 'prison_cigarettes'
end

lib.callback.register('XS-PoliceSystem:server:trader', function(src, pointId)
    local inmate, place, err = at(src, 'trader', pointId)
    if not inmate then return false, err end
    local T = J().trader or {}
    local sells, buys = {}, {}
    for i, e in ipairs(T.sells or {}) do
        if type(e) == 'table' and e.item then sells[#sells + 1] = itemView(e.item, e.price, { id = i }) end
    end
    for i, e in ipairs(T.buys or {}) do
        if type(e) == 'table' and e.item then buys[#buys + 1] = itemView(e.item, e.price, { id = i, have = Inventory.Count(src, e.item) }) end
    end
    local cur = currency()
    return true, { mode = 'trader', jail = place.name, currency = cur, currencyLabel = Inventory.Label(cur), currencyImage = Inventory.Image(cur), wallet = Inventory.Count(src, cur), sells = sells, buys = buys }
end)

lib.callback.register('XS-PoliceSystem:server:traderDeal', function(src, pointId, side, id, qty)
    local inmate, _, err = at(src, 'trader', pointId)
    if not inmate then return false, err end
    local T = J().trader or {}
    local list = side == 'sell' and T.buys or T.sells
    local e = (list or {})[tonumber(id) or 0]
    if type(e) ~= 'table' or not e.item then return false, Text('err_failed') end
    qty = Util.Clamp(math.floor(tonumber(qty) or 1), 1, 20)
    local cur = currency()
    local total = math.max(0, math.floor(tonumber(e.price) or 0)) * qty
    if side == 'sell' then
        if Inventory.Count(src, e.item) < qty then return false, Text('err_need_item', { item = Inventory.Label(e.item) }) end
        if total > 0 and not Inventory.CanCarry(src, cur, total) then return false, Text('err_cannot_carry') end
        if not Inventory.Remove(src, e.item, qty) then return false, Text('err_failed') end
        if total > 0 then Inventory.Add(src, cur, total) end
        return true, { wallet = Inventory.Count(src, cur), message = Text('trader_sold', { count = qty, item = Inventory.Label(e.item), price = total }) }
    end
    if Inventory.Count(src, cur) < total then return false, Text('err_no_currency', { item = Inventory.Label(cur) }) end
    if not Inventory.CanCarry(src, e.item, qty) then return false, Text('err_cannot_carry') end
    if total > 0 and not Inventory.Remove(src, cur, total) then return false, Text('err_failed') end
    if not Inventory.Add(src, e.item, qty) then
        if total > 0 then Inventory.Add(src, cur, total) end
        return false, Text('err_cannot_carry')
    end
    return true, { wallet = Inventory.Count(src, cur), message = Text('trader_bought', { count = qty, item = Inventory.Label(e.item), price = total }) }
end)

local function recipe(index)
    local r = (J().recipes or {})[tonumber(index) or 0]
    if type(r) ~= 'table' or not r.item or type(r.needs) ~= 'table' then return nil end
    return r
end

local function missing(src, r)
    for item, n in pairs(r.needs) do
        if Inventory.Count(src, item) < (tonumber(n) or 1) then return item end
    end
    return nil
end

lib.callback.register('XS-PoliceSystem:server:workbench', function(src, pointId)
    local inmate, place, err = at(src, 'craft', pointId)
    if not inmate then return false, err end
    local out = {}
    for i in ipairs(J().recipes or {}) do
        local r = recipe(i)
        if r then
            local needs = {}
            for item, n in pairs(r.needs) do needs[#needs + 1] = itemView(item, 0, { need = tonumber(n) or 1, have = Inventory.Count(src, item) }) end
            table.sort(needs, function(a, b) return a.label < b.label end)
            out[#out + 1] = itemView(r.item, 0, { id = i, seconds = math.max(3, math.floor(tonumber(r.seconds) or 10)), needs = needs })
        end
    end
    return true, { mode = 'craft', jail = place.name, recipes = out }
end)

lib.callback.register('XS-PoliceSystem:server:craftStart', function(src, pointId, index)
    local inmate, _, err = at(src, 'craft', pointId)
    if not inmate then return false, err end
    local r = recipe(index)
    if not r then return false, Text('err_failed') end
    local short = missing(src, r)
    if short then return false, Text('err_need_item', { item = Inventory.Label(short) }) end
    Inmate.crafting[src] = { point = pointId, index = tonumber(index), at = os.time() }
    return true, { seconds = math.max(3, math.floor(tonumber(r.seconds) or 10)), label = Inventory.Label(r.item) }
end)

lib.callback.register('XS-PoliceSystem:server:craft', function(src, pointId, index)
    local inmate, _, err = at(src, 'craft', pointId)
    if not inmate then return false, err end
    local r = recipe(index)
    local started = Inmate.crafting[src]
    Inmate.crafting[src] = nil
    if not r or not started or started.point ~= pointId or started.index ~= tonumber(index) or os.time() - started.at < math.max(3, math.floor(tonumber(r.seconds) or 10)) - 1 then
        return false, Text('err_slow_down')
    end
    local short = missing(src, r)
    if short then return false, Text('err_need_item', { item = Inventory.Label(short) }) end
    if not Inventory.CanCarry(src, r.item, 1) then return false, Text('err_cannot_carry') end
    for item, n in pairs(r.needs) do Inventory.Remove(src, item, tonumber(n) or 1) end
    Inventory.Add(src, r.item, 1)
    return true, Text('crafted', { item = Inventory.Label(r.item) })
end)

local function guardNear(place, p, range)
    for _, g in ipairs(place.points.guard or {}) do
        if (g.x - p.x) ^ 2 + (g.y - p.y) ^ 2 <= range * range and math.abs(g.z - p.z) < 6.0 then return true end
    end
    return false
end

local function penalise(src, inmate, months)
    months = math.max(0, math.floor(tonumber(months) or 0))
    if months <= 0 then return 0 end
    inmate.left = inmate.left + months * Jail.SecondsPerMonth()
    Jail.Persist(src)
    TriggerClientEvent('XS-PoliceSystem:client:jailTime', src, math.floor(inmate.left))
    return months
end

local function through(src, inmate, place, p, kind)
    local exit = p.exit
    if not exit then return false, Text('err_no_exit') end
    local ped = GetPlayerPed(src)
    if ped ~= 0 then SetEntityCoords(ped, exit.x + 0.0, exit.y + 0.0, exit.z + 0.0, false, false, false, false) end
    if (J().breakout or {}).alarm ~= false then
        if inmate.test then Prison.Alarm(place.id) else Prison.Break(place.id) end
    end
    Jail.Escape(src, true)
    Db.Log('breakout', { citizenid = inmate.cid, name = inmate.name }, 0, ('%s · %s'):format(place.name, Text('point_' .. kind)), nil)
    return true, { through = true, message = Text('breakout_through') }
end

local function caught(src, inmate, p, kind, item)
    inmate.breakout = inmate.breakout or {}
    inmate.breakout[p.id] = nil
    if item and item ~= '' then Inventory.Remove(src, item, 1) end
    local months = penalise(src, inmate, (J().contraband or {}).penaltyMonths)
    Inmate.Save(inmate)
    Db.Log('contraband', { citizenid = inmate.cid, name = inmate.name }, months, Text(kind == 'tunnel' and 'breakout_caught_tunnel' or 'breakout_caught_fence'), nil)
    return months
end

local function digSeconds(kind)
    local B = J().breakout or {}
    return math.max(3, math.floor(tonumber(kind == 'tunnel' and B.tunnelSeconds or B.fenceSeconds) or 20))
end

lib.callback.register('XS-PoliceSystem:server:digStart', function(src, kind, pointId)
    if kind ~= 'tunnel' and kind ~= 'fence' then return false, Text('err_failed') end
    local inmate, place, p = at(src, kind, pointId)
    if not inmate then return false, p end
    local B = J().breakout or {}
    if kind == 'tunnel' and (inmate.breakout or {})[p.id] and inmate.breakout[p.id] >= (B.tunnelSessions or 8) then
        return true, { ready = true }
    end
    local item = kind == 'tunnel' and B.tunnelItem or B.fenceItem
    if item and item ~= '' and not Inventory.Has(src, item, 1) then return false, Text('err_need_item', { item = Inventory.Label(item) }) end
    local seconds = digSeconds(kind)
    local session = { kind = kind, point = p.id, at = os.time() }
    Inmate.digging[src] = session
    if guardNear(place, p, tonumber(B.guardRange) or 15.0) and math.random(100) <= (tonumber(B.caughtChance) or 0) then
        SetTimeout(math.floor(seconds * 1000 * (0.25 + math.random() * 0.5)), function()
            if Inmate.digging[src] ~= session or Jail.inmates[src] ~= inmate or inmate.escaped then return end
            Inmate.digging[src] = nil
            local months = caught(src, inmate, p, kind, item)
            TriggerClientEvent('XS-PoliceSystem:client:inmateStop', src, Text('breakout_caught', { months = months }))
        end)
    end
    return true, { seconds = seconds }
end)

RegisterNetEvent('XS-PoliceSystem:server:digStop', function()
    Inmate.digging[source] = nil
end)

lib.callback.register('XS-PoliceSystem:server:dig', function(src, kind, pointId)
    if kind ~= 'tunnel' and kind ~= 'fence' then return false, Text('err_failed') end
    local inmate, place, p = at(src, kind, pointId)
    if not inmate then return false, p end
    local B = J().breakout or {}
    local started = Inmate.digging[src]
    Inmate.digging[src] = nil
    if not started or started.kind ~= kind or started.point ~= p.id or os.time() - started.at < digSeconds(kind) - 1 then return false, Text('err_slow_down') end
    local item = kind == 'tunnel' and B.tunnelItem or B.fenceItem
    if item and item ~= '' and not Inventory.Has(src, item, 1) then return false, Text('err_need_item', { item = Inventory.Label(item) }) end
    local snapped = item and item ~= '' and math.random(100) <= (tonumber(kind == 'tunnel' and B.spoonBreak or B.cuttersBreak) or 0)
    if snapped then Inventory.Remove(src, item, 1) end
    if kind == 'fence' then return through(src, inmate, place, p, kind) end
    inmate.breakout = inmate.breakout or {}
    local progress = (inmate.breakout[p.id] or 0) + 1
    inmate.breakout[p.id] = progress
    Inmate.Save(inmate)
    local sessions = math.max(1, math.floor(tonumber(B.tunnelSessions) or 8))
    return true, { progress = progress, sessions = sessions, done = progress >= sessions, snapped = snapped == true, item = item and Inventory.Label(item) or '' }
end)

lib.callback.register('XS-PoliceSystem:server:crawl', function(src, pointId)
    local inmate, place, p = at(src, 'tunnel', pointId)
    if not inmate then return false, p end
    local sessions = math.max(1, math.floor(tonumber((J().breakout or {}).tunnelSessions) or 8))
    if ((inmate.breakout or {})[p.id] or 0) < sessions then return false, Text('tunnel_not_done') end
    inmate.breakout[p.id] = nil
    Inmate.Save(inmate)
    return through(src, inmate, place, p, 'tunnel')
end)

function Inmate.Search(src)
    local inmate = Jail.inmates[src]
    if not inmate or inmate.escaped then return false end
    local C = J().contraband or {}
    Framework.Notify(src, Text('guard_search'), 'inform')
    if math.random(100) > (tonumber(C.searchChance) or 50) then return false end
    local found = {}
    for _, name in ipairs(C.items or {}) do
        local n = Inventory.Count(src, name)
        if n > 0 and Inventory.Remove(src, name, n) then found[#found + 1] = ('%d× %s'):format(n, Inventory.Label(name)) end
    end
    if #found == 0 then return false end
    local months = penalise(src, inmate, C.penaltyMonths)
    local list = table.concat(found, ', ')
    if Inmate.digging[src] or Inmate.crafting[src] then
        Inmate.digging[src], Inmate.crafting[src] = nil, nil
        TriggerClientEvent('XS-PoliceSystem:client:inmateStop', src, nil)
    end
    Framework.Notify(src, Text('guard_found', { items = list, months = months }), 'error')
    Db.Log('contraband', { citizenid = inmate.cid, name = inmate.name }, months, list, nil)
    return true
end

CreateThread(function()
    while true do
        Wait(30000)
        local C = J().contraband or {}
        local every = math.floor((tonumber(C.searchMinutes) or 0) * 60)
        if every > 0 then
            local now, byJail = os.time(), {}
            for src, inmate in pairs(Jail.inmates) do
                if not inmate.escaped and not inmate.arriving then
                    byJail[inmate.jailId] = byJail[inmate.jailId] or {}
                    table.insert(byJail[inmate.jailId], src)
                end
            end
            for jailId, list in pairs(byJail) do
                local place = Places.Get(jailId)
                local posts = place and place.points.guard or {}
                if #posts > 0 and now - (Inmate.searchAt[jailId] or 0) >= every then
                    local near = {}
                    for _, src in ipairs(list) do
                        for _, g in ipairs(posts) do
                            if Places.Near(src, g, tonumber(C.searchRange) or 12.0) then near[#near + 1] = src break end
                        end
                    end
                    if #near > 0 then
                        Inmate.searchAt[jailId] = now
                        local ok, err = pcall(Inmate.Search, near[math.random(#near)])
                        if not ok then print(('^1[XS-PoliceSystem]^0 guard search failed: %s'):format(tostring(err))) end
                    end
                end
            end
        end
    end
end)

local function size(S, slots, weight)
    return math.max(1, math.floor(tonumber(S.slots) or slots)), math.max(1000, math.floor(tonumber(S.weight) or weight))
end

lib.callback.register('XS-PoliceSystem:server:bedStash', function(src, pointId)
    local S = J().bedStash or {}
    if S.enabled == false then return false, Text('err_failed') end
    local inmate, place, p = at(src, 'cell', pointId)
    if not inmate then return false, p end
    local slots, weight = size(S, 8, 8000)
    local label = Text('bed_stash_label')
    local mode, id = Inventory.OpenLocker(src, ('xspolice_bed_%s'):format(place.id), label, slots, weight, vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0), nil)
    return true, { mode = mode, id = id, label = label, slots = slots, weight = weight }
end)

lib.callback.register('XS-PoliceSystem:server:hiddenStash', function(src, pointId)
    local inmate, place, p = at(src, 'hide', pointId)
    if not inmate then return false, p end
    local slots, weight = size(J().hiddenStash or {}, 15, 20000)
    local label = (p.label and p.label ~= '') and p.label or Text('point_hide')
    local id = ('xspolice_hide_%s_%s'):format(place.id, p.id)
    local mode = Inventory.OpenStash(src, id, label, slots, weight, nil, vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0))
    return true, { mode = mode, id = id, label = label, slots = slots, weight = weight }
end)

AddEventHandler('playerDropped', function()
    local src = source
    Inmate.crafting[src], Inmate.digging[src], Inmate.callAt[src] = nil, nil, nil
end)

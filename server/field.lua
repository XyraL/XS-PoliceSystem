Field = { escorts = {}, gsr = {}, lastAction = {}, cuffing = {}, resistAt = {}, fineAt = {} }

local function officerOf(src)
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job) then return nil end
    return { src = src, cop = true, job = job.name, citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', grade = job.grade, isBoss = job.isBoss }
end

local function civilianOf(src)
    return { src = src, cop = false, job = '', citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '', grade = 0 }
end

local function targetOf(src)
    return { src = src, citizenid = Framework.GetCitizenId(src), name = Framework.GetName(src) or '' }
end

local function near(a, b, range)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= (range or ((Config.Wheel.range or 3.0) + 1.5))
end

local function throttle(src, ms)
    local now = GetGameTimer()
    if Field.lastAction[src] and now - Field.lastAction[src] < (ms or 600) then return false end
    Field.lastAction[src] = now
    return true
end

function Field.IsCuffed(src)
    return Framework.GetMetaData(src, 'ishandcuffed') == true
end

function Field.IsDown(src)
    local bag = Player(src).state
    if bag.isDead or bag.dead then return true end
    return Framework.GetMetaData(src, 'isdead') == true or Framework.GetMetaData(src, 'inlaststand') == true
end

function Field.HandsUp(src)
    local ok, up = pcall(lib.callback.await, 'XS-PoliceSystem:client:handsUp', src)
    return ok and up == true
end

function Field.Restrained(src)
    return Field.IsCuffed(src) or Field.IsDown(src) or Field.HandsUp(src)
end

function Field.SetCuffed(target, on, officer)
    on = on == true
    Framework.SetMetaData(target, 'ishandcuffed', on)
    local bag = Player(target).state
    bag:set('xspCuffed', on, true)
    if on then
        bag:set('invBusy', true, true)
    elseif not Field.IsDown(target) then
        bag:set('invBusy', false, true)
    end
    if not on and Field.escorts[target] then Field.StopEscort(target) end
    TriggerClientEvent('XS-PoliceSystem:client:cuffed', target, on, officer)
    TriggerEvent('XS-PoliceSystem:server:cuffChanged', target, on, officer)
end

function Field.StopEscort(target)
    local officer = Field.escorts[target]
    Field.escorts[target] = nil
    TriggerClientEvent('XS-PoliceSystem:client:escorted', target, nil)
    if officer then TriggerClientEvent('XS-PoliceSystem:client:escorting', officer, nil) end
end

local Actions = {}

local function hasCuffs(officer)
    local item = Config.Cuffs.item
    if officer.cop and (not item or item == '') then return true end
    return Inventory.Has(officer.src, item or 'handcuffs', 1)
end

Actions.cuff = function(officer, target)
    if Field.cuffing[target] then return false, Text('err_slow_down') end
    if Field.IsCuffed(target) then
        if not hasCuffs(officer) and not officer.cop then
            return false, Text('err_need_item', { item = Inventory.Label(Config.Cuffs.item or 'handcuffs') })
        end
        TriggerClientEvent('XS-PoliceSystem:client:cuffAnim', officer.src, target, false)
        Field.SetCuffed(target, false, officer.src)
        return true, Text('uncuffed', { name = Text('the_person') })
    end
    if not hasCuffs(officer) then
        return false, Text('err_need_item', { item = Inventory.Label(Config.Cuffs.item or 'handcuffs') })
    end
    Field.cuffing[target] = true
    local surrendering = Field.IsDown(target) or Field.HandsUp(target)
    if Config.Cuffs.needsHandsUp and not surrendering then
        Field.cuffing[target] = nil
        return false, Text('err_not_surrendering')
    end
    local key = ('%s:%s'):format(target, officer.src)
    local now = os.time()
    local canResist = Config.Cuffs.resist and not surrendering and not (Field.resistAt[key] and now - Field.resistAt[key] < 20)
    if canResist then
        Field.resistAt[key] = now
        local ok, escaped = pcall(lib.callback.await, 'XS-PoliceSystem:client:resist', target)
        if ok and escaped == true then
            Field.cuffing[target] = nil
            Framework.Notify(target, Text('you_pulled_away'), 'success')
            return false, Text('err_pulled_away')
        end
    end
    if not near(officer.src, target) then
        Field.cuffing[target] = nil
        return false, Text('err_too_far')
    end
    TriggerClientEvent('XS-PoliceSystem:client:cuffAnim', officer.src, target, true)
    TriggerClientEvent('XS-PoliceSystem:client:getCuffedAnim', target, officer.src)
    SetTimeout(3200, function()
        Field.cuffing[target] = nil
        if GetPlayerName(target) and near(officer.src, target, 6.0) then Field.SetCuffed(target, true, officer.src) end
    end)
    return true, Text('cuffed', { name = Text('the_person') })
end

Actions.escort = function(officer, target)
    if Field.escorts[target] then
        if Field.escorts[target] ~= officer.src and not officer.cop then return false, Text('err_police_only') end
        Field.StopEscort(target)
        return true, Text('escort_stopped')
    end
    if not Field.IsCuffed(target) and not Field.IsDown(target) then return false, Text('err_not_restrained') end
    for t, o in pairs(Field.escorts) do
        if o == officer.src then Field.StopEscort(t) end
    end
    Field.escorts[target] = officer.src
    TriggerClientEvent('XS-PoliceSystem:client:escorted', target, officer.src)
    TriggerClientEvent('XS-PoliceSystem:client:escorting', officer.src, target)
    return true, Text('escort_started')
end

Actions.putInVehicle = function(officer, target, extra)
    local netId = tonumber(extra and extra.netId)
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
    if #(GetEntityCoords(GetPlayerPed(officer.src)) - GetEntityCoords(vehicle)) > 8.0 then return false, Text('err_too_far') end
    if not Field.IsCuffed(target) and not Field.IsDown(target) then return false, Text('err_not_restrained') end
    if Field.escorts[target] then Field.StopEscort(target) end
    TriggerClientEvent('XS-PoliceSystem:client:putInVehicle', target, netId)
    return true, Text('put_in_vehicle')
end

Actions.takeOutVehicle = function(officer, target)
    local ped = GetPlayerPed(target)
    if GetVehiclePedIsIn(ped, false) == 0 then return false, Text('err_not_in_vehicle') end
    if not Field.IsCuffed(target) and not Field.IsDown(target) then return false, Text('err_not_restrained') end
    TriggerClientEvent('XS-PoliceSystem:client:takeOutVehicle', target)
    return true, Text('took_out_vehicle')
end

Actions.search = function(officer, target)
    if Config.Search.needsRestrained and not Field.Restrained(target) then return false, Text('err_not_restrained') end
    if not Inventory.OpenPlayer(officer.src, target) then return false, Text('err_failed') end
    Framework.Notify(target, Text('being_searched'), 'inform')
    return true
end

Actions.seize = function(officer, target)
    if not Field.Restrained(target) then return false, Text('err_not_restrained') end
    if not Config.Seize.cash then return false, Text('err_failed') end
    local cash = Framework.GetMoney(target).cash
    if cash <= 0 then return false, Text('err_no_cash') end
    if not Framework.RemoveMoney(target, 'cash', cash, 'Seized by police') then return false, Text('err_failed') end
    if Config.Seize.society and Banking.name then Banking.Deposit(officer.job, cash, 'Seized cash') end
    Db.Log('seize', targetOf(target), cash, 'Cash seized', officer)
    Framework.Notify(target, Text('cash_seized_you', { amount = cash }), 'error')
    return true, Text('cash_seized', { amount = cash })
end

Actions.idcheck = function(officer, target)
    local player = Framework.GetPlayer(target)
    if not player then return false, Text('err_no_player') end
    local ci = player.PlayerData.charinfo or {}
    local meta = player.PlayerData.metadata or {}
    local licences = meta.licences or meta.licenses or {}
    local gender = tonumber(ci.gender)
    if gender == nil then gender = (ci.gender == 'female' or ci.gender == 'f') and 1 or 0 end
    return true, {
        card = {
            firstname = ci.firstname or '', lastname = ci.lastname or '', dob = ci.birthdate or '', nationality = ci.nationality or '',
            female = gender == 1, citizenid = player.PlayerData.citizenid, driver = licences.driver == true, weapon = licences.weapon == true,
            jailed = (tonumber(meta.injail) or 0) > 0,
            photo = Mugshot.Get(player.PlayerData.citizenid),
            wanted = Links.Warrants(player.PlayerData.citizenid),
        },
    }
end

Actions.gsr = function(officer, target)
    local cid = Framework.GetCitizenId(target)
    local at = cid and Field.gsr[cid]
    local positive = at and (os.time() - at) <= (Config.Gsr.minutes or 20) * 60
    return true, Text(positive and 'gsr_positive' or 'gsr_negative'), { positive = positive == true }
end

local function record(cid)
    local out = { bookings = 0, warrants = cid and Links.Warrants(cid) or 0, scenes = 0 }
    if not cid then return out end
    local ok, row = pcall(MySQL.single.await, "SELECT COUNT(*) AS `n`, UNIX_TIMESTAMP(MAX(`created_at`)) AS `last` FROM `xs_police_log` WHERE `citizenid` = ? AND `kind` = 'jail'", { cid })
    if ok and type(row) == 'table' then
        out.bookings = tonumber(row.n) or 0
        out.last = tonumber(row.last)
    end
    local okLab, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM `xs_police_lab` WHERE `match_cid` = ?', { cid })
    out.scenes = okLab and tonumber(n) or 0
    return out
end

function Field.Gloved(src)
    local ok, bare = pcall(lib.callback.await, 'XS-PoliceSystem:client:bare', src)
    return ok and bare == false
end

Actions.fingerprint = function(officer, target)
    local c = Config.Forensics or {}
    if c.needsRestrained ~= false and not Field.Restrained(target) then return false, Text('err_not_restrained') end
    if c.glovesBlock ~= false and Field.Gloved(target) then return false, Text('err_gloves_on') end
    local print, dna = Forensics.Print(target), Forensics.Dna(target)
    local scan = {
        name = Framework.GetName(target) or '', print = print, dna = dna, target = target, cid = Framework.GetCitizenId(target),
        seed = Util.Hash(tostring(print)) % 2147483647, matches = Forensics.Matches(officer.src, print, dna),
        record = record(Framework.GetCitizenId(target)),
    }
    Framework.Notify(target, Text('prints_taken_you'), 'inform')
    Db.Log('prints', targetOf(target), 0, 'Prints and DNA taken', officer)
    return true, { scan = scan }
end

Actions.takedna = function(officer, target)
    local c = Config.Forensics or {}
    local bag = c.bag ~= '' and c.bag or nil
    if bag and not Inventory.Has(officer.src, bag, 1) then return false, Text('err_need_item', { item = Inventory.Label(bag) }) end
    local dna = Forensics.Dna(target)
    local meta = {
        type = 'dna', label = Text('evidence_label_dna'), dnalabel = dna, street = '', collected = os.date('%d/%m %H:%M'), officer = officer.name,
        description = Text('evidence_desc_dna', { dna = dna, name = Framework.GetName(target) or '', officer = officer.name }),
    }
    if not Inventory.Add(officer.src, c.filled or 'filled_evidence_bag', 1, meta) then return false, Text('err_cannot_carry') end
    if bag then Inventory.Remove(officer.src, bag, 1) end
    return true, Text('dna_taken')
end

Actions.breathalyzer = function(officer, target)
    return true, { test = { kind = 'breath', name = Framework.GetName(target) or '', bac = Status.Breath(target), limit = (Config.Tests or {}).bacLimit or 0.08 } }
end

Actions.drugswab = function(officer, target)
    return true, { test = { kind = 'drugs', name = Framework.GetName(target) or '', results = Status.Drugs(target) } }
end

Actions.status = function(officer, target)
    return true, { statuses = Status.Texts(target) }
end

local function licenceKey(target)
    if Framework.GetMetaData(target, 'licences') == nil and Framework.GetMetaData(target, 'licenses') ~= nil then return 'licenses' end
    return 'licences'
end

local function canGrant(officer)
    return officer.isBoss or (officer.grade or 0) >= ((Config.Grades or {}).licences or 2)
end

Actions.licences = function(officer, target)
    local meta = Framework.GetMetaData(target, licenceKey(target)) or {}
    local list = {}
    for _, kind in ipairs((Config.Licences or {}).kinds or { 'driver', 'weapon' }) do list[#list + 1] = { kind = kind, has = meta[kind] == true } end
    return true, { licences = { target = target, name = Framework.GetName(target) or '', list = list, canGrant = canGrant(officer) } }
end

function Field.SetLicence(officer, target, kind, on)
    local known = false
    for _, k in ipairs((Config.Licences or {}).kinds or { 'driver', 'weapon' }) do if k == kind then known = true end end
    if not known then return false, Text('err_failed') end
    if on and not canGrant(officer) then return false, Text('err_grade') end
    local key = licenceKey(target)
    local meta = Framework.GetMetaData(target, key) or {}
    if (meta[kind] == true) == on then return false, Text(on and 'err_licence_has' or 'err_no_licence') end
    meta[kind] = on
    Framework.SetMetaData(target, key, meta)
    local label = Text('licence_' .. kind)
    Db.Log('licence', targetOf(target), 0, (on and 'Granted ' or 'Revoked ') .. kind, officer)
    Framework.Notify(target, Text(on and 'licence_granted_you' or 'licence_revoked_you', { kind = label }), on and 'success' or 'error')
    return true, Text(on and 'licence_granted' or 'licence_revoked', { kind = label })
end

Actions.licenceSet = function(officer, target, extra)
    if not WheelLayout.Allowed(officer.src, 'licences') then return false, Text('err_not_allowed') end
    return Field.SetLicence(officer, target, extra and extra.kind, extra and extra.on == true)
end

Actions.tracker = function(officer, target)
    if not (Config.Tracker or {}).enabled then return false, Text('err_failed') end
    local on = Framework.GetMetaData(target, 'tracker') ~= true
    if on and not Field.Restrained(target) then return false, Text('err_not_restrained') end
    Framework.SetMetaData(target, 'tracker', on)
    Framework.Notify(target, Text(on and 'tracker_on_you' or 'tracker_off_you'), 'inform')
    Db.Log('tracker', targetOf(target), 0, on and 'Ankle monitor on' or 'Ankle monitor off', officer)
    return true, Text(on and 'tracker_on' or 'tracker_off', { name = Framework.GetName(target) or '' })
end

Actions.service = function(officer, target, extra)
    if not Field.Restrained(target) then return false, Text('err_not_restrained') end
    return Service.Send(target, extra and extra.tasks, extra and extra.reason, officer)
end

Actions.solitary = function(officer, target)
    return Prison.Solitary(officer, target)
end

Actions.fine = function(officer, target, extra)
    local amount = math.floor(tonumber(extra and extra.amount) or 0)
    local reason = Util.Text(extra and extra.reason, 120)
    if amount <= 0 or amount > (Config.Fines.max or 50000) then return false, Text('err_amount') end
    if reason == '' then return false, Text('err_need_reason') end
    local key = ('%s:%s'):format(officer.src, target)
    if Field.fineAt[key] and os.time() - Field.fineAt[key] < 30 then return false, Text('err_slow_down') end
    local primary = Config.Fines.account == 'cash' and 'cash' or 'bank'
    local other = primary == 'cash' and 'bank' or 'cash'
    local paid = Framework.RemoveMoney(target, primary, amount, 'Police fine')
    if not paid then paid = Framework.RemoveMoney(target, other, amount, 'Police fine') end
    if not paid and Config.Fines.allowDebt then
        local player = Framework.GetPlayer(target)
        paid = player and player.Functions.RemoveMoney('bank', amount, 'Police fine') ~= false or false
    end
    if not paid then return false, Text('err_cannot_pay') end
    Field.fineAt[key] = os.time()
    if Config.Fines.society and Banking.name then Banking.Deposit(officer.job, amount, 'Fine: ' .. reason) end
    Db.Log('fine', targetOf(target), amount, reason, officer)
    TriggerEvent('XS-PoliceSystem:server:fined', target, amount, reason, officer.src)
    Framework.Notify(target, Text('fined_you', { amount = amount, reason = reason }), 'error')
    return true, Text('fined', { amount = amount })
end

Actions.rob = function(officer, target)
    if not Field.Restrained(target) then return false, Text('err_not_restrained') end
    if not Inventory.OpenPlayer(officer.src, target) then return false, Text('err_failed') end
    Framework.Notify(target, Text('being_robbed'), 'error')
    return true
end

Actions.seizeLicense = function(officer, target)
    local licences = Framework.GetMetaData(target, 'licences') or {}
    if licences.driver == false then return false, Text('err_no_licence') end
    licences.driver = false
    Framework.SetMetaData(target, 'licences', licences)
    Db.Log('licence', targetOf(target), 0, 'Driving licence seized', officer)
    Framework.Notify(target, Text('licence_seized_you'), 'error')
    return true, Text('licence_seized')
end

Actions.jail = function(officer, target, extra)
    if not Config.Jail.enabled then return false, Text('err_jail_off') end
    if not officer.isBoss and (officer.grade or 0) < ((Config.Grades or {}).jail or 0) then return false, Text('err_grade') end
    if not Field.IsCuffed(target) then return false, Text('err_not_cuffed') end
    return Jail.Send(target, tonumber(extra and extra.months) or 0, extra and extra.reason, officer)
end

local CIVILIAN = { cuff = true, escort = true, putInVehicle = true, takeOutVehicle = true, rob = true }

function Field.Act(src, name, target, extra)
    if not Actions[name] then return false, Text('err_failed') end
    if Field.IsCuffed(src) or Field.IsDown(src) or Jail.IsInmate(src) then return false, Text('err_cannot_now') end
    local officer = officerOf(src)
    if not officer then
        if not CIVILIAN[name] or (name ~= 'rob' and not Config.Cuffs.civilians) then return false, Text('err_police_only') end
        officer = civilianOf(src)
    end
    if officer.cop and not WheelLayout.Allowed(src, name) then return false, Text('err_not_allowed') end
    if not throttle(src) then return false, Text('err_slow_down') end
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return false, Text('err_no_player') end
    local range = name == 'takeOutVehicle' and 8.0 or nil
    if not near(src, target, range) then return false, Text('err_too_far') end
    return Actions[name](officer, target, extra)
end

function Field.Closest(src, range)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local at = GetEntityCoords(ped)
    local best, bestDist = nil, range or 2.5
    for _, other in ipairs(GetPlayers()) do
        other = tonumber(other)
        if other ~= src then
            local op = GetPlayerPed(other)
            if op ~= 0 then
                local d = #(GetEntityCoords(op) - at)
                if d <= bestDist then best, bestDist = other, d end
            end
        end
    end
    return best
end

lib.callback.register('XS-PoliceSystem:server:action', Field.Act)

local function plateOf(vehicle)
    return Util.Text(GetVehicleNumberPlateText(vehicle), 16)
end

local function trim(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

lib.callback.register('XS-PoliceSystem:server:checkPlate', function(src, netId)
    local officer = officerOf(src)
    if not officer then return false, Text('err_police_only') end
    if not WheelLayout.Allowed(src, 'checkPlate') then return false, Text('err_not_allowed') end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
    local plate = trim(plateOf(vehicle))
    local flag = Plates.Get(plate)
    local row = MySQL.single.await('SELECT `citizenid`, `vehicle` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { plate, plateOf(vehicle) })
    if not row then return true, { plate = plate, owner = nil, flag = flag and flag.reason or nil } end
    local owner = Framework.GetPlayerByCitizenId(row.citizenid)
    local name
    if owner then
        name = Framework.FullName(owner.PlayerData.charinfo)
    else
        local p = MySQL.single.await('SELECT `charinfo` FROM `players` WHERE `citizenid` = ?', { row.citizenid })
        name = p and Framework.FullName(Db.Decode(p.charinfo, {})) or ''
    end
    return true, { plate = plate, owner = name, model = row.vehicle, flag = flag and flag.reason or nil, wanted = Links.Warrants(row.citizenid) }
end)

RegisterNetEvent('XS-PoliceSystem:server:shot', function()
    local src = source
    local cid = Framework.GetCitizenId(src)
    if cid then Field.gsr[cid] = os.time() end
end)

RegisterNetEvent('XS-PoliceSystem:server:washed', function()
    local cid = Framework.GetCitizenId(source)
    if cid and Config.Gsr.waterClears then Field.gsr[cid] = nil end
end)

local function leave(src)
    if Field.escorts[src] then Field.StopEscort(src) end
    for target, officer in pairs(Field.escorts) do
        if officer == src then Field.StopEscort(target) end
    end
    Field.lastAction[src] = nil
end

Framework.OnUnloaded(function(src)
    leave(src)
    Field.cuffing[src] = nil
    local bag = Player(src).state
    if bag.xspCuffed then
        bag:set('xspCuffed', false, true)
        bag:set('invBusy', false, true)
    end
end)

Framework.OnLoaded(function(src)
    if not Field.IsCuffed(src) then return end
    local bag = Player(src).state
    bag:set('xspCuffed', true, true)
    bag:set('invBusy', true, true)
end)

exports('IsHandcuffed', function(src) return Field.IsCuffed(tonumber(src)) end)
exports('SetHandcuffed', function(src, on) Field.SetCuffed(tonumber(src), on == true) end)
exports('IsEscorted', function(src) return Field.escorts[tonumber(src)] ~= nil end)

InmateClient = { peds = {}, busy = false, shop = nil, stopped = false }

local NPC_KINDS = { 'guard', 'clerk', 'trader' }
local RANGE = 120.0

local function J()
    return Config.Jail or {}
end

local function v3(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end

local function drop(key)
    local entry = InmateClient.peds[key]
    if entry and DoesEntityExist(entry.ped) then DeleteEntity(entry.ped) end
    InmateClient.peds[key] = nil
end

local function scenario(ped, def)
    if def.scenario and def.scenario ~= '' then TaskStartScenarioInPlace(ped, def.scenario, 0, true) end
end

local function spawn(def, p)
    if not def or not def.model or not Util.LoadModel(def.model) then return nil end
    local hash = joaat(def.model)
    local ped = CreatePed(4, hash, p.x + 0.0, p.y + 0.0, p.z + 0.0, (p.w or 0.0) + 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    SetEntityAsMissionEntity(ped, true, true)
    scenario(ped, def)
    return ped
end

local function patrol(entry, def)
    local ped = entry.ped
    local target = entry.route[entry.leg]
    if not target then return end
    local now = GetGameTimer()
    if #(GetEntityCoords(ped) - v3(target)) < 1.6 then
        if not entry.waitUntil then
            entry.waitUntil = now + math.random(8000, 16000)
            SetEntityHeading(ped, (target.w or 0.0) + 0.0)
            scenario(ped, def)
        elseif now > entry.waitUntil then
            entry.waitUntil = nil
            entry.leg = entry.leg % #entry.route + 1
            local nextAt = entry.route[entry.leg]
            ClearPedTasks(ped)
            TaskGoStraightToCoord(ped, nextAt.x + 0.0, nextAt.y + 0.0, nextAt.z + 0.0, 1.0, -1, (nextAt.w or 0.0) + 0.0, 0.5)
        end
    elseif not entry.walking or now - entry.walking > 20000 then
        entry.walking = now
        TaskGoStraightToCoord(ped, target.x + 0.0, target.y + 0.0, target.z + 0.0, 1.0, -1, (target.w or 0.0) + 0.0, 0.5)
    end
end

CreateThread(function()
    while true do
        local c = GetEntityCoords(PlayerPedId())
        local wanted = {}
        local npcs = J().npcs or {}
        for _, place in ipairs(Me.places or {}) do
            if place.kind == 'jail' then
                for _, kind in ipairs(NPC_KINDS) do
                    local def = npcs[kind]
                    local list = place.points[kind] or {}
                    for i, p in ipairs(def and list or {}) do
                        local key = ('%s_%s_%s'):format(place.id, kind, p.id)
                        if #(c - v3(p)) < RANGE then
                            wanted[key] = true
                            local entry = InmateClient.peds[key]
                            if not entry or not DoesEntityExist(entry.ped) then
                                local ped = spawn(def, p)
                                if ped then
                                    entry = { ped = ped, kind = kind, leg = 1 }
                                    if kind == 'guard' and def.patrol and #list > 1 then
                                        entry.route = { p, list[i % #list + 1] }
                                        entry.leg = 2
                                        entry.waitUntil = GetGameTimer() + math.random(2000, 12000)
                                    end
                                    InmateClient.peds[key] = entry
                                end
                            elseif entry.route then
                                patrol(entry, def)
                            end
                        end
                    end
                end
            end
        end
        for key in pairs(InmateClient.peds) do
            if not wanted[key] then drop(key) end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for key in pairs(InmateClient.peds) do drop(key) end
end)

RegisterNetEvent('XS-PoliceSystem:client:jailCredit', function(credit)
    if JailClient.state then JailClient.state.credit = tonumber(credit) or 0 end
    UI.Send('jail', 'credit', { credit = tonumber(credit) or 0 })
end)

local function progress(seconds, label, anim)
    local done = lib.progressCircle({
        duration = math.floor((tonumber(seconds) or 10) * 1000), label = label, position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = anim,
    })
    ClearPedTasks(PlayerPedId())
    return done
end

local function open(kind, p, name)
    local ok, data = Me.Await(name, p.id)
    if not ok then return Framework.Notify(data or Text('err_failed'), 'error') end
    data.point = p.id
    InmateClient.shop = { kind = kind, point = p.id }
    Panels.Open('prisonshop', data)
end

function InmateClient.Stash(name, p)
    local ok, info = Me.Await(name, p.id)
    if not ok then return Framework.Notify(info or Text('err_failed'), 'error') end
    Inventory.OpenStash(info.mode, info.id, info.label, info.slots, info.weight)
end

function InmateClient.Commissary(p) open('commissary', p, 'commissary') end
function InmateClient.Trader(p) open('trader', p, 'trader') end
function InmateClient.Workbench(p) open('craft', p, 'workbench') end

UI.Handle('prisonshop:buy', function(d)
    if type(d) ~= 'table' then return false end
    return Me.Await('commissaryBuy', d.point, d.id, d.qty)
end)

UI.Handle('prisonshop:people', function(d)
    if type(d) ~= 'table' then return false end
    return Me.Await('commissaryPeople', d.point, d.query)
end)

UI.Handle('prisonshop:call', function(d)
    if type(d) ~= 'table' then return false end
    return Me.Await('commissaryCall', d.point, d.id, d.target, d.message)
end)

UI.Handle('prisonshop:deal', function(d)
    if type(d) ~= 'table' then return false end
    return Me.Await('traderDeal', d.point, d.side, d.id, d.qty)
end)

RegisterNetEvent('XS-PoliceSystem:client:inmateStop', function(message)
    if InmateClient.busy then
        InmateClient.stopped = true
        JailClient.Stop()
    end
    if message then Framework.Notify(message, 'error') end
end)

UI.Handle('prisonshop:craft', function(d)
    if type(d) ~= 'table' or InmateClient.busy then return false end
    local ok, info = Me.Await('craftStart', d.point, d.id)
    if not ok then return false, info end
    Panels.Close('prisonshop')
    CreateThread(function()
        InmateClient.busy, InmateClient.stopped = true, false
        local done = progress(info.seconds, Text('crafting', { item = info.label }), { scenario = 'PROP_HUMAN_BUM_BIN' })
        InmateClient.busy = false
        if not done or not JailClient.Inside() then return end
        local okDone, msg = Me.Await('craft', d.point, d.id)
        Me.Result(okDone, msg)
    end)
    return true
end)

local function through(info)
    DoScreenFadeOut(400)
    Wait(600)
    DoScreenFadeIn(800)
    Framework.Notify(info.message or Text('breakout_through'), 'success')
end

function InmateClient.Dig(kind, p)
    if InmateClient.busy or not JailClient.Inside() then return end
    InmateClient.busy, InmateClient.stopped = true, false
    local ok, info = Me.Await('digStart', kind, p.id)
    if not ok then
        InmateClient.busy = false
        return Framework.Notify(info or Text('err_failed'), 'error')
    end
    if info.ready then
        InmateClient.busy = false
        local crawl = lib.alertDialog({ header = Text('tunnel_ready_title'), content = Text('tunnel_ready_text'), centered = true, cancel = true })
        if crawl ~= 'confirm' then return end
        local okGo, res = Me.Await('crawl', p.id)
        if not okGo then return Framework.Notify(res or Text('err_failed'), 'error') end
        return through(res)
    end
    SetEntityHeading(PlayerPedId(), (p.w or 0.0) + 0.0)
    local anim = kind == 'tunnel' and { scenario = 'WORLD_HUMAN_GARDENER_PLANT' } or { scenario = 'WORLD_HUMAN_WELDING' }
    local done = progress(info.seconds, Text(kind == 'tunnel' and 'tunnel_digging' or 'fence_cutting'), anim)
    InmateClient.busy = false
    if not done then
        if not InmateClient.stopped then TriggerServerEvent('XS-PoliceSystem:server:digStop') end
        return
    end
    if not JailClient.Inside() then return end
    local okDone, res = Me.Await('dig', kind, p.id)
    if not okDone then return Framework.Notify(res or Text('err_failed'), 'error') end
    if res.through then return through(res) end
    if res.snapped then Framework.Notify(Text('tool_snapped', { item = res.item }), 'error') end
    if res.done then
        Framework.Notify(Text('tunnel_done'), 'success')
    else
        Framework.Notify(Text('tunnel_progress', { done = res.progress, total = res.sessions }), 'inform')
    end
end

Forensics = { drops = {}, busy = false }

local GROUPS = {
    [Util.Hash('GROUP_PISTOL')] = 'pistol',
    [Util.Hash('GROUP_SMG')] = 'smg',
    [Util.Hash('GROUP_RIFLE')] = 'rifle',
    [Util.Hash('GROUP_MG')] = 'mg',
    [Util.Hash('GROUP_SHOTGUN')] = 'shotgun',
    [Util.Hash('GROUP_SNIPER')] = 'sniper',
}
local COLOURS = { casing = { 226, 180, 78 }, blood = { 176, 18, 30 }, print = { 112, 192, 255 } }
local FLASHLIGHT = `WEAPON_FLASHLIGHT`
local BEAM = math.cos(math.rad(28))

local NO_GLOVES = {
    male = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [18] = true, [26] = true, [52] = true, [53] = true, [54] = true, [55] = true, [56] = true, [57] = true, [58] = true, [59] = true, [60] = true, [61] = true, [62] = true, [112] = true, [113] = true, [114] = true, [118] = true, [125] = true, [132] = true },
    female = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [19] = true, [59] = true, [60] = true, [61] = true, [62] = true, [63] = true, [64] = true, [65] = true, [66] = true, [67] = true, [68] = true, [69] = true, [70] = true, [71] = true, [129] = true, [130] = true, [131] = true, [135] = true, [142] = true, [149] = true, [153] = true, [157] = true, [161] = true, [165] = true },
}

local function cfg()
    return Config.Forensics or {}
end

function Forensics.Bare()
    local ok, gloved = pcall(function()
        local core = Framework.core or exports['qb-core']:GetCoreObject()
        return core.Functions.IsWearingGloves()
    end)
    if ok and type(gloved) == 'boolean' then return not gloved end
    local ped = PlayerPedId()
    local arms = GetPedDrawableVariation(ped, 3)
    local list = GetEntityModel(ped) == `mp_m_freemode_01` and NO_GLOVES.male or NO_GLOVES.female
    return list[arms] == true
end

lib.callback.register('XS-PoliceSystem:client:bare', function()
    return Forensics.Bare()
end)

local function ground(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if found == true or found == 1 then return gz end
    return z - 0.95
end

local pending, sentAt = 0, 0
function Forensics.Shot(ped, weapon)
    local c = cfg()
    if not c.enabled or not c.casings or not Evidence.Ours() then return end
    local group = GROUPS[Util.U32(GetWeapontypeGroup(weapon))]
    if not group then return end
    pending = pending + 1
    local now = GetGameTimer()
    if now - sentAt < 400 then return end
    sentAt = now
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.5 + math.random() * 0.9, (math.random() - 0.5) * 1.2, 0.0)
    TriggerServerEvent('XS-PoliceSystem:server:casing', weapon, group, { x = at.x, y = at.y, z = ground(at.x, at.y, at.z) + 0.02 }, pending, Forensics.Bare())
    pending = 0
end

local lastHealth, bleedAt, trailAt, trailPos = 200, 0, 0, nil

local function bleed(ped)
    if not Evidence.Ours() then return end
    local c = GetEntityCoords(ped)
    local x, y = c.x + (math.random() - 0.5) * 0.6, c.y + (math.random() - 0.5) * 0.6
    TriggerServerEvent('XS-PoliceSystem:server:bleed', { x = x, y = y, z = ground(x, y, c.z) + 0.02 })
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local c = cfg()
    local ped = PlayerPedId()
    if not c.enabled or not c.blood or args[1] ~= ped then return end
    local health = GetEntityHealth(ped)
    local lost = lastHealth - health
    lastHealth = health
    if lost < 5 then return end
    local now = GetGameTimer()
    if now - bleedAt < 4000 or math.random(100) > (c.bloodChance or 70) then return end
    bleedAt = now
    bleed(ped)
end)

CreateThread(function()
    while true do
        Wait(1000)
        local c = cfg()
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped)
        if health > lastHealth then lastHealth = health end
        if c.enabled and c.blood and c.bloodTrail and health > 100 and health <= (c.trailHealth or 150)
            and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) then
            local pos = GetEntityCoords(ped)
            local now = GetGameTimer()
            if now - trailAt > 6000 and (not trailPos or #(pos - trailPos) > 4.0) then
                trailAt, trailPos = now, pos
                bleed(ped)
            end
        end
    end
end)

CreateThread(function()
    local last = 0
    while true do
        Wait(1000)
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 and vehicle ~= last and cfg().enabled and Evidence.Ours() and Forensics.Bare() then
            local netId = Me.NetId(vehicle)
            if netId then TriggerServerEvent('XS-PoliceSystem:server:touched', netId) end
        end
        last = vehicle
    end
end)

function Forensics.Dust()
    local vehicle = Me.NearestVehicle(4.0)
    if not vehicle or vehicle == 0 or GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    local done = lib.progressCircle({
        duration = (cfg().dustSeconds or 6) * 1000, label = Text('dusting'), position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    })
    ClearPedTasks(PlayerPedId())
    if not done then return end
    local ok, msg = Me.Await('dustPrints', Me.NetId(vehicle))
    if ok then Inventory.Invalidate() end
    Me.Result(ok, msg)
end

function Forensics.Bleach()
    local done = lib.progressCircle({
        duration = (cfg().bleachSeconds or 8) * 1000, label = Text('bleaching'), position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = { scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    })
    ClearPedTasks(PlayerPedId())
    if not done then return end
    local ok, msg = Me.Await('bleach')
    if ok then Inventory.Invalidate() end
    Me.Result(ok, msg)
end

RegisterNetEvent('XS-PoliceSystem:client:evidence', function(action, data)
    if action == 'add' and type(data) == 'table' and data.id then
        data.seenAt = GetGameTimer()
        Forensics.drops[data.id] = data
    elseif action == 'remove' then
        for _, id in ipairs(type(data) == 'table' and data or { data }) do Forensics.drops[id] = nil end
    end
end)

local function sync()
    local list = Me.Await('forensics')
    Forensics.drops = {}
    local now = GetGameTimer()
    for _, d in ipairs(type(list) == 'table' and list or {}) do
        d.seenAt = now
        Forensics.drops[d.id] = d
    end
end

local function lit(ped)
    return GetSelectedPedWeapon(ped) == FLASHLIGHT or IsFlashLightOn(ped)
end

local function camForward()
    local rot = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

local function scan()
    local c = cfg()
    local ped = PlayerPedId()
    local needLight = c.flashlight ~= false
    if needLight and not lit(ped) then return {} end
    local pos = GetEntityCoords(ped)
    local cam, fwd = GetGameplayCamCoord(), camForward()
    local range = c.range or 12.0
    local out = {}
    for _, d in pairs(Forensics.drops) do
        local at = vector3(d.x, d.y, d.z)
        local dist = #(pos - at)
        if dist <= range then
            local seen = not needLight or dist <= 1.8
            if not seen then
                local dir = at - cam
                local len = #dir
                seen = len > 0 and (dir.x * fwd.x + dir.y * fwd.y + dir.z * fwd.z) / len >= BEAM
            end
            if seen then out[#out + 1] = { d = d, dist = dist } end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

local function title(d)
    if d.kind == 'casing' then
        return (d.count or 1) > 1 and Text('evidence_casings', { count = d.count }) or Text('evidence_casing')
    end
    return Text(d.kind == 'blood' and 'evidence_blood' or 'evidence_print')
end

local function text3d(x, y, z, text, scale)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

local function draw(list)
    for i, e in ipairs(list) do
        if i > 30 then break end
        local d = e.d
        local col = COLOURS[d.kind] or COLOURS.print
        DrawMarker(25, d.x, d.y, d.z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.42, 0.42, 0.42, col[1], col[2], col[3], 190, false, false, 2, false, nil, nil, false)
        DrawMarker(28, d.x, d.y, d.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.035, 0.035, 0.035, col[1], col[2], col[3], 230, false, false, 2, false, nil, nil, false)
        if e.dist < 5.0 then
            text3d(d.x, d.y, d.z + 0.3, title(d) .. (d.kind == 'casing' and d.calibre and ('~n~~c~' .. d.calibre) or ''), 0.3)
        end
    end
end

local function streetAt(d)
    local s1, s2 = GetStreetNameAtCoord(d.x, d.y, d.z)
    local street = GetStreetNameFromHashKey(s1) or ''
    local cross = s2 and s2 ~= 0 and GetStreetNameFromHashKey(s2) or ''
    if cross ~= '' then street = street .. ' / ' .. cross end
    return street
end

local function collect(d)
    if Forensics.busy then return end
    Forensics.busy = true
    local ped = PlayerPedId()
    if Util.LoadAnim('pickup_object') then
        TaskPlayAnim(ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 1200, 0, 0.0, false, false, false)
    end
    local done = lib.progressCircle({
        duration = 1500, label = Text('evidence_bagging'), position = 'bottom', canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    if done then
        local ok, msg = Me.Await('forensicsCollect', d.id, streetAt(d))
        if ok then
            Forensics.drops[d.id] = nil
            Inventory.Invalidate()
        end
        Me.Result(ok, msg)
    end
    Forensics.busy = false
end

local noteShown, noteAt = false, 0

local function note(e)
    local now = GetGameTimer()
    if not e then
        if noteShown then UI.Send('fieldnote', 'hide', {}) end
        noteShown = false
        return
    end
    if noteShown and now - noteAt < 400 then return end
    noteShown, noteAt = true, now
    local d = e.d
    local age = (tonumber(d.age) or 0) + math.floor((now - (d.seenAt or now)) / 1000)
    UI.Send('fieldnote', 'show', {
        id = d.id, kind = d.kind, calibre = d.calibre, group = d.group, count = d.count, marked = d.marked == true, quality = d.quality,
        age = math.floor(age / 30) * 30, reach = e.dist <= 1.6 and not IsPedInAnyVehicle(PlayerPedId(), false),
    })
end

CreateThread(function()
    local visible, nextScan, wasCop = {}, 0, false
    while true do
        local c = cfg()
        local cop = c.enabled == true and Framework.Loaded() and Me.IsCop()
        if cop ~= wasCop then
            wasCop = cop
            if cop then sync() else Forensics.drops = {} end
        end
        if not cop or not next(Forensics.drops) then
            visible = {}
            note(nil)
            Wait(1000)
        else
            local now = GetGameTimer()
            if now >= nextScan then visible, nextScan = scan(), now + 250 end
            if #visible == 0 then
                note(nil)
                Wait(200)
            else
                draw(visible)
                local near = visible[1]
                note(near.dist <= 3.0 and not Forensics.busy and near or nil)
                if near.dist <= 1.6 and not Forensics.busy and not IsPedInAnyVehicle(PlayerPedId(), false) then
                    if IsControlJustReleased(0, c.collectKey or 38) then
                        local target = near.d
                        CreateThread(function() collect(target) end)
                    end
                end
                Wait(0)
            end
        end
    end
end)

local function useHandcuffs()
    if Me.IsCop() then return Field.Run('cuff') end
    local target = Me.NearestPlayer(Config.Wheel.range or 3.0)
    if not target then return Framework.Notify(Text('err_nobody_near'), 'error') end
    local ok, msg = Me.Await('action', 'cuff', target)
    Me.Result(ok, type(msg) == 'string' and msg or nil)
end

local KNIFE = `WEAPON_KNIFE`
local shiv = { out = false, owned = false }

local function putShivAway()
    if not shiv.out then return end
    shiv.out = false
    local ped = PlayerPedId()
    if shiv.owned then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    else
        RemoveWeaponFromPed(ped, KNIFE)
    end
end

local function useShiv()
    if shiv.out then return putShivAway() end
    if Field.cuffed or IsPedInAnyVehicle(PlayerPedId(), false) then return end
    local ped = PlayerPedId()
    shiv.owned = HasPedGotWeapon(ped, KNIFE, false) == true
    if not shiv.owned then GiveWeaponToPed(ped, KNIFE, 0, false, true) end
    SetCurrentPedWeapon(ped, KNIFE, true)
    shiv.out = true
    CreateThread(function()
        while shiv.out do
            Wait(1500)
            if GetSelectedPedWeapon(PlayerPedId()) ~= KNIFE or Inventory.Count('prison_shiv') < 1 then putShivAway() end
        end
    end)
end

local USES = {
    handcuffs = function() CreateThread(useHandcuffs) end,
    spikestrip = function() Field.Run('spikes') end,
    bleach = function() CreateThread(Forensics.Bleach) end,
    prison_shiv = function() CreateThread(useShiv) end,
}

local function use(name)
    if Config.Cuffs.item and name == Config.Cuffs.item then name = 'handcuffs' end
    if Config.Spikes.item and name == Config.Spikes.item then name = 'spikestrip' end
    if (Config.Forensics or {}).bleach and name == Config.Forensics.bleach then name = 'bleach' end
    local fn = USES[name]
    if fn then fn() end
end

exports('useItem', function(data) use(type(data) == 'table' and data.name or data) end)

RegisterNetEvent('XS-PoliceSystem:client:useItem', use)

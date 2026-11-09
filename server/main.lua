lib.callback.register('XS-PoliceSystem:server:places', function()
    return Places.List()
end)

local function canRelease(src, target)
    if src == 0 then return true end
    if src == target or Jail.IsInmate(src) then return false end
    if Framework.IsAdmin(src) then return true end
    local job = Framework.GetJob(src)
    if not Framework.IsCop(job) then return false end
    return job.isBoss or (job.grade or 0) >= ((Config.Grades or {}).jail or 0)
end

lib.addCommand('unjail', {
    help = Text('cmd_unjail'),
    params = { { name = 'id', type = 'playerId', help = Text('cmd_player_id') } },
}, function(src, args)
    local target = tonumber(args.id)
    if not canRelease(src, target) then return Framework.Notify(src, Text('err_police_only'), 'error') end
    if not target or not Jail.inmates[target] then return Framework.Notify(src, Text('err_not_in_jail'), 'error') end
    Jail.Release(target, 'released')
    Framework.Notify(src, Text('unjailed'), 'success')
end)

CreateThread(function()
    if not Framework.name then return end
    if not Db.Setup() then
        print('^1[XS-PoliceSystem]^0 Database setup failed. Check that oxmysql is running and can reach your database.')
        return
    end
    Settings.Load()
    Places.Load()
    WheelLayout.Load()
    Plates.Load()
    Duty.Broadcast()
    Jail.LoadOnline()
    local stations, jails, lots = #Places.List('station'), #Places.List('jail'), #Places.List('impound')
    print(('^2[XS-PoliceSystem]^0 ready: %d station(s), %d jail(s), %d impound lot(s). Build them in game with /%s.'):format(stations, jails, lots, Config.Admin.command or 'policebuilder'))
end)

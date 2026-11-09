fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-PoliceSystem'
author 'XyraL'
description 'A complete police job and jail for Qbox and QBCore. Replaces qbx_police, qb-policejob and qb-prison.'
version '1.0.0'

provide 'qb-policejob'
provide 'qbx_police'
provide 'qb-prison'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'shared/locale.lua',
    'shared/util.lua',
    'shared/points.lua',
    'shared/wheel.lua',
    'shared/settings.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/target.lua',
    'bridge/keys.lua',
    'bridge/fuel.lua',
    'bridge/clothing.lua',
    'bridge/mdt.lua',
    'bridge/evidence.lua',
    'client/ui.lua',
    'client/settings.lua',
    'client/main.lua',
    'client/placement.lua',
    'client/panels.lua',
    'client/stations.lua',
    'client/field.lua',
    'client/impound.lua',
    'client/props.lua',
    'client/forensics.lua',
    'client/gsr.lua',
    'client/units.lua',
    'client/tackle.lua',
    'client/status.lua',
    'client/cameras.lua',
    'client/unitcams.lua',
    'client/heli.lua',
    'client/radar.lua',
    'client/scene.lua',
    'client/k9.lua',
    'client/service.lua',
    'client/prison.lua',
    'client/mugshot.lua',
    'client/jail.lua',
    'client/inmate.lua',
    'client/wheel.lua',
    'client/builder.lua',
    'client/compat.lua',
    'client/items.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/keys.lua',
    'bridge/banking.lua',
    'bridge/dispatch.lua',
    'bridge/evidence.lua',
    'server/db.lua',
    'server/settings.lua',
    'server/places.lua',
    'server/duty.lua',
    'server/stations.lua',
    'server/boss.lua',
    'server/field.lua',
    'server/props.lua',
    'server/jail.lua',
    'server/impound.lua',
    'server/status.lua',
    'server/plates.lua',
    'server/scene.lua',
    'server/k9.lua',
    'server/forensics.lua',
    'server/lab.lua',
    'server/prison.lua',
    'server/inmate.lua',
    'server/service.lua',
    'server/mugshot.lua',
    'server/dutyclock.lua',
    'server/links.lua',
    'server/units.lua',
    'server/unitcams.lua',
    'server/tackle.lua',
    'server/compat.lua',
    'server/builder.lua',
    'server/wheel.lua',
    'server/commands.lua',
    'server/items.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/wheel/*.png',
}

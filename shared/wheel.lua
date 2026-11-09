WheelDefs = {}

WheelDefs.Actions = {
    cuff = { icon = 'cuffs' },
    escort = { icon = 'escort' },
    search = { icon = 'search' },
    idcheck = { icon = 'id' },
    gsr = { icon = 'gsr' },
    fingerprint = { icon = 'fingerprint' },
    breathalyzer = { icon = 'breath' },
    drugswab = { icon = 'drugtest' },
    licences = { icon = 'licence' },
    tracker = { icon = 'anklet' },
    flagPlate = { icon = 'flag' },
    cameras = { icon = 'cctv' },
    unitCams = { icon = 'cctv' },
    service = { icon = 'vest' },
    solitary = { icon = 'solitary' },
    searchVehicle = { icon = 'trunk' },
    dustPrints = { icon = 'dust' },
    slowTraffic = { icon = 'slow' },
    stopTraffic = { icon = 'stop' },
    k9Call = { icon = 'k9' },
    k9Follow = { icon = 'leash' },
    k9Search = { icon = 'search' },
    k9Attack = { icon = 'bitesleeve' },
    k9Car = { icon = 'seat' },
    k9Track = { icon = 'paw' },
    k9Guard = { icon = 'k9badge' },
    k9Bark = { icon = 'whistle' },
    seize = { icon = 'cash' },
    putInVehicle = { icon = 'seat' },
    takeOutVehicle = { icon = 'exit' },
    checkPlate = { icon = 'plate' },
    impound = { icon = 'tow' },
    cone = { icon = 'cone' },
    barrier = { icon = 'barrier' },
    spikes = { icon = 'spikes' },
    removeProp = { icon = 'remove' },
    fine = { icon = 'fine' },
    jail = { icon = 'jail' },
    mdt = { icon = 'mdt' },
    panic = { icon = 'panic', danger = true },
}

WheelDefs.Order = {
    'cuff', 'escort', 'search', 'idcheck', 'gsr', 'fingerprint', 'breathalyzer', 'drugswab', 'licences', 'tracker', 'seize',
    'putInVehicle', 'takeOutVehicle', 'checkPlate', 'flagPlate', 'searchVehicle', 'dustPrints', 'cameras', 'unitCams', 'slowTraffic', 'stopTraffic',
    'k9Call', 'k9Follow', 'k9Search', 'k9Attack', 'k9Car', 'service', 'solitary',
    'impound', 'cone', 'barrier', 'spikes', 'removeProp', 'fine', 'jail', 'mdt', 'panic',
}

WheelDefs.Pages = {
    person = { icon = 'person' },
    vehicle = { icon = 'car' },
    scene = { icon = 'cone' },
    paperwork = { icon = 'paper' },
    k9 = { icon = 'k9' },
}

WheelDefs.Icons = {
    'cuffs', 'escort', 'search', 'person', 'car', 'cone', 'paper', 'panic', 'id', 'gsr', 'cash',
    'seat', 'exit', 'plate', 'tow', 'barrier', 'spikes', 'remove', 'fine', 'jail', 'mdt', 'fingerprint', 'breath', 'drugtest', 'licence', 'anklet', 'flag', 'cctv',
    'trunk', 'slow', 'stop', 'k9', 'leash', 'bitesleeve', 'dust', 'vest', 'solitary', 'paw', 'k9badge', 'whistle',
}

WheelDefs.Added = { 'k9Track', 'k9Guard', 'k9Bark' }

WheelDefs.Kinds = { command = true, client = true, server = true }

function WheelDefs.Default()
    return {
        pages = {
            { id = 'root', items = { 'cuff', 'escort', 'search', '@person', '@vehicle', '@scene', '@paperwork', 'mdt', 'panic' } },
            { id = 'person', items = { 'idcheck', 'gsr', 'fingerprint', 'breathalyzer', 'drugswab', 'licences', 'tracker', 'seize' } },
            { id = 'vehicle', items = { 'putInVehicle', 'takeOutVehicle', 'searchVehicle', 'dustPrints', 'checkPlate', 'flagPlate', 'impound' } },
            { id = 'scene', items = { 'cone', 'barrier', 'spikes', 'removeProp', 'slowTraffic', 'stopTraffic', '@k9' } },
            { id = 'k9', items = { 'k9Call', 'k9Follow', 'k9Search', 'k9Track', 'k9Attack', 'k9Guard', 'k9Bark', 'k9Car' } },
            { id = 'paperwork', items = { 'fine', 'jail', 'service', 'solitary', 'cameras', 'unitCams' } },
        },
        actions = {},
        custom = {},
    }
end

function WheelDefs.IsIcon(name)
    for _, icon in ipairs(WheelDefs.Icons) do
        if icon == name then return true end
    end
    return false
end

function WheelDefs.Permits(limits, job)
    if type(limits) ~= 'table' then return true end
    if not job then return false end
    if type(limits.jobs) == 'table' and #limits.jobs > 0 then
        local listed = false
        for _, name in ipairs(limits.jobs) do
            if name == job.name then listed = true break end
        end
        if not listed then return false end
    end
    if job.isBoss then return true end
    return (tonumber(job.grade) or 0) >= (tonumber(limits.grade) or 0)
end

Db = { ready = false }

local TABLES = {
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_places` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(16) NOT NULL,
            `name` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_inmates` (
            `citizenid` VARCHAR(64) NOT NULL,
            `name` VARCHAR(96) NOT NULL DEFAULT '',
            `jail_id` INT NOT NULL DEFAULT 0,
            `months` INT NOT NULL DEFAULT 0,
            `seconds_left` INT NOT NULL DEFAULT 0,
            `reason` VARCHAR(255) NOT NULL DEFAULT '',
            `officer_name` VARCHAR(96) NOT NULL DEFAULT '',
            `items` LONGTEXT NULL,
            `look` LONGTEXT NULL,
            `escaped` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_log` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `kind` VARCHAR(16) NOT NULL,
            `citizenid` VARCHAR(64) NOT NULL DEFAULT '',
            `name` VARCHAR(96) NOT NULL DEFAULT '',
            `amount` INT NOT NULL DEFAULT 0,
            `detail` VARCHAR(255) NOT NULL DEFAULT '',
            `officer_cid` VARCHAR(64) NOT NULL DEFAULT '',
            `officer_name` VARCHAR(96) NOT NULL DEFAULT '',
            `job` VARCHAR(32) NOT NULL DEFAULT '',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `job` (`job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_settings` (
            `name` VARCHAR(32) NOT NULL,
            `data` LONGTEXT NOT NULL,
            PRIMARY KEY (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_service` (
            `citizenid` VARCHAR(64) NOT NULL,
            `place_id` INT NOT NULL DEFAULT 0,
            `tasks` INT NOT NULL DEFAULT 0,
            `reason` VARCHAR(120) NOT NULL DEFAULT '',
            `officer` VARCHAR(96) NOT NULL DEFAULT '',
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_mugshots` (
            `citizenid` VARCHAR(64) NOT NULL,
            `image` MEDIUMTEXT NOT NULL,
            `officer` VARCHAR(96) NOT NULL DEFAULT '',
            `taken_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_duty` (
            `citizenid` VARCHAR(64) NOT NULL,
            `name` VARCHAR(96) NOT NULL DEFAULT '',
            `job` VARCHAR(32) NOT NULL DEFAULT '',
            `week_start` INT NOT NULL DEFAULT 0,
            `week_seconds` INT NOT NULL DEFAULT 0,
            `total_seconds` INT NOT NULL DEFAULT 0,
            `last_on` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_lab` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `place_id` INT NOT NULL,
            `kind` VARCHAR(16) NOT NULL DEFAULT '',
            `subject` VARCHAR(160) NOT NULL DEFAULT '',
            `result` VARCHAR(255) NOT NULL DEFAULT '',
            `officer` VARCHAR(96) NOT NULL DEFAULT '',
            `match_cid` VARCHAR(64) NOT NULL DEFAULT '',
            `created_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `place_id` (`place_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_flags` (
            `plate` VARCHAR(16) NOT NULL,
            `reason` VARCHAR(160) NOT NULL DEFAULT '',
            `officer` VARCHAR(96) NOT NULL DEFAULT '',
            `created_at` INT NOT NULL DEFAULT 0,
            `expires_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_favourites` (
            `citizenid` VARCHAR(64) NOT NULL,
            `data` TEXT NOT NULL,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_evidence` (
            `scope` VARCHAR(16) NOT NULL,
            `number` INT NOT NULL,
            `label` VARCHAR(96) NOT NULL DEFAULT '',
            `opened_by` VARCHAR(96) NOT NULL DEFAULT '',
            `opened_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`scope`, `number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_impound` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(16) NOT NULL,
            `citizenid` VARCHAR(64) NOT NULL DEFAULT '',
            `owner_name` VARCHAR(96) NOT NULL DEFAULT '',
            `model` VARCHAR(64) NOT NULL DEFAULT '',
            `lot_id` INT NOT NULL DEFAULT 0,
            `fee` INT NOT NULL DEFAULT 0,
            `reason` VARCHAR(160) NOT NULL DEFAULT '',
            `officer_name` VARCHAR(96) NOT NULL DEFAULT '',
            `job` VARCHAR(32) NOT NULL DEFAULT '',
            `hold_until` INT NOT NULL DEFAULT 0,
            `police_hold` TINYINT(1) NOT NULL DEFAULT 0,
            `condition` LONGTEXT NULL,
            `released` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `plate` (`plate`),
            KEY `citizenid` (`citizenid`),
            KEY `lot_id` (`lot_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `xs_police_staff_notes` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `job` VARCHAR(32) NOT NULL,
            `citizenid` VARCHAR(64) NOT NULL,
            `kind` VARCHAR(12) NOT NULL DEFAULT 'note',
            `text` VARCHAR(255) NOT NULL DEFAULT '',
            `author` VARCHAR(96) NOT NULL DEFAULT '',
            `created_at` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `job_cid` (`job`, `citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

local COLUMNS = {
    { 'xs_police_lab', 'match_cid', "VARCHAR(64) NOT NULL DEFAULT ''" },
    { 'xs_police_lab', 'ref', "VARCHAR(64) NOT NULL DEFAULT ''" },
    { 'xs_police_inmates', 'credit', 'INT NOT NULL DEFAULT 0' },
    { 'xs_police_inmates', 'breakout', 'LONGTEXT NULL' },
    { 'xs_police_inmates', 'test', 'TINYINT(1) NOT NULL DEFAULT 0' },
}

local function addColumns()
    for _, c in ipairs(COLUMNS) do
        local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { c[1], c[2] })
        if ok and tonumber(n) == 0 then
            pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(c[1], c[2], c[3]))
        end
    end
end

function Db.Setup()
    for _, statement in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, statement)
        if not ok then
            print(('^1[XS-PoliceSystem]^0 could not create a table: %s'):format(tostring(err)))
            return false
        end
    end
    addColumns()
    Db.ready = true
    return true
end

function Db.Json(value)
    local ok, out = pcall(json.encode, value)
    return ok and out or '{}'
end

function Db.Decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, out = pcall(json.decode, value)
    if ok and out ~= nil then return out end
    return fallback
end

function Db.Log(kind, target, amount, detail, officer)
    if not Db.ready then return end
    if target and target.citizenid and Jail and Jail.tests and Jail.tests[target.citizenid] then return end
    MySQL.insert('INSERT INTO xs_police_log (kind, citizenid, name, amount, detail, officer_cid, officer_name, job) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        kind, target and target.citizenid or '', target and target.name or '', math.floor(tonumber(amount) or 0),
        Util.Text(detail, 255), officer and officer.citizenid or '', officer and officer.name or '', officer and officer.job or '',
    })
end

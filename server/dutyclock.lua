DutyClock = { week = {} }

local function weekStart(now)
    local d = os.date('*t', now)
    local wday = (d.wday + 5) % 7
    return now - wday * 86400 - d.hour * 3600 - d.min * 60 - d.sec
end

function DutyClock.Tick(seconds)
    local now = os.time()
    local start = weekStart(now)
    for _, src in ipairs(Framework.Cops(true)) do
        local cid = Framework.GetCitizenId(src)
        local job = Framework.GetJob(src)
        if cid and job then
            MySQL.query([[
                INSERT INTO `xs_police_duty` (`citizenid`, `name`, `job`, `week_start`, `week_seconds`, `total_seconds`, `last_on`)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    `name` = VALUES(`name`), `job` = VALUES(`job`), `last_on` = VALUES(`last_on`),
                    `week_seconds` = IF(`week_start` = VALUES(`week_start`), `week_seconds` + VALUES(`week_seconds`), VALUES(`week_seconds`)),
                    `week_start` = VALUES(`week_start`),
                    `total_seconds` = `total_seconds` + VALUES(`total_seconds`)
            ]], { cid, Framework.GetName(src) or '', job.name, start, seconds, seconds, now })
        end
    end
end

function DutyClock.Hours(cids)
    local out = {}
    if #cids == 0 then return out end
    local start = weekStart(os.time())
    local marks = {}
    for i = 1, #cids do marks[i] = '?' end
    local rows = MySQL.query.await(('SELECT `citizenid`, `week_start`, `week_seconds`, `total_seconds`, `last_on` FROM `xs_police_duty` WHERE `citizenid` IN (%s)'):format(table.concat(marks, ',')), cids) or {}
    for _, r in ipairs(rows) do
        out[r.citizenid] = {
            week = (tonumber(r.week_start) == start) and (tonumber(r.week_seconds) or 0) or 0,
            total = tonumber(r.total_seconds) or 0,
            last = tonumber(r.last_on) or 0,
        }
    end
    return out
end

CreateThread(function()
    while true do
        Wait(60000)
        if Db.ready then DutyClock.Tick(60) end
    end
end)

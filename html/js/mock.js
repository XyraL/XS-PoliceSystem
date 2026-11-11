(() => {
    if (typeof GetParentResourceName === 'function') return;
    if (location.hostname.toLowerCase() === RESOURCE.toLowerCase()) return;
    const UP = window.XSPreviewRoot || '../';

    const send = (app, action, data) => window.dispatchEvent(new MessageEvent('message', { data: { app, action, data } }));
    const params = new URLSearchParams(location.search);
    const view = params.get('view') || 'wheel';
    if (params.get('bg') !== 'none') document.documentElement.style.background = 'linear-gradient(160deg,#6d7c88 0%,#45525c 45%,#262d33 100%)';

    const ITEMS = {
        root: [
            { id: 'cuff', icon: 'cuffs' }, { id: 'escort', icon: 'escort' }, { id: 'search', icon: 'search' },
            { id: 'person', icon: 'person', page: true }, { id: 'vehicle', icon: 'car', page: true },
            { id: 'scene', icon: 'cone', page: true }, { id: 'paperwork', icon: 'paper', page: true }, { id: 'mdt', icon: 'mdt' }, { id: 'panic', icon: 'panic', danger: true },
        ],
        vehicle: [{ id: 'putInVehicle', icon: 'seat' }, { id: 'takeOutVehicle', icon: 'exit' }, { id: 'checkPlate', icon: 'plate' }, { id: 'impound', icon: 'tow' }],
    };
    ITEMS.fav = [{ id: 'gsr', icon: 'gsr', fav: true }, { id: 'checkPlate', icon: 'plate', fav: true }].concat(ITEMS.root.map((i) => Object.assign({}, i, i.id === 'cuff' ? { fav: true } : {})));

    const WHEEL_DEFS = {
        actions: { cuff: { icon: 'cuffs' }, escort: { icon: 'escort' }, search: { icon: 'search' }, idcheck: { icon: 'id' }, gsr: { icon: 'gsr' }, fingerprint: { icon: 'fingerprint' }, breathalyzer: { icon: 'breath' }, drugswab: { icon: 'drugtest' }, licences: { icon: 'licence' }, tracker: { icon: 'anklet' }, flagPlate: { icon: 'flag' }, cameras: { icon: 'cctv' }, service: { icon: 'vest' }, solitary: { icon: 'solitary' }, searchVehicle: { icon: 'trunk' }, dustPrints: { icon: 'dust' }, slowTraffic: { icon: 'slow' }, stopTraffic: { icon: 'stop' }, k9Call: { icon: 'k9' }, k9Follow: { icon: 'leash' }, k9Search: { icon: 'search' }, k9Attack: { icon: 'bitesleeve' }, k9Car: { icon: 'seat' }, k9Track: { icon: 'paw' }, k9Guard: { icon: 'k9badge' }, k9Bark: { icon: 'whistle' }, seize: { icon: 'cash' }, putInVehicle: { icon: 'seat' }, takeOutVehicle: { icon: 'exit' }, checkPlate: { icon: 'plate' },
            impound: { icon: 'tow' }, cone: { icon: 'cone' }, barrier: { icon: 'barrier' }, spikes: { icon: 'spikes' }, removeProp: { icon: 'remove' }, fine: { icon: 'fine' }, jail: { icon: 'jail' }, mdt: { icon: 'mdt' }, panic: { icon: 'panic', danger: true } },
        order: ['cuff', 'escort', 'search', 'idcheck', 'gsr', 'fingerprint', 'breathalyzer', 'drugswab', 'licences', 'tracker', 'seize', 'flagPlate', 'cameras', 'searchVehicle', 'dustPrints', 'slowTraffic', 'stopTraffic', 'k9Call', 'k9Follow', 'k9Search', 'k9Track', 'k9Attack', 'k9Guard', 'k9Bark', 'k9Car', 'service', 'solitary', 'putInVehicle', 'takeOutVehicle', 'checkPlate', 'impound', 'cone', 'barrier', 'spikes', 'removeProp', 'fine', 'jail', 'mdt', 'panic'],
        pages: { person: { icon: 'person' }, vehicle: { icon: 'car' }, scene: { icon: 'cone' }, paperwork: { icon: 'paper' }, k9: { icon: 'k9' } },
        icons: ['cuffs', 'escort', 'search', 'person', 'car', 'cone', 'paper', 'panic', 'id', 'gsr', 'cash', 'seat', 'exit', 'plate', 'tow', 'barrier', 'spikes', 'remove', 'fine', 'jail', 'mdt', 'fingerprint', 'breath', 'drugtest', 'licence', 'anklet', 'flag', 'cctv', 'trunk', 'slow', 'stop', 'k9', 'leash', 'bitesleeve', 'dust', 'vest', 'solitary', 'paw', 'k9badge', 'whistle'],
        favourites: 4, off: {},
    };
    const WHEEL_DEFAULT = () => ({
        pages: [
            { id: 'root', label: '', items: ['cuff', 'escort', 'search', '@person', '@vehicle', '@scene', '@paperwork', 'mdt', 'panic'] },
            { id: 'person', label: '', items: ['idcheck', 'gsr', 'fingerprint', 'breathalyzer', 'drugswab', 'licences', 'tracker', 'seize'] },
            { id: 'vehicle', label: '', items: ['putInVehicle', 'takeOutVehicle', 'checkPlate', 'flagPlate', 'impound'] },
            { id: 'scene', label: '', items: ['cone', 'barrier', 'spikes', 'removeProp'] },
            { id: 'paperwork', label: '', items: ['fine', 'jail'] },
        ],
        actions: [], custom: [],
    });
    const WHEEL = {
        pages: [
            { id: 'root', label: '', items: ['cuff', 'escort', 'search', '@person', '@vehicle', '@scene', '@paperwork', 'mdt', 'panic'] },
            { id: 'person', label: '', items: ['idcheck', 'gsr', 'fingerprint', 'breathalyzer', 'drugswab', 'licences', 'tracker', 'seize'] },
            { id: 'vehicle', label: '', items: ['putInVehicle', 'takeOutVehicle', 'checkPlate', 'flagPlate', 'impound'] },
            { id: 'scene', label: '', items: ['cone', 'barrier', 'spikes', 'removeProp', 'xnotepad'] },
            { id: 'paperwork', label: 'Charges', icon: 'fine', items: ['fine', 'jail'] },
        ],
        actions: { spikes: { label: 'Stinger', jobs: ['sast', 'bcso'], grade: 1 }, jail: { label: '', jobs: [], grade: 2 } },
        custom: [{ id: 'xnotepad', label: 'Notepad', icon: 'paper', kind: 'command', value: 'e notepad', jobs: [], grade: 0, danger: false }],
    };

    const replies = {
        'armory:take': () => ({ ok: true, data: 'Took 1× Combat Pistol.' }),
        'garage:spawn': () => ({ ok: true }),
        'boss:money': (p) => ({ ok: true, data: 482300 + (p.direction === 'deposit' ? p.amount : -p.amount) }),
        'form:submit': (p) => ({ ok: true, data: p.kind === 'jail' ? 'Vincent Valentine jailed for 30 months.' : 'Fine of $750 issued.' }),
        'builder:save': (p) => ({ ok: true, data: Object.assign({}, p, { id: p.id || 9 }) }),
        'evidence:open': () => ({ ok: true }),
        'impound:submit': () => ({ ok: true }),
        'impoundlot:release': () => ({ ok: true, data: '46EEK572 is waiting for you in the lot.' }),
        'impoundlot:manage': () => ({ ok: true, data: 'Hold cleared.' }),
        'builder:wheelSave': (p) => ({ ok: true, data: p }),
        'boss:callsign': (p) => ({ ok: true, data: String(p.callsign || '').toUpperCase() }),
        'licence:set': (p) => ({ ok: true, data: { message: p.on ? 'Gave them a Firearm licence.' : 'Took their Driver licence.', licences: { target: 2, name: 'Terrence Obi', canGrant: true, list: [{ kind: 'driver', has: p.kind === 'driver' ? p.on : true }, { kind: 'weapon', has: p.kind === 'weapon' ? p.on : false }] } } }),
        'cameras:watch': () => ({ ok: true }),
        'unitcams:watch': () => ({ ok: true }),
        'scanner:mdt': () => ({ ok: true }),
        'lab:analyse': () => new Promise((r) => setTimeout(() => r({ ok: true, data: { result: 'The gun with serial SER123 is with Terrence Obi.', report: { kind: 'casing', label: 'Evidence: bullet casings', match: true, lines: [
            { label: 'Calibre', value: '9mm pistol round' }, { label: 'Casings', value: '3' }, { label: 'Gun serial', value: 'SER123' }, { label: 'Gun is with', value: 'Terrence Obi' },
            { label: 'Print on a casing', value: 'KQ482T19XWD7704' }, { label: 'Scene', value: 'Strawberry Ave / Davis Ave' }, { label: 'Bagged', value: '31/10 22:10 · Vincent Valentine' },
        ], links: [{ subject: 'Evidence: bullet casings · Grove St', at: Math.floor(Date.now() / 1000) - 86400 }, { subject: 'Evidence: bullet casings · Forum Dr', at: Math.floor(Date.now() / 1000) - 3 * 86400 }] }, reports: [{ id: 3, kind: 'fingerprint', subject: 'Evidence: prints from 46EEK572 · 46EEK572', result: 'The prints match Terrence Obi.', officer: '1-A-01 Vincent Valentine', at: Math.floor(Date.now() / 1000) }] } }), 1200)),
        'builder:wheelReset': () => ({ ok: true, data: WHEEL_DEFAULT() }),
        'boss:refresh': () => ({ ok: true, data: OFFICE() }),
        'lab:start': (p) => ({ ok: true, data: { bench: { a: 'microscope', b: 'sequencer', c: 'overlay' }[p.key] || 'microscope', seconds: 2, code: { a: 'SER123', b: '3F9A-11C2', c: 'KQ482T19XWD7704' }[p.key] } }),
        'prisonshop:buy': () => ({ ok: true, data: { credit: 26, message: 'Got 1× Sandwich.' } }),
        'prisonshop:people': () => ({ ok: true, data: [{ src: 5, name: 'Marco Reyes' }, { src: 7, name: 'Maria Lopez' }] }),
        'prisonshop:deal': () => ({ ok: true, data: { wallet: 8, message: 'Got 1× Scrap Metal for 2.' } }),
        'boss:log': (p) => ({ ok: true, data: { rows: LOG.filter((r) => (p.filter && p.filter.kind === 'money' ? ['fine', 'seize', 'impound_release', 'withdraw', 'deposit', 'speeding'].includes(r.kind) : true)), week: OFFICE().week } }),
        'boss:notes': () => ({ ok: true, data: [
            { id: 3, kind: 'warning', text: 'Late to briefing twice this week. Next one goes on the review.', author: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 90000 },
            { id: 2, kind: 'note', text: 'Wants to move to the K9 unit. Talk to Ruth about it.', author: 'Ruth Calloway', at: Math.floor(Date.now() / 1000) - 400000 },
            { id: 1, kind: 'commend', text: 'Pulled two people out of the burning car on Route 68.', author: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 900000 },
        ] }),
        'boss:note': () => ({ ok: true }),
        'boss:armory': (p) => ({ ok: true, data: p.list }),
        'boss:fleet': (p) => ({ ok: true, data: { vehicles: p.vehicles, helicopters: p.helicopters } }),
        'builder:settingsSave': (p) => ({ ok: true, data: { values: null, boot: { Commands: true } } }),
        'builder:jailtestskip': () => ({ ok: true, data: { jail: 'Bolingbroke Penitentiary', left: 20, escaped: false } }),
        'builder:areas': (list) => {
            const out = {};
            const near = (x, y) => (x > 300 && x < 600 && y < -900 && y > -1100 ? ['Sinner St', 'Mission Row'] : x > 1500 && y > 2400 && y < 2700 ? ['Route 68', 'Bolingbroke Penitentiary'] : x > 300 && x < 450 && y < -1550 ? ['Innocence Blvd', 'Davis'] : x < -1000 && y < -700 && y > -900 ? ['Vespucci Blvd', 'Vespucci Canals'] : x > 100 && x < 250 && y < -900 && y > -1050 ? ['Vespucci Blvd', 'Legion Square'] : x < -400 && y > 5900 ? ['Paleto Blvd', 'Paleto Bay'] : ['', 'Los Santos']);
            XS.list(list).forEach((a) => { const [street, zone] = near(Number(a.x), Number(a.y)); out[a.id] = { street, zone }; });
            return { ok: true, data: out };
        },
        'builder:here': () => ({ ok: true, data: { x: 446.5 + Math.random() * 6, y: -985.2 - Math.random() * 6, z: 30.7, w: Math.round(Math.random() * 360) } }),
        'builder:place': () => ({ ok: true, data: { x: 452.1 + Math.random() * 8, y: -990.4 - Math.random() * 8, z: 30.7, w: Math.round(Math.random() * 360) } }),
    };

    XS.post = async (endpoint, payload) => {
        if (endpoint === 'rpc') {
            const fn = replies[payload.name];
            return fn ? fn(payload.payload || {}) : { ok: true };
        }
        if (endpoint === 'close') {
            const app = payload && payload.app;
            if (app) send(app, 'close', {});
        }
        return { ok: true };
    };

    const BOSS = {
        department: 'Los Santos Police', job: 'police', myGrade: 4, isBoss: true, onDuty: 7, balance: 482300,
        grades: [{ level: 0, label: 'Cadet' }, { level: 1, label: 'Officer' }, { level: 2, label: 'Sergeant' }, { level: 3, label: 'Lieutenant' }, { level: 4, label: 'Chief' }],
        nearby: [{ src: 12, name: 'Terrence Obi' }],
        staff: [
            { cid: 'XSP1001', name: 'Vincent Valentine', grade: 4, online: true, callsign: '1-A-01' },
            { cid: 'XSP1002', name: 'Ruth Calloway', grade: 3, online: true, callsign: '2-L-14' },
            { cid: 'XSP1003', name: 'Dana Kessler', grade: 2, online: false, callsign: '' },
            { cid: 'XSP1004', name: 'Marco Reyes', grade: 1, online: true },
            { cid: 'XSP1005', name: 'Imani Brooks', grade: 0, online: false },
        ],
    };

    const LOG = [
        { id: 30, kind: 'jail', name: 'Terrence Obi', amount: 30, detail: 'Armed robbery, evading', officer: 'Ruth Calloway', at: Math.floor(Date.now() / 1000) - 420 },
        { id: 29, kind: 'fine', name: 'Dana Kessler', amount: 750, detail: 'Reckless driving', officer: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 1300 },
        { id: 28, kind: 'impound', name: '', amount: 500, detail: '46EEK572 · Davis Impound · 24h', officer: 'Marco Reyes', at: Math.floor(Date.now() / 1000) - 2600 },
        { id: 27, kind: 'commend', name: 'Ruth Calloway', amount: 0, detail: 'Talked down the Pacific Bank hostage taker', officer: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 5400 },
        { id: 26, kind: 'evidence', name: '', amount: 3, detail: 'Evidence: bullet casings · Grove St', officer: 'Imani Brooks', at: Math.floor(Date.now() / 1000) - 7200 },
        { id: 25, kind: 'impound_release', name: 'Vincent Valentine', amount: 1500, detail: '81XSP402', officer: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 9000 },
        { id: 24, kind: 'promote', name: 'Marco Reyes', amount: 1, detail: 'Officer', officer: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 86400 },
        { id: 23, kind: 'warning', name: 'Dana Kessler', amount: 0, detail: 'Late to briefing twice', officer: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 90000 },
        { id: 22, kind: 'seize', name: 'Terrence Obi', amount: 2300, detail: 'Cash seized', officer: 'Ruth Calloway', at: Math.floor(Date.now() / 1000) - 120000 },
        { id: 21, kind: 'withdraw', name: '', amount: 5000, detail: '', officer: 'Vincent Valentine', at: Math.floor(Date.now() / 1000) - 160000 },
    ];
    const OFFICE = () => Object.assign({}, BOSS, {
        isBoss: true, myGrade: 99, banking: true, maxPrice: 100000,
        grades: [{ level: 0, label: 'Cadet' }, { level: 1, label: 'Officer' }, { level: 2, label: 'Sergeant' }, { level: 3, label: 'Lieutenant' }, { level: 4, label: 'Chief' }],
        me: { cid: 'XSP1001', name: 'Vincent Valentine', grade: 4, rank: 'Chief' },
        staff: [
            { cid: 'XSP1001', name: 'Vincent Valentine', grade: 4, online: true, onDuty: true, callsign: '1-A-01', week: 3600 * 14.5, total: 3600 * 212, record: { note: 0, warning: 0, commend: 2 } },
            { cid: 'XSP1002', name: 'Ruth Calloway', grade: 3, online: true, onDuty: true, callsign: '2-L-14', week: 3600 * 18.2, total: 3600 * 340, record: { note: 1, warning: 0, commend: 3 } },
            { cid: 'XSP1003', name: 'Dana Kessler', grade: 2, online: false, onDuty: false, callsign: '3-S-22', week: 3600 * 4.1, total: 3600 * 96, record: { note: 2, warning: 2, commend: 0 } },
            { cid: 'XSP1004', name: 'Marco Reyes', grade: 1, online: true, onDuty: false, callsign: '4-O-31', week: 3600 * 9.7, total: 3600 * 61, record: { note: 0, warning: 0, commend: 0 } },
            { cid: 'XSP1005', name: 'Imani Brooks', grade: 1, online: true, onDuty: true, callsign: '4-O-35', week: 3600 * 11.0, total: 3600 * 44, record: { note: 0, warning: 1, commend: 1 } },
            { cid: 'XSP1006', name: 'Terrence Obi', grade: 0, online: false, onDuty: false, callsign: '', week: 0, total: 3600 * 3, record: { note: 0, warning: 0, commend: 0 } },
        ],
        station: { id: 1, name: 'Mission Row PD', armory: STATION.armory.concat([{ item: 'armor', grade: 1, price: 250, amount: 1 }, { item: 'handcuffs', grade: 0, price: 0, amount: 1 }]), vehicles: STATION.vehicles, helicopters: STATION.helicopters },
        pools: {
            items: [{ name: 'weapon_combatpistol', label: 'Combat Pistol' }, { name: 'weapon_carbinerifle', label: 'Carbine Rifle' }, { name: 'pistol_ammo', label: 'Pistol Ammo' }, { name: 'armor', label: 'Body Armour' },
                { name: 'handcuffs', label: 'Handcuffs', image: `${UP}inventory_images/handcuffs.png` }, { name: 'spikestrip', label: 'Spike Strip', image: `${UP}inventory_images/spikestrip.png` }, { name: 'weapon_stungun', label: 'Taser' }, { name: 'radio', label: 'Radio' }],
            vehicles: [{ model: 'police', label: 'Police Cruiser' }, { model: 'police3', label: 'Police Interceptor' }, { model: 'police4', label: 'Unmarked Cruiser' }, { model: 'policeb', label: 'Police Bike' }, { model: 'polmav', label: 'Police Maverick', heli: true }],
        },
        week: { jail: { n: 7, total: 210 }, fine: { n: 23, total: 18450 }, impound: { n: 9, total: 4500 }, impound_release: { n: 6, total: 5200 }, evidence: { n: 14, total: 31 }, prints: { n: 5, total: 0 }, seize: { n: 3, total: 6800 }, speeding: { n: 11, total: 1375 }, hire: { n: 1, total: 0 }, service: { n: 2, total: 20 } },
        recent: LOG.slice(0, 8),
    });

    const STATION = {
        id: 1, kind: 'station', name: 'Mission Row PD', blip: true, jobs: ['police'], plate: 'LSPD',
        armory: [{ item: 'weapon_combatpistol', grade: 0, price: 0, amount: 1 }, { item: 'weapon_carbinerifle', grade: 3, price: 0, amount: 1 }, { item: 'pistol_ammo', grade: 0, price: 0, amount: 5 }],
        vehicles: [{ model: 'police', label: 'Cruiser', grade: 0, livery: -1, extras: [] }, { model: 'police3', label: 'Interceptor', grade: 1, livery: 0, extras: [1, 2] }],
        helicopters: [{ model: 'polmav', label: 'Maverick', grade: 2, livery: -1, extras: [] }],
        points: {
            duty: [{ id: 'd1', x: 441.8, y: -982.0, z: 30.7, w: 90 }], locker: [{ id: 'l1', x: 461.5, y: -996.4, z: 30.7, w: 0 }],
            armory: [{ id: 'a1', x: 482.6, y: -995.1, z: 30.7, w: 0 }], garage: [{ id: 'g1', x: 441.0, y: -1013.5, z: 28.6, w: 90, spawn: { x: 446.2, y: -1025.1, z: 28.6, w: 0 } }],
            helipad: [], evidence: [{ id: 'e1', x: 475.2, y: -996.8, z: 26.3, w: 0 }], booking: [{ id: 'b1', x: 473.9, y: -1007.4, z: 26.3, w: 0 }], boss: [{ id: 'o1', x: 460.7, y: -985.6, z: 30.7, w: 0 }],
        },
    };

    const KINDS = {
        station: [{ key: 'duty' }, { key: 'locker' }, { key: 'armory' }, { key: 'garage', spawn: true }, { key: 'helipad', spawn: true }, { key: 'evidence' }, { key: 'lab' }, { key: 'booking' }, { key: 'boss' }, { key: 'camroom' }],
        jail: [{ key: 'cell' }, { key: 'canteen' }, { key: 'workout', exercise: true }, { key: 'release', single: true }, { key: 'solitary' }, { key: 'guard', npc: true }, { key: 'clerk', npc: true }, { key: 'trader', npc: true }, { key: 'craft' }, { key: 'hide', named: true }, { key: 'tunnel', exit: true }, { key: 'fence', exit: true }],
        impound: [{ key: 'desk' }, { key: 'lot', vehicle: true }],
        blip: [],
        service: [{ key: 'task' }],
    };

    function luaValues(src, env) {
        let i = 0;
        const n = src.length;
        const ws = () => {
            for (;;) {
                while (i < n && /\s/.test(src[i])) i++;
                if (src.startsWith('--[[', i)) { const e = src.indexOf(']]', i); i = e < 0 ? n : e + 2; continue; }
                if (src.startsWith('--', i)) { const e = src.indexOf('\n', i); i = e < 0 ? n : e + 1; continue; }
                return;
            }
        };
        const ident = () => { const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i, i + 80)); if (!m) return null; i += m[0].length; return m[0]; };
        function value() {
            ws();
            const c = src[i];
            if (c === '{') return table();
            if (c === "'" || c === '"') {
                let j = i + 1; let out = '';
                while (j < n && src[j] !== c) { if (src[j] === '\\') { out += src[j + 1] === 'n' ? '\n' : src[j + 1]; j += 2; } else out += src[j++]; }
                i = j + 1; return out;
            }
            if (c === '`') { const e = src.indexOf('`', i + 1); const out = src.slice(i + 1, e); i = e + 1; return out; }
            const num = /^-?(0x[0-9a-fA-F]+|\d+\.?\d*(e[-+]?\d+)?|\.\d+)/.exec(src.slice(i, i + 40));
            if (num) { i += num[0].length; return Number(num[0]); }
            const id = ident();
            if (id === 'true') return true;
            if (id === 'false') return false;
            if (id === 'nil') return null;
            ws();
            if (src[i] === '(') {
                i++; const args = [];
                for (;;) { ws(); if (src[i] === ')') { i++; break; } args.push(value()); ws(); if (src[i] === ',') i++; }
                if (/^vec(tor)?[234]$/.test(id)) return { x: args[0], y: args[1], z: args[2], w: args[3] };
                return null;
            }
            let v = env[id];
            while (src[i] === '.') { i++; const k = ident(); v = v ? v[k] : undefined; }
            return v;
        }
        function table() {
            i++;
            const arr = []; const obj = {}; let named = false;
            for (;;) {
                ws();
                if (src[i] === '}') { i++; break; }
                if (src[i] === '[') {
                    i++; const k = value(); ws(); i++; ws(); i++;
                    obj[k] = value(); named = true;
                } else {
                    const save = i; const id = ident(); ws();
                    if (id && src[i] === '=' && src[i + 1] !== '=') { i++; obj[id] = value(); named = true; } else { i = save; arr.push(value()); }
                }
                ws();
                if (src[i] === ',' || src[i] === ';') i++;
            }
            if (!named) return arr;
            arr.forEach((v, k) => { obj[k + 1] = v; });
            return obj;
        }
        while (i < n) {
            ws();
            if (i >= n) break;
            const start = i;
            let id = ident();
            if (!id) { i++; continue; }
            if (id === 'for' || id === 'function' || id === 'if' || id === 'while') break;
            if (id === 'local') { ws(); id = ident(); }
            const path = [id];
            while (src[i] === '.') { i++; path.push(ident()); }
            ws();
            if (src[i] !== '=' || i === start) { i++; continue; }
            i++;
            const v = value();
            let o = env;
            for (let k = 0; k < path.length - 1; k++) { if (typeof o[path[k]] !== 'object' || o[path[k]] === null) o[path[k]] = {}; o = o[path[k]]; }
            o[path[path.length - 1]] = v;
        }
        return env;
    }

    async function builderData() {
        const [cfgText, setText] = await Promise.all([fetch(`${UP}config.lua`).then((r) => r.text()), fetch(`${UP}shared/settings.lua`).then((r) => r.text())]);
        const env = luaValues(cfgText, {});
        luaValues(setText, env);
        const Config = env.Config || {};
        const read = (key) => key.split('.').reduce((o, k) => (o && typeof o === 'object' ? o[k] : undefined), Config);
        const sections = (env.Settings.Sections || []).map((sec) => ({ id: sec.id, icon: sec.icon, fields: (sec.fields || []).map((f) => {
            if (Array.isArray(f)) return { key: f[0], type: f[1], section: sec.id };
            const out = { key: f[1], type: f[2], section: sec.id };
            Object.keys(f).forEach((k) => { if (!/^\d+$/.test(k)) out[k] = f[k]; });
            return out;
        }) }));
        const defaults = {};
        sections.forEach((sec) => sec.fields.forEach((f) => { defaults[f.key] = read(f.key); }));
        const values = JSON.parse(JSON.stringify(defaults));
        if (params.get('changed') !== '0') {
            values['Forensics.bloodChance'] = 55;
            values['Jail.minutesPerMonth'] = 2;
            values['Tackle.anyone'] = true;
        }
        return { settings: { sections, defaults, values, boot: { Commands: true } }, env };
    }

    const NOW = Math.floor(Date.now() / 1000);
    const JAIL = {
        id: 2, kind: 'jail', name: 'Bolingbroke Penitentiary', radius: 200, center: { x: 1693.3, y: 2569.5, z: 44.6 }, markers: false,
        blip: { show: true, sprite: 285, colour: 1, scale: 0.8, label: '', short: true, who: 'all' },
        points: {
            cell: [{ id: 'c1', x: 1661.0, y: 2524.7, z: 45.6, w: 260 }, { id: 'c2', x: 1650.8, y: 2540.6, z: 45.6, w: 230 }],
            canteen: [{ id: 'k1', x: 1778.3, y: 2560.6, z: 45.6, w: 181 }],
            workout: [{ id: 'g1', x: 1770.7, y: 2480.0, z: 45.7, w: 32, exercise: 'pushups' }, { id: 'g2', x: 1745.0, y: 2479.2, z: 45.7, w: 323, exercise: 'weights' }],
            release: [{ id: 'r1', x: 1848.1, y: 2586.1, z: 44.7, w: 270 }],
        },
        work: [
            { id: 'w1', label: 'Fix the wiring', activity: 'repair', seconds: 12, credit: 30, spots: [{ id: 's1', x: 1761.5, y: 2540.4, z: 45.6 }, { id: 's2', x: 1718.5, y: 2527.8, z: 45.6 }, { id: 's3', x: 1700.2, y: 2474.8, z: 45.6 }] },
            { id: 'w2', label: 'Sweep the yard', activity: 'sweep', seconds: 10, credit: 20, spots: [{ id: 's4', x: 1765.7, y: 2565.9, z: 44.6 }] },
            { id: 'w3', label: 'Kitchen duty', activity: 'cook', seconds: 15, credit: 40, spots: [] },
        ],
        meals: [
            { id: 'm1', label: 'Lunch tray', items: [{ item: 'sandwich', amount: 1 }, { item: 'water_bottle', amount: 1 }] },
            { id: 'm2', label: 'Breakfast', items: [{ item: 'handcuffs', amount: 1 }] },
        ],
        mealMinutes: 5,
    };
    const IMPOUND = {
        id: 3, kind: 'impound', name: 'Davis Impound', jobs: [], fee: 500, clerk: 's_m_y_cop_01', markers: false,
        blip: { show: true, sprite: 68, colour: 47, scale: 0.8, label: '', short: true, who: 'all' },
        points: { desk: [{ id: 'k1', x: 409.1, y: -1623.4, z: 29.3, w: 230 }], lot: [{ id: 'l1', x: 401.5, y: -1631.2, z: 29.3, w: 140 }, { id: 'l2', x: 398.2, y: -1634.6, z: 29.3, w: 140 }] },
    };
    const CUSTOM_BLIP = { id: 4, kind: 'blip', name: 'Vespucci Beat Office', points: {}, blipAt: { x: -1108.4, y: -846.2, z: 19.3 }, blip: { show: true, sprite: 526, colour: 38, scale: 0.9, label: '', short: true, who: 'police' } };
    const RECORDS = [
        { id: 21, plate: '46EEK572', model: 'sultanrs', label: 'Sultan RS', owner: 'Vincent Valentine', lot: 3, lotName: 'Davis Impound', fee: 500, reason: 'Evading police, reckless driving', officer: 'Ruth Calloway', at: NOW - 5400, left: 0, policeHold: false },
        { id: 22, plate: '81XSP402', model: 'buffalo', label: 'Buffalo', owner: 'Vincent Valentine', lot: 3, lotName: 'Davis Impound', fee: 1500, reason: 'Used in a bank robbery', officer: 'Marco Reyes', at: NOW - 1800, left: 3600 * 21 + 1460, policeHold: false },
        { id: 23, plate: '12DMK880', model: 'kuruma', label: 'Kuruma', owner: 'Dana Kessler', lot: 3, lotName: 'Davis Impound', fee: 2500, reason: 'Evidence: shots fired from vehicle', officer: 'Vincent Valentine', at: NOW - 600, left: 3600 * 70, policeHold: true },
        { id: 24, plate: '07LQW119', model: 'blista', label: 'Blista', owner: 'Imani Brooks', lot: 4, lotName: 'Sandy Shores Impound', fee: 350, reason: 'Abandoned on the highway', officer: 'Terrence Obi', at: NOW - 86400, left: 0, policeHold: false },
    ];

    function show() {
        if (view === 'wheel' || view === 'wheel-vehicle' || view === 'wheel-fav') {
            send('wheel', 'open', {});
            const page = view === 'wheel-vehicle' ? 'vehicle' : 'root';
            const items = view === 'wheel-fav' ? ITEMS.fav : ITEMS[page];
            send('wheel', 'state', { page, index: view === 'wheel-vehicle' ? 3 : 1, items, back: page !== 'root', target: { person: { id: 12, distance: 1.4 }, vehicle: { plate: '46EEK572' } }, pin: view === 'wheel-fav' ? { pinned: true } : { pinned: false } });
        } else if (view === 'armory') {
            send('armory', 'open', { place: 1, point: 'a1', station: 'Mission Row PD', items: [
                { item: 'weapon_combatpistol', label: 'Combat Pistol', price: 0, amount: 1 }, { item: 'weapon_stungun', label: 'Taser', price: 0, amount: 1 },
                { item: 'weapon_pumpshotgun', label: 'Pump Shotgun', price: 0, amount: 1 }, { item: 'pistol_ammo', label: 'Pistol Ammo', price: 0, amount: 5 },
                { item: 'armor', label: 'Body Armour', price: 250, amount: 1, grade: 1 }, { item: 'handcuffs', label: 'Handcuffs', price: 0, amount: 1, image: `${UP}inventory_images/handcuffs.png` },
                { item: 'spikestrip', label: 'Spike Strip', price: 0, amount: 1, image: `${UP}inventory_images/spikestrip.png` }, { item: 'weapon_carbinerifle', label: 'Carbine Rifle', price: 0, amount: 1, grade: 3 },
            ] });
        } else if (view === 'canteen') {
            send('canteen', 'open', { point: 'k1', jail: 'Bolingbroke Penitentiary', wait: params.get('wait') === '1' ? 200 : 0, meals: [
                { id: 'm1', label: 'Lunch tray', items: [{ item: 'sandwich', label: 'Sandwich', amount: 1 }, { item: 'water_bottle', label: 'Water', amount: 1 }] },
                { id: 'm2', label: 'Breakfast', items: [{ item: 'coffee', label: 'Coffee', amount: 1 }, { item: 'donut', label: 'Donut', amount: 2 }] },
                { id: 'm3', label: 'Commissary', items: [{ item: 'spikestrip', label: 'Chocolate bar', amount: 1, image: `${UP}inventory_images/handcuffs.png` }] },
            ] });
        } else if (view === 'evidence') {
            send('evidence', 'open', { place: 1, point: 'e1', station: 'Mission Row PD', max: 9999, shared: false, lockers: [
                { number: 1042, label: 'Case 1042 · Fleeca robbery, Route 68', by: 'Ruth Calloway', at: NOW - 600 },
                { number: 7, label: 'Recovered firearms, Grove St', by: 'Vincent Valentine', at: NOW - 7200 },
                { number: 318, label: 'Case 318 · Hit and run', by: 'Marco Reyes', at: NOW - 3600 * 20 },
                { number: 2210, label: '', by: 'Dana Kessler', at: NOW - 3600 * 50 },
            ] });
        } else if (view === 'impound') {
            send('impound', 'open', { plate: '46EEK572', model: 'Sultan RS', holds: [0, 1, 6, 12, 24, 48, 72], maxHours: 168, minFee: 0, maxFee: 25000,
                lots: [{ id: 3, name: 'Davis Impound', fee: 500, distance: 850 }, { id: 4, name: 'Sandy Shores Impound', fee: 350, distance: 3900 }] });
        } else if (view === 'impoundlot') {
            const police = params.get('police') === '1';
            send('impoundlot', 'open', { place: 3, point: 'k1', lot: 3, name: 'Davis Impound', canManage: police,
                mine: RECORDS.filter((r) => r.owner === 'Vincent Valentine' || r.id === 24).map((r) => Object.assign({}, r)),
                all: police ? RECORDS.filter((r) => r.lot === 3) : null });
            if (params.get('tab') === 'all') setTimeout(() => { const b = document.querySelector('[data-lt="all"]'); if (b) b.click(); }, 40);
        } else if (view === 'garage') {
            send('garage', 'open', { place: 1, point: 'g1', kind: 'garage', station: 'Mission Row PD', vehicles: STATION.vehicles.concat([{ model: 'fbi', label: 'Unmarked', grade: 3 }]) });
        } else if (view === 'boss' || view === 'office') {
            send('office', 'open', Object.assign({ place: 1, point: 'o1' }, OFFICE()));
            const pg = params.get('page');
            if (pg) setTimeout(() => { const b = document.querySelector(`.of-nav [data-page="${pg}"]`); if (b) b.click(); }, 40);
            if (params.get('record')) setTimeout(() => { const b = document.querySelector(`[data-record="${params.get('record')}"]`); if (b) b.click(); }, 120);
        } else if (view === 'fine') {
            send('form', 'open', { kind: 'fine', target: 12, max: 50000 });
        } else if (view === 'jail') {
            send('form', 'open', { kind: 'jail', target: 12, max: 300, minutesPerMonth: 1 });
        } else if (view === 'service') {
            send('service', 'show', { left: 7, reason: 'Vandalism on Vespucci Blvd', place: 'Legion Square' });
        } else if (view === 'serviceform') {
            send('form', 'open', { kind: 'service', target: 12, max: 50 });
        } else if (view === 'lab') {
            const bench = params.get('bench');
            if (bench) setTimeout(() => { const row = document.querySelector(`.lb-bag[data-key="${bench}"] [data-analyse]`); if (row) row.click(); }, 80);
            send('lab', 'open', { place: 1, point: 'l1', station: 'Mission Row PD', seconds: 1, bags: [
                { key: 'a', type: 'casing', label: 'Evidence: bullet casings', street: 'Strawberry Ave / Davis Ave', collected: '31/10 22:10', detail: 'SER123' },
                { key: 'b', type: 'blood', label: 'Evidence: blood sample', street: 'Grove St', collected: '31/10 22:26', detail: '3F9A-11C2' },
                { key: 'c', type: 'fingerprint', label: 'Evidence: prints from 46EEK572', street: '46EEK572', collected: '31/10 22:41', detail: 'KQ482T19XWD7704' },
            ], reports: [
                { id: 2, kind: 'blood', subject: 'Evidence: blood sample · Forum Dr', result: 'The DNA matches Dana Kessler.', officer: '2-L-14 Ruth Calloway', at: Math.floor(Date.now() / 1000) - 3600 },
                { id: 1, kind: 'casing', subject: 'Evidence: bullet casings · Legion Square', result: 'The gun with serial 7XK2291 is with Marco Reyes.', officer: '1-A-01 Vincent Valentine', at: Math.floor(Date.now() / 1000) - 7200 },
            ] });
        } else if (view === 'prisonshop') {
            const mode = params.get('mode') || 'commissary';
            const img = (n) => `${UP}inventory_images/${n}.png`;
            const data = mode === 'commissary' ? { mode, jail: 'Bolingbroke Penitentiary', credit: 34, items: [
                { id: 1, item: 'sandwich', label: 'Sandwich', price: 8, amount: 1 }, { id: 2, item: 'water_bottle', label: 'Water Bottle', price: 4, amount: 1 },
                { id: 3, item: 'prison_cigarettes', label: 'Cigarettes', price: 15, amount: 1, image: img('prison_cigarettes') }, { id: 4, call: true, label: 'Phone call', price: 20 },
            ] } : mode === 'trader' ? { mode, jail: 'Bolingbroke Penitentiary', currency: 'prison_cigarettes', currencyLabel: 'Cigarettes', currencyImage: img('prison_cigarettes'), wallet: 10,
                sells: [{ id: 1, item: 'prison_scrap', label: 'Scrap Metal', price: 2, image: img('prison_scrap') }, { id: 2, item: 'prison_spoon', label: 'Spoon', price: 6, image: img('prison_spoon') }, { id: 3, item: 'lockpick', label: 'Lockpick', price: 12 }],
                buys: [{ id: 1, item: 'prison_shiv', label: 'Shiv', price: 6, have: 1, image: img('prison_shiv') }, { id: 2, item: 'sandwich', label: 'Sandwich', price: 1, have: 0 }] }
                : { mode: 'craft', jail: 'Bolingbroke Penitentiary', recipes: [
                    { id: 1, item: 'prison_shiv', label: 'Shiv', seconds: 15, image: img('prison_shiv'), needs: [{ item: 'prison_scrap', label: 'Scrap Metal', need: 2, have: 3 }] },
                    { id: 2, item: 'lockpick', label: 'Lockpick', seconds: 10, needs: [{ item: 'prison_scrap', label: 'Scrap Metal', need: 1, have: 3 }] },
                    { id: 3, item: 'prison_cutters', label: 'Wire Cutters', seconds: 25, image: img('prison_cutters'), needs: [{ item: 'prison_scrap', label: 'Scrap Metal', need: 4, have: 3 }, { item: 'prison_shiv', label: 'Shiv', need: 1, have: 0 }] },
                ] };
            send('prisonshop', 'open', Object.assign({ point: 'ck' }, data));
            if (params.get('call') === '1') setTimeout(() => { const b = document.querySelector('[data-call]'); if (b) b.click(); const i = document.querySelector('#ps-who'); if (i) { i.value = 'mar'; i.dispatchEvent(new Event('input')); } }, 60);
        } else if (view === 'fieldnote') {
            document.documentElement.style.background = 'radial-gradient(ellipse at 50% 70%,#3a3f44 0%,#1f2327 60%,#0e1013 100%)';
            const kind = params.get('kind') || 'casing';
            send('fieldnote', 'show', kind === 'casing' ? { id: 1, kind, calibre: '9mm pistol round', group: 'pistol', count: 3, marked: true, age: 120, reach: true }
                : kind === 'blood' ? { id: 2, kind, count: 4, age: 600, reach: true } : { id: 3, kind: 'print', quality: 82, age: 60, reach: false });
        } else if (view === 'breath') {
            send('tests', 'open', { kind: 'breath', name: 'Terrence Obi', bac: params.get('sober') === '1' ? 0 : 0.112, limit: 0.08 });
        } else if (view === 'drugs') {
            send('tests', 'open', { kind: 'drugs', name: 'Terrence Obi', results: { thc: true, coc: false, met: params.get('meth') === '1', opi: false } });
        } else if (view === 'licences') {
            send('licences', 'open', { target: 2, name: 'Terrence Obi', canGrant: params.get('rank') !== '1', list: [{ kind: 'driver', has: true }, { kind: 'weapon', has: false }] });
        } else if (view === 'flag') {
            send('form', 'open', { kind: 'flag', plate: '46EEK572', current: params.get('flagged') === '1' ? 'Stolen from Legion Square' : null, maxHours: 720 });
        } else if (view === 'cameras') {
            const labels = ['Pacific Bank CAM#1', 'Pacific Bank CAM#2', 'Pacific Bank CAM#3', 'Limited Ltd Grove St. CAM#1', "Rob's Liqour Prosperity St. CAM#1", "Rob's Liqour San Andreas Ave. CAM#1", 'Limited Ltd Ginger St. CAM#1', '24/7 Supermarkt Innocence Blvd. CAM#1', "Rob's Liqour El Rancho Blvd. CAM#1", 'Fleeca Bank Hawick Ave CAM#1', 'Fleeca Bank Legion Square CAM#1'];
            send('cameras', 'open', { last: 11, cameras: labels.map((label, i) => ({ id: i + 1, label, online: i !== 3 })) });
        } else if (view === 'unitcams') {
            const units = [
                { src: 2, name: 'Vincent Valentine', callsign: '1A-07', rank: 'Sergeant', dept: 'LSPD', k: 'driving', street: 'Strawberry Ave', cross: 'Davis Ave', zone: 'Davis', dash: { plate: 'LSPD 4271', any: false } },
                { src: 3, name: 'Ruth Calloway', callsign: '1A-12', rank: 'Officer', dept: 'LSPD', k: 'foot', street: 'Vespucci Blvd', cross: '', zone: 'Little Seoul', dash: { plate: 'LSPD 1180', any: false } },
                { src: 4, name: 'Marco Reyes', callsign: '2B-03', rank: 'Lieutenant', dept: 'LSPD', k: 'riding', street: 'Great Ocean Hwy', cross: '', zone: 'Chumash' },
                { src: 5, name: 'Dana Kessler', callsign: '', rank: 'Cadet', dept: 'LSPD', k: 'foot', street: 'Sinner St', cross: 'Atlee St', zone: 'Mission Row' },
                { src: 6, name: 'Imani Brooks', callsign: '3C-21', rank: 'Deputy', dept: 'BCSO', k: 'driving', street: 'Route 68', cross: '', zone: 'Harmony', dash: { plate: '82KTR119', any: true } },
                { src: 1, name: 'XyraL', callsign: '1A-01', rank: 'Captain', dept: 'LSPD', k: 'foot', street: 'Sinner St', cross: '', zone: 'Mission Row', dash: { plate: 'LSPD 0001', any: false }, me: true },
            ];
            send('unitcams', 'open', { station: params.get('remote') === '1' ? '' : 'Mission Row PD', remote: params.get('remote') === '1', modes: { body: true, dash: true, cabin: params.get('cabin') !== '0' }, units: params.get('empty') === '1' ? [] : units });
        } else if (view === 'unitfeed') {
            document.documentElement.style.background = params.get('mode') === 'body' || !params.get('mode') ? 'linear-gradient(180deg,#7d8790 0%,#59636b 50%,#2f363b 100%)' : 'linear-gradient(180deg,#8fa3b5 0%,#68798a 45%,#3c4248 46%,#2a2e32 100%)';
            const mode = params.get('mode') || 'body';
            send('unitfeed', 'show', { mode, src: 2, name: 'Vincent Valentine', callsign: '1A-07', rank: 'Sergeant', dept: 'LSPD', plate: mode === 'body' ? null : 'LSPD 4271', any: false,
                modes: { body: true, dash: true, cabin: true }, audio: params.get('mute') !== '1', many: true, unit: 'MPH', back: params.get('back') !== '0' });
            send('unitfeed', 'tick', { street: 'Strawberry Ave', cross: 'Davis Ave', zone: 'Davis', heading: 212, speed: mode === 'body' ? 3 : 47, inCar: mode !== 'body',
                lights: params.get('lights') === '1', siren: params.get('siren') === '1', talking: params.get('talk') === '1', radar: mode === 'dash' ? 54 : null });
            if (params.get('lost') === '1') send('unitfeed', 'signal', { ok: false });
            if (params.get('tune') === '1') send('unitfeed', 'tune', {});
        } else if (view === 'cctv') {
            document.documentElement.style.background = 'linear-gradient(180deg,#6c757b 0%,#4b545a 55%,#2e3337 100%)';
            send('cctv', 'show', { id: 22, label: 'Fleeca Bank Legion Square CAM#1', offline: params.get('off') === '1', rotate: true });
        } else if (view === 'heli') {
            document.documentElement.style.background = 'radial-gradient(ellipse at 50% 60%,#4a5a4e 0%,#2b352e 60%,#141a16 100%)';
            send('heli', 'show', {});
            send('heli', 'update', { vision: params.get('thermal') === '1' ? 'Thermal' : 'Day', zoom: 62, heading: 214, altitude: 186, scan: 100,
                target: { model: 'Sultan RS', plate: '46EEK572', speed: 87, unit: 'MPH', street: 'Strawberry Ave / Davis Ave', flagged: params.get('flag') === '1' ? 'Stolen from Legion Square' : null } });
        } else if (view === 'radar') {
            send('radar', 'show', {});
            send('radar', 'update', { patrol: 54, unit: 'MPH', fast: 88, locked: params.get('lock') === '1',
                front: { speed: 71, plate: '46EEK572', flagged: params.get('flag') === '1' ? 'Stolen' : null }, rear: { speed: 49, plate: '81XSP402' } });
        } else if (view === 'scanner') {
            send('scanner', 'open', { name: 'Terrence Obi', print: 'KQ482T19XWD7704', dna: '3F9A-11C2', cid: 'RTX40211', target: 2, mdt: params.get('nomdt') !== '1', mdtProfile: true, seed: 7319, record: { bookings: 3, last: Math.floor(Date.now() / 1000) - 86400 * 2, warrants: params.get('wanted') === '1' ? 1 : 0, scenes: 2 },
                matches: params.get('none') === '1' ? [] : [
                    { kind: 'fingerprint', label: 'Evidence: fingerprint', street: 'Strawberry Ave / Davis Ave', collected: '31/10 22:10' },
                    { kind: 'blood', label: 'Evidence: blood sample', street: 'Grove St', collected: '31/10 22:26' },
                ] });
        } else if (view === 'idcard') {
            send('idcard', 'open', { wanted: params.get('wanted') === '1' ? 2 : 0, photo: params.get('photo') === '1' ? `${UP}inventory_images/handcuffs.png` : null, firstname: 'Vincent', lastname: 'Valentine', dob: '1991-06-14', nationality: 'American', female: false, citizenid: 'XSP82145', driver: true, weapon: false, jailed: params.get('jailed') === '1' });
        } else if (view === 'band') {
            send('jail', 'open', { left: 1745, months: 30, reason: 'Armed robbery, evading', number: '4821', escaped: params.get('escaped') === '1' });
            if (params.get('escaped') === '1') send('jail', 'escaped', {});
        } else if (view === 'builder') {
            builderData().then(({ settings }) => {
                const SERVICE = { id: 5, kind: 'service', name: 'Legion Square Clean-up', markers: false, blip: { show: true, sprite: 365, colour: 17, scale: 0.8, label: '', short: true, who: 'all' },
                    points: { task: [{ id: 't1', x: 195.2, y: -934.1, z: 30.7, w: 0 }, { id: 't2', x: 182.6, y: -948.8, z: 30.1, w: 0 }, { id: 't3', x: 168.9, y: -985.3, z: 30.1, w: 0 }, { id: 't4', x: 206.4, y: -1003.7, z: 29.3, w: 0 }] } };
                const PALETO = { id: 6, kind: 'station', name: 'Paleto Bay Sheriff', enabled: false, jobs: ['bcso'], plate: 'BCSO', armory: [], vehicles: [{ model: 'sheriff', label: 'Sheriff Cruiser', grade: 0, livery: -1, extras: [] }], helicopters: [],
                    points: { duty: [{ id: 'pd1', x: -449.8, y: 6012.9, z: 31.8, w: 0 }], garage: [{ id: 'pg1', x: -455.4, y: 6002.0, z: 31.3, w: 88, spawn: { x: -455.4, y: 6002.0, z: 31.3, w: 88 } }] } };
                send('builder', 'open', {
                    places: [STATION, JAIL, IMPOUND, CUSTOM_BLIP, SERVICE, PALETO],
                    jailTest: params.get('jailtest') === '1' ? { jail: 'Bolingbroke Penitentiary', left: 272, escaped: params.get('escaped') === '1' } : undefined,
                    vehicles: [{ model: 'police', label: 'Police Cruiser' }, { model: 'police2', label: 'Police Buffalo' }, { model: 'police3', label: 'Police Interceptor' }, { model: 'policeb', label: 'Police Bike' }, { model: 'fbi', label: 'FIB Buffalo' }, { model: 'sheriff', label: 'Sheriff Cruiser' }, { model: 'polmav', label: 'Police Maverick' }],
                    items: [{ name: 'weapon_combatpistol', label: 'Combat Pistol' }, { name: 'weapon_stungun', label: 'Taser' }, { name: 'weapon_nightstick', label: 'Nightstick' }, { name: 'weapon_flashlight', label: 'Flashlight' }, { name: 'weapon_pumpshotgun', label: 'Pump Shotgun' }, { name: 'weapon_carbinerifle', label: 'Carbine Rifle' },
                        { name: 'pistol_ammo', label: 'Pistol Ammo' }, { name: 'rifle_ammo', label: 'Rifle Ammo' }, { name: 'armor', label: 'Body Armour' }, { name: 'radio', label: 'Radio' }, { name: 'sandwich', label: 'Sandwich' }, { name: 'water_bottle', label: 'Water Bottle' },
                        { name: 'handcuffs', label: 'Handcuffs', image: `${UP}inventory_images/handcuffs.png` }, { name: 'spikestrip', label: 'Spike Strip', image: `${UP}inventory_images/spikestrip.png` }, { name: 'empty_evidence_bag', label: 'Evidence Bag', image: `${UP}inventory_images/empty_evidence_bag.png` }],
                    jobs: [
                        { name: 'bcso', label: 'BCSO', grades: [{ grade: 0, label: 'Deputy' }, { grade: 1, label: 'Senior Deputy' }, { grade: 2, label: 'Sergeant' }, { grade: 3, label: 'Lieutenant' }, { grade: 4, label: 'Sheriff' }] },
                        { name: 'police', label: 'LSPD', grades: [{ grade: 0, label: 'Cadet' }, { grade: 1, label: 'Officer' }, { grade: 2, label: 'Sergeant' }, { grade: 3, label: 'Lieutenant' }, { grade: 4, label: 'Chief' }] },
                        { name: 'sast', label: 'SAST', grades: [{ grade: 0, label: 'Trooper' }, { grade: 1, label: 'Senior Trooper' }, { grade: 2, label: 'Corporal' }] },
                    ],
                    defaults: { armory: STATION.armory, vehicles: STATION.vehicles, helicopters: STATION.helicopters, plate: 'LSPD', radius: 150, fee: 500, clerk: 's_m_y_cop_01', minFee: 0, maxFee: 25000, markers: false,
                        jobs: [{ label: 'Fix the wiring', activity: 'repair' }, { label: 'Sweep the yard', activity: 'sweep' }], jobSeconds: 12, jobCredit: 30,
                        meals: [{ label: 'Lunch tray', items: [{ item: 'sandwich', amount: 1 }, { item: 'water_bottle', amount: 1 }] }], mealMinutes: 5,
                        activities: [{ key: 'repair', label: 'Electrical repairs' }, { key: 'sweep', label: 'Sweeping' }, { key: 'clean', label: 'Cleaning' }, { key: 'cook', label: 'Kitchen duty' }, { key: 'garden', label: 'Gardening' }],
                        exercises: [{ key: 'pushups', label: 'Push-ups' }, { key: 'situps', label: 'Sit-ups' }, { key: 'chinups', label: 'Chin-ups' }, { key: 'weights', label: 'Free weights' }, { key: 'yoga', label: 'Yoga' }],
                        bolingbroke: { center: { x: 1693.33, y: 2569.51, z: 44.55 }, radius: 200, points: { cell: [{ x: 1661.05, y: 2524.68, z: 45.56, w: 260.5 }, { x: 1650.81, y: 2540.58, z: 45.56, w: 230.4 }, { x: 1697.11, y: 2525.56, z: 45.56, w: 187.2 }], canteen: [{ x: 1778.31, y: 2560.56, z: 45.62, w: 181.1 }], workout: [{ x: 1770.72, y: 2479.98, z: 45.74, w: 31.7, exercise: 'pushups' }], release: [{ x: 1848.13, y: 2586.05, z: 44.67, w: 269.5 }] }, work: [{ label: 'Fix the wiring', activity: 'repair', spots: [{ x: 1761.46, y: 2540.41, z: 45.56, w: 272.2 }, { x: 1718.54, y: 2527.8, z: 45.56, w: 272.2 }] }] },
                        templates: {
                            missionrow: { kind: 'station', name: 'Mission Row PD', points: { duty: [{ x: 440.09, y: -974.92, z: 30.69, w: 0 }], locker: [{ x: 453.08, y: -980.12, z: 30.89, w: 0 }], armory: [{ x: 462.23, y: -981.12, z: 30.68, w: 90 }], garage: [{ x: 448.16, y: -1017.41, z: 28.56, w: 90.65, spawn: { x: 448.16, y: -1017.41, z: 28.56, w: 90.65 } }], helipad: [{ x: 449.17, y: -981.33, z: 43.69, w: 87.23, spawn: { x: 449.17, y: -981.33, z: 43.69, w: 87.23 } }], evidence: [{ x: 442.17, y: -996.07, z: 30.69, w: 0 }], booking: [{ x: 460.97, y: -989.18, z: 24.92, w: 0 }], boss: [{ x: 461.45, y: -986.2, z: 30.73, w: 0 }] } },
                            paleto: { kind: 'station', name: 'Paleto Bay Sheriff', points: { duty: [{ x: -449.81, y: 6012.91, z: 31.82, w: 0 }], garage: [{ x: -455.39, y: 6002.02, z: 31.34, w: 87.93, spawn: { x: -455.39, y: 6002.02, z: 31.34, w: 87.93 } }] } },
                        },
                        blips: { station: { sprite: 60, colour: 29, scale: 0.8 }, jail: { sprite: 285, colour: 1, scale: 0.8 }, impound: { sprite: 68, colour: 47, scale: 0.8 }, custom: { sprite: 162, colour: 3, scale: 0.8 }, service: { sprite: 365, colour: 17, scale: 0.8 } } },
                    kinds: KINDS,
                    wheel: WHEEL,
                    wheelDefs: WHEEL_DEFS,
                    settings,
                    live: { 2: { inmates: 3 }, 3: { held: 5 }, 5: { serving: 1 } },
                    system: { framework: 'qbox', inventory: 'ox_inventory', target: 'ox_target', banking: 'Renewed-Banking', dispatch: 'XS-Dispatch', keys: 'qbx_vehiclekeys', fuel: 'ox_fuel', clothing: 'illenium-appearance', mdt: 'XS-MDT', onDuty: 7, admin: 'XyraL' },
                });
                const go = params.get('go');
                const click = (sel) => { const el = document.querySelector(sel); if (el) el.click(); return el; };
                setTimeout(() => {
                    if (go === 'wheel' || params.get('wheel') === '1') click('[data-act="nav"][data-page="wheel"]');
                    if (go === 'settings') click('[data-act="nav"][data-page="settings"]');
                    if (go === 'list') click(`[data-act="nav"][data-page="list"][data-kind="${params.get('kind') || 'station'}"]`);
                    if (go === 'palette') click('[data-act="palette"]');
                    if (go === 'tpl') click(`[data-act="tpl"][data-tpl="${params.get('tpl') || 'missionrow'}"]`);
                    const tab = params.get('tab');
                    if (tab || go === 'edit') {
                        click(`.bx-table [data-act="open"][data-id="${params.get('pick') || 1}"]`);
                        if (tab) setTimeout(() => click(`[data-act="tab"][data-tab="${tab}"]`), 30);
                    }
                    const sec = params.get('sec');
                    if (sec) setTimeout(() => click(`[data-sec-go="${sec}"]`), 30);
                    const pg = params.get('page');
                    if (pg) setTimeout(() => click(`[data-page="${pg}"].bx-tab`), 30);
                    const edit = params.get('edit');
                    if (edit) setTimeout(() => click(`.we-item[data-ref="${edit}"]`), 60);
                }, 60);
            });
        }
    }

    fetch(`${UP}locales/en.lua`).then((r) => r.text()).then((text) => {
        const T = {};
        for (const m of text.matchAll(/([A-Za-z0-9_]+) = '((?:[^'\\]|\\.)*)'/g)) T[m[1]] = m[2].replace(/\\'/g, "'");
        send('core', 'boot', { locale: T, config: {} });
        show();
    }).catch(() => {
        send('core', 'boot', { locale: {}, config: {} });
        show();
    });
})();

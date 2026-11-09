(() => {
    const root = document.getElementById('xsp-builder');
    const t = XS.t;
    const esc = XS.esc;
    const I = (name, size) => XS.icon(name, size || 16);

    const KINDS = ['station', 'jail', 'impound', 'service', 'blip'];
    const ICON = { station: 'building', jail: 'jail', impound: 'tow', service: 'broom', blip: 'mapblip' };
    const DEFAULT_NAME = { station: 'station_default_name', jail: 'jail_default_name', impound: 'impound_default_name', blip: 'blip_default_name', service: 'service_default_name' };
    const TABS = { station: ['layout', 'armory', 'garage', 'options', 'blip'], jail: ['layout', 'jobs', 'canteen', 'options', 'blip'], impound: ['layout', 'options', 'blip'], service: ['layout', 'options', 'blip'], blip: ['blip', 'options'] };
    const NEEDED = { station: ['duty'], jail: ['cell', 'release'], impound: ['desk', 'lot'], service: ['task'], blip: [] };
    const NICE = { station: ['locker', 'armory', 'garage', 'evidence', 'booking', 'boss', 'camroom'], jail: ['canteen', 'workout'], impound: [], service: [], blip: [] };
    const TEMPLATES = [
        { id: 'missionrow', kind: 'station', name: 'bx_tpl_missionrow', fb: 'Mission Row PD', sub: 'bx_tpl_missionrow_sub', subFb: 'Duty, lockers, armory, garage, roof helipad, evidence, booking and the boss office, at the standard Mission Row interior.' },
        { id: 'paleto', kind: 'station', name: 'bx_tpl_paleto', fb: 'Paleto Bay Sheriff', sub: 'bx_tpl_paleto_sub', subFb: 'Duty, garage and helipad at the Paleto Bay sheriff office.' },
        { id: 'bolingbroke', kind: 'jail', name: 'bx_tpl_bolingbroke', fb: 'Bolingbroke Penitentiary', sub: 'bx_tpl_bolingbroke_sub', subFb: 'Cells, canteen, workout, a prison job, the release gate and the escape circle.' },
    ];

    const S = {
        open: false, page: 'overview', kind: 'station', places: [], catalog: { vehicles: [], items: [], jobs: [] }, defaults: {}, kinds: {},
        system: {}, live: {}, areas: {}, cur: null, dirty: false, busy: false, tab: 'layout', sel: null, labels: true, filter: '',
        overlay: null, bbq: '', shell: false,
    };

    const uid = () => `p${Date.now().toString(36)}${Math.floor(Math.random() * 1e6).toString(36)}`;
    const copy = (v) => JSON.parse(JSON.stringify(v));
    const kindDefs = (kind) => XS.list(S.kinds[kind]);
    const kindName = (kind) => t(`bx_kind_${kind}`, null, kind);
    const kindPlural = (kind) => t(`bx_nav_${kind}`, null, kind);
    const pointName = (key) => t(`point_${key}`, null, key);
    const pointHint = (key) => t(`point_${key}_hint`, null, '');
    const count = (list) => XS.list(list).length;
    const fixed = (n) => (Number(n) || 0).toFixed(1);
    const pageEl = () => root.querySelector('#bx-page');

    function blipDefaults(kind) {
        const B = (S.defaults.blips || {})[kind] || (S.defaults.blips || {}).custom || {};
        return { show: true, sprite: B.sprite || 1, colour: B.colour || 0, scale: B.scale || 0.8, label: '', short: true, who: 'all' };
    }

    function normalise(place) {
        place.points = place.points && !Array.isArray(place.points) ? place.points : {};
        kindDefs(place.kind).forEach((k) => { place.points[k.key] = XS.list(place.points[k.key]); });
        const b = place.blip && typeof place.blip === 'object' && !Array.isArray(place.blip) ? place.blip : { show: place.blip !== false };
        place.blip = Object.assign(blipDefaults(place.kind), b);
        place.enabled = place.enabled !== false;
        if (place.kind !== 'blip' && place.markers === undefined) place.markers = S.defaults.markers === true;
        if (place.kind === 'impound' || place.kind === 'station') place.jobs = XS.list(place.jobs);
        if (place.kind === 'jail') {
            place.work = XS.list(place.work).map((w) => Object.assign(w, { spots: XS.list(w.spots) }));
            place.meals = XS.list(place.meals).map((m) => Object.assign(m, { items: XS.list(m.items) }));
            if (place.mealMinutes === undefined) place.mealMinutes = Number(S.defaults.mealMinutes) || 5;
        }
        if (place.kind === 'station') {
            place.armory = XS.list(place.armory);
            place.vehicles = XS.list(place.vehicles).map((v) => Object.assign(v, { extras: XS.list(v.extras) }));
            place.helicopters = XS.list(place.helicopters).map((v) => Object.assign(v, { extras: XS.list(v.extras) }));
        }
        return place;
    }

    function newPlace(kind) {
        const D = S.defaults;
        const p = { id: null, kind, name: t(DEFAULT_NAME[kind], null, kind), blip: blipDefaults(kind), points: {}, enabled: true };
        if (kind === 'station') {
            Object.assign(p, { jobs: [], plate: D.plate || 'LSPD', armory: copy(XS.list(D.armory)), vehicles: copy(XS.list(D.vehicles)), helicopters: copy(XS.list(D.helicopters)) });
        } else if (kind === 'jail') {
            Object.assign(p, {
                radius: D.radius || 150,
                work: XS.list(D.jobs).map((d) => ({ id: uid(), label: d.label, activity: d.activity, seconds: Number(D.jobSeconds) || 12, credit: Number(D.jobCredit) || 30, pay: Number(D.jobPay) || 0, spots: [] })),
                meals: XS.list(D.meals).map((m) => ({ id: uid(), label: m.label, items: copy(XS.list(m.items)) })),
                mealMinutes: Number(D.mealMinutes) || 5,
            });
        } else if (kind === 'impound') {
            Object.assign(p, { jobs: [], fee: Number(D.fee) || 0, clerk: D.clerk || '' });
        }
        return normalise(p);
    }

    function anchor(p) {
        if (!p) return null;
        if (p.blipAt && p.blipAt.x !== undefined) return p.blipAt;
        if (p.center && p.center.x !== undefined) return p.center;
        for (const def of kindDefs(p.kind)) {
            const first = XS.list((p.points || {})[def.key])[0];
            if (first) return first;
        }
        for (const w of XS.list(p.work)) if (XS.list(w.spots)[0]) return w.spots[0];
        return null;
    }

    function pointTotal(p) {
        const spots = XS.list(p.work).reduce((n, w) => n + count(w.spots), 0);
        return Object.values(p.points || {}).reduce((n, list) => n + count(list), 0) + spots;
    }

    function areaText(p) {
        const a = S.areas[p && p.id !== null && p.id !== undefined ? String(p.id) : 'cur'];
        if (!a) return '';
        return [a.street, a.zone].filter(Boolean).join(', ');
    }

    async function loadAreas(list) {
        const ask = list.map((p) => {
            const a = anchor(p);
            return a ? { id: p.id === null || p.id === undefined ? 'cur' : p.id, x: a.x, y: a.y, z: a.z } : null;
        }).filter(Boolean);
        if (!ask.length) return;
        const res = await XS.rpc('builder:areas', ask);
        if (res.ok && res.data && typeof res.data === 'object') {
            Object.assign(S.areas, res.data);
            if (!S.open) return;
            if (S.page === 'overview' || S.page === 'list') renderPage();
            else refreshAreaText();
        }
    }

    function refreshAreaText() {
        const el = root.querySelector('#bx-area');
        if (el && S.cur) el.textContent = areaText(S.cur) || t('bx_area_unknown', null, 'No points yet');
    }

    let areaTimer = null;
    function select() {
        XS.rpc('builder:select', S.page === 'edit' ? S.cur : null);
        if (S.page === 'edit' && S.cur) {
            clearTimeout(areaTimer);
            areaTimer = setTimeout(() => loadAreas([S.cur]), 250);
        }
    }

    function settingOn(key) {
        const v = XS.BuilderSettings.value(key);
        return v !== false;
    }

    function gradeOpts(value) {
        const names = {};
        let max = 0;
        XS.list(S.catalog.jobs).forEach((j) => XS.list(j.grades).forEach((g) => {
            const n = Number(g.grade) || 0;
            if (n > max) max = n;
            if (!names[n]) names[n] = g.label;
        }));
        if (!Object.keys(names).length) max = 10;
        max = Math.max(max, Number(value) || 0);
        let out = '';
        for (let n = 0; n <= max; n++) out += `<option value="${n}" ${(Number(value) || 0) === n ? 'selected' : ''}>${esc(names[n] ? `${n} · ${names[n]}` : String(n))}</option>`;
        return out;
    }

    function itemInfo(name) {
        const hit = S.catalog.items.find((i) => i.name === name);
        return hit || null;
    }

    function thumb(name) {
        const hit = itemInfo(name);
        return `<span class="bx-thumb">${hit && hit.image ? `<img src="${esc(hit.image)}" alt="" onerror="this.remove()">` : I('box', 18)}</span>`;
    }

    function placeIssues(p) {
        const out = [];
        if (p.enabled === false) return [{ level: 'info', text: t('iss_off', null, 'Switched off'), sub: t('iss_off_sub', null, 'Players cannot see or use it until you switch it back on.'), tab: 'options' }];
        const n = (k) => count((p.points || {})[k]);
        NEEDED[p.kind].forEach((k) => {
            if (!n(k)) out.push({ level: 'bad', text: t('iss_need', { what: pointName(k) }, 'No %{what} point'), sub: pointHint(k), tab: 'layout', group: k });
        });
        if (p.kind === 'station') {
            if (!n('armory')) out.push({ level: 'warn', text: t('iss_no_armory', null, 'No armory'), sub: t('iss_no_armory_sub', null, 'Officers have nowhere to get weapons and gear.'), tab: 'layout', group: 'armory' });
            if (!n('garage')) out.push({ level: 'warn', text: t('iss_no_garage', null, 'No garage'), sub: t('iss_no_garage_sub', null, 'Officers have nowhere to take out a car.'), tab: 'layout', group: 'garage' });
            if (n('garage') && !count(p.vehicles)) out.push({ level: 'bad', text: t('iss_no_cars', null, 'The garage has no cars'), sub: t('iss_no_cars_sub', null, 'Add some on the Garage tab.'), tab: 'garage' });
            if (n('helipad') && !count(p.helicopters)) out.push({ level: 'warn', text: t('iss_no_helis', null, 'The helipad has no helicopters'), sub: t('iss_no_cars_sub', null, 'Add some on the Garage tab.'), tab: 'garage' });
            if (n('armory') && !count(p.armory)) out.push({ level: 'warn', text: t('iss_empty_armory', null, 'The armory is empty'), sub: t('iss_empty_armory_sub', null, 'Add items on the Armory tab.'), tab: 'armory' });
        } else if (p.kind === 'jail') {
            if (!n('canteen')) out.push({ level: 'info', text: t('iss_no_canteen', null, 'No canteen'), sub: t('iss_no_canteen_sub', null, 'Prisoners cannot get food.'), tab: 'layout', group: 'canteen' });
            if (n('canteen') && !count(p.meals)) out.push({ level: 'warn', text: t('iss_no_meals', null, 'The canteen serves nothing'), sub: t('iss_no_meals_sub', null, 'Add a meal on the Canteen tab.'), tab: 'canteen' });
            const empty = XS.list(p.work).filter((w) => !count(w.spots)).length;
            if (empty) out.push({ level: 'info', text: (empty === 1 ? t('iss_job_spots_one', null, 'A prison job has no spots') : t('iss_job_spots', { n: empty }, '%{n} prison jobs have no spots')), sub: t('iss_job_spots_sub', null, 'Jobs without spots are hidden from prisoners.'), tab: 'jobs' });
            const exitless = ['tunnel', 'fence'].reduce((n, k) => n + XS.list(p.points[k]).filter((pt) => !pt.exit).length, 0);
            if (exitless) out.push({ level: 'warn', text: (exitless === 1 ? t('iss_no_exit_one', null, 'A breakout spot has no exit') : t('iss_no_exit', { n: exitless }, '%{n} breakout spots have no exit')), sub: t('iss_no_exit_sub', null, 'Set where each tunnel or fence comes out.'), tab: 'layout', group: XS.list(p.points.tunnel).some((pt) => !pt.exit) ? 'tunnel' : 'fence' });
            if (!p.center || p.center.x === undefined) out.push({ level: 'info', text: t('iss_no_center', null, 'Escape circle sits on the first cell'), sub: t('iss_no_center_sub', null, 'Set the prison centre on the Options tab for an exact fit.'), tab: 'options' });
        } else if (p.kind === 'blip') {
            if (!p.blipAt || p.blipAt.x === undefined) out.push({ level: 'bad', text: t('iss_blip_unplaced', null, 'Not on the map yet'), sub: t('iss_blip_unplaced_sub', null, 'Pick where it sits on the Map blip tab.'), tab: 'blip' });
        }
        return out;
    }

    function globalIssues() {
        const out = [];
        const on = S.places.filter((p) => p.enabled !== false);
        if (!on.some((p) => p.kind === 'station' && count(p.points.duty))) {
            out.push({ level: 'bad', text: t('iss_no_station', null, 'No station with a duty point'), sub: t('iss_no_station_sub', null, 'Officers need one to clock on. Mission Row PD sets one up in a click.'), fix: { tpl: 'missionrow' } });
        }
        if (settingOn('Jail.enabled') && !on.some((p) => p.kind === 'jail' && count(p.points.cell))) {
            out.push({ level: 'warn', text: t('iss_no_prison', null, 'No prison with cells'), sub: t('iss_no_prison_sub', null, 'Jail sentences need one. The Bolingbroke layout fills it all in.'), fix: { tpl: 'bolingbroke' } });
        }
        S.places.forEach((p) => placeIssues(p).forEach((i) => out.push(Object.assign({ place: p }, i))));
        const rank = { bad: 0, warn: 1, info: 2 };
        return out.sort((a, b) => rank[a.level] - rank[b.level]);
    }

    function readiness() {
        let done = 0;
        let total = 2;
        const on = S.places.filter((p) => p.enabled !== false);
        if (on.some((p) => p.kind === 'station' && count(p.points.duty))) done++;
        if (!settingOn('Jail.enabled') || on.some((p) => p.kind === 'jail' && count(p.points.cell))) done++;
        on.forEach((p) => {
            NEEDED[p.kind].concat(NICE[p.kind]).forEach((k) => { total++; if (count(p.points[k])) done++; });
            if (p.kind === 'blip') { total++; if (p.blipAt && p.blipAt.x !== undefined) done++; }
        });
        return Math.round((done / total) * 100);
    }

    function liveText(p) {
        const L = S.live[String(p.id)] || {};
        if (p.kind === 'jail') return t('bx_live_inmates', { n: L.inmates || 0 }, '%{n} inmates now');
        if (p.kind === 'impound') return t('bx_live_held', { n: L.held || 0 }, '%{n} cars held');
        if (p.kind === 'service') return t('bx_live_serving', { n: L.serving || 0 }, '%{n} serving now');
        if (p.kind === 'blip') return t(`builder_blip_who_${(p.blip && p.blip.who) || 'all'}`, null, '');
        return t('bx_points_n', { n: pointTotal(p) }, '%{n} points');
    }

    function statusChips(p) {
        const iss = placeIssues(p);
        const bad = iss.filter((i) => i.level === 'bad').length;
        const warn = iss.filter((i) => i.level === 'warn').length;
        if (p.enabled === false) return `<span class="bx-chip off">${I('power', 11)}${esc(t('bx_off', null, 'Off'))}</span>`;
        if (bad) return `<span class="bx-chip bad">${I('alert', 11)}${esc(t('bx_needs_n', { n: bad + warn }, '%{n} to fix'))}</span>`;
        if (warn) return `<span class="bx-chip warn">${I('alert', 11)}${esc(t('bx_needs_n', { n: warn }, '%{n} to fix'))}</span>`;
        return `<span class="bx-chip ok">${I('check', 11)}${esc(t('bx_ready', null, 'Ready'))}</span>`;
    }

    function plan(p, opts) {
        return XS.Plan.render(p, kindDefs(p.kind), Object.assign({
            radius: S.defaults.radius, name: (k, i) => `${pointName(k)} ${i + 1}`, empty: t('bx_plan_empty', null, 'Nothing placed yet'),
        }, opts || {}));
    }

    function badge() {
        return `<svg class="bx-badge" viewBox="0 0 40 40"><defs><linearGradient id="bxBadge" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8fc0ff"/><stop offset="1" stop-color="#2563eb"/></linearGradient></defs>
            <path d="M20 2.5l14 5.2v9.6c0 9-6 16.2-14 20.2C12 33.5 6 26.3 6 17.3V7.7z" fill="url(#bxBadge)"/>
            <path d="M20 5.6l11.2 4.2v7.6c0 7.4-4.8 13.4-11.2 16.8C13.6 30.8 8.8 24.8 8.8 17.4V9.8z" fill="#08111f"/>
            <text x="20" y="23.4" text-anchor="middle" fill="#dbeaff" font-family="Segoe UI,Arial" font-weight="900" font-size="11.5" letter-spacing=".5">XS</text></svg>`;
    }

    function shell() {
        const sys = S.system || {};
        const stage = XS.stage(root);
        stage.innerHTML = `<div class="bx bx-in">
            <div class="bx-lightbar"></div>
            <div class="bx-top">
                <div class="bx-logo">${badge()}<div class="bx-word"><b>XS-<span>PoliceSystem</span></b><small>${esc(t('bx_builder', null, 'Builder'))}</small></div></div>
                <button class="bx-search" data-act="palette">${I('search', 16)}<span class="bx-stext">${esc(t('bx_search', null, 'Search places, settings and actions'))}</span><span class="bx-kbd">Ctrl</span><span class="bx-kbd">K</span></button>
                <span class="bx-sp"></span>
                <div class="bx-sys">
                    <span class="bx-pill ${sys.onDuty ? '' : 'off'}"><i></i>${esc(t('bx_on_duty', { n: Number(sys.onDuty) || 0 }, '%{n} on duty'))}</span>
                    ${sys.framework ? `<span class="bx-pill">${esc(sys.framework === 'qbox' ? 'Qbox' : 'QBCore')}</span>` : ''}
                </div>
                <button class="bx-iconbtn" data-act="walk" title="${esc(t('bx_walk_tip', null, 'Hide the builder and walk around. Every point is labelled.'))}">${I('eye', 16)}${esc(t('bx_walk', null, 'Walk the site'))}</button>
                <button class="bx-iconbtn close" data-act="close" title="${esc(t('close', null, 'Close'))}">${I('close', 16)}</button>
            </div>
            <div class="bx-body">
                <div class="bx-nav" id="bx-nav"></div>
                <div class="bx-main"><div class="bx-page xsp-scroll" id="bx-page"></div></div>
            </div>
            <div id="bx-ov"></div>
        </div>`;
        const page = pageEl();
        page.addEventListener('click', onClick);
        page.addEventListener('input', onInput);
        page.addEventListener('change', onChange);
        page.addEventListener('keydown', onPageKey);
        page.addEventListener('focusin', (e) => { if (e.target.dataset && e.target.dataset.picker) pickerUpdate(e.target); });
        page.addEventListener('focusout', (e) => { if (e.target.dataset && e.target.dataset.picker) setTimeout(() => pickerClose(e.target), 150); });
        stage.querySelector('.bx-top').addEventListener('click', onClick);
        stage.querySelector('#bx-nav').addEventListener('click', onClick);
        stage.querySelector('#bx-ov').addEventListener('click', onClick);
        stage.querySelector('#bx-ov').addEventListener('input', onPaletteInput);
        stage.querySelector('#bx-ov').addEventListener('keydown', onPaletteKey);
        S.shell = true;
        renderNav();
        renderPage(true);
        renderOverlay();
    }

    function renderNav() {
        const nav = root.querySelector('#bx-nav');
        if (!nav) return;
        const n = (kind) => S.places.filter((p) => p.kind === kind).length;
        const bad = (kind) => S.places.filter((p) => p.kind === kind && placeIssues(p).some((i) => i.level === 'bad')).length;
        const item = (page, kind, icon, label, badgeHtml) => {
            const on = (page === S.page && (page !== 'list' || kind === S.kind)) || (page === 'list' && S.page === 'edit' && S.cur && S.cur.kind === kind);
            return `<button class="bx-navitem ${on ? 'on' : ''}" data-act="nav" data-page="${page}" ${kind ? `data-kind="${kind}"` : ''}>${I(icon, 17)}<span class="bx-navlabel">${esc(label)}</span>${badgeHtml || ''}</button>`;
        };
        const changed = XS.BuilderSettings.changedCount();
        const admin = String((S.system || {}).admin || 'Admin');
        nav.innerHTML = `<div class="bx-navgroup">${esc(t('bx_nav_build', null, 'Build'))}</div>
            ${item('overview', null, 'grid', t('bx_nav_overview', null, 'Overview'))}
            ${KINDS.map((k) => item('list', k, ICON[k], kindPlural(k), `<span class="bx-count ${bad(k) ? 'warn' : ''}">${n(k)}</span>`)).join('')}
            <div class="bx-navsep"></div>
            <div class="bx-navgroup">${esc(t('bx_nav_system', null, 'System'))}</div>
            ${item('wheel', null, 'wheel', t('we_title', null, 'Quick action wheel'), XS.WheelEditor.isDirty() ? '<span class="bx-dot warn"></span>' : '')}
            ${item('settings', null, 'sliders', t('bs_title', null, 'Settings'), changed ? `<span class="bx-count">${changed}</span>` : '')}
            <div class="bx-me"><span class="bx-avatar">${esc(admin.slice(0, 2).toUpperCase())}</span><div style="min-width:0"><b>${esc(admin)}</b><small>${esc(t('bx_admin', null, 'Builder access'))}</small></div></div>`;
    }

    function renderPage(top) {
        const page = pageEl();
        if (!page) return;
        const scroll = page.scrollTop;
        XS.BuilderSettings.unmount();
        if (S.page === 'wheel') {
            XS.WheelEditor.mount(page, renderNav);
        } else if (S.page === 'settings') {
            XS.BuilderSettings.mount(page, renderNav);
        } else {
            page.innerHTML = S.page === 'overview' ? overview() : S.page === 'list' ? listPage() : S.page === 'edit' && S.cur ? editor() : overview();
            page.querySelectorAll('.bb-sp img').forEach((img) => { if (img.complete && img.naturalWidth === 0) img.classList.add('gone'); });
        }
        page.scrollTop = top ? 0 : scroll;
    }

    function overview() {
        const issues = globalIssues();
        const pct = readiness();
        const C = 2 * Math.PI * 50;
        const by = (k) => S.places.filter((p) => p.kind === k);
        const sum = (k, f) => by(k).reduce((n, p) => n + (Number((S.live[String(p.id)] || {})[f]) || 0), 0);
        const stat = (cls, n, label, sub, icon, go) => `<div class="bx-stat ${cls}" data-act="nav" data-page="${go[0]}" ${go[1] ? `data-kind="${go[1]}"` : ''}>${I(icon, 18)}<b>${n}</b><span>${esc(label)}</span><em>${esc(sub)}</em></div>`;
        const head = issues.filter((i) => i.level !== 'info').length;
        return `<div class="bx-pagehead"><div><h1>${esc(t('bx_overview_title', null, 'Overview'))}</h1><p>${esc(t('bx_overview_sub', null, 'Every station, prison and impound lot you have built, what still needs doing, and quick ways to set things up.'))}</p></div></div>
            <div class="bx-ov">
                <div class="bx-card bx-ready">
                    <div class="bx-ring"><svg width="118" height="118" viewBox="0 0 118 118"><defs><linearGradient id="bxRingGrad" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7cb4ff"/><stop offset="1" stop-color="#2f6fe0"/></linearGradient></defs><circle class="track" cx="59" cy="59" r="50"/><circle class="fill" cx="59" cy="59" r="50" stroke-dasharray="${C}" stroke-dashoffset="${C * (1 - pct / 100)}"/></svg>
                        <div><b>${pct}%</b><small>${esc(t('bx_set_up', null, 'Set up'))}</small></div></div>
                    <div class="bx-readytext">
                        <h2>${esc(head ? t('bx_todo_n', { n: head }, '%{n} things need a look') : t('bx_all_good', null, 'Everything is in place'))}</h2>
                        <p>${esc(head ? t('bx_todo_sub', null, 'Click one to jump straight to it.') : t('bx_all_good_sub', null, 'Officers can clock on, gear up, take out cars and send people to prison.'))}</p>
                        ${issues.length ? `<div class="bx-issues">${issues.map((i, idx) => `<div class="bx-issue ${i.level}"><i>${I(i.level === 'info' ? 'info' : 'alert', 14)}</i><div><b>${esc(i.text)}</b><span>${esc(i.place ? `${i.place.name} · ${i.sub || ''}` : i.sub || '')}</span></div><button class="bx-btn xs" data-act="fix" data-i="${idx}">${esc(i.fix ? t('bx_set_it_up', null, 'Set it up') : t('bx_open', null, 'Open'))}${I('chevron', 12)}</button></div>`).join('')}</div>`
                        : `<div class="bx-allgood">${I('check', 18)}${esc(t('bx_nothing_todo', null, 'Nothing to fix. Nice work.'))}</div>`}
                    </div>
                </div>
                <div class="bx-stats">
                    ${stat('', by('station').length, kindPlural('station'), t('bx_points_n', { n: by('station').reduce((n, p) => n + pointTotal(p), 0) }, '%{n} points'), 'building', ['list', 'station'])}
                    ${stat('amber', by('jail').length, kindPlural('jail'), t('bx_live_inmates', { n: sum('jail', 'inmates') }, '%{n} inmates now'), 'jail', ['list', 'jail'])}
                    ${stat('green', by('impound').length, kindPlural('impound'), t('bx_live_held', { n: sum('impound', 'held') }, '%{n} cars held'), 'tow', ['list', 'impound'])}
                    ${stat('green', by('service').length, kindPlural('service'), t('bx_live_serving', { n: sum('service', 'serving') }, '%{n} serving now'), 'broom', ['list', 'service'])}
                    ${stat('', Number((S.system || {}).onDuty) || 0, t('bx_stat_duty', null, 'Officers on duty'), t('bx_stat_duty_sub', null, 'Right now'), 'shield', ['overview'])}
                    ${stat('red', XS.BuilderSettings.changedCount(), t('bx_stat_settings', null, 'Settings changed'), t('bx_stat_settings_sub', null, 'From config.lua'), 'sliders', ['settings'])}
                </div>
            </div>
            <div class="bx-sec"><div class="bx-sectitle"><h2>${esc(t('bx_quick', null, 'Quick start'))}</h2><span>${esc(t('bx_quick_sub', null, 'One click fills in a whole place. Check it over, then save.'))}</span></div>
                <div class="bx-quick">
                    ${TEMPLATES.map((tp) => `<button class="bx-tpl" data-act="tpl" data-tpl="${tp.id}"><span class="bx-kindico ${tp.kind}">${I(ICON[tp.kind], 18)}</span><div><b>${esc(t(tp.name, null, tp.fb))}</b><span>${esc(t(tp.sub, null, tp.subFb))}</span></div></button>`).join('')}
                    ${KINDS.map((k) => `<button class="bx-tpl" data-act="new" data-kind="${k}"><span class="bx-kindico ${k}">${I('plus', 18)}</span><div><b>${esc(t(`bx_new_${k}`, null, k))}</b><span>${esc(t(`bx_new_${k}_sub`, null, ''))}</span></div></button>`).join('')}
                </div></div>
            <div class="bx-sec"><div class="bx-sectitle"><h2>${esc(t('bx_everything', null, 'Everything you have built'))}</h2><span>${esc(t('bx_count_places', { n: S.places.length }, '%{n} places'))}</span></div>
                ${S.places.length ? `<div class="bx-card" style="padding:12px 4px 4px"><table class="bx-table"><thead><tr><th>${esc(t('bx_col_name', null, 'Name'))}</th><th>${esc(t('bx_col_kind', null, 'Kind'))}</th><th>${esc(t('bx_col_status', null, 'Status'))}</th><th>${esc(t('bx_col_now', null, 'Now'))}</th><th class="r"></th></tr></thead><tbody>
                    ${S.places.map((p) => `<tr class="click" data-act="open" data-id="${p.id}"><td><div class="bx-pname"><span class="bx-kindico ${p.kind}">${I(ICON[p.kind], 15)}</span><div><b>${esc(p.name)}</b><small>${esc(areaText(p) || '—')}</small></div></div></td><td>${esc(kindName(p.kind))}</td><td>${statusChips(p)}</td><td style="color:var(--b-dim)">${esc(liveText(p))}</td><td class="r"><button class="bx-tool" data-act="card-goto" data-id="${p.id}" title="${esc(t('builder_goto', null, 'Go to'))}">${I('goto', 14)}</button></td></tr>`).join('')}
                    </tbody></table></div>` : `<div class="bx-empty">${I('building', 30)}<b>${esc(t('bx_empty_all', null, 'Nothing built yet'))}</b><p>${esc(t('bx_empty_all_sub', null, 'Start with Mission Row PD above, or make a blank station and place the points yourself.'))}</p></div>`}
            </div>
            <div class="bx-sec"><div class="bx-sectitle"><h2>${esc(t('bx_system', null, 'Your server'))}</h2><span>${esc(t('bx_system_sub', null, 'What the script found running. Change these in config.lua under Bridges.'))}</span></div>
                <div class="bx-sysgrid">${['framework', 'inventory', 'target', 'banking', 'dispatch', 'keys', 'fuel', 'clothing', 'mdt', 'evidence'].map((k) => {
                    const raw = (S.system || {})[k];
                    const v = raw === 'builtin' ? t('bx_sys_builtin', null, 'Built in') : raw === 'none' ? null : raw;
                    return `<div class="bx-sysrow"><span>${esc(t(`bx_sys_${k}`, null, k))}</span><b class="${v ? '' : 'none'}">${esc(v ? String(v) : t('bx_sys_none', null, 'None found'))}</b>${v ? '<i class="bx-dot"></i>' : '<i class="bx-dot off"></i>'}</div>`;
                }).join('')}</div>
            </div>`;
    }

    function listPage() {
        const k = S.kind;
        const q = S.filter.toLowerCase();
        const list = S.places.filter((p) => p.kind === k && (!q || `${p.name} ${areaText(p)}`.toLowerCase().includes(q)));
        const tpls = TEMPLATES.filter((tp) => tp.kind === k);
        return `<div class="bx-pagehead"><div><h1>${esc(kindPlural(k))}</h1><p>${esc(t(`bx_list_${k}_sub`, null, ''))}</p></div><span class="bx-sp"></span>
                ${tpls.map((tp) => `<button class="bx-btn" data-act="tpl" data-tpl="${tp.id}">${I('copy', 14)}${esc(t(tp.name, null, tp.fb))}</button>`).join('')}
                <button class="bx-btn primary" data-act="new" data-kind="${k}">${I('plus', 15)}${esc(t(`bx_new_${k}`, null, k))}</button></div>
            <div class="bx-listbar"><div class="bx-filter">${I('search', 15)}<input class="bx-input" id="bx-filter" value="${esc(S.filter)}" placeholder="${esc(t('bx_filter', null, 'Filter by name or area'))}"></div><span class="bx-hint">${esc(t('bx_count_places', { n: list.length }, '%{n} places'))}</span></div>
            <div class="bx-grid">${list.map(placeCard).join('')}
                <button class="bx-newcard" data-act="new" data-kind="${k}"><i>${I('plus', 22)}</i>${esc(t(`bx_new_${k}`, null, k))}</button></div>`;
    }

    function placeCard(p) {
        const chips = p.kind === 'blip' ? '' : kindDefs(p.kind).filter((d) => count(p.points[d.key])).map((d) => `<span class="bx-chip" title="${esc(pointName(d.key))}">${I(XS.PlanIcon(d.key), 12)}${count(p.points[d.key])}</span>`).join('');
        const spots = XS.list(p.work).reduce((n, w) => n + count(w.spots), 0);
        return `<div class="bx-pcard ${p.enabled === false ? 'off' : ''}" data-act="open" data-id="${p.id}">
            <div class="bx-pcard-map">${plan(p, { w: 400, h: 150, mini: true })}<div class="bx-pcard-status">${statusChips(p)}</div></div>
            <div class="bx-pcard-body"><h3>${esc(p.name)}</h3><small>${esc(areaText(p) || t('bx_area_unknown', null, 'No points yet'))}</small>
                <div class="bx-pcard-kinds">${chips}${spots ? `<span class="bx-chip">${I('gear', 12)}${spots}</span>` : ''}${p.kind === 'blip' ? `<span class="bx-chip">${esc(t('bx_blip_sprite', { id: p.blip.sprite }, 'Icon %{id}'))}</span>` : ''}</div></div>
            <div class="bx-pcard-foot"><span>${esc(liveText(p))}</span>
                <button class="bx-tool" data-act="card-goto" data-id="${p.id}" title="${esc(t('builder_goto', null, 'Go to'))}">${I('goto', 14)}</button>
                <button class="bx-tool" data-act="card-dup" data-id="${p.id}" title="${esc(t('bx_duplicate', null, 'Duplicate'))}">${I('copy', 14)}</button>
                <button class="bx-tool" data-act="open" data-id="${p.id}" title="${esc(t('bx_open', null, 'Open'))}">${I('chevron', 14)}</button></div>
        </div>`;
    }

    function editor() {
        const p = S.cur;
        const tabs = TABS[p.kind];
        if (!tabs.includes(S.tab)) S.tab = tabs[0];
        const tabCount = { layout: pointTotal(p), armory: count(p.armory), garage: count(p.vehicles) + count(p.helicopters), jobs: count(p.work), canteen: count(p.meals) };
        const steps = p.kind === 'blip' ? '' : `<div class="bx-steps">${kindDefs(p.kind).map((d) => {
            const has = count(p.points[d.key]) > 0;
            const need = NEEDED[p.kind].includes(d.key);
            return `<button class="bx-step ${has ? 'done' : need ? 'need' : ''}" data-act="step" data-kind="${d.key}"><i>${has ? I('check', 10) : need ? '!' : ''}</i>${esc(pointName(d.key))}</button>`;
        }).join('')}</div>`;
        return `<div class="bx-crumb"><button data-act="nav" data-page="overview">${esc(t('bx_nav_overview', null, 'Overview'))}</button>${I('chevron', 11)}<button data-act="nav" data-page="list" data-kind="${p.kind}">${esc(kindPlural(p.kind))}</button>${I('chevron', 11)}<span>${esc(p.name)}</span></div>
            <div class="bx-edhead">
                <span class="bx-kindico ${p.kind}" style="width:44px;height:44px;border-radius:12px">${I(ICON[p.kind], 22)}</span>
                <div style="flex:1;min-width:0"><input class="bx-edname" data-bind="name" maxlength="48" value="${esc(p.name)}">
                    <div class="bx-edmeta"><span class="bx-chip blue">${esc(kindName(p.kind))}</span>${p.id ? '' : `<span class="bx-chip warn">${esc(t('bx_new_unsaved', null, 'New, not saved yet'))}</span>`}<span class="bx-hint">${I('pin', 12)} <span id="bx-area">${esc(areaText(p) || t('bx_area_unknown', null, 'No points yet'))}</span></span>
                    <span class="bx-save-state ${S.dirty ? 'dirty' : ''}" id="bx-state">${stateText()}</span></div></div>
                <label class="bx-toggle" data-act="enabled" title="${esc(t('bx_live_tip', null, 'Off hides it from players without deleting it.'))}"><span class="bx-switch ${p.enabled !== false ? 'on' : ''}"></span>${esc(p.enabled !== false ? t('bx_live', null, 'Live') : t('bx_off', null, 'Off'))}</label>
                <button class="bx-btn" data-act="goto-first" ${anchor(p) ? '' : 'disabled'}>${I('goto', 14)}${esc(t('builder_goto', null, 'Go to'))}</button>
                <button class="bx-btn" data-act="dup">${I('copy', 14)}${esc(t('bx_duplicate', null, 'Duplicate'))}</button>
                <button class="bx-btn ghost" data-act="discard" id="bx-discard" ${S.dirty ? '' : 'disabled'}>${I('undo', 14)}${esc(t('builder_discard', null, 'Discard'))}</button>
                <button class="bx-btn primary" data-act="save">${I('check', 15)}${esc(t('save', null, 'Save'))}<span class="bx-kbd">Ctrl S</span></button>
            </div>
            ${steps}
            <div class="bx-tabs">${tabs.map((k) => `<button class="bx-tab ${S.tab === k ? 'on' : ''}" data-act="tab" data-tab="${k}">${I({ layout: 'map', armory: 'gun', garage: 'car', jobs: 'gear', canteen: 'food', options: 'sliders', blip: 'mapblip' }[k], 14)}${esc(t(`bx_tab_${k}`, null, k))}${tabCount[k] !== undefined ? `<em>${tabCount[k]}</em>` : ''}</button>`).join('')}</div>
            ${S.tab === 'layout' ? layoutTab() : S.tab === 'armory' ? armoryTab() : S.tab === 'garage' ? garageTab() : S.tab === 'jobs' ? jobsTab() : S.tab === 'canteen' ? canteenTab() : S.tab === 'options' ? optionsTab() : blipTab()}`;
    }

    function stateText() {
        return S.dirty ? `<span class="bx-dot warn"></span>${esc(t('builder_unsaved', null, 'Unsaved changes'))}` : `<span class="bx-dot"></span>${esc(t('builder_saved_state', null, 'All saved'))}`;
    }

    function markDirty() {
        S.dirty = true;
        const st = root.querySelector('#bx-state');
        if (st) { st.className = 'bx-save-state dirty'; st.innerHTML = stateText(); }
        const d = root.querySelector('#bx-discard');
        if (d) d.disabled = false;
    }

    function layoutTab() {
        const p = S.cur;
        const present = new Set(kindDefs(p.kind).filter((d) => count(p.points[d.key])).map((d) => d.key));
        if (XS.list(p.work).some((w) => count(w.spots))) present.add('job');
        return `<div class="bx-layout">
            <div class="bx-planwrap">
                <div class="bx-planbar"><b>${esc(t('bx_plan', null, 'Top-down plan'))}</b>
                    <button class="bx-tool ${S.labels ? 'on' : ''}" data-act="labels" title="${esc(t('bx_labels', null, 'Show names'))}">${I('tag', 14)}</button>
                    <button class="bx-tool" data-act="walk" title="${esc(t('bx_walk_tip', null, 'Hide the builder and walk around. Every point is labelled.'))}">${I('eye', 14)}</button></div>
                <div class="bx-plan" id="bx-plan">${plan(p, { w: 640, h: 500, sel: S.sel, labels: S.labels })}</div>
                <div class="bx-planlegend">${Array.from(present).map((k) => `<span><i style="background:${XS.PlanColour(k)}"></i>${esc(k === 'job' ? t('bx_tab_jobs', null, 'Prison jobs') : pointName(k))}</span>`).join('') || `<span>${esc(t('bx_plan_hint', null, 'Place a point and it shows up here, to scale.'))}</span>`}</div>
            </div>
            <div class="bx-groups">${kindDefs(p.kind).map(group).join('')}</div>
        </div>`;
    }

    function group(def) {
        const p = S.cur;
        const list = XS.list(p.points[def.key]);
        const need = NEEDED[p.kind].includes(def.key);
        const full = def.single && list.length >= 1;
        const col = XS.PlanColour(def.key);
        return `<div class="bx-group ${need && !list.length ? 'need' : ''}" data-group="${def.key}">
            <div class="bx-grouph"><span class="bx-gico" style="background:${col}">${I(XS.PlanIcon(def.key), 16)}</span>
                <div class="bx-gtext"><b>${esc(pointName(def.key))}${need ? `<span class="bx-tag ${list.length ? 'ok' : 'req'}">${esc(t('bx_needed', null, 'Needed'))}</span>` : ''}${def.single ? `<span class="bx-tag">${esc(t('bx_only_one', null, 'Only one'))}</span>` : ''}</b><span>${esc(pointHint(def.key))}</span></div>
                <span class="bx-count">${list.length}</span></div>
            ${list.length ? `<div class="bx-points">${list.map((pt, i) => pointRow(def, pt, i)).join('')}</div>` : ''}
            ${full ? '' : `<div class="bx-addrow"><button class="bx-btn sm" data-act="pt-add" data-kind="${def.key}">${I('camera', 14)}${esc(t('builder_add', null, 'Place with camera'))}</button><button class="bx-btn sm" data-act="pt-addhere" data-kind="${def.key}">${I('crosshair', 14)}${esc(t('builder_add_here', null, 'At my spot'))}</button></div>`}
        </div>`;
    }

    function pointRow(def, pt, i) {
        const ref = `${def.key}:${i}`;
        const coords = `${fixed(pt.x)}, ${fixed(pt.y)}, ${fixed(pt.z)} · ${Math.round(Number(pt.w) || 0)}°`;
        const main = def.named
            ? `<input class="bx-input sm" data-bind="points.${def.key}.${i}.label" maxlength="32" value="${esc(pt.label || '')}" placeholder="${esc(pointName(def.key))}"><small>${coords}</small>`
            : `<b>${esc(pointName(def.key))} ${i + 1}</b><small>${coords}</small>`;
        let extra = '';
        if (def.exercise) extra = `<select class="bx-input sm" data-bind="points.${def.key}.${i}.exercise" data-live="1">${XS.list(S.defaults.exercises).map((x) => `<option value="${esc(x.key)}" ${x.key === pt.exercise ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}</select>`;
        if (def.exit) extra = `<button class="bx-btn xs" data-act="pt-exit" data-ref="${ref}" title="${esc(t('bx_exit_tip', null, 'Where they come out on the other side'))}">${I('exit', 12)}<span class="${pt.exit ? 'bx-spawnset' : 'bx-spawnunset'}">${esc(pt.exit ? t('bx_exit_set', null, 'Exit set') : t('bx_set_exit', null, 'Set exit'))}</span></button>`;
        if (def.spawn) extra = `<button class="bx-btn xs" data-act="pt-spawn" data-ref="${ref}" title="${esc(t('bx_spawn_tip', null, 'Where the vehicle appears'))}">${I(def.key === 'helipad' ? 'helicopter' : 'car', 12)}<span class="${pt.spawn ? 'bx-spawnset' : 'bx-spawnunset'}">${esc(pt.spawn ? t('bx_spawn_set', null, 'Spawn set') : t('builder_spawn_set', null, 'Set spawn'))}</span></button>`;
        return `<div class="bx-pt ${S.sel === ref ? 'sel' : ''}" data-ptrow="${ref}">
            <span class="bx-ptn" data-act="pick" data-ref="${ref}">${i + 1}</span>
            <div class="bx-ptmain" ${def.named ? '' : `data-act="pick" data-ref="${ref}"`}>${main}</div>
            ${extra ? `<div class="bx-ptextra">${extra}</div>` : ''}
            <div class="bx-ptacts">
                <button class="bx-tool" data-act="pt-move" data-ref="${ref}" title="${esc(t('bx_move_cam', null, 'Move with the camera'))}">${I('camera', 14)}</button>
                <button class="bx-tool" data-act="pt-here" data-ref="${ref}" title="${esc(t('bx_move_here', null, 'Move to where you stand'))}">${I('crosshair', 14)}</button>
                <button class="bx-tool" data-act="pt-goto" data-ref="${ref}" title="${esc(t('builder_goto', null, 'Go to'))}">${I('goto', 14)}</button>
                <button class="bx-tool danger" data-act="pt-del" data-ref="${ref}" title="${esc(t('delete', null, 'Delete'))}">${I('remove', 14)}</button>
            </div></div>`;
    }

    function picker(target, placeholder) {
        return `<div class="bx-picker"><input class="bx-input" data-picker="${target}" autocomplete="off" placeholder="${esc(placeholder)}"><div class="bx-pickpop" hidden></div></div>`;
    }

    function armoryTab() {
        const p = S.cur;
        return `<div class="bx-listbar"><div style="flex:1;max-width:460px">${picker('armory', t('bx_add_item_search', { n: S.catalog.items.length }, 'Add an item. Search %{n} items'))}</div><span class="bx-sp"></span>
                <span class="bx-hint">${esc(t('builder_armory_note', null, 'What officers can take here. Grade is the lowest rank that sees it. Price 0 is free.'))}</span>
                <button class="bx-btn sm" data-act="arm-reset">${I('undo', 13)}${esc(t('builder_reset_defaults', null, 'Reset to defaults'))}</button></div>
            ${p.armory.length ? `<div class="bx-items"><div class="bx-itemrow head"><span></span><span>${esc(t('builder_item', null, 'Item'))}</span><span>${esc(t('we_grade', null, 'Lowest rank'))}</span><span>${esc(t('builder_price', null, 'Price'))}</span><span>${esc(t('builder_amount', null, 'Amount'))}</span><span></span></div>
                ${p.armory.map((e, i) => {
                    const info = itemInfo(e.item);
                    return `<div class="bx-itemrow">${thumb(e.item)}<div class="bx-itemname ${info ? '' : 'missing'}"><b>${esc(info ? info.label : e.item || '?')}</b><small>${esc(info ? e.item : t('bx_item_missing', { item: e.item }, '%{item} · not in your inventory'))}</small></div>
                        <select class="bx-input sm" data-bind="armory.${i}.grade" data-type="int">${gradeOpts(e.grade)}</select>
                        <div class="bx-unit"><input type="number" min="0" data-bind="armory.${i}.price" data-type="int" value="${Number(e.price) || 0}"><em>$</em></div>
                        <div class="bx-unit"><input type="number" min="1" max="250" data-bind="armory.${i}.amount" data-type="int" data-min="1" value="${Number(e.amount) || 1}"><em>×</em></div>
                        <button class="bx-tool danger" data-act="arm-del" data-i="${i}">${I('remove', 14)}</button></div>`;
                }).join('')}</div>`
                : `<div class="bx-empty">${I('gun', 28)}<b>${esc(t('bx_armory_empty', null, 'The armory is empty'))}</b><p>${esc(t('bx_armory_empty_sub', null, 'Search above to add items, or reset to the defaults from config.lua.'))}</p></div>`}`;
    }

    function fleet(key, title, icon) {
        const list = S.cur[key];
        return `<div class="bx-sec" style="margin-top:${key === 'vehicles' ? 0 : 22}px"><div class="bx-sectitle">${I(icon, 16)}<h2>${esc(title)}</h2><span>${esc(t('bx_count_vehicles', { n: list.length }, '%{n} vehicles'))}</span><span class="bx-sp"></span><button class="bx-btn sm" data-act="veh-add" data-key="${key}">${I('plus', 13)}${esc(t('builder_add_vehicle', null, 'Add vehicle'))}</button></div>
            <div class="bx-items">${list.map((v, i) => `<div class="bx-vehwrap"><div class="bx-veh">
                <div class="bx-mini"><span>${esc(t('builder_model', null, 'Model'))}</span><input class="bx-input sm mono" list="bx-vehs" data-bind="${key}.${i}.model" data-type="slug" value="${esc(v.model)}"></div>
                <div class="bx-mini"><span>${esc(t('bx_menu_name', null, 'Name in the menu'))}</span><input class="bx-input sm" data-bind="${key}.${i}.label" maxlength="32" value="${esc(v.label || '')}"></div>
                <div class="bx-mini"><span>${esc(t('we_grade', null, 'Lowest rank'))}</span><select class="bx-input sm" data-bind="${key}.${i}.grade" data-type="int">${gradeOpts(v.grade)}</select></div>
                <div class="bx-mini"><span>${esc(t('builder_livery', null, 'Livery'))}</span><input class="bx-input sm mono" type="number" min="-1" max="99" data-bind="${key}.${i}.livery" data-type="int" data-min="-1" value="${v.livery === undefined ? -1 : Number(v.livery)}"></div>
                <button class="bx-tool danger" data-act="veh-del" data-key="${key}" data-i="${i}">${I('remove', 14)}</button></div>
                <div class="bx-extras"><span>${esc(t('builder_extras', null, 'Extras on'))}</span>${Array.from({ length: 14 }, (_, n) => n + 1).map((n) => `<button class="bx-extra ${XS.list(v.extras).includes(n) ? 'on' : ''}" data-act="extra" data-key="${key}" data-i="${i}" data-n="${n}">${n}</button>`).join('')}</div>
            </div>`).join('') || `<div class="bx-empty" style="padding:24px">${esc(t('bx_fleet_empty', null, 'Nothing here yet.'))}</div>`}</div></div>`;
    }

    function garageTab() {
        return `<datalist id="bx-vehs">${S.catalog.vehicles.map((v) => `<option value="${esc(v.model)}">${esc(v.label)}</option>`).join('')}</datalist>
            <div class="bx-hint" style="margin-bottom:14px">${esc(t('builder_garage_note', null, 'Livery -1 keeps the default. Extras lists the extras switched on; the rest are switched off.'))}</div>
            ${fleet('vehicles', t('builder_cars', null, 'Garage'), 'car')}${fleet('helicopters', t('builder_helis', null, 'Helipad'), 'helicopter')}`;
    }

    function spotRows(j, spots) {
        return spots.map((s, i) => {
            const ref = `w:${j}:${i}`;
            return `<div class="bx-pt ${S.sel === ref ? 'sel' : ''}" data-ptrow="${ref}"><span class="bx-ptn" data-act="pick" data-ref="${ref}" style="background:rgba(251,146,60,.18);color:#fb923c">${i + 1}</span>
                <div class="bx-ptmain" data-act="pick" data-ref="${ref}"><b>${esc(t('builder_job_spot', { n: i + 1 }, 'Spot %{n}'))}</b><small>${fixed(s.x)}, ${fixed(s.y)}, ${fixed(s.z)}</small></div>
                <div class="bx-ptacts">
                    <button class="bx-tool" data-act="ws-move" data-ref="${ref}" title="${esc(t('bx_move_cam', null, 'Move with the camera'))}">${I('camera', 14)}</button>
                    <button class="bx-tool" data-act="ws-here" data-ref="${ref}" title="${esc(t('bx_move_here', null, 'Move to where you stand'))}">${I('crosshair', 14)}</button>
                    <button class="bx-tool" data-act="ws-goto" data-ref="${ref}" title="${esc(t('builder_goto', null, 'Go to'))}">${I('goto', 14)}</button>
                    <button class="bx-tool danger" data-act="ws-del" data-ref="${ref}" title="${esc(t('delete', null, 'Delete'))}">${I('remove', 14)}</button></div></div>`;
        }).join('');
    }

    function jobsTab() {
        const acts = XS.list(S.defaults.activities);
        return `<div class="bx-listbar"><span class="bx-hint" style="flex:1">${esc(t('builder_jobs_note', null, 'Prisoners walk up to a spot and do the task. Each one takes time off their sentence, and the next spot of that job lights up so they keep moving.'))}</span>
                <button class="bx-btn primary sm" data-act="job-new" ${S.cur.work.length >= 12 ? 'disabled' : ''}>${I('plus', 13)}${esc(t('builder_job_new', null, 'New job'))}</button></div>
            ${S.cur.work.map((w, j) => `<div class="bx-jobcard">
                <div class="bx-jobcard-h">
                    <div class="bx-mini"><span>${esc(t('builder_job_name', null, 'Job'))}</span><input class="bx-input sm" data-bind="work.${j}.label" maxlength="32" value="${esc(w.label)}"></div>
                    <div class="bx-mini"><span>${esc(t('builder_job_activity', null, 'Looks like'))}</span><select class="bx-input sm" data-bind="work.${j}.activity">${acts.map((a) => `<option value="${esc(a.key)}" ${a.key === w.activity ? 'selected' : ''}>${esc(a.label)}</option>`).join('')}</select></div>
                    <div class="bx-mini"><span>${esc(t('builder_job_seconds', null, 'Seconds'))}</span><div class="bx-unit"><input type="number" min="3" max="120" data-bind="work.${j}.seconds" data-type="int" data-min="3" data-max="120" value="${Number(w.seconds) || 12}"><em>s</em></div></div>
                    <div class="bx-mini"><span>${esc(t('builder_job_credit', null, 'Time off (s)'))}</span><div class="bx-unit"><input type="number" min="0" max="3600" data-bind="work.${j}.credit" data-type="int" data-max="3600" value="${Number(w.credit) || 0}"><em>s</em></div></div>
                    <div class="bx-mini"><span>${esc(t('bx_job_pay', null, 'Pays'))}</span><div class="bx-unit"><input type="number" min="0" max="1000" data-bind="work.${j}.pay" data-type="int" data-max="1000" value="${Number(w.pay) || 0}"><em>${esc(t('bx_credit_unit', null, 'credit'))}</em></div></div>
                    <button class="bx-btn sm danger" data-act="job-del" data-j="${j}">${I('remove', 13)}</button>
                </div>
                ${w.spots.length ? `<div class="bx-points">${spotRows(j, w.spots)}</div>` : `<div class="bx-hint" style="padding:0 12px">${esc(t('bx_job_nospots', null, 'No spots yet. Prisoners will not see this job until it has one.'))}</div>`}
                <div class="bx-addrow"><button class="bx-btn sm" data-act="ws-add" data-j="${j}">${I('camera', 14)}${esc(t('builder_add', null, 'Place with camera'))}</button><button class="bx-btn sm" data-act="ws-addhere" data-j="${j}">${I('crosshair', 14)}${esc(t('builder_add_here', null, 'At my spot'))}</button></div>
            </div>`).join('') || `<div class="bx-empty">${I('gear', 28)}<b>${esc(t('builder_jobs_none', null, 'No jobs yet.'))}</b></div>`}`;
    }

    function canteenTab() {
        return `<div class="bx-listbar"><div class="bx-mini" style="width:200px"><span>${esc(t('builder_meal_minutes', null, 'Minutes between meals'))}</span><div class="bx-unit"><input type="number" min="0" max="120" data-bind="mealMinutes" data-type="int" data-max="120" value="${Number(S.cur.mealMinutes) || 0}"><em>min</em></div></div>
                <span class="bx-hint" style="flex:1;align-self:flex-end">${esc(t('builder_canteen_note', null, 'Prisoners pick one meal at the canteen and get every item on its tray.'))}</span>
                <button class="bx-btn primary sm" data-act="meal-new" style="align-self:flex-end" ${S.cur.meals.length >= 12 ? 'disabled' : ''}>${I('plus', 13)}${esc(t('builder_meal_new', null, 'New meal'))}</button></div>
            ${S.cur.meals.map((m, j) => `<div class="bx-jobcard">
                <div class="bx-jobcard-h" style="grid-template-columns:minmax(0,1fr) auto">
                    <div class="bx-mini"><span>${esc(t('builder_meal_name', null, 'Meal'))}</span><input class="bx-input sm" data-bind="meals.${j}.label" maxlength="32" value="${esc(m.label)}"></div>
                    <button class="bx-btn sm danger" data-act="meal-del" data-j="${j}">${I('remove', 13)}</button>
                </div>
                <div class="bx-items" style="padding:0 12px 10px">${m.items.map((e, i) => {
                    const info = itemInfo(e.item);
                    return `<div class="bx-itemrow" style="grid-template-columns:44px minmax(0,1fr) 110px 30px">${thumb(e.item)}<div class="bx-itemname ${info ? '' : 'missing'}"><b>${esc(info ? info.label : e.item)}</b><small>${esc(info ? e.item : t('bx_item_missing', { item: e.item }, '%{item} · not in your inventory'))}</small></div>
                        <div class="bx-unit"><input type="number" min="1" max="20" data-bind="meals.${j}.items.${i}.amount" data-type="int" data-min="1" data-max="20" value="${Number(e.amount) || 1}"><em>×</em></div>
                        <button class="bx-tool danger" data-act="mi-del" data-j="${j}" data-i="${i}">${I('remove', 14)}</button></div>`;
                }).join('')}
                ${m.items.length < 6 ? picker(`meal:${j}`, t('bx_add_to_tray', null, 'Add an item to this tray')) : ''}</div>
            </div>`).join('') || `<div class="bx-empty">${I('food', 28)}<b>${esc(t('builder_meals_none', null, 'No meals yet. Nothing is served until you add one.'))}</b></div>`}`;
    }

    function departments(note) {
        const picked = new Set(S.cur.jobs);
        return `<div class="bx-rowline"><div><b>${esc(t('builder_departments', null, 'Departments'))}</b><div class="bx-hint">${esc(note)}</div>
            <div class="bx-jobchips" style="margin-top:10px">${S.catalog.jobs.map((j) => `<button class="bx-jobchip ${picked.has(j.name) ? 'on' : ''}" data-act="job" data-job="${esc(j.name)}"><span class="chk">${picked.has(j.name) ? I('check', 11) : ''}</span>${esc(j.label)}<small>${esc(j.name)}</small></button>`).join('') || `<span class="bx-hint">${esc(t('builder_no_jobs', null, 'No police jobs found in your framework.'))}</span>`}</div></div></div>`;
    }

    function switchRow(act, on, title, hint) {
        return `<div class="bx-rowline"><div><b>${esc(title)}</b>${hint ? `<div class="bx-hint">${esc(hint)}</div>` : ''}</div><span class="bx-switch ${on ? 'on' : ''}" data-act="${act}"></span></div>`;
    }

    function optionsTab() {
        const p = S.cur;
        let body = switchRow('enabled', p.enabled !== false, t('bx_opt_live', null, 'Live'), t('bx_opt_live_hint', null, 'Off hides it from every player without deleting it. A prison with inmates or a lot with cars cannot be switched off.'));
        if (p.kind === 'station') {
            body += departments(t('builder_departments_note', null, 'Leave all unticked and every police department can use this station.'));
            body += `<div class="bx-rowline"><div><b>${esc(t('builder_plate', null, 'Plate prefix'))}</b><div class="bx-hint">${esc(t('bx_plate_hint', null, 'Cars from this station get plates like LSPD 4271.'))}</div></div><input class="bx-input mono" style="width:120px;text-transform:uppercase" maxlength="4" data-bind="plate" data-type="upper4" value="${esc(p.plate || S.defaults.plate || 'LSPD')}"></div>`;
        }
        if (p.kind === 'impound') {
            body += departments(t('builder_impound_departments_note', null, 'Who can see the records here and clear holds. Leave all unticked for every police department.'));
            body += `<div class="bx-rowline"><div><b>${esc(t('builder_impound_fee', null, 'Release fee'))}</b><div class="bx-hint">${esc(t('builder_impound_fee_note', null, 'What a new impound here costs. Officers can change it when they impound.'))}</div></div><div class="bx-unit" style="width:170px"><input type="number" min="${Number(S.defaults.minFee) || 0}" max="${Number(S.defaults.maxFee) || 25000}" data-bind="fee" data-type="int" value="${Number(p.fee) || 0}"><em>$</em></div></div>`;
            body += `<div class="bx-rowline"><div><b>${esc(t('builder_impound_clerk', null, 'Clerk at the desk'))}</b><div class="bx-hint">${esc(t('builder_impound_clerk_note', null, 'A ped model that stands at each desk. Leave empty for nobody.'))}</div></div><input class="bx-input mono" style="width:220px" maxlength="48" data-bind="clerk" data-type="slug" value="${esc(p.clerk || '')}" placeholder="s_m_y_cop_01"></div>`;
        }
        if (p.kind === 'jail') {
            const c = p.center;
            const origin = c && c.x !== undefined ? c : XS.list(p.points.cell)[0];
            const reach = origin ? Math.round(XS.Plan.reach(p, origin, Number(p.radius) || 150)) : 0;
            const grownTo = reach > (Number(p.radius) || 150) ? reach : 0;
            body += `<div class="bx-rowline"><div><b>${esc(t('builder_bolingbroke', null, 'Bolingbroke layout'))}</b><div class="bx-hint">${esc(t('builder_bolingbroke_note', null, 'Fills in cells, the electrician job, the canteen, two workout spots, the release point and the escape circle at Bolingbroke Penitentiary. Replaces those points on this prison.'))}</div></div><button class="bx-btn" data-act="boli">${I('copy', 14)}${esc(t('builder_bolingbroke_use', null, 'Use the Bolingbroke layout'))}</button></div>`;
            body += `<div class="bx-rowline"><div><b>${esc(t('builder_jail_center', null, 'Prison centre'))}</b><div class="bx-hint">${esc(c ? `${fixed(c.x)}, ${fixed(c.y)}, ${fixed(c.z)}` : t('builder_center_auto', null, 'Uses the first cell'))}</div></div>
                <div style="display:flex;gap:6px"><button class="bx-btn sm" data-act="center-cam">${I('camera', 13)}${esc(t('builder_add', null, 'Place with camera'))}</button><button class="bx-btn sm" data-act="center-here">${I('crosshair', 13)}${esc(t('builder_here', null, 'My spot'))}</button>${c ? `<button class="bx-btn sm ghost" data-act="center-reset">${I('undo', 13)}</button>` : ''}</div></div>`;
            body += `<div class="bx-rowline"><div><b>${esc(t('builder_radius', null, 'Escape radius (m)'))}</b><div class="bx-hint">${esc(t('builder_radius_note', null, 'Leaving this circle around the centre counts as an escape. Shown as a red ring while you build.'))}${grownTo ? `<br>${esc(t('builder_radius_grown', { m: grownTo }, 'Grows to %{m} m to take in every spot you placed.'))}` : ''}</div></div><div class="bx-unit" style="width:150px"><input type="number" min="20" max="1500" data-bind="radius" data-type="int" data-min="20" data-max="1500" data-live="1" value="${Number(p.radius) || S.defaults.radius || 150}"><em>m</em></div></div>`;
        }
        if (p.kind !== 'blip') body += switchRow('markers', !!p.markers, t('builder_markers', null, 'Floor markers'), t('builder_markers_note', null, 'Off keeps the floor clean. Points still work with your target or the [E] prompt.'));
        return `<div class="bx-cols2" style="grid-template-columns:minmax(0,1.6fr) minmax(0,1fr);align-items:start">
            <div class="bx-card"><div class="bx-cardbody">${body}</div></div>
            <div class="bx-card" style="border-color:rgba(var(--b-red-rgb),.3)"><div class="bx-cardhead"><h3>${esc(t('bx_danger', null, 'Delete'))}</h3></div><div class="bx-cardbody"><p class="bx-hint" style="margin-bottom:12px">${esc(t('bx_danger_hint', null, 'Removes this place and every point in it for good. A prison with inmates or a lot with cars in it cannot be deleted.'))}</p>
                <button class="bx-btn danger" data-act="delete" ${p.id ? '' : 'disabled'}>${I('remove', 14)}${esc(t('bx_delete_place', null, 'Delete this place'))}</button></div></div>
        </div>`;
    }

    function spriteTile(sp, on) {
        return `<button class="bb-sp ${on ? 'on' : ''}" data-act="bb-sprite" data-id="${sp.id}" title="${esc(sp.label)} · ${sp.id}"><img src="${esc(XS.BLIPS.image(sp))}" alt="" loading="lazy" onerror="this.classList.add('gone')"><span>${sp.id}</span></button>`;
    }

    function spriteList() {
        const B = XS.BLIPS;
        const q = S.bbq.trim().toLowerCase();
        return q ? B.all.filter((sp) => String(sp.id) === q || sp.label.includes(q) || sp.name.includes(q)).slice(0, 180) : B.sprites;
    }

    function blipTab() {
        const p = S.cur;
        const b = p.blip;
        const at = p.blipAt;
        const B = XS.BLIPS;
        const sprite = B.find(b.sprite);
        const colour = B.colours.find((x) => x.id === Number(b.colour));
        const own = p.kind === 'blip';
        const sprites = spriteList();
        return `<div class="bb-wrap">
            <div class="bx-card"><div class="bx-cardbody">
                ${own ? '' : switchRow('bb-show', b.show !== false, t('builder_blip_show', null, 'Show on the map'), t('bx_blip_show_hint', null, 'Puts this place on the map for the people you pick below.'))}
                <div class="bx-cols2" style="margin:14px 0 16px">
                    <div><label class="bx-label">${esc(t('builder_blip_label', null, 'Name on the map'))}</label><input class="bx-input" data-bind="blip.label" data-live="1" maxlength="48" value="${esc(b.label || '')}" placeholder="${esc(p.name || '')}"></div>
                    <div><label class="bx-label">${esc(t('builder_blip_who', null, 'Who sees it'))}</label><select class="bx-input" data-bind="blip.who" data-live="1">${['all', 'police', 'duty'].map((w) => `<option value="${w}" ${b.who === w ? 'selected' : ''}>${esc(t(`builder_blip_who_${w}`, null, w))}</option>`).join('')}</select></div>
                </div>
                <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px"><label class="bx-label" style="margin:0;flex:1">${esc(t('builder_blip_icon', null, 'Icon'))}</label>
                    <div class="bx-filter" style="width:260px">${I('search', 15)}<input class="bx-input sm" id="bx-bbq" value="${esc(S.bbq)}" placeholder="${esc(t('builder_blip_search', { count: B.all.length }, 'Search all %{count} icons'))}"></div>
                    <div class="bx-unit" style="width:120px"><input type="number" min="0" max="999" data-bind="blip.sprite" data-type="int" data-max="999" data-live="1" data-redraw="1" value="${Number(b.sprite)}"><em>#</em></div></div>
                <div class="bb-sprites xsp-scroll" id="bx-bbgrid">${sprites.map((sp) => spriteTile(sp, sp.id === Number(b.sprite))).join('') || `<div class="bx-hint" style="grid-column:1/-1;padding:10px">${esc(t('builder_blip_none', null, 'No icon matches that.'))}</div>`}</div>
                <label class="bx-label" style="margin-top:16px">${esc(t('builder_blip_colour', null, 'Colour'))}</label>
                <div class="bb-colours">${B.colours.map((c) => `<button class="bb-c ${c.id === Number(b.colour) ? 'on' : ''}" data-act="bb-colour" data-id="${c.id}" title="${esc(c.label)} · ${c.id}" style="background:${c.hex}"></button>`).join('')}</div>
                <div class="bx-cols2" style="margin-top:16px">
                    <div><label class="bx-label">${esc(t('builder_blip_size', null, 'Size'))} <span class="bx-mono" id="bx-scale">${Number(b.scale).toFixed(2)}</span></label><input type="range" min="0.4" max="1.6" step="0.05" value="${Number(b.scale)}" class="bb-range" data-bind="blip.scale" data-type="num" data-live="1"></div>
                    <div style="display:flex;align-items:flex-end">${`<label class="bx-toggle" data-act="bb-short"><span class="bx-switch ${b.short !== false ? 'on' : ''}"></span>${esc(t('builder_blip_short', null, 'Only on the minimap when close'))}</label>`}</div>
                </div>
            </div></div>
            <div>
                <div class="bb-preview"><span class="bb-ico">${sprite ? `<img src="${esc(B.image(sprite))}" alt="" onerror="this.remove()">` : `<b>${Number(b.sprite)}</b>`}<i class="bb-dot" style="background:${colour ? colour.hex : '#888888'}"></i></span>
                    <div style="min-width:0"><strong>${esc(b.label || p.name || '')}</strong><span>${esc(sprite ? `${sprite.label} · ${sprite.id}` : t('builder_blip_custom', { id: b.sprite }, 'Icon %{id}'))} · ${esc(colour ? colour.label : t('builder_blip_colour_n', { id: b.colour }, 'Colour %{id}'))}</span><span>${esc(t(`builder_blip_who_${b.who || 'all'}`, null, ''))}${own || b.show !== false ? '' : ` · ${esc(t('bx_hidden', null, 'Hidden'))}`}</span></div></div>
                <div class="bx-card" style="margin-top:12px"><div class="bx-cardhead"><h3>${esc(t('builder_blip_where', null, 'Where it sits'))}</h3></div><div class="bx-cardbody">
                    <p class="bx-hint bx-mono" style="margin-bottom:10px">${at ? `${fixed(at.x)}, ${fixed(at.y)}, ${fixed(at.z)}` : esc(own ? t('builder_blip_unplaced', null, 'Not placed yet') : t('builder_blip_auto', null, 'Sits on the first point'))}</p>
                    <div style="display:flex;flex-wrap:wrap;gap:6px"><button class="bx-btn sm" data-act="blip-cam">${I('camera', 13)}${esc(t('builder_add', null, 'Place with camera'))}</button><button class="bx-btn sm" data-act="blip-here">${I('crosshair', 13)}${esc(t('builder_here', null, 'My spot'))}</button>
                    ${at ? `<button class="bx-btn sm" data-act="blip-goto">${I('goto', 13)}${esc(t('builder_goto', null, 'Go to'))}</button>` : ''}${at && !own ? `<button class="bx-btn sm ghost" data-act="blip-reset">${I('undo', 13)}${esc(t('builder_blip_reset', null, 'Reset'))}</button>` : ''}</div>
                </div></div>
            </div>
        </div>`;
    }

    function blank(kind, pos) {
        const p = Object.assign({ id: uid(), x: 0, y: 0, z: 0, w: 0 }, pos || {});
        delete p.snapped;
        delete p.width;
        const def = kindDefs(S.cur.kind).find((k) => k.key === kind) || {};
        if (def.named) p.label = pointName(kind);
        if (def.exercise) p.exercise = (XS.list(S.defaults.exercises)[0] || {}).key;
        return p;
    }

    async function place(kind, existing, extra) {
        if (S.busy) return null;
        S.busy = true;
        const res = await XS.rpc('builder:place', Object.assign({ mode: 'point', label: pointName(kind), origin: existing || null }, extra || {}));
        S.busy = false;
        return res.ok ? res.data : null;
    }

    async function placeExit(kind, pt) {
        const def = kindDefs(S.cur.kind).find((k) => k.key === kind) || {};
        if (!def.exit) return;
        const pos = await place(kind, pt.exit || pt, { label: t('bx_exit_spot', null, 'Where it comes out') });
        if (pos) pt.exit = posOf(pos);
    }

    async function here() {
        const res = await XS.rpc('builder:here', {});
        return res.ok ? res.data : null;
    }

    function vehicleExtra(kind) {
        const def = kindDefs(S.cur.kind).find((k) => k.key === kind) || {};
        return def.vehicle ? { previewModel: 'blista', previewVehicle: true } : null;
    }

    function changed(redraw) {
        markDirty();
        select();
        renderNav();
        if (redraw !== false) renderPage();
    }

    const posOf = (p) => ({ x: p.x, y: p.y, z: p.z, w: p.w });
    const refPoint = (ref) => { const [k, i] = ref.split(':'); return { list: S.cur.points[k], i: Number(i), kind: k }; };
    const refSpot = (ref) => { const [, j, i] = ref.split(':').map(Number); return { list: S.cur.work[j].spots, i, job: S.cur.work[j] }; };

    function applyBolingbroke(p) {
        const B = S.defaults.bolingbroke;
        if (!B) return;
        const pts = B.points || {};
        ['cell', 'canteen', 'workout', 'release'].forEach((k) => {
            p.points[k] = XS.list(pts[k]).map((pt) => Object.assign({}, pt, { id: uid() }));
        });
        p.center = Object.assign({}, B.center);
        p.radius = Number(B.radius) || p.radius;
        XS.list(B.work).forEach((pw) => {
            let target = p.work.find((w) => w.activity === pw.activity);
            if (!target) {
                target = { id: uid(), label: pw.label, activity: pw.activity, seconds: Number(S.defaults.jobSeconds) || 12, credit: Number(S.defaults.jobCredit) || 30, spots: [] };
                p.work.push(target);
            }
            target.spots = XS.list(pw.spots).map((pt) => Object.assign({}, pt, { id: uid() }));
        });
        if (!p.name || p.name === t('jail_default_name', null, 'State Prison')) p.name = t('builder_bolingbroke_name', null, 'Bolingbroke Penitentiary');
    }

    function fromTemplate(id) {
        if (id === 'bolingbroke') {
            const p = newPlace('jail');
            applyBolingbroke(p);
            return p;
        }
        const T = (S.defaults.templates || {})[id];
        if (!T) return null;
        const p = newPlace(T.kind);
        p.name = T.name;
        Object.keys(T.points || {}).forEach((k) => {
            p.points[k] = XS.list(T.points[k]).map((pt) => {
                const out = Object.assign({}, pt, { id: uid() });
                if (pt.spawn) out.spawn = Object.assign({}, pt.spawn);
                return out;
            });
        });
        return normalise(p);
    }

    function duplicate(src) {
        const p = normalise(copy(src));
        p.id = null;
        p.name = t('bx_copy_of', { name: src.name }, '%{name} (copy)').slice(0, 48);
        Object.keys(p.points).forEach((k) => p.points[k].forEach((pt) => { pt.id = uid(); }));
        XS.list(p.work).forEach((w) => { w.id = uid(); w.spots.forEach((s) => { s.id = uid(); }); });
        XS.list(p.meals).forEach((m) => { m.id = uid(); });
        return p;
    }

    function guard(next) {
        if (S.page === 'edit' && S.cur && S.dirty) {
            modal(t('bx_unsaved_title', { name: S.cur.name }, 'Save %{name}?'), t('bx_unsaved_text', null, 'You have changes here that are not saved yet.'), [
                { label: t('bx_keep_editing', null, 'Keep editing'), cls: 'ghost', fn: () => {} },
                { label: t('builder_discard', null, 'Discard'), cls: 'danger', fn: () => { S.dirty = false; next(); } },
                { label: t('save', null, 'Save'), cls: 'primary', fn: async () => { if (await save()) next(); } },
            ]);
            return;
        }
        next();
    }

    function go(page, kind) {
        guard(() => {
            S.page = page;
            if (kind) S.kind = kind;
            S.cur = null;
            S.sel = null;
            S.filter = '';
            select();
            renderNav();
            renderPage(true);
        });
    }

    function edit(place, opts) {
        guard(() => {
            const o = opts || {};
            S.cur = normalise(copy(place));
            S.dirty = !!o.dirty;
            S.page = 'edit';
            S.kind = S.cur.kind;
            S.tab = o.tab || TABS[S.cur.kind][0];
            S.sel = null;
            S.bbq = '';
            select();
            renderNav();
            renderPage(true);
            if (o.group) setTimeout(() => scrollToGroup(o.group), 30);
            if (o.dirty) loadAreas([S.cur]);
        });
    }

    function scrollToGroup(key) {
        const g = root.querySelector(`[data-group="${key}"]`);
        if (g) g.scrollIntoView({ block: 'center', behavior: 'smooth' });
    }

    function commitFocus() {
        const a = document.activeElement;
        if (a && a !== document.body && root.contains(a) && a.blur) a.blur();
    }

    async function save() {
        commitFocus();
        if (S.busy || !S.cur) return false;
        if (!String(S.cur.name || '').trim()) S.cur.name = t(DEFAULT_NAME[S.cur.kind], null, S.cur.kind);
        S.busy = true;
        const res = await XS.rpc('builder:save', S.cur);
        S.busy = false;
        if (!res.ok) { XS.toast(res.error, 'error'); return false; }
        const saved = normalise(res.data);
        const idx = S.places.findIndex((p) => p.id === saved.id);
        if (idx >= 0) S.places[idx] = saved; else S.places.push(saved);
        if (S.areas.cur && !S.areas[String(saved.id)]) S.areas[String(saved.id)] = S.areas.cur;
        S.cur = normalise(copy(saved));
        S.dirty = false;
        XS.toast(t('bx_saved', { name: saved.name }, '%{name} saved. Players see it now.'), 'ok');
        select();
        loadAreas([saved]);
        if (S.open && S.page === 'edit') { renderNav(); renderPage(); }
        return true;
    }

    function modal(title, text, buttons) {
        S.overlay = { type: 'modal', title, text, buttons };
        renderOverlay();
    }

    function closeOverlay() {
        S.overlay = null;
        renderOverlay();
    }

    function paletteItems() {
        const out = [];
        out.push({ g: 'go', icon: 'grid', label: t('bx_nav_overview', null, 'Overview'), run: () => go('overview') });
        KINDS.forEach((k) => out.push({ g: 'go', icon: ICON[k], kind: k, label: kindPlural(k), run: () => go('list', k) }));
        out.push({ g: 'go', icon: 'wheel', label: t('we_title', null, 'Quick action wheel'), run: () => go('wheel') });
        out.push({ g: 'go', icon: 'sliders', label: t('bs_title', null, 'Settings'), run: () => go('settings') });
        S.places.forEach((p) => out.push({ g: 'places', icon: ICON[p.kind], kind: p.kind, label: p.name, sub: [kindName(p.kind), areaText(p)].filter(Boolean).join(' · '), run: () => edit(p) }));
        KINDS.forEach((k) => out.push({ g: 'new', icon: 'plus', kind: k, label: t(`bx_new_${k}`, null, k), run: () => edit(newPlace(k), { dirty: true }) }));
        TEMPLATES.forEach((tp) => out.push({ g: 'new', icon: ICON[tp.kind], kind: tp.kind, label: t(tp.name, null, tp.fb), sub: t('bx_template', null, 'Template'), run: () => useTemplate(tp.id) }));
        XS.BuilderSettings.fields().forEach((f) => out.push({ g: 'settings', icon: 'sliders', label: XS.BuilderSettings.label(f.key), sub: XS.BuilderSettings.sectionLabel(f.section), deep: true, run: () => { go('settings'); setTimeout(() => XS.BuilderSettings.focus(f.key), 0); } }));
        out.push({ g: 'do', icon: 'eye', label: t('bx_walk', null, 'Walk the site'), run: () => XS.rpc('builder:walk', {}) });
        out.push({ g: 'do', icon: 'close', label: t('bx_close_builder', null, 'Close the builder'), run: () => XS.close('builder') });
        return out;
    }

    function paletteResults() {
        const q = (S.overlay.q || '').trim().toLowerCase();
        const words = q.split(/\s+/).filter(Boolean);
        const all = paletteItems().filter((i) => (q ? words.every((w) => `${i.label} ${i.sub || ''}`.toLowerCase().includes(w)) : !i.deep));
        return all.slice(0, 60);
    }

    function paletteList() {
        const list = paletteResults();
        S.overlay.list = list;
        if (S.overlay.idx >= list.length) S.overlay.idx = Math.max(0, list.length - 1);
        const groups = { go: t('bx_pal_go', null, 'Go to'), new: t('bx_pal_new', null, 'Create'), places: t('bx_pal_places', null, 'Places'), settings: t('bs_title', null, 'Settings'), do: t('bx_pal_do', null, 'Actions') };
        let html = '';
        let last = null;
        list.forEach((it, idx) => {
            if (it.g !== last) { html += `<div class="bx-palgroup">${esc(groups[it.g])}</div>`; last = it.g; }
            html += `<button class="bx-palitem ${idx === S.overlay.idx ? 'hl' : ''}" data-act="pal-run" data-i="${idx}"><span class="bx-kindico ${it.kind || ''}">${I(it.icon, 15)}</span><div><b>${esc(it.label)}</b>${it.sub ? `<small>${esc(it.sub)}</small>` : ''}</div>${idx === S.overlay.idx ? '<kbd>↵</kbd>' : ''}</button>`;
        });
        return html || `<div class="bx-empty" style="margin:10px;padding:26px">${esc(t('bs_nothing', null, 'Nothing matches'))}</div>`;
    }

    function renderOverlay() {
        const box = root.querySelector('#bx-ov');
        if (!box) return;
        const o = S.overlay;
        if (!o) { box.innerHTML = ''; return; }
        if (o.type === 'palette') {
            box.innerHTML = `<div class="bx-overlay" data-act="ov-close"><div class="bx-palette">
                <div class="bx-palin">${I('search', 18)}<input id="bx-palq" value="${esc(o.q || '')}" placeholder="${esc(t('bx_search', null, 'Search places, settings and actions'))}" autocomplete="off"><span class="bx-kbd">Esc</span></div>
                <div class="bx-palres" id="bx-palres">${paletteList()}</div>
                <div class="bx-palfoot"><span>↑ ↓ ${esc(t('bx_pal_move', null, 'to move'))}</span><span>↵ ${esc(t('bx_pal_open', null, 'to open'))}</span><span>Esc ${esc(t('bx_pal_close', null, 'to close'))}</span></div>
            </div></div>`;
            const q = box.querySelector('#bx-palq');
            q.focus();
            q.setSelectionRange(q.value.length, q.value.length);
        } else {
            box.innerHTML = `<div class="bx-overlay" data-act="ov-close"><div class="bx-modal"><h3>${esc(o.title)}</h3><p>${esc(o.text)}</p>
                <div class="acts">${o.buttons.map((b, i) => `<button class="bx-btn ${b.cls || ''}" data-act="modal-btn" data-i="${i}">${esc(b.label)}</button>`).join('')}</div></div></div>`;
        }
    }

    function openPalette() {
        S.overlay = { type: 'palette', q: '', idx: 0 };
        renderOverlay();
    }

    function runPalette(idx) {
        const it = (S.overlay && S.overlay.list || [])[idx];
        if (!it) return;
        closeOverlay();
        it.run();
    }

    function onPaletteInput(e) {
        if (e.target.id !== 'bx-palq' || !S.overlay) return;
        S.overlay.q = e.target.value;
        S.overlay.idx = 0;
        root.querySelector('#bx-palres').innerHTML = paletteList();
    }

    function onPaletteKey(e) {
        if (!S.overlay || S.overlay.type !== 'palette') return;
        const n = (S.overlay.list || []).length;
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
            e.preventDefault();
            S.overlay.idx = (S.overlay.idx + (e.key === 'ArrowDown' ? 1 : -1) + n) % Math.max(1, n);
            const res = root.querySelector('#bx-palres');
            res.innerHTML = paletteList();
            const hl = res.querySelector('.hl');
            if (hl) hl.scrollIntoView({ block: 'nearest' });
        } else if (e.key === 'Enter') {
            e.preventDefault();
            runPalette(S.overlay.idx);
        }
    }

    function useTemplate(id) {
        const p = fromTemplate(id);
        if (!p) return;
        edit(p, { dirty: true });
        XS.toast(t('bx_tpl_done', { name: p.name }, '%{name} is filled in. Check it over, then save.'), 'ok');
    }

    function pickerResults(q) {
        const s = q.trim().toLowerCase();
        return S.catalog.items.filter((i) => !s || i.name.toLowerCase().includes(s) || String(i.label || '').toLowerCase().includes(s)).slice(0, 40);
    }

    function pickerUpdate(input) {
        const pop = input.nextElementSibling;
        if (!pop) return;
        const list = pickerResults(input.value);
        const raw = input.value.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
        const extra = raw && !list.some((i) => i.name === raw) ? `<button class="bx-pickopt" data-act="pick-item" data-target="${esc(input.dataset.picker)}" data-item="${esc(raw)}"><span class="bx-thumb">${I('plus', 16)}</span><div><b>${esc(t('bx_use_name', { name: raw }, 'Use "%{name}"'))}</b><small>${esc(t('bx_use_name_sub', null, 'Not in your inventory list'))}</small></div></button>` : '';
        pop.innerHTML = list.map((i, idx) => `<button class="bx-pickopt ${idx === 0 ? 'hl' : ''}" data-act="pick-item" data-target="${esc(input.dataset.picker)}" data-item="${esc(i.name)}">${thumb(i.name)}<div><b>${esc(i.label)}</b><small>${esc(i.name)}</small></div></button>`).join('') + extra;
        pop.hidden = !pop.innerHTML;
    }

    function pickerClose(input) {
        const pop = input && input.nextElementSibling;
        if (pop) pop.hidden = true;
    }

    function pickItem(target, item) {
        if (!item) return;
        if (target === 'armory') {
            if (S.cur.armory.some((e) => e.item === item)) return XS.toast(t('bx_item_there', null, 'That item is already on the list.'), 'error');
            S.cur.armory.push({ item, grade: 0, price: 0, amount: 1 });
        } else if (target.startsWith('meal:')) {
            const meal = S.cur.meals[Number(target.split(':')[1])];
            if (!meal || meal.items.length >= 6) return;
            meal.items.push({ item, amount: 1 });
        }
        changed();
        const again = pageEl().querySelector(`[data-picker="${target}"]`);
        if (again) again.focus();
    }

    function parseValue(el) {
        const type = el.dataset.type || 'str';
        let v = el.value;
        if (type === 'int' || type === 'num') {
            v = type === 'int' ? Math.round(Number(v) || 0) : Number(v) || 0;
            const attr = (name) => (el[name] !== undefined && el[name] !== '' ? Number(el[name]) : null);
            const min = el.dataset.min !== undefined ? Number(el.dataset.min) : attr('min');
            const max = el.dataset.max !== undefined ? Number(el.dataset.max) : attr('max');
            if (min !== null && Number.isFinite(min)) v = Math.max(min, v);
            if (max !== null && Number.isFinite(max)) v = Math.min(max, v);
        } else if (type === 'upper4') {
            v = v.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4);
        } else if (type === 'slug') {
            v = v.toLowerCase().replace(/[^a-z0-9_-]/g, '');
        }
        return v;
    }

    function setPath(obj, path, value) {
        const parts = path.split('.');
        let o = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            if (o[parts[i]] === undefined || o[parts[i]] === null) return;
            o = o[parts[i]];
        }
        o[parts[parts.length - 1]] = value;
    }

    function onInput(e) {
        const el = e.target;
        if (el.dataset.picker) { pickerUpdate(el); return; }
        if (el.id === 'bx-filter') {
            S.filter = el.value;
            const pos = el.selectionStart;
            renderPage();
            const again = pageEl().querySelector('#bx-filter');
            if (again) { again.focus(); again.setSelectionRange(pos, pos); }
            return;
        }
        if (el.id === 'bx-bbq') {
            S.bbq = el.value;
            const grid = pageEl().querySelector('#bx-bbgrid');
            const list = spriteList();
            if (grid) grid.innerHTML = list.map((sp) => spriteTile(sp, sp.id === Number(S.cur.blip.sprite))).join('') || `<div class="bx-hint" style="grid-column:1/-1;padding:10px">${esc(t('builder_blip_none', null, 'No icon matches that.'))}</div>`;
            return;
        }
        if (!el.dataset.bind || !S.cur || el.tagName === 'SELECT') return;
        const type = el.dataset.type || 'str';
        if (type === 'int' || type === 'num') {
            if (el.type === 'range') {
                const lab = pageEl().querySelector('#bx-scale');
                if (lab) lab.textContent = Number(el.value).toFixed(2);
            }
            return;
        }
        const v = parseValue(el);
        if (type === 'upper4' || type === 'slug') {
            if (el.value !== v) { const pos = el.selectionStart; el.value = v; el.setSelectionRange(pos, pos); }
        }
        setPath(S.cur, el.dataset.bind, v);
        markDirty();
        if (el.dataset.bind === 'name') {
            const crumb = pageEl().querySelector('.bx-crumb span');
            if (crumb) crumb.textContent = v;
        }
        if (el.dataset.live) select();
    }

    function onChange(e) {
        const el = e.target;
        if (!el.dataset.bind || !S.cur) return;
        const type = el.dataset.type || 'str';
        if (el.tagName !== 'SELECT' && type !== 'int' && type !== 'num') {
            if (el.dataset.bind.endsWith('.model')) {
                const [key, i] = el.dataset.bind.split('.');
                const v = S.cur[key][Number(i)];
                const known = S.catalog.vehicles.find((x) => x.model === v.model);
                if (known && !v.label) { v.label = known.label; renderPage(); }
            }
            return;
        }
        const v = parseValue(el);
        if (type === 'int' || type === 'num') el.value = v;
        setPath(S.cur, el.dataset.bind, v);
        markDirty();
        if (el.dataset.live) select();
        if (el.dataset.redraw) renderPage();
    }

    function onPageKey(e) {
        const el = e.target;
        if (el.dataset && el.dataset.picker) {
            if (e.key === 'Enter') {
                e.preventDefault();
                const first = el.nextElementSibling && el.nextElementSibling.querySelector('.bx-pickopt');
                if (first) pickItem(el.dataset.picker, first.dataset.item);
            }
        }
    }

    async function onClick(e) {
        const el = e.target.closest('[data-act], [data-pt]');
        if (!el) return;
        if (el.dataset.pt !== undefined && !el.dataset.act) {
            S.sel = el.dataset.pt;
            renderPage();
            const row = pageEl().querySelector(`[data-ptrow="${CSS.escape(S.sel)}"]`);
            if (row) row.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
            return;
        }
        const act = el.dataset.act;
        const d = el.dataset;
        if (act === 'ov-close') { if (e.target === el) closeOverlay(); return; }
        if (el.disabled) return;
        switch (act) {
        case 'palette': return openPalette();
        case 'pal-run': return runPalette(Number(d.i));
        case 'modal-btn': {
            const b = S.overlay && S.overlay.buttons[Number(d.i)];
            closeOverlay();
            if (b) await b.fn();
            return;
        }
        case 'close': return XS.close('builder');
        case 'walk': return XS.rpc('builder:walk', {});
        case 'nav':
            if (d.page === 'list') return go('list', d.kind);
            return go(d.page);
        case 'new': return edit(newPlace(d.kind), { dirty: true });
        case 'tpl': return useTemplate(d.tpl);
        case 'open': {
            if (e.target.closest('[data-act]') !== el) return;
            const p = S.places.find((x) => String(x.id) === d.id);
            if (p) edit(p);
            return;
        }
        case 'card-goto': {
            e.stopPropagation();
            const a = anchor(S.places.find((x) => String(x.id) === d.id));
            if (a) XS.rpc('builder:goto', a);
            return;
        }
        case 'card-dup': {
            e.stopPropagation();
            const p = S.places.find((x) => String(x.id) === d.id);
            if (p) edit(duplicate(p), { dirty: true });
            return;
        }
        case 'fix': {
            const issue = globalIssues()[Number(d.i)];
            if (!issue) return;
            if (issue.fix && issue.fix.tpl) return useTemplate(issue.fix.tpl);
            if (issue.place) edit(issue.place, { tab: issue.tab, group: issue.group });
            return;
        }
        default:
            break;
        }
        if (!S.cur) return;
        const p = S.cur;
        switch (act) {
        case 'save': return save();
        case 'discard': {
            const orig = S.places.find((x) => x.id === p.id);
            if (!orig) { S.dirty = false; return go('list', p.kind); }
            S.cur = normalise(copy(orig));
            S.dirty = false;
            select();
            renderPage();
            return XS.toast(t('bx_discarded', null, 'Changes thrown away.'), 'ok');
        }
        case 'dup': return edit(duplicate(p), { dirty: true });
        case 'delete':
            return modal(t('bx_delete_title', { name: p.name }, 'Delete %{name}?'), t('bx_delete_text', null, 'This removes the place and every point in it for good.'), [
                { label: t('cancel', null, 'Cancel'), cls: 'ghost', fn: () => {} },
                { label: t('delete', null, 'Delete'), cls: 'danger', fn: async () => {
                    const res = await XS.rpc('builder:delete', { id: p.id });
                    if (!res.ok) return XS.toast(res.error, 'error');
                    S.places = S.places.filter((x) => x.id !== p.id);
                    S.dirty = false;
                    XS.toast(t('bx_deleted', { name: p.name }, '%{name} deleted.'), 'ok');
                    go('list', p.kind);
                } },
            ]);
        case 'goto-first': { const a = anchor(p); if (a) XS.rpc('builder:goto', a); return; }
        case 'tab': S.tab = d.tab; S.sel = null; return renderPage(true);
        case 'step': S.tab = 'layout'; renderPage(); return scrollToGroup(d.kind);
        case 'labels': S.labels = !S.labels; return renderPage();
        case 'enabled': p.enabled = p.enabled === false; return changed();
        case 'markers': p.markers = !p.markers; return changed();
        case 'job': {
            const set = new Set(p.jobs);
            if (set.has(d.job)) set.delete(d.job); else set.add(d.job);
            p.jobs = Array.from(set);
            return changed();
        }
        case 'pick': S.sel = S.sel === d.ref ? null : d.ref; return renderPage();
        case 'pt-add': {
            const pos = await place(d.kind, null, vehicleExtra(d.kind));
            if (!pos) return;
            const pt = blank(d.kind, pos);
            p.points[d.kind].push(pt);
            S.sel = `${d.kind}:${p.points[d.kind].length - 1}`;
            await placeExit(d.kind, pt);
            return changed();
        }
        case 'pt-addhere': {
            const pos = await here();
            if (!pos) return;
            const pt = blank(d.kind, pos);
            p.points[d.kind].push(pt);
            S.sel = `${d.kind}:${p.points[d.kind].length - 1}`;
            await placeExit(d.kind, pt);
            return changed();
        }
        case 'pt-move': {
            const r = refPoint(d.ref);
            const pos = await place(r.kind, r.list[r.i], vehicleExtra(r.kind));
            if (!pos) return;
            Object.assign(r.list[r.i], posOf(pos));
            S.sel = d.ref;
            return changed();
        }
        case 'pt-here': {
            const r = refPoint(d.ref);
            const pos = await here();
            if (!pos) return;
            Object.assign(r.list[r.i], posOf(pos));
            S.sel = d.ref;
            return changed();
        }
        case 'pt-goto': { const r = refPoint(d.ref); return XS.rpc('builder:goto', r.list[r.i]); }
        case 'pt-del': {
            const r = refPoint(d.ref);
            r.list.splice(r.i, 1);
            S.sel = null;
            return changed();
        }
        case 'pt-spawn': {
            const r = refPoint(d.ref);
            const pt = r.list[r.i];
            const fleetList = r.kind === 'helipad' ? p.helicopters : p.vehicles;
            const model = (fleetList[0] && fleetList[0].model) || (r.kind === 'helipad' ? 'polmav' : 'police');
            const pos = await place(r.kind, pt.spawn || pt, { previewModel: model, previewVehicle: true, label: t('builder_spawn', null, 'Spawn spot') });
            if (!pos) return;
            pt.spawn = posOf(pos);
            return changed();
        }
        case 'pt-exit': {
            const r = refPoint(d.ref);
            const pt = r.list[r.i];
            const had = pt.exit;
            await placeExit(r.kind, pt);
            if (pt.exit === had) return;
            return changed();
        }
        case 'ws-add': {
            const w = p.work[Number(d.j)];
            const last = w.spots[w.spots.length - 1];
            const pos = await place('job', last || null, { label: w.label });
            if (!pos) return;
            w.spots.push(Object.assign({ id: uid() }, posOf(pos)));
            return changed();
        }
        case 'ws-addhere': {
            const pos = await here();
            if (!pos) return;
            p.work[Number(d.j)].spots.push(Object.assign({ id: uid() }, posOf(pos)));
            return changed();
        }
        case 'ws-move': {
            const r = refSpot(d.ref);
            const pos = await place('job', r.list[r.i], { label: r.job.label });
            if (!pos) return;
            Object.assign(r.list[r.i], posOf(pos));
            return changed();
        }
        case 'ws-here': {
            const r = refSpot(d.ref);
            const pos = await here();
            if (!pos) return;
            Object.assign(r.list[r.i], posOf(pos));
            return changed();
        }
        case 'ws-goto': { const r = refSpot(d.ref); return XS.rpc('builder:goto', r.list[r.i]); }
        case 'ws-del': { const r = refSpot(d.ref); r.list.splice(r.i, 1); S.sel = null; return changed(); }
        case 'job-new': {
            const first = XS.list(S.defaults.activities)[0];
            p.work.push({ id: uid(), label: t('builder_job_new', null, 'New job'), activity: first ? first.key : 'repair', seconds: Number(S.defaults.jobSeconds) || 12, credit: Number(S.defaults.jobCredit) || 30, pay: Number(S.defaults.jobPay) || 0, spots: [] });
            return changed();
        }
        case 'job-del': {
            const w = p.work[Number(d.j)];
            return modal(t('bx_job_del_title', { name: w.label }, 'Delete %{name}?'), t('bx_job_del_text', { n: w.spots.length }, 'Its %{n} spots go with it.'), [
                { label: t('cancel', null, 'Cancel'), cls: 'ghost', fn: () => {} },
                { label: t('delete', null, 'Delete'), cls: 'danger', fn: () => { p.work.splice(Number(d.j), 1); changed(); } },
            ]);
        }
        case 'meal-new':
            p.meals.push({ id: uid(), label: t('canteen_default_meal', null, 'Lunch tray'), items: [] });
            return changed();
        case 'meal-del': p.meals.splice(Number(d.j), 1); return changed();
        case 'mi-del': p.meals[Number(d.j)].items.splice(Number(d.i), 1); return changed();
        case 'pick-item': return pickItem(d.target, d.item);
        case 'arm-del': p.armory.splice(Number(d.i), 1); return changed();
        case 'arm-reset': p.armory = copy(XS.list(S.defaults.armory)); return changed();
        case 'veh-add': p[d.key].push({ model: '', label: '', grade: 0, livery: -1, extras: [] }); return changed();
        case 'veh-del': p[d.key].splice(Number(d.i), 1); return changed();
        case 'extra': {
            const v = p[d.key][Number(d.i)];
            const n = Number(d.n);
            v.extras = v.extras.includes(n) ? v.extras.filter((x) => x !== n) : v.extras.concat([n]).sort((a, b) => a - b);
            return changed();
        }
        case 'boli': {
            const has = pointTotal(p) > 0;
            const run = () => { applyBolingbroke(p); changed(); XS.toast(t('builder_bolingbroke_done', null, 'Bolingbroke filled in. Check it over, then save.'), 'ok'); };
            if (!has) return run();
            return modal(t('bx_boli_title', null, 'Replace the points?'), t('bx_boli_text', null, 'This swaps the cells, canteen, workout, release point and job spots on this prison for the Bolingbroke ones.'), [
                { label: t('cancel', null, 'Cancel'), cls: 'ghost', fn: () => {} },
                { label: t('builder_bolingbroke_use', null, 'Use the Bolingbroke layout'), cls: 'primary', fn: run },
            ]);
        }
        case 'center-cam': {
            const pos = await place('center', p.center || null, { label: t('builder_jail_center', null, 'Prison centre') });
            if (!pos) return;
            p.center = { x: pos.x, y: pos.y, z: pos.z };
            return changed();
        }
        case 'center-here': {
            const pos = await here();
            if (!pos) return;
            p.center = { x: pos.x, y: pos.y, z: pos.z };
            return changed();
        }
        case 'center-reset': delete p.center; return changed();
        case 'bb-show': p.blip.show = p.blip.show === false; return changed();
        case 'bb-short': p.blip.short = p.blip.short === false; return changed();
        case 'bb-sprite': p.blip.sprite = Number(d.id); return changed();
        case 'bb-colour': p.blip.colour = Number(d.id); return changed();
        case 'blip-cam': {
            const pos = await place('blip', p.blipAt || null, { label: t('builder_blip_spot', null, 'Map blip') });
            if (!pos) return;
            p.blipAt = { x: pos.x, y: pos.y, z: pos.z };
            return changed();
        }
        case 'blip-here': {
            const pos = await here();
            if (!pos) return;
            p.blipAt = { x: pos.x, y: pos.y, z: pos.z };
            return changed();
        }
        case 'blip-goto': return XS.rpc('builder:goto', p.blipAt);
        case 'blip-reset': delete p.blipAt; return changed();
        default:
        }
    }

    function saveShortcut() {
        if (S.page === 'edit') return save();
        if (S.page === 'settings') return XS.BuilderSettings.save();
        if (S.page === 'wheel') return XS.WheelEditor.save();
        return null;
    }

    window.addEventListener('keydown', (e) => {
        if (!S.open || root.classList.contains('xsp-hidden')) return;
        const typing = /^(INPUT|TEXTAREA|SELECT)$/.test((e.target && e.target.tagName) || '');
        if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); openPalette(); return; }
        if ((e.ctrlKey || e.metaKey) && (e.key === 's' || e.key === 'S')) { e.preventDefault(); saveShortcut(); return; }
        if (e.key === '/' && !typing && !S.overlay) { e.preventDefault(); openPalette(); }
    });

    XS.apps.builder = {
        isOpen: () => S.open,
        escape() {
            if (S.overlay) return closeOverlay();
            const pop = root.querySelector('.bx-pickpop:not([hidden])');
            if (pop) { pop.hidden = true; return null; }
            return XS.close('builder');
        },
        on(action, data) {
            if (action === 'open') {
                data.jobs = XS.list(data.jobs).sort((a, b) => (b.name === 'police') - (a.name === 'police') || XS.list(b.grades).length - XS.list(a.grades).length);
                S.catalog = { vehicles: XS.list(data.vehicles), items: XS.list(data.items), jobs: XS.list(data.jobs).map((j) => Object.assign(j, { grades: XS.list(j.grades) })) };
                S.defaults = data.defaults || {};
                S.kinds = data.kinds || {};
                Object.keys(S.kinds).forEach((k) => { S.kinds[k] = XS.list(S.kinds[k]); });
                S.places = XS.list(data.places).map(normalise);
                S.system = data.system || {};
                S.live = data.live && !Array.isArray(data.live) ? data.live : {};
                XS.WheelEditor.load(data);
                XS.BuilderSettings.load(data);
                if (S.cur) normalise(S.cur);
                if (S.page === 'edit' && !S.cur) S.page = 'overview';
                S.open = true;
                S.overlay = null;
                XS.show('xsp-builder', true);
                shell();
                select();
                loadAreas(S.places.concat(S.cur && S.cur.id === null ? [S.cur] : []));
            } else if (action === 'hide') {
                XS.show('xsp-builder', false);
            } else if (action === 'show') {
                XS.show('xsp-builder', true);
            } else if (action === 'close') {
                S.open = false;
                S.overlay = null;
                XS.show('xsp-builder', false);
            }
        },
    };
})();

(() => {
    const root = document.getElementById('xsp-office');
    const t = XS.t;
    const esc = XS.esc;
    const I = (name, size) => XS.icon(name, size || 16);

    const PAGES = [
        { id: 'overview', icon: 'grid' }, { id: 'roster', icon: 'user' }, { id: 'armory', icon: 'gun' },
        { id: 'garage', icon: 'car' }, { id: 'money', icon: 'cash' }, { id: 'activity', icon: 'paper' },
    ];
    const KIND_ICON = {
        jail: 'jail', service: 'broom', solitary: 'lock', fine: 'fine', seize: 'cash', impound: 'tow', impound_release: 'tow', impound_clear: 'tow', impound_waive: 'tow',
        evidence: 'box', prints: 'fingerprint', vsearch: 'search', k9: 'k9', flag: 'plate', speeding: 'car', licence: 'id', tracker: 'pin',
        hire: 'user', fire: 'exit', promote: 'star', demote: 'star', callsign: 'tag', note: 'edit', warning: 'alert', commend: 'star',
        armory: 'gun', armory_edit: 'gun', fleet_edit: 'car', deposit: 'cash', withdraw: 'cash', unitcam: 'camera',
    };
    const GROUPS = ['all', 'arrests', 'impounds', 'evidence', 'staff', 'gear', 'money'];
    const INCOME = ['fine', 'seize', 'impound_release', 'speeding'];

    let open = false;
    let data = {};
    let page = 'overview';
    let busy = false;
    let roster = { q: '', filter: 'all' };
    let drawer = null;
    let draft = { armory: null, vehicles: null, helicopters: null };
    let log = { group: 'all', q: '', rows: [], done: false };
    let overlay = null;

    const copy = (v) => JSON.parse(JSON.stringify(v));
    const staff = () => XS.list(data.staff);
    const grades = () => XS.list(data.grades);
    const hours = (s) => (Number(s) || 0) / 3600;
    const initials = (name) => String(name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase() || '?';
    const week = (k) => (data.week && data.week[k]) || { n: 0, total: 0 };

    function rankName(level) {
        const g = grades().find((x) => Number(x.level) === Number(level));
        return g ? g.label : String(level);
    }

    function rankOptions(value, max) {
        return grades().filter((g) => Number(g.level) <= max || Number(g.level) === Number(value))
            .map((g) => `<option value="${g.level}" ${Number(g.level) === Number(value) ? 'selected' : ''}>${esc(`${g.level} · ${g.label}`)}</option>`).join('')
            || `<option value="${Number(value) || 0}">${Number(value) || 0}</option>`;
    }

    function when(ts) {
        const s = Math.floor(Date.now() / 1000) - Number(ts || 0);
        return s < 86400 ? XS.ago(ts) : XS.date(ts);
    }

    function sentence(r) {
        const vars = { officer: r.officer || t('of_someone', null, 'Someone'), name: r.name || t('of_someone_else', null, 'someone'), amount: Number(r.amount || 0).toLocaleString('en-US'), detail: r.detail || '' };
        return t(`log_${r.kind}`, vars, '%{officer} · %{detail}');
    }

    async function rpc(name, payload, button) {
        if (busy) return null;
        busy = true;
        if (button) button.disabled = true;
        const res = await XS.rpc(name, Object.assign({ place: data.place, point: data.point }, payload || {}));
        busy = false;
        if (button && button.isConnected) button.disabled = false;
        if (!res.ok) XS.toast(res.error, 'error');
        return res;
    }

    async function refresh() {
        const res = await XS.rpc('boss:refresh', { place: data.place, point: data.point });
        if (res.ok) {
            data = Object.assign(res.data, { place: data.place, point: data.point });
            render();
        }
    }

    function seal() {
        return `<svg class="of-seal" viewBox="0 0 64 64"><defs><linearGradient id="ofSeal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9cc7ff"/><stop offset=".5" stop-color="#3b82f6"/><stop offset="1" stop-color="#1d4ed8"/></linearGradient></defs>
            <path d="M32 3l6.2 6.6 8.9-1.6 2.6 8.7 8.4 3.4-1.9 8.8 5.2 7.4-6.6 6.1.6 9-8.9 1.6-3.9 8.2-8.6-2.8L32 61l-6.2-6.6-8.6 2.8-3.9-8.2-8.9-1.6.6-9-6.6-6.1 5.2-7.4L1.9 26l8.4-3.4 2.6-8.7 8.9 1.6z" fill="url(#ofSeal)"/>
            <circle cx="32" cy="32" r="19" fill="#08111f" stroke="#9cc7ff" stroke-width="1.2"/>
            <path d="M32 18.5l3.6 7.4 8.1 1.1-5.9 5.7 1.4 8L32 36.9l-7.2 3.8 1.4-8-5.9-5.7 8.1-1.1z" fill="url(#ofSeal)"/></svg>`;
    }

    function render() {
        const stage = XS.stage(root);
        const onDuty = Number(data.onDuty) || 0;
        stage.innerHTML = `<div class="of"><div class="bx-lightbar"></div>
            <div class="of-top">
                ${seal()}
                <div class="of-title"><span>${esc(t('of_kicker', null, 'Command office'))}</span><h1>${esc(data.department || data.job || '')}</h1>
                    <small>${I('building', 12)}${esc((data.station || {}).name || '')}</small></div>
                <span class="of-sp"></span>
                ${data.banking ? `<div class="of-kpi"><span>${esc(t('of_balance', null, 'Department account'))}</span><b>${esc(XS.money(data.balance))}</b></div>` : ''}
                <div class="of-kpi"><span>${esc(t('of_on_duty', null, 'On duty'))}</span><b>${onDuty}<em>/ ${staff().length}</em></b></div>
                <button class="of-x" data-close title="${esc(t('close', null, 'Close'))}">${I('close', 17)}</button>
            </div>
            <div class="of-body">
                <nav class="of-nav">
                    ${PAGES.map((p) => `<button class="${page === p.id ? 'on' : ''}" data-page="${p.id}">${I(p.icon, 17)}<span>${esc(t(`of_page_${p.id}`, null, p.id))}</span>${p.id === 'armory' && draft.armory ? '<i class="bx-dot warn"></i>' : ''}${p.id === 'garage' && draft.vehicles ? '<i class="bx-dot warn"></i>' : ''}</button>`).join('')}
                    <div class="of-plate"><span>${esc(t('of_signed', null, 'Signed in'))}</span><b>${esc((data.me || {}).name || '')}</b><em>${esc((data.me || {}).rank || '')}</em></div>
                </nav>
                <main class="of-main xsp-scroll" id="of-main">${body()}</main>
            </div>
            <div id="of-drawer">${drawer ? drawerHtml() : ''}</div>
            <div id="of-ov">${overlay ? overlayHtml() : ''}</div>
        </div>`;
        bind(stage);
        if (page === 'activity' && !log.rows.length && !log.done) loadLog(true);
    }

    function body() {
        if (page === 'roster') return rosterPage();
        if (page === 'armory') return armoryPage();
        if (page === 'garage') return garagePage();
        if (page === 'money') return moneyPage();
        if (page === 'activity') return activityPage();
        return overviewPage();
    }

    function head(title, sub, right) {
        return `<div class="of-head"><div><h2>${esc(title)}</h2>${sub ? `<p>${esc(sub)}</p>` : ''}</div><span class="of-sp"></span>${right || ''}</div>`;
    }

    function tile(icon, value, label, sub, tone) {
        return `<div class="of-tile ${tone || ''}">${I(icon, 18)}<b>${value}</b><span>${esc(label)}</span>${sub ? `<em>${esc(sub)}</em>` : ''}</div>`;
    }

    function feed(rows) {
        return rows.map((r) => `<div class="of-feed"><i class="k-${esc(r.kind)}">${I(KIND_ICON[r.kind] || 'paper', 14)}</i><div><b>${esc(sentence(r))}</b><span>${esc(when(r.at))}</span></div>${INCOME.includes(r.kind) || r.kind === 'deposit' ? `<em class="in">+${esc(XS.money(r.amount))}</em>` : r.kind === 'withdraw' ? `<em class="out">−${esc(XS.money(r.amount))}</em>` : ''}</div>`).join('');
    }

    function overviewPage() {
        const list = staff();
        const weekHours = list.reduce((n, s) => n + hours(s.week), 0);
        const top = list.slice().sort((a, b) => (b.week || 0) - (a.week || 0)).slice(0, 6);
        const maxH = Math.max(1, ...top.map((s) => hours(s.week)));
        const watch = [];
        list.forEach((s) => {
            const w = (s.record || {}).warning || 0;
            if (w >= 2) watch.push({ s, text: t('of_watch_warnings', { n: w }, '%{n} warnings on record'), tone: 'bad' });
            else if (!s.week) watch.push({ s, text: t('of_watch_idle', null, 'No hours this week'), tone: 'warn' });
        });
        return `${head(t('of_page_overview', null, 'Overview'), t('of_overview_sub', null, 'How the department is doing this week.'))}
            <div class="of-tiles">
                ${tile('cash', data.banking ? esc(XS.money(data.balance)) : '—', t('of_balance', null, 'Department account'), t('of_income_week', { amount: XS.money(INCOME.reduce((n, k) => n + week(k).total, 0)) }, '%{amount} in this week'), 'green')}
                ${tile('shield', `${Number(data.onDuty) || 0}<em>/${list.length}</em>`, t('of_on_duty_now', null, 'On duty now'), t('of_staff_n', { n: list.length }, '%{n} on the roster'))}
                ${tile('clock', weekHours.toFixed(1), t('of_hours_week', null, 'Hours this week'), t('of_hours_avg', { n: list.length ? (weekHours / list.length).toFixed(1) : '0' }, '%{n} per officer'))}
                ${tile('jail', week('jail').n, t('of_arrests_week', null, 'Jailed this week'), t('of_service_week', { n: week('service').n }, '%{n} community service'), 'red')}
                ${tile('fine', week('fine').n, t('of_fines_week', null, 'Fines this week'), XS.money(week('fine').total))}
                ${tile('tow', week('impound').n, t('of_impounds_week', null, 'Impounds this week'), t('of_released_n', { n: week('impound_release').n }, '%{n} collected'))}
                ${tile('box', week('evidence').n, t('of_evidence_week', null, 'Evidence bagged'), t('of_prints_n', { n: week('prints').n }, '%{n} prints taken'))}
                ${tile('user', `${week('hire').n}<em>/${week('fire').n}</em>`, t('of_hires_week', null, 'Hired / let go'), t('of_this_week', null, 'This week'))}
            </div>
            <div class="of-cols">
                <div class="of-card"><div class="of-cardh">${I('star', 15)}<h3>${esc(t('of_top', null, 'Top officers this week'))}</h3></div>
                    ${top.length ? top.map((s, i) => `<div class="of-bar"><span class="of-rank">${i + 1}</span><div><b>${esc(s.name || s.cid)}</b><small>${esc([s.callsign, rankName(s.grade)].filter(Boolean).join(' · '))}</small><i style="width:${(hours(s.week) / maxH) * 100}%"></i></div><em>${hours(s.week).toFixed(1)} h</em></div>`).join('') : `<p class="of-empty">${esc(t('boss_empty', null, 'No staff yet.'))}</p>`}</div>
                <div class="of-card"><div class="of-cardh">${I('alert', 15)}<h3>${esc(t('of_watch', null, 'Needs your attention'))}</h3></div>
                    ${watch.length ? watch.slice(0, 7).map((w) => `<button class="of-watch ${w.tone}" data-record="${esc(w.s.cid)}"><span class="of-av">${esc(initials(w.s.name))}</span><div><b>${esc(w.s.name || w.s.cid)}</b><small>${esc(w.text)}</small></div>${I('chevron', 14)}</button>`).join('') : `<p class="of-empty">${I('check', 16)} ${esc(t('of_watch_none', null, 'Nobody needs a word right now.'))}</p>`}</div>
            </div>
            <div class="of-card" style="margin-top:14px"><div class="of-cardh">${I('paper', 15)}<h3>${esc(t('of_latest', null, 'Latest activity'))}</h3><span class="of-sp"></span><button class="bx-btn xs ghost" data-page="activity">${esc(t('of_see_all', null, 'See all'))}${I('chevron', 12)}</button></div>
                ${XS.list(data.recent).length ? feed(XS.list(data.recent)) : `<p class="of-empty">${esc(t('of_no_activity', null, 'Nothing logged yet.'))}</p>`}</div>`;
    }

    function rosterPage() {
        const max = Number(data.myGrade) || 0;
        const q = roster.q.toLowerCase();
        const list = staff().filter((s) => {
            if (q && !`${s.name} ${s.cid} ${s.callsign}`.toLowerCase().includes(q)) return false;
            if (roster.filter === 'duty') return s.onDuty;
            if (roster.filter === 'online') return s.online;
            if (roster.filter === 'offline') return !s.online;
            return true;
        });
        const nearby = XS.list(data.nearby);
        const meCid = (data.me || {}).cid;
        const rows = list.map((s) => {
            const canEdit = s.cid !== meCid && (data.isBoss || Number(s.grade) < max + 1);
            const rec = s.record || {};
            const status = s.onDuty ? 'duty' : s.online ? 'online' : 'offline';
            return `<tr data-cid="${esc(s.cid)}">
                <td><div class="of-who"><span class="of-av">${esc(initials(s.name))}</span><div><b>${esc(s.name || s.cid)}</b><small>${esc(s.cid)}</small></div></div></td>
                <td><input class="bx-input sm mono of-cs" data-callsign maxlength="10" value="${esc(s.callsign || '')}" placeholder="—"></td>
                <td><select class="bx-input sm" data-grade ${canEdit ? '' : 'disabled'}>${rankOptions(s.grade, max)}</select></td>
                <td><span class="of-status ${status}"><i></i>${esc(t(`of_status_${status}`, null, status))}</span></td>
                <td><div class="of-hours"><b>${hours(s.week).toFixed(1)} h</b><small>${esc(t('of_total_h', { n: Math.round(hours(s.total)) }, '%{n} h total'))}</small></div></td>
                <td><button class="of-rec" data-record="${esc(s.cid)}">${rec.commend ? `<span class="c">${I('star', 11)}${rec.commend}</span>` : ''}${rec.warning ? `<span class="w">${I('alert', 11)}${rec.warning}</span>` : ''}${rec.note ? `<span class="n">${I('edit', 11)}${rec.note}</span>` : ''}${!rec.commend && !rec.warning && !rec.note ? `<span class="n">${esc(t('of_clean', null, 'Clean'))}</span>` : ''}</button></td>
                <td class="r"><div class="of-acts">
                    <button class="bx-tool" data-step="1" title="${esc(t('of_promote', null, 'Promote'))}" ${canEdit && Number(s.grade) < max ? '' : 'disabled'}>▲</button>
                    <button class="bx-tool" data-step="-1" title="${esc(t('of_demote', null, 'Demote'))}" ${canEdit && Number(s.grade) > 0 ? '' : 'disabled'}>▼</button>
                    <button class="bx-tool" data-record="${esc(s.cid)}" title="${esc(t('of_record', null, 'Record'))}">${I('paper', 14)}</button>
                    <button class="bx-tool danger" data-fire title="${esc(t('boss_fire', null, 'Fire'))}" ${canEdit ? '' : 'disabled'}>${I('exit', 14)}</button>
                </div></td></tr>`;
        }).join('');
        return `${head(t('of_page_roster', null, 'Roster'), t('of_roster_sub', null, 'Everyone in the department. Change ranks and callsigns straight from the table.'))}
            <div class="of-rosterbar">
                <div class="bx-filter">${I('search', 15)}<input class="bx-input" id="of-q" value="${esc(roster.q)}" placeholder="${esc(t('of_search_staff', null, 'Name, citizen ID or callsign'))}"></div>
                <div class="of-seg">${['all', 'duty', 'online', 'offline'].map((f) => `<button class="${roster.filter === f ? 'on' : ''}" data-filter="${f}">${esc(t(`of_filter_${f}`, null, f))}</button>`).join('')}</div>
                <span class="of-sp"></span>
                <div class="of-hire">${I('plus', 15)}${nearby.length ? `<select class="bx-input sm" id="of-target">${nearby.map((n) => `<option value="${n.src}">${esc(n.name)}</option>`).join('')}</select>
                    <select class="bx-input sm" id="of-hgrade">${rankOptions(0, max)}</select><button class="bx-btn sm primary" id="of-hire">${esc(t('boss_hire_btn', null, 'Hire'))}</button>`
                    : `<span>${esc(t('boss_nobody', null, 'Stand next to the person you want to hire.'))}</span>`}</div>
            </div>
            <div class="of-card of-tablewrap"><table class="bx-table of-table"><thead><tr><th>${esc(t('of_col_officer', null, 'Officer'))}</th><th>${esc(t('boss_callsign', null, 'Callsign'))}</th><th>${esc(t('of_col_rank', null, 'Rank'))}</th><th>${esc(t('of_col_status', null, 'Status'))}</th><th>${esc(t('of_col_week', null, 'This week'))}</th><th>${esc(t('of_col_record', null, 'Record'))}</th><th class="r"></th></tr></thead>
                <tbody>${rows || `<tr><td colspan="7"><p class="of-empty">${esc(t('of_nobody_matches', null, 'Nobody matches.'))}</p></td></tr>`}</tbody></table></div>`;
    }

    function drawerHtml() {
        const s = staff().find((x) => x.cid === drawer.cid) || {};
        const notes = XS.list(drawer.notes);
        return `<div class="of-shade" data-closedrawer></div><aside class="of-drawer">
            <div class="of-drawerh"><span class="of-av big">${esc(initials(s.name))}</span><div><b>${esc(s.name || drawer.cid)}</b><small>${esc([s.callsign, rankName(s.grade)].filter(Boolean).join(' · '))}</small></div><span class="of-sp"></span><button class="of-x" data-closedrawer>${I('close', 16)}</button></div>
            <div class="of-drawerstats"><div><b>${hours(s.week).toFixed(1)} h</b><span>${esc(t('of_this_week', null, 'This week'))}</span></div><div><b>${Math.round(hours(s.total))} h</b><span>${esc(t('of_all_time', null, 'All time'))}</span></div><div><b>${((s.record || {}).warning) || 0}</b><span>${esc(t('of_warnings', null, 'Warnings'))}</span></div></div>
            <div class="of-addnote">
                <div class="of-seg">${['note', 'warning', 'commend'].map((k) => `<button class="${drawer.kind === k ? 'on' : ''} k-${k}" data-nk="${k}">${esc(t(`of_kind_${k}`, null, k))}</button>`).join('')}</div>
                <textarea class="bx-input" id="of-notetext" rows="3" maxlength="255" placeholder="${esc(t(`of_kind_${drawer.kind}_hint`, null, ''))}">${esc(drawer.text || '')}</textarea>
                <button class="bx-btn sm primary" id="of-noteadd">${I('plus', 13)}${esc(t('of_add_record', null, 'Add to record'))}</button>
            </div>
            <div class="of-notes xsp-scroll">${drawer.loading ? `<p class="of-empty">…</p>` : notes.map((n) => `<div class="of-note k-${esc(n.kind)}"><div class="of-noteh"><span>${esc(t(`of_kind_${n.kind}`, null, n.kind))}</span><small>${esc(n.author)} · ${esc(XS.date(n.at))}</small>${data.isBoss ? `<button class="bx-tool danger" data-delnote="${n.id}">${I('remove', 12)}</button>` : ''}</div><p>${esc(n.text)}</p></div>`).join('') || `<p class="of-empty">${esc(t('of_record_empty', null, 'Nothing on record.'))}</p>`}</div>
        </aside>`;
    }

    function overlayHtml() {
        return `<div class="of-modalwrap"><div class="bx-modal"><h3>${esc(overlay.title)}</h3><p>${esc(overlay.text)}</p><div class="acts">${overlay.buttons.map((b, i) => `<button class="bx-btn ${b.cls || ''}" data-ovb="${i}">${esc(b.label)}</button>`).join('')}</div></div></div>`;
    }

    function poolItem(name) {
        return XS.list((data.pools || {}).items).find((i) => i.name === name) || null;
    }

    function thumb(name) {
        const hit = poolItem(name);
        return `<span class="bx-thumb">${hit && hit.image ? `<img src="${esc(hit.image)}" alt="" onerror="this.remove()">` : I('box', 18)}</span>`;
    }

    function saveBar(kind) {
        return `<div class="of-savebar"><span>${esc(t('of_unsaved', null, 'Changes not saved'))}</span><button class="bx-btn sm ghost" data-discard="${kind}">${esc(t('builder_discard', null, 'Discard'))}</button><button class="bx-btn sm primary" data-save="${kind}">${I('check', 13)}${esc(t('save', null, 'Save'))}</button></div>`;
    }

    function armoryPage() {
        const list = draft.armory || XS.list((data.station || {}).armory);
        const max = Number(data.myGrade) >= 99 ? 50 : Number(data.myGrade) || 0;
        const used = new Set(list.map((e) => e.item));
        const options = XS.list((data.pools || {}).items).filter((i) => !used.has(i.name));
        return `${head(t('of_page_armory', null, 'Armory'), t('of_armory_sub', { station: (data.station || {}).name || '' }, 'What officers can take at %{station}, the lowest rank for each and what it costs. Prices come out of the department account.'),
            `<div class="of-addsel"><select class="bx-input" id="of-additem">${options.map((i) => `<option value="${esc(i.name)}">${esc(i.label)}</option>`).join('') || `<option value="">${esc(t('of_pool_empty', null, 'Nothing else allowed'))}</option>`}</select><button class="bx-btn primary" id="of-armadd" ${options.length ? '' : 'disabled'}>${I('plus', 14)}${esc(t('builder_add_item', null, 'Add item'))}</button></div>`)}
            ${list.length ? `<div class="bx-items"><div class="bx-itemrow head"><span></span><span>${esc(t('builder_item', null, 'Item'))}</span><span>${esc(t('we_grade', null, 'Lowest rank'))}</span><span>${esc(t('builder_price', null, 'Price'))}</span><span>${esc(t('builder_amount', null, 'Amount'))}</span><span></span></div>
                ${list.map((e, i) => {
                    const info = poolItem(e.item);
                    return `<div class="bx-itemrow">${thumb(e.item)}<div class="bx-itemname"><b>${esc(info ? info.label : e.item)}</b><small>${esc(e.item)}</small></div>
                        <select class="bx-input sm" data-arm="${i}" data-f="grade">${rankOptions(e.grade, max)}</select>
                        <div class="bx-unit"><input type="number" min="0" max="${Number(data.maxPrice) || 100000}" data-arm="${i}" data-f="price" value="${Number(e.price) || 0}"><em>$</em></div>
                        <div class="bx-unit"><input type="number" min="1" max="250" data-arm="${i}" data-f="amount" value="${Number(e.amount) || 1}"><em>×</em></div>
                        <button class="bx-tool danger" data-armdel="${i}">${I('remove', 14)}</button></div>`;
                }).join('')}</div>` : `<div class="bx-empty">${I('gun', 28)}<b>${esc(t('bx_armory_empty', null, 'The armory is empty'))}</b></div>`}
            ${draft.armory ? saveBar('armory') : ''}`;
    }

    function fleetBlock(key, title, icon, heli) {
        const list = draft[key] || XS.list((data.station || {})[key]);
        const max = Number(data.myGrade) >= 99 ? 50 : Number(data.myGrade) || 0;
        const pool = XS.list((data.pools || {}).vehicles).filter((v) => !!v.heli === heli);
        const used = new Set(list.map((v) => v.model));
        const free = pool.filter((v) => !used.has(v.model));
        const label = (m) => (pool.find((v) => v.model === m) || {}).label || m;
        return `<div class="of-card" style="margin-bottom:14px"><div class="of-cardh">${I(icon, 15)}<h3>${esc(title)}</h3><small>${esc(t('bx_count_vehicles', { n: list.length }, '%{n} vehicles'))}</small><span class="of-sp"></span>
                <select class="bx-input sm" data-addveh-sel="${key}" style="width:220px">${free.map((v) => `<option value="${esc(v.model)}">${esc(v.label)}</option>`).join('') || `<option value="">${esc(t('of_pool_empty', null, 'Nothing else allowed'))}</option>`}</select>
                <button class="bx-btn sm" data-addveh="${key}" ${free.length ? '' : 'disabled'}>${I('plus', 13)}${esc(t('builder_add_vehicle', null, 'Add vehicle'))}</button></div>
            <div class="bx-items">${list.map((v, i) => `<div class="bx-vehwrap"><div class="bx-veh" style="grid-template-columns:minmax(0,1fr) minmax(0,1fr) 170px 92px 30px">
                <div class="bx-mini"><span>${esc(t('builder_model', null, 'Model'))}</span><div class="of-model"><b>${esc(label(v.model))}</b><small>${esc(v.model)}</small></div></div>
                <div class="bx-mini"><span>${esc(t('bx_menu_name', null, 'Name in the menu'))}</span><input class="bx-input sm" maxlength="32" data-veh="${key}:${i}" data-f="label" value="${esc(v.label || '')}"></div>
                <div class="bx-mini"><span>${esc(t('we_grade', null, 'Lowest rank'))}</span><select class="bx-input sm" data-veh="${key}:${i}" data-f="grade">${rankOptions(v.grade, max)}</select></div>
                <div class="bx-mini"><span>${esc(t('builder_livery', null, 'Livery'))}</span><input class="bx-input sm mono" type="number" min="-1" max="99" data-veh="${key}:${i}" data-f="livery" value="${v.livery === undefined ? -1 : Number(v.livery)}"></div>
                <button class="bx-tool danger" data-vehdel="${key}:${i}">${I('remove', 14)}</button></div>
                <div class="bx-extras"><span>${esc(t('builder_extras', null, 'Extras on'))}</span>${Array.from({ length: 14 }, (_, n) => n + 1).map((n) => `<button class="bx-extra ${XS.list(v.extras).includes(n) ? 'on' : ''}" data-extra="${key}:${i}:${n}">${n}</button>`).join('')}</div></div>`).join('') || `<p class="of-empty">${esc(t('bx_fleet_empty', null, 'Nothing here yet.'))}</p>`}</div></div>`;
    }

    function garagePage() {
        return `${head(t('of_page_garage', null, 'Garage'), t('of_garage_sub', { station: (data.station || {}).name || '' }, 'What officers can take out at %{station} and the lowest rank for each.'))}
            ${fleetBlock('vehicles', t('builder_cars', null, 'Garage'), 'car', false)}${fleetBlock('helicopters', t('builder_helis', null, 'Helipad'), 'helicopter', true)}
            ${draft.vehicles ? saveBar('fleet') : ''}`;
    }

    function moneyPage() {
        const income = INCOME.map((k) => ({ k, w: week(k) }));
        const total = income.reduce((n, x) => n + x.w.total, 0);
        return `${head(t('of_page_money', null, 'Money'), t('of_money_sub', null, 'The department account and where the money came from this week.'))}
            <div class="of-cols" style="grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr)">
                <div class="of-card of-vault"><span>${esc(t('of_balance', null, 'Department account'))}</span><b>${data.banking ? esc(XS.money(data.balance)) : '—'}</b>
                    ${data.banking ? `<div class="bx-unit" style="margin-top:16px"><input type="number" min="1" id="of-amount" placeholder="0"><em>$</em></div>
                    <div class="of-moneybtns"><button class="bx-btn" data-money="deposit">${I('plus', 14)}${esc(t('boss_deposit', null, 'Deposit'))}</button><button class="bx-btn" data-money="withdraw">${I('cash', 14)}${esc(t('boss_withdraw', null, 'Withdraw'))}</button></div>
                    <p class="of-fine">${esc(t('of_money_note', null, 'Deposits come from your cash. Withdrawals go to your cash and are logged.'))}</p>` : `<p class="of-fine">${esc(t('err_no_banking', null, 'No banking script found.'))}</p>`}</div>
                <div class="of-card"><div class="of-cardh">${I('fine', 15)}<h3>${esc(t('of_income', null, 'Income this week'))}</h3><span class="of-sp"></span><b class="of-total">${esc(XS.money(total))}</b></div>
                    ${income.map((x) => `<div class="of-incrow"><span>${esc(t(`of_income_${x.k}`, null, x.k))}</span><i><u style="width:${total ? (x.w.total / total) * 100 : 0}%"></u></i><b>${esc(XS.money(x.w.total))}</b><small>${x.w.n}×</small></div>`).join('')}</div>
            </div>
            <div class="of-card" style="margin-top:14px"><div class="of-cardh">${I('paper', 15)}<h3>${esc(t('of_ledger', null, 'Ledger'))}</h3></div><div id="of-ledger">${log.ledger ? (feed(log.ledger) || `<p class="of-empty">${esc(t('of_no_activity', null, 'Nothing logged yet.'))}</p>`) : '<p class="of-empty">…</p>'}</div></div>`;
    }

    function activityPage() {
        return `${head(t('of_page_activity', null, 'Activity'), t('of_activity_sub', null, 'Everything the department has done, newest first.'))}
            <div class="of-rosterbar">
                <div class="bx-filter">${I('search', 15)}<input class="bx-input" id="of-lq" value="${esc(log.q)}" placeholder="${esc(t('of_search_log', null, 'Search names, plates, reasons'))}"></div>
                <div class="of-seg">${GROUPS.map((g) => `<button class="${log.group === g ? 'on' : ''}" data-group="${g}">${esc(t(`of_group_${g}`, null, g))}</button>`).join('')}</div>
            </div>
            <div class="of-card">${log.rows.length ? feed(log.rows) : `<p class="of-empty">${esc(log.loading ? '…' : t('of_no_activity', null, 'Nothing logged yet.'))}</p>`}
                ${!log.done && log.rows.length ? `<div style="padding:10px;text-align:center"><button class="bx-btn sm" id="of-more">${esc(t('of_more', null, 'Show more'))}</button></div>` : ''}</div>`;
    }

    async function loadLog(reset) {
        if (reset) { log.rows = []; log.done = false; }
        log.loading = true;
        const res = await XS.rpc('boss:log', { place: data.place, point: data.point, filter: { kind: log.group, search: log.q, offset: log.rows.length, limit: 50 } });
        log.loading = false;
        if (res.ok) {
            const rows = XS.list(res.data.rows);
            log.rows = log.rows.concat(rows);
            log.done = rows.length < 50;
            if (res.data.week && !Array.isArray(res.data.week)) data.week = res.data.week;
        }
        if (open && page === 'activity') renderMain();
    }

    async function loadLedger() {
        const res = await XS.rpc('boss:log', { place: data.place, point: data.point, filter: { kind: 'money', limit: 30 } });
        log.ledger = res.ok ? XS.list(res.data.rows) : [];
        if (open && page === 'money') renderMain();
    }

    function renderMain() {
        const main = root.querySelector('#of-main');
        if (!main) return render();
        const top = main.scrollTop;
        main.innerHTML = body();
        main.scrollTop = top;
        bindMain(main);
    }

    function modal(title, text, buttons) {
        overlay = { title, text, buttons };
        root.querySelector('#of-ov').innerHTML = overlayHtml();
        root.querySelectorAll('[data-ovb]').forEach((b) => b.addEventListener('click', async () => {
            const btn = overlay.buttons[Number(b.dataset.ovb)];
            overlay = null;
            root.querySelector('#of-ov').innerHTML = '';
            if (btn && btn.fn) await btn.fn();
        }));
    }

    async function openRecord(cid) {
        drawer = { cid, kind: 'note', text: '', notes: [], loading: true };
        renderDrawer();
        const res = await XS.rpc('boss:notes', { place: data.place, point: data.point, cid });
        if (!drawer || drawer.cid !== cid) return;
        drawer.loading = false;
        drawer.notes = res.ok ? XS.list(res.data) : [];
        if (!res.ok) XS.toast(res.error, 'error');
        renderDrawer();
    }

    function renderDrawer() {
        const box = root.querySelector('#of-drawer');
        if (!box) return;
        box.innerHTML = drawer ? drawerHtml() : '';
        if (!drawer) return;
        box.querySelectorAll('[data-closedrawer]').forEach((b) => b.addEventListener('click', () => { drawer = null; renderDrawer(); }));
        box.querySelectorAll('[data-nk]').forEach((b) => b.addEventListener('click', () => {
            drawer.text = box.querySelector('#of-notetext').value;
            drawer.kind = b.dataset.nk;
            renderDrawer();
        }));
        box.querySelector('#of-noteadd').addEventListener('click', async (e) => {
            const text = box.querySelector('#of-notetext').value.trim();
            if (!text) return XS.toast(t('of_need_text', null, 'Write something first.'), 'error');
            const res = await rpc('boss:note', { cid: drawer.cid, kind: drawer.kind, text }, e.currentTarget);
            if (!res || !res.ok) return;
            XS.toast(t(`of_added_${drawer.kind}`, null, 'Added to their record.'), 'ok');
            const s = staff().find((x) => x.cid === drawer.cid);
            if (s) { s.record = s.record || {}; s.record[drawer.kind] = (s.record[drawer.kind] || 0) + 1; }
            const cid = drawer.cid;
            renderMain();
            openRecord(cid);
        });
        box.querySelectorAll('[data-delnote]').forEach((b) => b.addEventListener('click', async () => {
            const res = await rpc('boss:noteDelete', { id: Number(b.dataset.delnote) }, b);
            if (res && res.ok) openRecord(drawer.cid);
        }));
    }

    function bind(stage) {
        stage.querySelector('[data-close]').addEventListener('click', () => XS.close('office'));
        stage.querySelectorAll('.of-nav [data-page]').forEach((b) => b.addEventListener('click', () => go(b.dataset.page)));
        bindMain(stage.querySelector('#of-main'));
        renderDrawer();
    }

    function go(next) {
        page = next;
        if (next === 'money') loadLedger();
        if (next === 'activity') { log.rows = []; log.done = false; }
        render();
    }

    function bindMain(main) {
        main.querySelectorAll('[data-page]').forEach((b) => b.addEventListener('click', () => go(b.dataset.page)));
        main.querySelectorAll('[data-record]').forEach((b) => b.addEventListener('click', () => openRecord(b.dataset.record)));
        const q = main.querySelector('#of-q');
        if (q) q.addEventListener('input', () => {
            roster.q = q.value;
            const pos = q.selectionStart;
            renderMain();
            const again = root.querySelector('#of-q');
            again.focus();
            again.setSelectionRange(pos, pos);
        });
        main.querySelectorAll('[data-filter]').forEach((b) => b.addEventListener('click', () => { roster.filter = b.dataset.filter; renderMain(); }));
        const hire = main.querySelector('#of-hire');
        if (hire) hire.addEventListener('click', async () => {
            const res = await rpc('boss:hire', { target: Number(main.querySelector('#of-target').value), grade: Number(main.querySelector('#of-hgrade').value) }, hire);
            if (res && res.ok) { XS.toast(t('boss_hired', null, 'Hired.'), 'ok'); refresh(); }
        });
        main.querySelectorAll('tr[data-cid]').forEach((row) => {
            const cid = row.dataset.cid;
            const s = staff().find((x) => x.cid === cid) || {};
            const setGrade = async (grade, el) => {
                const res = await rpc('boss:grade', { cid, grade }, el);
                if (res && res.ok) { XS.toast(t(grade > Number(s.grade) ? 'of_promoted' : 'of_demoted', { name: s.name, rank: rankName(grade) }, '%{name} is now %{rank}.'), 'ok'); refresh(); }
            };
            const sel = row.querySelector('[data-grade]');
            sel.addEventListener('change', () => setGrade(Number(sel.value), sel));
            row.querySelectorAll('[data-step]').forEach((b) => b.addEventListener('click', () => setGrade(Number(s.grade) + Number(b.dataset.step), b)));
            const cs = row.querySelector('[data-callsign]');
            cs.addEventListener('change', async () => {
                const res = await rpc('boss:callsign', { cid, callsign: cs.value }, cs);
                if (res && res.ok) { s.callsign = res.data; cs.value = res.data; XS.toast(t('boss_callsign_saved', null, 'Callsign saved.'), 'ok'); } else cs.value = s.callsign || '';
            });
            row.querySelector('[data-fire]').addEventListener('click', () => modal(t('of_fire_title', { name: s.name }, 'Let %{name} go?'), t('of_fire_text', null, 'They lose the job straight away, online or not.'), [
                { label: t('cancel', null, 'Cancel'), cls: 'ghost' },
                { label: t('boss_fire', null, 'Fire'), cls: 'danger', fn: async () => {
                    const res = await rpc('boss:fire', { cid });
                    if (res && res.ok) { XS.toast(t('boss_fired', null, 'Let go.'), 'ok'); refresh(); }
                } },
            ]));
        });

        const armadd = main.querySelector('#of-armadd');
        if (armadd) armadd.addEventListener('click', () => {
            const item = main.querySelector('#of-additem').value;
            if (!item) return;
            draft.armory = draft.armory || copy(XS.list((data.station || {}).armory));
            draft.armory.push({ item, grade: 0, price: 0, amount: 1 });
            render();
        });
        main.querySelectorAll('[data-arm]').forEach((el) => el.addEventListener('change', () => {
            draft.armory = draft.armory || copy(XS.list((data.station || {}).armory));
            const e = draft.armory[Number(el.dataset.arm)];
            e[el.dataset.f] = Math.max(el.dataset.f === 'amount' ? 1 : 0, Math.floor(Number(el.value) || 0));
            if (el.dataset.f === 'price') e.price = Math.min(Number(data.maxPrice) || 100000, e.price);
            el.value = e[el.dataset.f];
            if (!root.querySelector('.of-savebar')) render();
        }));
        main.querySelectorAll('[data-armdel]').forEach((b) => b.addEventListener('click', () => {
            draft.armory = draft.armory || copy(XS.list((data.station || {}).armory));
            draft.armory.splice(Number(b.dataset.armdel), 1);
            render();
        }));

        const fleet = () => {
            if (!draft.vehicles) {
                draft.vehicles = copy(XS.list((data.station || {}).vehicles));
                draft.helicopters = copy(XS.list((data.station || {}).helicopters));
            }
        };
        main.querySelectorAll('[data-addveh]').forEach((b) => b.addEventListener('click', () => {
            const key = b.dataset.addveh;
            const model = main.querySelector(`[data-addveh-sel="${key}"]`).value;
            if (!model) return;
            fleet();
            const pool = XS.list((data.pools || {}).vehicles).find((v) => v.model === model) || {};
            draft[key].push({ model, label: pool.label || model, grade: 0, livery: -1, extras: [] });
            render();
        }));
        main.querySelectorAll('[data-veh]').forEach((el) => el.addEventListener('change', () => {
            fleet();
            const [key, i] = el.dataset.veh.split(':');
            const v = draft[key][Number(i)];
            v[el.dataset.f] = el.dataset.f === 'label' ? el.value.trim() : Math.floor(Number(el.value) || 0);
            if (el.dataset.f === 'livery') v.livery = Math.max(-1, Math.min(99, v.livery));
            if (!root.querySelector('.of-savebar')) render();
        }));
        main.querySelectorAll('[data-vehdel]').forEach((b) => b.addEventListener('click', () => {
            fleet();
            const [key, i] = b.dataset.vehdel.split(':');
            draft[key].splice(Number(i), 1);
            render();
        }));
        main.querySelectorAll('[data-extra]').forEach((b) => b.addEventListener('click', () => {
            fleet();
            const [key, i, n] = b.dataset.extra.split(':');
            const v = draft[key][Number(i)];
            const num = Number(n);
            v.extras = XS.list(v.extras).includes(num) ? XS.list(v.extras).filter((x) => x !== num) : XS.list(v.extras).concat([num]).sort((a, c) => a - c);
            render();
        }));
        main.querySelectorAll('[data-discard]').forEach((b) => b.addEventListener('click', () => {
            if (b.dataset.discard === 'armory') draft.armory = null; else { draft.vehicles = null; draft.helicopters = null; }
            render();
        }));
        main.querySelectorAll('[data-save]').forEach((b) => b.addEventListener('click', async () => {
            if (b.dataset.save === 'armory') {
                const res = await rpc('boss:armory', { list: draft.armory }, b);
                if (res && res.ok) { data.station.armory = XS.list(res.data); draft.armory = null; XS.toast(t('of_armory_saved', null, 'Armory saved. Officers see it straight away.'), 'ok'); render(); }
            } else {
                const res = await rpc('boss:fleet', { vehicles: draft.vehicles, helicopters: draft.helicopters }, b);
                if (res && res.ok) { data.station.vehicles = XS.list(res.data.vehicles); data.station.helicopters = XS.list(res.data.helicopters); draft.vehicles = null; draft.helicopters = null; XS.toast(t('of_fleet_saved', null, 'Garage saved.'), 'ok'); render(); }
            }
        }));

        main.querySelectorAll('[data-money]').forEach((b) => b.addEventListener('click', async () => {
            const amount = Math.floor(Number(main.querySelector('#of-amount').value) || 0);
            if (amount <= 0) return XS.toast(t('err_amount', null, 'Enter an amount.'), 'error');
            const res = await rpc('boss:money', { direction: b.dataset.money, amount }, b);
            if (res && res.ok) { data.balance = res.data; XS.toast(t(b.dataset.money === 'deposit' ? 'of_deposited' : 'of_withdrew', { amount: XS.money(amount) }, '%{amount} done.'), 'ok'); render(); loadLedger(); }
        }));

        const lq = main.querySelector('#of-lq');
        let timer = null;
        if (lq) lq.addEventListener('input', () => {
            log.q = lq.value;
            clearTimeout(timer);
            timer = setTimeout(() => loadLog(true).then(() => {
                const again = root.querySelector('#of-lq');
                if (again) { again.focus(); again.setSelectionRange(again.value.length, again.value.length); }
            }), 300);
        });
        main.querySelectorAll('[data-group]').forEach((b) => b.addEventListener('click', () => { log.group = b.dataset.group; loadLog(true); renderMain(); }));
        const more = main.querySelector('#of-more');
        if (more) more.addEventListener('click', () => loadLog(false));
    }

    XS.apps.office = {
        isOpen: () => open,
        escape() {
            if (overlay) { overlay = null; root.querySelector('#of-ov').innerHTML = ''; return; }
            if (drawer) { drawer = null; renderDrawer(); return; }
            XS.close('office');
        },
        on(action, payload) {
            if (action === 'open') {
                data = payload || {};
                open = true;
                drawer = null;
                overlay = null;
                draft = { armory: null, vehicles: null, helicopters: null };
                log = { group: 'all', q: '', rows: [], done: false };
                if (!PAGES.some((p) => p.id === page)) page = 'overview';
                XS.show('xsp-office', true);
                render();
                if (page === 'money') loadLedger();
            } else if (action === 'close') {
                open = false;
                XS.show('xsp-office', false);
            }
        },
    };
})();

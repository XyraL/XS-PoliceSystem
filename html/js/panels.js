(() => {
    const root = document.getElementById('xsp-panel');
    const t = XS.t;
    const esc = XS.esc;
    let app = null;
    let data = {};
    let busy = false;

    function shell(kicker, title, body, wide) {
        const stage = XS.stage(root);
        stage.innerHTML = `<div class="xp-panel ${wide ? 'xp-wide' : ''}">
            <div class="xp-head"><span class="xp-rail"></span>
                <div class="xp-titles"><div class="xp-kicker">${esc(kicker)}</div><h2>${esc(title)}</h2></div>
                <button class="xp-x" data-close title="${esc(t('close', null, 'Close'))}">${XS.icon('close', 18)}</button>
            </div>
            <div class="xp-body xsp-scroll">${body}</div>
        </div>`;
        stage.querySelector('[data-close]').addEventListener('click', () => XS.close(app));
        return stage;
    }

    async function run(name, payload, button) {
        if (busy) return null;
        busy = true;
        if (button) button.disabled = true;
        const res = await XS.rpc(name, payload);
        busy = false;
        if (button) button.disabled = false;
        if (!res.ok) XS.toast(res.error, 'error');
        return res;
    }

    const CATS = { weapons: 'gun', ammo: 'ammo', gear: 'gear' };
    let armoryCat = 'all';

    function category(item) {
        const name = String(item || '').toLowerCase();
        if (name.startsWith('weapon_')) return 'weapons';
        if (name.includes('ammo')) return 'ammo';
        return 'gear';
    }

    function photo(src, icon, size) {
        return `<div class="xp-photo">${src ? `<img src="${esc(src)}" alt="" draggable="false">` : ''}<span class="xp-ph">${XS.icon(icon || 'box', size || 30)}</span></div>`;
    }

    function photos(stage) {
        stage.querySelectorAll('.xp-photo img').forEach((img) => {
            const done = () => img.parentNode.classList.add(img.naturalWidth > 0 ? 'has' : 'none');
            if (img.complete) done();
            else {
                img.addEventListener('load', done, { once: true });
                img.addEventListener('error', () => img.parentNode.classList.add('none'), { once: true });
            }
        });
    }

    function armory() {
        const items = XS.list(data.items);
        const present = Object.keys(CATS).filter((c) => items.some((e) => category(e.item) === c));
        if (armoryCat !== 'all' && !present.includes(armoryCat)) armoryCat = 'all';
        const shown = items.filter((e) => armoryCat === 'all' || category(e.item) === armoryCat);
        const tabs = present.length > 1 ? `<div class="ar-tabs">${['all'].concat(present).map((c) => `<button class="ar-tab ${armoryCat === c ? 'on' : ''}" data-cat="${c}">${c === 'all' ? '' : XS.icon(CATS[c], 15)}${esc(t(`armory_cat_${c}`, null, c))}<em>${c === 'all' ? items.length : items.filter((e) => category(e.item) === c).length}</em></button>`).join('')}</div>` : '';
        const cards = shown.map((e) => `<div class="ar-card" data-item="${esc(e.item)}">
            ${photo(e.image, CATS[category(e.item)], 34)}
            ${e.amount > 1 ? `<em class="ar-count xp-mono">×${e.amount}</em>` : ''}
            <div class="ar-name"><b>${esc(e.label)}</b><span class="xp-mono">${esc(e.item)}</span></div>
            <div class="ar-meta"><span class="xp-chip ${e.price > 0 ? 'warn' : 'on'}">${e.price > 0 ? esc(XS.money(e.price)) : esc(t('free', null, 'Free'))}</span>
                ${e.grade > 0 ? `<span class="xp-chip">${esc(t('grade_short', { grade: e.grade }, `Grade ${e.grade}+`))}</span>` : ''}</div>
            <div class="ar-take"><div class="xp-qty"><button data-dec>−</button><input class="xp-mono" value="1" maxlength="2"><button data-inc>+</button></div>
                <button class="xp-btn primary small" data-take>${esc(t('armory_take', null, 'Take'))}</button></div>
        </div>`).join('');
        const body = `${tabs}${cards ? `<div class="ar-grid">${cards}</div>` : `<div class="xp-empty">${esc(t('armory_empty', null, 'Nothing here for your rank.'))}</div>`}`;
        const stage = shell(t('armory_title', null, 'Armory'), data.station || '', body, true);
        photos(stage);
        stage.querySelectorAll('[data-cat]').forEach((b) => b.addEventListener('click', () => { armoryCat = b.dataset.cat; armory(); }));
        stage.querySelectorAll('.ar-card').forEach((card) => {
            const input = card.querySelector('input');
            const clamp = () => { input.value = String(Math.min(10, Math.max(1, Math.floor(Number(input.value) || 1)))); };
            card.querySelector('[data-dec]').addEventListener('click', () => { input.value = String(Number(input.value) - 1); clamp(); });
            card.querySelector('[data-inc]').addEventListener('click', () => { input.value = String(Number(input.value) + 1); clamp(); });
            input.addEventListener('change', clamp);
            card.querySelector('[data-take]').addEventListener('click', async (e) => {
                clamp();
                const res = await run('armory:take', { place: data.place, point: data.point, item: card.dataset.item, qty: Number(input.value) }, e.currentTarget);
                if (res && res.ok) XS.toast(res.data, 'ok');
            });
        });
    }

    function lockerTag(n) {
        return `#${String(n).padStart(4, '0')}`;
    }

    function evidence() {
        const lockers = XS.list(data.lockers);
        const max = Number(data.max) || 9999;
        const known = new Map(lockers.map((l) => [Number(l.number), l]));
        const rows = (list) => list.map((l) => `<div class="xp-row ev-row" data-n="${l.number}">
                <span class="ev-tag xp-mono">${lockerTag(l.number)}</span>
                <div class="xp-row-main"><b>${esc(l.label || t('evidence_no_note', null, 'No note'))}</b><span>${esc(t('evidence_opened', { name: l.by || '?', when: XS.ago(l.at) }, `Opened by ${l.by} · ${XS.ago(l.at)}`))}</span></div>
                <button class="xp-btn small" data-open="${l.number}">${esc(t('evidence_open_btn', null, 'Open'))}</button>
            </div>`).join('') || `<div class="xp-empty">${esc(t('evidence_none', null, 'No lockers used yet. Type a number to open one.'))}</div>`;
        const body = `<div class="ev-top">
                <div class="ev-num"><label class="xp-label">${esc(t('evidence_locker', null, 'Locker'))}</label>
                    <input class="xp-input xp-mono ev-big" id="ev-n" inputmode="numeric" maxlength="${String(max).length}" placeholder="${'0'.repeat(String(max).length - 1)}1"></div>
                <div class="ev-lab"><label class="xp-label">${esc(t('evidence_note', null, 'Case or note'))}</label>
                    <input class="xp-input" id="ev-l" maxlength="96" placeholder="${esc(t('evidence_note_hint', null, 'Case 1042 · Fleeca robbery'))}"></div>
                <button class="xp-btn primary ev-go" id="ev-go">${XS.icon('locker', 16)}${esc(t('evidence_open_locker', null, 'Open locker'))}</button>
            </div>
            <div class="xp-note">${esc(t(data.shared ? 'evidence_range_shared' : 'evidence_range', { max }, `Lockers 1 to ${max}.`))}</div>
            <div class="ev-bar"><span class="xp-label">${esc(t('evidence_in_use', { count: lockers.length }, `Lockers in use (${lockers.length})`))}</span>
                <input class="xp-input" id="ev-q" placeholder="${esc(t('evidence_search', null, 'Search a number or note'))}"></div>
            <div class="xp-list ev-list" id="ev-list">${rows(lockers)}</div>`;
        const stage = shell(t('evidence_title', null, 'Evidence room'), data.station || '', body, true);
        const num = stage.querySelector('#ev-n');
        const note = stage.querySelector('#ev-l');
        let noteTouched = false;
        note.addEventListener('input', () => { noteTouched = true; });
        num.addEventListener('input', () => {
            num.value = num.value.replace(/[^0-9]/g, '');
            const hit = known.get(Number(num.value));
            if (!noteTouched) note.value = hit ? hit.label : '';
        });
        const open = async (n, label, button) => {
            n = Math.floor(Number(n) || 0);
            if (n < 1 || n > max) return XS.toast(t('err_locker_number', { max }, `Pick a locker from 1 to ${max}.`), 'error');
            await run('evidence:open', { place: data.place, point: data.point, number: n, label }, button);
        };
        const go = stage.querySelector('#ev-go');
        go.addEventListener('click', () => open(num.value, note.value.trim(), go));
        num.addEventListener('keydown', (e) => { if (e.key === 'Enter') open(num.value, note.value.trim(), go); });
        note.addEventListener('keydown', (e) => { if (e.key === 'Enter') open(num.value, note.value.trim(), go); });
        const bindRows = () => {
            stage.querySelectorAll('.ev-row').forEach((row) => row.addEventListener('click', (e) => {
                const l = known.get(Number(row.dataset.n));
                if (!l) return;
                if (e.target.closest('[data-open]')) return open(l.number, l.label, e.target.closest('[data-open]'));
                num.value = String(l.number);
                note.value = l.label || '';
                noteTouched = false;
                num.focus();
            }));
        };
        bindRows();
        stage.querySelector('#ev-q').addEventListener('input', (e) => {
            const q = e.target.value.trim().toLowerCase();
            const list = q ? lockers.filter((l) => String(l.number).includes(q) || lockerTag(l.number).includes(q) || String(l.label || '').toLowerCase().includes(q)) : lockers;
            stage.querySelector('#ev-list').innerHTML = rows(list);
            bindRows();
        });
        setTimeout(() => num.focus(), 30);
    }

    XS.span = function span(seconds) {
        const s = Math.max(0, Math.floor(Number(seconds) || 0));
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0) return `${d}d ${h}h`;
        if (h > 0) return `${h}h ${String(m).padStart(2, '0')}m`;
        if (m > 0) return `${m}m ${String(s % 60).padStart(2, '0')}s`;
        return `${s % 60}s`;
    };

    function hoursLabel(h) {
        return h === 0 ? t('impound_hold_none', null, 'None') : (h % 24 === 0 && h >= 24 ? t('impound_days', { n: h / 24 }, `${h / 24} d`) : t('impound_hours', { n: h }, `${h} h`));
    }

    function impound() {
        const lots = XS.list(data.lots);
        const holds = XS.list(data.holds).map(Number).filter((h) => h >= 0 && h <= (Number(data.maxHours) || 168));
        let lot = lots[0] ? lots[0].id : null;
        let hours = Math.min(Number(data.maxHours) || 168, Math.max(0, Math.floor(Number(data.hold) || 0)));
        const dist = (m) => (m === null || m === undefined ? '' : (m >= 1000 ? `${(m / 1000).toFixed(1)} km` : `${m} m`));
        const body = `<div class="xp-subject">${XS.icon('car', 18)}<span>${esc(data.model || '')} · ${esc(data.plate || '')}</span></div>
            <label class="xp-label">${esc(t('impound_lot', null, 'Impound lot'))}</label>
            <div class="im-lots">${lots.map((l) => `<button class="im-lot ${l.id === lot ? 'on' : ''}" data-lot="${l.id}"><b>${esc(l.name)}</b><span class="xp-mono">${esc(dist(l.distance))}</span></button>`).join('')}</div>
            <label class="xp-label" style="margin-top:14px">${esc(t('impound_hold', null, 'Hold'))}</label>
            <div class="xp-inline im-holds">${holds.map((h) => `<button class="xp-btn small ${h === hours ? 'primary' : ''}" data-h="${h}">${esc(hoursLabel(h))}</button>`).join('')}
                <input class="xp-input xp-mono" id="im-hours" inputmode="numeric" value="${hours}" style="width:70px;flex:none"><span class="xp-note" style="margin:0">${esc(t('impound_hours_unit', null, 'hours'))}</span></div>
            <div class="xp-note" id="im-when"></div>
            <div class="xp-two" style="margin-top:14px">
                <div><label class="xp-label">${esc(t('impound_fee', null, 'Release fee'))}</label>
                    <input class="xp-input xp-mono" id="im-fee" inputmode="numeric">
                    <div class="xp-note">${esc(t('impound_fee_range', { min: XS.money(data.minFee), max: XS.money(data.maxFee) }, `${XS.money(data.minFee)} to ${XS.money(data.maxFee)}`))}</div></div>
                <div><label class="xp-label">${esc(t('impound_police_hold', null, 'Police hold'))}</label>
                    <label class="im-check"><input type="checkbox" id="im-ph"><span>${esc(t('impound_police_hold_text', null, 'Only police can let it go'))}</span></label></div>
            </div>
            <label class="xp-label" style="margin-top:14px">${esc(t('form_reason', null, 'Reason'))}</label>
            <textarea class="xp-input" id="im-reason" rows="2" maxlength="160" placeholder="${esc(t('impound_reason_hint', null, 'Evading police, no insurance'))}"></textarea>
            <div class="xp-foot"><button class="xp-btn" data-close2>${esc(t('cancel', null, 'Cancel'))}</button><button class="xp-btn primary" id="im-go">${XS.icon('tow', 16)}${esc(t('impound_go', null, 'Impound'))}</button></div>`;
        const stage = shell(t('impound_title', null, 'Impound'), data.plate || '', body);
        const fee = stage.querySelector('#im-fee');
        const hoursInput = stage.querySelector('#im-hours');
        const when = stage.querySelector('#im-when');
        const setFee = () => { const l = lots.find((x) => x.id === lot); fee.value = String(l ? l.fee : 0); };
        const showWhen = () => {
            if (hours <= 0) { when.textContent = t('impound_when_now', null, 'The owner can collect it right away.'); return; }
            const d = new Date(Date.now() + hours * 3600 * 1000);
            const at = `${d.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' })} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
            when.textContent = t('impound_when', { time: at }, `The owner can collect it from ${at}. The hold runs in real time.`);
        };
        setFee();
        showWhen();
        stage.querySelector('[data-close2]').addEventListener('click', () => XS.close(app));
        stage.querySelectorAll('[data-lot]').forEach((b) => b.addEventListener('click', () => {
            lot = Number(b.dataset.lot);
            stage.querySelectorAll('[data-lot]').forEach((x) => x.classList.toggle('on', x === b));
            setFee();
        }));
        stage.querySelectorAll('[data-h]').forEach((b) => b.addEventListener('click', () => {
            hours = Number(b.dataset.h);
            hoursInput.value = String(hours);
            stage.querySelectorAll('[data-h]').forEach((x) => x.classList.toggle('primary', x === b));
            showWhen();
        }));
        hoursInput.addEventListener('input', () => {
            hours = Math.min(Number(data.maxHours) || 168, Math.max(0, Math.floor(Number(hoursInput.value.replace(/[^0-9]/g, '')) || 0)));
            stage.querySelectorAll('[data-h]').forEach((x) => x.classList.toggle('primary', Number(x.dataset.h) === hours));
            showWhen();
        });
        const go = stage.querySelector('#im-go');
        go.addEventListener('click', async () => {
            const reason = stage.querySelector('#im-reason').value.trim();
            if (!reason) return XS.toast(t('err_need_reason', null, 'Add a reason.'), 'error');
            const amount = Math.floor(Number(fee.value) || 0);
            if (amount < (Number(data.minFee) || 0) || amount > (Number(data.maxFee) || 25000)) return XS.toast(t('impound_fee_range', { min: XS.money(data.minFee), max: XS.money(data.maxFee) }, 'Fee out of range'), 'error');
            await run('impound:submit', { lot, hours, fee: amount, reason, policeHold: stage.querySelector('#im-ph').checked }, go);
        });
        setTimeout(() => stage.querySelector('#im-reason').focus(), 30);
    }

    let lotTab = 'mine';
    let lotTimer = null;

    function lotStatus(r, opened) {
        const left = Math.max(0, r.left - Math.floor((Date.now() - opened) / 1000));
        if (r.policeHold) return `<span class="xp-chip bad">${XS.icon('lock', 11)} ${esc(t('impound_status_police', null, 'Police hold'))}</span>`;
        if (left > 0) return `<span class="xp-chip warn" data-left="${r.left}">${esc(t('impound_status_held', { time: XS.span(left) }, `Held · ${XS.span(left)}`))}</span>`;
        return `<span class="xp-chip on">${esc(t('impound_status_ready', null, 'Ready'))}</span>`;
    }

    function impoundlot() {
        const opened = data.openedAt || (data.openedAt = Date.now());
        const mine = XS.list(data.mine);
        const all = data.all ? XS.list(data.all) : null;
        if (!all) lotTab = 'mine';
        const mineCards = mine.map((r) => {
            const here = Number(r.lot) === Number(data.lot);
            const left = Math.max(0, r.left - Math.floor((Date.now() - opened) / 1000));
            const ready = here && !r.policeHold && left <= 0;
            return `<div class="il-card ${ready ? 'ready' : ''}">
                <div class="il-plate xp-mono">${esc(r.plate)}</div>
                <div class="il-main"><b>${esc(r.label || r.model || '')}</b><span>${esc(r.reason || '')}</span>
                    <small>${esc(t('impound_by', { name: r.officer || '?', when: XS.date(r.at) }, `${r.officer} · ${XS.date(r.at)}`))}${here ? '' : ` · <i>${esc(t('impound_at_other', { lot: r.lotName }, `At ${r.lotName}`))}</i>`}</small></div>
                <div class="il-side">${lotStatus(r, opened)}
                    <button class="xp-btn ${ready ? 'primary' : ''} small" data-release="${r.id}" data-model="${esc(r.model || '')}" ${ready ? '' : 'disabled'}>${esc(r.fee > 0 ? t('impound_pay', { fee: XS.money(r.fee) }, `Pay ${XS.money(r.fee)} and collect`) : t('impound_collect', null, 'Collect'))}</button></div>
            </div>`;
        }).join('') || `<div class="xp-empty">${esc(t('impound_none_mine', null, 'You have no vehicles in the impound.'))}</div>`;
        const allRows = (list) => list.map((r) => `<div class="xp-row il-row">
                <span class="il-plate sm xp-mono">${esc(r.plate)}</span>
                <div class="xp-row-main"><b>${esc(r.owner || '?')} · ${esc(r.label || r.model || '')}</b><span>${esc(r.reason || '')} · ${esc(r.officer || '')} · ${esc(XS.date(r.at))}</span></div>
                ${lotStatus(r, opened)}<span class="xp-chip">${esc(XS.money(r.fee))}</span>
                ${data.canManage ? `<button class="xp-btn small" data-manage="clear" data-id="${r.id}" ${!r.policeHold && r.left <= 0 ? 'disabled' : ''}>${esc(t('impound_clear', null, 'Clear hold'))}</button>
                <button class="xp-btn small" data-manage="waive" data-id="${r.id}" ${r.fee > 0 ? '' : 'disabled'}>${esc(t('impound_waive', null, 'Waive fee'))}</button>` : ''}
            </div>`).join('') || `<div class="xp-empty">${esc(t('impound_none_lot', null, 'Nothing is held at this lot.'))}</div>`;
        const tabs = all ? `<div class="ar-tabs"><button class="ar-tab ${lotTab === 'mine' ? 'on' : ''}" data-lt="mine">${esc(t('impound_tab_mine', null, 'My vehicles'))}<em>${mine.length}</em></button>
            <button class="ar-tab ${lotTab === 'all' ? 'on' : ''}" data-lt="all">${XS.icon('paper', 15)}${esc(t('impound_tab_all', null, 'Lot records'))}<em>${all.length}</em></button></div>` : '';
        const body = lotTab === 'all' && all
            ? `${tabs}<input class="xp-input" id="il-q" placeholder="${esc(t('impound_search', null, 'Search a plate, owner or reason'))}" style="margin-bottom:10px"><div class="xp-list" id="il-list">${allRows(all)}</div>`
            : `${tabs}<div class="il-cards">${mineCards}</div>`;
        const stage = shell(t('impound_lot_title', null, 'Impound lot'), data.name || '', body, true);
        stage.querySelectorAll('[data-lt]').forEach((b) => b.addEventListener('click', () => { lotTab = b.dataset.lt; impoundlot(); }));
        const refresh = async () => {
            const res = await XS.rpc('impoundlot:refresh', { place: data.place, point: data.point });
            if (res.ok) { data = Object.assign(res.data, { place: data.place, point: data.point, openedAt: Date.now() }); impoundlot(); }
        };
        stage.querySelectorAll('[data-release]').forEach((b) => b.addEventListener('click', async () => {
            const res = await run('impoundlot:release', { place: data.place, point: data.point, id: Number(b.dataset.release), model: b.dataset.model }, b);
            if (res && res.ok) XS.toast(res.data, 'ok');
        }));
        const bindManage = () => stage.querySelectorAll('[data-manage]').forEach((b) => b.addEventListener('click', async () => {
            const res = await run('impoundlot:manage', { place: data.place, point: data.point, id: Number(b.dataset.id), action: b.dataset.manage }, b);
            if (res && res.ok) { XS.toast(res.data, 'ok'); refresh(); }
        }));
        bindManage();
        const q = stage.querySelector('#il-q');
        if (q) q.addEventListener('input', () => {
            const v = q.value.trim().toLowerCase();
            const list = v ? all.filter((r) => [r.plate, r.owner, r.reason, r.model, r.officer].some((x) => String(x || '').toLowerCase().includes(v))) : all;
            stage.querySelector('#il-list').innerHTML = allRows(list);
            bindManage();
        });
        if (lotTimer) clearInterval(lotTimer);
        lotTimer = setInterval(() => {
            if (app !== 'impoundlot') { clearInterval(lotTimer); lotTimer = null; return; }
            let expired = false;
            stage.querySelectorAll('[data-left]').forEach((chip) => {
                const left = Math.max(0, Number(chip.dataset.left) - Math.floor((Date.now() - opened) / 1000));
                if (left <= 0) expired = true;
                chip.textContent = left > 0 ? t('impound_status_held', { time: XS.span(left) }, `Held · ${XS.span(left)}`) : t('impound_status_ready', null, 'Ready');
            });
            if (expired && lotTab === 'mine') impoundlot();
        }, 1000);
    }

    function garage() {
        const list = XS.list(data.vehicles);
        const rows = list.map((v) => `<div class="xp-row">
            <div class="xp-row-main"><b>${esc(v.label)}</b><span class="xp-mono">${esc(v.model)}</span></div>
            ${v.grade > 0 ? `<span class="xp-chip">${esc(t('grade_short', { grade: v.grade }, `Grade ${v.grade}+`))}</span>` : ''}
            <button class="xp-btn primary small" data-model="${esc(v.model)}">${esc(t('garage_take', null, 'Take out'))}</button>
        </div>`).join('') || `<div class="xp-empty">${esc(t('garage_empty', null, 'No vehicles for your rank here.'))}</div>`;
        const stage = shell(t(data.kind === 'helipad' ? 'helipad_title' : 'garage_title', null, 'Garage'), data.station || '', `<div class="xp-list">${rows}</div>`);
        stage.querySelectorAll('[data-model]').forEach((b) => b.addEventListener('click', () => {
            run('garage:spawn', { place: data.place, point: data.point, kind: data.kind, model: b.dataset.model }, b);
        }));
    }

    function gradeOptions(selected, max) {
        return XS.list(data.grades).filter((g) => g.level <= max).map((g) => `<option value="${g.level}" ${Number(selected) === g.level ? 'selected' : ''}>${esc(g.level)} · ${esc(g.label)}</option>`).join('');
    }

    function flagForm() {
        const hours = [0, 2, 12, 24, 72, 168].filter((h) => h <= (Number(data.maxHours) || 720));
        const body = `
            ${data.current ? `<div class="fl-now">${XS.icon('panic', 16)}<span>${esc(t('flag_current', { reason: data.current }, `Flagged now: ${data.current}`))}</span></div>` : ''}
            <label class="xp-label">${esc(t('flag_plate', null, 'Plate'))}</label>
            <div class="fl-plate"><input class="fl-plate-in" id="fl-plate" maxlength="8" value="${esc(data.plate || '')}" spellcheck="false"><span>SAN ANDREAS</span></div>
            <label class="xp-label" style="margin-top:14px">${esc(t('flag_reason', null, 'Reason'))}</label>
            <textarea class="xp-input" id="fl-reason" rows="2" maxlength="160" placeholder="${esc(t('flag_reason_hint', null, 'Stolen, used in a robbery'))}"></textarea>
            <label class="xp-label" style="margin-top:14px">${esc(t('flag_hours', null, 'How long'))}</label>
            <div class="xp-inline fl-hours">${hours.map((h, i) => `<button class="xp-btn small ${i === 0 ? 'on' : ''}" data-h="${h}">${esc(h === 0 ? t('flag_forever', null, 'Until removed') : (h < 24 ? h + ' h' : (h / 24) + ' d'))}</button>`).join('')}</div>
            <div class="xp-foot">${data.current ? `<button class="xp-btn danger" id="fl-remove">${esc(t('flag_remove', null, 'Remove flag'))}</button><span style="flex:1"></span>` : ''}<button class="xp-btn" data-close2>${esc(t('cancel', null, 'Cancel'))}</button><button class="xp-btn primary" id="fl-go">${esc(t('flag_go', null, 'Flag it'))}</button></div>`;
        const stage = shell(t('flag_title', null, 'Flag a plate'), data.plate || t('flag_title', null, 'Flag a plate'), body.replace('<div class="xp-foot">', `<div class="xp-note" style="margin-top:12px">${esc(t('flag_sub', null, ''))}</div><div class="xp-foot">`));
        let picked = hours[0] || 0;
        stage.querySelector('[data-close2]').addEventListener('click', () => XS.close(app));
        stage.querySelectorAll('[data-h]').forEach((b) => b.addEventListener('click', () => {
            picked = Number(b.dataset.h);
            stage.querySelectorAll('[data-h]').forEach((x) => x.classList.toggle('on', x === b));
        }));
        const plateIn = stage.querySelector('#fl-plate');
        plateIn.addEventListener('input', () => { plateIn.value = plateIn.value.toUpperCase().replace(/[^A-Z0-9 ]/g, ''); });
        const go = stage.querySelector('#fl-go');
        go.addEventListener('click', async () => {
            const plate = plateIn.value.trim();
            const reason = stage.querySelector('#fl-reason').value.trim();
            if (!plate) return XS.toast(t('err_plate', null, 'Enter a plate.'), 'error');
            if (!reason) return XS.toast(t('err_need_reason', null, 'Add a reason.'), 'error');
            const res = await run('form:submit', { kind: 'flag', plate, reason, hours: picked }, go);
            if (res && res.ok) XS.toast(res.data, 'ok');
        });
        const remove = stage.querySelector('#fl-remove');
        if (remove) remove.addEventListener('click', async () => {
            const res = await run('form:submit', { kind: 'flag', plate: plateIn.value.trim(), remove: true }, remove);
            if (res && res.ok) XS.toast(res.data, 'ok');
        });
        setTimeout(() => (data.plate ? stage.querySelector('#fl-reason') : plateIn).focus(), 30);
    }

    function cameras() {
        const list = XS.list(data.cameras);
        const last = Number(data.last) || 0;
        const row = (c) => `<div class="xp-row cm-row ${c.id === last ? 'cm-last' : ''}" data-cam="${c.id}">
                <span class="cm-id xp-mono">${String(c.id).padStart(2, '0')}</span>
                <div class="xp-row-main"><b>${esc(c.label)}</b>${c.id === last ? `<span class="cm-tag">${esc(t('cam_last', null, 'From the last alert'))}</span>` : ''}</div>
                <span class="xp-chip ${c.online ? 'on' : 'off'}">${esc(c.online ? t('cam_live', null, 'Live') : t('cam_offline', null, 'Offline'))}</span>
                <button class="xp-btn small primary" data-watch="${c.id}">${esc(t('cam_watch', null, 'Watch'))}</button>
            </div>`;
        const sorted = list.slice().sort((a, b) => (b.id === last) - (a.id === last) || a.id - b.id);
        const body = `<input class="xp-input" id="cm-search" placeholder="${esc(t('cam_search', null, 'Search cameras'))}">
            <div class="xp-list cm-list" id="cm-list" style="margin-top:12px">${sorted.map(row).join('') || `<div class="xp-empty">${esc(t('cam_none', null, 'No cameras found.'))}</div>`}</div>`;
        const stage = shell(t('cam_title', null, 'Security cameras'), t('cam_sub', null, 'Banks and stores'), body);
        const bind = () => stage.querySelectorAll('[data-watch]').forEach((b) => b.addEventListener('click', () => run('cameras:watch', { id: Number(b.dataset.watch) }, b)));
        bind();
        const search = stage.querySelector('#cm-search');
        search.addEventListener('input', () => {
            const q = search.value.trim().toLowerCase();
            const hit = sorted.filter((c) => !q || c.label.toLowerCase().includes(q) || String(c.id) === q);
            stage.querySelector('#cm-list').innerHTML = hit.map(row).join('') || `<div class="xp-empty">${esc(t('cam_none', null, 'No cameras found.'))}</div>`;
            bind();
        });
        setTimeout(() => search.focus(), 30);
    }

    function licences() {
        const list = XS.list(data.list);
        const cards = list.map((l) => `<div class="lc-card ${l.has ? 'ok' : 'no'}">
                <div class="lc-ico">${XS.icon(l.kind === 'weapon' ? 'gun' : 'car', 22)}</div>
                <div class="lc-main"><b>${esc(t('licence_' + l.kind, null, l.kind))}</b><span class="xp-chip ${l.has ? 'on' : 'off'}">${esc(l.has ? t('licence_valid', null, 'Valid') : t('licence_none', null, 'None'))}</span></div>
                ${l.has ? `<button class="xp-btn small danger" data-set="${esc(l.kind)}" data-on="0">${esc(t('licence_take', null, 'Take'))}</button>`
                    : (data.canGrant ? `<button class="xp-btn small primary" data-set="${esc(l.kind)}" data-on="1">${esc(t('licence_give', null, 'Give'))}</button>` : '')}
            </div>`).join('');
        const body = `<div class="lc-list">${cards}</div>
            ${data.canGrant ? '' : `<div class="xp-note" style="margin-top:10px">${esc(t('licences_rank', null, ''))}</div>`}`;
        const stage = shell(t('licences_title', null, 'Licences'), data.name || '', body);
        stage.querySelectorAll('[data-set]').forEach((b) => b.addEventListener('click', async () => {
            const res = await run('licence:set', { target: data.target, kind: b.dataset.set, on: b.dataset.on === '1' }, b);
            if (res && res.ok) {
                XS.toast(res.data.message, 'ok');
                if (res.data.licences) { data = res.data.licences; licences(); }
            }
        }));
    }

    function seeded(text) {
        let h = 2166136261;
        String(text || 'xs').split('').forEach((c) => { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); });
        return () => { h ^= h << 13; h ^= h >>> 17; h ^= h << 5; return ((h >>> 0) % 10000) / 10000; };
    }

    function striations(rand, x, w, shift) {
        let out = '';
        for (let i = 0; i < 26; i++) {
            const y = 20 + rand() * 200;
            const sw = 0.6 + rand() * 2.6;
            const op = 0.35 + rand() * 0.55;
            out += `<line x1="${x}" y1="${y + shift}" x2="${x + w}" y2="${y + shift + (rand() - 0.5) * 3}" stroke="rgba(40,30,10,${op})" stroke-width="${sw}"/>`;
        }
        return out;
    }

    function ridges(rand, cx, cy) {
        let out = '';
        for (let i = 0; i < 15; i++) {
            const rx = 10 + i * 6.2;
            const ry = 14 + i * 7.4;
            const dash = `${8 + rand() * 30} ${2 + rand() * 6}`;
            out += `<ellipse cx="${cx}" cy="${cy + i * 0.8}" rx="${rx}" ry="${ry}" fill="none" stroke-width="2.2" stroke-dasharray="${dash}" stroke-dashoffset="${rand() * 40}"/>`;
        }
        return out;
    }

    function minutiae(rand, cx, cy) {
        let out = '';
        for (let i = 0; i < 9; i++) {
            const a = rand() * Math.PI * 2;
            const r = 20 + rand() * 70;
            out += `<circle cx="${cx + Math.cos(a) * r * 0.8}" cy="${cy + Math.sin(a) * r}" r="4"/>`;
        }
        return out;
    }

    function labBench(row, start) {
        const key = row.dataset.key;
        const bag = XS.list(data.bags).find((b) => b.key === key) || {};
        const bench = start.bench;
        const begun = Date.now();
        const seconds = Number(start.seconds) || 8;
        const rand = seeded(start.code || key);
        const body = root.querySelector('.xp-body');
        const titles = {
            microscope: [t('lab_bench_scope', null, 'Comparison microscope'), t('lab_bench_scope_hint', null, 'Slide the test casing until the marks line up with the casing from the scene.')],
            sequencer: [t('lab_bench_dna', null, 'DNA run'), t('lab_bench_dna_hint', null, 'Hold to spin the sample and let go when the needle is in the green.')],
            overlay: [t('lab_bench_print', null, 'Print comparison'), t('lab_bench_print_hint', null, 'Turn the lifted print until the ridges sit on top of the one on file.')],
        };
        let stage = '';
        if (bench === 'microscope') {
            const pattern = seeded(start.code || key);
            const left = striations(pattern, 40, 200, 0);
            const right = striations(seeded(start.code || key), 260, 200, 0);
            stage = `<svg viewBox="0 0 500 240" class="lbx-svg"><defs><clipPath id="lbxLens"><circle cx="250" cy="120" r="112"/></clipPath><linearGradient id="lbxBrass" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8a6326"/><stop offset=".45" stop-color="#e8c071"/><stop offset=".55" stop-color="#f3d58e"/><stop offset="1" stop-color="#8a6326"/></linearGradient></defs>
                <circle cx="250" cy="120" r="116" fill="#05070a" stroke="#2a3343" stroke-width="4"/>
                <g clip-path="url(#lbxLens)"><rect x="40" y="0" width="210" height="240" fill="url(#lbxBrass)"/>${left}
                <g id="lbx-shift"><rect x="250" y="-60" width="210" height="360" fill="url(#lbxBrass)"/>${right}</g>
                <line x1="250" y1="0" x2="250" y2="240" stroke="rgba(255,255,255,.75)" stroke-width="1.2"/></g>
                <circle cx="250" cy="120" r="112" fill="none" stroke="rgba(0,0,0,.6)" stroke-width="18" stroke-opacity=".35"/>
                <text x="120" y="232" class="lbx-tag">${esc(t('lab_bench_scene', null, 'SCENE'))}</text><text x="330" y="232" class="lbx-tag">${esc(t('lab_bench_test', null, 'TEST FIRE'))}</text></svg>
                <input type="range" class="lbx-range" id="lbx-in" min="-60" max="60" step="1" value="${Math.round((rand() > 0.5 ? 1 : -1) * (25 + rand() * 30))}">`;
        } else if (bench === 'overlay') {
            const r1 = seeded(start.code || key);
            const r2 = seeded(start.code || key);
            const dots = seeded(`${start.code || key}m`);
            const dots2 = seeded(`${start.code || key}m`);
            stage = `<svg viewBox="0 0 500 240" class="lbx-svg"><rect x="130" y="0" width="240" height="240" rx="12" fill="#0b1018" stroke="#263043"/>
                <g stroke="rgba(124,180,255,.55)">${ridges(r1, 250, 115)}</g>
                <g id="lbx-rot" stroke="rgba(255,255,255,.85)">${ridges(r2, 250, 115)}<g fill="#ff5d6c" stroke="none" id="lbx-dots" opacity=".2">${minutiae(dots, 250, 115)}</g></g>
                <g fill="none" stroke="#7cb4ff" stroke-width="2" opacity=".4">${minutiae(dots2, 250, 115)}</g></svg>
                <input type="range" class="lbx-range" id="lbx-in" min="-70" max="70" step="1" value="${Math.round((rand() > 0.5 ? 1 : -1) * (25 + rand() * 35))}">`;
        } else {
            stage = `<div class="lbx-dna"><div class="lbx-gauge"><i class="green"></i><b id="lbx-needle"></b></div>
                <button class="xp-btn primary" id="lbx-hold">${esc(t('lab_bench_hold', null, 'Hold to spin'))}</button>
                <div class="lbx-gel" id="lbx-gel">${[0, 1, 2, 3].map((l) => `<div class="lane ${l === 0 ? 'sample' : ''}">${Array.from({ length: 7 }, () => `<i style="top:${8 + rand() * 84}%;opacity:0"></i>`).join('')}</div>`).join('')}</div></div>`;
        }
        body.innerHTML = `<div class="lbx">
            <div class="lbx-head"><span class="xp-chip lb-type lb-${esc(bag.type)}">${esc(t('lab_type_' + bag.type, null, bag.type))}</span><div><b>${esc(titles[bench][0])}</b><span>${esc(titles[bench][1])}</span></div></div>
            <div class="lbx-stage">${stage}</div>
            <div class="lbx-meter"><i id="lbx-meter"></i></div>
            <div class="lbx-status" id="lbx-status">${esc(bag.label)}${bag.detail ? ` · <span class="xp-mono">${esc(bag.detail)}</span>` : ''}</div>
            <div class="xp-foot"><button class="xp-btn" id="lbx-cancel">${esc(t('cancel', null, 'Cancel'))}</button></div>
        </div>`;
        const meter = body.querySelector('#lbx-meter');
        const status = body.querySelector('#lbx-status');
        let done = false;
        const finish = async () => {
            if (done) return;
            done = true;
            status.textContent = t('lab_bench_running', null, 'Running it through the database');
            status.classList.add('run');
            const left = Math.max(1200, seconds * 1000 - (Date.now() - begun));
            meter.style.transition = `width ${left}ms linear`;
            meter.classList.add('run');
            requestAnimationFrame(() => { meter.style.width = '100%'; });
            const res = await run('lab:analyse', { place: data.place, point: data.point, key });
            if (res && res.ok) {
                data.reports = res.data.reports;
                labReport(res.data);
            } else {
                lab();
            }
        };
        body.querySelector('#lbx-cancel').addEventListener('click', () => { done = true; lab(); });
        const input = body.querySelector('#lbx-in');
        if (input) {
            let held = null;
            const apply = () => {
                const v = Number(input.value);
                const close = Math.max(0, 100 - Math.abs(v) * (bench === 'overlay' ? 1.4 : 1.6));
                if (!done) meter.style.width = `${close}%`;
                if (bench === 'microscope') body.querySelector('#lbx-shift').setAttribute('transform', `translate(0 ${v})`);
                else {
                    body.querySelector('#lbx-rot').setAttribute('transform', `rotate(${v} 250 115)`);
                    body.querySelector('#lbx-dots').setAttribute('opacity', String(0.2 + close / 125));
                }
                const tol = bench === 'overlay' ? 4 : 2;
                if (Math.abs(v) <= tol && !done) {
                    status.textContent = t(bench === 'overlay' ? 'lab_bench_print_lock' : 'lab_bench_scope_lock', null, 'That lines up. Hold it there.');
                    if (!held) held = setTimeout(() => { if (Math.abs(Number(input.value)) <= tol) { input.disabled = true; finish(); } held = null; }, 900);
                } else if (held) {
                    clearTimeout(held);
                    held = null;
                }
            };
            input.addEventListener('input', apply);
            apply();
        } else {
            const hold = body.querySelector('#lbx-hold');
            const needle = body.querySelector('#lbx-needle');
            let level = 0;
            let timer = null;
            const set = () => { needle.style.left = `${level}%`; meter.style.width = `${level}%`; };
            const press = () => {
                if (done || timer) return;
                timer = setInterval(() => { level = Math.min(100, level + 1.6); set(); }, 30);
            };
            const release = () => {
                if (!timer) return;
                clearInterval(timer);
                timer = null;
                if (level >= 62 && level <= 82) {
                    hold.disabled = true;
                    status.textContent = t('lab_bench_dna_ok', null, 'Good spin. The bands are coming through.');
                    body.querySelectorAll('#lbx-gel i').forEach((band, i) => setTimeout(() => { band.style.opacity = '1'; }, 120 * i));
                    setTimeout(finish, 900);
                } else {
                    status.textContent = t(level < 62 ? 'lab_bench_dna_slow' : 'lab_bench_dna_fast', null, 'Not quite. Try again.');
                    level = 0;
                    setTimeout(set, 250);
                }
            };
            hold.addEventListener('mousedown', press);
            hold.addEventListener('mouseup', release);
            hold.addEventListener('mouseleave', release);
        }
    }

    function labReport(res) {
        const r = res.report || {};
        const body = root.querySelector('.xp-body');
        body.innerHTML = `<div class="lbr">
            <div class="lbr-head ${r.match ? 'hit' : ''}">${XS.icon(r.match ? 'check' : 'info', 22)}<div><span>${esc(t('lab_report', null, 'Lab report'))} · ${esc(r.label || '')}</span><b>${esc(res.result || '')}</b></div></div>
            <div class="lbr-lines">${XS.list(r.lines).map((l) => `<div><span>${esc(l.label)}</span><b class="xp-mono">${esc(l.value)}</b></div>`).join('')}</div>
            <div class="xp-label" style="margin-top:16px">${esc(t('lab_seen_before', null, 'Seen before'))}</div>
            ${XS.list(r.links).length ? `<div class="lbr-links">${XS.list(r.links).map((l) => `<div>${XS.icon('pin', 14)}<span>${esc(l.subject)}</span><em>${esc(XS.date(l.at))}</em></div>`).join('')}</div>`
                : `<div class="xp-note">${esc(t('lab_first_time', null, 'This is the first time it has come up.'))}</div>`}
            <div class="xp-foot"><button class="xp-btn primary" id="lbr-back">${esc(t('lab_back', null, 'Back to the bench'))}</button></div>
        </div>`;
        body.querySelector('#lbr-back').addEventListener('click', () => lab());
    }

    function lab() {
        const bags = XS.list(data.bags);
        const reports = XS.list(data.reports);
        const typeLabel = (k) => t('lab_type_' + k, null, k);
        const bagRows = bags.map((b) => `<div class="xp-row lb-bag" data-key="${esc(b.key)}">
                <span class="xp-chip lb-type lb-${esc(b.type)}">${esc(typeLabel(b.type))}</span>
                <div class="xp-row-main"><b>${esc(b.label)}</b><span>${esc([b.street, b.collected].filter(Boolean).join(' · '))}</span>${b.detail ? `<span class="xp-mono">${esc(b.detail)}</span>` : ''}</div>
                <button class="xp-btn small primary" data-analyse>${esc(t('lab_analyse', null, 'Analyse'))}</button>
            </div>`).join('') || `<div class="xp-empty">${esc(t('lab_no_bags', null, 'You are not carrying any evidence bags.'))}</div>`;
        const reportRows = reports.map((r) => `<div class="lb-rep">
                <b>${esc(r.result)}</b>
                <span>${esc(r.subject)}</span>
                <em>${esc(r.officer)} · ${esc(XS.time(r.at))}</em>
            </div>`).join('') || `<div class="xp-empty">${esc(t('lab_no_reports', null, 'No reports yet.'))}</div>`;
        const body = `<div class="lb-cols">
                <div><div class="xp-label">${esc(t('lab_bags', null, 'Your evidence bags'))}</div><div class="xp-list">${bagRows}</div></div>
                <div><div class="xp-label">${esc(t('lab_reports', null, 'Reports'))}</div><div class="lb-reps">${reportRows}</div></div>
            </div>`;
        const stage = shell(t('lab_title', null, 'Forensic lab'), data.station || '', body, true);
        stage.querySelectorAll('.lb-bag').forEach((row) => {
            const btn = row.querySelector('[data-analyse]');
            btn.addEventListener('click', async () => {
                const res = await run('lab:start', { place: data.place, point: data.point, key: row.dataset.key }, btn);
                if (res && res.ok) labBench(row, res.data);
            });
        });
    }

    function serviceForm() {
        const quick = [5, 10, 15, 20, 30].filter((n) => n <= (Number(data.max) || 50));
        const body = `<div class="xp-subject">${XS.icon('person', 18)}<span>${esc(t('form_subject', { id: data.target }, `Person · ID ${data.target}`))}</span></div>
            <label class="xp-label">${esc(t('form_tasks', null, 'Tasks'))}</label>
            <div class="xp-inline"><input class="xp-input xp-mono" id="sv-tasks" value="10" inputmode="numeric" style="width:110px">${quick.map((n) => `<button class="xp-btn small" data-q="${n}">${n}</button>`).join('')}</div>
            <label class="xp-label" style="margin-top:14px">${esc(t('form_charges', null, 'Charges'))}</label>
            <textarea class="xp-input" id="sv-reason" rows="3" maxlength="120" placeholder="${esc(t('form_service_hint', null, ''))}"></textarea>
            <div class="xp-foot"><button class="xp-btn" data-close2>${esc(t('cancel', null, 'Cancel'))}</button><button class="xp-btn primary" id="sv-go">${esc(t('form_service_go', null, 'Send to community service'))}</button></div>`;
        const stage = shell(t('form_service_title', null, 'Community service'), '', body);
        stage.querySelector('[data-close2]').addEventListener('click', () => XS.close(app));
        stage.querySelectorAll('[data-q]').forEach((b) => b.addEventListener('click', () => { stage.querySelector('#sv-tasks').value = b.dataset.q; }));
        const go = stage.querySelector('#sv-go');
        go.addEventListener('click', async () => {
            const reason = stage.querySelector('#sv-reason').value.trim();
            if (!reason) return XS.toast(t('err_need_reason', null, 'Add a reason.'), 'error');
            const res = await run('form:submit', { kind: 'service', target: data.target, tasks: Math.floor(Number(stage.querySelector('#sv-tasks').value) || 0), reason }, go);
            if (res && res.ok) XS.toast(res.data, 'ok');
        });
    }

    function form() {
        if (data.kind === 'flag') return flagForm();
        if (data.kind === 'service') return serviceForm();
        const jail = data.kind === 'jail';
        const quick = [5, 10, 20, 30, 60].filter((m) => m <= (Number(data.max) || 300));
        const mpm = Number(data.minutesPerMonth) || 1;
        const body = jail ? `
            <div class="xp-subject">${XS.icon('person', 18)}<span>${esc(t('form_subject', { id: data.target }, `Person · ID ${data.target}`))}</span></div>
            <label class="xp-label">${esc(t('form_months', null, 'Sentence (months)'))}</label>
            <div class="xp-inline"><input class="xp-input xp-mono" id="fm-months" value="10" inputmode="numeric" style="width:110px">
                ${quick.map((m) => `<button class="xp-btn small" data-q="${m}">${m}</button>`).join('')}</div>
            <div class="xp-note" id="fm-time"></div>
            <label class="xp-label" style="margin-top:14px">${esc(t('form_charges', null, 'Charges'))}</label>
            <textarea class="xp-input" id="fm-reason" rows="3" maxlength="200" placeholder="${esc(t('form_charges_hint', null, 'Armed robbery, evading'))}"></textarea>
            <div class="xp-foot"><button class="xp-btn" data-close2>${esc(t('cancel', null, 'Cancel'))}</button><button class="xp-btn primary" id="fm-go">${esc(t('form_jail_go', null, 'Send to jail'))}</button></div>`
            : `
            <div class="xp-subject">${XS.icon('person', 18)}<span>${esc(t('form_subject', { id: data.target }, `Person · ID ${data.target}`))}</span></div>
            <label class="xp-label">${esc(t('form_amount', null, 'Amount'))}</label>
            <input class="xp-input xp-mono" id="fm-amount" inputmode="numeric" placeholder="${esc(t('form_amount_hint', { max: XS.money(data.max) }, `Up to ${XS.money(data.max)}`))}">
            <label class="xp-label" style="margin-top:14px">${esc(t('form_reason', null, 'Reason'))}</label>
            <textarea class="xp-input" id="fm-reason" rows="3" maxlength="120" placeholder="${esc(t('form_reason_hint', null, 'Speeding, 40 over'))}"></textarea>
            <div class="xp-foot"><button class="xp-btn" data-close2>${esc(t('cancel', null, 'Cancel'))}</button><button class="xp-btn primary" id="fm-go">${esc(t('form_fine_go', null, 'Issue fine'))}</button></div>`;
        const stage = shell(t(jail ? 'form_jail_title' : 'form_fine_title', null, jail ? 'Booking' : 'Citation'), t(jail ? 'form_jail_sub' : 'form_fine_sub', null, ''), body);
        stage.querySelector('[data-close2]').addEventListener('click', () => XS.close(app));
        if (jail) {
            const months = stage.querySelector('#fm-months');
            const time = stage.querySelector('#fm-time');
            const show = () => {
                const m = Math.floor(Number(months.value) || 0);
                time.textContent = m > 0 ? t('form_time', { minutes: m * mpm }, `${m * mpm} minutes in jail, counted while they are online`) : '';
            };
            months.addEventListener('input', show);
            stage.querySelectorAll('[data-q]').forEach((b) => b.addEventListener('click', () => { months.value = b.dataset.q; show(); }));
            show();
        }
        const go = stage.querySelector('#fm-go');
        go.addEventListener('click', async () => {
            const reason = stage.querySelector('#fm-reason').value.trim();
            const payload = { kind: data.kind, target: data.target, reason };
            if (jail) payload.months = Math.floor(Number(stage.querySelector('#fm-months').value) || 0);
            else payload.amount = Math.floor(Number(stage.querySelector('#fm-amount').value) || 0);
            if (!reason) return XS.toast(t(jail ? 'err_need_charges' : 'err_need_reason', null, 'Add a reason.'), 'error');
            const res = await run('form:submit', payload, go);
            if (res && res.ok) XS.toast(res.data, 'ok');
        });
        const first = stage.querySelector(jail ? '#fm-months' : '#fm-amount');
        if (first) setTimeout(() => first.focus(), 30);
    }

    let canteenTimer = null;

    function canteen() {
        const meals = XS.list(data.meals);
        const opened = data.openedAt || (data.openedAt = Date.now());
        const waitLeft = () => Math.max(0, (Number(data.wait) || 0) - Math.floor((Date.now() - opened) / 1000));
        const cards = meals.map((m) => `<div class="cn-meal" data-meal="${esc(m.id)}">
                <div class="cn-tray">${XS.list(m.items).map((e) => `<div class="cn-item">${photo(e.image, 'box', 24)}<span>${esc(e.label || e.item)}${e.amount > 1 ? ` <em class="xp-mono">×${e.amount}</em>` : ''}</span></div>`).join('')}</div>
                <div class="cn-foot"><b>${esc(m.label)}</b><button class="xp-btn primary small" data-take>${esc(t('canteen_take_meal', null, 'Take this'))}</button></div>
            </div>`).join('') || `<div class="xp-empty">${esc(t('canteen_empty', null, 'Nothing is being served here.'))}</div>`;
        const body = `<div class="cn-wait" id="cn-wait"></div><div class="cn-grid">${cards}</div>`;
        const stage = shell(t('canteen_title', null, 'Canteen'), data.jail || '', body, meals.length > 2);
        photos(stage);
        const waitEl = stage.querySelector('#cn-wait');
        const update = () => {
            const left = waitLeft();
            waitEl.textContent = left > 0 ? t('canteen_next', { time: XS.span(left) }, `Your next meal is in ${XS.span(left)}.`) : '';
            waitEl.classList.toggle('on', left > 0);
            stage.querySelectorAll('[data-take]').forEach((b) => { b.disabled = left > 0; });
        };
        update();
        if (canteenTimer) clearInterval(canteenTimer);
        canteenTimer = setInterval(() => {
            if (app !== 'canteen') { clearInterval(canteenTimer); canteenTimer = null; return; }
            update();
        }, 1000);
        stage.querySelectorAll('.cn-meal').forEach((card) => {
            card.querySelector('[data-take]').addEventListener('click', async (e) => {
                const res = await run('canteen:take', { point: data.point, meal: card.dataset.meal }, e.currentTarget);
                if (res && res.ok) XS.toast(res.data, 'ok');
            });
        });
    }

    function prisonshop() {
        const mode = data.mode;
        const qtyOf = {};
        const stepper = (key, max) => `<div class="xp-qty"><button data-dq="${key}" data-d="-1">−</button><input data-q="${key}" value="${qtyOf[key] || 1}" readonly><button data-dq="${key}" data-d="1" data-max="${max || 10}">+</button></div>`;
        const card = (e, key, price, action, extra) => `<div class="ps-card" data-key="${key}">
                ${photo(e.image, 'box', 26)}
                <div class="ps-name"><b>${esc(e.label || e.item)}${e.amount > 1 ? ` <em class="xp-mono">×${e.amount}</em>` : ''}</b>${extra || ''}</div>
                <div class="ps-buy"><span class="ps-price">${price}</span>${stepper(key, 10)}${action}</div>
            </div>`;
        let body = '';
        let title = '';
        if (mode === 'commissary') {
            title = t('commissary_title', null, 'Commissary');
            const items = XS.list(data.items);
            body = `<div class="ps-wallet">${XS.icon('cash', 18)}<span>${esc(t('commissary_credit', null, 'Your credit'))}</span><b class="xp-mono" id="ps-wallet">${Number(data.credit) || 0}</b><em>${esc(t('commissary_credit_hint', null, 'Earned on prison jobs'))}</em></div>
                <div class="ps-grid">${items.map((e) => (e.call
                    ? `<div class="ps-card ps-call"><div class="xp-photo ps-phone">${XS.icon('panic', 30)}</div><div class="ps-name"><b>${esc(e.label)}</b><span>${esc(t('commissary_call_hint', null, 'Send a message to someone in the city.'))}</span></div>
                        <div class="ps-buy"><span class="ps-price">${esc(t('commissary_price', { price: e.price }, '%{price} credit'))}</span><button class="xp-btn small primary" data-call="${e.id}">${esc(t('commissary_call_btn', null, 'Make a call'))}</button></div></div>`
                    : card(e, e.id, esc(t('commissary_price', { price: e.price }, '%{price} credit')), `<button class="xp-btn small primary" data-buy="${e.id}">${esc(t('commissary_buy', null, 'Buy'))}</button>`))).join('') || `<div class="xp-empty">${esc(t('commissary_empty', null, 'Nothing for sale.'))}</div>`}</div>
                <div class="ps-callbox" id="ps-callbox" hidden></div>`;
        } else if (mode === 'trader') {
            title = t('trader_title', null, 'Inmate trader');
            const cur = esc(data.currencyLabel || data.currency);
            body = `<div class="ps-wallet">${data.currencyImage ? `<img src="${esc(data.currencyImage)}" alt="" onerror="this.remove()">` : XS.icon('box', 18)}<span>${cur}</span><b class="xp-mono" id="ps-wallet">${Number(data.wallet) || 0}</b><em>${esc(t('trader_hint', null, 'Keep it quiet. Guards take anything they find.'))}</em></div>
                <div class="ps-sub">${esc(t('trader_sells', null, 'He has'))}</div>
                <div class="ps-grid">${XS.list(data.sells).map((e) => card(e, `s${e.id}`, `${e.price} <small>${cur}</small>`, `<button class="xp-btn small primary" data-deal="buy" data-id="${e.id}" data-k="s${e.id}">${esc(t('trader_get', null, 'Get'))}</button>`)).join('') || `<div class="xp-empty">${esc(t('trader_nothing', null, 'Nothing today.'))}</div>`}</div>
                <div class="ps-sub">${esc(t('trader_buys', null, 'He wants'))}</div>
                <div class="ps-grid">${XS.list(data.buys).map((e) => card(e, `b${e.id}`, `${e.price} <small>${cur}</small>`, `<button class="xp-btn small" data-deal="sell" data-id="${e.id}" data-k="b${e.id}" ${Number(e.have) > 0 ? '' : 'disabled'}>${esc(t('trader_give', null, 'Give'))}</button>`, `<span>${esc(t('trader_have', { n: Number(e.have) || 0 }, 'You have %{n}'))}</span>`)).join('') || `<div class="xp-empty">${esc(t('trader_nothing', null, 'Nothing today.'))}</div>`}</div>`;
        } else {
            title = t('workbench_title', null, 'Workbench');
            body = `<div class="ps-note">${XS.icon('alert', 15)}${esc(t('workbench_hint', null, 'Make it quick. If a guard finds what you made, it goes and so does more of your time.'))}</div>
                <div class="ps-recipes">${XS.list(data.recipes).map((r) => {
                    const ready = XS.list(r.needs).every((n) => Number(n.have) >= Number(n.need));
                    return `<div class="ps-recipe ${ready ? 'ready' : ''}">${photo(r.image, 'gear', 30)}
                        <div class="ps-name"><b>${esc(r.label)}</b><span>${esc(t('workbench_time', { n: r.seconds }, '%{n} seconds'))}</span>
                            <div class="ps-needs">${XS.list(r.needs).map((n) => `<span class="${Number(n.have) >= Number(n.need) ? 'ok' : 'no'}">${esc(n.label)} <b class="xp-mono">${Number(n.have)}/${Number(n.need)}</b></span>`).join('')}</div></div>
                        <button class="xp-btn small ${ready ? 'primary' : ''}" data-craft="${r.id}" ${ready ? '' : 'disabled'}>${esc(t('workbench_make', null, 'Make it'))}</button></div>`;
                }).join('') || `<div class="xp-empty">${esc(t('workbench_empty', null, 'Nothing you can make here.'))}</div>`}</div>`;
        }
        const stage = shell(title, data.jail || '', body, true);
        photos(stage);
        const wallet = (v) => { const el = stage.querySelector('#ps-wallet'); if (el) el.textContent = v; };
        stage.querySelectorAll('[data-dq]').forEach((b) => b.addEventListener('click', () => {
            const key = b.dataset.dq;
            qtyOf[key] = Math.max(1, Math.min(Number(b.dataset.max) || 10, (qtyOf[key] || 1) + Number(b.dataset.d)));
            stage.querySelector(`[data-q="${key}"]`).value = qtyOf[key];
        }));
        stage.querySelectorAll('[data-buy]').forEach((b) => b.addEventListener('click', async () => {
            const res = await run('prisonshop:buy', { point: data.point, id: Number(b.dataset.buy), qty: qtyOf[b.dataset.buy] || 1 }, b);
            if (res && res.ok) { data.credit = res.data.credit; wallet(res.data.credit); XS.toast(res.data.message, 'ok'); }
        }));
        stage.querySelectorAll('[data-deal]').forEach((b) => b.addEventListener('click', async () => {
            const res = await run('prisonshop:deal', { point: data.point, side: b.dataset.deal, id: Number(b.dataset.id), qty: qtyOf[b.dataset.k] || 1 }, b);
            if (res && res.ok) {
                data.wallet = res.data.wallet;
                wallet(res.data.wallet);
                XS.toast(res.data.message, 'ok');
                if (b.dataset.deal === 'sell') {
                    const e = XS.list(data.buys).find((x) => String(x.id) === b.dataset.id);
                    if (e) e.have = Math.max(0, (Number(e.have) || 0) - (qtyOf[b.dataset.k] || 1));
                    prisonshop();
                }
            }
        }));
        stage.querySelectorAll('[data-craft]').forEach((b) => b.addEventListener('click', () => run('prisonshop:craft', { point: data.point, id: Number(b.dataset.craft) }, b)));
        stage.querySelectorAll('[data-call]').forEach((b) => b.addEventListener('click', () => {
            const box = stage.querySelector('#ps-callbox');
            let picked = null;
            box.hidden = false;
            box.innerHTML = `<div class="xp-label">${esc(t('commissary_call_who', null, 'Who are you calling?'))}</div>
                <input class="xp-input" id="ps-who" maxlength="40" placeholder="${esc(t('commissary_call_search', null, 'Type at least 3 letters of their name'))}">
                <div class="ps-people" id="ps-people"></div>
                <div class="xp-label" style="margin-top:12px">${esc(t('commissary_call_msg', null, 'What do you say?'))}</div>
                <textarea class="xp-input" id="ps-msg" rows="3" maxlength="160"></textarea>
                <div class="xp-foot"><button class="xp-btn" id="ps-cancel">${esc(t('cancel', null, 'Cancel'))}</button><button class="xp-btn primary" id="ps-send" disabled>${esc(t('commissary_call_send', null, 'Call'))}</button></div>`;
            const who = box.querySelector('#ps-who');
            const people = box.querySelector('#ps-people');
            const send = box.querySelector('#ps-send');
            let timer = null;
            who.focus();
            who.addEventListener('input', () => {
                clearTimeout(timer);
                picked = null;
                send.disabled = true;
                timer = setTimeout(async () => {
                    const res = await XS.rpc('prisonshop:people', { point: data.point, query: who.value });
                    const list = res.ok ? XS.list(res.data) : [];
                    people.innerHTML = list.map((p) => `<button class="ps-person" data-src="${p.src}">${XS.icon('user', 14)}${esc(p.name)}</button>`).join('') || (who.value.trim().length >= 3 ? `<span class="xp-note">${esc(t('commissary_call_noone', null, 'Nobody by that name is around.'))}</span>` : '');
                    people.querySelectorAll('[data-src]').forEach((pb) => pb.addEventListener('click', () => {
                        picked = Number(pb.dataset.src);
                        people.querySelectorAll('.ps-person').forEach((x) => x.classList.toggle('on', x === pb));
                        send.disabled = false;
                    }));
                }, 250);
            });
            box.querySelector('#ps-cancel').addEventListener('click', () => { box.hidden = true; box.innerHTML = ''; });
            send.addEventListener('click', async () => {
                const res = await run('prisonshop:call', { point: data.point, id: Number(b.dataset.call), target: picked, message: box.querySelector('#ps-msg').value }, send);
                if (res && res.ok) { data.credit = res.data.credit; wallet(res.data.credit); XS.toast(res.data.message, 'ok'); box.hidden = true; box.innerHTML = ''; }
            });
        }));
    }

    const RENDER = { armory, garage, form, evidence, impound, impoundlot, canteen, prisonshop, cameras, licences, lab };

    function register(name) {
        XS.apps[name] = {
            isOpen: () => app === name,
            escape: () => XS.close(name),
            on(action, payload) {
                if (action === 'open') {
                    app = name;
                    data = payload || {};
                    XS.show('xsp-panel', true);
                    RENDER[name]();
                } else if (action === 'close' && app === name) {
                    app = null;
                    XS.show('xsp-panel', false);
                }
            },
        };
    }

    Object.keys(RENDER).forEach(register);
})();

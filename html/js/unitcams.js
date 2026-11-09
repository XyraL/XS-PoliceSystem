(() => {
    const t = XS.t;
    const esc = XS.esc;
    const I = (name, size) => XS.icon(name, size || 16);
    const pad = (n) => String(n).padStart(2, '0');
    const KIND_ICON = { foot: 'person', driving: 'car', riding: 'seat' };
    const COMPASS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

    function stamp(withZone) {
        const d = new Date();
        const base = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
        if (!withZone) return base;
        const off = -d.getTimezoneOffset();
        const abs = Math.abs(off);
        return `${base} ${off >= 0 ? '+' : '-'}${pad(Math.floor(abs / 60))}${pad(abs % 60)}`;
    }

    function initials(name) {
        return String(name || '').split(/\s+/).filter(Boolean).map((w) => w[0]).join('').slice(0, 3).toUpperCase() || '—';
    }

    function where(u) {
        const road = [u.street, u.cross].filter(Boolean).join(' / ');
        return { road: road || t('uc_unknown_road', null, 'Unknown road'), zone: u.zone || '' };
    }

    const root = document.getElementById('xsp-unitcams');
    let open = false;
    let data = {};
    let units = [];
    let query = '';
    let filter = 'all';
    let clock = null;

    function counts() {
        return {
            all: units.length,
            foot: units.filter((u) => u.k === 'foot').length,
            car: units.filter((u) => u.k !== 'foot').length,
            dash: units.filter((u) => u.dash).length,
        };
    }

    function matches(u) {
        if (filter === 'foot' && u.k !== 'foot') return false;
        if (filter === 'car' && u.k === 'foot') return false;
        if (filter === 'dash' && !u.dash) return false;
        if (!query) return true;
        return [u.name, u.callsign, u.rank, u.street, u.cross, u.zone].join(' ').toLowerCase().includes(query);
    }

    function tile(u) {
        const m = data.modes || {};
        const at = where(u);
        const ch = units.indexOf(u) + 1;
        const button = (mode, icon, label, ok) => `<button class="uc-btn ${mode === 'body' ? 'primary' : ''}" data-src="${u.src}" data-mode="${mode}" ${ok ? '' : 'disabled'}>${I(icon, 14)}<span>${esc(label)}</span></button>`;
        const acts = [
            m.body ? button('body', 'bodycam', t('uc_body', null, 'Body cam'), true) : '',
            m.dash ? button('dash', 'dashcam', t('uc_dash', null, 'Dash cam'), !!u.dash) : '',
            m.cabin ? button('cabin', 'seat', t('uc_cabin', null, 'Back seat'), !!u.dash) : '',
        ].join('');
        return `<div class="uc-mon k-${esc(u.k)}${u.me ? ' me' : ''}">
            <div class="uc-screen">
                <div class="uc-noise"></div><div class="uc-scan"></div>
                <div class="uc-live"><i></i>${esc(t('uc_live', null, 'LIVE'))}</div>
                <div class="uc-ch">CH ${pad(ch)}</div>
                <div class="uc-call">${esc(u.callsign || initials(u.name))}</div>
                <div class="uc-where"><b>${esc(at.road)}</b>${at.zone ? `<span>${esc(at.zone)}</span>` : ''}</div>
                <div class="uc-state">${I(KIND_ICON[u.k] || 'person', 12)}${esc(t(`uc_k_${u.k}`, null, u.k))}</div>
            </div>
            <div class="uc-info">
                <div class="uc-who"><b>${u.me ? `<em class="uc-you">${esc(t('uc_you', null, 'You'))}</em>` : ''}${esc(u.name)}</b><span>${esc([u.rank, u.dept].filter(Boolean).join(' · '))}</span></div>
                ${u.dash ? `<span class="uc-plate ${u.dash.any ? 'any' : ''}" title="${esc(u.dash.any ? t('uc_plate_any', null, 'The car they are driving') : t('uc_plate_station', null, 'Their station car'))}">${esc(u.dash.plate || '')}</span>` : `<span class="uc-nocar">${esc(t('uc_no_dash', null, 'No dash cam'))}</span>`}
            </div>
            <div class="uc-acts">${acts}</div>
        </div>`;
    }

    function renderWall() {
        const wall = root.querySelector('#uc-wall');
        if (!wall) return;
        const shown = units.filter(matches);
        if (shown.length) wall.innerHTML = shown.map(tile).join('');
        else wall.innerHTML = `<div class="uc-empty">${I('camera', 34)}<b>${esc(units.length ? t('uc_none_match', null, 'No units match.') : t('uc_none', null, 'Nobody else is on duty.'))}</b><span>${esc(units.length ? t('uc_none_match_sub', null, 'Try another name, callsign or street.') : t('uc_none_sub', null, 'Officers show up here as soon as they clock on.'))}</span></div>`;
        wall.querySelectorAll('[data-mode]').forEach((b) => b.addEventListener('click', async () => {
            if (b.disabled) return;
            wall.querySelectorAll('[data-mode]').forEach((x) => { x.disabled = true; });
            const res = await XS.rpc('unitcams:watch', { src: Number(b.dataset.src), mode: b.dataset.mode });
            if (!res.ok) { XS.toast(res.error, 'error'); renderWall(); }
        }));
        const c = counts();
        const set = (sel, v) => { const el = root.querySelector(sel); if (el) el.textContent = String(v); };
        set('#uc-n-all', c.all);
        set('#uc-n-dash', c.dash);
        set('#uc-n-car', c.car);
        Object.keys(c).forEach((k) => set(`[data-filter="${k}"] em`, c[k]));
    }

    function render() {
        const stage = XS.stage(root);
        const remote = !!data.remote;
        const chips = [['all', t('uc_f_all', null, 'All')], ['foot', t('uc_f_foot', null, 'On foot')], ['car', t('uc_f_car', null, 'In a car')], ['dash', t('uc_f_dash', null, 'Dash cam')]]
            .map(([k, label]) => `<button class="uc-chip ${filter === k ? 'on' : ''}" data-filter="${k}">${esc(label)}<em>0</em></button>`).join('');
        stage.innerHTML = `<div class="uc">
            <div class="bx-lightbar"></div>
            <div class="uc-top">
                <span class="uc-seal">${I('camera', 24)}</span>
                <div class="uc-title"><span>${esc(remote ? t('uc_kicker_remote', null, 'XS-PoliceSystem · Supervisor access') : t('uc_kicker', null, 'XS-PoliceSystem · Camera room'))}</span>
                    <h1>${esc(data.station || t('uc_title', null, 'Unit cameras'))}</h1>
                    <small>${esc(t('uc_sub', null, 'Live body cams and dash cams of every officer on duty'))}</small></div>
                <span class="uc-sp"></span>
                <div class="uc-kpi"><span>${esc(t('uc_kpi_units', null, 'Units'))}</span><b id="uc-n-all">0</b></div>
                <div class="uc-kpi"><span>${esc(t('uc_kpi_dash', null, 'Dash cams'))}</span><b id="uc-n-dash">0</b></div>
                <div class="uc-kpi"><span>${esc(t('uc_kpi_car', null, 'In a car'))}</span><b id="uc-n-car">0</b></div>
                <div class="uc-clock"><i></i><b id="uc-clock">${esc(stamp(false).slice(11))}</b></div>
                <button class="uc-x" data-close title="${esc(t('close', null, 'Close'))}">${I('close', 18)}</button>
            </div>
            <div class="uc-bar">
                <label class="uc-search">${I('search', 15)}<input id="uc-q" value="${esc(query)}" maxlength="40" placeholder="${esc(t('uc_search', null, 'Search a name, callsign or street'))}"></label>
                <div class="uc-chips">${chips}</div>
            </div>
            <div class="uc-wall xsp-scroll" id="uc-wall"></div>
            <div class="uc-foot">
                <span><i class="bx-kbd">Esc</i>${esc(t('uc_close', null, 'to close'))}</span>
                <span class="uc-dotsep"></span>
                <span>${esc(t('uc_foot_live', null, 'The list updates every few seconds'))}</span>
                <span class="uc-sp"></span>
                <span class="uc-keys"><i class="bx-kbd">A</i><i class="bx-kbd">D</i>${esc(t('uc_key_unit', null, 'officer'))}<i class="bx-kbd">1</i><i class="bx-kbd">2</i><i class="bx-kbd">3</i>${esc(t('uc_key_cam', null, 'camera'))}<i class="bx-kbd">M</i>${esc(t('uc_key_audio', null, 'audio'))}</span>
            </div>
        </div>`;
        stage.querySelector('[data-close]').addEventListener('click', () => XS.close('unitcams'));
        const input = stage.querySelector('#uc-q');
        input.addEventListener('input', () => { query = input.value.trim().toLowerCase(); renderWall(); });
        stage.querySelectorAll('[data-filter]').forEach((b) => b.addEventListener('click', () => {
            filter = b.dataset.filter;
            stage.querySelectorAll('[data-filter]').forEach((x) => x.classList.toggle('on', x === b));
            renderWall();
        }));
        renderWall();
        clearInterval(clock);
        clock = setInterval(() => { const el = document.getElementById('uc-clock'); if (el) el.textContent = stamp(false).slice(11); }, 1000);
        setTimeout(() => input.focus(), 30);
    }

    XS.apps.unitcams = {
        isOpen: () => open,
        escape: () => XS.close('unitcams'),
        on(action, payload) {
            if (action === 'open') {
                data = payload || {};
                units = XS.list(data.units);
                open = true;
                XS.show('xsp-unitcams', true);
                render();
            } else if (action === 'units') {
                units = XS.list(payload && payload.units);
                if (open) renderWall();
            } else if (action === 'close') {
                open = false;
                clearInterval(clock);
                XS.show('xsp-unitcams', false);
                root.innerHTML = '';
            }
        },
    };

    const feedRoot = document.getElementById('xsp-unitfeed');
    let feed = null;
    let feedClock = null;

    function keys(d) {
        const k = (key, label) => `<span><i class="xp-kbd">${esc(key)}</i>${esc(label)}</span>`;
        const m = d.modes || {};
        const out = [];
        if (d.many) out.push(k('A / D', t('uc_key_unit', null, 'officer')));
        if (m.body) out.push(k('1', t('uc_body', null, 'Body cam')));
        if (m.dash) out.push(k('2', t('uc_dash', null, 'Dash cam')));
        if (m.cabin) out.push(k('3', t('uc_cabin', null, 'Back seat')));
        out.push(k('M', t('uc_key_audio', null, 'audio')));
        out.push(k('Backspace', d.back ? t('uc_key_back', null, 'back') : t('uc_key_exit', null, 'exit')));
        return out.join('');
    }

    function audioTag(on) {
        return `${I('mic', 13)}<b>${esc(on ? t('uf_audio', null, 'AUDIO') : t('uf_audio_off', null, 'NO AUDIO'))}</b><span class="uf-meter"><i></i><i></i><i></i><i></i><i></i></span>`;
    }

    function frame(d) {
        const camName = d.mode === 'dash' ? t('uf_cam_dash', null, 'FRONT') : d.mode === 'cabin' ? t('uf_cam_cabin', null, 'REAR CABIN') : t('uf_cam_body', null, 'BODY CAM');
        const unit = d.callsign || initials(d.name);
        const common = `<div class="uf-noise"></div><div class="uf-vig"></div><div class="uf-static"></div>
            <div class="uf-live"><i></i>${esc(t('uc_live', null, 'LIVE'))}<em>${esc(camName)}</em><span class="uf-sig"><i></i><i></i><i></i><i></i></span></div>
            <div class="uf-audio ${d.audio ? '' : 'off'}" id="uf-audio">${audioTag(d.audio)}</div>
            <div class="uf-keys">${keys(d)}</div>
            <div class="uf-lost"><b>${esc(t('cam_no_signal', null, 'NO SIGNAL'))}</b><span>${esc(t('uf_reconnecting', null, 'Reconnecting'))}</span></div>`;
        if (d.mode === 'body') {
            return `<div class="uf uf-body">${common}
                <div class="uf-burn"><b id="uf-time">${esc(stamp(true))}</b><span>XS-POLICESYSTEM BWC · ${esc(unit)}</span></div>
                <div class="uf-unit"><b>${esc(unit)} · ${esc(d.name)}</b><span>${esc([d.rank, d.dept].filter(Boolean).join(' · '))}</span><span class="uf-where" id="uf-where"></span></div>
            </div>`;
        }
        return `<div class="uf uf-dash ${d.mode === 'cabin' ? 'uf-cabin' : ''}">${common}
            <div class="uf-bar top"><b id="uf-time">${esc(stamp(false))}</b><span>${esc(t('uf_unit', null, 'UNIT'))} ${esc(unit)}</span><span>${esc(camName)}</span><span class="uf-rec"><i></i>REC</span><b id="uf-speed">0 ${esc(d.unit || 'MPH')}</b></div>
            <div class="uf-bar bot"><span class="uf-where" id="uf-where"></span><span id="uf-hdg">N 000°</span>
                <span class="uf-ind" id="uf-lights">${esc(t('uf_lights', null, 'LIGHTS'))}</span><span class="uf-ind" id="uf-siren">${esc(t('uf_siren', null, 'SIREN'))}</span>
                ${d.mode === 'dash' ? `<span class="uf-ind" id="uf-radar">${esc(t('uf_target', null, 'TGT'))} --</span>` : ''}
                ${d.plate ? `<span class="uf-plate">${esc(d.plate)}</span>` : ''}</div>
        </div>`;
    }

    function setText(id, value) {
        const el = document.getElementById(id);
        if (el) el.textContent = value;
    }

    function tick(d) {
        if (!feed) return;
        const road = [d.street, d.cross].filter(Boolean).join(' / ');
        setText('uf-where', [road, d.zone].filter(Boolean).join(' · ').toUpperCase());
        const hdg = Number(d.heading) || 0;
        setText('uf-hdg', `${COMPASS[Math.round(hdg / 45) % 8]} ${String(hdg).padStart(3, '0')}°`);
        setText('uf-speed', `${Number(d.speed) || 0} ${feed.unit || 'MPH'}`);
        const lights = document.getElementById('uf-lights');
        if (lights) lights.classList.toggle('on', !!d.lights);
        const siren = document.getElementById('uf-siren');
        if (siren) siren.classList.toggle('on', !!d.siren);
        const radar = document.getElementById('uf-radar');
        if (radar) {
            radar.textContent = `${t('uf_target', null, 'TGT')} ${d.radar != null ? d.radar : '--'}`;
            radar.classList.toggle('on', d.radar != null);
        }
        const audio = document.getElementById('uf-audio');
        if (audio) audio.classList.toggle('talk', !!d.talking && feed.audio);
    }

    XS.apps.unitfeed = {
        isOpen: () => false,
        on(action, d) {
            if (action === 'show') {
                feed = d || {};
                feedRoot.innerHTML = frame(feed);
                XS.show('xsp-unitfeed', true);
                clearInterval(feedClock);
                feedClock = setInterval(() => setText('uf-time', stamp(feed && feed.mode === 'body')), 1000);
            } else if (action === 'tick') {
                tick(d || {});
            } else if (action === 'signal') {
                const el = feedRoot.querySelector('.uf');
                if (el) el.classList.toggle('lost', !(d && d.ok));
            } else if (action === 'tune') {
                const el = feedRoot.querySelector('.uf');
                if (el) el.classList.add('tuning');
            } else if (action === 'audio') {
                if (!feed) return;
                feed.audio = !!(d && d.on);
                const el = document.getElementById('uf-audio');
                if (el) { el.classList.toggle('off', !feed.audio); el.classList.remove('talk'); el.innerHTML = audioTag(feed.audio); }
            } else if (action === 'hide') {
                feed = null;
                clearInterval(feedClock);
                XS.show('xsp-unitfeed', false);
                feedRoot.innerHTML = '';
            }
        },
    };
})();

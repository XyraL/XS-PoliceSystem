(() => {
    const t = XS.t;
    const esc = XS.esc;

    const pad = (n) => String(n).padStart(2, '0');
    const stamp = () => {
        const d = new Date();
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    };
    const key = (k, label) => `<span><i class="xp-kbd">${esc(k)}</i>${esc(label)}</span>`;

    const cctvRoot = document.getElementById('xsp-cctv');
    let cctvTimer = null;
    function cctv(d) {
        cctvRoot.innerHTML = `<div class="cc ${d.offline ? 'off' : ''}">
            <div class="cc-noise"></div><div class="cc-vig"></div>
            <i class="cc-c tl"></i><i class="cc-c tr"></i><i class="cc-c bl"></i><i class="cc-c br"></i>
            <div class="cc-tl"><b>CAM ${pad(d.id)}</b><span>${esc(d.label || '')}</span></div>
            <div class="cc-tr"><i class="cc-dot"></i>${esc(t('cam_rec', null, 'REC'))}</div>
            <div class="cc-bl" id="cc-time">${stamp()}</div>
            <div class="cc-br">${key('A / D', t('cam_key_switch', null, 'camera'))}${d.rotate ? key('Mouse', t('cam_key_look', null, 'look')) : ''}${key('Scroll', t('cam_key_zoom', null, 'zoom'))}${key('Backspace', t('cam_key_exit', null, 'exit'))}</div>
            ${d.offline ? `<div class="cc-nosig">${esc(t('cam_no_signal', null, 'NO SIGNAL'))}</div>` : ''}
        </div>`;
        clearInterval(cctvTimer);
        cctvTimer = setInterval(() => { const el = document.getElementById('cc-time'); if (el) el.textContent = stamp(); }, 1000);
    }
    XS.apps.cctv = {
        isOpen: () => false,
        on(action, data) {
            if (action === 'show') { cctv(data || {}); XS.show('xsp-cctv', true); }
            if (action === 'hide') { clearInterval(cctvTimer); XS.show('xsp-cctv', false); cctvRoot.innerHTML = ''; }
        },
    };

    const heliRoot = document.getElementById('xsp-heli');
    function heliFrame() {
        const ticks = Array.from({ length: 37 }, (_, i) => `<i style="left:${i * 10}px"><b>${i % 3 === 0 ? (i * 10 / 10) * 10 : ''}</b></i>`).join('');
        heliRoot.innerHTML = `<div class="hc">
            <div class="hc-tape"><div class="hc-tape-in" id="hc-tape">${ticks}${ticks}</div><em></em></div>
            <div class="hc-left"><b id="hc-vision"></b><span>ZOOM</span><div class="hc-zoom"><i id="hc-zoom"></i></div></div>
            <div class="hc-right"><span>ALT</span><b id="hc-alt">0</b><span>HDG</span><b id="hc-hdg">000</b></div>
            <svg class="hc-ret" viewBox="0 0 200 200"><circle cx="100" cy="100" r="62" class="hc-ring"/><circle cx="100" cy="100" r="62" class="hc-scan" id="hc-scan"/>
                <path d="M100 20v40M100 140v40M20 100h40M140 100h40" class="hc-x"/><circle cx="100" cy="100" r="2.5" class="hc-dot"/></svg>
            <div class="hc-target" id="hc-target"></div>
            <div class="hc-keys">${key('E', t('heli_key_exit', null, 'exit'))}${key('RMB', t('heli_key_vision', null, 'vision'))}${key('Space', t('heli_key_lock', null, 'lock on'))}${key('Scroll', t('heli_key_zoom', null, 'zoom'))}${key('H', t('heli_key_light', null, 'spotlight'))}</div>
        </div>`;
    }
    function heliUpdate(d) {
        const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
        set('hc-vision', d.vision || '');
        set('hc-alt', `${Math.max(0, Number(d.altitude) || 0)}`);
        set('hc-hdg', String(Number(d.heading) || 0).padStart(3, '0'));
        const zoom = document.getElementById('hc-zoom');
        if (zoom) zoom.style.height = `${Math.max(4, Number(d.zoom) || 0)}%`;
        const tape = document.getElementById('hc-tape');
        if (tape) tape.style.transform = `translateX(${-((Number(d.heading) || 0) % 360)}px)`;
        const scan = document.getElementById('hc-scan');
        if (scan) scan.style.strokeDashoffset = `${389.6 * (1 - Math.min(100, Number(d.scan) || 0) / 100)}`;
        heliRoot.querySelector('.hc').classList.toggle('thermal', d.vision === t('heli_vision_thermal', null, 'Thermal'));
        const box = document.getElementById('hc-target');
        if (!box) return;
        const tg = d.target;
        box.classList.toggle('on', !!tg);
        box.classList.toggle('flag', !!(tg && tg.flagged));
        box.innerHTML = tg ? `<div class="hc-t-h">${esc(t('heli_locked', null, 'Locked'))}${tg.flagged ? `<em>${esc(t('radar_flagged', null, 'Flagged'))}</em>` : ''}</div>
            <div class="hc-t-row"><span>VEH</span><b>${esc(tg.model || '')}</b></div>
            <div class="hc-t-row"><span>PLATE</span><b class="hc-plate">${esc(tg.plate || '')}</b></div>
            <div class="hc-t-row"><span>SPD</span><b>${esc(tg.speed)} ${esc(tg.unit || '')}</b></div>
            <div class="hc-t-row"><span>LOC</span><b>${esc(tg.street || '')}</b></div>
            ${tg.flagged ? `<div class="hc-t-flag">${esc(tg.flagged)}</div>` : ''}`
            : (Number(d.scan) > 0 ? `<div class="hc-t-h">${esc(t('heli_scanning', null, 'Scanning'))} ${Math.floor(Number(d.scan))}%</div>` : '');
        if (!tg && Number(d.scan) > 0) box.classList.add('on');
    }
    XS.apps.heli = {
        isOpen: () => false,
        on(action, data) {
            if (action === 'show') { heliFrame(); XS.show('xsp-heli', true); }
            if (action === 'update') heliUpdate(data || {});
            if (action === 'hide') { XS.show('xsp-heli', false); heliRoot.innerHTML = ''; }
        },
    };

    const serviceRoot = document.getElementById('xsp-service');
    XS.apps.service = {
        isOpen: () => false,
        on(action, d) {
            if (action === 'hide') { XS.show('xsp-service', false); serviceRoot.innerHTML = ''; return; }
            if (action !== 'show') return;
            serviceRoot.innerHTML = `<div class="sv">
                <div class="sv-stripes"></div>
                <div class="sv-main"><span>${esc(t('service_hud', null, 'Community service'))}</span><b>${esc(t('service_tasks_left', { tasks: d.left }, `${d.left} tasks left`))}</b>${d.reason ? `<em>${esc(d.reason)}</em>` : ''}</div>
            </div>`;
            XS.show('xsp-service', true);
        },
    };

    XS.apps.mugshot = {
        isOpen: () => false,
        on(action, d) {
            if (action !== 'crop' || !d || !d.image) return;
            const img = new Image();
            img.onload = () => {
                const h = img.height * 0.62;
                const w = h * 0.8;
                const canvas = document.createElement('canvas');
                canvas.width = 240;
                canvas.height = 300;
                canvas.getContext('2d').drawImage(img, (img.width - w) / 2, (img.height - h) / 2 - img.height * 0.04, w, h, 0, 0, 240, 300);
                XS.rpc('mugshot:save', { target: d.target, image: canvas.toDataURL('image/jpeg', 0.82) });
            };
            img.src = d.image;
        },
    };

    const radarRoot = document.getElementById('xsp-radar');
    function digits(v, n) {
        return v === null || v === undefined || v === '' ? '' : String(v).padStart(n, ' ');
    }
    function radarFrame() {
        const win = (id, label) => `<div class="rd-win">
                <div class="rd-lab">${esc(label)}</div>
                <div class="rd-led red"><em>888</em><b id="rd-${id}"></b></div>
            </div>`;
        radarRoot.innerHTML = `<div class="rd">
            <div class="rd-unit">
                <div class="rd-top"><span class="rd-brand">PATROL<b>STAR</b> II</span><span class="rd-lock" id="rd-lock">${esc(t('radar_lock', null, 'Lock'))}</span><span class="rd-unitlabel" id="rd-unit"></span></div>
                <div class="rd-grid">
                    ${win('front', t('radar_front', null, 'Front'))}
                    <div class="rd-win"><div class="rd-lab">${esc(t('radar_fast', null, 'Fast'))}</div><div class="rd-led amber"><em>888</em><b id="rd-fast"></b></div></div>
                    ${win('rear', t('radar_rear', null, 'Rear'))}
                    <div class="rd-win"><div class="rd-lab">${esc(t('radar_patrol', null, 'Patrol'))}</div><div class="rd-led green"><em>888</em><b id="rd-patrol"></b></div></div>
                </div>
                <div class="rd-plates">
                    <div class="rd-pl" id="rd-pf"><span>${esc(t('radar_front', null, 'Front'))}</span><b></b><em>${esc(t('radar_flagged', null, 'Flagged'))}</em></div>
                    <div class="rd-pl" id="rd-pr"><span>${esc(t('radar_rear', null, 'Rear'))}</span><b></b><em>${esc(t('radar_flagged', null, 'Flagged'))}</em></div>
                </div>
            </div>
        </div>`;
    }
    function radarUpdate(d) {
        const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
        set('rd-front', digits(d.front && d.front.speed, 3));
        set('rd-rear', digits(d.rear && d.rear.speed, 3));
        set('rd-fast', digits(d.fast || '', 3));
        set('rd-patrol', digits(d.patrol, 3));
        set('rd-unit', d.unit || '');
        const lock = document.getElementById('rd-lock');
        if (lock) lock.classList.toggle('on', !!d.locked);
        [['rd-pf', d.front], ['rd-pr', d.rear]].forEach(([id, r]) => {
            const el = document.getElementById(id);
            if (!el) return;
            el.querySelector('b').textContent = r && r.plate ? r.plate : '— — —';
            el.classList.toggle('flag', !!(r && r.flagged));
        });
    }
    XS.apps.radar = {
        isOpen: () => false,
        on(action, data) {
            if (action === 'show') { radarFrame(); XS.show('xsp-radar', true); }
            if (action === 'update') { if (!radarRoot.firstChild) { radarFrame(); XS.show('xsp-radar', true); } radarUpdate(data || {}); }
            if (action === 'hide') { XS.show('xsp-radar', false); radarRoot.innerHTML = ''; }
        },
    };
})();

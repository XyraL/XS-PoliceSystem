(() => {
    const root = document.getElementById('xsp-wheel');
    const t = XS.t;
    const esc = XS.esc;
    const R_OUT = 138;
    const R_IN = 72;
    const GAP = 2.2;
    let state = null;
    let shape = '';

    const rad = (deg) => (deg - 90) * Math.PI / 180;
    const pt = (r, deg) => [150 + r * Math.cos(rad(deg)), 150 + r * Math.sin(rad(deg))];

    function slice(a0, a1) {
        const [x0, y0] = pt(R_OUT, a0);
        const [x1, y1] = pt(R_OUT, a1);
        const [x2, y2] = pt(R_IN, a1);
        const [x3, y3] = pt(R_IN, a0);
        const large = a1 - a0 > 180 ? 1 : 0;
        return `M${x0} ${y0} A${R_OUT} ${R_OUT} 0 ${large} 1 ${x1} ${y1} L${x2} ${y2} A${R_IN} ${R_IN} 0 ${large} 0 ${x3} ${y3}Z`;
    }

    function label(item) {
        return item.label || t(`wheel_${item.id}`, null, item.id);
    }

    function ring(items, selected) {
        const n = Math.max(items.length, 1);
        const span = 360 / n;
        const segs = items.map((item, i) => {
            const a0 = i * span - span / 2 + GAP / 2;
            const a1 = (i + 1) * span - span / 2 - GAP / 2;
            const [ix, iy] = pt((R_OUT + R_IN) / 2 - 2, i * span);
            const [nx, ny] = pt(R_OUT - 8, i * span);
            const [sx, sy] = pt(R_OUT - 9, i * span + Math.min(7, span / 2 - 4));
            return `<g class="ws ${item.danger ? 'ws-danger' : ''} ${item.page ? 'ws-page' : ''} ${i === selected ? 'ws-on' : ''}" data-i="${i}">
                <path d="${slice(a0, a1)}"/>
                <foreignObject x="${ix - 32}" y="${iy - 32}" width="64" height="64"><div class="ws-ico"><img src="img/wheel/${esc(item.icon)}.png" data-icon="${esc(item.icon)}" alt="" draggable="false"></div></foreignObject>
                ${i < 9 ? `<text x="${nx}" y="${ny + 3.5}" class="ws-num">${i + 1}</text>` : ''}
                ${item.fav ? `<text x="${sx}" y="${sy + 4}" class="ws-fav">★</text>` : ''}
            </g>`;
        }).join('');
        return `<svg class="wh-ring" viewBox="0 0 300 300" width="300" height="300">
                <circle cx="150" cy="150" r="${R_OUT + 6}" class="wh-halo"/>
                ${segs}
            </svg>`;
    }

    function iconFallback(scope) {
        scope.querySelectorAll('.ws-ico img').forEach((img) => img.addEventListener('error', () => {
            const holder = img.parentNode;
            if (holder) holder.innerHTML = XS.icon(img.dataset.icon, 22);
        }, { once: true }));
    }

    XS.wheelRing = (items, selected) => ring(items, selected);
    XS.wheelIcons = iconFallback;
    XS.wheelLabel = label;

    function build() {
        const items = state.items;
        const n = Math.max(items.length, 1);
        root.innerHTML = `<div class="wh">
            ${ring(items, -1)}
            <div class="wh-hub">
                <div class="wh-crumb" id="wh-crumb"></div>
                <div class="wh-name" id="wh-name"></div>
                <div class="wh-target" id="wh-target"></div>
            </div>
            <div class="wh-hints">
                <span><i class="xp-kbd">${esc(t('wheel_key_scroll', null, 'Scroll'))}</i>${esc(t('wheel_hint_pick', null, 'pick'))}</span>
                <span><i class="xp-kbd">1-${Math.min(9, n)}</i>${esc(t('wheel_hint_jump', null, 'jump'))}</span>
                <span><i class="xp-kbd">${esc(t('wheel_key_click', null, 'Click'))}</i>${esc(t('wheel_hint_use', null, 'use'))}</span>
                <span><i class="xp-kbd">${esc(t('wheel_key_right', null, 'Right'))}</i>${esc(state.back ? t('wheel_hint_back', null, 'back') : t('wheel_hint_close', null, 'close'))}</span>
                <span id="wh-pin" class="wh-pin"></span>
            </div>
        </div>`;
        iconFallback(root);
    }

    function needs(item) {
        const person = ['cuff', 'escort', 'search', 'seize', 'idcheck', 'gsr', 'putInVehicle', 'fine', 'jail'];
        const vehicle = ['checkPlate', 'impound', 'putInVehicle'];
        return { person: person.includes(item.id), vehicle: vehicle.includes(item.id) };
    }

    function update() {
        const items = state.items;
        const active = items[state.index - 1];
        root.querySelectorAll('.ws').forEach((g) => g.classList.toggle('ws-on', Number(g.dataset.i) === state.index - 1));
        const crumb = root.querySelector('#wh-crumb');
        const name = root.querySelector('#wh-name');
        const target = root.querySelector('#wh-target');
        crumb.textContent = state.page === 'root' ? t('wheel_title', null, 'Police') : (state.pageLabel || t(`wheel_${state.page}`, null, state.page));
        const pin = root.querySelector('#wh-pin');
        if (pin) pin.innerHTML = state.pin ? `<i class="xp-kbd">${esc(t('wheel_key_pin', null, 'G'))}</i>${esc(state.pin.pinned ? t('wheel_hint_unpin', null, 'unpin') : t('wheel_hint_pin', null, 'pin'))}` : '';
        name.textContent = active ? label(active) : '';
        let line = '';
        let cls = '';
        if (active && !active.page) {
            const need = needs(active);
            const info = state.target || {};
            if (need.vehicle && !need.person) {
                if (info.vehicle) line = t('wheel_target_vehicle', { plate: info.vehicle.plate }, `Vehicle ${info.vehicle.plate}`);
                else { line = t('wheel_no_vehicle', null, 'No vehicle near'); cls = 'bad'; }
            } else if (need.person) {
                if (info.person) line = t('wheel_target_person', { distance: info.person.distance }, `Person · ${info.person.distance} m`);
                else { line = t('wheel_no_person', null, 'No one in reach'); cls = 'bad'; }
            }
        } else if (active && active.page) {
            line = t('wheel_opens', null, 'Opens a menu');
        }
        target.textContent = line;
        target.className = `wh-target ${cls}`;
    }

    function pulse(i) {
        const g = root.querySelector(`.ws[data-i="${i - 1}"]`);
        if (!g) return;
        g.classList.remove('ws-pulse');
        void g.getBoundingClientRect();
        g.classList.add('ws-pulse');
    }

    XS.apps.wheel = {
        on(action, data) {
            if (action === 'open') {
                root.classList.remove('xsp-hidden');
                root.classList.remove('wh-in');
                void root.offsetWidth;
                root.classList.add('wh-in');
            } else if (action === 'state') {
                state = data;
                state.items = XS.list(state.items);
                const key = state.page + ':' + state.items.map((i) => `${i.id}|${i.icon}|${i.fav ? 1 : 0}`).join(',') + ':' + (state.back ? 1 : 0);
                if (key !== shape) {
                    shape = key;
                    build();
                }
                update();
            } else if (action === 'pulse') {
                pulse(data.index);
            } else if (action === 'close') {
                root.classList.add('xsp-hidden');
                shape = '';
                state = null;
            }
        },
    };
})();

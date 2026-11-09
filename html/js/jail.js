(() => {
    const root = document.getElementById('xsp-jail');
    const t = XS.t;
    const esc = XS.esc;
    let left = 0;
    let timer = null;
    let state = null;

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const mm = String(m).padStart(2, '0');
        const ss = String(sec).padStart(2, '0');
        return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
    }

    function render() {
        root.innerHTML = `<div class="band ${state.escaped ? 'band-out' : ''}">
            <span class="band-snap"></span>
            <div class="band-text">
                <div class="band-top"><b>${esc(t('jail_dept', null, 'SADOC'))}</b><span>${esc(t('jail_inmate', { number: state.number || '0000' }, `Inmate ${state.number}`))}</span></div>
                <div class="band-time" id="band-time">${state.escaped ? esc(t('jail_escaped', null, 'Escaped')) : esc(clock(left))}</div>
                <div class="band-meta">${esc(t('jail_sentence', { months: state.months || 0 }, `${state.months} months`))}${state.reason ? ` · ${esc(state.reason)}` : ''}</div>
                ${state.escaped ? '' : `<div class="band-credit" id="band-credit">${esc(t('jail_credit', { amount: Number(state.credit) || 0 }, 'Credit %{amount}'))}</div>`}
            </div>
            <span class="band-code"></span>
        </div>`;
    }

    function tick() {
        if (!state || state.escaped) return;
        left = Math.max(0, left - 1);
        const el = root.querySelector('#band-time');
        if (el) el.textContent = clock(left);
    }

    XS.apps.jail = {
        on(action, data) {
            if (action === 'open') {
                state = data || {};
                left = Number(state.left) || 0;
                root.classList.remove('xsp-hidden');
                render();
                clearInterval(timer);
                timer = setInterval(tick, 1000);
            } else if (action === 'time') {
                left = Number(data.left) || 0;
                const el = root.querySelector('#band-time');
                if (el && state && !state.escaped) el.textContent = clock(left);
            } else if (action === 'credit') {
                if (!state) return;
                state.credit = Number(data.credit) || 0;
                const el = root.querySelector('#band-credit');
                if (el) el.textContent = t('jail_credit', { amount: state.credit }, 'Credit %{amount}');
            } else if (action === 'escaped') {
                if (!state) return;
                state.escaped = true;
                render();
            } else if (action === 'close') {
                clearInterval(timer);
                state = null;
                root.classList.add('xsp-hidden');
                root.innerHTML = '';
            }
        },
    };
})();

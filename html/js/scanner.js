(() => {
    const root = document.getElementById('xsp-scanner');
    const t = XS.t;
    const esc = XS.esc;
    let open = false;

    function rng(seed) {
        return function next() {
            seed |= 0; seed = seed + 0x6D2B79F5 | 0;
            let x = Math.imul(seed ^ seed >>> 15, 1 | seed);
            x = x + Math.imul(x ^ x >>> 7, 61 | x) ^ x;
            return ((x ^ x >>> 14) >>> 0) / 4294967296;
        };
    }
    const smooth = (a, b, x) => { const v = Math.min(1, Math.max(0, (x - a) / (b - a))); return v * v * (3 - 2 * v); };

    function ridges(w, h, seed) {
        const r = rng(seed);
        const cx = w * (0.5 + (r() - 0.5) * 0.08), cy = h * (0.43 + (r() - 0.5) * 0.06);
        const lam = w / (12.5 + r() * 2.5);
        const twist = r() < 0.5 ? -1 : 1;
        const waves = [];
        for (let i = 0; i < 5; i++) waves.push([(r() * 2 - 1) * 0.07, (r() * 2 - 1) * 0.07, r() * 6.283, 0.05 + r() * 0.12]);
        const blotch = [];
        for (let i = 0; i < 6; i++) blotch.push([r() * w, r() * h, (0.12 + r() * 0.22) * w, 0.25 + r() * 0.5]);
        const pores = [];
        for (let i = 0; i < Math.floor(w * h / 260); i++) pores.push([r() * w, r() * h, 0.5 + r() * 0.9]);
        const out = new Float32Array(w * h);
        for (let y = 0; y < h; y++) {
            for (let x = 0; x < w; x++) {
                const nx = (x - cx) / w, ny = (y - cy) / h;
                const k = ny < 0 ? 1.55 : 1.55 * Math.exp(-ny * 9.5) + 0.02;
                const rho = Math.sqrt(k * nx * nx + ny * ny) * h;
                const th = Math.atan2(ny, nx * 1.2);
                let ph = rho / lam + twist * th / (2 * Math.PI);
                for (const [fx, fy, p, a] of waves) ph += a * Math.sin(x * fx + y * fy + p);
                let ink = smooth(0.38, 0.74, 0.5 + 0.5 * Math.cos(2 * Math.PI * ph));
                const mx = (x - w * 0.5) / (w * 0.47), my = (y - h * 0.52) / (h * 0.49);
                const d = Math.sqrt(mx * mx + my * my * (my > 0 ? 0.8 : 1));
                let p = 1 - 0.25 * d * d;
                for (const [bx, by, br, ba] of blotch) p -= ba * 0.5 * Math.exp(-((x - bx) ** 2 + (y - by) ** 2) / (br * br));
                ink *= (1 - smooth(0.74, 1.0, d)) * Math.max(0.12, Math.min(1, p));
                out[y * w + x] = ink;
            }
        }
        for (const [px, py, pr] of pores) {
            for (let y = Math.floor(py - 2); y <= py + 2; y++) {
                for (let x = Math.floor(px - 2); x <= px + 2; x++) {
                    if (x < 0 || y < 0 || x >= w || y >= h) continue;
                    const dd = Math.hypot(x - px, y - py);
                    if (dd < pr) out[y * w + x] *= 0.25 + 0.75 * (dd / pr);
                }
            }
        }
        return out;
    }

    function paint(canvas, seed, glow) {
        const w = canvas.width, h = canvas.height;
        const ink = ridges(w, h, seed);
        const ctx = canvas.getContext('2d');
        const img = ctx.createImageData(w, h);
        for (let i = 0; i < w * h; i++) {
            const v = ink[i];
            if (glow) {
                img.data[i * 4] = 150; img.data[i * 4 + 1] = 255; img.data[i * 4 + 2] = 214; img.data[i * 4 + 3] = Math.round(v * 255);
            } else {
                img.data[i * 4] = Math.round(236 - v * 196); img.data[i * 4 + 1] = Math.round(240 - v * 196); img.data[i * 4 + 2] = Math.round(241 - v * 192); img.data[i * 4 + 3] = 255;
            }
        }
        ctx.putImageData(img, 0, 0);
    }

    function clock() {
        const d = new Date();
        return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }

    function recordStrip(r) {
        const chips = [];
        if (Number(r.warrants) > 0) chips.push(`<span class="bad">${esc(t('scanner_warrants', { n: r.warrants }, 'Open warrants: %{n}'))}</span>`);
        chips.push(Number(r.bookings) > 0
            ? `<span class="warn">${esc(t('scanner_bookings', { n: r.bookings, date: r.last ? XS.date(r.last).slice(0, 10) : '' }, 'Booked %{n}x, last %{date}'))}</span>`
            : `<span>${esc(t('scanner_no_bookings', null, 'No prior bookings'))}</span>`);
        if (Number(r.scenes) > 0) chips.push(`<span class="warn">${esc(t('scanner_scenes', { n: r.scenes }, 'Linked to %{n} lab reports'))}</span>`);
        return `<div class="sc-rec">${chips.join('')}</div>`;
    }

    function copyText(text) {
        const area = document.createElement('textarea');
        area.value = String(text || '');
        area.setAttribute('readonly', '');
        area.style.position = 'fixed';
        area.style.left = '-9999px';
        document.body.appendChild(area);
        area.select();
        let ok = false;
        try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
        area.remove();
        return ok;
    }

    function codeRow(key, label, value) {
        if (!value) return '';
        return `<div class="sc-code">
            <small>${esc(label)}</small>
            <code>${esc(value)}</code>
            <button class="sc-copy" data-copy="${esc(key)}" title="${esc(t('scanner_copy', null, 'Copy'))}">${XS.icon('copy', 13)}<span>${esc(t('scanner_copy', null, 'Copy'))}</span></button>
        </div>`;
    }

    function flash(btn) {
        if (!btn) return;
        const label = btn.querySelector('span');
        const before = label ? label.textContent : '';
        btn.classList.add('done');
        if (label) label.textContent = t('scanner_copied', null, 'Copied');
        clearTimeout(btn._t);
        btn._t = setTimeout(() => {
            btn.classList.remove('done');
            if (label) label.textContent = before;
        }, 1400);
    }

    function render(scan) {
        const stage = XS.stage(root);
        const rec = scan.record || {};
        const wanted = Number(rec.warrants) > 0;
        const matches = XS.list(scan.matches);
        const values = { print: scan.print || '', dna: scan.dna || '', cid: scan.cid || '' };
        const list = matches.length
            ? matches.map((m) => `<div class="sc-m"><em>${esc(t('scanner_match', null, 'Match'))}</em><div><b>${esc(m.label || '')}</b><span>${esc([m.street, m.collected].filter(Boolean).join(' · '))}</span></div></div>`).join('')
            : `<div class="sc-none">${esc(t('scanner_no_match', null, 'Nothing you are carrying matches.'))}</div>`;
        const mdtTitle = scan.mdt ? '' : esc(t('scanner_no_mdt', null, 'No MDT on this server'));
        stage.innerHTML = `<div class="sc-wrap">
            <div class="sc">
                <div class="sc-cap"></div>
                <div class="sc-face">
                    <i class="sc-screw s1"></i><i class="sc-screw s2"></i><i class="sc-screw s3"></i><i class="sc-screw s4"></i>
                    <div class="sc-bezel">
                        <div class="sc-lcd">
                            <div class="sc-bar"><b>${esc(t('scanner_title', null, 'Mobile ID'))}</b><span>${esc(clock())}</span><i class="sc-batt"><i></i></i></div>
                            <div class="sc-banner ${wanted ? 'bad' : ''}">
                                <i>${XS.icon(wanted ? 'alert' : 'check', 15)}</i>
                                <b>${esc(wanted ? t('scanner_wanted', null, 'Wanted') : t('scanner_identified', null, 'Identified'))}</b>
                                <span>${esc(t('scanner_on_file', null, 'On file'))}</span>
                            </div>
                            <div class="sc-main">
                                <div class="sc-print"><canvas id="sc-print" width="120" height="150"></canvas><i class="sc-sweep"></i></div>
                                <div class="sc-who">
                                    <div class="sc-name">${esc(scan.name || '')}</div>
                                    ${recordStrip(rec)}
                                </div>
                            </div>
                            <div class="sc-codes">
                                ${codeRow('print', t('scanner_print', null, 'Fingerprint'), values.print)}
                                ${codeRow('dna', t('scanner_dna', null, 'DNA'), values.dna)}
                                ${codeRow('cid', t('scanner_cid', null, 'Citizen ID'), values.cid)}
                            </div>
                            <div class="sc-list"><small>${esc(t('scanner_matches', null, 'Your evidence bags'))}</small>${list}</div>
                            <div class="sc-soft"><span>${esc(t('scanner_copy', null, 'Copy'))}</span><span class="${scan.mdt ? '' : 'off'}">${esc(t('scanner_mdt', null, 'MDT'))}</span><span>${esc(t('scanner_done', null, 'Done'))}</span></div>
                        </div>
                        <i class="sc-glare"></i>
                    </div>
                    <div class="sc-keys">
                        <button class="sc-key" data-copy="print" title="${esc(t('scanner_copy', null, 'Copy'))}">${XS.icon('copy', 15)}</button>
                        <button class="sc-key mdt" data-mdt ${scan.mdt ? '' : `disabled title="${mdtTitle}"`}>${XS.icon('id', 15)}</button>
                        <button class="sc-key go" data-close>${XS.icon('check', 15)}</button>
                        <i class="sc-led"></i>
                    </div>
                    <div class="sc-platen"><div class="sc-glass"><canvas id="sc-residue" width="120" height="150"></canvas><i class="sc-line"></i></div></div>
                    <div class="sc-brand">LIVESCAN</div>
                </div>
            </div>
            <div class="sc-hint"><i class="xp-kbd">Esc</i>${esc(t('close', null, 'Close'))}</div>
        </div>`;
        const seed = Number(scan.seed) || 1;
        paint(stage.querySelector('#sc-print'), seed, false);
        paint(stage.querySelector('#sc-residue'), seed, true);
        stage.querySelector('[data-close]').addEventListener('click', () => XS.close('scanner'));
        stage.querySelectorAll('[data-copy]').forEach((btn) => btn.addEventListener('click', () => {
            const key = btn.dataset.copy;
            if (!values[key]) return;
            copyText(values[key]);
            const row = stage.querySelector(`.sc-copy[data-copy="${key}"]`);
            flash(row || btn);
            XS.toast(`${t('scanner_copied', null, 'Copied')}: ${values[key]}`, 'success');
        }));
        const mdt = stage.querySelector('[data-mdt]');
        if (mdt && scan.mdt) mdt.addEventListener('click', async () => {
            mdt.disabled = true;
            const res = await XS.rpc('scanner:mdt', { target: scan.target, cid: scan.cid });
            if (!res.ok) {
                mdt.disabled = false;
                XS.toast(res.error, 'error');
            }
        });
    }

    XS.apps.scanner = {
        isOpen: () => open,
        escape: () => XS.close('scanner'),
        on(action, data) {
            if (action === 'open') {
                open = true;
                XS.show('xsp-scanner', true);
                render(data || {});
            } else if (action === 'close') {
                open = false;
                XS.show('xsp-scanner', false);
            }
        },
    };
})();

(() => {
    const esc = XS.esc;
    const COLOURS = {
        duty: '#60a5fa', locker: '#a78bfa', armory: '#f87171', garage: '#34d399', helipad: '#2dd4bf', evidence: '#fbbf24', lab: '#f472b6',
        booking: '#38bdf8', boss: '#facc15', camroom: '#60a5fa', cell: '#94a3b8', canteen: '#fb923c', workout: '#a3e635', release: '#34d399', solitary: '#f87171',
        desk: '#60a5fa', lot: '#34d399', task: '#a3e635', job: '#fb923c', blip: '#f472b6',
        guard: '#3b82f6', clerk: '#2fcf8a', trader: '#e879f9', craft: '#facc15', tunnel: '#d97706', fence: '#ef4444',
    };
    const ICONS = {
        duty: 'clock', locker: 'shirt', armory: 'gun', garage: 'car', helipad: 'helicopter', evidence: 'box', lab: 'flask', booking: 'id', boss: 'star', camroom: 'camera',
        cell: 'door', canteen: 'food', workout: 'dumbbell', release: 'exit', solitary: 'lock', desk: 'id', lot: 'car', task: 'broom', job: 'gear',
        guard: 'shield', clerk: 'cash', trader: 'user', craft: 'gear', tunnel: 'door', fence: 'barrier',
    };
    const STEPS = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000];

    XS.PlanColour = (kind) => COLOURS[kind] || '#60a5fa';
    XS.PlanIcon = (kind) => ICONS[kind] || 'pin';

    const num = (v) => Number(v) || 0;
    const far = (a, b) => Math.hypot(num(a.x) - num(b.x), num(a.y) - num(b.y)) > 0.6;

    function reach(place, c, radius) {
        let r = radius;
        const fit = (p) => {
            if (!p || p.x === undefined) return;
            r = Math.max(r, Math.hypot(num(p.x) - num(c.x), num(p.y) - num(c.y), num(p.z !== undefined ? p.z : c.z) - num(c.z)) + 15);
        };
        Object.keys(place.points || {}).forEach((k) => { if (k !== 'release') XS.list(place.points[k]).forEach(fit); });
        XS.list(place.work).forEach((w) => XS.list(w.spots).forEach(fit));
        return r;
    }

    function collect(place, defs, opts) {
        const out = { pts: [], spawns: [], bays: [], routes: [], exits: [], circle: null, pin: null };
        const points = place.points || {};
        defs.forEach((def) => {
            XS.list(points[def.key]).forEach((p, i) => {
                if (def.key === 'lot') out.bays.push({ x: num(p.x), y: num(p.y), w: num(p.w), ref: `${def.key}:${i}` });
                out.pts.push({ x: num(p.x), y: num(p.y), w: num(p.w), kind: def.key, ref: `${def.key}:${i}`, label: p.label || opts.name(def.key, i), n: i + 1 });
                if (def.exit && p.exit && p.exit.x !== undefined) out.exits.push({ x: num(p.exit.x), y: num(p.exit.y), from: { x: num(p.x), y: num(p.y) }, kind: def.key });
                if (def.spawn && p.spawn && p.spawn.x !== undefined) {
                    out.spawns.push({ x: num(p.spawn.x), y: num(p.spawn.y), w: num(p.spawn.w), heli: def.key === 'helipad', from: far(p, p.spawn) ? { x: num(p.x), y: num(p.y) } : null });
                }
            });
        });
        XS.list(place.work).forEach((w, j) => {
            const route = [];
            XS.list(w.spots).forEach((s, i) => {
                out.pts.push({ x: num(s.x), y: num(s.y), w: num(s.w), kind: 'job', ref: `w:${j}:${i}`, label: `${w.label} ${i + 1}`, n: i + 1, diamond: true });
                route.push({ x: num(s.x), y: num(s.y) });
            });
            if (route.length > 1) out.routes.push(route);
        });
        if (place.kind === 'jail') {
            const c = place.center && place.center.x !== undefined ? place.center : XS.list(points.cell)[0];
            if (c) out.circle = { x: num(c.x), y: num(c.y), r: reach(place, c, num(place.radius) || num(opts.radius) || 150), set: !!(place.center && place.center.x !== undefined) };
        }
        if (place.blipAt && place.blipAt.x !== undefined) out.pin = { x: num(place.blipAt.x), y: num(place.blipAt.y) };
        return out;
    }

    function bounds(d) {
        const xs = [];
        const ys = [];
        const add = (x, y, r) => { xs.push(x - (r || 0), x + (r || 0)); ys.push(y - (r || 0), y + (r || 0)); };
        d.pts.forEach((p) => add(p.x, p.y, 3));
        d.spawns.forEach((s) => add(s.x, s.y, 4));
        d.exits.forEach((e) => add(e.x, e.y, 3));
        if (d.circle) add(d.circle.x, d.circle.y, d.circle.r);
        if (d.pin) add(d.pin.x, d.pin.y, 3);
        if (!xs.length) return null;
        return { minX: Math.min(...xs), maxX: Math.max(...xs), minY: Math.min(...ys), maxY: Math.max(...ys) };
    }

    function render(place, defs, opts) {
        const o = Object.assign({ w: 640, h: 500, pad: 34, mini: false, labels: true, sel: null, radius: 150, name: (k, i) => `${k} ${i + 1}`, empty: '' }, opts || {});
        const W = o.w;
        const H = o.h;
        const d = collect(place, defs, o);
        const b = bounds(d);
        const head = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg">`;
        const bg = `<defs><radialGradient id="plGlow${o.mini ? 'm' : ''}" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="#0d1524"/><stop offset="1" stop-color="#05070b"/></radialGradient></defs><rect width="${W}" height="${H}" fill="url(#plGlow${o.mini ? 'm' : ''})"/>`;
        if (!b) {
            return `${head}${bg}${grid(0, W, 0, H, 40, 0, 0, 1, true)}<text class="pl-empty" x="${W / 2}" y="${H / 2 + 4}">${esc(o.empty)}</text></svg>`;
        }
        const minSpan = o.mini ? 30 : 24;
        let spanX = b.maxX - b.minX;
        let spanY = b.maxY - b.minY;
        if (spanX < minSpan) { b.minX -= (minSpan - spanX) / 2; spanX = minSpan; }
        if (spanY < minSpan) { b.minY -= (minSpan - spanY) / 2; spanY = minSpan; }
        b.maxX = b.minX + spanX;
        b.maxY = b.minY + spanY;
        const pad = o.mini ? 18 : o.pad;
        const scale = Math.min((W - pad * 2) / spanX, (H - pad * 2) / spanY);
        const offX = (W - spanX * scale) / 2;
        const offY = (H - spanY * scale) / 2;
        const sx = (x) => offX + (x - b.minX) * scale;
        const sy = (y) => offY + (b.maxY - y) * scale;
        const step = STEPS.find((s) => s * scale >= (o.mini ? 30 : 46)) || STEPS[STEPS.length - 1];

        const wxL = b.minX - offX / scale;
        const wyT = b.maxY + offY / scale;
        let svg = head + bg + grid(wxL, W, wyT, H, step, offX, offY, scale, o.mini, b);

        if (d.circle) {
            const cx = sx(d.circle.x);
            const cy = sy(d.circle.y);
            svg += `<circle class="pl-radius" cx="${cx}" cy="${cy}" r="${d.circle.r * scale}"/>`;
            if (!o.mini) svg += `<path class="pl-center" d="M${cx - 7} ${cy}H${cx + 7}M${cx} ${cy - 7}V${cy + 7}"/>`;
        }
        d.routes.forEach((r) => { svg += `<polyline class="pl-route" points="${r.map((p) => `${sx(p.x)},${sy(p.y)}`).join(' ')}"/>`; });

        const rect = (x, y, w, lenM, widM, cls) => {
            const L = Math.max(o.mini ? 4 : 8, lenM * scale);
            const Wd = Math.max(o.mini ? 2 : 4, widM * scale);
            return `<rect class="${cls}" x="${-Wd / 2}" y="${-L / 2}" width="${Wd}" height="${L}" rx="${Math.min(3, Wd / 3)}" transform="translate(${sx(x)},${sy(y)}) rotate(${-w})"/>`;
        };
        d.bays.forEach((s) => { svg += rect(s.x, s.y, s.w, 5.6, 2.6, 'pl-spawn'); });
        d.spawns.forEach((s) => {
            if (s.from && !o.mini) svg += `<line class="pl-link" x1="${sx(s.from.x)}" y1="${sy(s.from.y)}" x2="${sx(s.x)}" y2="${sy(s.y)}"/>`;
            svg += s.heli ? rect(s.x, s.y, s.w, 4.6, 4.6, 'pl-spawn heli') : rect(s.x, s.y, s.w, 5.6, 2.4, 'pl-spawn');
        });

        d.exits.forEach((e) => {
            const col = XS.PlanColour(e.kind);
            if (!o.mini) svg += `<line class="pl-link" x1="${sx(e.from.x)}" y1="${sy(e.from.y)}" x2="${sx(e.x)}" y2="${sy(e.y)}" style="stroke:${col};stroke-opacity:.7"/>`;
            svg += `<rect x="${sx(e.x) - (o.mini ? 3 : 6)}" y="${sy(e.y) - (o.mini ? 3 : 6)}" width="${o.mini ? 6 : 12}" height="${o.mini ? 6 : 12}" rx="2" fill="none" stroke="${col}" stroke-width="2" stroke-dasharray="3 2"/>`;
        });

        const labels = [];
        d.pts.forEach((p) => {
            const col = XS.PlanColour(p.kind);
            const x = sx(p.x);
            const y = sy(p.y);
            if (o.mini) {
                svg += p.diamond ? `<rect x="${x - 3}" y="${y - 3}" width="6" height="6" fill="${col}" transform="rotate(45 ${x} ${y})"/>` : `<circle cx="${x}" cy="${y}" r="4" fill="${col}" stroke="#05070b" stroke-width="1.5"/>`;
                return;
            }
            const sel = o.sel === p.ref;
            const rad = (p.w * Math.PI) / 180;
            const dx = -Math.sin(rad) * 19;
            const dy = -Math.cos(rad) * 19;
            svg += `<g class="pl-pt ${sel ? 'sel' : ''}" data-pt="${esc(p.ref)}" transform="translate(${x},${y})"><title>${esc(p.label)} · ${p.x.toFixed(1)}, ${p.y.toFixed(1)}</title>`;
            svg += `<circle class="halo" r="16" stroke="${col}"/>`;
            if (!p.diamond) svg += `<line class="dir" x1="0" y1="0" x2="${dx}" y2="${dy}" stroke="${col}"/>`;
            if (p.diamond) {
                svg += `<rect class="body" x="-8" y="-8" width="16" height="16" rx="2" fill="${col}" transform="rotate(45)"/><text y="3.2">${p.n}</text>`;
            } else {
                svg += `<circle class="body" r="10.5" fill="${col}"/><svg x="-6.5" y="-6.5" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#05070b" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">${XS.iconPath(XS.PlanIcon(p.kind))}</svg>`;
            }
            svg += '</g>';
            if (o.labels) labels.push(`<text class="pl-label" x="${x}" y="${y + 27}">${esc(p.label)}</text>`);
        });
        svg += labels.join('');
        if (d.pin) {
            const x = sx(d.pin.x);
            const y = sy(d.pin.y);
            svg += o.mini ? `<circle cx="${x}" cy="${y}" r="3.5" class="pl-pin"/>` : `<path class="pl-pin" transform="translate(${x},${y})" d="M0 0C-5-6-8-9-8-13a8 8 0 0 1 16 0c0 4-3 7-8 13z"/><circle cx="${x}" cy="${y - 13}" r="2.6" fill="#05070b"/>`;
        }
        if (!o.mini) {
            const len = step * scale;
            svg += `<path class="pl-scale" d="M16 ${H - 22}v6h${len}v-6"/><text class="pl-scaletext" x="${16 + len + 8}" y="${H - 15}">${step} m</text>`;
            svg += `<g transform="translate(${W - 24},26)"><path d="M0-12L6 4 0 0-6 4z" fill="#93a0b4"/><text class="pl-north" y="17">N</text></g>`;
        }
        return `${svg}</svg>`;
    }

    function grid(wxL, W, wyT, H, step, offX, offY, scale, mini) {
        if (!step || !scale) return '';
        let out = '';
        const x0 = Math.ceil(wxL / step) * step;
        for (let x = x0, n = 0; (x - wxL) * scale <= W && n < 400; x += step, n++) {
            const px = (x - wxL) * scale;
            out += `<line class="pl-grid ${Math.round(x / step) % 5 === 0 && !mini ? 'major' : ''}" x1="${px}" y1="0" x2="${px}" y2="${H}"/>`;
        }
        const y0 = Math.floor(wyT / step) * step;
        for (let y = y0, n = 0; (wyT - y) * scale <= H && n < 400; y -= step, n++) {
            const py = (wyT - y) * scale;
            out += `<line class="pl-grid ${Math.round(y / step) % 5 === 0 && !mini ? 'major' : ''}" x1="0" y1="${py}" x2="${W}" y2="${py}"/>`;
        }
        return out;
    }

    XS.Plan = { render, reach };
})();

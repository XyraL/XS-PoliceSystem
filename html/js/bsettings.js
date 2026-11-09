(() => {
    const t = XS.t;
    const esc = XS.esc;
    let ctx = null;
    let el = null;
    let draft = {};
    let section = 'all';
    let query = '';
    let onlyChanged = false;
    let busy = false;
    let flash = null;
    let onChange = null;

    const copy = (v) => (v === undefined ? undefined : JSON.parse(JSON.stringify(v)));
    const keyOf = (key) => key.replace(/\./g, '_');
    const label = (key) => t(`cfg_${keyOf(key)}`, null, key);
    const hint = (key) => t(`cfg_${keyOf(key)}_hint`, null, '');
    const sectionLabel = (id) => t(`cfg_sec_${id}`, null, id);
    const sectionHint = (id) => t(`cfg_sec_${id}_hint`, null, '');

    function same(a, b) {
        if (Array.isArray(a) || Array.isArray(b)) {
            const x = XS.list(a);
            const y = XS.list(b);
            return x.length === y.length && x.every((v, i) => same(v, y[i]));
        }
        if (typeof a === 'number' && typeof b === 'number') return Math.abs(a - b) < 1e-9;
        return a === b;
    }

    const fields = () => ctx.sections.reduce((all, s) => all.concat(s.fields), []);
    const defOf = (key) => fields().find((f) => f.key === key);
    const current = (key) => (Object.prototype.hasOwnProperty.call(draft, key) ? draft[key] : ctx.values[key]);
    const changed = (key) => !same(current(key), ctx.defaults[key]);
    const pending = () => Object.keys(draft).filter((k) => !same(draft[k], ctx.values[k]));

    function truthy(v) {
        if (Array.isArray(v)) return v.length > 0;
        return v !== false && v !== undefined && v !== null && v !== '' && v !== 0;
    }

    function live(def, depth) {
        if (!def.needs || (depth || 0) > 6) return true;
        const parent = defOf(def.needs);
        return truthy(current(def.needs)) && (!parent || live(parent, (depth || 0) + 1));
    }

    function fmt(def, v) {
        if (v === undefined || v === null) return '—';
        if (def.type === 'bool') return v ? t('on', null, 'On') : t('off', null, 'Off');
        if (def.type === 'item') return v === false ? t('off', null, 'Off') : String(v);
        if (def.type === 'list' || def.type === 'seq') return XS.list(v).join(', ') || t('none', null, 'None');
        if (def.type === 'nums') return XS.list(v).map((n) => `${n}${def.unit ? ` ${def.unit}` : ''}`).join(', ');
        if (def.type === 'pct') return `${v}%`;
        if (def.type === 'select') return t(`cfg_opt_${String(v).replace(/[^a-z0-9_]/gi, '_')}`, null, String(v));
        if (def.type === 'grade') return gradeName(v);
        if (def.unit === '$') return XS.money(v);
        return `${v}${def.unit ? ` ${def.unit}` : ''}`;
    }

    function gradeList() {
        const names = {};
        let max = 0;
        XS.list(ctx.jobs).forEach((j) => XS.list(j.grades).forEach((g) => {
            const n = Number(g.grade) || 0;
            if (n > max) max = n;
            if (!names[n]) names[n] = g.label;
        }));
        if (!Object.keys(names).length) max = 10;
        return { names, max };
    }

    function gradeName(n) {
        const { names } = gradeList();
        return names[n] ? `${n} · ${names[n]}` : String(n);
    }

    function control(def) {
        const v = current(def.key);
        const k = esc(def.key);
        const off = !live(def);
        switch (def.type) {
        case 'bool':
            return `<span class="bx-switch ${v ? 'on' : ''} ${off ? 'dis' : ''}" data-bool="${k}"></span>`;
        case 'int':
        case 'num':
            return `<div class="bx-unit"><input type="number" data-num="${k}" value="${esc(v)}" min="${def.min !== undefined ? def.min : ''}" max="${def.max !== undefined ? def.max : ''}" step="${def.step || 1}" ${off ? 'disabled' : ''}>${def.unit ? `<em>${esc(def.unit)}</em>` : ''}<button data-step="${k}" data-dir="-1" ${off ? 'disabled' : ''}>−</button><button data-step="${k}" data-dir="1" ${off ? 'disabled' : ''}>+</button></div>`;
        case 'pct':
            return `<div class="bx-pct"><input type="range" min="0" max="100" step="1" data-pct="${k}" value="${Number(v) || 0}" ${off ? 'disabled' : ''}><b>${Number(v) || 0}%</b></div>`;
        case 'grade': {
            const { names, max } = gradeList();
            const top = Math.max(max, Number(v) || 0);
            let opts = '';
            for (let n = 0; n <= top; n++) opts += `<option value="${n}" ${Number(v) === n ? 'selected' : ''}>${esc(names[n] ? `${n} · ${names[n]}` : `${t('grade_short', { grade: n }, 'Grade %{grade}+').replace('+', '')}`)}</option>`;
            return `<select class="bx-input" data-grade="${k}" ${off ? 'disabled' : ''}>${opts}</select>`;
        }
        case 'select':
            return `<select class="bx-input" data-select="${k}" ${off ? 'disabled' : ''}>${XS.list(def.options).map((o) => `<option value="${esc(o)}" ${o === v ? 'selected' : ''}>${esc(t(`cfg_opt_${String(o).replace(/[^a-z0-9_]/gi, '_')}`, null, o))}</option>`).join('')}</select>`;
        case 'text':
            return `<input class="bx-input ${def.upper || def.slug ? 'mono' : ''}" data-text="${k}" maxlength="${def.max || 64}" value="${esc(v)}" ${off ? 'disabled' : ''}>`;
        case 'item': {
            const on = v !== false && v !== undefined && v !== null && v !== '';
            return `${def.off ? `<span class="bx-switch ${on ? 'on' : ''} ${off ? 'dis' : ''}" data-itemon="${k}"></span>` : ''}<input class="bx-input mono" list="bs-items" data-item="${k}" value="${esc(on ? v : '')}" placeholder="${esc(t('bs_item_off', null, 'No item needed'))}" ${!on || off ? 'disabled' : ''} style="width:190px">`;
        }
        case 'list':
        case 'nums':
            return `<div class="bx-tags" data-tags="${k}">${XS.list(v).map((x, i) => `<span class="bx-tagx">${esc(x)}${def.type === 'nums' && def.unit ? ` ${esc(def.unit)}` : ''}<button data-untag="${k}" data-i="${i}" ${off ? 'disabled' : ''}>${XS.icon('close', 10)}</button></span>`).join('')}<input data-tagin="${k}" ${def.items ? 'list="bs-items"' : ''} placeholder="${esc(def.type === 'nums' ? t('bs_add_number', null, 'Add…') : t('bs_add_tag', null, 'Type, then Enter'))}" ${def.type === 'nums' ? 'type="number"' : ''} ${off ? 'disabled' : ''}></div>`;
        case 'seq':
            return `<div class="bx-seq">${XS.list(v).map((x, i) => `<span class="bx-tagx">${esc(t(`cfg_opt_${x}`, null, x))}<button data-unseq="${k}" data-i="${i}" ${off ? 'disabled' : ''}>${XS.icon('close', 10)}</button></span>`).join('')}${XS.list(v).length < (def.max || 5) ? XS.list(def.options).map((o) => `<button class="bx-btn xs" data-seq="${k}" data-v="${esc(o)}" ${off ? 'disabled' : ''}>+ ${esc(t(`cfg_opt_${o}`, null, o))}</button>`).join('') : ''}</div>`;
        default:
            return '';
        }
    }

    function row(def) {
        const isChanged = changed(def.key);
        const needRestart = def.restart && !same(current(def.key), (ctx.boot || {})[def.key]);
        return `<div class="bx-setrow ${isChanged ? 'changed' : ''} ${live(def) ? '' : 'dim'} ${flash === def.key ? 'hit' : ''}" data-row="${esc(def.key)}">
            <div class="bx-setinfo"><b>${esc(label(def.key))}${def.restart ? `<span class="bx-restart">${esc(t('bs_restart', null, 'Restart'))}</span>` : ''}</b>
                ${hint(def.key) ? `<p>${esc(hint(def.key))}</p>` : ''}
                ${isChanged ? `<span class="bx-default">${esc(t('bs_default', { value: fmt(def, ctx.defaults[def.key]) }, 'config.lua: %{value}'))} · <button data-reset="${esc(def.key)}">${esc(t('bs_reset', null, 'Reset'))}</button></span>` : ''}
                ${needRestart ? `<span class="bx-default" style="color:var(--b-amber)">${esc(t('bs_needs_restart', null, 'Restart the script for this to take effect.'))}</span>` : ''}
            </div>
            <div class="bx-setctl">${control(def)}</div>
        </div>`;
    }

    function matches(def) {
        if (onlyChanged && !changed(def.key)) return false;
        if (!query) return true;
        const hay = `${label(def.key)} ${hint(def.key)} ${def.key} ${sectionLabel(def.section)}`.toLowerCase();
        return query.split(/\s+/).every((w) => hay.includes(w));
    }

    function render() {
        if (!el) return;
        const scroller = el.closest('.xsp-scroll');
        const top = scroller ? scroller.scrollTop : 0;
        const all = fields();
        const changedCount = all.filter((f) => changed(f.key)).length;
        const searching = query || onlyChanged;
        const shown = ctx.sections.filter((s) => searching || section === 'all' || s.id === section).map((s) => {
            const list = s.fields.filter(matches);
            if (!list.length) return '';
            const secChanged = s.fields.filter((f) => changed(f.key)).length;
            return `<section class="bx-setsec" data-sec="${esc(s.id)}">
                <div class="bx-setsech"><span class="bx-kindico">${XS.icon(s.icon, 17)}</span><div style="flex:1;min-width:0"><h2>${esc(sectionLabel(s.id))}</h2>${sectionHint(s.id) ? `<p>${esc(sectionHint(s.id))}</p>` : ''}</div>
                ${secChanged ? `<button class="bx-btn xs ghost" data-resetsec="${esc(s.id)}">${XS.icon('undo', 13)}${esc(t('bs_reset_section', null, 'Reset section'))}</button>` : ''}</div>
                ${list.map(row).join('')}
            </section>`;
        }).join('');
        const p = pending();
        el.innerHTML = `<datalist id="bs-items">${XS.list(ctx.items).map((i) => `<option value="${esc(i.name)}">${esc(i.label)}</option>`).join('')}</datalist>
            <div class="bx-pagehead"><div><h1>${esc(t('bs_title', null, 'Settings'))}</h1><p>${esc(t('bs_sub', null, 'How the whole police system behaves. Saving puts it live for everyone straight away, no restart. Anything you change here wins over config.lua.'))}</p></div></div>
            <div class="bx-setbar">
                <div class="bx-filter">${XS.icon('search', 15)}<input class="bx-input" id="bs-q" value="${esc(query)}" placeholder="${esc(t('bs_search', { n: all.length }, 'Search %{n} settings'))}"></div>
                <label class="bx-toggle" id="bs-only"><span class="bx-switch ${onlyChanged ? 'on' : ''}"></span>${esc(t('bs_only_changed', null, 'Only changed'))}</label>
                <span class="bx-sp"></span>
                <span class="bx-chip ${changedCount ? 'warn' : ''}">${esc(t('bs_changed_count', { n: changedCount }, '%{n} changed from config.lua'))}</span>
            </div>
            <div class="bx-set">
                <div class="bx-setnav">
                    <button class="${section === 'all' && !searching ? 'on' : ''}" data-sec-go="all">${XS.icon('sliders', 15)}<span>${esc(t('bs_all', null, 'All settings'))}</span></button>
                    ${ctx.sections.map((s) => {
                        const n = s.fields.filter((f) => changed(f.key)).length;
                        return `<button class="${section === s.id && !searching ? 'on' : ''}" data-sec-go="${esc(s.id)}">${XS.icon(s.icon, 15)}<span>${esc(sectionLabel(s.id))}</span>${n ? `<em>${n}</em>` : ''}</button>`;
                    }).join('')}
                </div>
                <div>${shown || `<div class="bx-empty">${XS.icon('search', 28)}<b>${esc(t('bs_nothing', null, 'Nothing matches'))}</b><p>${esc(t('bs_nothing_hint', null, 'Try another word, or turn off Only changed.'))}</p></div>`}<div style="height:70px"></div></div>
            </div>
            ${p.length ? `<div class="bx-savebar"><span>${esc(t('bs_pending', { n: p.length }, '%{n} unsaved'))}</span><button class="bx-btn sm ghost" id="bs-discard">${esc(t('builder_discard', null, 'Discard'))}</button><button class="bx-btn sm primary" id="bs-save">${XS.icon('check', 14)}${esc(t('bs_save', null, 'Save changes'))}<span class="bx-kbd">Ctrl S</span></button></div>` : ''}`;
        bind();
        if (scroller) scroller.scrollTop = top;
        if (flash) {
            const hit = el.querySelector(`[data-row="${CSS.escape(flash)}"]`);
            if (hit) hit.scrollIntoView({ block: 'center' });
            flash = null;
        }
        if (onChange) onChange();
    }

    function set(key, value) {
        draft[key] = value;
        if (same(value, ctx.values[key])) delete draft[key];
        render();
    }

    function addTag(key, raw) {
        const def = defOf(key);
        let v = String(raw || '').trim();
        if (!v) return;
        const list = XS.list(current(key)).slice();
        if (def.type === 'nums') {
            const n = Math.round(Number(v));
            if (!Number.isFinite(n)) return;
            const clamped = Math.min(def.max !== undefined ? def.max : n, Math.max(def.min !== undefined ? def.min : n, n));
            if (!list.includes(clamped) && list.length < (def.count || 10)) list.push(clamped);
            list.sort((a, b) => a - b);
        } else {
            if (def.slug) v = v.toLowerCase().replace(/[^a-z0-9_-]/g, '');
            if (v && !list.includes(v) && list.length < (def.max || 20)) list.push(v);
        }
        set(key, list);
        const again = el.querySelector(`[data-tagin="${CSS.escape(key)}"]`);
        if (again) again.focus();
    }

    function clampNum(def, raw) {
        let n = Number(raw);
        if (!Number.isFinite(n)) n = Number(ctx.values[def.key]) || 0;
        if (def.type === 'int') n = Math.round(n);
        else n = Math.round(n / (def.step || 0.1)) * (def.step || 0.1);
        n = Math.round(n * 1000) / 1000;
        if (def.min !== undefined) n = Math.max(def.min, n);
        if (def.max !== undefined) n = Math.min(def.max, n);
        return n;
    }

    function bind() {
        const q = el.querySelector('#bs-q');
        q.addEventListener('input', () => {
            query = q.value.trim().toLowerCase();
            const pos = q.selectionStart;
            render();
            const again = el.querySelector('#bs-q');
            again.focus();
            again.setSelectionRange(pos, pos);
        });
        el.querySelector('#bs-only').addEventListener('click', () => { onlyChanged = !onlyChanged; render(); });
        el.querySelectorAll('[data-sec-go]').forEach((b) => b.addEventListener('click', () => {
            section = b.dataset.secGo;
            query = '';
            onlyChanged = false;
            render();
            const scroller = el.closest('.xsp-scroll');
            if (scroller) scroller.scrollTop = 0;
        }));
        el.querySelectorAll('[data-bool]').forEach((s) => s.addEventListener('click', () => {
            if (s.classList.contains('dis')) return;
            set(s.dataset.bool, !current(s.dataset.bool));
        }));
        el.querySelectorAll('[data-num]').forEach((i) => i.addEventListener('change', () => set(i.dataset.num, clampNum(defOf(i.dataset.num), i.value))));
        el.querySelectorAll('[data-step]').forEach((b) => b.addEventListener('click', () => {
            const def = defOf(b.dataset.step);
            set(def.key, clampNum(def, (Number(current(def.key)) || 0) + Number(b.dataset.dir) * (def.step || 1)));
        }));
        el.querySelectorAll('[data-pct]').forEach((r) => {
            r.addEventListener('input', () => { r.nextElementSibling.textContent = `${r.value}%`; });
            r.addEventListener('change', () => set(r.dataset.pct, Number(r.value)));
        });
        el.querySelectorAll('[data-grade]').forEach((s) => s.addEventListener('change', () => set(s.dataset.grade, Number(s.value))));
        el.querySelectorAll('[data-select]').forEach((s) => s.addEventListener('change', () => set(s.dataset.select, s.value)));
        el.querySelectorAll('[data-text]').forEach((i) => i.addEventListener('change', () => {
            const def = defOf(i.dataset.text);
            let v = i.value.trim();
            if (def.upper) v = v.toUpperCase().replace(/[^A-Z0-9]/g, '');
            if (def.slug) v = v.toLowerCase().replace(/[^a-z0-9_-]/g, '');
            if (!v && !def.empty) { render(); return; }
            set(def.key, v.slice(0, def.max || 64));
        }));
        el.querySelectorAll('[data-itemon]').forEach((s) => s.addEventListener('click', () => {
            if (s.classList.contains('dis')) return;
            const key = s.dataset.itemon;
            const on = current(key) !== false;
            const fallback = ctx.defaults[key] !== false && ctx.defaults[key] ? ctx.defaults[key] : '';
            if (on) set(key, false);
            else if (fallback) set(key, fallback);
            else { draft[key] = ''; render(); const i = el.querySelector(`[data-item="${CSS.escape(key)}"]`); if (i) { i.disabled = false; i.focus(); } }
        }));
        el.querySelectorAll('[data-item]').forEach((i) => i.addEventListener('change', () => {
            const v = i.value.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
            set(i.dataset.item, v || false);
        }));
        el.querySelectorAll('[data-tagin]').forEach((i) => {
            i.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addTag(i.dataset.tagin, i.value); }
                if (e.key === 'Backspace' && !i.value) {
                    const list = XS.list(current(i.dataset.tagin)).slice();
                    if (list.length) { list.pop(); set(i.dataset.tagin, list); const again = el.querySelector(`[data-tagin="${CSS.escape(i.dataset.tagin)}"]`); if (again) again.focus(); }
                }
            });
            i.addEventListener('change', () => { if (i.value) addTag(i.dataset.tagin, i.value); });
        });
        el.querySelectorAll('[data-tags]').forEach((box) => box.addEventListener('click', (e) => { if (e.target === box) { const i = box.querySelector('input'); if (i) i.focus(); } }));
        el.querySelectorAll('[data-untag]').forEach((b) => b.addEventListener('click', () => {
            const list = XS.list(current(b.dataset.untag)).slice();
            list.splice(Number(b.dataset.i), 1);
            const def = defOf(b.dataset.untag);
            if (def.type === 'nums' && !list.length) return XS.toast(t('bs_need_one', null, 'Keep at least one.'), 'error');
            set(b.dataset.untag, list);
        }));
        el.querySelectorAll('[data-seq]').forEach((b) => b.addEventListener('click', () => set(b.dataset.seq, XS.list(current(b.dataset.seq)).concat([b.dataset.v]))));
        el.querySelectorAll('[data-unseq]').forEach((b) => b.addEventListener('click', () => {
            const list = XS.list(current(b.dataset.unseq)).slice();
            if (list.length <= 1) return XS.toast(t('bs_need_one', null, 'Keep at least one.'), 'error');
            list.splice(Number(b.dataset.i), 1);
            set(b.dataset.unseq, list);
        }));
        el.querySelectorAll('[data-reset]').forEach((b) => b.addEventListener('click', () => set(b.dataset.reset, copy(ctx.defaults[b.dataset.reset]))));
        el.querySelectorAll('[data-resetsec]').forEach((b) => b.addEventListener('click', () => {
            const sec = ctx.sections.find((s) => s.id === b.dataset.resetsec);
            sec.fields.forEach((f) => {
                draft[f.key] = copy(ctx.defaults[f.key]);
                if (same(draft[f.key], ctx.values[f.key])) delete draft[f.key];
            });
            render();
        }));
        const discard = el.querySelector('#bs-discard');
        if (discard) discard.addEventListener('click', () => { draft = {}; render(); });
        const save = el.querySelector('#bs-save');
        if (save) save.addEventListener('click', () => XS.BuilderSettings.save());
    }

    XS.BuilderSettings = {
        load(data) {
            const s = data.settings || {};
            ctx = {
                sections: XS.list(s.sections).map((sec) => Object.assign(sec, { fields: XS.list(sec.fields).map((f) => Object.assign(f, { options: XS.list(f.options) })) })),
                values: s.values || {}, defaults: s.defaults || {}, boot: s.boot || {},
                jobs: XS.list(data.jobs), items: XS.list(data.items),
            };
            Object.keys(draft).forEach((k) => { if (same(draft[k], ctx.values[k])) delete draft[k]; });
        },
        mount(target, cb) {
            el = target;
            onChange = cb;
            render();
        },
        unmount() { el = null; },
        fields: () => (ctx ? fields() : []),
        label,
        sectionLabel,
        changedCount: () => (ctx ? fields().filter((f) => changed(f.key)).length : 0),
        isDirty: () => !!ctx && pending().length > 0,
        focus(key) {
            const def = defOf(key);
            if (!def) return;
            section = def.section;
            query = '';
            onlyChanged = false;
            flash = key;
            if (el) render();
        },
        value: (key) => (ctx ? current(key) : undefined),
        async save() {
            const a = document.activeElement;
            if (a && a !== document.body && el && el.contains(a) && a.blur) a.blur();
            if (busy || !ctx) return;
            const keys = pending();
            if (!keys.length) return;
            const changes = {};
            keys.forEach((k) => { changes[k] = draft[k]; });
            busy = true;
            const res = await XS.rpc('builder:settingsSave', { changes, resets: [] });
            busy = false;
            if (!res.ok) return XS.toast(res.error, 'error');
            ctx.values = (res.data && res.data.values) || Object.assign({}, ctx.values, changes);
            ctx.boot = (res.data && res.data.boot) || ctx.boot;
            draft = {};
            XS.toast(t('bs_saved', { n: keys.length }, 'Saved %{n} settings. They are live now.'), 'ok');
            render();
        },
    };
})();

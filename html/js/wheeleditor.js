(() => {
    const t = XS.t;
    const esc = XS.esc;
    let ctx = null;
    let draft = null;
    let saved = null;
    let pageId = 'root';
    let editing = null;
    let dirty = false;
    let busy = false;
    let dragFrom = null;

    const copy = (v) => JSON.parse(JSON.stringify(v));
    const uid = (p) => `${p}${Date.now().toString(36)}${Math.floor(Math.random() * 1e4).toString(36)}`;
    const KINDS = ['command', 'client', 'server'];
    const MAX_PAGES = 12;
    const MAX_CUSTOM = 24;
    const MAX_ITEMS = 12;

    function normalise(layout) {
        const l = copy(layout || {});
        l.pages = XS.list(l.pages).map((p) => Object.assign(p, { items: XS.list(p.items), label: p.label || '' }));
        if (!l.pages.find((p) => p.id === 'root')) l.pages.unshift({ id: 'root', label: '', items: [] });
        l.custom = XS.list(l.custom).map((c) => Object.assign(c, { jobs: XS.list(c.jobs) }));
        if (!l.actions || Array.isArray(l.actions)) l.actions = {};
        Object.values(l.actions).forEach((a) => { a.jobs = XS.list(a.jobs); });
        return l;
    }

    function defs() { return ctx.defs || {}; }
    function page(id) { return draft.pages.find((p) => p.id === id); }
    function custom(id) { return draft.custom.find((c) => c.id === id); }

    function info(ref) {
        if (ref.startsWith('@')) {
            const id = ref.slice(1);
            const p = page(id) || {};
            const base = (defs().pages || {})[id] || {};
            return { ref, kind: 'page', id, label: p.label || t(`wheel_${id}`, null, id), icon: p.icon || base.icon || 'paper' };
        }
        const builtIn = (defs().actions || {})[ref];
        if (builtIn) {
            const o = draft.actions[ref] || {};
            return {
                ref, kind: 'action', id: ref, label: o.label || t(`wheel_${ref}`, null, ref), defaultLabel: t(`wheel_${ref}`, null, ref),
                icon: o.icon || builtIn.icon, danger: !!builtIn.danger, jobs: XS.list(o.jobs), grade: Number(o.grade) || 0,
                off: (defs().off || {})[ref] === false,
            };
        }
        const c = custom(ref);
        if (c) return { ref, kind: 'custom', id: ref, label: c.label, icon: c.icon, danger: !!c.danger, jobs: c.jobs, grade: Number(c.grade) || 0, type: c.kind, value: c.value };
        return null;
    }

    function placed() {
        const set = new Set();
        draft.pages.forEach((p) => p.items.forEach((ref) => set.add(ref)));
        return set;
    }

    function unused() {
        const used = placed();
        const out = { actions: [], custom: [], pages: [] };
        XS.list(defs().order).forEach((id) => { if (!used.has(id)) out.actions.push(info(id)); });
        draft.custom.forEach((c) => { if (!used.has(c.id)) out.custom.push(info(c.id)); });
        draft.pages.forEach((p) => { if (p.id !== 'root' && p.id !== pageId && !used.has(`@${p.id}`)) out.pages.push(info(`@${p.id}`)); });
        return out;
    }

    function reachable() {
        const seen = new Set(['root']);
        const queue = ['root'];
        while (queue.length) {
            const p = page(queue.shift());
            (p ? p.items : []).forEach((ref) => {
                if (ref.startsWith('@') && !seen.has(ref.slice(1))) { seen.add(ref.slice(1)); queue.push(ref.slice(1)); }
            });
        }
        return seen;
    }

    function markDirty() {
        dirty = true;
        const el = ctx.el.querySelector('#we-dirty');
        if (el) { el.className = 'bx-save-state dirty'; el.innerHTML = `<span class="bx-dot warn"></span>${esc(t('builder_unsaved', null, 'Unsaved changes'))}`; }
    }

    function limitsText(i) {
        const parts = [];
        if (i.kind === 'page') parts.push(t('wheel_opens', null, 'Opens a menu'));
        if (i.kind === 'custom') parts.push(`${t(`we_kind_${i.type}`, null, i.type)} · ${i.value}`);
        if (i.jobs && i.jobs.length) parts.push(i.jobs.join(', '));
        if (i.grade) parts.push(t('grade_short', { grade: i.grade }, `Grade ${i.grade}+`));
        if (i.off) parts.push(t('we_off', null, 'Turned off in config'));
        return parts.join(' · ');
    }

    function thumb(icon) {
        return `<span class="we-thumb"><img src="img/wheel/${esc(icon)}.png" alt="" onerror="this.remove()"></span>`;
    }

    function preview() {
        const p = page(pageId);
        const items = p.items.map((ref) => info(ref)).filter(Boolean).filter((i) => !i.off).map((i) => ({ id: i.id, icon: i.icon, label: i.label, page: i.kind === 'page', danger: i.danger }));
        const sel = editing ? items.findIndex((i) => i.id === (editing.startsWith('@') ? editing.slice(1) : editing)) : -1;
        const name = sel >= 0 ? items[sel].label : (pageId === 'root' ? t('wheel_title', null, 'Police') : info(`@${pageId}`).label);
        return `<div class="we-wheel">${XS.wheelRing(items, sel)}<div class="we-hub"><b>${esc(name)}</b><span>${esc(t('we_slots', { n: items.length }, `${items.length} slots`))}</span></div></div>`;
    }

    function iconGrid(current, attr) {
        return `<div class="we-icons">${XS.list(defs().icons).map((ic) => `<button class="we-icon ${ic === current ? 'on' : ''}" ${attr}="${esc(ic)}" title="${esc(ic)}"><img src="img/wheel/${esc(ic)}.png" alt=""></button>`).join('')}</div>`;
    }

    function jobChips(selected) {
        const set = new Set(XS.list(selected));
        return `<div class="bx-jobchips">${XS.list(ctx.jobs).map((j) => `<button class="bx-jobchip ${set.has(j.name) ? 'on' : ''}" data-wej="${esc(j.name)}"><span class="chk">${set.has(j.name) ? XS.icon('check', 11) : ''}</span>${esc(j.label)}</button>`).join('') || `<span class="bx-hint">${esc(t('builder_no_jobs', null, 'No police jobs found in your framework.'))}</span>`}</div>`;
    }

    function gradeSelect(value) {
        const names = {};
        let max = 0;
        XS.list(ctx.jobs).forEach((j) => XS.list(j.grades).forEach((g) => { const n = Number(g.grade) || 0; if (n > max) max = n; if (!names[n]) names[n] = g.label; }));
        if (!Object.keys(names).length) max = 10;
        max = Math.max(max, Number(value) || 0);
        let out = '';
        for (let n = 0; n <= max; n++) out += `<option value="${n}" ${(Number(value) || 0) === n ? 'selected' : ''}>${esc(names[n] ? `${n} · ${names[n]}` : String(n))}${n === 0 ? ` (${esc(t('we_everyone', null, 'everyone'))})` : ''}</option>`;
        return `<select class="bx-input" id="we-grade">${out}</select>`;
    }

    function editorPanel() {
        if (!editing) {
            return `<div class="we-tip">${XS.icon('edit', 20)}<br>${esc(t('we_tip', null, 'Pick an entry on the left to change its name, icon or who sees it.'))}</div>`;
        }
        if (editing.startsWith('@')) {
            const p = page(editing.slice(1));
            const i = info(editing);
            return `<div class="we-edit">
                <div class="we-edit-h">${thumb(i.icon)}<b>${esc(i.label)}</b><span class="bx-chip blue">${esc(t('we_menu', null, 'Menu'))}</span></div>
                <label class="bx-label">${esc(t('builder_label', null, 'Name'))}</label>
                <input class="bx-input" id="we-plabel" maxlength="32" value="${esc(p.label || '')}" placeholder="${esc(t(`wheel_${p.id}`, null, ''))}">
                <label class="bx-label" style="margin-top:14px">${esc(t('builder_blip_icon', null, 'Icon'))}</label>
                ${iconGrid(i.icon, 'data-wepi')}
            </div>`;
        }
        const i = info(editing);
        if (!i) return '';
        const isCustom = i.kind === 'custom';
        return `<div class="we-edit">
            <div class="we-edit-h">${thumb(i.icon)}<b>${esc(i.label)}</b><span class="bx-chip ${isCustom ? 'warn' : 'blue'}">${esc(isCustom ? t('we_custom', null, 'Your action') : t('we_builtin', null, 'Built in'))}</span></div>
            <label class="bx-label">${esc(t('builder_label', null, 'Name'))}</label>
            <input class="bx-input" id="we-label" maxlength="32" value="${esc(isCustom ? i.label : (draft.actions[i.id] || {}).label || '')}" placeholder="${esc(i.defaultLabel || '')}">
            ${isCustom ? `<div class="we-row">
                <div><label class="bx-label">${esc(t('we_does', null, 'Does'))}</label><select class="bx-input" id="we-kind">${KINDS.map((k) => `<option value="${k}" ${k === i.type ? 'selected' : ''}>${esc(t(`we_kind_${k}`, null, k))}</option>`).join('')}</select></div>
                <div style="flex:2"><label class="bx-label">${esc(t(`we_value_${i.type}`, null, 'Value'))}</label><input class="bx-input mono" id="we-value" maxlength="96" value="${esc(i.value || '')}" placeholder="${esc(t(`we_value_${i.type}_hint`, null, ''))}"></div>
            </div>
            <label class="bx-toggle" style="margin-top:12px" id="we-danger"><span class="bx-switch ${i.danger ? 'on' : ''}"></span>${esc(t('we_danger', null, 'Red, like Panic'))}</label>` : ''}
            <label class="bx-label" style="margin-top:14px">${esc(t('builder_blip_icon', null, 'Icon'))}</label>
            ${iconGrid(i.icon, 'data-wei')}
            <label class="bx-label" style="margin-top:14px">${esc(t('we_who', null, 'Departments'))}</label>
            ${jobChips(i.jobs)}
            <div class="bx-hint" style="margin-top:6px">${esc(t('we_who_note', null, 'Leave all unticked for every department.'))}</div>
            <label class="bx-label" style="margin-top:14px">${esc(t('we_grade', null, 'Lowest rank'))}</label>
            ${gradeSelect(i.grade)}
            ${isCustom ? `<div style="margin-top:14px"><button class="bx-btn sm danger" id="we-delcustom">${XS.icon('remove', 14)}${esc(t('we_delete_action', null, 'Delete this action'))}</button></div>` : ''}
        </div>`;
    }

    function render() {
        const el = ctx.el;
        const p = page(pageId) || page('root');
        pageId = p.id;
        const rows = p.items.map((ref, idx) => {
            const i = info(ref);
            if (!i) return '';
            return `<div class="we-item ${editing === ref ? 'on' : ''} ${i.off ? 'off' : ''}" draggable="true" data-idx="${idx}" data-ref="${esc(ref)}">
                <span class="we-grip">⋮⋮</span>${thumb(i.icon)}
                <div class="we-main"><b>${pageId === 'root' && idx < 9 ? `<em class="xp-mono">${idx + 1}</em>` : ''}${esc(i.label)}</b><span>${esc(limitsText(i))}</span></div>
                <button class="bx-tool" data-up="${idx}" ${idx === 0 ? 'disabled' : ''}>↑</button>
                <button class="bx-tool" data-down="${idx}" ${idx === p.items.length - 1 ? 'disabled' : ''}>↓</button>
                <button class="bx-tool danger" data-take="${idx}" title="${esc(t('we_take_off', null, 'Take off the wheel'))}">${XS.icon('close', 13)}</button>
            </div>`;
        }).join('') || `<div class="bx-empty" style="padding:26px">${esc(t('we_empty_page', null, 'Nothing on this menu yet.'))}</div>`;
        const u = unused();
        const options = [
            [t('we_group_actions', null, 'Actions'), u.actions],
            [t('we_group_custom', null, 'Your actions'), u.custom],
            [t('we_group_menus', null, 'Menus'), u.pages],
        ].filter(([, list]) => list.length).map(([label, list]) => `<optgroup label="${esc(label)}">${list.map((i) => `<option value="${esc(i.ref)}">${esc(i.label)}</option>`).join('')}</optgroup>`).join('');
        const live = reachable();
        const tabs = draft.pages.map((pg) => `<button class="bx-tab ${pg.id === pageId ? 'on' : ''} ${live.has(pg.id) ? '' : 'we-loose'}" data-page="${esc(pg.id)}" ${live.has(pg.id) ? '' : `title="${esc(t('we_loose', null, 'Not on the wheel. Add it to a menu or it is dropped on save.'))}"`}>${esc(pg.id === 'root' ? t('we_main', null, 'Main ring') : info(`@${pg.id}`).label)}</button>`).join('');
        el.innerHTML = `<div class="bx-pagehead">
                <div><h1>${esc(t('we_title', null, 'Quick action wheel'))}</h1><p>${esc(t('we_sub', null, 'What officers see on F6, in what order, and who sees what.'))}</p></div>
                <span class="bx-sp"></span>
                <span class="bx-save-state ${dirty ? 'dirty' : ''}" id="we-dirty">${dirty ? `<span class="bx-dot warn"></span>${esc(t('builder_unsaved', null, 'Unsaved changes'))}` : `<span class="bx-dot"></span>${esc(t('builder_saved_state', null, 'All saved'))}`}</span>
                <button class="bx-btn" id="we-reset">${XS.icon('undo', 14)}${esc(t('we_reset', null, 'Reset to default'))}</button>
                <button class="bx-btn primary" id="we-save">${XS.icon('check', 14)}${esc(t('save', null, 'Save'))}<span class="bx-kbd">Ctrl S</span></button>
            </div>
            <div class="we-pages">${tabs}<button class="bx-tab" id="we-newpage" ${draft.pages.length >= MAX_PAGES || p.items.length >= MAX_ITEMS ? 'disabled' : ''}>+ ${esc(t('we_new_menu', null, 'Menu'))}</button></div>
            <div class="we-cols">
                <div class="we-left">
                    ${live.has(pageId) ? '' : `<div class="bx-hint we-warn" style="margin-bottom:10px">${esc(t('we_loose', null, 'Not on the wheel. Add it to a menu or it is dropped on save.'))}</div>`}
                    ${pageId !== 'root' ? `<div style="display:flex;gap:6px;margin-bottom:10px"><button class="bx-btn sm" data-editpage="1">${XS.icon('edit', 13)}${esc(t('we_edit_menu', null, 'Rename or change icon'))}</button><button class="bx-btn sm danger" id="we-delpage">${XS.icon('remove', 13)}${esc(t('we_delete_menu', null, 'Delete this menu'))}</button></div>` : ''}
                    <div class="we-list" id="we-list">${rows}</div>
                    ${pageId === 'root' && p.items.length > 9 ? `<div class="bx-hint we-warn">${esc(t('we_over_nine', null, 'Only the first nine have number keys. The rest are reached by scrolling.'))}</div>` : ''}
                    <div class="we-add">
                        <select class="bx-input" id="we-addsel">${options || `<option value="">${esc(t('we_nothing_left', null, 'Everything is on the wheel'))}</option>`}</select>
                        <button class="bx-btn" id="we-add" ${options && p.items.length < MAX_ITEMS ? '' : 'disabled'}>${XS.icon('plus', 14)}${esc(t('we_add_here', null, 'Add here'))}</button>
                        <button class="bx-btn" id="we-newaction" ${draft.custom.length >= MAX_CUSTOM || p.items.length >= MAX_ITEMS ? 'disabled' : ''}>${XS.icon('plus', 14)}${esc(t('we_new_action', null, 'Your own action'))}</button>
                    </div>
                    ${p.items.length >= MAX_ITEMS ? `<div class="bx-hint we-warn">${esc(t('we_page_full', { n: MAX_ITEMS }, `A menu holds ${MAX_ITEMS} entries.`))}</div>` : ''}
                    <div class="bx-hint" style="margin-top:12px">${esc(t('we_fav_note', { n: defs().favourites }, `Officers can pin up to ${defs().favourites} actions to the front of their own wheel with G.`))}</div>
                </div>
                <div class="we-right">${preview()}${editorPanel()}</div>
            </div>`;
        XS.wheelIcons(el);
        bind(el, p);
        if (ctx.onChange) ctx.onChange();
    }

    function bind(el, p) {
        el.querySelectorAll('[data-page]').forEach((b) => b.addEventListener('click', () => { pageId = b.dataset.page; editing = null; render(); }));
        el.querySelector('#we-newpage').addEventListener('click', () => {
            const id = uid('pg');
            draft.pages.push({ id, label: t('we_new_menu_name', null, 'New menu'), icon: 'paper', items: [] });
            page(pageId).items.push(`@${id}`);
            pageId = id;
            editing = `@${id}`;
            markDirty(); render();
        });
        const delPage = el.querySelector('#we-delpage');
        if (delPage) delPage.addEventListener('click', () => {
            if (!delPage.dataset.sure) { delPage.dataset.sure = '1'; delPage.textContent = t('builder_sure', null, 'Click again to delete'); return; }
            const ref = `@${pageId}`;
            draft.pages.forEach((pg) => { pg.items = pg.items.filter((r) => r !== ref); });
            draft.pages = draft.pages.filter((pg) => pg.id !== pageId);
            pageId = 'root';
            editing = null;
            markDirty(); render();
        });
        const editPage = el.querySelector('[data-editpage]');
        if (editPage) editPage.addEventListener('click', () => { editing = `@${pageId}`; render(); });

        el.querySelectorAll('.we-item').forEach((row) => {
            row.addEventListener('click', (e) => {
                if (e.target.closest('button')) return;
                editing = row.dataset.ref;
                render();
            });
            row.addEventListener('dragstart', (e) => { dragFrom = Number(row.dataset.idx); e.dataTransfer.effectAllowed = 'move'; row.classList.add('drag'); });
            row.addEventListener('dragend', () => row.classList.remove('drag'));
            row.addEventListener('dragover', (e) => { e.preventDefault(); row.classList.add('over'); });
            row.addEventListener('dragleave', () => row.classList.remove('over'));
            row.addEventListener('drop', (e) => {
                e.preventDefault();
                const to = Number(row.dataset.idx);
                if (dragFrom === null || dragFrom === to) return;
                const [moved] = p.items.splice(dragFrom, 1);
                p.items.splice(to, 0, moved);
                dragFrom = null;
                markDirty(); render();
            });
        });
        const swap = (a, b) => { const tmp = p.items[a]; p.items[a] = p.items[b]; p.items[b] = tmp; markDirty(); render(); };
        el.querySelectorAll('[data-up]').forEach((b) => b.addEventListener('click', () => { const i = Number(b.dataset.up); if (i > 0) swap(i, i - 1); }));
        el.querySelectorAll('[data-down]').forEach((b) => b.addEventListener('click', () => { const i = Number(b.dataset.down); if (i < p.items.length - 1) swap(i, i + 1); }));
        el.querySelectorAll('[data-take]').forEach((b) => b.addEventListener('click', () => {
            const [ref] = p.items.splice(Number(b.dataset.take), 1);
            if (editing === ref) editing = null;
            markDirty(); render();
        }));
        el.querySelector('#we-add').addEventListener('click', () => {
            const ref = el.querySelector('#we-addsel').value;
            if (!ref) return;
            p.items.push(ref);
            editing = ref;
            markDirty(); render();
        });
        el.querySelector('#we-newaction').addEventListener('click', () => {
            const id = uid('x');
            draft.custom.push({ id, label: t('we_new_action_name', null, 'New action'), icon: 'paper', kind: 'command', value: '', jobs: [], grade: 0, danger: false });
            p.items.push(id);
            editing = id;
            markDirty(); render();
        });

        const ensureOverride = (id) => { draft.actions[id] = draft.actions[id] || { label: '', jobs: [], grade: 0 }; return draft.actions[id]; };
        const target = () => {
            if (!editing || editing.startsWith('@')) return null;
            return custom(editing) || ensureOverride(editing);
        };
        const label = el.querySelector('#we-label');
        if (label) label.addEventListener('change', () => {
            const tg = target();
            tg.label = label.value.trim() || (custom(editing) ? tg.label : '');
            markDirty(); render();
        });
        el.querySelectorAll('[data-wei]').forEach((b) => b.addEventListener('click', () => { target().icon = b.dataset.wei; markDirty(); render(); }));
        el.querySelectorAll('[data-wej]').forEach((c) => c.addEventListener('click', () => {
            const tg = target();
            const set = new Set(XS.list(tg.jobs));
            if (!set.has(c.dataset.wej)) set.add(c.dataset.wej); else set.delete(c.dataset.wej);
            tg.jobs = Array.from(set);
            markDirty(); render();
        }));
        const grade = el.querySelector('#we-grade');
        if (grade) grade.addEventListener('change', () => { target().grade = Math.max(0, Math.min(50, Math.floor(Number(grade.value) || 0))); markDirty(); render(); });
        const kind = el.querySelector('#we-kind');
        if (kind) kind.addEventListener('change', () => { target().kind = kind.value; markDirty(); render(); });
        const value = el.querySelector('#we-value');
        if (value) value.addEventListener('change', () => { target().value = value.value.trim(); markDirty(); render(); });
        const danger = el.querySelector('#we-danger');
        if (danger) danger.addEventListener('click', () => { target().danger = !target().danger; markDirty(); render(); });
        const delCustom = el.querySelector('#we-delcustom');
        if (delCustom) delCustom.addEventListener('click', () => {
            if (!delCustom.dataset.sure) { delCustom.dataset.sure = '1'; delCustom.textContent = t('builder_sure', null, 'Click again to delete'); return; }
            const id = editing;
            draft.custom = draft.custom.filter((c) => c.id !== id);
            draft.pages.forEach((pg) => { pg.items = pg.items.filter((r) => r !== id); });
            editing = null;
            markDirty(); render();
        });
        const plabel = el.querySelector('#we-plabel');
        if (plabel) plabel.addEventListener('change', () => {
            const pg = page(editing.slice(1));
            const builtIn = !!(defs().pages || {})[pg.id];
            pg.label = plabel.value.trim() || (builtIn ? '' : pg.label);
            markDirty(); render();
        });
        el.querySelectorAll('[data-wepi]').forEach((b) => b.addEventListener('click', () => { page(editing.slice(1)).icon = b.dataset.wepi; markDirty(); render(); }));

        el.querySelector('#we-save').addEventListener('click', async () => {
            if (busy) return;
            const missing = draft.custom.find((c) => !String(c.value || '').trim());
            if (missing) { editing = missing.id; render(); return XS.toast(t('we_need_value', { name: missing.label }, `${missing.label} needs a command or event.`), 'error'); }
            busy = true;
            const res = await XS.rpc('builder:wheelSave', draft);
            busy = false;
            if (!res.ok) return XS.toast(res.error, 'error');
            saved = normalise(res.data);
            draft = normalise(res.data);
            dirty = false;
            if (!page(pageId)) pageId = 'root';
            XS.toast(t('we_saved', null, 'Wheel saved. Officers see it straight away.'), 'ok');
            render();
        });
        const reset = el.querySelector('#we-reset');
        reset.addEventListener('click', async () => {
            if (!reset.dataset.sure) { reset.dataset.sure = '1'; reset.textContent = t('we_reset_sure', null, 'Click again to reset'); return; }
            const res = await XS.rpc('builder:wheelReset', {});
            if (!res.ok) return XS.toast(res.error, 'error');
            saved = normalise(res.data);
            draft = normalise(res.data);
            dirty = false;
            pageId = 'root';
            editing = null;
            XS.toast(t('we_reset_done', null, 'Back to the default wheel.'), 'ok');
            render();
        });
    }

    XS.WheelEditor = {
        load(data) {
            saved = normalise(data.wheel);
            if (!dirty) draft = normalise(data.wheel);
            ctx = Object.assign(ctx || {}, { defs: data.wheelDefs || {}, jobs: XS.list(data.jobs) });
        },
        mount(el, onChange) {
            ctx.el = el;
            ctx.onChange = onChange;
            if (!draft) draft = normalise(saved);
            render();
        },
        count() {
            return draft ? draft.pages.reduce((n, p) => n + p.items.filter((r) => !r.startsWith('@')).length, 0) : 0;
        },
        isDirty: () => dirty,
        save() { const b = ctx && ctx.el && ctx.el.querySelector('#we-save'); if (b) b.click(); },
    };
})();

(() => {
    const root = document.getElementById('xsp-fieldnote');
    const t = XS.t;
    const esc = XS.esc;
    let shown = null;

    const ICON = { casing: 'ammo', blood: 'gsr', print: 'fingerprint' };
    const GROUP = { pistol: 'note_group_pistol', smg: 'note_group_smg', rifle: 'note_group_rifle', mg: 'note_group_mg', shotgun: 'note_group_shotgun', sniper: 'note_group_sniper' };

    function age(kind, seconds) {
        const m = seconds / 60;
        if (kind === 'blood') {
            if (m < 3) return [t('note_blood_wet', null, 'Still wet'), 'fresh'];
            if (m < 15) return [t('note_blood_drying', null, 'Drying at the edges'), 'mid'];
            return [t('note_blood_dry', null, 'Dried dark'), 'old'];
        }
        if (kind === 'casing') {
            if (m < 5) return [t('note_casing_warm', null, 'Still warm'), 'fresh'];
            if (m < 20) return [t('note_casing_minutes', null, 'Fired in the last few minutes'), 'mid'];
            return [t('note_casing_old', null, 'Been lying here a while'), 'old'];
        }
        if (m < 10) return [t('note_print_fresh', null, 'Sharp, recently left'), 'fresh'];
        return [t('note_print_old', null, 'Faded'), 'old'];
    }

    function facts(d) {
        const out = [];
        const [when, tone] = age(d.kind, Number(d.age) || 0);
        out.push(`<li class="${tone}">${XS.icon('clock', 13)}${esc(when)}</li>`);
        if (d.kind === 'casing') {
            if (d.group && GROUP[d.group]) out.push(`<li>${XS.icon('gun', 13)}${esc(t(GROUP[d.group], null, d.group))}</li>`);
            out.push(`<li>${XS.icon('ammo', 13)}${esc(t('note_casing_count', { n: Number(d.count) || 1 }, '%{n} on the ground'))}</li>`);
            if (d.marked) out.push(`<li class="hit">${XS.icon('fingerprint', 13)}${esc(t('note_casing_print', null, 'A print on one of them'))}</li>`);
        } else if (d.kind === 'blood') {
            const n = Number(d.count) || 1;
            out.push(`<li>${XS.icon('gsr', 13)}${esc(n >= 6 ? t('note_blood_pool', null, 'A lot of it, someone bled here') : n >= 3 ? t('note_blood_spatter', null, 'Spatter and drops') : t('note_blood_drops', null, 'A few drops'))}</li>`);
            out.push(`<li class="dim">${XS.icon('info', 13)}${esc(t('note_blood_lab', null, 'Blood type and DNA need the lab'))}</li>`);
        } else {
            const q = Number(d.quality) || 60;
            out.push(`<li class="${q >= 75 ? 'hit' : ''}">${XS.icon('fingerprint', 13)}${esc(q >= 75 ? t('note_print_full', null, 'Clear enough to match') : t('note_print_partial', null, 'Partial, might still match'))}</li>`);
        }
        return out.join('');
    }

    function render(d) {
        const title = d.kind === 'casing' ? (d.calibre || t('evidence_casing', null, 'Bullet casing')) : d.kind === 'blood' ? t('evidence_blood', null, 'Blood') : t('evidence_print', null, 'Fingerprint');
        root.innerHTML = `<div class="fn fn-${esc(d.kind)}">
            <div class="fn-tape"><span>${esc(t('note_tape', null, 'EVIDENCE · DO NOT CROSS'))}</span></div>
            <div class="fn-body"><span class="fn-ico">${XS.icon(ICON[d.kind] || 'box', 22)}</span>
                <div class="fn-main"><small>${esc(t('note_kicker', null, 'Field note'))}</small><b>${esc(title)}</b><ul>${facts(d)}</ul></div></div>
            ${d.reach ? `<div class="fn-key"><span class="xp-kbd">E</span>${esc(t('note_bag', null, 'Bag it'))}</div>` : `<div class="fn-key dim">${esc(t('note_closer', null, 'Get closer to bag it'))}</div>`}
        </div>`;
    }

    XS.apps.fieldnote = {
        on(action, data) {
            if (action === 'show') {
                const key = JSON.stringify(data || {});
                if (key === shown) return;
                shown = key;
                render(data || {});
                root.classList.remove('xsp-hidden');
            } else if (action === 'hide') {
                shown = null;
                root.classList.add('xsp-hidden');
            }
        },
    };
})();

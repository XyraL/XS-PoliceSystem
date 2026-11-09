(() => {
    const root = document.getElementById('xsp-idcard');
    const t = XS.t;
    const esc = XS.esc;
    let open = false;

    const SILHOUETTE = '<svg viewBox="0 0 100 120" width="100%" height="100%" aria-hidden="true"><rect width="100" height="120" fill="#c9d3dd"/><circle cx="50" cy="44" r="21" fill="#9aa8b6"/><path d="M12 120c4-27 20-40 38-40s34 13 38 40z" fill="#9aa8b6"/></svg>';

    function render(card) {
        const stage = XS.stage(root);
        const last = (card.lastname || '').toUpperCase();
        const first = (card.firstname || '').toUpperCase();
        stage.innerHTML = `<div class="idc-wrap">
            <div class="idc">
                <div class="idc-top"><span class="idc-state">${esc(t('id_state', null, 'San Andreas'))}</span><span class="idc-type">${esc(t('id_type', null, 'Identification card'))}</span></div>
                <div class="idc-body">
                    <div class="idc-photo">${card.photo ? `<img src="${esc(card.photo)}" alt="">` : SILHOUETTE}<span class="idc-ghost">${SILHOUETTE}</span></div>
                    <div class="idc-fields">
                        <div class="idc-num"><small>${esc(t('id_number', null, 'ID'))}</small><b>${esc(card.citizenid || '')}</b></div>
                        <div class="idc-name"><span>${esc(last)}</span><span>${esc(first)}</span></div>
                        <div class="idc-grid">
                            <div><small>${esc(t('id_dob', null, 'DOB'))}</small><b>${esc(card.dob || '')}</b></div>
                            <div><small>${esc(t('id_sex', null, 'Sex'))}</small><b>${esc(card.female ? 'F' : 'M')}</b></div>
                            <div class="idc-wide"><small>${esc(t('id_nationality', null, 'Nationality'))}</small><b>${esc(card.nationality || '')}</b></div>
                        </div>
                        <div class="idc-lic">
                            <span class="${card.driver ? 'ok' : 'no'}">${esc(t('id_driver', null, 'Driver'))}</span>
                            <span class="${card.weapon ? 'ok' : 'no'}">${esc(t('id_weapon', null, 'Firearm'))}</span>
                        </div>
                    </div>
                </div>
                <div class="idc-foot"><span class="idc-sign">${esc(card.firstname || '')} ${esc(card.lastname || '')}</span><span class="idc-seal"></span></div>
                ${card.jailed ? `<div class="idc-stamp">${esc(t('id_in_custody', null, 'In custody'))}</div>` : ''}
                ${card.wanted ? `<div class="idc-stamp idc-wanted">${esc(t('id_wanted', { count: card.wanted }, 'Wanted'))}</div>` : ''}
            </div>
            <div class="idc-hint"><i class="xp-kbd">Esc</i>${esc(t('close', null, 'Close'))}</div>
        </div>`;
        stage.querySelector('.idc-wrap').addEventListener('click', () => XS.close('idcard'));
    }

    XS.apps.idcard = {
        isOpen: () => open,
        escape: () => XS.close('idcard'),
        on(action, data) {
            if (action === 'open') {
                open = true;
                XS.show('xsp-idcard', true);
                render(data || {});
            } else if (action === 'close') {
                open = false;
                XS.show('xsp-idcard', false);
            }
        },
    };
})();

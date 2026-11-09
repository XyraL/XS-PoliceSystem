(() => {
    const root = document.getElementById('xsp-tests');
    const t = XS.t;
    const esc = XS.esc;
    let open = false;
    const DRUGS = ['thc', 'coc', 'met', 'opi'];

    function breath(test) {
        const bac = Number(test.bac) || 0;
        const limit = Number(test.limit) || 0.08;
        const over = bac >= limit;
        return `<div class="bt">
            <div class="bt-tube"><i></i></div>
            <div class="bt-body">
                <div class="bt-brand">ALCO<b>SCAN</b> 7</div>
                <div class="bt-lcd ${over ? 'over' : ''}">
                    <div class="bt-row"><span>${esc(t('test_bac', null, 'BAC'))}</span><span>${esc(t('test_limit', { limit: limit.toFixed(2) }, `Limit ${limit.toFixed(2)}`))}</span></div>
                    <div class="bt-num"><em>8.888</em><b id="bt-val">0.000</b></div>
                    <div class="bt-unit">g/210L</div>
                    <div class="bt-verdict">${esc(over ? t('test_over', null, 'Over the limit') : t('test_under', null, 'Under the limit'))}</div>
                </div>
                <div class="bt-keys"><i></i><i class="go"></i><i></i></div>
                <div class="bt-grip"></div>
            </div>
            <div class="bt-name">${esc(t('test_subject', null, 'Subject'))} · ${esc(test.name || '')}</div>
        </div>`;
    }

    function drugs(test) {
        const results = test.results || {};
        const lanes = DRUGS.map((d) => {
            const pos = results[d] === true;
            return `<div class="dt-lane ${pos ? 'pos' : 'neg'}">
                <b>${esc(t(`test_${d}`, null, d.toUpperCase()))}</b>
                <div class="dt-win"><i class="dt-c"></i>${pos ? '' : '<i class="dt-t"></i>'}<span class="dt-lab c">C</span><span class="dt-lab t">T</span></div>
            </div>`;
        }).join('');
        const legend = DRUGS.map((d) => {
            const pos = results[d] === true;
            return `<div class="dt-res ${pos ? 'pos' : 'neg'}"><span>${esc(t(`test_drug_${d}`, null, d))}</span><b>${esc(pos ? t('test_positive', null, 'Positive') : t('test_negative', null, 'Negative'))}</b></div>`;
        }).join('');
        return `<div class="dt">
            <div class="dt-cassette">
                <div class="dt-swab"><i></i></div>
                <div class="dt-head">ORAL FLUID · 4 PANEL</div>
                <div class="dt-lanes">${lanes}</div>
                <div class="dt-well"><i></i></div>
                <div class="dt-lot">LOT 24-0917 · EXP 2027-03</div>
            </div>
            <div class="dt-card">
                <div class="dt-card-h"><b>${esc(t('test_drug_title', null, 'Oral fluid drug test'))}</b><span>${esc(test.name || '')}</span></div>
                ${legend}
            </div>
        </div>`;
    }

    function render(test) {
        const stage = XS.stage(root);
        stage.innerHTML = `<div class="ts-wrap">${test.kind === 'drugs' ? drugs(test) : breath(test)}
            <div class="ts-hint"><i class="xp-kbd">Esc</i>${esc(t('close', null, 'Close'))}</div></div>`;
        stage.querySelector('.ts-wrap').addEventListener('click', () => XS.close('tests'));
        if (test.kind !== 'drugs') {
            const el = stage.querySelector('#bt-val');
            const target = Number(test.bac) || 0;
            const started = performance.now();
            const tick = (now) => {
                const p = Math.min(1, (now - started) / 1300);
                el.textContent = (target * (1 - Math.pow(1 - p, 3))).toFixed(3);
                if (p < 1 && open) requestAnimationFrame(tick);
            };
            requestAnimationFrame(tick);
        }
    }

    XS.apps.tests = {
        isOpen: () => open,
        escape: () => XS.close('tests'),
        on(action, data) {
            if (action === 'open') {
                open = true;
                XS.show('xsp-tests', true);
                render(data || {});
            } else if (action === 'close') {
                open = false;
                XS.show('xsp-tests', false);
            }
        },
    };
})();

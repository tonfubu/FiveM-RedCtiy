(function () {
    const RING_CIRC = 213.6; // 2*pi*34
    let maxSpeed = 220;

    let targetSpeed = 0;
    let shownSpeed = 0;
    let rafActive = false;

    const $ = (id) => document.getElementById(id);
    const hud = $('hud');

    function show() {
        hud.classList.remove('hidden');
        hud.classList.add('visible');
    }
    function hide() {
        hud.classList.remove('visible');
        hud.classList.add('hidden');
    }

    function setStat(el, state) {
        el.classList.remove('active', 'accent', 'warn');
        if (state) el.classList.add(state);
    }

    // smooth speed animation
    function animate() {
        const diff = targetSpeed - shownSpeed;
        if (Math.abs(diff) < 0.5) {
            shownSpeed = targetSpeed;
        } else {
            shownSpeed += diff * 0.25;
        }
        const s = Math.round(shownSpeed);
        $('speed').textContent = s;

        const frac = Math.max(0, Math.min(1, shownSpeed / maxSpeed));
        $('ringProg').style.strokeDashoffset = (RING_CIRC * (1 - frac)).toFixed(1);
        // ring turns danger-red near top speed
        $('ringProg').style.stroke = frac > 0.92 ? 'var(--danger)' : 'var(--accent)';

        if (shownSpeed !== targetSpeed) {
            requestAnimationFrame(animate);
        } else {
            rafActive = false;
        }
    }
    function kick() {
        if (!rafActive) { rafActive = true; requestAnimationFrame(animate); }
    }

    function update(d) {
        // speed + gear
        targetSpeed = d.speed || 0;
        kick();
        $('gear').textContent = d.gear != null ? d.gear : 'N';
        if (d.maxSpeed) maxSpeed = d.maxSpeed;

        // street / direction
        $('direction').textContent = d.directionText || d.direction || '';
        $('dirLetter').textContent = d.direction || '';
        $('street').textContent = (d.street && d.street.length) ? d.street : 'Unknown Street';

        // voice
        let vEl = $('st-voice');
        if (d.talking) {
            setStat(vEl, d.voiceMode === 'shout' ? 'warn' : 'accent');
        } else {
            setStat(vEl, null);
        }

        // seatbelt: on=accent, off+fast=warn, off=muted
        let bEl = $('st-belt');
        if (d.seatbelt) setStat(bEl, 'accent');
        else if ((d.speed || 0) > 60) setStat(bEl, 'warn');
        else setStat(bEl, null);

        // lock
        setStat($('st-lock'), d.locked ? 'accent' : null);

        // engine
        let eEl = $('st-engine');
        if (d.engineWarn) setStat(eEl, 'warn');
        else if (d.engine) setStat(eEl, 'active');
        else setStat(eEl, null);

        // fuel
        let fEl = $('st-fuel');
        $('fuelVal').textContent = (d.fuel != null ? d.fuel : '--') + '%';
        if (d.fuelWarn) setStat(fEl, 'warn');
        else setStat(fEl, 'active');
    }

    window.addEventListener('message', function (e) {
        const msg = e.data || {};
        switch (msg.action) {
            case 'show':   show(); break;
            case 'hide':   hide(); break;
            case 'update': update(msg.data || {}); break;
            case 'config':
                if (msg.data && msg.data.maxSpeed) maxSpeed = msg.data.maxSpeed;
                if (msg.data && msg.data.units) $('unit').textContent = msg.data.units;
                break;
        }
    });
})();

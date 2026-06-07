const $ = (id) => document.getElementById(id);
const rootStyle = document.documentElement.style;
const circumference = 194.78;
let alertTimer = null;
let audioCtx = null;

function toggle(el, visible) {
    el.classList.toggle('hidden', !visible);
}

function setClass(el, classes) {
    el.className = classes;
}

function setWidth(id, value) {
    $(id).style.width = `${Math.max(0, Math.min(100, Number(value) || 0))}%`;
}

function healthColor(value, inverse) {
    value = Number(value) || 0;
    if (inverse) {
        if (value >= 75) return '#FF4D4D';
        if (value >= 45) return '#C084FC';
        return '#22C55E';
    }
    if (value <= 12) return '#FF4D4D';
    if (value <= 30) return '#FB923C';
    if (value <= 60) return '#FFD21F';
    return '#22C55E';
}

function updateVoice(voice) {
    if (!voice) return;
    const label = voice.label || voice.name || 'Normal';
    const color = voice.color || '#FFD21F';
    $('voiceChip').textContent = label;
    $('voiceChip').style.color = color;
    $('voiceChip').classList.toggle('talking', !!voice.talking);
    $('playerVoice').textContent = `[P] ${label}`;
    $('playerVoice').style.color = color;
    $('micStat').style.color = color;
    $('micStat').classList.toggle('talking', !!voice.talking);
}

function updateVehicle(data) {
    $('direction').textContent = data.directionText || data.direction || 'NORTH';
    $('street').textContent = data.street || 'Unknown Road';
    $('speed').textContent = Number(data.speed || 0);
    $('gear').textContent = data.gear || 'N';
    $('fuel').textContent = `${Number(data.fuel || 0)}%`;

    const speedRatio = Math.min(Number(data.speed || 0) / Number(data.maxSpeed || 240), 1);
    $('speedRing').style.strokeDashoffset = circumference - (circumference * speedRatio);
    $('speedRing').style.stroke = speedRatio > .82 ? '#FF4D4D' : '#FFD21F';

    const durability = Number(data.durability || 0);
    $('durability').textContent = `${durability}%`;
    setWidth('durabilityBar', durability);
    $('durabilityBar').style.background = healthColor(durability);

    setClass($('fuelStat'), `stat ${data.fuelWarn ? 'warn pulse' : 'accent'}`);
    setClass($('durabilityStat'), `stat durability ${data.engineWarn ? 'warn' : 'ok'}`);
    setClass($('engineStat'), `stat icon-only ${data.engineFailed ? 'warn pulse' : (data.engine ? 'ok' : 'warn')}`);
    $('engineStat').textContent = data.engineFailed ? 'FAIL' : (data.engine ? 'ENG' : 'OFF');
    setClass($('lockStat'), `stat icon-only ${data.locked ? 'accent' : ''}`);
    $('lockStat').textContent = data.locked ? 'LOCK' : 'OPEN';
    setClass($('beltStat'), `stat icon-only belt ${data.seatbelt ? 'ok' : (data.seatbeltWarn ? 'warn pulse' : '')}`);
    $('beltStat').textContent = data.seatbelt ? 'BELT' : 'NO BELT';
    updateVoice(data.voice);
}

function setCirclePercent(el, value) {
    const deg = Math.max(0, Math.min(100, Number(value) || 0)) * 3.6;
    el.style.setProperty('--percent', deg + 'deg');
}

function updateStatus(data) {
    const hp = Math.max(0, Math.min(100, Number(data.hp || 0)));
    const armor = Math.max(0, Math.min(100, Number(data.armor || 0)));
    const hunger = Number(data.hunger == null ? 100 : data.hunger);
    const stress = Number(data.stress || 0);
    setWidth('hpBar', hp);
    setWidth('armorBar', armor);
    $('hpText').textContent = Math.round(hp) + '%';
    $('hungerText').textContent = Math.round(hunger);
    $('stressText').textContent = Math.round(stress);
    setCirclePercent($('hungerCircle'), hunger);
    setCirclePercent($('stressCircle'), stress);
    $('statusHud').classList.toggle('dead', !!data.dead || hp <= 0);
}

function showAlert(text) {
    $('alertBox').textContent = text || 'WARNING';
    toggle($('alertBox'), true);
    clearTimeout(alertTimer);
    alertTimer = setTimeout(() => toggle($('alertBox'), false), 3000);
}

function playSound(name) {
    const audio = $(name);
    if (!audio) return fallbackTone(name);
    audio.volume = name === 'seatbelt_warning' ? 0.18 : 0.22;
    audio.currentTime = 0;
    audio.play().catch(() => fallbackTone(name));
}

function fallbackTone(name) {
    try {
        audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        const freq = name === 'seatbelt_on' ? 880 : (name === 'seatbelt_off' ? 420 : 660);
        osc.type = 'sine';
        osc.frequency.value = freq;
        gain.gain.setValueAtTime(0.001, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(name === 'seatbelt_warning' ? 0.045 : 0.035, audioCtx.currentTime + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.16);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.18);
    } catch (_) {}
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'config') {
        if (msg.hud && msg.hud.Scale) rootStyle.setProperty('--scale', msg.hud.Scale);
        return;
    }
    if (msg.action === 'vehicleVisible') {
        toggle($('vehicleHud'), !!msg.visible);
        return;
    }
    if (msg.action === 'playerVisible') {
        toggle($('playerInfo'), !!msg.visible);
        return;
    }
    if (msg.action === 'vehicle') {
        updateVehicle(msg);
        return;
    }
    if (msg.action === 'playerInfo') {
        $('playerId').textContent = msg.id || 0;
        $('dateText').textContent = msg.date || '--/--/--';
        $('timeText').textContent = msg.time || '--:--';
        updateVoice(msg.voice);
        return;
    }
    if (msg.action === 'status') {
        updateStatus(msg);
        return;
    }
    if (msg.action === 'sound') {
        playSound(msg.name);
        return;
    }
    if (msg.action === 'seatbelt') {
        $('beltStat').classList.toggle('ok', !!msg.enabled);
        return;
    }
    if (msg.action === 'voiceFlash') {
        updateVoice(msg.voice);
        return;
    }
    if (msg.action === 'alert') {
        showAlert(msg.text);
        return;
    }
    if (msg.action === 'refuel') {
        toggle($('refuelBox'), !!msg.active);
        if (msg.progress != null) setWidth('refuelBar', msg.progress);
    }
});

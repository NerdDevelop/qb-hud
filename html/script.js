// NERD HUD - NUI controller. Listens for messages from client.lua.

const $  = (s, c = document) => c.querySelector(s);
const $$ = (s, c = document) => [...c.querySelectorAll(s)];

const SPEEDO_CIRC = 157.08; // π × 50 (half-arc length)
const RESOURCE = (typeof GetParentResourceName !== 'undefined') ? GetParentResourceName() : 'nerd-hud';

const state = {
    health: 100, armor: 0, hunger: 100, thirst: 100,
    stamina: 100, oxygen: 100, mic: 0, micOn: true, voiceMode: 2,
    stress: 0, parachute: false, seatbelt: false,
    speed: 0, fuel: 100, engine: 100,
    inVehicle: false, useMPH: false, maxSpeed: 350
};

let settings = {
    colors: {
        health: '#FF3B30', armor: '#00A3FF', hunger: '#FFB800',
        thirst: '#06B6D4', stamina: '#00D26A', mic: '#ED0246', brand: '#ED0246'
    },
    positions: {},
    hidden: { compass: false, stats: false },
    effects: { crit: true, mic: true, glow: 100, opacity: 85 },
    minimapMode: 'vehicle',   // 'vehicle' = show only in a car, 'always' = always visible
    cinemaMode: false,        // letterbox bars + hidden HUD for cinematic shots
    scale: 100,           // global scale (the slider)
    elementScales: {}     // per-element scale, e.g. { compass: 1.2, speedo: 0.9, ... }
};

// hud update functions
function updateStat(name, value) {
    state[name] = Math.max(0, Math.min(100, value));
    const stat = $(`.stat[data-stat="${name}"]`);
    if (!stat) return;
    const fill = stat.querySelector('.stat__fill');
    const valueEl = stat.querySelector('.stat__value');
    fill.style.width = state[name] + '%';
    valueEl.textContent = name === 'mic' ? (state.micOn ? 'ON' : 'OFF')
                       : name === 'parachute' ? 'ON'
                       : Math.round(state[name]);

    // crit: most stats highlight when low, stress highlights when high
    if (settings.effects.crit) {
        if (name === 'stress') {
            stat.classList.toggle('is-critical', state[name] > 75);
        } else if (name !== 'mic' && name !== 'parachute') {
            stat.classList.toggle('is-critical', state[name] > 0 && state[name] < 25);
        }
    } else {
        stat.classList.remove('is-critical');
    }

    const tip = stat.querySelector('.stat__tip');
    if (tip && name !== 'mic' && name !== 'parachute') tip.textContent = `${name.toUpperCase()} · ${Math.round(state[name])}%`;
    else if (tip && name === 'mic') tip.textContent = `MIC · ${state.micOn ? 'ON' : 'OFF'}`;
    else if (tip && name === 'parachute') tip.textContent = 'PARACHUTE · ON';
}

// qb-hud-style: hide stats that aren't in use
function setStatVisible(name, visible) {
    const stat = $(`.stat[data-stat="${name}"]`);
    if (stat) stat.style.display = visible ? '' : 'none';
}

function setStress(value) {
    state.stress = value;
    if (value > 0) {
        setStatVisible('stress', true);
        updateStat('stress', value);
    } else {
        updateStat('stress', 0);
        setStatVisible('stress', false);
    }
}

function setParachute(on) {
    state.parachute = on;
    setStatVisible('parachute', on);
    if (on) updateStat('parachute', 100);
}

function setSeatbelt(buckled) {
    state.seatbelt = buckled;
    const beltItem = $('#seatbelt-item');
    if (beltItem) {
        beltItem.classList.toggle('is-on', buckled);
        beltItem.classList.toggle('is-off', !buckled);
    }
}

function updateSpeed(value) {
    state.speed = value;
    const valueEl = $('#speedo-value');
    if (valueEl) valueEl.textContent = Math.round(value);

    // V2: Segmented bar
    const segments = document.querySelectorAll('.speedo .seg');
    if (segments.length > 0) {
        const pct = Math.min(value, state.maxSpeed) / state.maxSpeed;
        const filled = Math.round(pct * segments.length);
        segments.forEach((seg, i) => {
            const isOn = i < filled;
            seg.classList.toggle('is-on', isOn);
            seg.classList.toggle('is-edge', isOn && i === filled - 1);
        });
    }

    // Backward compat with old half-arc design (if still present)
    const fill = $('.speedo__fill');
    if (fill) {
        const offset = SPEEDO_CIRC * (1 - Math.min(value, state.maxSpeed) / state.maxSpeed);
        fill.style.strokeDashoffset = offset;
    }
}

function updateGear(label) {
    const gearEl = $('#speedo-gear');
    if (gearEl && label) gearEl.textContent = label;
}

function updateFuel(value) {
    state.fuel = value;
    const v = Math.max(0, Math.min(100, Number(value) || 0));

    // Existing vinfo fuel item (icon + number)
    const item = $('#fuel-item');
    const valueEl = $('#fuel-value');
    if (item && valueEl) {
        valueEl.textContent = Math.round(v);
        item.classList.remove('is-good', 'is-warning', 'is-critical');
        if (v > 30) item.classList.add('is-good');
        else if (v > 10) item.classList.add('is-warning');
        else item.classList.add('is-critical');
    }

    // NEW: single skewed parallelogram fuel bar
    const fuelFill = $('#speedo-fuel-fill');
    if (fuelFill) {
        fuelFill.style.width = v + '%';
        fuelFill.classList.remove('is-warning', 'is-critical');
        if (v <= 10)      fuelFill.classList.add('is-critical');
        else if (v <= 30) fuelFill.classList.add('is-warning');
    }
}

function updateEngine(value) {
    state.engine = value;
    const item = $('#engine-item');
    const valueEl = $('#engine-value');
    if (!item || !valueEl) return;
    valueEl.textContent = Math.round(value);

    // Hide engine when at 95%+ (no damage), show only when damaged
    if (value >= 95) {
        item.style.display = 'none';
        return;
    }
    item.style.display = '';

    item.classList.remove('is-good', 'is-warning', 'is-critical');
    if (value > 50) item.classList.add('is-good');
    else if (value > 20) item.classList.add('is-warning');
    else item.classList.add('is-critical');
}

function updateHeading(deg) {
    $('#compass-heading').textContent = Math.round(deg) + '°';
}

function updateStreet(street, zone) {
    if (street) $('#street-name').textContent = street;
    if (zone) $('#zone-name').textContent = zone;
}

function setMicOn(on, mode) {
    state.micOn = !!on;
    state.voiceMode = mode || 2;

    const micEl = $('#stat-mic');
    const valueEl = micEl.querySelector('.stat__value');
    const tipEl = micEl.querySelector('.stat__tip');

    // pma-voice modes: 1=Whisper, 2=Normal, 3=Shout
    const modeNames = ['', 'WHISPER', 'NORMAL', 'SHOUT'];
    const fillLevels = [0, 33, 66, 100];

    const fill = micEl.querySelector('.stat__fill');
    fill.style.width = (state.micOn ? fillLevels[state.voiceMode] : 0) + '%';

    if (state.micOn) {
        // Just show the mode number (1, 2, or 3)
        valueEl.textContent = state.voiceMode;
        tipEl.textContent = 'VOICE · ' + (modeNames[state.voiceMode] || 'NORMAL');
    } else {
        valueEl.textContent = '0';
        tipEl.textContent = 'VOICE · OFF';
    }
}

function setMicTalking(talking) {
    if (!state.micOn) return;
    const micEl = $('#stat-mic');
    micEl.classList.toggle('is-talking', talking);

    // Pulse the fill while talking
    if (talking && settings.effects.mic) {
        micEl.classList.add('is-active');
    } else {
        micEl.classList.remove('is-active');
    }
}

function setMicRadio(active) {
    const micEl = $('#stat-mic');
    micEl.classList.toggle('is-radio', active);
}

function setVehicleVisible(visible) {
    state.inVehicle = visible;
    $('#speedo-container').style.display = visible ? '' : 'none';
}

function setOxygenVisible(visible) {
    $('#stat-oxygen').style.display = visible ? '' : 'none';
}

function setHudVisible(visible) {
    document.body.classList.toggle('hud-hidden', !visible);
}

// settings panel control
const settingsPanel = $('#nui-settings');

function openSettings() {
    settingsPanel.classList.add('is-open');

    // Reveal every hidden HUD element so the user can tweak them
    document.body.classList.add('settings-preview');
    const speedoEl = $('#speedo-container');
    if (speedoEl) speedoEl.style.display = '';

    // Show the stress and parachute stats (the hidden ones)
    const stressEl = $('#stat-stress');
    const parachuteEl = $('#stat-parachute');
    const oxygenEl = $('#stat-oxygen');
    [stressEl, parachuteEl, oxygenEl].forEach(el => {
        if (el && el.style.display === 'none') {
            el.dataset.wasHidden = '1';
            el.style.display = '';
        }
    });
}
function closeSettings() {
    settingsPanel.classList.remove('is-open');
    document.body.classList.remove('settings-preview');

    // Restore the vehicle HUD state based on whether the player is actually in a car
    const speedoEl = $('#speedo-container');
    if (speedoEl && !state.inVehicle) speedoEl.style.display = 'none';

    // Put the previously hidden stats back to their original state
    [$('#stat-stress'), $('#stat-parachute'), $('#stat-oxygen')].forEach(el => {
        if (el && el.dataset.wasHidden === '1') {
            el.style.display = 'none';
            delete el.dataset.wasHidden;
        }
    });

    fetch(`https://${RESOURCE}/close-settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
}
$('#nui-close').addEventListener('click', closeSettings);

// ESC closes settings
document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && settingsPanel.classList.contains('is-open')) {
        closeSettings();
    }
});

// Tabs
$$('.nui-tab').forEach(tab => {
    tab.addEventListener('click', () => {
        $$('.nui-tab').forEach(t => t.classList.remove('is-active'));
        $$('.nui-pane').forEach(p => p.classList.remove('is-active'));
        tab.classList.add('is-active');
        $(`[data-pane="${tab.dataset.tab}"]`).classList.add('is-active');
    });
});

// admin config from Lua: which HUD pieces show, which settings rows are
// visible, and locked defaults
const cfg = {
    elements: {},   // e.g. { health: true, hunger: false, ... }
    panel:    {},   // e.g. { hideCompass: true, minimapMode: false, ... }
    defaults: {}    // e.g. { hideCompass: false, hudSize: 100, ... }
};

// Selector tables so we know what to hide.
// elementSelectors: HUD pieces in the world view
// panelSelectors  : rows inside /hudsettings (we walk up to the row container)
const elementSelectors = {
    health   : '[data-stat="health"]',
    armor    : '[data-stat="armor"]',
    hunger   : '[data-stat="hunger"]',
    thirst   : '[data-stat="thirst"]',
    stamina  : '[data-stat="stamina"]',
    oxygen   : '#stat-oxygen',
    mic      : '#stat-mic',
    stress   : '#stat-stress',
    parachute: '#stat-parachute',
    compass  : '[data-hud="compass"]',
    speedo   : '#speedo-container',
    seatbelt : '#seatbelt-item',
    engine   : '#engine-item',
    // minimap is the native GTA radar - hidden via Lua, not the DOM
};

// Which input/element identifies each panel row
const panelRowInputs = {
    dragMode    : '#t-drag',
    mouseResize : '#t-resize',
    hideCompass : '#h-compass',
    hideStats   : '#h-stats',
    minimapMode : '#t-map-always',
    hudSize     : '#scale-s',
    lowStatPulse: '#e-crit',
    micPulse    : '#e-mic',
    glow        : '#glow-s',
    opacity     : '#op-s',
    cinemaMode  : '#t-cinema',
};

function isPanelLocked(key) {
    return cfg.panel && cfg.panel[key] === false;
}
function isElementOff(key) {
    return cfg.elements && cfg.elements[key] === false;
}

function applyConfigVisibility() {
    // 1) Hide HUD pieces that are turned off in Config.Elements
    Object.entries(elementSelectors).forEach(([key, sel]) => {
        const el = document.querySelector(sel);
        if (!el) return;
        if (isElementOff(key)) {
            el.dataset.cfgOff = '1';
            el.style.display = 'none';
        } else if (el.dataset.cfgOff === '1') {
            delete el.dataset.cfgOff;
            el.style.display = '';
        }
    });

    // If the entire stats container has no visible stats inside it, hide it too.
    const statsBox = document.querySelector('[data-hud="stats"]');
    if (statsBox) {
        const anyStat = [...statsBox.querySelectorAll('.stat')].some(s => s.style.display !== 'none');
        statsBox.style.visibility = anyStat ? '' : 'hidden';
    }

    // 2) Hide rows in the settings panel that the admin locked off
    Object.entries(panelRowInputs).forEach(([key, sel]) => {
        const input = document.querySelector(sel);
        if (!input) return;
        const row = input.closest('.toggle-row, .slider-row');
        if (!row) return;
        row.style.display = isPanelLocked(key) ? 'none' : '';
    });

    // 3) Hide individual color rows when the matching element is off
    ['health','armor','hunger','thirst','stamina','mic'].forEach(stat => {
        const row = document.querySelector(`.color-row[data-stat="${stat}"]`);
        if (row) row.style.display = isElementOff(stat) ? 'none' : '';
    });

    // 4) Whole Colors tab toggle
    if (isPanelLocked('colorsTab')) {
        const btn  = document.querySelector('.nui-tab[data-tab="colors"]');
        const pane = document.querySelector('.nui-pane[data-pane="colors"]');
        if (btn)  btn.style.display  = 'none';
        if (pane) pane.style.display = 'none';
        // If Colors was the active tab, fall through to Layout
        if (btn && btn.classList.contains('is-active')) {
            const layoutBtn = document.querySelector('.nui-tab[data-tab="layout"]');
            if (layoutBtn) layoutBtn.click();
        }
    }
}

// Drop any saved-setting keys the admin has locked. Called right after
// load-settings decodes the saved KVP.
function stripLockedFromSaved(saved) {
    if (!saved || typeof saved !== 'object') return saved;
    if (isPanelLocked('hideCompass') && saved.hidden) delete saved.hidden.compass;
    if (isPanelLocked('hideStats')   && saved.hidden) delete saved.hidden.stats;
    if (isPanelLocked('minimapMode')) delete saved.minimapMode;
    if (isPanelLocked('hudSize'))    delete saved.scale;
    if (saved.effects) {
        if (isPanelLocked('lowStatPulse')) delete saved.effects.crit;
        if (isPanelLocked('micPulse'))     delete saved.effects.mic;
        if (isPanelLocked('glow'))         delete saved.effects.glow;
        if (isPanelLocked('opacity'))      delete saved.effects.opacity;
    }
    if (isPanelLocked('colorsTab')) delete saved.colors;
    if (isPanelLocked('cinemaMode')) delete saved.cinemaMode;
    return saved;
}

// apply settings
function applySettings() {
    Object.entries(settings.colors).forEach(([s, c]) => applyColor(s, c));
    Object.entries(settings.positions).forEach(([id, pos]) => {
        const el = $(`[data-hud="${id}"]`);
        if (el && pos.x != null) {
            el.style.left = pos.x + 'px';
            el.style.top = pos.y + 'px';
            el.style.right = 'auto';
            el.style.bottom = 'auto';
            el.style.transform = 'none';
        }
    });
    Object.entries(settings.hidden).forEach(([id, h]) => {
        const el = $(`[data-hud="${id}"]`);
        if (el) el.style.display = h ? 'none' : '';
    });
    applyEffects();
    applyScale();
    applyCinemaMode();
    syncControls();
}

function applyColor(stat, color) {
    if (stat === 'brand') {
        document.documentElement.style.setProperty('--nerd-primary', color);
        const r = parseInt(color.slice(1, 3), 16);
        const g = parseInt(color.slice(3, 5), 16);
        const b = parseInt(color.slice(5, 7), 16);
        document.documentElement.style.setProperty('--nerd-primary-glow', `rgba(${r},${g},${b},0.45)`);
        document.documentElement.style.setProperty('--nerd-primary-soft', `rgba(${r},${g},${b},0.15)`);
    } else {
        const el = $(`.stat--${stat}`);
        if (el) el.style.setProperty('--stat-color', color);
    }
    settings.colors[stat] = color;
}

function applyEffects() {
    if (!settings.effects.crit) {
        $$('.stat.is-critical').forEach(el => el.classList.remove('is-critical'));
    }
    if (!settings.effects.mic && state.micOn) {
        $('#stat-mic').classList.remove('is-active');
    } else if (settings.effects.mic && state.micOn) {
        $('#stat-mic').classList.add('is-active');
    }

    let style = $('#nui-dynamic') || (() => {
        const s = document.createElement('style');
        s.id = 'nui-dynamic';
        document.head.appendChild(s);
        return s;
    })();
    const op = settings.effects.opacity / 100;
    const intensity = settings.effects.glow / 100;
    // Only .compass has a background; .speedo is fully transparent
    style.textContent = `
        .compass.glass {
            background: rgba(8, 8, 8, ${0.7 * op}) !important;
        }
        .stat__bg { background: rgba(8, 8, 8, ${0.78 * op}) !important; }
        .stat__fill { filter: drop-shadow(0 0 ${4 * intensity}px var(--stat-color)); }
    `;
}

// elementScales: per-element scale (multiplied by the base scale)
if (!settings.elementScales) settings.elementScales = {};

function getElementOrigin(el) {
    const data = el.dataset.hud || el.id || '';
    if (data === 'compass') return 'top center';
    if (data === 'stats') return 'bottom left';
    if (data === 'minimap') return 'bottom center';
    if (data === 'speedo' || el.id === 'speedo-container') return 'bottom right';
    if (data === 'time' || data === 'money' || data === 'job') return 'top right';
    return 'center center';
}

function getElementId(el) {
    return el.dataset.hud || el.id || '';
}

function applyScale() {
    const baseScale = settings.scale / 100;
    const elements = new Set([
        ...document.querySelectorAll('.draggable'),
        document.getElementById('speedo-container')
    ]);
    elements.forEach(el => {
        if (!el) return;
        const id = getElementId(el);
        // Final scale = base (from the slider) * per-element scale
        const individualScale = settings.elementScales[id] || 1;
        const finalScale = baseScale * individualScale;
        el.style.transformOrigin = getElementOrigin(el);
        el.style.transform = `scale(${finalScale})`;
    });
}

function syncControls() {
    $$('.color-row').forEach(row => {
        const stat = row.dataset.stat;
        const color = settings.colors[stat] || '#ED0246';
        row.style.setProperty('--row-color', color);
        row.querySelectorAll('.color-swatch').forEach(s => {
            s.classList.toggle('is-active', s.dataset.color.toLowerCase() === color.toLowerCase());
        });
    });
    $('#h-compass').checked = settings.hidden.compass || false;
    $('#h-stats').checked   = settings.hidden.stats || false;
    const mapAlwaysEl = $('#t-map-always');
    if (mapAlwaysEl) mapAlwaysEl.checked = settings.minimapMode === 'always';
    const cinemaEl = $('#t-cinema');
    if (cinemaEl) cinemaEl.checked = !!settings.cinemaMode;
    $('#e-crit').checked    = settings.effects.crit;
    $('#e-mic').checked     = settings.effects.mic;
    $('#scale-s').value     = settings.scale;
    $('#scale-v').textContent = settings.scale + '%';
    $('#glow-s').value      = settings.effects.glow;
    $('#glow-v').textContent  = settings.effects.glow + '%';
    $('#op-s').value        = settings.effects.opacity;
    $('#op-v').textContent    = settings.effects.opacity + '%';
}

// color pickers
$$('.color-row').forEach(row => {
    const stat = row.dataset.stat;
    row.querySelectorAll('.color-swatch').forEach(swatch => {
        swatch.addEventListener('click', () => {
            row.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('is-active'));
            swatch.classList.add('is-active');
            applyColor(stat, swatch.dataset.color);
            row.style.setProperty('--row-color', swatch.dataset.color);
        });
    });
});

// hide-element toggles
const hideMap = { 'h-compass': 'compass', 'h-stats': 'stats' };
Object.entries(hideMap).forEach(([id, key]) => {
    $('#' + id).addEventListener('change', e => {
        settings.hidden[key] = e.target.checked;
        const el = $(`[data-hud="${key}"]`);
        if (el) el.style.display = e.target.checked ? 'none' : '';
    });
});

// Minimap visibility mode toggle
const mapAlwaysToggle = $('#t-map-always');
if (mapAlwaysToggle) {
    mapAlwaysToggle.addEventListener('change', e => {
        settings.minimapMode = e.target.checked ? 'always' : 'vehicle';
        // Live update - the Lua side flips the radar right away,
        // and the value will be persisted on Save like everything else.
        fetch(`https://${RESOURCE}/set-minimap-mode`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ mode: settings.minimapMode })
        }).catch(() => {});
    });
}

// cinema mode: body class hides the HUD and slides in the bars
function applyCinemaMode() {
    document.body.classList.toggle('is-cinema', !!settings.cinemaMode);
}
const cinemaToggle = $('#t-cinema');
if (cinemaToggle) {
    cinemaToggle.addEventListener('change', e => {
        settings.cinemaMode = e.target.checked;
        applyCinemaMode();
    });
}

// effect toggles
$('#e-crit').addEventListener('change', e => { settings.effects.crit = e.target.checked; applyEffects(); });
$('#e-mic').addEventListener('change',  e => { settings.effects.mic = e.target.checked; applyEffects(); });

// scale/glow/opacity sliders
$('#scale-s').addEventListener('input', e => {
    settings.scale = +e.target.value;
    $('#scale-v').textContent = settings.scale + '%';
    applyScale();
});
$('#glow-s').addEventListener('input', e => {
    settings.effects.glow = +e.target.value;
    $('#glow-v').textContent = settings.effects.glow + '%';
    applyEffects();
});
$('#op-s').addEventListener('input', e => {
    settings.effects.opacity = +e.target.value;
    $('#op-v').textContent = settings.effects.opacity + '%';
    applyEffects();
});

// save button
$('#save-btn').addEventListener('click', () => {
    // drag mode is a tool, never something we want persisted
    if (document.body.classList.contains('is-dragmode')) {
        document.body.classList.remove('is-dragmode');
        const dragToggle = $('#t-drag');
        if (dragToggle) dragToggle.checked = false;
    }
    // same for resize mode
    if (document.body.classList.contains('is-resize-mode')) {
        document.body.classList.remove('is-resize-mode');
        const resizeToggle = $('#t-resize');
        if (resizeToggle) resizeToggle.checked = false;
    }

    // strip admin-locked keys before sending up
    const payload = JSON.parse(JSON.stringify(settings));
    stripLockedFromSaved(payload);
    fetch(`https://${RESOURCE}/save-settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).catch(() => {});

    // Show toast
    const t = $('#save-toast');
    t.classList.add('is-visible');
    setTimeout(() => t.classList.remove('is-visible'), 1800);

    // Close after save (this sends close-settings, which drops the NUI focus on the Lua side)
    setTimeout(closeSettings, 600);
});

// reset button
$('#reset-btn').addEventListener('click', () => {
    // close drag mode + panel
    document.body.classList.remove('is-dragmode');
    settingsPanel.classList.remove('is-open');

    // release the mouse before anything else, otherwise the cursor sticks
    fetch(`https://${RESOURCE}/close-settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});

    // ask the server to wipe saved settings
    fetch(`https://${RESOURCE}/reset-settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});

    // reload after focus drops
    setTimeout(() => location.reload(), 300);
});

// drag mode
$('#t-drag').addEventListener('change', e => {
    document.body.classList.toggle('is-dragmode', e.target.checked);
});

// resize mode - mouse-wheel resize
const scaleIndicator = $('#scale-indicator');
let scaleHideTimer = null;

function showScaleIndicator(text) {
    if (!scaleIndicator) return;
    scaleIndicator.textContent = text || (settings.scale + '%');
    scaleIndicator.classList.add('is-visible');
    clearTimeout(scaleHideTimer);
    scaleHideTimer = setTimeout(() => {
        scaleIndicator.classList.remove('is-visible');
    }, 1000);
}

const resizeToggle = $('#t-resize');
if (resizeToggle) {
    resizeToggle.addEventListener('change', e => {
        document.body.classList.toggle('is-resize-mode', e.target.checked);
        // Turn off drag mode if resize mode just turned on
        if (e.target.checked && document.body.classList.contains('is-dragmode')) {
            document.body.classList.remove('is-dragmode');
            const dragT = $('#t-drag');
            if (dragT) dragT.checked = false;
        }
    });
}

// resize: only the element under the cursor
let isResizing = false;
let resizeStartY = 0;
let resizeStartScale = 1;
let resizeTarget = null;

// Resize a single element
function setElementScale(target, newPct) {
    if (!target) return;
    const id = getElementId(target);
    if (!settings.elementScales) settings.elementScales = {};
    settings.elementScales[id] = Math.max(0.5, Math.min(2.0, newPct / 100));
    applyScale();
    showScaleIndicator(`${id.toUpperCase()}: ${Math.round(newPct)}%`);
}

// Adjust the global scale (slider)
function setHudScale(newScale) {
    settings.scale = Math.max(70, Math.min(150, newScale));
    const sliderEl = document.getElementById('scale-s');
    const valueEl  = document.getElementById('scale-v');
    if (sliderEl) sliderEl.value = settings.scale;
    if (valueEl)  valueEl.textContent = settings.scale + '%';
    applyScale();
    showScaleIndicator(`${settings.scale}%`);
}

// Find the closest HUD element under the cursor
function findHudTarget(e) {
    if (!e.target || !e.target.closest) return null;
    if (e.target.closest('.nui-settings')) return null;
    return e.target.closest('.draggable') || (e.target.closest('#speedo-container'));
}

document.addEventListener('mousedown', (e) => {
    if (!document.body.classList.contains('is-resize-mode')) return;
    const target = findHudTarget(e);
    if (!target) return;  // cursor is not over a HUD element

    resizeTarget = target;
    isResizing = true;
    resizeStartY = e.clientY;
    const id = getElementId(target);
    if (!settings.elementScales) settings.elementScales = {};
    resizeStartScale = (settings.elementScales[id] || 1) * 100;
    document.body.style.cursor = 'ns-resize';
    e.preventDefault();
    e.stopPropagation();
}, true);

document.addEventListener('mousemove', (e) => {
    if (!isResizing || !resizeTarget) return;
    e.preventDefault();
    const deltaY = resizeStartY - e.clientY;
    const newPct = Math.round(resizeStartScale + (deltaY / 3));
    setElementScale(resizeTarget, newPct);
}, true);

document.addEventListener('mouseup', () => {
    if (isResizing) {
        isResizing = false;
        resizeTarget = null;
        document.body.style.cursor = '';
    }
}, true);

// Mouse wheel - scales the element under the cursor
window.addEventListener('wheel', (e) => {
    if (!document.body.classList.contains('is-resize-mode')) return;
    const target = findHudTarget(e);
    if (!target) return;  // cursor is not over a HUD element

    e.preventDefault();
    const deltaY = e.deltaY || -e.wheelDelta || 0;
    if (deltaY === 0) return;
    const direction = deltaY < 0 ? 1 : -1;
    const id = getElementId(target);
    const currentPct = (settings.elementScales[id] || 1) * 100;
    setElementScale(target, currentPct + direction * 5);
}, { passive: false, capture: true });

let drag = null;
$$('.draggable').forEach(el => {
    el.addEventListener('mousedown', e => {
        if (!document.body.classList.contains('is-dragmode')) return;
        if (e.target.closest('.nui-settings')) return;
        e.preventDefault();
        const r = el.getBoundingClientRect();
        drag = { el, x: e.clientX - r.left, y: e.clientY - r.top };
        el.classList.add('is-being-dragged');
        el.style.left = r.left + 'px';
        el.style.top = r.top + 'px';
        el.style.right = 'auto';
        el.style.bottom = 'auto';
        el.style.transform = 'none';
    });
});

document.addEventListener('mousemove', e => {
    if (!drag) return;
    const x = Math.max(0, Math.min(window.innerWidth - drag.el.offsetWidth, e.clientX - drag.x));
    const y = Math.max(0, Math.min(window.innerHeight - drag.el.offsetHeight, e.clientY - drag.y));
    drag.el.style.left = x + 'px';
    drag.el.style.top = y + 'px';
});

document.addEventListener('mouseup', () => {
    if (drag) {
        drag.el.classList.remove('is-being-dragged');
        const id = drag.el.dataset.hud;
        settings.positions[id] = { x: parseInt(drag.el.style.left), y: parseInt(drag.el.style.top) };
        drag = null;
    }
});

// Settings panel itself draggable via header
const header = $('#nui-header');
let panelDrag = null;
header.addEventListener('mousedown', e => {
    if (e.target.closest('.nui-close')) return;
    const r = settingsPanel.getBoundingClientRect();
    panelDrag = { x: e.clientX - r.left, y: e.clientY - r.top };
    settingsPanel.classList.add('is-dragged');
    settingsPanel.style.left = r.left + 'px';
    settingsPanel.style.top = r.top + 'px';
    e.preventDefault();
});
document.addEventListener('mousemove', e => {
    if (!panelDrag) return;
    const x = Math.max(0, Math.min(window.innerWidth - settingsPanel.offsetWidth, e.clientX - panelDrag.x));
    const y = Math.max(0, Math.min(window.innerHeight - settingsPanel.offsetHeight, e.clientY - panelDrag.y));
    settingsPanel.style.left = x + 'px';
    settingsPanel.style.top = y + 'px';
});
document.addEventListener('mouseup', () => { panelDrag = null; });

// R key to reset positions
document.addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT') return;
    if ((e.key === 'r' || e.key === 'R') && document.body.classList.contains('is-dragmode')) {
        settings.positions = {};
        $$('.draggable').forEach(el => {
            ['left', 'top', 'right', 'bottom', 'transform'].forEach(p => el.style[p] = '');
        });
    }
});

// nui message listener (from client.lua)
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'update-stats':
            if (data.health  != null) updateStat('health',  data.health);
            if (data.armor   != null) updateStat('armor',   data.armor);
            if (data.hunger  != null) updateStat('hunger',  data.hunger);
            if (data.thirst  != null) updateStat('thirst',  data.thirst);
            if (data.stamina != null) updateStat('stamina', data.stamina);
            if (data.oxygen  != null) updateStat('oxygen',  data.oxygen);
            if (data.isUnderwater != null) setOxygenVisible(data.isUnderwater);
            break;

        case 'update-vehicle':
            if (data.inVehicle != null) setVehicleVisible(data.inVehicle);
            if (data.speed    != null) updateSpeed(data.speed);
            if (data.fuel     != null) updateFuel(data.fuel);
            if (data.engine   != null) updateEngine(data.engine);
            if (data.seatbelt != null) setSeatbelt(data.seatbelt);
            if (data.gear     != null) updateGear(data.gear);
            break;

        case 'update-stress':
            // Stress only shows when smoking (value > 0)
            setStress(data.value || 0);
            break;

        case 'update-parachute':
            // Only shows when wearing one
            setParachute(!!data.on);
            break;

        case 'update-compass':
            if (data.heading != null) updateHeading(data.heading);
            if (data.street || data.zone) updateStreet(data.street, data.zone);
            break;

        case 'update-mic':
            setMicOn(data.on, data.mode);
            break;

        case 'update-mic-talking':
            setMicTalking(data.talking);
            break;

        case 'update-mic-radio':
            setMicRadio(data.active);
            break;

        case 'show-settings':
            openSettings();
            break;

        case 'show-hud':
            setHudVisible(data.show !== false);
            break;

        case 'load-settings':
            if (data.settings) {
                const saved = stripLockedFromSaved(data.settings);
                // Merge what's left over the current settings
                settings = Object.assign(settings, saved);
                applyConfigVisibility();
                applySettings();
            }
            break;

        case 'init-config':
            if (data.config) {
                if (data.config.colors)  settings.colors = Object.assign(settings.colors, data.config.colors);
                if (data.config.effects) settings.effects = Object.assign(settings.effects, data.config.effects);
                if (data.config.useMPH != null) {
                    state.useMPH = data.config.useMPH;
                    $('#speedo-unit').textContent = data.config.useMPH ? 'MPH' : 'KM/H';
                }
                if (data.config.maxSpeed) state.maxSpeed = data.config.maxSpeed;

                // Server-side toggles
                if (data.config.elements) cfg.elements = data.config.elements;
                if (data.config.panel)    cfg.panel    = data.config.panel;
                if (data.config.defaults) cfg.defaults = data.config.defaults;

                // Apply locked-in defaults to the settings object up front
                if (cfg.defaults.hudSize != null)     settings.scale = cfg.defaults.hudSize;
                if (cfg.defaults.hideCompass != null) settings.hidden.compass = !!cfg.defaults.hideCompass;
                if (cfg.defaults.hideStats   != null) settings.hidden.stats   = !!cfg.defaults.hideStats;
                if (cfg.defaults.cinemaMode  != null) settings.cinemaMode      = !!cfg.defaults.cinemaMode;
                if (data.config.minimapMode === 'always' || data.config.minimapMode === 'vehicle') {
                    settings.minimapMode = data.config.minimapMode;
                }

                applyConfigVisibility();
                applySettings();
            }
            break;
    }
});

// init — apply default settings on load
applySettings();

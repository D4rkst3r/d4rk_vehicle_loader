// Vehicle Loader Debug UI - Script

const state = {
    visible: false,
    trailerLabel: '-',
    currentSlot: 1,
    totalSlots: 1,
    slotId: 1,
    mode: 'position',
    axis: 'x',
    step: 0.1,
    values: { x: 0, y: 0, z: 0 },
    rotation: { x: 0, y: 0, z: 0 },
    slots: [],
    undoCount: 0,
    redoCount: 0,
};

const RESOURCE_NAME = 'vehicle_loader';

// ============================================
// NUI Message Handler
// ============================================
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.type) {
        case 'show':
            showUI();
            updateUI(data);
            break;

        case 'hide':
            hideUI();
            break;

        case 'update':
            updateUI(data);
            break;

        case 'updateSlots':
            updateSlotList(data.slots);
            break;
    }
});

// ============================================
// UI Updates
// ============================================
function showUI() {
    document.getElementById('app').classList.remove('hidden');
    state.visible = true;
}

function hideUI() {
    document.getElementById('app').classList.add('hidden');
    state.visible = false;
}

function updateUI(data) {
    if (data.trailerLabel !== undefined) {
        state.trailerLabel = data.trailerLabel;
        document.getElementById('trailerLabel').textContent = data.trailerLabel;
    }

    if (data.currentSlot !== undefined) {
        state.currentSlot = data.currentSlot;
        document.getElementById('currentSlot').textContent = data.currentSlot;
    }

    if (data.totalSlots !== undefined) {
        state.totalSlots = data.totalSlots;
        document.getElementById('totalSlots').textContent = data.totalSlots;
    }

    if (data.slotId !== undefined) {
        state.slotId = data.slotId;
        document.getElementById('slotId').textContent = data.slotId;
    }

    if (data.values !== undefined) {
        state.values = data.values;
        if (state.mode === 'position') {
            document.getElementById('valueX').value = data.values.x.toFixed(2);
            document.getElementById('valueY').value = data.values.y.toFixed(2);
            document.getElementById('valueZ').value = data.values.z.toFixed(2);
        }
    }

    if (data.rotation !== undefined) {
        state.rotation = data.rotation;
        if (state.mode === 'rotation') {
            document.getElementById('valueX').value = data.rotation.x.toFixed(2);
            document.getElementById('valueY').value = data.rotation.y.toFixed(2);
            document.getElementById('valueZ').value = data.rotation.z.toFixed(2);
        }
    }

    if (data.undoCount !== undefined) {
        state.undoCount = data.undoCount;
        const el = document.getElementById('undoCount');
        if (el) el.textContent = `${data.undoCount} Schritte`;
    }

    if (data.redoCount !== undefined) {
        state.redoCount = data.redoCount;
        const el = document.getElementById('redoCount');
        if (el) el.textContent = `${data.redoCount} Schritte`;
    }

    if (data.slots !== undefined) {
        updateSlotList(data.slots);
    }
}

function updateSlotList(slots) {
    state.slots = slots;
    const container = document.getElementById('slotList');
    container.innerHTML = '';

    slots.forEach((slot, index) => {
        const item = document.createElement('div');
        const isActive = (index + 1) === state.currentSlot;
        const isOccupied = slot.occupied || false;

        item.className = `slot-item ${isActive ? 'active' : ''} ${isOccupied ? 'occupied' : 'free'}`;
        item.innerHTML = `
            <div class="slot-icon">${slot.id}</div>
            <div class="slot-info">
                <strong>Slot ${slot.id}</strong>
                <small>${slot.offset.x.toFixed(2)}, ${slot.offset.y.toFixed(2)}, ${slot.offset.z.toFixed(2)}</small>
            </div>
            <div class="slot-status ${isOccupied ? 'occupied' : 'free'}">
                ${isOccupied ? 'Belegt' : 'Frei'}
            </div>
        `;

        item.addEventListener('click', () => {
            sendNUIMessage('selectSlot', { index: index + 1 });
        });

        container.appendChild(item);
    });
}

// ============================================
// NUI Callbacks (Send to Lua)
// ============================================
function sendNUIMessage(action, data = {}) {
    // FiveM NUI Callback
    if (typeof GetParentResourceName !== 'undefined') {
        fetch(`https://${GetParentResourceName()}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        }).catch(() => {});
    } else {
        // Dev mode (browser preview)
        console.log(`[NUI] ${action}`, data);
    }
}

// ============================================
// TABS
// ============================================
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

        tab.classList.add('active');
        const target = tab.dataset.tab;
        document.querySelector(`[data-content="${target}"]`).classList.add('active');
    });
});

// ============================================
// MODE SWITCHER
// ============================================
document.querySelectorAll('.mode-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        state.mode = btn.dataset.mode;
        sendNUIMessage('setMode', { mode: state.mode });

        // Update inputs to show current mode values
        const values = state.mode === 'position' ? state.values : state.rotation;
        document.getElementById('valueX').value = values.x.toFixed(2);
        document.getElementById('valueY').value = values.y.toFixed(2);
        document.getElementById('valueZ').value = values.z.toFixed(2);
    });
});

// ============================================
// VALUE BUTTONS (+/-)
// ============================================
document.querySelectorAll('.value-buttons button').forEach(btn => {
    btn.addEventListener('click', () => {
        const axis = btn.dataset.axis;
        const delta = parseInt(btn.dataset.delta) * state.step;
        sendNUIMessage('adjust', { axis, delta });
    });
});

// ============================================
// STEP SELECTOR
// ============================================
document.querySelectorAll('.step-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.step-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        state.step = parseFloat(btn.dataset.step);
        sendNUIMessage('setStep', { step: state.step });
    });
});

// ============================================
// APPLY BUTTON (Manual Input)
// ============================================
document.getElementById('applyBtn').addEventListener('click', () => {
    const x = parseFloat(document.getElementById('valueX').value) || 0;
    const y = parseFloat(document.getElementById('valueY').value) || 0;
    const z = parseFloat(document.getElementById('valueZ').value) || 0;

    sendNUIMessage('applyValues', { mode: state.mode, x, y, z });
});

// ============================================
// ACTION BUTTONS
// ============================================
document.getElementById('snapBtn').addEventListener('click', () => sendNUIMessage('snap'));
document.getElementById('undoBtn').addEventListener('click', () => sendNUIMessage('undo'));
document.getElementById('redoBtn').addEventListener('click', () => sendNUIMessage('redo'));
document.getElementById('rampBtn').addEventListener('click', () => sendNUIMessage('testRamp'));
document.getElementById('detectRampBtn').addEventListener('click', () => sendNUIMessage('detectRamp'));
document.getElementById('exportBtn').addEventListener('click', () => sendNUIMessage('export'));

// ============================================
// SLOT BUTTONS
// ============================================
document.getElementById('addSlotBtn').addEventListener('click', () => sendNUIMessage('addSlot'));
document.getElementById('duplicateSlotBtn').addEventListener('click', () => sendNUIMessage('duplicateSlot'));
document.getElementById('mirrorSlotBtn').addEventListener('click', () => sendNUIMessage('mirrorSlot'));
document.getElementById('removeSlotBtn').addEventListener('click', () => sendNUIMessage('removeSlot'));

// ============================================
// VEHICLE GRID
// ============================================
document.querySelectorAll('.vehicle-card').forEach(card => {
    card.addEventListener('click', () => {
        sendNUIMessage('spawnTestVehicle', { model: card.dataset.model });
    });
});

document.getElementById('deleteVehicleBtn').addEventListener('click', () => {
    sendNUIMessage('deleteTestVehicle');
});

// ============================================
// CLOSE BUTTON
// ============================================
document.getElementById('closeBtn').addEventListener('click', () => {
    sendNUIMessage('close');
});

// ============================================
// KEYBOARD SHORTCUTS (Within NUI)
// ============================================
document.addEventListener('keydown', (e) => {
    // ESC closes UI
    if (e.key === 'Escape') {
        sendNUIMessage('close');
    }
});

// ============================================
// DEV MODE: Auto-show in browser preview
// ============================================
if (typeof GetParentResourceName === 'undefined') {
    // We're in browser preview, show UI with mock data
    showUI();
    updateUI({
        trailerLabel: 'Standard Flatbed',
        currentSlot: 1,
        totalSlots: 3,
        slotId: 1,
        values: { x: 0.00, y: -3.50, z: 1.00 },
        rotation: { x: 0, y: 0, z: 0 },
        undoCount: 0,
        redoCount: 0,
    });

    updateSlotList([
        { id: 1, offset: { x: 0.00, y: -3.50, z: 1.00 }, occupied: false },
        { id: 2, offset: { x: 1.50, y: -5.00, z: 1.00 }, occupied: true },
        { id: 3, offset: { x: -1.50, y: -2.50, z: 1.00 }, occupied: false },
    ]);
}

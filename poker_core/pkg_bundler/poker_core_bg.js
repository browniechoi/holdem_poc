export class WasmGame {
    static __wrap(ptr) {
        ptr = ptr >>> 0;
        const obj = Object.create(WasmGame.prototype);
        obj.__wbg_ptr = ptr;
        WasmGameFinalization.register(obj, obj.__wbg_ptr, obj);
        return obj;
    }
    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        WasmGameFinalization.unregister(this);
        return ptr;
    }
    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_wasmgame_free(ptr, 0);
    }
    /**
     * @param {number} iters
     * @returns {string}
     */
    actions_with_ev_json(iters) {
        let deferred1_0;
        let deferred1_1;
        try {
            const ret = wasm.wasmgame_actions_with_ev_json(this.__wbg_ptr, iters);
            deferred1_0 = ret[0];
            deferred1_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free(deferred1_0, deferred1_1, 1);
        }
    }
    /**
     * @param {number} action_code
     */
    apply_user_action(action_code) {
        wasm.wasmgame_apply_user_action(this.__wbg_ptr, action_code);
    }
    /**
     * Create a new game. `seed` is a JS number (f64) to avoid BigInt.
     * @param {number} seed
     * @param {number} num_players
     */
    constructor(seed, num_players) {
        const ret = wasm.wasmgame_new(seed, num_players);
        this.__wbg_ptr = ret >>> 0;
        WasmGameFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * Overwrites this game's state with the snapshot's state (undo).
     * @param {WasmGame} snap
     */
    restore_from(snap) {
        _assertClass(snap, WasmGame);
        wasm.wasmgame_restore_from(this.__wbg_ptr, snap.__wbg_ptr);
    }
    /**
     * Returns a deep clone of the current game state as a new WasmGame.
     * Used by the frontend to checkpoint before each user action (undo support).
     * @returns {WasmGame}
     */
    snapshot() {
        const ret = wasm.wasmgame_snapshot(this.__wbg_ptr);
        return WasmGame.__wrap(ret);
    }
    start_new_training_hand() {
        wasm.wasmgame_start_new_training_hand(this.__wbg_ptr);
    }
    /**
     * @returns {string}
     */
    state_json() {
        let deferred1_0;
        let deferred1_1;
        try {
            const ret = wasm.wasmgame_state_json(this.__wbg_ptr);
            deferred1_0 = ret[0];
            deferred1_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free(deferred1_0, deferred1_1, 1);
        }
    }
    step_ai_until_user_or_hand_end() {
        wasm.wasmgame_step_ai_until_user_or_hand_end(this.__wbg_ptr);
    }
    step_playback_once() {
        wasm.wasmgame_step_playback_once(this.__wbg_ptr);
    }
    step_to_hand_end() {
        wasm.wasmgame_step_to_hand_end(this.__wbg_ptr);
    }
}
if (Symbol.dispose) WasmGame.prototype[Symbol.dispose] = WasmGame.prototype.free;
export function __wbg___wbindgen_throw_6ddd609b62940d55(arg0, arg1) {
    throw new Error(getStringFromWasm0(arg0, arg1));
}
export function __wbindgen_init_externref_table() {
    const table = wasm.__wbindgen_externrefs;
    const offset = table.grow(4);
    table.set(0, undefined);
    table.set(offset + 0, undefined);
    table.set(offset + 1, null);
    table.set(offset + 2, true);
    table.set(offset + 3, false);
}
const WasmGameFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_wasmgame_free(ptr >>> 0, 1));

function _assertClass(instance, klass) {
    if (!(instance instanceof klass)) {
        throw new Error(`expected instance of ${klass.name}`);
    }
}

function getStringFromWasm0(ptr, len) {
    ptr = ptr >>> 0;
    return decodeText(ptr, len);
}

let cachedUint8ArrayMemory0 = null;
function getUint8ArrayMemory0() {
    if (cachedUint8ArrayMemory0 === null || cachedUint8ArrayMemory0.byteLength === 0) {
        cachedUint8ArrayMemory0 = new Uint8Array(wasm.memory.buffer);
    }
    return cachedUint8ArrayMemory0;
}

let cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
cachedTextDecoder.decode();
const MAX_SAFARI_DECODE_BYTES = 2146435072;
let numBytesDecoded = 0;
function decodeText(ptr, len) {
    numBytesDecoded += len;
    if (numBytesDecoded >= MAX_SAFARI_DECODE_BYTES) {
        cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true, fatal: true });
        cachedTextDecoder.decode();
        numBytesDecoded = len;
    }
    return cachedTextDecoder.decode(getUint8ArrayMemory0().subarray(ptr, ptr + len));
}


let wasm;
export function __wbg_set_wasm(val) {
    wasm = val;
}

/* @ts-self-types="./poker_core.d.ts" */

import * as wasm from "./poker_core_bg.wasm";
import { __wbg_set_wasm } from "./poker_core_bg.js";
__wbg_set_wasm(wasm);
wasm.__wbindgen_start();
export {
    WasmGame
} from "./poker_core_bg.js";

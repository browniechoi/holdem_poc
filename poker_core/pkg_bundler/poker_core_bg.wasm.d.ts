/* tslint:disable */
/* eslint-disable */
export const memory: WebAssembly.Memory;
export const pc_actions_with_ev_json: (a: number, b: number) => number;
export const pc_apply_user_action: (a: number, b: number) => void;
export const pc_clone_game: (a: number) => number;
export const pc_copy_game_state: (a: number, b: number) => void;
export const pc_free_cstring: (a: number) => void;
export const pc_free_game: (a: number) => void;
export const pc_new_game: (a: bigint, b: number) => number;
export const pc_start_new_training_hand: (a: number) => void;
export const pc_state_json: (a: number) => number;
export const pc_step_ai_until_user_or_hand_end: (a: number) => void;
export const pc_step_playback_once: (a: number) => void;
export const pc_step_to_hand_end: (a: number) => void;
export const __wbg_wasmgame_free: (a: number, b: number) => void;
export const wasmgame_actions_with_ev_json: (a: number, b: number) => [number, number];
export const wasmgame_apply_user_action: (a: number, b: number) => void;
export const wasmgame_new: (a: number, b: number) => number;
export const wasmgame_restore_from: (a: number, b: number) => void;
export const wasmgame_snapshot: (a: number) => number;
export const wasmgame_start_new_training_hand: (a: number) => void;
export const wasmgame_state_json: (a: number) => [number, number];
export const wasmgame_step_ai_until_user_or_hand_end: (a: number) => void;
export const wasmgame_step_playback_once: (a: number) => void;
export const wasmgame_step_to_hand_end: (a: number) => void;
export const __wbindgen_externrefs: WebAssembly.Table;
export const __wbindgen_free: (a: number, b: number, c: number) => void;
export const __wbindgen_start: () => void;

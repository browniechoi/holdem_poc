/* tslint:disable */
/* eslint-disable */

export class WasmGame {
    free(): void;
    [Symbol.dispose](): void;
    actions_with_ev_json(iters: number): string;
    apply_user_action(action_code: number): void;
    /**
     * Create a new game. `seed` is a JS number (f64) to avoid BigInt.
     */
    constructor(seed: number, num_players: number);
    /**
     * Overwrites this game's state with the snapshot's state (undo).
     */
    restore_from(snap: WasmGame): void;
    /**
     * Returns a deep clone of the current game state as a new WasmGame.
     * Used by the frontend to checkpoint before each user action (undo support).
     */
    snapshot(): WasmGame;
    start_new_training_hand(): void;
    state_json(): string;
    step_ai_until_user_or_hand_end(): void;
    step_playback_once(): void;
    step_to_hand_end(): void;
}

import { WasmGame } from '../../poker_core/pkg_bundler/poker_core.js'
import type { PublicState, ActionEV } from './types'

export class Game {
  private wasm: WasmGame
  private _snap: WasmGame | null = null

  constructor(seed?: number, numPlayers = 6) {
    this.wasm = new WasmGame(seed ?? Date.now(), numPlayers)
    this.wasm.step_ai_until_user_or_hand_end()
  }

  state(): PublicState {
    return JSON.parse(this.wasm.state_json())
  }

  actions(iters = 1600): ActionEV[] {
    return JSON.parse(this.wasm.actions_with_ev_json(iters))
  }

  act(actionCode: number): void {
    this.wasm.apply_user_action(actionCode)
    this.wasm.step_ai_until_user_or_hand_end()
  }

  /** Apply the user's action without stepping any bots. */
  applyUserAction(code: number): void {
    this.wasm.apply_user_action(code)
  }

  /**
   * Step exactly one bot action. Returns true if a step was taken,
   * false if it's the user's turn or the hand is over (caller should stop).
   */
  stepOnce(): boolean {
    const s = JSON.parse(this.wasm.state_json()) as { hand_over: boolean; to_act: number; players: { is_user: boolean }[] }
    if (s.hand_over) return false
    if (s.players[s.to_act]?.is_user) return false
    this.wasm.step_playback_once()
    return true
  }

  stepToHandEnd(): void {
    this.wasm.step_to_hand_end()
  }

  newHand(): void {
    this.wasm.start_new_training_hand()
    this.wasm.step_ai_until_user_or_hand_end()
  }

  get canUndo(): boolean {
    return this._snap !== null
  }

  /** Save current state so it can be restored with undo(). */
  checkpoint(): void {
    if (this._snap) this._snap.free()
    this._snap = this.wasm.snapshot()
  }

  /** Restore to the last checkpoint. Returns false if no checkpoint exists. */
  undo(): boolean {
    if (!this._snap) return false
    this.wasm.restore_from(this._snap)
    this._snap.free()
    this._snap = null
    return true
  }

  free(): void {
    if (this._snap) { this._snap.free(); this._snap = null }
    this.wasm.free()
  }
}

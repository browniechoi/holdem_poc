import { WasmGame } from '../../poker_core/pkg_bundler/poker_core.js'
import type { PublicState, ActionEV } from './types'

export class Game {
  private wasm: WasmGame

  constructor(seed?: number, numPlayers = 6) {
    this.wasm = new WasmGame(seed ?? Date.now(), numPlayers)
    this.wasm.step_ai_until_user_or_hand_end()
  }

  state(): PublicState {
    return JSON.parse(this.wasm.state_json())
  }

  actions(iters = 1200): ActionEV[] {
    return JSON.parse(this.wasm.actions_with_ev_json(iters))
  }

  act(actionCode: number): void {
    this.wasm.apply_user_action(actionCode)
    this.wasm.step_ai_until_user_or_hand_end()
  }

  stepToHandEnd(): void {
    this.wasm.step_to_hand_end()
  }

  newHand(): void {
    this.wasm.start_new_training_hand()
    this.wasm.step_ai_until_user_or_hand_end()
  }

  free(): void {
    this.wasm.free()
  }
}

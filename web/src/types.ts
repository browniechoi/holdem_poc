export interface PublicPlayer {
  name: string
  stack: number
  hand_delta: number
  in_hand: boolean
  last_action: string
  is_user: boolean
  archetype: string
  tightness: number
  aggression: number
  calliness: number
  skill: number
  committed_street: number
  contributed_hand: number
  hole_cards: string[]
  hand_rank: string | null
}

export interface PublicState {
  pot: number
  sb: number
  bb: number
  dealer_idx: number
  sb_idx: number
  bb_idx: number
  street: string
  board: string[]
  players: PublicPlayer[]
  to_act: number
  to_call: number
  user_hole: string[]
  hand_over: boolean
  winner_name: string | null
  winner_names: string[]
  action_log: string[]
}

export interface WhyMetrics {
  hand_class: string
  board_texture: string
  made_hand_now: string
  draw_outlook: string
  blocker_note: string
  to_call: number
  pot_after_call: number
  pot_odds_pct: number
  required_equity_pct: number
  estimated_equity_pct: number
  equity_gap_pct: number
  ev_gap: number
  chips_at_risk: number
  pot_after_commit: number
  net_if_win: number
  breakeven_win_rate_pct: number
}

export interface ActionEV {
  action: string
  action_code: number
  amount: number
  ev: number
  baseline_ev: number
  ev_stderr: number
  best_confidence: string
  is_clear_best: boolean
  is_best: boolean
  baseline_ev_stderr: number
  baseline_best_confidence: string
  baseline_is_clear_best: boolean
  baseline_is_best: boolean
  reason: string
  why: WhyMetrics
}

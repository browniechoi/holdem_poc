import type { ActionEV } from './types'

export const ACTION_DISPLAY: Record<string, string> = {
  fold: 'Fold',
  'check/call': 'Check / Call',
  raise_min: 'Min Raise',
  bet_quarter_pot: 'Bet 1/4',
  bet_third_pot: 'Bet 1/3',
  bet_half_pot: 'Bet 1/2',
  bet_three_quarter_pot: 'Bet 3/4',
  bet_pot: 'Bet Pot',
  bet_overbet_125_pot: 'Bet 1.25x',
  bet_overbet_150_pot: 'Bet 1.5x',
  bet_overbet_175_pot: 'Bet 1.75x',
  bet_overbet_200_pot: 'Bet 2x',
  raise_half_pot: 'Raise 1/2',
  raise_three_quarter_pot: 'Raise 3/4',
  raise_pot: 'Raise Pot',
  raise_overbet_125_pot: 'Raise 1.25x',
  raise_overbet_150_pot: 'Raise 1.5x',
  raise_overbet_175_pot: 'Raise 1.75x',
  raise_overbet_200_pot: 'Raise 2x',
}

export const OVERSIZED_ACTIONS = new Set([
  'bet_overbet_125_pot',
  'bet_overbet_150_pot',
  'bet_overbet_175_pot',
  'bet_overbet_200_pot',
  'raise_overbet_125_pot',
  'raise_overbet_150_pot',
  'raise_overbet_175_pot',
  'raise_overbet_200_pot',
])

export function fmt(ev: number) {
  const abs = Math.abs(ev).toFixed(1)
  return ev >= 0 ? `+${abs}` : `−${abs}`
}

export function fmtMaybe(ev: unknown) {
  return typeof ev === 'number' && Number.isFinite(ev) ? fmt(ev) : '—'
}

export function primaryEv(a: ActionEV, isPreflop: boolean) {
  return isPreflop ? a.ev : a.baseline_ev
}

export function primaryConfidence(a: ActionEV, isPreflop: boolean) {
  return isPreflop ? a.best_confidence : a.baseline_best_confidence
}

export function primaryStderr(a: ActionEV, isPreflop: boolean) {
  return isPreflop ? a.ev_stderr : a.baseline_ev_stderr
}

export function primaryIsBest(a: ActionEV, isPreflop: boolean) {
  return isPreflop ? a.is_best : a.baseline_is_best
}

export function primaryIsClearBest(a: ActionEV, isPreflop: boolean) {
  return isPreflop ? a.is_clear_best : a.baseline_is_clear_best
}

export function isNearOptimal(chosen: ActionEV, allActions: ActionEV[]): boolean {
  const bestEV = Math.max(...allActions.map(a => a.ev))
  // Base tolerance: 5% of best EV, floor 2 chips
  let tolerance = Math.max(Math.abs(bestEV) * 0.05, 2.0)
  // When best EV is near zero (fold-or-play spots), widen tolerance so that
  // -EV plays aren't penalised. In live poker the slower deal speed makes
  // playing marginal hands reasonable for implied odds, range balance, and
  // table image — factors the Monte Carlo EV doesn't capture.
  if (Math.abs(bestEV) < 5) {
    tolerance = Math.max(tolerance, 20.0)
  }
  return chosen.ev >= bestEV - tolerance
}

export interface DecisionRecord {
  id: string
  handNo: number
  label: string
  street: string
  graded: boolean
  ev?: number
  bestEV?: number
  nearOptimal?: boolean
  reviewNote?: string
}

/** Remove actions whose chip amount duplicates an earlier entry (same-stack corner case). */
export function dedup(actions: ActionEV[]): ActionEV[] {
  const seen = new Set<number>()
  return actions.filter(a => {
    if (a.action === 'fold' || a.action === 'check/call') return true
    if (a.amount <= 0) return true
    if (seen.has(a.amount)) return false
    seen.add(a.amount)
    return true
  })
}

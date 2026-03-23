import type { ActionEV } from '../types'

interface Props {
  chosenCode: number
  actions: ActionEV[]
  onContinue: () => void
  onUndo?: () => void
  onSkip?: () => void
}

const ACTION_DISPLAY: Record<string, string> = {
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

function fmt(ev: number) {
  const abs = Math.abs(ev).toFixed(1)
  return ev >= 0 ? `+${abs}` : `−${abs}`
}

function isNearOptimal(chosen: ActionEV, allActions: ActionEV[]): boolean {
  const bestEV = Math.max(...allActions.map(a => a.ev))
  const tolerance = Math.max(Math.abs(bestEV) * 0.05, 2.0)
  return chosen.ev >= bestEV - tolerance
}

function dedup(actions: ActionEV[]): ActionEV[] {
  const seen = new Set<number>()
  return actions.filter(a => {
    if (a.action === 'fold' || a.action === 'check/call') return true
    if (a.amount <= 0) return true
    if (seen.has(a.amount)) return false
    seen.add(a.amount)
    return true
  })
}

export function ReviewPanel({ chosenCode, actions, onContinue, onUndo, onSkip }: Props) {
  const visible = dedup(actions)
  const chosen = visible.find(a => a.action_code === chosenCode)
    ?? actions.find(a => a.action_code === chosenCode)
  const best = visible.find(a => a.is_best) ?? actions.find(a => a.is_best)
  const nearOpt = chosen ? isNearOptimal(chosen, actions) : false
  const chosenLabel = chosen
    ? (ACTION_DISPLAY[chosen.action] ?? chosen.action) +
      (chosen.amount > 0 && chosen.action !== 'fold' ? ` $${chosen.amount}` : '')
    : '—'

  return (
    <div className="review-panel">
      <div className="review-header">
        <span className="review-label">You chose:</span>
        <span className="review-chosen">{chosenLabel}</span>
        <span className={`review-optimal ${nearOpt ? 'yes' : 'no'}`}>
          {nearOpt ? '✓ Near-optimal' : '✗ Suboptimal'}
        </span>
      </div>

      <div className="action-buttons">
        {visible.map(a => {
          const label = ACTION_DISPLAY[a.action] ?? a.action
          const amtLabel = a.amount > 0 && a.action !== 'fold' ? ` $${a.amount}` : ''
          const isChosen = a.action_code === chosenCode
          const evPositive = a.ev >= 0

          return (
            <div
              key={a.action_code}
              className={[
                'action-btn',
                a.is_best ? 'action-btn--best' : '',
                a.action === 'fold' ? 'action-btn--fold' : '',
                isChosen ? 'action-btn--chosen' : '',
              ].filter(Boolean).join(' ')}
            >
              <span className="action-btn-label">{label}{amtLabel}</span>
              <span className={`action-btn-ev ${evPositive ? 'ev-pos' : 'ev-neg'}`}>
                {fmt(a.ev)}
              </span>
              {a.is_best && <span className="action-btn-star">★</span>}
            </div>
          )
        })}
      </div>

      {best && (
        <div className="action-why">
          {best.why.hand_class && <span className="why-pill">{best.why.hand_class}</span>}
          {best.why.board_texture && <span className="why-pill">{best.why.board_texture}</span>}
          {best.why.made_hand_now && <span className="why-pill">{best.why.made_hand_now}</span>}
          {best.why.draw_outlook && <span className="why-pill">{best.why.draw_outlook}</span>}
          <span className="why-pill" data-tip="Win probability at showdown vs opponents.">
            Equity ~{best.why.estimated_equity_pct.toFixed(0)}%
          </span>
          {best.why.to_call > 0 && (
            <span className="why-pill" data-tip={`Need ${best.why.required_equity_pct.toFixed(0)}% equity to break even. Pot odds = call ÷ (pot + call).`}>
              Pot odds {best.why.pot_odds_pct.toFixed(0)}%
            </span>
          )}
        </div>
      )}

      {chosen && (() => {
        const gap = chosen.ev - chosen.baseline_ev
        const significant = Math.abs(gap) >= 2.0
        return (
          <div className="ev-compare">
            <strong>Pool EV:</strong> {chosen.ev >= 0 ? '+' : ''}{chosen.ev.toFixed(1)}
            {' '}·{' '}
            <strong>Baseline (random opps):</strong> {chosen.baseline_ev >= 0 ? '+' : ''}{chosen.baseline_ev.toFixed(1)}
            {significant && (
              <span className="ev-gap-warning">
                {' '}— {gap > 0
                  ? `these bots call too much (+${gap.toFixed(1)} to exploit)`
                  : `these bots play tighter (${gap.toFixed(1)} vs neutral)`}
              </span>
            )}
          </div>
        )
      })()}

      <div className="review-actions-row">
        {onUndo && (
          <button className="review-undo-btn" onClick={onUndo}>
            ↩ Undo & Try Again
          </button>
        )}
        {onSkip && (
          <button className="skip-btn" onClick={onSkip}>
            Skip to result
          </button>
        )}
        <button className="review-continue-btn" onClick={onContinue}>
          Continue →
        </button>
      </div>
    </div>
  )
}

import type { ActionEV } from '../types'
import { chenEval } from '../chenFormula'

interface Props {
  actions: ActionEV[]
  onAct: (code: number) => void
  disabled?: boolean
  showEV: boolean
  onToggleEV: () => void
  street: string
  userHole: string[]
}

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

function fmt(ev: number) {
  const abs = Math.abs(ev).toFixed(1)
  return ev >= 0 ? `+${abs}` : `−${abs}`
}

/** Remove actions whose chip amount duplicates an earlier entry (same-stack corner case). */
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

export function ActionPanel({ actions, onAct, disabled, showEV, onToggleEV, street, userHole }: Props) {
  const visible = dedup(actions)
  if (!visible.length) return null

  const best = visible.find(a => a.is_best)
  const isPreflop = street === 'preflop'
  const chen = isPreflop && userHole.length === 2
    ? chenEval(userHole[0], userHole[1])
    : null

  return (
    <div className="action-panel">
      <div className="action-top-row">
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1 }}>
          {chen && (
            <span
              className={`chen-badge chen-badge--${chen.tier}`}
              data-tip={chen.tip}
            >
              Score {chen.score} · {chen.label}
            </span>
          )}
          {showEV && best ? (
            <div className="action-hint">
              <span className="action-hint-label">Best:</span> {best.reason}
            </div>
          ) : (
            <div className="action-hint action-hint--hidden">Decide first, then reveal EV</div>
          )}
        </div>
        <button className="ev-toggle-btn" onClick={onToggleEV}>
          {showEV ? 'Hide EV' : 'Show EV'}
        </button>
      </div>

      <div className="action-buttons">
        {visible.map(a => {
          const label = ACTION_DISPLAY[a.action] ?? a.action
          const amtLabel = a.amount > 0 && a.action !== 'fold' ? ` $${a.amount}` : ''
          const evPositive = a.ev >= 0

          return (
            <button
              key={a.action_code}
              className={[
                'action-btn',
                showEV && a.is_best ? 'action-btn--best' : '',
                a.action === 'fold' ? 'action-btn--fold' : '',
              ].filter(Boolean).join(' ')}
              onClick={() => onAct(a.action_code)}
              disabled={disabled}
            >
              <span className="action-btn-label">{label}{amtLabel}</span>
              {showEV && (
                <span className={`action-btn-ev ${evPositive ? 'ev-pos' : 'ev-neg'}`}>
                  {fmt(a.ev)}
                </span>
              )}
              {showEV && a.is_best && <span className="action-btn-star">★</span>}
            </button>
          )
        })}
      </div>

      {showEV && best && (
        <div className="action-why">
          {best.why.hand_class && <span className="why-pill">{best.why.hand_class}</span>}
          {best.why.board_texture && <span className="why-pill">{best.why.board_texture}</span>}
          {best.why.made_hand_now && <span className="why-pill">{best.why.made_hand_now}</span>}
          {best.why.draw_outlook && <span className="why-pill">{best.why.draw_outlook}</span>}
          <span
            className="why-pill"
            data-tip="Your estimated probability of winning at showdown. Higher = stronger hand."
          >
            Equity ~{best.why.estimated_equity_pct.toFixed(0)}%
          </span>
          {best.why.to_call > 0 && (
            <span
              className="why-pill"
              data-tip={`You need ${best.why.required_equity_pct.toFixed(0)}% equity to break even. Pot odds = call ÷ (pot + call).`}
            >
              Pot odds {best.why.pot_odds_pct.toFixed(0)}%
            </span>
          )}
        </div>
      )}
    </div>
  )
}

import type { ActionEV } from '../types'

interface Props {
  actions: ActionEV[]
  onAct: (code: number) => void
  disabled?: boolean
}

const ACTION_DISPLAY: Record<string, string> = {
  fold: 'Fold',
  'check/call': 'Check / Call',
  raise_min: 'Min Raise',
  bet_quarter_pot: '¼ Pot',
  bet_third_pot: '⅓ Pot',
  bet_half_pot: '½ Pot',
  bet_three_quarter_pot: '¾ Pot',
  bet_pot: 'Pot',
  bet_overbet_125_pot: '1.25× Pot',
  bet_overbet_150_pot: '1.5× Pot',
  bet_overbet_175_pot: '1.75× Pot',
  bet_overbet_200_pot: '2× Pot',
  raise_half_pot: 'Raise ½',
  raise_three_quarter_pot: 'Raise ¾',
  raise_pot: 'Raise Pot',
  raise_overbet_125_pot: 'Raise 1.25×',
  raise_overbet_150_pot: 'Raise 1.5×',
  raise_overbet_175_pot: 'Raise 1.75×',
  raise_overbet_200_pot: 'Raise 2×',
}

function fmt(ev: number) {
  const abs = Math.abs(ev).toFixed(1)
  return ev >= 0 ? `+${abs}` : `−${abs}`
}

function isFold(a: ActionEV) {
  return a.action === 'fold'
}

export function ActionPanel({ actions, onAct, disabled }: Props) {
  if (!actions.length) return null

  const best = actions.find(a => a.is_best)

  return (
    <div className="action-panel">
      {best && (
        <div className="action-hint">
          <span className="action-hint-label">Best:</span> {best.reason}
        </div>
      )}

      <div className="action-buttons">
        {actions.map(a => {
          const label = ACTION_DISPLAY[a.action] ?? a.action
          const amtLabel = a.amount > 0 && !isFold(a) ? ` $${a.amount}` : ''
          const evPositive = a.ev >= 0

          return (
            <button
              key={a.action_code}
              className={[
                'action-btn',
                a.is_best ? 'action-btn--best' : '',
                isFold(a) ? 'action-btn--fold' : '',
              ].filter(Boolean).join(' ')}
              onClick={() => onAct(a.action_code)}
              disabled={disabled}
            >
              <span className="action-btn-label">{label}{amtLabel}</span>
              <span className={`action-btn-ev ${evPositive ? 'ev-pos' : 'ev-neg'}`}>
                {fmt(a.ev)}
              </span>
              {a.is_best && <span className="action-btn-star">★</span>}
            </button>
          )
        })}
      </div>

      {best && (
        <div className="action-why">
          <span>{best.why.hand_class}</span>
          {best.why.board_texture && <span>{best.why.board_texture}</span>}
          {best.why.made_hand_now && <span>{best.why.made_hand_now}</span>}
          {best.why.draw_outlook && <span>{best.why.draw_outlook}</span>}
          <span>Equity ~{best.why.estimated_equity_pct.toFixed(0)}%</span>
          {best.why.to_call > 0 && (
            <span>Pot odds {best.why.pot_odds_pct.toFixed(0)}%</span>
          )}
        </div>
      )}
    </div>
  )
}

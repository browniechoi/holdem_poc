import type { ActionEV } from '../types'
import { chenEval } from '../chenFormula'
import {
  ACTION_DISPLAY,
  OVERSIZED_ACTIONS,
  fmtMaybe,
  primaryEv,
  primaryConfidence,
  primaryStderr,
  primaryIsBest,
  primaryIsClearBest,
  dedup,
} from '../evUtils'

interface Props {
  actions: ActionEV[]
  onAct: (code: number) => void
  disabled?: boolean
  showEV: boolean
  onToggleEV: () => void
  street: string
  userHole: string[]
}

export function ActionPanel({ actions, onAct, disabled, showEV, onToggleEV, street, userHole }: Props) {
  const visible = dedup(actions)
  if (!visible.length) return null

  const isPreflop = street === 'preflop'
  const best = visible.find(a => primaryIsBest(a, isPreflop))
  const poolBest = !isPreflop ? visible.find(a => a.is_best) : undefined
  const bestConfidence = best ? primaryConfidence(best, isPreflop) : 'low'
  const bestStderr = best ? primaryStderr(best, isPreflop) : null
  const bestIsClear = best ? primaryIsClearBest(best, isPreflop) : false
  const chen = isPreflop && userHole.length === 2
    ? chenEval(userHole[0], userHole[1])
    : null
  const confidenceLabel = best ? `${bestConfidence}-confidence` : ''
  const bestLabel = best
    ? `${ACTION_DISPLAY[best.action] ?? best.action}${best.amount > 0 && best.action !== 'fold' ? ` $${best.amount}` : ''}`
    : ''
  const downgradeOversizedPoolWinner = !isPreflop
    && !!best
    && !!poolBest
    && poolBest.action_code !== best.action_code
    && OVERSIZED_ACTIONS.has(poolBest.action)
    && bestConfidence === 'low'

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
              <span className="action-hint-label">
                {bestIsClear ? (isPreflop ? 'Best:' : 'Reference best:') : 'Estimate:'}
              </span>{' '}
              {isPreflop
                ? (bestIsClear
                    ? best.reason
                    : `Top line is ${confidenceLabel}; treat the EV map as directional.${bestStderr !== null ? ` ±${bestStderr.toFixed(1)} chips standard error on the current best action.` : ''}`)
                : (bestIsClear
                    ? `Reference EV currently prefers ${bestLabel}. Pool EV stays secondary exploit context.${downgradeOversizedPoolWinner ? ' Pool EV is over-weighting an oversized exploit in this low-confidence node.' : ''}`
                    : `Reference EV top line is ${confidenceLabel}; treat the postflop map as directional.${bestStderr !== null ? ` ±${bestStderr.toFixed(1)} chips standard error on the current reference best action.` : ''}${downgradeOversizedPoolWinner ? ' Pool EV is over-weighting an oversized exploit here, so oversized pool winners are being downgraded.' : ''}`)}
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
          const shownEv = primaryEv(a, isPreflop)
          const evPositive = shownEv >= 0

          return (
            <button
              key={a.action_code}
              className={[
                'action-btn',
                showEV && primaryIsBest(a, isPreflop) && primaryIsClearBest(a, isPreflop) ? 'action-btn--best' : '',
                a.action === 'fold' ? 'action-btn--fold' : '',
              ].filter(Boolean).join(' ')}
              onClick={() => onAct(a.action_code)}
              disabled={disabled}
            >
              <span className="action-btn-label">{label}{amtLabel}</span>
              {showEV && (
                <span className={`action-btn-ev ${evPositive ? 'ev-pos' : 'ev-neg'}`}>
                  {fmtMaybe(shownEv)}
                </span>
              )}
              {showEV && primaryIsBest(a, isPreflop) && primaryIsClearBest(a, isPreflop) && <span className="action-btn-star">★</span>}
            </button>
          )
        })}
      </div>

      {showEV && best && (
        <div className="action-why">
          <span className="why-pill">Confidence {bestConfidence}</span>
          {bestStderr !== null && <span className="why-pill">SE ±{bestStderr.toFixed(1)}</span>}
          {!isPreflop && <span className="why-pill">Postflop primary: Reference EV</span>}
          {downgradeOversizedPoolWinner && <span className="why-pill">Oversized pool exploit downgraded</span>}
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

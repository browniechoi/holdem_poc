import type { ActionEV } from '../types'
import { chenEval } from '../chenFormula'
import {
  ACTION_DISPLAY,
  fmtBreakeven,
  equitySuggestion,
  primaryConfidence,
  primaryStderr,
  primaryIsBest,
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
  const bestConfidence = best ? primaryConfidence(best, isPreflop) : 'low'
  const bestStderr = best ? primaryStderr(best, isPreflop) : null
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
          {showEV ? (
            <div className="action-hint">
              <span className="action-hint-label">Equity guide:</span>{' '}
              How much win-rate each action needs to break even.
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
          const hasBE = a.action !== 'fold' && a.why.breakeven_win_rate_pct > 0

          const botEv = typeof a.ev === 'number' && Number.isFinite(a.ev) ? a.ev : null
          const refEv = typeof a.baseline_ev === 'number' && Number.isFinite(a.baseline_ev) ? a.baseline_ev : null
          const evGap = botEv !== null && refEv !== null ? botEv - refEv : null
          const gapSignificant = evGap !== null && Math.abs(evGap) >= 2.0

          return (
            <button
              key={a.action_code}
              className={[
                'action-btn',
                a.action === 'fold' ? 'action-btn--fold' : '',
              ].filter(Boolean).join(' ')}
              onClick={() => onAct(a.action_code)}
              disabled={disabled}
            >
              <span className="action-btn-label">{label}{amtLabel}</span>
              {showEV && hasBE && (
                <span className={`action-btn-ev ${
                  a.why.estimated_equity_pct >= a.why.breakeven_win_rate_pct ? 'ev-pos' : 'ev-neg'
                }`}>
                  {fmtBreakeven(a.why.breakeven_win_rate_pct)}
                </span>
              )}
              {showEV && botEv !== null && refEv !== null && (
                <span className={`action-btn-ev-detail ${gapSignificant ? (evGap! > 0 ? 'ev-gap--exploit' : 'ev-gap--tight') : ''}`}>
                  {botEv >= 0 ? '+' : ''}{botEv.toFixed(0)} / ref {refEv >= 0 ? '+' : ''}{refEv.toFixed(0)}
                </span>
              )}
            </button>
          )
        })}
      </div>

      {showEV && (() => {
        const callAction = visible.find(a => a.action === 'check/call')
        const eq = visible[0]?.why
        if (!eq) return null
        const estimated = eq.estimated_equity_pct
        const callRequired = callAction?.why.required_equity_pct ?? 0
        const potOdds = callAction?.why.pot_odds_pct ?? 0
        const suggestion = callRequired > 0 ? equitySuggestion(estimated, callRequired) : null
        return (
          <div className={`equity-summary ${suggestion ? (suggestion.favorable ? 'equity-summary--good' : 'equity-summary--bad') : 'equity-summary--good'}`}>
            <span>Your equity: ~{estimated.toFixed(0)}%</span>
            {callRequired > 0 ? (
              <>
                <span className="equity-summary-sep">·</span>
                <span>Need {callRequired.toFixed(0)}% to call (pot odds {potOdds.toFixed(0)}%)</span>
                <span className="equity-summary-sep">→</span>
                <span className="equity-summary-verdict">{suggestion!.text}</span>
              </>
            ) : (
              <>
                <span className="equity-summary-sep">·</span>
                <span>Check is free</span>
              </>
            )}
          </div>
        )
      })()}

      {showEV && best && (
        <div className="action-why">
          <span className="why-pill">Confidence {bestConfidence}</span>
          {bestStderr !== null && <span className="why-pill">SE ±{bestStderr.toFixed(1)}</span>}
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

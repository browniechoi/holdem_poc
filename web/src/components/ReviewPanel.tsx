import type { ActionEV } from '../types'
import {
  ACTION_DISPLAY,
  fmtBreakeven,
  primaryConfidence,
  primaryStderr,
  primaryIsBest,
  dedup,
} from '../evUtils'

interface Props {
  chosenCode: number
  actions: ActionEV[]
  street: string
  onContinue: () => void
  onUndo?: () => void
  onSkip?: () => void
}

export function ReviewPanel({ chosenCode, actions, street, onContinue, onUndo, onSkip }: Props) {
  const visible = dedup(actions)
  const isPreflop = street === 'preflop'
  const chosen = visible.find(a => a.action_code === chosenCode)
    ?? actions.find(a => a.action_code === chosenCode)
  const best = visible.find(a => primaryIsBest(a, isPreflop)) ?? actions.find(a => primaryIsBest(a, isPreflop))
  const bestConfidence = best ? primaryConfidence(best, isPreflop) : 'low'
  const bestStderr = best ? primaryStderr(best, isPreflop) : null
  const chosenLabel = chosen
    ? (ACTION_DISPLAY[chosen.action] ?? chosen.action) +
      (chosen.amount > 0 && chosen.action !== 'fold' ? ` $${chosen.amount}` : '')
    : '—'

  return (
    <div className="review-panel">
      <div className="review-header">
        <span className="review-label">You chose:</span>
        <span className="review-chosen">{chosenLabel}</span>
        <span className="review-note">
          Equity-based guidance
        </span>
      </div>

      <div className="action-buttons">
        {visible.map(a => {
          const label = ACTION_DISPLAY[a.action] ?? a.action
          const amtLabel = a.amount > 0 && a.action !== 'fold' ? ` $${a.amount}` : ''
          const isChosen = a.action_code === chosenCode
          const hasBE = a.action !== 'fold' && a.why.breakeven_win_rate_pct > 0
          const botEv = typeof a.ev === 'number' && Number.isFinite(a.ev) ? a.ev : null
          const refEv = typeof a.baseline_ev === 'number' && Number.isFinite(a.baseline_ev) ? a.baseline_ev : null
          const evGap = botEv !== null && refEv !== null ? botEv - refEv : null
          const gapSignificant = evGap !== null && Math.abs(evGap) >= 2.0

          return (
            <div
              key={a.action_code}
              className={[
                'action-btn',
                a.action === 'fold' ? 'action-btn--fold' : '',
                isChosen ? 'action-btn--chosen' : '',
              ].filter(Boolean).join(' ')}
            >
              <span className="action-btn-label">{label}{amtLabel}</span>
              {hasBE ? (
                <span className={`action-btn-ev ${
                  a.why.estimated_equity_pct >= a.why.breakeven_win_rate_pct ? 'ev-pos' : 'ev-neg'
                }`}>
                  {fmtBreakeven(a.why.breakeven_win_rate_pct)}
                </span>
              ) : null}
              {botEv !== null && refEv !== null && (
                <span className={`action-btn-ev-detail ${gapSignificant ? (evGap! > 0 ? 'ev-gap--exploit' : 'ev-gap--tight') : ''}`}>
                  {botEv >= 0 ? '+' : ''}{botEv.toFixed(0)} / ref {refEv >= 0 ? '+' : ''}{refEv.toFixed(0)}
                </span>
              )}
            </div>
          )
        })}
      </div>

      <div className="ev-bot-warning">EV reflects tendencies of these specific bots, not sound general strategy</div>

      {best && (
        <div className="action-why">
          <span className="why-pill">Confidence {bestConfidence}</span>
          {bestStderr !== null && <span className="why-pill">SE ±{bestStderr.toFixed(1)}</span>}
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
        const chosenEV = typeof chosen.ev === 'number' && Number.isFinite(chosen.ev) ? chosen.ev : null
        const baselineEV = typeof chosen.baseline_ev === 'number' && Number.isFinite(chosen.baseline_ev) ? chosen.baseline_ev : null
        const gap = chosenEV !== null && baselineEV !== null ? chosenEV - baselineEV : null
        const significant = gap !== null && Math.abs(gap) >= 2.0
        return (
          <div className="ev-compare">
            <strong>Bot EV:</strong> {chosenEV !== null ? `${chosenEV >= 0 ? '+' : ''}${chosenEV.toFixed(1)}` : '—'}
            {' '}·{' '}
            <strong>Reference EV:</strong> {baselineEV !== null ? `${baselineEV >= 0 ? '+' : ''}${baselineEV.toFixed(1)}` : '—'}
            {significant && gap !== null && (
              <span className="ev-gap-warning">
                {' '}— {gap > 0
                  ? `bots overcall (+${gap.toFixed(1)} exploit)`
                  : `bots play tighter (${gap.toFixed(1)} vs ref)`}
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

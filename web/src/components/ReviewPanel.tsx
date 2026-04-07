import type { ActionEV } from '../types'
import {
  ACTION_DISPLAY,
  OVERSIZED_ACTIONS,
  fmtMaybe,
  primaryEv,
  primaryConfidence,
  primaryStderr,
  primaryIsBest,
  primaryIsClearBest,
  isNearOptimal,
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
  const poolBest = !isPreflop ? visible.find(a => a.is_best) ?? actions.find(a => a.is_best) : undefined
  const bestConfidence = best ? primaryConfidence(best, isPreflop) : 'low'
  const bestStderr = best ? primaryStderr(best, isPreflop) : null
  const bestIsClear = best ? primaryIsClearBest(best, isPreflop) : false
  const preflopGradeable = isPreflop && !!bestIsClear
  const nearOpt = preflopGradeable && chosen ? isNearOptimal(chosen, actions) : false
  const chosenLabel = chosen
    ? (ACTION_DISPLAY[chosen.action] ?? chosen.action) +
      (chosen.amount > 0 && chosen.action !== 'fold' ? ` $${chosen.amount}` : '')
    : '—'
  const downgradeOversizedPoolWinner = !isPreflop
    && !!best
    && !!poolBest
    && poolBest.action_code !== best.action_code
    && OVERSIZED_ACTIONS.has(poolBest.action)
    && bestConfidence === 'low'

  return (
    <div className="review-panel">
      <div className="review-header">
        <span className="review-label">You chose:</span>
        <span className="review-chosen">{chosenLabel}</span>
        {preflopGradeable ? (
          <span className={`review-optimal ${nearOpt ? 'yes' : 'no'}`}>
            {nearOpt ? '✓ Near-optimal' : '✗ Suboptimal'}
          </span>
        ) : isPreflop && best ? (
          <span className="review-note">
            Preflop estimate: {bestConfidence}-confidence
            {bestIsClear ? '' : ' · directional only'}
          </span>
        ) : best ? (
          <span className="review-note">
            Postflop reference estimate: {bestConfidence}-confidence
            {bestIsClear ? '' : ' · directional only'}
            {downgradeOversizedPoolWinner ? ' · oversized pool winners downgraded' : ''}
          </span>
        ) : (
          <span className="review-note">
            EV unavailable.
          </span>
        )}
      </div>

      <div className="action-buttons">
        {visible.map(a => {
          const label = ACTION_DISPLAY[a.action] ?? a.action
          const amtLabel = a.amount > 0 && a.action !== 'fold' ? ` $${a.amount}` : ''
          const isChosen = a.action_code === chosenCode
          const shownEv = primaryEv(a, isPreflop)
          const evPositive = shownEv >= 0

          return (
            <div
              key={a.action_code}
              className={[
                'action-btn',
                primaryIsBest(a, isPreflop) && primaryIsClearBest(a, isPreflop) ? 'action-btn--best' : '',
                a.action === 'fold' ? 'action-btn--fold' : '',
                isChosen ? 'action-btn--chosen' : '',
              ].filter(Boolean).join(' ')}
            >
              <span className="action-btn-label">{label}{amtLabel}</span>
              <span className={`action-btn-ev ${evPositive ? 'ev-pos' : 'ev-neg'}`}>
                {fmtMaybe(shownEv)}
              </span>
              {primaryIsBest(a, isPreflop) && primaryIsClearBest(a, isPreflop) && <span className="action-btn-star">★</span>}
            </div>
          )
        })}
      </div>

      {best && (
        <div className="action-why">
          <span className="why-pill">Confidence {bestConfidence}</span>
          {bestStderr !== null && <span className="why-pill">SE ±{bestStderr.toFixed(1)}</span>}
          {!isPreflop && <span className="why-pill">Postflop primary: Reference EV</span>}
          {downgradeOversizedPoolWinner && <span className="why-pill">Oversized pool exploit downgraded</span>}
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
        const primaryLabel = isPreflop ? 'EV' : 'Reference estimate'
        const secondaryLabel = isPreflop ? 'Reference estimate' : 'Pool estimate'
        return (
          <div className="ev-compare">
            {isPreflop ? (
              <>
                <strong>{primaryLabel}:</strong> {chosenEV !== null ? `${chosenEV >= 0 ? '+' : ''}${chosenEV.toFixed(1)}` : '—'}
                {' '}·{' '}
                <strong>{secondaryLabel}:</strong> {baselineEV !== null ? `${baselineEV >= 0 ? '+' : ''}${baselineEV.toFixed(1)}` : '—'}
              </>
            ) : (
              <>
                <strong>{primaryLabel}:</strong> {baselineEV !== null ? `${baselineEV >= 0 ? '+' : ''}${baselineEV.toFixed(1)}` : '—'}
                {' '}·{' '}
                <strong>{secondaryLabel}:</strong> {chosenEV !== null ? `${chosenEV >= 0 ? '+' : ''}${chosenEV.toFixed(1)}` : '—'}
              </>
            )}
            {significant && gap !== null && (
              <span className="ev-gap-warning">
                {' '}— {gap > 0
                  ? `these bots call too much (+${gap.toFixed(1)} to exploit)`
                  : `these bots play tighter (${gap.toFixed(1)} vs reference)`}
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

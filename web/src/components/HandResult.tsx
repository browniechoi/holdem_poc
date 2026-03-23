import type { PublicState } from '../types'
import { Card } from './Card'

interface DecisionRecord {
  label: string
  ev: number
  bestEV: number
  nearOptimal: boolean
}

interface Props {
  state: PublicState
  decisions: DecisionRecord[]
  onNext: () => void
}

export function HandResult({ state, decisions, onNext }: Props) {
  const user = state.players.find(p => p.is_user)
  const won = user && state.winner_names.includes(user.name)
  const delta = user?.hand_delta ?? 0

  return (
    <div className="hand-result">
      <div className={`hand-result-outcome ${won ? 'won' : delta < 0 ? 'lost' : 'push'}`}>
        {won ? '▲ You win' : delta < 0 ? '▼ You lose' : '— Push'}
        <span className="hand-result-delta">
          {delta >= 0 ? `+$${delta}` : `-$${Math.abs(delta)}`}
        </span>
      </div>

      {state.winner_names.length > 0 && (
        <div className="hand-result-winners">
          {state.players
            .filter(p => state.winner_names.includes(p.name) && p.hole_cards.length === 2)
            .map(p => (
              <div key={p.name} className="hand-result-player">
                <span className="hand-result-name">{p.name}</span>
                <div className="hand-result-cards">
                  {p.hole_cards.map((c, i) => <Card key={i} card={c} small />)}
                </div>
                {p.hand_rank && <span className="hand-result-rank">{p.hand_rank}</span>}
              </div>
            ))}
        </div>
      )}

      {decisions.length > 0 && (
        <div className="decision-summary">
          <div className="decision-summary-title">Your decisions this hand</div>
          <div className="decision-summary-rows">
            {decisions.map((d, i) => (
              <div key={i} className={`decision-chip ${d.nearOptimal ? 'optimal' : 'subopt'}`}>
                {d.label} {d.nearOptimal ? '✓' : `✗ (best: ${d.bestEV >= 0 ? '+' : ''}${d.bestEV.toFixed(1)})`}
              </div>
            ))}
          </div>
        </div>
      )}

      <button className="next-hand-btn" onClick={onNext}>
        Next hand →
      </button>
    </div>
  )
}

// Export the type so App.tsx can use it
export type { DecisionRecord }

import type { PublicState } from '../types'
import { Card } from './Card'

interface Props {
  state: PublicState
  onNext: () => void
}

export function HandResult({ state, onNext }: Props) {
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

      <div className="hand-result-log">
        {state.action_log.slice(-6).map((line, i) => (
          <div key={i} className="hand-result-log-line">{line}</div>
        ))}
      </div>

      <button className="next-hand-btn" onClick={onNext}>
        Next hand →
      </button>
    </div>
  )
}

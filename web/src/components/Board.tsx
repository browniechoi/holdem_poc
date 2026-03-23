import type { PublicState } from '../types'
import { Card } from './Card'

interface Props {
  state: PublicState
}

export function Board({ state }: Props) {
  const { board, pot, street } = state

  // Show placeholder slots for unrevealed cards
  const slots: (string | null)[] = [...board]
  const target = street === 'preflop' ? 0 : street === 'flop' ? 3 : street === 'turn' ? 4 : 5
  while (slots.length < target) slots.push(null)

  return (
    <div className="board">
      <div className="board-cards">
        {slots.map((card, i) =>
          card
            ? <Card key={i} card={card} />
            : <div key={i} className="card card--placeholder" />
        )}
      </div>
      <div className="board-pot">Pot <strong>${pot}</strong></div>
      <div className="board-street">{street.toUpperCase()}</div>
    </div>
  )
}

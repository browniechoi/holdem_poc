interface CardProps {
  card?: string      // e.g. "As", "Kh", "2d" — not required when faceDown
  faceDown?: boolean
  small?: boolean
}

const SUIT_SYMBOL: Record<string, string> = {
  s: '♠', h: '♥', d: '♦', c: '♣',
}
const RED_SUITS = new Set(['h', 'd'])

export function Card({ card, faceDown = false, small = false }: CardProps) {
  const cls = `card${small ? ' card--sm' : ''}${faceDown ? ' card--back' : ''}`

  if (faceDown) {
    return <div className={cls}><span className="card-back-pattern">🂠</span></div>
  }

  const rank = card!.slice(0, -1)
  const suit = card!.slice(-1)
  const red = RED_SUITS.has(suit)

  return (
    <div className={cls} data-red={red || undefined}>
      <span className="card-rank">{rank}</span>
      <span className="card-suit">{SUIT_SYMBOL[suit] ?? suit}</span>
    </div>
  )
}

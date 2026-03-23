interface CardProps {
  card?: string      // e.g. "As", "Kh", "2d" — not required when faceDown
  faceDown?: boolean
  small?: boolean
  dealt?: boolean    // trigger deal-in animation
  delay?: number     // animation delay in seconds
}

const SUIT_SYMBOL: Record<string, string> = {
  s: '♠', h: '♥', d: '♦', c: '♣',
}
const RED_SUITS = new Set(['h', 'd'])

export function Card({ card, faceDown = false, small = false, dealt = false, delay = 0 }: CardProps) {
  const cls = [
    'card',
    small ? 'card--sm' : '',
    faceDown ? 'card--back' : '',
    dealt ? 'card--dealt' : '',
  ].filter(Boolean).join(' ')

  const style = dealt && delay > 0 ? { animationDelay: `${delay}s` } : undefined

  if (faceDown) {
    return <div className={cls} style={style}><span className="card-back-pattern">🂠</span></div>
  }

  const rank = card!.slice(0, -1)
  const suit = card!.slice(-1)
  const red = RED_SUITS.has(suit)

  return (
    <div className={cls} style={style} data-red={red || undefined}>
      <span className="card-rank">{rank}</span>
      <span className="card-suit">{SUIT_SYMBOL[suit] ?? suit}</span>
    </div>
  )
}

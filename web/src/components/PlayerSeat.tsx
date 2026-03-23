import type { PublicPlayer } from '../types'
import { Card } from './Card'

interface Props {
  player: PublicPlayer
  isDealer: boolean
  isSB: boolean
  isBB: boolean
  isActing: boolean
  isWinner: boolean
  showCards: boolean   // true at showdown or for user always
  position: number     // seat index 0-5
  isThinking?: boolean // bots deciding (loading phase)
  isBotActing?: boolean // this specific bot is currently deciding (animation)
  dealKey?: number     // increments each new hand to re-trigger deal animation
}

const ACTION_LABEL: Record<string, string> = {
  fold: 'Folded',
  'check/call': 'Check/Call',
  check: 'Check',
  call: 'Call',
  ' ': '',
}

function actionLabel(raw: string) {
  if (!raw || raw.trim() === '') return ''
  if (ACTION_LABEL[raw]) return ACTION_LABEL[raw]
  if (raw.startsWith('bet_')) return 'Bet'
  if (raw.startsWith('raise_')) return 'Raise'
  return raw
}

export function PlayerSeat({ player, isDealer, isSB, isBB, isActing, isWinner, showCards, position, isThinking, isBotActing, dealKey }: Props) {
  const folded = !player.in_hand
  const classes = [
    'seat',
    `seat--pos${position}`,
    isActing ? 'seat--acting' : '',
    isBotActing ? 'seat--bot-deciding' : '',
    isWinner ? 'seat--winner' : '',
    folded && !isWinner ? 'seat--folded' : '',
    player.is_user ? 'seat--user' : '',
    isThinking && !folded && !player.is_user ? 'seat--thinking' : '',
  ].filter(Boolean).join(' ')

  return (
    <div className={classes}>
      <div className="seat-badges">
        {isDealer && <span className="badge badge-d">D</span>}
        {isSB && <span className="badge badge-sb">SB</span>}
        {isBB && <span className="badge badge-bb">BB</span>}
      </div>

      <div className="seat-cards">
        {player.in_hand ? (
          (showCards && player.hole_cards.length === 2)
            ? player.hole_cards.map((c, i) => (
                <Card key={`${dealKey ?? 0}-${i}`} card={c} small dealt />
              ))
            : [
                <Card key={`${dealKey ?? 0}-0`} faceDown small dealt />,
                <Card key={`${dealKey ?? 0}-1`} faceDown small dealt delay={0.08} />,
              ]
        ) : player.is_user && player.hole_cards.length === 2 ? (
          // Show user's own cards even after folding — useful for learning
          <div className="seat-cards--folded-user">
            {player.hole_cards.map((c, i) => (
              <Card key={i} card={c} small />
            ))}
          </div>
        ) : (
          <span className="seat-folded-x">✕</span>
        )}
      </div>

      <div className="seat-info">
        <div className="seat-name">{player.name}</div>
        <div className="seat-stack">${player.stack}</div>
        {player.committed_street > 0 && (
          <div className="seat-bet">${player.committed_street}</div>
        )}
        {player.hand_rank && (
          <div className="seat-rank">{player.hand_rank}</div>
        )}
      </div>

      {player.last_action && player.last_action.trim() && (
        <div className="seat-action">{actionLabel(player.last_action)}</div>
      )}
    </div>
  )
}

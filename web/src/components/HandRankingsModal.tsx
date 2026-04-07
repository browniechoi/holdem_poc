import { useState } from 'react'
import { chenScore, type HandTier } from '../chenFormula'

interface Props {
  onClose: () => void
}

type RankingsTab = 'made' | 'starting'

const RANKS = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2'] as const

const MADE_HAND_RANKINGS = [
  { rank: 1, name: 'Royal Flush', example: 'A K Q J 10 ♠', desc: 'A, K, Q, J, 10 of the same suit. Unbeatable.' },
  { rank: 2, name: 'Straight Flush', example: '9 8 7 6 5 ♥', desc: 'Five consecutive cards, all same suit.' },
  { rank: 3, name: 'Four of a Kind', example: 'K K K K 2', desc: 'Four cards of the same rank.' },
  { rank: 4, name: 'Full House', example: 'J J J 9 9', desc: 'Three of a kind + a pair.' },
  { rank: 5, name: 'Flush', example: 'A J 8 5 2 ♦', desc: 'Any five cards of the same suit (not consecutive).' },
  { rank: 6, name: 'Straight', example: '8 7 6 5 4', desc: 'Five consecutive cards of any suit. Ace can be high (A-K-Q-J-10) or low (A-2-3-4-5).' },
  { rank: 7, name: 'Three of a Kind', example: '7 7 7 K 3', desc: 'Three cards of the same rank.' },
  { rank: 8, name: 'Two Pair', example: 'Q Q 4 4 9', desc: 'Two different pairs.' },
  { rank: 9, name: 'One Pair', example: '10 10 A 7 2', desc: 'Two cards of the same rank.' },
  { rank: 10, name: 'High Card', example: 'A K J 8 3', desc: 'No matching cards. Best single card wins.' },
]

function tierFromChenScore(score: number): HandTier {
  if (score >= 12) return 'premium'
  if (score >= 10) return 'strong'
  if (score >= 7) return 'playable'
  if (score >= 5) return 'marginal'
  return 'weak'
}

function cellLabel(rowRank: string, colRank: string, rowIdx: number, colIdx: number) {
  if (rowIdx === colIdx) return `${rowRank}${colRank}`
  if (rowIdx < colIdx) return `${rowRank}${colRank}s`
  return `${colRank}${rowRank}o`
}

function suitedCards(rowRank: string, colRank: string, suited: boolean) {
  const high = `${rowRank}h`
  const low = `${colRank}${suited ? 'h' : 'd'}`
  return [high, low] as const
}

const STARTING_HAND_GRID = RANKS.map((rowRank, rowIdx) =>
  RANKS.map((colRank, colIdx) => {
    const label = cellLabel(rowRank, colRank, rowIdx, colIdx)
    const suited = rowIdx < colIdx
    const [c1, c2] = rowIdx === colIdx
      ? [`${rowRank}h`, `${colRank}d`] as const
      : suitedCards(rowRank, colRank, suited)
    const score = chenScore(c1, c2)
    return {
      label,
      score,
      tier: tierFromChenScore(score),
    }
  })
)

const TIER_LEGEND: Array<{ tier: HandTier; label: string; note: string }> = [
  { tier: 'premium', label: 'Premium', note: 'Raise/3-bet aggressively in most games.' },
  { tier: 'strong', label: 'Strong', note: 'Profitable opens and continues in many seats.' },
  { tier: 'playable', label: 'Playable', note: 'Position-sensitive; often fine in later seats.' },
  { tier: 'marginal', label: 'Marginal', note: 'Needs table, stack, and position help.' },
  { tier: 'weak', label: 'Weak', note: 'Usually fold. Do not justify these by curiosity.' },
]

export function HandRankingsModal({ onClose }: Props) {
  const [tab, setTab] = useState<RankingsTab>('made')

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box modal-box--wide" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <span className="modal-title">Poker Cheat Sheets</span>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-tabs">
          <button
            className={`modal-tab ${tab === 'made' ? 'modal-tab--active' : ''}`}
            onClick={() => setTab('made')}
          >
            Hand Rankings
          </button>
          <button
            className={`modal-tab ${tab === 'starting' ? 'modal-tab--active' : ''}`}
            onClick={() => setTab('starting')}
          >
            Starting Hands
          </button>
        </div>
        <div className="modal-body">
          {tab === 'made' ? (
            <>
              <p className="modal-note">Hands ranked from strongest (#1) to weakest (#10). Best 5-card hand wins.</p>
              <table className="rankings-table">
                <tbody>
                  {MADE_HAND_RANKINGS.map(r => (
                    <tr key={r.rank} className="rankings-row">
                      <td className="rankings-num">{r.rank}</td>
                      <td className="rankings-name">{r.name}</td>
                      <td className="rankings-example">{r.example}</td>
                      <td className="rankings-desc">{r.desc}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div className="modal-tip">
                <strong>Tip:</strong> The board is shared. Your best hand uses any 5 of your 2 hole cards + 5 board cards.
              </div>
            </>
          ) : (
            <>
              <p className="modal-note">
                Starting-hand cheat sheet uses Chen score tiers as a quick strength guide. This is a relative strength map, not a full position-specific opening chart.
              </p>
              <div className="starting-hand-legend">
                {TIER_LEGEND.map(item => (
                  <div key={item.tier} className={`starting-hand-legend-item starting-hand-legend-item--${item.tier}`}>
                    <strong>{item.label}</strong>
                    <span>{item.note}</span>
                  </div>
                ))}
              </div>
              <div className="starting-hand-grid-wrap">
                <table className="starting-hand-grid">
                  <thead>
                    <tr>
                      <th />
                      {RANKS.map(rank => <th key={rank}>{rank}</th>)}
                    </tr>
                  </thead>
                  <tbody>
                    {STARTING_HAND_GRID.map((row, rowIdx) => (
                      <tr key={RANKS[rowIdx]}>
                        <th>{RANKS[rowIdx]}</th>
                        {row.map(cell => (
                          <td
                            key={cell.label}
                            className={`starting-hand-cell starting-hand-cell--${cell.tier}`}
                            title={`${cell.label} · Chen ${cell.score}`}
                          >
                            <span className="starting-hand-cell-label">{cell.label}</span>
                            <span className="starting-hand-cell-score">{cell.score}</span>
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="modal-tip">
                <strong>How to read it:</strong> Pairs are on the diagonal. Upper-right is suited, lower-left is offsuit. Premium and strong cells should dominate your value ranges; marginal and weak cells need position and table context.
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

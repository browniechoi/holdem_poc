interface Props {
  onClose: () => void
}

const RANKINGS = [
  { rank: 1, name: 'Royal Flush',    example: 'A K Q J 10 ♠',  desc: 'A, K, Q, J, 10 of the same suit. Unbeatable.' },
  { rank: 2, name: 'Straight Flush', example: '9 8 7 6 5 ♥',   desc: 'Five consecutive cards, all same suit.' },
  { rank: 3, name: 'Four of a Kind', example: 'K K K K 2',      desc: 'Four cards of the same rank.' },
  { rank: 4, name: 'Full House',     example: 'J J J 9 9',      desc: 'Three of a kind + a pair.' },
  { rank: 5, name: 'Flush',          example: 'A J 8 5 2 ♦',   desc: 'Any five cards of the same suit (not consecutive).' },
  { rank: 6, name: 'Straight',       example: '8 7 6 5 4',      desc: 'Five consecutive cards of any suit. Ace can be high (A-K-Q-J-10) or low (A-2-3-4-5).' },
  { rank: 7, name: 'Three of a Kind',example: '7 7 7 K 3',      desc: 'Three cards of the same rank.' },
  { rank: 8, name: 'Two Pair',       example: 'Q Q 4 4 9',      desc: 'Two different pairs.' },
  { rank: 9, name: 'One Pair',       example: '10 10 A 7 2',    desc: 'Two cards of the same rank.' },
  { rank: 10, name: 'High Card',     example: 'A K J 8 3',      desc: 'No matching cards. Best single card wins.' },
]

export function HandRankingsModal({ onClose }: Props) {
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <span className="modal-title">Poker Hand Rankings</span>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          <p className="modal-note">Hands ranked from strongest (#1) to weakest (#10). Best 5-card hand wins.</p>
          <table className="rankings-table">
            <tbody>
              {RANKINGS.map(r => (
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
            <strong>Tip:</strong> The board (community cards) are shared — your best hand uses any 5 of your 2 hole cards + 5 board cards.
          </div>
        </div>
      </div>
    </div>
  )
}

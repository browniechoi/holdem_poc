// Chen formula for preflop hand strength scoring.
// Reference: Bill Chen & Jerrod Ankenman "The Mathematics of Poker"

const HIGH_CARD_SCORE: Record<number, number> = {
  14: 10, 13: 8, 12: 7, 11: 6, 10: 5,
  9: 4.5, 8: 4, 7: 3.5, 6: 3, 5: 2.5, 4: 2, 3: 1.5, 2: 1,
}

function parseRank(card: string): number {
  const r = card[0]
  if (r === 'A') return 14
  if (r === 'K') return 13
  if (r === 'Q') return 12
  if (r === 'J') return 11
  if (r === 'T') return 10
  return parseInt(r, 10)
}

export function chenScore(c1: string, c2: string): number {
  const r1 = parseRank(c1)
  const r2 = parseRank(c2)
  const suited = c1[c1.length - 1] === c2[c2.length - 1]
  const hi = Math.max(r1, r2)
  const lo = Math.min(r1, r2)

  let score = HIGH_CARD_SCORE[hi] ?? 1

  // Pocket pair: double value, min 5
  if (r1 === r2) {
    score = Math.max(score * 2, 5)
    return Math.round(score * 2) / 2
  }

  // Suited bonus
  if (suited) score += 2

  // Gap penalty
  const gap = hi - lo - 1
  if (gap === 1) score -= 1
  else if (gap === 2) score -= 2
  else if (gap === 3) score -= 4
  else if (gap >= 4) score -= 5

  // Straight potential: connected or 1-gap below a queen
  if (gap <= 1 && hi < 12) score += 1

  return Math.round(score * 2) / 2
}

export type HandTier = 'premium' | 'strong' | 'playable' | 'marginal' | 'weak'

export interface ChenResult {
  score: number
  tier: HandTier
  label: string
  tip: string
}

const TIER_INFO: Record<HandTier, { label: string; tip: string }> = {
  premium:  { label: 'Premium',  tip: 'Top-tier starting hands. Raise or 3-bet aggressively.' },
  strong:   { label: 'Strong',   tip: 'Strong hand. Open-raise in most positions.' },
  playable: { label: 'Playable', tip: 'Decent hand. Can open in late position; be selective early.' },
  marginal: { label: 'Marginal', tip: 'Below average. Fold in early position; can steal from the button.' },
  weak:     { label: 'Weak',     tip: 'Trash. Fold unless stealing from a late position vs tight players.' },
}

export function chenEval(c1: string, c2: string): ChenResult {
  const score = chenScore(c1, c2)
  const tier: HandTier =
    score >= 12 ? 'premium'  :
    score >= 10 ? 'strong'   :
    score >= 7  ? 'playable' :
    score >= 5  ? 'marginal' : 'weak'
  return { score, tier, ...TIER_INFO[tier] }
}

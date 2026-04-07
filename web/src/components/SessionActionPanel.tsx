import type { DecisionRecord } from '../evUtils'

interface Props {
  decisions: DecisionRecord[]
}

function fmtMaybe(ev: number | undefined) {
  if (typeof ev !== 'number' || !Number.isFinite(ev)) return '—'
  return `${ev >= 0 ? '+' : ''}${ev.toFixed(1)}`
}

export function SessionActionPanel({ decisions }: Props) {
  const gradedCount = decisions.filter(d => d.graded).length
  const gradedNearOpt = decisions.filter(d => d.graded && d.nearOptimal).length

  return (
    <aside className="session-panel">
      <div className="session-panel-header">
        <div className="session-panel-title">Current Session</div>
        <div className="session-panel-stats">
          <span>{decisions.length} decisions</span>
          {gradedCount > 0 && (
            <span>{Math.round((gradedNearOpt / gradedCount) * 100)}% graded near-opt</span>
          )}
        </div>
      </div>

      {decisions.length === 0 ? (
        <div className="session-panel-empty">
          Your actions will accumulate here for the current browser session.
        </div>
      ) : (
        <div className="session-panel-list">
          {[...decisions].reverse().map(decision => (
            <div key={decision.id} className={`session-decision ${decision.graded ? (decision.nearOptimal ? 'session-decision--good' : 'session-decision--bad') : 'session-decision--neutral'}`}>
              <div className="session-decision-top">
                <span className="session-decision-hand">H{decision.handNo}</span>
                <span className="session-decision-street">{decision.street.toUpperCase()}</span>
                <span className="session-decision-label">{decision.label}</span>
              </div>
              <div className="session-decision-bottom">
                {decision.graded ? (
                  <>
                    <span>{decision.nearOptimal ? 'Near-optimal' : 'Suboptimal'}</span>
                    <span>EV {fmtMaybe(decision.ev)}</span>
                    <span>Best {fmtMaybe(decision.bestEV)}</span>
                  </>
                ) : (
                  <span>{decision.reviewNote ?? 'Estimate only'}</span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </aside>
  )
}

import { useEffect, useRef, useState, useCallback } from 'react'
import { Game } from './game'
import type { PublicState, ActionEV } from './types'
import { PlayerSeat } from './components/PlayerSeat'
import { Board } from './components/Board'
import { ActionPanel } from './components/ActionPanel'
import { ReviewPanel } from './components/ReviewPanel'
import { HandResult } from './components/HandResult'
import type { DecisionRecord } from './components/HandResult'
import { LogStrip } from './components/LogStrip'
import { HandRankingsModal } from './components/HandRankingsModal'
import './App.css'

const SEAT_STYLE: React.CSSProperties[] = [
  { bottom: 0,     left: '50%',  transform: 'translateX(-50%)' },
  { top:  '75%',   left: '6%',   transform: 'translate(-50%, -50%)' },
  { top:  '25%',   left: '6%',   transform: 'translate(-50%, -50%)' },
  { top:  '8%',    left: '25%',  transform: 'translate(-50%, -50%)' },
  { top:  '8%',    left: '75%',  transform: 'translate(-50%, -50%)' },
  { top:  '25%',   left: '94%',  transform: 'translate(-50%, -50%)' },
  { top:  '75%',   left: '94%',  transform: 'translate(-50%, -50%)' },
  { bottom: 0,     left: '27%',  transform: 'translateX(-50%)' },
  { bottom: 0,     left: '73%',  transform: 'translateX(-50%)' },
]

const BOT_STEP_MS = 380

type Phase = 'loading' | 'user_turn' | 'reviewing' | 'bot_acting' | 'hand_over'

interface SessionStats {
  handsPlayed: number
  decisions: number
  nearOptimal: number
}

interface ReviewData {
  chosenCode: number
  actions: ActionEV[]
}

function isNearOptimal(chosen: ActionEV, allActions: ActionEV[]): boolean {
  const bestEV = Math.max(...allActions.map(a => a.ev))
  const tolerance = Math.max(Math.abs(bestEV) * 0.05, 2.0)
  return chosen.ev >= bestEV - tolerance
}

export default function App() {
  const gameRef = useRef<Game | null>(null)
  const [phase, setPhase] = useState<Phase>('loading')
  const [state, setState] = useState<PublicState | null>(null)
  const [actions, setActions] = useState<ActionEV[]>([])
  const [actionsLoading, setActionsLoading] = useState(false)
  const [showEV, setShowEV] = useState(false)
  const [review, setReview] = useState<ReviewData | null>(null)
  const [session, setSession] = useState<SessionStats>({ handsPlayed: 0, decisions: 0, nearOptimal: 0 })
  const [handDecisions, setHandDecisions] = useState<DecisionRecord[]>([])
  const [showRankings, setShowRankings] = useState(false)
  const [canUndo, setCanUndo] = useState(false)
  const [dealKey, setDealKey] = useState(0)
  const [userFolded, setUserFolded] = useState(false)
  // Persistent log accumulates across hands so players can scroll back
  const [fullLog, setFullLog] = useState<string[]>([])
  const prevLogLenRef = useRef(0)

  // Ref so the animation loop can access a fresh ref without stale closure
  const animLoopRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const refresh = useCallback((g: Game) => {
    const s = g.state()
    setState(s)
    setCanUndo(g.canUndo)
    // Append any new WASM log entries since last refresh to persistent log
    setFullLog(prev => {
      // If WASM log shrunk, a new hand cleared it — start from 0
      const base = s.action_log.length < prevLogLenRef.current ? 0 : prevLogLenRef.current
      const newEntries = s.action_log.slice(base)
      prevLogLenRef.current = s.action_log.length
      return newEntries.length ? [...prev, ...newEntries] : prev
    })
    if (s.hand_over) {
      setPhase('hand_over')
      setActions([])
    } else {
      setActionsLoading(true)
      setShowEV(false)
      setTimeout(() => {
        setActions(g.actions())
        setActionsLoading(false)
        setPhase('user_turn')
      }, 0)
    }
  }, [])

  /** Animate bots stepping one at a time, then call refresh when done. */
  const startBotAnimation = useCallback((g: Game) => {
    setPhase('bot_acting')

    function step() {
      const more = g.stepOnce()
      const s = g.state()
      setState(s)
      // Flush new log entries that appeared during this bot step
      setFullLog(prev => {
        const base = s.action_log.length < prevLogLenRef.current ? 0 : prevLogLenRef.current
        const newEntries = s.action_log.slice(base)
        prevLogLenRef.current = s.action_log.length
        return newEntries.length ? [...prev, ...newEntries] : prev
      })
      if (more) {
        animLoopRef.current = setTimeout(step, BOT_STEP_MS)
      } else {
        // All bots done — compute EVs and hand control back to user
        refresh(g)
      }
    }
    // Brief initial pause so the user sees their own action settle first
    animLoopRef.current = setTimeout(step, BOT_STEP_MS)
  }, [refresh])

  useEffect(() => {
    const g = new Game()
    gameRef.current = g
    refresh(g)
    return () => {
      if (animLoopRef.current) clearTimeout(animLoopRef.current)
      g.free()
    }
  }, [refresh])

  const handleAct = useCallback((code: number) => {
    const g = gameRef.current
    if (!g || phase !== 'user_turn') return

    const chosen = actions.find(a => a.action_code === code)!
    const nearOpt = isNearOptimal(chosen, actions)
    const bestEV = Math.max(...actions.map(a => a.ev))
    const label = chosen.action + (chosen.amount > 0 && chosen.action !== 'fold' ? ` $${chosen.amount}` : '')

    setHandDecisions(prev => [...prev, {
      label, ev: chosen.ev, bestEV, nearOptimal: nearOpt,
    }])
    if (chosen.action === 'fold') setUserFolded(true)
    setSession(s => ({
      ...s,
      decisions: s.decisions + 1,
      nearOptimal: s.nearOptimal + (nearOpt ? 1 : 0),
    }))

    if (!showEV) {
      // Show review first; bots animate after user clicks Continue
      setReview({ chosenCode: code, actions: [...actions] })
      setPhase('reviewing')
      setTimeout(() => {
        try { g.checkpoint() } catch (e) { console.warn('checkpoint failed:', e) }
        g.applyUserAction(code)
        setState(g.state())
        setCanUndo(g.canUndo)
      }, 0)
    } else {
      // EV visible — go straight to bot animation
      setPhase('bot_acting')
      setTimeout(() => {
        try { g.checkpoint() } catch (e) { console.warn('checkpoint failed:', e) }
        g.applyUserAction(code)
        setState(g.state())
        setCanUndo(g.canUndo)
        startBotAnimation(g)
      }, 0)
    }
  }, [phase, actions, showEV, startBotAnimation])

  const handleUndo = useCallback(() => {
    const g = gameRef.current
    if (!g) return
    if (animLoopRef.current) { clearTimeout(animLoopRef.current); animLoopRef.current = null }
    if (!g.undo()) return
    setHandDecisions(prev => {
      const last = prev[prev.length - 1]
      if (last) {
        setSession(s => ({
          ...s,
          decisions: s.decisions - 1,
          nearOptimal: s.nearOptimal - (last.nearOptimal ? 1 : 0),
        }))
      }
      return prev.slice(0, -1)
    })
    setReview(null)
    setUserFolded(false)
    setCanUndo(false)
    setPhase('loading')
    setTimeout(() => { refresh(g) }, 0)
  }, [refresh])

  const handleContinueReview = useCallback(() => {
    const g = gameRef.current
    if (!g) return
    setReview(null)
    // Now animate the bots that acted after the user's move
    startBotAnimation(g)
  }, [startBotAnimation])

  const handleSkipToResult = useCallback(() => {
    const g = gameRef.current
    if (!g) return
    if (animLoopRef.current) { clearTimeout(animLoopRef.current); animLoopRef.current = null }
    g.stepToHandEnd()
    refresh(g)
  }, [refresh])

  const handleNextHand = useCallback(() => {
    const g = gameRef.current
    if (!g) return
    setSession(s => ({ ...s, handsPlayed: s.handsPlayed + 1 }))
    setHandDecisions([])
    setUserFolded(false)
    setDealKey(k => k + 1)
    setPhase('loading')
    setTimeout(() => {
      g.newHand()
      refresh(g)
    }, 0)
  }, [refresh])

  if (!state) {
    return <div className="loading-screen">Loading engine…</div>
  }

  const { players, dealer_idx, sb_idx, bb_idx, to_act } = state
  const showdownOrOver = state.hand_over || state.street === 'showdown'
  const userPlayer = players.find(p => p.is_user)
  const isBotActing = phase === 'bot_acting'

  return (
    <div className="app">
      <header className="app-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span className="app-title">HoldemPOC</span>
          <button className="rankings-btn" onClick={() => setShowRankings(true)}>Hand Rankings</button>
        </div>
        <div className="app-header-right">
          <span className="app-stack">
            Stack: <strong>${userPlayer?.stack ?? '—'}</strong>
          </span>
          {(userPlayer?.contributed_hand ?? 0) > 0 && (
            <span className="app-pot-contrib">
              In pot: <strong>${userPlayer!.contributed_hand}</strong>
            </span>
          )}
          <span className="app-session">
            Hands: <strong>{session.handsPlayed}</strong>
            {session.decisions > 0 && (
              <> · Optimal: <strong>{Math.round(session.nearOptimal / session.decisions * 100)}%</strong> ({session.decisions})</>
            )}
          </span>
        </div>
      </header>

      <div className="table-container">
        <div className="table-felt">
          {players.map((p, i) => (
            <div
              key={p.name}
              className="seat-wrapper"
              style={{ position: 'absolute', ...SEAT_STYLE[i] }}
            >
              <PlayerSeat
                player={p}
                isDealer={i === dealer_idx}
                isSB={i === sb_idx}
                isBB={i === bb_idx}
                isActing={i === to_act && !state.hand_over}
                isWinner={state.hand_over && state.winner_names.includes(p.name)}
                showCards={p.is_user || showdownOrOver}
                position={i}
                isThinking={phase === 'loading' || actionsLoading}
                isBotActing={isBotActing && i === to_act && !p.is_user}
                dealKey={dealKey}
              />
            </div>
          ))}

          <div className="table-center">
            <Board state={state} />
          </div>
        </div>
      </div>

      <div className="bottom-area">
        {phase === 'hand_over' ? (
          <HandResult state={state} decisions={handDecisions} onNext={handleNextHand} />
        ) : phase === 'reviewing' && review ? (
          <ReviewPanel
            chosenCode={review.chosenCode}
            actions={review.actions}
            onContinue={handleContinueReview}
            onUndo={canUndo ? handleUndo : undefined}
            onSkip={userFolded ? handleSkipToResult : undefined}
          />
        ) : phase === 'bot_acting' ? (
          <div className="thinking">
            <span className="thinking-dots">opponents deciding</span>
            {userFolded && (
              <button className="skip-btn" onClick={handleSkipToResult}>Skip to result</button>
            )}
          </div>
        ) : phase === 'loading' || actionsLoading ? (
          <div className="thinking">
            <span className="thinking-dots">computing EV</span>
          </div>
        ) : (
          <ActionPanel
            actions={actions}
            onAct={handleAct}
            disabled={phase !== 'user_turn'}
            showEV={showEV}
            onToggleEV={() => setShowEV(v => !v)}
            street={state.street}
            userHole={state.user_hole}
          />
        )}

        <LogStrip entries={fullLog} />
      </div>

      {showRankings && <HandRankingsModal onClose={() => setShowRankings(false)} />}
    </div>
  )
}

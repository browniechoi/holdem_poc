import { useEffect, useRef, useState, useCallback } from 'react'
import { Game } from './game'
import type { PublicState, ActionEV } from './types'
import { PlayerSeat } from './components/PlayerSeat'
import { Board } from './components/Board'
import { ActionPanel } from './components/ActionPanel'
import { HandResult } from './components/HandResult'
import './App.css'

// Positions for up to 9 players. Index = seat number (0 = user, always bottom-center).
const SEAT_STYLE: React.CSSProperties[] = [
  { bottom: 0, left: '50%', transform: 'translateX(-50%)' },     // 0 user
  { bottom: '18%', left: '4%' },                                  // 1
  { top: '22%', left: '1%' },                                     // 2
  { top: 0, left: '22%' },                                        // 3
  { top: 0, left: '58%' },                                        // 4
  { top: '22%', right: '1%' },                                    // 5
  { bottom: '18%', right: '4%' },                                 // 6
  { bottom: '18%', left: '30%' },                                 // 7
  { bottom: '18%', right: '30%' },                                // 8
]

type Phase = 'loading' | 'user_turn' | 'hand_over'

export default function App() {
  const gameRef = useRef<Game | null>(null)
  const [phase, setPhase] = useState<Phase>('loading')
  const [state, setState] = useState<PublicState | null>(null)
  const [actions, setActions] = useState<ActionEV[]>([])
  const [actionsLoading, setActionsLoading] = useState(false)

  // Snapshot game state and compute EV actions (synchronous but potentially slow ~50-150ms)
  const refresh = useCallback((g: Game) => {
    const s = g.state()
    setState(s)
    if (s.hand_over) {
      setPhase('hand_over')
      setActions([])
    } else {
      setActionsLoading(true)
      // Defer EV computation one tick so the UI can render first
      setTimeout(() => {
        setActions(g.actions())
        setActionsLoading(false)
        setPhase('user_turn')
      }, 0)
    }
  }, [])

  useEffect(() => {
    const g = new Game()
    gameRef.current = g
    refresh(g)
    return () => g.free()
  }, [refresh])

  const handleAct = useCallback((code: number) => {
    const g = gameRef.current
    if (!g || phase !== 'user_turn') return
    setPhase('loading')
    setActions([])
    // Defer so loading state renders before the synchronous WASM call
    setTimeout(() => {
      g.act(code)
      refresh(g)
    }, 0)
  }, [phase, refresh])

  const handleNextHand = useCallback(() => {
    const g = gameRef.current
    if (!g) return
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

  return (
    <div className="app">
      <header className="app-header">
        <span className="app-title">HoldemPOC</span>
        <span className="app-stack">
          Stack: <strong>${players.find(p => p.is_user)?.stack ?? '—'}</strong>
        </span>
      </header>

      <div className="table-container">
        <div className="table-felt">
          {/* Player seats */}
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
                showCards={p.is_user || showdownOrOver}
                position={i}
              />
            </div>
          ))}

          {/* Center board */}
          <div className="table-center">
            <Board state={state} />
          </div>
        </div>
      </div>

      {/* Action area */}
      <div className="bottom-area">
        {phase === 'hand_over' ? (
          <HandResult state={state} onNext={handleNextHand} />
        ) : phase === 'loading' || actionsLoading ? (
          <div className="thinking">computing EV…</div>
        ) : (
          <ActionPanel
            actions={actions}
            onAct={handleAct}
            disabled={phase !== 'user_turn'}
          />
        )}
      </div>
    </div>
  )
}

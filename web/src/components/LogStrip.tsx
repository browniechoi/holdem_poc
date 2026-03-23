import { useEffect, useRef } from 'react'

interface Props {
  entries: string[]
}

type EntryKind = 'header' | 'street' | 'user' | 'action' | 'info' | 'skip'

function classifyEntry(line: string): EntryKind {
  if (line.startsWith('-----')) return 'header'
  if (line.startsWith('──')) return 'street'
  if (line.startsWith('Your decision:')) return 'skip'
  if (line.startsWith('Your hole') || line.startsWith('Dealer:')) return 'info'
  if (line.startsWith('You ')) return 'user'
  return 'action'
}

export function LogStrip({ entries }: Props) {
  const endRef = useRef<HTMLDivElement>(null)
  const visible = entries.filter(l => classifyEntry(l) !== 'skip')

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [entries.length])

  if (!visible.length) return null

  // Number only action/user entries (fold, call, raise, bet, check, posts)
  let actionIdx = 0

  return (
    <div className="log-strip">
      <div className="log-strip-title">Action log</div>
      <div className="log-entries">
        {visible.map((line, i) => {
          const kind = classifyEntry(line)
          const isCountable = kind === 'action' || kind === 'user'
          if (isCountable) actionIdx++
          const num = isCountable ? actionIdx : null

          return (
            <div key={i} className={`log-entry log-entry--${kind}`}>
              {num !== null && <span className="log-num">{num}.</span>}
              {line}
            </div>
          )
        })}
        <div ref={endRef} />
      </div>
    </div>
  )
}

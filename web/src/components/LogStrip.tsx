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
  const scrollerRef = useRef<HTMLDivElement>(null)
  const visible = entries.filter(line => classifyEntry(line) !== 'skip')

  useEffect(() => {
    const node = scrollerRef.current
    if (!node) return
    node.scrollLeft = node.scrollWidth
  }, [visible.length])

  if (!visible.length) return null

  let actionIdx = 0

  return (
    <div className="log-strip">
      <div className="log-strip-title">Hand History</div>
      <div className="log-entries log-entries--ticker" ref={scrollerRef}>
        {visible.map((line, i) => {
          const kind = classifyEntry(line)
          const isCountable = kind === 'action' || kind === 'user'
          if (isCountable) actionIdx += 1
          return (
            <div key={`${i}-${line}`} className={`log-entry log-entry--${kind}`}>
              {isCountable && <span className="log-num">{actionIdx}.</span>}
              <span className="log-text">{line}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

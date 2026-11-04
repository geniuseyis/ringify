import { useRef, type KeyboardEvent, type PointerEvent } from 'react'
import { formatTime } from '../lib/format'
import { timeAtPosition, trimBoundary } from '../lib/waveformCoordinates'

interface WaveformProps {
  peaks: number[]
  duration: number
  start: number
  end: number
  playhead?: number
  editable?: boolean
  onChange?: (start: number, end: number) => void
  zoom?: number
  compact?: boolean
  timeFormatter?: (time: number) => string
}

export function Waveform({ peaks, duration, start, end, playhead = start, editable = false,
  onChange, zoom = 1, compact = false, timeFormatter = formatTime }: WaveformProps) {
  const track = useRef<HTMLDivElement>(null)
  const safeDuration = Math.max(0.1, duration)
  const change = (kind: 'start' | 'end', time: number) => onChange?.(...trimBoundary(kind, time, start, end, safeDuration))
  const pointer = (kind: 'start' | 'end', event: PointerEvent<HTMLButtonElement>) => {
    const rect = track.current?.getBoundingClientRect()
    if (rect) change(kind, timeAtPosition(event.clientX, rect.left, rect.width, safeDuration))
  }
  const keyboard = (kind: 'start' | 'end', event: KeyboardEvent<HTMLButtonElement>) => {
    const current = kind === 'start' ? start : end
    const step = event.shiftKey ? 1 : 0.1
    if (['ArrowLeft', 'ArrowDown', 'ArrowRight', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
      event.preventDefault()
      const next = event.key === 'Home' ? 0 : event.key === 'End' ? safeDuration
        : current + (['ArrowLeft', 'ArrowDown'].includes(event.key) ? -step : step)
      change(kind, next)
    }
  }
  return (
    <div className="waveform-viewport">
      <div className="waveform-track" style={{ width: `${Math.max(1, zoom) * 100}%` }}>
        <div ref={track} data-testid="waveform-track" className={`waveform ${compact ? 'waveform-compact' : ''}`}>
          <div className="waveform-grid" aria-hidden="true">
            {[0, 25, 50, 75, 100].map((position) => <span key={position} style={{ left: `${position}%` }} />)}
          </div>
          <div className="waveform-bars" aria-hidden="true">
            {peaks.map((peak, index) => {
              const time = index / Math.max(1, peaks.length - 1) * safeDuration
              return <i key={index} className={time >= start && time <= end ? 'is-selected' : ''}
                style={{ height: `${Math.max(2, peak * 100)}%` }} />
            })}
          </div>
          <div className="waveform-selection" style={{ left: `${start / safeDuration * 100}%`,
            width: `${(end - start) / safeDuration * 100}%` }} aria-hidden="true" />
          <span className="playhead" style={{ left: `${playhead / safeDuration * 100}%` }} aria-hidden="true" />
          {editable ? (['start', 'end'] as const).map((kind) => (
            <button key={kind} type="button" role="slider" className="trim-control"
              style={{ left: `${(kind === 'start' ? start : end) / safeDuration * 100}%` }}
              aria-label={kind === 'start' ? 'Kesim başlangıcı' : 'Kesim bitişi'}
              aria-valuemin={kind === 'start' ? Math.max(0, end - 29) : start + 1}
              aria-valuemax={kind === 'start' ? end - 1 : Math.min(safeDuration, start + 29)}
              aria-valuenow={kind === 'start' ? start : end}
              aria-valuetext={timeFormatter(kind === 'start' ? start : end)}
              onPointerDown={(event) => { event.currentTarget.setPointerCapture(event.pointerId); pointer(kind, event) }}
              onPointerMove={(event) => { if (event.currentTarget.hasPointerCapture(event.pointerId)) pointer(kind, event) }}
              onKeyDown={(event) => keyboard(kind, event)}><span aria-hidden="true" /></button>
          )) : null}
        </div>
        {!compact ? <div className="timeline-labels" aria-hidden="true">
          {[0, 0.25, 0.5, 0.75, 1].map((fraction) => <span key={fraction}>{timeFormatter(fraction * safeDuration)}</span>)}
        </div> : null}
      </div>
    </div>
  )
}

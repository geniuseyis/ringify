import type { CSSProperties, ReactNode } from 'react'
import { Pause, Play, SkipBack } from 'lucide-react'
import type { EditorState, Language } from '../types'
import { Waveform } from '../components/Waveform'
import { formatStudioTime } from './tokens'

export function EffectSlider({ id, label, icon, value, max, step, display, onChange }: {
  id: string; label: string; icon: ReactNode; value: number; max: number; step: number
  display: string; onChange: (value: number) => void
}) {
  const progress = max > 0 ? Math.max(0, Math.min(100, value / max * 100)) : 0
  return <div className="f-effect-slider">
    <div className="f-effect-label"><label htmlFor={id}><span aria-hidden="true">{icon}</span>{label}</label><output htmlFor={id} aria-live="off">{display}</output></div>
    <input id={id} type="range" min="0" max={max} step={step} value={value} aria-valuetext={display} onChange={event => onChange(Number(event.target.value))} style={{'--f-progress':`${progress}%`} as CSSProperties} />
  </div>
}

export function SelectionWaveform({ editor, playhead }: { editor: EditorState; playhead: number }) {
  return <div className="f-waveform">
    <Waveform peaks={editor.asset.peaks} duration={editor.asset.duration} start={editor.trimStart} end={editor.trimEnd} playhead={playhead} compact />
    <div className="f-wave-times" aria-hidden="true"><span>{formatStudioTime(editor.trimStart)}</span><span>{formatStudioTime(editor.trimEnd)}</span></div>
  </div>
}

export function FinishingTransport({ language, isPlaying, elapsed, duration, onPlay, onStop, disabled = false }: {
  language: Language; isPlaying: boolean; elapsed: number; duration: number
  onPlay: () => void; onStop: () => void; disabled?: boolean
}) {
  const isTr = language === 'tr'
  return <div className="f-transport" role="group" aria-label={isTr ? 'Oynatma kontrolleri' : 'Playback controls'}>
    <span className="f-elapsed">{formatStudioTime(elapsed)}</span>
    <div className="f-transport-buttons"><button type="button" onClick={onStop} disabled={disabled} className="f-transport-reset" aria-label={isTr ? 'Başa dön' : 'Return to start'}><SkipBack size={21} aria-hidden="true" /></button><button type="button" onClick={onPlay} disabled={disabled} className="f-transport-play" aria-label={isPlaying ? (isTr ? 'Duraklat' : 'Pause') : (isTr ? 'Oynat' : 'Play')}>{isPlaying ? <Pause size={24} fill="currentColor" aria-hidden="true" /> : <Play size={24} fill="currentColor" aria-hidden="true" />}</button></div>
    <span>{formatStudioTime(duration)}</span>
  </div>
}

import type { ButtonHTMLAttributes, ComponentProps, ReactNode } from 'react'
import { ArrowRight, AudioLines, Check, ChevronRight, Clock3, FileAudio, LoaderCircle, Pause, Play, Repeat2, Scissors, ShieldCheck, SkipBack, Square } from 'lucide-react'
import type { Language, ProjectSummary } from '../types'
import { formatDate } from '../lib/format'
import { Waveform } from '../components/Waveform'
import { formatStudioTime } from './tokens'

type ActionProps = ButtonHTMLAttributes<HTMLButtonElement> & { children: ReactNode; icon?: ReactNode }

export function PrimaryActionButton({ children, icon, className = '', ...props }: ActionProps) {
  return <button type="button" className={`r-action r-primary ${className}`} {...props}>{icon}<span>{children}</span><ArrowRight size={19} aria-hidden="true" /></button>
}

export function SecondaryActionButton({ children, icon, className = '', ...props }: ActionProps) {
  return <button type="button" className={`r-action r-secondary ${className}`} {...props}>{icon}<span>{children}</span></button>
}

export function ProjectCard({ project, language, onOpen }: { project: ProjectSummary; language: Language; onOpen: () => void }) {
  const isTr = language === 'tr'
  return <button type="button" className="r-project" onClick={onOpen}>
    <span className="r-project-heading"><span className="r-project-art" aria-hidden="true"><FileAudio size={26} /><AudioLines size={13} /></span><span className="r-project-copy"><strong>{project.name}</strong><small>{project.sourceName}</small></span><ChevronRight size={18} aria-hidden="true" /></span>
    <span className="r-project-details"><span><Clock3 size={12} aria-hidden="true" />{formatDate(project.updatedAt, isTr ? 'tr-TR' : 'en-US')}</span><span><Scissors size={12} aria-hidden="true" />{formatStudioTime(project.duration)}</span><span className="r-project-status">{project.status === 'exported' ? <Check size={12} aria-hidden="true" /> : <FileAudio size={12} aria-hidden="true" />}{project.status === 'exported' ? (isTr ? 'Hazır' : 'Ready') : (isTr ? 'Taslak' : 'Draft')}</span></span>
  </button>
}

// Brand illustration only: never presented as a measured waveform of a saved project.
export function SignatureArtwork() {
  return <div className="r-signature-art" aria-hidden="true"><svg viewBox="0 0 260 200" fill="none"><ellipse cx="157" cy="95" rx="85" ry="84" /><ellipse cx="157" cy="95" rx="65" ry="64" /><ellipse cx="157" cy="95" rx="43" ry="42" /><path d="M58 96h30l5-10 7 20 7-37 8 54 8-70 8 82 8-64 8 43 8-25 8 14h35l7-9 7 16 7-13h40" /><path className="r-signature-orbit" d="M24 133c48-57 122-74 225-41M65 178c24-75 76-123 155-145" /></svg><span className="r-signature-mark"><Scissors size={20} strokeWidth={1.5} /></span></div>
}

export function EmptyStateView({ title, description }: { title: string; description: string }) {
  return <div className="r-empty"><span className="r-empty-icon" aria-hidden="true"><FileAudio size={24} /></span><div><h3>{title}</h3><p>{description}</p></div></div>
}

export function LoadingStateView({ label }: { label: string }) {
  return <div className="r-loading" role="status"><LoaderCircle size={22} className="spin" aria-hidden="true" /><span>{label}</span></div>
}

export function ErrorStateView({ message }: { message: string }) {
  return <p className="r-error" role="alert">{message}</p>
}

export function LocalProcessingNote({ language }: { language: Language }) {
  return <aside className="r-local-note"><ShieldCheck size={15} aria-hidden="true" /><span>{language === 'tr' ? 'Sesin cihazında. Kontrol sende.' : 'Your audio stays local. You stay in control.'}</span></aside>
}

type WaveformProps = ComponentProps<typeof Waveform>
export function AudioWaveform(props: WaveformProps) {
  return <Waveform {...props} timeFormatter={formatStudioTime} />
}

export function AudioToolPanel({ children, label }: { children: ReactNode; label: string }) {
  return <div className="r-tool-panel editor-toolbar" role="group" aria-label={label}>{children}</div>
}

export function PlaybackControls({ language, isPlaying, loop, elapsed, duration, onPlay, onStop, onToggleLoop }: {
  language: Language; isPlaying: boolean; loop: boolean; elapsed: number; duration: number
  onPlay: () => void; onStop: () => void; onToggleLoop: () => void
}) {
  const isTr = language === 'tr'
  return <div className="r-playback" role="group" aria-label={isTr ? 'Oynatma kontrolleri' : 'Playback controls'}>
    <div className="r-transport-heading"><span>{isTr ? 'ÖN DİNLEME' : 'PREVIEW'}</span><div className="r-playback-clock"><strong>{formatStudioTime(elapsed)}</strong><span> / {formatStudioTime(duration)}</span></div><span className={loop ? 'r-loop-on' : ''}>{loop ? (isTr ? 'DÖNGÜ AÇIK' : 'LOOP ON') : (isTr ? 'SEÇİLİ BÖLÜM' : 'SELECTION')}</span></div>
    <div className="r-transport-buttons"><button type="button" className="r-icon" onClick={onToggleLoop} aria-label={isTr ? 'Seçimi döngüyle oynat' : 'Loop selection'} aria-pressed={loop}><Repeat2 size={21} aria-hidden="true" /></button><div className="r-main-transport"><button type="button" className="r-icon" onClick={onStop} aria-label={isTr ? 'Başa dön' : 'Return to start'}><SkipBack size={21} aria-hidden="true" /></button><button type="button" className="r-play" onClick={onPlay} aria-label={isPlaying ? (isTr ? 'Duraklat' : 'Pause') : (isTr ? 'Oynat' : 'Play')}>{isPlaying ? <Pause size={25} fill="currentColor" aria-hidden="true" /> : <Play size={25} fill="currentColor" aria-hidden="true" />}</button><button type="button" className="r-icon" onClick={onStop} aria-label={isTr ? 'Durdur' : 'Stop'}><Square size={18} fill="currentColor" aria-hidden="true" /></button></div><span className="r-transport-duration" aria-hidden="true">{formatStudioTime(duration)}</span></div>
  </div>
}

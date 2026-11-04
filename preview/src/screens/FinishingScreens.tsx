import { ArrowDownRight, ArrowUpRight, AudioLines, BellRing, Check, FileAudio, PencilLine, RotateCcw, Share2, SlidersHorizontal, Volume2 } from 'lucide-react'
import type { EditorState, Language } from '../types'
import { ScreenShell } from '../components/ScreenShell'
import { useSegmentPlayer } from '../hooks/useSegmentPlayer'
import { PrimaryActionButton } from '../designSystem/StudioComponents'
import { EffectSlider, FinishingTransport, SelectionWaveform } from '../designSystem/FinishingComponents'
import { designVariables, formatStudioTime } from '../designSystem/tokens'
import '../designSystem/finishing.css'

interface EffectsScreenProps {
  language: Language; editor: EditorState; onChange: (next: EditorState) => void
  onBack: () => void; onContinue: () => void
}

export function EffectsScreen({ language, editor, onChange, onBack, onContinue }: EffectsScreenProps) {
  const isTr = language === 'tr'
  const player = useSegmentPlayer(editor)
  const duration = editor.trimEnd - editor.trimStart
  const fadeLimit = Math.min(5, Math.max(0, duration / 2))
  const effects = editor.effects
  const update = (partial: Partial<typeof effects>) => onChange({ ...editor, effects: { ...effects, ...partial } })
  const reset = () => update({ volume:1, fadeIn:0, fadeOut:0, normalize:false })
  const seconds = (value: number) => `${value.toFixed(1).replace('.', isTr ? ',' : '.')} ${isTr ? 'sn' : 's'}`
  return <ScreenShell title={isTr ? 'Sesi iyileştir' : 'Enhance Audio'} onBack={onBack} className="effects-screen v2-screen v3-finish v3-effects" style={designVariables} scroll={false}
    trailing={<button type="button" className="f-reset" onClick={reset} aria-label={isTr ? 'Sıfırla' : 'Reset'} title={isTr ? 'Sıfırla' : 'Reset'}><RotateCcw size={20} aria-hidden="true" /></button>}>
    <div className="f-workspace">
      <div className="f-track"><span className="f-track-icon" aria-hidden="true"><AudioLines size={24} /></span><div><h2>{editor.projectName}</h2><p title={editor.asset.fileName}>{editor.asset.fileName}</p></div><span className="f-duration">{formatStudioTime(duration)}</span></div>
      <div className="f-listening"><SelectionWaveform editor={editor} playhead={player.playhead} /><FinishingTransport language={language} isPlaying={player.isPlaying} elapsed={player.playhead-editor.trimStart} duration={duration} onPlay={player.play} onStop={player.stop} disabled={!editor.asset.buffer} /></div>
      {player.error ? <p className="f-error" role="alert">{player.error}</p> : null}
      <div className="f-section-label">{isTr ? 'SES' : 'AUDIO'}</div>
      <div className="f-control-group"><EffectSlider id="volume-control" label={isTr ? 'Ses Seviyesi' : 'Volume'} icon={<Volume2 size={19} />} value={effects.volume} max={1.5} step={0.05} display={`${Math.round(effects.volume*100)}%`} onChange={volume=>update({volume})} /></div>
      <div className="f-section-label">{isTr ? 'GEÇİŞLER' : 'FADES'}</div>
      <div className="f-control-group"><EffectSlider id="fade-in-control" label="Fade-in" icon={<ArrowUpRight size={19} />} value={Math.min(effects.fadeIn,fadeLimit)} max={fadeLimit} step={0.1} display={seconds(Math.min(effects.fadeIn,fadeLimit))} onChange={fadeIn=>update({fadeIn})} /><EffectSlider id="fade-out-control" label="Fade-out" icon={<ArrowDownRight size={19} />} value={Math.min(effects.fadeOut,fadeLimit)} max={fadeLimit} step={0.1} display={seconds(Math.min(effects.fadeOut,fadeLimit))} onChange={fadeOut=>update({fadeOut})} /></div>
      <button type="button" className="f-normalize" role="switch" aria-label={isTr ? 'Ses seviyesini dengele' : 'Normalize volume'} aria-checked={effects.normalize} onClick={()=>update({normalize:!effects.normalize})}><span className="f-normalize-label"><SlidersHorizontal size={20} aria-hidden="true" /><span>{isTr ? 'Ses seviyesini dengele' : 'Normalize volume'}</span></span><span className={`f-switch ${effects.normalize ? 'is-on' : ''}`} aria-hidden="true"><i>{effects.normalize ? <Check size={12} strokeWidth={3} /> : null}</i></span></button>
    </div>
    <footer className="f-footer"><PrimaryActionButton onClick={onContinue}>{isTr ? 'Ön İzle' : 'Preview'}</PrimaryActionButton></footer>
  </ScreenShell>
}

interface RingtonePreviewScreenProps {
  language: Language; editor: EditorState; onChange: (next: EditorState) => void
  onBack: () => void; onExport: () => void
}

export function RingtonePreviewScreen({ language, editor, onChange, onBack, onExport }: RingtonePreviewScreenProps) {
  const isTr = language === 'tr'
  const player = useSegmentPlayer(editor)
  const duration = editor.trimEnd - editor.trimStart
  const buffer = editor.asset.buffer
  const sampleRate = buffer ? new Intl.NumberFormat(isTr ? 'tr-TR' : 'en-US', {maximumFractionDigits:1}).format(buffer.sampleRate/1000) : null
  const effects = editor.effects
  return <ScreenShell title={isTr ? 'Zil sesi ön izlemesi' : 'Ringtone Preview'} onBack={onBack} className="ringtone-preview-screen v2-screen v3-finish v3-preview" style={designVariables} scroll={false}>
    <div className="f-workspace">
      <div className="f-tone-mark" aria-hidden="true"><BellRing size={30} strokeWidth={1.5} /></div>
      <div className="f-name-group"><label htmlFor="ringtone-name">{isTr ? 'Zil sesi adı' : 'Ringtone name'}</label><div className="f-name-field"><input id="ringtone-name" value={editor.projectName} maxLength={64} required aria-invalid={!editor.projectName.trim()} onChange={event=>onChange({...editor,projectName:event.target.value})} /><PencilLine size={18} aria-hidden="true" /></div></div>
      <div className="f-source-caption"><FileAudio size={14} aria-hidden="true" /><span title={editor.asset.fileName}>{editor.asset.fileName}</span>{editor.asset.isDemo ? <span className="f-demo-label">Demo</span> : null}</div>
      <div className="f-listening"><SelectionWaveform editor={editor} playhead={player.playhead} /><FinishingTransport language={language} isPlaying={player.isPlaying} elapsed={player.playhead-editor.trimStart} duration={duration} onPlay={player.play} onStop={player.stop} disabled={!buffer} /></div>
      {player.error || !buffer ? <p className="f-error" role="alert">{player.error || (isTr ? 'Gerçek ses verisi yok. Düzenlemeye dönüp bir ses dosyası seç.' : 'No audio data. Return to editing and choose an audio file.')}</p> : null}
      <dl className="f-details"><div><dt>{isTr ? 'Süre' : 'Duration'}</dt><dd>{formatStudioTime(duration)}</dd></div><div><dt>{isTr ? 'Çıktı' : 'Output'}</dt><dd>{buffer ? `WAV · ${sampleRate} kHz · ${buffer.numberOfChannels===1?'Mono':'Stereo'}` : '—'}</dd></div><div><dt>{isTr ? 'Efektler' : 'Effects'}</dt><dd>{Math.round(effects.volume*100)}%{(effects.fadeIn>0||effects.fadeOut>0) ? ' · Fade' : ''}{effects.normalize ? ' · Normalize' : ''}</dd></div></dl>
    </div>
    <footer className="f-footer"><PrimaryActionButton icon={<Share2 size={20} aria-hidden="true" />} onClick={onExport} disabled={!editor.projectName.trim()||!buffer}>{isTr ? 'Dışa Aktar' : 'Export'}</PrimaryActionButton><button type="button" className="f-edit-again" onClick={onBack}>{isTr ? 'Yeniden Düzenle' : 'Edit Again'}</button></footer>
  </ScreenShell>
}

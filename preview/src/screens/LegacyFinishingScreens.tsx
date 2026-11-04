// Active, restored presentation selected by the user. Audio/data behavior stays shared.
import { FileAudio, Pause, Play, RotateCcw, Share2 } from 'lucide-react'
import type { EditorState, Language } from '../types'
import { formatTime } from '../lib/format'
import { useSegmentPlayer } from '../hooks/useSegmentPlayer'
import { Button } from '../components/Button'
import { ScreenShell } from '../components/ScreenShell'
import { Waveform } from '../components/Waveform'
import {designVariables} from '../designSystem/tokens'
import {useEffect,useState} from 'react'
import {AdvancedAudioPanel} from './AdvancedAudioPanel'
import {PersonalPresetsPanel} from './PersonalPresetsPanel'
import '../designSystem/loopCrossfade.css'

export function EffectsScreen({language,editor,onChange,onBack,onContinue,canNormalize=true,canAdvancedEffects=false,onRequirePro}: {
  language:Language;editor:EditorState;onChange:(next:EditorState)=>void;onBack:()=>void;onContinue:()=>void;canNormalize?:boolean;canAdvancedEffects?:boolean;onRequirePro?:()=>void
}) {
  const [before,setBefore]=useState(false)
  useEffect(()=>setBefore(false),[editor.projectID,editor.asset.buffer])
  const isTr=language==='tr',player=useSegmentPlayer(before?{...editor,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}:editor),duration=editor.trimEnd-editor.trimStart,effects=editor.effects
  const update=(partial:Partial<typeof effects>)=>onChange({...editor,effects:{...effects,...partial}})
  return <ScreenShell title={isTr?'Sesi iyileştir':'Enhance Audio'} onBack={onBack} backLabel={isTr?'Geri':'Back'} className="effects-screen v2-screen v3-screen v3-flow v3-effects av-screen av-finish av-effects" style={designVariables}>
    <div className="effects-preview-card"><Waveform peaks={editor.asset.peaks} duration={editor.asset.duration} start={editor.trimStart} end={editor.trimEnd} playhead={player.playhead} compact /><button type="button" className="play-button small" onClick={player.play} aria-label={player.isPlaying?(isTr?'Duraklat':'Pause'):(isTr?'Oynat':'Play')}>{player.isPlaying?<Pause size={20} fill="currentColor" />:<Play size={20} fill="currentColor" />}</button><span>{formatTime(duration)}</span></div>
    {player.error?<p className="inline-error" role="alert">{player.error}</p>:null}
    <div className="n4-effect-settings">
    <div className="control-card"><label htmlFor="volume-control"><span><strong>{isTr?'Ses Seviyesi':'Volume'}</strong><small>{Math.round(effects.volume*100)}%</small></span></label><input id="volume-control" aria-label={isTr?'Ses Seviyesi':'Volume'} type="range" min="0" max="1.5" step="0.05" value={effects.volume} onChange={event=>update({volume:Number(event.target.value)})} /></div>
    <div className="control-card"><label htmlFor="fade-in-control"><span><strong>Fade-in</strong><small>{effects.fadeIn.toFixed(1)} {isTr?'sn':'s'}</small></span></label><input id="fade-in-control" aria-label="Fade-in" type="range" min="0" max={Math.min(5,duration/2)} step="0.1" value={effects.fadeIn} onChange={event=>update({fadeIn:Number(event.target.value)})} /></div>
    <div className="control-card"><label htmlFor="fade-out-control"><span><strong>Fade-out</strong><small>{effects.fadeOut.toFixed(1)} {isTr?'sn':'s'}</small></span></label><input id="fade-out-control" aria-label="Fade-out" type="range" min="0" max={Math.min(5,duration/2)} step="0.1" value={effects.fadeOut} onChange={event=>update({fadeOut:Number(event.target.value)})} /></div>
    </div>
    <button type="button" className="toggle-card" role={canNormalize||effects.normalize?'switch':undefined} aria-label={`${isTr?'Ses seviyesini dengele':'Normalize volume'}${!canNormalize&&!effects.normalize?' — Ringify Pro':''}`} aria-checked={canNormalize||effects.normalize?effects.normalize:undefined} onClick={()=>{if(!canNormalize&&!effects.normalize){onRequirePro?.();return}update({normalize:!effects.normalize})}}><span><strong>{isTr?'Ses seviyesini dengele':'Normalize volume'}{!canNormalize?<em className="plan-pro">Pro</em>:null}</strong><small>{isTr?'Tepe seviyesini güvenli biçimde yükseltir':'Raises peak level safely'}</small></span><i className={effects.normalize?'is-on':''}><b /></i></button>
    <Button variant="ghost" fullWidth aria-pressed={before} onClick={()=>setBefore(value=>!value)}>{before?(isTr?'Orijinal dinleniyor':'Listening to original'):(isTr?'Öncesi / sonrası dinle':'Compare original / processed')}</Button>
    <AdvancedAudioPanel editor={editor} language={language} enabled={canAdvancedEffects} onChange={onChange} onRequirePro={onRequirePro}/>
    <div className="n4-effect-settings loop-crossfade-control">
      <button type="button" className="toggle-card" role="switch" aria-label={isTr?'Pürüzsüz loop':'Smooth loop'} aria-checked={(effects.loopCrossfade??0)>0}
        onClick={()=>update({loopCrossfade:(effects.loopCrossfade??0)>0?0:.03})}>
        <span><strong>{isTr?'Pürüzsüz loop':'Smooth loop'}</strong><small>{Math.round((effects.loopCrossfade??0)*1000)} ms</small></span>
        <i className={(effects.loopCrossfade??0)>0?'is-on':''}><b/></i>
      </button>
      {(effects.loopCrossfade??0)>0?<div className="control-card"><label><span><strong>{isTr?'Uç geçişi':'Edge overlap'}</strong><small>{Math.round((effects.loopCrossfade??0)*1000)} ms</small></span><input type="range" min="0.005" max="0.25" step="0.005" value={effects.loopCrossfade}
        aria-label={isTr?'Döngü uç geçişi':'Loop edge overlap'} aria-valuetext={`${Math.round((effects.loopCrossfade??0)*1000)} ms`}
        onChange={event=>update({loopCrossfade:Number(event.target.value)})}/></label></div>:null}
    </div>
    <PersonalPresetsPanel editor={editor} language={language} onChange={onChange} canNormalize={canNormalize} canAdvancedEffects={canAdvancedEffects} onRequirePro={onRequirePro}/>
    <div className="split-actions"><Button variant="ghost" onClick={()=>onChange({...editor,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}})} icon={<RotateCcw size={18} />}>{isTr?'Sıfırla':'Reset'}</Button><Button onClick={onContinue}>{isTr?'Ön İzle':'Preview'}</Button></div>
  </ScreenShell>
}

export function RingtonePreviewScreen({language,editor,onChange,onBack,onEdit,onExport}: {
  language:Language;editor:EditorState;onChange:(next:EditorState)=>void;onBack:()=>void;onEdit?:()=>void;onExport:()=>void
}) {
  const isTr=language==='tr',player=useSegmentPlayer(editor)
  return <ScreenShell title={isTr?'Zil sesi ön izlemesi':'Ringtone Preview'} onBack={onBack} backLabel={isTr?'Geri':'Back'} className="ringtone-preview-screen v2-screen v3-screen v3-flow v3-preview av-screen av-finish av-preview" style={designVariables}>
    {player.error||!editor.asset.buffer?<p className="inline-error" role="alert">{player.error||(isTr?'Gerçek ses verisi yok. Düzenlemeye dönüp bir ses dosyası seç.':'No audio data. Return to editing and choose an audio file.')}</p>:null}
    <div className="n4-preview-identity"><span className="n4-preview-symbol" aria-hidden="true"><FileAudio size={36}/></span><button type="button" className="play-button large" onClick={player.play} disabled={!editor.asset.buffer} aria-label={player.isPlaying?(isTr?'Duraklat':'Pause'):(isTr?'Oynat':'Play')}>{player.isPlaying?<Pause size={29} fill="currentColor" aria-hidden="true"/>:<Play size={29} fill="currentColor" aria-hidden="true"/>}</button></div>
    <label className="field-label" htmlFor="ringtone-name">{isTr?'Zil sesi adı':'Ringtone name'}</label><input id="ringtone-name" className="text-field centered-field" value={editor.projectName} maxLength={64} onChange={event=>onChange({...editor,projectName:event.target.value})} />
    <Waveform peaks={editor.asset.peaks} duration={editor.asset.duration} start={editor.trimStart} end={editor.trimEnd} playhead={player.playhead} compact />
    <div className="preview-metadata"><span><small>{isTr?'SÜRE':'DURATION'}</small><strong>{formatTime(editor.trimEnd-editor.trimStart)}</strong></span><span><small>{isTr?'HEDEF BİÇİM':'OUTPUT FORMAT'}</small><strong>{editor.asset.buffer?'WAV':'—'}</strong></span><span><small>{isTr?'KAYNAK':'SOURCE'}</small><strong>{editor.asset.isDemo?'Demo':(isTr?'Yerel':'Local')}</strong></span></div>
    <div className="stack-actions"><Button fullWidth icon={<Share2 size={19} />} onClick={onExport} disabled={!editor.projectName.trim()||!editor.asset.buffer}>{isTr?'Dışa Aktar':'Export'}</Button><Button fullWidth variant="ghost" icon={<RotateCcw size={18} />} onClick={onEdit??onBack}>{isTr?'Yeniden Düzenle':'Edit Again'}</Button></div>
  </ScreenShell>
}


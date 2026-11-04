import {useState} from 'react'
import {AudioLines,FolderOpen,Minus,Plus,Redo2,RotateCcw,Scissors,Undo2} from 'lucide-react'
import type {EditorState,Language,ScreenId} from '../types'
import {ScreenShell} from '../components/ScreenShell'
import {useSegmentPlayer} from '../hooks/useSegmentPlayer'
import {AudioToolPanel,AudioWaveform,ErrorStateView,PlaybackControls,PrimaryActionButton,SecondaryActionButton} from '../designSystem/StudioComponents'
import {designVariables,formatStudioTime} from '../designSystem/tokens'
import {AudioMarkersPanel} from './AudioMarkersPanel'

interface EditorScreenProps {
  language:Language
  editor:EditorState
  onChange:(next:EditorState)=>void
  onBack:()=>void
  onContinue:()=>void
}

export function StudioEmptyScreen({language,onNavigate}:{language:Language;onNavigate:(screen:ScreenId)=>void}){
  const isTr=language==='tr'
  return <ScreenShell className="v2-screen v3-screen v3-studio-empty av-screen av-studio-empty" style={designVariables}>
    <div className="n3-studio-empty-icon" aria-hidden="true"><AudioLines size={32}/></div>
    <div className="n3-studio-empty-copy"><h1 className="sr-only">{isTr?'Ses Stüdyosu':'Audio Studio'}</h1><h2>{isTr?'Stüdyon hazır':'Your studio is ready'}</h2><p>{isTr?'Düzenlemek için bir ses ekle veya kayıtlı projeni aç.':'Add audio to edit, or open one of your saved projects.'}</p></div>
    <div className="n3-studio-empty-actions"><PrimaryActionButton icon={<Plus size={20} aria-hidden="true"/>} onClick={()=>onNavigate('import')}>{isTr?'Ses ekle':'Add audio'}</PrimaryActionButton><SecondaryActionButton icon={<FolderOpen size={20} aria-hidden="true"/>} onClick={()=>onNavigate('library')}>{isTr?'Kütüphaneyi aç':'Open library'}</SecondaryActionButton></div>
  </ScreenShell>
}

export function EditorScreen({language,editor,onChange,onBack,onContinue}:EditorScreenProps){
  const isTr=language==='tr'
  const [zoom,setZoom]=useState(1)
  const [history,setHistory]=useState<Array<[number,number]>>([])
  const [future,setFuture]=useState<Array<[number,number]>>([])
  const [loop,setLoop]=useState(false)
  const {isPlaying,playhead,play,stop,error}=useSegmentPlayer(editor,loop)
  const duration=editor.trimEnd-editor.trimStart
  const validation=!Number.isFinite(duration)||duration<1
    ?(isTr?'En az 1 saniye seç.':'Select at least 1 second.')
    :duration>29?(isTr?'Zil sesi en fazla 29 saniye olabilir.':'A ringtone can be up to 29 seconds.'):null

  // Preserve the existing trim history and audio processing contract.
  const commitTrim=(start:number,end:number)=>{
    stop()
    setHistory(items=>[...items.slice(-19),[editor.trimStart,editor.trimEnd]])
    setFuture([])
    onChange({...editor,trimStart:start,trimEnd:end})
  }
  const undo=()=>{
    const previous=history.at(-1)
    if(!previous)return
    setHistory(items=>items.slice(0,-1))
    setFuture(items=>[[editor.trimStart,editor.trimEnd],...items])
    onChange({...editor,trimStart:previous[0],trimEnd:previous[1]})
  }
  const redo=()=>{
    const next=future[0]
    if(!next)return
    setFuture(items=>items.slice(1))
    setHistory(items=>[...items,[editor.trimStart,editor.trimEnd]])
    onChange({...editor,trimStart:next[0],trimEnd:next[1]})
  }
  const channels=editor.asset.buffer?.numberOfChannels
  const sampleRate=editor.asset.buffer?.sampleRate
  return <ScreenShell title={isTr?'Ses Stüdyosu':'Audio Studio'} onBack={onBack} backLabel={isTr?'Geri':'Back'} scroll={false} className="editor-screen v2-screen v2-studio v3-screen v3-studio av-screen av-studio" style={designVariables}
    trailing={<div className="n3-history" role="group" aria-label={isTr?'Düzenleme geçmişi':'Edit history'}><button type="button" aria-label={isTr?'Geri Al':'Undo'} onClick={undo} disabled={!history.length}><Undo2 size={20} aria-hidden="true"/></button><button type="button" aria-label={isTr?'Yinele':'Redo'} onClick={redo} disabled={!future.length}><Redo2 size={20} aria-hidden="true"/></button></div>}>
    <div className="r-studio-workspace">
      <div className="r-asset editor-file-info"><span className="n3-file-art" aria-hidden="true"><AudioLines size={24}/></span><div><h2>{editor.projectName}</h2><p>{formatStudioTime(editor.asset.duration)}{channels?` · ${channels===1?'Mono':`${channels} ${isTr?'kanal':'channels'}`} · ${((sampleRate??0)/1000).toLocaleString(isTr?'tr-TR':'en-US',{maximumFractionDigits:1})} kHz`:''}</p><span className="sr-only">{editor.asset.fileName}</span></div><span className="r-source-badge">{editor.asset.isDemo?(isTr?'ÖRNEK':'SAMPLE'):(isTr?'YEREL':'LOCAL')}</span></div>
      <section className="r-wave-panel" aria-label={isTr?'Ses dalgası düzenleme alanı':'Waveform editing area'}><div className="r-wave-deck"><AudioWaveform peaks={editor.asset.peaks} duration={editor.asset.duration} start={editor.trimStart} end={editor.trimEnd} playhead={playhead} editable zoom={zoom} onChange={commitTrim}/></div></section>
      <div className="r-selection selection-stats"><div><span>{isTr?'Başlangıç':'Start'}</span><strong>{formatStudioTime(editor.trimStart)}</strong></div><div className={`r-selected-duration ${validation?'is-invalid':''}`}><span>{isTr?'Seçili bölüm':'Selection'}</span><strong>{formatStudioTime(duration)}</strong></div><div><span>{isTr?'Bitiş':'End'}</span><strong>{formatStudioTime(editor.trimEnd)}</strong></div></div>
      <AudioToolPanel label={isTr?'Düzenleme araçları':'Editing tools'}><span className="n3-current-tool"><Scissors size={18} aria-hidden="true"/>{isTr?'Kes':'Trim'}</span><div className="r-zoom"><button type="button" onClick={()=>setZoom(value=>Math.max(1,value-1))} disabled={zoom===1} aria-label={isTr?'Uzaklaştır':'Zoom out'}><Minus size={19} aria-hidden="true"/></button><output aria-live="polite" aria-label={isTr?'Yakınlaştırma düzeyi':'Zoom level'}>{zoom}×</output><button type="button" onClick={()=>setZoom(value=>Math.min(3,value+1))} disabled={zoom===3} aria-label={isTr?'Yakınlaştır':'Zoom in'}><Plus size={19} aria-hidden="true"/></button></div><button type="button" aria-label={isTr?'Sıfırla':'Reset'} onClick={()=>commitTrim(0,Math.min(29,editor.asset.duration))}><RotateCcw size={20} aria-hidden="true"/></button></AudioToolPanel>
      <p className="sr-only">{isTr?'Kesim tutamaklarını sürükle veya ok tuşlarıyla ince ayar yap.':'Drag the trim handles or fine-tune with the arrow keys.'}</p>
      <AudioMarkersPanel editor={editor} language={language} time={playhead} onChange={onChange} onSelect={commitTrim}/>
      {validation?<ErrorStateView message={validation}/>:null}
      {error?<ErrorStateView message={error}/>:null}
    </div>
    <footer className="r-studio-footer"><PlaybackControls language={language} isPlaying={isPlaying} loop={loop} elapsed={playhead-editor.trimStart} duration={duration} onPlay={play} onStop={stop} onToggleLoop={()=>setLoop(value=>!value)}/><PrimaryActionButton onClick={onContinue} disabled={Boolean(validation)} icon={<Scissors size={20} aria-hidden="true"/>}>{isTr?'Efektlere Devam Et':'Continue to Effects'}</PrimaryActionButton></footer>
  </ScreenShell>
}

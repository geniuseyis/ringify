import { useRef, useState, type ChangeEvent, type ReactNode } from 'react'
import { AudioLines, Check, ChevronRight, CircleStop, FileAudio, FileVideo, FolderOpen, Headphones, LoaderCircle, Mic2, Save, Trash2, Video } from 'lucide-react'
import type { AudioMarker, Language, ScreenId } from '../types'
import {maximumAudioMarkers} from '../lib/audioMarkers'
import '../designSystem/audioMarkers.css'
import { ScreenShell } from '../components/ScreenShell'
import {ModalSheet} from '../designSystem/ModalSheet'
import { useVoiceRecorder } from '../hooks/useVoiceRecorder'
import { PrimaryActionButton, SecondaryActionButton } from '../designSystem/StudioComponents'
import { designVariables, formatStudioTime } from '../designSystem/tokens'

interface ImportScreenProps {
  language: Language; isLoading: boolean; error: string | null
  projectLimitReached?: boolean
  onBack: () => void; onChooseFile: (file: File) => void; onUseDemo: () => void
  onNavigate: (screen: ScreenId) => void; onClearError: () => void
}

export function ImportScreen({ language, isLoading, error, projectLimitReached=false, onBack, onChooseFile, onUseDemo, onNavigate, onClearError }: ImportScreenProps) {
  const isTr = language === 'tr'
  const audio = useRef<HTMLInputElement>(null)
  const video = useRef<HTMLInputElement>(null)
  function choose(event: ChangeEvent<HTMLInputElement>) {
    const file = event.currentTarget.files?.[0]
    event.currentTarget.value = ''
    if (file) onChooseFile(file)
  }
  return <ScreenShell title={isLoading ? (isTr ? 'Medya hazırlanıyor' : 'Preparing media') : (isTr ? 'Kaynak seç' : 'Choose a source')}
    onBack={onBack} backLabel={isTr?'Geri':'Back'} className="v2-screen v2-capture v2-import v3-screen v3-flow v3-capture v3-import av-screen av-capture av-import" style={designVariables} scroll={false}>
    <div className="r-capture-workspace">
      {isLoading ? <div className="r-ingest-loading" role="status" aria-live="polite"><span className="r-ingest-loading-icon"><LoaderCircle className="spin" size={32} aria-hidden="true" /></span><h2>{isTr ? 'Ses akışı analiz ediliyor…' : 'Analyzing audio stream…'}</h2></div> : <>
        <div className="r-capture-intro"><h2>{isTr?'Bir ses ekle':'Add a sound'}</h2><p>{isTr?'Dosyalarından seç veya yeni bir kayıt oluştur.':'Choose a file or create a recording.'}</p></div>
        {error ? <div className="r-capture-error" role="alert"><FileAudio size={23} aria-hidden="true" /><div><strong>{projectLimitReached?(isTr?'Proje sınırına ulaştın':'Project limit reached'):(isTr ? 'Dosya açılamadı' : 'Could not open file')}</strong><p>{error}</p><button type="button" onClick={onClearError}>{isTr ? 'Tekrar Dene' : 'Retry'}</button></div></div> : null}
        {projectLimitReached?<PrimaryActionButton onClick={()=>onNavigate('premium')}>{isTr?'Pro planlarını gör':'View Pro plans'}</PrimaryActionButton>:null}
        <div className="r-source-group" role="group" aria-label={isTr ? 'Yerel medya kaynakları' : 'Local media sources'}>
          <ImportSourceCard icon={<Video size={23} />} name={isTr ? 'Fotoğraflar’dan video' : 'Video from Photos'} detail={isTr ? 'Bu önizlemede yerel video seçici' : 'Local video picker in this preview'} onClick={() => video.current?.click()} />
          <ImportSourceCard icon={<FileAudio size={23} />} name={isTr ? 'Dosyalar’dan ses' : 'Audio from Files'} detail="MP3 · M4A · WAV · AAC" onClick={() => audio.current?.click()} />
          <ImportSourceCard icon={<FileVideo size={23} />} name={isTr ? 'Dosyalar’dan video' : 'Video from Files'} detail="MP4 · MOV · WebM" onClick={() => video.current?.click()} />
          <ImportSourceCard icon={<FolderOpen size={23} />} name={isTr?'Kayıtlı projeyi aç':'Open a saved project'} detail={isTr?'Kütüphanenden düzenlemeye devam et':'Continue editing from your library'} onClick={()=>onNavigate('library')}/>
          <ImportSourceCard icon={<FileAudio size={23}/>} name={isTr?'Ses Dönüştür':'Convert Audio'} detail="MP4 / MP3 → WAV · M4A (iOS)" onClick={()=>onNavigate('conversion')}/>
        <button type="button" className="r-mic-source" aria-label={isTr ? 'Mikrofonla kaydet' : 'Record with microphone'} onClick={() => onNavigate('recorder')}><span className="r-source-symbol"><Mic2 size={24} aria-hidden="true" /></span><span><strong>{isTr ? 'Mikrofonla kaydet' : 'Record with microphone'}</strong><small>{isTr ? 'Yeni bir ses kaydı oluştur.' : 'Create a new voice recording.'}</small></span><ChevronRight size={19} aria-hidden="true" /></button>
        </div>
        <button type="button" className="r-demo-source" aria-label={isTr ? 'Telif içermeyen demo sesi kullan' : 'Use royalty-free demo sound'} onClick={onUseDemo}><AudioLines size={19} aria-hidden="true" /><span><strong>{isTr ? 'Örnek sesle dene' : 'Try a sample sound'}</strong><small>{isTr ? 'Telif içermeyen demo sesi kullan' : 'Use royalty-free demo sound'}</small></span><ChevronRight size={18} aria-hidden="true" /></button>
        <input ref={audio} className="sr-only" type="file" aria-label={isTr ? 'Ses dosyası seç' : 'Choose audio file'} accept="audio/*,.mp3,.m4a,.aac,.wav" onChange={choose} />
        <input ref={video} className="sr-only" type="file" aria-label={isTr ? 'Video dosyası seç' : 'Choose video file'} accept="video/*,.mp4,.mov,.webm" onChange={choose} />
      </>}
    </div>
  </ScreenShell>
}

function ImportSourceCard({ icon, name, detail, onClick }: { icon: ReactNode; name: string; detail: string; onClick: () => void }) {
  return <button type="button" className="r-import-source" aria-label={name} onClick={onClick}><span className="r-source-symbol" aria-hidden="true">{icon}</span><span><strong>{name}</strong><small>{detail}</small></span><ChevronRight size={19} aria-hidden="true" /></button>
}

export function RecorderScreen({ language, onBack, onUseRecording }: { language: Language; onBack: () => void; onUseRecording: (file: File, markers?:AudioMarker[]) => void }) {
  const isTr = language === 'tr'
  const capture = useVoiceRecorder(language)
  const [deleteOpen,setDeleteOpen]=useState(false)
  const [markers,setMarkers]=useState<AudioMarker[]>([])
  const deleteTrigger=useRef<HTMLElement|null>(null),startButton=useRef<HTMLButtonElement>(null)
  const active = capture.status === 'recording'
  const pending = capture.status === 'requesting' || capture.status === 'stopping'
  const level = active ? capture.level : 0
  const ready = capture.status === 'ready' && !!capture.recordedFile
  const statusText = active ? (isTr ? 'KAYIT SÜRÜYOR' : 'RECORDING') : ready ? (isTr ? 'KAYIT HAZIR' : 'RECORDING READY') : pending ? (isTr ? 'HAZIRLANIYOR' : 'PREPARING') : (isTr ? 'KAYDA HAZIR' : 'READY TO RECORD')
  return <ScreenShell title={isTr ? 'Ses Kaydı' : 'Voice Recorder'} onBack={onBack} backLabel={isTr?'Geri':'Back'} className="v2-screen v2-capture v2-recorder v3-screen v3-flow v3-capture v3-recorder av-screen av-capture av-recorder" style={designVariables} scroll={false}>
    <div className="r-capture-workspace" inert={deleteOpen?true:undefined} aria-hidden={deleteOpen?true:undefined}>
      <div className={`r-record-deck ${active ? 'is-recording' : ''}`}>
        <div className="r-record-status"><span className="r-status-dot" aria-hidden="true" />{statusText}<span className="r-input-kind">{isTr ? 'MİKROFON' : 'MICROPHONE'}</span></div>
        <div className="r-record-symbol" aria-hidden="true">{ready ? <Check size={34} /> : <Mic2 size={34} strokeWidth={1.5} />}</div>
        <output className="r-record-time" aria-live="off" aria-label={isTr ? 'Kayıt süresi' : 'Recording duration'}>{formatStudioTime(capture.seconds)}</output>
        <div className="r-input-meter" role="meter" data-active={active} aria-label={isTr ? 'Ses seviyesi' : 'Audio level'} aria-valuemin={0} aria-valuemax={1} aria-valuenow={level} aria-valuetext={active ? `${Math.round(level * 100)}% RMS` : (isTr ? 'Mikrofon kapalı' : 'Microphone off')}>
          {Array.from({length:32}, (_, index) => <i key={index} className={active && index / 32 < level ? 'is-active' : ''} aria-hidden="true" />)}
        </div>
        <div className="r-meter-labels"><span><AudioLines size={13} aria-hidden="true" />{isTr ? 'GİRİŞ SEVİYESİ · RMS' : 'INPUT LEVEL · RMS'}</span><span>{active ? `${Math.round(level * 100)}%` : '—'}</span></div>
      </div>
      {active?<button type="button" className="record-marker" disabled={markers.length>=maximumAudioMarkers} onClick={()=>{
        const time=capture.currentTime();if(!Number.isFinite(time)||time<0)return
        setMarkers(previous=>[...previous,{id:crypto.randomUUID(),time,label:isTr?`İşaret ${previous.length+1}`:`Marker ${previous.length+1}`}])
      }}>{isTr?'İşaret Ekle':'Add Marker'} · {markers.length}</button>:null}
      {markers.length?<details className="record-markers"><summary>{isTr?'İşaretler':'Markers'} · {markers.length}</summary><ul>{markers.map(marker=><li key={marker.id}><span>{marker.label} · {formatStudioTime(marker.time)}</span><button type="button" aria-label={`${marker.label} · ${isTr?'Sil':'Delete'}`} onClick={()=>setMarkers(values=>values.filter(value=>value.id!==marker.id))}><Trash2 size={16}/></button></li>)}</ul></details>:null}
      {pending ? <p className="r-pending-note" role="status"><LoaderCircle size={17} className="spin" aria-hidden="true" />{capture.status === 'requesting' ? (isTr ? 'Mikrofon izni bekleniyor…' : 'Waiting for microphone permission…') : (isTr ? 'Kayıt dosyası hazırlanıyor…' : 'Preparing the recording file…')}</p> : null}
      {capture.error ? <div className="r-capture-error" role="alert"><Mic2 size={23} aria-hidden="true" /><div><strong>{isTr ? 'Mikrofona erişilemiyor' : 'Microphone unavailable'}</strong><p>{capture.error}</p></div></div> : null}
      {capture.audioUrl ? <div className="r-record-preview"><span><Headphones size={18} aria-hidden="true" />{isTr ? 'KAYDINI DİNLE' : 'LISTEN BACK'}</span><audio src={capture.audioUrl} controls aria-label={isTr ? 'Kayıt ön izlemesi' : 'Recording preview'} /></div> : null}
    </div>
    <footer className="r-capture-footer r-recorder-actions" inert={deleteOpen?true:undefined} aria-hidden={deleteOpen?true:undefined}>
      {ready && capture.recordedFile ? <><PrimaryActionButton icon={<Save size={20} aria-hidden="true" />} onClick={() => markers.length?onUseRecording(capture.recordedFile!,markers):onUseRecording(capture.recordedFile!)}>{isTr ? 'Kaydı Kullan' : 'Use Recording'}</PrimaryActionButton><SecondaryActionButton icon={<Trash2 size={18} aria-hidden="true" />} onClick={event=>{deleteTrigger.current=event.currentTarget;setDeleteOpen(true)}}>{isTr ? 'Kaydı Sil' : 'Delete Recording'}</SecondaryActionButton></> : active || capture.status === 'stopping' ? <button type="button" className="n4-record-button r-stop-record" onClick={capture.stop} disabled={pending}><span className="n4-record-circle"><CircleStop size={22} aria-hidden="true" /></span><span>{isTr ? 'Kaydı Durdur' : 'Stop Recording'}</span></button> : <button type="button" ref={startButton} className="n4-record-button" onClick={()=>{setMarkers([]);void capture.start()}} disabled={pending}><span className="n4-record-circle"><Mic2 size={22} aria-hidden="true"/></span><span>{isTr?'Kaydı Başlat':'Start Recording'}</span></button>}
    </footer>
    {deleteOpen?<ModalSheet title={isTr?'Kayıt silinsin mi?':'Delete this recording?'} closeLabel={isTr?'Kapat':'Close'} onClose={()=>setDeleteOpen(false)} restoreFocusTo={deleteTrigger.current}>
      <div className="n4-delete-recording"><p>{isTr?'Henüz projeye eklenmemiş bu ses kaydı silinir.':'This recording has not been added to a project and will be deleted.'}</p><button type="button" className="r-action n4-confirm-delete" onClick={()=>{capture.discard();setMarkers([]);setDeleteOpen(false);requestAnimationFrame(()=>startButton.current?.focus())}}>{isTr?'Kaydı Sil':'Delete Recording'}</button><SecondaryActionButton onClick={()=>setDeleteOpen(false)}>{isTr?'Vazgeç':'Cancel'}</SecondaryActionButton></div>
    </ModalSheet>:null}
  </ScreenShell>
}

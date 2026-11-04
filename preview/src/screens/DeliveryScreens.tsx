import {useEffect,useState} from 'react'
import {Check,CheckCircle2,ChevronRight,Download,ExternalLink,FileAudio,FolderOpen,LoaderCircle,Music2,Smartphone} from 'lucide-react'
import type {EditorState,Language} from '../types'
import {sanitizeFileName,formatFileSize} from '../lib/format'
import {ScreenShell} from '../components/ScreenShell'
import {PrimaryActionButton,SecondaryActionButton} from '../designSystem/StudioComponents'
import {designVariables,formatStudioTime} from '../designSystem/tokens'
import {useWavExport} from '../hooks/useWavExport'
import {selectionExportPlan,type WavBitDepth} from '../lib/wavExportPlan'
import '../designSystem/delivery.css'

export function ExportScreen({language,editor,onBack,onComplete,onGuide,onDone,canHighPrecision=false,onRequirePro}: {
  language:Language;editor:EditorState;onBack:()=>void;onComplete:(name:string,blob:Blob)=>Promise<void>;onGuide:()=>void;onDone?:()=>void;canHighPrecision?:boolean;onRequirePro?:()=>void
}){
  const [bitDepth,setBitDepth]=useState<WavBitDepth>(16)
  const isTr=language==='tr',job=useWavExport(editor,onComplete,language,bitDepth)
  const [fileName,setFileName]=useState(editor.projectName)
  useEffect(()=>setFileName(editor.projectName),[editor.projectID,editor.projectName,editor.asset.buffer])
  const busy=job.status==='preparing'||job.status==='saving',buffer=editor.asset.buffer
  const duration=editor.trimEnd-editor.trimStart
  let plan:ReturnType<typeof selectionExportPlan>|null=null
  try{if(buffer)plan=selectionExportPlan(buffer,editor.trimStart,editor.trimEnd,editor.effects,bitDepth)}catch{/* Actual export surfaces validation errors; never display fabricated output metadata. */}
  const rate=buffer?new Intl.NumberFormat(isTr?'tr-TR':'en-US',{maximumFractionDigits:1}).format(buffer.sampleRate/1000):'—'
  const success=job.status==='success'&&job.result
  if(success&&job.result){const result=job.result;return <ScreenShell title={isTr?'Dışa aktar':'Export'} className="export-success-screen v2-screen v4-delivery v3-screen v3-flow v3-delivery av-screen av-finish av-export" style={designVariables} scroll={false}>
    <div className="d-workspace"><div className="d-success-mark"><CheckCircle2 size={42} aria-hidden="true" /></div><div className="d-heading d-centered"><h2>{isTr?'Zil sesin hazır.':'Your ringtone is ready.'}</h2></div><div className="d-result-file"><span className="d-file-icon"><FileAudio size={28} aria-hidden="true" /></span><div><strong title={result.fileName}>{result.fileName}</strong><small>{formatStudioTime(result.duration)} · WAV PCM {result.bitDepth}-bit · {result.channels===1?'Mono':'Stereo'} · {formatFileSize(result.blob.size,language)}</small></div><Check size={20} aria-hidden="true" /></div><a className="d-download r-action r-primary" href={result.url} download={result.fileName}><Download size={20} aria-hidden="true" /><span>{isTr?'Dosyayı İndir':'Download File'}</span></a><button type="button" className="d-guide-link" onClick={onGuide}><Smartphone size={23} aria-hidden="true" /><span>{isTr?'iPhone’da Ayarlama Rehberi':'iPhone Setup Guide'}</span><ChevronRight size={19} aria-hidden="true" /></button></div>
    <footer className="d-footer"><SecondaryActionButton icon={<FolderOpen size={19} aria-hidden="true" />} onClick={onDone??onBack}>{isTr?'Kütüphaneye Git':'Go to Library'}</SecondaryActionButton></footer>
  </ScreenShell>}
  return <ScreenShell title={isTr?'Dışa aktar':'Export'} onBack={job.status==='saving'?undefined:onBack} backLabel={isTr?'Geri':'Back'} className="export-screen v2-screen v4-delivery v3-screen v3-flow v3-delivery av-screen av-finish av-export" style={designVariables} scroll={false}>
    <div className="d-workspace"><div className="d-export-identity"><span className="d-file-icon"><FileAudio size={32} aria-hidden="true" /></span><div><span className="d-kicker">WAV / PCM</span><h2>{editor.projectName}</h2><small title={editor.asset.fileName}>{editor.asset.fileName}</small></div></div>
      <div className="d-section-title">{isTr?'Dosya adı':'File name'}</div><div className="d-name-field"><input id="export-name" aria-label={isTr?'Dosya adı':'File name'} value={fileName} maxLength={64} disabled={busy} onChange={event=>setFileName(event.target.value)} /><span>.wav</span></div>
      <div className="d-section-title">{isTr?'Biçim':'Format'}</div><div className="d-formats"><div><span className="d-format-symbol"><FileAudio size={21} aria-hidden="true" /></span><span><strong>WAV / PCM</strong><small>{isTr?'Tarayıcıda gerçek çıktı':'Real browser output'}</small></span><CheckCircle2 size={22} aria-hidden="true" /></div><div className="d-native-format"><span className="d-format-symbol"><Music2 size={21} aria-hidden="true" /></span><span><strong>M4A / AAC</strong><small>{isTr?'Native iOS hedefi':'Native iOS target'}</small></span><span className="d-ios-label">iOS</span></div></div>
      <label className="d-section-title" htmlFor="wav-precision">{isTr?'PCM hassasiyeti':'PCM precision'}</label><select id="wav-precision" className="d-precision" value={bitDepth} disabled={busy} onChange={event=>{const next=Number(event.target.value) as WavBitDepth;if(next===24&&!canHighPrecision){onRequirePro?.();return}if(next===16||next===24)setBitDepth(next)}}><option value="16">PCM 16-bit</option><option value="24">PCM 24-bit{canHighPrecision?'':' · Pro'}</option></select>
      <div className="d-section-title">{isTr?'Ses bilgileri':'Audio details'}</div><dl className="d-details"><div><dt>{isTr?'Seçili bölüm':'Selection'}</dt><dd>{formatStudioTime(duration)}</dd></div><div><dt>{isTr?'Örnekleme':'Sample rate'}</dt><dd>{rate} kHz · {bitDepth}-bit</dd></div><div><dt>{isTr?'Çıktı kanalları':'Output channels'}</dt><dd>{plan?(plan.channels===1?'Mono':'Stereo'):'—'}</dd></div><div><dt>{isTr?'WAV boyutu':'WAV size'}</dt><dd>{plan?formatFileSize(plan.byteCount,language):'—'}</dd></div></dl>
      {busy?<div className="d-job-status" role="status"><LoaderCircle className="spin" size={24} aria-hidden="true" /><strong>{job.status==='saving'?(isTr?'Proje kaydediliyor…':'Saving project…'):job.stage==='verifying'?(isTr?'Dosya doğrulanıyor…':'Verifying file…'):job.stage==='encoding'?(isTr?'WAV kodlanıyor…':'Encoding WAV…'):(isTr?'Ses işleniyor…':'Processing audio…')}</strong></div>:null}
      {job.error?<p className="d-error" role="alert">{job.error}</p>:null}
    </div>
    <footer className="d-footer">{job.status==='preparing'?<SecondaryActionButton onClick={job.cancel}>{isTr?'İşlemi İptal Et':'Cancel Export'}</SecondaryActionButton>:job.status==='saving'?null:<PrimaryActionButton icon={<Download size={20} aria-hidden="true" />} disabled={!sanitizeFileName(fileName)||!buffer} onClick={()=>void job.start(fileName)}>{isTr?'WAV Olarak Oluştur':'Create WAV'}</PrimaryActionButton>}</footer>
  </ScreenShell>
}

export function RingtoneGuideScreen({language,onBack,onDone}: {language:Language;onBack:()=>void;onDone?:()=>void}){
  const isTr=language==='tr'
  const [method,setMethod]=useState<'26'|'garage'>('26')
  const current=isTr?[
    ['Dosyayı iPhone’a kaydet','WAV çıktısını indir ve Dosyalar uygulamasında aç.'],
    ['Paylaş seçeneklerini aç','“Zil Sesi Olarak Kullan” cihazında görünüyorsa seç. Görünmüyorsa GarageBand yöntemine geç.'],
    ['Sonucu kontrol et','Ayarlar → Ses ve Dokunuş → Zil Sesi bölümünden seçimini doğrula.']
  ]:[['Save to your iPhone','Download the WAV and open it in Files.'],['Open sharing options','Choose “Use as Ringtone” only if your device offers it. Otherwise, use the GarageBand method.'],['Check the result','Confirm the sound in Settings → Sounds & Haptics → Ringtone.']]
  const garage=isTr?[
    ['GarageBand’i aç','Yeni ses kaydı projesi oluştur ve Parçalar görünümüne geç.'],
    ['Ses dosyanı ekle','Döngüler → Dosyalar’dan çıktını içe aktar; bölümü başlangıca hizala.'],
    ['Zil sesi olarak dışa aktar','Parçalarım → Paylaş → Zil Sesi yolunu izle.'],
    ['Kullanımını seç','Dışa aktarma bitince “Sesi şöyle kullan” üzerinden zil sesi türünü seç.']
  ]:[['Open GarageBand','Create a new audio recording project and switch to Tracks.'],['Add your file','Import the export from Loops → Files, then align the region to the beginning.'],['Export a ringtone','From My Songs, share the project as a ringtone.'],['Choose its use','After export, choose the ringtone type in Use Sound As.']]
  return <ScreenShell title={isTr?'Zil sesi olarak ayarla':'Set as Ringtone'} onBack={onBack} backLabel={isTr?'Geri':'Back'} className="guide-screen v2-screen v4-delivery v3-screen v3-flow v3-delivery av-screen av-finish av-guide" style={designVariables} scroll={false}>
    <div className="d-workspace"><div className="d-guide-heading"><span className="d-file-icon"><Smartphone size={31} aria-hidden="true" /></span><div><h2>{isTr?'iPhone’da kullan':'Use on iPhone'}</h2><p>{method==='26'?(isTr?'Cihazına bağlı paylaşım yöntemi':'Device-dependent sharing method'):'GarageBand'}</p></div></div>
      <div className="d-methods" role="group" aria-label={isTr?'Kurulum yöntemi':'Setup method'}><button type="button" aria-pressed={method==='26'} onClick={()=>setMethod('26')}>iOS 26+</button><button type="button" aria-pressed={method==='garage'} onClick={()=>setMethod('garage')}>GarageBand</button></div>
      <ol className="d-guide-steps">{(method==='26'?current:garage).map(([title,description],index)=><li key={`${method}-${index}`}><span aria-hidden="true">{index+1}</span><div><h3>{title}</h3><p>{description}</p></div></li>)}</ol>
      <a className="d-support-link" href="https://support.apple.com/en-gu/120692" target="_blank" rel="noreferrer"><span>{isTr?'Apple’ın resmi rehberi':'Apple official guide'}</span><ExternalLink size={18} aria-hidden="true" /></a>
    </div>
    <footer className="d-footer"><PrimaryActionButton onClick={onDone??onBack}>{isTr?'Tamam':'Done'}</PrimaryActionButton></footer>
  </ScreenShell>
}

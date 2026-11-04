import {useEffect,useRef,useState} from 'react'
import type {EditorState,Language,StudioEffects} from '../types'
import type {AudioAnalysis} from '../lib/audioAnalysis'
import {neutralStudio,studioPresets,studioSettings,validateStudioRate} from '../lib/studioEffects'
import '../designSystem/advancedAudio.css'
import {SegmentSuggestionsPanel} from './SegmentSuggestionsPanel'

export function AdvancedAudioPanel({editor,language,enabled,onChange,onRequirePro}:{editor:EditorState;language:Language;enabled:boolean;onChange:(next:EditorState)=>void;onRequirePro?:()=>void}){
  const tr=language==='tr'
  let settings=neutralStudio,invalid=false
  try{settings=studioSettings(editor.effects.studio)}catch{invalid=true}
  const [measurement,setMeasurement]=useState<{data:AudioAnalysis;buffer:AudioBuffer;start:number;end:number}|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState(false)
  const analysis=measurement?.buffer===editor.asset.buffer&&measurement.start===editor.trimStart&&measurement.end===editor.trimEnd?measurement.data:null
  const worker=useRef<Worker|null>(null)
  const [parameterError,setParameterError]=useState(false)
  useEffect(()=>{setMeasurement(null);setError(false);setBusy(false);setParameterError(false);return()=>{worker.current?.terminate();worker.current=null}},[editor.asset.buffer,editor.trimStart,editor.trimEnd,enabled])
  function update(partial:Partial<StudioEffects>){
    try{const next=studioSettings({...settings,...partial});validateStudioRate(next,editor.asset.buffer?.sampleRate??48000);setParameterError(false);onChange({...editor,effects:{...editor.effects,studio:next}})}
    catch{setParameterError(true)}
  }
  function analyze(){
    const buffer=editor.asset.buffer;if(!enabled||!buffer||busy)return
    setBusy(true);setError(false);setMeasurement(null)
    try{
      const first=Math.round(editor.trimStart*buffer.sampleRate),last=Math.round(editor.trimEnd*buffer.sampleRate)
      if(buffer.numberOfChannels>2||buffer.numberOfChannels<1||last<=first||last-first>Math.ceil(buffer.sampleRate*29.001))throw Error('Invalid source')
      const channels=Array.from({length:buffer.numberOfChannels},(_,i)=>buffer.getChannelData(i).slice(first,last))
      const job=new Worker(new URL('../workers/audioAnalysis.worker.ts',import.meta.url),{type:'module'});worker.current=job
      job.onmessage=event=>{if(worker.current!==job)return;job.terminate();worker.current=null;setBusy(false);if(event.data.error)setError(true);else setMeasurement({data:event.data.result,buffer,start:editor.trimStart,end:editor.trimEnd})}
      job.onerror=()=>{if(worker.current!==job)return;job.terminate();worker.current=null;setBusy(false);setError(true)}
      job.postMessage({channels,sampleRate:buffer.sampleRate},channels.map(channel=>channel.buffer))
    }catch{worker.current?.terminate();worker.current=null;setBusy(false);setError(true)}
  }
  if(invalid)return <div role="alert"><p>{tr?'Kaydedilmiş gelişmiş efekt ayarları geçersiz. Kaynak sesin korunuyor.':'Stored advanced settings are invalid. Your source audio is retained.'}</p><button type="button" onClick={()=>onChange({...editor,effects:{...editor.effects,studio:undefined}})}>{tr?'Gelişmiş ayarları temizle':'Clear advanced settings'}</button></div>
  if(!enabled)return <button type="button" className="advanced-locked" onClick={onRequirePro}>{tr?'EQ, filtreler ve analiz':'EQ, filters and analysis'}<span>Ringify Pro →</span></button>
  const labels={neutral:tr?'Düz':'Flat',warm:tr?'Sıcak':'Warm',clear:tr?'Net':'Clear',telephone:tr?'Telefon':'Telephone'}
  const db=(value:number|null)=>value===null?'−∞':value.toFixed(1)
  return <details className="advanced-audio"><summary>{tr?'Gelişmiş ses araçları':'Advanced audio tools'}</summary>
    {parameterError?<p role="alert">{tr?'Bu kaynak için EQ/filtre frekansları geçersiz. High-pass, low-pass değerinden düşük olmalı.':'Invalid EQ/filter frequencies for this source. High-pass must be below low-pass.'}</p>:null}
    <label>{tr?'Ses karakteri':'Preset'}<select aria-label={tr?'Ses karakteri':'Preset'} value="" onChange={event=>{if(event.target.value)update({...studioPresets[event.target.value as keyof typeof studioPresets]})}}><option value="">{tr?'Bir preset uygula':'Apply a preset'}</option>{Object.entries(labels).map(([id,label])=><option value={id} key={id}>{label}</option>)}</select></label>
    {(['low','mid','high'] as const).map((key,i)=><label key={key}>{[tr?'Bas · 120 Hz':'Bass · 120 Hz',tr?'Orta · 1 kHz':'Mid · 1 kHz',tr?'Tiz · 6 kHz':'Treble · 6 kHz'][i]}<span>{settings[key]>0?'+':''}{settings[key]} dB</span><input aria-label={['EQ 120 Hz','EQ 1 kHz','EQ 6 kHz'][i]} type="range" min="-12" max="12" step="1" value={settings[key]} onChange={event=>update({[key]:Number(event.target.value)})}/></label>)}
    {(['highPass','lowPass'] as const).map(key=><label key={key}>{key==='highPass'?(tr?'High-pass · alt frekans kes':'High-pass'):(tr?'Low-pass · üst frekans kes':'Low-pass')}<select aria-label={key==='highPass'?'High-pass':'Low-pass'} value={settings[key]} onChange={event=>update({[key]:Number(event.target.value)})}>{[0,...(key==='highPass'?[40,80,150,300,500]:[1000,3400,6000,12000,18000]),...(![0,40,80,150,300,500,1000,3400,6000,12000,18000].includes(settings[key])?[settings[key]]:[])].filter(value=>value===0||value<(editor.asset.buffer?.sampleRate??48000)/2).map(value=><option key={value} value={value}>{value?`${value} Hz`:(tr?'Kapalı':'Off')}</option>)}</select></label>)}
    <label>{tr?'Kanallar':'Channels'}<select aria-label={tr?'Kanallar':'Channels'} value={settings.channels} onChange={event=>update({channels:event.target.value as StudioEffects['channels']})}><option value="original">{tr?'Kaynağı koru':'Keep source'}</option><option value="mono">Mono</option><option value="stereo">Stereo</option></select></label>
    <button type="button" role="switch" aria-checked={settings.limiter} onClick={()=>update({limiter:!settings.limiter})}>{tr?'Tepe sınırlayıcı':'Peak limiter'}<span>{settings.limiter?(tr?'Açık':'On'):(tr?'Kapalı':'Off')}</span></button>
    {settings.limiter?<label>{tr?'Tepe tavanı':'Peak ceiling'}<span>{Math.round(settings.ceiling*100)}%</span><input aria-label={tr?'Tepe tavanı':'Peak ceiling'} type="range" min="0.1" max="0.99" step="0.01" value={settings.ceiling} onChange={event=>update({ceiling:Number(event.target.value)})}/></label>:null}
    <button type="button" onClick={()=>update(neutralStudio)}>{tr?'Gelişmiş ayarları sıfırla':'Reset advanced settings'}</button>
    <button type="button" disabled={!editor.asset.buffer||busy} onClick={analyze}>{busy?(tr?'Analiz ediliyor…':'Analyzing…'):(tr?'Seçimi analiz et':'Analyze selection')}</button>
    {busy?<p role="status">{tr?'Kaynak PCM ölçülüyor…':'Measuring source PCM…'}</p>:null}
    {busy?<button type="button" onClick={()=>{worker.current?.terminate();worker.current=null;setBusy(false);setMeasurement(null)}}>{tr?'Analizi iptal et':'Cancel analysis'}</button>:null}
    {error?<p role="alert">{tr?'Analiz tamamlanamadı. Tekrar dene.':'Analysis failed. Try again.'}</p>:null}
    {analysis?<div className="advanced-analysis"><p>{tr?'Kaynak seçimi · efektler öncesi':'Source selection · before effects'}</p><dl><div><dt>Peak</dt><dd>{db(analysis.peakDbFS)} dBFS</dd></div><div><dt>RMS</dt><dd>{db(analysis.rmsDbFS)} dBFS</dd></div><div><dt>{tr?'Sessiz bölgeler':'Silent regions'}</dt><dd>{analysis.silentRegions.length}</dd></div></dl>{analysis.suggestion?<button type="button" onClick={()=>{const suggestion=analysis.suggestion!;onChange({...editor,trimStart:editor.trimStart+suggestion.start,trimEnd:editor.trimStart+suggestion.end})}}>{tr?'Baş/son sessizliğini kes':'Trim leading/trailing silence'}</button>:null}</div>:null}
    <SegmentSuggestionsPanel editor={editor} language={language} onChange={onChange}/>
  </details>
}

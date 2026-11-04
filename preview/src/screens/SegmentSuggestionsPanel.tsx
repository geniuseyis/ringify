import {useEffect,useRef,useState} from 'react'
import type {EditorState,Language} from '../types'
import type {SegmentSuggestion} from '../lib/segmentSuggestions'
import {validSegmentSuggestions} from '../lib/segmentSuggestions'
import {formatTime} from '../lib/format'
export function SegmentSuggestionsPanel({editor,language,onChange}:{editor:EditorState;language:Language;onChange:(editor:EditorState)=>void}){
  const tr=language==='tr',buffer=editor.asset.buffer,worker=useRef<Worker|null>(null)
  const [seconds,setSeconds]=useState<15|20|29>(29),[busy,setBusy]=useState(false),[error,setError]=useState(false)
  const [result,setResult]=useState<{buffer:AudioBuffer;seconds:number;items:SegmentSuggestion[]}|null>(null)
  const items=result?.buffer===buffer&&result.seconds===seconds?result.items:null
  useEffect(()=>{setResult(null);setBusy(false);setError(false);return()=>{worker.current?.terminate();worker.current=null}},[buffer,seconds])
  function cancel(){worker.current?.terminate();worker.current=null;setBusy(false)}
  function scan(){
    if(!buffer||busy)return
    setError(false);setResult(null)
    if(buffer.duration>120||buffer.length*buffer.numberOfChannels*4>48*1024*1024||![1,2].includes(buffer.numberOfChannels)){setError(true);return}
    setBusy(true)
    try{
      const channels=Array.from({length:buffer.numberOfChannels},(_,i)=>buffer.getChannelData(i).slice())
      const job=new Worker(new URL('../workers/segmentSuggestions.worker.ts',import.meta.url),{type:'module'});worker.current=job
      job.onmessage=event=>{
        if(worker.current!==job)return
        cancel()
        const reply:unknown=event.data
        const segments=reply&&typeof reply==='object'&&'segments' in reply?reply.segments:undefined
        if(!validSegmentSuggestions(segments,buffer.duration,buffer.sampleRate,seconds)){setError(true);return}
        setResult({buffer,seconds,items:segments})
      }
      job.onerror=()=>{if(worker.current===job){cancel();setError(true)}}
      job.postMessage({channels,sampleRate:buffer.sampleRate,seconds},channels.map(channel=>channel.buffer))
    }catch{cancel();setError(true)}
  }
  return <section className="segment-suggestions"><h3>{tr?'Ses bölümü önerileri':'Audio segment suggestions'}</h3><p>{tr?'Kaynağın ortalama enerjisine göre sıralanır. Konuşma veya müzik içeriği anlaşılmaz.':'Ranked by average source energy, without interpreting speech or music.'}</p>
    <label>{tr?'Hedef süre':'Target duration'}<select disabled={busy} value={seconds} onChange={event=>setSeconds(Number(event.target.value) as 15|20|29)}>{[15,20,29].map(value=><option key={value} value={value}>{value} {tr?'saniye':'seconds'}</option>)}</select></label>
    <button type="button" disabled={!buffer||busy} onClick={scan}>{tr?'Kaynakta bölüm bul':'Find source segments'}</button>
    {busy?<><p role="status">{tr?'Kaynak taranıyor…':'Scanning source…'}</p><button type="button" onClick={cancel}>{tr?'Taramayı iptal et':'Cancel scan'}</button></>:null}
    {error?<p role="alert">{tr?'Tarama tamamlanamadı. En fazla 2 dakika, 48 MiB açılmış veri ve mono/stereo kaynak gerekir.':'Scan failed. Use mono/stereo up to 2 minutes and 48 MiB decoded data.'}</p>:null}
    {items?items.length?items.map((item,i)=><button key={`${item.start}-${item.end}`} type="button" onClick={()=>onChange({...editor,trimStart:item.start,trimEnd:item.end})}>{i+1}. {formatTime(item.start)}–{formatTime(item.end)} · {item.rmsDbFS.toFixed(1)} dBFS</button>):<p role="status">{tr?'Eşiğin üzerinde uygun bölüm bulunamadı.':'No suitable segment above the energy threshold.'}</p>:null}
  </section>
}

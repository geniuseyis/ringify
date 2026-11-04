import {useState} from 'react'
import type {AudioMarker,EditorState,Language} from '../types'
import {markerSelection,maximumAudioMarkers,validateAudioMarkers} from '../lib/audioMarkers'
import {formatStudioTime} from '../designSystem/tokens'
import '../designSystem/audioMarkers.css'

export function AudioMarkersPanel({editor,language,time,onChange,onSelect}:{editor:EditorState;language:Language;time:number;
  onChange:(next:EditorState)=>void;onSelect:(start:number,end:number)=>void}){
  const tr=language==='tr',[name,setName]=useState(''),[error,setError]=useState(false),[pending,setPending]=useState<string>()
  let markers:AudioMarker[]=[],invalid=false
  try{markers=validateAudioMarkers(editor.markers,editor.asset.duration)}catch{invalid=true}
  function update(next:AudioMarker[]){
    try{const valid=validateAudioMarkers(next,editor.asset.duration);onChange({...editor,markers:valid});setError(false);return true}
    catch{setError(true);return false}
  }
  function select(marker:AudioMarker){
    try{const range=markerSelection(marker,editor.asset.duration,editor.trimEnd-editor.trimStart);onSelect(...range);setError(false)}
    catch{setError(true)}
  }
  return <details className="audio-markers"><summary>{tr?'İşaretler':'Markers'} · {markers.length}</summary>
    {invalid?<p role="alert">{tr?'Kayıtlı işaret verisi geçersiz. Kaynak ses korunuyor.':'Stored marker data is invalid. Source audio is kept.'}</p>:<>
      <label>{tr?'İşaret adı (isteğe bağlı)':'Marker label (optional)'}<input value={name} onChange={event=>setName(event.target.value)} maxLength={120}/></label>
      <button type="button" disabled={markers.length>=maximumAudioMarkers} onClick={()=>{
        const marker={id:crypto.randomUUID(),time,label:name.trim()||(tr?`İşaret ${markers.length+1}`:`Marker ${markers.length+1}`)}
        if(update([...markers,marker]))setName('')
      }}>{tr?'Bu Konuma İşaret Ekle':'Mark This Position'} · {formatStudioTime(time)}</button>
      <ul>{markers.map(marker=><li key={marker.id}>
        <button type="button" className="marker-select" onClick={()=>select(marker)}>{marker.label} · {formatStudioTime(marker.time)}</button>
        <button type="button" aria-label={`${marker.label} · ${tr?'Sil':'Delete'}`} onClick={()=>setPending(marker.id)}>×</button>
      </li>)}</ul>
      {pending?<div role="group" aria-label={tr?'İşaret silinsin mi?':'Delete marker?'}><button type="button" onClick={()=>{if(update(markers.filter(marker=>marker.id!==pending)))setPending(undefined)}}>{tr?'Sil':'Delete'}</button><button type="button" onClick={()=>setPending(undefined)}>{tr?'Vazgeç':'Cancel'}</button></div>:null}
    </>}
    {error?<p role="alert">{tr?'İşaret konumu veya adı geçersiz.':'Invalid marker position or label.'}</p>:null}
  </details>
}

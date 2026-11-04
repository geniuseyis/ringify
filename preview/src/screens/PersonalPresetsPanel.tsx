import {useEffect,useId,useMemo,useRef,useState,type FormEvent} from 'react'
import {Pencil,Trash2} from 'lucide-react'
import type {EditorState,Language} from '../types'
import {ProjectRepository} from '../lib/projectRepository'
import {applyUserPreset,type UserAudioPreset} from '../lib/userAudioPresets'
import {canChangeNormalization,canChangeStudioEffects} from '../lib/proAccess'
import '../designSystem/personalPresets.css'

type PresetStore=Pick<ProjectRepository,'listAudioPresets'|'saveAudioPreset'|'deleteAudioPreset'>
export function PersonalPresetsPanel({editor,language,onChange,canNormalize,canAdvancedEffects,onRequirePro,repository}:{
  editor:EditorState;language:Language;onChange:(next:EditorState)=>void;canNormalize:boolean;canAdvancedEffects:boolean;
  onRequirePro?:()=>void;repository?:PresetStore
}){
  const tr=language==='tr',store=useMemo(()=>repository??new ProjectRepository(),[repository])
  const nameInputID=useId()
  const [presets,setPresets]=useState<UserAudioPreset[]>([]),[name,setName]=useState(''),[editing,setEditing]=useState<string>()
  const [busy,setBusy]=useState(false),[error,setError]=useState(false),[pendingDelete,setPendingDelete]=useState<string>()
  const mounted=useRef(false),deleteTarget=useRef<HTMLButtonElement|null>(null)
  useEffect(()=>{let active=true;mounted.current=true
    store.listAudioPresets().then(rows=>{if(active)setPresets(rows)}).catch(()=>{if(active)setError(true)})
    return()=>{active=false;mounted.current=false}
  },[store])
  async function refresh(){const rows=await store.listAudioPresets();if(mounted.current)setPresets(rows)}
  async function save(event:FormEvent){
    event.preventDefault();if(busy)return
    setBusy(true);setError(false)
    try{
      const prior=presets.find(item=>item.id===editing),now=new Date().toISOString()
      await store.saveAudioPreset({id:prior?.id??crypto.randomUUID(),name:name.trim(),effects:prior?.effects??editor.effects,
        createdAt:prior?.createdAt??now,updatedAt:now})
      await refresh();if(mounted.current){setName('');setEditing(undefined)}
    }catch{if(mounted.current)setError(true)}finally{if(mounted.current)setBusy(false)}
  }
  function apply(preset:UserAudioPreset){
    setError(false)
    try{
      if(!editor.asset.buffer)throw Error('Open an audio source first')
      const next=applyUserPreset(preset,editor.trimEnd-editor.trimStart,editor.asset.buffer.sampleRate)
      if(!canChangeNormalization(editor.effects.normalize,next.normalize,canNormalize)||!canChangeStudioEffects(editor.effects,next,canAdvancedEffects)){
        onRequirePro?.();return
      }
      onChange({...editor,effects:next})
    }catch{setError(true)}
  }
  async function remove(){
    if(!pendingDelete||busy)return
    setBusy(true);setError(false)
    try{await store.deleteAudioPreset(pendingDelete);await refresh();if(mounted.current){setPendingDelete(undefined);deleteTarget.current?.focus()}}
    catch{if(mounted.current)setError(true)}finally{if(mounted.current)setBusy(false)}
  }
  return <details className="personal-presets"><summary>{tr?'Kişisel Ses Ayarları':'Personal Audio Presets'}</summary>
    <form onSubmit={save}>
      <label htmlFor={nameInputID}>{tr?'Ayar adı':'Preset name'}</label>
      <input id={nameInputID} value={name} onChange={e=>setName(e.target.value)} maxLength={120} autoComplete="off" disabled={busy}/>
      <div className="preset-actions"><button type="submit" disabled={busy||!name.trim()}>{editing?(tr?'Adı Kaydet':'Save Name'):(tr?'Mevcut Ayarları Kaydet':'Save Current Settings')}</button>
        {editing?<button type="button" disabled={busy} onClick={()=>{setEditing(undefined);setName('')}}>{tr?'Vazgeç':'Cancel'}</button>:null}</div>
    </form>
    {presets.map(preset=><div className="preset-row" key={preset.id}>
      <button type="button" className="preset-apply" disabled={busy} onClick={()=>apply(preset)}>{preset.name}</button>
      <button type="button" disabled={busy} aria-label={`${preset.name} · ${tr?'Yeniden adlandır':'Rename'}`} onClick={()=>{setEditing(preset.id);setName(preset.name)}}><Pencil size={18}/></button>
      <button type="button" disabled={busy} aria-label={`${preset.name} · ${tr?'Sil':'Delete'}`} onClick={event=>{deleteTarget.current=event.currentTarget;setPendingDelete(preset.id)}}><Trash2 size={18}/></button>
    </div>)}
    {pendingDelete?<fieldset className="preset-confirm" onKeyDown={event=>{if(event.key==='Escape'){event.stopPropagation();setPendingDelete(undefined);deleteTarget.current?.focus()}}}>
      <legend>{tr?'Kişisel ayar silinsin mi?':'Delete personal preset?'}</legend>
      <button type="button" disabled={busy} onClick={remove}>{tr?'Sil':'Delete'}</button>
      <button type="button" disabled={busy} onClick={()=>{setPendingDelete(undefined);deleteTarget.current?.focus()}}>{tr?'Vazgeç':'Cancel'}</button>
    </fieldset>:null}
    {busy?<p role="status">{tr?'Kaydediliyor…':'Saving…'}</p>:null}
    {error?<div role="alert"><p>{tr?'İşlem tamamlanamadı. Kaydı ve kaynak sesini koruduk; adı veya kaynak ayarlarını kontrol et.':'The operation failed. Saved presets and source audio are kept; check the name or source settings.'}</p>
      <button type="button" disabled={busy} onClick={()=>{setError(false);refresh().catch(()=>setError(true))}}>{tr?'Tekrar Dene':'Try Again'}</button></div>:null}
  </details>
}

import {useEffect,useRef,useState} from 'react'
import type {Language,ProjectSummary} from '../types'
import type {ExportSummary,ProjectCollection,StoredMedia} from '../lib/projectRepository'
import {formatFileSize,formatDate} from '../lib/format'
import {mediaBlob} from '../lib/projectRepository'
import {shareAudioFile} from '../lib/sharing'
import {LibraryAccessError,ProjectLimitError} from '../lib/proAccess'
import '../designSystem/libraryTools.css'

export interface LibraryOperations {
  pro:boolean;onRequirePro:()=>void
  patch:(ids:string[],patch:Pick<Partial<ProjectSummary>,'favorite'|'collectionIDs'>)=>Promise<void>
  duplicate:(id:string)=>Promise<void>;removeMany:(ids:string[])=>Promise<void>
  collections:()=>Promise<ProjectCollection[]>;createCollection:(name:string)=>Promise<ProjectCollection>;deleteCollection:(id:string)=>Promise<void>
  history:(id:string)=>Promise<ExportSummary[]>;exportMedia:(id:string)=>Promise<StoredMedia|undefined>;deleteExport:(id:string)=>Promise<void>;storage:()=>Promise<number>
}
export {LibraryTools} from './LibraryOrganizer'
export function LibraryProjectTools({project,language,ops,onClose,onBusyChange,onSubviewChange}:{project:ProjectSummary;language:Language;ops:LibraryOperations;onClose:()=>void;onBusyChange:(busy:boolean)=>void;onSubviewChange?:(active:boolean)=>void}){
  const tr=language==='tr',[mode,setMode]=useState<'actions'|'collection'|'history'>('actions'),[collections,setCollections]=useState<ProjectCollection[]>([]),[selected,setSelected]=useState<string[]>(project.collectionIDs??[]),[history,setHistory]=useState<ExportSummary[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState<string|null>(null),[deleting,setDeleting]=useState<string|null>(null)
  const mounted=useRef(true),running=useRef(false)
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false}},[])
  useEffect(()=>onSubviewChange?.(mode!=='actions'),[mode,onSubviewChange])
  async function run(action:()=>Promise<void>,close=false){if(running.current)return;running.current=true;setBusy(true);onBusyChange(true);setError(null);try{await action();if(close&&mounted.current)onClose()}catch(failure){if(failure instanceof LibraryAccessError||failure instanceof ProjectLimitError){onClose();ops.onRequirePro()}else if(mounted.current)setError(failure instanceof Error?failure.message:(tr?'İşlem tamamlanamadı.':'Operation failed.'))}finally{running.current=false;onBusyChange(false);if(mounted.current)setBusy(false)}}
  return <div className="library-tool-sheet">{error?<p role="alert">{error}</p>:null}{busy?<p role="status">{tr?'İşlem sürüyor…':'Working…'}</p>:null}
    {mode==='actions'?<><button type="button" disabled={busy} onClick={()=>{if(!ops.pro&&!project.favorite){onClose();ops.onRequirePro();return}void run(()=>ops.patch([project.id],{favorite:!project.favorite}),true)}}>{project.favorite?(tr?'Favorilerden kaldır':'Remove favorite'):(tr?'Favorilere ekle · Pro':'Add favorite · Pro')}</button><button type="button" disabled={busy} onClick={()=>void run(()=>ops.duplicate(project.id),true)}>{tr?'Çoğalt':'Duplicate'}</button><button type="button" disabled={busy} onClick={()=>void run(async()=>{setCollections(await ops.collections());setMode('collection')})}>{tr?'Koleksiyonları düzenle':'Edit collections'}</button><button type="button" disabled={busy} onClick={()=>void run(async()=>{setHistory(await ops.history(project.id));setMode('history')})}>{tr?'Dışa aktarma geçmişi':'Export history'}</button></>:null}
    {mode==='collection'?<><h3 className="uf-sheet-section-title">{tr?'Koleksiyonları düzenle':'Edit collections'}</h3>{collections.map(row=><label key={row.id}><input type="checkbox" checked={selected.includes(row.id)} disabled={busy||(!ops.pro&&!project.collectionIDs?.includes(row.id))} onChange={event=>setSelected(old=>event.target.checked?[...old,row.id]:old.filter(id=>id!==row.id))}/>{row.name}</label>)}{!collections.length?<p>{tr?'Henüz koleksiyon yok.':'No collections yet.'}</p>:null}<button type="button" disabled={busy} onClick={()=>void run(()=>ops.patch([project.id],{collectionIDs:selected}),true)}>{tr?'Koleksiyonları Kaydet':'Save Collections'}</button></>:null}
    {mode==='history'?<>{!history.length?<p>{tr?'Arşivlenmiş çıktı yok.':'No archived exports.'}</p>:null}{history.map(row=><div key={row.id}><strong>{row.name}</strong><p>{formatDate(row.createdAt,tr?'tr-TR':'en-US')} · {formatFileSize(row.byteCount,language)} · {row.verified?`PCM ${row.bitDepth}-bit`:(tr?'Eski çıktı · doğrulama yok':'Legacy output · unverified')}</p><button type="button" disabled={busy} onClick={()=>void run(async()=>{const media=await ops.exportMedia(row.id);if(!media)throw Error(tr?'Çıktı bulunamadı.':'Output not found.');await shareAudioFile(mediaBlob(media),row.name)})}>{tr?'Paylaş / İndir':'Share / Download'}</button>{deleting===row.id?<><p>{tr?'Bu arşiv kaydı silinsin mi? Kaynak ve güncel proje çıktısı korunur.':'Delete this archive entry? Source and current output are retained.'}</p><button type="button" disabled={busy} onClick={()=>void run(async()=>{await ops.deleteExport(row.id);setHistory(await ops.history(project.id));setDeleting(null)})}>{tr?'Arşiv Kaydını Sil':'Delete Archive Entry'}</button><button type="button" disabled={busy} onClick={()=>setDeleting(null)}>{tr?'Vazgeç':'Cancel'}</button></>:<button type="button" disabled={busy} onClick={()=>setDeleting(row.id)}>{tr?'Arşivden kaldır':'Remove from history'}</button>}</div>)}</>:null}
    {mode!=='actions'?<button type="button" disabled={busy} onClick={()=>setMode('actions')}>{tr?'Geri':'Back'}</button>:null}
  </div>
}

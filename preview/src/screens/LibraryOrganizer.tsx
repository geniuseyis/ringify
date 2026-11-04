import {useEffect,useRef,useState} from 'react'
import {createPortal} from 'react-dom'
import {ArrowUpDown,ChevronLeft,ChevronRight,Folder,HardDrive,Plus,Star,Trash2} from 'lucide-react'
import type {Language,ProjectSummary} from '../types'
import type {ProjectCollection} from '../lib/projectRepository'
import type {LibraryOperations} from './LibraryTools'
import {ModalSheet} from '../designSystem/ModalSheet'
import {formatFileSize} from '../lib/format'

interface Props{language:Language;projects:ProjectSummary[];ops:LibraryOperations;onFilter:(favorite:boolean,collection:string,sort:string)=>void;onBatch:()=>void;batch:boolean;onModalChange?:(open:boolean)=>void}
export function LibraryTools({language,projects,ops,onFilter,onBatch,batch,onModalChange}:Props){
  const tr=language==='tr',[favorite,setFavorite]=useState(false),[collection,setCollection]=useState(''),[sort,setSort]=useState('newest')
  const [rows,setRows]=useState<ProjectCollection[]>([]),[pane,setPane]=useState<'filters'|'collections'|'storage'|null>(null),[create,setCreate]=useState(false)
  const [name,setName]=useState(''),[bytes,setBytes]=useState<number|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState<string|null>(null),[deleting,setDeleting]=useState<string|null>(null)
  const trigger=useRef<HTMLElement|null>(null),root=useRef<HTMLDivElement>(null),alive=useRef(true),running=useRef(false)
  useEffect(()=>{alive.current=true;let current=true;void ops.collections().then(value=>{if(current)setRows(value)}).catch(()=>{if(current)setError(tr?'Koleksiyonlar okunamadı.':'Could not read collections.')});return()=>{current=false;alive.current=false}},[ops.collections,tr,projects])
  useEffect(()=>onFilter(favorite,collection,sort),[favorite,collection,sort,onFilter])
  useEffect(()=>{if(pane!=='storage')return;let current=true;setBytes(null);void ops.storage().then(value=>{if(current)setBytes(value)}).catch(()=>{if(current)setError(tr?'Depolama bilgisi okunamadı.':'Could not read storage.')});return()=>{current=false}},[pane,ops.storage,tr])
  function close(){if(running.current)return;onModalChange?.(false);setPane(null);setCreate(false);setError(null)}
  function open(next:typeof pane,element:HTMLElement){trigger.current=element;setError(null);setPane(next);onModalChange?.(true)}
  function requirePro(){close();ops.onRequirePro()}
  async function run(action:()=>Promise<void>){if(running.current)return;running.current=true;setBusy(true);setError(null);try{await action()}catch(failure){if(alive.current)setError(failure instanceof Error?failure.message:(tr?'İşlem başarısız.':'Operation failed.'))}finally{running.current=false;if(alive.current)setBusy(false)}}
  const title=pane==='filters'?(tr?'Filtrele ve sırala':'Filter and sort'):pane==='storage'?(tr?'Depolama bilgisi':'Storage information'):create?(tr?'Yeni koleksiyon':'New collection'):(tr?'Koleksiyonlar':'Collections')
  const dialog=pane?<ModalSheet title={title} closeLabel={tr?'Kapat':'Close'} busy={busy} onClose={close} focusKey={`${pane}:${create}`} restoreFocusTo={trigger.current}>
    <div className="library-tool-sheet">
      {error?<p role="alert">{error}</p>:null}
      {pane==='filters'?<>
        <label>{tr?'Sıralama':'Sort'}<select value={sort} onChange={event=>setSort(event.target.value)}>{(tr?['En yeni','En eski','Ad','Süre']:['Newest','Oldest','Name','Duration']).map((label,i)=><option value={['newest','oldest','name','duration'][i]} key={label}>{label}</option>)}</select></label>
        <label>{tr?'Koleksiyon':'Collection'}<select value={collection} onChange={event=>setCollection(event.target.value)}><option value="">{tr?'Tümü':'All'}</option>{rows.map(row=><option value={row.id} key={row.id}>{row.name}</option>)}</select></label>
        <button type="button" onClick={()=>{setFavorite(false);setCollection('');setSort('newest')}}>{tr?'Filtreleri temizle':'Clear filters'}</button>
        <button type="button" onClick={()=>{if(!ops.pro&&!batch){requirePro();return}close();onBatch()}}>{batch?(tr?'Seçimi kapat':'Exit selection'):(tr?'Çoklu seçim · Pro':'Multi-select · Pro')}</button>
        <button type="button" onClick={()=>setPane('storage')}><HardDrive size={18}/>{tr?'Depolama bilgisi':'Storage information'}</button>
        <button type="button" onClick={close}>{tr?'Sonuçları göster':'Show results'}</button>
      </>:null}
      {pane==='collections'&&!create?<>
        <button type="button" onClick={()=>{setCollection('');close()}}>{tr?'Tüm projeler':'All projects'}<ChevronRight size={17}/></button>
        {!rows.length?<p>{tr?'Projelerini koleksiyonlarla bir arada tut.':'Keep related projects together in collections.'}</p>:rows.map(row=><div key={row.id}><div className="uf-collection-row"><button type="button" disabled={busy} onClick={()=>{setCollection(row.id);close()}}><Folder size={19}/><span>{row.name}</span><small>{projects.filter(project=>project.collectionIDs?.includes(row.id)).length}</small></button><button type="button" disabled={busy} aria-label={tr?`${row.name} koleksiyonunu sil`:`Delete collection ${row.name}`} onClick={()=>setDeleting(row.id)}><Trash2 size={18}/></button></div>
          {deleting===row.id?<><p>{tr?'Yalnız koleksiyon kaldırılır; projeler korunur.':'Only the collection is removed; projects are retained.'}</p><button type="button" disabled={busy} onClick={()=>void run(async()=>{await ops.deleteCollection(row.id);setRows(await ops.collections());if(collection===row.id)setCollection('');setDeleting(null)})}>{tr?'Koleksiyonu Sil':'Delete Collection'}</button><button type="button" disabled={busy} onClick={()=>setDeleting(null)}>{tr?'Vazgeç':'Cancel'}</button></>:null}
        </div>)}
        <button type="button" disabled={busy} onClick={()=>{if(!ops.pro){requirePro();return}setCreate(true)}}><Plus size={18}/>{tr?'Koleksiyon oluştur · Pro':'Create collection · Pro'}</button>
        <button type="button" disabled={busy} onClick={()=>setPane('storage')}><HardDrive size={18}/>{tr?'Depolama bilgisi':'Storage information'}</button>
      </>:null}
      {pane==='collections'&&create?<>
        <button type="button" className="uf-sheet-back" disabled={busy} onClick={()=>setCreate(false)}><ChevronLeft size={19}/>{tr?'Koleksiyonlar':'Collections'}</button>
        <label>{tr?'Koleksiyon adı':'Collection name'}<input data-autofocus value={name} maxLength={64} disabled={busy} onChange={event=>setName(event.target.value)}/></label>
        <button type="button" disabled={busy||!name.trim()} onClick={()=>void run(async()=>{await ops.createCollection(name);setRows(await ops.collections());setName('');setCreate(false)})}>{tr?'Oluştur':'Create'}</button>
      </>:null}
      {pane==='storage'?<>
        {bytes===null?<p role="status">{tr?'Hesaplanıyor…':'Calculating…'}</p>:<section className="uf-storage-summary"><HardDrive size={26}/><strong>{formatFileSize(bytes,language)}</strong><span>{tr?'Kayıtlı medya verisi':'Stored media payload'}</span><small>{projects.length} {tr?'proje':'projects'}</small></section>}
        <p>{tr?'Kaynaklar, güncel çıktılar ve dışa aktarma geçmişindeki medya verisi.':'Media payload in sources, current outputs and export history.'}</p>
        <button type="button" onClick={()=>setPane('collections')}>{tr?'Koleksiyonları yönet':'Manage collections'}</button>
      </>:null}
    </div>
  </ModalSheet>:null
  const host=root.current?.closest('.screen-content')
  return <div ref={root}>
    <div className="uf-library-toolbar"><button type="button" aria-label={tr?'Favoriler':'Favorites'} aria-pressed={favorite} onClick={()=>setFavorite(value=>!value)}><Star size={17}/>{tr?'Favoriler':'Favorites'}<span>{projects.filter(project=>project.favorite).length}</span></button><button type="button" onClick={event=>open('collections',event.currentTarget)}><Folder size={17}/>{tr?'Koleksiyonlar':'Collections'}</button><button type="button" aria-label={tr?'Filtrele ve sırala':'Filter and sort'} onClick={event=>open('filters',event.currentTarget)}><ArrowUpDown size={20}/></button></div>
    <div className="uf-filter-heading"><strong>{collection?rows.find(row=>row.id===collection)?.name:(tr?{newest:'Son düzenlenenler',oldest:'En eski projeler',name:'Ada göre',duration:'Süreye göre'}:{newest:'Recently edited',oldest:'Oldest projects',name:'By name',duration:'By duration'})[sort as 'newest']}</strong>{collection?<button type="button" onClick={()=>setCollection('')}>{tr?'Temizle':'Clear'}</button>:null}{batch?<button type="button" onClick={onBatch}>{tr?'Seçimi kapat':'Exit selection'}</button>:null}</div>
    {!pane&&error?<p role="alert">{error}</p>:null}{host?createPortal(dialog,host):dialog}
  </div>
}

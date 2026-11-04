import type { AudioEffects, EditorState, ProjectSummary } from '../types'
import {maximumUserPresets,validateUserPreset,type UserAudioPreset} from './userAudioPresets'
import {validateAudioMarkers} from './audioMarkers'
import type {AudioMarker} from '../types'

export interface StoredMedia { bytes: ArrayBuffer; type: string }
export interface StoredProject {
  markers?: AudioMarker[]
  id: string
  summary: ProjectSummary
  sourceDuration: number
  effects: AudioEffects
  source: StoredMedia | null
  output?: StoredMedia
}
export interface ProjectCollection {id:string;name:string;createdAt:string}
export interface ExportSummary {id:string;projectID:string;name:string;createdAt:string;byteCount:number;bitDepth?:number;duration?:number;verified:boolean}
interface ProjectIndex {id:string;summary:ProjectSummary;sourceBytes:number;outputBytes:number;lastExportID?:string}
interface ExportRecord extends ExportSummary {media:StoredMedia}
const stores=['projects','projectSummaries','collections','exportHistory','exportSummaries','audioPresets']
function indexRecord(project:StoredProject,lastExportID?:string):ProjectIndex{return{id:project.id,summary:project.summary,sourceBytes:project.source?.bytes.byteLength??0,outputBytes:project.output?.bytes.byteLength??0,...(lastExportID?{lastExportID}:{})}}
function exportRecord(project:StoredProject,id:string):ExportRecord{
  const media=project.output!,bytes=media.bytes
  let bitDepth:number|undefined,duration:number|undefined,verified=false
  if(bytes.byteLength>=44){
    const view=new DataView(bytes),rate=view.getUint32(24,true),channels=view.getUint16(22,true),bits=view.getUint16(34,true)
    const alignment=channels*bits/8,dataSize=bytes.byteLength-44
    verified=view.getUint32(0,false)===0x52494646&&view.getUint32(4,true)===bytes.byteLength-8
      &&view.getUint32(8,false)===0x57415645&&view.getUint32(12,false)===0x666d7420&&view.getUint32(16,true)===16
      &&view.getUint16(20,true)===1&&[16,24].includes(bits)&&[1,2].includes(channels)&&rate>0
      &&view.getUint32(28,true)===rate*alignment&&view.getUint16(32,true)===alignment
      &&view.getUint32(36,false)===0x64617461&&view.getUint32(40,true)===dataSize&&dataSize>0&&dataSize%alignment===0
    if(verified){bitDepth=bits;duration=(bytes.byteLength-44)/(rate*channels*bits/8)}
  }
  return{id,projectID:project.id,name:project.summary.name,createdAt:project.summary.updatedAt,byteCount:bytes.byteLength,bitDepth,duration,verified,media}
}
function putExport(tx:IDBTransaction,record:ExportRecord){const {media,...summary}=record;tx.objectStore('exportHistory').put(record);tx.objectStore('exportSummaries').put(summary)}

export async function storeMedia(blob: Blob): Promise<StoredMedia> {
  return { bytes: await blob.arrayBuffer(), type: blob.type }
}
export function mediaBlob(media: StoredMedia): Blob {
  return new Blob([media.bytes], { type: media.type })
}

export function projectSnapshot(editor: EditorState, previous?: StoredProject): StoredProject {
  if (!editor.projectID) throw new Error('Missing project identifier')
  const unchanged = previous && previous.summary.trimStart === editor.trimStart
    && previous.summary.trimEnd === editor.trimEnd
    && JSON.stringify(previous.effects) === JSON.stringify(editor.effects)
  return {
    id: editor.projectID,
    summary: {
      ...previous?.summary,
      id: editor.projectID, name: editor.projectName, sourceName: editor.asset.fileName,
      duration: editor.trimEnd - editor.trimStart, trimStart: editor.trimStart, trimEnd: editor.trimEnd,
      updatedAt: new Date().toISOString(), status: unchanged ? previous.summary.status : 'draft', isDemo: editor.asset.isDemo,
    },
    sourceDuration: editor.asset.duration, effects: { ...editor.effects },
    ...(editor.markers!==undefined||previous?.markers!==undefined?{markers:validateAudioMarkers(editor.markers===undefined?previous?.markers:editor.markers,editor.asset.duration)}:{}),
    source: previous?.source ?? null, output: unchanged ? previous.output : undefined,
  }
}

export class ProjectRepository {
  constructor(private readonly name = 'ringify.projects.v2', private readonly factory: IDBFactory | undefined = globalThis.indexedDB) {}

  private open(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      if (!this.factory) { reject(new Error('IndexedDB unavailable')); return }
      let blocked = false
      const request = this.factory.open(this.name, 3)
      request.onupgradeneeded = (event) => {
        const db=request.result,tx=request.transaction!
        if(!db.objectStoreNames.contains('projects'))db.createObjectStore('projects',{keyPath:'id'})
        for(const name of stores.slice(1))if(!db.objectStoreNames.contains(name)){
          const store=db.createObjectStore(name,{keyPath:'id'})
          if(name.startsWith('export'))store.createIndex('projectID','projectID',{unique:false})
        }
        // v2 -> v3 only adds presets. Preserve source, indexes and export IDs.
        if(event.oldVersion>=2)return
        // Bounded cursor backfill. Never delete/rewrite an original source row.
        const cursor=tx.objectStore('projects').openCursor()
        cursor.onsuccess=()=>{const row=cursor.result;if(!row)return;try{const project=row.value as StoredProject
          if(!project.summary||project.summary.id!==project.id){tx.abort();return}
          const legacyID=project.output?`legacy:${project.id}`:undefined
          tx.objectStore('projectSummaries').put(indexRecord(project,legacyID))
          if(legacyID)putExport(tx,exportRecord(project,legacyID))
          row.continue()}catch{tx.abort()}
        }
      }
      request.onsuccess = () => { const db=request.result;db.onversionchange=()=>db.close();if (blocked) db.close(); else resolve(db) }
      request.onerror = () => reject(request.error ?? new Error('Could not open project storage'))
      request.onblocked = () => { blocked = true; reject(new Error('Project storage is open in another tab')) }
    })
  }
  private async transaction<T>(mode:IDBTransactionMode,action:(tx:IDBTransaction,done:(value:T)=>void,fail:(error:unknown)=>void)=>void):Promise<T>{
    const db=await this.open()
    return new Promise((resolve,reject)=>{
      const tx=db.transaction(stores,mode);let value:T,failure:unknown,failed=false
      const fail=(error:unknown)=>{if(failed)return;failed=true;failure=error;tx.abort()}
      tx.oncomplete=()=>{db.close();resolve(value)}
      tx.onabort=tx.onerror=()=>{db.close();reject(failure??tx.error??Error('Library transaction failed'))}
      try{action(tx,next=>{value=next},fail)}catch(error){fail(error)}
    })
  }

  async listAudioPresets():Promise<UserAudioPreset[]> {
    return this.transaction('readonly',(tx,done,fail)=>{
      const request=tx.objectStore('audioPresets').getAll()
      request.onsuccess=()=>{try{done(request.result.map(validateUserPreset).sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt)||a.id.localeCompare(b.id)))}catch(error){fail(error)}}
    })
  }
  async saveAudioPreset(value:UserAudioPreset):Promise<void> {
    const preset=validateUserPreset(value)
    return this.transaction('readwrite',(tx,done,fail)=>{
      const store=tx.objectStore('audioPresets'),request=store.getAll()
      request.onsuccess=()=>{try{
        const all=request.result.map(validateUserPreset),prior=all.find(item=>item.id===preset.id)
        if(all.some(item=>item.id!==preset.id&&item.name.localeCompare(preset.name,undefined,{sensitivity:'base'})===0))throw Error('Preset name already exists')
        if(!prior&&all.length>=maximumUserPresets)throw Error('Preset limit reached')
        if(prior&&prior.createdAt!==preset.createdAt)throw Error('Preset identity changed')
        store.put(preset);done(undefined)
      }catch(error){fail(error)}}
    })
  }
  async deleteAudioPreset(id:string):Promise<void> {
    return this.transaction('readwrite',(tx,done)=>{tx.objectStore('audioPresets').delete(id);done(undefined)})
  }

  async list(): Promise<StoredProject[]> {
    return this.transaction('readonly',(tx,done)=>{
      const rows=tx.objectStore('projects').getAll(),meta=tx.objectStore('projectSummaries').getAll();let ready=0
      const finish=()=>{if(++ready!==2)return;const map=new Map((meta.result as ProjectIndex[]).map(item=>[item.id,item.summary]));done((rows.result as StoredProject[]).map(row=>({...row,summary:map.get(row.id)??row.summary})).sort((a,b)=>b.summary.updatedAt.localeCompare(a.summary.updatedAt)))}
      rows.onsuccess=finish;meta.onsuccess=finish
    })
  }
  async get(id: string): Promise<StoredProject | undefined> {
    return this.transaction('readonly',(tx,done)=>{
      const row=tx.objectStore('projects').get(id),meta=tx.objectStore('projectSummaries').get(id);let ready=0
      const finish=()=>{if(++ready===2)done(row.result?{...row.result,summary:meta.result?.summary??row.result.summary}:undefined)}
      row.onsuccess=finish;meta.onsuccess=finish
    })
  }
  async put(project: StoredProject): Promise<void> {
    await this.putChecked(project,()=>{},false)
  }
  async putChecked(project:StoredProject,validate:(current:StoredProject|undefined,count:number)=>void,archiveOutput:boolean):Promise<void>{
    return this.transaction('readwrite',(tx,done,fail)=>{
      const current=tx.objectStore('projects').get(project.id),meta=tx.objectStore('projectSummaries').get(project.id),count=tx.objectStore('projects').count();let ready=0
      const commit=()=>{if(++ready!==3)return;try{
        const previous=current.result?{...current.result,summary:meta.result?.summary??current.result.summary}:undefined
        validate(previous,count.result)
        const record={...project,summary:{...project.summary,...(meta.result?{favorite:meta.result.summary.favorite,collectionIDs:meta.result.summary.collectionIDs}:{})}}
        // Missing optional traits remain absent for old-record compatibility.
        if(record.summary.favorite===undefined)delete record.summary.favorite
        if(record.summary.collectionIDs===undefined)delete record.summary.collectionIDs
        let lastExportID=meta.result?.lastExportID
        if(record.output&&(archiveOutput||!lastExportID)){lastExportID=crypto.randomUUID();putExport(tx,exportRecord(record,lastExportID))}
        tx.objectStore('projects').put(record);tx.objectStore('projectSummaries').put(indexRecord(record,lastExportID));done(undefined)
      }catch(error){fail(error)}}
      current.onsuccess=commit;meta.onsuccess=commit;count.onsuccess=commit
    })
  }
  async delete(id: string): Promise<void> {
    await this.deleteMany([id])
  }
  async clear(): Promise<void> {
    await this.transaction<void>('readwrite',(tx,done)=>{for(const name of stores)tx.objectStore(name).clear();done(undefined)})
  }
  async listSummaries():Promise<ProjectSummary[]>{return this.transaction('readonly',(tx,done)=>{const request=tx.objectStore('projectSummaries').getAll();request.onsuccess=()=>done((request.result as ProjectIndex[]).map(row=>row.summary).sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt)))})}
  async collections():Promise<ProjectCollection[]>{return this.transaction('readonly',(tx,done)=>{const request=tx.objectStore('collections').getAll();request.onsuccess=()=>done(request.result)})}
  async createCollection(name:string):Promise<ProjectCollection>{
    const clean=name.trim();if(!clean||clean.length>64||/[\u0000-\u001f]/.test(clean))throw Error('Invalid collection name')
    return this.transaction('readwrite',(tx,done,fail)=>{const request=tx.objectStore('collections').getAll();request.onsuccess=()=>{
      if(request.result.some((row:ProjectCollection)=>row.name.toLocaleLowerCase('tr')===clean.toLocaleLowerCase('tr'))){fail(Error('Collection name already exists'));return}
      const row={id:crypto.randomUUID(),name:clean,createdAt:new Date().toISOString()};tx.objectStore('collections').put(row);done(row)
    }})
  }
  async patchSummaries(ids:string[],patch:Pick<Partial<ProjectSummary>,'favorite'|'collectionIDs'|'name'>,validate?:(current:ProjectSummary)=>void):Promise<void>{
    if(patch.favorite!==undefined&&typeof patch.favorite!=='boolean')throw Error('Invalid favorite value')
    if(patch.collectionIDs!==undefined&&(!Array.isArray(patch.collectionIDs)||patch.collectionIDs.some(id=>typeof id!=='string')))throw Error('Invalid collection IDs')
    return this.transaction('readwrite',(tx,done,fail)=>{
      const collections=tx.objectStore('collections').getAll();collections.onsuccess=()=>{
        const valid=new Set((collections.result as ProjectCollection[]).map(row=>row.id))
        if(patch.collectionIDs?.some(id=>!valid.has(id))){fail(Error('Collection not found'));return}
        if(patch.name!==undefined&&(!patch.name.trim()||patch.name.trim().length>64)){fail(Error('Invalid project name'));return}
        for(const id of new Set(ids)){const request=tx.objectStore('projectSummaries').get(id);request.onsuccess=()=>{try{if(!request.result)throw Error('Project not found');const row=request.result as ProjectIndex;validate?.(row.summary);row.summary={...row.summary,...patch,...(patch.name?{name:patch.name.trim()}:{}),...(patch.collectionIDs?{collectionIDs:[...new Set(patch.collectionIDs)]}:{})};tx.objectStore('projectSummaries').put(row)}catch(error){fail(error)}}}
        done(undefined)
      }
    })
  }
  async deleteMany(ids:string[]):Promise<void>{return this.transaction('readwrite',(tx,done)=>{
    for(const id of new Set(ids)){
      tx.objectStore('projects').delete(id);tx.objectStore('projectSummaries').delete(id)
      for(const name of ['exportHistory','exportSummaries']){const cursor=tx.objectStore(name).index('projectID').openCursor(IDBKeyRange.only(id));cursor.onsuccess=()=>{const row=cursor.result;if(row){row.delete();row.continue()}}}
    }done(undefined)
  })}
  async updateSummaries(next:ProjectSummary[],baseline:string[]):Promise<void>{return this.transaction('readwrite',(tx,done,fail)=>{
    const req=tx.objectStore('projectSummaries').getAll();req.onsuccess=()=>{try{
      const desired=new Map(next.map(row=>[row.id,row])),base=new Set(baseline)
      for(const record of req.result as ProjectIndex[]){
        if(!base.has(record.id))continue // Never delete a project created in another tab after this UI snapshot.
        const wanted=desired.get(record.id)
        if(wanted){
          if(!wanted.name.trim()||wanted.name.trim().length>64)throw Error('Invalid project name')
          if(wanted.name!==record.summary.name)tx.objectStore('projectSummaries').put({...record,summary:{...record.summary,name:wanted.name.trim(),updatedAt:wanted.updatedAt}})
        }else{
          tx.objectStore('projects').delete(record.id);tx.objectStore('projectSummaries').delete(record.id)
          for(const name of ['exportHistory','exportSummaries']){const cursor=tx.objectStore(name).index('projectID').openCursor(record.id);cursor.onsuccess=()=>{const row=cursor.result;if(row){row.delete();row.continue()}}}
        }
      }done(undefined)
    }catch(error){fail(error)}}
  })}
  async deleteCollection(id:string):Promise<void>{return this.transaction('readwrite',(tx,done)=>{
    tx.objectStore('collections').delete(id);const cursor=tx.objectStore('projectSummaries').openCursor();cursor.onsuccess=()=>{const row=cursor.result;if(!row)return;const value=row.value as ProjectIndex;if(value.summary.collectionIDs?.includes(id)){row.update({...value,summary:{...value.summary,collectionIDs:value.summary.collectionIDs.filter(item=>item!==id)}})}row.continue()};done(undefined)
  })}
  async duplicate(id:string,name:string,limit:number):Promise<StoredProject>{return this.transaction('readwrite',(tx,done,fail)=>{
    const source=tx.objectStore('projects').get(id),meta=tx.objectStore('projectSummaries').get(id),count=tx.objectStore('projects').count();let ready=0
    const copy=()=>{if(++ready!==3)return;try{
      if(!source.result?.source)throw Error('Source audio unavailable')
      if(!Number.isSafeInteger(limit)||count.result>=limit)throw Error('Project limit reached')
      const clean=name.trim();if(!clean||clean.length>64)throw Error('Invalid project name')
      const newID=crypto.randomUUID(),record:StoredProject={...source.result,id:newID,summary:{...(meta.result?.summary??source.result.summary),id:newID,name:clean,updatedAt:new Date().toISOString()}}
      let exportID:string|undefined;if(record.output){exportID=crypto.randomUUID();putExport(tx,exportRecord(record,exportID))}
      tx.objectStore('projects').put(record);tx.objectStore('projectSummaries').put(indexRecord(record,exportID));done(record)
    }catch(error){fail(error)}};source.onsuccess=copy;meta.onsuccess=copy;count.onsuccess=copy
  })}
  async history(projectID:string):Promise<ExportSummary[]>{return this.transaction('readonly',(tx,done)=>{const req=tx.objectStore('exportSummaries').index('projectID').getAll(projectID);req.onsuccess=()=>done((req.result as ExportSummary[]).sort((a,b)=>b.createdAt.localeCompare(a.createdAt)))})}
  async exportMedia(id:string):Promise<StoredMedia|undefined>{return this.transaction('readonly',(tx,done)=>{const req=tx.objectStore('exportHistory').get(id);req.onsuccess=()=>done(req.result?.media)})}
  async deleteExport(id:string):Promise<void>{return this.transaction('readwrite',(tx,done)=>{tx.objectStore('exportHistory').delete(id);tx.objectStore('exportSummaries').delete(id);done(undefined)})}
  async storageBytes():Promise<number>{return this.transaction('readonly',(tx,done)=>{const rows=tx.objectStore('projectSummaries').getAll(),history=tx.objectStore('exportSummaries').getAll();let ready=0;const finish=()=>{if(++ready===2)done((rows.result as ProjectIndex[]).reduce((sum,row)=>sum+row.sourceBytes+row.outputBytes,0)+(history.result as ExportSummary[]).reduce((sum,row)=>sum+row.byteCount,0))};rows.onsuccess=finish;history.onsuccess=finish})}
  // Legacy metadata has no recoverable audio: do not fabricate a source or
  // overwrite a newer IndexedDB record with an old localStorage summary.
  async migrate(summaries: ProjectSummary[]): Promise<void> {
    for (const summary of summaries) {
      if (!await this.get(summary.id)) await this.put({ id: summary.id, summary,
        sourceDuration: summary.trimEnd, source: null,
        effects: { volume: 1, fadeIn: 0, fadeOut: 0, normalize: false } })
    }
  }
}

import { useCallback, useEffect, useRef, useState } from 'react'
import type { EditorState, ProjectSummary, Language } from '../types'
import {canCreateProject,canChangeNormalization,canChangeStudioEffects,AdvancedAudioAccessError,HighPrecisionAccessError,LibraryAccessError,ProjectLimitError,ProFeatureError} from '../lib/proAccess'
import { loadProjects, clearLegacyProjects } from '../lib/storage'
import { ProjectRepository, projectSnapshot, storeMedia } from '../lib/projectRepository'
import {proProjectLimit,freeProjectLimit} from '../lib/proOffering'

export function useProjectLibrary(onError: (error: unknown) => void, access: {hasVerifiedPro:boolean;language:Language} = {hasVerifiedPro:false,language:'tr'}) {
  const [repository] = useState(() => new ProjectRepository())
  const [projects, setProjects] = useState<ProjectSummary[]>([])
  const [loading, setLoading] = useState(true)
  const queue = useRef<Promise<unknown>>(Promise.resolve())
  const errorRef = useRef(onError)
  errorRef.current = onError
  const accessRef=useRef(access)
  accessRef.current=access
  const refresh = useCallback(async () => {
    setProjects(await repository.listSummaries())
  }, [repository])
  const migrateLegacy = useCallback(async () => {
    let legacy: ProjectSummary[] = []
    // Only migrate records that actually existed. Sample metadata must not
    // consume a new user's Normal project capacity.
    try { if(localStorage.getItem('ringify.projects.v1')!==null) legacy = loadProjects() } catch (error) { errorRef.current(error) }
    await repository.migrate(legacy)
    try { clearLegacyProjects() } catch (error) { errorRef.current(error) }
  }, [repository])

  // Serialize edits, rename, export and deletion. Never let a slow older save
  // overwrite a newer selection, or resurrect a project after deletion.
  const enqueue = useCallback(<T,>(operation: () => Promise<T>): Promise<T> => {
    const next = queue.current.then(operation, operation)
    queue.current = next.catch(() => undefined)
    return next
  }, [])

  useEffect(() => {
    let mounted = true
    void enqueue(async () => {
      await migrateLegacy()
      if (mounted) await refresh()
    }).catch((error) => { if (mounted) errorRef.current(error) })
      .finally(() => { if (mounted) setLoading(false) })
    return () => { mounted = false }
  }, [migrateLegacy, enqueue, refresh])

  const save = useCallback((editor: EditorState, output?: Blob, outputName?: string) => enqueue(async () => {
    if (!editor.projectID || !editor.asset.buffer) return
    const previous = await repository.get(editor.projectID)
    // Enforce inside the serialized commit queue, not only against UI counts.
    // Existing records remain editable even when they exceed the new Normal limit.
    if (!canChangeNormalization(previous?.effects.normalize??false,editor.effects.normalize,accessRef.current.hasVerifiedPro)) {
      throw new ProFeatureError(accessRef.current.language)
    }
    const record = projectSnapshot(editor, previous)
    if(!canChangeStudioEffects(previous?.effects??{},editor.effects,accessRef.current.hasVerifiedPro))throw new AdvancedAudioAccessError(accessRef.current.language)
    if (!record.source && editor.asset.sourceBlob) record.source = await storeMedia(editor.asset.sourceBlob)
    if (!record.source) throw new Error('Source audio could not be saved')
    if (output) {
      if(output.size>=44&&!accessRef.current.hasVerifiedPro){
        const header=new DataView(await output.slice(0,44).arrayBuffer())
        if(header.getUint32(0,false)===0x52494646&&header.getUint32(8,false)===0x57415645&&header.getUint16(20,true)===1&&header.getUint16(34,true)===24)throw new HighPrecisionAccessError(accessRef.current.language)
      }
      record.output = await storeMedia(output)
      record.summary.status = 'exported'
      record.summary.name = outputName || record.summary.name
    }
    await repository.putChecked(record,(current,count)=>{
      if(!current&&!canCreateProject(count,accessRef.current.hasVerifiedPro))throw new ProjectLimitError(accessRef.current.language,accessRef.current.hasVerifiedPro)
      if(!canChangeNormalization(current?.effects.normalize??false,record.effects.normalize,accessRef.current.hasVerifiedPro))throw new ProFeatureError(accessRef.current.language)
      if(!canChangeStudioEffects(current?.effects??{},record.effects,accessRef.current.hasVerifiedPro))throw new AdvancedAudioAccessError(accessRef.current.language)
    },!!output&&accessRef.current.hasVerifiedPro)
    await refresh()
  }), [enqueue, repository, refresh])

  const update = useCallback((next:ProjectSummary[])=>{const baseline=projects.map(row=>row.id);return enqueue(async()=>{await repository.updateSummaries(next,baseline);await refresh()})},[enqueue,repository,refresh,projects])
  const patch = useCallback((ids:string[],fields:Pick<Partial<ProjectSummary>,'favorite'|'collectionIDs'>)=>enqueue(async()=>{
    await repository.patchSummaries(ids,fields,current=>{
      if(!accessRef.current.hasVerifiedPro&&((fields.favorite===true&&!current.favorite)||fields.collectionIDs?.some(id=>!current.collectionIDs?.includes(id))))throw new LibraryAccessError(accessRef.current.language)
    });await refresh()
  }),[enqueue,repository,refresh])
  const createCollection=useCallback((name:string)=>enqueue(async()=>{if(!accessRef.current.hasVerifiedPro)throw new LibraryAccessError(accessRef.current.language);return repository.createCollection(name)}),[enqueue,repository])
  const deleteCollection=useCallback((id:string)=>enqueue(async()=>{await repository.deleteCollection(id);await refresh()}),[enqueue,repository,refresh])
  const removeMany = useCallback((ids:string[])=>enqueue(async()=>{await repository.deleteMany(ids);await refresh()}),[enqueue,repository,refresh])
  const duplicate = useCallback((id:string)=>enqueue(async()=>{
    const row=await repository.get(id);if(!row)throw Error('Project not found')
    const count=(await repository.listSummaries()).length
    if(!canCreateProject(count,accessRef.current.hasVerifiedPro))throw new ProjectLimitError(accessRef.current.language,accessRef.current.hasVerifiedPro)
    await repository.duplicate(id,`${row.summary.name.slice(0,52)} ${accessRef.current.language==='tr'?'kopya':'copy'}`,accessRef.current.hasVerifiedPro?proProjectLimit:freeProjectLimit);await refresh()
  }),[enqueue,repository,refresh])

  const clear = useCallback(() => enqueue(async () => {
    await repository.clear()
    clearLegacyProjects()
    setProjects([])
  }), [enqueue, repository])

  const get = useCallback((id: string) => enqueue(() => repository.get(id)), [enqueue, repository])
  const retry = useCallback(() => enqueue(async () => {
    await migrateLegacy()
    await refresh()
  }), [enqueue, migrateLegacy, refresh])
  return { projects, loading, save, update, clear, get, retry,patch,removeMany,duplicate,repository,createCollection,deleteCollection }
}

import {describe,it,expect,vi} from 'vitest'
import {IDBFactory,IDBObjectStore as FakeObjectStore} from 'fake-indexeddb'
import {ProjectRepository,type StoredProject} from './projectRepository'
import type {UserAudioPreset} from './userAudioPresets'

const preset=(id='preset'):UserAudioPreset=>({id,name:'Voice',effects:{volume:.8,fadeIn:.2,fadeOut:.3,normalize:false},createdAt:'2026-11-02T10:00:00Z',updatedAt:'2026-11-02T10:00:00Z'})
const project=():StoredProject=>({id:'one',summary:{id:'one',name:'Source',sourceName:'source.wav',duration:2,trimStart:0,trimEnd:2,updatedAt:'2026-11-02T10:00:00Z',status:'draft'},
  sourceDuration:2,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false},source:{bytes:new Uint8Array([2,4,8]).buffer,type:'audio/wav'}})
describe('persistent personal presets',()=>{
  it('keeps source markers through reopening and creates independent metadata when duplicating',async()=>{
    const factory=new IDBFactory(),repo=new ProjectRepository('marker-reopen',factory),original=project()
    original.markers=[{id:'point',time:1.25,label:'Chorus'}]
    await repo.put(original)
    const reopened=new ProjectRepository('marker-reopen',factory)
    expect((await reopened.get('one'))?.markers).toEqual(original.markers)
    const copy=await reopened.duplicate('one','Copy',3)
    copy.markers![0].label='Copied marker';await reopened.put(copy)
    expect((await reopened.get('one'))?.markers).toEqual(original.markers)
    expect((await reopened.get(copy.id))?.source).toEqual(original.source)
  })
  it('reopens presets, renames without replacing effects and deletes independently of source projects',async()=>{
    const factory=new IDBFactory(),repo=new ProjectRepository('preset-crud',factory),original=project()
    await repo.put(original);await repo.saveAudioPreset(preset())
    const reopened=new ProjectRepository('preset-crud',factory)
    expect(await reopened.listAudioPresets()).toEqual([preset()])
    await reopened.saveAudioPreset({...preset(),name:'Renamed'})
    expect((await reopened.listAudioPresets())[0]).toEqual({...preset(),name:'Renamed'})
    await reopened.deleteAudioPreset('preset')
    expect(await reopened.listAudioPresets()).toEqual([])
    expect(await reopened.get('one')).toEqual(original)
  })
  it('does not overwrite committed settings after quota errors or duplicate names',async()=>{
    const repo=new ProjectRepository('preset-errors',new IDBFactory())
    await repo.saveAudioPreset(preset())
    await expect(repo.saveAudioPreset({...preset('other'),name:'voice'})).rejects.toThrow()
    const spy=vi.spyOn(FakeObjectStore.prototype,'put').mockImplementationOnce(()=>{throw new DOMException('Quota exceeded','QuotaExceededError')})
    await expect(repo.saveAudioPreset({...preset(),name:'Changed'})).rejects.toThrow('Quota exceeded')
    spy.mockRestore()
    expect(await repo.listAudioPresets()).toEqual([preset()])
  })
  it('clears personal metadata with the existing atomic full reset',async()=>{
    const repo=new ProjectRepository('preset-reset',new IDBFactory())
    await repo.put(project());await repo.saveAudioPreset(preset())
    await repo.clear()
    expect(await repo.listAudioPresets()).toEqual([])
    expect(await repo.list()).toEqual([])
  })
  it('serializes concurrent saves at the capacity boundary without evicting existing presets',async()=>{
    const repo=new ProjectRepository('preset-capacity',new IDBFactory())
    for(let i=0;i<63;i++)await repo.saveAudioPreset({...preset(String(i)),name:`Voice ${i}`})
    const results=await Promise.allSettled([repo.saveAudioPreset({...preset('last-a'),name:'Last A'}),repo.saveAudioPreset({...preset('last-b'),name:'Last B'})])
    expect(results.filter(result=>result.status==='fulfilled')).toHaveLength(1)
    const stored=await repo.listAudioPresets()
    expect(stored).toHaveLength(64)
    expect(stored.find(item=>item.id==='0')).toEqual({...preset('0'),name:'Voice 0'})
  })
  it('upgrades v2 without rewriting source rows, summaries or existing export IDs',async()=>{
    const factory=new IDBFactory(),original=project(),media={bytes:new Uint8Array([9,7,5]).buffer,type:'audio/wav'}
    await new Promise<void>((resolve,reject)=>{
      const request=factory.open('preset-migration',2)
      request.onupgradeneeded=()=>{
        for(const name of ['projects','projectSummaries','collections','exportHistory','exportSummaries']){
          const store=request.result.createObjectStore(name,{keyPath:'id'})
          if(name.startsWith('export'))store.createIndex('projectID','projectID')
        }
        const tx=request.transaction!,summary={id:'existing-export',projectID:'one',name:'Old',createdAt:'2026-10-01T10:00:00Z',byteCount:3,verified:true}
        tx.objectStore('projects').put(original)
        tx.objectStore('projectSummaries').put({id:'one',summary:original.summary,sourceBytes:3,outputBytes:0})
        tx.objectStore('exportHistory').put({...summary,media});tx.objectStore('exportSummaries').put(summary)
      }
      request.onsuccess=()=>{request.result.close();resolve()};request.onerror=()=>reject(request.error)
    })
    const repo=new ProjectRepository('preset-migration',factory)
    await repo.saveAudioPreset(preset())
    expect(await repo.get('one')).toEqual(original)
    expect((await repo.history('one')).map(row=>row.id)).toEqual(['existing-export'])
    expect(await repo.exportMedia('existing-export')).toEqual(media)
  })
})

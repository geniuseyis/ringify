import {IDBFactory,IDBObjectStore} from 'fake-indexeddb'
import {afterEach,describe,it,expect,vi} from 'vitest'
import {ProjectRepository,type StoredProject} from './projectRepository'

function project(id='one'):StoredProject{return{id,summary:{id,name:id,sourceName:'original.wav',trimStart:1,trimEnd:3,duration:2,status:'exported',updatedAt:'2026-11-01T10:00:00Z'},sourceDuration:4,effects:{volume:.7,fadeIn:.2,fadeOut:.3,normalize:true},source:{bytes:new Uint8Array([1,3,5,7]).buffer,type:'audio/wav'},output:{bytes:new Uint8Array([9,8,7]).buffer,type:'audio/wav'}}}
async function legacy(factory:IDBFactory,name:string,records:StoredProject[]){await new Promise<void>((resolve,reject)=>{const open=factory.open(name,1);open.onupgradeneeded=()=>open.result.createObjectStore('projects',{keyPath:'id'});open.onerror=()=>reject(open.error);open.onsuccess=()=>{const db=open.result,tx=db.transaction('projects','readwrite');records.forEach(row=>tx.objectStore('projects').put(row));tx.oncomplete=()=>{db.close();resolve()}}})}
afterEach(()=>vi.restoreAllMocks())
describe('schema 2 media integrity and organization',()=>{
  it('upgrades actual schema 1 data without changing source, effects or output',async()=>{
    const factory=new IDBFactory(),original=project();await legacy(factory,'upgrade',[original])
    const repo=new ProjectRepository('upgrade',factory)
    expect(await repo.get('one')).toEqual(original)
    expect(await repo.listSummaries()).toEqual([original.summary])
    const history=await repo.history('one');expect(history).toHaveLength(1);expect(history[0]).toMatchObject({id:'legacy:one',verified:false,byteCount:3})
    expect(await repo.exportMedia(history[0].id)).toEqual(original.output)
    expect(await repo.storageBytes()).toBe(10)
  })
  it('aborts failed upgrade and preserves schema 1 original media for retry',async()=>{
    const factory=new IDBFactory();await legacy(factory,'retry',[project()])
    const originalPut=IDBObjectStore.prototype.put,put=vi.spyOn(IDBObjectStore.prototype,'put')
    put.mockImplementation(function(this:IDBObjectStore,...args:Parameters<IDBObjectStore['put']>){if(this.name==='projectSummaries')throw Error('disk full');return originalPut.apply(this,args)})
    await expect(new ProjectRepository('retry',factory).listSummaries()).rejects.toThrow()
    put.mockRestore()
    expect(await new ProjectRepository('retry',factory).get('one')).toEqual(project())
  })
  it('lists and patches metadata without loading or rewriting all media',async()=>{
    const repo=new ProjectRepository('metadata',new IDBFactory());await repo.put(project())
    const all=vi.spyOn(IDBObjectStore.prototype,'getAll'),put=vi.spyOn(IDBObjectStore.prototype,'put')
    await repo.listSummaries();await repo.patchSummaries(['one'],{favorite:true,name:'New'})
    expect(all.mock.contexts.every(store=>(store as IDBObjectStore).name!=='projects')).toBe(true)
    expect(put.mock.contexts.every(store=>(store as IDBObjectStore).name!=='projects')).toBe(true)
    all.mockRestore();put.mockRestore()
    expect(await repo.get('one')).toEqual({...project(),summary:{...project().summary,favorite:true,name:'New'}})
  })
  it('rolls back the entire batch if any target fails validation',async()=>{
    const repo=new ProjectRepository('batch',new IDBFactory());await repo.put(project('a'));await repo.put(project('b'))
    await expect(repo.patchSummaries(['a','b'],{favorite:true},row=>{if(row.id==='b')throw Error('denied')})).rejects.toThrow('denied')
    expect((await repo.listSummaries()).every(row=>row.favorite===undefined)).toBe(true)
    await expect(repo.patchSummaries(['a','missing'],{name:'Changed'})).rejects.toThrow()
    expect((await repo.get('a'))?.summary.name).toBe('a')
  })
  it('rejects invalid collection references and unlinks deleted collections without removing projects',async()=>{
    const repo=new ProjectRepository('collection',new IDBFactory());await repo.put(project());const col=await repo.createCollection('  Sesler  ')
    await expect(repo.createCollection('sesler')).rejects.toThrow()
    await expect(repo.patchSummaries(['one'],{collectionIDs:['missing']})).rejects.toThrow()
    await repo.patchSummaries(['one'],{collectionIDs:[col.id,col.id],favorite:true})
    expect((await repo.get('one'))?.summary.collectionIDs).toEqual([col.id])
    await repo.put(project());expect((await repo.get('one'))?.summary.favorite).toBe(true)
    await repo.deleteCollection(col.id)
    expect(await repo.collections()).toEqual([]);expect((await repo.get('one'))?.summary.collectionIDs).toEqual([])
    expect((await repo.get('one'))?.source).toEqual(project().source)
  })
  it('serializes quota checks across independent repository instances',async()=>{
    const factory=new IDBFactory(),a=new ProjectRepository('concurrent',factory),b=new ProjectRepository('concurrent',factory)
    const check=(_current:StoredProject|undefined,count:number)=>{if(count>=1)throw Error('quota')}
    const result=await Promise.allSettled([a.putChecked(project('a'),check,false),b.putChecked(project('b'),check,false)])
    expect(result.filter(item=>item.status==='fulfilled')).toHaveLength(1)
    expect(await a.listSummaries()).toHaveLength(1)
  })
  it('duplicates actual source, settings and output; deleting original cannot damage the copy',async()=>{
    const repo=new ProjectRepository('copy',new IDBFactory());await repo.put(project())
    const copy=await repo.duplicate('one','Copy',3);expect(copy.id).not.toBe('one');expect(copy.source).toEqual(project().source);expect(copy.effects).toEqual(project().effects)
    await repo.delete('one');expect(await repo.history('one')).toEqual([]);expect(await repo.get(copy.id)).toEqual(copy);expect(await repo.history(copy.id)).toHaveLength(1)
    await expect(repo.duplicate(copy.id,'Other',1)).rejects.toThrow('limit')
  })
  it('deletes archived output without touching current output; clear removes every store',async()=>{
    const repo=new ProjectRepository('history',new IDBFactory());await repo.put(project());await repo.putChecked(project(),()=>{},true)
    expect(await repo.history('one')).toHaveLength(2)
    const row=(await repo.history('one'))[0];await repo.deleteExport(row.id)
    expect(await repo.exportMedia(row.id)).toBeUndefined();expect((await repo.get('one'))?.output).toEqual(project().output)
    await repo.put(project());expect(await repo.history('one')).toHaveLength(1)
    await repo.createCollection('Keep');await repo.clear()
    expect(await repo.storageBytes()).toBe(0);expect(await repo.collections()).toEqual([]);expect(await repo.history('one')).toEqual([])
  })
  it('does not erase new projects created after a stale UI list was captured',async()=>{
    const repo=new ProjectRepository('stale',new IDBFactory());await repo.put(project('a'));await repo.put(project('b'))
    await repo.updateSummaries([],['a'])
    expect(await repo.get('a')).toBeUndefined();expect(await repo.get('b')).toEqual(project('b'))
  })
})

import {act,cleanup,fireEvent,render,renderHook,screen,waitFor,within} from '@testing-library/react'
import {IDBFactory} from 'fake-indexeddb'
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest'
import App from './App'
import type {EditorState} from './types'
import {ProjectRepository,type StoredProject} from './lib/projectRepository'
import {useProjectLibrary} from './hooks/useProjectLibrary'
import {ProjectLimitError,ProFeatureError} from './lib/proAccess'
import {audioFixture,FakeAudioContext} from './test/audioFixtures'

const mocks=vi.hoisted(()=>({decode:vi.fn(),demo:vi.fn()}))
vi.mock('./lib/audio',async original=>({...await original<typeof import('./lib/audio')>(),
  decodeAudioFile:(blob:Blob)=>mocks.decode(blob),createDemoBuffer:()=>mocks.demo(),getAudioContext:()=>new FakeAudioContext()}))
beforeEach(()=>{
  vi.stubGlobal('indexedDB',new IDBFactory())
  localStorage.clear()
  localStorage.setItem('ringify.projects.migrated.v2','true')
  // A historical preference must never authorize paid features.
  localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'light',language:'tr',onboardingSeen:true,isProDemo:true}))
  mocks.decode.mockReset();mocks.demo.mockReset()
  mocks.decode.mockResolvedValue({buffer:audioFixture([Array<number>(400).fill(.3)]),duration:4,peaks:[.3,.3]})
})
afterEach(()=>{cleanup();vi.unstubAllGlobals()})
function record(id:string,normalize=false):StoredProject{
  return {id,summary:{id,name:`Stored ${id}`,sourceName:'voice.wav',duration:2,trimStart:1,trimEnd:3,updatedAt:'2026-11-01T00:00:00Z',status:'draft'},sourceDuration:4,
    source:{bytes:new Uint8Array([10,20,30]).buffer,type:'audio/wav'},effects:{volume:.6,fadeIn:.2,fadeOut:.3,normalize}}
}
function editor(id:string,normalize=false):EditorState{
  return {projectID:id,projectName:`Stored ${id}`,asset:{fileName:'voice.wav',buffer:audioFixture([Array<number>(400).fill(.3)]),duration:4,peaks:[.3,.3],sourceBlob:new Blob([new Uint8Array([10,20,30])],{type:'audio/wav'}),isDemo:false},trimStart:1,trimEnd:3,effects:{volume:.6,fadeIn:.2,fadeOut:.3,normalize}}
}
async function readyHook(pro=false){
  const view=renderHook(({verified})=>useProjectLibrary(vi.fn(),{hasVerifiedPro:verified,language:'tr'}),{initialProps:{verified:pro}})
  await waitFor(()=>expect(view.result.current.loading).toBe(false))
  return view
}
describe('Normal/Pro safe persistence boundaries',()=>{
  it('starts a fresh library without synthetic legacy records consuming Normal capacity',async()=>{
    localStorage.removeItem('ringify.projects.migrated.v2')
    const {result}=await readyHook()
    expect(result.current.projects).toHaveLength(0)
    await act(async()=>{await result.current.save(editor('a'))})
    expect(await new ProjectRepository().list()).toHaveLength(1)
  })
  it('serializes concurrent new saves and commits only one Normal project',async()=>{
    const {result}=await readyHook()
    let outcomes:PromiseSettledResult<void>[]=[]
    await act(async()=>{outcomes=await Promise.allSettled(['a','b','c','d'].map(id=>result.current.save(editor(id))))})
    expect(outcomes.filter(x=>x.status==='fulfilled')).toHaveLength(1)
    const rejected=outcomes.filter((x):x is PromiseRejectedResult=>x.status==='rejected')
    expect(rejected).toHaveLength(3)
    expect(rejected.every(x=>x.reason instanceof ProjectLimitError)).toBe(true)
    const records=await new ProjectRepository().list()
    expect(records).toHaveLength(1)
    expect(records.every(r=>new Uint8Array(r.source!.bytes).join(',')==='10,20,30')).toBe(true)
  })
  it('keeps and edits all existing over-limit projects without deleting source media',async()=>{
    const repository=new ProjectRepository()
    for(const id of ['a','b','c','d','e'])await repository.put(record(id))
    const {result,rerender}=await readyHook()
    await act(async()=>{await result.current.save({...editor('e'),projectName:'Edited existing'})})
    await expect(result.current.save(editor('f'))).rejects.toBeInstanceOf(ProjectLimitError)
    const records=await repository.list()
    expect(records).toHaveLength(5)
    expect((await repository.get('e'))?.summary.name).toBe('Edited existing')
    expect(records.every(r=>r.source!.bytes.byteLength===3)).toBe(true)
    rerender({verified:true})
    await act(async()=>{await result.current.save({...editor('a'),projectName:'Pro edited existing'})})
    await expect(result.current.save(editor('f'))).rejects.toBeInstanceOf(ProjectLimitError)
    expect((await repository.get('a'))?.summary.name).toBe('Pro edited existing')
    expect(await repository.list()).toHaveLength(5)
  })
  it('denies new normalization without verified access and allows only the three-project Pro capacity',async()=>{
    const {result,rerender}=await readyHook()
    await expect(result.current.save(editor('a',true))).rejects.toBeInstanceOf(ProFeatureError)
    expect(await new ProjectRepository().list()).toHaveLength(0)
    rerender({verified:true})
    await act(async()=>{for(const id of ['a','b','c'])await result.current.save(editor(id,true))})
    await expect(result.current.save(editor('d',true))).rejects.toBeInstanceOf(ProjectLimitError)
    expect(await new ProjectRepository().list()).toHaveLength(3)
  })
  it('serializes verified Pro saves at three and never grants capacity beyond the base entitlement',async()=>{
    const {result}=await readyHook(true)
    let outcomes:PromiseSettledResult<void>[]=[]
    await act(async()=>{outcomes=await Promise.allSettled(['a','b','c','d','e'].map(id=>result.current.save(editor(id))))})
    expect(outcomes.filter(x=>x.status==='fulfilled')).toHaveLength(3)
    const rejected=outcomes.filter((x):x is PromiseRejectedResult=>x.status==='rejected')
    expect(rejected).toHaveLength(2)
    expect(rejected.every(x=>x.reason instanceof ProjectLimitError)).toBe(true)
    expect(rejected.every(x=>x.reason.message.includes('3 proje sınırına ulaştın'))).toBe(true)
    const records=await new ProjectRepository().list()
    expect(records).toHaveLength(3)
    expect(records.every(r=>new Uint8Array(r.source!.bytes).join(',')==='10,20,30')).toBe(true)
  })
  it('preserves an existing normalized edit, permits disabling it and rejects enabling it again',async()=>{
    const repository=new ProjectRepository()
    await repository.put(record('legacy',true))
    const {result}=await readyHook()
    await act(async()=>{await result.current.save(editor('legacy',true))})
    expect((await repository.get('legacy'))?.effects.normalize).toBe(true)
    await act(async()=>{await result.current.save(editor('legacy',false))})
    await expect(result.current.save(editor('legacy',true))).rejects.toBeInstanceOf(ProFeatureError)
    expect((await repository.get('legacy'))?.effects.normalize).toBe(false)
    expect(new Uint8Array((await repository.get('legacy'))!.source!.bytes)).toEqual(new Uint8Array([10,20,30]))
  })
  it('blocks a second import before audio allocation despite a legacy local Pro flag',async()=>{
    const repository=new ProjectRepository()
    await repository.put(record('a'))
    render(<App />)
    await screen.findByRole('heading',{name:'Sesini imzana dönüştür.'})
    fireEvent.click(screen.getByRole('button',{name:'Yeni Zil Sesi Oluştur Video, ses veya mikrofon'}))
    fireEvent.click(screen.getByRole('button',{name:'Telif içermeyen demo sesi kullan'}))
    expect(await screen.findByText('Proje sınırına ulaştın')).toBeInTheDocument()
    expect(mocks.demo).not.toHaveBeenCalled()
    expect(mocks.decode).not.toHaveBeenCalled()
    expect(await repository.list()).toHaveLength(1)
    fireEvent.click(screen.getByRole('button',{name:'Pro planlarını gör'}))
    expect(screen.getByRole('heading',{name:'Ringify Pro'})).toBeInTheDocument()
    expect(screen.getAllByRole('radio')).toHaveLength(4)
  })
  it('reopens and exports an over-limit legacy normalized project using its actual stored parameters',async()=>{
    const repository=new ProjectRepository()
    for(const id of ['a','b','c','legacy'])await repository.put(record(id,id==='legacy'))
    render(<App />)
    await screen.findByRole('heading',{name:'Sesini imzana dönüştür.'})
    fireEvent.click(within(screen.getByRole('navigation')).getByRole('button',{name:'Kütüphane'}))
    fireEvent.click((await screen.findByText('Stored legacy')).closest('button')!)
    fireEvent.click(await screen.findByRole('button',{name:'Efektlere Devam Et'}))
    expect(screen.getByRole('switch',{name:'Ses seviyesini dengele'})).toHaveAttribute('aria-checked','true')
    fireEvent.click(screen.getByRole('button',{name:'Ön İzle'}))
    fireEvent.click(screen.getByRole('button',{name:'Dışa Aktar'}))
    fireEvent.click(screen.getByRole('button',{name:'WAV Olarak Oluştur'}))
    expect(await screen.findByText('Zil sesin hazır.')).toBeInTheDocument()
    const saved=await repository.get('legacy')
    expect(saved?.effects.normalize).toBe(true)
    expect(saved?.output!.bytes.byteLength).toBeGreaterThan(44)
    expect(new Uint8Array(saved!.source!.bytes)).toEqual(new Uint8Array([10,20,30]))
    expect(await repository.list()).toHaveLength(4)
  })
})
vi.mock('./lib/selectionExport',async()=>({renderSelectionExport:(await import('./test/selectionExportFixture')).selectionExportFixture}))

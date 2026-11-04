import {act,cleanup,fireEvent,render,screen,waitFor,within} from '@testing-library/react'
import {IDBFactory} from 'fake-indexeddb'
import {afterEach,beforeEach,expect,it,vi} from 'vitest'
import {ProjectRepository} from './lib/projectRepository'
import {audioFixture,FakeAudioContext} from './test/audioFixtures'
import App from './App'
const decode=vi.hoisted(()=>vi.fn())
vi.mock('./lib/audio',async original=>({...await original<typeof import('./lib/audio')>(),decodeAudioFile:(blob:Blob,signal:AbortSignal)=>decode(blob,signal),getAudioContext:()=>new FakeAudioContext()}))
beforeEach(()=>{vi.stubGlobal('indexedDB',new IDBFactory());decode.mockReset();localStorage.clear();localStorage.setItem('ringify.projects.migrated.v2','true');localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'light',language:'tr',onboardingSeen:true}))})
afterEach(()=>{cleanup();vi.unstubAllGlobals()})
const decoded=()=>({buffer:audioFixture([new Array(400).fill(.3)]),duration:4,peaks:[.3]})
async function home(){await screen.findByRole('heading',{name:'Sesini imzana dönüştür.'})}
it('does not save or navigate when an import decoder replies after leaving the screen',async()=>{
  let finish!:(value:ReturnType<typeof decoded>)=>void
  decode.mockImplementation(()=>new Promise(resolve=>{finish=resolve}))
  const {container}=render(<App/>);await home();fireEvent.click(screen.getByRole('button',{name:'Yeni Zil Sesi Oluştur Video, ses veya mikrofon'}))
  fireEvent.change(container.querySelector('input[type="file"][accept^="audio"]')!,{target:{files:[new File(['wav'],'source.wav')]}})
  await waitFor(()=>expect(decode).toHaveBeenCalledOnce());const signal=decode.mock.calls[0][1] as AbortSignal
  fireEvent.click(screen.getByRole('button',{name:'Geri'}));expect(signal.aborted).toBe(true)
  await act(async()=>{finish(decoded())});await home()
  expect(await new ProjectRepository().listSummaries()).toEqual([])
  expect(screen.queryByRole('heading',{name:'Ses Stüdyosu'})).not.toBeInTheDocument()
})
it('discards an older project decode when a different project is opened',async()=>{
  const repo=new ProjectRepository()
  for(const id of ['Alpha','Beta'])await repo.put({id,summary:{id,name:id,sourceName:id+'.wav',duration:2,trimStart:1,trimEnd:3,status:'draft',updatedAt:'2026-11-01'},sourceDuration:4,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false},source:{bytes:new Uint8Array([id==='Alpha'?1:2]).buffer,type:'audio/wav'}})
  let finish!:(value:ReturnType<typeof decoded>)=>void
  decode.mockImplementationOnce(()=>new Promise(resolve=>{finish=resolve})).mockResolvedValueOnce(decoded())
  render(<App/>);await home();fireEvent.click(within(screen.getByRole('navigation')).getByRole('button',{name:'Kütüphane'}))
  fireEvent.click((await screen.findByText('Alpha')).closest('button')!);await waitFor(()=>expect(decode).toHaveBeenCalledOnce())
  const oldSignal=decode.mock.calls[0][1] as AbortSignal
  fireEvent.click(screen.getByText('Beta').closest('button')!);await screen.findByRole('heading',{name:'Ses Stüdyosu'});expect(oldSignal.aborted).toBe(true)
  await act(async()=>{finish(decoded())});expect(screen.getByText('Beta.wav')).toBeInTheDocument();expect(screen.queryByText('Alpha.wav')).not.toBeInTheDocument()
  expect(await repo.listSummaries()).toHaveLength(2)
})

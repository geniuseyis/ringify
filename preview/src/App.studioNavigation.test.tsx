import {cleanup,fireEvent,render,screen,waitFor,within} from '@testing-library/react'
import {IDBFactory} from 'fake-indexeddb'
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest'
import App from './App'
import {ProjectRepository,type StoredProject} from './lib/projectRepository'
import {audioFixture,FakeAudioContext} from './test/audioFixtures'

// Real App/IndexedDB routing and persistence; only codec decoding and Web Audio
// hardware are controlled here. Real audio playback/export is browser-tested.
const decode=vi.hoisted(()=>vi.fn())
vi.mock('./lib/audio',async original=>({...await original<typeof import('./lib/audio')>(),
  decodeAudioFile:(blob:Blob)=>decode(blob),getAudioContext:()=>new FakeAudioContext()}))

beforeEach(()=>{
  vi.stubGlobal('indexedDB',new IDBFactory())
  localStorage.clear()
  localStorage.setItem('ringify.projects.migrated.v2','true')
  localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'light',language:'tr',onboardingSeen:true,isProDemo:false}))
  decode.mockReset().mockImplementation(async(blob:Blob)=>{
    expect(new Uint8Array(await blob.arrayBuffer())).toEqual(new Uint8Array([10,20,30]))
    return {buffer:audioFixture([Array<number>(400).fill(.3)]),duration:4,peaks:[.2,.3,.4,.3]}
  })
})
afterEach(()=>{cleanup();vi.unstubAllGlobals()})

async function home(language:'tr'|'en'='tr'){await screen.findByRole('heading',{name:language==='tr'?'Sesini imzana dönüştür.':'Turn sound into your signature.'})}
const tab=(name:string)=>within(screen.getByRole('navigation')).getByRole('button',{name})
function retainedProject():StoredProject{
  return {id:'retained-studio',summary:{id:'retained-studio',name:'Retained tone',sourceName:'voice.wav',duration:2,trimStart:1,trimEnd:3,updatedAt:'2026-11-01T00:00:00.000Z',status:'draft'},sourceDuration:4,
    source:{bytes:new Uint8Array([10,20,30]).buffer,type:'audio/wav'},effects:{volume:.6,fadeIn:.2,fadeOut:.3,normalize:true}}
}

describe('Ringify 3.0 studio navigation and source integrity',()=>{
  it('returns Preview back to Effects while the explicit re-edit action opens Studio',async()=>{
    const repository=new ProjectRepository(),source=retainedProject();await repository.put(source)
    render(<App/>);await home();fireEvent.click(tab('Kütüphane'))
    fireEvent.click((await screen.findByText(source.summary.name)).closest('button')!)
    await screen.findByRole('heading',{name:'Ses Stüdyosu'})
    fireEvent.click(screen.getByRole('button',{name:'Efektlere Devam Et'}));fireEvent.click(screen.getByRole('button',{name:'Ön İzle'}))
    fireEvent.click(screen.getByRole('button',{name:'Geri'}));expect(screen.getByRole('heading',{name:'Sesi iyileştir'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Ön İzle'}));fireEvent.click(screen.getByRole('button',{name:'Yeniden Düzenle'}))
    expect(screen.getByRole('heading',{name:'Ses Stüdyosu'})).toBeInTheDocument()
    expect((await repository.get(source.id))?.effects).toEqual(source.effects)
  })
  it('exposes four real primary tabs and makes Pro a contextual flow instead of a fifth tab',async()=>{
    render(<App />)
    await home()
    const navigation=screen.getByRole('navigation')
    expect(within(navigation).getAllByRole('button').map(button=>button.textContent)).toEqual(['Ana Sayfa','Stüdyo','Kütüphane','Ayarlar'])
    expect(tab('Ana Sayfa')).toHaveAttribute('aria-current','page')
    expect(within(navigation).queryByRole('button',{name:'Pro'})).not.toBeInTheDocument()
    expect(screen.queryByRole('button',{name:'Ringify Pro'})).not.toBeInTheDocument()
    fireEvent.click(tab('Ayarlar'))
    fireEvent.click(screen.getByRole('button',{name:'Ringify Pro'}))
    expect(screen.getByRole('heading',{name:'Ringify Pro'})).toBeInTheDocument()
    expect(screen.getAllByRole('radio')).toHaveLength(4)
    fireEvent.click(screen.getByRole('button',{name:'Geri'}))
    expect(screen.getByRole('heading',{name:'Ayarlar'})).toBeInTheDocument()
    fireEvent.click(tab('Ana Sayfa'))
    expect(screen.getByRole('heading',{name:'Sesini imzana dönüştür.'})).toBeInTheDocument()
    expect(decode).not.toHaveBeenCalled()
    expect(await new ProjectRepository().list()).toEqual([])
  })

  it('opens an honest empty Studio without invented media or interactive fake waveform',async()=>{
    const {container}=render(<App />)
    await home()
    fireEvent.click(tab('Stüdyo'))
    expect(screen.getByRole('heading',{name:'Ses Stüdyosu'})).toBeInTheDocument()
    expect(screen.getByRole('heading',{name:'Stüdyon hazır'})).toBeInTheDocument()
    expect(tab('Stüdyo')).toHaveAttribute('aria-current','page')
    expect(screen.queryByTestId('waveform-track')).not.toBeInTheDocument()
    expect(screen.queryByRole('slider')).not.toBeInTheDocument()
    expect(container.querySelector('.waveform-bars')).toBeNull()
    expect(screen.queryByRole('button',{name:'Oynat'})).not.toBeInTheDocument()
    expect(decode).not.toHaveBeenCalled()
    expect(await new ProjectRepository().list()).toEqual([])
  })

  it('connects empty Studio import/library actions to the existing routes and returns to its context',async()=>{
    render(<App />)
    await home()
    fireEvent.click(tab('Stüdyo'))
    fireEvent.click(screen.getByRole('button',{name:'Ses ekle'}))
    expect(screen.getByRole('heading',{name:'Kaynak seç'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Geri'}))
    expect(screen.getByRole('heading',{name:'Stüdyon hazır'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Kütüphaneyi aç'}))
    expect(screen.getByRole('heading',{name:'Kütüphane'})).toBeInTheDocument()
    fireEvent.click(tab('Stüdyo'))
    expect(screen.getByRole('heading',{name:'Stüdyon hazır'})).toBeInTheDocument()
    expect(decode).not.toHaveBeenCalled()
  })

  it('retains actual project identity, source, trim and grandfathered effects across Home/Studio tabs',async()=>{
    const repository=new ProjectRepository(),original=retainedProject()
    await repository.put(original)
    render(<App />)
    await home()
    const recent=screen.getByRole('region',{name:'Son projeler'})
    fireEvent.click((await within(recent).findByText(original.summary.name)).closest('button')!)
    await screen.findByRole('heading',{name:'Ses Stüdyosu'})
    expect(tab('Stüdyo')).toHaveAttribute('aria-current','page')
    expect(screen.getByRole('slider',{name:'Kesim başlangıcı'})).toHaveAttribute('aria-valuenow','1')
    fireEvent.keyDown(screen.getByRole('slider',{name:'Kesim başlangıcı'}),{key:'ArrowRight'})
    await waitFor(async()=>expect((await repository.get(original.id))!.summary.trimStart).toBeCloseTo(1.1))
    fireEvent.click(tab('Ana Sayfa'))
    fireEvent.click(tab('Stüdyo'))
    expect(screen.getByRole('heading',{name:'Ses Stüdyosu'})).toBeInTheDocument()
    expect(screen.getByRole('slider',{name:'Kesim başlangıcı'})).toHaveAttribute('aria-valuenow','1.1')
    expect(decode).toHaveBeenCalledOnce()
    const restored=(await repository.get(original.id))!
    expect(restored.id).toBe(original.id)
    expect(restored.effects).toEqual(original.effects)
    expect(new Uint8Array(restored.source!.bytes)).toEqual(new Uint8Array(original.source!.bytes))
    expect(await repository.list()).toHaveLength(1)
  })

  it('uses consistent minimal preview chrome across Home, Studio and Import',async()=>{
    const {container}=render(<App />)
    await home()
    expect(container.querySelector('.status-bar,.dynamic-island,.home-indicator')).toBeNull()
    fireEvent.click(tab('Stüdyo'))
    expect(container.querySelector('.status-bar,.dynamic-island,.home-indicator')).toBeNull()
    fireEvent.click(screen.getByRole('button',{name:'Ses ekle'}))
    expect(container.querySelector('.status-bar,.dynamic-island,.home-indicator')).toBeNull()
  })

  it('localizes Studio empty navigation without fabricating source data',async()=>{
    localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'light',language:'en',onboardingSeen:true}))
    render(<App />)
    await home('en')
    expect(screen.getByRole('navigation',{name:'Main navigation'})).toBeInTheDocument()
    fireEvent.click(tab('Studio'))
    expect(screen.getByRole('heading',{name:'Audio Studio'})).toBeInTheDocument()
    expect(screen.getByRole('heading',{name:'Your studio is ready'})).toBeInTheDocument()
    expect(screen.getByRole('button',{name:'Add audio'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Open library'}))
    expect(screen.getByRole('heading',{name:'Library'})).toBeInTheDocument()
    expect(decode).not.toHaveBeenCalled()
  })
})

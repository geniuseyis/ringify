import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { IDBFactory } from 'fake-indexeddb'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ProjectRepository } from './lib/projectRepository'
import { audioFixture, FakeAudioContext } from './test/audioFixtures'
import App from './App'

const decode = vi.hoisted(() => vi.fn())
vi.mock('./lib/audio', async (original) => ({...await original<typeof import('./lib/audio')>(),
  decodeAudioFile:(blob:Blob) => decode(blob), getAudioContext:() => new FakeAudioContext()}))
beforeEach(() => {
  decode.mockClear()
  vi.stubGlobal('indexedDB',new IDBFactory())
  localStorage.clear()
  localStorage.setItem('ringify.projects.migrated.v2','true')
  localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'light',language:'tr',onboardingSeen:true}))
  decode.mockImplementation(async (blob:Blob) => {
    expect(new Uint8Array(await blob.arrayBuffer())).toEqual(new Uint8Array([10,20,30]))
    return {buffer:audioFixture([Array<number>(400).fill(0.3)]),duration:4,peaks:[0.3,0.3]}
  })
})
afterEach(() => {cleanup(); vi.unstubAllGlobals()})

async function openFromLibrary() {
  await screen.findByRole('heading',{name:'Sesini imzana dönüştür.'})
  fireEvent.click(within(screen.getByRole('navigation')).getByRole('button',{name:'Kütüphane'}))
  fireEvent.click((await screen.findByText('Persisted tone')).closest('button')!)
  expect(await screen.findByRole('heading',{name:'Ses Stüdyosu'})).toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Efektlere Devam Et'}))
  expect(await screen.findByRole('heading',{name:'Sesi iyileştir'})).toBeInTheDocument()
}
describe('durable project reopening through the application', () => {
  it('commits original file bytes and a draft before opening the editor', async () => {
    const {container} = render(<App />)
    await screen.findByRole('heading',{name:'Sesini imzana dönüştür.'})
    fireEvent.click(screen.getByRole('button',{name:'Yeni Zil Sesi Oluştur Video, ses veya mikrofon'}))
    const file = new File([new Uint8Array([10,20,30])],'voice.wav',{type:'audio/wav'})
    fireEvent.change(container.querySelector('input[type="file"][accept^="audio"]')!,{target:{files:[file]}})
    await screen.findByRole('heading',{name:'Ses Stüdyosu'})
    const records = await new ProjectRepository().list()
    expect(records).toHaveLength(1)
    expect(records[0].summary.status).toBe('draft')
    expect(new Uint8Array(records[0].source!.bytes)).toEqual(new Uint8Array([10,20,30]))
    expect(decode).toHaveBeenCalledWith(file)
  })
  it('restores real source bytes and effects, saves an edit and restores it after remount', async () => {
    const repository = new ProjectRepository()
    await repository.put({id:'persisted',summary:{id:'persisted',name:'Persisted tone',sourceName:'voice.wav',
      duration:2,trimStart:1,trimEnd:3,updatedAt:new Date().toISOString(),status:'draft'},sourceDuration:4,
      effects:{volume:0.6,fadeIn:0.3,fadeOut:0.4,normalize:true},source:{bytes:new Uint8Array([10,20,30]).buffer,type:'audio/wav'}})
    const first = render(<App />)
    await openFromLibrary()
    expect(screen.getByLabelText(/Ses Seviyesi/)).toHaveValue('0.6')
    expect(screen.getByLabelText(/Fade-in/)).toHaveValue('0.3')
    fireEvent.change(screen.getByLabelText(/Ses Seviyesi/),{target:{value:'0.75'}})
    await waitFor(async () => expect((await repository.get('persisted'))!.effects.volume).toBe(0.75))
    first.unmount()
    await act(async () => {render(<App />)})
    await openFromLibrary()
    expect(screen.getByLabelText(/Ses Seviyesi/)).toHaveValue('0.75')
    expect(decode).toHaveBeenCalledTimes(2)
    expect((await repository.get('persisted'))!.source!.bytes.byteLength).toBe(3)
  })
})

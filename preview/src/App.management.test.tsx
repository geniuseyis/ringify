import {cleanup, fireEvent, render, screen, within} from '@testing-library/react'
import {IDBFactory} from 'fake-indexeddb'
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest'
import App from './App'
import {ProjectRepository} from './lib/projectRepository'

beforeEach(async()=>{
  vi.stubGlobal('indexedDB',new IDBFactory())
  localStorage.clear()
  localStorage.setItem('ringify.projects.migrated.v2','true')
  localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'light',language:'tr',onboardingSeen:true}))
  await new ProjectRepository().put({id:'retained',summary:{id:'retained',name:'Retained tone',sourceName:'voice.wav',
    duration:2,trimStart:0,trimEnd:2,updatedAt:new Date().toISOString(),status:'draft'},sourceDuration:2,
    effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false},source:{bytes:new Uint8Array([4,5,6]).buffer,type:'audio/wav'}})
})
afterEach(()=>{cleanup();vi.restoreAllMocks();vi.unstubAllGlobals()})

async function resetDialog(){
  render(<App />)
  await screen.findByRole('heading',{name:'Sesini imzana dönüştür.'})
  fireEvent.click(within(screen.getByRole('navigation')).getByRole('button',{name:'Ayarlar'}))
  fireEvent.click(screen.getByRole('button',{name:'Depolama'}))
  fireEvent.click(screen.getByRole('button',{name:'Yerel verileri sıfırla'}))
  return screen.getByRole('dialog')
}

describe('Application reset confirmation and durable failure handling',()=>{
  it('does not clear IndexedDB when the user cancels',async()=>{
    const clear=vi.spyOn(ProjectRepository.prototype,'clear')
    const dialog=await resetDialog()
    fireEvent.click(within(dialog).getByRole('button',{name:'Vazgeç'}))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(clear).not.toHaveBeenCalled()
    const records=await new ProjectRepository().list()
    expect(records).toHaveLength(1)
    expect(new Uint8Array(records[0].source!.bytes)).toEqual(new Uint8Array([4,5,6]))
  })

  it('keeps the dialog and real data after a storage failure propagated by App',async()=>{
    const clear=vi.spyOn(ProjectRepository.prototype,'clear').mockRejectedValueOnce(new Error('Storage locked'))
    const dialog=await resetDialog()
    fireEvent.click(within(dialog).getByRole('button',{name:'Verileri Sil'}))
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Storage locked')
    expect(clear).toHaveBeenCalledOnce()
    expect(dialog).toBeInTheDocument()
    expect(within(dialog).getByRole('button',{name:'Verileri Sil'})).toBeEnabled()
    const record=await new ProjectRepository().get('retained')
    expect(new Uint8Array(record!.source!.bytes)).toEqual(new Uint8Array([4,5,6]))
    expect(JSON.parse(localStorage.getItem('ringify.settings.v1')!).onboardingSeen).toBe(true)
  })
})

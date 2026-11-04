import {cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react'
import {afterEach,expect,it,vi} from 'vitest'
import {LibraryScreen} from './ManagementScreens'
import type {LibraryOperations} from './LibraryTools'
import type {ProjectSummary} from '../types'
afterEach(cleanup)
const projects:ProjectSummary[]=[{id:'one',name:'Alpha',sourceName:'source.wav',duration:2,trimStart:1,trimEnd:3,updatedAt:'2026-11-01',status:'exported',favorite:true,collectionIDs:['c']},{id:'two',name:'Beta',sourceName:'two.wav',duration:3,trimStart:0,trimEnd:3,updatedAt:'2026-10-31',status:'draft'}]
async function ready(){fireEvent.click(screen.getByRole('button',{name:'Filtrele ve sırala'}));await screen.findByRole('option',{name:'Sounds'});fireEvent.click(screen.getByRole('button',{name:'Sonuçları göster'}))}
function setup(pro=true){
  const ops:LibraryOperations={pro,onRequirePro:vi.fn(),patch:vi.fn().mockResolvedValue(undefined),duplicate:vi.fn().mockResolvedValue(undefined),removeMany:vi.fn().mockResolvedValue(undefined),collections:vi.fn().mockResolvedValue([{id:'c',name:'Sounds',createdAt:'2026-11-01'}]),createCollection:vi.fn().mockResolvedValue({id:'new',name:'New'}),deleteCollection:vi.fn().mockResolvedValue(undefined),history:vi.fn().mockResolvedValue([{id:'out',projectID:'one',name:'Alpha.wav',createdAt:'2026-11-01',byteCount:100,verified:false}]),exportMedia:vi.fn(),deleteExport:vi.fn().mockResolvedValue(undefined),storage:vi.fn().mockResolvedValue(4096)}
  render(<LibraryScreen projects={projects} language="tr" operations={ops} onOpenProject={vi.fn()} onCreate={vi.fn()} onUpdateProjects={vi.fn()} onShare={vi.fn()}/>);return ops
}
it('filters real favorites and collections, sorts metadata and opens actual project actions',async()=>{
  setup();expect(screen.getByRole('button',{name:'Favoriler'})).toBeVisible();expect(screen.getByRole('button',{name:'Koleksiyonlar'})).toBeVisible();expect(screen.getByRole('button',{name:'Filtrele ve sırala'})).toBeVisible();expect(screen.getByText('Son düzenlenenler')).toBeVisible();await ready()
  fireEvent.click(screen.getByRole('button',{name:'Favoriler'}));expect(screen.queryByText('Beta')).not.toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Favoriler'}));fireEvent.click(screen.getByRole('button',{name:'Filtrele ve sırala'}));fireEvent.change(screen.getByRole('combobox',{name:'Koleksiyon'}),{target:{value:'c'}})
  expect(screen.queryByText('Beta')).not.toBeInTheDocument()
  fireEvent.change(screen.getByRole('combobox',{name:'Koleksiyon'}),{target:{value:''}});fireEvent.change(screen.getByRole('combobox',{name:'Sıralama'}),{target:{value:'oldest'}})
  fireEvent.click(screen.getByRole('button',{name:'Sonuçları göster'}))
  const cards=document.querySelectorAll('.library-card-main');expect(cards[0]).toHaveTextContent('Beta')
})
it('retains legacy favorites for free users but routes new favorites and selection to Pro',async()=>{
  const ops=setup(false);await ready()
  fireEvent.click(screen.getByRole('button',{name:'Filtrele ve sırala'}));fireEvent.click(screen.getByRole('button',{name:'Çoklu seçim · Pro'}));expect(ops.onRequirePro).toHaveBeenCalledOnce()
  fireEvent.click(screen.getByRole('button',{name:'Beta seçenekleri'}));fireEvent.click(screen.getByRole('button',{name:'Favorilere ekle · Pro'}))
  expect(ops.onRequirePro).toHaveBeenCalledTimes(2);expect(ops.patch).not.toHaveBeenCalled()
  fireEvent.click(screen.getByRole('button',{name:'Alpha seçenekleri'}));fireEvent.click(screen.getByRole('button',{name:'Favorilerden kaldır'}))
  await waitFor(()=>expect(ops.patch).toHaveBeenCalledWith(['one'],{favorite:false}))
})
it('requires an explicit destructive confirmation before deleting selected projects',async()=>{
  const ops=setup();await ready()
  fireEvent.click(screen.getByRole('button',{name:'Filtrele ve sırala'}));fireEvent.click(screen.getByRole('button',{name:'Çoklu seçim · Pro'}));fireEvent.click(screen.getByRole('button',{name:'Görünenleri seç'}));fireEvent.click(screen.getByRole('button',{name:'Seçilileri sil'}))
  expect(ops.removeMany).not.toHaveBeenCalled();fireEvent.click(screen.getByRole('button',{name:'Vazgeç'}));expect(ops.removeMany).not.toHaveBeenCalled()
  fireEvent.click(screen.getByRole('button',{name:'Seçilileri sil'}));fireEvent.click(screen.getByRole('button',{name:'Projeleri Sil'}))
  await waitFor(()=>expect(ops.removeMany).toHaveBeenCalledWith(['one','two']))
})
it('shows failed batch actions and retains selection for retry',async()=>{
  const ops=setup();vi.mocked(ops.patch).mockRejectedValue(Error('disk full'));await ready()
  fireEvent.click(screen.getByRole('button',{name:'Filtrele ve sırala'}));fireEvent.click(screen.getByRole('button',{name:'Çoklu seçim · Pro'}));fireEvent.click(screen.getByRole('button',{name:'Görünenleri seç'}));fireEvent.click(screen.getByRole('button',{name:'Favorilere ekle'}))
  expect(await screen.findByRole('alert')).toHaveTextContent('disk full');expect(screen.getByText('2 seçili')).toBeInTheDocument()
})
it('reads output history honestly and confirms archive deletion separately from the project',async()=>{
  const ops=setup();await ready();fireEvent.click(screen.getByRole('button',{name:'Alpha seçenekleri'}));fireEvent.click(screen.getByRole('button',{name:'Dışa aktarma geçmişi'}))
  expect(await screen.findByText(/Eski çıktı · doğrulama yok/)).toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Arşivden kaldır'}));expect(ops.deleteExport).not.toHaveBeenCalled()
  fireEvent.click(screen.getByRole('button',{name:'Arşiv Kaydını Sil'}));await waitFor(()=>expect(ops.deleteExport).toHaveBeenCalledWith('out'));expect(ops.removeMany).not.toHaveBeenCalled()
})
it('shows actual storage payload and preserves projects when deleting a collection',async()=>{
  const ops=setup();await ready();fireEvent.click(screen.getByRole('button',{name:'Koleksiyonlar'}));fireEvent.click(screen.getByRole('button',{name:'Depolama bilgisi'}))
  expect(await screen.findByText(/Kayıtlı medya verisi/)).toBeInTheDocument()
  expect(screen.getByText('4,1 kB')).toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Koleksiyonları yönet'}));fireEvent.click(screen.getByRole('button',{name:'Sounds koleksiyonunu sil'}));expect(ops.deleteCollection).not.toHaveBeenCalled()
  fireEvent.click(screen.getByRole('button',{name:'Koleksiyonu Sil'}));await waitFor(()=>expect(ops.deleteCollection).toHaveBeenCalledWith('c'));expect(ops.removeMany).not.toHaveBeenCalled()
})

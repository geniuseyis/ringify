import {cleanup,fireEvent,render,screen,within} from '@testing-library/react'
import {afterEach,expect,it,vi} from 'vitest'
import {IDBFactory} from 'fake-indexeddb'
import {SettingsScreen} from './SettingsScreen'
import {LibraryScreen} from './ManagementScreens'
import App from '../App'

afterEach(()=>{cleanup();localStorage.clear();vi.unstubAllGlobals()})
function settings(){
  const props={settings:{theme:'light' as const,language:'tr' as const,exportFormat:'m4a-ios' as const,onboardingSeen:true,isProDemo:true},language:'tr' as const,storageCount:1,onChange:vi.fn(),onHelp:vi.fn(),onResetData:vi.fn(),onToast:vi.fn(),onOpenLibrary:vi.fn(),onOpenPremium:vi.fn(),onReadStorage:vi.fn().mockResolvedValue(1024)}
  render(<SettingsScreen {...props}/>);return props
}
it('starts Settings with Account and never turns a legacy demo flag into a lifetime license',()=>{
  settings();expect(screen.getAllByRole('heading',{level:2})[0]).toHaveTextContent('Hesap')
  expect(screen.getByText('Normal sürüm · 1 proje')).toBeInTheDocument()
  expect(screen.queryByText(/Ömür boyu lisans/i)).not.toBeInTheDocument()
  expect(screen.queryByRole('button',{name:'Yerel verileri sıfırla'})).not.toBeInTheDocument()
})
it('keeps restore in license details and never changes a preference or fabricates access',()=>{
  const props=settings();fireEvent.click(screen.getByRole('button',{name:'Hesap ve lisans'}))
  fireEvent.click(screen.getByRole('button',{name:'Satın almaları geri yükle'}))
  expect(screen.getByRole('dialog')).toHaveTextContent('Web önizlemesi Apple satın almalarını doğrulayamaz')
  fireEvent.keyDown(screen.getByRole('dialog'),{key:'Escape'})
  expect(screen.getByRole('heading',{name:'Hesap ve lisans'})).toBeInTheDocument()
  expect(props.onChange).not.toHaveBeenCalled();expect(props.onOpenPremium).not.toHaveBeenCalled()
})
it('opens the requested help topic instead of placing its answer on Settings',()=>{
  const props=settings();fireEvent.click(screen.getByRole('button',{name:'Zil sesi nasıl oluşturulur?'}))
  expect(props.onHelp).toHaveBeenCalledWith('create')
  fireEvent.click(screen.getByRole('button',{name:'Destek ve geri bildirim'}));expect(props.onHelp).toHaveBeenLastCalledWith('contact')
})
it('reads actual storage only on the storage subpage and retains real library navigation',async()=>{
  const props=settings();expect(props.onReadStorage).not.toHaveBeenCalled()
  fireEvent.click(screen.getByRole('button',{name:'Depolama'}));expect(await screen.findByText('1,02 kB')).toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Projeler'}));expect(props.onOpenLibrary).toHaveBeenCalledOnce()
})
it('shows project details from the actual summary and returns to the existing project actions',()=>{
  const row={id:'real',name:'My tone',sourceName:'actual-recording.wav',duration:2,trimStart:1,trimEnd:3,updatedAt:'2026-11-02',status:'draft' as const}
  const open=vi.fn();render(<LibraryScreen language="tr" projects={[row]} onOpenProject={open} onCreate={vi.fn()} onShare={vi.fn()} onUpdateProjects={vi.fn()}/>)
  fireEvent.click(screen.getByRole('button',{name:'My tone seçenekleri'}));fireEvent.click(screen.getByRole('button',{name:'Proje ayrıntıları'}))
  expect(screen.getByRole('dialog')).toHaveTextContent('actual-recording.wav')
  fireEvent.click(screen.getByRole('button',{name:'Geri'}));fireEvent.click(screen.getByRole('button',{name:'Yeniden düzenle'}))
  expect(open).toHaveBeenCalledWith(row)
})
it('opens Pro outside the tab bar and returns to the license subpage that launched it',async()=>{
  vi.stubGlobal('indexedDB',new IDBFactory());localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'light',language:'tr',onboardingSeen:true}));localStorage.setItem('ringify.projects.migrated.v2','true')
  render(<App/>);await screen.findByRole('heading',{name:'Sesini imzana dönüştür.'})
  fireEvent.click(within(screen.getByRole('navigation')).getByRole('button',{name:'Ayarlar'}))
  fireEvent.click(screen.getByRole('button',{name:'Hesap ve lisans'}));fireEvent.click(screen.getByRole('button',{name:'Pro planlarını gör'}))
  expect(screen.getByRole('heading',{name:'Ringify Pro'})).toBeInTheDocument()
  expect(screen.queryByRole('navigation',{name:'Ana navigasyon'})).not.toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Geri'}));expect(screen.getByRole('heading',{name:'Hesap ve lisans'})).toBeInTheDocument()
  expect(screen.getByRole('navigation',{name:'Ana navigasyon'})).toBeInTheDocument()
})

import {cleanup,fireEvent,render,screen,within,waitFor} from '@testing-library/react'
import {afterEach,describe,expect,it,vi} from 'vitest'
import {HelpScreen} from './SupportScreens'
import type {Language} from '../types'
afterEach(()=>{cleanup();localStorage.clear()})
function renderHelp(language: Language = 'tr') {
  const onBack = vi.fn(), onNavigate = vi.fn()
  return { ...render(<HelpScreen language={language} onBack={onBack} onNavigate={onNavigate} />), onBack, onNavigate }
}

const faqTitles = [
  'Hangi dosyaları kullanabilirim?',
  'Projelerim nerede saklanıyor?',
  'Mikrofon neden açılmıyor?',
  'Ses neden bozuluyor?',
  'iPhone’da nasıl zil sesi yaparım?',
  'Dışa aktarma neden durdu?',
]

function filterButton(name: string) {
  return within(screen.getByRole('group',{name:'Yardım konuları'})).getByRole('button',{name})
}


describe('Help content, search and real recovery navigation', () => {
  it('keeps topic answers off the index and provides real back navigation without placeholder contacts', () => {
    const { container, onBack } = renderHelp()
    expect(screen.getByRole('heading', { name: 'Yardım' })).toBeInTheDocument()
    for (const title of faqTitles) {
      expect(screen.getByRole('button',{name:title})).toBeInTheDocument()
    }
    expect(container.querySelector('.uf-help-answer')).toBeNull()
    expect(container.querySelector('a[href*=".example"]')).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onBack).toHaveBeenCalledOnce()
  })

  it('trims search and case-folds Turkish microphone queries into the one actual answer', () => {
    const { container } = renderHelp()
    fireEvent.change(screen.getByLabelText('Yardımda ara'), { target: { value: '  MİKROFON  ' } })
    expect(screen.getByText('Mikrofon neden açılmıyor?')).toBeInTheDocument()
    expect(screen.queryByText('Hangi dosyaları kullanabilirim?')).not.toBeInTheDocument()
    expect(container.querySelectorAll('details')).toHaveLength(0)
    expect(screen.getByText('1 konu')).toBeInTheDocument()
  })

  it('recovers from an empty search using the real clear action', () => {
    renderHelp()
    const search = screen.getByLabelText('Yardımda ara')
    fireEvent.change(search, { target: { value: 'bulunamayacak-yardim' } })
    expect(screen.getByText('Sonuç bulunamadı')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Aramayı temizle' }))
    expect(search).toHaveValue('')
    for (const title of faqTitles) expect(screen.getByText(title)).toBeInTheDocument()
  })

  it('filters real answers with pressed states rather than confusing the separate troubleshooting controls', () => {
    renderHelp()
    expect(filterButton('Tümü')).toHaveAttribute('aria-pressed', 'true')
    fireEvent.click(filterButton('Ses'))
    expect(filterButton('Ses')).toHaveAttribute('aria-pressed', 'true')
    expect(filterButton('Tümü')).toHaveAttribute('aria-pressed', 'false')
    expect(screen.getByText('Mikrofon neden açılmıyor?')).toBeInTheDocument()
    expect(screen.getByText('Ses neden bozuluyor?')).toBeInTheDocument()
    expect(screen.queryByText('Hangi dosyaları kullanabilirim?')).not.toBeInTheDocument()
    fireEvent.click(filterButton('Çıktı'))
    expect(filterButton('Çıktı')).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('iPhone’da nasıl zil sesi yaparım?')).toBeInTheDocument()
    expect(screen.getByText('Dışa aktarma neden durdu?')).toBeInTheDocument()
    fireEvent.click(filterButton('Dosya'))
    expect(filterButton('Dosya')).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('Hangi dosyaları kullanabilirim?')).toBeInTheDocument()
    expect(screen.queryByText('Ses neden bozuluyor?')).not.toBeInTheDocument()
    fireEvent.click(filterButton('Tümü'))
    for (const title of faqTitles) expect(screen.getByText(title)).toBeInTheDocument()
  })

  it('connects every quick action to its existing real application destination', () => {
    const { onNavigate } = renderHelp()
    for (const [name, destination] of [['Dosya ekle', 'import'], ['iPhone rehberi', 'guide'], ['Projelerim', 'library']]) {
      fireEvent.click(screen.getByRole('button', { name }))
      expect(onNavigate).toHaveBeenLastCalledWith(destination)
    }
    expect(onNavigate).toHaveBeenCalledTimes(3)
  })

  it.each([
    ['Dosya', 'Yeni dosya seç', 'import'],
    ['Mikrofon', 'Kaydı aç', 'recorder'],
    ['Depolama', 'Kütüphaneyi aç', 'library'],
    ['Çıktı', 'Projeleri kontrol et', 'library'],
  ])('offers a real %s recovery action without a placeholder success toast', (category, action, destination) => {
    const { onNavigate, onBack } = renderHelp()
    fireEvent.click(screen.getByRole('button',{name:'Adım adım sorun giderme'}))
    const troubleshooting = screen.getByRole('group', { name: 'Sorun giderme' })
    fireEvent.click(within(troubleshooting).getByRole('button', { name: category }))
    fireEvent.click(screen.getByRole('button', { name: action }))
    expect(onNavigate).toHaveBeenCalledExactlyOnceWith(destination)
    expect(onBack).not.toHaveBeenCalled()
  })

  it('localizes search and all real quick actions into English', () => {
    const { onNavigate } = renderHelp('en')
    expect(screen.getByRole('heading', { name: 'Help' })).toBeInTheDocument()
    expect(screen.getByLabelText('Search help')).toBeInTheDocument()
    for (const [name, destination] of [['Add a file', 'import'], ['iPhone guide', 'guide'], ['My projects', 'library']]) {
      fireEvent.click(screen.getByRole('button', { name }))
      expect(onNavigate).toHaveBeenLastCalledWith(destination)
    }
    expect(onNavigate).toHaveBeenCalledTimes(3)
  })

  it('opens one answer at a time and restores topic focus on Back',async()=>{
    renderHelp()
    fireEvent.click(screen.getByRole('button',{name:'Hangi dosyaları kullanabilirim?'}))
    expect(screen.getByRole('heading',{name:'Hangi dosyaları kullanabilirim?'})).toHaveFocus()
    expect(screen.queryByLabelText('Yardımda ara')).not.toBeInTheDocument()
    expect(screen.getByText(/32 MiB/)).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Geri'}))
    await waitFor(()=>expect(screen.getByRole('button',{name:'Hangi dosyaları kullanabilirim?'})).toHaveFocus())
  })

  it('routes support through the chosen Help Center and keeps nested Back paths',()=>{
    const {container,onBack}=renderHelp()
    fireEvent.click(screen.getByRole('button',{name:'Destek ve geri bildirim'}))
    expect(screen.getByText(/Yardım Merkezi’nde/)).toBeInTheDocument()
    expect(container.querySelector('a[href^="mailto:"]')).toHaveAttribute('href','mailto:ringifydestek@gmail.com')
    fireEvent.click(screen.getByRole('button',{name:'Dosya içe aktarma sorunları'}))
    expect(screen.getByRole('heading',{name:'Dosya içe aktarma sorunları'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Geri'}))
    expect(screen.getByRole('heading',{name:'Destek ve geri bildirim'})).toBeInTheDocument()
    expect(onBack).not.toHaveBeenCalled()
  })

  it('returns directly to Settings when a topic was opened from a Settings row',()=>{
    const onBack=vi.fn(),onNavigate=vi.fn()
    render(<HelpScreen language="tr" initialTopic="purchases" onBack={onBack} onNavigate={onNavigate}/>)
    fireEvent.click(screen.getByRole('button',{name:'Geri'}));expect(onBack).toHaveBeenCalledOnce()
  })
})

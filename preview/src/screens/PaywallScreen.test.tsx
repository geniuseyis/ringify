import {cleanup, fireEvent, render, screen, within} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import {afterEach, describe, expect, it, vi} from 'vitest'
import {PremiumScreen} from './PaywallScreen'
import type {Language} from '../types'

afterEach(() => {cleanup(); localStorage.clear()})
function renderPremium(language: Language = 'tr', onBack?: () => void) {
  const onNavigate = vi.fn()
  return {...render(<PremiumScreen language={language} onNavigate={onNavigate} onBack={onBack} />), onNavigate}
}

describe('Ringify Pro purchase plan presentation',()=>{
  it('offers four plans, three concise benefits and one purchase action',()=>{
    const {container}=renderPremium()
    expect(screen.getByRole('heading',{name:'Ringify Pro'})).toBeInTheDocument()
    expect(screen.getAllByRole('radio')).toHaveLength(4)
    expect(within(screen.getByRole('list',{name:'Bir bakışta Pro'})).getAllByRole('listitem')).toHaveLength(3)
    expect(container.querySelectorAll('.r-primary')).toHaveLength(1)
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
    expect(container.querySelector('details')).toBeNull()
    expect(screen.queryByRole('region',{name:'Ek proje kapasitesi'})).not.toBeInTheDocument()
    for(const name of ['Haftalık','Aylık','Yıllık','Ömür boyu'])expect(screen.getByRole('radio',{name})).toBeInTheDocument()
    expect(container.textContent).not.toMatch(/demo|ücretsiz deneme|sınırsız|unlimited/i)
    expect(screen.getByText(/önerilen fiyatlar/i)).toBeInTheDocument()
  })
  it('defaults to the full yearly charge and states renewal clearly',()=>{
    const {container}=renderPremium()
    expect(screen.getByRole('radio',{name:'Yıllık'})).toBeChecked()
    expect(container.querySelector('.p8-billing')).toHaveTextContent('Her yıl ₺2.499,99')
    expect(container.querySelector('.p8-billing')).toHaveTextContent('otomatik yenilenir')
    expect(screen.getByText(/%40 avantaj/)).toBeInTheDocument()
    expect(screen.queryByText('₺208,33')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Plan ve ödeme ayrıntıları'}))
    expect(within(screen.getByRole('dialog')).getByText('₺208,33')).toBeInTheDocument()
    expect(screen.getByRole('dialog')).toHaveTextContent('12 × ₺349,99')
  })
  it('updates period and removes automatic renewal for lifetime',()=>{
    const {container}=renderPremium()
    fireEvent.click(screen.getByRole('radio',{name:'Haftalık'}))
    expect(container.querySelector('.p8-billing')).toHaveTextContent('Her hafta ₺124,99')
    fireEvent.click(screen.getByRole('radio',{name:'Aylık'}))
    expect(container.querySelector('.p8-billing')).toHaveTextContent('Her ay ₺349,99')
    fireEvent.click(screen.getByRole('radio',{name:'Ömür boyu'}))
    expect(container.querySelector('.p8-billing')).toHaveTextContent('₺4.499,99 tek ödeme. Otomatik yenileme yok.')
  })
  it('supports native keyboard movement among plan radios',async()=>{
    const user=userEvent.setup()
    renderPremium()
    screen.getByRole('radio',{name:'Yıllık'}).focus()
    await user.keyboard('{ArrowRight}')
    expect(screen.getByRole('radio',{name:'Ömür boyu'})).toBeChecked()
  })
  it('shows real Normal/Pro limits and never gives planned tools an available tick',()=>{
    const {container}=renderPremium()
    fireEvent.click(screen.getByRole('button',{name:'Normal ve Pro’yu karşılaştır'}))
    const normalize=within(container.querySelector('[data-feature="normalize"]') as HTMLElement)
    expect(normalize.getByText('Dahil değil')).toBeInTheDocument()
    expect(normalize.getByText('Dahil')).toBeInTheDocument()
    const capacity=within(container.querySelector('[data-feature="projects"]') as HTMLElement)
    expect(capacity.getByText('1')).toBeInTheDocument()
    expect(capacity.getByText('3')).toBeInTheDocument()
    expect(capacity.getByText(/Ek proje yuvaları ayrı ücretli: ₺49,99/)).toBeInTheDocument()
    for(const id of ['eq','presets','analysis','collections','history']){
      const row=within(container.querySelector('[data-feature="'+id+'"]') as HTMLElement)
      expect(row.getByText('Planlanan')).toBeInTheDocument()
      expect(row.queryByText('Dahil',{exact:true})).not.toBeInTheDocument()
    }
  })
  it('filters comparison differences without losing the selected plan',()=>{
    const {container}=renderPremium()
    fireEvent.click(screen.getByRole('button',{name:'Normal ve Pro’yu karşılaştır'}))
    fireEvent.click(screen.getByRole('button',{name:'Pro farkları'}))
    expect(container.querySelectorAll('[data-feature]')).toHaveLength(7)
    expect(container.querySelector('[data-feature="import"]')).toBeNull()
    fireEvent.click(screen.getByRole('button',{name:'Tüm özellikler'}))
    expect(container.querySelectorAll('[data-feature]')).toHaveLength(17)
    fireEvent.click(screen.getByRole('button',{name:'Kapat'}))
    expect(screen.getByRole('radio',{name:'Yıllık'})).toBeChecked()
  })
  it('discloses the per-slot one-time proposal without simulating an extra-slot purchase',()=>{
    renderPremium()
    fireEvent.click(screen.getByRole('button',{name:'Plan ve ödeme ayrıntıları'}))
    const slots=screen.getByRole('region',{name:'Ek proje kapasitesi'})
    expect(slots).toHaveTextContent('₺49,99')
    expect(slots).toHaveTextContent('Tek ödeme')
    expect(slots).toHaveTextContent('proje silinince yuva yeniden kullanılabilir')
    expect(slots).toHaveTextContent('En fazla 20 ek yuva')
    expect(slots).toHaveTextContent('ayrı, kalıcı bir Apple satın alımı')
    expect(slots).toHaveTextContent('Bu web önizlemesinde satın alma yapılamaz')
    expect(within(slots).queryByRole('button')).not.toBeInTheDocument()
  })
  it('does not turn a legacy local flag into purchase success',()=>{
    const value=JSON.stringify({isProDemo:true})
    localStorage.setItem('ringify.settings.v1',value)
    const {onNavigate}=renderPremium()
    fireEvent.click(screen.getByRole('button',{name:'iPhone’da satın al'}))
    const dialog=screen.getByRole('dialog')
    expect(dialog).toHaveTextContent('Bu tarayıcı Apple ödeme ekranını açamaz.')
    expect(dialog).toHaveTextContent('Pro yetkisi oluşturulmaz.')
    expect(localStorage.getItem('ringify.settings.v1')).toBe(value)
    expect(onNavigate).not.toHaveBeenCalled()
  })
  it('closes purchase details with Escape and returns focus to the CTA',()=>{
    renderPremium()
    const action=screen.getByRole('button',{name:'iPhone’da satın al'})
    fireEvent.click(action)
    fireEvent.keyDown(document,{key:'Escape'})
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(action).toHaveFocus()
  })
  it('explains restore truthfully and provides real policy information links',()=>{
    renderPremium()
    fireEvent.click(screen.getByRole('button',{name:'Geri yükle ve yasal bilgiler'}))
    expect(screen.getByRole('dialog')).toHaveTextContent('Apple satın almalarını doğrulayamaz')
    fireEvent.click(screen.getByRole('button',{name:'Satın alma bilgileri'}))
    expect(screen.getByRole('link',{name:'Apple aboneliklerini yönet'})).toHaveAttribute('href','https://apps.apple.com/account/subscriptions')
    expect(screen.getByRole('link',{name:'Apple Standart Kullanım Koşulları'})).toHaveAttribute('href','https://www.apple.com/legal/internet-services/itunes/dev/stdeula/')
    fireEvent.click(screen.getByRole('button',{name:'Satın almalara dön'}))
    fireEvent.click(screen.getByRole('button',{name:'Gizlilik'}))
    expect(screen.getByRole('dialog')).toHaveTextContent('ödeme kartı bilgisi')
  })
  it('keeps a working route back to Normal',()=>{
    const {onNavigate}=renderPremium()
    fireEvent.click(screen.getByRole('button',{name:'Normal ile devam et'}))
    expect(onNavigate).toHaveBeenCalledExactlyOnceWith('home')
  })
  it('localizes the choices while retaining the Türkiye currency and billing period',()=>{
    const {container}=renderPremium('en')
    expect(screen.getByRole('radio',{name:'Yearly'})).toBeChecked()
    expect(container.querySelector('.p8-billing')).toHaveTextContent('TRY')
    expect(container.querySelector('.p8-billing')).toHaveTextContent('every year')
    expect(screen.getByRole('button',{name:'Purchase on iPhone'})).toBeInTheDocument()
  })
})

describe('Pro detail flow accessibility', () => {
  it.each([
    ['Normal ve Pro’yu karşılaştır', 'Normal mi, Pro mu?'],
    ['Plan ve ödeme ayrıntıları', 'Plan ve ödeme ayrıntıları'],
    ['Sık sorulan sorular', 'Sık sorulan sorular'],
    ['Geri yükle ve yasal bilgiler', 'Satın almalar ve gizlilik'],
    ['iPhone’da satın al', 'Satın alma iPhone’da tamamlanır'],
  ])('opens %s in one tap, traps focus and returns to its trigger', async (action, title) => {
    const user = userEvent.setup()
    const {container} = renderPremium()
    const trigger = screen.getByRole('button', {name: action})
    await user.click(trigger)
    const dialog = screen.getByRole('dialog', {name: title})
    const close = within(dialog).getByRole('button', {name: 'Kapat'})
    const done = within(dialog).getByRole('button', {name: 'Anladım'})
    expect(container.querySelector('.p8-layout')).toHaveAttribute('inert')
    expect(container.querySelector('.p8-layout')).toHaveAttribute('aria-hidden', 'true')
    expect(close).toHaveFocus()
    await user.tab({shift: true})
    expect(done).toHaveFocus()
    await user.tab()
    expect(close).toHaveFocus()
    await user.keyboard('{Escape}')
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(trigger).toHaveFocus()
    expect(container.querySelector('.p8-layout')).not.toHaveAttribute('inert')
  })

  it('keeps every FAQ keyboard reachable and discloses its answer only on request', async () => {
    const user = userEvent.setup()
    const {container} = renderPremium()
    await user.click(screen.getByRole('button', {name: 'Sık sorulan sorular'}))
    const summaries = Array.from(container.querySelectorAll('summary'))
    expect(summaries).toHaveLength(4)
    for (const summary of summaries) {
      expect(summary.parentElement).not.toHaveAttribute('open')
      await user.tab()
      expect(summary).toHaveFocus()
    }
    await user.click(summaries[0])
    expect(summaries[0].parentElement).toHaveAttribute('open')
    expect(summaries[0].parentElement).toHaveTextContent('Var olan projelerin silinmez')
    await user.click(summaries[0])
    expect(summaries[0].parentElement).not.toHaveAttribute('open')
  })

  it('keeps the selected plan, close control and original focus target across nested legal views', () => {
    renderPremium()
    fireEvent.click(screen.getByRole('radio', {name: 'Ömür boyu'}))
    const trigger = screen.getByRole('button', {name: 'Geri yükle ve yasal bilgiler'})
    fireEvent.click(trigger)
    fireEvent.click(screen.getByRole('button', {name: 'Satın alma bilgileri'}))
    expect(screen.getByRole('dialog', {name: 'Satın alma bilgileri'})).toHaveTextContent('Otomatik yenileme yok')
    expect(screen.getByRole('button', {name: 'Kapat'})).toHaveFocus()
    fireEvent.click(screen.getByRole('button', {name: 'Satın almalara dön'}))
    expect(screen.getByRole('dialog', {name: 'Satın almalar ve gizlilik'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', {name: 'Gizlilik'}))
    expect(screen.getByRole('dialog', {name: 'Gizlilik'})).toHaveTextContent('satın alma kanıtı sayılmaz')
    fireEvent.click(screen.getByRole('button', {name: 'Kapat'}))
    expect(trigger).toHaveFocus()
    expect(screen.getByRole('radio', {name: 'Ömür boyu'})).toBeChecked()
  })

  it('dismisses on the backdrop and restores the originating detail link', () => {
    const {container} = renderPremium()
    const trigger = screen.getByRole('button', {name: 'Plan ve ödeme ayrıntıları'})
    fireEvent.click(trigger)
    fireEvent.mouseDown(container.querySelector('.sheet-backdrop')!)
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(trigger).toHaveFocus()
  })

  it('describes each radio with its actual price and billing period', () => {
    renderPremium()
    expect(screen.getByRole('radio', {name: 'Haftalık'})).toHaveAccessibleDescription('₺124,99 Her 7 gün')
    expect(screen.getByRole('radio', {name: 'Yıllık'})).toHaveAccessibleDescription('₺2.499,99 Her yıl')
    expect(screen.getByRole('radio', {name: 'Ömür boyu'})).toHaveAccessibleDescription('₺4.499,99 Tek ödeme · yenileme yok')
  })

  it('returns to the invoking screen through Back and has a Close route at the root', () => {
    const onBack = vi.fn()
    const view = renderPremium('tr', onBack)
    fireEvent.click(screen.getByRole('button', {name: 'Geri'}))
    expect(onBack).toHaveBeenCalledOnce()
    expect(view.onNavigate).not.toHaveBeenCalled()
    view.unmount()
    const root = renderPremium()
    fireEvent.click(screen.getByRole('button', {name: 'Kapat'}))
    expect(root.onNavigate).toHaveBeenCalledExactlyOnceWith('home')
  })

  it('localizes detail entry points and restore/legal navigation into English', () => {
    renderPremium('en')
    fireEvent.click(screen.getByRole('button', {name: 'Compare Normal and Pro'}))
    expect(screen.getByRole('table', {name: 'Normal and Pro feature comparison'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', {name: 'Close'}))
    fireEvent.click(screen.getByRole('button', {name: 'Restore and legal information'}))
    expect(screen.getByRole('dialog')).toHaveTextContent('web preview cannot verify Apple purchases')
    fireEvent.click(screen.getByRole('button', {name: 'Privacy'}))
    expect(screen.getByRole('button', {name: 'Back to purchases'})).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', {name: 'Got it'}))
    fireEvent.click(screen.getByRole('button', {name: 'Frequently asked questions'}))
    expect(screen.getByText('Are these prices final?')).toBeInTheDocument()
  })
})

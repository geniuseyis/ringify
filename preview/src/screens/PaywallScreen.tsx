import {useId, useRef, useState, type MouseEvent} from 'react'
import {AudioLines, Check, ChevronDown, ChevronLeft, ChevronRight, Clock3, Crown, FileAudio, HelpCircle, Minus, ReceiptText, RotateCcw, ShieldCheck, Smartphone, X} from 'lucide-react'
import type {Language, ScreenId} from '../types'
import {ScreenShell} from '../components/ScreenShell'
import {ModalSheet} from '../designSystem/ModalSheet'
import {PrimaryActionButton, SecondaryActionButton} from '../designSystem/StudioComponents'
import {designVariables} from '../designSystem/tokens'
import {annualSavings, billingDisclosure, comparisonFeatures, freeProjectLimit, proProjectLimit, projectSlotOffering, planFor, planNames, price, proPlans, type ProPlanID} from '../lib/proOffering'
import '../designSystem/paywall.css'

type Sheet = 'comparison' | 'billing' | 'faq' | 'purchase' | 'support' | 'terms' | 'privacy' | null
type PremiumScreenProps = {language: Language; onNavigate: (screen: ScreenId) => void; onBack?: () => void}

export function PremiumScreen({language, onNavigate, onBack}: PremiumScreenProps) {
  const isTr = language === 'tr'
  const [selected, setSelected] = useState<ProPlanID>('yearly')
  const [sheet, setSheet] = useState<Sheet>(null)
  const trigger = useRef<HTMLElement | null>(null)
  const planGroup = useId()
  const amount = price(planFor(selected).priceMinor, language)
  const titles: Record<Exclude<Sheet, null>, string> = {
    comparison: isTr ? 'Normal mi, Pro mu?' : 'Normal or Pro?',
    billing: isTr ? 'Plan ve ödeme ayrıntıları' : 'Plan and billing details',
    faq: isTr ? 'Sık sorulan sorular' : 'Frequently asked questions',
    purchase: isTr ? 'Satın alma iPhone’da tamamlanır' : 'Complete your purchase on iPhone',
    support: isTr ? 'Satın almalar ve gizlilik' : 'Purchases and privacy',
    terms: isTr ? 'Satın alma bilgileri' : 'Purchase details',
    privacy: isTr ? 'Gizlilik' : 'Privacy',
  }
  function open(next: Exclude<Sheet, null>, event: MouseEvent<HTMLButtonElement>) {
    trigger.current = event.currentTarget
    setSheet(next)
  }
  function close() { setSheet(null) }

  function sheetContent() {
    switch (sheet) {
      case 'comparison': return <ComparisonDetails language={language} />
      case 'billing': return <BillingDetails language={language} selected={selected} />
      case 'faq': return <ProQuestions language={language} />
      case 'purchase': return <>
        <span className="p8-sheet-icon"><Smartphone size={28} aria-hidden="true" /></span>
        <h3>{isTr ? planNames[selected].tr : planNames[selected].en} · {amount}</h3>
        <p>{isTr ? 'Bu tarayıcı Apple ödeme ekranını açamaz. Seçtiğin plan iOS uygulamasında App Store üzerinden satın alınır.' : 'This browser cannot open Apple’s purchase sheet. Purchase the selected plan through the App Store in the iOS app.'}</p>
        <p>{billingDisclosure(selected, language)}</p>
        <p>{isTr ? 'Burada ödeme yapılmaz veya Pro yetkisi oluşturulmaz.' : 'No payment or Pro entitlement is created here.'}</p>
      </>
      case 'support': return <>
        <span className="p8-sheet-icon"><RotateCcw size={26} aria-hidden="true" /></span>
        <h3>{isTr ? 'Satın almaları geri yükle' : 'Restore purchases'}</h3>
        <p>{isTr ? 'Geri yüklemeyi, satın almanın yapıldığı Apple hesabıyla iPhone uygulamasında başlat. Web önizlemesi Apple satın almalarını doğrulayamaz.' : 'Start restore in the iPhone app using the Apple account used for purchase. The web preview cannot verify Apple purchases.'}</p>
        <div className="p8-detail-links">
          <button type="button" onClick={() => setSheet('terms')}><ReceiptText size={19} aria-hidden="true" /><span>{titles.terms}</span><ChevronRight size={17} aria-hidden="true" /></button>
          <button type="button" onClick={() => setSheet('privacy')}><ShieldCheck size={19} aria-hidden="true" /><span>{titles.privacy}</span><ChevronRight size={17} aria-hidden="true" /></button>
        </div>
      </>
      case 'terms':
      case 'privacy': return <>
        <button type="button" className="p8-sheet-back" onClick={() => setSheet('support')}><ChevronLeft size={20} aria-hidden="true" />{isTr ? 'Satın almalara dön' : 'Back to purchases'}</button>
        {sheet === 'terms' ? <>
          <p>{billingDisclosure(selected, language)}</p>
          <p>{isTr ? 'Tüm süreler aynı Pro kapsamına erişim içindir. Planlanan araçlar geliştirilmeden mevcut özellik sayılmaz.' : 'All durations provide the same Pro scope. Planned tools are not included as currently available features.'}</p>
          <a href="https://apps.apple.com/account/subscriptions" target="_blank" rel="noopener noreferrer">{isTr ? 'Apple aboneliklerini yönet' : 'Manage Apple subscriptions'}</a>
          <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer">{isTr ? 'Apple Standart Kullanım Koşulları' : 'Apple Standard EULA'}</a>
        </> : <>
          <p>{isTr ? 'Ses ve projeler bu tarayıcının yerel deposunda tutulur; ödeme kartı bilgisi bu önizlemeye girilmez.' : 'Audio and projects stay in this browser’s local storage; no payment card information is entered in this preview.'}</p>
          <p>{isTr ? 'iOS satın alımları Apple tarafından işlenir. Eski yerel Pro bayrakları satın alma kanıtı sayılmaz.' : 'Apple processes iOS purchases. Legacy local Pro flags are never proof of purchase.'}</p>
        </>}
      </>
      default: return null
    }
  }

  return <ScreenShell className="premium-screen v2-screen v3-screen v3-flow v8-paywall av-screen av-manage av-pro" style={designVariables} scroll={false}>
    <div className="p8-layout" inert={sheet ? true : undefined} aria-hidden={sheet ? true : undefined}>
      <div className="p8-workspace">
        <header className="p8-header">
          <button type="button" className="p8-dismiss" aria-label={onBack ? (isTr ? 'Geri' : 'Back') : (isTr ? 'Kapat' : 'Close')} onClick={onBack ?? (() => onNavigate('home'))}>
            {onBack ? <ChevronLeft size={23} aria-hidden="true" /> : <X size={22} aria-hidden="true" />}
          </button>
          <span>RINGIFY PRO</span><span className="p8-market">TR · TRY</span>
        </header>

        <section className="p8-hero" aria-labelledby={planGroup + '-title'}>
          <span className="p8-crown"><Crown size={29} strokeWidth={1.6} aria-hidden="true" /></span>
          <div><h1 id={planGroup + '-title'}>Ringify Pro</h1><p>{isTr ? 'Sesine daha fazla alan aç.' : 'Make more room for your sound.'}</p></div>
        </section>
        <ul className="p8-benefits" aria-label={isTr ? 'Bir bakışta Pro' : 'Pro at a glance'}>
          <li><FileAudio size={20} aria-hidden="true" /><span><strong>{isTr ? proProjectLimit + ' kayıtlı proje' : proProjectLimit + ' saved projects'}</strong><small>{isTr ? 'Normal planda ' + freeProjectLimit + ' proje' : freeProjectLimit + ' project on Normal'}</small></span><Check size={17} aria-hidden="true" /></li>
          <li><AudioLines size={20} aria-hidden="true" /><span><strong>{isTr ? 'Ses seviyesini dengele' : 'Balance your audio level'}</strong><small>{isTr ? 'Pro ile normalize' : 'Normalization with Pro'}</small></span><Check size={17} aria-hidden="true" /></li>
          <li><ShieldCheck size={20} aria-hidden="true" /><span><strong>{isTr ? 'Yerel ve reklamsız' : 'Local and ad-free'}</strong><small>{isTr ? 'Normal ve Pro’da dahil' : 'Included with Normal and Pro'}</small></span><Check size={17} aria-hidden="true" /></li>
        </ul>

        <fieldset className="p8-plans">
          <legend>{isTr ? 'Planını seç' : 'Choose your plan'}</legend>
          <p className="p8-price-status">{isTr ? 'Türkiye için önerilen fiyatlar · Satışa açılmadı' : 'Proposed Türkiye prices · Not on sale yet'}</p>
          <div className="p8-plan-grid">{proPlans.map(option => {
            const id = option.id as ProPlanID, name = planNames[id], active = selected === id
            return <label className={'p8-plan' + (active ? ' is-selected' : '')} key={id}>
              <input type="radio" name={planGroup} aria-label={isTr ? name.tr : name.en} aria-describedby={planGroup + '-' + id + '-price ' + planGroup + '-' + id + '-period'} checked={active} onChange={() => setSelected(id)} />
              <span className="p8-plan-top"><strong>{isTr ? name.tr : name.en}</strong><i className="p8-radio">{active ? <Check size={11} aria-hidden="true" /> : null}</i></span>
              <span className="p8-plan-price" id={planGroup + '-' + id + '-price'}>{price(option.priceMinor, language)}</span>
              <span className="p8-plan-period" id={planGroup + '-' + id + '-period'}>{id === 'lifetime' ? (isTr ? 'Tek ödeme · yenileme yok' : 'One payment · no renewal') : id === 'weekly' ? (isTr ? 'Her 7 gün' : 'Every 7 days') : id === 'monthly' ? (isTr ? 'Her ay' : 'Every month') : (isTr ? 'Her yıl' : 'Every year')}</span>
              {id === 'yearly' ? <span className="p8-plan-badge">{isTr ? '%' + annualSavings() + ' avantaj' : 'Save ' + annualSavings() + '%'}</span> : null}
            </label>
          })}</div>
        </fieldset>
        <p className="p8-scope-note">{isTr ? 'Dört plan. Aynı Pro kapsamı.' : 'Four plans. The same Pro features.'}</p>

        <nav className="p8-detail-links" aria-label={isTr ? 'Pro hakkında ayrıntılar' : 'More about Pro'}>
          <button type="button" onClick={event => open('comparison', event)}><Crown size={19} aria-hidden="true" /><span>{isTr ? 'Normal ve Pro’yu karşılaştır' : 'Compare Normal and Pro'}</span><ChevronRight size={17} aria-hidden="true" /></button>
          <button type="button" onClick={event => open('billing', event)}><ReceiptText size={19} aria-hidden="true" /><span>{titles.billing}</span><ChevronRight size={17} aria-hidden="true" /></button>
          <button type="button" onClick={event => open('faq', event)}><HelpCircle size={19} aria-hidden="true" /><span>{titles.faq}</span><ChevronRight size={17} aria-hidden="true" /></button>
          <button type="button" onClick={event => open('support', event)}><RotateCcw size={19} aria-hidden="true" /><span>{isTr ? 'Geri yükle ve yasal bilgiler' : 'Restore and legal information'}</span><ChevronRight size={17} aria-hidden="true" /></button>
        </nav>
        <button type="button" className="p8-keep-normal" onClick={() => onNavigate('home')}>{isTr ? 'Normal ile devam et' : 'Continue with Normal'}</button>
      </div>
      <footer className="p8-footer">
        <div className="p8-selected-summary"><span>{isTr ? planNames[selected].tr : planNames[selected].en}</span><strong>{amount}</strong></div>
        <p className="p8-billing" aria-live="polite">{billingDisclosure(selected, language)}</p>
        <PrimaryActionButton icon={<Crown size={20} aria-hidden="true" />} onClick={event => open('purchase', event)}>{isTr ? 'iPhone’da satın al' : 'Purchase on iPhone'}</PrimaryActionButton>
      </footer>
    </div>
    {sheet ? <ModalSheet title={titles[sheet]} closeLabel={isTr ? 'Kapat' : 'Close'} onClose={close} restoreFocusTo={trigger.current} focusKey={sheet}>
      <div className="p8-sheet-content">{sheetContent()}<SecondaryActionButton onClick={close}>{isTr ? 'Anladım' : 'Got it'}</SecondaryActionButton></div>
    </ModalSheet> : null}
  </ScreenShell>
}

function ComparisonDetails({language}: {language: Language}) {
  const isTr = language === 'tr'
  const [differences, setDifferences] = useState(false)
  const rows = comparisonFeatures.filter(row => !differences || row.normal !== row.pro)
  function cell(value: string) {
    if (value === 'yes') return <span className="p8-check"><Check size={20} aria-hidden="true" /><span className="sr-only">{isTr ? 'Dahil' : 'Included'}</span></span>
    if (value === 'no') return <span className="p8-minus"><Minus size={19} aria-hidden="true" /><span className="sr-only">{isTr ? 'Dahil değil' : 'Not included'}</span></span>
    if (value === 'planned') return <span className="p8-pending"><Clock3 size={14} aria-hidden="true" /><span>{isTr ? 'Planlanan' : 'Planned'}</span></span>
    if (value === 'ios') return <span className="p8-pending"><Smartphone size={15} aria-hidden="true" /><span>iOS</span></span>
    return <span className="p8-capacity">{value}</span>
  }
  return <>
    <p>{isTr ? 'Temel stüdyo araçları Normal’de kalır. Pro, normalize ve daha fazla proje alanı ekler.' : 'Normal keeps the essential studio tools. Pro adds normalization and more project space.'}</p>
    <div className="p8-view-filter" role="group" aria-label={isTr ? 'Karşılaştırma görünümü' : 'Comparison view'}>
      <button type="button" aria-pressed={!differences} onClick={() => setDifferences(false)}>{isTr ? 'Tüm özellikler' : 'All features'}</button>
      <button type="button" aria-pressed={differences} onClick={() => setDifferences(true)}>{isTr ? 'Pro farkları' : 'Pro differences'}</button>
    </div>
    <div className="p8-matrix" role="table" aria-label={isTr ? 'Normal ve Pro özellik karşılaştırması' : 'Normal and Pro feature comparison'}>
      <div role="row" className="p8-matrix-header"><span role="columnheader">{isTr ? 'Özellik' : 'Feature'}</span><strong role="columnheader">Normal</strong><strong role="columnheader">Pro</strong></div>
      {rows.map(row => <div className="p8-matrix-row" role="row" key={row.id} data-feature={row.id}>
        <div role="cell" className="p8-feature-copy"><strong>{isTr ? row.tr : row.en}</strong><small>{isTr ? row.detailTr : row.detailEn}</small></div>
        <div role="cell"><span className="p8-mobile-label">Normal</span>{cell(row.normal)}</div><div role="cell"><span className="p8-mobile-label">Pro</span>{cell(row.pro)}</div>
      </div>)}
    </div>
    <p>{isTr ? 'Planlanan araçlar henüz kullanıma açık değildir. M4A/AAC iPhone doğrulaması bekler. Normal 1, Pro 3 kayıtlı proje içerir. Ek proje yuvaları ayrı ücretlidir; cihaz depolama sınırları sürer.' : 'Planned tools are not available yet. M4A/AAC awaits iPhone verification. Normal includes 1 saved project; Pro includes 3. Extra project slots are charged separately; device storage limits still apply.'}</p>
  </>
}

function BillingDetails({language, selected}: {language: Language; selected: ProPlanID}) {
  const isTr = language === 'tr', plan = planFor(selected), amount = price(plan.priceMinor, language)
  return <>
    <section className="p8-breakdown"><span>{isTr ? planNames[selected].tr : planNames[selected].en}</span><strong>{amount}</strong><p>{billingDisclosure(selected, language)}</p></section>
    {selected === 'yearly' ? <section className="p8-breakdown"><span>{isTr ? 'Aylık karşılığı' : 'Monthly equivalent'}</span><strong>{price(Math.round(plan.priceMinor / 12), language)}<small> / {isTr ? 'ay' : 'month'}</small></strong><p>{isTr ? amount + ' yıllık tek çekim. Avantaj, 12 × ' + price(planFor('monthly').priceMinor, language) + ' aylık ödeme toplamına göredir.' : amount + ' billed annually. Savings compare with 12 monthly payments of ' + price(planFor('monthly').priceMinor, language) + '.'}</p></section> : null}
    <p>{isTr ? 'Tüm Pro planlarında aynı Pro kapsamı. Yalnızca süre ve ödeme biçimi değişir.' : 'Every Pro plan has the same Pro scope. Only the duration and billing change.'}</p>
    <section className="p8-breakdown" aria-label={isTr ? 'Ek proje kapasitesi' : 'Extra project capacity'}>
      <span>{isTr ? 'PRO’YA EK KAPASİTE' : 'EXTRA CAPACITY FOR PRO'}</span>
      <strong>{price(projectSlotOffering.priceMinor, language)}<small> / {isTr ? 'ek proje yuvası' : 'extra project slot'}</small></strong>
      <p>{isTr ? 'Tek ödeme. Pro aktifken 3 projenin üzerine bir yuva ekler; proje silinince yuva yeniden kullanılabilir. Pro biterse kayıtlar korunur, yeni proje limiti 1 olur.' : 'One payment. Adds one slot beyond 3 while Pro is active; deleting a project frees the slot for reuse. When Pro ends, records are preserved and new projects use the limit of 1.'}</p>
      <p>{isTr ? 'En fazla 20 ek yuva; her biri ayrı, kalıcı bir Apple satın alımı. Aynı Apple hesabıyla geri yüklenir. Bu web önizlemesinde satın alma yapılamaz; iPhone ödeme doğrulaması bekleniyor.' : 'Up to 20 extra slots, each a separate permanent Apple purchase. Restore with the same Apple account. Purchases are unavailable in this web preview; iPhone payment verification is pending.'}</p>
    </section>
  </>
}

function ProQuestions({language}: {language: Language}) {
  const isTr = language === 'tr'
  const faq = [
    [isTr ? 'Normal planda neler korunur?' : 'What stays on the Normal plan?', isTr ? 'Temel düzenleme ve ' + freeProjectLimit + ' kayıtlı proje. Var olan projelerin silinmez; eski normalize ayarları korunur. Yeni normalize işlemi Pro gerektirir. Pro ' + proProjectLimit + ' kayıtlı proje içerir; üzeri için her ek yuva ' + price(projectSlotOffering.priceMinor, language) + ' tek ödemedir.' : 'Basic editing and ' + freeProjectLimit + ' saved project. Existing projects are never removed and prior normalization is preserved. New normalization requires Pro. Pro includes ' + proProjectLimit + ' saved projects; each extra slot costs ' + price(projectSlotOffering.priceMinor, language) + ' once.'],
    [isTr ? 'Abonelik ile ömür boyu arasındaki fark nedir?' : 'How does lifetime differ from a subscription?', isTr ? 'Haftalık, aylık ve yıllık planlar iptal edilene kadar otomatik yenilenir. Ömür boyu tek seferlik satın almadır; yenilenmez.' : 'Weekly, monthly and yearly plans renew automatically until cancelled. Lifetime is a single, non-renewing purchase.'],
    [isTr ? 'Mevcut aboneliğim varken ömür boyu alırsam?' : 'What if I buy lifetime with an existing subscription?', isTr ? 'Ömür boyu ayrı bir üründür. Mevcut aboneliğinin yenilenmesini Apple abonelik ayarlarından ayrıca yönet.' : 'Lifetime is a separate product. Manage the existing subscription’s renewal separately in Apple subscription settings.'],
    [isTr ? 'Fiyatlar kesin mi?' : 'Are these prices final?', isTr ? 'Bu ekrandaki tutarlar Türkiye için önerilen ürün fiyatlarıdır. Satıştaki iOS uygulamasında geçerli tutar ve para birimi Apple ödeme ekranından doğrulanır.' : 'These are proposed product prices for Türkiye. Confirm the current amount and currency in the Apple purchase sheet in the released iOS app.'],
  ]
  // Explicit tabindex also includes native disclosures in ModalSheet's focus trap.
  return <div className="p8-faq">{faq.map(([question, answer]) => <details key={question}><summary tabIndex={0}>{question}<ChevronDown size={18} aria-hidden="true" /></summary><p>{answer}</p></details>)}</div>
}

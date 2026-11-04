import catalog from '../../../shared/pro-offering.json'
import type {Language} from '../types'

export type ProPlanID='weekly'|'monthly'|'yearly'|'lifetime'
export const proPlans=catalog.plans
export const freeProjectLimit=catalog.freeProjectLimit
export const proProjectLimit=catalog.proProjectLimit
export const projectSlotOffering=catalog.projectSlotOffering
export const planNames:Record<ProPlanID,{tr:string;en:string}>= {
  weekly:{tr:'Haftalık',en:'Weekly'},monthly:{tr:'Aylık',en:'Monthly'},
  yearly:{tr:'Yıllık',en:'Yearly'},lifetime:{tr:'Ömür boyu',en:'Lifetime'},
}
export function planFor(id:ProPlanID){return proPlans.find(plan=>plan.id===id)!}
export function price(minor:number,language:Language){
  if(!Number.isFinite(minor)||minor<0)throw new RangeError('Invalid price')
  return new Intl.NumberFormat(language==='tr'?'tr-TR':'en-GB',{style:'currency',currency:'TRY'}).format(minor/100)
}
export function annualSavings(){return Math.floor((1-planFor('yearly').priceMinor/(planFor('monthly').priceMinor*12))*100)}
export function billingDisclosure(id:ProPlanID,language:Language){
  const isTr=language==='tr',amount=price(planFor(id).priceMinor,language)
  if(id==='lifetime')return isTr?`${amount} tek ödeme. Otomatik yenileme yok.`:`${amount} once. No automatic renewal.`
  const unit=isTr?{weekly:'hafta',monthly:'ay',yearly:'yıl'}:{weekly:'week',monthly:'month',yearly:'year'}
  return isTr?`Her ${unit[id]} ${amount}. İptal edilene kadar otomatik yenilenir.`:`${amount} every ${unit[id]}. Renews automatically until cancelled.`
}

export type ComparisonFeature={id:string;group:'studio'|'library'|'advanced';tr:string;en:string;detailTr:string;detailEn:string;normal:string;pro:string;status:'available'|'planned'|'ios'}
export const comparisonFeatures:ComparisonFeature[]=[
  {id:'import',group:'studio',tr:'Ses ve video içe aktarma',en:'Audio and video import',detailTr:'Desteklenen dosya ve codec’ler',detailEn:'Supported files and codecs',normal:'yes',pro:'yes',status:'available'},
  {id:'record',group:'studio',tr:'Mikrofon kaydı',en:'Microphone recording',detailTr:'Gerçek seviye ölçümü ve ön dinleme',detailEn:'Real level meter and preview',normal:'yes',pro:'yes',status:'available'},
  {id:'trim',group:'studio',tr:'Hassas kesim ve waveform',en:'Precise trim and waveform',detailTr:'1–29 sn seçim, zoom ve klavye kontrolü',detailEn:'1–29 sec selection, zoom and keyboard control',normal:'yes',pro:'yes',status:'available'},
  {id:'playback',group:'studio',tr:'Döngü, duraklatma ve geri alma',en:'Loop, pause and undo',detailTr:'Seçili bölümü düzenle ve yeniden dinle',detailEn:'Edit and replay the selected region',normal:'yes',pro:'yes',status:'available'},
  {id:'gain',group:'studio',tr:'Ses seviyesi ve fade',en:'Volume and fades',detailTr:'Fade-in / fade-out ve güvenli kazanç',detailEn:'Fade-in / fade-out and safe gain',normal:'yes',pro:'yes',status:'available'},
  {id:'normalize',group:'studio',tr:'Normalize',en:'Normalization',detailTr:'Tepe seviyesini güvenli biçimde dengele',detailEn:'Safely balance the peak level',normal:'no',pro:'yes',status:'available'},
  {id:'wav',group:'studio',tr:'WAV dışa aktarımı ve paylaşım',en:'WAV export and sharing',detailTr:'Gerçek PCM dosyası; destek yoksa indirme',detailEn:'Real PCM file; download fallback for sharing',normal:'yes',pro:'yes',status:'available'},
  {id:'aac',group:'studio',tr:'M4A / AAC dışa aktarımı',en:'M4A / AAC export',detailTr:'iPhone doğrulaması bekliyor',detailEn:'iPhone verification pending',normal:'ios',pro:'ios',status:'ios'},
  {id:'projects',group:'library',tr:'Kayıtlı proje kapasitesi',en:'Saved project capacity',detailTr:`Ek proje yuvaları ayrı ücretli: ${price(projectSlotOffering.priceMinor,'tr')} / yuva; satışa açılmadı`,detailEn:`Extra project slots are charged separately: ${price(projectSlotOffering.priceMinor,'en')} per slot; not on sale yet`,normal:String(freeProjectLimit),pro:String(proProjectLimit),status:'available'},
  {id:'reopen',group:'library',tr:'Kaynakla yeniden düzenleme',en:'Re-edit original media',detailTr:'Ses, trim ve efekt ayarlarıyla geri aç',detailEn:'Reopen audio, trim and effect settings',normal:'yes',pro:'yes',status:'available'},
  {id:'management',group:'library',tr:'Arama, filtre ve proje yönetimi',en:'Search, filters and project management',detailTr:'Adlandırma, onaylı silme ve paylaşım',detailEn:'Rename, confirmed deletion and sharing',normal:'yes',pro:'yes',status:'available'},
  {id:'privacy',group:'library',tr:'Yerel işleme, reklamsız kullanım',en:'Local processing, no advertising',detailTr:'Sesin zorunlu bir sunucuya gönderilmez',detailEn:'No required upload of your audio',normal:'yes',pro:'yes',status:'available'},
  {id:'eq',group:'advanced',tr:'EQ ve ses filtreleri',en:'EQ and audio filters',detailTr:'Low-pass / high-pass ve ton kontrolü',detailEn:'Low-pass / high-pass and tone controls',normal:'no',pro:'planned',status:'planned'},
  {id:'presets',group:'advanced',tr:'Ses presetleri',en:'Audio presets',detailTr:'Kaydedilmiş işleme kombinasyonları',detailEn:'Saved processing combinations',normal:'no',pro:'planned',status:'planned'},
  {id:'analysis',group:'advanced',tr:'Sessizlik ve seviye analizi',en:'Silence and level analysis',detailTr:'Cihaz üzerinde deterministik öneriler',detailEn:'Deterministic on-device suggestions',normal:'no',pro:'planned',status:'planned'},
  {id:'collections',group:'advanced',tr:'Koleksiyonlar ve favoriler',en:'Collections and favorites',detailTr:'Genişletilmiş medya düzeni',detailEn:'Expanded media organization',normal:'no',pro:'planned',status:'planned'},
  {id:'history',group:'advanced',tr:'Çıktı geçmişi ve kalite presetleri',en:'Export history and quality presets',detailTr:'Gelişmiş dışa aktarma yönetimi',detailEn:'Advanced export management',normal:'no',pro:'planned',status:'planned'},
]

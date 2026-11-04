import {useEffect,useRef,useState,type MouseEvent} from 'react'
import {Check,ChevronRight,Crown,FileAudio,FolderOpen,HardDrive,HelpCircle,Languages,LoaderCircle,Moon,Palette,RotateCcw,ShieldCheck,Sun,Trash2} from 'lucide-react'
import type {AppSettings,Language,ThemePreference} from '../types'
import {ScreenShell} from '../components/ScreenShell'
import {DetailHeader} from '../designSystem/DetailHeader'
import {ModalSheet} from '../designSystem/ModalSheet'
import {SecondaryActionButton} from '../designSystem/StudioComponents'
import {designVariables} from '../designSystem/tokens'
import {formatFileSize} from '../lib/format'
import {freeProjectLimit} from '../lib/proOffering'
import {helpTopics,type HelpTopicId} from './helpContent'
import {version} from '../../package.json'
import '../designSystem/uiFreeze.css'

interface Props {
  settings:AppSettings;language:Language;storageCount:number;onChange:(next:AppSettings)=>void
  onHelp:(topic?:HelpTopicId)=>void;onResetData:()=>void|Promise<void>;onToast:(message:string)=>void
  onOpenLibrary?:()=>void;onOpenPremium?:()=>void;onReadStorage?:()=>Promise<number>
  activePage?:SettingsPage;onPageChange?:(page:SettingsPage)=>void
}
export type SettingsPage='root'|'account'|'appearance'|'export'|'storage'|'privacy'|'terms'
export function SettingsScreen({settings,language,storageCount,onChange,onHelp,onResetData,onOpenLibrary,onOpenPremium,onReadStorage,activePage,onPageChange}:Props){
  const tr=language==='tr',[localPage,setLocalPage]=useState<SettingsPage>('root'),[dialog,setDialog]=useState<'restore'|'reset'|null>(null)
  const page=activePage??localPage
  function setPage(next:SettingsPage){setLocalPage(next);onPageChange?.(next)}
  const [busy,setBusy]=useState(false),[error,setError]=useState<string|null>(null),[bytes,setBytes]=useState<number|null>(null)
  const running=useRef(false),mounted=useRef(true),trigger=useRef<HTMLElement|null>(null),returnTarget=useRef<HTMLElement|null>(null)
  const body=useRef<HTMLDivElement>(null)
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false}},[])
  useEffect(()=>{if(page!=='storage'||!onReadStorage)return;let current=true;setBytes(null);void onReadStorage().then(value=>{if(current)setBytes(value)}).catch(()=>{if(current)setError(tr?'Depolama bilgisi okunamadı.':'Could not read storage.')});return()=>{current=false}},[page,onReadStorage,tr])
  function open(next:SettingsPage,event:MouseEvent<HTMLButtonElement>){returnTarget.current=event.currentTarget;setError(null);setPage(next)}
  function back(){const label=returnTarget.current?.getAttribute('aria-label');setPage('root');setError(null);requestAnimationFrame(()=>{Array.from(body.current?.querySelectorAll<HTMLButtonElement>('button[aria-label]')??[]).find(button=>button.getAttribute('aria-label')===label)?.focus()})}
  function show(next:'restore'|'reset',event:MouseEvent<HTMLButtonElement>){trigger.current=event.currentTarget;setError(null);setDialog(next)}
  async function reset(){if(running.current)return;running.current=true;setBusy(true);setError(null);try{await onResetData();if(mounted.current)setDialog(null)}catch(reason){if(mounted.current)setError(reason instanceof Error?reason.message:(tr?'Veriler silinemedi. Tekrar dene.':'Data could not be deleted. Try again.'))}finally{running.current=false;if(mounted.current)setBusy(false)}}
  const titles:Record<SettingsPage,string>={root:tr?'Ayarlar':'Settings',account:tr?'Hesap ve lisans':'Account and license',appearance:tr?'Görünüm':'Appearance',export:tr?'Ses ve dışa aktarma':'Audio and export',storage:tr?'Depolama':'Storage',privacy:tr?'Gizlilik':'Privacy',terms:tr?'Kullanım koşulları':'Terms of use'}
  const themes:Array<{value:ThemePreference;title:string;icon:typeof Sun}>=[{value:'system',title:tr?'Sistem':'System',icon:Palette},{value:'light',title:tr?'Açık':'Light',icon:Sun},{value:'dark',title:tr?'Koyu':'Dark',icon:Moon}]
  function row(label:string,icon:typeof Sun,onClick:(event:MouseEvent<HTMLButtonElement>)=>void,value?:string,danger=false){const Icon=icon;return <button type="button" className={`uf-setting-row ${danger?'is-danger':''}`} aria-label={label} onClick={onClick}><span className="uf-setting-icon"><Icon size={20} aria-hidden="true"/></span><span className="uf-setting-label">{label}</span>{value?<small>{value}</small>:null}<ChevronRight size={17} aria-hidden="true"/></button>}
  return <ScreenShell className="settings-screen v2-screen v3-screen v3-flow v5-management v3-management v3-settings uf-settings av-screen av-support av-settings" style={designVariables} scroll={false}>
    <div ref={body} className="uf-settings-body" inert={dialog?true:undefined} aria-hidden={dialog?true:undefined}>
      {page==='root'?<header className="m5-title-row"><h1>{titles.root}</h1></header>:<DetailHeader title={titles[page]} language={language} onBack={back}/>}
      <div className="m5-workspace uf-settings-content">
        {page==='root'?<>
          <section className="uf-group"><h2>{tr?'Hesap':'Account'}</h2><div className="uf-group-list">
            <button type="button" className="uf-account-row" aria-label="Ringify Pro" onClick={onOpenPremium}><span className="uf-account-crown"><Crown size={25} aria-hidden="true"/></span><span><strong>Ringify Pro</strong><small>{tr?'Normal sürüm · 1 proje':'Normal plan · 1 project'}</small></span><ChevronRight size={19} aria-hidden="true"/></button>
            {row(tr?'Hesap ve lisans':'Account and license',ShieldCheck,event=>open('account',event))}
          </div></section>
          <section className="uf-group"><h2>{tr?'Genel':'General'}</h2><div className="uf-group-list">
            {row(tr?'Görünüm':'Appearance',Palette,event=>open('appearance',event),themes.find(theme=>theme.value===settings.theme)?.title)}
            {row(tr?'Dil':'Language',Languages,()=>onChange({...settings,language:settings.language==='tr'?'en':'tr'}),settings.language==='tr'?'Türkçe':'English')}
          </div></section>
          <section className="uf-group"><h2>{tr?'Stüdyo ve dosyalar':'Studio and files'}</h2><div className="uf-group-list">
            {row(tr?'Ses ve dışa aktarma':'Audio and export',FileAudio,event=>open('export',event),'WAV')}
            {row(tr?'Depolama':'Storage',HardDrive,event=>open('storage',event),`${storageCount} ${tr?'proje':'projects'}`)}
          </div></section>
          <section className="uf-group"><h2>{tr?'Gizlilik ve koşullar':'Privacy and terms'}</h2><div className="uf-group-list">
            {row(tr?'Veri ve gizlilik':'Data & privacy',ShieldCheck,event=>open('privacy',event))}
            {row(tr?'Kullanım koşulları':'Terms of use',FileAudio,event=>open('terms',event))}
          </div></section>
          <section className="uf-group"><h2>{tr?'Yardım ve sorular':'Help and questions'}</h2><div className="uf-group-list">
            {helpTopics.filter(topic=>['create','ringtone','formats','purchases'].includes(topic.id)).map(topic=><div key={topic.id}>{row(tr?topic.tr:topic.en,HelpCircle,()=>onHelp(topic.id))}</div>)}
            {row(tr?'Yardım ve hata durumları':'Help & Error States',HelpCircle,()=>onHelp())}
            {row(tr?'Destek ve geri bildirim':'Support and feedback',HelpCircle,()=>onHelp('contact'))}
          </div></section>
          <p className="uf-about">Ringify · {version}</p>
        </>:null}
        {page==='account'?<><section className="uf-detail-intro"><span className="uf-account-crown"><Crown size={28}/></span><h2>{tr?'Bu cihazdaki lisans':'License on this device'}</h2><p>{tr?'Normal sürüm':'Normal plan'}</p></section><dl className="uf-info-list"><div><dt>{tr?'Kayıtlı projeler':'Saved projects'}</dt><dd>{storageCount} / {freeProjectLimit}</dd></div><div><dt>{tr?'Satın alma kanalı':'Purchase channel'}</dt><dd>App Store · iOS</dd></div></dl><div className="uf-group-list">{row(tr?'Pro planlarını gör':'View Pro plans',Crown,()=>onOpenPremium?.())}{row(tr?'Satın almaları geri yükle':'Restore purchases',RotateCcw,event=>show('restore',event))}</div></>:null}
        {page==='appearance'?<div className="uf-group-list" role="group" aria-label={tr?'Tema seçimi':'Theme selection'}>{themes.map(({value,title,icon:Icon})=><button type="button" key={value} className="uf-setting-row" aria-pressed={settings.theme===value} onClick={()=>onChange({...settings,theme:value})}><Icon size={21}/><span className="uf-setting-label">{title}</span>{settings.theme===value?<Check size={19} aria-hidden="true"/>:null}</button>)}</div>:null}
        {page==='export'?<><section className="uf-detail-intro"><FileAudio size={32}/><h2>{tr?'Dışa aktarma seçenekleri':'Export options'}</h2><p>{tr?'Dosyanın biçimini ve kalitesini Dışa Aktar ekranında gözden geçir.':'Review format and quality on the Export screen.'}</p></section><dl className="uf-info-list"><div><dt>{tr?'Tarayıcı biçimi':'Browser format'}</dt><dd>WAV / PCM</dd></div><div><dt>{tr?'Standart kalite':'Standard precision'}</dt><dd>16-bit</dd></div><div><dt>{tr?'Yüksek hassasiyet':'High precision'}</dt><dd>24-bit · Pro</dd></div><div><dt>{tr?'iPhone biçimi':'iPhone format'}</dt><dd>M4A / AAC · iOS</dd></div></dl><div className="uf-group-list">{row(tr?'Projeler':'Projects',FolderOpen,()=>onOpenLibrary?.())}</div></>:null}
        {page==='storage'?<><section className="uf-storage-summary"><HardDrive size={29}/><strong>{bytes===null?'—':formatFileSize(bytes,language)}</strong><span>{tr?'Kayıtlı medya verisi':'Stored media payload'}</span><small>{storageCount} {tr?'proje':'projects'}</small></section>{error?<p role="alert">{error}</p>:null}<div className="uf-group-list">{row(tr?'Projeler':'Projects',FolderOpen,()=>onOpenLibrary?.())}{row(tr?'Yerel verileri sıfırla':'Reset local data',Trash2,event=>show('reset',event),undefined,true)}</div></>:null}
        {page==='privacy'?<section className="uf-prose"><ShieldCheck size={30}/><h2>{tr?'Seslerin bu cihazda':'Your audio stays here'}</h2><p>{tr?'Ses dosyaları ve projeler bu tarayıcının yerel IndexedDB deposunda tutulur.':'Audio files and projects are kept in this browser’s local IndexedDB storage.'}</p><p>{tr?'Mikrofon izni yalnız kayıt başlatıldığında istenir.':'Microphone permission is requested only when recording starts.'}</p><p>{tr?'Site verileri temizlenirse yerel kayıtlar da silinir. Harici kaynak dosyaların değişmez.':'Clearing site data deletes local records. External source files are not changed.'}</p></section>:null}
        {page==='terms'?<section className="uf-prose"><h2>{tr?'Kullanım ve lisans':'Usage and license'}</h2><p>{tr?'Sahip olduğun veya kullanma iznin olan seslerle çalış. Ringify sistem zil sesini doğrudan değiştirmez; iPhone rehberini izle.':'Use media you own or have permission to use. Ringify does not directly change the system ringtone; follow the iPhone guide.'}</p><a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer">{tr?'Apple Standart Kullanım Koşulları':'Apple Standard EULA'}</a></section>:null}
      </div>
    </div>
    {dialog?<ModalSheet title={dialog==='reset'?(tr?'Yerel veriler silinsin mi?':'Delete local data?'):(tr?'Satın almaları geri yükle':'Restore purchases')} closeLabel={tr?'Kapat':'Close'} onClose={()=>{if(!busy){setDialog(null);setError(null)}}} busy={busy} restoreFocusTo={trigger.current}>
      <div className="uf-prose">{dialog==='restore'?<p>{tr?'Geri yüklemeyi satın almanın yapıldığı Apple hesabıyla iPhone uygulamasında başlat. Web önizlemesi Apple satın almalarını doğrulayamaz.':'Start restore in the iPhone app using the Apple account used for purchase. The web preview cannot verify Apple purchases.'}</p>:<><p>{tr?'Bu tarayıcıdaki projeler, ses dosyaları, geçmiş ve ayarlar silinir. Harici kaynak dosyaların değişmez.':'Projects, browser media, history and settings will be deleted. External source files are not changed.'}</p>{error?<p role="alert">{error}</p>:null}{busy?<p role="status"><LoaderCircle className="spin" size={18}/>{tr?'Siliniyor…':'Deleting…'}</p>:null}<button type="button" className="uf-danger-button" disabled={busy} onClick={()=>void reset()}>{tr?'Verileri Sil':'Delete Data'}</button><SecondaryActionButton disabled={busy} onClick={()=>setDialog(null)}>{tr?'Vazgeç':'Cancel'}</SecondaryActionButton></>}</div>
    </ModalSheet>:null}
  </ScreenShell>
}

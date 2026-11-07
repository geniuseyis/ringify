import {useEffect,useMemo,useRef,useState} from 'react'
import {ArrowDownToLine,ArrowUpRight,ChevronRight,CircleHelp,FileAudio,FolderOpen,HardDrive,Import,Mic,Search,Smartphone} from 'lucide-react'
import type {Language,ScreenId} from '../types'
import {ScreenShell} from '../components/ScreenShell'
import {SecondaryActionButton} from '../designSystem/StudioComponents'
import {DetailHeader} from '../designSystem/DetailHeader'
import {designVariables} from '../designSystem/tokens'
import {helpTopics,type HelpTopicId} from './helpContent'
import '../designSystem/support.css'
import '../designSystem/appleV2Management.css'
import '../designSystem/uiFreeze.css'

const SUPPORT_EMAIL='ringifydestek@gmail.com'

export {PremiumScreen} from './PaywallScreen'

const problems=[
  {key:'file',tr:'Dosya',en:'File',icon:FileAudio,titleTr:'Dosya açılmıyor',titleEn:'The file will not open',textTr:'Farklı bir dosya veya kaynağın sağlam bir kopyasını seç. Ses izi olmayan videoları kullanamazsın.',textEn:'Choose another file or an intact copy of the source. Videos without an audio track cannot be used.',actionTr:'Yeni dosya seç',actionEn:'Choose a new file',route:'import'},
  {key:'mic',tr:'Mikrofon',en:'Microphone',icon:Mic,titleTr:'Kayıt başlamıyor',titleEn:'Recording will not start',textTr:'Tarayıcının mikrofon iznini ve giriş cihazını kontrol et, sonra kayıt ekranında yeniden dene.',textEn:'Check the browser microphone permission and input device, then try again in the recorder.',actionTr:'Kaydı aç',actionEn:'Open recorder',route:'recorder'},
  {key:'storage',tr:'Depolama',en:'Storage',icon:HardDrive,titleTr:'Kayıt için yer aç',titleEn:'Make room for your project',textTr:'Önemli çıktıları önce indir. Kütüphaneden gereksiz projeleri onaylayarak silebilirsin; dışarıdaki kaynak dosyalar korunur.',textEn:'Download important exports first. Remove unneeded projects with confirmation in the library; external source files remain untouched.',actionTr:'Kütüphaneyi aç',actionEn:'Open library',route:'library'},
  {key:'export',tr:'Çıktı',en:'Export',icon:ArrowDownToLine,titleTr:'Çıktıyı yeniden hazırla',titleEn:'Prepare the output again',textTr:'Kayıtlı projeni açıp kaynak ve seçim aralığını kontrol et. Ardından dışa aktarmayı tekrar başlat.',textEn:'Open the saved project and check its source and selection, then start export again.',actionTr:'Projeleri kontrol et',actionEn:'Check projects',route:'library'},
] as const

export function HelpScreen({language,onBack,onNavigate,initialTopic}:{language:Language;onBack:()=>void;onNavigate:(screen:ScreenId)=>void;initialTopic?:HelpTopicId}){
  const tr=language==='tr',locale=tr?'tr-TR':'en-US'
  const [query,setQuery]=useState(''),[category,setCategory]=useState('all'),[problem,setProblem]=useState(0)
  const [trail,setTrail]=useState<HelpTopicId[]>(initialTopic?[initialTopic]:[]),[troubleshooting,setTroubleshooting]=useState(false)
  const trigger=useRef<HTMLElement|null>(null)
  const workspace=useRef<HTMLDivElement>(null)
  useEffect(()=>{setTrail(initialTopic?[initialTopic]:[]);setTroubleshooting(false)},[initialTopic])
  const filtered=useMemo(()=>{const needle=query.trim().toLocaleLowerCase(locale);return helpTopics.filter(topic=>(category==='all'||topic.category===category)&&`${tr?topic.tr:topic.en} ${tr?topic.answerTr:topic.answerEn}`.toLocaleLowerCase(locale).includes(needle))},[query,category,locale,tr])
  const topic=helpTopics.find(item=>item.id===trail.at(-1)),selected=problems[problem],ProblemIcon=selected.icon
  function open(id:HelpTopicId,element:HTMLElement){trigger.current=element;setTrail(old=>[...old,id])}
  function back(){const label=trigger.current?.textContent;if(troubleshooting){setTroubleshooting(false)}else if(trail.length>1){setTrail(old=>old.slice(0,-1))}else if(topic&&!initialTopic){setTrail([])}else{onBack();return}requestAnimationFrame(()=>{Array.from(workspace.current?.querySelectorAll<HTMLButtonElement>('button')??[]).find(button=>button.textContent===label)?.focus()})}
  const title=topic?(tr?topic.tr:topic.en):troubleshooting?(tr?'Sorun giderme':'Troubleshooting'):(tr?'Yardım':'Help')
  return <ScreenShell className="help-screen v2-screen v3-screen v3-flow v7-support v7-help v3-help uf-help av-screen av-support av-help" style={designVariables} scroll={false}>
    <DetailHeader title={title} language={language} onBack={back}/>
    <div ref={workspace} className="uf-help-workspace">
      {topic?<article className="uf-help-answer"><span className="uf-topic-symbol"><CircleHelp size={28} aria-hidden="true"/></span><p>{tr?topic.answerTr:topic.answerEn}</p>
        {topic.id==='contact'?<div className="uf-group-list">{helpTopics.filter(item=>['import','microphone','export','purchases','storage'].includes(item.id)).map(item=><button type="button" className="uf-topic-row" key={item.id} onClick={event=>open(item.id,event.currentTarget)}><span>{tr?item.tr:item.en}</span><ChevronRight size={17} aria-hidden="true"/></button>)}<a className="uf-topic-row" href={'mailto:'+SUPPORT_EMAIL}><span>{tr?'Bize e-posta gönder':'Email us'} · {SUPPORT_EMAIL}</span><ArrowUpRight size={17} aria-hidden="true"/></a></div>:<SecondaryActionButton onClick={()=>onNavigate(topic.route)}>{tr?topic.actionTr:topic.actionEn}<ChevronRight size={18} aria-hidden="true"/></SecondaryActionButton>}
      </article>:troubleshooting?<section className="c7-problem"><div className="c7-problem-picker" role="group" aria-label={tr?'Sorun giderme':'Troubleshooting'}>{problems.map((item,index)=><button type="button" key={item.key} aria-pressed={problem===index} onClick={()=>setProblem(index)}>{tr?item.tr:item.en}</button>)}</div><div className="c7-problem-detail" aria-live="polite"><span className="c7-row-icon"><ProblemIcon size={25} aria-hidden="true"/></span><h2>{tr?selected.titleTr:selected.titleEn}</h2><p>{tr?selected.textTr:selected.textEn}</p><SecondaryActionButton onClick={()=>onNavigate(selected.route)}>{tr?selected.actionTr:selected.actionEn}<ChevronRight size={18} aria-hidden="true"/></SecondaryActionButton></div></section>:<>
        <label className="c7-search"><Search size={20} aria-hidden="true"/><input type="search" value={query} aria-label={tr?'Yardımda ara':'Search help'} placeholder={tr?'Bir konu ara':'Search a topic'} onChange={event=>setQuery(event.target.value)}/></label>
        <div className="c7-quick-actions">{[{route:'import',icon:Import,tr:'Dosya ekle',en:'Add a file'},{route:'guide',icon:Smartphone,tr:'iPhone rehberi',en:'iPhone guide'},{route:'library',icon:FolderOpen,tr:'Projelerim',en:'My projects'}].map(({route,icon:Icon,tr:turkish,en})=><button type="button" key={route} onClick={()=>onNavigate(route as ScreenId)}><Icon size={23} aria-hidden="true"/><span>{tr?turkish:en}</span><ArrowUpRight size={13} aria-hidden="true"/></button>)}</div>
        <div className="c7-section-heading"><h2>{tr?'Yardım konuları':'Help topics'}</h2><span aria-live="polite">{filtered.length} {tr?'konu':'topics'}</span></div>
        <div className="c7-filters" role="group" aria-label={tr?'Yardım konuları':'Help topics'}>{(['all','file','audio','export','pro'] as const).map((value,index)=><button type="button" key={value} aria-pressed={category===value} onClick={()=>setCategory(value)}>{(tr?['Tümü','Dosya','Ses','Çıktı','Pro']:['All','File','Audio','Export','Pro'])[index]}</button>)}</div>
        {filtered.length?<div className="uf-group-list">{filtered.map(item=><button type="button" className="uf-topic-row" key={item.id} onClick={event=>open(item.id,event.currentTarget)}><CircleHelp size={19} aria-hidden="true"/><span>{tr?item.tr:item.en}</span><ChevronRight size={18} aria-hidden="true"/></button>)}</div>:<div className="c7-empty"><Search size={26}/><h2>{tr?'Sonuç bulunamadı':'No results found'}</h2><SecondaryActionButton onClick={()=>{setQuery('');setCategory('all')}}>{tr?'Aramayı temizle':'Clear search'}</SecondaryActionButton></div>}
        <div className="c7-section-heading"><h2>{tr?'Bir sorun mu var?':'Need a hand?'}</h2></div><div className="uf-group-list"><button type="button" className="uf-topic-row" onClick={event=>{trigger.current=event.currentTarget;setTroubleshooting(true)}}><HardDrive size={20}/><span>{tr?'Adım adım sorun giderme':'Step-by-step troubleshooting'}</span><ChevronRight size={18}/></button></div>
      </>}
    </div>
  </ScreenShell>
}

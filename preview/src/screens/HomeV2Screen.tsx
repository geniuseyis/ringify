// User-selected Ringify 2.0 Home. Retains real loading/project/navigation callbacks.
import {ArrowUpRight,ChevronRight,FolderOpen,Mic2,Scissors,Settings2,ShieldCheck} from 'lucide-react'
import type {Language,ProjectSummary,ScreenId} from '../types'
import {ScreenShell} from '../components/ScreenShell'
import {LogoMark} from '../components/LogoMark'
import {EmptyStateView,LoadingStateView,LocalProcessingNote,ProjectCard,SignatureArtwork} from '../designSystem/StudioComponents'
import {designVariables} from '../designSystem/tokens'

export function HomeV2Screen({language,projects,isLoading,onNavigate,onOpenProject}:{language:Language;projects:ProjectSummary[];isLoading:boolean;onNavigate:(screen:ScreenId)=>void;onOpenProject:(project:ProjectSummary)=>void}){
  const isTr=language==='tr'
  const shortcuts=[
    {screen:'recorder',icon:Mic2,label:isTr?'Ses Kaydet':'Record'},
    {screen:'library',icon:FolderOpen,label:isTr?'Kütüphane':'Library'},
    {screen:'guide',icon:ShieldCheck,label:isTr?'Nasıl Ayarlanır?':'Setup Guide'},
  ] as const
  return <ScreenShell className="home-screen v2-screen v2-home av-screen av-home" style={designVariables}>
    <header className="r-home-header"><div><LogoMark size={35}/><span className="r-wordmark-detail">{isTr?'KİŞİSEL SES STÜDYON':'YOUR PERSONAL AUDIO STUDIO'}</span></div><button type="button" className="r-icon" aria-label={isTr?'Ayarlar':'Settings'} onClick={()=>onNavigate('settings')}><Settings2 size={21} aria-hidden="true"/></button></header>
    <section className="r-home-feature" aria-labelledby="home-title"><SignatureArtwork/><div className="r-feature-copy"><span className="r-eyebrow">{isTr?'HER SES BİR BAŞLANGIÇ.':'EVERY SOUND IS A BEGINNING.'}</span><h1 id="home-title">{isTr?'Sesini imzana dönüştür.':'Turn sound into your signature.'}</h1><p>{isTr?'Bir anı seç. Kendine ait bir ses yarat.':'Choose a moment. Make it sound like you.'}</p></div>
      <button type="button" className="r-create hero-action" aria-label={isTr?'Yeni Zil Sesi Oluştur Video, ses veya mikrofon':'Create New Ringtone Video, audio or microphone'} onClick={()=>onNavigate('import')}><span className="r-create-symbol" aria-hidden="true"><Scissors size={23} strokeWidth={1.7}/></span><span className="r-create-copy"><strong>{isTr?'Yeni Zil Sesi Oluştur':'Create New Ringtone'}</strong><small>{isTr?'Video, ses veya mikrofon':'Video, audio or microphone'}</small></span><ArrowUpRight size={23} aria-hidden="true"/></button>
    </section>
    <section className="r-shortcut-panel" aria-label={isTr?'Hızlı erişim':'Quick actions'}><div className="r-shortcut-heading"><span>{isTr?'Hızlı araçlar':'Quick tools'}</span><span>{isTr?'İçe aktar. Düzenle. Dinle.':'Import. Edit. Listen.'}</span></div><div className="r-shortcuts">{shortcuts.map(({screen,icon:Icon,label})=><button type="button" key={screen} onClick={()=>onNavigate(screen)}><span className="r-shortcut-icon"><Icon size={22} strokeWidth={1.7} aria-hidden="true"/></span><span>{label}</span></button>)}</div></section>
    <section className="r-recents" aria-labelledby="recent-title"><div className="r-section-heading"><div><span className="r-eyebrow">{isTr?'KALDIĞIN YERDEN':'PICK UP WHERE YOU LEFT OFF'}</span><h2 id="recent-title">{isTr?'Son projeler':'Recent projects'}</h2></div><button type="button" className="r-text-action" aria-label={isTr?'Tümü':'See all'} onClick={()=>onNavigate('library')}>{isTr?'Tümü':'See all'}<ChevronRight size={15} aria-hidden="true"/></button></div>
      {isLoading?<LoadingStateView label={isTr?'Projeler yükleniyor…':'Loading projects…'}/>:projects.length===0?<EmptyStateView title={isTr?'İlk zil sesini oluştur':'Create your first ringtone'} description={isTr?'İçe aktardığın sesler ve taslakların burada.':'Your imported sounds and drafts will live here.'}/>:<div className="r-projects">{projects.slice(0,3).map(project=><ProjectCard key={project.id} project={project} language={language} onOpen={()=>onOpenProject(project)}/>)}</div>}
    </section><LocalProcessingNote language={language}/>
  </ScreenShell>
}

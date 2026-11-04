import {ArrowRight,ArrowUpRight,ChevronRight,Crown,FolderOpen,HelpCircle,Mic2,Plus,Scissors} from 'lucide-react'
import type {Language,ProjectSummary,ScreenId} from '../types'
import {ScreenShell} from '../components/ScreenShell'
import {EmptyStateView,LoadingStateView} from '../designSystem/StudioComponents'
import {GroupedSection,ProjectListRow} from '../designSystem/AppleV2Components'
import {designVariables,formatStudioTime} from '../designSystem/tokens'

interface HomeScreenProps {
  language:Language
  projects:ProjectSummary[]
  isLoading:boolean
  onNavigate:(screen:ScreenId)=>void
  onOpenProject:(project:ProjectSummary)=>void
}

// Historical Apple V2 proposal remains reviewable; the active Home is the user's 2.0 choice.
export {HomeV2Screen as HomeScreen} from './HomeV2Screen'
export function HomeAppleV2Screen({language,projects,isLoading,onNavigate,onOpenProject}:HomeScreenProps){
  const isTr=language==='tr'
  const resume=projects.find(project=>project.status==='draft')
  const exports=projects.filter(project=>project.status==='exported').slice(0,2)
  const shortcuts=[
    {screen:'import',icon:Scissors,label:isTr?'Ses Kes':'Trim Audio'},
    {screen:'recorder',icon:Mic2,label:isTr?'Ses Kaydet':'Record'},
    {screen:'import',icon:FolderOpen,label:isTr?'İçe Aktar':'Import'},
  ] as const
  return <ScreenShell className="home-screen v2-screen v2-home v3-screen v3-home" style={designVariables}>
    <header className="n3-home-header"><h1>Ringify</h1><button type="button" className="n3-pro-link" aria-label="Ringify Pro" onClick={()=>onNavigate('premium')}><Crown size={17} aria-hidden="true"/>Pro</button></header>
    <button type="button" className="r-create n3-create" aria-label={isTr?'Yeni Zil Sesi Oluştur Video, ses veya mikrofon':'Create New Ringtone Video, audio or microphone'} onClick={()=>onNavigate('import')}>
      <span className="n3-create-icon" aria-hidden="true"><Plus size={28} strokeWidth={1.7}/></span>
      <span className="n3-create-copy"><strong>{isTr?'Yeni Zil Sesi Oluştur':'Create New Ringtone'}</strong><small>{isTr?'Müzik, video veya ses kaydından':'From music, video or a voice recording'}</small></span><ArrowUpRight size={19} aria-hidden="true"/>
    </button>
    <div className="n3-shortcuts" role="group" aria-label={isTr?'Hızlı erişim':'Quick actions'}>{shortcuts.map(({screen,icon:Icon,label})=><button type="button" key={label} onClick={()=>onNavigate(screen)}><Icon size={24} strokeWidth={1.7} aria-hidden="true"/><span>{label}</span></button>)}</div>
    <GroupedSection title={isTr?'Son projeler':'Recent projects'} action={<button type="button" className="n3-text-link" aria-label={isTr?'Tümü':'See all'} onClick={()=>onNavigate('library')}>{isTr?'Tümünü gör':'See all'}<ChevronRight size={14} aria-hidden="true"/></button>}>
      {isLoading?<LoadingStateView label={isTr?'Projeler yükleniyor…':'Loading projects…'}/>:projects.length===0?<EmptyStateView title={isTr?'İlk zil sesini oluştur':'Create your first ringtone'} description={isTr?'Bir ses ekle. Düzenlediğin projeler burada saklanır.':'Add a sound. Your editing projects will be saved here.'}/>:<div className="n3-project-list r-projects">{projects.slice(0,3).map(project=><ProjectListRow key={project.id} project={project} language={language} onOpen={()=>onOpenProject(project)}/>)}</div>}
    </GroupedSection>
    {!isLoading&&resume?<GroupedSection title={isTr?'Kaldığın yerden devam et':'Continue editing'}><button type="button" className="n3-resume" aria-label={isTr?`Çalışmaya devam et: ${resume.name}`:`Continue editing: ${resume.name}`} onClick={()=>onOpenProject(resume)}><Scissors size={23} aria-hidden="true"/><span><strong>{resume.name}</strong><small>{formatStudioTime(resume.duration)} · {isTr?'Düzenlemeye devam et':'Continue your edit'}</small></span><ArrowRight size={19} aria-hidden="true"/></button></GroupedSection>:null}
    {!isLoading&&exports.length?<GroupedSection title={isTr?'Son dışa aktarılanlar':'Recent exports'}><div className="n3-project-list">{exports.map(project=><ProjectListRow key={project.id} project={project} language={language} onOpen={()=>onOpenProject(project)}/>)}</div></GroupedSection>:null}
    <button type="button" className="n3-help-link" onClick={()=>onNavigate('guide')}><HelpCircle size={18} aria-hidden="true"/>{isTr?'iPhone’da zil sesi nasıl ayarlanır?':'How do I set a ringtone on iPhone?'}</button>
  </ScreenShell>
}

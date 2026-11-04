import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { CheckCircle2, X } from 'lucide-react'
import type { AppSettings, EditorState, ProjectSummary, ScreenId, ToastMessage } from './types'
import { calculatePeaks, createDemoBuffer, createDemoPeaks, decodeAudioFile, encodeSelectionAsWav } from './lib/audio'
import { defaultSettings, loadSettings, resetPreviewData, saveSettings } from './lib/storage'
import { mediaBlob } from './lib/projectRepository'
import { shareAudioFile } from './lib/sharing'
import { useProjectLibrary } from './hooks/useProjectLibrary'
import { canCreateProject,canChangeNormalization,canChangeStudioEffects,ProjectLimitError } from './lib/proAccess'
import { sanitizeFileName } from './lib/format'
import { PhoneFrame } from './components/PhoneFrame'
import { TabBar } from './components/TabBar'
import { SplashScreen, OnboardingScreen, HomeScreen, ImportScreen } from './screens/StartScreens'
import {fitRecordingMarkers,validateAudioMarkers} from './lib/audioMarkers'
import type {AudioMarker} from './types'
import { EditorScreen, EffectsScreen, RecorderScreen } from './screens/EditorScreens'
import {StudioEmptyScreen} from './screens/StudioScreen'
import type {LibraryOperations} from './screens/LibraryTools'
import type {HelpTopicId} from './screens/helpContent'
import type {SettingsPage} from './screens/SettingsScreen'
import {AudioConversionScreen} from './screens/AudioConversionScreen'
import { ExportScreen, RingtoneGuideScreen, RingtonePreviewScreen } from './screens/OutputScreens'
import { HelpScreen, LibraryScreen } from './screens/LibraryScreens'
import { PremiumScreen, SettingsScreen } from './screens/PremiumSettingsScreens'
import './styles.css'
import './designSystem/studio.css'
import './designSystem/buttonEffects.css'
import './designSystem/appleV2.css'
import './designSystem/appleV2Flows.css'
import './designSystem/appleVercel.css'

const initialEditor: EditorState = {
  asset: {
    fileName: 'ringify-demo.wav',
    duration: 24,
    peaks: createDemoPeaks(),
    buffer: null,
    isDemo: true,
  },
  trimStart: 2.4,
  trimEnd: 20.8,
  effects: { volume: 1, fadeIn: 0.4, fadeOut: 0.7, normalize: false },
  projectName: 'Yeni Zil Sesim',
}

const tabScreens: ScreenId[] = ['home', 'studio', 'library', 'settings']

function resolvedTheme(settings: AppSettings): 'light' | 'dark' {
  if (settings.theme !== 'system') return settings.theme
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

export default function App() {
  const [settings, setSettings] = useState<AppSettings>(() => loadSettings())
  const [editor, setEditor] = useState<EditorState>(initialEditor)
  const [screen, setScreen] = useState<ScreenId>('splash')
  const [helpTopic,setHelpTopic]=useState<HelpTopicId|undefined>()
  const [settingsPage,setSettingsPage]=useState<SettingsPage>('root')
  const navigationHistory = useRef<ScreenId[]>([])
  const [isImporting, setIsImporting] = useState(false)
  const creationBusy=useRef(false)
  const mediaJob=useRef<AbortController|null>(null)
  useEffect(()=>()=>mediaJob.current?.abort(),[])
  const [projectLimitReached,setProjectLimitReached]=useState(false)
  const [importError, setImportError] = useState<string | null>(null)
  const [toasts, setToasts] = useState<ToastMessage[]>([])
  const [themeTick, setThemeTick] = useState(0)
  const [storageError, setStorageError] = useState<string | null>(null)
  const reportStorageError = useCallback(() => setStorageError('Ses/proje kaydedilemedi. Depolama iznini ve boş alanı kontrol edin. / Audio could not be saved. Check storage permissions and space.'), [])
  // A legacy browser preference never establishes an Apple purchase entitlement.
  const hasVerifiedPro=false
  const library = useProjectLibrary(reportStorageError,{hasVerifiedPro,language:settings.language})
  const { projects, loading: isLoadingProjects } = library

  const language = settings.language
  const theme = useMemo(() => resolvedTheme(settings), [settings, themeTick])

  useEffect(() => {
    const timer = window.setTimeout(() => setScreen(settings.onboardingSeen ? 'home' : 'onboarding'), 720)
    return () => window.clearTimeout(timer)
  }, [])

  useEffect(() => {
    try { saveSettings(settings) } catch { reportStorageError() }
  }, [settings, reportStorageError])

  useEffect(() => {
    if (editor.projectID && editor.asset.buffer) void library.save(editor).catch(reportStorageError)
  }, [editor, library.save, reportStorageError])

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)')
    const update = () => setThemeTick((value) => value + 1)
    media.addEventListener('change', update)
    return () => media.removeEventListener('change', update)
  }, [])

  useEffect(() => {
    document.documentElement.dataset.theme = theme
    document.documentElement.lang = language
  }, [language, theme])

  const navigate = useCallback((next: ScreenId) => {
    mediaJob.current?.abort()
    if(next==='help')setHelpTopic(undefined)
    navigationHistory.current = [...navigationHistory.current.slice(-12), screen]
    setScreen(next)
  }, [screen])

  const navigateTab = (next: ScreenId) => {
    mediaJob.current?.abort()
    if(next==='settings'&&screen==='settings')setSettingsPage('root')
    navigationHistory.current = []
    setScreen(next)
  }

  const goBack = (fallback: ScreenId = 'home') => {
    mediaJob.current?.abort()
    setScreen(navigationHistory.current.pop() ?? fallback)
  }

  const finishOnboarding = () => {
    const next = { ...settings, onboardingSeen: true }
    setSettings(next)
    navigationHistory.current = []
    setScreen('home')
  }

  const showToast = useCallback((message: string, tone: ToastMessage['tone'] = 'neutral') => {
    const id = Date.now() + Math.random()
    setToasts((items) => [...items, { id, message, tone }])
    window.setTimeout(() => setToasts((items) => items.filter((item) => item.id !== id)), 3200)
  }, [])

  const canStartProject = () => {
    if(canCreateProject(projects.length,hasVerifiedPro))return true
    setProjectLimitReached(true)
    setImportError(new ProjectLimitError(language,hasVerifiedPro).message)
    setScreen('import')
    return false
  }
  const changeEditor = (next:EditorState) => {
    if(!canChangeNormalization(editor.effects.normalize,next.effects.normalize,hasVerifiedPro)){navigate('premium');return}
    if(!canChangeStudioEffects(editor.effects,next.effects,hasVerifiedPro)){navigate('premium');return}
    setEditor(next)
  }
  const loadFile = async (file: File, markers?: AudioMarker[]) => {
    if(creationBusy.current||!canStartProject())return
    creationBusy.current=true
    mediaJob.current?.abort()
    const job=new AbortController();mediaJob.current=job
    setProjectLimitReached(false)
    setImportError(null)
    setIsImporting(true)
    try {
      const decoded = await decodeAudioFile(file,job.signal)
      job.signal.throwIfAborted()
      if (decoded.duration < 1) throw new Error(language === 'tr' ? 'Dosya en az 1 saniye olmalı.' : 'The file must be at least 1 second long.')
      const next: EditorState = {
        ...(markers===undefined?{}:{markers:fitRecordingMarkers(markers,decoded.duration)}),
        projectID: crypto.randomUUID(),
        asset: { fileName: file.name, duration: decoded.duration, peaks: decoded.peaks, buffer: decoded.buffer, sourceBlob: file, isDemo: false },
        trimStart: 0,
        trimEnd: Math.min(29, decoded.duration),
        effects: { volume: 1, fadeIn: 0, fadeOut: 0, normalize: false },
        projectName: sanitizeFileName(file.name.replace(/\.[^.]+$/, '')) || (language === 'tr' ? 'Yeni Zil Sesim' : 'My New Ringtone'),
      }
      await library.save(next)
      job.signal.throwIfAborted()
      setStorageError(null)
      setEditor(next)
      navigationHistory.current.push('import')
      setScreen('editor')
    } catch (error) {
      if(job.signal.aborted)return
      setProjectLimitReached(error instanceof ProjectLimitError)
      const message = error instanceof Error && error.message
        ? error.message
        : (language === 'tr' ? 'Tarayıcı bu dosyanın ses akışını çözemedi. WAV, MP3 veya M4A dene.' : 'The browser could not decode this audio stream. Try WAV, MP3 or M4A.')
      setImportError(message)
      setScreen('import')
    } finally {
      if(mediaJob.current===job)mediaJob.current=null
      creationBusy.current=false
      setIsImporting(false)
    }
  }

  const loadDemoAudio = async () => {
    if(creationBusy.current||!canStartProject())return
    creationBusy.current=true
    setIsImporting(true)
    setProjectLimitReached(false)
    setImportError(null)
    try {
      const buffer = createDemoBuffer(24)
      const next: EditorState = {
        ...initialEditor,
        projectID: crypto.randomUUID(),
        asset: { ...initialEditor.asset, buffer, sourceBlob: encodeSelectionAsWav(buffer, 0, buffer.duration, {volume:1,fadeIn:0,fadeOut:0,normalize:false}), peaks: calculatePeaks(buffer, 240), isDemo: true },
        projectName: language === 'tr' ? 'Mor Ufuk' : 'Violet Horizon',
      }
      await library.save(next)
      setEditor(next)
      navigationHistory.current.push('import')
      setScreen('editor')
    } catch (error) {
      setProjectLimitReached(error instanceof ProjectLimitError)
      setImportError(error instanceof ProjectLimitError?error.message:language === 'tr' ? 'Tarayıcı ses motorunu başlatamadı. Sayfaya dokunup tekrar dene.' : 'The browser could not start its audio engine. Interact with the page and try again.')
    } finally {
      creationBusy.current=false
      setIsImporting(false)
    }
  }

  const openProject = async (project: ProjectSummary) => {
    mediaJob.current?.abort()
    const job=new AbortController();mediaJob.current=job
    try {
      const saved = await library.get(project.id)
      job.signal.throwIfAborted()
      if (!saved?.source) throw new Error(language === 'tr' ? 'Bu eski kayıtta ses dosyası yok. Kaynağı yeniden içe aktarın.' : 'This legacy record has no audio. Import the source again.')
      const sourceBlob = mediaBlob(saved.source)
      const decoded = await decodeAudioFile(sourceBlob,job.signal)
      job.signal.throwIfAborted()
      setEditor({ projectID: saved.id,
        asset: { fileName: saved.summary.sourceName, ...decoded, sourceBlob, isDemo: saved.summary.isDemo ?? false },
        trimStart: saved.summary.trimStart, trimEnd: saved.summary.trimEnd,
        effects: { ...saved.effects }, projectName: saved.summary.name,
        markers: validateAudioMarkers(saved.markers,decoded.duration) })
      navigate('editor')
    } catch (error) {
      if(job.signal.aborted)return
      showToast(error instanceof Error ? error.message : 'Proje açılamadı / Could not open project', 'error')
    }finally{if(mediaJob.current===job)mediaJob.current=null}
  }

  const saveExportedProject = async (fileName: string, output: Blob) => {
    try { await library.save(editor, output, fileName); setStorageError(null) }
    catch (error) { reportStorageError(); throw error }
  }

  const shareProject = async (project: ProjectSummary) => {
    const saved = await library.get(project.id)
    if (!saved?.output) throw new Error(language === 'tr' ? 'Önce projeyi WAV olarak dışa aktarın.' : 'Export the project as WAV first.')
    await shareAudioFile(mediaBlob(saved.output), project.name)
  }

  const updateSettings = (next: AppSettings) => setSettings(next)
  const resetData = async () => {
    mediaJob.current?.abort()
    try {
      await library.clear()
      setProjectLimitReached(false)
      setImportError(null)
      setEditor(initialEditor)
      resetPreviewData()
      setSettings({ ...defaultSettings })
      navigationHistory.current = []
      setScreen('onboarding')
      showToast(language === 'tr' ? 'Yerel veriler sıfırlandı.' : 'Local data reset.', 'success')
    } catch (error) { reportStorageError(); throw error }
  }

  const libraryOperations=useMemo<LibraryOperations>(()=>({
    pro:hasVerifiedPro,onRequirePro:()=>navigate('premium'),patch:library.patch,duplicate:library.duplicate,
    removeMany:async(ids)=>{mediaJob.current?.abort();await library.removeMany(ids);setEditor(current=>ids.includes(current.projectID??'')?initialEditor:current)},
    collections:()=>library.repository.collections(),createCollection:library.createCollection,deleteCollection:library.deleteCollection,
    history:id=>library.repository.history(id),exportMedia:id=>library.repository.exportMedia(id),deleteExport:id=>library.repository.deleteExport(id),storage:()=>library.repository.storageBytes(),
  }),[hasVerifiedPro,navigate,library.patch,library.duplicate,library.removeMany,library.repository,library.createCollection,library.deleteCollection])
  let content
  switch (screen) {
    case 'splash':
      content = <SplashScreen language={language} />
      break
    case 'onboarding':
      content = <OnboardingScreen language={language} onFinish={finishOnboarding} />
      break
    case 'home':
      content = <HomeScreen language={language} projects={projects} isLoading={isLoadingProjects} onNavigate={navigate} onOpenProject={openProject} />
      break
    case 'import':
      content = <ImportScreen language={language} isLoading={isImporting} error={importError} projectLimitReached={projectLimitReached} onBack={() => goBack('home')} onChooseFile={loadFile} onUseDemo={loadDemoAudio} onNavigate={navigate} onClearError={() => {setImportError(null);setProjectLimitReached(false)}} />
      break
    case 'conversion':
      content=<AudioConversionScreen language={language} onBack={()=>goBack('import')}/>
      break
    case 'recorder':
      content = <RecorderScreen language={language} onBack={() => goBack('import')} onUseRecording={loadFile} />
      break
    case 'studio':
    case 'editor':
      content = editor.asset.buffer
        ? <EditorScreen language={language} editor={editor} onChange={changeEditor} onBack={() => screen==='studio'?navigateTab('home'):goBack('import')} onContinue={() => navigate('effects')} />
        : <StudioEmptyScreen language={language} onNavigate={navigate} />
      break
    case 'effects':
      content = <EffectsScreen language={language} editor={editor} canNormalize={hasVerifiedPro} canAdvancedEffects={hasVerifiedPro} onRequirePro={() => navigate('premium')} onChange={changeEditor} onBack={() => goBack('editor')} onContinue={() => navigate('ringtonePreview')} />
      break
    case 'ringtonePreview':
      content = <RingtonePreviewScreen language={language} editor={editor} onChange={changeEditor} onBack={() => goBack('effects')} onEdit={()=>navigate('editor')} onExport={() => navigate('export')} />
      break
    case 'export':
      content = <ExportScreen language={language} editor={editor} canHighPrecision={hasVerifiedPro} onRequirePro={()=>navigate('premium')} onBack={() => goBack('ringtonePreview')} onComplete={saveExportedProject} onGuide={() => navigate('guide')} onDone={() => navigateTab('library')} />
      break
    case 'guide':
      content = <RingtoneGuideScreen language={language} onBack={() => goBack('home')} onDone={() => navigateTab('home')} />
      break
    case 'library':
      content = <LibraryScreen language={language} projects={projects} operations={libraryOperations} isLoading={isLoadingProjects} onOpenProject={openProject} onCreate={() => navigate('import')} onShare={shareProject} onUpdateProjects={async (next) => {
        mediaJob.current?.abort()
        await library.update(next)
        setEditor(current=>{if(!current.projectID)return current;const row=next.find(item=>item.id===current.projectID);return !row?initialEditor:row.name!==current.projectName?{...current,projectName:row.name}:current})
      }} />
      break
    case 'premium':
      content = <PremiumScreen language={language} onNavigate={navigate} onBack={()=>goBack('home')} />
      break
    case 'settings':
      content = <SettingsScreen settings={settings} language={language} storageCount={projects.length} activePage={settingsPage} onPageChange={setSettingsPage} onReadStorage={libraryOperations.storage} onChange={updateSettings} onHelp={topic=>{navigate('help');setHelpTopic(topic)}} onResetData={resetData} onToast={showToast} onOpenLibrary={() => navigateTab('library')} onOpenPremium={() => navigate('premium')} />
      break
    case 'help':
      content = <HelpScreen language={language} initialTopic={helpTopic} onBack={() => goBack('settings')} onNavigate={navigate} />
      break
  }

  const showTabs = tabScreens.includes(screen)||screen==='editor'
  const isV3Screen = screen!=='home'
  return (
    <PhoneFrame theme={theme} minimalChrome={isV3Screen||screen==='home'}>
      <div className={`ringify-app ${showTabs ? 'has-tabs' : ''}${isV3Screen?' is-v3-screen':''}`}>
        {storageError ? <div className="storage-error" role="alert"><span>{storageError}</span><button onClick={() => {
          void library.retry().then(() => library.save(editor)).then(() => setStorageError(null)).catch(reportStorageError)
        }}>{language === 'tr' ? 'Tekrar Dene' : 'Retry'}</button></div> : null}
        {content}
        {showTabs ? <TabBar active={screen==='editor'?'studio':screen} language={language} onNavigate={navigateTab} /> : null}
        <div className="toast-stack" aria-live="polite">
          {toasts.map((toast) => (
            <div className={`toast toast-${toast.tone ?? 'neutral'}`} key={toast.id}>
              {toast.tone === 'success' ? <CheckCircle2 size={18} /> : null}
              <span>{toast.message}</span>
              <button onClick={() => setToasts((items) => items.filter((item) => item.id !== toast.id))} aria-label="Kapat"><X size={16} /></button>
            </div>
          ))}
        </div>
      </div>
    </PhoneFrame>
  )
}

import type { ComponentProps } from 'react'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ImportScreen, RecorderScreen } from './CaptureScreens'
import { useVoiceRecorder } from '../hooks/useVoiceRecorder'

// Presentation contracts only. The recorder hook/media lifecycle has separate tests.
vi.mock('../hooks/useVoiceRecorder', () => ({ useVoiceRecorder: vi.fn() }))

const recorder = {
  status: 'idle' as const,
  seconds: 0,
  level: 0,
  audioUrl: null as string | null,
  recordedFile: null as File | null,
  error: null as string | null,
  start: vi.fn().mockResolvedValue(undefined),
  stop: vi.fn(),
  discard: vi.fn(),
  currentTime: () => 0,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(useVoiceRecorder).mockReturnValue({ ...recorder })
})
afterEach(cleanup)

describe('Recording bookmarks',()=>{
  it('carries the active recorder clock through to the real recording import callback',()=>{
    const file=new File(['recording'],'voice.webm',{type:'audio/webm'})
    recorderState({status:'recording',seconds:1.5,currentTime:()=>1.625})
    const view=renderRecorder()
    fireEvent.click(screen.getByRole('button',{name:/İşaret Ekle/}))
    recorderState({status:'ready',seconds:3,recordedFile:file,currentTime:()=>3})
    view.rerender(<RecorderScreen language="tr" onBack={view.onBack} onUseRecording={view.onUseRecording}/>)
    fireEvent.click(screen.getByRole('button',{name:'Kaydı Kullan'}))
    expect(view.onUseRecording).toHaveBeenCalledWith(file,[expect.objectContaining({time:1.625,label:'İşaret 1'})])
  })
})

function renderImport(overrides: Partial<ComponentProps<typeof ImportScreen>> = {}) {
  const props = {
    language: 'tr' as const,
    isLoading: false,
    error: null as string | null,
    onBack: vi.fn(),
    onChooseFile: vi.fn(),
    onUseDemo: vi.fn(),
    onNavigate: vi.fn(),
    onClearError: vi.fn(),
    ...overrides,
  }
  return { ...render(<ImportScreen {...props} />), ...props }
}

function renderRecorder(overrides: Partial<ComponentProps<typeof RecorderScreen>> = {}) {
  const props = { language: 'tr' as const, onBack: vi.fn(), onUseRecording: vi.fn(), ...overrides }
  return { ...render(<RecorderScreen {...props} />), ...props }
}

function recorderState(overrides: Partial<ReturnType<typeof useVoiceRecorder>>) {
  vi.mocked(useVoiceRecorder).mockReturnValue({ ...recorder, ...overrides })
}

describe('Media Import presentation contracts', () => {
  it('connects source cards to the matching local audio/video pickers', () => {
    const { container } = renderImport()
    const audio = container.querySelector<HTMLInputElement>('input[type="file"][accept^="audio/"]')!
    const video = container.querySelector<HTMLInputElement>('input[type="file"][accept^="video/"]')!
    expect(audio).toHaveAttribute('accept', 'audio/*,.mp3,.m4a,.aac,.wav')
    expect(video).toHaveAttribute('accept', 'video/*,.mp4,.mov,.webm')
    const chooseAudio = vi.spyOn(audio, 'click').mockImplementation(() => undefined)
    const chooseVideo = vi.spyOn(video, 'click').mockImplementation(() => undefined)
    fireEvent.click(screen.getByRole('button', { name: 'Dosyalar’dan ses' }))
    expect(chooseAudio).toHaveBeenCalledOnce()
    fireEvent.click(screen.getByRole('button', { name: 'Fotoğraflar’dan video' }))
    fireEvent.click(screen.getByRole('button', { name: 'Dosyalar’dan video' }))
    expect(chooseVideo).toHaveBeenCalledTimes(2)
  })

  it('passes the selected File unchanged, clears the picker value and ignores cancellation', () => {
    const { onChooseFile } = renderImport()
    const inputs = [
      screen.getByLabelText('Ses dosyası seç') as HTMLInputElement,
      screen.getByLabelText('Video dosyası seç') as HTMLInputElement,
    ]
    const files = [
      new File(['local audio bytes'], 'kayit.wav', { type: 'audio/wav' }),
      new File(['local video bytes'], 'kayit.mov', { type: 'video/quicktime' }),
    ]
    inputs.forEach((input, index) => {
      // jsdom forbids setting a native file input to a nonempty path; expose only
      // its value property here so the reset assignment itself remains observable.
      Object.defineProperty(input, 'value', { configurable: true, writable: true, value: `C:\\fakepath\\${files[index].name}` })
      fireEvent.change(input, { target: { files: [files[index]] } })
      expect(onChooseFile).toHaveBeenLastCalledWith(files[index])
      expect(input.value).toBe('')
    })
    expect(onChooseFile).toHaveBeenCalledTimes(2)
    fireEvent.change(inputs[0], { target: { files: [] } })
    expect(onChooseFile).toHaveBeenCalledTimes(2)
  })

  it('connects demo, microphone navigation and back without selecting fake media', () => {
    const { onUseDemo, onNavigate, onBack, onChooseFile } = renderImport()
    fireEvent.click(screen.getByRole('button', { name: 'Telif içermeyen demo sesi kullan' }))
    fireEvent.click(screen.getByRole('button', { name: 'Mikrofonla kaydet' }))
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onUseDemo).toHaveBeenCalledOnce()
    expect(onNavigate).toHaveBeenCalledExactlyOnceWith('recorder')
    expect(onBack).toHaveBeenCalledOnce()
    expect(onChooseFile).not.toHaveBeenCalled()
  })

  it('announces loading and hides file source controls while keeping back functional', () => {
    const { container, onBack } = renderImport({ isLoading: true })
    expect(screen.getByRole('status')).toHaveTextContent('Ses akışı analiz ediliyor…')
    expect(container.querySelector('input[type="file"]')).toBeNull()
    expect(screen.queryByRole('button', { name: 'Dosyalar’dan ses' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Telif içermeyen demo sesi kullan' })).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onBack).toHaveBeenCalledOnce()
  })

  it('shows the real import failure and routes retry to error recovery', () => {
    const { onClearError, onChooseFile } = renderImport({ error: 'Desteklenmeyen codec' })
    expect(screen.getByRole('alert')).toHaveTextContent('Desteklenmeyen codec')
    fireEvent.click(screen.getByRole('button', { name: 'Tekrar Dene' }))
    expect(onClearError).toHaveBeenCalledOnce()
    expect(onChooseFile).not.toHaveBeenCalled()
  })

  it('localizes the import actions in English and retains their callbacks', () => {
    const { onNavigate, onUseDemo } = renderImport({ language: 'en' })
    expect(screen.getByRole('heading', { name: 'Choose a source' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Video from Photos' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Audio from Files' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Video from Files' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Record with microphone' }))
    fireEvent.click(screen.getByRole('button', { name: 'Use royalty-free demo sound' }))
    expect(onNavigate).toHaveBeenCalledWith('recorder')
    expect(onUseDemo).toHaveBeenCalledOnce()
    expect(screen.queryByRole('button', { name: 'Mikrofonla kaydet' })).not.toBeInTheDocument()
  })
})

describe('Voice Recorder presentation contracts', () => {
  it('starts only on user action and reports zero input level while idle', () => {
    recorderState({ level: 0.8 })
    const { onBack } = renderRecorder()
    expect(useVoiceRecorder).toHaveBeenCalledWith('tr')
    expect(recorder.start).not.toHaveBeenCalled()
    expect(screen.getByRole('meter')).toHaveAttribute('aria-valuemin', '0')
    expect(screen.getByRole('meter')).toHaveAttribute('aria-valuemax', '1')
    expect(screen.getByRole('meter')).toHaveAttribute('aria-valuenow', '0')
    fireEvent.click(screen.getByRole('button', { name: 'Kaydı Başlat' }))
    expect(recorder.start).toHaveBeenCalledOnce()
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onBack).toHaveBeenCalledOnce()
  })

  it('shows measured recording level and elapsed time and connects stop', () => {
    recorderState({ status: 'recording', seconds: 12.5, level: 0.625 })
    renderRecorder()
    expect(screen.getByRole('meter')).toHaveAttribute('aria-valuenow', '0.625')
    expect(screen.getByText('0:12.5')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Kaydı Durdur' }))
    expect(recorder.stop).toHaveBeenCalledOnce()
    expect(recorder.start).not.toHaveBeenCalled()
  })

  it.each([
    ['requesting', 'Kaydı Başlat'],
    ['stopping', 'Kaydı Durdur'],
  ] as const)('disables the main action during %s rather than starting duplicate work', (status, name) => {
    recorderState({ status })
    renderRecorder()
    const action = screen.getByRole('button', { name })
    expect(action).toBeDisabled()
    fireEvent.click(action)
    expect(recorder.start).not.toHaveBeenCalled()
    expect(recorder.stop).not.toHaveBeenCalled()
    expect(screen.getByRole('meter')).toHaveAttribute('aria-valuenow', '0')
  })

  it('uses the actual ready File, keeps native audio preview and connects discard', () => {
    const recordedFile = new File(['recorded media'], 'ses.webm', { type: 'audio/webm' })
    recorderState({ status: 'ready', recordedFile, audioUrl: 'blob:ringify-recorded', seconds: 8, level: 0.7 })
    const { container, onUseRecording } = renderRecorder()
    const audio = container.querySelector('audio')
    expect(audio).toHaveAttribute('src', 'blob:ringify-recorded')
    expect(audio).toHaveAttribute('controls')
    expect(screen.getByRole('meter')).toHaveAttribute('aria-valuenow', '0')
    fireEvent.click(screen.getByRole('button', { name: 'Kaydı Kullan' }))
    expect(onUseRecording).toHaveBeenCalledExactlyOnceWith(recordedFile)
    fireEvent.click(screen.getByRole('button', { name: 'Kaydı Sil' }))
    expect(recorder.discard).not.toHaveBeenCalled()
    const dialog=screen.getByRole('dialog',{name:'Kayıt silinsin mi?'})
    fireEvent.click(within(dialog).getByRole('button',{name:'Kaydı Sil'}))
    expect(recorder.discard).toHaveBeenCalledOnce()
  })

  it('surfaces microphone errors and allows a deliberate retry without fake success', () => {
    recorderState({ status: 'error', error: 'Mikrofon izni reddedildi' })
    const { onUseRecording, container } = renderRecorder()
    expect(screen.getByRole('alert')).toHaveTextContent('Mikrofon izni reddedildi')
    expect(screen.queryByRole('button', { name: 'Kaydı Kullan' })).not.toBeInTheDocument()
    expect(container.querySelector('audio')).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: 'Kaydı Başlat' }))
    expect(recorder.start).toHaveBeenCalledOnce()
    expect(onUseRecording).not.toHaveBeenCalled()
  })

  it('passes English to the recorder hook and localizes the recording action', () => {
    recorderState({ status: 'recording', level: 0.2 })
    renderRecorder({ language: 'en' })
    expect(useVoiceRecorder).toHaveBeenCalledWith('en')
    expect(screen.getByRole('heading', { name: 'Voice Recorder' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Stop Recording' }))
    expect(recorder.stop).toHaveBeenCalledOnce()
    expect(screen.queryByRole('button', { name: 'Kaydı Durdur' })).not.toBeInTheDocument()
  })

  it.each(['Vazgeç','Kapat','Escape'])('preserves the ready File and URL when deletion is cancelled with %s',action=>{
    const recordedFile=new File(['recorded bytes'],'retained.webm',{type:'audio/webm'})
    recorderState({status:'ready',recordedFile,audioUrl:'blob:retained-recording',seconds:3})
    const {container,onUseRecording}=renderRecorder()
    const trigger=screen.getByRole('button',{name:'Kaydı Sil'})
    trigger.focus();fireEvent.click(trigger)
    const dialog=screen.getByRole('dialog',{name:'Kayıt silinsin mi?'})
    if(action==='Escape')fireEvent.keyDown(dialog,{key:'Escape'})
    else fireEvent.click(within(dialog).getByRole('button',{name:action}))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(recorder.discard).not.toHaveBeenCalled()
    expect(container.querySelector('audio')).toHaveAttribute('src','blob:retained-recording')
    expect(trigger).toHaveFocus()
    fireEvent.click(screen.getByRole('button',{name:'Kaydı Kullan'}))
    expect(onUseRecording).toHaveBeenCalledExactlyOnceWith(recordedFile)
  })

  it('localizes the ready-recording delete confirmation and requires its explicit English action',()=>{
    const recordedFile=new File(['recorded bytes'],'retained.webm',{type:'audio/webm'})
    recorderState({status:'ready',recordedFile,audioUrl:'blob:retained-recording'})
    renderRecorder({language:'en'})
    fireEvent.click(screen.getByRole('button',{name:'Delete Recording'}))
    expect(recorder.discard).not.toHaveBeenCalled()
    fireEvent.click(within(screen.getByRole('dialog',{name:'Delete this recording?'})).getByRole('button',{name:'Delete Recording'}))
    expect(recorder.discard).toHaveBeenCalledOnce()
  })
})

describe('Phase 4 import navigation',()=>{
  it('opens the real library without selecting or fabricating a new source file',()=>{
    const {onNavigate,onChooseFile,onUseDemo}=renderImport()
    fireEvent.click(screen.getByRole('button',{name:'Kayıtlı projeyi aç'}))
    expect(onNavigate).toHaveBeenCalledExactlyOnceWith('library')
    expect(onChooseFile).not.toHaveBeenCalled()
    expect(onUseDemo).not.toHaveBeenCalled()
  })
})

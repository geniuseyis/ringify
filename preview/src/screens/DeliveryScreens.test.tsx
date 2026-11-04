import type { ComponentProps } from 'react'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ExportScreen, RingtoneGuideScreen } from './DeliveryScreens'
import { useWavExport } from '../hooks/useWavExport'
import { emptyAudio } from '../test/audioFixtures'
import type { EditorState } from '../types'

// The export job is controlled at its hook boundary. These tests cover rendered
// states and callbacks, not WAV encoding, IndexedDB commits or URL ownership.
vi.mock('../hooks/useWavExport', () => ({ useWavExport: vi.fn() }))

const job = {
  status: 'idle' as const,
  error: null as string | null,
  result: null,
  stage:'processing' as const,
  start: vi.fn().mockResolvedValue(undefined),
  cancel: vi.fn(),
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(useWavExport).mockReturnValue({ ...job })
})
afterEach(cleanup)

function editorFixture(): EditorState {
  return {
    projectID: 'delivery-project', projectName: 'Vapur',
    asset: { fileName: 'vapur.wav', duration: 40, peaks: [0.1, 0.6, 0.3], buffer: emptyAudio(1, 4000, 100), isDemo: false },
    trimStart: 3, trimEnd: 23,
    effects: { volume: 0.75, fadeIn: 0.4, fadeOut: 0.8, normalize: true },
  }
}

function exportResult() {
  return { url: 'blob:ringify-verified-output', blob: new Blob(['verified-output'], { type: 'audio/wav' }), fileName: 'Vapur.wav', duration: 20,bitDepth:16 as const,sampleRate:100,channels:1 }
}

function exportState(overrides: Partial<ReturnType<typeof useWavExport>>) {
  vi.mocked(useWavExport).mockReturnValue({ ...job, ...overrides })
}

function renderExport(overrides: Partial<ComponentProps<typeof ExportScreen>> = {}) {
  const props = {
    language: 'tr' as const, editor: editorFixture(), onBack: vi.fn(),
    onComplete: vi.fn().mockResolvedValue(undefined), onGuide: vi.fn(), onDone: vi.fn(), ...overrides,
  }
  const rendered = render(<ExportScreen {...props} />)
  return { ...rendered, ...props, refresh: () => rendered.rerender(<ExportScreen {...props} />) }
}

function renderGuide(overrides: Partial<ComponentProps<typeof RingtoneGuideScreen>> = {}) {
  const props = { language: 'tr' as const, onBack: vi.fn(), onDone: vi.fn(), ...overrides }
  return { ...render(<RingtoneGuideScreen {...props} />), ...props }
}

describe('Export delivery presentation contracts', () => {
  it('uses output channel metadata, shows exact planned size and gates PCM24 to Pro',()=>{
    const editor=editorFixture();editor.asset.buffer=emptyAudio(2,4000,100)
    editor.effects={...editor.effects,studio:{low:0,mid:0,high:0,highPass:0,lowPass:0,channels:'mono',limiter:false,ceiling:.99}}
    const requirePro=vi.fn();renderExport({editor,onRequirePro:requirePro})
    expect(screen.getByText('Çıktı kanalları').parentElement).toHaveTextContent('Mono')
    expect(screen.getByText('WAV boyutu').parentElement).toHaveTextContent('4,04 kB')
    fireEvent.change(screen.getByRole('combobox',{name:'PCM hassasiyeti'}),{target:{value:'24'}})
    expect(requirePro).toHaveBeenCalledOnce();expect(screen.getByRole('combobox')).toHaveValue('16')
  })
  it('selects real PCM24 for an authorized profile and locks profile editing while busy',()=>{
    const view=renderExport({canHighPrecision:true})
    fireEvent.change(screen.getByRole('combobox',{name:'PCM hassasiyeti'}),{target:{value:'24'}})
    expect(useWavExport).toHaveBeenLastCalledWith(view.editor,view.onComplete,'tr',24)
    exportState({status:'preparing'});view.refresh();expect(screen.getByRole('combobox')).toBeDisabled()
  })
  it('passes the actual editor/persistence callback into the hook and starts with the bounded edited name', () => {
    const { editor, onComplete } = renderExport()
    expect(useWavExport).toHaveBeenCalledWith(editor, onComplete, 'tr',16)
    expect(job.start).not.toHaveBeenCalled()
    const name = screen.getByRole('textbox', { name: 'Dosya adı' })
    expect(name).toHaveValue(editor.projectName)
    expect(name).toHaveAttribute('maxlength', '64')
    fireEvent.change(name, { target: { value: 'Akşam Vapuru' } })
    fireEvent.click(screen.getByRole('button', { name: 'WAV Olarak Oluştur' }))
    expect(job.start).toHaveBeenCalledExactlyOnceWith('Akşam Vapuru')
    expect(onComplete).not.toHaveBeenCalled()
  })

  it('keeps idle back navigation functional without starting or cancelling a job', () => {
    const { onBack } = renderExport()
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onBack).toHaveBeenCalledOnce()
    expect(job.start).not.toHaveBeenCalled()
    expect(job.cancel).not.toHaveBeenCalled()
  })

  it('announces preparing without invented progress percentages and connects cancellation', () => {
    exportState({ status: 'preparing' })
    renderExport()
    expect(screen.getByRole('status')).not.toHaveTextContent(/\d+\s*%/)
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'İşlemi İptal Et' }))
    expect(job.cancel).toHaveBeenCalledOnce()
    expect(job.start).not.toHaveBeenCalled()
  })

  it('announces saving and does not offer unsafe cancellation during the storage commit', () => {
    exportState({ status: 'saving' })
    renderExport()
    expect(screen.getByRole('status')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'İşlemi İptal Et' })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Dosyayı İndir' })).not.toBeInTheDocument()
    expect(job.cancel).not.toHaveBeenCalled()
  })

  it('uses the actual successful result URL and connects guide/library exit actions', () => {
    const result = exportResult()
    exportState({ status: 'success', result })
    const { onGuide, onDone } = renderExport()
    const download = screen.getByRole('link', { name: 'Dosyayı İndir' })
    expect(download).toHaveAttribute('href', result.url)
    expect(download).toHaveAttribute('download', result.fileName)
    fireEvent.click(screen.getByRole('button', { name: 'iPhone’da Ayarlama Rehberi' }))
    fireEvent.click(screen.getByRole('button', { name: 'Kütüphaneye Git' }))
    expect(onGuide).toHaveBeenCalledOnce()
    expect(onDone).toHaveBeenCalledOnce()
    expect(job.start).not.toHaveBeenCalled()
  })

  it('shows the real export error and retries through the same explicit create action', () => {
    exportState({ status: 'error', error: 'Depolama kotası dolu' })
    renderExport()
    expect(screen.getByRole('alert')).toHaveTextContent('Depolama kotası dolu')
    expect(screen.queryByRole('link', { name: 'Dosyayı İndir' })).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'WAV Olarak Oluştur' }))
    expect(job.start).toHaveBeenCalledExactlyOnceWith('Vapur')
  })

  it('localizes both idle and successful delivery controls into English', () => {
    const { onGuide, onDone, refresh } = renderExport({ language: 'en' })
    expect(screen.getByRole('textbox', { name: 'File name' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Create WAV' })).toBeInTheDocument()
    exportState({ status: 'success', result: exportResult() })
    refresh()
    expect(screen.getByRole('link', { name: 'Download File' })).toHaveAttribute('href', 'blob:ringify-verified-output')
    fireEvent.click(screen.getByRole('button', { name: 'iPhone Setup Guide' }))
    fireEvent.click(screen.getByRole('button', { name: 'Go to Library' }))
    expect(onGuide).toHaveBeenCalledOnce()
    expect(onDone).toHaveBeenCalledOnce()
  })
})

describe('Ringtone setup guide presentation contracts', () => {
  it('starts with iOS 26+ selected and exposes real numbered steps and the official support link', () => {
    const { container } = renderGuide()
    expect(screen.getByRole('button', { name: /iOS\s*26\+/ })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: 'GarageBand' })).toHaveAttribute('aria-pressed', 'false')
    const list = container.querySelector('ol')!
    expect(list).toBeInTheDocument()
    expect(within(list).getAllByRole('listitem').length).toBeGreaterThanOrEqual(3)
    expect(screen.getByRole('link', { name: /Apple/ })).toHaveAttribute('href', 'https://support.apple.com/en-gu/120692')
  })

  it('switches methods with pressed states while retaining numbered instructions and source attribution', () => {
    const { container } = renderGuide()
    const initialSteps = container.querySelector('ol')!.textContent
    fireEvent.click(screen.getByRole('button', { name: 'GarageBand' }))
    expect(screen.getByRole('button', { name: 'GarageBand' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: /iOS\s*26\+/ })).toHaveAttribute('aria-pressed', 'false')
    const list = container.querySelector('ol')!
    expect(within(list).getAllByRole('listitem').length).toBeGreaterThanOrEqual(3)
    expect(list.textContent).not.toBe(initialSteps)
    expect(list).toHaveTextContent('GarageBand')
    expect(screen.getByRole('link', { name: /Apple/ })).toHaveAttribute('href', 'https://support.apple.com/en-gu/120692')
  })

  it('uses the explicit done callback and preserves independent back navigation', () => {
    const { onDone, onBack } = renderGuide()
    fireEvent.click(screen.getByRole('button', { name: 'Tamam' }))
    expect(onDone).toHaveBeenCalledOnce()
    expect(onBack).not.toHaveBeenCalled()
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onBack).toHaveBeenCalledOnce()
  })

  it('falls back to back navigation when no done callback is supplied', () => {
    const { onBack } = renderGuide({ onDone: undefined })
    fireEvent.click(screen.getByRole('button', { name: 'Tamam' }))
    expect(onBack).toHaveBeenCalledOnce()
  })

  it('localizes guide completion into English without changing the official support target', () => {
    const { onDone } = renderGuide({ language: 'en' })
    fireEvent.click(screen.getByRole('button', { name: 'Done' }))
    expect(onDone).toHaveBeenCalledOnce()
    expect(screen.getByRole('link', { name: /Apple/ })).toHaveAttribute('href', 'https://support.apple.com/en-gu/120692')
    expect(screen.queryByRole('button', { name: 'Tamam' })).not.toBeInTheDocument()
  })
})

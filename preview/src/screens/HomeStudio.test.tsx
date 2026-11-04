import { useState } from 'react'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { HomeScreen } from './StartScreens'
import { EditorScreen } from './EditorScreens'
import { useSegmentPlayer } from '../hooks/useSegmentPlayer'
import { emptyAudio } from '../test/audioFixtures'
import type { EditorState, ProjectSummary } from '../types'

// These tests exercise UI contracts with the real waveform and controlled playback.
// The existing segmentPlayer/audioProcessing suites verify the actual audio engine.
vi.mock('../hooks/useSegmentPlayer', () => ({ useSegmentPlayer: vi.fn() }))

const player = {
  isPlaying: false,
  playhead: 6,
  play: vi.fn().mockResolvedValue(undefined),
  stop: vi.fn(),
  error: null as string | null,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(useSegmentPlayer).mockReturnValue({ ...player })
})
afterEach(cleanup)

function project(index: number): ProjectSummary {
  return {
    id: `project-${index}`,
    name: `Kaydım ${index}`,
    sourceName: `kayit-${index}.wav`,
    duration: 15,
    trimStart: 2,
    trimEnd: 17,
    updatedAt: '2026-10-31T09:00:00.000Z',
    status: index % 2 ? 'draft' : 'exported',
  }
}

function renderHome(projects: ProjectSummary[] = [], isLoading = false) {
  const onNavigate = vi.fn()
  const onOpenProject = vi.fn()
  render(<HomeScreen language="tr" projects={projects} isLoading={isLoading}
    onNavigate={onNavigate} onOpenProject={onOpenProject} />)
  return { onNavigate, onOpenProject }
}

function initialEditor(): EditorState {
  return {
    projectID: 'existing-project',
    projectName: 'Boğaz Tınısı',
    asset: {
      fileName: 'Bosphorus.wav',
      duration: 40,
      peaks: [0.1, 0.4, 0.7, 0.3, 0.8, 0.5, 0.2, 0.6],
      buffer: emptyAudio(1, 4000, 100),
      isDemo: false,
    },
    trimStart: 6,
    trimEnd: 21,
    effects: { volume: 0.8, fadeIn: 0.3, fadeOut: 0.5, normalize: true },
  }
}

interface EditorHarnessProps {
  initial: EditorState
  onChange: (next: EditorState) => void
  onBack: () => void
  onContinue: () => void
}

function EditorHarness({ initial, onChange, onBack, onContinue }: EditorHarnessProps) {
  const [editor, setEditor] = useState(initial)
  return <EditorScreen language="tr" editor={editor} onChange={(next) => {
    setEditor(next)
    onChange(next)
  }} onBack={onBack} onContinue={onContinue} />
}

function renderEditor(initial = initialEditor()) {
  const props = { initial, onChange: vi.fn(), onBack: vi.fn(), onContinue: vi.fn() }
  const result = render(<EditorHarness {...props} />)
  return { ...result, ...props, refresh: () => result.rerender(<EditorHarness {...props} />) }
}

function expectTrim(start: number, end: number) {
  expect(screen.getByRole('slider', { name: 'Kesim başlangıcı' })).toHaveAttribute('aria-valuenow', String(start))
  expect(screen.getByRole('slider', { name: 'Kesim bitişi' })).toHaveAttribute('aria-valuenow', String(end))
}

describe('Ringify 3.0 Home contracts', () => {
  it('keeps the empty-state import action functional', () => {
    const { onNavigate, onOpenProject } = renderHome()
    expect(screen.getByRole('heading', { name: 'Sesini imzana dönüştür.' })).toBeInTheDocument()
    expect(screen.getByText('İlk zil sesini oluştur')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Yeni Zil Sesi Oluştur Video, ses veya mikrofon' }))
    expect(onNavigate).toHaveBeenCalledExactlyOnceWith('import')
    expect(onOpenProject).not.toHaveBeenCalled()
  })

  it('shows loading instead of stale projects or the empty state', () => {
    const { onNavigate } = renderHome([project(1)], true)
    expect(screen.getByRole('status')).toHaveTextContent('Projeler yükleniyor…')
    expect(screen.queryByText('Kaydım 1')).not.toBeInTheDocument()
    expect(screen.queryByText('İlk zil sesini oluştur')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Yeni Zil Sesi Oluştur Video, ses veya mikrofon' }))
    expect(onNavigate).toHaveBeenCalledWith('import')
  })

  it('opens the actual recent project rather than starting a new import', () => {
    const projects = [project(1), project(2), project(3), project(4)]
    const { onOpenProject, onNavigate } = renderHome(projects)
    fireEvent.click(within(screen.getByRole('region', { name: 'Son projeler' })).getByRole('button', { name: /Kaydım 2/ }))
    expect(onOpenProject).toHaveBeenCalledExactlyOnceWith(projects[1])
    expect(onNavigate).not.toHaveBeenCalled()
    expect(within(screen.getByRole('region', { name: 'Son projeler' })).queryByText('Kaydım 4')).not.toBeInTheDocument()
    expect(screen.queryByRole('status')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Tümü' }))
    expect(onNavigate).toHaveBeenCalledWith('library')
  })

  it('routes every Home shortcut to its existing destination', () => {
    const { onNavigate } = renderHome()
    const shortcuts = [
      ['Ses Kaydet', 'recorder'],
      ['Kütüphane', 'library'],
      ['Nasıl Ayarlanır?', 'guide'],
      ['Ayarlar', 'settings'],
    ] as const
    for (const [name, destination] of shortcuts) {
      fireEvent.click(screen.getByRole('button', { name }))
      expect(onNavigate).toHaveBeenLastCalledWith(destination)
    }
    expect(onNavigate).toHaveBeenCalledTimes(shortcuts.length)
  })
})

describe('Ringify 3.0 Audio Studio contracts', () => {
  it('preserves the current selection and valid continue/back callbacks', () => {
    const { onContinue, onBack } = renderEditor()
    expect(screen.getByRole('heading', { name: 'Ses Stüdyosu' })).toBeInTheDocument()
    expect(screen.getByText('Bosphorus.wav')).toBeInTheDocument()
    expectTrim(6, 21)
    fireEvent.click(screen.getByRole('button', { name: 'Efektlere Devam Et' }))
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onContinue).toHaveBeenCalledOnce()
    expect(onBack).toHaveBeenCalledOnce()
  })

  it('supports keyboard trim, undo, redo and reset without changing media or effects', () => {
    const { initial, onChange } = renderEditor()
    expect(screen.getByRole('button', { name: 'Geri Al' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Yinele' })).toBeDisabled()
    fireEvent.keyDown(screen.getByRole('slider', { name: 'Kesim başlangıcı' }), { key: 'ArrowRight', shiftKey: true })
    expectTrim(7, 21)
    expect(player.stop).toHaveBeenCalledOnce()
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, trimStart: 7 })
    fireEvent.click(screen.getByRole('button', { name: 'Geri Al' }))
    expectTrim(6, 21)
    fireEvent.click(screen.getByRole('button', { name: 'Yinele' }))
    expectTrim(7, 21)
    fireEvent.click(screen.getByRole('button', { name: 'Sıfırla' }))
    expectTrim(0, 29)
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, trimStart: 0, trimEnd: 29 })
    fireEvent.click(screen.getByRole('button', { name: 'Geri Al' }))
    expectTrim(7, 21)
  })

  it('clears redo after a new trim branch and retains fine keyboard adjustments', () => {
    renderEditor()
    const start = () => screen.getByRole('slider', { name: 'Kesim başlangıcı' })
    fireEvent.keyDown(start(), { key: 'ArrowRight', shiftKey: true })
    fireEvent.click(screen.getByRole('button', { name: 'Geri Al' }))
    expect(screen.getByRole('button', { name: 'Yinele' })).toBeEnabled()
    fireEvent.keyDown(start(), { key: 'ArrowLeft' })
    expectTrim(5.9, 21)
    expect(screen.getByRole('button', { name: 'Yinele' })).toBeDisabled()
  })

  it('bounds zoom at 1×–3× and scales the actual waveform track', () => {
    renderEditor()
    const zoomIn = screen.getByRole('button', { name: 'Yakınlaştır' })
    const zoomOut = screen.getByRole('button', { name: 'Uzaklaştır' })
    const track = () => screen.getByTestId('waveform-track').parentElement
    expect(zoomOut).toBeDisabled()
    expect(screen.getByText('1×')).toBeInTheDocument()
    expect(track()).toHaveStyle({ width: '100%' })
    fireEvent.click(zoomIn)
    expect(screen.getByText('2×')).toBeInTheDocument()
    expect(track()).toHaveStyle({ width: '200%' })
    fireEvent.click(zoomIn)
    expect(screen.getByText('3×')).toBeInTheDocument()
    expect(track()).toHaveStyle({ width: '300%' })
    expect(zoomIn).toBeDisabled()
    fireEvent.click(zoomIn)
    expect(screen.getByText('3×')).toBeInTheDocument()
    fireEvent.click(zoomOut)
    fireEvent.click(zoomOut)
    expect(zoomOut).toBeDisabled()
    expect(track()).toHaveStyle({ width: '100%' })
    expectTrim(6, 21)
  })

  it('passes loop state to the existing player and exposes its pressed state', () => {
    const { initial } = renderEditor()
    const loop = screen.getByRole('button', { name: 'Seçimi döngüyle oynat' })
    expect(loop).toHaveAttribute('aria-pressed', 'false')
    expect(useSegmentPlayer).toHaveBeenLastCalledWith(initial, false)
    fireEvent.click(loop)
    expect(loop).toHaveAttribute('aria-pressed', 'true')
    expect(useSegmentPlayer).toHaveBeenLastCalledWith(initial, true)
    fireEvent.click(loop)
    expect(loop).toHaveAttribute('aria-pressed', 'false')
    expect(useSegmentPlayer).toHaveBeenLastCalledWith(initial, false)
  })

  it('uses the existing play/pause callback and reflects player state', () => {
    const { refresh } = renderEditor()
    fireEvent.click(screen.getByRole('button', { name: 'Oynat' }))
    expect(player.play).toHaveBeenCalledOnce()
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, isPlaying: true, playhead: 8.25 })
    refresh()
    fireEvent.click(screen.getByRole('button', { name: 'Duraklat' }))
    expect(player.play).toHaveBeenCalledTimes(2)
  })

  it.each([
    [6, 6.5, 'En az 1 saniye seç.'],
    [0, 30, 'Zil sesi en fazla 29 saniye olabilir.'],
  ])('blocks continuation for invalid selection %s–%s', (start, end, message) => {
    const initial = { ...initialEditor(), trimStart: start, trimEnd: end }
    const { onContinue } = renderEditor(initial)
    expect(screen.getByRole('alert')).toHaveTextContent(message)
    const continueButton = screen.getByRole('button', { name: 'Efektlere Devam Et' })
    expect(continueButton).toBeDisabled()
    fireEvent.click(continueButton)
    expect(onContinue).not.toHaveBeenCalled()
  })

  it('surfaces playback failures rather than reporting a successful preview', () => {
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, error: 'Codec açılamadı' })
    renderEditor()
    expect(screen.getByRole('alert')).toHaveTextContent('Codec açılamadı')
    expect(screen.getByRole('button', { name: 'Oynat' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Duraklat' })).not.toBeInTheDocument()
  })

  it('localizes the approved Studio back action into English without changing its callbacks', () => {
    const onBack = vi.fn(), onContinue = vi.fn()
    render(<EditorScreen language="en" editor={initialEditor()} onChange={vi.fn()} onBack={onBack} onContinue={onContinue} />)
    expect(screen.getByRole('heading', { name: 'Audio Studio' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Back' }))
    fireEvent.click(screen.getByRole('button', { name: 'Continue to Effects' }))
    expect(onBack).toHaveBeenCalledOnce()
    expect(onContinue).toHaveBeenCalledOnce()
    expect(screen.queryByRole('button', { name: 'Geri' })).not.toBeInTheDocument()
  })
})

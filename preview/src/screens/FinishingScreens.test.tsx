import { useState } from 'react'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { EffectsScreen, RingtonePreviewScreen } from './FinishingScreens'
import { useSegmentPlayer } from '../hooks/useSegmentPlayer'
import { emptyAudio } from '../test/audioFixtures'
import type { EditorState, Language } from '../types'

// Only presentation and callback contracts are exercised here. The real shared
// audio pipeline remains covered by its DSP/segment-player tests and browser QA.
vi.mock('../hooks/useSegmentPlayer', () => ({ useSegmentPlayer: vi.fn() }))

const player = {
  isPlaying: false,
  playhead: 3,
  play: vi.fn().mockResolvedValue(undefined),
  stop: vi.fn(),
  error: null as string | null,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(useSegmentPlayer).mockReturnValue({ ...player })
})
afterEach(cleanup)

function initialEditor(): EditorState {
  return {
    projectID: 'finishing-project',
    projectName: 'Boğaz Tınısı',
    asset: {
      fileName: 'Bosphorus.wav',
      duration: 40,
      peaks: [0.15, 0.6, 0.35, 0.8, 0.45, 0.2],
      buffer: emptyAudio(2, 4000, 100),
      isDemo: false,
    },
    trimStart: 3,
    trimEnd: 23,
    effects: { volume: 0.75, fadeIn: 0.4, fadeOut: 0.8, normalize: false },
  }
}

function renderEffects(initial = initialEditor(), language: Language = 'tr') {
  const onChange = vi.fn()
  const onBack = vi.fn()
  const onContinue = vi.fn()
  function Harness() {
    const [editor, setEditor] = useState(initial)
    return <EffectsScreen language={language} editor={editor} onBack={onBack} onContinue={onContinue}
      onChange={(next) => { setEditor(next); onChange(next) }} />
  }
  const rendered = render(<Harness />)
  return { ...rendered, initial, onChange, onBack, onContinue, refresh: () => rendered.rerender(<Harness />) }
}

function renderPreview(initial = initialEditor(), language: Language = 'tr') {
  const onChange = vi.fn()
  const onBack = vi.fn()
  const onExport = vi.fn()
  function Harness() {
    const [editor, setEditor] = useState(initial)
    return <RingtonePreviewScreen language={language} editor={editor} onBack={onBack} onExport={onExport}
      onChange={(next) => { setEditor(next); onChange(next) }} />
  }
  const rendered = render(<Harness />)
  return { ...rendered, initial, onChange, onBack, onExport, refresh: () => rendered.rerender(<Harness />) }
}

describe('Advanced Effects presentation contracts', () => {
  it('keeps volume limits and derives fade limits from the actual selected duration', () => {
    const initial = { ...initialEditor(), trimStart: 3, trimEnd: 7 }
    const { rerender } = render(<EffectsScreen language="tr" editor={initial}
      onChange={vi.fn()} onBack={vi.fn()} onContinue={vi.fn()} />)
    expect(screen.getByRole('heading', { name: 'Sesi iyileştir' })).toBeInTheDocument()
    const volume = screen.getByRole('slider', { name: 'Ses Seviyesi' })
    expect(volume).toHaveAttribute('id', 'volume-control')
    expect(volume).toHaveAttribute('min', '0')
    expect(volume).toHaveAttribute('max', '1.5')
    expect(volume).toHaveAttribute('step', '0.05')
    for (const [name, id] of [['Fade-in', 'fade-in-control'], ['Fade-out', 'fade-out-control']]) {
      const fade = screen.getByRole('slider', { name })
      expect(fade).toHaveAttribute('id', id)
      expect(fade).toHaveAttribute('min', '0')
      expect(fade).toHaveAttribute('max', '2')
      expect(fade).toHaveAttribute('step', '0.1')
    }
    rerender(<EffectsScreen language="tr" editor={{ ...initial, trimEnd: 23 }}
      onChange={vi.fn()} onBack={vi.fn()} onContinue={vi.fn()} />)
    expect(screen.getByRole('slider', { name: 'Fade-in' })).toHaveAttribute('max', '5')
    expect(screen.getByRole('slider', { name: 'Fade-out' })).toHaveAttribute('max', '5')
  })

  it('updates volume and both fades while retaining all other project and audio fields', () => {
    const { initial, onChange } = renderEffects()
    fireEvent.change(screen.getByRole('slider', { name: 'Ses Seviyesi' }), { target: { value: '1.2' } })
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, effects: { ...initial.effects, volume: 1.2 } })
    fireEvent.change(screen.getByRole('slider', { name: 'Fade-in' }), { target: { value: '1.5' } })
    fireEvent.change(screen.getByRole('slider', { name: 'Fade-out' }), { target: { value: '2.5' } })
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, effects: { volume: 1.2, fadeIn: 1.5, fadeOut: 2.5, normalize: false } })
    expect(onChange.mock.lastCall?.[0].asset).toBe(initial.asset)
    expect(vi.mocked(useSegmentPlayer).mock.lastCall?.[0]).toEqual(onChange.mock.lastCall?.[0])
  })

  it('toggles normalize accessibly without replacing volume or fade settings', () => {
    const { initial, onChange } = renderEffects()
    const normalize = screen.getByRole('switch', { name: 'Ses seviyesini dengele' })
    expect(normalize).toHaveAttribute('aria-checked', 'false')
    fireEvent.click(normalize)
    expect(normalize).toHaveAttribute('aria-checked', 'true')
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, effects: { ...initial.effects, normalize: true } })
    fireEvent.click(normalize)
    expect(normalize).toHaveAttribute('aria-checked', 'false')
    expect(onChange).toHaveBeenLastCalledWith(initial)
  })

  it('resets only effects to the supported processing defaults', () => {
    const initial = initialEditor()
    initial.effects.normalize = true
    const { onChange } = renderEffects(initial)
    fireEvent.click(screen.getByRole('button', { name: 'Sıfırla' }))
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, effects: { volume: 1, fadeIn: 0, fadeOut: 0, normalize: false } })
    expect(onChange.mock.lastCall?.[0].asset).toBe(initial.asset)
    expect(screen.getByRole('slider', { name: 'Ses Seviyesi' })).toHaveValue('1')
    expect(screen.getByRole('switch', { name: 'Ses seviyesini dengele' })).toHaveAttribute('aria-checked', 'false')
  })

  it('retains the real preview and back callbacks', () => {
    const { onContinue, onBack, onChange } = renderEffects()
    fireEvent.click(screen.getByRole('button', { name: 'Ön İzle' }))
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(onContinue).toHaveBeenCalledOnce()
    expect(onBack).toHaveBeenCalledOnce()
    expect(onChange).not.toHaveBeenCalled()
  })

  it('delegates play/pause and return-to-start to the existing audio hook', () => {
    const { refresh } = renderEffects()
    fireEvent.click(screen.getByRole('button', { name: 'Oynat' }))
    expect(player.play).toHaveBeenCalledOnce()
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, isPlaying: true, playhead: 5 })
    refresh()
    fireEvent.click(screen.getByRole('button', { name: 'Duraklat' }))
    fireEvent.click(screen.getByRole('button', { name: 'Başa dön' }))
    expect(player.play).toHaveBeenCalledTimes(2)
    expect(player.stop).toHaveBeenCalledOnce()
  })

  it('announces actual playback errors without the old promotional decorations or footer note', () => {
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, error: 'Ses çözümlenemedi' })
    const { container } = renderEffects()
    expect(screen.getByRole('alert')).toHaveTextContent('Ses çözümlenemedi')
    expect(container.querySelector('.preview-celebration, .artwork-disc, svg.lucide-sparkles, .inline-notice')).toBeNull()
    expect(screen.queryByText(/Bu önizlemede ses seviyesi, fade ve normalize/)).not.toBeInTheDocument()
  })

  it('localizes effect controls and actions into English', () => {
    const { onContinue } = renderEffects(initialEditor(), 'en')
    expect(screen.getByRole('heading', { name: 'Enhance Audio' })).toBeInTheDocument()
    expect(screen.getByRole('slider', { name: 'Volume' })).toBeInTheDocument()
    expect(screen.getByRole('switch', { name: 'Normalize volume' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Play' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Return to start' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Preview' }))
    expect(onContinue).toHaveBeenCalledOnce()
  })
})

describe('Ringtone Preview presentation contracts', () => {
  it('edits the bounded ringtone name without changing media, selection or effects', () => {
    const { initial, onChange } = renderPreview()
    expect(screen.getByRole('heading', { name: 'Zil sesi ön izlemesi' })).toBeInTheDocument()
    const name = screen.getByRole('textbox', { name: 'Zil sesi adı' })
    expect(name).toHaveAttribute('maxlength', '64')
    expect(name).toHaveValue(initial.projectName)
    fireEvent.change(name, { target: { value: 'Akşam Vapuru' } })
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, projectName: 'Akşam Vapuru' })
    expect(onChange.mock.lastCall?.[0].asset).toBe(initial.asset)
    expect(onChange.mock.lastCall?.[0].effects).toBe(initial.effects)
    expect(vi.mocked(useSegmentPlayer).mock.lastCall?.[0]).toEqual(onChange.mock.lastCall?.[0])
  })

  it('exports a named real audio selection and keeps Edit Again connected', () => {
    const { onExport, onBack, onChange } = renderPreview()
    const exportButton = screen.getByRole('button', { name: 'Dışa Aktar' })
    expect(exportButton).toBeEnabled()
    fireEvent.click(exportButton)
    fireEvent.click(screen.getByRole('button', { name: 'Yeniden Düzenle' }))
    expect(onExport).toHaveBeenCalledOnce()
    expect(onBack).toHaveBeenCalledOnce()
    expect(onChange).not.toHaveBeenCalled()
  })

  it.each(['blank name', 'missing audio'] as const)('blocks export for %s rather than claiming a usable output', (missing) => {
    const initial = initialEditor()
    if (missing === 'blank name') initial.projectName = '   '
    else initial.asset.buffer = null
    const { onExport } = renderPreview(initial)
    const exportButton = screen.getByRole('button', { name: 'Dışa Aktar' })
    expect(exportButton).toBeDisabled()
    fireEvent.click(exportButton)
    expect(onExport).not.toHaveBeenCalled()
    if (missing === 'missing audio') expect(screen.getByRole('alert')).toHaveTextContent(/ses|dosya|audio|file/i)
  })

  it('retains play/pause and return-to-start callbacks for the final processed preview', () => {
    const { refresh } = renderPreview()
    fireEvent.click(screen.getByRole('button', { name: 'Oynat' }))
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, isPlaying: true })
    refresh()
    fireEvent.click(screen.getByRole('button', { name: 'Duraklat' }))
    fireEvent.click(screen.getByRole('button', { name: 'Başa dön' }))
    expect(player.play).toHaveBeenCalledTimes(2)
    expect(player.stop).toHaveBeenCalledOnce()
  })

  it('announces playback errors and removes the old slogan, sparkle and disc presentation', () => {
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, error: 'Ses aygıtı kullanılamıyor' })
    const { container } = renderPreview()
    expect(screen.getByRole('alert')).toHaveTextContent('Ses aygıtı kullanılamıyor')
    expect(screen.queryByText('Kulağa hazır geliyor')).not.toBeInTheDocument()
    expect(container.querySelector('.preview-celebration, .artwork-disc, svg.lucide-sparkles, .inline-notice')).toBeNull()
  })

  it('localizes the final name, preview controls and export actions into English', () => {
    const { onExport, onBack } = renderPreview(initialEditor(), 'en')
    expect(screen.getByRole('heading', { name: 'Ringtone Preview' })).toBeInTheDocument()
    expect(screen.getByRole('textbox', { name: 'Ringtone name' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Play' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Export' }))
    fireEvent.click(screen.getByRole('button', { name: 'Edit Again' }))
    expect(onExport).toHaveBeenCalledOnce()
    expect(onBack).toHaveBeenCalledOnce()
  })
})

import { useState } from 'react'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { EffectsScreen, RingtonePreviewScreen } from './LegacyFinishingScreens'
import { useSegmentPlayer } from '../hooks/useSegmentPlayer'
import { emptyAudio } from '../test/audioFixtures'
import type { EditorState } from '../types'

// Restored-screen presentation only; the actual playback/DSP pipeline is not
// replaced or reimplemented. Its existing engine suites remain authoritative.
vi.mock('../hooks/useSegmentPlayer', () => ({ useSegmentPlayer: vi.fn() }))

const player = { isPlaying: false, playhead: 3, play: vi.fn().mockResolvedValue(undefined), stop: vi.fn(), error: null as string | null }
beforeEach(() => { vi.clearAllMocks(); vi.mocked(useSegmentPlayer).mockReturnValue({ ...player }) })
afterEach(cleanup)

function editorFixture(): EditorState {
  return {
    projectID: 'restored-finishing-project', projectName: 'Boğaz Tınısı',
    asset: { fileName: 'bosphorus.wav', duration: 40, peaks: [0.15, 0.6, 0.8, 0.2], buffer: emptyAudio(2, 4000, 100), isDemo: false },
    trimStart: 3, trimEnd: 23,
    effects: { volume: 0.75, fadeIn: 0.4, fadeOut: 0.8, normalize: false },
  }
}

function renderEffects(initial = editorFixture()) {
  const onChange = vi.fn(), onBack = vi.fn(), onContinue = vi.fn()
  function Harness() {
    const [editor, setEditor] = useState(initial)
    return <EffectsScreen language="tr" editor={editor} onBack={onBack} onContinue={onContinue}
      onChange={next => { setEditor(next); onChange(next) }} />
  }
  const rendered = render(<Harness />)
  return { ...rendered, initial, onChange, onBack, onContinue, refresh: () => rendered.rerender(<Harness />) }
}

function renderPreview(initial = editorFixture()) {
  const onChange = vi.fn(), onBack = vi.fn(), onExport = vi.fn()
  function Harness() {
    const [editor, setEditor] = useState(initial)
    return <RingtonePreviewScreen language="tr" editor={editor} onBack={onBack} onExport={onExport}
      onChange={next => { setEditor(next); onChange(next) }} />
  }
  const rendered = render(<Harness />)
  return { ...rendered, initial, onChange, onBack, onExport, refresh: () => rendered.rerender(<Harness />) }
}

describe('Restored finishing screen contracts', () => {
  it('restores effect cards and updates/resets only supported effect fields without the old extra note', () => {
    const { container, initial, onChange } = renderEffects()
    expect(screen.getByRole('heading', { name: 'Sesi iyileştir' })).toBeInTheDocument()
    for (const selector of ['.effects-preview-card', '.control-card', '.toggle-card', '.split-actions']) {
      expect(container.querySelector(selector)).toBeInTheDocument()
    }
    fireEvent.change(screen.getByRole('slider', { name: 'Ses Seviyesi' }), { target: { value: '1.2' } })
    fireEvent.change(screen.getByRole('slider', { name: 'Fade-in' }), { target: { value: '1.5' } })
    fireEvent.change(screen.getByRole('slider', { name: 'Fade-out' }), { target: { value: '2.5' } })
    const normalize = screen.getByRole('switch', { name: 'Ses seviyesini dengele' })
    fireEvent.click(normalize)
    expect(normalize).toHaveAttribute('aria-checked', 'true')
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, effects: { volume: 1.2, fadeIn: 1.5, fadeOut: 2.5, normalize: true } })
    expect(onChange.mock.lastCall?.[0].asset).toBe(initial.asset)
    fireEvent.click(screen.getByRole('button', { name: 'Sıfırla' }))
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, effects: { volume: 1, fadeIn: 0, fadeOut: 0, normalize: false } })
    expect(screen.queryByText(/Bu önizlemede ses seviyesi, fade ve normalize/)).not.toBeInTheDocument()
    expect(container.querySelector('aside.inline-notice')).toBeNull()
  })

  it('keeps effect play/pause, playback errors, preview and back callbacks intact', () => {
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, error: 'Ses aygıtı kullanılamıyor' })
    const { refresh, onContinue, onBack } = renderEffects()
    expect(screen.getByRole('alert')).toHaveTextContent('Ses aygıtı kullanılamıyor')
    fireEvent.click(screen.getByRole('button', { name: 'Oynat' }))
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, isPlaying: true })
    refresh()
    fireEvent.click(screen.getByRole('button', { name: 'Duraklat' }))
    fireEvent.click(screen.getByRole('button', { name: 'Ön İzle' }))
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(player.play).toHaveBeenCalledTimes(2)
    expect(onContinue).toHaveBeenCalledOnce()
    expect(onBack).toHaveBeenCalledOnce()
  })

  it('uses the new file identity rather than a decorative CD and preserves real name/source/effect callbacks', () => {
    const { container, initial, onChange, onExport, onBack } = renderPreview()
    expect(screen.getByRole('heading', { name: 'Zil sesi ön izlemesi' })).toBeInTheDocument()
    expect(container.querySelector('.n4-preview-identity')).toBeInTheDocument()
    expect(container.querySelector('.ringtone-artwork,.artwork-disc,.preview-celebration')).toBeNull()
    const name = screen.getByRole('textbox', { name: 'Zil sesi adı' })
    expect(name).toHaveAttribute('maxlength', '64')
    fireEvent.change(name, { target: { value: 'Akşam Vapuru' } })
    expect(onChange).toHaveBeenLastCalledWith({ ...initial, projectName: 'Akşam Vapuru' })
    expect(onChange.mock.lastCall?.[0].asset).toBe(initial.asset)
    expect(onChange.mock.lastCall?.[0].effects).toBe(initial.effects)
    fireEvent.click(screen.getByRole('button', { name: 'Dışa Aktar' }))
    fireEvent.click(screen.getByRole('button', { name: 'Yeniden Düzenle' }))
    expect(onExport).toHaveBeenCalledOnce()
    expect(onBack).toHaveBeenCalledOnce()
    expect(container.querySelector('aside.inline-notice')).toBeNull()
  })

  it('keeps restored preview play/pause and exposes real playback failures', () => {
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, error: 'Ses çözümlenemedi' })
    const { refresh } = renderPreview()
    expect(screen.getByRole('alert')).toHaveTextContent('Ses çözümlenemedi')
    fireEvent.click(screen.getByRole('button', { name: 'Oynat' }))
    vi.mocked(useSegmentPlayer).mockReturnValue({ ...player, isPlaying: true })
    refresh()
    fireEvent.click(screen.getByRole('button', { name: 'Duraklat' }))
    expect(player.play).toHaveBeenCalledTimes(2)
  })

  it('blocks export when the restored preview name is blank', () => {
    const initial = { ...editorFixture(), projectName: '   ' }
    const { onExport } = renderPreview(initial)
    const exportButton = screen.getByRole('button', { name: 'Dışa Aktar' })
    expect(exportButton).toBeDisabled()
    fireEvent.click(exportButton)
    expect(onExport).not.toHaveBeenCalled()
  })

  it('blocks missing-audio export and shows an actionable error instead of a fake ready state', () => {
    const initial = editorFixture()
    initial.asset.buffer = null
    const { onExport } = renderPreview(initial)
    expect(screen.getByRole('alert')).toHaveTextContent(/ses|dosya|audio|file/i)
    const exportButton = screen.getByRole('button', { name: 'Dışa Aktar' })
    expect(exportButton).toBeDisabled()
    fireEvent.click(exportButton)
    expect(onExport).not.toHaveBeenCalled()
  })
})

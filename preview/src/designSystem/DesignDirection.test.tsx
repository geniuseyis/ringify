import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import tokens from '../../../design/tokens.json'
import { HomeScreen } from '../screens/HomeScreen'
import type { ProjectSummary } from '../types'
import { PlaybackControls, ProjectCard } from './StudioComponents'
import { designVariables } from './tokens'

afterEach(cleanup)

const project: ProjectSummary = {
  id: 'real-project-metadata',
  name: 'Boğazdaki sabah',
  sourceName: 'field-recording.wav',
  duration: 14.5,
  trimStart: 2.25,
  trimEnd: 16.75,
  updatedAt: '2026-10-31T12:00:00.000Z',
  status: 'exported',
}

function playbackProps() {
  return {
    language: 'tr' as const,
    isPlaying: false,
    loop: false,
    elapsed: 2.5,
    duration: 14.5,
    onPlay: vi.fn(),
    onStop: vi.fn(),
    onToggleLoop: vi.fn(),
  }
}

function luminance(hex: string) {
  const channels = [1, 3, 5].map((index) => parseInt(hex.slice(index, index + 2), 16) / 255)
    .map((channel) => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4)
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
}

function contrast(foreground: string, background: string) {
  const values = [luminance(foreground), luminance(background)]
  return (Math.max(...values) + 0.05) / (Math.min(...values) + 0.05)
}

describe('Ringify signature direction functional contracts', () => {
  it('keeps the user-selected scissors create action connected to real import navigation', () => {
    const onNavigate = vi.fn()
    const onOpenProject = vi.fn()
    render(<HomeScreen language="tr" projects={[]} isLoading={false}
      onNavigate={onNavigate} onOpenProject={onOpenProject} />)
    const create = screen.getByRole('button', { name: 'Yeni Zil Sesi Oluştur Video, ses veya mikrofon' })
    expect(create.querySelector('svg.lucide-scissors')).toBeInTheDocument()
    fireEvent.click(create)
    expect(onNavigate).toHaveBeenCalledExactlyOnceWith('import')
    expect(onOpenProject).not.toHaveBeenCalled()
  })

  it('shows real source, date, selected duration and status without inventing a saved waveform', () => {
    const onOpen = vi.fn()
    const { rerender } = render(<ProjectCard project={project} language="tr" onOpen={onOpen} />)
    const card = screen.getByRole('button', { name: /Boğazdaki sabah/ })
    expect(within(card).getByText(project.sourceName)).toBeInTheDocument()
    const date = new Intl.DateTimeFormat('tr-TR', { day: 'numeric', month: 'short' }).format(new Date(project.updatedAt))
    expect(within(card).getByText(date)).toBeInTheDocument()
    expect(within(card).getByText('0:14.5')).toBeInTheDocument()
    expect(within(card).getByText('Hazır')).toBeInTheDocument()
    expect(card.querySelector('[data-testid="waveform-track"], .waveform-bars')).toBeNull()
    fireEvent.click(card)
    expect(onOpen).toHaveBeenCalledOnce()
    rerender(<ProjectCard project={{ ...project, status: 'draft' }} language="tr" onOpen={onOpen} />)
    expect(screen.getByText('Taslak')).toBeInTheDocument()
    expect(screen.queryByText('Hazır')).not.toBeInTheDocument()
  })

  it('connects play/pause, Square stop and SkipBack return-to-start to their real callbacks', () => {
    const props = playbackProps()
    const { rerender } = render(<PlaybackControls {...props} />)
    const play = screen.getByRole('button', { name: 'Oynat' })
    expect(play.querySelector('svg.lucide-play')).toBeInTheDocument()
    fireEvent.click(play)
    expect(props.onPlay).toHaveBeenCalledOnce()
    rerender(<PlaybackControls {...props} isPlaying />)
    const pause = screen.getByRole('button', { name: 'Duraklat' })
    expect(pause.querySelector('svg.lucide-pause')).toBeInTheDocument()
    fireEvent.click(pause)
    expect(props.onPlay).toHaveBeenCalledTimes(2)
    const stop = screen.getByRole('button', { name: 'Durdur' })
    const returnToStart = screen.getByRole('button', { name: 'Başa dön' })
    expect(stop.querySelector('svg.lucide-square')).toBeInTheDocument()
    expect(returnToStart.querySelector('svg.lucide-skip-back')).toBeInTheDocument()
    fireEvent.click(stop)
    fireEvent.click(returnToStart)
    expect(props.onStop).toHaveBeenCalledTimes(2)
    expect(props.onPlay).toHaveBeenCalledTimes(2)
  })

  it('exposes controlled loop state and toggles it through the existing callback', () => {
    const props = playbackProps()
    const { rerender } = render(<PlaybackControls {...props} />)
    const loop = screen.getByRole('button', { name: 'Seçimi döngüyle oynat' })
    expect(loop).toHaveAttribute('aria-pressed', 'false')
    fireEvent.click(loop)
    expect(props.onToggleLoop).toHaveBeenCalledOnce()
    rerender(<PlaybackControls {...props} loop />)
    expect(loop).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('DÖNGÜ AÇIK')).toBeInTheDocument()
    fireEvent.click(loop)
    expect(props.onToggleLoop).toHaveBeenCalledTimes(2)
    expect(props.onPlay).not.toHaveBeenCalled()
    expect(props.onStop).not.toHaveBeenCalled()
  })

  it('maps signature tokens and keeps intended opaque canvas/text/wave pairs at least 4.5:1', () => {
    const signature = tokens.signature
    for (const [name, value] of Object.entries(signature)) {
      expect(designVariables).toHaveProperty(`--r-signature-${name}`, value)
    }
    for (const foreground of [signature.canvasText, signature.canvasMuted, signature.wave, signature.waveDim]) {
      expect(contrast(foreground, signature.canvas)).toBeGreaterThanOrEqual(4.5)
    }
    for (const background of [signature.heroStart, signature.heroEnd]) {
      for (const foreground of [signature.heroText, signature.heroSecondary, signature.heroAccent]) {
        expect(contrast(foreground, background)).toBeGreaterThanOrEqual(4.5)
      }
    }
  })
})

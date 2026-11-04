import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'
import { IDBFactory } from 'fake-indexeddb'

const settings = {
  theme: 'light',
  language: 'tr',
  exportFormat: 'wav-demo',
  onboardingSeen: true,
  isProDemo: false,
}

class RejectingAudioContext {
  sampleRate = 44_100
  decodeAudioData() { decodeCalled(); return Promise.reject(new Error('Unsupported audio data')) }
  createBuffer() { throw new Error('not needed') }
}
const decodeCalled = vi.fn()

describe('Ringify preview', () => {
  beforeEach(() => {
    vi.stubGlobal('indexedDB', new IDBFactory())
    decodeCalled.mockClear()
    vi.useFakeTimers()
    localStorage.clear()
    localStorage.setItem('ringify.settings.v1', JSON.stringify(settings))
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: RejectingAudioContext })
  })

  afterEach(() => {
    cleanup()
    vi.runOnlyPendingTimers()
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  async function finishLaunch() {
    await act(async () => { vi.advanceTimersByTime(800) })
  }

  it('navigates from Home to the import flow', async () => {
    render(<App />)
    expect(screen.getByLabelText('Ringify açılış ekranı')).toBeInTheDocument()
    await finishLaunch()
    fireEvent.click(screen.getByRole('button', { name: /Yeni Zil Sesi Oluştur/ }))
    expect(screen.getByRole('heading', { name: 'Kaynak seç' })).toBeInTheDocument()
    expect(screen.getByText('Telif içermeyen demo sesi kullan')).toBeInTheDocument()
  })

  it('changes appearance from Settings', async () => {
    render(<App />)
    await finishLaunch()
    const settingsButtons = screen.getAllByRole('button', { name: 'Ayarlar' })
    fireEvent.click(settingsButtons[settingsButtons.length - 1])
    fireEvent.click(screen.getByRole('button', { name: /Görünüm/ }))
    fireEvent.click(screen.getByRole('button', { name: 'Koyu' }))
    expect(document.documentElement.dataset.theme).toBe('dark')
  })

  it('shows a recoverable error for an undecodable local file', async () => {
    const { container } = render(<App />)
    await finishLaunch()
    fireEvent.click(screen.getByRole('button', { name: /Yeni Zil Sesi Oluştur/ }))
    const input = container.querySelector('input[type="file"][accept^="audio"]') as HTMLInputElement
    const file = new File(['not audio'], 'bozuk.wav', { type: 'audio/wav' })
    fireEvent.change(input, { target: { files: [file] } })
    await act(async () => { await Promise.resolve(); await Promise.resolve() })
    expect(screen.getByRole('alert')).toHaveTextContent('Dosya açılamadı')
    expect(decodeCalled).toHaveBeenCalledOnce()
    expect(screen.getByRole('button', { name: 'Tekrar Dene' })).toBeEnabled()
  })
})

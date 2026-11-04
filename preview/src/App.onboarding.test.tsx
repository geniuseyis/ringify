import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { IDBFactory } from 'fake-indexeddb'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'
import { ProjectRepository, type StoredProject } from './lib/projectRepository'
import type { AppSettings } from './types'

const settingsKey = 'ringify.settings.v1'
const initialSettings: AppSettings = {
  theme: 'light', language: 'tr', exportFormat: 'wav-demo', onboardingSeen: false, isProDemo: false,
}

beforeEach(() => {
  vi.stubGlobal('indexedDB', new IDBFactory())
  // Only the launch timeout is fake. Native setImmediate remains
  // available to fake-indexeddb so real repository transactions can complete.
  vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] })
  localStorage.clear()
  localStorage.setItem('ringify.projects.migrated.v2', 'true')
  localStorage.setItem(settingsKey, JSON.stringify(initialSettings))
})

afterEach(() => {
  cleanup()
  vi.clearAllTimers()
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

function storedSettings(): AppSettings {
  return JSON.parse(localStorage.getItem(settingsKey)!) as AppSettings
}

async function finishLaunch() {
  await act(async () => { vi.advanceTimersByTime(800) })
}

describe('Application onboarding persistence', () => {
  it('shows the real launch before onboarding, completes all pages and skips onboarding after remount', async () => {
    const first = render(<App />)
    expect(screen.getByLabelText('Ringify açılış ekranı')).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Sesini içeri aktar' })).not.toBeInTheDocument()
    await act(async () => { vi.advanceTimersByTime(719) })
    expect(screen.getByLabelText('Ringify açılış ekranı')).toBeInTheDocument()
    await act(async () => { vi.advanceTimersByTime(81) })
    expect(screen.getByRole('heading', { name: 'Sesini içeri aktar' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'İleri' }))
    fireEvent.click(screen.getByRole('button', { name: 'İleri' }))
    fireEvent.click(screen.getByRole('button', { name: 'Başla' }))
    expect(screen.getByRole('heading', { name:'Sesini imzana dönüştür.' })).toBeInTheDocument()
    expect(storedSettings()).toEqual({ ...initialSettings, onboardingSeen: true })
    first.unmount()
    render(<App />)
    await finishLaunch()
    expect(screen.getByRole('heading', { name:'Sesini imzana dönüştür.' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Sesini içeri aktar' })).not.toBeInTheDocument()
  })

  it('persists Skip through the same completion path and keeps it skipped after remount', async () => {
    const first = render(<App />)
    await finishLaunch()
    fireEvent.click(screen.getByRole('button', { name: 'Geç' }))
    expect(screen.getByRole('heading', { name:'Sesini imzana dönüştür.' })).toBeInTheDocument()
    expect(storedSettings()).toEqual({ ...initialSettings, onboardingSeen: true })
    first.unmount()
    render(<App />)
    await finishLaunch()
    expect(screen.getByRole('heading', { name:'Sesini imzana dönüştür.' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Geç' })).not.toBeInTheDocument()
  })

  it('takes an already-completed profile directly from launch to Home', async () => {
    localStorage.setItem(settingsKey, JSON.stringify({ ...initialSettings, onboardingSeen: true }))
    render(<App />)
    expect(screen.getByLabelText('Ringify açılış ekranı')).toBeInTheDocument()
    await finishLaunch()
    expect(screen.getByRole('heading', { name:'Sesini imzana dönüştür.' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Sesini içeri aktar' })).not.toBeInTheDocument()
    expect(storedSettings().onboardingSeen).toBe(true)
  })

  it('does not mark onboarding complete merely by browsing forward, backward or through dots', async () => {
    render(<App />)
    await finishLaunch()
    fireEvent.click(screen.getByRole('button', { name: 'İleri' }))
    expect(storedSettings().onboardingSeen).toBe(false)
    fireEvent.click(screen.getByRole('button', { name: '3. sayfa' }))
    expect(storedSettings().onboardingSeen).toBe(false)
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    expect(screen.getByRole('heading', { name: 'Tam istediğin anı seç' })).toBeInTheDocument()
    expect(storedSettings()).toEqual(initialSettings)
  })

  it('preserves existing IndexedDB project/source bytes and settings when onboarding completes', async () => {
    const repository = new ProjectRepository()
    const original: StoredProject = {
      id: 'existing-before-welcome',
      summary: { id: 'existing-before-welcome', name: 'Kayıtlı Ses', sourceName: 'kayit.wav', duration: 2, trimStart: 1, trimEnd: 3, updatedAt: '2026-10-31T12:00:00.000Z', status: 'draft' },
      sourceDuration: 4,
      source: { bytes: new Uint8Array([82, 73, 70, 70, 10, 20, 30, 40]).buffer, type: 'audio/wav' },
      effects: { volume: 0.6, fadeIn: 0.3, fadeOut: 0.4, normalize: true },
    }
    await repository.put(original)
    const first = render(<App />)
    await finishLaunch()
    fireEvent.click(screen.getByRole('button', { name: '3. sayfa' }))
    fireEvent.click(screen.getByRole('button', { name: 'Başla' }))
    expect(screen.getByRole('heading', { name:'Sesini imzana dönüştür.' })).toBeInTheDocument()
    await act(async () => {
      const restored = await repository.get(original.id)
      expect(restored).toEqual(original)
      expect(new Uint8Array(restored!.source!.bytes)).toEqual(new Uint8Array([82, 73, 70, 70, 10, 20, 30, 40]))
    })
    first.unmount()
    render(<App />)
    await finishLaunch()
    expect(screen.getByRole('heading', { name:'Sesini imzana dönüştür.' })).toBeInTheDocument()
    await act(async () => { expect(await repository.list()).toEqual([original]) })
    expect(storedSettings()).toEqual({ ...initialSettings, onboardingSeen: true })
  })
})

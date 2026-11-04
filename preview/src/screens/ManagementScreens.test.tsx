import { useState, type ComponentProps } from 'react'
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { LibraryScreen, SettingsScreen } from './ManagementScreens'
import type { AppSettings, ProjectSummary } from '../types'

// Controlled parent state simulates successful persistence only after callbacks
// resolve. IndexedDB/file ownership stays covered by the existing data suites.
afterEach(cleanup)

function projectsFixture(): ProjectSummary[] {
  return [
    { id: 'istanbul-project', name: 'İstanbul Işık', sourceName: 'istanbul.wav', duration: 20, trimStart: 3, trimEnd: 23, updatedAt: '2026-10-31T12:00:00.000Z', status: 'exported' },
    { id: 'evening-project', name: 'Sessiz Akşam', sourceName: 'aksam.webm', duration: 12, trimStart: 0, trimEnd: 12, updatedAt: '2026-10-30T12:00:00.000Z', status: 'draft' },
    { id: 'sunrise-project', name: 'Gün Doğumu', sourceName: 'gun.wav', duration: 15, trimStart: 5, trimEnd: 20, updatedAt: '2026-10-29T12:00:00.000Z', status: 'exported' },
  ]
}

function settingsFixture(): AppSettings {
  return { theme: 'system', language: 'tr', exportFormat: 'm4a-ios', onboardingSeen: true, isProDemo: false }
}

function deferred() {
  let resolve!: () => void
  const promise = new Promise<void>(done => { resolve = done })
  return { promise, resolve }
}

function renderLibrary(overrides: Partial<ComponentProps<typeof LibraryScreen>> = {}) {
  const props = {
    language: 'tr' as const, projects: projectsFixture(), isLoading: false,
    onCreate: vi.fn(), onOpenProject: vi.fn(),
    onUpdateProjects: vi.fn().mockResolvedValue(undefined), onShare: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  }
  function Harness() {
    const [projects, setProjects] = useState(props.projects)
    return <LibraryScreen {...props} projects={projects} onUpdateProjects={async next => {
      await props.onUpdateProjects(next)
      setProjects(next)
    }} />
  }
  return { ...render(<Harness />), ...props }
}

function renderSettings(overrides: Partial<ComponentProps<typeof SettingsScreen>> = {}) {
  const props = {
    settings: settingsFixture(), language: 'tr' as const, storageCount: 3,
    onChange: vi.fn(), onHelp: vi.fn(), onResetData: vi.fn().mockResolvedValue(undefined),
    onToast: vi.fn(), onOpenLibrary: vi.fn(), onOpenPremium: vi.fn(), ...overrides,
  }
  function Harness() {
    const [settings, setSettings] = useState(props.settings)
    return <SettingsScreen {...props} settings={settings} language={settings.language}
      onChange={next => { setSettings(next); props.onChange(next) }} />
  }
  return { ...render(<Harness />), ...props }
}

function openProjectActions(name = 'İstanbul Işık') {
  const trigger = screen.getByRole('button', { name: `${name} seçenekleri` })
  trigger.focus()
  fireEvent.click(trigger)
  return trigger
}

function beginRename() {
  const trigger = openProjectActions()
  fireEvent.click(screen.getByRole('button', { name: 'Yeniden adlandır' }))
  return trigger
}

function backdrop(container: HTMLElement) {
  return container.querySelector<HTMLElement>('.sheet-backdrop')!
}

describe('Library management presentation and safety contracts', () => {
  it('announces loading without exposing stale cards or a false empty state', () => {
    const { container, onCreate } = renderLibrary({ isLoading: true })
    expect(screen.getByRole('heading', { name: 'Kütüphane' })).toBeInTheDocument()
    expect(screen.getByRole('status')).toBeInTheDocument()
    expect(container.querySelector('.library-card')).toBeNull()
    expect(screen.queryByText('Henüz proje yok')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Yeni' }))
    expect(onCreate).toHaveBeenCalledOnce()
  })

  it('opens the actual selected project and preserves card actions when switching grid/list layout', () => {
    const { container, projects, onOpenProject } = renderLibrary()
    expect(screen.getByRole('button', { name: 'Tümü' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('3 proje')).toBeVisible()
    const toggle = screen.getByRole('button', { name: 'Görünümü değiştir' })
    expect(toggle).toBeVisible()
    fireEvent.click(toggle)
    expect(container.querySelector('.library-items.layout-grid')).toBeInTheDocument()
    expect(container.querySelectorAll('.library-card')).toHaveLength(3)
    expect(container.querySelectorAll('.more-button')).toHaveLength(3)
    fireEvent.click(screen.getByText('Sessiz Akşam').closest('button')!)
    expect(onOpenProject).toHaveBeenCalledExactlyOnceWith(projects[1])
    fireEvent.click(toggle)
    expect(container.querySelector('.library-items.layout-list')).toBeInTheDocument()
  })

  it('trims searches and handles Turkish dotted/dotless I without changing project identity', () => {
    const { onOpenProject, projects } = renderLibrary()
    const search = screen.getByPlaceholderText('Projelerde ara')
    fireEvent.change(search, { target: { value: '  istanbul  ' } })
    expect(screen.getByText('İstanbul Işık')).toBeInTheDocument()
    expect(screen.queryByText('Sessiz Akşam')).not.toBeInTheDocument()
    fireEvent.change(search, { target: { value: '  IŞIK  ' } })
    expect(screen.getByText('İstanbul Işık')).toBeInTheDocument()
    fireEvent.click(screen.getByText('İstanbul Işık').closest('button')!)
    expect(onOpenProject).toHaveBeenCalledExactlyOnceWith(projects[0])
  })

  it('distinguishes an empty filter from an empty library and preserves filter pressed states', () => {
    renderLibrary({ projects: [projectsFixture()[0]] })
    fireEvent.click(screen.getByRole('button', { name: 'Taslaklar' }))
    expect(screen.getByRole('button', { name: 'Taslaklar' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByText('Bu filtrede proje yok')).toBeInTheDocument()
    expect(screen.queryByText('Henüz proje yok')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Zil Sesleri' }))
    expect(screen.getByText('İstanbul Işık')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Zil Sesleri' })).toHaveAttribute('aria-pressed', 'true')
  })

  it('commits a trimmed bounded rename while preserving source IDs and all other records', async () => {
    const { projects, onUpdateProjects } = renderLibrary()
    beginRename()
    const name = screen.getByRole('textbox', { name: 'Yeni ad' })
    expect(name).toHaveAttribute('maxlength', '64')
    fireEvent.change(name, { target: { value: '  İstanbul Sabahı  ' } })
    fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(onUpdateProjects).toHaveBeenCalledOnce()
    const saved = vi.mocked(onUpdateProjects).mock.calls[0][0]
    expect(saved[0]).toEqual({ ...projects[0], name: 'İstanbul Sabahı', updatedAt: expect.any(String) })
    expect(saved.slice(1)).toEqual(projects.slice(1))
    expect(screen.getByText('İstanbul Sabahı')).toBeInTheDocument()
  })

  it('keeps the rename dialog and last saved project on persistence failure', async () => {
    const onUpdateProjects = vi.fn().mockRejectedValue(new Error('Depolama dolu'))
    renderLibrary({ onUpdateProjects })
    beginRename()
    fireEvent.change(screen.getByRole('textbox', { name: 'Yeni ad' }), { target: { value: 'Yeni Ad' } })
    fireEvent.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Depolama dolu')
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByRole('textbox', { name: 'Yeni ad' })).toHaveValue('Yeni Ad')
    expect(screen.getAllByText('İstanbul Işık').length).toBeGreaterThan(0)
    expect(screen.getByRole('button', { name: 'Kaydet' })).toBeEnabled()
  })

  it('requires explicit deletion confirmation and removes only the selected project', async () => {
    const { projects, onUpdateProjects } = renderLibrary()
    openProjectActions()
    fireEvent.click(screen.getByRole('button', { name: 'Sil' }))
    expect(onUpdateProjects).not.toHaveBeenCalled()
    fireEvent.click(screen.getByRole('button', { name: 'Vazgeç' }))
    expect(onUpdateProjects).not.toHaveBeenCalled()
    fireEvent.click(screen.getByRole('button', { name: 'Sil' }))
    fireEvent.click(screen.getByRole('button', { name: 'Projeyi Sil' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(onUpdateProjects).toHaveBeenCalledExactlyOnceWith(projects.slice(1))
    expect(screen.queryByText('İstanbul Işık')).not.toBeInTheDocument()
    expect(screen.getByText('Sessiz Akşam')).toBeInTheDocument()
  })

  it('shares and re-edits the real selected record through the existing callbacks', async () => {
    const { projects, onShare, onOpenProject } = renderLibrary()
    openProjectActions('Gün Doğumu')
    fireEvent.click(screen.getByRole('button', { name: 'Paylaş' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(onShare).toHaveBeenCalledExactlyOnceWith(projects[2])
    openProjectActions('Gün Doğumu')
    fireEvent.click(screen.getByRole('button', { name: 'Yeniden düzenle' }))
    expect(onOpenProject).toHaveBeenCalledExactlyOnceWith(projects[2])
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('closes normal sheets with Escape/backdrop and returns focus to the original trigger', async () => {
    const { container } = renderLibrary()
    const trigger = openProjectActions()
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' })
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(trigger).toHaveFocus()
    openProjectActions()
    fireEvent.mouseDown(backdrop(container))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(trigger).toHaveFocus()
  })

  it('guards a pending rename against duplicate writes, cancellation, Escape and backdrop dismissal', async () => {
    const pending = deferred()
    const onUpdateProjects = vi.fn().mockReturnValue(pending.promise)
    const { container } = renderLibrary({ onUpdateProjects })
    beginRename()
    fireEvent.change(screen.getByRole('textbox', { name: 'Yeni ad' }), { target: { value: 'Yeni Ad' } })
    const save = screen.getByRole('button', { name: 'Kaydet' })
    act(() => { fireEvent.click(save); fireEvent.click(save) })
    expect(onUpdateProjects).toHaveBeenCalledOnce()
    expect(screen.getByRole('status')).toBeInTheDocument()
    expect(save).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Vazgeç' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Kapat' })).toBeDisabled()
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' })
    fireEvent.mouseDown(backdrop(container))
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    await act(async () => { pending.resolve(); await pending.promise })
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(screen.getByText('Yeni Ad')).toBeInTheDocument()
  })

  it('disables every project operation during a pending share and prevents duplicate sharing', async () => {
    const pending = deferred()
    const onShare = vi.fn().mockReturnValue(pending.promise)
    const { container, onOpenProject, onUpdateProjects } = renderLibrary({ onShare })
    openProjectActions()
    const share = screen.getByRole('button', { name: 'Paylaş' })
    act(() => { fireEvent.click(share); fireEvent.click(share) })
    expect(onShare).toHaveBeenCalledOnce()
    expect(screen.getByRole('status')).toBeInTheDocument()
    for (const name of ['Yeniden düzenle', 'Yeniden adlandır', 'Paylaş', 'Sil', 'Kapat']) {
      expect(screen.getByRole('button', { name })).toBeDisabled()
    }
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' })
    fireEvent.mouseDown(backdrop(container))
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(onOpenProject).not.toHaveBeenCalled()
    expect(onUpdateProjects).not.toHaveBeenCalled()
    await act(async () => { pending.resolve(); await pending.promise })
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })
})

describe('Settings management presentation and safety contracts', () => {
  it('updates theme pressed states without replacing unrelated stored preferences', () => {
    const { settings, onChange } = renderSettings()
    fireEvent.click(screen.getByRole('button', { name: 'Görünüm' }))
    expect(screen.getByRole('button', { name: 'Sistem' })).toHaveAttribute('aria-pressed', 'true')
    fireEvent.click(screen.getByRole('button', { name: 'Koyu' }))
    expect(screen.getByRole('button', { name: 'Koyu' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: 'Sistem' })).toHaveAttribute('aria-pressed', 'false')
    expect(onChange).toHaveBeenLastCalledWith({ ...settings, theme: 'dark' })
    fireEvent.click(screen.getByRole('button', { name: 'Açık' }))
    expect(onChange).toHaveBeenLastCalledWith({ ...settings, theme: 'light' })
  })

  it('switches the displayed language immediately while retaining the full settings object', () => {
    const { settings, onChange } = renderSettings()
    fireEvent.click(screen.getByRole('button', { name: 'Dil' }))
    expect(screen.getByRole('heading', { name: 'Settings' })).toBeInTheDocument()
    expect(onChange).toHaveBeenLastCalledWith({ ...settings, language: 'en' })
    fireEvent.click(screen.getByRole('button', { name: 'Language' }))
    expect(screen.getByRole('heading', { name: 'Ayarlar' })).toBeInTheDocument()
    expect(onChange).toHaveBeenLastCalledWith(settings)
  })

  it('navigates projects, Pro and help through real callbacks instead of placeholder toasts', () => {
    const { onOpenLibrary, onOpenPremium, onHelp, onToast } = renderSettings()
    fireEvent.click(screen.getByRole('button', { name: 'Depolama' }))
    fireEvent.click(screen.getByRole('button', { name: 'Projeler' }))
    fireEvent.click(screen.getByRole('button', { name: 'Geri' }))
    fireEvent.click(screen.getByRole('button', { name: 'Ringify Pro' }))
    fireEvent.click(screen.getByRole('button', { name: 'Yardım ve hata durumları' }))
    expect(onOpenLibrary).toHaveBeenCalledOnce()
    expect(onOpenPremium).toHaveBeenCalledOnce()
    expect(onHelp).toHaveBeenCalledOnce()
    expect(onToast).not.toHaveBeenCalled()
  })

  it('opens a privacy subpage and restores the root action focus on Back', async () => {
    renderSettings()
    const privacy = screen.getByRole('button', { name: 'Veri ve gizlilik' })
    privacy.focus()
    fireEvent.click(privacy)
    expect(screen.getByRole('heading', { name: 'Gizlilik' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', {name:'Geri'}))
    await waitFor(() => expect(screen.getByRole('button', {name:'Veri ve gizlilik'})).toHaveFocus())
  })

  it('never resets local data merely by opening or cancelling the confirmation', () => {
    const { onResetData, onChange } = renderSettings()
    fireEvent.click(screen.getByRole('button', {name:'Depolama'}))
    fireEvent.click(screen.getByRole('button', { name: 'Yerel verileri sıfırla' }))
    expect(screen.getByRole('dialog', { name: 'Yerel veriler silinsin mi?' })).toBeInTheDocument()
    expect(onResetData).not.toHaveBeenCalled()
    fireEvent.click(screen.getByRole('button', { name: 'Vazgeç' }))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(onResetData).not.toHaveBeenCalled()
    expect(onChange).not.toHaveBeenCalled()
  })

  it('awaits confirmed data deletion and guards duplicate confirmation and dismissal while pending', async () => {
    const pending = deferred()
    const onResetData = vi.fn().mockReturnValue(pending.promise)
    const { container } = renderSettings({ onResetData })
    fireEvent.click(screen.getByRole('button', {name:'Depolama'}))
    fireEvent.click(screen.getByRole('button', { name: 'Yerel verileri sıfırla' }))
    const confirm = screen.getByRole('button', { name: 'Verileri Sil' })
    act(() => { fireEvent.click(confirm); fireEvent.click(confirm) })
    expect(onResetData).toHaveBeenCalledOnce()
    expect(screen.getByRole('status')).toBeInTheDocument()
    expect(confirm).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Vazgeç' })).toBeDisabled()
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' })
    fireEvent.mouseDown(backdrop(container))
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    await act(async () => { pending.resolve(); await pending.promise })
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('keeps a failed reset confirmation open with its error and does not overwrite settings', async () => {
    const onResetData = vi.fn().mockRejectedValue(new Error('Veritabanı kilitli'))
    const { onChange } = renderSettings({ onResetData })
    fireEvent.click(screen.getByRole('button', {name:'Depolama'}))
    fireEvent.click(screen.getByRole('button', { name: 'Yerel verileri sıfırla' }))
    fireEvent.click(screen.getByRole('button', { name: 'Verileri Sil' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Veritabanı kilitli')
    expect(screen.getByRole('dialog', { name: 'Yerel veriler silinsin mi?' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Verileri Sil' })).toBeEnabled()
    expect(onChange).not.toHaveBeenCalled()
  })

  it('localizes appearance controls in English and retains theme accessibility states', () => {
    renderSettings({ settings: { ...settingsFixture(), language: 'en' }, language: 'en' })
    fireEvent.click(screen.getByRole('button', { name: 'Appearance' }))
    expect(screen.getByRole('button', { name: 'System' })).toHaveAttribute('aria-pressed', 'true')
    fireEvent.click(screen.getByRole('button', { name: 'Dark' }))
    expect(screen.getByRole('button', { name: 'Dark' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByRole('button', { name: 'Light' })).toHaveAttribute('aria-pressed', 'false')
  })

  it('presents WAV as read-only preview output without a fake format toggle or preference mutation', () => {
    const { onChange, settings } = renderSettings()
    expect(screen.getAllByText(/WAV/).length).toBeGreaterThan(0)
    fireEvent.click(screen.getByRole('button', {name:'Ses ve dışa aktarma'}))
    expect(screen.getByText('WAV / PCM')).toBeInTheDocument()
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument()
    expect(onChange).not.toHaveBeenCalled()
    fireEvent.click(screen.getByRole('button', {name:'Geri'}))
    fireEvent.click(screen.getByRole('button', { name: 'Görünüm' }))
    fireEvent.click(screen.getByRole('button', { name: 'Koyu' }))
    expect(onChange).toHaveBeenLastCalledWith({ ...settings, theme: 'dark', exportFormat: 'm4a-ios' })
  })
})

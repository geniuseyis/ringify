import type { AppSettings, ProjectSummary } from '../types'

const PROJECTS_KEY = 'ringify.projects.v1'
const SETTINGS_KEY = 'ringify.settings.v1'

export const defaultSettings: AppSettings = {
  theme: 'system',
  language: 'tr',
  exportFormat: 'wav-demo',
  onboardingSeen: false,
  isProDemo: false,
}

export const demoProjects: ProjectSummary[] = [
  {
    id: 'demo-morning',
    name: 'Sabah Işığı',
    sourceName: 'ornek-melodi.wav',
    duration: 18.4,
    trimStart: 4.2,
    trimEnd: 22.6,
    updatedAt: '2026-10-31T09:42:00.000Z',
    status: 'exported',
    isDemo: true,
  },
  {
    id: 'demo-chime',
    name: 'Yumuşak Tını',
    sourceName: 'kayit-demo.wav',
    duration: 12.8,
    trimStart: 0,
    trimEnd: 12.8,
    updatedAt: '2026-10-29T18:15:00.000Z',
    status: 'draft',
    isDemo: true,
  },
]

function safeParse<T>(value: string | null, fallback: T): T {
  if (!value) return fallback
  try {
    return JSON.parse(value) as T
  } catch {
    return fallback
  }
}

export function loadSettings(): AppSettings {
  try {
    const saved = safeParse<Partial<AppSettings>>(localStorage.getItem(SETTINGS_KEY), {})
    return { ...defaultSettings, ...saved,
      theme: ['system', 'light', 'dark'].includes(saved.theme ?? '') ? saved.theme! : defaultSettings.theme,
      language: saved.language === 'en' ? 'en' : 'tr' }
  } catch { return { ...defaultSettings } }
}

export function saveSettings(settings: AppSettings) {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings))
}

export function loadProjects(): ProjectSummary[] {
  if (localStorage.getItem('ringify.projects.migrated.v2') === 'true') return []
  const projects = safeParse<unknown>(localStorage.getItem(PROJECTS_KEY), demoProjects)
  return Array.isArray(projects) ? projects.filter((item): item is ProjectSummary =>
    item && typeof item.id === 'string' && typeof item.name === 'string'
    && typeof item.sourceName === 'string' && typeof item.updatedAt === 'string'
    && Number.isFinite(item.duration) && Number.isFinite(item.trimStart) && Number.isFinite(item.trimEnd)) : []
}

export function clearLegacyProjects() {
  localStorage.setItem('ringify.projects.migrated.v2', 'true')
  localStorage.removeItem(PROJECTS_KEY)
}

export function saveProjects(projects: ProjectSummary[]) {
  localStorage.setItem(PROJECTS_KEY, JSON.stringify(projects))
}

export function resetPreviewData() {
  localStorage.removeItem(PROJECTS_KEY)
  localStorage.removeItem(SETTINGS_KEY)
}

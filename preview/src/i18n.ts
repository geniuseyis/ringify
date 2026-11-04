import type { Language } from './types'

const copy = {
  tr: {
    create: 'Yeni Zil Sesi Oluştur',
    home: 'Ana Sayfa',
    library: 'Kütüphane',
    pro: 'Pro',
    settings: 'Ayarlar',
    continue: 'Devam Et',
    cancel: 'İptal',
    back: 'Geri',
    done: 'Bitti',
    retry: 'Tekrar Dene',
    loading: 'Hazırlanıyor…',
    demo: 'Demo',
    previewOnly: 'Windows etkileşimli önizlemesi',
  },
  en: {
    create: 'Create New Ringtone',
    home: 'Home',
    library: 'Library',
    pro: 'Pro',
    settings: 'Settings',
    continue: 'Continue',
    cancel: 'Cancel',
    back: 'Back',
    done: 'Done',
    retry: 'Try Again',
    loading: 'Preparing…',
    demo: 'Demo',
    previewOnly: 'Windows interactive preview',
  },
} as const

export type CopyKey = keyof (typeof copy)['tr']

export function getCopy(language: Language) {
  return copy[language]
}

export function t(language: Language, key: CopyKey) {
  return copy[language][key]
}

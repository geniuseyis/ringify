import { AudioLines, Home, Library, Settings } from 'lucide-react'
import type { Language, ScreenId } from '../types'
import { getCopy } from '../i18n'
import {designVariables} from '../designSystem/tokens'

interface TabBarProps {
  active: ScreenId
  language: Language
  onNavigate: (screen: ScreenId) => void
}

export function TabBar({ active, language, onNavigate }: TabBarProps) {
  const copy = getCopy(language)
  const tabs = [
    { id: 'home' as const, label: copy.home, icon: Home },
    { id: 'studio' as const, label: language==='tr'?'Stüdyo':'Studio', icon: AudioLines },
    { id: 'library' as const, label: copy.library, icon: Library },
    { id: 'settings' as const, label: copy.settings, icon: Settings },
  ]

  return (
    <nav className="tab-bar v3-tab-bar" style={designVariables} aria-label={language==='tr'?'Ana navigasyon':'Main navigation'}>
      {tabs.map(({ id, label, icon: Icon }) => (
        <button
          key={id}
          className={`tab-item ${active === id ? 'is-active' : ''}`}
          onClick={() => onNavigate(id)}
          aria-current={active === id ? 'page' : undefined}
        >
          <Icon size={21} strokeWidth={active === id ? 2.7 : 2} aria-hidden="true" />
          <span>{label}</span>
        </button>
      ))}
    </nav>
  )
}

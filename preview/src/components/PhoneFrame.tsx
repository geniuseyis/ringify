import type { ReactNode } from 'react'

interface PhoneFrameProps {
  children: ReactNode
  theme: 'light' | 'dark'
  minimalChrome?: boolean
}

export function PhoneFrame({ children, theme, minimalChrome=false }: PhoneFrameProps) {
  return (
    <main className={`preview-stage theme-${theme}${minimalChrome?' minimal-preview':''}`}>
      <div className="ambient-orb ambient-one" />
      <div className="ambient-orb ambient-two" />
      <div className="preview-caption" aria-hidden="true">
        <span className="caption-kicker">RINGIFY</span>
        <strong>Interactive iOS Preview</strong>
        <small>Windows • React • Local-first</small>
      </div>
      <div className="phone-shell">
        <div className="phone-speaker" />
        <div className="phone-screen">
          {!minimalChrome?<div className="status-bar" aria-hidden="true">
            <span>9:41</span>
            <span className="dynamic-island" />
            <span className="status-icons">● ◒ ▰</span>
          </div>:null}
          <div className="app-viewport">{children}</div>
          {!minimalChrome?<div className="home-indicator" aria-hidden="true" />:null}
        </div>
      </div>
    </main>
  )
}

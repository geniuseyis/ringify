import type { CSSProperties, ReactNode } from 'react'
import { ChevronLeft, MoreHorizontal } from 'lucide-react'

interface ScreenShellProps {
  title?: string
  eyebrow?: string
  onBack?: () => void
  backLabel?: string
  trailing?: ReactNode
  children: ReactNode
  className?: string
  scroll?: boolean
  style?: CSSProperties
}

export function ScreenShell({
  title,
  eyebrow,
  onBack,
  backLabel = 'Geri',
  trailing,
  children,
  className = '',
  scroll = true,
  style,
}: ScreenShellProps) {
  return (
    <section style={style} className={`screen ${scroll ? 'screen-scroll' : 'screen-fixed'} ${className}`.trim()}>
      {title || onBack || trailing ? (
        <header className="screen-header">
          <div className="header-side header-leading">
            {onBack ? (
              <button className="icon-button" onClick={onBack} aria-label={backLabel}>
                <ChevronLeft size={22} strokeWidth={2.4} />
              </button>
            ) : null}
          </div>
          <div className="screen-title-wrap">
            {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
            {title ? <h1 className="screen-title">{title}</h1> : null}
          </div>
          <div className="header-side header-trailing">
            {trailing === 'more' ? (
              <button className="icon-button" aria-label="Daha fazla">
                <MoreHorizontal size={22} />
              </button>
            ) : trailing}
          </div>
        </header>
      ) : null}
      <div className="screen-content">{children}</div>
    </section>
  )
}
